--!strict
-- The ridiculous things prisoners lift in the yard gym. GymProps.build(id) returns an anchored
-- Model standing on y = 0 around the origin (the same model is cloned, unanchored, for lifting).

local Build = require(script.Parent.Build)

local GymProps = {}

local WHITE = Color3.fromRGB(225, 226, 228)
local STEEL = Color3.fromRGB(70, 74, 80)

local function p(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3, props: Build.Props?): Part
	return Build.part(m, name, size, cf, color, props)
end

local builders: { [string]: (m: Model) -> () } = {
	Toilet = function(m)
		-- a proper porcelain toilet: pedestal, bowl, seat with the lid up, tank, lid, handle
		local function cyl(name: string, d: number, h: number, y: number, z: number, color: Color3)
			return p(
				m,
				name,
				Vector3.new(h, d, d),
				CFrame.new(0, y, z) * CFrame.Angles(0, 0, math.pi / 2),
				color,
				{
					Shape = Enum.PartType.Cylinder,
					Material = Enum.Material.Marble,
				}
			)
		end
		cyl("Base", 1.2, 0.2, 0.1, 0.3, WHITE)
		cyl("Pedestal", 1.05, 1.0, 0.7, 0.25, WHITE)
		cyl("Bowl", 2.0, 0.75, 1.55, 0, WHITE)
		cyl("BowlInside", 1.5, 0.06, 1.9, 0, Color3.fromRGB(150, 190, 210))
		cyl("Seat", 2.12, 0.14, 2.0, 0, Color3.fromRGB(246, 246, 242))
		p(
			m,
			"LidUp",
			Vector3.new(1.9, 1.9, 0.14),
			CFrame.new(0, 2.95, 0.95) * CFrame.Angles(math.rad(-12), 0, 0),
			Color3.fromRGB(246, 246, 242),
			{
				Material = Enum.Material.SmoothPlastic,
			}
		)
		p(
			m,
			"Tank",
			Vector3.new(2.2, 1.9, 0.9),
			CFrame.new(0, 2.85, 1.45),
			WHITE,
			{ Material = Enum.Material.Marble }
		)
		p(
			m,
			"TankLid",
			Vector3.new(2.32, 0.16, 1.0),
			CFrame.new(0, 3.88, 1.45),
			Color3.fromRGB(240, 240, 238),
			{
				Material = Enum.Material.Marble,
			}
		)
		p(
			m,
			"Handle",
			Vector3.new(0.5, 0.12, 0.12),
			CFrame.new(-0.85, 3.4, 0.98),
			STEEL,
			{ Material = Enum.Material.Metal }
		)
	end,
	Mattress = function(m)
		local colors = {
			Color3.fromRGB(210, 210, 200),
			Color3.fromRGB(170, 180, 200),
			Color3.fromRGB(200, 190, 170),
			Color3.fromRGB(190, 200, 190),
		}
		for i, c in colors do
			p(
				m,
				"Mattress",
				Vector3.new(3.4, 0.7, 6),
				CFrame.new((i % 2) * 0.3 - 0.15, 0.35 + (i - 1) * 0.72, (i % 3) * 0.2)
					* CFrame.Angles(0, (i - 2) * 0.05, 0),
				c,
				{ Material = Enum.Material.Fabric }
			)
		end
		p(
			m,
			"Pillow",
			Vector3.new(2.4, 0.5, 1.2),
			CFrame.new(0, 3.2, -2),
			Color3.fromRGB(245, 245, 240),
			{ Material = Enum.Material.Fabric }
		)
	end,
	Vending = function(m)
		-- a glowing snack machine: lit glass front with rows of snacks, a header, coin panel, tray
		-- a hollow cabinet: the back block plus a frame around a recessed, lit window
		local red = Color3.fromRGB(170, 40, 40)
		local metal = { Material = Enum.Material.Metal }
		p(m, "Body", Vector3.new(4, 7, 1.9), CFrame.new(0, 3.5, 0.55), red, metal)
		p(m, "Frame", Vector3.new(0.3, 7, 1.1), CFrame.new(-1.85, 3.5, -0.95), red, metal)
		p(m, "Frame", Vector3.new(1.1, 7, 1.1), CFrame.new(1.45, 3.5, -0.95), red, metal)
		p(m, "Frame", Vector3.new(2.6, 1.3, 1.1), CFrame.new(-0.4, 0.65, -0.95), red, metal)
		p(m, "Frame", Vector3.new(2.6, 0.9, 1.1), CFrame.new(-0.4, 6.55, -0.95), red, metal)
		p(m, "Trim", Vector3.new(4.1, 0.3, 3.1), CFrame.new(0, 7.0, 0), Color3.fromRGB(40, 40, 44), {
			Material = Enum.Material.Metal,
		})
		local header = p(
			m,
			"Header",
			Vector3.new(3.6, 0.9, 0.1),
			CFrame.new(0, 6.35, -1.52),
			Color3.fromRGB(255, 220, 90)
		)
		local hg = Instance.new("SurfaceGui")
		hg.Face = Enum.NormalId.Front
		hg.LightInfluence = 0
		hg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		hg.PixelsPerStud = 40
		hg.Parent = header
		local ht = Instance.new("TextLabel")
		ht.Size = UDim2.fromScale(1, 1)
		ht.BackgroundColor3 = Color3.fromRGB(255, 210, 70)
		ht.Text = "SNAX"
		ht.Font = Enum.Font.GothamBlack
		ht.TextScaled = true
		ht.TextColor3 = Color3.fromRGB(150, 20, 20)
		ht.Parent = hg
		local back = p(
			m,
			"Inside",
			Vector3.new(2.56, 4.76, 0.1),
			CFrame.new(-0.4, 3.7, -0.46),
			Color3.fromRGB(235, 235, 240)
		)
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Range = 8
		light.Brightness = 0.8
		light.Color = Color3.fromRGB(230, 240, 255)
		light.Parent = back
		local colors = {
			Color3.fromRGB(240, 190, 40),
			Color3.fromRGB(60, 150, 220),
			Color3.fromRGB(220, 60, 60),
			Color3.fromRGB(90, 190, 90),
			Color3.fromRGB(240, 120, 40),
			Color3.fromRGB(160, 90, 200),
		}
		for row = 0, 3 do
			p(
				m,
				"Shelf",
				Vector3.new(2.56, 0.08, 0.8),
				CFrame.new(-0.4, 1.75 + row * 1.2, -0.95),
				Color3.fromRGB(150, 150, 156),
				{
					Material = Enum.Material.Metal,
				}
			)
			for col = 0, 3 do
				p(
					m,
					"Snack",
					Vector3.new(0.5, 0.75, 0.35),
					CFrame.new(-1.35 + col * 0.64, 2.17 + row * 1.2, -0.78),
					colors[(row * 4 + col) % #colors + 1]
				)
			end
		end
		p(
			m,
			"Glass",
			Vector3.new(2.7, 4.6, 0.1),
			CFrame.new(-0.4, 3.5, -1.52),
			Color3.fromRGB(190, 220, 240),
			{
				Material = Enum.Material.Glass,
				Transparency = 0.55,
			}
		)
		p(m, "Keypad", Vector3.new(0.8, 1.8, 0.12), CFrame.new(1.45, 4.3, -1.53), Color3.fromRGB(30, 30, 35))
		for k = 0, 5 do
			p(
				m,
				"Key",
				Vector3.new(0.2, 0.2, 0.06),
				CFrame.new(1.3 + (k % 2) * 0.3, 4.75 - math.floor(k / 2) * 0.32, -1.6),
				Color3.fromRGB(200, 200, 204)
			)
		end
		p(
			m,
			"CoinSlot",
			Vector3.new(0.3, 0.12, 0.06),
			CFrame.new(1.45, 3.7, -1.6),
			Color3.fromRGB(230, 190, 60),
			{ Material = Enum.Material.Metal }
		)
		p(m, "Slot", Vector3.new(2.6, 0.7, 0.12), CFrame.new(-0.4, 0.75, -1.53), Color3.fromRGB(20, 20, 22))
	end,
	Guard = function(m)
		-- a guard asleep on a stretcher, snoring
		p(
			m,
			"Stretcher",
			Vector3.new(2.6, 0.4, 6.6),
			CFrame.new(0, 0.6, 0),
			Color3.fromRGB(60, 120, 90),
			{ Material = Enum.Material.Fabric }
		)
		for _, dz in { -3.2, 3.2 } do
			p(
				m,
				"Pole",
				Vector3.new(0.3, 0.3, 1),
				CFrame.new(-1.3, 0.6, dz + (if dz > 0 then 0.6 else -0.6)),
				STEEL
			)
			p(
				m,
				"Pole",
				Vector3.new(0.3, 0.3, 1),
				CFrame.new(1.3, 0.6, dz + (if dz > 0 then 0.6 else -0.6)),
				STEEL
			)
		end
		local guard = Build.npc(
			m,
			"Guard",
			CFrame.new(0, 0, 0),
			Color3.fromRGB(40, 60, 110),
			Color3.fromRGB(20, 30, 60),
			Color3.fromRGB(30, 40, 60)
		)
		guard:PivotTo(CFrame.new(0, 1.3, 2.6) * CFrame.Angles(-math.pi / 2, 0, 0))
		for _, d in guard:GetChildren() do
			d.Parent = m
		end
		guard:Destroy()
		local head = m:FindFirstChild("Head") :: BasePart?
		if head then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(60, 40)
			bb.StudsOffset = Vector3.new(0, 2, 0)
			bb.MaxDistance = 60
			bb.Parent = head
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 1)
			l.Text = "Zzz"
			l.TextScaled = true
			l.Font = Enum.Font.GothamBlack
			l.TextColor3 = Color3.fromRGB(220, 230, 255)
			l.Parent = bb
		end
	end,
	Washer = function(m)
		p(
			m,
			"Body",
			Vector3.new(3.4, 3.6, 3.4),
			CFrame.new(0, 1.8, 0),
			WHITE,
			{ Material = Enum.Material.Metal }
		)
		p(
			m,
			"Door",
			Vector3.new(0.2, 2.2, 2.2),
			CFrame.new(0, 1.8, -1.72) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(150, 190, 220),
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Glass,
				Transparency = 0.3,
			}
		)
		p(
			m,
			"Suds",
			Vector3.new(0.15, 1.6, 1.6),
			CFrame.new(0, 1.6, -1.6) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(240, 245, 255),
			{
				Shape = Enum.PartType.Cylinder,
			}
		)
		p(m, "Panel", Vector3.new(3.3, 0.7, 0.3), CFrame.new(0, 3.3, -1.6), Color3.fromRGB(60, 60, 70))
	end,
	Desk = function(m)
		local wood = Color3.fromRGB(100, 66, 40)
		p(
			m,
			"Top",
			Vector3.new(7, 0.5, 3.4),
			CFrame.new(0, 3, 0),
			wood,
			{ Material = Enum.Material.WoodPlanks }
		)
		for _, dx in { -3, 3 } do
			p(
				m,
				"Drawers",
				Vector3.new(1.6, 2.75, 3.2),
				CFrame.new(dx, 1.4, 0),
				wood,
				{ Material = Enum.Material.Wood }
			)
		end
		p(m, "Lamp", Vector3.new(0.5, 1.4, 0.5), CFrame.new(2.6, 3.95, 1), Color3.fromRGB(40, 120, 70))
		p(
			m,
			"Papers",
			Vector3.new(1.4, 0.3, 1),
			CFrame.new(-1, 3.4, 0.4) * CFrame.Angles(0, 0.3, 0),
			Color3.fromRGB(240, 240, 230)
		)
		p(m, "Lunch", Vector3.new(1, 0.6, 1), CFrame.new(0.6, 3.55, -0.6), Color3.fromRGB(230, 160, 60))
		p(
			m,
			"Nameplate",
			Vector3.new(2, 0.5, 0.3),
			CFrame.new(0, 3.5, -1.4),
			Color3.fromRGB(200, 170, 60),
			{ Material = Enum.Material.Metal }
		)
	end,
	Bus = function(m)
		local body = Color3.fromRGB(225, 225, 220)
		p(m, "Body", Vector3.new(7, 6, 20), CFrame.new(0, 4, 0), body, { Material = Enum.Material.Metal })
		p(m, "Stripe", Vector3.new(7.14, 0.8, 20.14), CFrame.new(0, 3.2, 0), Color3.fromRGB(40, 70, 130))
		p(m, "Roof", Vector3.new(6.6, 0.5, 19.6), CFrame.new(0, 7.2, 0), body)
		for side = -1, 1, 2 do
			for i = 0, 5 do
				p(
					m,
					"Window",
					Vector3.new(0.1, 1.8, 2.2),
					CFrame.new(side * 3.53, 5.3, -7.5 + i * 3),
					Color3.fromRGB(40, 50, 60),
					{
						Material = Enum.Material.Glass,
					}
				)
				p(
					m,
					"Bars",
					Vector3.new(0.15, 1.8, 0.2),
					CFrame.new(side * 3.64, 5.3, -7.5 + i * 3),
					Color3.fromRGB(30, 30, 30)
				)
			end
			for _, z in { -7, 7 } do
				p(
					m,
					"Wheel",
					Vector3.new(1, 2.4, 2.4),
					CFrame.new(side * 3.2, 1.2, z),
					Color3.fromRGB(25, 25, 28),
					{
						Shape = Enum.PartType.Cylinder,
					}
				)
			end
		end
		p(
			m,
			"Windshield",
			Vector3.new(6, 2.4, 0.1),
			CFrame.new(0, 5.4, -10.03),
			Color3.fromRGB(40, 50, 60),
			{ Material = Enum.Material.Glass }
		)
		local plateTag =
			p(m, "Plate", Vector3.new(5, 0.9, 0.1), CFrame.new(0, 3.2, -10.05), Color3.fromRGB(240, 240, 235))
		Build.sign(
			plateTag,
			Enum.NormalId.Front,
			"DEPT OF CORRECTIONS",
			Color3.fromRGB(30, 50, 100),
			Color3.new(1, 1, 1)
		)
	end,
}

function GymProps.build(id: string): Model
	local m = Instance.new("Model")
	m.Name = id
	local fn = builders[id] or builders.Toilet
	fn(m)
	m.WorldPivot = CFrame.new() -- pivot = the floor point the prop stands on
	return m
end

-- An unanchored, weightless copy scaled so it fits above a head (max ~maxSize studs).
function GymProps.held(id: string, maxSize: number): Model
	local m = GymProps.build(id)
	local _, size = m:GetBoundingBox()
	local biggest = math.max(size.X, size.Y, size.Z)
	if biggest > maxSize then
		m:ScaleTo(maxSize / biggest)
	end
	local cf = m:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "HeldRoot"
	root.Transparency = 1
	root.Size = Vector3.one
	root.CFrame = cf
	root.Parent = m
	m.PrimaryPart = root
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			if d ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	return m
end

return GymProps
