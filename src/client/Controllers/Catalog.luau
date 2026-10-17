--!strict
-- CELL CATALOG button (lower left, next to the stats): during LOCKDOWN, standing in your own cell,
-- "📦 CATALOG" opens the Tool Crib / Commissary at the catalog price (Services/Shop checks it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Tunnel = require(Shared.Tunnel)

local Util = script.Parent.Parent.Util
local UI = require(Util.UI)
local Sound = require(Util.Sound)
local Shops = require(script.Parent.Shops)

local Catalog = {}

local player = Players.LocalPlayer

function Catalog.start()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui: ScreenGui = UI.new("ScreenGui", {
		Name = "Catalog",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		Parent = playerGui,
	})
	local btn: TextButton = UI.new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(140, 44),
		BackgroundColor3 = Color3.fromRGB(22, 23, 30),
		BackgroundTransparency = 0.25,
		AutoButtonColor = true,
		Text = "",
		Visible = false,
		Parent = gui,
	}, { UI.corner(22), UI.stroke(Color3.fromRGB(255, 190, 90), 2, 0.15) })
	UI.bigText({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Text = "📦 CATALOG",
		TextColor3 = Color3.new(1, 1, 1),
		Parent = btn,
	}, UI.INK, 1.2)
	UI.scaleObject(btn)
	-- just right of the stat lines (they are 260 HUD units wide)
	local function place()
		btn.Position = UDim2.new(0, 12 + 266 * UI.screenScale(), 1, -12)
	end
	place()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	btn.Activated:Connect(function()
		Sound.play("Click")
		Shops.openCatalog("Workshop")
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local night = ReplicatedStorage:GetAttribute("Phase") == "Night"
		local show = false
		if night then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local cell = player:GetAttribute("Cell")
			if root and root:IsA("BasePart") and typeof(cell) == "number" and cell > 0 then
				-- the cell room itself (z < 0), not down the tunnel
				local _, _, z = Tunnel.toBlock(Tunnel.frame(cell), root.Position)
				show = Tunnel.cellAt(root.Position) == cell
					and z < 0
					and player:GetAttribute("Hidden") ~= true
			end
		end
		btn.Visible = show
		if not night then
			Shops.closeCatalog()
		end
	end)
end

return Catalog
