--!strict
-- The VAULT DOOR guarding a zone's sealed chamber (Services/Dig): a thick riveted steel door with
-- a wheel, hazard stripes and the chamber's name on a health bar above it. Built on the chamber's
-- front face, a hair in front of the rock so the voxels behind it never show through.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Tunnel = require(Shared.Tunnel)
local Progression = require(Shared.Progression)
local Format = require(Shared.Format)

local Build = require(script.Parent.Build)

local VaultDoor = {}

local B = World.BlockSize
local STEEL = Color3.fromRGB(78, 82, 90)
local DARK = Color3.fromRGB(34, 36, 40)

export type Door = { model: Model, bar: Frame, hpText: TextLabel }

-- Builds the door for `zone` in front of its chamber in the tunnel at `frame`.
function VaultDoor.build(parent: Instance, frame: CFrame, zone: number): Door?
	local b = Progression.chamberBox(zone)
	local z = Zones[zone]
	if not b or not z or not z.chamber then
		return nil
	end
	local w = (b.x1 - b.x0 + 1) * B
	local h = (b.y1 - b.y0 + 1) * B
	-- the plane of the chamber's front (the face toward the cell), moved a little toward you
	local mid = Tunnel.blockCenter(frame, (b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2, b.z0)
	local toward = frame:VectorToWorldSpace(Vector3.new(0, 0, 1))
	local center = mid + toward * (B / 2 + 0.35)
	-- (local +Z faces you: the rivets, wheel and stripes sit on that side)
	local cf = CFrame.lookAt(center, center - toward)
	local m = Instance.new("Model")
	m.Name = "VaultDoor" .. zone
	local metal = { Material = Enum.Material.DiamondPlate }
	local slab = Build.part(m, "Door", Vector3.new(w - 0.4, h - 0.4, 0.6), cf, STEEL, metal)
	m.PrimaryPart = slab
	-- a heavy frame around it
	Build.part(m, "FrameTop", Vector3.new(w, 0.5, 0.9), cf * CFrame.new(0, h / 2 - 0.25, -0.05), DARK, metal)
	Build.part(
		m,
		"FrameBottom",
		Vector3.new(w, 0.5, 0.9),
		cf * CFrame.new(0, -h / 2 + 0.25, -0.05),
		DARK,
		metal
	)
	Build.part(
		m,
		"FrameLeft",
		Vector3.new(0.5, h - 1, 0.9),
		cf * CFrame.new(-w / 2 + 0.25, 0, -0.05),
		DARK,
		metal
	)
	Build.part(
		m,
		"FrameRight",
		Vector3.new(0.5, h - 1, 0.9),
		cf * CFrame.new(w / 2 - 0.25, 0, -0.05),
		DARK,
		metal
	)
	-- rivets in rows
	for _, y in { h / 2 - 1, -h / 2 + 1 } do
		for x = -w / 2 + 1.2, w / 2 - 1.2, 2.2 do
			Build.part(
				m,
				"Rivet",
				Vector3.new(0.3, 0.3, 0.3),
				cf * CFrame.new(x, y, 0.38),
				Color3.fromRGB(150, 154, 160),
				{
					Shape = Enum.PartType.Ball,
					Material = Enum.Material.Metal,
				}
			)
		end
	end
	-- the wheel: a ring of spokes around a hub
	local wheel = cf * CFrame.new(0, 0, 0.5)
	Build.part(
		m,
		"Hub",
		Vector3.new(0.5, 1.4, 1.4),
		wheel * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(190, 160, 70),
		{
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Metal,
		}
	)
	for k = 0, 3 do
		Build.part(
			m,
			"Spoke",
			Vector3.new(4.4, 0.3, 0.3),
			wheel * CFrame.new(0, 0, 0.12) * CFrame.Angles(0, 0, k * math.pi / 4),
			Color3.fromRGB(170, 140, 60),
			{
				Material = Enum.Material.Metal,
			}
		)
	end
	-- hazard stripes across the bottom
	for k = 0, math.floor(w / 2) - 1 do
		Build.part(
			m,
			"Hazard",
			Vector3.new(0.9, 0.6, 0.06),
			cf * CFrame.new(-w / 2 + 1.4 + k * 2, -h / 2 + 1.2, 0.33) * CFrame.Angles(0, 0, math.pi / 4),
			if k % 2 == 0 then Color3.fromRGB(240, 190, 40) else DARK,
			{ CanCollide = false }
		)
	end
	-- the zone's glow behind the cracks
	local c = z.chamber.light
	Build.light(slab, Color3.fromRGB(c[1], c[2], c[3]), 14, 0.8)
	-- the health bar
	local gui = Instance.new("BillboardGui")
	gui.Name = "Health"
	gui.Size = UDim2.fromOffset(240, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, h / 2 + 1.6, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Parent = slab
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 20)
	name.Font = Enum.Font.GothamBlack
	name.TextSize = 16
	name.TextColor3 = Color3.fromRGB(255, 220, 120)
	name.TextStrokeTransparency = 0.4
	name.Text = "⚠ SEALED: " .. string.upper(z.chamber.name)
	name.Parent = gui
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(10, 24)
	track.Size = UDim2.new(1, -20, 0, 12)
	track.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	track.BorderSizePixel = 0
	track.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = track
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(235, 70, 60)
	bar.BorderSizePixel = 0
	bar.Parent = track
	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 6)
	corner2.Parent = bar
	local hpText = Instance.new("TextLabel")
	hpText.BackgroundTransparency = 1
	hpText.Size = UDim2.fromScale(1, 1)
	hpText.Font = Enum.Font.GothamBold
	hpText.TextSize = 10
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.Text = ""
	hpText.Parent = track
	m:SetAttribute("Zone", zone)
	m.Parent = parent
	return { model = m, bar = bar, hpText = hpText }
end

function VaultDoor.setHp(door: Door, hp: number, max: number)
	local k = math.clamp(hp / math.max(max, 1), 0, 1)
	door.bar.Size = UDim2.fromScale(k, 1)
	door.hpText.Text = Format.number(math.max(0, math.ceil(hp))) .. " HP"
end

return VaultDoor
