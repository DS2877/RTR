--!strict
-- How a base and its treadmill LOOK, by level. A fresh plot is a plain brown wooden shack with a
-- creaky wooden treadmill; every few levels they are rebuilt bigger and grander, in new colors:
-- shack -> stone cottage -> white manor -> slate mansion -> navy & gold palace -> royal palace.
-- Only decoration lives here (rebuilt into the models "Palace" / "TreadDecor"); the parts the game
-- logic uses (floor, walls, stage, pedestals, belt, signs...) are only recolored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)

local Palace = {}

local FLOOR = 0.4

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

export type Look = {
	name: string,
	wall: Color3, -- walls, pillars
	dark: Color3, -- stage, path, roof
	trim: Color3, -- caps, bands, fence rails, gable edges
	accent: Color3, -- panels, path tiles, pedestal rings
	neon: boolean, -- glowing tiles / caps / emblem
	wood: boolean, -- plank walls + wooden fence (the shack)
}

-- index = tier (World.PalaceTierLevels says which plot level reaches it)
local LOOKS: { Look } = {
	{
		name = "Shack",
		wall = c(150, 102, 62),
		dark = c(104, 70, 42),
		trim = c(186, 140, 90),
		accent = c(200, 165, 115),
		neon = false,
		wood = true,
	},
	{
		name = "Cottage",
		wall = c(178, 178, 186),
		dark = c(120, 70, 50),
		trim = c(196, 72, 56),
		accent = c(236, 222, 196),
		neon = false,
		wood = false,
	},
	{
		name = "Manor",
		wall = c(242, 240, 236),
		dark = c(60, 92, 170),
		trim = c(80, 124, 214),
		accent = c(120, 200, 255),
		neon = false,
		wood = false,
	},
	{
		name = "Mansion",
		wall = c(66, 74, 96),
		dark = c(38, 42, 58),
		trim = c(214, 220, 232),
		accent = c(80, 220, 255),
		neon = true,
		wood = false,
	},
	{
		name = "Palace",
		wall = c(38, 40, 92),
		dark = c(26, 28, 66),
		trim = c(255, 190, 30),
		accent = c(255, 70, 220),
		neon = true,
		wood = false,
	},
	{
		name = "Royal Palace",
		wall = c(34, 22, 46),
		dark = c(18, 12, 26),
		trim = c(255, 200, 40),
		accent = c(190, 80, 255),
		neon = true,
		wood = false,
	},
}
Palace.Looks = LOOKS

-- The tier reached at `level` given ascending start levels.
function Palace.tier(level: number, starts: { number }): number
	local t = 1
	for i, from in starts do
		if level >= from then
			t = i
		end
	end
	return t
end

local function brick(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	sides: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	if sides then
		p.FrontSurface = Enum.SurfaceType.Studs
		p.BackSurface = Enum.SurfaceType.Studs
		p.LeftSurface = Enum.SurfaceType.Studs
		p.RightSurface = Enum.SurfaceType.Studs
	end
	p.Parent = parent
	return p
end

-- Decoration you can't bump into (keeps every walkway clear, whatever the tier builds).
local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function glow(p: BasePart, on: boolean): BasePart
	if on then
		p.Material = Enum.Material.Neon
	end
	return p
end

-- A stepped (voxel) gable: `steps` blocks shrinking by `inset` each side, an edge block on every
-- step's corners. `cf`: bottom center.
function Palace.gable(
	parent: Instance,
	cf: CFrame,
	width: number,
	steps: number,
	inset: number,
	depth: number,
	fill: Color3,
	edge: Color3
)
	local h = 2.4
	for i = 0, steps - 1 do
		local w = width - i * inset * 2
		if w <= 2 then
			break
		end
		local y = h / 2 + i * h
		brick(parent, "Gable", Vector3.new(w, h, depth), cf * CFrame.new(0, y, 0), fill)
		for _, side in { -1, 1 } do
			brick(
				parent,
				"GableEdge",
				Vector3.new(inset + 0.6, h + 0.2, depth + 0.6),
				cf * CFrame.new(side * (w / 2 - inset / 2 + 0.3), y, 0),
				edge
			)
		end
	end
end

local function tower(parent: Instance, cf: CFrame, height: number, size: number, look: Look)
	brick(
		parent,
		"Tower",
		Vector3.new(size, height, size),
		cf * CFrame.new(0, height / 2, 0),
		look.wall,
		true
	)
	for y = 6, height - 2, 7 do
		brick(
			parent,
			"TowerBand",
			Vector3.new(size + 0.6, 1, size + 0.6),
			cf * CFrame.new(0, y, 0),
			look.trim
		)
	end
	local y = height
	for i = 0, 3 do
		local w = size + 1 - i * (size / 3)
		if w < 1 then
			break
		end
		brick(
			parent,
			"Spire",
			Vector3.new(w, 1.6, w),
			cf * CFrame.new(0, y + 0.8, 0),
			if i % 2 == 0 then look.trim else look.dark
		)
		y += 1.6
	end
	glow(
		brick(parent, "TowerCap", Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0, y + 0.7, 0), look.accent),
		look.neon
	)
