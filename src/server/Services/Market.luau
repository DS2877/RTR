--!strict
-- Noodle shops beyond the upgrades: LAUNDRY (uniforms, fist trails), MESS HALL (buffs until the
-- next morning), BLACK MARKET (3 items a day, rotating at 00:00 UTC) and DECOR (placed in your
-- tunnel for everyone to see). Buffs feed Dig (power, finds, speed) and Loot (magnet).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Extras = require(Shared.Config.Extras)
local Assets = require(Shared.Config.Assets)
local Finds = require(Shared.Config.Finds)
local World = require(Shared.Config.World)
local Voxel = require(Shared.Voxel)
local Progression = require(Shared.Progression)
local Tunnel = require(Shared.Tunnel)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local RateLimit = require(script.Parent.Parent.Util.RateLimit)
local Build = require(script.Parent.Parent.Util.Build)
local Stats = require(script.Parent.Stats)

local Market = {}

local restoring: { [Player]: boolean } = {} -- "Own" is re-applying the avatar

local world: any = nil
local decorFolder: Folder? = nil

local function find(list: { Extras.Item }, id: string): Extras.Item?
	for _, it in list do
		if it.id == id then
			return it
		end
	end
	return nil
end

local function today(): number
	return os.time() // 86400
end

-- ===== buffs =====

local function buffActive(s: State.PlayerState, id: string): boolean
	local ends = s.buffs[id]
	return ends ~= nil and (ends == math.huge or os.time() < ends)
end

local function sum(player: Player, field: string): number
	local s = State.get(player)
	if not s then
		return 0
	end
	local total = 0
	for id, cfg in Extras.Buffs do
		local v = (cfg :: any)[field]
		if typeof(v) == "number" and buffActive(s, id) then
			total += v
		end
	end
	return total
end

function Market.powerBoost(player: Player): number
	return 1 + sum(player, "power")
end

function Market.findBoost(player: Player): number
	return sum(player, "finds")
end

function Market.speedBoost(player: Player): number
	return sum(player, "speed")
end

function Market.magnet(player: Player): boolean
	local s = State.get(player)
	return s ~= nil and buffActive(s, "Magnet")
end

