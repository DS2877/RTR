--!strict
-- PRISON PASS panel: the 🎫 tile opens a list of all 30 tiers with the FREE and the PREMIUM
-- reward of each (every reward is shown before you buy: known contents). Reached tiers get a
-- Claim button; premium rewards ask for the pass. The tile badge counts what you can claim.
-- Data comes from the "Pass" attribute (JSON, Services/Pass).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Pass)
local Extras = require(Shared.Config.Extras)
local Products = require(Shared.Config.Products)
local PassMath = require(Shared.Pass)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Util = script.Parent.Parent.Util
local UI = require(Util.UI)
local Panel = require(Util.Panel)
local Sound = require(Util.Sound)
local LootToast = require(Util.LootToast)
local HUD = require(script.Parent.HUD)

local PassUI = {}

local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 210, 90)
local AMBER = Color3.fromRGB(220, 130, 30)
local GREEN = Color3.fromRGB(80, 210, 110)
local GREY = Color3.fromRGB(128, 128, 128)

local price = 399
for _, p in Products.Items do
	if p.key == "PrisonPass" then
		price = p.price
	end
end

-- id -> "emoji name" for the exclusive items
local names: { [string]: string } = {}
for _, list in { Extras.Uniforms, Extras.Fists } do
	for _, it in list :: { any } do
		names[it.id] = (it.emoji or "") .. " " .. (it.name or it.id)
	end
end

