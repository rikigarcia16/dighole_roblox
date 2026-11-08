"""Gameplay video for the Roblox experience page (Videos tab). Rules followed: real current gameplay,
interface allowed, NO promotional text, NO voice-over, instrumental music only (original, no lyrics).
Note: some shots use a scripted camera (the game's own scene, slowed down while recording); review
them against Roblox's video rules before uploading (see MARKETING_ASSETS_README.md)."""
from video import *

SIZE = (1920, 1080)
lay = lambda f=0.5, z=1.0, fy=0.5: (lambda im: land(im, (f, fy), z))
segs = [
    Seg("dig_surface", 0.5, 5.5, lay(0.5), fade_in=0.5),
    Seg("surface_hero", 1.0, 3.5, lay(0.52)),
    Seg("sell_ui", 1.2, 4.5, lay(0.5)),
    Seg("showcase_ui", 1.6, 3.5, lay(0.45)),
    Seg("descent_b", 0.0, 5.0, lay(0.5), speed=1.6),
    Seg("mines_action", 5.0, 3.0, lay(0.45)),
    Seg("crystal_action", 3.0, 3.0, lay(0.55)),
    Seg("abyss_action", 0.0, 2.2, lay(0.5)),
    Seg("legendary_ui", 2.8, 4.2, lay(0.5), fade_out=0.8),
]
st = np.cumsum([0] + [s.dur for s in segs])
cues = [(0.8 + k * 0.62, "sfx_dig_hit.wav", 0.35) for k in range(8)] + [(st[2] + 0.9 + k * 0.2, "sfx_coin.wav", 0.4) for k in range(5)] + \
       [(st[3] + 0.6, "sfx_legendary_shimmer.wav", 0.5), (st[4] - 0.1, "sfx_whoosh_down.wav", 0.7), (st[8] + 1.1, "sfx_legendary_shimmer.wav", 0.8)]
out = os.path.join(ROOT, "09_OFFICIAL_TRAILER", "THNE_video_pagina_roblox_gameplay_1920x1080.mp4")
render(segs, [], out, SIZE, cues, "music_trailer_adventure_112bpm.wav", 0.6, 4.3)