end

-- A fence from `a` to `b` (base-local x / depth): posts every ~10 studs + rails. Wooden stakes for
-- the shack, stone posts for the cottage, capped posts with plaques from the manor up.
local function fence(
	parent: Instance,
	at: (number, number, number) -> CFrame,
	a: Vector2,
	b: Vector2,
	t: number,
	look: Look
)
	local H = World.WallHeight
	local d = b - a
	local len = d.Magnitude
	local n = math.max(1, math.round(len / 10))
	local angle = math.atan2(d.X, -d.Y) -- local Z runs along the fence
	for i = 0, n do
		local p = a + d * (i / n)
		local cf = at(p.X, 0, p.Y) * CFrame.Angles(0, angle, 0)
		if look.wood then
			deco(
				brick(
					parent,
					"Stake",
					Vector3.new(1, H - 0.5, 1),
					cf * CFrame.new(0, (H - 0.5) / 2, 0),
					look.dark
				)
			)
		else
			local size = if t >= 3 then 1.8 else 1.5
			deco(
				brick(
					parent,
					"FencePost",
					Vector3.new(size, H, size),
					cf * CFrame.new(0, H / 2, 0),
					look.wall,
					true
				)
			)
			deco(
				brick(
					parent,
					"FenceCap",
					Vector3.new(size + 0.6, 0.8, size + 0.6),
					cf * CFrame.new(0, H + 0.4, 0),
					look.trim
				)
			)
			if t >= 3 then
				deco(
					brick(
						parent,
						"FenceSpike",
						Vector3.new(1, 1, 1),
						cf * CFrame.new(0, H + 1.3, 0),
						look.trim
					)
				)
				for _, x in { -1, 1 } do
					glow(
						deco(
							brick(
								parent,
								"FencePlaque",
								Vector3.new(0.2, 0.9, 0.9),
								cf * CFrame.new(x * 0.95, H * 0.55, 0) * CFrame.Angles(math.rad(45), 0, 0),
								look.accent
							)
						),
						look.neon
					)
				end
			end
		end
	end
	local mid = (a + b) / 2
	local rails = if look.wood then { H * 0.5 } else { H * 0.35, H * 0.75 }
	for _, y in rails do
		deco(
			brick(
				parent,
				"FenceRail",
				Vector3.new(if look.wood then 0.5 else 0.7, if look.wood then 0.9 else 0.7, len),
				at(mid.X, y, mid.Y) * CFrame.Angles(0, angle, 0),
				look.trim
			)
		)
	end
end

local function recolor(model: Instance, name: string, color: Color3, neon: boolean?)
	for _, p in model:GetChildren() do
		if p.Name == name and p:IsA("BasePart") then
			p.Color = color
			if neon ~= nil then
				p.Material = if neon then Enum.Material.Neon else Enum.Material.Plastic
			end
		end
	end
end

