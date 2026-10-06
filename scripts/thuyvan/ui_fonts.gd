class_name UiFonts
extends RefCounted
## Thủy Vân's lettering (the owner, 2026-10-05: English text, names kept in their Vietnamese spelling), so every font
## here must write all 134 Vietnamese letters. Three roles: serif for titles and names, sans for the HUD and menus, mono
## for debug lines. Each is the computer's own fonts in order (SystemFont), every macOS name in the lists checked
## complete by tools/fonts/font_cmap_check.py; the tails are the usual Windows and Linux names, unverified. A family
## shipped under assets/fonts/<folder>/ (none yet: free-licence fonts wait for the owner's go-ahead) goes first, with
## the system list behind it. Nothing uses these yet (wiring is Phase 2); tests/thuyvan/test_vietnamese_glyphs.gd
## checks them.

## Left out after the cmap check: Hoefler Text and Menlo (no ơ/ư rows), PT Mono, Andale Mono, Palatino (ớ, ờ).
## Avenir Next's Heavy faces and Helvetica Neue's Thin Italic fall short too; no weight here picks them.
const SERIF := ["Baskerville", "Georgia", "Times New Roman", "Noto Serif", "DejaVu Serif", "Liberation Serif", "serif"]
const SANS := ["Avenir Next", "Helvetica Neue", "Arial", "Segoe UI", "Noto Sans", "DejaVu Sans", "Liberation Sans",
		"sans-serif"]
const MONO := ["Monaco", "Courier New", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"]
## Each role's shipped family folder under assets/fonts (used only when its files are there).
const BUNDLED_DIR := "res://assets/fonts/"
const BUNDLED := {"serif": "notoserif", "sans": "bevietnampro", "mono": ""}
## A static family's file per weight ("<Family>-<Style>.ttf"); a variable one ("[wght]" in its name) takes any weight.
const STYLES := {100: "Thin", 200: "ExtraLight", 300: "Light", 400: "Regular", 500: "Medium", 600: "SemiBold",
		700: "Bold", 800: "ExtraBold", 900: "Black"}
## Extra line spacing per role, in ems, so stacked tone marks (Ể Ỗ Ặ) never touch the line above: the most ink outside
## the line box among the role's macOS fonts (tools/fonts/font_proof.py; Georgia 0.14, Helvetica Neue 0.125, Monaco
## 0.21 at 14-40 px).
const LINE_GAP_EM := {"serif": 0.15, "sans": 0.125, "mono": 0.225}

static var _cache := {}


## Titles, names and headings ("Vạn Thủy, Capital of the Waters").
static func serif(weight := 500, italic := false) -> Font:
	return font("serif", weight, italic)


## The HUD, menus and body text.
static func sans(weight := 500, italic := false) -> Font:
	return font("sans", weight, italic)


## Debug lines and numbers in columns.
static func mono(weight := 400) -> Font:
	return font("mono", weight, false)


## A role's font: the shipped family when there is one (over the system list), else the system list.
static func font(role: String, weight := 500, italic := false) -> Font:
	var key := "%s:%d:%s" % [role, weight, italic]
	if not _cache.has(key):
		var f := bundled(role, weight, italic)
		_cache[key] = f if f else system(role, weight, italic)
	return _cache[key]


## The role's system list alone: the first installed name, then the engine's own font for any glyph it lacks (and the
## platform's fallback while drawing).
static func system(role: String, weight := 500, italic := false) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names(role))
	f.font_weight = weight
	f.font_italic = italic
	f.fallbacks = [ThemeDB.fallback_font]
	return f


## The shipped family's face for a role and weight, over the system list (null when no family ships for the role).
static func bundled(role: String, weight := 500, italic := false) -> Font:
	var folder := String(BUNDLED.get(role, ""))
	if folder.is_empty() or not DirAccess.dir_exists_absolute(BUNDLED_DIR + folder):
		return null
	var dir := BUNDLED_DIR + folder + "/"
	var want := String(STYLES.get(snappedi(clampi(weight, 100, 900), 100), "Regular"))
	if italic:
		want = "Italic" if want == "Regular" else want + "Italic"
	var pick := ""
	var variable := false
	for f: String in ResourceLoader.list_directory(dir):
		if not (f.ends_with(".ttf") or f.ends_with(".otf")):
			continue
		var is_var := f.contains("[")
		if is_var and (f.contains("Italic") == italic) and pick.is_empty():
			pick = f
			variable = true
		elif not is_var and f.get_basename().ends_with("-" + want):
			pick = f
			variable = false
			break
	if pick.is_empty():
		return null
	var file := load(dir + pick) as FontFile
	if file == null:
		return null
	var v := FontVariation.new()
	v.base_font = file
	if variable:
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	v.fallbacks = [system(role, weight, italic)]
	return v


## A role's names in order (serif, sans, mono).
static func names(role: String) -> Array:
	match role:
		"serif":
			return SERIF
		"mono":
			return MONO
	return SANS


## The extra line spacing (px) that keeps a role's tone marks off the line above at a font size.
static func line_gap(role: String, size: int) -> int:
	return ceili(float(LINE_GAP_EM.get(role, 0.15)) * size)


## Drop the cached fonts (a test, or a family added on disk).
static func reset() -> void:
	_cache.clear()
