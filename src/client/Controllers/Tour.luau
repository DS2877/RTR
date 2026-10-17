--!strict
-- The first-join TOUR: a short, slim camera tour of everything that matters (your wall, the dump,
-- The Fence, the upgrade shops, the gym, the Mess Hall, the night rules, the escape). One small
-- card at the bottom with Next / Skip. Shown once (profile TourDone, "TourDone" attribute); admins
-- can replay it. Nothing else guides you during play: no arrows, no step boxes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Sound = require(Client.Util.Sound)
local LootToast = require(Client.Util.LootToast)

local Tour = {}

-- true while the tour plays (loot cards wait until it's over)
Tour.active = false

local player = Players.LocalPlayer
local playing = false

type Stop = { title: string, body: string, view: () -> CFrame? }

local function shop(name: string): BasePart?
	for _, s in CollectionService:GetTagged("Shop") do
		if s:GetAttribute("Shop") == name and s:IsA("BasePart") then
			return s
		end
	end
	return nil
end

-- a camera a little back from a spot, on the side facing the Common Room, looking at it
local function lookAt(p: BasePart?, back: number?, up: number?): CFrame?
	if not p then
		return nil
	end
	local cr = World.CommonRoom
	local pos = p.Position
	local d = Vector3.new(cr.x - pos.X, 0, cr.z - pos.Z)
	d = if d.Magnitude > 1 then d.Unit else Vector3.new(1, 0, 0)
	local eye = pos + d * (back or 18) + Vector3.new(0, up or 9, 0)
	return CFrame.lookAt(eye, pos + Vector3.new(0, 2, 0))
end

local function cellView(eye: Vector3, at: Vector3): () -> CFrame?
	return function()
		local cell = player:GetAttribute("Cell")
		if typeof(cell) ~= "number" or cell < 1 then
			return nil
		end
		local f = Tunnel.frame(cell)
		return CFrame.lookAt(f * eye, f * at)
	end
end

-- short on purpose: the rest (Fence, Jobs, night, Crew, the Canteen...) comes as one-time tips the
-- moment it matters (Config/Tips)
local STOPS: { Stop } = {
	{
		title = "Welcome, inmate!",
		body = "That back wall is your way out. Hold 👊 PUNCH to smash it: keep hitting for a COMBO.",
		view = cellView(Vector3.new(9, 10, 19), Vector3.new(0, 5, 0)),
	},
	{
		title = "🌀 Vacuum",
		body = "Hold VACUUM to suck the rubble (and any finds) into your backpack.",
		view = cellView(Vector3.new(-3, 6, 8), Vector3.new(2, 4, -2)),
	},
	{
		title = "🧱 Rubble Dump",
		body = "Backpack full? Dump it here in the Yard for 🍜 Noodles. Finds sell at The Fence.",
		view = function()
			return lookAt(CollectionService:GetTagged("Dump")[1] :: BasePart?, 20, 12)
		end,
	},
	{
		title = "🔨 Tool Crib",
		body = "Buy a 🥄 Spoon first: it hits twice as hard! Then bigger tools, brushes and a cart.",
		view = function()
			return lookAt(shop("Workshop"), 16, 7)
		end,
	},
	{
		title = "🌙 Lights out",
		body = "At night the doors lock: dig for bonus finds, and hide in bed when the guard comes!",
		view = cellView(Vector3.new(-12, 8, 16), Vector3.new(-6, 2, 9)),
	},
	{
		title = "🏃 600 m to freedom",
		body = "Crack the vault door of each zone, reach the bottom and ESCAPE. Every escape makes you stronger!",
		view = cellView(Vector3.new(0, 7, 12), Vector3.new(0, 4, -6)),
	},
}

local function card(parent: Instance)
	local box = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(460, 152),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.12,
		Parent = parent,
	}, { UI.corner(14), UI.stroke(Color3.new(1, 1, 1), 1, 0.84) })
	UI.scaleObject(box)
	local dots = UI.new("Frame", {
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(200, 6),
		BackgroundTransparency = 1,
		Parent = box,
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.Parent = dots
	local title = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 26),
		Size = UDim2.new(1, -32, 0, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(245, 246, 250),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = box,
	})
	local body = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 44),
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(190, 194, 206),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = box,
	}, { UI.new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 12 }) })
	-- thumb-sized buttons: Skip as a faint pill, Next as the bright one
	local skip = UI.new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.fromOffset(100, 44),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(200, 204, 216),
		Text = "Skip",
		AutoButtonColor = true,
		Parent = box,
	}, { UI.corner(12), UI.stroke(Color3.new(1, 1, 1), 1, 0.8) })
	local nextBtn = UI.new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = Color3.fromRGB(255, 170, 60),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = UI.INK,
		Text = "Next ›",
		AutoButtonColor = true,
		Parent = box,
	}, { UI.corner(12) })
	return box, dots, title, body, skip, nextBtn
end

function Tour.play()
	if playing then
		return
	end
	playing = true
	Tour.active = true
	LootToast.setPaused(true)
	local camera = workspace.CurrentCamera
	local playerGui = player:WaitForChild("PlayerGui")
	-- a clean screen: hide the HUD while touring
	local hidden: { ScreenGui } = {}
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	local gui =
		UI.new("ScreenGui", { Name = "Tour", ResetOnSpawn = false, DisplayOrder = 20, Parent = playerGui })
	local box, dots, title, body, skip, nextBtn = card(gui)
	local pips: { Frame } = {}
	for i = 1, #STOPS do
		pips[i] = UI.new("Frame", {
			LayoutOrder = i,
			Size = UDim2.fromOffset(14, 4),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.8,
			Parent = dots,
		}, { UI.corner(2) })
	end
	local oldType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local index = 0
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		gui:Destroy()
		camera.CameraType = oldType
		for _, g in hidden do
			g.Enabled = true
		end
		Remotes.get(Remotes.Names.TourDone):FireServer()
		playing = false
		Tour.active = false
		LootToast.setPaused(false)
	end
	local function show(i: number)
		local stop = STOPS[i]
		index = i
		title.Text = stop.title
		body.Text = stop.body
		nextBtn.Text = if i == #STOPS then "Let's dig!" else "Next ›"
		for k, p in pips do
			p.BackgroundTransparency = if k <= i then 0 else 0.8
			p.BackgroundColor3 = if k == i then Color3.fromRGB(255, 170, 60) else Color3.new(1, 1, 1)
		end
		local cf = stop.view()
		if cf then
			TweenService
				:Create(camera, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					CFrame = cf,
				})
				:Play()
		end
		box.Position = UDim2.new(0.5, 0, 1, -16)
		UI.tween(box, 0.25, { Position = UDim2.new(0.5, 0, 1, -24) }, Enum.EasingStyle.Quint)
	end
	nextBtn.Activated:Connect(function()
		Sound.play("Click")
		if index >= #STOPS then
			finish()
		else
			show(index + 1)
		end
	end)
	skip.Activated:Connect(function()
		Sound.play("Click")
		finish()
	end)
	show(1)
end

function Tour.start()
	task.spawn(function()
		-- first join only: wait until the profile and the character are in
		while player:GetAttribute("Loaded") ~= true or player:GetAttribute("TourDone") == nil do
			task.wait(0.5)
		end
		if player:GetAttribute("TourDone") == true then
			return
		end
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(2)
		if player:GetAttribute("TourDone") ~= true then
			Tour.play()
		end
	end)
end

return Tour
