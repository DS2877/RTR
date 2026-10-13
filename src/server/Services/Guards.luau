--!strict
-- One guard per zone, like the genre: it SLEEPS beside the crates (💤) and WAKES when someone
-- steals one. Then it chases that thief through its zone and gives up at the zone's border (the
-- zone's gate stops it too), walks home and falls asleep again. Touch = caught (the crate goes
-- back, short stun). Each guard fits its zone (a guard dog in the suburbs, a butler at the pool
-- villas, a robot in the bank vault...) and they get bigger and faster farther out.
-- People are real R15 rigs with Roblox's run/idle animations; animals and machines are built
-- from parts and walked by a rigless Humanoid. During a GUARD STRIKE every guard keeps sleeping.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Vaults = require(Shared.Config.Vaults)
local World = require(Shared.Config.World)
local Remotes = require(Shared.Remotes)
local Progression = require(Shared.Progression)
local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Carry = require(script.Parent.Carry)
local Events = require(script.Parent.Events)
local Rig = require(script.Parent.Parent.Util.Rig)

local Guards = {}

type Guard = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	home: CFrame,
	vault: number,
	zone: CFrame, -- the zone's origin (its start on the corridor center line)
	target: Player?,
	mode: string, -- "sleep" | "chase" | "return"
	tag: TextLabel,
	reach: number, -- how close it must get to catch you
	stunnedUntil: number, -- stuck in a trap
	person: boolean, -- an R15 rig (animated) or a part-built creature
}

local guards: { Guard } = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

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
	p.Material = material or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = model
	return p
end

-- Rigidly attached body part of a creature.
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

-- The floating tag (💤 while asleep, ‼️ while chasing), sized in studs so it shrinks with distance.
local function makeTag(parent: BasePart, height: number): TextLabel
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(5, 0, 1.6, 0)
	bb.StudsOffset = Vector3.new(0, height, 0)
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	bb.Parent = parent
	local l = Instance.new("TextLabel")
	l.Name = "Tag"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = ""
	l.TextColor3 = Color3.new(1, 1, 1)
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Parent = l
	l.Parent = bb
	return l
end

local function setupHumanoid(humanoid: Humanoid, vaultIndex: number)
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
end

-- ===== people (R15) =====
type Outfit = { skin: Color3, torso: Color3, legs: Color3, hat: string?, extra: string? }
local OUTFITS: { [string]: Outfit } = {
	butler = { skin = rgb(255, 205, 160), torso = rgb(25, 25, 30), legs = rgb(25, 25, 30), extra = "bowtie" },
	security = {
		skin = rgb(245, 205, 55),
		torso = rgb(30, 40, 80),
		legs = rgb(25, 30, 60),
		hat = "cap",
		extra = "badge",
	},
	captain = {
		skin = rgb(255, 205, 160),
		torso = rgb(245, 245, 250),
		legs = rgb(245, 245, 250),
		hat = "captain",
	},
	croupier = {
		skin = rgb(255, 205, 160),
		torso = rgb(170, 20, 35),
		legs = rgb(20, 20, 24),
		hat = "visor",
		extra = "vest",
	},
	billionaire = {
		skin = rgb(255, 205, 160),
		torso = rgb(255, 200, 40),
		legs = rgb(30, 30, 36),
		hat = "top",
		extra = "chain",
	},
}

