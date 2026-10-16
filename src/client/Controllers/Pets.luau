--!strict
-- CELLMATES on the client: every player's pets (their "Pets" attribute) follow them around,
-- hopping on the ground or flapping overhead, with a small name + level tag. The dig pet leaps at
-- the rock when the server says it swung (Remotes.PetAct). The 🐀 Pets tile opens your shop:
-- known prices, the perk at your pet's level, an XP bar, Buy / Equip. Models are built from
-- ellipsoids (SpecialMesh spheres) welded to one anchored root, so a pet moves with one CFrame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Pets)
local PetMath = require(Shared.Pets)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local Tunnel = require(Shared.Tunnel)

local Client = script.Parent.Parent
local UI = require(Client.Util.UI)
local Panel = require(Client.Util.Panel)
local Sound = require(Client.Util.Sound)
local LootToast = require(Client.Util.LootToast)
local HUD = require(script.Parent.HUD)
local VoxelRender = require(script.Parent.VoxelRender)

local Pets = {}

local player = Players.LocalPlayer
local folder: Folder

type Built = { model: Model, root: BasePart, flies: boolean, tag: TextLabel? }
type Live = {
	built: Built,
	id: string,
	level: number,
	pos: Vector3,
	look: Vector3,
	leapTo: Vector3?,
	leapAt: number,
}

-- ===== models =====

