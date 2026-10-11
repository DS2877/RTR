--!strict
-- Vault guards: chunky security NPCs. They patrol their vault and chase anyone carrying loot
-- nearby. Touch = caught (loot goes back, short stun). Faster guards on richer vaults.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vaults = require(ReplicatedStorage.Shared.Config.Vaults)
local State = require(script.Parent.Parent.State)
local Carry = require(script.Parent.Carry)

local Guards = {}

type Guard = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	home: CFrame,
	vault: number,
	center: Vector3,
	target: Player?,
	nextPatrol: number,
}

local guards: { Guard } = {}
local rng = Random.new()

local function limb(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = root.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	p.Parent = model
	return p
end

local function buildGuard(vaultIndex: number, home: CFrame, trim: Color3): Guard
	local model = Instance.new("Model")
	model.Name = "Guard"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = home
	root.Parent = model
	model.PrimaryPart = root

	local suit = Color3.fromRGB(25, 25, 30)
	local skin = Color3.fromRGB(255, 205, 160)
	limb(model, root, "Torso", Vector3.new(2.4, 2.4, 1.3), CFrame.new(0, 0, 0), suit)
	limb(model, root, "Tie", Vector3.new(0.4, 1.6, 0.1), CFrame.new(0, 0.2, -0.68), trim)
	limb(model, root, "Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 2.05, 0), skin)
	limb(
		model,
		root,
		"Shades",
		Vector3.new(1.4, 0.4, 0.1),
		CFrame.new(0, 2.25, -0.82),
		Color3.new(0, 0, 0),
		Enum.Material.Glass
	)
	limb(model, root, "Cap", Vector3.new(1.8, 0.5, 1.8), CFrame.new(0, 3.0, 0), suit)
	limb(model, root, "LegL", Vector3.new(1, 2.4, 1), CFrame.new(-0.6, -2.3, 0), suit)
	limb(model, root, "LegR", Vector3.new(1, 2.4, 1), CFrame.new(0.6, -2.3, 0), suit)
	limb(model, root, "ArmL", Vector3.new(0.9, 2.2, 0.9), CFrame.new(-1.7, 0, 0), suit)
	limb(model, root, "ArmR", Vector3.new(0.9, 2.2, 0.9), CFrame.new(1.7, 0, 0), suit)

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2.5
	humanoid.WalkSpeed = Vaults[vaultIndex].guardSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	for _, st in
		{
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Dead,
			Enum.HumanoidStateType.Seated,
		}
	do
		humanoid:SetStateEnabled(st, false)
	end
	humanoid.Parent = model

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(110, 26)
	bb.StudsOffset = Vector3.new(0, 4.6, 0)
	bb.MaxDistance = 120
	bb.Parent = root
	local l = Instance.new("TextLabel")
	l.Name = "Tag"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = "GUARD"
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Parent = l
	l.Parent = bb

	model.Parent = workspace:FindFirstChild("Guards") or workspace
	root:SetNetworkOwner(nil)
	return {
		model = model,
		humanoid = humanoid,
		root = root,
		home = home,
		vault = vaultIndex,
		center = home.Position,
		target = nil,
		nextPatrol = 0,
	}
end

local function setTag(g: Guard, chasing: boolean)
	local tag = g.root:FindFirstChild("BillboardGui") and (g.root :: any).BillboardGui:FindFirstChild("Tag")
	if tag then
		tag.Text = if chasing then "❗ STOP THIEF ❗" else "GUARD"
		tag.TextColor3 = if chasing then Color3.fromRGB(255, 70, 70) else Color3.new(1, 1, 1)
	end
end

local function step(g: Guard)
	local def = Vaults[g.vault]
	local pos = g.root.Position
	-- keep the current target while still valid
	local target = g.target
	if target then
		local s = State.get(target)
		local r = State.root(target)
		if
			not s
			or not s.carry
			or not r
			or (r.Position - g.center).Magnitude > def.leash
			or target.Parent ~= Players
		then
			target = nil
		end
	end
	if not target then
		local best, bestDist = nil, math.huge
		for player, s in State.all() do
			if s.carry then
				local r = State.root(player)
				if r then
					local fromVault = (r.Position - g.center).Magnitude
					local d = (r.Position - pos).Magnitude
					if fromVault <= def.aggro and d < bestDist then
						best, bestDist = player, d
					end
				end
			end
		end
		target = best
	end
	if target ~= g.target then
		setTag(g, target ~= nil)
	end
	g.target = target

	if target then
		local r = State.root(target)
		if r then
			g.humanoid:MoveTo(r.Position)
			local flat = Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z).Magnitude
			if flat < 4.5 and math.abs(r.Position.Y - pos.Y) < 8 then
				Carry.caught(target, "a guard")
				g.target = nil
				setTag(g, false)
			end
		end
	else
		local t = os.clock()
		if (pos - g.home.Position).Magnitude > 30 or t >= g.nextPatrol then
			g.nextPatrol = t + rng:NextNumber(3, 6)
			local patrol = g.home * CFrame.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-10, 18))
			g.humanoid:MoveTo(patrol.Position)
		end
	end
end

function Guards.start(worldInfo: any)
	local folder = Instance.new("Folder")
	folder.Name = "Guards"
	folder.Parent = workspace
	for _, v in worldInfo.vaults do
		local def = Vaults[v.index]
		local trim = Color3.fromRGB(def.trim[1], def.trim[2], def.trim[3])
		for _, cf in v.guardSpawns do
			local g = buildGuard(v.index, cf, trim)
			g.center = v.center
			table.insert(guards, g)
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.12)
			for _, g in guards do
				local ok, err = pcall(step, g)
				if not ok then
					warn("guard step failed: " .. tostring(err))
				end
			end
		end
	end)
end

return Guards
