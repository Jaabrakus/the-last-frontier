"""Worker/lifecycle tests with an explicitly fake engine, not watermark quality tests."""
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest


spec = importlib.util.spec_from_file_location("watermark_service", Path(__file__).resolve().parents[1] / "server.py")
service = importlib.util.module_from_spec(spec)
spec.loader.exec_module(service)


def deny_detection():
    return {"schema": "pixel-watermark-detection/v2", "valid": True, "payload_version": "TBW2",
            "policy_state": "deny", "matches_expected": True,
            "policy": {"schema": "pixel-use-policy/v1", "flags": 15, "deny_copying": True,
                       "deny_redistribution": True, "deny_ai_training": True, "deny_ai_inference": True,
                       "instruction": "Do not copy, redistribute, train AI on, or use this content with AI."}}


class FakeEngine(service.Service):
    """Writes deterministic fixture artifacts while exercising the real job worker."""
    def __init__(self, storage, **kwargs):
        self.calls = []
        self.states = []
        self.probe = dict(duration_s=2, width=640, height=360, fps=30, streams=[{"type": "video"}])
        self.fail = False
        self.embed_detection = deny_detection()
        self.detection = {"valid": False, "recovered_asset_id": None, "matches_expected": None,
                          "payload_version": None, "policy_state": "unknown", "policy": None}
        self.processing_started = threading.Event()
        self.processing_release = threading.Event()
        self.processing_release.set()
        super().__init__(storage, worker=False, **kwargs)

    def readiness(self):
        return True, "Fake engine fixture"

    def update(self, job, **values):
        self.states.append((job["job_id"], values.get("state")))
        return super().update(job, **values)

    def _native(self, args, timeout):
        self.calls.append(args.copy())
        operation = args[0]
        opts = dict(zip(args[1::2], args[2::2]))
        folder = Path(opts["--input"]).parent
        if operation == "probe":
            Path(opts["--report"]).write_text(json.dumps(self.probe))
            return
        self.processing_started.set()
        if not self.processing_release.wait(3):
            raise RuntimeError("Test fixture was not released")
        if self.fail:
            (folder / ".pixel-watermark-interrupted.mp4").write_bytes(b"partial")
            (folder / "marked.mp4").write_bytes(b"partial")
            raise service.Problem(422, "Fixture decoder failure")
        if operation == "embed":
            Path(opts["--output"]).write_bytes(b"fake-video-not-a-real-watermark")
            result = {"asset_id": opts["--asset-id"], "notice": opts["--notice"],
                      "source": opts["--input"], "output": opts["--output"],
                      "source_sha256": "fixture-source-hash", "nested": {"model_path": "/private/model.jit"},
                      "detection": self.embed_detection}
            Path(opts["--manifest"]).write_text(json.dumps(result))
        else:
            Path(opts["--report"]).write_text(json.dumps(dict(self.detection, expected_asset_id=opts.get("--asset-id"))))


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.svc = FakeEngine(self.tmp.name)
        self.thread = None

    def tearDown(self):
        self.svc.processing_release.set()
        self.svc.close()
        if self.thread:
            self.thread.join(2)
            self.assertFalse(self.thread.is_alive(), "Worker failed to stop")
        self.tmp.cleanup()

    def make_job(self, mode="embed"):
        job = self.svc.reserve(mode)
        (self.svc.storage / job["job_id"] / "source.bin").write_bytes(b"fixture")
        fields = {"notice": "Permission required.", "creator": "Test creator"} if mode == "embed" else {"asset_id": None}
        self.svc.submit(job, fields)
        return job

    def start_worker(self):
        self.thread = threading.Thread(target=self.svc._work, daemon=True)
        self.thread.start()

    def wait_done(self, *jobs):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            if self.svc.pending.unfinished_tasks == 0 and all(j["state"] in ("complete", "error", "denied") for j in jobs):
                return
            time.sleep(0.01)
        self.fail("Jobs did not finish")

    def test_embed_transitions_sanitizes_shared_manifest_and_removes_source(self):
        job = self.make_job()
        self.start_worker()
        self.wait_done(job)
        self.assertEqual(job["state"], "complete")
        states = [s for token, s in self.svc.states if token == job["job_id"]]
        self.assertIn("probing", states)
        self.assertIn("processing", states)
        self.assertEqual(states[-1], "complete")
        folder = self.svc.storage / job["job_id"]
        raw = (folder / "manifest.json").read_text()
        self.assertNotIn(str(folder), raw)
        self.assertNotIn(job["job_id"], raw)
        self.assertNotIn("model_path", raw)
        result = json.loads(raw)
        self.assertEqual(result["asset_id"], job["asset_id"])
        self.assertEqual(result["notice"], "Permission required.")
        self.assertTrue(result["service"]["notice_is_self_supplied"])
        self.assertEqual(result["permission"]["decision"], "deny")
        self.assertEqual(set(result["permission"]["restrictions"]), {"copying", "redistribution", "ai_training", "ai_use"})
        self.assertEqual(self.svc.calls[-1][self.svc.calls[-1].index("--policy-flags") + 1], "15")
        self.assertFalse((folder / "source.bin").exists())
        self.assertFalse((folder / "probe.json").exists())
        snapshot = self.svc.snapshot(job["job_id"])
        self.assertNotIn("fields", snapshot)
        self.assertEqual(set(snapshot["downloads"]), {"video", "manifest"})

    def test_unmarked_detection_is_completed_negative_not_processing_error(self):
        job = self.make_job("detect")
        self.start_worker()
        self.wait_done(job)
        self.assertEqual(job["state"], "complete")
        self.assertFalse(job["result"]["valid"])
        self.assertIsNone(job["result"]["recovered_asset_id"])
        self.assertEqual(job["result"]["permission"]["decision"], "unknown")
        self.assertNotIn("--asset-id", self.svc.calls[-1])
        self.assertEqual(set(self.svc.snapshot(job["job_id"])["downloads"]), {"report"})

    def test_current_deny_survives_expected_uuid_mismatch(self):
        self.svc.detection = dict(deny_detection(), matches_expected=False)
        job = self.make_job("detect")
        self.start_worker()
        self.wait_done(job)
        self.assertFalse(job["result"]["matches_expected"])
        self.assertEqual(job["result"]["permission"]["decision"], "deny")
        self.assertEqual(job["result"]["permission"]["source"], "pixel_payload")

    def test_existing_pixel_copy_denial_stops_before_embed_and_creates_no_output(self):
        self.svc.detection = deny_detection()
        job = self.make_job()
        self.start_worker()
        self.wait_done(job)
        self.assertEqual(job["state"], "denied")
        self.assertEqual(job["result"]["permission"]["decision"], "deny")
        self.assertEqual(job["result"]["denied_action"], "re_watermark")
        self.assertEqual([c[0] for c in self.svc.calls], ["probe", "detect"])
        self.assertNotIn("downloads", self.svc.snapshot(job["job_id"]))
        self.assertEqual([p.name for p in (self.svc.storage / job["job_id"]).iterdir()], ["job.json"])

    def test_ai_use_only_denial_stops_before_neural_embedding(self):
        self.svc.detection = deny_detection()
        self.svc.detection["policy"].update(flags=4, deny_copying=False, deny_redistribution=False,
                                             deny_ai_training=False, instruction="Do not use this content with AI.")
        job = self.make_job()
        self.start_worker()
        self.wait_done(job)
        self.assertEqual(job["state"], "denied")
        self.assertEqual(job["result"]["permission"]["restrictions"], ["ai_use"])
        self.assertEqual([c[0] for c in self.svc.calls], ["probe", "detect"])
        self.assertNotIn("downloads", self.svc.snapshot(job["job_id"]))
        self.assertEqual([p.name for p in (self.svc.storage / job["job_id"]).iterdir()], ["job.json"])

    def test_legacy_unknown_does_not_block_requested_marking_or_become_a_rights_grant(self):
        self.svc.detection = {"valid": True, "payload_version": "TBW1", "policy_state": "unknown", "policy": None}
        self.assertEqual(service.permission_from_detection(self.svc.detection)["decision"], "unknown")
        job = self.make_job()
        self.start_worker()
        self.wait_done(job)
        self.assertEqual(job["state"], "complete")
        self.assertEqual([c[0] for c in self.svc.calls], ["probe", "detect", "embed"])

    def test_legacy_denial_notice_does_not_become_pixel_policy(self):
        self.svc.detection = {"valid": True, "payload_version": "TBW1", "policy_state": "unknown", "policy": None,
                              "metadata": {"notice": "Do not copy or use with AI."}}
        job = self.make_job("detect")
        self.start_worker()
        self.wait_done(job)
        self.assertTrue(job["result"]["valid"])
        self.assertEqual(job["result"]["permission"]["decision"], "unknown")
        self.assertEqual(job["result"]["permission"]["restrictions"], [])

    def test_embed_without_recovered_policy_is_not_published(self):
        self.svc.embed_detection = {"valid": True, "payload_version": "TBW1", "policy": None}
        job = self.make_job()
        self.start_worker()
        self.wait_done(job)
        self.assertEqual(job["state"], "error")
        self.assertNotIn("downloads", self.svc.snapshot(job["job_id"]))
        self.assertEqual([p.name for p in (self.svc.storage / job["job_id"]).iterdir()], ["job.json"])

    def test_pixel_policy_unknown_for_invalid_forged_or_zero_flag_results(self):
        zero = deny_detection()
        zero["policy"].update(flags=0, **{k: False for k in service.RESTRICTIONS})
        zero["policy_state"] = "unknown"
        malformed = deny_detection()
        malformed["policy"]["deny_copying"] = "true"
        inconsistent = deny_detection()
        inconsistent["policy"]["flags"] = 1
        for report in [dict(deny_detection(), valid=False), dict(deny_detection(), payload_version="TBW1"),
                       dict(deny_detection(), policy_state="unknown"), zero, malformed, inconsistent, {}]:
            with self.subTest(report=report):
                decision = service.permission_from_detection(report)
                self.assertEqual(decision["decision"], "unknown")
                self.assertEqual(decision["restrictions"], [])

    def test_partial_pixel_policy_reports_only_recovered_denials(self):
        report = deny_detection()
        report["policy"].update(flags=2, deny_copying=False, deny_redistribution=False, deny_ai_inference=False,
                                instruction="Do not train AI on this content.")
        decision = service.permission_from_detection(report)
        self.assertEqual(decision["decision"], "deny")
        self.assertEqual(decision["restrictions"], ["ai_training"])

    def test_retained_older_job_api_permission_is_unknown(self):
        job = self.make_job("detect")
        job.update(state="complete", result={"valid": True, "notice": "No AI use"})
        self.assertEqual(self.svc.snapshot(job["job_id"])["result"]["permission"]["decision"], "unknown")

    def test_probe_rejects_expensive_work_before_embed(self):
        self.svc.probe.update(duration_s=60, width=3840, height=2160, fps=60)
        job = self.make_job()
        self.start_worker()
        self.wait_done(job)
        self.assertEqual(job["state"], "error")
        self.assertEqual([c[0] for c in self.svc.calls], ["probe"])
        self.assertFalse((self.svc.storage / job["job_id"] / "source.bin").exists())

    def test_unknown_nonfinite_and_out_of_bounds_probe_rejected(self):
        cases = [{"duration_s": None}, {"duration_s": float("nan")}, {"fps": float("inf")},
                 {"width": 0}, {"height": 5000}, {"duration_s": 60, "fps": 120}]
        for changes in cases:
            with self.subTest(changes=changes), self.assertRaises(service.Problem):
                service.Service.validate_probe(dict(self.svc.probe, **changes))

    def test_failed_processor_removes_partial_native_outputs(self):
        self.svc.fail = True
        job = self.make_job()
        self.start_worker()
        self.wait_done(job)
        self.assertEqual(job["state"], "error")
        self.assertEqual(job["message"], "Fixture decoder failure")
        self.assertEqual([p.name for p in (self.svc.storage / job["job_id"]).iterdir()], ["job.json"])

    def test_single_worker_keeps_second_job_queued_until_first_finishes(self):
        self.svc.processing_release.clear()
        first, second = self.make_job(), self.make_job()
        self.start_worker()
        self.assertTrue(self.svc.processing_started.wait(2))
        self.assertEqual(first["state"], "processing")
        self.assertEqual(second["state"], "queued")
        self.assertEqual([c[0] for c in self.svc.calls], ["probe", "detect"])
        self.svc.processing_release.set()
        self.wait_done(first, second)
        self.assertEqual([c[0] for c in self.svc.calls], ["probe", "detect", "embed", "probe", "detect", "embed"])

    def test_expired_queued_job_does_not_stop_worker_or_leak_admission_slot(self):
        expired = self.make_job()
        expired["expires_at"] = time.time() - 1
        self.svc.cleanup()
        self.assertNotIn(expired["job_id"], self.svc.jobs)
        active = self.make_job()
        self.start_worker()
        self.wait_done(active)
        self.assertEqual(active["state"], "complete")
        self.assertTrue(self.thread.is_alive())
        for _ in range(5):
            self.assertTrue(self.svc.slots.acquire(blocking=False))
        self.assertFalse(self.svc.slots.acquire(blocking=False))

    def test_restart_marks_interrupted_job_error_and_cleans_original_and_partial(self):
        job = self.make_job()
        folder = self.svc.storage / job["job_id"]
        (folder / ".pixel-watermark-interrupted.mp4").write_bytes(b"partial")
        (folder / "upload.body").write_bytes(b"private upload")
        restored = FakeEngine(self.tmp.name)
        try:
            self.assertEqual(restored.snapshot(job["job_id"])["state"], "error")
            self.assertEqual([p.name for p in folder.iterdir()], ["job.json"])
        finally:
            restored.close()

    def test_finished_job_expiry_removes_all_retained_artifacts(self):
        job = self.make_job()
        self.start_worker()
        self.wait_done(job)
        job["expires_at"] = time.time() - 1
        self.svc.cleanup()
        with self.assertRaises(service.Problem) as failure:
            self.svc.snapshot(job["job_id"])
        self.assertEqual(failure.exception.status, 404)
        self.assertFalse((self.svc.storage / job["job_id"]).exists())


if __name__ == "__main__":
    unittest.main()
