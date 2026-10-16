--!strict
-- The big moments of M4 on the client: 🧨 DYNAMITE button + explosion, the ESCAPE button and
-- cinematic, 💡 decor placing, guard inspections (HIDE / BRIBE, footsteps, light under the door),
-- server events (banner + timer), the treasure marker, rewards, the VIP door and chat tag.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Cycle = require(Shared.Config.Cycle)
local Extras = require(Shared.Config.Extras)
local World = require(Shared.Config.World)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local LootToast = require(Client.Util.LootToast)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)
local HUD = require(script.Parent.HUD)
local DigFX = require(script.Parent.DigFX)
local VoxelRender = require(script.Parent.VoxelRender)
local CameraController = require(script.Parent.CameraController)
local DigController = require(script.Parent.DigController)

local Moments = {}

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(20, 20, 28)
local gui: ScreenGui
local folder: Folder

local function bigButton(name: string, text: string, color: Color3, pos: UDim2, size: Vector2): TextButton
	local b: TextButton = UI.new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(1, 1),
		Position = pos,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = color,
		Text = "",
		Visible = false,
		Parent = gui,
	}, {
		UI.corner(math.floor(size.Y / 2)),
		UI.stroke(UI.INK, 2),
		UI.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
	})
	UI.bigText({
		Name = "Label",
		Position = UDim2.fromScale(0.08, 0.2),
		Size = UDim2.fromScale(0.84, 0.6),
		Text = text,
		Parent = b,
	}, UI.INK, 1.5)
	UI.scaleObject(b, 1.1)
	return b
end

-- ===== explosion =====

local function boom(owner: number, x: number, y: number, z: number)
	local t = VoxelRender.get(owner)
	if not t then
		return
	end
	local pos = Tunnel.blockCenter(t.frame, x, y, z)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 170, 60)
	ball.Size = Vector3.one * 2
	ball.CFrame = CFrame.new(pos)
	ball.Parent = folder
	UI.tween(ball, 0.35, { Size = Vector3.one * 18, Transparency = 1 })
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 6
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Parent = ball
	task.delay(0.5, function()
		ball:Destroy()
	end)
	if owner == player.UserId then
		Shake.kick(1)
		Sound.play("Boom", 0.9, 1)
		Sound.play("BigBreak", 0.9, 0.85)
	end
end

-- ===== escape cinematic =====

local function escapeCinematic(rebirths: number, prison: string)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local yard = Vector3.new(World.Yard.x, 0, World.Yard.z)
	local wallTop = Vector3.new(World.Yard.x - World.Yard.sx / 2, 18, 0)
	cam.CameraType = Enum.CameraType.Scriptable
	local overlay = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = gui,
	})
	local title = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.8, 0.14),
		Text = "YOU ESCAPED!",
		TextColor3 = Color3.fromRGB(255, 220, 80),
		ZIndex = 51,
		Parent = gui,
	}, DARK, 4)
	local sub = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.7, 0.07),
		Text = "",
		ZIndex = 51,
		Parent = gui,
	}, DARK, 3)
	-- searchlights sweeping the yard at night
	local beams = {}
	for i = 1, 3 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 255, 220)
		p.Transparency = 0.7
		p.Size = Vector3.new(4, 80, 4)
		p.Parent = folder
		beams[i] = p
	end
	local oldClock = Lighting.ClockTime
	Sound.play("Siren", 0.6)
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		Lighting.ClockTime = 0.5
		for i, p in beams do
			local a = t * 0.9 + i * 2.1
			p.CFrame = CFrame.new(yard + Vector3.new(math.cos(a) * 40, 30, math.sin(a) * 40))
				* CFrame.Angles(math.sin(a) * 0.5, 0, math.cos(a) * 0.5)
		end
		-- fly over the yard, up the wall and over it
		local k = math.clamp(t / 4, 0, 1)
		local from = yard + Vector3.new(50, 8, 30)
		local to = wallTop + Vector3.new(-25, 10, 0)
		cam.CFrame = CFrame.lookAt(from:Lerp(to, k), wallTop:Lerp(wallTop + Vector3.new(-80, 0, 0), k))
	end)
	task.wait(4)
	sub.Text = "...but the guards caught you!"
	Sound.play("Full", 0.6)
	UI.tween(overlay, 0.6, { BackgroundTransparency = 0.2 })
	task.wait(1.4)
	title.Text = "WELCOME TO " .. prison
	sub.Text = string.format(
		"Escape #%d · x%s punch, gym and Noodles forever",
		rebirths,
		Format.number(1 + rebirths * 0.5)
	)
	Sound.play("Zone", 0.8)
	DigFX.confetti()
	task.wait(3)
	conn:Disconnect()
	for _, p in beams do
		p:Destroy()
	end
	Lighting.ClockTime = oldClock
	cam.CameraType = Enum.CameraType.Custom
	UI.tween(overlay, 0.5, { BackgroundTransparency = 1 })
	title:Destroy()
	sub:Destroy()
	task.delay(0.6, function()
		overlay:Destroy()
	end)
