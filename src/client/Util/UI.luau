--!strict
-- Tiny helpers for building UI and effects in code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local UI = {}

-- UI.new("Frame", { Size = ..., Parent = ... }, { child, child })
function UI.new(className: string, props: { [string]: any }?, children: { any }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Returns `any` so mixed child lists like { UI.corner(), UI.stroke() } type-check.
function UI.corner(radius: number?): any
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

-- Slim style: borders and text outlines are capped thin everywhere (the HUD reference look).
UI.MAX_STROKE = 2
UI.MAX_TEXT_STROKE = 1.6

function UI.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = math.min(thickness or 1.5, UI.MAX_STROKE),
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.textStroke(color: Color3, thickness: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color,
		Thickness = math.min(thickness or 1.4, UI.MAX_TEXT_STROKE),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UI.gradient(top: Color3, bottom: Color3): UIGradient
	return UI.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function UI.label(props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
	}
	for k, v in props do
		base[k] = v
	end
	return UI.new("TextLabel", base)
end

-- Big chunky simulator-style text: heavy font with a thick dark outline.
function UI.bigText(props: { [string]: any }, strokeColor: Color3?, thickness: number?): TextLabel
	local base: { [string]: any } = { Font = Enum.Font.FredokaOne } -- the genre's rounded bold font
	for k, v in props do
		base[k] = v
	end
	local l = UI.label(base)
	UI.textStroke(strokeColor or Color3.fromRGB(15, 15, 20), thickness or 1.4).Parent = l
	return l
end

function UI.tween(
	inst: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- Quick scale "bump" on a GuiObject that has a UIScale child named "Bump".
function UI.bump(gui: GuiObject, amount: number?)
	local scale = gui:FindFirstChild("Bump") :: UIScale?
	if not scale then
		scale = UI.new("UIScale", { Name = "Bump", Parent = gui })
	end
	assert(scale, "bump scale missing")
	scale.Scale = 1 + (amount or 0.15)
	UI.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Icon by name: the uploaded image from Config/Assets.Images if set, otherwise an emoji.
function UI.icon(name: string, emoji: string): GuiObject
	local id = (Assets.Images :: any)[name] :: string?
	if id and id ~= "" then
		return UI.new("ImageLabel", {
			Name = name .. "Icon",
			BackgroundTransparency = 1,
			Image = id,
			ScaleType = Enum.ScaleType.Fit,
		})
	end
	return UI.new("TextLabel", {
		Name = name .. "Icon",
		BackgroundTransparency = 1,
		Text = emoji,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
	})
end

-- HUD scale: phones in landscape are ~390 pt tall; bigger on tablets/PC.
-- A landscape iPhone (852x393 pt) lands at ~0.61: the HUD hugs the corners and leaves the
-- middle of the screen to the game (playtest feedback: 0.75 covered too much).
function UI.screenScale(): number
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(852, 393)
	return math.clamp(math.min(size.Y / 640, size.X / 1150), 0.55, 1.15)
end

-- Menus/panels are drawn bigger than the HUD widgets: on a landscape iPhone a 600x330 panel
-- lands at ~440x240, big enough to read and tap.
UI.PANEL_SCALE = 1.2

-- Scales one GuiObject (and its children) with UI.screenScale() * factor. Use this for boxes
-- in a full-screen layer, so full-screen backdrops stay full-screen.
function UI.scaleObject(obj: GuiObject, factor: number?)
	local scale: UIScale = UI.new("UIScale", { Parent = obj })
	local f = factor or 1
	scale.Scale = UI.screenScale() * f
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			scale.Scale = UI.screenScale() * f
		end)
	end
end

function UI.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- ===== the HUD kit (slim buttons, slim text) =====

UI.INK = Color3.fromRGB(18, 18, 26)

-- Tiny outlined text, left-aligned unless told otherwise.
function UI.slimText(props: { [string]: any }): TextLabel
	local base: { [string]: any } = { TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in props do
		base[k] = v
	end
	return UI.bigText(base, UI.INK, 1.4)
end

-- Square icon tile with a glossy gradient and a small label over its bottom edge
-- (like "Store" / "Index"). Returns the button.
function UI.tile(
	parent: Instance,
	name: string,
	emoji: string,
	label: string?,
	top: Color3,
	bottom: Color3,
	size: number?
): TextButton
	local s = size or 62
	local b: TextButton = UI.new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(s, s),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = true,
		Parent = parent,
	}, {
		UI.corner(math.floor(s * 0.22)),
		UI.stroke(UI.INK, 2),
		UI.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 }),
	})
	UI.new("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.12, if label then 0.04 else 0.12),
		Size = UDim2.fromScale(0.76, if label then 0.66 else 0.76),
		Text = emoji,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = b,
	})
	if label then
		UI.bigText({
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(1.15, 0, 0.32, 0),
			Text = label,
			ZIndex = 3,
			Parent = b,
		}, UI.INK, 1.6)
	end
	return b