local function syncBuffs(player: Player)
	local s = State.get(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	local list = {}
	for id in Extras.Buffs do
		if buffActive(s, id) then
			table.insert(list, id)
		end
	end
	table.sort(list)
	player:SetAttribute("Buffs", table.concat(list, ","))
	player:SetAttribute("FastPunch", Market.speedBoost(player))
	player:SetAttribute("Magnet", Market.magnet(player))
end

-- Buffs cost Noodles: they survive a rejoin / server hop. Timed ones keep their end time; an
-- "until the morning" meal comes back if you return within MorningKeepSeconds.
local MORNING_KEEP = 10 * 60

function Market.saveBuffs(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local out = {}
	for id, ends in s.buffs do
		out[id] = if ends == math.huge then 0 else ends
	end
	s.data.Buffs, s.data.BuffsAt = out, os.time()
end

function Market.loadBuffs(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	local t = os.time()
	for id, ends in s.data.Buffs or {} do
		if Extras.Buffs[id] and typeof(ends) == "number" then
			if ends == 0 and t - (s.data.BuffsAt or 0) < MORNING_KEEP then
				s.buffs[id] = math.huge
			elseif ends > t then
				s.buffs[id] = ends
			end
		end
	end
	syncBuffs(player)
end

-- A bought buff for `seconds` more (Robux products: NOODLE RUSH); stacks onto time left.
function Market.addBuff(player: Player, id: string, seconds: number)
	local s = State.get(player)
	if not s then
		return
	end
	local now = os.time()
	local ends = s.buffs[id]
	local from = if ends and ends ~= math.huge and ends > now then ends else now
	s.buffs[id] = from + seconds
	syncBuffs(player)
end

-- DayNight hook: meals last until the morning.
function Market.morning()
	for player, s in State.all() do
		for id, ends in table.clone(s.buffs) do
			if ends == math.huge then
				s.buffs[id] = nil
			end
		end
		syncBuffs(player)
	end
end

-- ===== looks =====

local LAYERED: { [Enum.AccessoryType]: boolean } = {
	[Enum.AccessoryType.TShirt] = true,
	[Enum.AccessoryType.Shirt] = true,
	[Enum.AccessoryType.Pants] = true,
	[Enum.AccessoryType.Jacket] = true,
	[Enum.AccessoryType.Sweater] = true,
	[Enum.AccessoryType.Shorts] = true,
	[Enum.AccessoryType.DressSkirt] = true,
	[Enum.AccessoryType.LeftShoe] = true,
	[Enum.AccessoryType.RightShoe] = true,
}

local function applyLooks(player: Player)
	local s = State.get(player)
	local character = typeof(player) == "Instance" and player.Character or nil
	if not s or not character then
		return
	end
	-- every prisoner wears a jumpsuit (Classic Orange unless they picked another one)
	local uniform = find(Extras.Uniforms, if s.data.Uniform ~= "" then s.data.Uniform else "Orange")
	if uniform and uniform.color then
		for _, c in character:GetChildren() do
			-- (3D layered clothing would sit on top of the jumpsuit: red pants, a glowing top...)
			if
				c:IsA("Shirt")
				or c:IsA("Pants")
				or c:IsA("ShirtGraphic")
				or (c:IsA("Accessory") and LAYERED[c.AccessoryType])
			then
				c:Destroy()
			end
		end
		-- Classic Orange = the real prison shirt + INMATE pants from the catalog, on top of your
		-- own skin and accessories (layered clothing filtered out); other uniforms recolor the body
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local dressed = false
		if uniform.id == "Orange" and humanoid then
			dressed = pcall(function()
				local desc = humanoid:GetAppliedDescription()
				local keep = {}
				for _, acc in desc:GetAccessories(true) do
					if not acc.IsLayered then
						table.insert(keep, acc)
					end
				end
				desc:SetAccessories(keep, true)
				desc.Shirt = Assets.Outfits.inmate.Shirt
				desc.Pants = Assets.Outfits.inmate.Pants
				desc.GraphicTShirt = 0
				humanoid:ApplyDescription(desc)
			end)
		end
		local color = Build.rgb(uniform.color)
		local bc = if dressed then nil else character:FindFirstChildOfClass("BodyColors")
		if bc then
			bc.TorsoColor3 = color
			bc.LeftLegColor3 = color
			bc.RightLegColor3 = color
			bc.LeftArmColor3 = color
			bc.RightArmColor3 = color
		end
		for _, part in if dressed then {} else character:GetChildren() do
			if
				part:IsA("BasePart")
				and not string.find(part.Name, "Hand")
				and part.Name ~= "Head"
				and part.Name ~= "HumanoidRootPart"
			then
				part.Color = color
			end
		end
	end
	-- the cell number stenciled on the back
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") and s.cell and not torso:FindFirstChild("CellNumber") then
		local gui = Instance.new("SurfaceGui")
		gui.Name = "CellNumber"
		gui.Face = Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 1
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = string.format("%02d", s.cell)
		label.TextColor3 = Color3.fromRGB(30, 30, 34)
		label.TextTransparency = 0.15
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.18, 0)
		pad.PaddingBottom = UDim.new(0.18, 0)
		pad.PaddingLeft = UDim.new(0.2, 0)
		pad.PaddingRight = UDim.new(0.2, 0)
		pad.Parent = label
		label.Parent = gui
		gui.Parent = torso
	end
	-- fists: VIP = gold hands, plus a trail on each fist
	local gold = s.passes.VIP
	for _, side in { "Left", "Right" } do
		local hand = character:FindFirstChild(side .. "Hand") or character:FindFirstChild(side .. " Arm")
		if hand and hand:IsA("BasePart") then
			if gold then
				-- polished gold, not Neon: Neon + bloom turned the fists into glowing blobs
				hand.Color = Color3.fromRGB(232, 178, 52)
				hand.Material = Enum.Material.SmoothPlastic
				hand.Reflectance = 0.18
			end
			local old = hand:FindFirstChild("FistTrail")
			if old then
				old:Destroy()
			end
			local fist = find(Extras.Fists, s.data.Fist)
			if fist and fist.color then
				local a0 = Instance.new("Attachment")
				a0.Position = Vector3.new(0, 0.3, 0)
				a0.Parent = hand
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, -0.3, 0)
				a1.Parent = hand
				local trail = Instance.new("Trail")
				trail.Name = "FistTrail"
				trail.Attachment0 = a0
				trail.Attachment1 = a1
				trail.Lifetime = 0.25
				trail.LightEmission = 1
				trail.Color = ColorSequence.new(Build.rgb(fist.color))
				trail.Transparency = NumberSequence.new(0.2, 1)
				trail.Parent = hand
			end
		end
	end
end

function Market.onCharacter(player: Player)
	task.wait(0.5)
	applyLooks(player)
	-- the avatar's own clothes can arrive later: put the jumpsuit back on once they're in
	-- (gives up after 15 s or when the player left)
	if typeof(player) == "Instance" then
		local t0 = os.clock()
		while player.Parent and not player:HasAppearanceLoaded() and os.clock() - t0 < 15 do
			task.wait(0.5)
		end
		if player.Parent then
			applyLooks(player)
		end
	end
end

-- ===== decor =====

local function decorModel(kind: string, cf: CFrame, s: State.PlayerState): Model
	local m = Instance.new("Model")
	m.Name = kind
	local wood = Color3.fromRGB(130, 90, 50)
	local metal = Color3.fromRGB(110, 112, 118)
	local base = cf * CFrame.new(0, -World.BlockSize / 2, 0) -- floor of the block
	local function p(name: string, size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?)
		local part = Build.part(m, name, size, base * offset, color, props)
		part.CanCollide = false
		return part
	end
	if kind == "Lamp" then
		p("Pole", Vector3.new(0.3, 3.2, 0.3), CFrame.new(0, 1.6, 0), metal)
		local bulb =
			p("Bulb", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 3.4, 0), Color3.fromRGB(255, 230, 160), {
				Material = Enum.Material.Neon,
			})
		Build.light(bulb, Color3.fromRGB(255, 220, 160), 18, 1.4)
	elseif kind == "Rails" then
		for _, dx in { -0.7, 0.7 } do
			p(
				"Rail",
				Vector3.new(0.2, 0.2, 2),
				CFrame.new(dx, 0.3, 0),
				metal,
				{ Material = Enum.Material.Metal }
			)
		end
		for dz = -0.75, 0.75, 0.5 do
			p(
				"Tie",
				Vector3.new(1.9, 0.15, 0.3),
				CFrame.new(0, 0.12, dz),
				wood,
				{ Material = Enum.Material.Wood }
			)
		end
	elseif kind == "Cart" then
		p("Bin", Vector3.new(1.6, 1, 1.8), CFrame.new(0, 0.9, 0), metal, { Material = Enum.Material.Metal })
		p(
			"Load",
			Vector3.new(1.4, 0.4, 1.6),
			CFrame.new(0, 1.5, 0),
			Color3.fromRGB(150, 140, 125),
			{ Material = Enum.Material.Slate }
		)
		for _, dx in { -0.8, 0.8 } do
			for _, dz in { -0.6, 0.6 } do
				p("Wheel", Vector3.new(0.2, 0.6, 0.6), CFrame.new(dx, 0.3, dz), Color3.fromRGB(40, 40, 44), {
					Shape = Enum.PartType.Cylinder,
				})
			end
		end
	elseif kind == "Sign" then
		p("Post", Vector3.new(0.25, 2.4, 0.25), CFrame.new(0, 1.2, 0), wood)
		local board = p(
			"Board",
			Vector3.new(1.8, 1, 0.15),
			CFrame.new(0, 2.2, 0),
			wood,
			{ Material = Enum.Material.WoodPlanks }
		)
		Build.sign(board, Enum.NormalId.Front, "KEEP OUT!", Color3.fromRGB(255, 240, 200))
		Build.sign(board, Enum.NormalId.Back, "KEEP OUT!", Color3.fromRGB(255, 240, 200))
	elseif kind == "Barrel" then
		p(
			"Barrel",
			Vector3.new(1.6, 1.3, 1.3),
			CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(150, 70, 40),
			{
				Shape = Enum.PartType.Cylinder,
				Material = Enum.Material.Wood,
			}
		)
	elseif kind == "Flag" then
		p("Pole", Vector3.new(0.15, 3.6, 0.15), CFrame.new(0, 1.8, 0), metal)
		p(
			"Cloth",
			Vector3.new(0.05, 0.9, 1.4),
			CFrame.new(0, 3.1, 0.7),
			Color3.fromRGB(230, 60, 60),
			{ Material = Enum.Material.Fabric }
		)
	elseif kind == "Trophy" then
		p(
			"Stand",
			Vector3.new(1.4, 1.2, 1.4),
			CFrame.new(0, 0.6, 0),
			Color3.fromRGB(60, 50, 70),
			{ Material = Enum.Material.Marble }
		)
		local glass =
			p("Glass", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.8, 0), Color3.fromRGB(200, 230, 255), {
				Transparency = 0.6,
				Material = Enum.Material.Glass,
			})
		-- best find ever
		local best, bestValue = "🏆", -1
		for id in s.data.Found do
			local f = Finds.ById[id]
			if f and f.value > bestValue then
				best, bestValue = f.emoji, f.value
			end
		end
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(1.4, 1.4)
		gui.LightInfluence = 0
		gui.MaxDistance = 60
		gui.Adornee = glass
		gui.Parent = glass
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.TextScaled = true
		l.Text = best
		l.Parent = gui
	end
	return m
