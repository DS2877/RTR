--!strict
-- 🪤 Bear traps, the genre's chase tool. While you carry loot you can drop up to Traps.PerCarry
-- traps behind you out on the street; a guard or another player who steps in one is stuck for
-- Traps.StuckSeconds. The Richest can't lock their base, so they get a defense instead: up to
-- Traps.RichestMax traps inside their own base (only intruders spring them).
-- A trap snaps shut once, and an unsprung one rusts away after a while.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local Vaults = require(Shared.Config.Vaults)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Bases = require(script.Parent.Bases)
local Movement = require(script.Parent.Movement)
local Guards = require(script.Parent.Guards)

local Traps = {}

local T = Economy.Traps

type Trap = {
	owner: Player,
	model: Model,
	jaws: { BasePart },
	pos: Vector3,
	expires: number,
	defense: boolean, -- the Richest's home trap
}

local traps: { Trap } = {}
local used: { [Player]: number } = {}
local carryStamp: { [Player]: number } = {}
local folder: Folder

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Metal
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- An open bear trap: a steel ring, a red trigger plate, two toothed jaws lying open.
local function build(pos: Vector3, defense: boolean): (Model, { BasePart })
	local model = Instance.new("Model")
	model.Name = "BearTrap"
	local flat = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	part(model, "Ring", Vector3.new(0.25, 4.2, 4.2), flat, rgb(70, 72, 80), Enum.PartType.Cylinder)
	local plate = part(
		model,
		"Plate",
		Vector3.new(0.3, 1.6, 1.6),
		flat + Vector3.new(0, 0.05, 0),
		rgb(220, 40, 40),
		Enum.PartType.Cylinder
	)
	plate.Material = Enum.Material.Neon
	local jaws = {}
	for side = -1, 1, 2 do
		local hinge = CFrame.new(pos + Vector3.new(0, 0.15, 0))
		local jaw = part(
			model,
			"Jaw",
			Vector3.new(4, 0.25, 1.6),
			hinge * CFrame.new(0, 0, side * 1.3),
			rgb(200, 204, 212)
		)
		for i = -1, 1 do
			part(
				model,
				"Tooth",
				Vector3.new(0.5, 0.5, 0.5),
				jaw.CFrame * CFrame.new(i * 1.2, 0.3, -side * 0.6),
				rgb(235, 235, 240)
			)
		end
		table.insert(jaws, jaw)
	end
	-- the Richest's traps glow gold, a thief's traps glow red (everyone can see them and jump)
	local glow = Instance.new("PointLight")
	glow.Color = if defense then rgb(255, 200, 60) else rgb(255, 60, 60)
	glow.Range = 8
	glow.Brightness = 1.2
	glow.Parent = plate
	model.PrimaryPart = plate
	model:SetAttribute("Defense", defense)
	model.Parent = folder
	return model, jaws
end

local function trapsLeft(player: Player): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local carry = s.carry
	if carry then
		if carryStamp[player] ~= carry.startedAt then
			carryStamp[player] = carry.startedAt
			used[player] = 0
		end
		return T.PerCarry - (used[player] or 0)
	end
	if s.isRichest then
		local n = 0
		for _, t in traps do
			if t.owner == player and t.defense then
				n += 1
			end
		end
		return T.RichestMax - n
	end
	return 0
end

local function sync(player: Player)
	player:SetAttribute("TrapsLeft", trapsLeft(player))
end

local function remove(t: Trap)
	local i = table.find(traps, t)
	if i then
		table.remove(traps, i)
	end
	t.model:Destroy()
end

-- SNAP: the jaws close on whoever stepped in.
local function snap(t: Trap)
	local i = table.find(traps, t)
	if i then
		table.remove(traps, i)
	end
	for _, jaw in t.jaws do
		local side = if jaw.Position.Z > t.pos.Z then 1 else -1
		jaw.CFrame = CFrame.new(t.pos + Vector3.new(0, 1, side * 0.2))
			* CFrame.Angles(side * math.rad(80), 0, 0)
	end
	task.delay(1.2, function()
		t.model:Destroy()
	end)
	if t.defense and t.owner.Parent == Players then
		sync(t.owner)
	end
