--!strict
-- CELL RAIDS: by day anyone can walk into your cell and steal ONE find from your Stash chest
-- (hold STEAL as long as your Lock says), then carry it home: slower and glowing. Hit the thief
-- and it goes back. Trap = the thief slips on soap; Alarm = you get a notice and a beam to them.
-- Sold finds are always safe; unsold ones (slots or Stash) are always at risk.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PvP = require(Shared.Config.PvP)
local Economy = require(Shared.Config.Economy)
local Upgrades = require(Shared.Config.Upgrades)
local Finds = require(Shared.Config.Finds)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)
local Cells = require(script.Parent.Cells)

local Raid = {}

local world: any = nil
Raid.isDay = function(): boolean
	return true
end

local holdStart: { [any]: { cell: number, at: number } } = {}
local trapUsed: { [number]: boolean } = {} -- cell -> trap already sprung today

local function findName(id: string): string
	local f = Finds.ById[id]
	return if f then f.emoji .. " " .. f.name else id
end

function Raid.lockSeconds(s: State.PlayerState): number
	return (Upgrades.Lock[s.data.Levels.Lock] or Upgrades.Lock[1]).value
end

function Raid.sendStash(player: Player)
	local s = State.get(player)
	if s then
		Net.fire(player, Remotes.Names.Stash, s.data.Stash)
	end
end

-- The prompt's hold time follows the owner's lock (owners skip it on their own client).
function Raid.refreshPrompt(player: Player)
	local s = State.get(player)
	if not s or not s.cell then
		return
	end
	local stash = Cells.record(s.cell).stash :: BasePart
	local prompt = stash:FindFirstChild("StashPrompt") :: ProximityPrompt?
	if prompt then
		prompt.HoldDuration = Raid.lockSeconds(s)
	end
	stash:SetAttribute("Owner", (player :: any).UserId)
end

-- Owner: move every find from your slots into the chest ("put"), or back ("take").
function Raid.stashCmd(player: Player, cmd: string): number
	local s = State.get(player)
	local pos = State.root(player)
	if not s or not s.cell or not pos then
		return 0
	end
	local stash = Cells.record(s.cell).stash :: BasePart
	if (stash.Position - pos).Magnitude > 14 then
		return 0
	end
	local moved = 0
	local data = s.data
	if cmd == "put" then
		while #data.Finds > 0 and #data.Stash < PvP.StashSize do
			table.insert(data.Stash, table.remove(data.Finds) :: string)
			moved += 1
		end
	elseif cmd == "take" then
		local slots = Progression.findSlots(data.Levels.FindSlots)
		while #data.Stash > 0 and #data.Finds < slots do
			table.insert(data.Finds, table.remove(data.Stash) :: string)
			moved += 1
		end
	end
	if moved > 0 then
		Net.fire(player, Remotes.Names.Finds, data.Finds)
		Raid.sendStash(player)
		Stats.sync(player)
	end
	return moved
end

local function setCarrying(thief: Player, on: boolean)
	if typeof(thief) ~= "Instance" then
		return
	end
	thief:SetAttribute("Carrying", on)
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if on then PvP.CarrySpeed else Economy.WalkSpeed
	end
	if character then
		local old = character:FindFirstChild("ThiefGlow")
		if old then
			old:Destroy()
		end
		if on then
			local h = Instance.new("Highlight")
			h.Name = "ThiefGlow"
			h.FillColor = Color3.fromRGB(255, 200, 40)
			h.FillTransparency = 0.6
			h.OutlineColor = Color3.fromRGB(255, 240, 120)
			h.Parent = character
		end
	end
end

local function deliver(thief: Player, ts: State.PlayerState)
	local c = ts.carrying :: any
	ts.carrying = nil
	setCarrying(thief, false)
	local slots = Progression.findSlots(ts.data.Levels.FindSlots)
	if #ts.data.Finds < slots then
		table.insert(ts.data.Finds, c.id)
		Net.fire(thief, Remotes.Names.Finds, ts.data.Finds)
	else
		table.insert(ts.data.Stash, c.id)
		Raid.sendStash(thief)
	end
	ts.data.Found[c.id] = true
	ts.data.Stats.Steals += 1
	Stats.sync(thief)
	Net.fire(thief, Remotes.Names.Raid, "home", "Heist complete! " .. findName(c.id) .. " is yours.", nil)
	Net.announce(
		string.format("%s stole a %s from %s!", thief.Name, findName(c.id), (c.owner :: any).Name),
		{ 255, 170, 60 },
		nil
	)
end

-- The stolen find goes back to its owner (thief hit, night fell, thief left).
function Raid.returnCarry(thief: Player, why: string)
	local ts = State.get(thief)
	local c = ts and ts.carrying
	if not ts or not c then
		return
	end
	local os_ = State.get(c.owner)
	if not os_ then
		-- the owner already left the server: the thief keeps it
		deliver(thief, ts)
		return
	end
	ts.carrying = nil
	setCarrying(thief, false)
	do
		table.insert(os_.data.Stash, c.id)
		Raid.sendStash(c.owner)
		Net.fire(
			c.owner,
			Remotes.Names.Raid,
			"dropped",
			"Your " .. findName(c.id) .. " is back in your Stash!",
			nil
		)
	end
	Net.fire(
		thief,
		Remotes.Names.Raid,
		"dropped",
		"You dropped the " .. findName(c.id) .. " (" .. why .. ")",
		nil
	)