-- Color of an unlocked pedestal at plot level `level`.
function Palace.pedestalColor(level: number): Color3
	return LOOKS[Palace.tier(level, World.PalaceTierLevels)].dark:Lerp(Color3.new(1, 1, 1), 0.1)
end

-- Rebuilds the base's looks for plot level `level`. Returns true when the tier changed.
function Palace.dressBase(base: any, level: number): boolean
	local t = Palace.tier(level, World.PalaceTierLevels)
	local model: Model = base.model
	if model:GetAttribute("PalaceTier") == t and model:FindFirstChild("Palace") then
		return false
	end
	model:SetAttribute("PalaceTier", t)
	model:SetAttribute("PalaceName", LOOKS[t].name)
	local old = model:FindFirstChild("Palace")
	if old then
		old:Destroy()
	end
	local look = LOOKS[t]
	local f = Instance.new("Model")
	f.Name = "Palace"
	local origin: CFrame = base.origin
	local W, D = World.BaseWidth, World.BaseDepth
	local SH = World.StageHeight
	local stageTop = FLOOR + SH
	local function at(lx: number, ly: number, depth: number): CFrame
		return origin * CFrame.new(lx, ly, -depth)
	end

	-- the parts the game uses: recolored
	recolor(model, "Path", look.dark)
	recolor(model, "Stage", look.dark)
	recolor(model, "Step1", look.wall)
	recolor(model, "Step2", look.wall)
	recolor(model, "StageLip", look.trim)
	recolor(model, "TileFrame", look.trim)
	recolor(model, "Tile", look.accent, look.neon)
	recolor(model, "Sign", look.dark)
	recolor(model, "SignTrim", look.trim)
	for _, ped in base.pedestals do
		if ped.Material ~= Enum.Material.ForceField then -- locked pedestals stay ghostly
			ped.Color = Palace.pedestalColor(level)
		end
	end
	for _, ring in base.rings or {} do
		ring.Color = look.accent
	end

	-- fence around the yard (the entrance stays open)
	local ex = World.EntranceWidth / 2 + 3
	fence(f, at, Vector2.new(-W / 2, 0), Vector2.new(-ex, 0), t, look)
	fence(f, at, Vector2.new(ex, 0), Vector2.new(W / 2, 0), t, look)
	fence(f, at, Vector2.new(-W / 2, 0), Vector2.new(-W / 2, D - 2), t, look)
	fence(f, at, Vector2.new(W / 2, 0), Vector2.new(W / 2, D - 2), t, look)

	-- the back wall: grows with the tier (the shack is a low plank wall, the royal palace towers)
	local wallH = 10 + t * 3
	local back = deco(brick(f, "BackWall", Vector3.new(W, wallH, 2), at(0, wallH / 2, D), look.wall, true))
	if look.wood then
		-- vertical planks in two shades
		for lx = -W / 2 + 3, W / 2 - 3, 6 do
			deco(
				brick(
					f,
					"Plank",
					Vector3.new(2.6, wallH - 1, 0.4),
					at(lx, (wallH - 1) / 2, D - 1.2),
					look.dark
				)
			)
		end
		back.FrontSurface = Enum.SurfaceType.Smooth
	end
	-- pillars: none on the shack, 2 on the cottage ... 6 on the palaces (banded from the mansion up)
	local pillarSets = { {}, { -30, 30 }, { -36, -12, 12, 36 }, { -45, -27, -9, 9, 27, 45 } }
	local pillars = pillarSets[math.min(t, 4)]
	for _, lx in pillars do
		deco(
			brick(
				f,
				"Pillar",
				Vector3.new(3.2, wallH + 2, 3.2),
				at(lx, (wallH + 2) / 2, D - 2.4),
				look.wall:Lerp(look.dark, 0.25),
				true
			)
		)
		if t >= 4 then
			for y = 4, wallH, 6 do
				deco(brick(f, "PillarBand", Vector3.new(3.8, 0.9, 3.8), at(lx, y, D - 2.4), look.trim))
			end
		end
		deco(brick(f, "PillarCap", Vector3.new(4.2, 1.2, 4.2), at(lx, wallH + 2.6, D - 2.4), look.trim))
	end
	-- panels with a diamond from the manor up
	if t >= 3 then
		local panelH = math.min(13, wallH - 6)
		for _, lx in { -36, -18, 0, 18, 36 } do
			if t >= 4 or math.abs(lx) < 30 then
				deco(
					brick(
						f,
						"Panel",
						Vector3.new(12, panelH, 0.6),
						at(lx, stageTop + panelH / 2 + 1, D - 1.3),
						look.accent:Lerp(look.dark, 0.35)
					)
				)
				glow(
					deco(
						brick(
							f,
							"Diamond",
							Vector3.new(3.6, 3.6, 0.4),
							at(lx, stageTop + panelH / 2 + 1, D - 1.7) * CFrame.Angles(0, 0, math.rad(45)),
							look.trim
						)
					),
					t >= 5
				)
			end
		end
	end
	-- roof: a wooden triangle on the shack, a stepped gable on everything else (taller per tier)
	deco(brick(f, "RoofTrim", Vector3.new(W + 2, 1.4, 3), at(0, wallH + 0.7, D - 1), look.trim))
	Palace.gable(
		f,
		at(0, wallH + 1.4, D - 1),
		W - 10,
		2 + t,
		if look.wood then 9 else 5,
		2.6,
		look.dark,
		look.trim
	)
	if t >= 5 then
		glow(
			deco(
				brick(
					f,
					"Emblem",
					Vector3.new(5, 5, 0.6),
					at(0, wallH + 9, D - 2.6) * CFrame.Angles(0, 0, math.rad(45)),
					look.accent
				)
			),
			true
		)
	end
	-- towers: back corners from the mansion, front corners too on the palaces
	if t >= 4 then
		for _, lx in { -W / 2, W / 2 } do
			tower(f, at(lx, 0, D), wallH + 6 + (t - 4) * 4, 6, look)
			if t >= 5 then
				tower(f, at(lx, 0, 0), World.WallHeight + 6, 4, look)
			end
		end
	elseif not look.wood then
		for _, lx in { -W / 2, W / 2 } do
			deco(
				brick(
					f,
					"CornerPost",
					Vector3.new(3, World.WallHeight + 3, 3),
					at(lx, (World.WallHeight + 3) / 2, 0),
					look.wall,
					true
				)
			)
		end
	end
	-- entrance arch posts (the name sign itself is a game part)
	local archX = World.EntranceWidth / 2 + 1.5
	for _, lx in { -archX, archX } do
		deco(
			brick(
				f,
				"ArchPost",
				Vector3.new(3, 13, 3),
				at(lx, 6.5, 0),
				if look.wood then look.dark else look.wall,
				true
			)
		)
		if not look.wood then
			for y = 3, 12, 4.5 do
				deco(brick(f, "ArchBand", Vector3.new(3.6, 0.8, 3.6), at(lx, y, 0), look.trim))
			end
		end
		glow(
			deco(
				brick(
					f,
					"ArchCap",
					Vector3.new(3.6, 1.2, 3.6),
					at(lx, 13.6, 0),
					if look.neon then base.color else look.trim
				)
			),
			look.neon
		)
	end
	f.Parent = model
	return true
