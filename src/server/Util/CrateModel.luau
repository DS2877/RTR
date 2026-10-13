--!strict
-- Blocky treasure chests (the loot in the rich people's zones): one look per rarity, from a plain
-- wooden crate to a burning gold chest. PrimaryPart is "Core". What is inside stays a secret until
-- the appraiser opens it at your base.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)

local CrateModel = {}

type Look = { body: Color3, lid: Color3, band: Color3, lock: Color3, neon: boolean }

local LOOKS: { [string]: Look } = {
	Common = {
		body = Color3.fromRGB(176, 120, 70),
		lid = Color3.fromRGB(150, 98, 56),
		band = Color3.fromRGB(96, 64, 40),
		lock = Color3.fromRGB(200, 200, 205),
		neon = false,
	},
	Uncommon = {
		body = Color3.fromRGB(150, 104, 62),
		lid = Color3.fromRGB(70, 170, 80),
		band = Color3.fromRGB(50, 130, 60),
		lock = Color3.fromRGB(230, 230, 235),
		neon = false,
	},
	Rare = {
		body = Color3.fromRGB(44, 70, 140),
		lid = Color3.fromRGB(60, 110, 210),
		band = Color3.fromRGB(205, 215, 230),
		lock = Color3.fromRGB(255, 255, 255),
		neon = false,
	},
	Epic = {
		body = Color3.fromRGB(70, 36, 110),
		lid = Color3.fromRGB(150, 70, 230),
		band = Color3.fromRGB(255, 196, 40),
		lock = Color3.fromRGB(255, 220, 90),
		neon = false,
	},
	Legendary = {
		body = Color3.fromRGB(255, 190, 40),
		lid = Color3.fromRGB(255, 214, 80),
		band = Color3.fromRGB(40, 36, 60),
		lock = Color3.fromRGB(255, 80, 60),
		neon = false,
	},
	Mythic = {
		body = Color3.fromRGB(30, 22, 40),
		lid = Color3.fromRGB(255, 70, 160),
		band = Color3.fromRGB(255, 120, 200),
		lock = Color3.fromRGB(120, 255, 255),
		neon = true,
	},
}

-- Each zone's crates look their own (a wooden box in the suburbs, a steel safe with a wheel in the
-- bank vault, a gold-lidded chest on the island...). The rarity shows in the straps/trim color
-- and the glow; Mythic lids glow.
type Theme = { body: Color3, lid: Color3, emblem: string, mark: Color3 }
local THEMES: { [string]: Theme } = {
	Suburbs = {
		body = Color3.fromRGB(170, 116, 68),
		lid = Color3.fromRGB(146, 96, 54),
		emblem = "plank",
		mark = Color3.fromRGB(110, 72, 42),
	},
	PoolVillas = {
		body = Color3.fromRGB(245, 245, 250),
		lid = Color3.fromRGB(40, 200, 210),
		emblem = "star",
		mark = Color3.fromRGB(40, 200, 210),
	},
	Mansion = {
		body = Color3.fromRGB(110, 60, 36),
		lid = Color3.fromRGB(130, 74, 44),
		emblem = "column",
		mark = Color3.fromRGB(255, 200, 60),
	},
	BankVault = {
		body = Color3.fromRGB(150, 156, 166),
		lid = Color3.fromRGB(120, 126, 136),
		emblem = "wheel",
		mark = Color3.fromRGB(70, 255, 120),
	},
	YachtHarbor = {
		body = Color3.fromRGB(30, 50, 110),
		lid = Color3.fromRGB(250, 250, 255),
		emblem = "wheel",
		mark = Color3.fromRGB(255, 200, 40),
	},
	Casino = {
		body = Color3.fromRGB(30, 20, 26),
		lid = Color3.fromRGB(170, 20, 35),
		emblem = "gem",
		mark = Color3.fromRGB(255, 40, 70),
	},
	PrivateIsland = {
		body = Color3.fromRGB(160, 110, 60),
		lid = Color3.fromRGB(255, 200, 40),
		emblem = "skull",
		mark = Color3.fromRGB(245, 245, 240),
	},
	SpaceVault = {
		body = Color3.fromRGB(40, 22, 70),
		lid = Color3.fromRGB(70, 40, 120),
		emblem = "coin",
		mark = Color3.fromRGB(190, 110, 255),
	},
}

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs -- LEGO look like the rest of the world
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = true
	p.Parent = model
	return p
