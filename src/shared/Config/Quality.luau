--!strict
-- Automatic quality (Controllers/Quality): the client watches its frame rate and steps these
-- levels down when it can't hold ~45 fps (and back up when it's comfortably smooth again).

export type Level = {
	name: string,
	stream: number, -- tunnel render radius in blocks (World.StreamRadius at High)
	lights: number, -- glowing tunnel features / work lamps with a real PointLight
	shadows: boolean, -- point/spot lights cast shadows
	debris: number, -- debris cube cap (World.MaxDebris at High)
	particles: number, -- particle emission multiplier
	bloom: boolean,
}

local Quality = {
	Levels = {
		{
			name = "Low",
			stream = 24,
			lights = 6,
			shadows = false,
			debris = 60,
			particles = 0.3,
			bloom = false,
		},
		{
			name = "Medium",
			stream = 32,
			lights = 14,
			shadows = false,
			debris = 100,
			particles = 0.6,
			bloom = true,
		},
		{
			name = "High",
			stream = 40,
			lights = 28,
			shadows = true,
			debris = 150,
			particles = 1,
			bloom = true,
		},
	} :: { Level },
	DropBelow = 45, -- fps (average) ...
	DropSeconds = 4, -- ... for this long -> one level down
	RaiseAbove = 57, -- fps ...
	RaiseSeconds = 20, -- ... for this long -> one level up
	Cooldown = 8, -- seconds between changes
}

return Quality
