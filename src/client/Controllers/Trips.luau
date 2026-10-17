--!strict
-- QUICK TRIP + CELL CATALOG buttons (lower left, next to the stats). In your own cell or tunnel:
-- "⏬ DIG FACE" (and "⏫ CELL" once you're down the tunnel) ask the server for a quick trip; you
-- hold still while a bar fills (Services/Travel). During LOCKDOWN in your cell, "📦 CATALOG" opens
-- the Tool Crib / Commissary at the catalog price (Services/Shop).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)

local Util = script.Parent.Parent.Util
local UI = require(Util.UI)
local Sound = require(Util.Sound)
local Shops = require(script.Parent.Shops)

local Trips = {}

local player = Players.LocalPlayer

local function pill(parent: Instance, order: number, text: string, color: Color3): TextButton
	local b: TextButton = UI.new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(132, 44),
		BackgroundColor3 = Color3.fromRGB(22, 23, 30),
		BackgroundTransparency = 0.25,
		AutoButtonColor = true,
		Text = "",
		Visible = false,
		Parent = parent,
	}, { UI.corner(22), UI.stroke(color, 2, 0.15) })
	UI.bigText({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = b,
	}, UI.INK, 1.2)
	return b
end

function Trips.start()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui: ScreenGui = UI.new("ScreenGui", {
		Name = "Trips",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		Parent = playerGui,
	})
	local stack: Frame = UI.new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(132, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	})
	UI.scaleObject(stack)
	-- just right of the stat lines (they are 260 HUD units wide)
	local function place()
		stack.Position = UDim2.new(0, 12 + 266 * UI.screenScale(), 1, -12)
	end
	place()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end

	local catalogBtn = pill(stack, 1, "📦 CATALOG", Color3.fromRGB(255, 190, 90))
	local cellBtn = pill(stack, 2, "⏫ CELL", Color3.fromRGB(120, 200, 255))
	local faceBtn = pill(stack, 3, "⏬ DIG FACE", Color3.fromRGB(255, 150, 70))

	-- the channel bar (center, under the toasts)
	local barBox: Frame = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(260, 46),
		BackgroundColor3 = Color3.fromRGB(16, 17, 22),
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	}, { UI.corner(12), UI.stroke(Color3.new(1, 1, 1), 1, 0.8) })
	UI.scaleObject(barBox)
	local barText = UI.bigText({
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 20),
		Text = "",
		Parent = barBox,
	}, UI.INK, 1.2)
	local track: Frame = UI.new("Frame", {
		Position = UDim2.new(0, 12, 1, -16),
		Size = UDim2.new(1, -24, 0, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.85,
		Parent = barBox,
	}, { UI.corner(4) })
	local fill: Frame = UI.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(255, 200, 90),
		Parent = track,
	}, { UI.corner(4) })

	local travel = Remotes.get(Remotes.Names.Travel)
	local channeling = false
	local readyAt = 0
	local function ask(where: string)
		if channeling then
			return
		end
		if os.clock() < readyAt then
			Sound.play("Click", 0.3, 0.7)
			return
		end
		Sound.play("Click")
		travel:FireServer(where)
	end
	faceBtn.Activated:Connect(function()
		ask("face")
	end)
	cellBtn.Activated:Connect(function()
		ask("cell")
	end)
	catalogBtn.Activated:Connect(function()
		Sound.play("Click")
		Shops.openCatalog("Workshop")
	end)

	Remotes.get(Remotes.Names.TravelState).OnClientEvent
		:Connect(function(state: string, where: string, seconds: number?)
			if state == "start" then
				channeling = true
				barText.Text = if where == "face"
					then "⏬ Off to the dig face... hold still"
					else "⏫ Back to your cell... hold still"
				barBox.Visible = true
				fill.Size = UDim2.fromScale(0, 1)
				TweenService
					:Create(fill, TweenInfo.new(seconds or World.TravelChannel, Enum.EasingStyle.Linear), {
						Size = UDim2.fromScale(1, 1),
					})
					:Play()
			elseif state == "done" then
				channeling = false
				barBox.Visible = false
				readyAt = os.clock() + (seconds or World.TravelCooldown)
				Sound.play("Land", 0.6)
			else
				if channeling then
					Sound.play("Click", 0.3, 0.6)
				end
				channeling = false
				barBox.Visible = false
			end
		end)

	-- which buttons make sense where you are
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local cell = player:GetAttribute("Cell")
		local busy = player:GetAttribute("Carrying") == true
			or player:GetAttribute("Hidden") == true
			or player:GetAttribute("Breakout") ~= nil
			or player:GetAttribute("Lifting") ~= nil
		local home = false
		local deep = false
		if root and root:IsA("BasePart") and typeof(cell) == "number" and cell > 0 then
			home = Tunnel.cellAt(root.Position) == cell
			if home then
				local _, _, z = Tunnel.toBlock(Tunnel.frame(cell), root.Position)
				deep = z >= 6
			end
		end
		local night = ReplicatedStorage:GetAttribute("Phase") == "Night"
		faceBtn.Visible = home and not busy
		cellBtn.Visible = home and deep and not busy
		catalogBtn.Visible = home and night and not deep and not busy
		local cooling = os.clock() < readyAt
		for _, b in { faceBtn, cellBtn } do
			b.BackgroundTransparency = if cooling or channeling then 0.6 else 0.25
		end
		if channeling and not home then
			barBox.Visible = false
		end
		if not night then
			Shops.closeCatalog()
		end
	end)
end

return Trips
