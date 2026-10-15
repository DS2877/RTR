--!strict
-- The first-minute tutorial on the client: one instruction at a time with a glowing arrow (beam)
-- to where you need to go: PUNCH the wall -> VACUUM the rubble -> DUMP in the Yard -> SELL at
-- The Fence -> UPGRADE at the Workshop. The server decides when a step is done.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Tunnel = require(Shared.Tunnel)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Sound = require(Client.Util.Sound)
local DigFX = require(script.Parent.DigFX)

local Guide = {}

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(20, 20, 28)

local TEXT = {
	"STEP 1/5 · Walk to the wall and hold 👊 PUNCH",
	"STEP 2/5 · Hold 🌀 VACUUM next to the rubble",
	"STEP 3/5 · Fill your backpack, then DUMP it in the Yard 🪨",
	"STEP 4/5 · Sell your finds at THE FENCE 💰",
	"STEP 5/5 · Buy an upgrade at the WORKSHOP 🔨",
}

local function shopPart(name: string): BasePart?
	for _, s in CollectionService:GetTagged("Shop") do
		if s:GetAttribute("Shop") == name then
			return s :: BasePart
		end
	end
	return nil
end

local function target(step: number): Vector3?
	if step == 1 then
		local cell = player:GetAttribute("Cell")
		if typeof(cell) == "number" and cell > 0 then
			return Tunnel.frame(cell) * Vector3.new(0, 3, 1)
		end
	elseif step == 2 then
		return DigFX.nearestHeap()
	elseif step == 3 then
		local bag, cap = player:GetAttribute("Bag"), player:GetAttribute("BagCap")
		local dump = CollectionService:GetTagged("Dump")[1]
		-- only point at the dump once there's something worth dumping
		if dump and typeof(bag) == "number" and typeof(cap) == "number" and bag >= math.min(cap, 10) then
			return (dump :: BasePart).Position + Vector3.new(0, 4, 0)
		end
	elseif step == 4 then
		local p = shopPart("Fence")
		return if p then p.Position + Vector3.new(0, 4, 0) else nil
	elseif step == 5 then
		local p = shopPart("Workshop")
		return if p then p.Position + Vector3.new(0, 4, 0) else nil
	end
	return nil
end

function Guide.start()
	local gui = UI.new(
		"ScreenGui",
		{ Name = "Guide", ResetOnSpawn = false, DisplayOrder = 3, Parent = player:WaitForChild("PlayerGui") }
	)
	local box = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(440, 34),
		BackgroundColor3 = Color3.fromRGB(255, 230, 90),
		Visible = false,
		Parent = gui,
	}, { UI.corner(17), UI.stroke(DARK, 2), UI.gradient(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)) })
	UI.scaleObject(box)
	local text = UI.bigText(
		{ Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -16, 1, -10), Text = "", Parent = box },
		DARK,
		2
	)

	local folder = Instance.new("Folder")
	folder.Name = "GuideArrow"
	folder.Parent = workspace
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Parent = folder
	local a1 = Instance.new("Attachment")
	a1.Parent = holder
	local beam: Beam? = nil

	local last = 0
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local step = player:GetAttribute("Tutorial")
		local active = typeof(step) == "number" and step >= 1 and step <= #TEXT
		box.Visible = active
		if not active then
			if beam then
				beam.Enabled = false
			end
			return
		end
		if step ~= last then
			if last ~= 0 then
				Sound.play("Upgrade", 0.5)
			end
			last = step :: number
			text.Text = TEXT[step :: number]
			UI.bump(box, 0.1)
		end
		local pos = target(step :: number)
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if pos and r then
			if not beam or beam.Parent ~= r then
				local a0 = Instance.new("Attachment")
				a0.Parent = r
				local b = Instance.new("Beam")
				b.Attachment0 = a0
				b.Attachment1 = a1
				b.Width0 = 0.8
				b.Width1 = 0.8
				b.FaceCamera = true
				b.LightEmission = 1
				b.Segments = 12
				b.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90))
				b.Parent = r
				beam = b
			end
			holder.Position = pos
			local b = beam :: Beam
			b.Enabled = true
		elseif beam then
			beam.Enabled = false
		end
	end)
end

return Guide