end

-- Treadmill looks by treadmill level: wooden -> metal -> blue arch -> neon -> winged -> golden.
Palace.TreadNames = { "Wooden", "Metal", "Turbo", "Neon", "Winged", "Golden" }
local TREADS = {
	{ belt = c(110, 110, 115), frame = c(150, 102, 62), rail = c(110, 75, 45), stripe = c(150, 150, 155) },
	{ belt = c(45, 45, 50), frame = c(160, 165, 175), rail = c(110, 115, 125), stripe = c(200, 200, 210) },
	{ belt = c(40, 50, 90), frame = c(235, 240, 255), rail = c(70, 110, 255), stripe = c(110, 170, 255) },
	{ belt = c(50, 30, 100), frame = c(235, 240, 255), rail = c(110, 80, 255), stripe = c(170, 90, 255) },
	{ belt = c(60, 30, 120), frame = c(235, 240, 255), rail = c(70, 110, 255), stripe = c(200, 110, 255) },
	{ belt = c(40, 30, 10), frame = c(255, 200, 40), rail = c(255, 230, 120), stripe = c(255, 210, 60) },
}

-- Rebuilds the treadmill's looks for treadmill level `level`. Returns true when the tier changed.
function Palace.dressTreadmill(base: any, level: number): boolean
	local t = Palace.tier(level, World.TreadTierLevels)
	local model: Model = base.model
	if model:GetAttribute("TreadTier") == t and model:FindFirstChild("TreadDecor") then
		return false
	end
	model:SetAttribute("TreadTier", t)
	local old = model:FindFirstChild("TreadDecor")
	if old then
		old:Destroy()
	end
	local look = TREADS[t]
	local belt: BasePart = base.belt
	belt.Color = look.belt
	belt:SetAttribute("BeltColor", look.stripe) -- the client scrolls stripes in this color
	local f = Instance.new("Model")
	f.Name = "TreadDecor"
	local L = belt.Size.Z
	-- belt-local: +Z runs toward the entrance (the belt shares the base's rotation), y = belt top
	local top = belt.CFrame * CFrame.new(0, belt.Size.Y / 2, 0)
	local farEnd = -L / 2 - 0.5 -- the end away from the entrance, where the screen stands
	local function at(x: number, y: number, z: number): CFrame
		return top * CFrame.new(x, y, z)
	end
	deco(brick(f, "TreadBase", Vector3.new(12, 0.6, L + 3), at(0, -0.5, 0), look.frame))
	for _, side in { -1, 1 } do
		deco(brick(f, "Rail", Vector3.new(1.4, 1.4 + t * 0.2, L + 2), at(side * 5.2, 0.6, 0), look.rail))
		if t >= 4 then
			glow(
				deco(brick(f, "RailGlow", Vector3.new(0.3, 0.3, L + 1), at(side * 4.4, 1.3, 0), look.stripe)),
				true
			)
		end
	end
	local screen = model:FindFirstChild("TreadScreen") :: BasePart?
	if t <= 2 then
		-- two posts hold the screen board
		for _, side in { -1, 1 } do
			deco(brick(f, "TreadPost", Vector3.new(0.8, 9.5, 0.8), at(side * 4.2, 4.75, farEnd), look.rail))
		end
	else
		-- the arch over the far end (wider + taller with the tier) and, from tier 5, the wings
		local archH = 10 + (t - 3) * 1.5
		for _, side in { -1, 1 } do
			local ax = side * 5.4
			deco(
				brick(
					f,
					"TreadArch",
					Vector3.new(1.8, archH, 1.8),
					at(ax, archH / 2, farEnd),
					look.rail,
					true
				)
			)
			if t >= 5 then
				local count = if t >= 6 then 6 else 4
				for i = 1, count do
					local wing = deco(
						brick(
							f,
							"Wing",
							Vector3.new(1, 5 + i, 1),
							at(ax + side * (1.2 + i * 0.9), 4.6 + i * 0.8, farEnd)
								* CFrame.Angles(0, 0, math.rad(-side * (20 + i * 10))),
							if i % 2 == 0 then look.stripe else look.rail
						)
					)
					wing.CastShadow = false
				end
			end
		end
		deco(brick(f, "TreadArchTop", Vector3.new(12.6, 1.6, 2), at(0, archH + 0.8, farEnd), look.stripe))
	end
	if t >= 6 then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(look.stripe)
		sparkle.Size = NumberSequence.new(0.5, 0)
		sparkle.Rate = 12
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(1, 3)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.LightEmission = 1
		sparkle.Parent = f:FindFirstChild("TreadBase") :: BasePart
	end
	if screen then
		screen.Color = if t <= 1 then look.frame else c(30, 20, 60)
	end
	f.Parent = model
	return true
end

return Palace
