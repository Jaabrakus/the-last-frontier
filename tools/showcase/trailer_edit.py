#!/usr/bin/env python3
"""The trailer, cut (user 2026-09-28: "lets create a trailer for the game we have a lot going on"): the takes of
tools/showcase/trailer.gd on the score's bar grid (tools/showcase/trailer_score.py), letterboxed, with its titles and
the game's own sound under the score.

    python3 tools/showcase/trailer_edit.py <takes dir>[,<takes dir>...] <out.mp4> <work dir> [--sheet] [--music <wav>]

A takes dir holds raw.avi (the movie writer's: only its sound is used) and a folder per take (frames/, frames.txt,
marks.txt). EDIT is the cut: every clip starts on a beat (a beat 18 frames at 30 fps) and lasts whole beats; `src` is
where in its take it starts (s), or `sync` puts one of the take's marks (the shot fired, the tree down) on a beat.
TITLES are the words over it. --sheet: a contact sheet of the cut (every clip's first, middle and last frame) and no
film. --music: a finished track (same length or longer) in place of the synthesized score.
The encoder is video_encode.swift (built into the work dir). Needs numpy and Pillow; the fonts are macOS's.
"""
from __future__ import annotations

import argparse
import math
import multiprocessing as mp
import os
import struct
import subprocess
import sys
import wave
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import trailer_score  # noqa: E402

FPS = 30
BEAT_F = 18                        ## frames per beat (100 BPM)
W, H = 1920, 1080
LETTERBOX = 2.39                   ## the picture's aspect inside the 16:9 frame
SERIF = "/System/Library/Fonts/Supplemental/Baskerville.ttc"
SANS = "/System/Library/Fonts/Avenir Next.ttc"
CREAM = (244, 236, 218)
AMBER = (226, 196, 142)


def B(bar: float, beat: float = 0.0) -> int:
	"""The output frame of a bar and beat."""
	return int(round((bar * 4 + beat) * BEAT_F))


@dataclass
class Clip:
	shot: str
	at: int                        ## output frame it cuts in on (B())
	beats: float
	src: float = 0.0               ## seconds into the take
	sync: tuple | None = None      ## (mark, output frame): the take's mark lands there (overrides src)
	speed: float = 1.0             ## > 1: faster (its sound left out)
	xfade: int = 0                 ## frames of dissolve from the clip before (they come before `at`)
	fade_in: int = 0               ## frames up from black
	fade_out: int = 0              ## frames down to black at its end
	gain: float | None = -8.0      ## dB of the take's own sound (None: silent)
	pre: float = 0.0               ## seconds its sound starts before its picture
	shift: int = 0                 ## px the picture moves up (+) or down in the letterbox (reframing)
	accents: tuple = ()            ## ((mark, kind), ...): a hit in the score at the mark ("boom", "hit", "thud", "cry";
	                               ## a number for the mark: that many beats into the clip)

	@property
	def end(self) -> int:
		return self.at + int(round(self.beats * BEAT_F))


@dataclass
class Title:
	at: int
	beats: float
	lines: list = field(default_factory=list)      ## [(text, style)]
	where: str = "center"          ## center | low
	fade: int = 12

	@property
	def end(self) -> int:
		return self.at + int(round(self.beats * BEAT_F))


# --- the cut -----------------------------------------------------------------------------------------------------------

