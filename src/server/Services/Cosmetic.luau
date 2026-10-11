--!strict
-- Trails (bought with cash, Halloween candy, or the Rainbow Trail pass) and the seasonal event.
-- The equipped trail is a Trail between two attachments on the HumanoidRootPart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Wallet = require(script.Parent.Wallet)

local Cosmetic = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function Cosmetic.seasonActive(): boolean
	local d = os.date("!*t") :: any
	return Cosmetics.seasonActive({ month = d.month, day = d.day })
end

function Cosmetic.syncAttributes(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	player:SetAttribute("Candy", s.data.Candy)
	player:SetAttribute("Trail", s.data.Trail)
	local owned = {}
	for id in s.data.Trails do
		table.insert(owned, id)
	end
	table.sort(owned)
	player:SetAttribute("TrailsOwned", table.concat(owned, ","))
end

function Cosmetic.owns(player: Player, id: string): boolean
	local s = State.get(player)
	local t = Cosmetics.trail(id)
	if not s or not t then
		return false
	end
	if t.currency == "pass" then
		return t.pass ~= nil and s.passes[t.pass] == true
	end
	return s.data.Trails[id] == true
end

-- Puts the equipped trail on the current character (or removes it).
function Cosmetic.apply(player: Player)
	local s = State.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not s or not root then
		return
	end
	local old = root:FindFirstChild("RTR_Trail")
	if old then
		old:Destroy()
	end
	for _, n in { "RTR_TrailA", "RTR_TrailB" } do
		local a = root:FindFirstChild(n)
		if a then
			a:Destroy()
		end
	end
	local t = Cosmetics.trail(s.data.Trail)
	if not t or not Cosmetic.owns(player, t.id) then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "RTR_TrailA"
	a0.Position = Vector3.new(0, t.width / 2, 0.4)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "RTR_TrailB"
	a1.Position = Vector3.new(0, -t.width / 2, 0.4)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "RTR_Trail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = t.lifetime
	trail.LightEmission = t.glow
	trail.FaceCamera = true
	trail.MinLength = 0.1
	local keys = {}
	for i, c in t.colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #t.colors - 1), rgb(c)))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, rgb(t.colors[1])))
	end
	trail.Color = ColorSequence.new(keys)
	trail.Transparency = if t.fade
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		else NumberSequence.new(0.15)
	trail.Parent = root
end

-- Returns true when bought (also used by the smoke test).
function Cosmetic.buy(player: Player, id: string): boolean
	local s = State.get(player)
	local t = Cosmetics.trail(id)
	if not s or not t or t.currency == "pass" or s.data.Trails[id] then
		return false
	end
	if t.currency == "candy" then
		if not Cosmetic.seasonActive() or s.data.Candy < t.price then
			Net.notice(player, "Need " .. t.price .. " 🍬", "bad")
			return false
		end
		s.data.Candy -= t.price
	elseif not Wallet.spend(player, t.price) then
		Net.notice(player, "Need " .. Format.cash(t.price), "bad")
		Net.fire(player, Remotes.Names.Offer, "cash")
		return false
	end
	s.data.Trails[id] = true
	s.data.Trail = id
	Cosmetic.syncAttributes(player)
	Cosmetic.apply(player)
	Net.notice(player, t.emoji .. " " .. t.name .. " trail unlocked!", "upgrade")
	return true
end

function Cosmetic.equip(player: Player, id: string): boolean
	local s = State.get(player)
	if not s or (id ~= "" and not Cosmetic.owns(player, id)) then
		return false
	end
	s.data.Trail = id
	Cosmetic.syncAttributes(player)
	Cosmetic.apply(player)
	return true
end

function Cosmetic.addCandy(player: Player, amount: number)
	local s = State.get(player)
	if s and amount > 0 then
		s.data.Candy += amount
		player:SetAttribute("Candy", s.data.Candy)
	end
end

function Cosmetic.onCharacter(player: Player)
	task.wait(0.3)
	Cosmetic.apply(player)
end

function Cosmetic.start(worldInfo: any)
	workspace:SetAttribute("Season", if Cosmetic.seasonActive() then Cosmetics.Season.id else nil)
	local buyLimit = RateLimit.new(2, 4)
	Net.on(Remotes.Names.BuyTrail, function(player, id)
		if buyLimit(player) and typeof(id) == "string" then
			Cosmetic.buy(player, id)
		end
	end)
	Net.on(Remotes.Names.EquipTrail, function(player, id)
		if buyLimit(player) and typeof(id) == "string" then
			Cosmetic.equip(player, id)
		end
	end)
	if worldInfo.trailsPrompt then
		worldInfo.trailsPrompt.Triggered:Connect(function(player: Player)
			Net.fire(player, Remotes.Names.OpenTrails)
		end)
	end
end

return Cosmetic
