"""Which sun azimuths keep the player at the spawn (0, 0, 6) out of the fort's shadows (spec 3.2).

Ray-marches a box/prism model of the south and west walls, the cabin with its roof, the chimney,
the storehouse and the SE blockhouse (frontier_level.gd dimensions) toward the sun at 19.1 deg
elevation for 27 points on the standing character. Usage: python3 spawn_sun_check.py
"""
import math, numpy as np
def boxes_inside(p):
    x,y,z = p
    B = [((-16,16),(0,4.45),(15.81,16.19)), ((-16.19,-15.81),(0,4.45),(-16,16)),
         ((-11.5,-4.5),(0,3.0),(4.5,9.5)), ((-4.88,-3.98),(2.6,4.2),(7.55,8.45)),
         ((6.5,11.5),(0,2.4),(2,6)), ((13.75,18.25),(0,3.5),(13.75,18.25)), ((13.25,18.75),(3.5,5.7),(13.25,18.75))]
    for (a,b),(c,d),(e,f) in B:
        if a<=x<=b and c<=y<=d and e<=z<=f: return True
    # cabin roof prism (ridge along x at z=7)
    if -11.8<=x<=-4.2 and 4.2<=z<=9.8:
        top = 3.0 + 1.96*(1-abs(z-7)/2.8)
        if 2.9 <= y <= top: return True
    # storehouse roof (ridge along z at x=9)
    if 6.7<=x<=11.3 and 1.2<=z<=6.8:
        top = 2.4 + 1.33*(1-abs(x-9)/2.3)
        if 2.3 <= y <= top: return True
    # SE blockhouse roof
    if 13.25<=x<=18.75 and 13.25<=z<=18.75:
        top = 5.7 + 1.9*(1-abs(x-16)/3.05)
        if 5.6 <= y <= top: return True
    return False
def lit(p, s):
    for t in np.arange(0.05, 60, 0.05):
        q = (p[0]+s[0]*t, p[1]+s[1]*t, p[2]+s[2]*t)
        if q[1] > 8: return True
        if boxes_inside(q): return False
    return True
el = math.radians(19.1)
pts = [(dx, h, 6+dz) for dx in (-0.3,0,0.3) for dz in (-0.3,0,0.3) for h in (0.1,0.9,1.7)]
for az in range(210, 262, 4):
    a = math.radians(az)
    s = (math.sin(a)*math.cos(el), math.sin(el), -math.cos(a)*math.cos(el))
    n = sum(lit(p, s) for p in pts)
    # parade ground patch sunlit fraction in the view area north of spawn
    grid = [(x, 0.05, z) for x in range(-12, 13, 2) for z in range(-12, 7, 2)]
    g = sum(lit(p, s) for p in grid) / len(grid)
    print(f"az {az}: spawn body points lit {n}/{len(pts)}  parade ground (x -12..12, z -12..6) lit {g*100:.0f}%")