S = trailer_score.SECTIONS
EDIT = [
	# open: the game's start-up screen (the title, the menu, its picture of the river: user 2026-09-29), dissolving
	# into the river at dawn; the valley in summer, then in the fall (the seasons)
	Clip("menu", B(0), 5, src=0.0, fade_in=12, gain=None, shift=-110),     # (down: the title clear of the letterbox)
	Clip("dawn_river", B(1, 1), 11, src=0.3, xfade=30, gain=-3.0, pre=2.2),
	Clip("valley", B(4), 4, src=0.8, xfade=24, gain=-9.0),
	Clip("autumn", B(5), 4, src=1.0, xfade=18, gain=-9.0),
	Clip("herd", B(6), 8, src=0.6, xfade=24, gain=-7.0),
	Clip("gate", B(8), 8, src=0.5, xfade=18, gain=-5.0),
	# grow: make a life
	Clip("walk", B(10), 8, src=1.0, gain=-7.0),
	Clip("chop", B(12), 4, sync=("felled", B(13)), gain=-2.0),
	Clip("chop", B(13), 8, sync=("felled", B(13)), gain=-2.0, accents=(("down", "boom"),)),
	Clip("build", B(15), 8, src=0.3, speed=1.6, gain=None),
	# yoga together, quick, under "MAKE A LIFE" (the synthesized cry did not sound right: user 2026-09-29)
	Clip("yoga", B(17), 2, sync=("paired", B(17)), gain=None),
	Clip("forage", B(17, 2), 2, src=0.4, gain=-6.0),
	Clip("cast", B(18), 4, sync=("cast", B(18, 1)), gain=-6.0),
	Clip("fight", B(19), 4, sync=("strike", B(19, 0.5)), gain=-5.0),
	Clip("ride", B(20), 8, src=0.6, gain=-5.0),
	# hunt: live off the land
	Clip("bison", B(22), 4, src=1.5, gain=-7.0),
	Clip("stalk", B(23), 6, sync=("loose", B(24, 1)), gain=-4.0),
	Clip("musket", B(24, 2), 6, sync=("shot", B(25, 2)), gain=-1.0),
	Clip("throw", B(26), 4, sync=("release", B(26, 1.5)), gain=-3.0),
	Clip("vault", B(27), 2, src=0.9, gain=-5.0),
	Clip("climb_tree", B(27, 2), 2, sync=("grip", B(27, 1)), gain=-5.0),
	Clip("stampede", B(28), 8, sync=("shot", B(28, 0.5)), gain=-2.0),
	# dark: the weather and the night
	Clip("storm", B(30), 8, src=6.0, gain=-1.0),
	# winter: snow falling in the woods, the river frozen across, the wolves on the snow
	Clip("winter_walk", B(32), 4, src=1.5, gain=-6.0),
	Clip("river_ice", B(33), 4, src=2.0, gain=-6.0),
	Clip("wolves", B(34), 4, src=1.0, gain=-3.0),
	Clip("torch", B(35), 4, src=0.6, gain=-5.0),
	Clip("camp", B(36), 4, src=3.0, gain=-5.0),
	Clip("reload", B(37), 4, sync=("ram", B(37, 1)), gain=-2.0, accents=(("ram", "thud"),)),
	# climax: a beat of black, then the shot in the dark on the hit
	Clip("night_shot", B(38, 1), 3, sync=("shot", B(38, 2)), gain=0.0),
	# title
	Clip("dusk", B(39), 12, src=0.5, fade_in=3, fade_out=36, gain=-12.0),
	# sting
	# the mammoth on the plains: shot behind the knee over his shoulder, going down; he takes hold of its flank and
	# climbs onto its back; then the charge's shot
	# (straight on from the title, no black between); the last shot: the climb, cut away before he is on its back (user
	# 2026-09-29: "it should end before he climbs the top of the mammoth"), a hit on the cut to the end card (the
	# charge's shot, the sting that was here, is out: "the final shot is bad")
	Clip("mammoth", B(42), 4, sync=("shot", B(42, 1)), gain=-1.0, accents=(("buckle", "boom"),)),
	Clip("mammoth", B(43), 7, sync=("grab", B(43)), gain=-2.0, accents=((7.0, "hit"),)),
]

TITLES = [
	Title(B(1, 3), 8, [("THE UPPER MOHAWK VALLEY", "place"), ("1765", "year")], where="low", fade=16),
	Title(B(5, 0.5), 3, [("THE SEASONS TURN", "tag")], where="low"),
	Title(B(10, 0.5), 6, [("CARVE OUT A LIFE", "tag")], where="low"),
	# what is happening (user 2026-09-29: "at least have titles of what is happening")
	Title(B(12, 1), 5, [("FELL THE FOREST", "tag")], where="low"),
	Title(B(15, 0.5), 6, [("BUILD A HOMESTEAD", "tag")], where="low"),
	Title(B(17), 4, [("MAKE A LIFE", "tag")], where="low"),
	Title(B(18, 0.5), 5, [("FISH THE RIVERS", "tag")], where="low"),
	Title(B(20, 0.5), 6, [("TAME AND RIDE HORSES", "tag")], where="low"),
	Title(B(22, 0.5), 6, [("LIVE OFF THE LAND", "tag")], where="low"),
	Title(B(24), 5, [("HUNT WITH BOW AND MUSKET", "tag")], where="low"),
	Title(B(27), 4, [("CLIMB ANYTHING", "tag")], where="low"),
	Title(B(28, 1), 5, [("THE HERDS STAMPEDE", "tag")], where="low"),
	Title(B(30, 0.5), 6, [("ENDURE THE WILD", "tag")], where="low"),
	Title(B(32, 0.5), 6, [("SURVIVE THE WINTER", "tag")], where="low"),
	Title(B(34, 0.5), 3, [("WOLVES HUNT TOO", "tag")], where="low"),
	Title(B(36, 0.5), 3, [("MAKE CAMP", "tag")], where="low"),
	Title(B(37, 0.5), 3, [("LOAD BY HAND", "tag")], where="low"),
	Title(B(39, 1), 10, [("FRONTIER", "title"), ("IN DEVELOPMENT", "place")], fade=20),
	Title(B(42, 0.5), 6, [("BRING DOWN GIANTS", "tag")], where="low"),
	Title(B(44, 3), 9, [("FRONTIER", "title_small"), ("In development", "sub"), ("", "gap"),
			("Deer and wolves: Quaternius (CC0)  ·  Bison and great horned owl: Poly by Google (CC-BY 3.0)", "small"),
			("Textures: Poly Haven (CC0)  ·  Sounds: Kenney, kheetor, rubberduck (CC0) and public-domain recordings", "small"),
			("Recorded in the game  ·  Music synthesized for the trailer  ·  Full credits: CREDITS.md", "small")], fade=14),
]
END = B(S["sting"][1])