local function buildPerson(kind: string, vaultIndex: number, home: CFrame): Guard?
	local outfit = OUTFITS[kind]
	if not outfit then
		return nil
	end
	local rig = Rig.build(
		"guard_" .. kind,
		{ head = outfit.skin, torso = outfit.torso, arms = outfit.torso, legs = outfit.legs }
	)
	if not rig then
		return nil
	end
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local head = rig:FindFirstChild("Head") :: BasePart?
	local chest = rig:FindFirstChild("UpperTorso") :: BasePart?
	if not root or not humanoid or not head or not chest then
		rig:Destroy()
		return nil
	end
	local top = head.Size.Y / 2
	local hf = -head.Size.Z / 2
	local front = -chest.Size.Z / 2 - 0.04
	local function onHead(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?
	)
		Rig.attach(head, newPart(rig, name, size, color, material), offset)
	end
	local function onChest(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material?
	)
		Rig.attach(chest, newPart(rig, name, size, color, material), offset)
	end
	onHead(
		"Shades",
		Vector3.new(1.05, 0.28, 0.1),
		CFrame.new(0, 0.12, hf - 0.04),
		rgb(15, 15, 18),
		Enum.Material.Glass
	)
	if outfit.hat == "cap" then
		onHead("Cap", Vector3.new(1.3, 0.45, 1.3), CFrame.new(0, top + 0.12, 0), outfit.torso)
		onHead("Brim", Vector3.new(1.3, 0.12, 0.6), CFrame.new(0, top - 0.05, hf - 0.25), outfit.torso)
	elseif outfit.hat == "captain" then
		onHead("CaptainHat", Vector3.new(1.4, 0.5, 1.4), CFrame.new(0, top + 0.2, 0), rgb(255, 255, 255))
		onHead("CaptainBrim", Vector3.new(1.4, 0.12, 0.6), CFrame.new(0, top, hf - 0.25), rgb(20, 30, 80))
		onHead(
			"CaptainBadge",
			Vector3.new(0.4, 0.3, 0.1),
			CFrame.new(0, top + 0.25, hf - 0.04),
			rgb(255, 200, 40)
		)
	elseif outfit.hat == "visor" then
		onHead(
			"Visor",
			Vector3.new(1.3, 0.12, 0.8),
			CFrame.new(0, top - 0.1, hf - 0.3),
			rgb(40, 180, 90),
			Enum.Material.Glass
		)
	elseif outfit.hat == "top" then
		onHead("HatBrim", Vector3.new(1.7, 0.15, 1.7), CFrame.new(0, top + 0.05, 0), rgb(20, 20, 25))
		onHead("TopHat", Vector3.new(1.1, 1.3, 1.1), CFrame.new(0, top + 0.75, 0), rgb(20, 20, 25))
		onHead("HatBand", Vector3.new(1.15, 0.2, 1.15), CFrame.new(0, top + 0.25, 0), rgb(255, 200, 40))
	end
	if outfit.extra == "bowtie" then
		onChest("Shirt", Vector3.new(0.7, 1.4, 0.08), CFrame.new(0, 0.2, front), rgb(250, 250, 250))
		onChest("BowTie", Vector3.new(0.6, 0.25, 0.12), CFrame.new(0, 0.75, front - 0.04), rgb(20, 20, 24))
	elseif outfit.extra == "badge" then
		onChest("Badge", Vector3.new(0.35, 0.35, 0.08), CFrame.new(0.5, 0.45, front), rgb(255, 205, 40))
	elseif outfit.extra == "vest" then
		onChest("Vest", Vector3.new(1.6, 1.4, 0.08), CFrame.new(0, 0, front), rgb(20, 20, 24))
	elseif outfit.extra == "chain" then
		onChest(
			"Chain",
			Vector3.new(1.1, 0.15, 0.1),
			CFrame.new(0, 0.45, front - 0.04),
			rgb(255, 230, 120),
			Enum.Material.Neon
		)
	end
	rig.Name = "Guard"
	rig:SetAttribute("Vault", vaultIndex)
	rig:SetAttribute("Rig", "R15")
	rig:SetAttribute("Kind", kind)
	rig:ScaleTo(Vaults[vaultIndex].guardScale)
	rig:PivotTo(home)
	setupHumanoid(humanoid, vaultIndex)
	local tag = makeTag(head, 2.6)
	rig.Parent = workspace:FindFirstChild("Guards") or workspace
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	Rig.setPose(humanoid, "Idle")
	return {
		model = rig,
		humanoid = humanoid,
		root = root,
		home = home,
		vault = vaultIndex,
		zone = home,
		target = nil,
		mode = "sleep",
		tag = tag,
		reach = 4.5 * Vaults[vaultIndex].guardScale,
		stunnedUntil = 0,
		person = true,
	}
end

