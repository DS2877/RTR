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
				{ Size = UDim2.fromOffset(170, 56) },
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
		{ Size = UDim2.fromOffset(170, 56) },
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
	local hideBtn = bigButton(
		"Hide",
		"🛏️ HIDE!",
		Color3.fromRGB(120, 160, 255),
		UDim2.new(0.5, 110, 1, -140),
		Vector2.new(220, 58)
	)
	local bribeBtn = bigButton(
		"Bribe",
		"💰 BRIBE",
		Color3.fromRGB(255, 210, 70),
		UDim2.new(0.5, 110, 1, -84),
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
	escapeBtn.Activated:Connect(function()
		Remotes.get(Remotes.Names.Escape):FireServer()
		escapeBtn.Visible = false
	end)
	decorPanel = Panel.new(
		"DecorPlacePanel",
		"💡 PLACE DECOR",
		Color3.fromRGB(255, 190, 100),
		Color3.fromRGB(110, 60, 0),
		Vector2.new(580, 300)
	)
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 56),
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
	hideBtn.Activated:Connect(function()
		Remotes.get(Remotes.Names.Hide):FireServer()
		hideBtn.Visible = false
		bribeBtn.Visible = false
		Sound.play("Click")
	end)
	bribeBtn.Activated:Connect(function()
		Remotes.get(Remotes.Names.Bribe):FireServer()
		hideBtn.Visible = false
		bribeBtn.Visible = false
	end)

	Remotes.get(Remotes.Names.Boom).OnClientEvent:Connect(boom)
	Remotes.get(Remotes.Names.EscapeReady).OnClientEvent:Connect(function()
		escapeBtn.Visible = true
		Sound.play("Zone", 0.6)
		HUD.toast("🌅 DAYLIGHT! Tap ESCAPE!", "good")
	end)
	player:GetAttributeChangedSignal("CanEscape"):Connect(function()
		escapeBtn.Visible = player:GetAttribute("CanEscape") == true
	end)
	escapeBtn.Visible = player:GetAttribute("CanEscape") == true
	Remotes.get(Remotes.Names.Escaped).OnClientEvent:Connect(function(rebirths, prison)
		task.spawn(escapeCinematic, rebirths, prison)
	end)

	-- guard inspection
	local doorLight: Part? = nil
	Remotes.get(Remotes.Names.Inspect).OnClientEvent
		:Connect(function(phase: string, seconds: number, snitched: boolean)
			if phase == "warn" then
				hideBtn.Visible = true
				bribeBtn.Visible = snitched
				HUD.toast("👮 FOOTSTEPS... a guard is coming! HIDE!", "bad")
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
				hideBtn.Visible = false
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
	local eventLabel = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.fromOffset(420, 30),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 140, 70),
		Visible = false,
		Parent = gui,
	}, DARK, 3)
	UI.scaleObject(eventLabel)
	Remotes.get(Remotes.Names.Event).OnClientEvent:Connect(function(id: string)
		local cfg = Cycle.Events[id]
		if cfg then
			HUD.toast("⚡ " .. cfg.name .. ": " .. cfg.text, "cash")
			Shake.kick(0.3)
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
		-- event timer
		local ev = ReplicatedStorage:GetAttribute("Event")
		local cfg = if typeof(ev) == "string" then Cycle.Events[ev] else nil
		if cfg then
			local ends = ReplicatedStorage:GetAttribute("EventEnds")
			local left = if typeof(ends) == "number"
				then math.max(0, ends - workspace:GetServerTimeNow())
				else 0
			eventLabel.Text = string.format("⚡ %s %s", cfg.name, Format.duration(left))
			eventLabel.Visible = false -- the Event tile on the left shows it
		else
			eventLabel.Visible = false
		end
	end)
end

return Moments
