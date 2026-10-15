--!strict
-- Patrolling guards: where they walk and the things they say. They are comic relief: they always
-- have a reason not to see what's going on. Positions are computed from the server clock
-- (Shared/Patrol), so every client moves them smoothly with no network traffic; the server only
-- picks the lines (it knows who is nearby and what they're doing).
--
-- Routes are loops of { x, z } floor points (the corridor runs along X at z = 0, the Common Room is
-- around x = -182, the Yard around x = -330: see Config/World). {name} = the nearest prisoner.

local Patrol = {
	Speed = 5.5, -- studs per second
	Pause = 2.2, -- seconds standing at each corner, looking around
	SayEvery = { 9, 15 }, -- seconds between lines (random in this range)
	BubbleSeconds = 5,
	HearRange = 26, -- studs: who the guard "notices" (and still doesn't see)

	Routes = {
		Corridor = { { -108, 0 }, { 108, 0 } },
		CorridorNorth = { { 108, -5 }, { -108, -5 } },
		CorridorSouth = { { -100, 5 }, { 100, 5 } },
		CommonRoom = { { -152, -16 }, { -212, -16 }, { -212, 16 }, { -152, 16 } },
		Yard = { { -282, -22 }, { -392, -22 }, { -392, 30 }, { -282, 30 } },
	} :: { [string]: { { number } } },

	-- one entry per guard: their name, cap color, and route per schedule phase
	Guards = {
		{
			name = "Officer Dave",
			routes = { RollCall = "Corridor", Day = "Yard", LightsOut = "Corridor", Night = "CorridorNorth" },
		},
		{
			name = "Officer Brenda",
			routes = {
				RollCall = "CommonRoom",
				Day = "CommonRoom",
				LightsOut = "CommonRoom",
				Night = "CorridorSouth",
			},
		},
		{
			name = "Sgt. Lumpy",
			routes = { RollCall = "Corridor", Day = "Corridor", LightsOut = "Corridor", Night = "Corridor" },
		},
	},

	-- what they say, by situation (most specific first; see Services/Patrol)
	Lines = {
		Stolen = {
			"{name}, running with somebody else's stuff? Great cardio.",
			"Is that yours, {name}? ...Eh, finders keepers. Not my shift.",
			"Running in the halls! ...Ugh, too much paperwork. Carry on.",
		},
		Fight = {
			"Fighting? No no. That's a very aggressive hug.",
			"I'm on my break. I've been on my break since 2009.",
			"Ooh, good one! I mean... stop that. Please. Whenever.",
			"If I don't look, it didn't happen. Prison rule number one.",
		},
		Digging = {
			"Hear that tapping? Probably the pipes. Definitely the pipes.",
			"Somebody's remodeling. Nice. This place needs it.",
			"Sounds like a jackhammer. Must be my stomach. Is it lunch yet?",
			"{name}, do you hear digging? No? Me neither. Good talk.",
		},
		Bag = {
			"That's a lot of laundry, {name}.",
			"Gravel in your pockets, {name}? Must be a new diet.",
			"Sand everywhere. Must have blown in from the beach. We don't have a beach.",
			"{name}, your pants are full of rocks. Totally normal. Moving on.",
		},
		Lifting = {
			"Nice form, {name}! Wait, is that the vending machine?",
			"Lift with your legs! And put that toilet back when you're done.",
		},
		Near = {
			"Evening, {name}. Nothing suspicious about you. At all.",
			"{name}, you look shorter. Have you been... tunneling? Ha! Kidding.",
			"Nice jumpsuit, {name}. Very orange.",
			"Move along, {name}. I'm guarding. Very hard. With my eyes closed.",
		},
		RollCall = {
			"Roll call! Say 'here' if you haven't tunneled out!",
			"Cell three... present. Cell four... close enough.",
			"Twelve cells, twelve prisoners. Math checks out. Probably.",
			"Everybody here? Great. I'm not counting twice.",
		},
		Day = {
			"Twenty years on the job. Never seen an escape. Never looked, either.",
			"If anyone needs me, I'll be over here ignoring things.",
			"The warden says 'stay alert'. I say 'stay a little alert'.",
			"Is it lunch yet? It feels like lunch.",
			"These walls are solid. I checked one. Once.",
			"I could stop the digging... or I could finish my crossword.",
		},
		LightsOut = {
			"Lights out! Back to your cells! Pretty please!",
			"Ten seconds! Nine! ...What comes after nine?",
		},
		Night = {
			"Lights out means I can't see anything. Very convenient.",
			"My flashlight is low on batteries. All night. Every night.",
			"Shh. If I'm quiet I can hear... nothing. Nothing at all.",
			"Night shift. I'm awake. Mostly. Zzz... I'm awake!",
		},
	} :: { [string]: { string } },
}

return Patrol
