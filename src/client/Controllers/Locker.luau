--!strict
-- LIFER'S LOCKER: the steel locker in your cell (no HUD button: walk up to it). Its prompt opens a
-- panel with every perk: level, what it does now, what the next level does, the FP price and a
-- buy button (the server checks everything: Services/Locker). A small key glows over your locker
-- while you can afford a perk. After an escape a card shows the Freedom Points it earned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Locker)
local Rules = require(Shared.Locker)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)
local LootToast = require(Client.Util.LootToast)

local Locker = {}

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 200, 80)

local function fp(): number
	local v = player:GetAttribute("FP")
	return if typeof(v) == "number" then v else 0
end

-- this player's perk levels, from the Perk<id> attributes
function Locker.perks(): Rules.Perks
	local out: Rules.Perks = {}
	for _, p in Config.Perks do
		local v = player:GetAttribute(Rules.attr(p.id))
		if typeof(v) == "number" then
			out[p.id] = v
		end
	end
	return out
end

-- the cheapest perk level you could buy next (nil = everything maxed)
local function cheapest(perks: Rules.Perks): number?
	local best: number? = nil
	for _, p in Config.Perks do
		local c = Rules.nextCost(perks, p.id)
		if c and (best == nil or c < best) then
			best = c
		end
	end
	return best
end

local function myLocker(): BasePart?
	local cell = player:GetAttribute("Cell")
	local prison = workspace:FindFirstChild("Prison")
	local cells = prison and prison:FindFirstChild("Cells")
	local m = cells and typeof(cell) == "number" and cells:FindFirstChild("Cell" .. cell)
	local l = m and m:FindFirstChild("Locker")
	local body = l and l:FindFirstChild("LockerBody")
	return if body and body:IsA("BasePart") then body else nil
end

local function clear(body: Instance)
	for _, c in body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function buildPanel()
	local panel = Panel.new(
		"LockerPanel",
		"🗝️ LIFER'S LOCKER",
		GOLD,
		Color3.fromRGB(110, 70, 0),
		Vector2.new(560, 320)
	)
	UI.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = panel.body,
	})
	local buy = Remotes.get(Remotes.Names.LockerBuy)
	local function render()
		clear(panel.body)
		local points = fp()
		local perks = Locker.perks()
		panel.subtitle.Text = string.format(
			"🗝️ %s Freedom Point%s · perks are kept forever",
			Format.number(points),
			if points == 1 then "" else "s"
		)
		-- how to earn them (one slim line on top)
		local pts = Config.Points
		local how = Panel.row(panel.body, 0, 40)
		Panel.text(
			"desc",
			string.format(
				"Every escape +%d 🗝️  ·  GOLD breakout +%d  ·  a run under %d min of play +%d",
				pts.Base,
				pts.Gold,
				pts.FastMinutes,
				pts.Fast
			),
			{
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -24, 1, 0),
				TextColor3 = GOLD:Lerp(Color3.new(1, 1, 1), 0.4),
				Parent = how,
			}
		)
		for i, p in Config.Perks do
			local level = Rules.level(perks, p.id)
			local cur = p.levels[level]
			local nxt = p.levels[level + 1]
			local cost = Rules.nextCost(perks, p.id)
			local r = Panel.row(panel.body, i, 66)
			Panel.text("note", string.format("PERK · LV %d/%d", level, #p.levels), {
				Position = UDim2.fromOffset(12, 5),
				Size = UDim2.new(0.66, -12, 0, 15),
				TextSize = 13,
				TextColor3 = GOLD:Lerp(Color3.new(1, 1, 1), 0.35),
				Parent = r,
			})
			Panel.text("title", p.emoji .. " " .. p.name, {
				Position = UDim2.fromOffset(12, 20),
				Size = UDim2.new(0.66, -12, 0, 18),
				Parent = r,
			})
			Panel.text(
				"desc",
				if nxt and cur
					then cur.text .. "  →  " .. nxt.text
					elseif nxt then "Next: " .. nxt.text
					else "MAXED · " .. cur.text,
				{
					Position = UDim2.fromOffset(12, 38),
					Size = UDim2.new(0.66, -12, 0, 24),
					TextSize = 12,
					TextWrapped = true,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = r,
				}
			)
			local afford = cost ~= nil and points >= cost
			local b = Panel.button(
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.new(0.3, 0, 0, 44),
				},
				if afford then GOLD else Color3.fromRGB(190, 190, 190),
				Color3.fromRGB(110, 70, 0),
				if cost then "🗝️ " .. cost else "MAX"
			)
			b.Parent = r
			b.Activated:Connect(function()
				if not cost then
					return
				end
				Sound.play(if afford then "Purchase" else "Click")
				buy:FireServer(p.id)
			end)
		end
	end
	panel.onOpen = render
	local attrs = { "FP" }
	for _, p in Config.Perks do
		table.insert(attrs, Rules.attr(p.id))
	end
	for _, a in attrs do
		player:GetAttributeChangedSignal(a):Connect(function()
			if panel.isOpen() then
				render()
			end
		end)
	end
	return panel
