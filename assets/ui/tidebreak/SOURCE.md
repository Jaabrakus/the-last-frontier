# Tidebreak menu stills

These three 1280 × 720 screenshots are unchanged copies of the game rendered for the arena palette comparison in `artifacts/tidebreak_planetes_palette/after/`. `manifest.json` there records the stopped clock, camera, fighter positions and lighting. They are in-game screenshots, not downloaded series images.

- `deck.png`: elevated arena view.
- `behind.png`: view from behind the fighter.
- `sky.png`: lower arena and sky view.

The menu captions are in `scripts/ui/menu/menu_paintings.gd`. Legacy river screenshots and their evidence remain under `assets/ui/pictures/`; they no longer appear in the demo rotation.

`tools/menu/make_splash.gd` renders `assets/ui/tidebreak_splash.png` from the deck screenshot, native type and vector decoration. It uses the existing system serif fallback stack and does not bundle a font. The previous `assets/ui/splash.png` is retained as historical artwork.
