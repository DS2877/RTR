--!strict
-- Night guard inspections: a guard with a flashlight walks to a cell door. 5 s warning (footsteps,
-- light under the door, the HIDE button). Safe = in bed AND the hole covered (Hideout). Caught =
-- you lose this night's unsold finds in your backpack (find slots), never progress or Noodles.
-- SNITCH: pay Noodles to tip off the guard about someone (guaranteed visit next night); the
-- target can BRIBE the guard during the warning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Cycle = require(Shared.Config.Cycle)
local Economy = require(Shared.Config.Economy)
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Build = require(script.Parent.Parent.Util.Build)
local Characters = require(script.Parent.Parent.Util.Characters)
local Breakout = require(script.Parent.Breakout)
local Stats = require(script.Parent.Stats)
local Hideout = require(script.Parent.Hideout)
local Cells = require(script.Parent.Cells)

local Guards = {}

Guards.isNight = function(): boolean
	return false
end

local active: { [any]: number } = {} -- player -> warning ends (os.clock)
local guardModel: Model? = nil

local function zoneValue(s: State.PlayerState): number
	return Zones[math.clamp(s.data.Zone, 1, #Zones)].rubble
end

function Guards.bribeCost(s: State.PlayerState): number
	return Cycle.BribeBlocks * zoneValue(s)
end

function Guards.snitchCost(target: State.PlayerState): number
	return Cycle.SnitchBlocks * zoneValue(target)
end

local function walkGuard(cell: number, seconds: number)
	local m = guardModel
	if not m then
		return
	end
	local frame = Tunnel.frame(cell)
	-- outside the door, in the corridor, looking in
	local door = (frame * CFrame.new(0, 0, World.CellDepth + 3)).Position
	local target = CFrame.lookAt(door, (frame * CFrame.new(0, 0, 5)).Position)
	local start = m:GetPivot()
	local value = Instance.new("CFrameValue")
	value.Value = start
	value.Changed:Connect(function(cf)
		m:PivotTo(cf)
	end)
	local duration = math.max(1, seconds - 0.5)
	local t = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Value = target,
	})
	-- legs and arms move while it walks (the idle takes over again when it arrives)
	local dist = (target.Position - start.Position).Magnitude
	if dist > 1 then
		Characters.setWalking(m, true, dist / duration)
	end
	t:Play()
	t.Completed:Connect(function()
		value:Destroy()
		Characters.setWalking(m, false)
	end)
end

-- Starts an inspection of this player (warning first). Returns false if not possible.
function Guards.inspect(player: Player): boolean
	local s = State.get(player)
	if not s or not s.cell or active[player] or Breakout.running(player) then
		return false
	end
	-- fair warning: the footsteps give you the base time PLUS the walk back from wherever you
	-- are in your tunnel (so you can always make it to bed if you hurry)
	local seconds = Cycle.InspectWarning
	local pos = State.root(player)
	local bed = Cells.record(s.cell).model:FindFirstChild("Mattress") :: BasePart?
	if pos and bed then
		seconds = math.clamp(
			Cycle.InspectWarning + (pos - bed.Position).Magnitude / Economy.WalkSpeed * 1.15,
			Cycle.InspectWarning,
			Cycle.InspectWarningMax
		)
	end
	seconds = math.ceil(seconds)
	active[player] = os.clock() + seconds
	local snitched = s.snitched
	Net.fire(player, Remotes.Names.Inspect, "warn", seconds, snitched)
	walkGuard(s.cell, seconds)
	task.delay(seconds, function()
		active[player] = nil
		local now = State.get(player)
		if not now then
			return
		end
		if not Guards.isNight() then
			-- morning came first: the guard went home
			Net.fire(player, Remotes.Names.Inspect, "safe", 0, false)
			return
		end
		now.snitched = false
		local bribed = now.bribed
		now.bribed = false
		if bribed or Hideout.isSafe(now) then
			Net.fire(player, Remotes.Names.Inspect, "safe", 0, false)
			Net.notice(player, "The guard sees a sleeping prisoner. Phew!", "good")
		else
			local spotted = now.hidden -- in bed, but the hole was showing
			local lost = #now.data.Finds
			now.data.Finds = {}
			Net.fire(player, Remotes.Names.Finds, now.data.Finds)
			Net.fire(player, Remotes.Names.Inspect, "caught", 0, false)
			Net.notice(
				player,
				(if spotted then "The guard spotted the hole in your wall! " else "")
					.. (
						if lost > 0
							then "CAUGHT! The guard took " .. lost .. " unsold finds."
							else "CAUGHT! Luckily your pockets were empty."
					),
				"bad"
			)
			Stats.sync(player)
		end
	end)
	return true
