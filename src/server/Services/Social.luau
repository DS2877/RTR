--!strict
-- Friend Boost: +10% cash for every Roblox friend on the same server (capped). Recounted whenever
-- someone joins or leaves. Shown in the HUD via the "FriendBoost" player attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local State = require(script.Parent.Parent.State)

local Social = {}

local friendCache: { [string]: boolean } = {}

local function pairKey(a: number, b: number): string
	return if a < b then a .. ":" .. b else b .. ":" .. a
end

local function areFriends(a: Player, b: Player): boolean
	local key = pairKey(a.UserId, b.UserId)
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local friends = ok and result == true
	if ok then
		friendCache[key] = friends
	end
	return friends
end

-- The boost as a fraction (0.2 = +20%) for `friends` friends on the server.
function Social.boostFor(friends: number): number
	local F = Economy.FriendBoost
	return math.min(F.Max, friends * F.PerFriend)
end

function Social.recount()
	local players = Players:GetPlayers()
	for _, p in players do
		local s = State.get(p)
		if s then
			local n = 0
			for _, other in players do
				if other ~= p and areFriends(p, other) then
					n += 1
				end
			end
			s.friendBoost = Social.boostFor(n)
			p:SetAttribute("FriendBoost", s.friendBoost)
		end
	end
end

function Social.start()
	Players.PlayerAdded:Connect(function()
		task.delay(3, Social.recount) -- after their data has loaded
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(Social.recount)
	end)
end

return Social
