--!strict
-- Every admin command has a button in the HUD's ADMIN dashboard, and every button runs a command
-- the server knows (there are no chat commands, so a missing button = a command nobody can use).
local fs = require("@lune/fs")

local CLIENT_ONLY = { tour = true, perf = true, photo = true }

return function()
	local hud = fs.readFile("src/client/Controllers/HUD.luau")
	local admin = fs.readFile("src/server/Services/Admin.luau")
	local cycle = fs.readFile("src/shared/Config/Cycle.luau")
	-- buttons: { "Label", "cmd", arg }
	local buttons: { [string]: boolean } = {}
	local a = string.find(hud, "local sections", 1, true)
	local b = string.find(hud, "local remote = Remotes.get(Remotes.Names.AdminCmd)", 1, true)
	assert(a and b, "admin dashboard found")
	for cmd in string.gmatch(string.sub(hud, a, b), '{ "[^"]+", "([%w_]+)"') do
		buttons[cmd] = true
	end
	-- server commands: cmd == "x" (plus every event in Config/Cycle.Events)
	local server: { [string]: boolean } = {}
	for cmd in string.gmatch(admin, 'cmd == "([%w_]+)"') do
		server[cmd] = true
	end
	local events = string.sub(cycle, string.find(cycle, "Events = {", 1, true) :: number)
	for name in string.gmatch(events, "\n\t\t(%u[%u_]+) = {") do
		server[string.lower(name)] = true
	end
	for cmd in buttons do
		assert(CLIENT_ONLY[cmd] or server[cmd], "button without a server command: " .. cmd)
	end
	for cmd in server do
		assert(buttons[cmd], "admin command without a button: " .. cmd)
	end
	assert(not string.find(admin, "Chatted", 1, true), "no chat commands")
end