# --- the takes ---------------------------------------------------------------------------------------------------------

class Take:
	def __init__(self, run: str, name: str):
		self.run = run
		self.name = name
		d = os.path.join(run, name)
		self.dir = os.path.join(d, "frames")
		self.n = len([f for f in os.listdir(self.dir) if f.endswith(".jpg")])
		self.engine: list[int] = []
		with open(os.path.join(d, "frames.txt")) as f:
			for line in f:
				if line.startswith("#") or not line.strip():
					continue
				self.engine.append(int(line.split()[1]))
		self.marks: dict[str, int] = {}
		mp_ = os.path.join(d, "marks.txt")
		if os.path.exists(mp_):
			with open(mp_) as f:
				for line in f:
					p = line.split()
					if len(p) == 2 and p[1] not in self.marks:
						self.marks[p[1]] = int(p[0])

	def path(self, k: int) -> str:
		return os.path.join(self.dir, "f%05d.jpg" % max(0, min(self.n - 1, k)))


def find_takes(runs: list[str]) -> dict[str, Take]:
	out: dict[str, Take] = {}
	for run in runs:
		for name in sorted(os.listdir(run)):
			if os.path.isdir(os.path.join(run, name, "frames")) and os.path.exists(os.path.join(run, name, "frames.txt")):
				t = Take(run, name)
				if t.n > 0:
					out[name] = t
	return out


_warned: set = set()


def src0(c: Clip, t: Take) -> int:
	"""The take's frame at the clip's first output frame."""
	if c.sync:
		m, at = c.sync
		if m not in t.marks:
			if (c.shot, m) not in _warned:
				_warned.add((c.shot, m))
				print("EDIT: %s has no mark '%s' (marks: %s): src %.1f s instead" % (c.shot, m, sorted(t.marks), c.src))
			return int(round(c.src * FPS))
		return t.marks[m] - int(round((at - c.at) * c.speed))
	return int(round(c.src * FPS))


def src_at(c: Clip, t: Take, i: int) -> int:
	return src0(c, t) + int(math.floor((i - c.at) * c.speed))


# --- the picture -------------------------------------------------------------------------------------------------------

_fonts: dict = {}


def font(style: str) -> tuple:
	"""(font, colour, tracking in em, gap after) of a title style."""
	if style not in _fonts:
		spec = {
			"title": (SERIF, 190, CREAM, 0.16, 28),
			"title_small": (SERIF, 120, CREAM, 0.14, 18),
			"tag": (SERIF, 66, CREAM, 0.2, 10),
			"place": (SERIF, 46, AMBER, 0.3, 12),
			"year": (SERIF, 34, CREAM, 0.5, 0),
			"sub": (SERIF, 42, AMBER, 0.06, 14),
			"small": (SANS, 23, (196, 196, 190), 0.02, 10),
			"gap": (SANS, 23, (0, 0, 0), 0.0, 26),
		}[style]
		try:
			f = ImageFont.truetype(spec[0], spec[1])
		except OSError:
			f = ImageFont.load_default()
		_fonts[style] = (f, spec[2], spec[3], spec[4], spec[1])
	return _fonts[style]


def text_width(d: ImageDraw.ImageDraw, s: str, f, tr: float, size: int) -> float:
	if not s:
		return 0.0
	return sum(d.textlength(ch, font=f) for ch in s) + tr * size * (len(s) - 1)


