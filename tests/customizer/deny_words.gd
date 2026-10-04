extends RefCounted
## The deny-list the creator's tests hold player-facing copy to (test_jewellery, test_tattoos, test_slots_patterns):
## tools/character/lib/catalog.py's DENY_TERMS (read from that file, so the catalog build and the tests share one list),
## the research's additions (docs/research/peoples_dress_1750s.md 1.4.7: "negro", "mulatto", "coolie", "oriental",
## "harem") and the creator's own (CREATOR), each matched as a whole word and in any case: "war" flags "war" and "War",
## not "ware", "warm" or "toward"; "pipes?" flags "pipe" and "pipes", not "piped".
##
##   const DenyWords := preload("res://tests/customizer/deny_words.gd")
##   var hits: Array = DenyWords.hits("A brave's war bonnet")       # ["brave", "war bonnet"]
##   DenyWords.hits(text, ["moko", "tatau"])                       # with a test's own words

const CATALOG_PY := "res://tools/character/lib/catalog.py"
## The research's additions (1.4.7).
const RESEARCH := ["negro(?:es)?", "mulattos?", "coolies?", "oriental", "harems?"]
## The creator's own: the words its earlier lists held beside the catalog's.
const CREATOR := ["war", "clans?", "feathers?", "bonnets?"]
## catalog.py's list as it stood on 2026-10-03, used only when that file cannot be read.
const FALLBACK := ["war ?bonnets?", "gustoweh", "kastowa", "false ?faces?", "medicine (?:mask|bundle)s?", "eagles?",
		"wampum", "roach(?:es)?", "pipes?", "pipe[- ]tomahawks?", "scalp\\w*", "war ?paint", "squaws?", "braves?", "papooses?",
		"chiefs?", "savages?", "redskins?", "tribal", "pocahontas", "indian (?:costume|outfit|stockings|princess|maiden)",
		"warrior outfit", "dream ?catchers?"]

static var _catalog_terms: Array = []
static var _res := {}


## catalog.py's DENY_TERMS (its r"..." patterns), or FALLBACK.
static func catalog_terms() -> Array:
	if _catalog_terms.is_empty():
		var src := FileAccess.get_file_as_string(CATALOG_PY) if FileAccess.file_exists(CATALOG_PY) else ""
		var at := src.find("DENY_TERMS = [")
		var end := src.find("]\n", at) if at >= 0 else -1
		if at >= 0 and end > at:
			var re := RegEx.create_from_string("r\"((?:[^\"\\\\]|\\\\.)*)\"")
			for m in re.search_all(src.substr(at, end - at)):
				_catalog_terms.append(m.get_string(1))
		if _catalog_terms.is_empty():
			_catalog_terms = FALLBACK.duplicate()
	return _catalog_terms


## Every pattern: the catalog's, the research's, the creator's and `extra`.
static func terms(extra := []) -> Array:
	return catalog_terms() + RESEARCH + CREATOR + extra


## The deny-listed words in `text` (as written there, lower case), [] when none.
static func hits(text: String, extra := []) -> Array:
	var key := ",".join(PackedStringArray(extra))
	if not _res.has(key):
		_res[key] = RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(PackedStringArray(terms(extra))))
	var out := []
	for m in (_res[key] as RegEx).search_all(text):
		var w := m.get_string().to_lower()
		if not w in out:
			out.append(w)
	return out
