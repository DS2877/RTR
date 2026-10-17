--!strict
-- CART: the upgrade track that makes you faster inside YOUR OWN tunnel (Config/Upgrades.Cart).
-- A small loop sets Humanoid.WalkSpeed to Economy.WalkSpeed x the cart's speed while you stand in
-- your own tunnel (not the cell room, the corridors, the Yard or anyone else's tunnel), and puts it
-- back when you leave. Hands off while something else owns your speed: a stolen find on your back
-- (Raid: CarrySpeed), the gym (Gym freezes you), THE BREAKOUT, lying in bed. It writes only when
-- the value changes. The "Carting" attribute tells the client to show the cart's dust trail.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)

local State = require(script.Parent.Parent.State)
local Breakout = require(script.Parent.Breakout)
local Gym = require(script.Parent.Gym)

local Cart = {}

local INTERVAL = 0.25

-- the WalkSpeed this loop last wrote, per player (nil = we don't own it right now)
local boosted: { [any]: number } = {}

-- Is this world position inside the player's own tunnel (behind the back wall's first layer)?
function Cart.inOwnTunnel(s: State.PlayerState, pos: Vector3): boolean
	if not s.cell or not s.frame or Tunnel.cellAt(pos) ~= s.cell then
		return false
	end
	local _, _, z = Tunnel.toBlock(s.frame, pos)
	return z >= 0
end

-- The WalkSpeed this player should have right now, or nil when the cart has no say.
function Cart.desired(player: Player, s: State.PlayerState, pos: Vector3): number?
	if s.carrying or s.hidden or Breakout.running(player) or Gym.lifting(player) then
		return nil
	end
	local mult = Progression.cartSpeed(s.data.Levels.Cart)
	if mult <= 1 or not Cart.inOwnTunnel(s, pos) then
		return nil
	end
	-- whole studs per second: WalkSpeed reads back exactly, so "only write on change" holds
	return math.floor(Economy.WalkSpeed * mult + 0.5)
end

local function setFlag(player: Player, on: boolean)
	if typeof(player) == "Instance" and (player:GetAttribute("Carting") == true) ~= on then
		player:SetAttribute("Carting", on)
	end
end

function Cart.update(player: Player, s: State.PlayerState)
	if typeof(player) ~= "Instance" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		boosted[player] = nil
		setFlag(player, false)
		return
	end
	local want = Cart.desired(player, s, root.Position)
	if want then
		if humanoid.WalkSpeed ~= want then
			humanoid.WalkSpeed = want
		end
		boosted[player] = want
		setFlag(player, true)
		return
	end
	local mine = boosted[player]
	if mine then
		boosted[player] = nil
		-- back to walking, unless something else set its own speed meanwhile (carry, gym)
		if humanoid.WalkSpeed == mine then
			humanoid.WalkSpeed = Economy.WalkSpeed
		end
	end
	setFlag(player, false)
end

function Cart.onLeaving(player: Player)
	boosted[player] = nil
end

function Cart.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				task.wait(INTERVAL)
				for player, s in State.all() do
					Cart.update(player, s)
				end
			end)
			if not ok then
				warn("[Cart] loop:", err)
				task.wait(1)
			end
		end
	end)
end

return Cart
