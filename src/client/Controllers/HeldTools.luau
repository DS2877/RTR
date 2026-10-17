--!strict
-- The tool you bought is in your hand: every player's current tool (their "Tools" attribute =
-- Config/Upgrades.Tools level) is built from a few parts on each client and welded to the right
-- hand. Fists = nothing in hand. Built in "grip space": the hand holds the origin, -Z sticks out
-- of the fist (down when the arm hangs, forward when it punches).

local Players = game:GetService("Players")

local HeldTools = {}

local METAL = Color3.fromRGB(176, 180, 188)
local DARK = Color3.fromRGB(46, 48, 54)
local WOOD = Color3.fromRGB(130, 88, 52)

type Kit = {
	box: (size: Vector3, at: CFrame, color: Color3, mat: Enum.Material?) -> Part,
	rod: (radius: number, length: number, z: number, color: Color3, mat: Enum.Material?) -> Part,
	ball: (size: Vector3, at: CFrame, color: Color3, mat: Enum.Material?) -> Part,
	light: (part: BasePart, color: Color3, range: number) -> (),
}

local BUILD: { [number]: (k: Kit) -> () } = {
	-- 2 Spoon
	[2] = function(k)
		k.rod(0.07, 1.3, -0.45, METAL, Enum.Material.Metal)
		k.ball(Vector3.new(0.42, 0.12, 0.6), CFrame.new(0, 0, -1.3), METAL, Enum.Material.Metal)
	end,
	-- 3 Shovel
	[3] = function(k)
		k.rod(0.09, 2.1, -0.75, WOOD, Enum.Material.Wood)
		k.box(Vector3.new(0.5, 0.12, 0.16), CFrame.new(0, 0, 0.32), DARK, Enum.Material.Metal)
		k.box(Vector3.new(0.85, 0.08, 0.8), CFrame.new(0, 0, -2.15), METAL, Enum.Material.Metal)
	end,
	-- 4 Pickaxe
	[4] = function(k)
		k.rod(0.09, 2.0, -0.7, WOOD, Enum.Material.Wood)
		k.box(Vector3.new(1.5, 0.2, 0.26), CFrame.new(0, 0, -1.75), METAL, Enum.Material.Metal)
		for _, x in { -1, 1 } do
			k.box(
				Vector3.new(0.4, 0.14, 0.18),
				CFrame.new(x * 0.9, 0, -1.68) * CFrame.Angles(0, x * 0.35, 0),
				METAL,
				Enum.Material.Metal
			)
		end
	end,
	-- 5 Jackhammer
	[5] = function(k)
		k.box(Vector3.new(0.62, 0.7, 1.05), CFrame.new(0, 0, -0.45), Color3.fromRGB(240, 190, 40))
		k.box(Vector3.new(0.9, 0.14, 0.14), CFrame.new(0, 0.42, -0.1), DARK)
		k.rod(0.16, 0.3, -1.1, DARK, Enum.Material.Metal)
		k.rod(0.07, 1.0, -1.7, METAL, Enum.Material.Metal)
	end,
	-- 6 Drill
	[6] = function(k)
		k.box(Vector3.new(0.5, 0.62, 0.95), CFrame.new(0, 0.05, -0.4), Color3.fromRGB(235, 110, 40))
		k.box(Vector3.new(0.3, 0.55, 0.3), CFrame.new(0, -0.32, -0.1), DARK)
		k.rod(0.15, 0.25, -1.0, DARK, Enum.Material.Metal)
		k.rod(0.08, 0.9, -1.55, METAL, Enum.Material.DiamondPlate)
	end,
	-- 7 Laser
	[7] = function(k)
		k.box(
			Vector3.new(0.42, 0.5, 1.2),
			CFrame.new(0, 0.05, -0.5),
			Color3.fromRGB(210, 214, 222),
			Enum.Material.Metal
		)
		k.rod(0.12, 0.5, -1.3, DARK, Enum.Material.Metal)
		local tip = k.ball(
			Vector3.new(0.22, 0.22, 0.22),
			CFrame.new(0, 0, -1.6),
			Color3.fromRGB(255, 60, 60),
			Enum.Material.Neon
		)
		k.light(tip, Color3.fromRGB(255, 60, 60), 6)
	end,
	-- 8 Plasma Cutter
	[8] = function(k)
		k.box(
			Vector3.new(0.5, 0.55, 1.2),
			CFrame.new(0, 0.05, -0.5),
			Color3.fromRGB(40, 44, 60),
			Enum.Material.Metal
		)
		for i = 0, 2 do
			k.rod(0.17, 0.08, -0.25 - i * 0.3, Color3.fromRGB(80, 200, 255), Enum.Material.Neon)
		end
		local tip = k.rod(0.06, 0.7, -1.45, Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
		k.light(tip, Color3.fromRGB(90, 200, 255), 8)
	end,
	-- 9 Quantum Fist
	[9] = function(k)
		local core = k.ball(
			Vector3.new(1.05, 1.05, 1.05),
			CFrame.new(0, 0, -0.1),
			Color3.fromRGB(170, 90, 255),
			Enum.Material.ForceField
		)
		for i, a in { 0, math.pi / 3, -math.pi / 3 } do
			k.box(
				Vector3.new(1.35, 0.05, 0.05),
				CFrame.new(0, 0, -0.1) * CFrame.Angles(a, i * 0.7, 0),
				Color3.fromRGB(200, 140, 255),
				Enum.Material.Neon
			)
		end
		k.light(core, Color3.fromRGB(170, 90, 255), 8)
	end,
	-- 10 Freedom Fist
	[10] = function(k)
		local glove = k.ball(
			Vector3.new(1.0, 1.0, 1.15),
			CFrame.new(0, 0, -0.1),
			Color3.fromRGB(255, 205, 60),
			Enum.Material.Foil
		)
		for _, a in { 0, math.pi * 2 / 3, -math.pi * 2 / 3 } do
			k.box(
				Vector3.new(0.12, 0.12, 0.5),
				CFrame.Angles(0, 0, a) * CFrame.new(0, 0.55, -0.1) * CFrame.Angles(0.6, 0, 0),
				Color3.fromRGB(255, 240, 160),
				Enum.Material.Neon
			)
		end
		k.light(glove, Color3.fromRGB(255, 210, 90), 8)
	end,
}

local held: { [Player]: Model } = {}

local function clear(p: Player)
	local m = held[p]
	if m then
		m:Destroy()
		held[p] = nil
	end
end

local function build(p: Player)
	clear(p)
	local level = p:GetAttribute("Tools")
	local builder = typeof(level) == "number" and BUILD[level] or nil
	local character = p.Character
	if not builder or not character then
		return
	end
	local hand = character:FindFirstChild("RightHand")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local att = hand:FindFirstChild("RightGripAttachment")
	local grip = if att and att:IsA("Attachment")
		then att.WorldCFrame
		else hand.CFrame * CFrame.new(0, -0.15, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	local m = Instance.new("Model")
	m.Name = "HeldTool"
	local function finish(part: Part, at: CFrame, color: Color3, mat: Enum.Material?): Part
		part.Color = color
		part.Material = mat or Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.CFrame = grip * at
		local w = Instance.new("WeldConstraint")
		w.Part0 = hand
		w.Part1 = part
		w.Parent = part
		part.Parent = m
		return part
	end
	local kit: Kit = {
		box = function(size, at, color, mat)
			local part = Instance.new("Part")
			part.Size = size
			return finish(part, at, color, mat)
		end,
		rod = function(radius, length, z, color, mat)
			local part = Instance.new("Part")
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(length, radius * 2, radius * 2)
			-- (a cylinder's axis is its X: turn it to run along -Z out of the fist)
			return finish(part, CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0), color, mat)
		end,
		ball = function(size, at, color, mat)
			local part = Instance.new("Part")
			part.Size = size
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
			return finish(part, at, color, mat)
		end,
		light = function(part, color, range)
			local l = Instance.new("PointLight")
			l.Color = color
			l.Range = range
			l.Brightness = 1.2
			l.Shadows = false
			l.Parent = part
		end,
	}
	builder(kit)
	m.Parent = character
	held[p] = m
end

local function watch(p: Player)
	p:GetAttributeChangedSignal("Tools"):Connect(function()
		build(p)
	end)
	p.CharacterAdded:Connect(function(character)
		clear(p)
		-- (a re-applied avatar swaps the hand: build again on the new one)
		character.ChildAdded:Connect(function(c)
			if c.Name == "RightHand" then
				task.delay(0.2, build, p)
			end
		end)
		local hand = character:WaitForChild("RightHand", 10)
		if hand then
			task.wait(0.2)
			build(p)
		end
	end)
	if p.Character then
		build(p)
	end
end

function HeldTools.start()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
end

return HeldTools
