"""Fast checks for balance denominators and rejection of misleading samples."""
import unittest

from balance_report import ELEMENTS, parse_log, summarize


def game(a, b, seat=0):
    winner = (a, b)[seat] if seat >= 0 else "none"
    return (f'BAL GAME {a}-{b} winner={winner} seat={seat} game_s=300 '
            'lost=2:3 strings=5/2/1 kos0={"move/a":3} kos1={"move/b":2}')


def schedule(winner=None):
    return "\n".join(game(a, b, winner(a, b, n) if winner else n % 2)
                     for n in range(3) for a in ELEMENTS for b in ELEMENTS if a != b)


class BalanceReportTests(unittest.TestCase):
    def test_equal_participation_has_two_different_denominators(self):
        report = summarize([parse_log(schedule() + "\nBALANCE PASSED (6 checks)")])
        self.assertTrue(report["screen_passed"])
        self.assertEqual(report["cross_games"], 36)
        for element in report["elements"].values():
            self.assertEqual((element["wins"], element["games"]), (9, 18))
            self.assertEqual(element["win_rate"], 0.5)
            self.assertEqual(element["pooled_win_share"], 0.25)

    def test_mirrors_do_not_inflate_element_wins(self):
        report = summarize([parse_log(schedule() + "\n" + "\n".join([game("earth", "earth")] * 5)
                                      + "\nBALANCE PASSED (6 checks)")])
        self.assertTrue(report["screen_passed"])
        self.assertEqual(report["mirror_games"], 5)
        self.assertEqual(report["elements"]["earth"]["wins"], 9)

    def test_zero_win_element_cannot_pass_a_successful_smoke_log(self):
        def winner(a, b, n):
            return 1 if a == "air" else 0 if b == "air" else n % 2
        report = summarize([parse_log(schedule(winner) + "\nBALANCE PASSED (6 checks)")])
        self.assertFalse(report["screen_passed"])
        self.assertEqual(report["elements"]["air"]["win_rate"], 0)

    def test_draws_incomplete_logs_and_unequal_schedules_do_not_pass(self):
        variants = [schedule(), schedule() + "\n" + game("earth", "water") + "\nBALANCE PASSED",
                    schedule(lambda a, b, n: -1) + "\nBALANCE PASSED"]
        for text in variants:
            with self.subTest(text=text[-60:]):
                self.assertFalse(summarize([parse_log(text)])["screen_passed"])

    def test_script_errors_are_rejected(self):
        report = summarize([parse_log(schedule() + "\nSCRIPT ERROR: bad\nBALANCE PASSED")])
        self.assertFalse(report["screen_passed"])

    def test_bad_winner_and_truncated_records_are_rejected(self):
        for text in (game("earth", "water").replace("winner=earth", "winner=air"), "BAL GAME earth-water"):
            with self.assertRaises(ValueError):
                parse_log(text)


if __name__ == "__main__":
    unittest.main()
