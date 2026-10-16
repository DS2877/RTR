--!strict
-- Detailed cell furniture (WorldBuilder.buildCell): a steel bunk with posts, rails and slats, a
-- stitched mattress, a folded blanket and a pillow; a stainless prison toilet (pedestal, bowl, rim,
-- water, tank with a flush button, a paper roll); a steel sink on a pipe with a faucet, soap and a
-- cup. `at(x, y, d)` = the cell's own placement (x across, y up, d from the door into the cell).
-- The named parts the game uses keep their names: Mattress, Pillow, Blanket, Toilet, Tank, Sink.

local Build = require(script.Parent.Build)

local Props = {}

export type At = (x: number, y: number, d: number) -> CFrame

local STEEL = Color3.fromRGB(62, 66, 72)
local STAINLESS = Color3.fromRGB(196, 200, 206)

local function part(
	model: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	props: { [string]: any }?
): Part
	local base: { [string]: any } = { Material = Enum.Material.SmoothPlastic }
	if props then
		for k, v in props do
			base[k] = v
		end
	end
	return Build.part(model, name, size, cf, color, base)
end

-- a vertical cylinder (Roblox cylinders run along X): diameter d, height h, centered at cf
local function post(
	model: Instance,
	name: string,
	d: number,
	h: number,
	cf: CFrame,
	color: Color3,
	props: { [string]: any }?
): Part
	local base: { [string]: any } = { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal }
	if props then
		for k, v in props do
			base[k] = v
		end
	end
	return part(model, name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, base)
end

-- a cylinder lying along the cell's d axis (for rolls running the length of the bed)
local function alongD(
	model: Instance,
	name: string,
	d: number,
	len: number,
	cf: CFrame,
	color: Color3,
	props: { [string]: any }?
): Part
	local base: { [string]: any } = { Shape = Enum.PartType.Cylinder }
	if props then
		for k, v in props do
			base[k] = v
		end
	end
	return part(model, name, Vector3.new(len, d, d), cf * CFrame.Angles(0, math.pi / 2, 0), color, base)
end

-- a cylinder lying across the cell (x axis)
local function alongX(
	model: Instance,
	name: string,
	d: number,
	len: number,
	cf: CFrame,
	color: Color3,
	props: { [string]: any }?
): Part
	local base: { [string]: any } = { Shape = Enum.PartType.Cylinder }
	if props then
		for k, v in props do
			base[k] = v
		end
	end
	return part(model, name, Vector3.new(len, d, d), cf, color, base)
end