local function blob(
	m: Model,
	root: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	mat: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Anchored = false
	p.CFrame = root.CFrame * offset
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	p.Parent = m
	return p
end

local function stick(m: Model, root: BasePart, size: Vector3, offset: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Anchored = false
	p.CFrame = root.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	p.Parent = m
	return p
end

local EYE = Color3.fromRGB(16, 16, 18)
local PINK = Color3.fromRGB(236, 150, 160)

-- builders: the pet faces -Z, its feet at y = 0 of the root
local BUILD: { [string]: (m: Model, r: BasePart) -> boolean } = {}

local function ratLike(m: Model, r: BasePart, fur: Color3, mat: Enum.Material?)
	blob(m, r, Vector3.new(0.9, 0.6, 1.3), CFrame.new(0, 0.35, 0), fur, mat)
	blob(m, r, Vector3.new(0.55, 0.5, 0.65), CFrame.new(0, 0.48, -0.72), fur, mat)
	blob(m, r, Vector3.new(0.14, 0.12, 0.14), CFrame.new(0, 0.46, -1.06), PINK)
	for _, x in { -0.2, 0.2 } do
		blob(m, r, Vector3.new(0.32, 0.32, 0.07), CFrame.new(x, 0.78, -0.62), fur:Lerp(PINK, 0.4), mat)
		blob(m, r, Vector3.new(0.1, 0.1, 0.1), CFrame.new(x * 0.7, 0.56, -0.98), EYE)
		blob(m, r, Vector3.new(0.18, 0.12, 0.26), CFrame.new(x * 1.6, 0.06, -0.35), fur:Lerp(EYE, 0.2), mat)
		blob(m, r, Vector3.new(0.18, 0.12, 0.26), CFrame.new(x * 1.6, 0.06, 0.4), fur:Lerp(EYE, 0.2), mat)
	end
	stick(
		m,
		r,
		Vector3.new(1.3, 0.09, 0.09),
		CFrame.new(0, 0.3, 1.2) * CFrame.Angles(0, math.pi / 2, 0.35),
		PINK
	)
end

BUILD.Rat = function(m, r)
	ratLike(m, r, Color3.fromRGB(128, 124, 120))
	return false
end
BUILD.GoldRat = function(m, r)
	ratLike(m, r, Color3.fromRGB(240, 196, 70), Enum.Material.Foil)
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 230, 120)
	sparkle.Parent = r
	return false
end
BUILD.Roach = function(m, r)
	local shell = Color3.fromRGB(96, 52, 28)
	blob(m, r, Vector3.new(0.8, 0.36, 1.15), CFrame.new(0, 0.26, 0), shell, Enum.Material.Glass)
	blob(m, r, Vector3.new(0.45, 0.3, 0.35), CFrame.new(0, 0.24, -0.66), shell:Lerp(EYE, 0.5))
	for _, x in { -1, 1 } do
		for k = -1, 1 do
			stick(
				m,
				r,
				Vector3.new(0.6, 0.05, 0.05),
				CFrame.new(x * 0.5, 0.12, k * 0.3) * CFrame.Angles(0, 0, x * 0.4),
				EYE
			)
		end
		stick(
			m,
			r,
			Vector3.new(1.1, 0.03, 0.03),
			CFrame.new(x * 0.25, 0.42, -1.2) * CFrame.Angles(0, math.pi / 2 + x * 0.35, -0.4),
			shell
		)
	end
	return false
end
BUILD.Cat = function(m, r)
	local fur = Color3.fromRGB(230, 140, 60)
	blob(m, r, Vector3.new(0.8, 0.75, 1.45), CFrame.new(0, 0.7, 0), fur)
	blob(m, r, Vector3.new(0.75, 0.7, 0.7), CFrame.new(0, 1.15, -0.78), fur)
	blob(m, r, Vector3.new(0.4, 0.28, 0.25), CFrame.new(0, 1.02, -1.08), Color3.fromRGB(250, 230, 210))
	for _, x in { -0.22, 0.22 } do
		local ear = Instance.new("WedgePart")
		ear.Size = Vector3.new(0.08, 0.32, 0.26)
		ear.Color = fur
		ear.CanCollide, ear.CanQuery, ear.CanTouch, ear.Massless, ear.Anchored =
			false, false, false, true, false
		ear.CFrame = r.CFrame * CFrame.new(x, 1.55, -0.72)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1, w.Parent = r, ear, ear
		ear.Parent = m
		blob(
			m,
			r,
			Vector3.new(0.13, 0.15, 0.08),
			CFrame.new(x * 0.7, 1.22, -1.12),
			Color3.fromRGB(110, 200, 90)
		)
		for _, z in { -0.5, 0.5 } do
			stick(
				m,
				r,
				Vector3.new(0.5, 0.18, 0.18),
				CFrame.new(x * 1.3, 0.25, z) * CFrame.Angles(0, 0, math.pi / 2),
				fur
			)
		end
	end
	stick(
		m,
		r,
		Vector3.new(0.9, 0.14, 0.14),
		CFrame.new(0, 1.1, 0.95) * CFrame.Angles(0, math.pi / 2, 1.0),
		fur
	)
	return false
end
local function bird(m: Model, r: BasePart, body: Color3, head: Color3, beak: Color3, wing: Color3)
	blob(m, r, Vector3.new(0.7, 0.7, 1.0), CFrame.new(0, 0, 0), body)
	blob(m, r, Vector3.new(0.48, 0.48, 0.48), CFrame.new(0, 0.42, -0.42), head)
	blob(m, r, Vector3.new(0.14, 0.12, 0.3), CFrame.new(0, 0.38, -0.74), beak)
	for _, x in { -1, 1 } do
		blob(
			m,
			r,
			Vector3.new(0.12, 0.45, 0.8),
			CFrame.new(x * 0.4, 0.05, 0.05) * CFrame.Angles(0, 0, x * 0.4),
			wing
		)
		blob(m, r, Vector3.new(0.09, 0.09, 0.09), CFrame.new(x * 0.16, 0.5, -0.62), EYE)
	end
	blob(m, r, Vector3.new(0.4, 0.12, 0.5), CFrame.new(0, -0.05, 0.62), wing)
end
BUILD.Pigeon = function(m, r)
	bird(
		m,
		r,
		Color3.fromRGB(150, 156, 170),
		Color3.fromRGB(90, 110, 120),
		Color3.fromRGB(230, 160, 60),
		Color3.fromRGB(120, 126, 140)
	)
	return true
end
BUILD.Parrot = function(m, r)
	bird(
		m,
		r,
		Color3.fromRGB(60, 190, 80),
		Color3.fromRGB(220, 50, 50),
		Color3.fromRGB(250, 210, 70),
		Color3.fromRGB(50, 110, 220)
	)
	return true
end
-- the Prison Pass bird: black-and-white stripes, a tiny ball and chain
BUILD.Jailbird = function(m, r)
	bird(
		m,
		r,
		Color3.fromRGB(240, 240, 236),
		Color3.fromRGB(30, 30, 34),
		Color3.fromRGB(250, 170, 40),
		Color3.fromRGB(30, 30, 34)
	)
	for _, y in { -0.12, 0.12 } do
		blob(m, r, Vector3.new(0.74, 0.1, 1.02), CFrame.new(0, y, 0), Color3.fromRGB(30, 30, 34))
	end
	blob(
		m,
		r,
		Vector3.new(0.26, 0.26, 0.26),
		CFrame.new(0.3, -0.62, 0.35),
		Color3.fromRGB(60, 60, 66),
		Enum.Material.Metal
	)
	stick(
		m,
		r,
		Vector3.new(0.05, 0.4, 0.05),
		CFrame.new(0.2, -0.4, 0.2) * CFrame.Angles(0.4, 0, 0.5),
		Color3.fromRGB(150, 150, 160)
	)
	return true
end
BUILD.Badger = function(m, r)
	local fur = Color3.fromRGB(46, 46, 50)
	blob(m, r, Vector3.new(0.95, 0.62, 1.45), CFrame.new(0, 0.38, 0), fur)
	blob(m, r, Vector3.new(0.62, 0.52, 0.7), CFrame.new(0, 0.5, -0.82), fur)
	blob(m, r, Vector3.new(0.2, 0.3, 0.72), CFrame.new(0, 0.74, -0.78), Color3.fromRGB(240, 240, 236))
	blob(m, r, Vector3.new(0.14, 0.12, 0.14), CFrame.new(0, 0.48, -1.18), EYE)
	for _, x in { -0.24, 0.24 } do
		blob(
			m,
			r,
			Vector3.new(0.09, 0.09, 0.09),
			CFrame.new(x * 0.8, 0.6, -1.08),
			Color3.fromRGB(230, 230, 230)
		)
		for _, z in { -0.45, 0.45 } do
			blob(m, r, Vector3.new(0.22, 0.2, 0.32), CFrame.new(x * 1.7, 0.08, z), fur)
		end
	end
	return false
end
BUILD.Bulldog = function(m, r)
	local fur = Color3.fromRGB(200, 160, 110)
	blob(m, r, Vector3.new(1.1, 0.9, 1.4), CFrame.new(0, 0.75, 0), fur)
	blob(m, r, Vector3.new(0.95, 0.85, 0.8), CFrame.new(0, 1.1, -0.8), fur)
	blob(m, r, Vector3.new(0.7, 0.4, 0.4), CFrame.new(0, 0.92, -1.15), fur:Lerp(Color3.new(1, 1, 1), 0.25))
	blob(m, r, Vector3.new(0.24, 0.16, 0.16), CFrame.new(0, 1.1, -1.32), EYE)
	stick(
		m,
		r,
		Vector3.new(0.25, 0.86, 0.86),
		CFrame.new(0, 0.95, -0.42) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(180, 30, 30)
	)
	for _, x in { -0.3, 0.3 } do
		blob(m, r, Vector3.new(0.3, 0.2, 0.22), CFrame.new(x * 1.2, 1.5, -0.7), fur:Lerp(EYE, 0.4))
		blob(m, r, Vector3.new(0.11, 0.11, 0.11), CFrame.new(x * 0.8, 1.28, -1.16), EYE)
		for _, z in { -0.45, 0.45 } do
			stick(
				m,
				r,
				Vector3.new(0.6, 0.26, 0.26),
				CFrame.new(x * 1.3, 0.3, z) * CFrame.Angles(0, 0, math.pi / 2),
				fur
			)
		end
	end
	return false
end

local function build(id: string, level: number): Built
	local m = Instance.new("Model")
	m.Name = "Pet_" .. id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, -500, 0)
	root.Parent = m
	m.PrimaryPart = root
	local builder = BUILD[id] or BUILD.Rat
	local flies = builder(m, root)
	local pet = PetMath.get(id)
	local tag: TextLabel? = nil
	if pet then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 18)
		gui.StudsOffset = Vector3.new(0, 2.1, 0)
		gui.MaxDistance = 36
		gui.LightInfluence = 0
		gui.Parent = root
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 12
		l.TextColor3 = Color3.fromRGB(240, 240, 245)
		l.TextStrokeTransparency = 0.5
		l.Text = string.format("%s · Lv %d", pet.name, level)
		l.Parent = gui
		tag = l
	end
	m.Parent = folder
	return { model = m, root = root, flies = flies, tag = tag }
