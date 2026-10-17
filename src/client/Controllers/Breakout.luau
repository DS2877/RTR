--!strict
-- THE BREAKOUT on the client: night falls, the searchlights sweep (drawn from the same shared math
-- the server checks, Shared/Breakout), two guards run your own path a few seconds behind you,
-- a slim run card shows the clock, the goal and how often you were spotted. Getting sent back
-- flashes red. The finish is a cinematic: you jump in the car, it tears off down the road, the
-- medal and the smuggled Noodles... and then the roadblock and your new, tougher prison.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Rules = require(Shared.Breakout)
local Config = require(Shared.Config.Breakout)
local Assets = require(Shared.Config.Assets)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Sound = require(Client.Util.Sound)
local Shake = require(Client.Util.Shake)
local Cinematic = require(Client.Util.Cinematic)
local DigFX = require(script.Parent.DigFX)
local Clock = require(script.Parent.Clock)

local Breakout = {}

local player = Players.LocalPlayer
local O = Vector3.new(Config.Origin.x, Config.Origin.y, Config.Origin.z)
local Y = Rules.YardY
local DARK = Color3.fromRGB(14, 15, 20)
local LIGHT = Color3.fromRGB(255, 246, 210)
local RED = Color3.fromRGB(255, 70, 70)

type Chaser = { model: Model, hrp: BasePart, off: number, walk: AnimationTrack?, delay: number }

local running = false
local gui: ScreenGui
local folder: Folder
local card: Frame
local clock: TextLabel
local goal: TextLabel
local spottedText: TextLabel
local flash: Frame
local banner: TextLabel
local dots: { Frame } = {}
local t0 = 0
local checkpoint = 1
local spotted = 0
local trail: { { t: number, p: Vector3 } } = {}
local chasers: { Chaser } = {}
local beams: { { at: Attachment, disc: BasePart, spot: BasePart } } = {}
local hidden: { ScreenGui } = {}
local savedLighting: { [string]: any } = {}
local siren: any = nil
local finishing = false -- the getaway cinematic is playing
local finishLabels: { Instance } = {} -- its texts (gone in the restore path, whatever happens)

local function world(x: number, y: number, z: number): Vector3
	return O + Vector3.new(x, y, z)
end

-- ===== the run card =====

local function buildGui()
	gui = UI.new("ScreenGui", {
		Name = "Breakout",
		ResetOnSpawn = false,
		DisplayOrder = 30,
		IgnoreGuiInset = true,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	flash = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = RED,
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = gui,
	})
	card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(400, 92),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2,
		ZIndex = 5,
		Parent = gui,
	}, { UI.corner(14), UI.stroke(RED, 1, 0.45) })
	UI.scaleObject(card)
	UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(220, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = RED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "🚨 THE BREAKOUT",
		ZIndex = 6,
		Parent = card,
	})
	clock = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 6),
		Size = UDim2.fromOffset(100, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0:00",
		ZIndex = 6,
		Parent = card,
	})
	goal = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 36),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(230, 232, 238),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		ZIndex = 6,
		Parent = card,
	})
	UI.new("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 11, Parent = goal })
	spottedText = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 70),
		Size = UDim2.fromOffset(200, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(190, 194, 206),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		ZIndex = 6,
		Parent = card,
	})
	for i = 1, 3 do
		dots[i] = UI.new("Frame", {
			Position = UDim2.fromOffset(14 + (i - 1) * 34, 77),
			Size = UDim2.fromOffset(28, 5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.75,
			ZIndex = 6,
			Parent = card,
		}, { UI.corner(2) })
	end
	banner = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.8, 0.11),
		Text = "",
		TextColor3 = RED,
		TextTransparency = 1,
		ZIndex = 8,
		Parent = gui,
	}, Color3.fromRGB(40, 0, 0), 3)
end

local function paintCard()
	goal.Text = Rules.Objectives[math.clamp(checkpoint, 1, #Rules.Objectives)]
	spottedText.Text = if spotted > 0 then "Sent back: " .. spotted else "Clean run so far"
	for i, d in dots do
		d.BackgroundTransparency = if i < checkpoint then 0 elseif i == checkpoint then 0.3 else 0.75
		d.BackgroundColor3 = if i == checkpoint then RED else Color3.new(1, 1, 1)
	end
end

local function shout(text: string, color: Color3, seconds: number)
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency = 0
	local s = banner:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = banner })
	s.Scale = 1.4
	UI.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(seconds, function()
		if banner.Text == text then
			UI.tween(banner, 0.4, { TextTransparency = 1 })
		end
	end)
