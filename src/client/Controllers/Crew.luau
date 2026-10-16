--!strict
-- CREW on the client: the 👥 Crew tile opens a panel with your crew (and its Noodles bonus) and
-- everyone else on the server with an Invite button, plus "Invite friends" (Roblox's own game
-- invite). An invite shows a slim card with JOIN / ✕ that runs out. Digging in your host's
-- tunnel needs nothing else: DigController aims there while you stand in it.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)
local HUD = require(script.Parent.HUD)

local Crew = {}

local player = Players.LocalPlayer
local CYAN = Color3.fromRGB(120, 230, 255)
local BLUE = Color3.fromRGB(40, 120, 220)
local GREEN = Color3.fromRGB(80, 210, 110)
local GREY = Color3.fromRGB(128, 128, 128)

type CrewInfo = { host: string, hostId: number, members: { string }, bonus: number, you: string }

local function info(): CrewInfo?
	local raw = player:GetAttribute("Crew")
	if typeof(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok then data else nil
end

local function buildPanel(): Panel.Panel
	local panel = Panel.new("CrewPanel", "👥 CREW", CYAN, BLUE, Vector2.new(540, 320))
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.body }
	)
	local invite = Remotes.get(Remotes.Names.CrewInvite)
	local leave = Remotes.get(Remotes.Names.CrewLeave)
	local function render()
		for _, c in panel.body:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local me = info()
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		-- your crew
		if me then
			panel.subtitle.Text = string.format("+%d%% Noodles for everyone in it", me.bonus)
			local r = Panel.row(panel.body, nextOrder(), 62)
			Panel.text("title", if me.you == "host" then "Your crew" else me.host .. "'s crew", {
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(0.66, -12, 0, 18),
				Parent = r,
			})
			Panel.text("desc", table.concat(me.members, " · "), {
				Position = UDim2.fromOffset(12, 30),
				Size = UDim2.new(0.66, -12, 0, 24),
				TextSize = 12,
				Parent = r,
			})
			local b = Panel.button(
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.new(0.28, 0, 0, 36),
					Parent = r,
				},
				Color3.fromRGB(230, 90, 80),
				Color3.fromRGB(120, 30, 20),
				if me.you == "host" then "Break up" else "Leave"
			)
			b.Activated:Connect(function()
				Sound.play("Click")
				leave:FireServer()
			end)
			if me.you == "host" then
				for _, name in me.members do
					local other = Players:FindFirstChild(name)
					if other and other ~= player and other:IsA("Player") then
						local kr = Panel.row(panel.body, nextOrder(), 44)
						Panel.text("desc", "⛏️  " .. name .. " digs with you", {
							Position = UDim2.fromOffset(12, 0),
							Size = UDim2.new(0.66, -12, 1, 0),
							Parent = kr,
						})
						local kb = Panel.button({
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -10, 0.5, 0),
							Size = UDim2.new(0.22, 0, 0, 30),
							Parent = kr,
						}, GREY, GREY, "Send home")
						kb.Activated:Connect(function()
							Sound.play("Click")
							leave:FireServer(other.UserId)
						end)
					end
				end
			end
		else
			panel.subtitle.Text =
				string.format("dig together: +%d%% Noodles each", math.floor(Economy.CrewBonus * 100))
			local r = Panel.row(panel.body, nextOrder(), 54)
			Panel.text(
				"desc",
				"Invite players to dig in YOUR tunnel. Everyone keeps their own rubble, finds and gold, and the whole crew earns more (friends even more).",
				{
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(1, -24, 1, 0),
					TextSize = 12,
					Parent = r,
				}
			)
		end
		-- invite Roblox friends into this server
		local fr = Panel.row(panel.body, nextOrder(), 48)
		Panel.text("title", "📨 Bring your friends", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.6, -12, 1, 0),
			Parent = fr,
		})
		local fb = Panel.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.34, 0, 0, 34),
			Parent = fr,
		}, CYAN, BLUE, "Invite friends")
		fb.Activated:Connect(function()
			Sound.play("Click")
			pcall(function()
				if SocialService:CanSendGameInviteAsync(player) then
					SocialService:PromptGameInvite(player)
				end
			end)
		end)
		-- everyone else on the server
		local guest = me ~= nil and me.you == "guest"
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local busy = typeof(other:GetAttribute("Crew")) == "string"
					and other:GetAttribute("Crew") ~= ""
				local r = Panel.row(panel.body, nextOrder(), 44)
				Panel.text("title", other.DisplayName, {
					Position = UDim2.fromOffset(12, 0),
					Size = UDim2.new(0.6, -12, 1, 0),
					Parent = r,
				})
				local can = not busy and not guest
				local b = Panel.button(
					{
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.new(0.26, 0, 0, 30),
						Parent = r,
					},
					if can then GREEN else GREY,
					if can then Color3.fromRGB(20, 90, 40) else GREY,
					if busy then "In a crew" else "Invite"
				)
				if can then
					b.Activated:Connect(function()
						Sound.play("Click")
						invite:FireServer(other.UserId)
					end)
				end
			end
		end
	end
	panel.onOpen = render
	player:GetAttributeChangedSignal("Crew"):Connect(function()
		if panel.isOpen() then
			render()
		end
	end)
	return panel