end

-- ===== following =====

local live: { [Player]: { Live } } = {}
local SLOTS = { Vector3.new(-2.3, 0, 2.2), Vector3.new(2.3, 0, 2.2), Vector3.new(0, 0, 3.6) }

local function parsePets(p: Player): { { id: string, level: number } }
	local raw = p:GetAttribute("Pets")
	local out = {}
	if typeof(raw) == "string" and raw ~= "" then
		for _, part in string.split(raw, ",") do
			local id, lvl = string.match(part, "^(%w+):(%d+)$")
			if id and PetMath.get(id) then
				table.insert(out, { id = id, level = tonumber(lvl) or 1 })
			end
		end
	end
	return out
end

local function refresh(p: Player)
	local old = live[p] or {}
	local want = parsePets(p)
	local same = #old == #want
	if same then
		for i, w in want do
			if old[i].id ~= w.id or old[i].level ~= w.level then
				same = false
			end
		end
	end
	if same then
		return
	end
	for _, l in old do
		l.built.model:Destroy()
	end
	local list: { Live } = {}
	local character = p.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local start = if hrp and hrp:IsA("BasePart") then hrp.Position else Vector3.new(0, -500, 0)
	for _, w in want do
		table.insert(list, {
			built = build(w.id, w.level),
			id = w.id,
			level = w.level,
			pos = start,
			look = Vector3.new(0, 0, -1),
			leapTo = nil,
			leapAt = 0,
		})
	end
	live[p] = list
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function step(dt: number)
	local now = os.clock()
	local filter: { Instance } = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(filter, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = filter
	for p, list in live do
		local character = p.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			continue
		end
		local base = hrp.CFrame
		local flatLook = Vector3.new(base.LookVector.X, 0, base.LookVector.Z)
		local yaw = if flatLook.Magnitude > 0.01
			then CFrame.lookAt(base.Position, base.Position + flatLook)
			else CFrame.new(base.Position)
		for i, l in list do
			local b = l.built
			local target = (yaw * CFrame.new(SLOTS[i] or SLOTS[1])).Position
			-- the ground under the target (characters and pets ignored)
			local hit = workspace:Raycast(target + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), rayParams)
			local groundY = if hit then hit.Position.Y else base.Position.Y - 3
			local goal = Vector3.new(target.X, groundY, target.Z)
			if b.flies then
				goal += Vector3.new(0, 3 + math.sin(now * 2.2 + i) * 0.35, 0)
			end
			-- the dig pet leaps at the rock
			if l.leapTo and now - l.leapAt < 0.5 then
				local k = (now - l.leapAt) / 0.5
				local arc = math.sin(k * math.pi)
				goal = l.pos:Lerp(l.leapTo, arc) + Vector3.new(0, arc * 1.2, 0)
			elseif l.leapTo then
				l.leapTo = nil
			end
			local moved = goal - l.pos
			l.pos = l.pos:Lerp(goal, 1 - math.exp(-dt * 9))
			local flatMove = Vector3.new(moved.X, 0, moved.Z)
			if flatMove.Magnitude > 0.15 then
				l.look = l.look:Lerp(flatMove.Unit, 1 - math.exp(-dt * 10))
			elseif flatLook.Magnitude > 0.01 then
				l.look = l.look:Lerp(flatLook.Unit, 1 - math.exp(-dt * 3))
			end
			local hop = if not b.flies and flatMove.Magnitude > 0.4
				then math.abs(math.sin(now * 13 + i)) * 0.3
				else 0
			local look = if l.look.Magnitude > 0.01 then l.look.Unit else Vector3.new(0, 0, -1)
			local cf = CFrame.lookAt(l.pos, l.pos + look) * CFrame.new(0, hop, 0)
			if b.flies then
				cf *= CFrame.Angles(math.sin(now * 14 + i) * 0.08, 0, 0)
			end
			b.root.CFrame = cf
		end
	end
