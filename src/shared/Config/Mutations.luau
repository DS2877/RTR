--!strict
-- Mutations roll when loot spawns in a vault. Fusing 3 identical items gives the next tier.

export type Mutation = {
	id: string,
	mult: number,
	chance: number, -- chance on spawn (checked rarest first); "None" is the rest
	color: { number }?,
	label: string,
}

local Mutations = {
	Order = { "None", "Gold", "Diamond", "Rainbow" },
	List = {
		None = { id = "None", mult = 1, chance = 0, label = "" },
		Gold = { id = "Gold", mult = 2, chance = 0.06, color = { 255, 200, 40 }, label = "GOLD" },
		Diamond = { id = "Diamond", mult = 5, chance = 0.015, color = { 120, 230, 255 }, label = "DIAMOND" },
		Rainbow = { id = "Rainbow", mult = 15, chance = 0.003, color = { 255, 120, 220 }, label = "RAINBOW" },
	} :: { [string]: Mutation },
	FuseCount = 3, -- identical items needed for one fuse
}

-- The tier after `id`, or nil at the top.
function Mutations.next(id: string): string?
	for i, m in Mutations.Order do
		if m == id then
			return Mutations.Order[i + 1]
		end
	end
	return nil
end

return Mutations