end

-- ===== decor panel (placing) =====

local decorPanel: Panel.Panel
local function renderDecorPlace()
	for _, c in decorPanel.body:GetChildren() do
		if not c:IsA("UIGridLayout") then
			c:Destroy()
		end
	end
	local owned: { [string]: number } = {}
	for _, pair in string.split(tostring(player:GetAttribute("DecorOwned") or ""), ",") do
		local id, n = string.match(pair, "(%w+)=(%d+)")
		if id then
			owned[id] = tonumber(n) or 0
		end
	end
	local place = Remotes.get(Remotes.Names.PlaceDecor)
	local any = false
	for _, it in Extras.Decor do
		local n = owned[it.id] or 0
		if n > 0 then
			any = true
			local b = Panel.button(
				{ Size = UDim2.fromOffset(168, 40) },
				Color3.fromRGB(255, 220, 140),
				Color3.fromRGB(110, 60, 0),
				string.format("%s %s x%d", it.emoji, it.name, n)
			)
			b.Parent = decorPanel.body
			b.Activated:Connect(function()
				Sound.play("Click")
				place:FireServer(it.id)
			end)
		end
	end
	local clearB = Panel.button(
		{ Size = UDim2.fromOffset(168, 40) },
		Color3.fromRGB(255, 150, 150),
		Color3.fromRGB(110, 20, 20),
		"Pick all up"
	)
	clearB.Parent = decorPanel.body
	clearB.Activated:Connect(function()
		Remotes.get(Remotes.Names.ClearDecor):FireServer()
	end)
	decorPanel.subtitle.Text = if any then "tap to place here" else "buy decor at the Workshop"
end