-- The bunk: centered on (x, d), 4 wide, 9 long. Returns the mattress.
function Props.bed(model: Instance, at: At, x: number, d: number, blanket: Color3): BasePart
	local metal = { Material = Enum.Material.Metal }
	for _, sx in { -1.85, 1.85 } do
		for _, sd in { -4.35, 4.35 } do
			post(
				model,
				"BedPost",
				0.32,
				if sd < 0 then 3.2 else 2.2,
				at(x + sx, if sd < 0 then 1.6 else 1.1, d + sd),
				STEEL
			)
		end
		-- side rails, top and bottom
		part(model, "BedRail", Vector3.new(0.22, 0.22, 8.4), at(x + sx, 1.45, d), STEEL, metal)
		part(model, "BedRail", Vector3.new(0.22, 0.22, 8.4), at(x + sx, 0.35, d), STEEL, metal)
	end
	-- head bars (by the pillow) and the foot rail
	part(model, "BedRail", Vector3.new(3.48, 0.22, 0.22), at(x, 3.05, d - 4.35), STEEL, metal)
	part(model, "BedRail", Vector3.new(3.48, 0.22, 0.22), at(x, 1.45, d - 4.35), STEEL, metal)
	for k = -1, 1 do
		post(model, "BedBar", 0.14, 1.4, at(x + k * 0.9, 2.3, d - 4.35), STEEL)
	end
	part(model, "BedRail", Vector3.new(3.48, 0.22, 0.22), at(x, 1.45, d + 4.35), STEEL, metal)
	-- slats under the mattress
	for k = -3, 3 do
		part(
			model,
			"BedSlat",
			Vector3.new(3.48, 0.1, 0.5),
			at(x, 1.58, d + k * 1.2),
			Color3.fromRGB(90, 94, 100),
			metal
		)
	end
	-- the mattress (Hideout lays you down on it) with stitched edges
	local mattress =
		part(model, "Mattress", Vector3.new(3.5, 0.7, 8.4), at(x, 1.98, d), Color3.fromRGB(226, 224, 212), {
			Material = Enum.Material.Fabric,
		})
	for _, sx in { -1.72, 1.72 } do
		alongD(model, "MattressPiping", 0.16, 8.3, at(x + sx, 2.3, d), Color3.fromRGB(190, 186, 172), {
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	-- folded blanket: flat over the foot half, a rolled fold, hanging edges
	part(model, "Blanket", Vector3.new(3.66, 0.12, 4.6), at(x, 2.39, d + 1.6), blanket, {
		Material = Enum.Material.Fabric,
	})
	alongX(model, "BlanketFold", 0.42, 3.66, at(x, 2.5, d - 0.75), blanket, {
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	for _, sx in { -1.86, 1.86 } do
		part(model, "BlanketEdge", Vector3.new(0.08, 0.55, 4.6), at(x + sx, 2.15, d + 1.6), blanket, {
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	-- the pillow (Hideout points your head at it), slightly plumped
	part(model, "Pillow", Vector3.new(2.7, 0.42, 1.4), at(x, 2.54, d - 3.4), Color3.fromRGB(246, 246, 240), {
		Material = Enum.Material.Fabric,
	})
	alongX(model, "PillowRoll", 0.5, 2.6, at(x, 2.55, d - 3.4), Color3.fromRGB(246, 246, 240), {
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	return mattress
end

-- The stainless toilet against the back side (tank toward +d). Returns the bowl ("Toilet").
function Props.toilet(model: Instance, at: At, x: number, d: number): BasePart
	local steel = { Material = Enum.Material.Metal, Reflectance = 0.08 }
	post(model, "ToiletPedestal", 1.3, 1.25, at(x, 0.62, d + 0.25), STAINLESS, steel)
	local bowl = post(model, "Toilet", 2.2, 0.85, at(x, 1.67, d), STAINLESS, steel)
	post(model, "ToiletRim", 2.36, 0.12, at(x, 2.15, d), Color3.fromRGB(176, 180, 186), {
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	post(model, "ToiletWater", 1.5, 0.04, at(x, 2.0, d), Color3.fromRGB(150, 190, 210), {
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
	})
	part(model, "Tank", Vector3.new(2.3, 2.3, 0.9), at(x, 2.6, d + 1.35), STAINLESS, steel)
	part(
		model,
		"TankLid",
		Vector3.new(2.42, 0.14, 1.02),
		at(x, 3.82, d + 1.35),
		Color3.fromRGB(176, 180, 186),
		steel
	)
	post(model, "FlushButton", 0.4, 0.12, at(x, 3.95, d + 1.35), Color3.fromRGB(60, 60, 64), steel)
	-- toilet paper on the side wall
	part(
		model,
		"PaperHolder",
		Vector3.new(0.12, 0.12, 0.9),
		at(x + 1.42, 3.2, d - 1.4),
		STEEL,
		{ Material = Enum.Material.Metal }
	)
	alongD(model, "PaperRoll", 0.7, 0.6, at(x + 1.1, 3.2, d - 1.4), Color3.fromRGB(245, 245, 240), {
		CanCollide = false,
	})
	return bowl
end

-- The steel sink on a pipe, with a faucet, a soap bar and a cup with a toothbrush. Returns "Sink".
function Props.sink(model: Instance, at: At, x: number, y: number, d: number): BasePart
	local steel = { Material = Enum.Material.Metal, Reflectance = 0.08 }
	local basin = part(model, "Sink", Vector3.new(2.2, 0.8, 1.8), at(x, y, d), STAINLESS, steel)
	part(
		model,
		"SinkBowl",
		Vector3.new(1.6, 0.06, 1.2),
		at(x - 0.1, y + 0.42, d),
		Color3.fromRGB(120, 124, 130),
		{
			Material = Enum.Material.Metal,
			CanCollide = false,
		}
	)
	post(model, "SinkPipe", 0.28, y - 0.4, at(x + 0.5, (y - 0.4) / 2, d), STEEL)
	post(model, "Faucet", 0.22, 0.55, at(x + 0.75, y + 0.68, d), STAINLESS, steel)
	part(model, "Spout", Vector3.new(0.5, 0.14, 0.14), at(x + 0.55, y + 0.92, d), STAINLESS, steel)
	part(
		model,
		"Soap",
		Vector3.new(0.45, 0.16, 0.3),
		at(x - 0.75, y + 0.48, d - 0.6),
		Color3.fromRGB(240, 170, 190),
		{
			CanCollide = false,
		}
	)
	post(model, "Cup", 0.36, 0.5, at(x - 0.75, y + 0.65, d + 0.55), Color3.fromRGB(90, 150, 210), {
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	part(
		model,
		"Toothbrush",
		Vector3.new(0.06, 0.8, 0.06),
		at(x - 0.72, y + 1.0, d + 0.55) * CFrame.Angles(0.25, 0, 0.15),
		Color3.fromRGB(230, 60, 60),
		{
			CanCollide = false,
		}
	)
	return basin
end

-- A leafy bush: overlapping balls in a few greens (reads far better than one green ball).
function Props.bush(parent: Instance, at: Vector3, size: number, seed: number?)
	local greens = {
		Color3.fromRGB(58, 112, 52),
		Color3.fromRGB(74, 132, 60),
		Color3.fromRGB(46, 96, 46),
		Color3.fromRGB(88, 142, 70),
	}
	local r = Random.new(seed or math.floor(at.X * 13 + at.Z * 7))
	for k = 1, 5 do
		local s = size * (0.55 + r:NextNumber() * 0.35)
		local off = Vector3.new(
			(r:NextNumber() - 0.5) * size * 0.7,
			(r:NextNumber() - 0.2) * size * 0.45,
			(r:NextNumber() - 0.5) * size * 0.7
		)
		part(
			parent,
			"Leaves",
			Vector3.new(s, s, s),
			CFrame.new(at + off),
			greens[(k + r:NextInteger(0, 3)) % #greens + 1],
			{
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.Grass,
				CanCollide = false,
				CastShadow = true,
			}
		)
	end
end

-- A tree in a concrete planter: tapered trunk, branch stubs, a clustered canopy.
function Props.tree(parent: Instance, at: Vector3, height: number, seed: number?)
	local bark = Color3.fromRGB(92, 68, 48)
	post(
		parent,
		"Planter",
		4.4,
		1.4,
		CFrame.new(at + Vector3.new(0, 0.7, 0)),
		Color3.fromRGB(130, 132, 134),
		{
			Material = Enum.Material.Concrete,
		}
	)
	post(
		parent,
		"PlanterSoil",
		3.8,
		0.1,
		CFrame.new(at + Vector3.new(0, 1.42, 0)),
		Color3.fromRGB(70, 52, 38),
		{
			Material = Enum.Material.Ground,
			CanCollide = false,
		}
	)
	post(
		parent,
		"Trunk",
		1.1,
		height * 0.55,
		CFrame.new(at + Vector3.new(0, 1.4 + height * 0.275, 0)),
		bark,
		{
			Material = Enum.Material.Wood,
		}
	)
	post(
		parent,
		"Trunk",
		0.75,
		height * 0.35,
		CFrame.new(at + Vector3.new(0.15, 1.4 + height * 0.7, 0)),
		bark,
		{
			Material = Enum.Material.Wood,
			CanCollide = false,
		}
	)
	for k = 0, 2 do
		local a = k * 2.1 + (seed or 0)
		part(
			parent,
			"Branch",
			Vector3.new(0.35, 0.35, 2.4),
			CFrame.new(at + Vector3.new(math.cos(a) * 0.9, 1.4 + height * 0.62, math.sin(a) * 0.9))
				* CFrame.Angles(0.6, a, 0),
			bark,
			{
				Material = Enum.Material.Wood,
				CanCollide = false,
			}
		)
	end
	local top = at + Vector3.new(0, 1.4 + height * 0.85, 0)
	Props.bush(parent, top, height * 0.55, seed)
	Props.bush(parent, top + Vector3.new(0, height * 0.22, 0), height * 0.4, (seed or 0) + 7)
end

return Props