end

-- ===== night =====

local NIGHT = {
	ClockTime = 0.6,
	Brightness = 0.6,
	Ambient = Color3.fromRGB(28, 32, 46),
	OutdoorAmbient = Color3.fromRGB(34, 40, 58),
	FogColor = Color3.fromRGB(10, 12, 20),
	FogEnd = 260,
	FogStart = 40,
}

local function nightOn()
	for k in NIGHT do
		savedLighting[k] = (Lighting :: any)[k]
	end
	Clock.setOverride(true)
	RunService:BindToRenderStep("BreakoutNight", Enum.RenderPriority.Last.Value, function()
		for k, v in NIGHT do
			(Lighting :: any)[k] = v
		end
	end)
end

local function nightOff()
	pcall(function()
		RunService:UnbindFromRenderStep("BreakoutNight")
	end)
	for k, v in savedLighting do
		(Lighting :: any)[k] = v
	end
	savedLighting = {}
	Clock.setOverride(false)
end

-- ===== searchlights =====

local function newBeam(head: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(head)
	anchor.Parent = folder
	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 1.2
	beam.Width1 = Config.LightRadius * 2
	beam.Color = ColorSequence.new(LIGHT)
	beam.Transparency = NumberSequence.new(0.55, 0.82)
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = anchor
	-- the bright pool on the ground (this is what gets you)
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.CastShadow = false
	disc.Material = Enum.Material.Neon
	disc.Color = LIGHT
	disc.Transparency = 0.55
	disc.Size = Vector3.new(0.12, Config.LightRadius * 2, Config.LightRadius * 2)
	disc.Parent = folder
	-- a real light on the ground so the yard actually lights up
	local spot = Instance.new("Part")
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.one
	spot.Parent = folder
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Front
	sl.Angle = 22
	sl.Range = 40
	sl.Brightness = 6
	sl.Color = LIGHT
	sl.Shadows = #beams == 0 -- (one shadow-casting light is plenty on a phone)
	sl.Parent = spot
	table.insert(beams, { at = a1, disc = disc, spot = spot })
end

local function buildLights()
	for _, t in Rules.Towers do
		newBeam(world(t.x, Y + Rules.TowerHeadY, t.z))
	end
	newBeam(world(Rules.WallTower.x, Rules.WallTopY + Rules.TowerHeadY, Rules.WallTower.z))
end

local function updateLights(t: number)
	for i, b in beams do
		local target: Vector3
		local head: Vector3
		if i <= Rules.LightCount then
			local x, z = Rules.light(i, t)
			target = world(x, Y + 0.08, z)
			local tw = Rules.Towers[i]
			head = world(tw.x, Y + Rules.TowerHeadY, tw.z)
		else
			target = world(218, Rules.WallTopY + 0.08, Rules.towerLight(t))
			head = world(Rules.WallTower.x, Rules.WallTopY + Rules.TowerHeadY, Rules.WallTower.z)
		end
		b.at.WorldPosition = target
		b.disc.CFrame = CFrame.new(target) * CFrame.Angles(0, 0, math.pi / 2)
		b.spot.CFrame = CFrame.lookAt(head, target)
	end
end

-- ===== the guards on your heels =====

local function newChaser(delay: number): Chaser?
	local templates = ReplicatedStorage:FindFirstChild("NPCTemplates")
	local t = templates and templates:FindFirstChild("Guard")
	if not t or not t:IsA("Model") then
		return nil
	end
	local m = t:Clone()
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then
		m:Destroy()
		return nil
	end
	hrp.Anchored = true
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	local head = m:FindFirstChild("Head")
	if head then
		local torch = Instance.new("SpotLight")
		torch.Face = Enum.NormalId.Front
		torch.Range = 26
		torch.Angle = 40
		torch.Brightness = 3
		torch.Color = LIGHT
		torch.Parent = head
	end
	m.Parent = folder
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local walk: AnimationTrack? = nil
	pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = Assets.Animations.WalkR15
		walk = (animator :: Animator):LoadAnimation(a)
	end)
	if walk then
		walk.Looped = true
		walk:Play(0.1, 1, 1.6)
	end
	local off = m:GetAttribute("FeetOffset")
	return {
		model = m,
		hrp = hrp,
		off = if typeof(off) == "number" then off else 3,
		walk = walk,
		delay = delay,
	}
end

local function clearChasers()
	for _, c in chasers do
		c.model:Destroy()
	end
	chasers = {}
end