def draw_title(canvas: Image.Image, t: Title, alpha: float, top: int, bottom: int) -> None:
	layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
	d = ImageDraw.Draw(layer)
	rows = []
	total = 0
	for text, style in t.lines:
		f, col, tr, gap, size = font(style)
		asc, desc = f.getmetrics()
		rows.append((text, f, col, tr, size, asc + desc))
		total += asc + desc + gap
	if t.where == "low":
		y = bottom - total - int(0.09 * (bottom - top))
	else:
		y = top + (bottom - top - total) // 2
	for (text, style), (s, f, col, tr, size, lh) in zip(t.lines, rows):
		gap = font(style)[3]
		x = (canvas.width - text_width(d, s, f, tr, size)) / 2
		for ch in s:
			d.text((x, y), ch, font=f, fill=col + (255,))
			x += d.textlength(ch, font=f) + tr * size
		y += lh + gap
	a = layer.getchannel("A")
	shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
	shadow.putalpha(a.filter(ImageFilter.GaussianBlur(7)).point(lambda v: min(255, int(v * 0.9))))
	edge = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
	edge.putalpha(a.filter(ImageFilter.GaussianBlur(1.5)).point(lambda v: int(v * 0.6)))
	for lay in (shadow, edge, layer):
		if alpha < 1.0:
			lay.putalpha(lay.getchannel("A").point(lambda v, k=alpha: int(v * k)))
		canvas.alpha_composite(lay)


class Plan:
	def __init__(self, takes: dict[str, Take], edit: list[Clip], titles: list[Title], end: int):
		self.takes = takes
		self.edit = [c for c in edit if c.shot in takes]
		missing = sorted({c.shot for c in edit if c.shot not in takes})
		if missing:
			# (a missing take used to be left black: the whole of a draft's second half went out that way)
			if os.environ.get("ALLOW_BLACK", "") != "1":
				raise SystemExit("EDIT: no take for %s: record them (trailer.gd only=...) or ALLOW_BLACK=1" % ", ".join(missing))
			for m in missing:
				print("EDIT: no take '%s': left black" % m)
		self.titles = titles
		self.end = end
		self.bar = int(round((H - W / LETTERBOX) / 2))
		yy, xx = np.mgrid[0:H, 0:W]
		r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
		self.vignette = (1.0 - 0.22 * np.clip(r - 0.55, 0.0, 1.0) ** 1.6).astype(np.float32)[..., None]

	def picture(self, c: Clip, i: int) -> np.ndarray:
		t = self.takes[c.shot]
		im = Image.open(t.path(src_at(c, t, i))).convert("RGB")
		if im.size != (W, H):
			im = im.resize((W, H), Image.BICUBIC)
		a = np.asarray(im, dtype=np.float32)
		if c.shift:
			a = np.roll(a, -c.shift, axis=0)
		k = 1.0
		if c.fade_in:
			k = min(k, (i - c.at + 1) / c.fade_in)
		if c.fade_out:
			k = min(k, (c.end - i) / c.fade_out)
		return a * max(0.0, min(1.0, k))

	def frame(self, i: int) -> Image.Image:
		cur = None
		nxt = None
		for c in self.edit:
			if c.at <= i < c.end:
				cur = c
			elif c.xfade and c.at - c.xfade <= i < c.at:
				nxt = c
		if cur is None:
			a = np.zeros((H, W, 3), np.float32)
		else:
			a = self.picture(cur, i)
		if nxt is not None:
			w = (i - (nxt.at - nxt.xfade) + 1) / (nxt.xfade + 1)
			w = w * w * (3 - 2 * w)
			a = a * (1 - w) + self.picture(nxt, i) * w
		a = a * self.vignette
		a[: self.bar] = 0
		a[H - self.bar:] = 0
		img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")
		for t in self.titles:
			if t.at <= i < t.end:
				al = min(1.0, (i - t.at + 1) / t.fade, (t.end - i) / t.fade)
				draw_title(img, t, max(0.0, al), self.bar, H - self.bar)
		return img.convert("RGB")


_plan: Plan | None = None


def _render(args) -> None:
	i, out = args
	_plan.frame(i).save(os.path.join(out, "f%05d.jpg" % i), quality=92)


# --- the sound ---------------------------------------------------------------------------------------------------------

