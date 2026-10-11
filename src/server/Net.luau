--!strict
-- Small helpers for messages to clients.
-- Messages to anything that isn't a real Player (the smoke test's simulated players) go to
-- `Net.sink` instead, so the whole game loop can be exercised headlessly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Net = {}

Net.sink = nil :: ((player: any, name: string, args: { any }) -> ())?

local function deliver(player: Player, name: string, ...: any)
	if typeof(player) == "Instance" then
		Remotes.get(name):FireClient(player, ...)
	elseif Net.sink then
		Net.sink(player, name, { ... })
	end
end

-- kind: "good" | "bad" | "info" | "cash" | "upgrade"
function Net.notice(player: Player, text: string, kind: string?)
	deliver(player, Remotes.Names.Notice, text, kind or "info")
end

function Net.announce(text: string, color: { number }?, sound: string?)
	Remotes.get(Remotes.Names.Announce):FireAllClients(text, color or { 255, 215, 60 }, sound)
	if Net.sink then
		Net.sink(nil, Remotes.Names.Announce, { text })
	end
end

function Net.fire(player: Player, name: string, ...: any)
	deliver(player, name, ...)
end

function Net.on(name: string, handler: (player: Player, ...any) -> ())
	Remotes.get(name).OnServerEvent:Connect(handler)
end

return Net
