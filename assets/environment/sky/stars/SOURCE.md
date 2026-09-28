# Star catalogue

`ybsc5.gz`: the Yale Bright Star Catalogue, 5th revised edition (Hoffleit & Warren 1991; NASA Astronomical Data
Center / Harvard-Smithsonian Center for Astrophysics), downloaded 2026-09-25 with the owner's approval from
http://tdc-www.harvard.edu/catalogs/ybsc5.gz (573,921 bytes). 9,110 stars to V ~ 6.5.

`star_map.png` is baked from it by `tools/environment/sky/bake_star_map.py` (equirectangular RA / Dec, J2000;
sqrt-encoded flux, B-V colour). The sky shader (`shaders/sky/frontier_sky_dynamic.gdshader`) samples it through
the WorldClock's celestial basis, so the constellations and the pole are true for the Mohawk Valley, 1765.
