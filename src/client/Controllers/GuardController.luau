--!strict
-- The patrolling guards on the client: blocky officers (cap, badge, baton) walking their routes
-- from the server clock (Shared/Patrol), legs and arms swinging, looking around at the corners,
-- flashlights on at night, and slim speech bubbles with whatever the server says they say.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Patrol)
local PatrolMath = require(Shared.Patrol)

local GuardController = {}

local NAVY = Color3.fromRGB(38, 52, 84)
local DARK_NAVY = Color3.fromRGB(26, 34, 54)
local SKIN = Color3.fromRGB(234, 184, 146)
local GOLD = Color3.fromRGB(226, 182, 70)

type Guard = {
	model: Model,
	parts: { [string]: BasePart },
	offsets: { [string]: CFrame },
	light: SpotLight,
	bubble: BillboardGui,
	box: Frame,
	text: TextLabel,
	scale: UIScale,
	shownAt: number,
	-- a real avatar (from ReplicatedStorage.NPCTemplates.Guard) once it's there
	avatar: { hrp: BasePart, off: number, walk: AnimationTrack?, idle: AnimationTrack? }?,
}

local Assets = require(Shared.Config.Assets)

-- Swaps a blocky guard for the avatar template: same bubble + flashlight, walk/idle animations.
local function toAvatar(g: Guard, template: Model, parent: Instance, index: number)
	local rig = template:Clone()
	rig.Name = g.model.Name
	local hrp = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = rig:FindFirstChild("Head") :: BasePart?
	local hand = rig:FindFirstChild("RightHand") :: BasePart?
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not hrp or not head or not humanoid then
		rig:Destroy()
		return
	end
	hrp.Anchored = true
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	-- the flashlight in the right hand
	if hand then
		local torch = Instance.new("Part")
		torch.Name = "Flashlight"
		torch.Size = Vector3.new(0.25, 0.25, 0.8)
		torch.Color = Color3.fromRGB(40, 40, 44)
		torch.Material = Enum.Material.Metal
		torch.CanCollide = false
		torch.CanQuery = false
		torch.Massless = true
		torch.CFrame = hand.CFrame * CFrame.new(0, -0.15, -0.35)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = torch
		weld.Parent = torch
		torch.Parent = rig
		g.light.Face = Enum.NormalId.Front
		g.light.Parent = torch
	end
	g.bubble.Parent = head
	-- each guard its own skin tone (the template is built with the first one)
	local bc = rig:FindFirstChildOfClass("BodyColors")
	if bc then
		local c = Assets.Skin[(index * 2 - 1) % #Assets.Skin + 1]
		local tone = Color3.fromRGB(c[1], c[2], c[3])
		bc.HeadColor3, bc.TorsoColor3 = tone, tone
		bc.LeftArmColor3, bc.RightArmColor3 = tone, tone
		bc.LeftLegColor3, bc.RightLegColor3 = tone, tone
	end
	-- into the world FIRST: LoadAnimation fails (silently, in the pcall) on a rig that isn't in
	-- the DataModel yet, which left the guards gliding along without moving a limb
	g.model:Destroy()
	g.model = rig
	rig.Parent = parent
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local function load(id: string): AnimationTrack?
		local ok, track = pcall(function()
			local a = Instance.new("Animation")
			a.AnimationId = id
			return (animator :: Animator):LoadAnimation(a)
		end)
		if ok and track then
			track.Looped = true
			return track
		end
		return nil
	end
	local off = rig:GetAttribute("FeetOffset")
	g.avatar = {
		hrp = hrp,
		off = if typeof(off) == "number" then off else 3,
		walk = load(Assets.Animations.WalkR15),
		idle = load(Assets.Animations.IdleR15),
	}
end

local function part(m: Model, name: string, size: Vector3, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local function build(i: number, parent: Instance): Guard
	local spec = Config.Guards[i]
	local m = Instance.new("Model")
	m.Name = spec.name
	local parts: { [string]: BasePart } = {}
	local offsets: { [string]: CFrame } = {}
	-- offsets are relative to the feet (y = 0), facing -Z
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material?)
		parts[name] = part(m, name, size, color, mat)
		offsets[name] = offset
	end
	add("LegL", Vector3.new(0.95, 2.4, 1), CFrame.new(-0.5, 1.2, 0), DARK_NAVY)
	add("LegR", Vector3.new(0.95, 2.4, 1), CFrame.new(0.5, 1.2, 0), DARK_NAVY)
	add("Torso", Vector3.new(2.2, 2.2, 1.1), CFrame.new(0, 3.5, 0), NAVY)
	add("Belt", Vector3.new(2.25, 0.35, 1.15), CFrame.new(0, 2.5, 0), Color3.fromRGB(20, 20, 22))
	add("Badge", Vector3.new(0.4, 0.5, 0.1), CFrame.new(-0.5, 4, -0.58), GOLD, Enum.Material.Metal)
	add("Baton", Vector3.new(0.25, 1.6, 0.25), CFrame.new(1.2, 2.2, 0.2), Color3.fromRGB(15, 15, 18))
	add("ArmL", Vector3.new(0.8, 2.1, 0.8), CFrame.new(-1.5, 3.5, 0), NAVY)
	add("ArmR", Vector3.new(0.8, 2.1, 0.8), CFrame.new(1.5, 3.5, 0), NAVY)
	add("Head", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 5.3, 0), SKIN)
	add("Cap", Vector3.new(1.6, 0.5, 1.6), CFrame.new(0, 6.15, 0), DARK_NAVY)
	add("Brim", Vector3.new(1.7, 0.15, 0.6), CFrame.new(0, 5.88, -1), DARK_NAVY)
	add("CapBadge", Vector3.new(0.4, 0.3, 0.1), CFrame.new(0, 6.15, -0.82), GOLD, Enum.Material.Metal)
	add("Shades", Vector3.new(1.52, 0.3, 0.2), CFrame.new(0, 5.45, -0.8), Color3.fromRGB(10, 10, 12))
	add("Mustache", Vector3.new(0.8, 0.15, 0.1), CFrame.new(0, 4.95, -0.72), Color3.fromRGB(60, 40, 30))
	add("Flashlight", Vector3.new(0.3, 0.3, 0.9), CFrame.new(1.5, 2.5, -0.6), Color3.fromRGB(40, 40, 44))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom -- the hand points it forward (arm raised)
	light.Angle = 45
	light.Range = 24
	light.Brightness = 2.2
	light.Color = Color3.fromRGB(255, 244, 210)
	light.Shadows = true
	light.Enabled = false
	light.Parent = parts.Flashlight
	-- speech bubble: a small translucent sign floating over the head, sized in studs (it shrinks
	-- with distance like the guard does, so it never covers the screen)
	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.new(9, 0, 1.9, 0)
	bubble.StudsOffset = Vector3.new(0, 2.2, 0)
	bubble.MaxDistance = 45
	bubble.LightInfluence = 0
	bubble.Enabled = false
	bubble.Parent = parts.Head
	local box = Instance.new("Frame")
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	box.BackgroundTransparency = 0.4
	box.BorderSizePixel = 0
	box.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = box
	local scale = Instance.new("UIScale")
	scale.Parent = box
	local short = string.match(spec.name, "(%S+)$") or spec.name
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	text.Size = UDim2.fromScale(0.92, 0.78)
	text.Font = Enum.Font.GothamMedium
	text.TextScaled = true
	text.TextWrapped = true
	text.RichText = true
	text.TextColor3 = Color3.fromRGB(236, 238, 244)
	text.Text = ""
	text:SetAttribute("Who", short)
	text.Parent = box
	m.Parent = parent
	return {
		model = m,
		parts = parts,
		offsets = offsets,
		light = light,
		bubble = bubble,
		box = box,
		text = text,
		scale = scale,
		shownAt = 0,
	}
