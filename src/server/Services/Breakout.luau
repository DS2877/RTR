--!strict
-- THE BREAKOUT: the playable escape. Escaping (Services/Escape) does the rebirth bookkeeping first
-- (so leaving mid-run never loses it), then sends you here: the sewer, the searchlit yard with
-- guards running your own path a few seconds behind you, the wall, the getaway car. The server
-- checks every rule (Shared/Breakout) ten times a second: fall in the water, step into a light or
-- let the guards catch up and you're back at the last checkpoint. The medal (time + times
-- spotted) decides the Noodles you smuggle into the next prison. Admins can practice (no reward).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rules = require(Shared.Breakout)
local Config = require(Shared.Config.Breakout)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local State = require(script.Parent.Parent.State)
local Net = require(script.Parent.Parent.Net)
local Course = require(script.Parent.Parent.Util.BreakoutCourse)
local Loot = require(script.Parent.Loot)
local Cells = require(script.Parent.Cells)
local Stats = require(script.Parent.Stats)

local Breakout = {}

Breakout.onFinish = nil :: ((player: Player, medal: string) -> ())?

export type Run = {
	t0: number, -- os.clock() at the start
	checkpoint: number,
	spotted: number, -- times sent back (lights, guards, the water)
	grace: number, -- os.clock() until which nothing can get you
	trail: { { t: number, p: Vector3 } }, -- your path, for the guards on your heels
	practice: boolean,
	rebirths: number,
	prison: string,
	done: boolean,
}

local runs: { [any]: Run } = {}

local function place(player: any, cf: CFrame)
	if typeof(player) ~= "Instance" then
		player.Position = cf.Position -- smoke-test players
		return
	end
	local character = player.Character
	if character then
		character:PivotTo(cf)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

local function setFlag(player: any, on: boolean)
	if typeof(player) == "Instance" then
		player:SetAttribute("Breakout", if on then true else nil)
	end
end

function Breakout.running(player: Player): boolean
	local r = runs[player]
	return r ~= nil and not r.done
end

-- Starts a run (Escape calls it after the rebirth; admins can `practice` without one).
function Breakout.begin(player: Player, practice: boolean, rebirths: number?, prison: string?): boolean
	local s = State.get(player)
	if not s or Breakout.running(player) then
		return false
	end
	Course.build()
	local now = os.clock()
	runs[player] = {
		t0 = now,
		checkpoint = 1,
		spotted = 0,
		grace = now + Config.Grace + 1.5,
		trail = {},
		practice = practice,
		rebirths = rebirths or s.data.Rebirths,
		prison = prison or "",
		done = false,
	}
	s.vacuuming = false
	setFlag(player, true)
	place(player, Course.spawn(1))
	Net.fire(player, Remotes.Names.Breakout, "start", workspace:GetServerTimeNow(), practice)
	return true
end

-- Back to the last checkpoint (fell, spotted, caught, or respawned).
function Breakout.reset(player: Player, reason: string)
	local r = runs[player]
	if not r or r.done then
		return
	end
	if reason ~= "respawn" then
		r.spotted += 1
	end
	r.grace = os.clock() + Config.Grace
	r.trail = {}
	place(player, Course.spawn(r.checkpoint))
	Net.fire(player, Remotes.Names.Breakout, "reset", reason, r.checkpoint, r.spotted)
end

local function finish(player: Player, r: Run, timedOut: boolean)
	r.done = true
	local seconds = os.clock() - r.t0
	local medal = if timedOut then nil else Rules.medal(seconds, r.spotted)
	local cash = 0
	local s = State.get(player)
	if s and medal and not r.practice then
		cash = medal.cash
		Loot.addNoodles(player, cash)
		local st = s.data.Stats
		st.Breakouts += 1
		if st.BestEscape <= 0 or seconds < st.BestEscape then
			st.BestEscape = math.floor(seconds * 10 + 0.5) / 10
		end
		Stats.sync(player)
	end
	Net.fire(
		player,
		Remotes.Names.Breakout,
		"finish",
		seconds,
		if medal then medal.id else "",
		cash,
		r.rebirths,
		r.prison,
		r.spotted,
		r.practice
	)
	if medal and not r.practice then
		Net.announce(
			string.format(
				"%s %s broke out in %s! %s",
				medal.emoji,
				player.Name,
				Format.duration(seconds),
				medal.name
			),
			{ 255, 215, 60 },
			"Zone"
		)
	end
	if Breakout.onFinish then
		Breakout.onFinish(player, if medal then medal.id else "")
	end
	-- the cinematic plays, then the cops bring you to your new cell
	task.delay(if typeof(player) == "Instance" then 9 else 0, function()
		if runs[player] == r then
			runs[player] = nil
		end
		setFlag(player, false)
		if typeof(player) == "Instance" and player.Parent then
			Cells.toCell(player)
		end
	end)
end

-- One rules check for one runner at server time `t` (exposed for the smoke test).
function Breakout.check(player: Player, t: number)
	local r = runs[player]
	if not r or r.done then
		return
	end
	if not State.get(player) then
		runs[player] = nil
		return
	end
	local root = State.root(player)
	if not root then
		return
	end
	local now = os.clock()
	if now - r.t0 > Config.TimeLimit then
		finish(player, r, true)
		return
	end
	local lp = Course.toLocal(root)
	local x, y, z = lp.X, lp.Y, lp.Z
	-- wandered off the course entirely (teleported, glitched): back to the checkpoint
	if math.abs(z) > Rules.HalfWidth + 20 or x < -20 or x > 330 or y < -40 or y > 120 then
		Breakout.reset(player, "respawn")
		return
	end
	local cp = Rules.checkpointAt(r.checkpoint, x, y, z)
	if cp then
		r.checkpoint = cp
		r.grace = math.max(r.grace, now + 1)
		r.trail = {}
		Net.fire(player, Remotes.Names.Breakout, "checkpoint", cp)
	end
	if r.checkpoint >= 3 and Rules.atFinish(x, y, z) and now - r.t0 >= Config.MinTime then
		finish(player, r, false)
		return
	end
	if Rules.fell(x, y, z) then
		Breakout.reset(player, "fell")
		return
	end
	if now < r.grace then
		return
	end
	if Rules.spotted(x, y, z, t) then
		Breakout.reset(player, "spotted")
		return
	end
	-- the guards run your path ChaserDelay seconds behind: stop (or double back) and they're on you
	if r.checkpoint >= 2 then
		table.insert(r.trail, { t = now, p = root })
		local behind: Vector3? = nil
		while #r.trail > 1 and r.trail[2].t <= now - Config.ChaserDelay do
			table.remove(r.trail, 1)
		end
		if r.trail[1].t <= now - Config.ChaserDelay then
			behind = r.trail[1].p
		end
		if behind and (behind - root).Magnitude < Config.CatchRadius then
			Breakout.reset(player, "caught")
		end
	end
end

-- A respawned character (reset button / died) goes back to its checkpoint.
function Breakout.onCharacter(player: Player)
	if Breakout.running(player) then
		task.delay(0.3, function()
			Breakout.reset(player, "respawn")
		end)
	end
end

function Breakout.leaving(player: Player)
	runs[player] = nil
end

-- the smoke test peeks at a run
function Breakout._run(player: Player): Run?
	return runs[player]
end

function Breakout.start()
	Course.build()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local t = workspace:GetServerTimeNow()
			for player in runs do
				Breakout.check(player, t)
			end
		end
	end)
end

return Breakout
