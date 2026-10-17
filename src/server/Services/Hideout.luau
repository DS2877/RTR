--!strict
-- Your cell as a hideout (no screen buttons: you walk up to things and hold their prompt):
--   COVER  a big beach tapestry on a wooden roller over the back wall (the tunnel hole). Hold the
--          prompt by the wall to roll it down / up (everyone sees it). Punching the wall rolls it up.
--   SLEEP  hold the prompt at your bed to lie down (moving or the prompt again gets you up).
-- A night inspection only passes when you're in bed AND the hole is covered (or you have no hole
-- yet). Only the cell's owner can use its prompts (the client hides the others' prompts).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local World = require(Shared.Config.World)
local Cycle = require(Shared.Config.Cycle)
local Voxel = require(Shared.Voxel)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Build = require(script.Parent.Parent.Util.Build)

local Hideout = {}

local W = World.TunnelWidth * World.BlockSize
local TOP = World.TunnelHeight * World.BlockSize - 0.9 -- the roller hangs just under the ceiling
local LENGTH = TOP - 0.15 -- cloth length when fully down
local ROLL_SECONDS = 0.7

type Cover = {
	cloth: Part,
	roller: Part,
	weight: Part,
	frame: CFrame,
	value: NumberValue, -- 0 = rolled up, 1 = down
	down: boolean,
}

local world: any = nil
local covers: { [number]: Cover } = {}

-- ===== the tapestry =====

