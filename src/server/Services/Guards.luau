--!strict
-- Vault guards: chunky security NPCs. They patrol their vault and chase anyone carrying loot
-- nearby. Touch = caught (loot goes back, short stun). Faster guards on richer vaults.
-- Limbs hang on Motor6Ds so clients can swing them (walk animation in Controllers/WorldFX).
-- During a GUARD STRIKE event they fall asleep at home and catch nobody.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Vaults = require(Shared.Config.Vaults)
local Remotes = require(Shared.Remotes)
local Progression = require(Shared.Progression)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Carry = require(script.Parent.Carry)
local Events = require(script.Parent.Events)

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
	tag: TextLabel,
	asleep: boolean,
}

local guards: { Guard } = {}
local rng = Random.new()

local SUIT = Color3.fromRGB(28, 28, 36)
local SKIN = Color3.fromRGB(255, 205, 160)

local function newPart(
	model: Model,
	name: string,
	size: Vector3,
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
	p.Parent = model
	return p
end

-- Rigidly attached detail.
local function weld(
	model: Model,
	to: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = newPart(model, name, size, color, material)
	p.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
	return p
end

-- A limb that swings around `joint` (offset from the root, at the top of the limb).
local function limb(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	joint: Vector3,
	color: Color3
): Part
	local p = newPart(model, name, size, color)
	p.CFrame = root.CFrame * CFrame.new(joint) * CFrame.new(0, -size.Y / 2, 0)
	local m = Instance.new("Motor6D")
	m.Name = name .. "Joint"
	m.Part0 = root
	m.Part1 = p
	m.C0 = CFrame.new(joint)
	m.C1 = CFrame.new(0, size.Y / 2, 0)
	m.Parent = root
	return p
end

local function buildGuard(vaultIndex: number, home: CFrame, trim: Color3): Guard
	local model = Instance.new("Model")
	model.Name = "Guard"
	model:SetAttribute("Vault", vaultIndex)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = home
	root.Parent = model
	model.PrimaryPart = root

	local torso = weld(model, root, "Torso", Vector3.new(2.4, 2.4, 1.3), CFrame.new(), SUIT)
	weld(model, torso, "Shirt", Vector3.new(0.9, 2.2, 0.1), CFrame.new(0, 0.05, -0.66), Color3.new(1, 1, 1))
	weld(model, torso, "Tie", Vector3.new(0.35, 1.7, 0.12), CFrame.new(0, 0.1, -0.7), trim)
	weld(
		model,
		torso,
		"Belt",
		Vector3.new(2.5, 0.35, 1.4),
		CFrame.new(0, -1.05, 0),
		Color3.fromRGB(15, 15, 18)
	)
	weld(
		model,
		torso,
		"Badge",
		Vector3.new(0.45, 0.45, 0.1),
		CFrame.new(0.7, 0.6, -0.7),
		Color3.fromRGB(255, 205, 40),
		Enum.Material.Foil
	)
	local head = weld(model, root, "Head", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 1.95, 0), SKIN)
	weld(
		model,
		head,
		"Shades",
		Vector3.new(1.45, 0.4, 0.12),
		CFrame.new(0, 0.15, -0.76),
		Color3.new(0, 0, 0),
		Enum.Material.Glass
	)
	weld(model, head, "Cap", Vector3.new(1.7, 0.5, 1.7), CFrame.new(0, 0.9, 0), SUIT)
	weld(model, head, "Brim", Vector3.new(1.7, 0.15, 0.7), CFrame.new(0, 0.7, -1.05), SUIT)
	weld(model, head, "CapBand", Vector3.new(1.75, 0.18, 1.75), CFrame.new(0, 0.72, 0), trim)
	weld(
		model,
		head,
		"Earpiece",
		Vector3.new(0.15, 0.4, 0.15),
		CFrame.new(0.78, -0.1, 0),
		Color3.new(0, 0, 0)
	)

	limb(model, root, "LegL", Vector3.new(1, 2.5, 1), Vector3.new(-0.6, -1.0, 0), SUIT)
	limb(model, root, "LegR", Vector3.new(1, 2.5, 1), Vector3.new(0.6, -1.0, 0), SUIT)
	limb(model, root, "ArmL", Vector3.new(0.85, 2.2, 0.85), Vector3.new(-1.65, 1.0, 0), SUIT)
	limb(model, root, "ArmR", Vector3.new(0.85, 2.2, 0.85), Vector3.new(1.65, 1.0, 0), SUIT)

	-- Rigless NPC: R15 mode makes the Humanoid hover the root HipHeight studs above the floor
	-- (R6 mode looks for leg parts, finds none and trips over).
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
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
			Enum.HumanoidStateType.Climbing,
		}
	do
		humanoid:SetStateEnabled(st, false)
	end
	humanoid.Parent = model

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(130, 30)
	bb.StudsOffset = Vector3.new(0, 4.8, 0)
	bb.MaxDistance = 120
	bb.LightInfluence = 0
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
	pcall(function()
		root:SetNetworkOwner(nil) -- the server moves guards (pcall: headless smoke tests have no physics)
	end)
	return {
		model = model,
		humanoid = humanoid,
		root = root,
		home = home,
		vault = vaultIndex,
		center = home.Position,
		target = nil,
		nextPatrol = 0,
		tag = l,
		asleep = false,
	}
end

local function setTag(g: Guard, mode: string)
	g.tag.Text = if mode == "chase"
		then "❗ STOP THIEF ❗"
		elseif mode == "sleep" then "💤 ZZZ"
		else "GUARD"
	g.tag.TextColor3 = if mode == "chase"
		then Color3.fromRGB(255, 70, 70)
		elseif mode == "sleep" then Color3.fromRGB(150, 210, 255)
		else Color3.new(1, 1, 1)
	g.model:SetAttribute("Chasing", mode == "chase")
	g.model:SetAttribute("Asleep", mode == "sleep")
end

-- The speed you need to outrun this guard with what you carry (for the "too slow" offer).
local function tooSlowFor(g: Guard, player: Player): boolean
	local s = State.get(player)
	if not s then
		return false
	end
	return Progression.walkSpeed(s.data.Speed) * 0.85 < Vaults[g.vault].guardSpeed
end

local function step(g: Guard)
	local def = Vaults[g.vault]
	local pos = g.root.Position

	if Events.active("GuardStrike") then
		if not g.asleep then
			g.asleep = true
			g.target = nil
			setTag(g, "sleep")
			g.humanoid:MoveTo(g.home.Position)
		end
		return
	elseif g.asleep then
		g.asleep = false
		setTag(g, "idle")
	end

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
		if target then
			Net.fire(target, Remotes.Names.Alarm, def.name)
		end
	end
	if target ~= g.target then
		setTag(g, if target then "chase" else "idle")
	end
	g.target = target

	if target then
		local r = State.root(target)
		if r then
			g.humanoid:MoveTo(r.Position)
			local flat = Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z).Magnitude
			if flat < 4.5 and math.abs(r.Position.Y - pos.Y) < 8 then
				Carry.caught(target, "a guard", tooSlowFor(g, target))
				g.target = nil
				setTag(g, "idle")
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

-- Exposed for the smoke test.
Guards.step = step
Guards.all = function(): { Guard }
	return guards
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
