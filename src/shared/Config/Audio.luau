--!strict
-- The sound design. Every id is Roblox-licensed Creator Store audio from ProSoundEffects (usable in
-- any experience); the smoke test re-checks every one with MarketplaceService:GetProductInfo.
--
-- Banks = variations of one sound (Sound.play picks one at random, never the same twice in a row).
-- Materials = how each zone's blocks sound: `hit` while cracking, `break` when it gives, `extra`
-- an optional layer on breaks (rebar clank, steam, wet splat...). `pitch` shifts the whole set.

local function ids(list: { number }): { string }
	local out = {}
	for i, n in list do
		out[i] = "rbxassetid://" .. n
	end
	return out
end

local Audio = {
	Banks = {
		-- the punch itself: air + fist
		Swing = ids({ 9120728815, 9120728883, 9120729005, 9120729007, 9120729134, 9120729337 }), -- Whoosh Heavy Punches
		Fist = ids({ 9117969687, 9117969717, 9117969878, 9117969892, 9117970193, 9117970227 }), -- Punch Kit Beefy Hit
		-- material hits (block takes damage)
		HitConcrete = ids({ 9113225186, 9113225187, 9113225476, 9113225486, 9113225488 }), -- Axe Impact Big Hits Against Concrete
		HitRock = ids({ 9118598279, 9118598469, 9118598470, 9118598729 }), -- Rock Hit Dirt Impact (tight)
		HitDirt = ids({ 9114109300, 9114109952, 9114110819, 9114084044, 9114084427 }), -- Dirt Impacts / Digging With Pick
		HitMetal = ids({ 9116647303, 9116647574, 9116651688 }), -- Metal Hit Concrete / Metal Hits
		HitGlass = ids({ 9114591164, 9114591567, 9114591759 }), -- Glass Break(s), played soft and high
		HitStone = ids({ 9118608146, 9118612324, 9118612665, 9118612945 }), -- Rock Hits Rock / Rock Impact
		-- material breaks
		BreakConcrete = ids({ 9118587493, 9118587698, 9118587701, 9118588165 }), -- Rock Drop On Concrete Drops Breaks
		BreakRock = ids({ 9125869504, 9125869495, 9125869138, 9125869107, 9125869108 }), -- Rock Cracks ... Impact Debris
		BreakDirt = ids({ 9114083537, 9114083746, 9118616114 }), -- Dirt Throws From Shovel / Rock Impact Dirt Thuds
		BreakGlass = ids({ 9114592237, 9114591718, 9114592245 }), -- Glass Breaks
		BreakStone = ids({ 9119048272, 9119599198, 9118582938, 9118582978 }), -- Shale Break / Statue Debris / Rock Crack
		-- layers on top of a break
		Debris = ids({ 9118583120, 9118583136, 9118586609, 9118586608 }), -- Rock Crack Crackling Debris / Rock Debris
		BigBreak = ids({ 9119186658, 9114221862 }), -- Slab Drop Debris / Earthquake Debris Rock Bursts
		Rebar = ids({ 9125672726, 9125672562 }), -- Metal Impact Sledge Hammer
		Splat = ids({ 9119478716, 9113604746 }), -- Splashes Debris Falling Into The Sewer / Bubbles In Sewer
		Sear = ids({ 9118884046, 9118884310 }), -- Searing Bursts (lava)
		Chime = ids({ 9126073001, 9126073318 }), -- Synth Sparkle Tone (crystal)
		-- cubes hitting the floor, the vacuum
		Land = ids({ 9114657439, 9114657434, 9114657456, 9118688006 }), -- Gravel Hits / Rocks Dirt Impacts
		Suck = ids({ 9119669295, 9119669065, 9119669074, 9119669618 }), -- Suction Pop
		-- prison
		CellDoor = ids({ 9114885296, 9114885622, 9117911977 }), -- Jail Cell Door / Prison Door
		Boom = ids({ 9114224354 }), -- Earthquake Explosion
		UIClick = ids({ 9119717529, 9119717523 }), -- Switch Click Toggle Button
	} :: { [string]: { string } },

	Materials = {
		Plaster = { hit = "HitConcrete", pitch = 1.25, breakBank = "BreakConcrete", volume = 0.5 },
		Brick = { hit = "HitConcrete", pitch = 1.05, breakBank = "BreakRock", volume = 0.6 },
		Concrete = { hit = "HitConcrete", pitch = 0.92, breakBank = "BreakConcrete", volume = 0.65 },
		Reinforced = {
			hit = "HitMetal",
			pitch = 0.9,
			breakBank = "BreakConcrete",
			extra = "Rebar",
			volume = 0.6,
		},
		Clay = { hit = "HitDirt", pitch = 0.95, breakBank = "BreakDirt", volume = 0.7 },
		Sewer = { hit = "HitDirt", pitch = 0.85, breakBank = "BreakDirt", extra = "Splat", volume = 0.7 },
		Bedrock = { hit = "HitRock", pitch = 0.75, breakBank = "BreakRock", volume = 0.75 },
		Crystal = { hit = "HitGlass", pitch = 1.35, breakBank = "BreakGlass", extra = "Chime", volume = 0.35 },
		Magma = { hit = "HitRock", pitch = 0.7, breakBank = "BreakRock", extra = "Sear", volume = 0.75 },
		Ruins = { hit = "HitStone", pitch = 0.95, breakBank = "BreakStone", volume = 0.65 },
	} :: {
		[string]: { hit: string, pitch: number, breakBank: string, extra: string?, volume: number },
	},

	-- looping beds (studs/volume handled by the client)
	Loops = {
		Vacuum = "rbxassetid://9126149814", -- Vacuum Suction Small Objects Sucked Up Tube
		Tunnel = "rbxassetid://9119643864", -- Storm Drain Presence (hollow underground air)
		Drips = "rbxassetid://9120607899", -- Water Trickle Constant Dripping In Tunnel
		Lava = "rbxassetid://9112823197", -- Lava Rumble
		Crystal = "rbxassetid://9125718987", -- Ominous Crystal Presence Ringing Tones Glass
		Hum = "rbxassetid://9125446267", -- Command Room Tone Deep Air Conditioning Hum
	} :: { [string]: string },

	-- per zone (by Zones[i].id): which material set and which ambience loop under it
	Zone = {
		Plaster = { material = "Plaster", ambience = "Tunnel" },
		Brick = { material = "Brick", ambience = "Tunnel" },
		Concrete = { material = "Concrete", ambience = "Hum" },
		Reinforced = { material = "Reinforced", ambience = "Hum" },
		Clay = { material = "Clay", ambience = "Drips" },
		Sewer = { material = "Sewer", ambience = "Drips" },
		Bedrock = { material = "Bedrock", ambience = "Tunnel" },
		Crystal = { material = "Crystal", ambience = "Crystal" },
		Magma = { material = "Magma", ambience = "Lava" },
		Ruins = { material = "Ruins", ambience = "Tunnel" },
	} :: { [string]: { material: string, ambience: string } },

	-- consecutive breaks within this many seconds climb in pitch (rhythm reward), capped
	StreakWindow = 1.2,
	StreakStep = 0.025,
	StreakMax = 0.15,
	-- every hit on the same block sounds a little higher (you hear it about to give)
	CrackPitchStep = 0.06,
	AmbienceVolume = 0.32,
	MusicDuckInTunnel = 0.55,
	VacuumVolume = 0.35,
}

return Audio