local function spawnChasers()
	if #chasers > 0 then
		return
	end
	for i, d in { Config.ChaserDelay, Config.ChaserDelay + 0.9 } do
		local c = newChaser(d)
		if c then
			chasers[i] = c
		end
	end
end

-- where you were `delay` seconds ago (the oldest point we have if the trail is younger)
local function trailAt(now: number, delay: number): (Vector3?, Vector3?)
	local want = now - delay
	local prev: Vector3? = nil
	for i = #trail, 1, -1 do
		if trail[i].t <= want then
			local nxt = trail[i + 1]
			local dir = if nxt then nxt.p - trail[i].p else Vector3.zero
			return trail[i].p, dir
		end
		prev = trail[i].p
	end
	return prev, nil
end

-- ===== the run =====

local function root(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function hideHud()
	Cinematic.showHud(hidden) -- (a second start never strands the first list)
	hidden = Cinematic.hideHud(gui)
end

local function showHud()
	Cinematic.showHud(hidden)
end

local function stop()
	running = false
	finishing = false
	clearChasers()
	for _, b in beams do
		b.at:Destroy()
	end
	beams = {}
	folder:ClearAllChildren()
	trail = {}
	if siren then
		siren.stop()
		siren = nil
	end
	nightOff()
	gui.Enabled = false
	showHud()
end

local function onStart(_serverT: number, practice: boolean)
	if running then
		return
	end
	running = true
	t0 = os.clock()
	checkpoint, spotted = 1, 0
	trail = {}
	hideHud()
	gui.Enabled = true
	card.Visible = true
	paintCard()
	nightOn()
	buildLights()
	siren = Sound.loop(Assets.Sounds.Siren)
	siren.set(0.12)
	Sound.play("Alarm", 0.5)
	Shake.kick(0.5)
	shout(if practice then "PRACTICE RUN" else "RUN!", RED, 1.6)
end

local REASONS = {
	spotted = "SPOTTED!",
	caught = "THE GUARDS GOT YOU!",
	fell = "SPLASH!",
}

local function onReset(reason: string, cp: number, n: number)
	checkpoint, spotted = cp, n
	trail = {}
	clearChasers()
	paintCard()
	local text = REASONS[reason]
	if text then
		flash.BackgroundTransparency = 0.35
		UI.tween(flash, 0.8, { BackgroundTransparency = 1 })
		shout(text, RED, 1.2)
		Sound.play("Alarm", 0.6)
		Shake.kick(0.7)
	end
end

local function onCheckpoint(cp: number)
	checkpoint = cp
	trail = {}
	paintCard()
	Sound.play("Chime", 0.6, 1.2)
	Sound.play("Upgrade", 0.4, 1.3)
	shout(if cp == 2 then "OUT OF THE SEWER!" else "OVER THE TOP!", Color3.fromRGB(255, 220, 90), 1.2)
end

-- the getaway: into the car, down the road, the medal, then the roadblock
local function finishBody(
	seconds: number,
	medalId: string,
	cash: number,
	rebirths: number,
	prison: string,
	n: number,
	practice: boolean
)
	clearChasers()
	card.Visible = false
	if siren then
		siren.set(0)
	end
	local cam = workspace.CurrentCamera
	local course = workspace:FindFirstChild("Breakout")
	local car = course and course:FindFirstChild("GetawayCar")
	local character = player.Character
	-- you're in the car now
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			end
		end
	end
	local start: CFrame? = if car and car:IsA("Model") then car:GetPivot() else nil
	if cam and car and car:IsA("Model") and start then
		cam.CameraType = Enum.CameraType.Scriptable
		local value = Instance.new("CFrameValue")
		value.Value = start
		value.Changed:Connect(function(cf)
			car:PivotTo(cf)
		end)
		Sound.play("Boom", 0.4, 1.6)
		TweenService:Create(value, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Value = start * CFrame.new(0, 0, -90),
		}):Play()
		local t1 = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			if os.clock() - t1 > 7 or not running then
				conn:Disconnect()
				return
			end
			local cf = car:GetPivot()
			cam.CFrame =
				CFrame.lookAt(start.Position + Vector3.new(14, 7, 10), cf.Position + Vector3.new(0, 2, 0))
		end)
	end
	local medal = nil
	for _, m in Config.Medals do
		if m.id == medalId then
			medal = m
		end
	end
	task.wait(1.2)
	shout("YOU'RE FREE!", Color3.fromRGB(255, 220, 80), 2.4)
	Sound.play("Zone", 0.8)
	DigFX.confetti()
	local line = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.8, 0.06),
		Text = if medal
			then string.format(
				"%s %s · %s · sent back %d×",
				medal.emoji,
				medal.name,
				Format.duration(seconds),
				n
			)
			else "Out of time... but you slipped away!",
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 8,
		Parent = gui,
	}, DARK, 2)
	table.insert(finishLabels, line)
	local sub = UI.bigText({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.7, 0.045),
		Text = if practice
			then "Practice run: no reward"
			elseif cash > 0 then "+" .. Format.number(cash) .. " 🍜 smuggled into your next prison"
			else "",
		TextColor3 = Color3.fromRGB(255, 220, 90),
		ZIndex = 8,
		Parent = gui,
	}, DARK, 2)
	table.insert(finishLabels, sub)
	task.wait(3.4)
	if not practice then
		-- ...the roadblock
		flash.BackgroundColor3 = Color3.new(0, 0, 0)
		UI.tween(flash, 0.6, { BackgroundTransparency = 0.15 })
		Sound.play("Siren", 0.5)
		shout("...ROADBLOCK!", RED, 1.4)
		task.wait(1.6)
		line.Text = "WELCOME TO " .. prison
		sub.Text = string.format(
			"Escape #%d · x%s punch, gym and Noodles forever",
			rebirths,
			Format.number(1 + rebirths * 0.5)
		)
		Sound.play("Zone", 0.7)
		task.wait(2.4)
	else
		task.wait(1.5)
	end
	if car and car:IsA("Model") and start then
		car:PivotTo(start)
	end
