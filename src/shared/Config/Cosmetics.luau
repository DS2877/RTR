--!strict
-- Trails (the glowing streak behind you while you run) and the seasonal event.
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
}

local Cosmetics = {
	Trails = {
		{
			id = "Sparkle",
			name = "Sparkle",
			emoji = "✨",
			currency = "cash",
			price = 5000,
			colors = { { 255, 255, 255 }, { 255, 240, 170 } },
			width = 1.2,
			lifetime = 0.5,
			glow = 0.6,
			fade = true,
		},
		{
			id = "NeonBlue",
			name = "Neon Blue",
			emoji = "💠",
			currency = "cash",
			price = 500000,
			colors = { { 70, 200, 255 }, { 40, 90, 255 } },
			width = 1.6,
			lifetime = 0.6,
			glow = 1,
		},
		{
			id = "Fire",
			name = "Fire",
			emoji = "🔥",
			currency = "cash",
			price = 50e6,
			colors = { { 255, 230, 90 }, { 255, 120, 30 }, { 200, 20, 20 } },
			width = 2,
			lifetime = 0.7,
			glow = 1,
			fade = true,
		},
		{
			id = "Money",
			name = "Money Rain",
			emoji = "💸",
			currency = "cash",
			price = 2e9,
			colors = { { 120, 255, 130 }, { 40, 170, 70 } },
			width = 2.2,
			lifetime = 0.8,
			glow = 0.8,
		},
		{
			id = "Lightning",
			name = "Lightning",
			emoji = "⚡",
			currency = "cash",
			price = 100e9,
			colors = { { 255, 255, 255 }, { 120, 230, 255 }, { 60, 120, 255 } },
			width = 2.4,
			lifetime = 0.5,
			glow = 1,
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
		},
	} :: { Trail },

	-- Seasonal event: active from `from` to `to` (month, day; UTC), every year, automatically.
	Season = {
		id = "Halloween",
		name = "HALLOWEEN",
		from = { 10, 1 },
		to = { 11, 3 },
	},
	CandyPerPickup = 1,
	BigCandyChance = 0.12, -- a pumpkin pickup worth BigCandy
	BigCandy = 5,
}

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