end

-- ===== the shop panel =====

local function petData(): any
	local raw = player:GetAttribute("PetData")
	if typeof(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, d = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok then d else nil
end

local function buildPanel(): Panel.Panel
	local ORANGE = Color3.fromRGB(255, 200, 120)
	local BROWN = Color3.fromRGB(190, 110, 40)
	local panel = Panel.new("PetsPanel", "🐀 CELLMATES", ORANGE, BROWN, Vector2.new(560, 320))
	UI.new(
		"UIListLayout",
		{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel.body }
	)
	local buy = Remotes.get(Remotes.Names.PetBuy)
	local equip = Remotes.get(Remotes.Names.PetEquip)
	local function render()
		for _, c in panel.body:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local d = petData() or { owned = {}, equipped = {}, slots = 1, zone = 1 }
		local out = #(d.equipped or {})
		panel.subtitle.Text = string.format("out: %d / %d · escape to bring more", out, d.slots or 1)
		for i, pet in Config.List do
			local xp = d.owned and d.owned[pet.id]
			local owned = xp ~= nil
			local level, into, need = PetMath.level(xp or 0)
			local isOut = owned and table.find(d.equipped or {}, pet.id) ~= nil
			local r = Panel.row(panel.body, i, 62)
			Panel.text(
				"title",
				pet.emoji .. "  " .. pet.name .. (if owned then "  · Lv " .. level else ""),
				{
					Position = UDim2.fromOffset(12, 7),
					Size = UDim2.new(0.66, -12, 0, 18),
					Parent = r,
				}
			)
			Panel.text("desc", PetMath.perkText(pet.id, if owned then level else 1) .. " · " .. pet.desc, {
				Position = UDim2.fromOffset(12, 26),
				Size = UDim2.new(0.66, -12, 0, 16),
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = r,
			})
			if owned then
				local bar = UI.new("Frame", {
					Position = UDim2.fromOffset(12, 47),
					Size = UDim2.new(0.5, -12, 0, 4),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.88,
					Parent = r,
				}, { UI.corner(2) })
				UI.new("Frame", {
					Size = UDim2.fromScale(if need > 0 then math.clamp(into / need, 0, 1) else 1, 1),
					BackgroundColor3 = ORANGE,
					Parent = bar,
				}, { UI.corner(2) })
			end
			local text, color, action
			if owned then
				text = if isOut then "Out ✓" else "Take out"
				color = if isOut then Color3.fromRGB(128, 128, 128) else Color3.fromRGB(80, 170, 255)
				action = function()
					equip:FireServer(pet.id, not isOut)
				end
			elseif pet.exclusive then
				text = "🎫 PASS"
				color = Color3.fromRGB(128, 128, 128)
				action = nil
			elseif (d.zone or 1) < pet.zone then
				text = "🔒 Zone " .. pet.zone
				color = Color3.fromRGB(128, 128, 128)
				action = nil
			else
				text = Format.noodles(PetMath.price(pet.id))
				color = Color3.fromRGB(80, 210, 110)
				action = function()
					buy:FireServer(pet.id)
				end
			end
			local b = Panel.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.new(0.3, 0, 0, 36),
				Parent = r,
			}, color, color, text)
			if action then
				b.Activated:Connect(function()
					Sound.play("Click")
					action()
				end)
			end
		end
	end
	panel.onOpen = render
	player:GetAttributeChangedSignal("PetData"):Connect(function()
		if panel.isOpen() then
			render()
		end
	end)
	return panel
