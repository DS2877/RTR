--!strict
-- One-time tips (Services/Tutorial.tip): each shows ONCE per prisoner, the moment it matters, as a
-- normal card. The first-join tour stays short; these cover the rest as you meet it.

export type Tip = { icon: string, title: string, text: string }

local Tips: { [string]: Tip } = {
	BagFull = {
		icon = "🧱",
		title = "Backpack full!",
		text = "Dump it at the RUBBLE DUMP in the Yard for 🍜 Noodles",
	},
	FirstFind = {
		icon = "💰",
		title = "You found something!",
		text = "Sell finds at THE FENCE in the Common Room",
	},
	FirstDump = {
		icon = "📋",
		title = "Daily jobs pay big",
		text = "Tap 📋 Jobs for today's work + your login streak",
	},
	Night = {
		icon = "🌙",
		title = "Lockdown",
		text = "Dig for bonus finds. Guards check cells: cover the hole + get in bed",
	},
	Catalog = {
		icon = "📦",
		title = "Shopping at night?",
		text = "Tap 📦 CATALOG in your cell: every upgrade, +20%",
	},
	Zone2 = {
		icon = "👥",
		title = "Dig with friends",
		text = "Tap 👥 Crew: everyone in a crew gets more Noodles",
	},
}

return Tips
