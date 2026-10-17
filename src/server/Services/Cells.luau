--!strict
-- Cell assignment (like tycoon plots): every player gets a free cell on join.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)
local State = require(script.Parent.Parent.State)
local Hideout = require(script.Parent.Hideout)

local Cells = {}

local world: any = nil
local owners: { [number]: any } = {} -- cell index -> player

function Cells.start(w: any)
	world = w
end

function Cells.assign(player: Player): number?
	for i = 1, #world.cells do
		if owners[i] == nil then
			owners[i] = player
			local s = State.get(player)
			if s then
				s.cell = i
				s.frame = world.cells[i].frame
			end
			world.cells[i].model:SetAttribute("Owner", player.UserId)
			Cells.updateSign(player)
			return i
		end
	end
	return nil
end

function Cells.release(player: Player)
	for i, p in owners do
		if p == player then
			owners[i] = nil
			local cell = world.cells[i]
			cell.model:SetAttribute("Owner", nil)
			cell.sign.Text = "CELL " .. i .. "\nFREE"
			cell.shelf:ClearAllChildren()
		end
	end
end

function Cells.ownerOf(cell: number): any
	return owners[cell]
end

function Cells.record(cell: number): any
	return world.cells[cell]
end

function Cells.updateSign(player: Player)
	local s = State.get(player)
	if not s or not s.cell then
		return
	end
	local zone = Zones[s.data.Zone] or Zones[1]
	world.cells[s.cell].sign.Text =
		string.format("%s\n⛏️ %dm · %s", player.Name, s.data.RunDepth, zone.name)
end

-- Puts the character inside its cell, facing the back wall.
function Cells.toCell(player: Player)
	local s = State.get(player)
	local character = player.Character
	if not s or not s.cell or not character then
		return
	end
	Hideout.wake(player)
	character:PivotTo(world.cells[s.cell].spawn)
end

return Cells
