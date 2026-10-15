--!strict
-- Asset IDs. Empty string = not uploaded; the game stays silent / uses primitives instead.
-- Every sound here is Roblox-licensed Creator Store audio (APMOfficial / ProSoundEffects), usable in
-- any experience. The smoke test re-checks every id with MarketplaceService:GetProductInfo.

local Assets = {
	Sounds = {
		Click = "rbxassetid://9112872070", -- Small Bubbles Pop 4
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

	Images = {} :: { [string]: string },
}

return Assets
