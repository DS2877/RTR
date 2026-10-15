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
		p(
			m,
			"Base",
			Vector3.new(1.4, 1.4, 1.8),
			CFrame.new(0, 0.7, 0.2),
			WHITE,
			{ Material = Enum.Material.Marble }
		)
		p(
			m,
			"Bowl",
			Vector3.new(2, 0.6, 2.4),
			CFrame.new(0, 1.7, 0),
			WHITE,
			{ Material = Enum.Material.Marble }
		)
		p(m, "Seat", Vector3.new(2.1, 0.15, 2.5), CFrame.new(0, 2.08, 0), Color3.fromRGB(240, 240, 235))
		p(
			m,
			"Tank",
			Vector3.new(2.2, 2, 0.9),
			CFrame.new(0, 2.6, 1.3),
			WHITE,
			{ Material = Enum.Material.Marble }
		)
		p(
			m,
			"Handle",
			Vector3.new(0.5, 0.15, 0.15),
			CFrame.new(-0.9, 3.3, 0.8),
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
		p(
			m,
			"Body",
			Vector3.new(4, 7, 3),
			CFrame.new(0, 3.5, 0),
			Color3.fromRGB(170, 40, 40),
			{ Material = Enum.Material.Metal }
		)
		p(m, "Glass", Vector3.new(2.6, 5, 0.2), CFrame.new(-0.4, 4, -1.5), Color3.fromRGB(180, 220, 240), {
			Material = Enum.Material.Glass,
			Transparency = 0.4,
		})
		for row = 0, 3 do
			for col = 0, 2 do
				p(
					m,
					"Snack",
					Vector3.new(0.6, 0.8, 0.5),
					CFrame.new(-1.3 + col * 0.9, 2.2 + row * 1.2, -1.2),
					if (row + col) % 2 == 0
						then Color3.fromRGB(240, 190, 40)
						else Color3.fromRGB(60, 150, 220)
				)
			end
		end
		p(m, "Keypad", Vector3.new(0.8, 1.6, 0.2), CFrame.new(1.4, 4.4, -1.55), Color3.fromRGB(30, 30, 35))
		p(m, "Slot", Vector3.new(2.6, 0.7, 0.2), CFrame.new(-0.4, 0.8, -1.55), Color3.fromRGB(20, 20, 22))
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
		p(m, "Panel", Vector3.new(3.4, 0.6, 0.3), CFrame.new(0, 3.3, -1.6), Color3.fromRGB(60, 60, 70))
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
		p(m, "Stripe", Vector3.new(7.05, 0.8, 20.05), CFrame.new(0, 3.2, 0), Color3.fromRGB(40, 70, 130))
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
					CFrame.new(side * 3.56, 5.3, -7.5 + i * 3),
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
			p(m, "Plate", Vector3.new(5, 0.8, 0.1), CFrame.new(0, 3.2, -10.05), Color3.fromRGB(240, 240, 235))
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
