--!strict
-- Night guard inspections: a guard with a flashlight walks to a cell door. 5 s warning (footsteps,
-- light under the door, the HIDE button). Hidden (poster over the hole, in bed) = fine. Caught =
-- you lose this night's unsold finds in your backpack (find slots), never progress or Noodles.
-- SNITCH: pay Noodles to tip off the guard about someone (guaranteed visit next night); the
-- target can BRIBE the guard during the warning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Cycle = require(Shared.Config.Cycle)
local World = require(Shared.Config.World)
local Zones = require(Shared.Config.Zones)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Build = require(script.Parent.Parent.Util.Build)
local Stats = require(script.Parent.Stats)
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

local function walkGuard(cell: number)
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
	local t = TweenService:Create(value, TweenInfo.new(Cycle.InspectWarning - 0.5, Enum.EasingStyle.Linear), {
		Value = target,
	})
	t:Play()
	t.Completed:Connect(function()
		value:Destroy()
	end)
end

-- Starts an inspection of this player (warning first). Returns false if not possible.
function Guards.inspect(player: Player): boolean
	local s = State.get(player)
	if not s or not s.cell or active[player] then
		return false
	end
	active[player] = os.clock() + Cycle.InspectWarning
	s.hidden = false
	local snitched = s.snitched
	Net.fire(player, Remotes.Names.Inspect, "warn", Cycle.InspectWarning, snitched)
	walkGuard(s.cell)
	task.delay(Cycle.InspectWarning, function()
		active[player] = nil
		local now = State.get(player)
		if not now then
			return
		end
		now.snitched = false
		if now.hidden then
			Net.fire(player, Remotes.Names.Inspect, "safe", 0, false)
			Net.notice(player, "The guard sees a sleeping prisoner. Phew!", "good")
		else
			local lost = #now.data.Finds
			now.data.Finds = {}
			Net.fire(player, Remotes.Names.Finds, now.data.Finds)
			Net.fire(player, Remotes.Names.Inspect, "caught", 0, false)
			Net.notice(
				player,
				if lost > 0
					then "CAUGHT! The guard took " .. lost .. " unsold finds."
					else "CAUGHT! Luckily your pockets were empty.",
				"bad"
			)
			Stats.sync(player)
		end
		now.hidden = false
	end)
	return true
end

function Guards.hide(player: Player): boolean
	local s = State.get(player)
	if not s or not active[player] or os.clock() > active[player] then
		return false
	end
	s.hidden = true
	-- into bed, poster over the hole
	if typeof(player) == "Instance" and player.Character and s.cell then
		local bed = Cells.record(s.cell).model:FindFirstChild("Mattress") :: BasePart?
		if bed then
			player.Character:PivotTo(bed.CFrame * CFrame.new(0, 2.5, 0))
		end
		local frame = Tunnel.frame(s.cell)
		local poster = Build.part(
			workspace,
			"HidePoster",
			Vector3.new(World.TunnelWidth * World.BlockSize, World.TunnelHeight * World.BlockSize, 0.3),
			frame * CFrame.new(0, World.TunnelHeight, 0.4),
			Color3.fromRGB(70, 140, 220),
			{ CanCollide = false }
		)
		Build.sign(poster, Enum.NormalId.Back, "🏝️ DREAM BIG 🏝️", Color3.new(1, 1, 1))
		task.delay(Cycle.InspectWarning + 1, function()
			poster:Destroy()
		end)
	end
	return true
end

function Guards.bribe(player: Player): boolean
	local s = State.get(player)
	if not s or not active[player] or not s.snitched then
		return false
	end
	local cost = Guards.bribeCost(s)
	if s.data.Noodles < cost then
		Net.notice(player, "Not enough Noodles to bribe the guard!", "bad")
		return false
	end
	s.data.Noodles -= cost
	s.hidden = true
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
		while true do
			task.wait(Cycle.InspectEvery)
			if Guards.isNight() then
				for player, s in State.all() do
					if s.snitched or math.random() < Cycle.InspectChance then
						Guards.inspect(player)
						break -- one guard, one visit at a time
					end
				end
			end
		end
	end)
end

return Guards
