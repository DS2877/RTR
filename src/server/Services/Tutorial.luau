--!strict
-- Onboarding: the first-join TOUR (client/Controllers/Tour: a short camera tour of everything that
-- matters, TourDone in the profile, "TourDone" attribute) and the onboarding funnel logged to
-- AnalyticsService (PUNCH -> VACUUM -> DUMP -> SELL -> UPGRADE, TutorialStep in the profile).
-- Nothing is shown during play: no arrows, no step boxes.

local AnalyticsService = game:GetService("AnalyticsService")

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

local Tutorial = {}

Tutorial.Steps = { "Punch", "Vacuum", "Dump", "Sell", "Upgrade" }
local DONE = #Tutorial.Steps + 1

local function log(fn: () -> ())
	pcall(fn)
end

-- Analytics (no-ops for simulated players)
function Tutorial.funnel(player: Player, step: number, name: string)
	if typeof(player) ~= "Instance" then
		return
	end
	log(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Tutorial.event(player: Player, name: string, value: number?)
	if typeof(player) ~= "Instance" then
		return
	end
	log(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

function Tutorial.zone(player: Player, zone: number)
	if typeof(player) ~= "Instance" then
		return
	end
	log(function()
		AnalyticsService:LogProgressionCompleteEvent(player, "Zones", zone)
	end)
end

local function sync(player: Player, step: number)
	if typeof(player) == "Instance" then
		player:SetAttribute("Tutorial", step)
	end
end

function Tutorial.step(player: Player): number
	local s = State.get(player)
	return if s then (s.data :: any).TutorialStep or 1 else DONE
end

-- Called with the step that just happened ("Punch", "Vacuum", ...): advances if it was the
-- current one. Steps after Dump: Sell is skipped when you have nothing to sell.
function Tutorial.did(player: Player, what: string)
	local s = State.get(player)
	if not s then
		return
	end
	local d = s.data :: any
	local step = d.TutorialStep or 1
	if step >= DONE then
		return
	end
	if Tutorial.Steps[step] ~= what then
		-- buying before selling still counts as the end of the tutorial
		if what == "Upgrade" and step >= 3 then
			step = DONE - 1
		else
			return
		end
	end
	step += 1
	if Tutorial.Steps[step] == "Sell" and #s.data.Finds == 0 then
		step += 1
	end
	d.TutorialStep = step
	sync(player, step)
	Tutorial.funnel(player, step, if step >= DONE then "TutorialDone" else Tutorial.Steps[step])
end

function Tutorial.onJoin(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local d = s.data :: any
	d.TutorialStep = d.TutorialStep or 1
	sync(player, d.TutorialStep)
	if typeof(player) == "Instance" then
		player:SetAttribute("TourDone", d.TourDone == true)
	end
	if d.TutorialStep == 1 then
		Tutorial.funnel(player, 1, "Joined")
	end
end

function Tutorial.start()
	Net.on(Remotes.Names.TourDone, function(player)
		local s = State.get(player)
		if s and not (s.data :: any).TourDone then
			(s.data :: any).TourDone = true
			Tutorial.event(player, "TourDone")
			if typeof(player) == "Instance" then
				player:SetAttribute("TourDone", true)
			end
		end
	end)
end

return Tutorial