end

function GuardController.start()
	local folder = Instance.new("Folder")
	folder.Name = "PatrolGuards"
	folder.Parent = workspace
	local guards: { Guard } = {}
	for i in Config.Guards do
		guards[i] = build(i, folder)
	end
	-- real avatars as soon as the server published the template
	task.spawn(function()
		local templates = ReplicatedStorage:WaitForChild("NPCTemplates", 60)
		local t = templates and templates:WaitForChild("Guard", 60)
		if t and t:IsA("Model") then
			for i, g in guards do
				local ok, err = pcall(toAvatar, g, t, folder, i)
				if not ok then
					warn("[GuardController] avatar failed", err)
				end
			end
		end
	end)
	-- the speech bubbles wait for the server's Patrol folder in the background (start() must not
	-- block the controllers after it)
	local said: Instance? = nil
	local function show(i: number)
		local g = guards[i]
		local src = said
		if not g or not src then
			return
		end
		local text = src:GetAttribute("Say" .. i)
		if typeof(text) ~= "string" then
			return
		end
		local who = tostring(g.text:GetAttribute("Who") or "")
		local safe = string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
		g.text.Text = '<font color="#8FB4FF"><b>' .. who .. ":</b></font> " .. safe
		g.text.TextTransparency = 0
		g.box.BackgroundTransparency = 0.4
		g.bubble.Enabled = true
		g.shownAt = os.clock()
		g.scale.Scale = 0.9
		TweenService:Create(g.scale, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { Scale = 1 }):Play()
	end
	task.spawn(function()
		local folderPatrol = ReplicatedStorage:WaitForChild("Patrol", 30)
		if not folderPatrol then
			return
		end
		said = folderPatrol
		for i in Config.Guards do
			folderPatrol:GetAttributeChangedSignal("SayAt" .. i):Connect(function()
				show(i)
			end)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local p = ReplicatedStorage:GetAttribute("Phase")
		local phase = if typeof(p) == "string" then p else "Day"
		local t = workspace:GetServerTimeNow()
		local dark = phase == "Night" or phase == "LightsOut"
		local now = os.clock()
		for i, g in guards do
			local pose = PatrolMath.guard(i, phase, t)
			local look = if pose.walking then 0 else math.sin(t * 1.3 + i) * 0.7
			local base = CFrame.new(pose.x, 0, pose.z) * CFrame.Angles(0, pose.heading + math.pi, 0)
			local swing = if pose.walking then math.sin(t * 7 + i) * 0.5 else 0
			local bob = if pose.walking then math.abs(math.sin(t * 7 + i)) * 0.12 else 0
			local av = g.avatar
			if av then
				-- the avatar walks its route; its animations do the legs and arms
				av.hrp.CFrame = base
					* CFrame.new(0, av.off, 0)
					* CFrame.Angles(0, if pose.walking then 0 else look * 0.6, 0)
				local walkT, idleT = av.walk, av.idle
				local on, off = if pose.walking then walkT else idleT, if pose.walking then idleT else walkT
				if on and not on.IsPlaying then
					on:Play(0.25, 1, if pose.walking then Config.Speed / 9 else 1)
				end
				if off and off.IsPlaying then
					off:Stop(0.25)
				end
				g.light.Enabled = dark
			end
			for name, bp in (if av then {} else g.parts) :: { [string]: BasePart } do
				local o = g.offsets[name]
				local cf = base * CFrame.new(0, bob, 0)
				if name == "LegL" or name == "LegR" then
					local s = if name == "LegL" then swing else -swing
					cf = cf * CFrame.new(o.X, 2.4, 0) * CFrame.Angles(s, 0, 0) * CFrame.new(0, -1.2, 0)
				elseif name == "ArmL" then
					cf = cf
						* CFrame.new(o.X, 4.5, 0)
						* CFrame.Angles(-swing * 0.8, 0, 0)
						* CFrame.new(0, -1, 0)
				elseif name == "ArmR" or name == "Flashlight" then
					-- right arm holds the flashlight forward at night
					local raise = if dark then 1.2 else -swing * 0.8
					cf = cf * CFrame.new(1.5, 4.5, 0) * CFrame.Angles(raise, 0, 0)
					cf = if name == "ArmR" then cf * CFrame.new(0, -1, 0) else cf * CFrame.new(0, -2.1, -0.1)
				elseif
					name == "Head"
					or name == "Cap"
					or name == "Brim"
					or name == "CapBadge"
					or name == "Shades"
					or name == "Mustache"
				then
					-- looking around at the corners
					cf = cf * CFrame.new(0, 5.3, 0) * CFrame.Angles(0, look, 0) * CFrame.new(0, -5.3, 0) * o
				else
					cf = cf * o
				end
				bp.CFrame = cf
			end
			g.light.Enabled = dark
			if g.bubble.Enabled then
				local age = now - g.shownAt
				if age > Config.BubbleSeconds + 0.4 then
					g.bubble.Enabled = false
				elseif age > Config.BubbleSeconds then
					-- fade out
					local k = (age - Config.BubbleSeconds) / 0.4
					g.text.TextTransparency = k
					g.box.BackgroundTransparency = 0.4 + 0.6 * k
				end
			end
		end
	end)
end

return GuardController
