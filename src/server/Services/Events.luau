--!strict
-- Server events: every 10-15 minutes something happens to the whole server for 90 seconds
-- (GOLD RUSH, GUARD STRIKE, CASH FRENZY). Announced to everyone, with a real countdown in the HUD
-- (workspace attributes EventId / EventName / EventEnds). Other services ask Events.active(id).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Net = require(script.Parent.Parent.Net)

local Events = {}

local E = Economy.Events
local current: string? = nil
local endsAt = 0
local rng = Random.new()

local function now(): number
	return workspace:GetServerTimeNow()
end

function Events.def(id: string): any?
	for _, e in E.List do
		if e.id == id then
			return e
		end
	end
	return nil
end

function Events.active(id: string): boolean
	return current == id and now() < endsAt
end

function Events.current(): string?
	return if current and now() < endsAt then current else nil
end

function Events.stop()
	current = nil
	endsAt = 0
	workspace:SetAttribute("EventId", nil)
	workspace:SetAttribute("EventName", nil)
	workspace:SetAttribute("EventEnds", nil)
end

-- Starts an event now (also used by the !event admin command and the smoke test).
function Events.start(id: string, duration: number?): boolean
	local def = Events.def(id)
	if not def then
		return false
	end
	current = id
	endsAt = now() + (duration or E.Duration)
	workspace:SetAttribute("EventId", id)
	workspace:SetAttribute("EventName", def.emoji .. " " .. def.name)
	workspace:SetAttribute("EventEnds", endsAt)
	Net.announce(def.emoji .. " " .. def.name .. "! " .. def.desc .. " " .. def.emoji, def.color, "Event")
	return true
end

function Events.startService()
	Events.stop()
	task.spawn(function()
		task.wait(E.FirstAfter)
		while true do
			local pick = E.List[rng:NextInteger(1, #E.List)]
			Events.start(pick.id)
			task.wait(E.Duration)
			if current == pick.id then
				Events.stop()
				Net.announce("The " .. pick.name .. " is over!", { 220, 220, 230 })
			end
			task.wait(rng:NextNumber(E.EverySeconds[1], E.EverySeconds[2]))
		end
	end)
	-- an admin-started event still needs to end on time
	task.spawn(function()
		while true do
			task.wait(1)
			if current and now() >= endsAt then
				Events.stop()
			end
		end
	end)
end

return Events
