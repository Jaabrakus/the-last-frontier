# The broadcast menus' art: where it comes from

All of it is our own, made on 2026-10-10. No third-party image, icon, font or shader was used for these files. (The type is
Barlow, in `assets/fonts/barlow`, with its own SOURCE.md and licence.)

## lobby_fire.jpg, lobby_earth.jpg, lobby_water.jpg, lobby_air.jpg (1920 x 1080)

The backdrop plate of the main menu's lobby, one per element: a still of the game's own ring scene (`scenes/ring.tscn`) at noon
with nobody on the deck, taken from the lobby camera (`FighterWorld.LOBBY_CAM`, `LOBBY_AT`, `LOBBY_FOV`) with a long lens's far
blur. The gate and banners behind show your end's element (and the opponent's at the far end). Each was drawn at 3840 x 2160
and scaled down (Lanczos), then saved as a JPEG (quality 0.92). The live fighter is drawn over the plate by `FighterWorld`, from the same
camera, so that the figure stands on the plate's deck. The plates are made by `tools/ui_audit/lobby_backdrops.gd` (run it
through `tools/loop/godot_run.sh`, in a window); nothing is retouched by hand.

## blur.gdshader

`BroadcastUI.backdrop_blur`: what is drawn under a screen (the lobby behind the match setup, the ring behind the Esc menu and
the match-end board) softened by the screen texture's own mip levels and drawn toward a navy tint, more at the left where the
rundown stands. Written for this project; it takes no code from elsewhere.