end

function Pets.start()
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace
	local function watch(p: Player)
		p:GetAttributeChangedSignal("Pets"):Connect(function()
			refresh(p)
		end)
		p.CharacterAdded:Connect(function()
			live[p] = live[p] or {}
			for _, l in live[p] do
				l.pos = Vector3.new(0, -500, 0)
			end
		end)
		refresh(p)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		for _, l in live[p] or {} do
			l.built.model:Destroy()
		end
		live[p] = nil
	end)
	RunService.Heartbeat:Connect(step)
	-- the dig pet swings
	Remotes.get(Remotes.Names.PetAct).OnClientEvent
		:Connect(function(ownerId: number, id: string, x: number, y: number, z: number, tunnelOwner: number)
			local p = Players:GetPlayerByUserId(ownerId)
			local t = VoxelRender.get(tunnelOwner)
			if not p or not t then
				return
			end
			for _, l in live[p] or {} do
				if l.id == id then
					l.leapTo = Tunnel.blockCenter(t.frame, x, y, z)
					l.leapAt = os.clock()
					if p == player then
						Sound.play("HitDirt", 0.35, 1.3)
					end
				end
			end
		end)
	Remotes.get(Remotes.Names.PetLevel).OnClientEvent:Connect(function(id: string, level: number)
		local pet = PetMath.get(id)
		if pet then
			LootToast.show({
				icon = pet.emoji,
				title = pet.name .. " · Lv " .. level,
				tag = PetMath.perkText(id, level),
				value = "LEVEL UP",
				color = Color3.fromRGB(255, 200, 120),
				seconds = 3,
			})
			Sound.play("Upgrade", 0.5, 1.3)
		end
	end)
	local tile = HUD.petsTile
	if tile then
		local panel = buildPanel()
		tile.Activated:Connect(function()
			Sound.play("Click")
			panel.toggle()
		end)
	end
end

return Pets
