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

	-- background playlist (loops) and the track that takes over while you carry a stolen find
	Music = {
		Playlist = {
			"rbxassetid://1837463238", -- Heist Time (APM)
			"rbxassetid://9045731376", -- Smooth Operator (APM)
			"rbxassetid://9045939292", -- Code Heist (APM)
			"rbxassetid://9038367768", -- Funky Disco Beats (APM)
		},
		Chase = "rbxassetid://9047963157", -- Spy Action (APM)
		Volume = 0.25,
		ChaseVolume = 0.4,
	},

	Images = {} :: { [string]: string },

	-- Roblox's own avatar animations (from the default Animate script, usable in every experience):
	-- the punch plays the tool lunge (a straight forward thrust) and every 3rd hit the slash.
	-- The smoke test checks these are Animation assets.
	Animations = {
		PunchR15 = { "rbxassetid://522638767", "rbxassetid://522635514" }, -- toollunge, toolslash
		PunchR6 = { "rbxassetid://129967478", "rbxassetid://129967390" }, -- toollunge, toolslash
		PunchSpeed = 1.7,
	},
}

return Assets