end

-- Starts a steal (the hold began). Springs the trap and rings the alarm.
function Raid.beginSteal(thief: Player, cell: number)
	local owner = Cells.ownerOf(cell)
	local os_ = owner and State.get(owner)
	if not owner or not os_ or owner == thief or not Raid.isDay() then
		return
	end
	holdStart[thief] = { cell = cell, at = os.clock() }
	if os_.data.Levels.Trap > 1 and not trapUsed[cell] then
		trapUsed[cell] = true
		Net.fire(thief, Remotes.Names.Slip, PvP.TrapSeconds)
		Net.notice(thief, "🧼 SLIPPERY SOAP! It's a trap!", "bad")
		holdStart[thief] = nil -- the slip interrupts the hold
	end
	if os_.data.Levels.Alarm > 1 then
		Net.fire(
			owner,
			Remotes.Names.Raid,
			"alarm",
			"🔔 " .. thief.Name .. " is raiding your Stash!",
			(thief :: any).UserId
		)
	end
end

-- Returns a reason when the steal fails (also used by the smoke test).
function Raid.steal(thief: Player, cell: number, skipHold: boolean?): string?
	local ts = State.get(thief)
	local owner = Cells.ownerOf(cell)
	local os_ = owner and State.get(owner)
	if not ts or not owner or not os_ then
		return "no owner"
	end
	if owner == thief then
		return "own stash"
	end
	if not Raid.isDay() then
		return "night"
	end
	if ts.carrying then
		return "already carrying"
	end
	if not ts.cell then
		return "no cell"
	end
	local pos = State.root(thief)
	local stash = Cells.record(cell).stash :: BasePart
	if not pos or (stash.Position - pos).Magnitude > 14 then
		return "too far"
	end
	if not skipHold then
		local h = holdStart[thief]
		holdStart[thief] = nil
		if not h or h.cell ~= cell or os.clock() - h.at < Raid.lockSeconds(os_) - 0.35 then
			return "lock"
		end
	end
	if #os_.data.Stash == 0 then
		Net.notice(thief, "The Stash is empty!", "info")
		return "empty"
	end
	-- the most valuable find
	local best, bestValue = 1, -1
	for i, id in os_.data.Stash do
		local v = Progression.findValue(id)
		if v > bestValue then
			best, bestValue = i, v
		end
	end
	local id = table.remove(os_.data.Stash, best) :: string
	os_.data.Stats.Robbed += 1
	ts.carrying = { id = id, owner = owner }
	setCarrying(thief, true)
	Raid.sendStash(owner)
	Net.fire(
		thief,
		Remotes.Names.Raid,
		"carry",
		"You grabbed " .. findName(id) .. "! Carry it to YOUR cell!",
		nil
	)
	Net.fire(
		owner,
		Remotes.Names.Raid,
		"stolen",
		thief.Name .. " stole your " .. findName(id) .. "! Hit them!",
		(thief :: any).UserId
	)
	return nil
end

function Raid.tick()
	for player, s in State.all() do
		if s.carrying then
			local pos = State.root(player)
			if not Raid.isDay() then
				Raid.returnCarry(player, "the guards took it")
			elseif State.get(s.carrying.owner) == nil then
				-- the owner left: it's yours once you're home
				if pos and s.cell and Tunnel.cellAt(pos) == s.cell then
					deliver(player, s)
				end
			elseif pos and s.cell and Tunnel.cellAt(pos) == s.cell then
				deliver(player, s)
			end
		end
	end
end

function Raid.newDay()
	trapUsed = {}
end

function Raid.onLeaving(player: Player)
	Raid.returnCarry(player, "left")
	holdStart[player] = nil
	-- anyone carrying this player's find keeps going: it becomes theirs at home
end

function Raid.start(w: any)
	world = w
	for _, cell in world.cells do
		local prompt = cell.stash:FindFirstChild("StashPrompt") :: ProximityPrompt
		prompt.PromptButtonHoldBegan:Connect(function(player)
			local owner = Cells.ownerOf(cell.index)
			if owner and owner ~= player then
				Raid.beginSteal(player, cell.index)
			end
		end)
		prompt.Triggered:Connect(function(player)
			local owner = Cells.ownerOf(cell.index)
			if owner == player then
				Raid.sendStash(player)
				Net.fire(player, Remotes.Names.OpenStash)
			elseif owner then
				Raid.steal(player, cell.index)
			end
		end)
	end
	local limit = RateLimit.new(3, 5)
	Net.on(Remotes.Names.StashCmd, function(player, cmd)
		if limit(player) and (cmd == "put" or cmd == "take") then
			Raid.stashCmd(player, cmd)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			Raid.tick()
		end
	end)
end

return Raid
