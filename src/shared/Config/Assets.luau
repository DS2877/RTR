--!strict
-- Asset IDs. Empty string = not uploaded; the game stays silent / uses primitives instead.
-- Every sound here is Roblox-licensed Creator Store audio (uploaded by APMOfficial = music, or
-- ProSoundEffects = SFX), usable in any experience. Names/lengths were looked up in the Creator
-- Store; the smoke test re-checks every id with MarketplaceService:GetProductInfo on each build.

local Assets = {
	Sounds = {
		Click = "rbxassetid://9112872070", -- Small Bubbles Pop 4
		Open = "rbxassetid://9112872058", -- Small Bubbles Pop 3
		Grab = "rbxassetid://9114369623", -- Fairy Dust 1
		Deposit = "rbxassetid://9125444889", -- Coins Drop Metal Hits
		Collect = "rbxassetid://9113728049", -- Cash Register 2
		Coin = "rbxassetid://9113849651", -- Coin Throws 3
		Upgrade = "rbxassetid://9116422213", -- Magic Transformation 17
		Purchase = "rbxassetid://9117244567", -- Pay Phone Dropping Dimes
		Caught = "rbxassetid://9117947034", -- Puddle Stomps Splash 9
		Slap = "rbxassetid://9113510797", -- Body Hit Slap 3
		Whoosh = "rbxassetid://9126229255", -- Whoosh By Fast Airy
		Alarm = "rbxassetid://9113087543", -- Alarm Buzzer 2
		Crown = "rbxassetid://1836473422", -- Victory Fanfare Sting (APM)
		Bounty = "rbxassetid://1844584698", -- Winner (APM)
		Announce = "rbxassetid://1841390412", -- Bouncy Bouncy Sting 1 (APM)
		Event = "rbxassetid://1845411858", -- Top Prize (APM)
		Rare = "rbxassetid://1841173427", -- Magical (c) (APM)
	} :: { [string]: string },

	-- Background playlist (loops through), and the track that takes over while you carry loot.
	Music = {
		Playlist = {
			"rbxassetid://1837463238", -- Heist Time
			"rbxassetid://9045731376", -- Smooth Operator
			"rbxassetid://9045939292", -- Code Heist
			"rbxassetid://9038367768", -- Funky Disco Beats
		},
		Chase = "rbxassetid://9047963157", -- Spy Action
		Volume = 0.32,
		ChaseVolume = 0.42,
	},

	-- Default R15 animations owned by Roblox (used for the treadmill run while standing still).
	Animations = {
		Run = "rbxassetid://913376220",
	} :: { [string]: string },

	Images = {} :: { [string]: string },
}

return Assets