end

function Market.renderDecor(player: Player)
	local s = State.get(player)
	if not s or not decorFolder or not s.cell then
		return
	end
	local name = "Cell" .. s.cell
	local old = decorFolder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	local frame = Tunnel.frame(s.cell)
	for _, p in s.data.Placed do
		local item = Extras.Decor[p[1]]
		if item then
			local cf = frame * CFrame.new(Tunnel.localCenter(p[2], p[3], p[4]))
			decorModel(item.id, cf, s).Parent = f
		end
	end
	f.Parent = decorFolder
end

function Market.clearRender(player: Player)
	local s = State.get(player)
	if s and s.cell and decorFolder then
		local old = decorFolder:FindFirstChild("Cell" .. s.cell)
		if old then
			old:Destroy()
		end
	end
end

-- Places one owned decor item where you stand (inside your own dug tunnel). Returns a reason.
function Market.place(player: Player, kind: string): string?
	local s = State.get(player)
	local pos = State.root(player)
	if not s or not s.grid or not s.frame or not pos then
		return "no state"
	end
	local index: number? = nil
	for i, item in Extras.Decor do
		if item.id == kind then
			index = i
		end
	end
	if not index or (s.data.Decor[kind] or 0) <= 0 then
		return "not owned"
	end
	if #s.data.Placed >= Extras.MaxPlaced then
		Net.notice(player, "Your tunnel is full of decor!", "info")
		return "full"
	end
	if kind == "Lamp" then
		local lamps = 0
		for _, p in s.data.Placed do
			if Extras.Decor[p[1]] and Extras.Decor[p[1]].id == "Lamp" then
				lamps += 1
			end
		end
		if lamps >= Extras.MaxLamps then
			Net.notice(player, "Max " .. Extras.MaxLamps .. " lamps per tunnel", "info")
			return "lamps"
		end
	end
	-- the block at your feet (root is ~3 studs above the floor)
	local x, y, z = Tunnel.toBlock(s.frame, pos - Vector3.new(0, 2.5, 0))
	if not Voxel.inBounds(s.grid, x, y, z) or not Voxel.isDug(s.grid, x, y, z) then
		Net.notice(player, "Stand inside your own tunnel to place decor.", "info")
		return "not in tunnel"
	end
	-- drop it to the floor
	while y > 0 and Voxel.isDug(s.grid, x, y - 1, z) do
		y -= 1
	end
	s.data.Decor[kind] -= 1
	table.insert(s.data.Placed, { index, x, y, z })
	Market.renderDecor(player)
	Market.sync(player)
	return nil
