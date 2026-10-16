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

	-- one entry per guard: their name, route per schedule phase and their own quirks (said now and
	-- then instead of a generic idle line)
	Guards = {
		{
			name = "Officer Dave",
			routes = { RollCall = "Corridor", Day = "Yard", LightsOut = "Corridor", Night = "CorridorNorth" },
			quirks = {
				"I brought a sandwich from home. Then I ate it. At home.",
				"My doctor says I need more exercise. I walk this loop. Twice.",
				"Today's lunch is mystery meat. The mystery is: why.",
				"I'm not sleeping on the job. I'm resting my eyes. Professionally.",
				"Fun fact: the yard is exactly 4 donuts long. I measured.",
				"If you need me, I'm on a very important snack break.",
				"Lunch was eleven minutes ago. Is it dinner yet?",
				"I'd chase you, but I just sat down. In my head.",
			},
		},
		{
			name = "Officer Brenda",
			routes = {
				RollCall = "CommonRoom",
				Day = "CommonRoom",
				LightsOut = "CommonRoom",
				Night = "CorridorSouth",
			},
			quirks = {
				"Did you hear? Cell 7 has a pet rat. His name is Kevin. Kevin's nice.",
				"I'm knitting the warden a scarf. It's 40 feet long. Don't ask.",
				"My podcast says most escapes happen at night. Good thing I listen at night.",
				"I see everything. Except this whole room. And the yard. And you.",
				"No gossip on my shift. Anyway, did you hear about the warden's toupee?",
				"My horoscope said 'look the other way today'. Who am I to argue?",
				"Somebody stole my yogurt again. That's the real crime here.",
				"I'm writing a novel. It's about a guard who notices nothing. Very personal.",
			},
		},
		{
			name = "Sgt. Lumpy",
			routes = { RollCall = "Corridor", Day = "Corridor", LightsOut = "Corridor", Night = "Corridor" },
			quirks = {
				"Thirty years in the service. Can't see a thing past my nose. Still proud.",
				"Back in my day, we dug tunnels uphill. Both ways.",
				"Attention! ...Oh, that's a mop. At ease, mop.",
				"I lost my glasses in 1998. Haven't missed anything since.",
				"Discipline! Order! ...What was I saying? Ah, lunch.",
				"Nobody escapes on Sgt. Lumpy's watch. My watch stopped in 2003.",
				"Stand up straight, soldier! ...You're a wall. My mistake.",
				"I run a tight ship. The ship has holes. Many holes. Tunnel-shaped.",
			},
		},
	},
	QuirkChance = 0.35, -- share of idle lines that are the guard's own quirks

	-- what they say, by situation (most specific first; see Services/Patrol)
	Lines = {
		Stolen = {
			"{name}, running with somebody else's stuff? Great cardio.",
			"Is that yours, {name}? ...Eh, finders keepers. Not my shift.",
			"Running in the halls! ...Ugh, too much paperwork. Carry on.",
			"Stop, thief! ...I say that to everyone. It's a greeting.",
			"{name}, that box looks heavy. Want a hand? No? Okay, bye.",
			"Stolen goods? In MY prison? I'd better write that down. Got a pen?",
			"I'll pretend that's a birthday present, {name}. Happy birthday.",
			"Somebody's gonna be mad about that. Not me though. I'm chill.",
		},
		Fight = {
			"Fighting? No no. That's a very aggressive hug.",
			"I'm on my break. I've been on my break since 2009.",
			"Ooh, good one! I mean... stop that. Please. Whenever.",
			"If I don't look, it didn't happen. Prison rule number one.",
			"Is this a fight or a dance-off? Either way, great energy.",
			"Hey! No punching! ...Unless it's a really good punch.",
			"I'd break it up, but my union says I need a second guard.",
			"Ten bucks on the short one. I mean - break it up!",
			"Easy, {name}! You'll spill my coffee. Then we'd have a real problem.",
		},
		Digging = {
			"Hear that tapping? Probably the pipes. Definitely the pipes.",
			"Somebody's remodeling. Nice. This place needs it.",
			"Sounds like a jackhammer. Must be my stomach. Is it lunch yet?",
			"{name}, do you hear digging? No? Me neither. Good talk.",
			"That rumbling? Earthquake. A tiny, prisoner-shaped earthquake.",
			"Whoever's knocking: we're closed. Come back during visiting hours.",
			"Woodpeckers. In the basement. It happens. Probably.",
			"The walls are making noises again. Old building. Very old. Very hollow.",
			"If that's a tunnel, it's a very polite one. Hasn't bothered me once.",
			"Termites. Really strong ones. With fists.",
		},
		Bag = {
			"That's a lot of laundry, {name}.",
			"Gravel in your pockets, {name}? Must be a new diet.",
			"Sand everywhere. Must have blown in from the beach. We don't have a beach.",
			"{name}, your pants are full of rocks. Totally normal. Moving on.",
			"Is that a backpack or a small mountain, {name}?",
			"Collecting rocks? Cute hobby. My nephew does that. He's five.",
			"You're walking funny, {name}. Rock-heavy funny. None of my business.",
			"Dust trail leading to your cell, {name}? Must be the wind. Indoors.",
		},
		Lifting = {
			"Nice form, {name}! Wait, is that the vending machine?",
			"Lift with your legs! And put that toilet back when you're done.",
			"Do NOT drop that on my foot, {name}. My foot has been through enough.",
			"Look at those guns! I mean arms. No guns. There are no guns here.",
			"{name}'s getting strong. Strong enough to punch a wall? Ha. Nah.",
			"Is that my desk?! ...Fine. Do ten reps, then bring it back.",
			"Pump it, {name}! Not that I'm cheering. Officially.",
		},
		Near = {
			"Evening, {name}. Nothing suspicious about you. At all.",
			"{name}, you look shorter. Have you been... tunneling? Ha! Kidding.",
			"Nice jumpsuit, {name}. Very orange.",
			"Move along, {name}. I'm guarding. Very hard. With my eyes closed.",
			"{name}! Love the dust in your hair. Very... rustic.",
			"Hey {name}, why are your hands so dirty? Gardening? Sure. Gardening.",
			"{name}, if you escape, send me a postcard. Kidding! ...Unless?",
			"Behave, {name}. Or don't. I'm not your mom.",
			"{name}, stop looking at the floor like that. It's just a floor.",
			"How's it going, {name}? Don't answer. Plausible deniability.",
		},
		RollCall = {
			"Roll call! Say 'here' if you haven't tunneled out!",
			"Cell three... present. Cell four... close enough.",
			"Twelve cells, twelve prisoners. Math checks out. Probably.",
			"Everybody here? Great. I'm not counting twice.",
			"Roll call! If you're not here, please say so.",
			"One, two, three... many. That's a full house.",
			"Stand by your door! Unless your door has a hole in the back.",
			"Who's that lump under the blanket? ...Yep, looks like a person.",
		},
		Day = {
			"Twenty years on the job. Never seen an escape. Never looked, either.",
			"If anyone needs me, I'll be over here ignoring things.",
			"The warden says 'stay alert'. I say 'stay a little alert'.",
			"Is it lunch yet? It feels like lunch.",
			"These walls are solid. I checked one. Once.",
			"I could stop the digging... or I could finish my crossword.",
			"Seven letters, 'escape route'. T-U-N-N-E-L... that's six. Hm.",
			"Beautiful day for staying inside a prison. Like you do.",
			"Security cameras? Oh, those are decorations.",
			"Warden's coming! ...No he isn't. Just practicing my scared face.",
			"I asked for a raise. They gave me a smaller hat.",
			"Remember, kids: crime doesn't pay. Noodles do, apparently.",
		},
		LightsOut = {
			"Lights out! Back to your cells! Pretty please!",
			"Ten seconds! Nine! ...What comes after nine?",
			"Bedtime! Brush your teeth! Stop digging! In that order!",
			"Everybody in! Last one to their cell does my paperwork!",
			"Lights out in a minute! Hide your shovels! I mean - what shovels?",
		},
		Night = {
			"Lights out means I can't see anything. Very convenient.",
			"My flashlight is low on batteries. All night. Every night.",
			"Shh. If I'm quiet I can hear... nothing. Nothing at all.",
			"Night shift. I'm awake. Mostly. Zzz... I'm awake!",
			"Was that a shadow? Just a big shadow. Carrying rocks.",
			"Nobody's out here, right? Great. I'm scared of the dark.",
			"Counting sheep on duty. Sheep number 412... looks like a prisoner.",
			"It's so quiet. Too quiet. Ooh, a vending machine.",
			"Who goes there?! ...Me? Oh. Carry on, me.",
		},
		TopDog = {
			"Is that a gold chain, {name}? Contraband. ...It's very shiny though.",
			"Top Dog {name}! Can I get an autograph? For my kid. Not for me.",
			"{name} runs this place now? Cool, can I get Fridays off?",
			"All hail {name}, I guess. Please don't fight me.",
		},
	} :: { [string]: { string } },
}

return Patrol
