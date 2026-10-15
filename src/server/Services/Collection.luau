--!strict
-- The collection: every find you ever dug up. Shown on the shelf in your cell (empty slots show a
-- "?" silhouette per zone); completing a zone's set gives +10% Noodles forever
-- (Progression.collectionMultiplier, used by Loot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Finds = require(Shared.Config.Finds)
local Zones = require(Shared.Config.Zones)
local Rarity = require(Shared.Config.Rarity)
local Progression = require(Shared.Progression)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Cells = require(script.Parent.Cells)

local Collection = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Draws the owner's collection on their cell shelf.
function Collection.render(player: Player)
	local s = State.get(player)
	if not s or not s.cell then
		return
	end
	local record = Cells.record(s.cell)
	local frame: Frame = record.shelf
	frame:ClearAllChildren()
	local rows = Economy.OpenZones
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = frame
	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.1)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 235, 150)
	local sets = #Progression.completedSets(s.data.Found)
	title.Text =
		string.format("COLLECTION · %d set%s (+%d%% 🍜)", sets, if sets == 1 then "" else "s", sets * 10)
	title.Parent = frame
	for zone = 1, rows do
		local row = Instance.new("Frame")
		row.LayoutOrder = zone
		row.BackgroundColor3 = Color3.fromRGB(70, 48, 30)
		row.BackgroundTransparency = 0.2
		row.Size = UDim2.fromScale(1, 0.88 / rows - 0.01)
		row.Parent = frame
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.fromScale(0.28, 1)
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Text = Zones[zone].name
		name.Parent = row
		local list = Finds.ByZone[zone] or {}
		for i, f in list do
			local slot = Instance.new("TextLabel")
			local have = s.data.Found[f.id] == true
			slot.BackgroundColor3 = if have
				then rgb(Rarity.Tiers[f.rarity].color):Lerp(Color3.new(0, 0, 0), 0.5)
				else Color3.fromRGB(30, 22, 16)
			slot.Position = UDim2.fromScale(0.29 + (i - 1) * 0.142, 0.06)
			slot.Size = UDim2.fromScale(0.13, 0.88)
			slot.Font = Enum.Font.FredokaOne
			slot.TextScaled = true
			slot.Text = if have then f.emoji else "?"
			slot.TextColor3 = if have then Color3.new(1, 1, 1) else Color3.fromRGB(90, 70, 55)
			slot.Parent = row
		end
	end
end

-- A find was dug up (hooked from Dig).
function Collection.onFound(player: Player, id: string, firstTime: boolean)
	if not firstTime then
		return
	end
	local s = State.get(player)
	if not s then
		return
	end
	local f = Finds.ById[id]
	Collection.render(player)
	for _, zone in Progression.completedSets(s.data.Found) do
		if f and zone == f.zone then
			Net.announce(
				string.format("%s completed the %s collection!", player.Name, Zones[zone].name),
				{ 200, 140, 255 },
				"Rare"
			)
			Net.notice(player, "Set complete: +10% Noodles forever!", "upgrade")
		end
	end
end

function Collection.multiplier(player: Player): number
	local s = State.get(player)
	return if s then Progression.collectionMultiplier(s.data.Found) else 1
end

return Collection