end

function Market.clearDecor(player: Player)
	local s = State.get(player)
	if not s then
		return
	end
	for _, p in s.data.Placed do
		local item = Extras.Decor[p[1]]
		if item then
			s.data.Decor[item.id] = (s.data.Decor[item.id] or 0) + 1
		end
	end
	s.data.Placed = {}
	Market.renderDecor(player)
	Market.sync(player)
end

-- ===== buying =====

function Market.sync(player: Player)
	local s = State.get(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	local owned = {}
	for id, n in s.data.Decor do
		if n > 0 then
			table.insert(owned, id .. "=" .. n)
		end
	end
	player:SetAttribute("DecorOwned", table.concat(owned, ","))
	local uniforms = {}
	for id in s.data.Uniforms do
		table.insert(uniforms, id)
	end
	player:SetAttribute("UniformsOwned", table.concat(uniforms, ","))
	player:SetAttribute("Uniform", s.data.Uniform)
	player:SetAttribute("Fist", s.data.Fist)
	syncBuffs(player)
end

local SHOP_PART =
	{ Laundry = "Laundry", MessHall = "MessHall", BlackMarket = "BlackMarket", Decor = "Workshop" }

-- Returns a reason when refused.
function Market.buy(player: Player, shop: string, id: string): string?
	local s = State.get(player)
	local pos = State.root(player)
	if not s or not pos then
		return "no state"
	end
	local partName = SHOP_PART[shop]
	local counter = partName and world.shops[partName]
	if not counter or (counter.Position - pos).Magnitude > 22 then
		return "too far"
	end
	local item: Extras.Item? = nil
	if shop == "Laundry" then
		item = find(Extras.Uniforms, id) or find(Extras.Fists, id)
	elseif shop == "MessHall" then
		item = find(Extras.Meals, id)
	elseif shop == "BlackMarket" then
		if table.find(Progression.marketStock(today()), id) then
			item = find(Extras.Market, id)
		end
	elseif shop == "Decor" then
		item = find(Extras.Decor, id)
	end
	if not item then
		return "not sold"
	end
	if shop == "Laundry" and s.data.Uniforms[id] then
		-- already owned: equip it
		Market.equip(player, id)
		return nil
	end
	if item.pass then
		Net.notice(player, "🎫 Earn it on the Prison Pass!", "info")
		return "pass only"
	end
	if item.starter then
		Net.notice(player, "🎁 Comes with the Starter Pack (Store)!", "info")
		return "starter only"
	end
	local price = Progression.itemPrice(item, s.data.Zone)
	if s.data.Noodles < price then
		Net.notice(player, "Not enough Noodles 🍜", "bad")
		return "poor"
	end
	s.data.Noodles -= price
	if shop == "Laundry" then
		s.data.Uniforms[id] = true
		Market.equip(player, id)
	elseif shop == "Decor" then
		s.data.Decor[id] = (s.data.Decor[id] or 0) + 1
		Net.notice(
			player,
			item.emoji .. " " .. item.name .. " bought! Place it with 💡 in your tunnel.",
			"upgrade"
		)
	elseif id == "Dynamite" then
		s.data.Dynamite += 1
		if typeof(player) == "Instance" then
			player:SetAttribute("Dynamite", s.data.Dynamite)
		end
		Net.notice(player, "🧨 +1 Dynamite", "upgrade")
	elseif item.buff then
		s.buffs[item.buff] = if item.seconds then os.time() + item.seconds else math.huge
		Net.notice(player, item.emoji .. " " .. item.name .. ": " .. item.desc, "upgrade")
	end
	Stats.sync(player)
	Market.sync(player)
	return nil
end

function Market.equip(player: Player, id: string)
	local s = State.get(player)
	if not s then
		return
	end
	if id == "Own" then
		if s.data.Uniform == "" then
			return
		end
		-- back to the classic jumpsuit: undo a recolored uniform by re-applying the avatar in place
		-- (no respawn, no trip back to the cell), then the jumpsuit goes on again
		s.data.Uniform = ""
		Market.sync(player)
		if typeof(player) == "Instance" and not restoring[player] then
			restoring[player] = true
			task.spawn(function()
				local ok, desc = pcall(function()
					return Players:GetHumanoidDescriptionFromUserId(player.UserId)
				end)
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if ok and desc and humanoid and s.data.Uniform == "" then
					pcall(function()
						humanoid:ApplyDescription(desc)
					end)
					applyLooks(player)
				end
				restoring[player] = nil
			end)
		end
		return
	elseif find(Extras.Uniforms, id) and (s.data.Uniforms[id] or id == "Orange") then
		s.data.Uniform = id
	elseif find(Extras.Fists, id) and s.data.Uniforms[id] then
		s.data.Fist = if s.data.Fist == id then "" else id -- tap again to take them off
	end
	Market.sync(player)
	applyLooks(player)
end

function Market.start(w: any)
	world = w
	local f = Instance.new("Folder")
	f.Name = "Decor"
	f.Parent = workspace:FindFirstChild("Prison") or workspace
	decorFolder = f
	local limit = RateLimit.new(3, 5)
	Net.on(Remotes.Names.BuyItem, function(player, shop, id)
		if limit(player) and typeof(shop) == "string" and typeof(id) == "string" and #id < 24 then
			Market.buy(player, shop, id)
		end
	end)
	Net.on(Remotes.Names.Equip, function(player, kind, id)
		if limit(player) and kind == "uniform" and typeof(id) == "string" then
			Market.equip(player, id)
		end
	end)
	Net.on(Remotes.Names.PlaceDecor, function(player, kind)
		if limit(player) and typeof(kind) == "string" then
			Market.place(player, kind)
		end
	end)
	Net.on(Remotes.Names.ClearDecor, function(player)
		if limit(player) then
			Market.clearDecor(player)
		end
	end)
	-- timed buffs run out
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				task.wait(5)
				for player, s in State.all() do
					local changed = false
					for id, ends in table.clone(s.buffs) do
						if ends ~= math.huge and os.time() >= ends then
							s.buffs[id] = nil
							changed = true
						end
					end
					if changed then
						syncBuffs(player)
					end
				end
			end)
			if not ok then
				warn("[Market] loop:", err)
				task.wait(1)
			end
		end
	end)
	ReplicatedStorage:SetAttribute("MarketDay", today())
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				task.wait(30)
				ReplicatedStorage:SetAttribute("MarketDay", today())
			end)
			if not ok then
				warn("[Market] loop:", err)
				task.wait(1)
			end
		end
	end)
end

return Market
