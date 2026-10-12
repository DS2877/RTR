--!strict
-- Builds a loot item from primitive parts (no uploaded meshes needed) with a floating label.
-- The model's PrimaryPart is "Core"; every part is non-colliding and massless so it can be
-- anchored on a pedestal or welded above a player's head.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Rarity = require(Shared.Config.Rarity)
local Mutations = require(Shared.Config.Mutations)
local Format = require(Shared.Format)

local ItemModel = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = true
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- Shape builders: everything is built around the origin, about 3-4 studs big.
local SHAPES: { [string]: (model: Model, color: Color3) -> () } = {
	box = function(model, color)
		part(model, "Body", Vector3.new(3.2, 2.2, 2.4), CFrame.new(0, 0, 0), color)
		part(
			model,
			"Top",
			Vector3.new(2.4, 0.6, 1.8),
			CFrame.new(0, 1.4, 0),
			color:Lerp(Color3.new(1, 1, 1), 0.25)
		)
	end,
	bar = function(model, color)
		part(model, "Body", Vector3.new(3.6, 1.1, 1.6), CFrame.Angles(0, 0, math.rad(20)), color)
		part(
			model,
			"Cap",
			Vector3.new(1.0, 1.4, 1.9),
			CFrame.new(1.5, 0.55, 0),
			color:Lerp(Color3.new(0, 0, 0), 0.2)
		)
	end,
	gem = function(model, color)
		part(model, "Body", Vector3.new(2.2, 2.2, 2.2), CFrame.Angles(math.rad(45), 0, math.rad(45)), color)
		part(model, "Shine", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 0, 0), Color3.new(1, 1, 1))
	end,
	orb = function(model, color)
		part(model, "Body", Vector3.new(2.8, 2.8, 2.8), CFrame.new(), color, Enum.PartType.Ball)
		part(
			model,
			"Ring",
			Vector3.new(0.3, 3.4, 3.4),
			CFrame.Angles(0, 0, math.rad(90)),
			color:Lerp(Color3.new(1, 1, 1), 0.4),
			Enum.PartType.Cylinder
		)
	end,
	frame = function(model, color)
		part(model, "Body", Vector3.new(3.4, 2.6, 0.4), CFrame.new(), Color3.fromRGB(180, 130, 40))
		part(model, "Inner", Vector3.new(2.8, 2.0, 0.5), CFrame.new(), color)
	end,
	egg = function(model, color)
		part(model, "Body", Vector3.new(2.6, 3.4, 2.6), CFrame.new(), color, Enum.PartType.Ball)
		part(
			model,
			"Spot",
			Vector3.new(0.9, 0.9, 0.9),
			CFrame.new(0.9, 0.6, -0.8),
			color:Lerp(Color3.new(1, 1, 1), 0.5),
			Enum.PartType.Ball
		)
	end,
	tall = function(model, color)
		part(
			model,
			"Body",
			Vector3.new(3.6, 1.8, 1.8), -- cylinder length is X: 3.6 tall once stood up
			CFrame.Angles(0, 0, math.rad(90)),
			color,
			Enum.PartType.Cylinder
		)
		part(
			model,
			"Top",
			Vector3.new(2.2, 0.5, 2.2),
			CFrame.new(0, 1.9, 0),
			color:Lerp(Color3.new(0, 0, 0), 0.25)
		)
	end,
}

-- Cylinders are along X; rotate "tall" so it stands up.
local function fixTall(model: Model)
	local body = model:FindFirstChild("Body") :: BasePart?
	if body and body.Shape == Enum.PartType.Cylinder then
		body.CFrame = CFrame.Angles(0, 0, math.rad(90))
	end
end

export type Options = {
	label: boolean?, -- floating name + income label (default true)
	extraText: string?, -- line under the income (e.g. owner name)
	scale: number?, -- 1 = carried size; displays use ~1.5
}

-- Chance that a vault stand rolls exactly this item + mutation (shown as "1 in N").
local function odds(rarity: string, mutation: string): number
	local total = 0
	for _, id in Rarity.Order do
		total += Rarity.Tiers[id].weight
	end
	local p = Rarity.Tiers[rarity].weight / total
	if mutation == "None" then
		local mutated = 0
		for _, m in Mutations.List do
			mutated += m.chance
		end
		return p * (1 - mutated)
	end
	return p * Mutations.List[mutation].chance
end
ItemModel.odds = odds

