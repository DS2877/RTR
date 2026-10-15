--!strict
-- Small helpers for building the world in code.

local Build = {}

export type Props = { [string]: any }

function Build.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Anchored part. `cf` is the center; size in studs.
function Build.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	props: Props?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- Axis-aligned box from two corners.
function Build.box(parent: Instance, name: string, a: Vector3, b: Vector3, color: Color3, props: Props?): Part
	local lo = a:Min(b)
	local hi = a:Max(b)
	return Build.part(parent, name, hi - lo, CFrame.new((lo + hi) / 2), color, props)
end

-- Big chunky text on one face of a part.
function Build.sign(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	textColor: Color3?,
	stroke: Color3?
): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Parent = gui
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = stroke or Color3.fromRGB(20, 20, 25)
	s.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return label
end

function Build.prompt(parent: Instance, action: string, object: string, distance: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = parent
	return p
end

function Build.light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- A blocky shopkeeper / guard figure (no Humanoid: decor only). `cf` = feet position, facing LookVector.
function Build.npc(parent: Instance, name: string, cf: CFrame, shirt: Color3, hat: Color3?): Model
	local m = Instance.new("Model")
	m.Name = name
	local skin = Color3.fromRGB(234, 184, 146)
	Build.part(m, "Legs", Vector3.new(2, 2.4, 1), cf * CFrame.new(0, 1.2, 0), Color3.fromRGB(50, 55, 70))
	Build.part(m, "Torso", Vector3.new(2.2, 2.2, 1.1), cf * CFrame.new(0, 3.5, 0), shirt)
	Build.part(m, "ArmL", Vector3.new(0.8, 2.1, 0.8), cf * CFrame.new(-1.5, 3.5, 0), shirt)
	Build.part(m, "ArmR", Vector3.new(0.8, 2.1, 0.8), cf * CFrame.new(1.5, 3.5, 0), shirt)
	local head = Build.part(m, "Head", Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(0, 5.3, 0), skin)
	Build.part(
		m,
		"EyeL",
		Vector3.new(0.22, 0.3, 0.05),
		head.CFrame * CFrame.new(-0.3, 0.15, -0.71),
		Color3.new()
	)
	Build.part(
		m,
		"EyeR",
		Vector3.new(0.22, 0.3, 0.05),
		head.CFrame * CFrame.new(0.3, 0.15, -0.71),
		Color3.new()
	)
	Build.part(
		m,
		"Smile",
		Vector3.new(0.6, 0.12, 0.05),
		head.CFrame * CFrame.new(0, -0.3, -0.71),
		Color3.new()
	)
	if hat then
		Build.part(m, "Hat", Vector3.new(1.6, 0.5, 1.6), cf * CFrame.new(0, 6.2, 0), hat)
		Build.part(m, "Brim", Vector3.new(1.6, 0.15, 0.6), cf * CFrame.new(0, 6.0, -1.0), hat)
	end
	m.Parent = parent
	return m
end

return Build
