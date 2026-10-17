--!strict
-- Slim loot notifications (finds, treasure, rewards): a dark translucent bar with a glossy
-- rarity tile, a tiny rarity tag, the name and the value. Slides + fades in at the top right, stacks
-- (newest on top, max 3; 2 on a phone), then glides up and fades out. Rare+ gets a light sweep.
-- While the first-join tour runs (Controllers/Tour pauses us) cards wait and show afterwards.

local Players = game:GetService("Players")

local UI = require(script.Parent.UI)

local LootToast = {}

export type Spec = {
	icon: string,
	title: string,
	tag: string?, -- small caps line above the title ("RARE FIND")
	value: string?, -- right side ("🍜 120")
	color: Color3,
	shine: boolean?,
	seconds: number?,
}

local WIDTH = 300
local HEIGHT = 58
local GAP = 8
local MAX = 3

local holder: Frame? = nil
local stack: { CanvasGroup } = {}
local top = UI.RIGHT_LOOT_Y -- where the stack starts in the right column (Moments moves it)
local paused = false
local queue: { Spec } = {}

-- phones (screen scale under 0.75) have room for two cards above the action buttons; one while
-- the event card pushes the stack down
local function maxCards(): number
	if UI.screenScale() >= 0.75 then
		return MAX
	end
	return if top > UI.RIGHT_EVENT_Y then 1 else 2
end

local function place(h: Frame)
	h.Position = UDim2.new(1, -14, 0, 10 + top * UI.screenScale())
end

local function root(): Frame
	if holder and holder.Parent then
		return holder
	end
	local gui = UI.new("ScreenGui", {
		Name = "LootToasts",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		IgnoreGuiInset = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	local h = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		-- under the clock + event card column (Controllers/Clock, Moments)
		Size = UDim2.fromOffset(WIDTH, (HEIGHT + GAP) * MAX),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UI.scaleObject(h)
	place(h)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			place(h)
		end)
	end
	holder = h
	return h
end

local function slot(i: number): UDim2
	return UDim2.fromOffset(0, (i - 1) * (HEIGHT + GAP))
end

local function relayout()
	for i, card in stack do
		UI.tween(card, 0.25, { Position = slot(i) }, Enum.EasingStyle.Quint)
	end
end

local function dismiss(card: CanvasGroup)
	local i = table.find(stack, card)
	if not i then
		return
	end
	table.remove(stack, i)
	UI.tween(card, 0.3, { GroupTransparency = 1, Position = card.Position - UDim2.fromOffset(0, 14) })
	task.delay(0.32, function()
		card:Destroy()
	end)
	relayout()
end

-- The top of the stack in right-column units (UI.RIGHT_LOOT_Y with the event card showing,
-- UI.RIGHT_EVENT_Y without it).
function LootToast.setTop(y: number)
	if y == top then
		return
	end
	top = y
	local h = holder
	if h and h.Parent then
		local old = h.Position
		place(h)
		local want = h.Position
		h.Position = old
		UI.tween(h, 0.3, { Position = want }, Enum.EasingStyle.Quint)
	end
	while #stack > maxCards() do
		dismiss(stack[#stack])
	end
end

-- Hold cards back (the tour is talking); unpausing shows what waited, newest last.
function LootToast.setPaused(on: boolean)
	paused = on
	if not on then
		local waiting = queue
		queue = {}
		for i, spec in waiting do
			task.delay((i - 1) * 0.5, LootToast.show, spec)
		end
	end
end

function LootToast.isPaused(): boolean
	return paused
end

function LootToast.show(spec: Spec)
	if paused then
		table.insert(queue, spec)
		if #queue > 4 then
			table.remove(queue, 1)
		end
		return
	end
	local parent = root()
	local c = spec.color
	local card: CanvasGroup = UI.new("CanvasGroup", {
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = slot(1) + UDim2.fromOffset(0, 16),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.18,
		GroupTransparency = 1,
		Parent = parent,
	}, {
		UI.corner(12),
		UI.stroke(Color3.new(1, 1, 1), 1, 0.82),
	})
	-- rarity accent: a soft glow from the left edge
	UI.new("Frame", {
		Size = UDim2.new(0.6, 0, 1, 0),
		BackgroundColor3 = c,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		UI.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.72),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	-- glossy tile with the icon
	local tile = UI.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 7, 0.5, 0),
		Size = UDim2.fromOffset(HEIGHT - 14, HEIGHT - 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = card,
	}, {
		UI.corner(10),
		UI.stroke(Color3.new(1, 1, 1), 1, 0.55),
		UI.new("UIGradient", {
			Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.3), c:Lerp(Color3.new(0, 0, 0), 0.35)),
			Rotation = 90,
		}),
	})
	local icon = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		Text = spec.icon,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Parent = tile,
	})
	local x = HEIGHT + 2
	UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 5),
		Size = UDim2.new(1, -x - 70, 0, 16),
		Text = string.upper(spec.tag or ""),
		TextColor3 = c:Lerp(Color3.new(1, 1, 1), 0.25),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, 22),
		Size = UDim2.new(1, -x - 70, 0, 28),
		Text = spec.title,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	if spec.value then
		UI.new("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(70, 22),
			Text = spec.value,
			TextColor3 = Color3.fromRGB(255, 214, 90),
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})
	end
	-- a light sweep across rare cards
	if spec.shine then
		local sweep = UI.new("Frame", {
			Position = UDim2.new(-0.4, 0, 0, 0),
			Size = UDim2.new(0.3, 0, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Rotation = 0,
			ZIndex = 5,
			Parent = card,
		}, {
			UI.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.7),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		task.delay(0.25, function()
			UI.tween(sweep, 0.7, { Position = UDim2.new(1.1, 0, 0, 0) }, Enum.EasingStyle.Sine)
		end)
	end

	table.insert(stack, 1, card)
	while #stack > maxCards() do
		dismiss(stack[#stack])
	end
	relayout()
	UI.tween(card, 0.28, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
	-- the icon pops in a beat later
	local s = UI.new("UIScale", { Scale = 0.4, Parent = icon })
	UI.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(spec.seconds or 2.6, function()
		dismiss(card)
	end)
end

return LootToast
