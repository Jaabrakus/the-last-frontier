#!/bin/zsh
# Thủy Vân: R1, the Đá Trắng reach in the painted look (scenes/thuyvan_r1.tscn). Double-click in Finder to play.
# You start at the east head of the rope bridge; F9 stills the river (S0 <-> S1). Esc for the menu (no saving).
# Optional: pass quality=high|medium|low after the command (default medium).
exec zsh "${0:A:h}/play_thuyvan.command" r1 "$@"