function ItemModel.build(id: string, mutation: string, options: Options?): Model
	local info = Progression.item(id)
	assert(info, "unknown item " .. id)
	local mut = Mutations.List[mutation] or Mutations.List.None
	local tier = Rarity.Tiers[info.rarity]

	local model = Instance.new("Model")
	model.Name = "Item_" .. id
	model:SetAttribute("ItemId", id)
	model:SetAttribute("Mutation", mut.id)

	local color = rgb(info.color)
	if mut.color then
		color = rgb(mut.color)
	end
	local build = SHAPES[info.shape] or SHAPES.box
	build(model, color)
	if info.shape == "tall" then
		fixTall(model)
	end

	-- material by mutation
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			if mut.id == "Gold" then
				d.Material = Enum.Material.SmoothPlastic -- clean cartoon gold (Foil reads as crumpled wrap)
				d.Reflectance = 0.25
			elseif mut.id == "Diamond" then
				d.Material = Enum.Material.Glass
				d.Reflectance = 0.3
			elseif mut.id == "Rainbow" then
				d.Material = Enum.Material.Neon
				CollectionService:AddTag(d, "Rainbow")
			end
		end
	end

	local core = part(model, "Core", Vector3.new(1, 1, 1), CFrame.new(), Color3.new(1, 1, 1))
	core.Transparency = 1
	model.PrimaryPart = core

	if tier.glow or mut.id ~= "None" then
		local light = Instance.new("PointLight")
		light.Color = if mut.color then rgb(mut.color) else rgb(tier.color)
		light.Brightness = 2
		light.Range = 10
		light.Parent = core
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(light.Color)
		sparkles.Size = NumberSequence.new(0.4, 0)
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Rate = if info.rarity == "Mythic" then 25 else 10
		sparkles.Speed = NumberRange.new(1, 3)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 1
		sparkles.Parent = core
	end

	local opts = options or {}
	local scale = opts.scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	-- the rarest loot burns (genre look: flames + glow around Legendary/Mythic)
	if info.rarity == "Legendary" or info.rarity == "Mythic" then
		local fire = Instance.new("ParticleEmitter")
		fire.Name = "Aura"
		fire.Texture = "rbxasset://textures/particles/fire_main.dds"
		fire.Color = ColorSequence.new(rgb(tier.color), Color3.new(1, 1, 1))
		fire.LightEmission = 1
		fire.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2.2 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		fire.Transparency = NumberSequence.new(0.2, 1)
		fire.Lifetime = NumberRange.new(0.5, 0.9)
		fire.Speed = NumberRange.new(2, 4)
		fire.Rate = if info.rarity == "Mythic" then 40 else 22
		fire.SpreadAngle = Vector2.new(25, 25)
		fire.Parent = core
	end
	if opts.label ~= false then
		-- Sized in studs (not pixels), so labels shrink with distance like the world does and
		-- far-away loot never stacks into a wall of text. Only what matters is shown: the name, the
		-- income, and rarity/odds/mutation when they are special.
		local p = odds(info.rarity, mut.id)
		local rare = info.rarity ~= "Common" and info.rarity ~= "Uncommon"
		local lines: { { text: string, weight: number, color: Color3 } } = {}
		if mut.id ~= "None" then
			table.insert(lines, { text = mut.label, weight = 0.8, color = rgb(mut.color :: { number }) })
		end
		if rare then
			table.insert(lines, { text = info.rarity, weight = 0.85, color = rgb(tier.color) })
		end
		table.insert(lines, { text = info.name, weight = 1, color = Color3.new(1, 1, 1) })
		table.insert(lines, {
			text = "+" .. Format.cash(Progression.income(id, mut.id)) .. "/s",
			weight = 1.25,
			color = Color3.fromRGB(110, 255, 120),
		})
		if p < 1 / 20 then
			table.insert(
				lines,
				{ text = Format.oneIn(p), weight = 0.7, color = Color3.fromRGB(170, 255, 190) }
			)
		end
		local total = 0
		for _, l in lines do
			total += l.weight
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "Label"
		bb.Size = UDim2.new(6 * scale, 0, 0.62 * total * scale, 0)
		bb.StudsOffset = Vector3.new(0, 2.4 * scale + 0.4 * total * scale, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 75
		bb.LightInfluence = 0
		bb.Adornee = core
		bb.Parent = core
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = bb
		for order, l in lines do
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, l.weight / total)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.Text = l.text
			t.TextColor3 = l.color
			t.LayoutOrder = order
			local st = Instance.new("UIStroke")
			st.Thickness = 2
			st.Color = Color3.fromRGB(20, 20, 25)
			st.Parent = t
			t.Parent = bb
		end
	end

	return model
end

-- Move every part of an item model (built around the origin) to `cf`.
function ItemModel.place(model: Model, cf: CFrame)
	model:PivotTo(cf)
end

-- Unanchor and weld every part to `attachTo` (e.g. above a player's head).
function ItemModel.weldTo(model: Model, attachTo: BasePart, offset: CFrame)
	model:PivotTo(attachTo.CFrame * offset)
	local core = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d ~= core then
				local w = Instance.new("WeldConstraint")
				w.Part0 = core
				w.Part1 = d
				w.Parent = d
			end
			d.Anchored = false
		end
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = attachTo
	w.Part1 = core
	w.Parent = core
end

return ItemModel
