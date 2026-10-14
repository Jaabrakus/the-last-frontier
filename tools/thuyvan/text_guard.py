#!/usr/bin/env python3
"""Thủy Vân's text guard: no later book's reveals, none of the show's words, and no claim spoken as the game's own.

Scans the given files and folders (JSON, GDScript string literals, .tres and .tscn text) against the phrase lists in
guard_terms.json (beside this file, never shipped: tools/thuyvan has a .gdignore):

    python3 tools/thuyvan/text_guard.py data/thuyvan
    python3 tools/thuyvan/text_guard.py data/story data/ring data/sway scripts/ui --out report.txt

It FAILS (exit 1) on hits anywhere but the legacy paths (data/story, data/ring, data/sway, scripts/ui), where it only
reports: those belong to the frontier and the Tidebreak loop until the cutover. It also flags strings that are not NFC
and, in JSON, keys named like author-side matter (author_truth, hidden, evidence, truth, reveal_guard) and any key or
id holding a word no id under data/ may hold (hollow, seal, containment, convergence).

In JSON a display string is {"text": ..., "voice": ..., "tags": [...]}: the voice decides the claim-only terms and the
allowlist's voiced entries, and the nearest enclosing row's reveal_book (else Book I) decides the book-gated terms.
GDScript and scene strings count as Book I with no voice. Lowercase ids and res:// paths are checked as ids, not text.
"""

import argparse
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TERMS_PATH = os.path.join(HERE, "guard_terms.json")
LEGACY = ("data/story", "data/ring", "data/sway", "scripts/ui")
EXTS = (".json", ".gd", ".tres", ".tscn")
LISTS = ("book_gated", "show_words", "claim_only", "keys", "ids", "nfc")
# A code id or a resource path, not words a player reads.
IDENT = re.compile(r"^[a-z0-9_./:\-]*$")
PATH_PREFIXES = ("res://", "user://", "uid://")


class Item:
    """One string to check, with where it came from and what it is."""

    def __init__(self, text, where, kind="text", voice=None, tags=(), book=1):
        self.text = text
        self.where = where
        self.kind = kind  # "text", "key"
        self.voice = voice
        self.tags = tuple(tags)
        self.book = book


class Hit:
    def __init__(self, path, where, lst, term, snippet, strict):
        self.path = path
        self.where = where
        self.list = lst
        self.term = term
        self.snippet = snippet
        self.strict = strict

    def line(self):
        tag = "FAIL  " if self.strict else "report"
        return "%s %s:%s  %s/%s  %s" % (tag, self.path, self.where, self.list, self.term, json.dumps(self.snippet, ensure_ascii=False))


# --- terms ---------------------------------------------------------------------------------------------------------

def _compile(entry):
    flags = 0 if entry.get("case_sensitive") else re.IGNORECASE
    e = dict(entry)
    e["re"] = re.compile(unicodedata.normalize("NFC", entry["pattern"]), flags)
    return e


def load_terms(path=TERMS_PATH):
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    terms = {}
    for name in ("book_gated", "show_words", "claim_only", "allowlist"):
        terms[name] = [_compile(e) for e in raw.get(name, [])]
    terms["forbidden_keys"] = [k.lower() for k in raw.get("forbidden_keys", [])]
    terms["forbidden_id_words"] = [w.lower() for w in raw.get("forbidden_id_words", [])]
    return terms


# --- checking one string -------------------------------------------------------------------------------------------

def _snippet(text, m=None, width=40):
    if m is None:
        return text[: width * 2]
    a = max(0, m.start() - width)
    b = min(len(text), m.end() + width)
    return ("..." if a > 0 else "") + text[a:b] + ("..." if b < len(text) else "")


def _is_ident(text):
    return bool(IDENT.match(text)) or text.startswith(PATH_PREFIXES)


def _mask_allowed(text, item, terms):
    """Blank out the allowlisted spans (whose voice, tags and companion text fit) so no other list sees them."""
    out = text
    for e in terms["allowlist"]:
        if "voices" in e and item.voice not in e["voices"]:
            continue
        if "tags" in e and not set(e["tags"]).issubset(item.tags):
            continue
        if "requires" in e and unicodedata.normalize("NFC", e["requires"]) not in text:
            continue
        out = e["re"].sub(lambda m: " " * len(m.group(0)), out)
    return out


def check_item(item, terms):
    """[(list, term id, snippet)] for one string."""
    hits = []
    text = item.text
    nfc = unicodedata.normalize("NFC", text)
    if nfc != text:
        hits.append(("nfc", "not_nfc", _snippet(text)))
    low = nfc.lower()
    if item.kind == "key":
        for k in terms["forbidden_keys"]:
            if k in low:
                hits.append(("keys", k, nfc))
    if item.kind == "key" or (item.voice is None and _is_ident(nfc)):
        for w in terms["forbidden_id_words"]:
            if w in low:
                hits.append(("ids", w, nfc))
        return hits
    masked = _mask_allowed(nfc, item, terms)
    for e in terms["book_gated"]:
        if e["earliest_book"] > item.book:
            m = e["re"].search(masked)
            if m:
                hits.append(("book_gated", "%s(book %d)" % (e["id"], e["earliest_book"]), _snippet(nfc, m)))
    for e in terms["show_words"]:
        m = e["re"].search(masked)
        if m:
            hits.append(("show_words", e["id"], _snippet(nfc, m)))
    for e in terms["claim_only"]:
        if item.voice in e.get("voices", []):
            continue
        m = e["re"].search(masked)
        if m:
            hits.append(("claim_only", e["id"], _snippet(nfc, m)))
    return hits


# --- reading strings out of files ----------------------------------------------------------------------------------

