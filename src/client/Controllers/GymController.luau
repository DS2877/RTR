--!strict
-- The gym on the client: while you hold something over your head (server: Services/Gym), a slim
-- meter card sweeps the needle (same formula and server clock as the server). The green zone jumps
-- to a new spot after every rep (Progression.liftCenter, the server agrees), PERFECT reps build a
-- combo with named tiers, 10 clean reps = a SET bonus, and a goal line shows the next thing to
-- lift. The LIFT button replaces PUNCH; your arms go up (an Animator track, so everyone sees it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Assets = require(Shared.Config.Assets)
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
local active: { station: number, start: number, reps: number }? = nil

local GLASS = Color3.fromRGB(16, 17, 22)
local GREEN = Color3.fromRGB(90, 220, 110)
local GOLD = Color3.fromRGB(255, 205, 60)
local RED = Color3.fromRGB(255, 95, 95)
local MUTED = Color3.fromRGB(168, 172, 186)

-- ===== arms up =====

local liftTrack: AnimationTrack? = nil
local holdToken = 0

local function loadTrack(): AnimationTrack?
	local c = player.Character
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator then
		return nil
	end
	local ok, track = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = if humanoid.RigType == Enum.HumanoidRigType.R15
			then Assets.Animations.LiftR15
			else Assets.Animations.LiftR6
		return animator:LoadAnimation(a)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = Enum.AnimationPriority.Action2
	track.Looped = false
	return track
end

-- one pump: play the start of the cheer (arms going up) and freeze at the top
local function pump(speed: number)
	local t = liftTrack
	if not t then
		return
	end
	holdToken += 1
	local mine = holdToken
	if not t.IsPlaying then
		t:Play(0.12, 1, speed)
	else
		t.TimePosition = 0.05
		t:AdjustSpeed(speed)
	end
	task.delay(0.3 / speed, function()
		if holdToken == mine and t.IsPlaying then
			t:AdjustSpeed(0)
		end
	end)
end

local function stopArms()
	holdToken += 1
	if liftTrack then
		liftTrack:Stop(0.2)
		liftTrack:Destroy()
		liftTrack = nil
	end
end

-- ===== UI =====

local function text(props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		base[k] = v
	end
	return UI.new("TextLabel", base)
end

function GymController.start()
	local gui = UI.new("ScreenGui", {
		Name = "Gym",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- the meter card (bottom middle, above the hotbar)
	local card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.fromOffset(380, 92),
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.15,
		Parent = gui,
	}, { UI.corner(14), UI.stroke(Color3.new(1, 1, 1), 1, 0.84) })
	UI.scaleObject(card)
	local title = text({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.55, -14, 0, 16),
		TextSize = 14,
		Text = "",
		Parent = card,
	})
	-- SET pips (top right)
	local pips: { Frame } = {}
	local pipRow = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 11),
		Size = UDim2.fromOffset(Economy.LiftSetReps * 12, 10),
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		UI.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 4),
		}),
	})
	for i = 1, Economy.LiftSetReps do
		pips[i] = UI.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.82,
			Parent = pipRow,
		}, { UI.corner(4) })
	end
	text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18 - Economy.LiftSetReps * 12, 0, 8),
		Size = UDim2.fromOffset(40, 16),
		Text = "SET",
		TextSize = 11,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})

	local bar = UI.new("Frame", {
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9,
		ClipsDescendants = false,
		Parent = card,
	}, { UI.corner(10) })
	local zone = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = GREEN,
		BackgroundTransparency = 0.15,
		Parent = bar,
	}, { UI.corner(8) })
	local perfect = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.25, 1),
		BackgroundColor3 = GOLD,
		Parent = zone,
	}, { UI.corner(6) })
	local needle = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 4, 1, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = bar,
	}, { UI.corner(2) })
	-- a flash over the bar on every rep
	local flash = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = bar,
	}, { UI.corner(10) })

	local comboLabel = text({
		Position = UDim2.fromOffset(14, 60),
		Size = UDim2.new(0.5, -14, 0, 22),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextColor3 = GOLD,
		Parent = card,
	})
	local setLabel = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 62),
		Size = UDim2.new(0.5, -14, 0, 18),
		Text = "",
		TextSize = 13,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})

	-- goal line under the card: the next thing to lift
	local goal = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.new(1, -40, 0, 22),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local goalText = text({
		Size = UDim2.new(1, 0, 0, 14),
		Text = "",
		TextSize = 11,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = goal,
	})
	local goalBar = UI.new("Frame", {
		Position = UDim2.fromOffset(0, 17),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.85,
		Parent = goal,
	}, { UI.corner(2) })
	local goalFill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GREEN,
		Parent = goalBar,
	}, { UI.corner(2) })

	-- feedback above the character: PERFECT! / GOOD / OOF + the gain
	local popHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(420, 90),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(popHolder)
	local pop = text({
		Size = UDim2.new(1, 0, 0, 44),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = popHolder,
	})
	UI.textStroke(Color3.fromRGB(10, 10, 14), 1.5).Parent = pop
	local popScale = UI.new("UIScale", { Parent = pop })
	local tierLabel = text({
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 26),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = popHolder,
	})
	UI.textStroke(Color3.fromRGB(10, 10, 14), 1.4).Parent = tierLabel
	local tierScale = UI.new("UIScale", { Parent = tierLabel })

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
	local liftRing = UI.stroke(GOLD, 2, 1)
	liftRing.Parent = liftBtn
	local downBtn = UI.actionButton(buttons, "Down", "✋", "DROP", 64)
	downBtn.Position = UDim2.new(1, -96, 1, -178)

	-- floating "+12 💪" that rises from the meter
	local function floatGain(amount: number, color: Color3)
		local l = text({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, math.random(-60, 60), 0, 0),
			Size = UDim2.fromOffset(160, 24),
			Text = "+" .. Format.number(amount) .. " 💪",
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		UI.textStroke(Color3.fromRGB(10, 10, 14), 1.2).Parent = l
		UI.tween(l, 0.9, { Position = l.Position - UDim2.fromOffset(0, 70), TextTransparency = 1 })
		task.delay(0.95, function()
			l:Destroy()
		end)
	end

	local function updateGoal()
		local strength = player:GetAttribute("Strength")
		local str = if typeof(strength) == "number" then strength else 0
		local nextSt = nil
		for _, st in Economy.Gym do
			if st.minStrength > str then
				nextSt = st
				break
			end
		end
		if nextSt then
			local prevMin = 0
			for _, st in Economy.Gym do
				if st.minStrength <= str then
					prevMin = math.max(prevMin, st.minStrength)
				end
			end
			goalText.Text = string.format(
				"NEXT  %s %s  ·  %s / %s 💪",
				nextSt.emoji,
				string.upper(nextSt.name),
				Format.number(str),
				Format.number(nextSt.minStrength)
			)
			local k = math.clamp((str - prevMin) / math.max(1, nextSt.minStrength - prevMin), 0, 1)
			UI.tween(goalFill, 0.3, { Size = UDim2.fromScale(k, 1) })
		else
			goalText.Text = "YOU CAN LIFT EVERYTHING. EVEN THE BUS."
			goalFill.Size = UDim2.fromScale(1, 1)
		end
	end
	player:GetAttributeChangedSignal("Strength"):Connect(function()
		if active then
			updateGoal()
		end
	end)

	local function moveZone(station: number, reps: number, instant: boolean)
		local c = Progression.liftCenter(station, reps)
		if instant then
			zone.Position = UDim2.fromScale(c, 0)
		else
			UI.tween(zone, 0.18, { Position = UDim2.fromScale(c, 0) }, Enum.EasingStyle.Quint)
		end
	end

	local function setPips(clean: number)
		local filled = clean % Economy.LiftSetReps
		for i, p in pips do
			local on = i <= filled
			p.BackgroundColor3 = if on then GREEN else Color3.new(1, 1, 1)
			p.BackgroundTransparency = if on then 0 else 0.82
		end
	end

	local setTotal = 0
	local prompts: { ProximityPrompt } = {}
	local function setActive(station: number?, start: number?)
		if station and start then
			active = { station = station, start = start, reps = 0 }
			local st = Economy.Gym[station]
			title.Text = st.emoji .. "  " .. string.upper(st.name)
			zone.Size = UDim2.fromScale(st.zone, 1)
			perfect.Size = UDim2.fromScale(st.perfect / st.zone, 1)
			moveZone(station, 0, true)
			setPips(0)
			setTotal = 0
			comboLabel.Text = ""
			setLabel.Text = "Tap LIFT in the green"
			pop.Text = ""
			tierLabel.Text = ""
			liftRing.Transparency = 1
			updateGoal()
			gui.Enabled = true
			if HUD.buttons then
				HUD.buttons.Visible = false
			end
			-- the big "Lift" prompt would cover the meter: hide them (locally) while lifting
			prompts = {}
			for _, part in CollectionService:GetTagged("GymStation") do
				local pr = part:FindFirstChild("LiftPrompt")
				if pr and pr:IsA("ProximityPrompt") then
					pr.Enabled = false
					table.insert(prompts, pr)
				end
			end
			stopArms()
			liftTrack = loadTrack()
			pump(1)
		else
			active = nil
			gui.Enabled = false
			if HUD.buttons then
				HUD.buttons.Visible = true
			end
			for _, pr in prompts do
				pr.Enabled = true
			end
			prompts = {}
			stopArms()
		end
	end

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
		pump(2.2)
	end)
	downBtn.Activated:Connect(function()
		Remotes.get(Remotes.Names.GymStop):FireServer()
	end)

	Remotes.get(Remotes.Names.LiftStart).OnClientEvent:Connect(function(station, start)
		setActive(station, start)
		Sound.play("Land", 0.5, 0.8)
	end)
	Remotes.get(Remotes.Names.LiftStop).OnClientEvent:Connect(function()
		setActive(nil, nil)
		Sound.play("Land", 0.6, 0.9)
	end)
	player.CharacterAdded:Connect(function()
		setActive(nil, nil)
	end)

	local popToken = 0
	local lastTier = 0
	Remotes.get(Remotes.Names.Lifted).OnClientEvent
		:Connect(function(gain: number, q: string, n: number, reps: number?, clean: number?, bonus: number?)
			local a = active
			if not a then
				return
			end
			popToken += 1
			local mine = popToken
			a.reps = reps or (a.reps + 1)
			moveZone(a.station, a.reps, false)
			setPips(clean or 0)
			setTotal += gain
			setLabel.Text = if setTotal > 0 then "+" .. Format.number(setTotal) .. " 💪 this set" else ""
			local tierIndex, tier = Progression.liftTier(n)
			if q == "perfect" then
				pop.Text = "PERFECT!"
				pop.TextColor3 = GOLD
				-- the chime climbs with the combo
				Sound.play("Chime", 0.45, 1 + math.min(n, 16) * 0.045)
				Sound.play("Fist", 0.5, 0.75)
				Shake.kick(0.2 + math.min(n, 10) * 0.02)
				flash.BackgroundColor3 = GOLD
				flash.BackgroundTransparency = 0.35
				floatGain(gain - (bonus or 0), GOLD)
			elseif q == "good" then
				pop.Text = "GOOD"
				pop.TextColor3 = GREEN
				Sound.play("Fist", 0.45, 0.9)
				Shake.kick(0.1)
				flash.BackgroundColor3 = GREEN
				flash.BackgroundTransparency = 0.6
				floatGain(gain - (bonus or 0), GREEN)
			else
				pop.Text = "OOF!"
				pop.TextColor3 = RED
				Sound.play("Land", 0.7, 0.6)
				Shake.kick(0.35)
				flash.BackgroundColor3 = RED
				flash.BackgroundTransparency = 0.45
				-- the card wobbles
				card.Rotation = 3
				UI.tween(card, 0.35, { Rotation = 0 }, Enum.EasingStyle.Elastic)
			end
			UI.tween(flash, 0.3, { BackgroundTransparency = 1 })
			popScale.Scale = 1.35
			UI.tween(popScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			-- combo multiplier + tier
			if n >= 2 then
				local mult = Economy.LiftPerfect
					* (1 + math.min((n - 1) * Economy.LiftComboStep, Economy.LiftComboMax - 1))
				comboLabel.Text = string.format("🔥 x%d  ·  %.1f×", n, mult)
				comboLabel.TextColor3 = if tier then UI.rgb(tier.color) else GOLD
				UI.bump(comboLabel :: any, 0.2)
			else
				comboLabel.Text = ""
			end
			liftRing.Color = if tier then UI.rgb(tier.color) else GOLD
			liftRing.Transparency = if tier then 0.1 else 1
			if tierIndex > lastTier and tier then
				tierLabel.Text = tier.name
				tierLabel.TextColor3 = UI.rgb(tier.color)
				tierScale.Scale = 1.8
				UI.tween(tierScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				Sound.play("Upgrade", 0.6, 0.9 + tierIndex * 0.08)
				Shake.punch(2 + tierIndex)
			elseif tierIndex == 0 then
				tierLabel.Text = ""
			end
			lastTier = tierIndex
			-- SET complete
			if bonus and bonus > 0 then
				task.delay(0.15, function()
					Sound.play("Coin", 0.7, 1.1)
					Sound.play("Upgrade", 0.5, 1.2)
					floatGain(bonus, Color3.fromRGB(140, 220, 255))
					setLabel.Text = "SET! +" .. Format.number(bonus) .. " 💪 bonus"
					setLabel.TextColor3 = Color3.fromRGB(140, 220, 255)
					task.delay(1.2, function()
						setLabel.TextColor3 = MUTED
					end)
					for _, p in pips do
						p.BackgroundColor3 = Color3.fromRGB(140, 220, 255)
						p.BackgroundTransparency = 0
						UI.tween(p, 0.6, { BackgroundTransparency = 0.82 })
					end
				end)
			end
			task.delay(0.7, function()
				if popToken == mine then
					pop.Text = ""
				end
			end)
		end)

	RunService.RenderStepped:Connect(function()
		local a = active
		if not a then
			return
		end
		local st = Economy.Gym[a.station]
		local pos = Progression.meterPos(workspace:GetServerTimeNow() - a.start, st.meter)
		needle.Position = UDim2.fromScale(pos, 0.5)
		-- the needle glows while it's inside the zone
		local q = Progression.liftQuality(pos, a.station, Progression.liftCenter(a.station, a.reps))
		needle.BackgroundColor3 = if q == "perfect"
			then GOLD
			elseif q == "good" then GREEN
			else Color3.new(1, 1, 1)
		needle.Size = if q == "miss" then UDim2.new(0, 4, 1, 12) else UDim2.new(0, 6, 1, 16)
	end)
end

return GymController