end

-- Drop a trap at the player's feet. Returns why it failed (for the smoke test), or nil.
function Traps.place(player: Player): string?
	local s = State.get(player)
	local root = State.root(player)
	local h = State.humanoid(player)
	if not s or not root or not h or h.Health <= 0 or os.clock() < s.stunUntil then
		return "cannot"
	end
	local feet = root.Position - Vector3.new(0, h.HipHeight + root.Size.Y / 2 - 0.15, 0)
	local defense = false
	if s.carry then
		if feet.X < World.StreetStartX + 4 then
			return "street only" -- no traps in the plaza (the safe zone) or in bases
		end
	elseif s.isRichest and s.base and Bases.contains(s.base, feet) then
		defense = true
	else
		return "not allowed"
	end
	if trapsLeft(player) <= 0 then
		return "none left"
	end
	for _, t in traps do
		if (t.pos - feet).Magnitude < 4 then
			return "too close"
		end
	end
	if not defense then
		used[player] = (used[player] or 0) + 1
	end
	local model, jaws = build(feet, defense)
	table.insert(traps, {
		owner = player,
		model = model,
		jaws = jaws,
		pos = feet,
		expires = os.clock() + (if defense then T.RichestLifeSeconds else T.LifeSeconds),
		defense = defense,
	})
	sync(player)
	return nil
end

local function near(t: Trap, pos: Vector3): boolean
	local d = pos - t.pos
	return Vector3.new(d.X, 0, d.Z).Magnitude < T.Radius and d.Y > -2 and d.Y < 6
end

local function check()
	local now = os.clock()
	for i = #traps, 1, -1 do
		local t = traps[i]
		if not t then
			continue
		end
		local ownerState = State.get(t.owner)
		if now > t.expires or (t.defense and (not ownerState or not ownerState.isRichest)) then
			remove(t)
			if ownerState then
				sync(t.owner)
			end
			continue
		end
		local sprung = false
		if not t.defense then
			for _, g in Guards.all() do
				if now >= g.stunnedUntil and near(t, g.root.Position) then
					Guards.stun(g, T.StuckSeconds)
					Net.notice(t.owner, "🪤 Your trap caught " .. Vaults[g.vault].guardName .. "!", "good")
					sprung = true
					break
				end
			end
		end
		if not sprung then
			for player, s in State.all() do
				local r = State.root(player)
				if player ~= t.owner and r and now >= s.stunUntil and near(t, r.Position) then
					Movement.stun(player, T.StuckSeconds)
					Net.notice(player, "🪤 You stepped in " .. t.owner.DisplayName .. "'s trap!", "bad")
					Net.notice(t.owner, "🪤 Your trap caught " .. player.DisplayName .. "!", "good")
					sprung = true
					break
				end
			end
		end
		if sprung then
			snap(t)
		end
	end
end

-- Exposed for the smoke test.
Traps.check = check
Traps.all = function(): { Trap }
	return traps
end

function Traps.start()
	folder = Instance.new("Folder")
	folder.Name = "Traps"
	folder.Parent = workspace
	local limit = RateLimit.new(2, 3)
	Net.on(Remotes.Names.PlaceTrap, function(player)
		if limit(player) then
			local why = Traps.place(player)
			if why == "street only" then
				Net.notice(player, "🪤 Traps only work out on the street!", "bad")
			elseif why == "none left" then
				Net.notice(player, "🪤 No traps left!", "bad")
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(check)
			if not ok then
				warn("traps check failed: " .. tostring(err))
			end
		end
	end)
	-- keep the TRAP button's count right (new carry = fresh traps, crown won / lost)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in State.all() do
				local n = trapsLeft(player)
				if player:GetAttribute("TrapsLeft") ~= n then
					player:SetAttribute("TrapsLeft", n)
				end
			end
		end
	end)
end

function Traps.onLeaving(player: Player)
	for i = #traps, 1, -1 do
		local t = traps[i]
		if t and t.owner == player then
			remove(t)
		end
	end
	used[player] = nil
	carryStamp[player] = nil
end

return Traps