function Moments.start()
	gui = UI.new("ScreenGui", {
		Name = "Moments",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		Parent = player:WaitForChild("PlayerGui"),
	})
	folder = Instance.new("Folder")
	folder.Name = "MomentsFX"
	folder.Parent = workspace

	-- hotbar slots (bottom middle) for the tunnel tools, slim pills for the big moments
	local hotbar = HUD.hotbar :: Frame
	local dynamiteBtn = UI.slot(hotbar, "Dynamite", "🧨", "BUY", 58)
	dynamiteBtn.LayoutOrder = 1
	dynamiteBtn.Visible = false
	local escapeBtn = bigButton(
		"Escape",
		"🏃 ESCAPE!",
		Color3.fromRGB(90, 230, 120),
		UDim2.new(0.5, 110, 1, -84),
		Vector2.new(220, 52)
	)
	local decorBtn = UI.slot(hotbar, "Decor", "💡", "Decor", 58)
	decorBtn.LayoutOrder = 2
	decorBtn.Visible = false
	-- your cell as a hideout (Services/Hideout): the bed and the tapestry have hold-prompts; only
	-- your own cell's are shown, labeled for what they'd do now
	local function ownPrompts(): { ProximityPrompt }
		local list = {}
		local cells = workspace:FindFirstChild("Prison") and workspace.Prison:FindFirstChild("Cells")
		if not cells then
			return list
		end
		for _, d in cells:GetDescendants() do
			if d:IsA("ProximityPrompt") and (d.Name == "SleepPrompt" or d.Name == "CoverPrompt") then
				local model = d:FindFirstAncestorWhichIsA("Model")
				while model and model:GetAttribute("Owner") == nil and model.Parent ~= cells do
					model = model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model")
				end
				d.Enabled = model ~= nil and model:GetAttribute("Owner") == player.UserId
				table.insert(list, d)
			end
		end
		return list
	end
	local function syncHideout()
		local down = player:GetAttribute("CoverDown") == true
		local hidden = player:GetAttribute("Hidden") == true
		for _, pr in ownPrompts() do
			if pr.Name == "SleepPrompt" then
				pr.ActionText = if hidden then "Get up" else "Sleep"
			else
				pr.ActionText = if down then "Uncover the hole" else "Cover the hole"
			end
		end
		if HUD.buttons then
			-- no PUNCH from bed
			HUD.buttons.Visible = not hidden and player:GetAttribute("Lifting") == nil
		end
	end
	task.delay(3, syncHideout)
	player:GetAttributeChangedSignal("Cell"):Connect(syncHideout)
	player:GetAttributeChangedSignal("CoverDown"):Connect(syncHideout)
	player:GetAttributeChangedSignal("Hidden"):Connect(syncHideout)
	-- ceiling fans (Mess Hall) turn slowly
	local fans: { { model: Model, base: CFrame, speed: number } } = {}
	local function addFan(m: Instance)
		if m:IsA("Model") then
			table.insert(fans, { model = m, base = m:GetPivot(), speed = 1.6 + (#fans % 3) * 0.25 })
		end
	end
	for _, m in CollectionService:GetTagged("CeilingFan") do
		addFan(m)
	end
	CollectionService:GetInstanceAddedSignal("CeilingFan"):Connect(addFan)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, f in fans do
			if f.model.Parent then
				f.model:PivotTo(f.base * CFrame.Angles(0, t * f.speed, 0))
			end
		end
	end)
	-- moving (joystick / jump) gets you out of bed
	local lastWake = 0
	RunService.RenderStepped:Connect(function()
		if player:GetAttribute("Hidden") ~= true then
			return
		end
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h and (h.MoveDirection.Magnitude > 0.2 or h.Jump) and os.clock() - lastWake > 1 then
			lastWake = os.clock()
			Remotes.get(Remotes.Names.Sleep):FireServer(false)
		end
	end)
	local bribeBtn = bigButton(
		"Bribe",
		"💰 BRIBE",
		Color3.fromRGB(255, 210, 70),
		UDim2.new(0.5, 110, 1, -140), -- (not on top of ESCAPE)
		Vector2.new(220, 46)
	)

	dynamiteBtn.Activated:Connect(function()
		local n = player:GetAttribute("Dynamite")
		if typeof(n) == "number" and n > 0 then
			-- light it at the block we're aiming at (the yellow outline)
			local a = DigController.getAim()
			if a then
				Remotes.get(Remotes.Names.Dynamite):FireServer(a.x, a.y, a.z)
			else
				HUD.toast("Aim at the wall first!", "info")
			end
		else
			Remotes.get(Remotes.Names.RobuxBuy):FireServer("Dynamite")
		end
	end)
	-- ESCAPE shows in your own tunnel when you can escape (not while lifting); after a tap it
	-- waits for the server, and comes back if nothing happened
	local escapeSent = 0
	escapeBtn.Activated:Connect(function()
		Remotes.get(Remotes.Names.Escape):FireServer()
		escapeSent = os.clock()
	end)
	decorPanel = Panel.new(
		"DecorPlacePanel",
		"💡 PLACE DECOR",
		Color3.fromRGB(255, 190, 100),
		Color3.fromRGB(110, 60, 0),
		Vector2.new(580, 300)
	)
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(168, 40),
		CellPadding = UDim2.fromOffset(8, 8),
		Parent = decorPanel.body,
	})
	decorPanel.onOpen = renderDecorPlace
	player:GetAttributeChangedSignal("DecorOwned"):Connect(function()
		if decorPanel.isOpen() then
			renderDecorPlace()
		end
	end)
	decorBtn.Activated:Connect(function()
		decorPanel.toggle()
	end)
	bribeBtn.Activated:Connect(function()
		Remotes.get(Remotes.Names.Bribe):FireServer()
		bribeBtn.Visible = false
	end)

	Remotes.get(Remotes.Names.Boom).OnClientEvent:Connect(boom)
	Remotes.get(Remotes.Names.EscapeReady).OnClientEvent:Connect(function()
		Sound.play("Zone", 0.6)
		HUD.toast("🌅 DAYLIGHT! Tap ESCAPE!", "good")
	end)
	escapeBtn.Visible = false
	Remotes.get(Remotes.Names.Escaped).OnClientEvent:Connect(function(rebirths, prison)
		task.spawn(escapeCinematic, rebirths, prison)
	end)

	-- guard inspection (the event card shows the countdown)
	local inspectEnds, inspectTotal = 0, 1
	local doorLight: Part? = nil
	Remotes.get(Remotes.Names.Inspect).OnClientEvent
		:Connect(function(phase: string, seconds: number, snitched: boolean)
			if phase == "warn" then
				inspectEnds = os.clock() + seconds
				inspectTotal = seconds
				bribeBtn.Visible = snitched
				HUD.toast(
					string.format(
						"👮 FOOTSTEPS... a guard is coming in %ds! Cover the hole and get in bed!",
						seconds
					),
					"bad"
				)
				Sound.play("Full", 0.4, 0.6)
				local cell = player:GetAttribute("Cell")
				if typeof(cell) == "number" and cell > 0 then
					local frame = Tunnel.frame(cell)
					local p = Instance.new("Part")
					p.Anchored = true
					p.CanCollide = false
					p.CanQuery = false
					p.Transparency = 1
					p.Size = Vector3.one
					p.CFrame = frame * CFrame.new(0, 1, World.CellDepth - 1)
					local l = Instance.new("SpotLight")
					l.Range = 24
					l.Angle = 50
					l.Brightness = 5
					l.Color = Color3.fromRGB(255, 250, 220)
					l.Face = Enum.NormalId.Back
					l.Parent = p
					p.Parent = folder
					doorLight = p
				end
				for i = 1, seconds do
					task.delay(i - 1, function()
						Sound.play("Punch", 0.25, 0.5)
					end)
				end
			else
				inspectEnds = 0
				bribeBtn.Visible = false
				if doorLight then
					doorLight:Destroy()
					doorLight = nil
				end
				if phase == "caught" then
					Shake.kick(0.6)
					Sound.play("Full", 0.6)
				end
			end
		end)

	-- events
	-- a slim card under the top bar while an event runs: icon, name, what it does, time left
	local eventCard = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(330, 44),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.18,
		Visible = false,
		Parent = gui,
	}, { UI.corner(12), UI.stroke(Color3.fromRGB(255, 170, 70), 1, 0.5) })
	UI.scaleObject(eventCard)
	local eventIcon = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(32, 32),
		Text = "",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = eventCard,
	})
	local eventName = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(46, 5),
		Size = UDim2.new(1, -110, 0, 18),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 190, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = eventCard,
	})
	local eventText = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(46, 23),
		Size = UDim2.new(1, -110, 0, 15),
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(200, 204, 214),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = eventCard,
	})
	local eventTime = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(56, 20),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = eventCard,
	})
	local eventBar = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -3),
		Size = UDim2.new(1, -24, 0, 2),
		BackgroundColor3 = Color3.fromRGB(255, 170, 70),
		BorderSizePixel = 0,
		Parent = eventCard,
	}, { UI.corner(1) })
	local eventScale = UI.new("UIScale", { Parent = eventIcon })
	Remotes.get(Remotes.Names.Event).OnClientEvent:Connect(function(id: string)
		local cfg = Cycle.Events[id]
		if not cfg then
			return
		end
		HUD.toast(cfg.emoji .. " " .. cfg.name .. "! " .. cfg.text, "cash")
		Sound.play("Upgrade", 0.6, 0.8)
		Shake.kick(0.3)
		eventScale.Scale = 2
		UI.tween(eventScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		if id == "EARTHQUAKE" then
			-- rumble for a few seconds
			Sound.play("Boom", 0.8, 0.6)
			for i = 0, 14 do
				task.delay(i * 0.2, function()
					Shake.kick(0.5 - i * 0.025)
				end)
			end
		end
	end)

	-- treasure marker in your tunnel
	local marker: Part? = nil
	Remotes.get(Remotes.Names.Treasure).OnClientEvent:Connect(function(x: number?, y: number?, z: number?)
		if marker then
			marker:Destroy()
			marker = nil
		end
		local cell = player:GetAttribute("Cell")
		if not x or not y or not z or typeof(cell) ~= "number" or cell <= 0 then
			return
		end
		local frame = Tunnel.frame(cell)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.CFrame = CFrame.new(Tunnel.blockCenter(frame, x, y, z))
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(160, 60)
		bb.AlwaysOnTop = true
		bb.Parent = p
		UI.bigText({
			Size = UDim2.fromScale(1, 1),
			Text = string.format("💰 TREASURE\n%dm", z),
			TextColor3 = Color3.fromRGB(255, 220, 70),
			Parent = bb,
		})
		p.Parent = folder
		marker = p
		LootToast.show({
			icon = "💰",
			title = "Treasure at " .. z .. "m",
			tag = "In your tunnel",
			color = Color3.fromRGB(240, 190, 50),
			shine = true,
			seconds = 4,
		})
	end)

	-- rewards
	Remotes.get(Remotes.Names.Reward).OnClientEvent:Connect(function(_kind: string, text: string)
		LootToast.show({ icon = "🎁", title = text, tag = "Reward", color = Color3.fromRGB(240, 180, 50) })
		Sound.play("Dump", 0.6)
	end)

	-- VIP door opens for VIPs (locally), VIP chat tag
	local function vipDoors()
		local vip = player:GetAttribute("VIP") == true
		for _, d in CollectionService:GetTagged("VIPDoor") do
			(d :: BasePart).CanCollide = not vip
		end
		-- VIPs see the velvet rope unhooked
		for _, d in CollectionService:GetTagged("VIPRope") do
			(d :: BasePart).Transparency = if vip then 1 else 0
		end
	end
	player:GetAttributeChangedSignal("VIP"):Connect(vipDoors)
	vipDoors()
	pcall(function()
		TextChatService.OnIncomingMessage = function(message: TextChatMessage)
			local props = Instance.new("TextChatMessageProperties")
			local src = message.TextSource
			local p = src and Players:GetPlayerByUserId(src.UserId)
			if p and p:GetAttribute("VIP") == true then
				props.PrefixText = "<font color='#FFC828'>[VIP]</font> " .. message.PrefixText
			end
			return props
		end
	end)

	-- context visibility
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local cell, _z = CameraController.where()
		local mine = cell ~= nil and cell == player:GetAttribute("Cell")
		local inTunnel = mine and CameraController.inTunnel()
		dynamiteBtn.Visible = inTunnel
		local n = player:GetAttribute("Dynamite")
		local label = dynamiteBtn:FindFirstChild("Label") :: TextLabel
		label.Text = if typeof(n) == "number" and n > 0 then "x" .. n else "BUY"
		decorBtn.Visible = inTunnel
		escapeBtn.Visible = player:GetAttribute("CanEscape") == true
			and inTunnel
			and player:GetAttribute("Lifting") == nil
			and os.clock() - escapeSent > 5
		-- event timer
		local ev = ReplicatedStorage:GetAttribute("Event")
		local cfg = if typeof(ev) == "string" then Cycle.Events[ev] else nil
		if os.clock() < inspectEnds then
			local left = inspectEnds - os.clock()
			eventIcon.Text = "👮"
			eventName.Text = "GUARD INSPECTION"
			eventText.Text = "Cover the hole and get in your bed!"
			eventTime.Text = string.format("%ds", math.ceil(left))
			eventBar.Size = UDim2.new(math.clamp(left / inspectTotal, 0, 1), -24, 0, 2)
			eventCard.Visible = true
		elseif cfg then
			local ends = ReplicatedStorage:GetAttribute("EventEnds")
			local left = if typeof(ends) == "number"
				then math.max(0, ends - workspace:GetServerTimeNow())
				else 0
			eventIcon.Text = cfg.emoji
			eventName.Text = cfg.name
			eventText.Text = cfg.text
			eventTime.Text = Format.duration(left)
			eventBar.Size = UDim2.new(math.clamp(left / cfg.seconds, 0, 1), -24, 0, 2)
			eventCard.Visible = true
		else
			eventCard.Visible = false
		end
	end)
end

return Moments
