--!strict
-- Small helpers for messages to clients.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Net = {}

-- kind: "good" | "bad" | "info"
function Net.notice(player: Player, text: string, kind: string?)
	Remotes.get(Remotes.Names.Notice):FireClient(player, text, kind or "info")
end

function Net.announce(text: string, color: { number }?)
	Remotes.get(Remotes.Names.Announce):FireAllClients(text, color or { 255, 215, 60 })
end

function Net.fire(player: Player, name: string, ...: any)
	Remotes.get(name):FireClient(player, ...)
end

function Net.on(name: string, handler: (player: Player, ...any) -> ())
	Remotes.get(name).OnServerEvent:Connect(handler)
end

return Net