-- ===== animals and machines (parts on an invisible root) =====
local function buildCreature(kind: string, vaultIndex: number, home: CFrame): Guard
	local S = Vaults[vaultIndex].guardScale
	local model = Instance.new("Model")
	model.Name = "Guard"
	model:SetAttribute("Vault", vaultIndex)
	model:SetAttribute("Rig", "Creature")
	model:SetAttribute("Kind", kind)
	local hip = (if kind == "dog" then 1.6 elseif kind == "ai" then 5 else 3) * S
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2) * S
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = home * CFrame.new(0, hip + S - 4, 0)
	root.Parent = model
	model.PrimaryPart = root
	local function piece(
		name: string,
		size: Vector3,
		offset: Vector3,
		color: Color3,
		material: Enum.Material?
	): Part
		return weld(model, root, name, size * S, CFrame.new(offset * S), color, material)
	end
	local head: BasePart
	if kind == "dog" then
		-- a stocky guard dog: black + tan, pointy ears, a spiked collar
		local black, tan = rgb(35, 30, 30), rgb(190, 120, 60)
		piece("Body", Vector3.new(2.2, 2, 4.4), Vector3.new(0, 0.4, 0.4), black)
		piece("Chest", Vector3.new(2, 1.4, 1), Vector3.new(0, 0, -1.6), tan)
		head = piece("Head", Vector3.new(1.8, 1.7, 1.9), Vector3.new(0, 1.6, -2.4), black)
		piece("Snout", Vector3.new(1.1, 0.9, 1.2), Vector3.new(0, 1.2, -3.8), tan)
		piece("Nose", Vector3.new(0.5, 0.4, 0.3), Vector3.new(0, 1.5, -4.4), rgb(15, 15, 15))
		for _, x in { -0.6, 0.6 } do
			piece("Ear", Vector3.new(0.4, 0.9, 0.3), Vector3.new(x, 2.8, -2.2), black)
			piece(
				"Eye",
				Vector3.new(0.3, 0.3, 0.1),
				Vector3.new(x * 0.8, 1.9, -3.36),
				rgb(255, 230, 80),
				Enum.Material.Neon
			)
		end
		piece("Collar", Vector3.new(1.9, 0.35, 0.6), Vector3.new(0, 0.9, -1.8), rgb(200, 30, 40))
		for _, x in { -0.7, 0.7 } do
			for _, z in { -1.4, 2 } do
				piece("Leg", Vector3.new(0.6, 1.8, 0.6), Vector3.new(x, -1.4, z), black)
				piece("Paw", Vector3.new(0.7, 0.3, 0.8), Vector3.new(x, -2.3, z - 0.1), tan)
			end
		end
		piece("Tail", Vector3.new(0.3, 0.3, 1.4), Vector3.new(0, 1.3, 3), black)
	elseif kind == "robot" then
		-- a boxy steel robot with a green visor and a laser in its chest
		local steel, dark = rgb(170, 176, 186), rgb(70, 76, 86)
		piece("Torso", Vector3.new(3, 3, 2), Vector3.new(0, 1, 0), steel)
		piece(
			"Core",
			Vector3.new(1, 1, 0.2),
			Vector3.new(0, 1.2, -1.05),
			rgb(70, 255, 120),
			Enum.Material.Neon
		)
		head = piece("Head", Vector3.new(2, 1.6, 1.8), Vector3.new(0, 3.4, 0), steel)
		piece(
			"Visor",
			Vector3.new(1.7, 0.45, 0.2),
			Vector3.new(0, 3.5, -0.95),
			rgb(70, 255, 120),
			Enum.Material.Neon
		)
		piece("Antenna", Vector3.new(0.2, 1, 0.2), Vector3.new(0, 4.7, 0), dark)
		for _, x in { -1.9, 1.9 } do
			piece("Arm", Vector3.new(0.8, 2.6, 0.8), Vector3.new(x, 0.8, 0), dark)
			piece("Hand", Vector3.new(1, 0.6, 1), Vector3.new(x, -0.7, 0), steel)
		end
		for _, x in { -0.8, 0.8 } do
			piece("Leg", Vector3.new(0.9, 3, 0.9), Vector3.new(x, -2, 0), dark)
			piece("Foot", Vector3.new(1.1, 0.4, 1.4), Vector3.new(x, -3.3, -0.2), steel)
		end
	else
		-- the A.I. sentinel: a floating purple drone with one glowing eye and fins
		local shell = rgb(60, 40, 110)
		local body = piece("Body", Vector3.new(4, 4, 4), Vector3.new(0, 0, 0), shell)
		body.Shape = Enum.PartType.Ball
		head = body
		piece("EyeRing", Vector3.new(2.2, 2.2, 0.4), Vector3.new(0, 0.2, -1.85), rgb(20, 10, 40))
		local eye = piece(
			"Eye",
			Vector3.new(1.4, 1.4, 0.5),
			Vector3.new(0, 0.2, -2),
			rgb(255, 80, 230),
			Enum.Material.Neon
		)
		eye.Shape = Enum.PartType.Ball
		for _, x in { -2.4, 2.4 } do
			piece(
				"Fin",
				Vector3.new(0.3, 2.4, 2.6),
				Vector3.new(x, 0, 0.4),
				rgb(190, 110, 255),
				Enum.Material.Neon
			)
		end
		piece(
			"Thruster",
			Vector3.new(1.4, 0.6, 1.4),
			Vector3.new(0, -2.2, 0),
			rgb(120, 220, 255),
			Enum.Material.Neon
		)
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = hip
	setupHumanoid(humanoid, vaultIndex)
	humanoid.Parent = model
	local tag = makeTag(head, 2.5 * S)
	model.Parent = workspace:FindFirstChild("Guards") or workspace
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return {
		model = model,
		humanoid = humanoid,
		root = root,
		home = home,
		vault = vaultIndex,
		zone = home,
		target = nil,
		mode = "sleep",
		tag = tag,
		reach = (if kind == "dog" then 4.5 else 5) * S,
		stunnedUntil = 0,
		person = false,
	}