local function read(): any
	local raw = player:GetAttribute("Pass")
	if typeof(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok then d else nil
end

local function claimable(d: any): number
	if not d then
		return 0
	end
	local reached = PassMath.tier(d.xp or 0)
	local n = 0
	for i = 1, reached do
		if not (d.free and d.free[tostring(i)]) then
			n += 1
		end
		if d.premium and not (d.paid and d.paid[tostring(i)]) then
			n += 1
		end
	end
	return n
end

local function rewardText(r: any, rubble: number): string
	return PassMath.text(r, rubble, names)
end

local function buildPanel(): Panel.Panel
	local panel = Panel.new("PassPanel", "🎫 PRISON PASS", GOLD, AMBER, Vector2.new(580, 330))
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.body }
	)
	local claim = Remotes.get(Remotes.Names.PassClaim)
	local robux = Remotes.get(Remotes.Names.RobuxBuy)

	local function render()
		for _, c in panel.body:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local d = read()
			or { season = 0, xp = 0, premium = false, free = {}, paid = {}, ends = 0, rubble = 1 }
		local reached, into = PassMath.tier(d.xp or 0)
		local left = math.max(0, (d.ends or 0) - os.time())
		panel.subtitle.Text = if (d.season or 0) <= 0
			then "season 1 starts soon"
			else string.format("season %d · ends in %s", d.season, Format.duration(left))

		-- header: tier + xp bar + premium button
		local head = Panel.row(panel.body, 0, 74)
		Panel.text("title", string.format("Tier %d / %d", reached, #Config.Tiers), {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(0.6, -12, 0, 20),
			Parent = head,
		})
		Panel.text(
			"desc",
			if reached >= #Config.Tiers
				then "Every tier done. Legend."
				else string.format(
					"%d / %d XP to tier %d · dig, do jobs, crack vaults, break out",
					into,
					Config.TierXp,
					reached + 1
				),
			{
				Position = UDim2.fromOffset(12, 30),
				Size = UDim2.new(0.6, -12, 0, 16),
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = head,
			}
		)
		local bar = UI.new("Frame", {
			Position = UDim2.fromOffset(12, 54),
			Size = UDim2.new(0.6, -12, 0, 8),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.88,
			Parent = head,
		}, { UI.corner(4) })
		UI.new("Frame", {
			Size = UDim2.fromScale(
				if reached >= #Config.Tiers then 1 else math.clamp(into / Config.TierXp, 0, 1),
				1
			),
			BackgroundColor3 = GOLD,
			Parent = bar,
		}, { UI.corner(4) })
		local premBtn = Panel.button(
			{
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0.36, 0, 0, 46),
				Parent = head,
			},
			if d.premium then GREY else GOLD,
			AMBER,
			if d.premium then "PREMIUM ✓ · +25% XP" else string.format("🎫 PREMIUM · R$ %d", price)
		)
		if not d.premium then
			premBtn.Activated:Connect(function()
				Sound.play("Click")
				robux:FireServer("PrisonPass")
			end)
		end

		-- column titles
		local cols = Panel.row(panel.body, 1, 22)
		cols.BackgroundTransparency = 1
		Panel.text("note", "FREE", {
			Position = UDim2.new(0.12, 0, 0, 0),
			Size = UDim2.new(0.42, -8, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = cols,
		})
		Panel.text("note", "🎫 PREMIUM", {
			Position = UDim2.new(0.56, 0, 0, 0),
			Size = UDim2.new(0.42, -8, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = GOLD,
			Parent = cols,
		})

		local rubble = d.rubble or 1
		local firstOpen: GuiObject? = nil
		for i = 1, #Config.Tiers do
			local r = Panel.row(panel.body, 1 + i, 50)
			r.Name = "Row" .. i
			if i <= reached then
				r.BackgroundTransparency = 0.9
			end
			Panel.text("title", tostring(i), {
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(0.12, -8, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if i <= reached then GOLD else Panel.MUTED,
				Parent = r,
			})
			for col, premium in { false, true } do
				local reward = PassMath.reward(i, premium)
				local done = if premium
					then d.paid and d.paid[tostring(i)]
					else d.free and d.free[tostring(i)]
				local text = rewardText(reward, rubble)
				local color, action
				if done then
					text ..= "  ✓"
					color = GREY
				elseif i > reached then
					text = "🔒 " .. text
					color = GREY
				elseif premium and not d.premium then
					text = "🎫 " .. text
					color = GREY
					action = function()
						robux:FireServer("PrisonPass")
					end
				else
					text = "Claim " .. text
					color = if premium then GOLD else GREEN
					action = function()
						claim:FireServer(i, premium)
					end
				end
				local b = Panel.button({
					Position = UDim2.new(if col == 1 then 0.12 else 0.56, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Size = UDim2.new(0.42, -8, 0, 44),
					Parent = r,
				}, color, color, text)
				if action then
					b.Activated:Connect(function()
						Sound.play("Click")
						action()
					end)
				end
				if firstOpen == nil and not done and i <= reached and (not premium or d.premium) then
					firstOpen = r
				end
			end
		end
		-- scroll to the first thing to claim (or the current tier)
		task.defer(function()
			local target = firstOpen or panel.body:FindFirstChild("Row" .. reached)
			if target and target:IsA("GuiObject") then
				local y = target.AbsolutePosition.Y
					- panel.body.AbsolutePosition.Y
					+ panel.body.CanvasPosition.Y
				panel.body.CanvasPosition = Vector2.new(0, math.max(0, y - 80))
			end
		end)
	end
	panel.onOpen = render
	player:GetAttributeChangedSignal("Pass"):Connect(function()
		if panel.isOpen() then
			local keep = panel.body.CanvasPosition
			render()
			task.defer(function()
				panel.body.CanvasPosition = keep
			end)
		end
	end)
	return panel
end

function PassUI.start()
	local tile = HUD.passTile
	if not tile then
		return
	end
	local panel = buildPanel()
	tile.Activated:Connect(function()
		Sound.play("Click")
		panel.toggle()
	end)
	local function badge()
		local n = claimable(read())
		UI.badge(tile, if n > 0 then tostring(n) else "", Color3.fromRGB(60, 190, 90))
	end
	player:GetAttributeChangedSignal("Pass"):Connect(badge)
	task.defer(badge)
	Remotes.get(Remotes.Names.PassTier).OnClientEvent:Connect(function(n: number)
		LootToast.show({
			icon = "🎫",
			title = "Prison Pass tier " .. n,
			tag = "New reward · tap 🎫 Pass",
			value = "TIER UP",
			color = GOLD,
			seconds = 3.4,
		})
		Sound.play("Upgrade", 0.5, 1.2)
		UI.bump(tile, 0.25)
	end)
	Remotes.get(Remotes.Names.PassClaimed).OnClientEvent:Connect(function(i: number, premium: boolean)
		local d = read()
		local r = PassMath.reward(i, premium)
		if r then
			LootToast.show({
				icon = if premium then "🎫" else "🎁",
				title = rewardText(r, d and d.rubble or 1),
				tag = "Prison Pass tier " .. i .. (if premium then " · premium" else ""),
				value = "CLAIMED",
				color = if premium then GOLD else GREEN,
				seconds = 2.6,
			})
			Sound.play("Coin", 0.6)
		end
	end)
end

return PassUI
