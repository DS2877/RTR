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

local Tour = {}

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

local STOPS: { Stop } = {
	{
		title = "Welcome to Dig Out!",
		body = "You're a prisoner. The back wall of your cell is your way out.",
		view = cellView(Vector3.new(9, 10, 19), Vector3.new(0, 5, 0)),
	},
	{
		title = "👊 Punch & dig",
		body = "Hold PUNCH to break blocks: keep going for a COMBO. Glowing veins hide finds, gold blocks pay on the spot.",
		view = cellView(Vector3.new(-3, 6, 8), Vector3.new(2, 4, -2)),
	},
	{
		title = "🧱 Rubble Dump",
		body = "Carry rubble out to the Yard and dump it for 🍜 Noodles. Full? Keep digging, it waits on the floor.",
		view = function()
			return lookAt(CollectionService:GetTagged("Dump")[1] :: BasePart?, 20, 12)
		end,
	},
	{
		title = "💰 The Fence",
		body = "Sell your finds here. Unsold finds can be stolen during the day!",
		view = function()
			return lookAt(shop("Fence"), 16, 7)
		end,
	},
	{
		title = "🔨 Tool Crib",
		body = "Spend Noodles on tools that hit harder and brushes that break more blocks per punch.",
		view = function()
			return lookAt(shop("Workshop"), 16, 7)
		end,
	},
	{
		title = "🎒 Commissary",
		body = "Bigger backpacks, more find slots and a stronger vacuum.",
		view = function()
			return lookAt(shop("Commissary"), 16, 7)
		end,
	},
	{
		title = "💪 Yard Gym",
		body = "Lift ridiculous things for Strength. Stronger prisoners punch harder.",
		view = function()
			return lookAt(CollectionService:GetTagged("GymStation")[1] :: BasePart?, 22, 10)
		end,
	},
	{
		title = "🍲 Mess Hall",
		body = "Meals give you buffs until the morning.",
		view = function()
			return lookAt(shop("MessHall"), 20, 8)
		end,
	},
	{
		title = "🌙 Lights out",
		body = "At night the doors lock and guards check the cells. Cover the hole and get in bed in time!",
		view = cellView(Vector3.new(-12, 8, 16), Vector3.new(-6, 2, 9)),
	},
	{
		title = "🏃 Escape",
		body = "Dig through 10 zones to the bottom and ESCAPE. Tap 📋 Jobs for daily work that pays extra. Good luck!",
		view = cellView(Vector3.new(0, 7, 12), Vector3.new(0, 4, -6)),
	},
}

local function card(parent: Instance)
	local box = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(420, 112),
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
		TextSize = 18,
		TextColor3 = Color3.fromRGB(245, 246, 250),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = box,
	})
	local body = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 50),
		Size = UDim2.new(1, -32, 0, 34),
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(190, 194, 206),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = box,
	})
	local skip = UI.new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.fromOffset(70, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(150, 154, 168),
		Text = "Skip",
		Parent = box,
	})
	local nextBtn = UI.new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(110, 30),
		BackgroundColor3 = Color3.fromRGB(255, 170, 60),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = UI.INK,
		Text = "Next ›",
		AutoButtonColor = true,
		Parent = box,
	}, { UI.corner(9) })
	return box, dots, title, body, skip, nextBtn
end

function Tour.play()
	if playing then
		return
	end
	playing = true
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
