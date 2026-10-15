# tools/view – look at the prison without Roblox

CI's smoke test dumps every part of the built world (`world.txt`, artifact "world").
`render.mjs` loads it into three.js in headless Chromium and writes PNG screenshots of named views
(cell, corridor, Common Room, Yard, overview...). Lighting/materials are approximations: it is for
layout, proportions, colors and composition, not exact Roblox shading.

    cd <scratch dir with three + playwright installed>
    node /path/to/RTR/tools/view/render.mjs world.txt out/ [viewName...]