end

export type Options = {
	scale: number?,
	title: string?, -- e.g. "Museum Crate" (rarity is shown above it); nil = no label
	theme: string?, -- the rich person's id: their own crate design (else the plain rarity look)
}

-- Built around the origin, bottom at y = 0 (scale 1 = about 3.6 studs wide).
function CrateModel.build(rarity: string, options: Options?): Model
	local look = LOOKS[rarity] or LOOKS.Common
	local theme = options and options.theme and THEMES[options.theme]
	if theme then
		local tc = (Rarity.Tiers[rarity] or Rarity.Tiers.Common).color
		look = {
			body = theme.body,
			lid = theme.lid,
			band = if rarity == "Common" then theme.mark else Color3.fromRGB(tc[1], tc[2], tc[3]),
			lock = look.lock,
			neon = look.neon,
		}
	end
	local tier = Rarity.Tiers[rarity] or Rarity.Tiers.Common
	local model = Instance.new("Model")
	model.Name = "Crate_" .. rarity
	model:SetAttribute("Rarity", rarity)

	local W, H, D = 3.6, 2.2, 2.6
	part(model, "Body", Vector3.new(W, H, D), CFrame.new(0, H / 2, 0), look.body)
	local lid = part(model, "Lid", Vector3.new(W + 0.3, 0.9, D + 0.3), CFrame.new(0, H + 0.45, 0), look.lid)
	if look.neon then
		lid.Material = Enum.Material.Neon
	end
	-- two straps over the lid and down the front/back
	for _, x in { -W / 3, W / 3 } do
		part(model, "Band", Vector3.new(0.4, H + 1.1, D + 0.4), CFrame.new(x, (H + 1.1) / 2, 0), look.band)
	end
	-- trim along the bottom + corner posts
	part(model, "Trim", Vector3.new(W + 0.2, 0.3, D + 0.2), CFrame.new(0, 0.15, 0), look.band)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(
				model,
				"Corner",
				Vector3.new(0.35, H, 0.35),
				CFrame.new(x * (W / 2 - 0.05), H / 2, z * (D / 2 - 0.05)),
				look.band
			)
		end
	end
	local lock =
		part(model, "Lock", Vector3.new(0.8, 0.9, 0.3), CFrame.new(0, H - 0.1, -D / 2 - 0.15), look.lock)
	lock.TopSurface = Enum.SurfaceType.Smooth

	-- the rich person's emblem on the front (below the lock)
	if theme then
		local front = -D / 2 - 0.2
		local m = theme.mark
		if theme.emblem == "gem" then
			part(
				model,
				"Emblem",
				Vector3.new(0.9, 0.9, 0.2),
				CFrame.new(0, H * 0.4, front) * CFrame.Angles(0, 0, math.rad(45)),
				m
			).Material =
				Enum.Material.Neon
		elseif theme.emblem == "pickaxe" then
			part(
				model,
				"Emblem",
				Vector3.new(0.25, 1.5, 0.2),
				CFrame.new(0, H * 0.4, front) * CFrame.Angles(0, 0, math.rad(-35)),
				Color3.fromRGB(140, 100, 60)
			)
			part(
				model,
				"EmblemHead",
				Vector3.new(1.4, 0.3, 0.2),
				CFrame.new(0.3, H * 0.62, front) * CFrame.Angles(0, 0, math.rad(-35)),
				m
			)
		elseif theme.emblem == "wheel" then
			local w = part(
				model,
				"Emblem",
				Vector3.new(0.2, 1.3, 1.3),
				CFrame.new(0, H * 0.42, front) * CFrame.Angles(0, math.rad(90), 0),
				m
			)
			w.Shape = Enum.PartType.Cylinder
		elseif theme.emblem == "star" then
			for _, a in { 0, 45 } do
				part(
					model,
					"Emblem",
					Vector3.new(0.9, 0.9, 0.2),
					CFrame.new(0, H * 0.42, front) * CFrame.Angles(0, 0, math.rad(a)),
					m
				)
			end
		elseif theme.emblem == "skull" then
			part(model, "Emblem", Vector3.new(0.9, 0.8, 0.2), CFrame.new(0, H * 0.45, front), m)
			for _, x in { -0.2, 0.2 } do
				part(
					model,
					"EmblemEye",
					Vector3.new(0.2, 0.2, 0.1),
					CFrame.new(x, H * 0.48, front - 0.12),
					Color3.new(0, 0, 0)
				)
			end
		elseif theme.emblem == "column" then
			part(model, "Emblem", Vector3.new(0.4, 1.1, 0.2), CFrame.new(0, H * 0.4, front), m)
			part(model, "EmblemCap", Vector3.new(0.9, 0.2, 0.2), CFrame.new(0, H * 0.4 + 0.6, front), m)
		elseif theme.emblem == "coin" then
			local c = part(
				model,
				"Emblem",
				Vector3.new(0.2, 1.1, 1.1),
				CFrame.new(0, H * 0.42, front) * CFrame.Angles(0, math.rad(90), 0),
				m
			)
			c.Shape = Enum.PartType.Cylinder
		else
			part(model, "Emblem", Vector3.new(W - 0.6, 0.3, 0.15), CFrame.new(0, H * 0.35, front + 0.05), m)
		end
	end

	local core = part(model, "Core", Vector3.new(1, 1, 1), CFrame.new(0, H / 2, 0), Color3.new(1, 1, 1))
	core.Transparency = 1
	model.PrimaryPart = core

	if tier.glow then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(tier.color[1], tier.color[2], tier.color[3])
		light.Brightness = 2
		light.Range = 10
		light.Parent = core
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(light.Color)
		sparkles.Size = NumberSequence.new(0.5, 0)
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Rate = if rarity == "Mythic" then 25 else 10
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 1
		sparkles.Parent = core
	end
	if rarity == "Legendary" or rarity == "Mythic" then
		local fire = Instance.new("ParticleEmitter")
		fire.Name = "Aura"
		fire.Texture = "rbxasset://textures/particles/fire_main.dds"
		fire.Color = ColorSequence.new(
			Color3.fromRGB(tier.color[1], tier.color[2], tier.color[3]),
			Color3.new(1, 1, 1)
		)
		fire.LightEmission = 1
		fire.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0) })
		fire.Transparency = NumberSequence.new(0.25, 1)
		fire.Lifetime = NumberRange.new(0.5, 0.9)
		fire.Speed = NumberRange.new(2, 4)
		fire.Rate = if rarity == "Mythic" then 36 else 20
		fire.SpreadAngle = Vector2.new(30, 30)
		fire.Parent = core
	end

	local opts = options or {}
	if opts.title then
		-- rarity (in its color) over the crate's name, sized in studs so it shrinks with distance
		local bb = Instance.new("BillboardGui")
		bb.Name = "Label"
		bb.Size = UDim2.new(4.5, 0, 1.2, 0)
		bb.StudsOffset = Vector3.new(0, 3.4, 0)
		bb.MaxDistance = 28 -- only up close: a pile of crates must not become a wall of text
		bb.LightInfluence = 0
		bb.Adornee = core
		bb.Parent = core
		for i, line in
			{
				{ rarity, Color3.fromRGB(tier.color[1], tier.color[2], tier.color[3]) },
				{ opts.title, Color3.new(1, 1, 1) },
			}
		do
			local t = Instance.new("TextLabel")
			t.Name = if i == 1 then "Rarity" else "Title"
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromScale(0, (i - 1) * 0.5)
			t.Size = UDim2.fromScale(1, 0.5)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.Text = line[1] :: string
			t.TextColor3 = line[2] :: Color3
			local st = Instance.new("UIStroke")
			st.Thickness = 2
			st.Color = Color3.fromRGB(20, 20, 25)
			st.Parent = t
			t.Parent = bb
		end
	end

	local scale = opts.scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

return CrateModel