def json_items(node, where="$", book=1):
    """Every key and string in a parsed JSON value, each with its display voice and its row's book."""
    if isinstance(node, dict):
        rb = node.get("reveal_book")
        if isinstance(rb, int) and not isinstance(rb, bool):
            book = rb
        voice = node.get("voice") if isinstance(node.get("voice"), str) else None
        tags = node.get("tags") if isinstance(node.get("tags"), list) else []
        is_display = voice is not None and isinstance(node.get("text"), str)
        for k, v in node.items():
            sub = "%s.%s" % (where, k)
            yield Item(k, sub, kind="key", book=book)
            if is_display and k == "text":
                yield Item(v, sub, voice=voice, tags=[t for t in tags if isinstance(t, str)], book=book)
            else:
                for it in json_items(v, sub, book):
                    yield it
    elif isinstance(node, list):
        for i, v in enumerate(node):
            for it in json_items(v, "%s[%d]" % (where, i), book):
                yield it
    elif isinstance(node, str):
        yield Item(node, where, book=book)


_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\", "0": "\0"}


def _unescape(s):
    def rep(m):
        e = m.group(1)
        if e[0] in "uU":
            try:
                return chr(int(e[1:], 16))
            except ValueError:
                return m.group(0)
        return _ESCAPES.get(e, e)
    return re.sub(r"\\(u[0-9a-fA-F]{4}|U[0-9a-fA-F]{6}|.)", rep, s)


def code_strings(src, comment="#"):
    """(line, text) for every string literal in GDScript or scene text. StringName (&"") and NodePath (^"") literals
    are names, not text, and are skipped; comments (from `comment` to the end of the line) are skipped."""
    out = []
    i, line, n = 0, 1, len(src)
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
        elif comment and c == comment:
            while i < n and src[i] != "\n":
                i += 1
        elif c in "\"'":
            prefix = src[i - 1] if i > 0 else ""
            q = c * 3 if src[i:i + 3] == c * 3 else c
            start_line = line
            j = i + len(q)
            buf = []
            while j < n and src[j:j + len(q)] != q:
                if src[j] == "\\" and j + 1 < n:
                    buf.append(src[j:j + 2])
                    if src[j + 1] == "\n":
                        line += 1
                    j += 2
                    continue
                if src[j] == "\n":
                    line += 1
                    if len(q) == 1:
                        break  # an unclosed one-line string: stop at the line's end
                buf.append(src[j])
                j += 1
            i = j + len(q)
            if prefix not in ("&", "^"):
                raw = "".join(buf)
                out.append((start_line, raw if prefix == "r" else _unescape(raw)))
        else:
            i += 1
    return out


def file_items(path):
    ext = os.path.splitext(path)[1]
    with open(path, encoding="utf-8") as f:
        src = f.read()
    if ext == ".json":
        try:
            data = json.loads(src)
        except ValueError as e:
            return [], str(e)
        return list(json_items(data)), None
    comment = "#" if ext == ".gd" else ";"
    items = []
    for ln, s in code_strings(src, comment if ext == ".gd" else None):
        items.append(Item(s, str(ln)))
    return items, None


# --- walking paths -------------------------------------------------------------------------------------------------

def rel(path):
    p = os.path.relpath(os.path.abspath(path), REPO)
    return p.replace(os.sep, "/")


def is_legacy(relpath):
    return any(relpath == p or relpath.startswith(p + "/") for p in LEGACY)


def walk(paths):
    for p in paths:
        if os.path.isdir(p):
            for root, dirs, files in os.walk(p):
                dirs[:] = sorted(d for d in dirs if not d.startswith("."))
                for name in sorted(files):
                    if name.endswith(EXTS):
                        yield os.path.join(root, name)
        elif p.endswith(EXTS) and os.path.isfile(p):
            yield p


def scan(paths, terms, report_only=False):
    """(hits, files scanned, parse errors)."""
    hits, errors, count = [], [], 0
    for path in walk(paths):
        count += 1
        r = rel(path)
        strict = not report_only and not is_legacy(r)
        items, err = file_items(path)
        if err:
            errors.append((r, err))
            if strict:
                hits.append(Hit(r, "parse", "parse", "json", err, True))
            continue
        for it in items:
            for lst, term, snip in check_item(it, terms):
                hits.append(Hit(r, it.where, lst, term, snip, strict))
    return hits, count, errors


def summary(hits):
    lines = []
    for strict in (True, False):
        group = [h for h in hits if h.strict == strict]
        if not group:
            continue
        counts = {}
        for h in group:
            counts[h.list] = counts.get(h.list, 0) + 1
        lines.append("%s: %d hits (%s)" % ("failing" if strict else "report only", len(group),
                     ", ".join("%s %d" % (k, counts[k]) for k in sorted(counts))))
    return lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("paths", nargs="*", default=[os.path.join(REPO, "data", "thuyvan")])
    ap.add_argument("--terms", default=TERMS_PATH)
    ap.add_argument("--report-only", action="store_true", help="never fail, only report")
    ap.add_argument("--out", help="also write the report to this file")
    args = ap.parse_args(argv)
    terms = load_terms(args.terms)
    hits, count, _ = scan(args.paths, terms, args.report_only)
    out = [h.line() for h in hits]
    out += summary(hits)
    failing = [h for h in hits if h.strict]
    out.append("TEXT GUARD %s (%d files, %d failing, %d reported)" % (
        "FAILED" if failing else "PASSED", count, len(failing), len(hits) - len(failing)))
    text = "\n".join(out)
    print(text)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
    return 1 if failing else 0


if __name__ == "__main__":
    sys.exit(main())