def avi_audio(path: str):
	"""(rate, channels, [bytes after each video frame]) from a Godot movie-writer AVI, streamed (pictures skipped)."""
	blocks: list = []
	pending = bytearray()
	st = {"type": None, "fmt": None}
	with open(path, "rb") as f:
		def walk(start: int, end: int, movi: bool) -> None:
			pos = start
			while pos + 8 <= end:
				f.seek(pos)
				hdr = f.read(8)
				if len(hdr) < 8:
					return
				cid, size = hdr[:4], struct.unpack("<I", hdr[4:])[0]
				body = pos + 8
				if cid in (b"RIFF", b"LIST"):
					kind = f.read(4)
					# (a movie still being written has its lists' sizes unset: to the end of the file)
					walk(body + 4, end if size == 0 or body + size > end else body + size, movi or kind == b"movi")
					if size == 0:
						return
				elif cid == b"strh":
					st["type"] = f.read(4)
				elif cid == b"strf" and st["type"] == b"auds":
					tag, ch, rate, _bps, _al, bits = struct.unpack("<HHIIHH", f.read(16))
					st["fmt"] = (tag, ch, rate, bits)
				elif movi and cid[2:4] in (b"dc", b"db"):
					blocks.append(bytearray())
				elif movi and cid[2:4] == b"wb":
					data = f.read(size)
					if blocks:
						blocks[-1] += data
					else:
						pending.extend(data)
				pos = body + size + (size & 1)
		walk(12, os.path.getsize(path), False)
	if st["fmt"] is None:
		raise SystemExit("no sound in %s" % path)
	tag, ch, rate, bits = st["fmt"]
	if tag != 1 or bits != 16:
		raise SystemExit("expected 16-bit PCM in %s, got %s" % (path, st["fmt"]))
	if pending and blocks:
		blocks[0] = pending + blocks[0]
	return rate, ch, blocks


def mix(plan: Plan, runs: list[str], music: str | None) -> tuple[np.ndarray, int]:
	avis = {}
	rate = 48000
	for run in runs:
		p = os.path.join(run, "raw.avi")
		if os.path.exists(p):
			rate, ch, blocks = avi_audio(p)
			avis[run] = (ch, blocks)
			print("EDIT sound: %s  %d Hz x %d, %d frames" % (p, rate, ch, len(blocks)))
	spf = rate / FPS
	n = int(round(plan.end * spf))
	game = np.zeros((n, 2))
	accents = []
	edit = plan.edit
	for k, c in enumerate(edit):
		t = plan.takes[c.shot]
		for m, kind in c.accents:
			if isinstance(m, (int, float)):
				accents.append(((c.at + m * BEAT_F) / FPS, kind))
			elif m in t.marks:
				accents.append(((c.at + (t.marks[m] - src0(c, t)) / c.speed) / FPS, kind))
		if c.gain is None or c.speed != 1.0 or t.run not in avis:
			continue
		ch, blocks = avis[t.run]
		nxt = edit[k + 1] if k + 1 < len(edit) and edit[k + 1].at == c.end else None
		out_len = nxt.xfade if nxt and nxt.xfade else 0
		first = c.at - c.xfade - int(round(c.pre * FPS))
		last = c.end + out_len
		pieces = []
		for i in range(first, last):
			s = src_at(c, t, i)
			e = t.engine[s] + 1 if 0 <= s < len(t.engine) else -1
			b = blocks[e] if 0 <= e < len(blocks) else b""
			a = np.frombuffer(bytes(b), dtype="<i2").astype(np.float64) / 32768.0
			a = a.reshape(-1, ch) if len(a) else np.zeros((0, ch))
			if ch == 1:
				a = np.repeat(a, 2, axis=1)
			want = int(round((i + 1) * spf)) - int(round(i * spf))
			if len(a) < want:
				a = np.vstack([a, np.zeros((want - len(a), 2))])
			pieces.append(a[:want, :2])
		y = np.vstack(pieces) * 10 ** (c.gain / 20.0)
		m = len(y)
		env = np.ones(m)
		fin = max(int(round((c.xfade + c.pre * FPS + c.fade_in) * spf)), int(0.006 * rate))
		fout = max(int(round((out_len + c.fade_out) * spf)), int(0.006 * rate))
		env[:fin] = np.minimum(env[:fin], np.linspace(0.0, 1.0, fin))
		env[m - fout:] = np.minimum(env[m - fout:], np.linspace(1.0, 0.0, fout))
		y *= env[:, None]
		o = int(round(first * spf))
		lo, hi = max(0, o), min(n, o + m)
		if hi > lo:
			game[lo:hi] += y[lo - o:hi - o]
	if music:
		with wave.open(music) as w:
			sc = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").reshape(-1, w.getnchannels()) / 32768.0
		if sc.shape[1] == 1:
			sc = np.repeat(sc, 2, axis=1)
		score = np.zeros((n, 2))
		score[: min(n, len(sc))] = sc[:n]
	else:
		print("EDIT score: %.1f s, %d accents" % (n / rate, len(accents)))
		score = trailer_score.render(n / rate, rate, accents)
		score = np.vstack([score, np.zeros((max(0, n - len(score)), 2))])[:n]
	y = score * 0.62 + game
	pk = np.percentile(np.abs(y), 99.95) + 1e-9
	y = np.tanh(y / pk * 0.9 * 1.4) / math.tanh(1.4)
	y *= 10 ** (-1.0 / 20.0) / (np.max(np.abs(y)) + 1e-9)
	return y, rate


