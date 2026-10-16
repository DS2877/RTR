--!strict
-- Asset IDs. Empty string = not uploaded; the game stays silent / uses primitives instead.
-- Every sound here is Roblox-licensed Creator Store audio (APMOfficial / ProSoundEffects), usable in
-- any experience. The smoke test re-checks every id with MarketplaceService:GetProductInfo.

local Assets = {
	Sounds = {
		Click = "rbxassetid://9119717529", -- Switch Click On Or Off Toggle Button 1
		Open = "rbxassetid://9112872058", -- Small Bubbles Pop 3
		Punch = "rbxassetid://9113510797", -- Body Hit Slap 3 (played low and fast = a thud)
		Crumble = "rbxassetid://9125444889", -- Coins Drop Metal Hits (played low = rubble)
		Find = "rbxassetid://9114369623", -- Fairy Dust 1
		Dump = "rbxassetid://9113728049", -- Cash Register 2
		Coin = "rbxassetid://9113849651", -- Coin Throws 3
		Upgrade = "rbxassetid://9116422213", -- Magic Transformation 17
		Purchase = "rbxassetid://9117244567", -- Pay Phone Dropping Dimes
		Vacuum = "rbxassetid://9126229255", -- Whoosh By Fast Airy
		Full = "rbxassetid://9113087543", -- Alarm Buzzer 2
		Siren = "rbxassetid://9113087543", -- Alarm Buzzer 2 (LIGHTS OUT)
		Zone = "rbxassetid://1836473422", -- Victory Fanfare Sting (APM)
		Announce = "rbxassetid://1841390412", -- Bouncy Bouncy Sting 1 (APM)
		Rare = "rbxassetid://1841173427", -- Magical (c) (APM)
	} :: { [string]: string },

	-- background playlist (loops, shuffled) and the track that takes over while you carry a stolen
	-- find. Prison-yard radio: real-played 90s boom bap / G-funk / West Coast from the licensed APM
	-- library (free in every experience). title/artist show in the "now playing" chip.
	Music = {
		Playlist = {
			{ id = "rbxassetid://1842771788", title = "G Funkin", artist = "Geoffrey Wilkinson" },
			{ id = "rbxassetid://9040327518", title = "West Coast Lo Rider", artist = "Red Line" },
			{ id = "rbxassetid://1844096934", title = "Ghetto Life", artist = "Score Production Music" },
			{ id = "rbxassetid://1842771655", title = "Brooklyn Strut", artist = "Geoffrey Wilkinson" },
			{ id = "rbxassetid://9042398678", title = "Don't Come Round Here", artist = "Charlie Cosmic" },
			{ id = "rbxassetid://1837359223", title = "Hooded Head", artist = "Gum Motion Tracks" },
			{ id = "rbxassetid://9040327320", title = "Palm Trees in LA", artist = "Red Line" },
			{ id = "rbxassetid://1842771765", title = "Covert Operation", artist = "Geoffrey Wilkinson" },
			{
				id = "rbxassetid://9038773540",
				title = "Cruising through the Neighborhood",
				artist = "Charlie Cosmic",
			},
			{ id = "rbxassetid://1839361813", title = "Deviant Behavior", artist = "Sylvain Raymond Lux" },
			{ id = "rbxassetid://9040328482", title = "Walk on the West", artist = "Red Line" },
			{ id = "rbxassetid://1842771974", title = "Just Chillin", artist = "Geoffrey Wilkinson" },
			{
				id = "rbxassetid://9038774201",
				title = "Always Twisted in the Streets",
				artist = "Charlie Cosmic",
			},
			{ id = "rbxassetid://9040330242", title = "Big Grizzly Walking", artist = "Red Line" },
		} :: { { id: string, title: string, artist: string } },
		Chase = "rbxassetid://1846934387", -- Gangsta Brutality A (APM)
		Volume = 0.25,
		ChaseVolume = 0.35,
	},

	Images = {} :: { [string]: string },

	-- Roblox's own avatar animations (from the default Animate script, usable in every experience):
	-- the punch plays the tool lunge (a straight forward thrust) and every 3rd hit the slash.
	-- The smoke test checks these are Animation assets.
	Animations = {
		PunchR15 = { "rbxassetid://522638767", "rbxassetid://522635514" }, -- toollunge, toolslash
		PunchR6 = { "rbxassetid://129967478", "rbxassetid://129967390" }, -- toollunge, toolslash
		PunchSpeed = 1.7,
		LiftR15 = "rbxassetid://507770677", -- cheer: both arms up (held still = hoisting the prop)
		LiftR6 = "rbxassetid://129423030",
		IdleR15 = "rbxassetid://507766388", -- NPCs standing around
		WalkR15 = "rbxassetid://507777826", -- patrolling guards
	},

	-- NPC outfits (Util/Characters builds real R15 avatars from these catalog items). Shirt / Pants =
	-- classic clothing; the others are accessories ("id,id" lists allowed).
	Outfits = {
		guard = {
			Shirt = 6180109308, -- blue police shirt with badge
			Pants = 2430769797, -- dark uniform pants with a belt
			Hat = "6377328912", -- vintage police cap
			Waist = "4376960922", -- utility belt
			Faces = { 31117267, 7074786 }, -- Skeptic, Check It: guards don't smile
		},
		chef = {
			Shirt = 6780936233, -- white chef jacket
			Pants = 398633812, -- black jeans (Roblox)
			Hat = "96678446", -- The Star Chef (Roblox)
		},
		inmate = {
			Shirt = 562522990, -- orange "Prison" shirt
			Pants = 7562301741, -- orange INMATE pants
			Hair = { "1772336109", "221175236", "236398436", "319642066" }, -- Roblox hair (one per NPC)
		},
		visitor = {
			Shirt = 12142438478, -- dark suit
			Pants = 398633812,
			Hair = { "1772336109" },
		},
		glasses = "62690529", -- thick rimmed glasses (Roblox): The Fence + the Black Market dealer
	} :: { [string]: any },
	-- NPC bodies: Roblox's free "Man" bundle (a real body shape instead of the blocky default)
	Body = {
		Head = 86498048,
		Torso = 86500008,
		RightArm = 86500036,
		LeftArm = 86500054,
		LeftLeg = 86500064,
		RightLeg = 86500078,
	},
	-- free Roblox faces (Smile, Chill, Check It, Skeptic, Freckles, Hmmm...)
	Faces = { 144075659, 7074764, 7074786, 31117267, 12145366, 7076076 },
	-- warm, natural skin tones (the bright fluorescent prison light washes pale tones out to white)
	Skin = {
		{ 204, 142, 105 },
		{ 168, 112, 80 },
		{ 222, 166, 126 },
		{ 124, 82, 58 },
		{ 186, 128, 92 },
		{ 92, 60, 44 },
	},
}

return Assets
