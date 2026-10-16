# Store art (Creator Hub)

`store/icon.png` (512x512) and `store/thumb-*.jpg` (1920x1080) are rendered from the real built world:
CI's world dump (artifact "world") + the Lune tunnel (`tools/view/tunnel.luau`) + actors
(`tools/view/actors.py`, scenes in `tools/view/marketing/actors.json`), rendered with
`tools/view/render.mjs` (views in `tools/view/marketing/views.json`, W=1920 H=1080, icon 1024x1024)
and finished by `tools/view/marketing/compose.py` (logo + captions).

Upload by hand: Creator Hub -> the experience -> Places / Configure -> Icon and Thumbnails.