end

-- Whatever goes wrong in the cinematic, the camera, your character, the HUD and the sky come back.
local function restoreAfterFinish()
	for _, l in finishLabels do
		l:Destroy()
	end
	finishLabels = {}
	flash.BackgroundColor3 = RED
	flash.BackgroundTransparency = 1
	local character = player.Character
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
	stop()
end

local function onFinish(...: any)
	finishing = true
	local ok, err = xpcall(finishBody, debug.traceback, ...)
	if not ok then
		warn("[Breakout] finish cinematic failed: " .. tostring(err))
	end
	restoreAfterFinish()
end

function Breakout.start()
	folder = Instance.new("Folder")
	folder.Name = "BreakoutFX"
	folder.Parent = workspace
	buildGui()
	Remotes.get(Remotes.Names.Breakout).OnClientEvent:Connect(function(kind: string, ...)
		if kind == "start" then
			onStart(...)
		elseif not running then
			return
		elseif kind == "reset" then
			onReset(...)
		elseif kind == "checkpoint" then
			onCheckpoint(...)
		elseif kind == "finish" then
			task.spawn(onFinish, ...)
		end
	end)
	-- failsafe: the run is over on the server but no finish arrived (lost event, server error)
	player:GetAttributeChangedSignal("Breakout"):Connect(function()
		if player:GetAttribute("Breakout") ~= nil or not running then
			return
		end
		task.delay(10, function()
			if running and not finishing and player:GetAttribute("Breakout") == nil then
				restoreAfterFinish()
			end
		end)
	end)
	RunService.RenderStepped:Connect(function()
		if not running then
			return
		end
		local now = os.clock()
		clock.Text = Format.duration(now - t0)
		updateLights(workspace:GetServerTimeNow())
		local r = root()
		if not r or not card.Visible then
			return
		end
		-- the guards: on your path once you're out of the sewer
		if checkpoint >= 2 then
			local last = trail[#trail]
			if not last or now - last.t > 0.05 then
				table.insert(trail, { t = now, p = r.Position })
			end
			while #trail > 2 and trail[2].t < now - Config.ChaserDelay - 2 do
				table.remove(trail, 1)
			end
			spawnChasers()
			local closest = math.huge
			for _, c in chasers do
				local p, dir = trailAt(now, c.delay)
				if p then
					local flat = if dir and dir.Magnitude > 0.01
						then Vector3.new(dir.X, 0, dir.Z)
						else Vector3.new(r.Position.X - p.X, 0, r.Position.Z - p.Z)
					local look = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
					local feet = p - Vector3.new(0, 3, 0)
					c.hrp.CFrame = CFrame.lookAt(feet, feet + look) * CFrame.new(0, c.off, 0)
					closest = math.min(closest, (p - r.Position).Magnitude)
				end
			end
			-- close behind you: the screen edges pulse red
			if closest < 8 then
				flash.BackgroundTransparency = 0.82 + math.sin(now * 12) * 0.06
			elseif flash.BackgroundTransparency < 1 and flash.BackgroundTransparency > 0.7 then
				flash.BackgroundTransparency = 1
			end
		end
	end)
end

return Breakout