local function art(cloth: Part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Art"
	gui.Face = Enum.NormalId.Back -- faces into the cell
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(720, 480)
	gui.LightInfluence = 1
	gui.Parent = cloth
	local function frame(props: { [string]: any }, parent: Instance): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		for k, v in props do
			(f :: any)[k] = v
		end
		f.Parent = parent
		return f
	end
	local function gradient(parent: Instance, keys: { { number } }, rotation: number?)
		local g = Instance.new("UIGradient")
		local seq = {}
		for _, k in keys do
			table.insert(seq, ColorSequenceKeypoint.new(k[1], Color3.fromRGB(k[2], k[3], k[4])))
		end
		g.Color = ColorSequence.new(seq)
		g.Rotation = rotation or 90
		g.Parent = parent
	end
	local root = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, gui)
	-- sunset sky
	gradient(root, {
		{ 0, 60, 46, 110 },
		{ 0.35, 214, 84, 120 },
		{ 0.6, 255, 150, 90 },
		{ 1, 255, 196, 120 },
	})
	-- the sun sinking into the sea
	local sun = frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(190, 190),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
	}, root)
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(1, 0)
	sc.Parent = sun
	gradient(sun, { { 0, 255, 236, 160 }, { 1, 255, 160, 80 } })
	-- sea with glittering bands
	local sea = frame({
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, root)
	gradient(sea, { { 0, 52, 120, 170 }, { 1, 20, 60, 110 } })
	for i = 1, 5 do
		frame({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10 + i * 16),
			Size = UDim2.fromOffset(170 - i * 24, 4),
			BackgroundColor3 = Color3.fromRGB(255, 214, 140),
			BackgroundTransparency = 0.15 + i * 0.12,
			ZIndex = 4,
		}, sea)
	end
	-- a sandy beach in the corner + palm trees
	local sand = frame({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(0.42, 0.16),
		BackgroundColor3 = Color3.fromRGB(236, 200, 140),
		ZIndex = 5,
	}, root)
	local sandCorner = Instance.new("UICorner")
	sandCorner.CornerRadius = UDim.new(0, 60)
	sandCorner.Parent = sand
	for _, p in { { 0.07, 0.62, 190 }, { 0.25, 0.7, 130 } } do
		local palm = Instance.new("TextLabel")
		palm.BackgroundTransparency = 1
		palm.AnchorPoint = Vector2.new(0.5, 0.5)
		palm.Position = UDim2.fromScale(p[1], p[2])
		palm.Size = UDim2.fromOffset(p[3], p[3])
		palm.Text = "🌴"
		palm.TextScaled = true
		palm.Font = Enum.Font.GothamBold
		palm.ZIndex = 6
		palm.Parent = root
	end
	-- the slogan
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.08, 0.07)
	title.Size = UDim2.fromScale(0.84, 0.2)
	title.Text = "DREAM BIG"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 248, 230)
	title.ZIndex = 7
	title.Parent = root
	local ts = Instance.new("UIStroke")
	ts.Color = Color3.fromRGB(80, 30, 60)
	ts.Thickness = 3
	ts.Parent = title
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0.2, 0.27)
	sub.Size = UDim2.fromScale(0.6, 0.06)
	sub.Text = "NOTHING TO SEE BEHIND HERE"
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(255, 230, 200)
	sub.TextTransparency = 0.2
	sub.ZIndex = 7
	sub.Parent = root
	-- woven border
	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = Color3.fromRGB(150, 60, 50)
	border.Thickness = 14
	border.Parent = root
	local pad = frame({
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.new(1, -36, 1, -36),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, root)
	local inner = Instance.new("UIStroke")
	inner.Color = Color3.fromRGB(240, 200, 110)
	inner.Thickness = 3
	inner.Parent = pad
end

local function place(c: Cover)
	local k = math.clamp(c.value.Value, 0, 1)
	local length = math.max(0.05, LENGTH * k)
	c.cloth.Size = Vector3.new(W - 1.2, length, 0.12)
	c.cloth.CFrame = c.frame * CFrame.new(0, TOP - length / 2, 0.45)
	c.cloth.Transparency = if k < 0.01 then 1 else 0
	local gui = c.cloth:FindFirstChild("Art") :: SurfaceGui?
	if gui then
		gui.Enabled = k >= 0.01
	end
	-- the roll gets fatter as more cloth is wound onto it
	local d = 0.55 + 1.15 * (1 - k)
	c.roller.Size = Vector3.new(W - 1.2, d, d)
	-- (cylinders run along their X axis: across the wall)
	c.roller.CFrame = c.frame * CFrame.new(0, TOP + 0.1, 0.45 + d / 2)
	c.weight.CFrame = c.frame * CFrame.new(0, TOP - length, 0.5)
	c.weight.Transparency = if k < 0.05 then 1 else 0
end

local function build(cell: any): Cover
	local frame: CFrame = cell.frame
	local model = Instance.new("Model")
	model.Name = "Cover"
	model.Parent = cell.model
	local wood = Color3.fromRGB(120, 78, 44)
	local cloth = Build.part(model, "Cloth", Vector3.new(W, 1, 0.12), frame, Color3.fromRGB(240, 236, 228), {
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	art(cloth)
	local roller = Build.part(model, "Roller", Vector3.new(W, 1, 1), frame, Color3.fromRGB(196, 170, 130), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		CanQuery = false,
	})
	-- wooden end caps + hooks on the wall
	for _, side in { -1, 1 } do
		Build.part(
			model,
			"Bracket",
			Vector3.new(0.5, 1.6, 1.8),
			frame * CFrame.new(side * (W / 2 - 0.25), TOP + 0.1, 0.9),
			wood,
			{ Material = Enum.Material.Wood, CanCollide = false, CanQuery = false }
		)
	end
	local weight = Build.part(model, "Weight", Vector3.new(W - 0.8, 0.35, 0.35), frame, wood, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Wood,
		CanCollide = false,
		CanQuery = false,
	})
	local value = Instance.new("NumberValue")
	value.Name = "Down"
	value.Value = 0
	value.Parent = model
	local c: Cover =
		{ cloth = cloth, roller = roller, weight = weight, frame = frame, value = value, down = false }
	value.Changed:Connect(function()
		place(c)
	end)
	place(c)
	return c
end

-- ===== cover =====

local function setCoverOf(cell: number, down: boolean)
	local c = covers[cell]
	if not c or c.down == down then
		return
	end
	c.down = down
	TweenService:Create(
		c.value,
		TweenInfo.new(ROLL_SECONDS, if down then Enum.EasingStyle.Bounce else Enum.EasingStyle.Quad),
		{ Value = if down then 1 else 0 }
	):Play()
end

function Hideout.setCover(player: Player, down: boolean): boolean
	local s = State.get(player)
	if not s or not s.cell then
		return false
	end
	s.coverDown = down
	setCoverOf(s.cell, down)
	if typeof(player) == "Instance" then
		player:SetAttribute("CoverDown", down)
	end
	return true
end

-- Inspection rule: in bed, and the hole covered (no hole yet counts as covered).
function Hideout.isSafe(s: State.PlayerState): boolean
	-- (the tunnel as it is now: after an escape the wall is whole again)
	return s.hidden and (s.coverDown or s.grid == nil or Voxel.depth(s.grid) <= 0)
end

-- ===== sleeping =====

local function inOwnCell(player: Player, s: State.PlayerState): boolean
	local pos = State.root(player)
	return pos ~= nil and s.cell ~= nil and Tunnel.cellAt(pos) == s.cell
end

-- on = lie down in your bed / get up. force skips the "are you in your cell" check (inspection).
function Hideout.setHidden(player: Player, on: boolean, force: boolean?): boolean
	local s = State.get(player)
	if not s or not s.cell then
		return false
	end
	if on and not force then
		local bedPart = world.cells[s.cell].model:FindFirstChild("Mattress") :: BasePart?
		local pos = State.root(player)
		if not inOwnCell(player, s) or not bedPart or not pos or (bedPart.Position - pos).Magnitude > 12 then
			Net.notice(player, "Walk up to your own bed to sleep.", "info")
			return false
		end
	end
	if s.hidden == on then
		return true
	end
	s.hidden = on
	if typeof(player) ~= "Instance" then
		return true
	end
	player:SetAttribute("Hidden", on)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local bed = world.cells[s.cell].model:FindFirstChild("Mattress") :: BasePart?
	local pillow = world.cells[s.cell].model:FindFirstChild("Pillow") :: BasePart?
	if not character or not hrp or not hrp:IsA("BasePart") or not bed then
		return true
	end
	local headDir = if pillow
		then Vector3.new(pillow.Position.X - bed.Position.X, 0, pillow.Position.Z - bed.Position.Z).Unit
		else bed.CFrame.LookVector
	if on then
		-- on your back, head on the pillow, half under the blanket
		local pos = bed.Position + Vector3.new(0, bed.Size.Y / 2 + 0.55, 0) + headDir * 0.6
		local up = headDir -- the character's "up" runs along the bed
		local back = Vector3.new(0, -1, 0) -- its back (+Z) faces down, so it looks at the ceiling
		local right = up:Cross(back)
		hrp.Anchored = true
		character:PivotTo(CFrame.fromMatrix(pos, right, up, back))
	else
		-- step out next to the bed, facing the back wall
		local center = (world.cells[s.cell].frame :: CFrame).Position
		local side = Vector3.new(center.X - bed.Position.X, 0, 0)
		side = if side.Magnitude > 0 then side.Unit else Vector3.new(1, 0, 0)
		local stand = bed.Position + side * 4 + Vector3.new(0, 3, 0)
		local look = (world.cells[s.cell].frame :: CFrame).LookVector
		character:PivotTo(CFrame.lookAt(stand, stand + Vector3.new(look.X, 0, look.Z)))
		hrp.Anchored = false
	end
	return true
end

-- Out of bed on the spot (before any teleport: an anchored sleeper can't walk anywhere).
function Hideout.wake(player: Player)
	local s = State.get(player)
	if not s or not s.hidden then
		return
	end
	s.hidden = false
	if typeof(player) ~= "Instance" then
		return
	end
	player:SetAttribute("Hidden", false)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		hrp.Anchored = false
	end
end

-- Dig hook: no punching from bed; punching the wall rolls the cover up.
function Hideout.beforePunch(player: Player, s: State.PlayerState): boolean
	if s.hidden then
		return false
	end
	if s.coverDown then
		Hideout.setCover(player, false)
	end
	return true
end

-- A new character never starts in bed.
function Hideout.onCharacter(player: Player)
	local s = State.get(player)
	if s then
		s.hidden = false
		if typeof(player) == "Instance" then
			player:SetAttribute("Hidden", false)
		end
	end
end

function Hideout.onLeaving(player: Player)
	local s = State.get(player)
	if s and s.cell then
		setCoverOf(s.cell, false)
	end
end

function Hideout.start(w: any)
	world = w
	for i, cell in world.cells do
		covers[i] = build(cell)
	end
	-- the prompts: by the wall (cover) and on the bed (sleep)
	for i, cell in world.cells do
		local frame: CFrame = cell.frame
		local spot = Build.part(
			cell.model,
			"CoverSpot",
			Vector3.new(4, 4, 0.2),
			frame * CFrame.new(0, 4, 2),
			Color3.new(),
			{
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
			}
		)
		local cp = Build.prompt(spot, "Cover the hole", "Tapestry", 10)
		cp.Name = "CoverPrompt"
		cp.HoldDuration = Cycle.CoverHold
		cp.Triggered:Connect(function(player)
			local s = State.get(player)
			if s and s.cell == i then
				Hideout.setCover(player, not s.coverDown)
			end
		end)
		local bed = cell.model:FindFirstChild("Mattress")
		if bed and bed:IsA("BasePart") then
			local sp = Build.prompt(bed, "Sleep", "Bed", 8)
			sp.Name = "SleepPrompt"
			sp.HoldDuration = Cycle.SleepHold
			sp.Triggered:Connect(function(player)
				local s = State.get(player)
				if s and s.cell == i then
					Hideout.setHidden(player, not s.hidden)
				end
			end)
		end
	end
	local limit = RateLimit.new(2, 4)
	Net.on(Remotes.Names.Cover, function(player, down)
		if limit(player) and (down == nil or typeof(down) == "boolean") then
			local s = State.get(player)
			-- only from your own cell (or your bed in it): never across the prison
			if s and (s.hidden or inOwnCell(player, s)) then
				Hideout.setCover(player, if down == nil then not s.coverDown else down)
			end
		end
	end)
	Net.on(Remotes.Names.Sleep, function(player, on)
		if limit(player) and (on == nil or typeof(on) == "boolean") then
			local s = State.get(player)
			if s then
				Hideout.setHidden(player, if on == nil then not s.hidden else on)
			end
		end
	end)
end

return Hideout
