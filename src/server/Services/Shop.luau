--!strict
-- The Common Room counters: Workshop (tools, brushes), Commissary (backpack, find slots, vacuum),
-- The Fence (opens the sell panel; selling itself is in Loot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Upgrades = require(Shared.Config.Upgrades)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Stats = require(script.Parent.Stats)

local Shop = {}

local world: any = nil

Shop.onBought = nil :: ((player: Player, track: string) -> ())?

local function shopFor(track: string): string?
	for shop, tracks in Upgrades.Shops do
		if table.find(tracks, track) then
			return shop
		end
	end
	return nil
end

-- Returns the new level, or nil (with the reason) when the purchase is refused.
function Shop.buy(player: Player, track: string): (number?, string?)
	local s = State.get(player)
	if not s then
		return nil, "no state"
	end
	local shop = shopFor(track)
	if not shop then
		return nil, "unknown track"
	end
	local root = State.root(player)
	local counter = world.shops[shop]
	if not root or (root - counter.Position).Magnitude > Economy.ShopRange + 6 then
		return nil, "too far"
	end
	local levels = s.data.Levels :: any
	local level = levels[track]
	local cost = Progression.nextCost(track, level)
	if not cost then
		Net.notice(player, "Maxed out for now!", "info")
		return nil, "maxed"
	end
	if s.data.Noodles < cost then
		Net.notice(player, "Not enough Noodles 🍜", "bad")
		return nil, "poor"
	end
	s.data.Noodles -= cost
	levels[track] = level + 1
	local item = (Upgrades :: any)[track][level + 1]
	Net.notice(player, string.format("%s %s unlocked!", item.emoji, item.name), "upgrade")
	Stats.sync(player)
	if Shop.onBought then
		Shop.onBought(player, track)
	end
	return level + 1, nil
end

function Shop.start(w: any)
	world = w
	for name, counter in world.shops do
		local prompt = counter:FindFirstChild("ShopPrompt") :: ProximityPrompt
		prompt.Triggered:Connect(function(player)
			Net.fire(player, Remotes.Names.OpenShop, name)
		end)
	end
	local buyLimit = RateLimit.new(4, 6)
	Net.on(Remotes.Names.Buy, function(player, track)
		if buyLimit(player) and typeof(track) == "string" and #track < 20 then
			Shop.buy(player, track)
		end
	end)
end

return Shop
