--!strict
-- Awards Roblox badges for milestones (Config/Badges ids; 0 = not created yet, skipped). Each
-- award runs in its own thread with pcall: badge web calls can be slow or fail, never the game.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Badges)

local Badges = {}

local given: { [any]: { [string]: boolean } } = {} -- this session (no repeat web calls)

function Badges.award(player: any, key: string)
	local id = Config[key]
	if not id or id == 0 or typeof(player) ~= "Instance" then
		return
	end
	local mine = given[player] or {}
	given[player] = mine
	if mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		pcall(function()
			if not BadgeService:UserHasBadgeAsync(player.UserId, id) then
				BadgeService:AwardBadge(player.UserId, id)
			end
		end)
	end)
end

function Badges.onLeaving(player: any)
	given[player] = nil
end

return Badges
