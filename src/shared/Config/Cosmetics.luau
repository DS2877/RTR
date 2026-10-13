--!strict
-- Trails (the glowing streak behind you while you run) and the seasonal event. Like the genre, a
-- trail is also a Speed multiplier on your treadmill, and the names climb a color ladder
-- (Bronze -> Silver -> Gold -> Emerald -> Ruby -> Galaxy) so everyone can read your rank.
-- currency: "cash" (in-game money), "candy" (Halloween event currency) or "pass" (a Robux game
-- pass with known contents; its id lives in Config/Products, `pass` = that pass's key).

export type Trail = {
	id: string,
	name: string,
	emoji: string,
	currency: string,
	price: number,
	pass: string?,
	colors: { { number } }, -- 1..n colors along the trail
	width: number,
	lifetime: number,
	glow: number, -- LightEmission 0..1
	fade: boolean?, -- fades out toward the tail
	mult: number, -- treadmill Speed multiplier while equipped
}

local Cosmetics = {
	Trails = {
		{
			id = "Sparkle",
			name = "Bronze",
			emoji = "🥉",
			currency = "cash",
			price = 5000,
			colors = { { 230, 150, 70 }, { 160, 90, 40 } },
			width = 1.2,
			lifetime = 0.5,
			glow = 0.6,
			fade = true,
			mult = 1.5,
		},
		{
			id = "NeonBlue",
			name = "Silver",
			emoji = "🥈",
			currency = "cash",
			price = 500000,
			colors = { { 245, 245, 255 }, { 170, 175, 190 } },
			width = 1.6,
			lifetime = 0.6,
			glow = 1,
			mult = 2,
		},
		{
			id = "Fire",
			name = "Gold",
			emoji = "🥇",
			currency = "cash",
			price = 50e6,
			colors = { { 255, 235, 120 }, { 255, 190, 30 }, { 200, 130, 10 } },
			width = 2,
			lifetime = 0.7,
			glow = 1,
			fade = true,
			mult = 3,
		},
		{
			id = "Money",
			name = "Emerald",
			emoji = "💚",
			currency = "cash",
			price = 2e9,
			colors = { { 120, 255, 170 }, { 30, 180, 90 } },
			width = 2.2,
			lifetime = 0.8,
			glow = 0.8,
			mult = 4,
		},
		{
			id = "Lightning",
			name = "Ruby",
			emoji = "❤️",
			currency = "cash",
			price = 100e9,
			colors = { { 255, 120, 140 }, { 220, 20, 60 }, { 120, 0, 30 } },
			width = 2.4,
			lifetime = 0.5,
			glow = 1,
			mult = 6,
		},
		{
			id = "Galaxy",
			name = "Galaxy",
			emoji = "🌌",
			currency = "cash",
			price = 5e12,
			colors = { { 255, 120, 255 }, { 140, 80, 255 }, { 40, 40, 160 } },
			width = 2.8,
			lifetime = 1,
			glow = 1,
			fade = true,
			mult = 10,
		},
		{
			id = "Pumpkin",
			name = "Pumpkin",
			emoji = "🎃",
			currency = "candy",
			price = 150,
			colors = { { 255, 160, 40 }, { 255, 90, 0 }, { 40, 20, 10 } },
			width = 2.2,
			lifetime = 0.8,
			glow = 0.9,
			fade = true,
			mult = 2.5,
		},
		{
			id = "Ghost",
			name = "Ghost",
			emoji = "👻",
			currency = "candy",
			price = 400,
			colors = { { 230, 255, 255 }, { 170, 220, 255 } },
			width = 2.6,
			lifetime = 1.1,
			glow = 0.7,
			fade = true,
			mult = 4,
		},
		{
			id = "Rainbow",
			name = "Rainbow",
			emoji = "🌈",
			currency = "pass",
			price = 0,
			pass = "RainbowTrail",
			colors = {
				{ 255, 70, 70 },
				{ 255, 180, 40 },
				{ 255, 255, 70 },
				{ 80, 230, 110 },
				{ 70, 170, 255 },
				{ 170, 90, 255 },
			},
			width = 2.6,
			lifetime = 0.9,
			glow = 1,
			mult = 5,
		},
	} :: { Trail },

	-- Seasonal event: active from `from` to `to` (month, day; UTC), every year, automatically.
	Season = {
		id = "Halloween",
		name = "HALLOWEEN",
		from = { 10, 1 },
		to = { 11, 3 },
	},
	-- 🍬 candy for every crate you bring home during the season, by the crate's rarity
	CandyPerCrate = {
		Common = 5,
		Uncommon = 8,
		Rare = 12,
		Epic = 20,
		Legendary = 35,
		Mythic = 60,
	} :: { [string]: number },
}

-- Treadmill Speed multiplier of an equipped trail ("" / unknown = 1).
function Cosmetics.trailMult(id: string?): number
	local t = id and Cosmetics.trail(id)
	return if t then t.mult else 1
end

function Cosmetics.trail(id: string): Trail?
	for _, t in Cosmetics.Trails do
		if t.id == id then
			return t
		end
	end
	return nil
end

-- Is the season running on this date? (`date` = os.date("!*t") style table)
function Cosmetics.seasonActive(date: { month: number, day: number }): boolean
	local s = Cosmetics.Season
	local v = date.month * 100 + date.day
	return v >= s.from[1] * 100 + s.from[2] and v <= s.to[1] * 100 + s.to[2]
end

return Cosmetics