end

-- the key over your locker while a perk is affordable
local function beacon()
	local gui: BillboardGui? = nil
	local function refresh()
		local body = myLocker()
		local c = cheapest(Locker.perks())
		local show = body ~= nil and c ~= nil and fp() >= c
		if show and body and (not gui or gui.Adornee ~= body) then
			if gui then
				gui:Destroy()
			end
			local g: BillboardGui = UI.new("BillboardGui", {
				Name = "LockerBeacon",
				Adornee = body,
				Size = UDim2.fromOffset(46, 46),
				StudsOffset = Vector3.new(0, 4.6, 0),
				AlwaysOnTop = false,
				MaxDistance = 60,
				LightInfluence = 0,
				Parent = player:WaitForChild("PlayerGui"),
			})
			local icon = UI.new("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "🗝️",
				TextScaled = true,
				Font = Enum.Font.GothamBold,
				Parent = g,
			})
			-- a slow bob so it reads as "something for you here"
			task.spawn(function()
				local t = 0
				while g.Parent do
					t += task.wait(0.05)
					icon.Position = UDim2.fromOffset(0, math.sin(t * 2.4) * 4)
				end
			end)
			gui = g
		elseif not show and gui then
			gui:Destroy()
			gui = nil
		end
	end
	local attrs = { "FP", "Cell" }
	for _, p in Config.Perks do
		table.insert(attrs, Rules.attr(p.id))
	end
	for _, a in attrs do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	task.delay(3, refresh)
end

function Locker.start()
	local panel = buildPanel()
	Remotes.get(Remotes.Names.OpenLocker).OnClientEvent:Connect(function()
		panel.setOpen(true)
	end)
	-- close it when you walk away
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel.isOpen() then
				local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local body = myLocker()
				if
					r
					and r:IsA("BasePart")
					and body
					and (r.Position - body.Position).Magnitude > Config.Range + 14
				then
					panel.setOpen(false)
				end
			end
		end
	end)
	beacon()
	-- the points an escape earned: shown once THE BREAKOUT's finish cinematic is over
	Remotes.get(Remotes.Names.Freedom).OnClientEvent
		:Connect(function(gained: number, total: number, gold: boolean)
			task.spawn(function()
				local waited = 0
				while player:GetAttribute("Breakout") ~= nil and waited < 20 do
					waited += task.wait(0.25)
				end
				task.wait(1.2)
				LootToast.show({
					icon = "🗝️",
					title = string.format("+%d Freedom Point%s", gained, if gained == 1 then "" else "s"),
					tag = if gold then "GOLD BREAKOUT BONUS" else "LIFER'S LOCKER",
					value = "🗝️ " .. Format.number(total),
					color = GOLD,
					shine = true,
					seconds = 6,
				})
				Sound.play("Upgrade", 0.5, 1.1)
				local c = cheapest(Locker.perks())
				if not c or total < c then
					return
				end
				task.wait(2)
				LootToast.show({
					icon = "🔐",
					title = "Spend them at the locker in your cell",
					tag = "PERMANENT PERKS",
					color = GOLD,
					seconds = 5,
				})
			end)
		end)
end

return Locker
