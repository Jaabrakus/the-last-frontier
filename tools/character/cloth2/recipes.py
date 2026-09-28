"""cloth2 recipes shared by several garments."""

from cloth2 import garment as G


def shirt(g, hem=0.60, side_hem=0.69, sleeve_end=0.925, neck=None, dip=0.0, dip_width=0.09, gather=0.008,
          sleeve_ease=(0.006, 0.013), ease=0.0055, slit_top=0.74, collar=True, band_t=0.88, steps=9, flare=0.06,
          tail_gap=0.024, z_full=0.72):
    """A linen shirt or shift: the body and sleeves as one shell, tails from the hips."""
    g.shell(G.TORSO + G.ARMS)
    g.neckline(dip=dip, dip_width=dip_width, **(neck or {})).bottom(0.905)
    g.sleeves(end=sleeve_end, ease=sleeve_ease, gather=gather)
    g.seams()
    g.fit(ease=ease)
    g.tails(hem=hem, side_hem=side_hem, flare=flare, steps=steps, slits=[(84.0, 96.0, slit_top)], gap=tail_gap, z_full=z_full)
    if collar:
        g.collar_zone(1, 0.035)
    g.zone(1, limb=("arm_l", "arm_r"), t_above=band_t if sleeve_end > 0.9 else sleeve_end - 0.05)
    g.uv()
