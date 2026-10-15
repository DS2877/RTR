--!strict
-- The gym on the client: while you hold something over your head (server: Services/Gym), the
-- timing meter sweeps (same formula and server clock as the server), the LIFT button replaces
-- PUNCH, and every rep pops PERFECT! / GOOD / OOF! with a combo counter. Your arms go up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Progression = require(Shared.Progression)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)
local HUD = require(script.Parent.HUD)

local GymController = {}

local player = Players.LocalPlayer
local active: { station: number, start: number }? = nil
local baseC0: { [Motor6D]: CFrame } = {}

local function shoulders(): { Motor6D }
	local out = {}
	local c = player.Character
	if not c then
		return out
	end
	for _, side in { "Right", "Left" } do
		local upper = c:FindFirstChild(side .. "UpperArm")
		local m = upper and upper:FindFirstChild(side .. "Shoulder")
		if not m then
			local torso = c:FindFirstChild("Torso")
			m = torso and torso:FindFirstChild(side .. " Shoulder")
		end
		if m and m:IsA("Motor6D") then
			table.insert(out, m)
		end
	end
	return out
end

function GymController.start()
	local gui = UI.new("ScreenGui", {
		Name = "Gym",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- the meter: dark bar, green zone, gold perfect band, white needle
	local holder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(360, 74),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(holder)
	local title = UI.bigText({ Size = UDim2.new(1, 0, 0, 22), Text = "", Parent = holder }, UI.INK, 1.5)
	local bar = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Color3.fromRGB(40, 40, 48),
		Parent = holder,
	}, { UI.corner(13), UI.stroke(UI.INK, 2) })
	local zone = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = Color3.fromRGB(90, 210, 100),
		Parent = bar,
	}, { UI.corner(6) })
	local perfect = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.08, 1),
		BackgroundColor3 = Color3.fromRGB(255, 205, 50),
		Parent = bar,
	}, { UI.corner(4) })
	local needle = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 6, 1, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = bar,
	}, { UI.corner(3), UI.stroke(UI.INK, 1.5) })
	local hint = UI.slimText({
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 16),
		Text = "Tap LIFT in the green · gold = PERFECT",
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = holder,
	})
	local _ = hint
	-- big feedback text
	local pop = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(360, 54),
		Text = "",
		Parent = gui,
	}, UI.INK, 2)
	UI.scaleObject(pop)
	local combo = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(240, 28),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 205, 50),
		Parent = gui,
	}, UI.INK, 1.5)
	UI.scaleObject(combo)

	-- LIFT (where PUNCH is) + put down
	local buttons = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(280, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(buttons, 1.1)
	local liftBtn = UI.actionButton(buttons, "Lift", "🏋️", "LIFT", 112)
	liftBtn.Position = UDim2.new(1, -205, 1, -80)
	liftBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
	local downBtn = UI.actionButton(buttons, "Down", "✋", "DROP", 64)
	downBtn.Position = UDim2.new(1, -96, 1, -178)

	local liftRemote = Remotes.get(Remotes.Names.Lift)
	local lastTap = 0
	liftBtn.Activated:Connect(function()
		local t = os.clock()
		if not active or t - lastTap < Economy.LiftInterval then
			return
		end
		lastTap = t
		liftRemote:FireServer()
		UI.bump(liftBtn, 0.15)
		for _, m in shoulders() do
			local b = baseC0[m]
			if b then
				m.C0 = b
					* (
						if m.Parent and m.Parent.Name ~= "Torso"
							then CFrame.Angles(math.rad(200), 0, 0)
							else CFrame.Angles(
								0,
								0,
								math.rad(if m.Name:find("Right") then 200 else -200)
							)
					)
			end
		end
	end)
	downBtn.Activated:Connect(function()
		Remotes.get(Remotes.Names.GymStop):FireServer()
	end)

	local function setActive(station: number?, start: number?)
		if station and start then
			active = { station = station, start = start }
			local st = Economy.Gym[station]
			title.Text = st.emoji .. " " .. string.upper(st.name)
			zone.Size = UDim2.fromScale(st.zone, 1)
			perfect.Size = UDim2.fromScale(st.perfect, 1)
			gui.Enabled = true
			if HUD.buttons then
				HUD.buttons.Visible = false
			end
			baseC0 = {}
			for _, m in shoulders() do
				baseC0[m] = m.C0
			end
		else
			active = nil
			gui.Enabled = false
			if HUD.buttons then
				HUD.buttons.Visible = true
			end
			for m, b in baseC0 do
				if m.Parent then
					m.C0 = b
				end
			end
			baseC0 = {}
		end
	end

	Remotes.get(Remotes.Names.LiftStart).OnClientEvent:Connect(function(station, start)
		setActive(station, start)
		Sound.play("Upgrade", 0.4, 0.7)
	end)
	Remotes.get(Remotes.Names.LiftStop).OnClientEvent:Connect(function()
		setActive(nil, nil)
	end)
	player.CharacterAdded:Connect(function()
		setActive(nil, nil)
	end)

	local popToken = 0
	Remotes.get(Remotes.Names.Lifted).OnClientEvent:Connect(function(gain: number, q: string, n: number)
		popToken += 1
		local mine = popToken
		if q == "perfect" then
			pop.Text = "PERFECT! +" .. Format.number(gain) .. " 💪"
			pop.TextColor3 = Color3.fromRGB(255, 210, 60)
			Sound.play("Coin", 0.6, 1.2)
			Shake.kick(0.25)
		elseif q == "good" then
			pop.Text = "GOOD +" .. Format.number(gain) .. " 💪"
			pop.TextColor3 = Color3.fromRGB(120, 230, 120)
			Sound.play("Click", 0.5, 0.9)
			Shake.kick(0.12)
		else
			pop.Text = "OOF!"
			pop.TextColor3 = Color3.fromRGB(255, 100, 100)
			Sound.play("Punch", 0.6, 0.5)
			Shake.kick(0.35)
		end
		combo.Text = if n >= 2 then "x" .. n .. " COMBO" else ""
		UI.bump(pop :: any, 0.25)
		task.delay(0.8, function()
			if popToken == mine then
				pop.Text = ""
			end
		end)
	end)

	RunService.RenderStepped:Connect(function(dt)
		local a = active
		if not a then
			return
		end
		local st = Economy.Gym[a.station]
		local pos = Progression.meterPos(workspace:GetServerTimeNow() - a.start, st.meter)
		needle.Position = UDim2.fromScale(pos, 0.5)
		-- arms ease back to "holding it up" between reps
		for m, b in baseC0 do
			if m.Parent then
				local hold = if m.Parent.Name ~= "Torso"
					then CFrame.Angles(math.rad(170), 0, 0)
					else CFrame.Angles(0, 0, math.rad(if m.Name:find("Right") then 170 else -170))
				m.C0 = m.C0:Lerp(b * hold, math.min(1, dt * 10))
			end
		end
	end)
end

return GymController
