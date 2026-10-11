--!strict
-- Asset IDs. Empty string = not uploaded; the game stays silent / uses primitives instead.
-- Sounds are Roblox licensed Creator Store audio (APM / ProSoundEffects), usable in any experience.

local Assets = {
	Sounds = {
		Click = "rbxassetid://9112872070", -- Small Bubbles Pop 4
		Open = "rbxassetid://9112872058", -- Small Bubbles Pop 3
		Grab = "rbxassetid://9114369623", -- Fairy Dust 1
		Deposit = "rbxassetid://9125444889", -- Coins Drop Metal Hits
		Collect = "rbxassetid://9125445531", -- Coins Drop Metal Hits
		Upgrade = "rbxassetid://9040476898", -- Early Bird - Hit1 (APM)
		Purchase = "rbxassetid://9117244567", -- Pay Phone Dropping Dimes
		Caught = "rbxassetid://9117947034", -- Puddle Stomps Splash 9
		Crown = "rbxassetid://1836860398", -- Winning Spirit (APM)
		Announce = "rbxassetid://1841390412", -- Bouncy Bouncy Sting 1 (APM)
		Rare = "rbxassetid://1841173427", -- Magical (c) (APM)
	} :: { [string]: string },
	Images = {} :: { [string]: string },
}

return Assets