end

-- the invite card: slim, bottom center, runs out
local function buildInviteCard(): (string, number, boolean) -> ()
	local gui = UI.new("ScreenGui", {
		Name = "CrewInvite",
		ResetOnSpawn = false,
		DisplayOrder = 12,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local box: Frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(380, 74),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { UI.corner(14), UI.stroke(CYAN, 1, 0.4) })
	UI.scaleObject(box)
	local title: TextLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -150, 0, 20),
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = CYAN,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = box,
	})
	local body: TextLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -150, 0, 32),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(205, 208, 218),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = box,
	})
	local join = Panel.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -54, 0.5, 0),
		Size = UDim2.fromOffset(78, 36),
		Parent = box,
	}, GREEN, Color3.fromRGB(20, 90, 40), "JOIN")
	local no = Panel.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(38, 36),
		Parent = box,
	}, GREY, GREY, "✕")
	local timer = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -4),
		Size = UDim2.new(1, -28, 0, 2),
		BackgroundColor3 = CYAN,
		BorderSizePixel = 0,
		Parent = box,
	})
	local answer = Remotes.get(Remotes.Names.CrewAnswer)
	local hostId = 0
	local token = 0
	local function close()
		box.Visible = false
		token += 1
	end
	join.Activated:Connect(function()
		Sound.play("Upgrade", 0.5, 1.2)
		answer:FireServer(hostId, true)
		close()
	end)
	no.Activated:Connect(function()
		Sound.play("Click")
		answer:FireServer(hostId, false)
		close()
	end)
	return function(name: string, id: number, friend: boolean)
		hostId = id
		token += 1
		local mine = token
		title.Text = "👥 " .. name .. " wants you in their crew!"
		body.Text = string.format(
			"Dig together in their tunnel: +%d%% Noodles for everyone%s.",
			math.floor((Economy.CrewBonus + (if friend then Economy.CrewFriendBonus else 0)) * 100),
			if friend then " (you're friends: extra!)" else ""
		)
		box.Visible = true
		box.Position = UDim2.new(0.5, 0, 1, -130)
		UI.tween(box, 0.3, { Position = UDim2.new(0.5, 0, 1, -150) }, Enum.EasingStyle.Back)
		Sound.play("Announce", 0.4)
		timer.Size = UDim2.new(1, -28, 0, 2)
		UI.tween(timer, Economy.CrewInviteSeconds, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
		task.delay(Economy.CrewInviteSeconds, function()
			if token == mine then
				close()
			end
		end)
	end
end

function Crew.start()
	local tile = HUD.crewTile
	if not tile then
		return
	end
	local panel = buildPanel()
	tile.Activated:Connect(function()
		Sound.play("Click")
		panel.toggle()
	end)
	local function badge()
		local me = info()
		UI.badge(tile, if me then tostring(#me.members) else "", BLUE)
	end
	player:GetAttributeChangedSignal("Crew"):Connect(badge)
	badge()
	local show = buildInviteCard()
	Remotes.get(Remotes.Names.CrewInvited).OnClientEvent
		:Connect(function(id: number, name: string, friend: boolean)
			if typeof(id) == "number" and typeof(name) == "string" then
				show(name, id, friend == true)
			end
		end)
end

return Crew
