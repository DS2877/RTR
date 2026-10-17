--!strict
-- The prison schedule on the client: a slim widget (phase, prison time, progress, the rules right
-- now, what comes next), the LIGHTS OUT countdown with a siren, cell doors slamming, and the sky:
-- prison time runs continuously through each phase (Config/Cycle.Schedule clock ranges), with a
-- real dawn and dusk.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Cycle = require(Shared.Config.Cycle)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)

local Clock = {}

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(20, 20, 28)
local PHASE_COLOR = {
	RollCall = Color3.fromRGB(255, 214, 90),
	Day = Color3.fromRGB(120, 210, 255),
	LightsOut = Color3.fromRGB(255, 90, 90),
	Night = Color3.fromRGB(150, 140, 255),
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- the indoor ambient for this moment of the day (CameraController darkens it in tunnels)
local baseAmbient = rgb(Cycle.Look.Day.ambient)
function Clock.ambient(): Color3
	return baseAmbient
end

-- A cinematic (the Breakout night, the escape) owns the sky while this is set: the schedule
-- doesn't write Lighting and CameraController leaves Ambient alone.
Clock.override = false
function Clock.setOverride(on: boolean)
	Clock.override = on
end

function Clock.phase(): string
	local p = ReplicatedStorage:GetAttribute("Phase")
	return if typeof(p) == "string" then p else "Day"
end

local function entry(id: string): (number, any)
	for i, e in Cycle.Schedule do
		if e.id == id then
			return i, e
		end
	end
	return 2, Cycle.Schedule[2]
end

-- 0..1 how dark it is at prison time h (0..24): night, dawn 5-7.5, day, dusk 17.5-19.5
local function darkness(h: number): number
	local function smooth(a: number): number
		a = math.clamp(a, 0, 1)
		return a * a * (3 - 2 * a)
	end
	if h < 5 or h >= 19.5 then
		return 1
	elseif h < 7.5 then
		return 1 - smooth((h - 5) / 2.5)
	elseif h < 17.5 then
		return 0
	end
	return smooth((h - 17.5) / 2)
end

local function hhmm(h: number): string
	local m = math.floor((h % 24) * 60)
	return string.format("%02d:%02d", m // 60, m % 60)
end

function Clock.start()
	local gui = UI.new("ScreenGui", {
		Name = "Clock",
		ResetOnSpawn = false,
		DisplayOrder = 3,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- the schedule widget, in the top-right corner (the event card and the loot cards stack under it)
	local card: Frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(260, 76),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.3,
		Parent = gui,
	}, {
		UI.corner(10),
		UI.stroke(Color3.new(1, 1, 1), 1, 0.85),
	})
	UI.scaleObject(card)
	UI.placeRight(card, UI.RIGHT_CLOCK_Y)
	local function text(props: { [string]: any }): TextLabel
		local base: { [string]: any } = {
			BackgroundTransparency = 1,
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		}
		for k, v in props do
			base[k] = v
		end
		return UI.new("TextLabel", base)
	end
	local title = text({
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -74, 0, 20),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	local clockText = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 5),
		Size = UDim2.fromOffset(62, 20),
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(200, 205, 214),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	})
	local track = UI.new("Frame", {
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.new(1, -20, 0, 3),
		BackgroundColor3 = Color3.fromRGB(60, 62, 70),
		BorderSizePixel = 0,
		Parent = card,
	}, { UI.corner(2) })
	local fill = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	}, { UI.corner(2) })
	-- (the rules shrink a little rather than run off the card)
	local rules = text({
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -20, 0, 18),
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(215, 220, 228),
		Text = "",
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 11, Parent = rules })
	local nextText = text({
		Position = UDim2.fromOffset(10, 54),
		Size = UDim2.new(1, -20, 0, 17),
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(170, 175, 186),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	})
	-- the LIGHTS OUT countdown: big, above your character's head, clear of the toasts up top
	-- (a holder carries the screen scale, so the label's own bump scale doesn't fight it)
	local warningHolder = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(420, 52),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(warningHolder)
	local warning = UI.bigText({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 80, 80),
		Visible = false,
		Parent = warningHolder,
	}, DARK, 2)
	-- tagged parts, cached (refreshed when tags come and go) instead of looked up every frame
	local windows: { BasePart } = {}
	local windowDark = -1 -- the darkness the windows were last painted for (-1: repaint)
	local searchlights: { BasePart } = {}
	local function trackTag(tag: string, list: { BasePart })
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("BasePart") then
				table.insert(list, inst)
			end
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
			if inst:IsA("BasePart") and not table.find(list, inst) then
				table.insert(list, inst)
				windowDark = -1
			end
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
			local i = table.find(list, inst :: any)
			if i then
				table.remove(list, i)
			end
		end)
	end
	trackTag("SkyWindow", windows)
	trackTag("Searchlight", searchlights)
	local textAcc = 1

	local lastPhase = ""
	local lastSecond = -1
	local shownDark = 0
	local searchBase: { [BasePart]: CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		local phase = Clock.phase()
		local nowT = workspace:GetServerTimeNow()
		local ends = ReplicatedStorage:GetAttribute("PhaseEnds")
		local starts = ReplicatedStorage:GetAttribute("PhaseStart")
		local left = if typeof(ends) == "number" then math.max(0, ends - nowT) else 0
		local length = if typeof(ends) == "number" and typeof(starts) == "number"
			then math.max(1, ends - starts)
			else 1
		local progress = math.clamp(1 - left / length, 0, 1)
		local index, e = entry(phase)
		local _, nxt = entry(Cycle.Schedule[index % #Cycle.Schedule + 1].id)
		local color = PHASE_COLOR[phase] or Color3.new(1, 1, 1)

		-- prison time moves through the phase's clock range
		local h = (e.clock[1] + (e.clock[2] - e.clock[1]) * progress) % 24
		-- the card's text ~4 times a second (it only changes by the second anyway)
		textAcc += dt
		if textAcc >= 0.25 or phase ~= lastPhase then
			textAcc = 0
			title.Text = e.emoji .. "  " .. e.name
			title.TextColor3 = color
			clockText.Text = hhmm(h)
			fill.Size = UDim2.fromScale(progress, 1)
			fill.BackgroundColor3 = color
			rules.Text = e.rules
			local mins, secs = math.floor(left / 60), math.floor(left % 60)
			nextText.Text = string.format(
				"Next: %s %s in %s",
				nxt.emoji,
				nxt.name,
				if mins > 0 then string.format("%d:%02d", mins, secs) else string.format("%ds", secs)
			)
		end

		-- LIGHTS OUT countdown
		warning.Visible = phase == "LightsOut"
		if phase == "LightsOut" then
			local s = math.ceil(left)
			warning.Text = "LIGHTS OUT! " .. s
			if s ~= lastSecond then
				lastSecond = s
				Sound.play("Siren", 0.35, 0.9)
				UI.bump(warning :: any, 0.2)
			end
		end
		if phase ~= lastPhase then
			if phase == "Night" then
				Shake.kick(0.3)
				Sound.play("CellDoor", 0.7, 0.95) -- lockdown: every door slams
			elseif
				(phase == "RollCall" or phase == "Day")
				and lastPhase ~= ""
				and lastPhase ~= "RollCall"
			then
				Sound.play("CellDoor", 0.5, 1.1)
			end
			if lastPhase ~= "" then
				UI.bump(card, 0.12)
			end
			lastPhase = phase
		end

		-- the sky follows prison time (eased so a forced phase change doesn't snap)
		shownDark += (darkness(h) - shownDark) * math.min(1, dt * 1.5)
		local k = shownDark
		local day, night = Cycle.Look.Day, Cycle.Look.Night
		if not Clock.override then
			Lighting.ClockTime = h
			Lighting.Brightness = day.brightness + (night.brightness - day.brightness) * k
			Lighting.OutdoorAmbient = rgb(day.outdoor):Lerp(rgb(night.outdoor), k)
		end
		baseAmbient = rgb(day.ambient):Lerp(rgb(night.ambient), k)

		-- frosted windows go dark at night; the tower searchlight sweeps the Yard
		if math.abs(k - windowDark) > 0.01 then
			windowDark = k
			for _, part in windows do
				part.Color = Color3.fromRGB(210, 222, 235):Lerp(Color3.fromRGB(28, 32, 44), k)
				local sl = part:FindFirstChildOfClass("SurfaceLight")
				if sl then
					sl.Brightness = 1.2 * (1 - k)
				end
			end
		end
		local t = workspace:GetServerTimeNow()
		for _, part in searchlights do
			local base = searchBase[part]
			if not base then
				base = part.CFrame
				searchBase[part] = base
			end
			part.CFrame = base :: CFrame
				* CFrame.Angles(0, math.sin(t * 0.35) * 1.1 + 0.8, 0)
				* CFrame.Angles(math.rad(-50 + math.sin(t * 0.7) * 8), 0, 0)
			local beam = part:FindFirstChildOfClass("Beam")
			if beam then
				beam.Transparency = NumberSequence.new(0.92 - 0.2 * k, 1)
			end
		end
	end)
end

return Clock
