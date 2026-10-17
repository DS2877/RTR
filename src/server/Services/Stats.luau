--!strict
-- Mirrors a player's numbers into Player attributes so the HUD can show them (read-only for clients).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progression = require(ReplicatedStorage.Shared.Progression)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local State = require(script.Parent.Parent.State)

local Stats = {}

function Stats.capacity(s: State.PlayerState): number
	local mult = if s.passes.HugeBackpack then Economy.PassEffects.HugeBackpack else 1
	return Progression.capacity(s.data.Levels.Backpack) * mult
end

function Stats.power(s: State.PlayerState): number
	return Progression.punchPower(s.data.Strength, s.data.Levels.Tools, s.data.Rebirths)
end

function Stats.sync(player: Player)
	local s = State.get(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	local d = s.data
	player:SetAttribute("Noodles", d.Noodles)
	player:SetAttribute("Strength", d.Strength)
	player:SetAttribute("Power", Stats.power(s))
	player:SetAttribute("Tools", d.Levels.Tools)
	player:SetAttribute("Brushes", d.Levels.Brushes)
	player:SetAttribute("Backpack", d.Levels.Backpack)
	player:SetAttribute("FindSlots", d.Levels.FindSlots)
	player:SetAttribute("Vacuum", d.Levels.Vacuum)
	player:SetAttribute("Lock", d.Levels.Lock)
	player:SetAttribute("Trap", d.Levels.Trap)
	player:SetAttribute("Alarm", d.Levels.Alarm)
	player:SetAttribute("StashUsed", #d.Stash)
	player:SetAttribute("Bag", d.Bag)
	player:SetAttribute("BagCap", Stats.capacity(s))
	player:SetAttribute("Loose", s.loose)
	player:SetAttribute("Slots", Progression.findSlots(d.Levels.FindSlots))
	player:SetAttribute("SlotsUsed", #d.Finds)
	player:SetAttribute("MaxDepth", d.MaxDepth)
	player:SetAttribute("RunDepth", d.RunDepth)
	player:SetAttribute("Zone", d.Zone)
	player:SetAttribute("Cell", s.cell or 0)
	player:SetAttribute("AutoVacuum", s.passes.AutoVacuum == true)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local n = ls:FindFirstChild("🍜 Noodles") :: IntValue?
		local depth = ls:FindFirstChild("⛏️ Depth") :: IntValue?
		local escapes = ls:FindFirstChild("🏃 Escapes") :: IntValue?
		if escapes then
			escapes.Value = d.Rebirths
		end
		if n then
			n.Value = math.floor(math.min(d.Noodles, 2 ^ 53))
		end
		if depth then
			depth.Value = d.RunDepth
		end
	end
end

function Stats.setupLeaderstats(player: Player)
	if typeof(player) ~= "Instance" then
		return
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local escapes = Instance.new("IntValue")
	escapes.Name = "🏃 Escapes"
	escapes.Parent = ls
	local n = Instance.new("IntValue")
	n.Name = "🍜 Noodles"
	n.Parent = ls
	local depth = Instance.new("IntValue")
	depth.Name = "⛏️ Depth"
	depth.Parent = ls
	ls.Parent = player
end

return Stats