end

-- Red notification bubble in a tile's top-right corner ("!" or a count). Empty text hides it.
function UI.badge(parent: GuiObject, text: string, color: Color3?): TextLabel
	local existing = parent:FindFirstChild("Badge") :: TextLabel?
	local l = existing
		or UI.new("TextLabel", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = color or Color3.fromRGB(230, 40, 50),
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 5,
			Parent = parent,
		}, {
			UI.corner(11),
			UI.stroke(Color3.new(1, 1, 1), 1.5),
			UI.new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }),
		})
	assert(l, "badge")
	l.Text = text
	l.Visible = text ~= ""
	if color then
		l.BackgroundColor3 = color
	end
	return l
end

-- A stat line without a box: emoji icon + bold colored value (like the cash / candy counters).
function UI.statLine(
	parent: Instance,
	order: number,
	emoji: string,
	color: Color3,
	height: number?
): TextLabel
	local h = height or 26
	local row = UI.new("Frame", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, h),
		Parent = parent,
	})
	UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(h, h),
		Text = emoji,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = row,
	})
	return UI.bigText({
		Name = "Value",
		Position = UDim2.fromOffset(h + 4, 1),
		Size = UDim2.new(1, -h - 4, 1, -2),
		Text = "0",
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}, UI.INK, 1.6)
end

-- Translucent round action button with a thin white ring (like the jump button).
function UI.actionButton(
	parent: Instance,
	name: string,
	emoji: string,
	label: string,
	size: number
): TextButton
	local b: TextButton = UI.new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Color3.fromRGB(25, 25, 32),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	}, {
		UI.corner(size // 2),
		UI.stroke(Color3.new(1, 1, 1), 2, 0.25),
	})
	UI.new("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.22, 0.14),
		Size = UDim2.fromScale(0.56, 0.5),
		Text = emoji,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = b,
	})
	UI.bigText({
		Name = "Label",
		Position = UDim2.fromScale(0.1, 0.62),
		Size = UDim2.fromScale(0.8, 0.2),
		Text = label,
		Parent = b,
	}, UI.INK, 1.2)
	return b
end

-- Hotbar slot: dark translucent rounded square with an icon and a tiny label / count.
function UI.slot(parent: Instance, name: string, emoji: string, label: string, size: number?): TextButton
	local s = size or 58
	local b: TextButton = UI.new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(s, s),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.35,
		Text = "",
		AutoButtonColor = true,
		Parent = parent,
	}, {
		UI.corner(10),
		UI.stroke(Color3.new(1, 1, 1), 1.5, 0.55),
	})
	UI.new("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.15, 0.08),
		Size = UDim2.fromScale(0.7, 0.66),
		Text = emoji,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = b,
	})
	UI.bigText({
		Name = "Label",
		Position = UDim2.fromScale(0.04, 0.72),
		Size = UDim2.fromScale(0.92, 0.24),
		Text = label,
		Parent = b,
	}, UI.INK, 1.2)
	return b
end

-- Small on/off switch with a label to its right (like "Slow Mode"). onChange(newValue).
function UI.toggle(
	parent: Instance,
	order: number,
	label: string,
	on: boolean,
	onChange: (boolean) -> ()
): Frame
	local row = UI.new("Frame", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = parent,
	})
	local sw: TextButton = UI.new("TextButton", {
		Size = UDim2.fromOffset(44, 24),
		BackgroundColor3 = Color3.fromRGB(70, 70, 80),
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	}, { UI.corner(6), UI.stroke(UI.INK, 1.5) })
	local knob = UI.new("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.fromRGB(110, 230, 90),
		Parent = sw,
	}, { UI.corner(5) })
	UI.bigText({
		Position = UDim2.fromOffset(50, 2),
		Size = UDim2.new(1, -50, 1, -4),
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}, UI.INK, 1.4)
	local state = on
	local function draw()
		knob.Position = UDim2.fromOffset(if state then 22 else 2, 2)
		knob.BackgroundColor3 = if state then Color3.fromRGB(110, 230, 90) else Color3.fromRGB(200, 200, 205)
	end
	draw()
	sw.Activated:Connect(function()
		state = not state
		draw()
		onChange(state)
	end)
	return row
end

return UI
