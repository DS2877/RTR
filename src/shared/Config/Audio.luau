--!strict
-- The sound design. Every id is Roblox-licensed Creator Store audio from the ProSoundEffects
-- library (or APM via Roblox), usable in any experience; the smoke test re-checks every one with
-- MarketplaceService:GetProductInfo.
--
-- Picked by measurement (tools: decode + analyse each candidate): instant attack (the hit lands on
-- the first frame, or `start` skips the silence before it), short tails for hits, nothing shrill,
-- no clipping. `gain` normalises each clip to the same loudness (loudest 50 ms ~ -12 dBFS at
-- volume 1, never above 0 dBFS peak), so a call site's volume means the same thing for every
-- variation. Sound.play multiplies its volume by the gain.
--
-- Banks = variations of one sound (Sound.play picks one at random, never the same twice in a row).
-- Materials = how each zone's blocks sound: `hit` while cracking, `break` when it gives, `extra`
-- an optional layer on breaks (rebar clank, wet splat, lava gloop, crystal ping). `pitch` shifts
-- the whole set a little.

export type Clip = { gain: number, start: number }

-- per asset id: loudness gain + seconds of silence to skip
local Clips: { [string]: Clip } = {}
local function clip(id: number, gain: number, start: number?): string
	local key = "rbxassetid://" .. id
	Clips[key] = { gain = gain, start = start or 0 }
	return key
end

