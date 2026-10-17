--!strict
-- Slim modal panel in the same look as the loot cards and the schedule widget: dark translucent
-- glass, a thin colored accent line under a small title, the subtitle on a line of its own under
-- it, a round close button big enough for a thumb, a scrolling list of slim rows. Only one panel
-- is open at a time.
-- No dimmed backdrop: the world stays visible and the joystick keeps working; X closes.
-- Kit: Panel.new / Panel.row / Panel.text / Panel.button (all menus build rows with these).

local Players = game:GetService("Players")

local UI = require(script.Parent.UI)
local Sound = require(script.Parent.Sound)

local Panel = {}

export type Panel = {
	gui: ScreenGui,
	frame: Frame,
	body: ScrollingFrame,
	subtitle: TextLabel,
	setOpen: (open: boolean) -> (),
	toggle: () -> (),
	isOpen: () -> boolean,
	onOpen: (() -> ())?,
}

Panel.BG = Color3.fromRGB(16, 17, 22)
Panel.TEXT = Color3.fromRGB(245, 246, 250)
Panel.MUTED = Color3.fromRGB(168, 172, 186)

local all: { Panel } = {}

function Panel.new(name: string, title: string, color: Color3, dark: Color3, size: Vector2?): Panel
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local dims = size or Vector2.new(540, 300)
	local _ = dark

	local gui: ScreenGui = UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = 4,
		Enabled = false,
		Parent = playerGui,
	})

	local frame: Frame = UI.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(dims.X, dims.Y),
		BackgroundColor3 = Panel.BG,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, {
		UI.corner(14),
		UI.stroke(Color3.new(1, 1, 1), 1, 0.84),
	})
	-- Only the panel box scales (not the whole layer).
	UI.scaleObject(frame, UI.PANEL_SCALE)

	-- a soft wash of the shop's color from the top-left corner
	UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = frame,
	}, {
		UI.corner(14),
		UI.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.8),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -76, 0, 24),
		Text = title,
		Font = Enum.Font.GothamBlack,
		TextSize = 19,
		TextColor3 = Panel.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	-- accent line under the title
	UI.new("Frame", {
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.fromOffset(34, 3),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = frame,
	}, { UI.corner(2) })
	local subtitle: TextLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(58, 28),
		Size = UDim2.new(1, -120, 0, 18),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.45),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})

	local close: TextButton = UI.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = Panel.TEXT,
		AutoButtonColor = true,
		ZIndex = 5,
		Parent = frame,
	}, { UI.corner(22) })

	local body: ScrollingFrame = UI.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(12, 54),
		Size = UDim2.new(1, -24, 1, -64),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Color3.new(1, 1, 1),
		ScrollBarImageTransparency = 0.6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	})

	local panel: Panel
	panel = {
		gui = gui,
		frame = frame,
		body = body,
		subtitle = subtitle,
		setOpen = function(open: boolean)
			if open then
				for _, other in all do
					if other ~= panel then
						other.gui.Enabled = false
					end
				end
			end
			gui.Enabled = open
			if open then
				Sound.play("Open")
				-- small slide-up (the frame's UIScale is used for screen scaling)
				frame.Position = UDim2.fromScale(0.5, 0.56)
				UI.tween(frame, 0.22, { Position = UDim2.fromScale(0.5, 0.53) }, Enum.EasingStyle.Quint)
				if panel.onOpen then
					panel.onOpen()
				end
			end
		end,
		toggle = function()
			panel.setOpen(not gui.Enabled)
		end,
		isOpen = function()
			return gui.Enabled
		end,
		onOpen = nil,
	}
	close.Activated:Connect(function()
		panel.setOpen(false)
	end)
	table.insert(all, panel)
	return panel
end

function Panel.anyOpen(): boolean
	for _, p in all do
		if p.gui.Enabled then
			return true
		end
	end
	return false
end

-- One slim list row (a faint glass strip).
function Panel.row(body: Instance, order: number, height: number?): Frame
	return UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -6, 0, height or 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.95,
		Parent = body,
	}, { UI.corner(10), UI.stroke(Color3.new(1, 1, 1), 1, 0.92) })
end

local KINDS: { [string]: { font: Enum.Font, size: number, color: Color3 } } = {
	title = { font = Enum.Font.GothamBold, size = 16, color = Panel.TEXT },
	desc = { font = Enum.Font.GothamMedium, size = 13, color = Panel.MUTED },
	note = { font = Enum.Font.GothamBold, size = 13, color = Color3.fromRGB(255, 200, 120) },
}

-- Text in the panel style. kind = "title" | "desc" | "note"; props override (Position, Size,
-- TextColor3, LayoutOrder, Parent, ...).
function Panel.text(kind: string, text: string, props: { [string]: any }): TextLabel
	local k = KINDS[kind] or KINDS.desc
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Text = text,
		Font = k.font,
		TextSize = k.size,
		TextColor3 = k.color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = kind ~= "title",
		TextTruncate = if kind == "title" then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
	}
	for key, v in props do
		base[key] = v
	end
	return UI.new("TextLabel", base)
end

-- A slim pill button. A grey color (r == g == b) means "not available": drawn as a faint
-- outline with muted text. Returns (button, label).
function Panel.button(
	props: { [string]: any },
	color: Color3,
	dark: Color3,
	text: string
): (TextButton, TextLabel)
	local _ = dark
	local muted = math.abs(color.R - color.G) < 0.01 and math.abs(color.G - color.B) < 0.01
	local light = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B > 0.6
	local base: { [string]: any } = {
		BackgroundColor3 = if muted then Color3.new(1, 1, 1) else color,
		BackgroundTransparency = if muted then 0.93 else 0,
		AutoButtonColor = true,
		Text = "",
	}
	for k, v in props do
		base[k] = v
	end
	local b: TextButton = UI.new("TextButton", base, {
		UI.corner(9),
		if muted
			then UI.stroke(Color3.new(1, 1, 1), 1, 0.85)
			else UI.new("UIGradient", {
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
				Rotation = 90,
			}),
	})
	local l: TextLabel = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0),
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = if muted then Panel.MUTED elseif light then UI.INK else Color3.new(1, 1, 1),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = b,
	})
	return b, l
end

return Panel