end

local function setTag(g: Guard, mode: string)
	g.mode = mode
	if mode == "chase" then
		g.tag.Text = "‼️"
		g.tag.TextColor3 = rgb(255, 70, 70)
	elseif mode == "sleep" then
		g.tag.Text = "💤"
		g.tag.TextColor3 = rgb(150, 210, 255)
	else
		g.tag.Text = ""
	end
	g.model:SetAttribute("Chasing", mode == "chase")
	g.model:SetAttribute("Asleep", mode == "sleep")
end

-- Is `pos` inside guard g's zone? (it never chases anyone out of it)
local function inZone(g: Guard, pos: Vector3): boolean
	local l = g.zone:PointToObjectSpace(pos)
	local depth = -l.Z
	return depth >= 0 and depth <= World.VaultSpacing and math.abs(l.X) <= World.ZoneHalfWidth + 2
end

-- Someone stole a crate in zone `vaultIndex`: its guard wakes up and chases them.
function Guards.alert(vaultIndex: number, thief: Player)
	if Events.active("GuardStrike") then
		return -- everyone's asleep
	end
	for _, g in guards do
		if g.vault == vaultIndex and g.mode ~= "chase" then
			g.target = thief
			setTag(g, "chase")
			Net.fire(thief, Remotes.Names.Alarm, Vaults[vaultIndex].guardName)
		end
	end
end

-- A trap snapped shut on this guard.
function Guards.stun(g: Guard, seconds: number)
	g.stunnedUntil = os.clock() + seconds
	g.humanoid:MoveTo(g.root.Position)
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
	local pos = g.root.Position
	if os.clock() < g.stunnedUntil then
		return
	end
	if Events.active("GuardStrike") and g.mode ~= "sleep" then
		g.target = nil
		setTag(g, "return")
	end

	if g.mode == "chase" then
		local target = g.target
		local s = target and State.get(target)
		local r = target and State.root(target)
		if
			not target
			or not s
			or not s.carry
			or not r
			or target.Parent ~= Players
			or not inZone(g, r.Position)
		then
			-- got away (out of the zone) or dropped it: back to bed
			g.target = nil
			setTag(g, "return")
		else
			g.humanoid:MoveTo(r.Position)
			local flat = Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z).Magnitude
			if flat < g.reach and math.abs(r.Position.Y - pos.Y) < 12 then
				Carry.caught(target, Vaults[g.vault].guardName, tooSlowFor(g, target))
				g.target = nil
				setTag(g, "return")
			end
		end
	end
	if g.mode == "return" then
		local home = g.home.Position
		if Vector3.new(home.X - pos.X, 0, home.Z - pos.Z).Magnitude < 4 then
			setTag(g, "sleep")
		else
			g.humanoid:MoveTo(home)
		end
	end
end

-- People: run animation while moving (faster legs for faster guards), idle when standing.
local function pose(g: Guard)
	if not g.person then
		return
	end
	local v = g.root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if speed > 1.5 then
		Rig.setPose(g.humanoid, "Run", math.clamp(speed / 18, 0.7, 2.2))
	else
		Rig.setPose(g.humanoid, "Idle")
	end
end

-- Exposed for the smoke test and traps.
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
		local home: CFrame = v.guardSpawns[1]
		local g = buildPerson(def.guard, v.index, home)
			or buildCreature(if OUTFITS[def.guard] then "robot" else def.guard, v.index, home)
		g.zone = v.origin
		setTag(g, "sleep")
		table.insert(guards, g)
	end
	task.spawn(function()
		while true do
			task.wait(0.12)
			for _, g in guards do
				local ok, err = pcall(step, g)
				if not ok then
					warn("guard step failed: " .. tostring(err))
				end
				pcall(pose, g)
			end
		end
	end)
end

return Guards