end

-- The inspection's HIDE button: into bed and the tapestry down, in one tap.
function Guards.hide(player: Player): boolean
	local s = State.get(player)
	if not s or not active[player] or os.clock() > active[player] then
		return false
	end
	Hideout.setCover(player, true)
	return Hideout.setHidden(player, true, true)
end

function Guards.bribe(player: Player): boolean
	local s = State.get(player)
	if not s or not active[player] or not s.snitched then
		return false
	end
	if s.bribed then
		return true -- (a double tap never pays twice)
	end
	local cost = Guards.bribeCost(s)
	if s.data.Noodles < cost then
		Net.notice(player, "Not enough Noodles to bribe the guard!", "bad")
		return false
	end
	s.data.Noodles -= cost
	s.bribed = true
	Stats.sync(player)
	Net.notice(player, "The guard pockets " .. Format.noodles(cost) .. " and walks away.", "info")
	return true
end

-- Returns a reason when refused.
function Guards.snitch(player: Player, userId: any): string?
	local s = State.get(player)
	if not s or typeof(userId) ~= "number" then
		return "bad args"
	end
	local target: Player? = nil
	for p in State.all() do
		if (p :: any).UserId == userId then
			target = p
		end
	end
	local ts = target and State.get(target)
	if not target or not ts or target == player then
		return "no target"
	end
	if ts.snitched then
		Net.notice(player, "The guard already knows about " .. target.Name .. ".", "info")
		return "already"
	end
	local cost = Guards.snitchCost(ts)
	if s.data.Noodles < cost then
		Net.notice(player, "Snitching costs " .. Format.noodles(cost), "bad")
		return "poor"
	end
	s.data.Noodles -= cost
	ts.snitched = true
	Stats.sync(player)
	Net.notice(player, "The guard will check " .. target.Name .. "'s cell tonight. 🤫", "info")
	Net.notice(target, "Someone snitched on you! A guard visits your cell tonight.", "bad")
	return nil
end

function Guards.start()
	-- the guard NPC (decor; walks to inspected cells)
	guardModel = Build.npc(
		workspace.Prison,
		"Guard",
		CFrame.new(0, 0, 0),
		Color3.fromRGB(40, 60, 110),
		Color3.fromRGB(20, 30, 60)
	); -- pivot at the feet (the default pivot is the middle of the body: it walked into the floor)
	(guardModel :: Model).WorldPivot = CFrame.new(0, 0, 0)
	local head = (guardModel :: Model):FindFirstChild("Head") :: BasePart
	local torch = Instance.new("SpotLight")
	torch.Range = 40
	torch.Angle = 35
	torch.Brightness = 4
	torch.Face = Enum.NormalId.Front
	torch.Parent = head
	local hideLimit = RateLimit.new(1, 2)
	Net.on(Remotes.Names.Hide, function(player)
		if hideLimit(player) then
			Guards.hide(player)
		end
	end)
	Net.on(Remotes.Names.Bribe, function(player)
		if hideLimit(player) then
			Guards.bribe(player)
		end
	end)
	local snitchLimit = RateLimit.new(0.5, 2)
	Net.on(Remotes.Names.Snitch, function(player, userId)
		if snitchLimit(player) then
			Guards.snitch(player, userId)
		end
	end)
	task.spawn(function()
		local visited: { [any]: boolean } = {} -- inspected tonight (one visit per prisoner a night)
		while true do
			local ok, err = pcall(function()
				task.wait(Cycle.InspectEvery)
				if Guards.isNight() then
					-- one guard, one visit at a time: snitched prisoners first
					local pick: Player? = nil
					for player, s in State.all() do
						if s.snitched then
							pick = player
							break
						end
					end
					if not pick then
						-- a fair draw among everyone not visited yet tonight (brand-new prisoners are left alone);
						-- the odds of a visit grow with the number of prisoners, like a roll for each of them
						local pool = {}
						for player, ps in State.all() do
							if not visited[player] and ps.data.PlayMinutes >= Cycle.InspectNewbieMinutes then
								table.insert(pool, player)
							end
						end
						if #pool > 0 and math.random() < 1 - (1 - Cycle.InspectChance) ^ #pool then
							pick = pool[math.random(1, #pool)]
						end
					end
					if pick then
						visited[pick] = true
						Guards.inspect(pick)
					end
				else
					table.clear(visited)
				end
			end)
			if not ok then
				warn("[Guards] loop:", err)
				task.wait(1)
			end
		end
	end)
end

return Guards
