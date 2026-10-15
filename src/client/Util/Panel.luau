--!strict
-- Slim modal panel in the HUD style: glossy colored header band with a small outlined title,
-- small red round close button, light body with a scrolling list, thin outlines everywhere.
-- Only one panel is open at a time.
-- No dimmed backdrop: the world stays visible and the joystick keeps working; X closes.

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

local all: { Panel } = {}

function Panel.new(name: string, title: string, color: Color3, dark: Color3, size: Vector2?): Panel
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local dims = size or Vector2.new(560, 310)

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
		BackgroundColor3 = Color3.fromRGB(246, 246, 250),
		Parent = gui,
	}, {
		UI.corner(16),
		UI.stroke(UI.INK, 2),
	})
	-- Only the panel box scales (not the whole layer).
	UI.scaleObject(frame, UI.PANEL_SCALE)

	-- Header band
	local header = UI.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = color,
		Parent = frame,
	}, {
		UI.corner(16),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
			Rotation = 90,
		}),
	})
	-- square off the header's bottom corners
	UI.new("Frame", {
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = header,
	}, {
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(225, 225, 225), Color3.fromRGB(200, 200, 200)),
			Rotation = 90,
		}),
	})
	UI.bigText({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(0.55, -14, 0, 28),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = header,
	}, UI.INK, 1.6)
	local subtitle = UI.bigText({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 12),
		Size = UDim2.new(0.45, -52, 0, 22),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = header,
	}, UI.INK, 1.4)

	local close: TextButton = UI.new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = Color3.fromRGB(240, 60, 70),
		Text = "",
		ZIndex = 5,
		Parent = frame,
	}, { UI.corner(19), UI.stroke(UI.INK, 2) })
	UI.bigText({
		Position = UDim2.fromOffset(9, 8),
		Size = UDim2.new(1, -18, 1, -16),
		Text = "X",
		ZIndex = 6,
		Parent = close,
	}, UI.INK, 1.4)

	local body: ScrollingFrame = UI.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(10, 52),
		Size = UDim2.new(1, -20, 1, -60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = dark,
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
				-- small slide-up pop (the frame's UIScale is used for screen scaling)
				frame.Position = UDim2.fromScale(0.5, 0.58)
				UI.tween(frame, 0.22, { Position = UDim2.fromScale(0.5, 0.53) }, Enum.EasingStyle.Back)
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

-- A chunky colored button with big text. Returns (button, label).
function Panel.button(
	props: { [string]: any },
	color: Color3,
	dark: Color3,
	text: string
): (TextButton, TextLabel)
	local base: { [string]: any } = {
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Text = "",
	}
	for k, v in props do
		base[k] = v
	end
	local b: TextButton = UI.new("TextButton", base, {
		UI.corner(10),
		UI.stroke(UI.INK, 1.5),
		UI.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
			Rotation = 90,
		}),
	})
	local l = UI.bigText({
		Position = UDim2.fromOffset(8, 9),
		Size = UDim2.new(1, -16, 1, -18),
		Text = text,
		Parent = b,
	}, UI.INK, 1.4)
	local _ = dark
	return b, l
end

return Panel
