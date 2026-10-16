--!strict
-- THE BREAKOUT: the playable escape at the end of the tunnel (Services/Breakout, Shared/Breakout).
-- Sewer -> manhole -> searchlit yard (guards on your heels) -> the wall -> the getaway car.
-- Rewards are known up front: the medal decides the Noodles you smuggle into the next prison.

local Breakout = {
	-- where the course floats (far above the prison: its own little night world)
	Origin = { x = 0, y = 420, z = 0 },
	TimeLimit = 240, -- seconds: after this the run ends anyway (FREE, no medal)
	MinTime = 20, -- a finish faster than this is not believed (teleport exploits)
	Grace = 2.5, -- seconds after a (re)spawn before lights and chasers can get you
	-- searchlights: circles on the yard floor
	LightRadius = 7.5,
	TowerLightRadius = 5,
	-- the guards on your heels run your own path this many seconds behind you
	ChaserDelay = 4.5,
	CatchRadius = 3,
	Medals = {
		{ id = "gold", name = "GOLD ESCAPE", emoji = "🥇", time = 80, spotted = 0, cash = 3000 },
		{ id = "silver", name = "SILVER ESCAPE", emoji = "🥈", time = 130, spotted = 2, cash = 1500 },
		{
			id = "bronze",
			name = "BRONZE ESCAPE",
			emoji = "🥉",
			time = math.huge,
			spotted = math.huge,
			cash = 600,
		},
	},
}

return Breakout