def write_wav(path: str, y: np.ndarray, rate: int) -> None:
	with wave.open(path, "wb") as w:
		w.setnchannels(2)
		w.setsampwidth(2)
		w.setframerate(rate)
		w.writeframes((np.clip(y, -1, 1) * 32767).astype("<i2").tobytes())


# --- main --------------------------------------------------------------------------------------------------------------

def sheet(plan: Plan, out: str) -> None:
	tw, th = 480, 270
	rows = []
	for c in plan.edit:
		rows.append((c, [c.at, (c.at + c.end) // 2, c.end - 1]))
	img = Image.new("RGB", (tw * 3 + 260, th * len(rows)), (18, 18, 18))
	d = ImageDraw.Draw(img)
	f = ImageFont.truetype(SANS, 20)
	for r, (c, fr) in enumerate(rows):
		t = plan.takes[c.shot]
		d.text((10, r * th + 10), "%s\nbar %.2f  %g beats\ntake %d-%d of %d" % (c.shot, c.at / BEAT_F / 4, c.beats,
				src_at(c, t, c.at), src_at(c, t, c.end - 1), t.n), font=f, fill=(240, 220, 170))
		for k, i in enumerate(fr):
			img.paste(plan.frame(i).resize((tw, th)), (260 + k * tw, r * th))
	img.save(out)
	print("EDIT sheet %s" % out)


def main() -> None:
	ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
	ap.add_argument("runs")
	ap.add_argument("out")
	ap.add_argument("work")
	ap.add_argument("--sheet", action="store_true")
	ap.add_argument("--music")
	a = ap.parse_args()
	runs = a.runs.split(",")
	os.makedirs(a.work, exist_ok=True)
	takes = find_takes(runs)
	print("EDIT takes: %s" % ", ".join("%s(%d)" % (k, v.n) for k, v in takes.items()))
	plan = Plan(takes, EDIT, TITLES, END)
	for c in plan.edit:
		t = takes[c.shot]
		s0, s1 = src_at(c, t, c.at - c.xfade), src_at(c, t, c.end - 1)
		if s0 < 0 or s1 >= t.n:
			print("EDIT: %s at bar %.2f runs off its take (frames %d-%d of %d): held" % (c.shot, c.at / 72.0, s0, s1, t.n))
	if a.sheet:
		sheet(plan, a.out)
		return
	global _plan
	_plan = plan
	fdir = os.path.join(a.work, "cut")
	os.makedirs(fdir, exist_ok=True)
	for f in os.listdir(fdir):
		os.remove(os.path.join(fdir, f))
	with mp.get_context("fork").Pool(max(1, (os.cpu_count() or 4) - 1)) as pool:
		for k, _ in enumerate(pool.imap_unordered(_render, [(i, fdir) for i in range(plan.end)], chunksize=8)):
			if k % 300 == 0:
				print("EDIT frames %d / %d" % (k, plan.end), flush=True)
	y, rate = mix(plan, runs, a.music)
	wav = os.path.join(a.work, "trailer.wav")
	write_wav(wav, y, rate)
	enc = os.path.join(a.work, "video_encode")
	if not os.path.exists(enc):
		subprocess.run(["swiftc", "-O", os.path.join(os.path.dirname(os.path.abspath(__file__)), "video_encode.swift"),
				"-o", enc], check=True, stderr=subprocess.DEVNULL)
	subprocess.run([enc, "encode", fdir, str(FPS), a.out, wav, "24000000"], check=True)
	print("EDIT DONE %s (%.1f s)" % (a.out, plan.end / FPS))


if __name__ == "__main__":
	main()