local Audio = {
	Clips = Clips,

	Banks = {
		-- the fist landing: a soft body layer under every punch (and the gym)
		Fist = {
			clip(9113570289, 1.17), -- Boxing Hits 14 (0.48 s)
			clip(9113568548, 1.2), -- Boxing Hits 13
			clip(9113573524, 1.14), -- Boxing Hits 5
			clip(9113573987, 1.09), -- Boxing Hits 12
		},

		-- material hits (block takes damage): tight, < 0.3 s tails
		HitConcrete = {
			clip(9118625022, 1.21), -- Rock Impacts 11
			clip(9118607821, 1.35), -- Rock Hits Rock On Rock Various Versions 5
			clip(9119603829, 1.47), -- Statue Hits 19
			clip(9118626298, 1.24), -- Rock Impacts 7
		},
		HitRock = {
			clip(9118597462, 0.83), -- Rock Hit Dirt Impact 7
			clip(9118598240, 0.59), -- Rock Hit Dirt Impact 12
			clip(9118598279, 0.68), -- Rock Hit Dirt Impact 14
			clip(9118598729, 0.68), -- Rock Hit Dirt Impact 20
		},
		HitDirt = {
			clip(9114103786, 0.98, 0.015), -- Dirt Impacts 17
			clip(9118616114, 1.03, 0.035), -- Rock Impact Dirt Hard Muted Thuds 1
			clip(9118684997, 2.64, 0.038), -- Rocks Dirt Impacts In Ground 7
			clip(9114109300, 0.96, 0.028), -- Dirt Impacts 1
		},
		HitMetal = {
			clip(9116751108, 0.75), -- Metal Plate Impact Manhole Hit 2
			clip(9116541944, 1.04, 0.019), -- Metal Clanks 2
			clip(9116647303, 1.04), -- Metal Hit Concrete 9
		},
		HitGlass = { -- crystal: ice chunks are glassy without being shrill
			clip(9114865174, 1.35), -- Ice Hammer Hitting Large Chunks 4
			clip(9114864974, 1.09), -- Ice Hammer Hitting Large Chunks 3
			clip(9114864953, 1.3), -- Ice Hammer Hitting Large Chunks 1
		},
		HitStone = {
			clip(9119603528, 1.73), -- Statue Hits 14
			clip(9119603662, 1.58), -- Statue Hits 15
			clip(9119603829, 1.47), -- Statue Hits 19
			clip(9119596406, 0.82), -- Statue Chisel 1
		},

		-- material breaks
		BreakPlaster = {
			clip(9114199593, 1.0), -- Drywall Crunch 2
			clip(9114199583, 0.63, 0.025), -- Drywall Crunch 1
			clip(9114199750, 0.7, 0.032), -- Drywall Crunch 4
		},
		BreakConcrete = {
			clip(9118587493, 1.53, 0.023), -- Rock Drop On Concrete Drops Breaks 1
			clip(9118587996, 1.65, 0.034), -- Rock Drop On Concrete Drops Breaks 7
			clip(9118587494, 1.47, 0.216), -- Rock Drop On Concrete Drops Breaks 2
			clip(9118588165, 1.56, 0.074), -- Rock Drop On Concrete Drops Breaks 10
		},
		BreakRock = {
			clip(9119050772, 0.71, 0.098), -- Shale Break Low End Crackling Rock 6
			clip(9119050031, 0.71, 0.066), -- Shale Break Low End Crackling Rock 5
			clip(9119050441, 0.7, 0.098), -- Shale Break Low End Crackling Rock 2
			clip(9125869504, 2.98), -- Rock Cracks Rock Hitting Rock Impact Debris
			clip(9125869107, 3.05), -- Rock Cracks Rock Hitting Rock Impact Debris
		},
		BreakDirt = {
			clip(9113805426, 0.65, 0.306), -- Cinder Block Impact Falling To Dirt 3
			clip(9113805428, 0.58, 0.312), -- Cinder Block Impact Falling To Dirt 1
			clip(9113806542, 0.79, 0.151), -- Cinder Block Impact Falling To Dirt 10
			clip(9114109300, 0.96, 0.028), -- Dirt Impacts 1
		},
		BreakGlass = {
			clip(9114857307, 1.57, 0.21), -- Ice Chunk Drop Onto Concrete Some Break 1
			clip(9114857819, 1.14, 0.459), -- Ice Chunk Drop Onto Concrete Some Break 2
			clip(9114857473, 0.91, 0.393), -- Ice Chunk Drop Onto Concrete Some Break 3
		},
		BreakStone = {
			clip(9118584349, 0.72), -- Rock Cracks Big Boulder Hits 1
			clip(9118607563, 0.91), -- Rock Hits Rock On Rock Various Versions 1
			clip(9118608946, 1.35), -- Rock Hits Rock On Rock Various Versions 9
		},

		-- layers on top of a break (used sparingly)
		Debris = {
			clip(9118586709, 3.17, 0.376), -- Rock Debris 3
			clip(9118586608, 1.38, 0.239), -- Rock Debris 1
			clip(9118586609, 1.02, 0.216), -- Rock Debris 2
		},
		BigBreak = {
			clip(9119186658, 0.97, 0.506), -- Slab Drop Debris 4
			clip(9119186450, 0.99, 0.449), -- Slab Drop Debris 3
			clip(9114221862, 1.46, 0.092), -- Earthquake Debris Rock Bursts Scattering 1
		},
		Rebar = {
			clip(9125672726, 1.09), -- Metal Impact Sledge Hammer Hits On 5 Ft I-Beam
			clip(9125672562, 1.03), -- Metal Impact Sledge Hammer Hits On 5 Ft I-Beam
		},
		Splat = {
			clip(9117283360, 1.42, 0.022), -- Penguins Flop Watery Splatting Impacts 5
			clip(9117283175, 1.5, 0.061), -- Penguins Flop Watery Splatting Impacts 4
			clip(9117283124, 1.43, 0.064), -- Penguins Flop Watery Splatting Impacts 2
		},
		Gloop = { -- lava: a thick bubble instead of a hiss
			clip(9120313118, 1.4, 0.027), -- Underwater Bubbles Very Short Burst Heavy 1
			clip(9113537815, 1.04, 0.022), -- Boink Wet Suction Pop Blip Hollow 3
		},
		Chime = { -- one tuned note, so pitch climbs (combos, counters) sound like a scale
			clip(9117042092, 1.78, 0.174), -- Music Box Swan Lake Single Notes 3
		},

		-- cubes hitting the floor, the vacuum swallowing them, footsteps
		Land = {
			clip(9118688358, 7.48), -- Rocks Dirt Impacts In Ground 48
			clip(9118684997, 2.64, 0.038), -- Rocks Dirt Impacts In Ground 7
			clip(9118687440, 7.0), -- Rocks Dirt Impacts In Ground 40
			clip(9119603662, 1.58), -- Statue Hits 15
		},
		Suck = {
			clip(9119669065, 2.28), -- Suction Pop 4
			clip(9119668978, 1.27), -- Suction Pop 3
			clip(9119668788, 0.91, 0.011), -- Suction Pop 1
		},
		Step = {
			clip(9114523161, 2.67), -- Foot Stomp 1
			clip(9114523358, 3.24), -- Foot Stomp 4
			clip(9114523629, 3.97), -- Foot Stomp 7
		},

		-- prison
		CellDoor = {
			clip(9114884923, 1.04, 0.259), -- Jail Cell Door 1
			clip(9114885622, 1.65, 0.632), -- Jail Cell Door 13
			clip(9116603883, 0.82, 0.143), -- Metal Door 1
		},
		Boom = {
			clip(9116973611, 0.87), -- Mortar Explosion 3 (short, deep)
			clip(9114224721, 0.52), -- Earthquake Explosion 1
		},
	} :: { [string]: { string } },

	-- the same for the single sounds in Config/Assets.Sounds (by name)
	Single = {
		Click = { gain = 2.69, start = 0 }, -- Wood Impacts Soft Impacts On Temple Blocks 2
		Open = { gain = 5.67, start = 0 }, -- Bubble Bloop High Pitched Cute 1
		Punch = { gain = 0.85, start = 0.017 }, -- Boxing Hits 6
		Crumble = { gain = 3.17, start = 0.376 }, -- Rock Debris 3
		Find = { gain = 2.98, start = 0 }, -- Computer Melody Melodic Blitz Electronic Game
		Dump = { gain = 0.85, start = 0 }, -- Cash Register 2
		Coin = { gain = 1.29, start = 0 }, -- Cash Register 1
		Upgrade = { gain = 1.47, start = 0.013 }, -- Magic Transformation 10
		Purchase = { gain = 1.12, start = 0 }, -- Cash Register 5
		Vacuum = { gain = 3.1, start = 0.034 }, -- Whooshes Fast Wipes Quick Airy Slices 3
		Full = { gain = 2.39, start = 0 }, -- Fat Beeps Deep Bubble Like Bursts 1
		Alarm = { gain = 2.62, start = 0 }, -- Siren Blat 4
		Siren = { gain = 1.69, start = 0.133 }, -- Submarine Alarm Klaxon 6
		Zone = { gain = 0.56, start = 0.228 }, -- Victory Fanfare Sting (APM)
		Announce = { gain = 0.64, start = 0.088 }, -- Bouncy Bouncy Sting 1 (APM)
		Rare = { gain = 0.96, start = 0.136 }, -- Magical (c) (APM)
	} :: { [string]: Clip },

	Materials = {
		Plaster = { hit = "HitConcrete", pitch = 1.1, breakBank = "BreakPlaster", volume = 0.55 },
		Brick = { hit = "HitConcrete", pitch = 1.0, breakBank = "BreakRock", volume = 0.6 },
		Concrete = { hit = "HitConcrete", pitch = 0.92, breakBank = "BreakConcrete", volume = 0.6 },
		Reinforced = {
			hit = "HitMetal",
			pitch = 0.95,
			breakBank = "BreakConcrete",
			extra = "Rebar",
			volume = 0.5,
		},
		Clay = { hit = "HitDirt", pitch = 1.0, breakBank = "BreakDirt", volume = 0.6 },
		Sewer = { hit = "HitDirt", pitch = 0.92, breakBank = "BreakDirt", extra = "Splat", volume = 0.6 },
		Bedrock = { hit = "HitRock", pitch = 0.85, breakBank = "BreakRock", volume = 0.65 },
		Crystal = { hit = "HitGlass", pitch = 1.08, breakBank = "BreakGlass", extra = "Chime", volume = 0.5 },
		Magma = { hit = "HitRock", pitch = 0.8, breakBank = "BreakRock", extra = "Gloop", volume = 0.65 },
		Ruins = { hit = "HitStone", pitch = 0.95, breakBank = "BreakStone", volume = 0.6 },
	} :: {
		[string]: { hit: string, pitch: number, breakBank: string, extra: string?, volume: number },
	},

	-- looping beds (studs/volume handled by the client)
	Loops = {
		Vacuum = "rbxassetid://9120360676", -- Vacuum Cleaner 1 (steady motor)
		Tunnel = "rbxassetid://9119643864", -- Storm Drain Presence 1 (hollow underground air)
		Drips = "rbxassetid://9120607899", -- Water Trickle Constant Dripping In Tunnel 1
		Lava = "rbxassetid://9112823197", -- Lava Rumble 1
		Crystal = "rbxassetid://9125718987", -- Ominous Crystal Presence Ringing Tones Glass
		Hum = "rbxassetid://9125446564", -- Command Room Tone Deep Air Conditioning Hum
	} :: { [string]: string },
	-- per loop: loudness gain (integrated ~ -20 LUFS at volume 1) and the steady part to loop
	-- (skips a recording's start-up / fade-out so the bed never dips)
	LoopTune = {
		Vacuum = { gain = 0.82, from = 0.25, to = 14.5 },
		Tunnel = { gain = 10 },
		Drips = { gain = 1.04, to = 26.5 },
		Lava = { gain = 1.06 },
		Crystal = { gain = 0.95 },
		Hum = { gain = 0.84 },
		Siren = { gain = 1.69 }, -- Assets.Sounds.Siren as a loop (Breakout)
	} :: { [string]: { gain: number, from: number?, to: number? } },

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

	-- the shortest gap (seconds) between two plays of a sound; rapid-fire sounds stay readable
	MinGap = {
		Land = 0.25, -- at most ~4 cube taps a second
		Suck = 0.08,
		Debris = 0.35,
		Full = 0.6,
		Alarm = 0.3,
		Coin = 0.07,
		Step = 0.15,
	} :: { [string]: number },
	DefaultGap = 0.035,
	-- random pitch spread for one-shots (± fraction)
	Spread = 0.04,

	-- consecutive breaks within this many seconds climb in pitch (rhythm reward), capped
	StreakWindow = 1.2,
	StreakStep = 0.015,
	StreakMax = 0.08,
	-- every hit on the same block sounds a little higher (you hear it about to give), capped
	CrackPitchStep = 0.03,
	CrackPitchMax = 0.1,
	-- the soft fist layer under a material hit (0 = off)
	FistUnderHit = 0.18,
	-- one debris trickle at most every this many breaks (big multi-breaks always get one)
	DebrisEvery = 3,
	AmbienceVolume = 0.32,
	MusicDuckInTunnel = 0.55,
	VacuumVolume = 0.35,
}

return Audio
