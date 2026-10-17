--!strict
-- Keeps the game smooth on phones: measures the frame rate and steps the quality level
-- (Config/Quality) down when it drops under ~45 fps, back up when there's headroom. A level sets
-- the tunnel render radius, the light budget, light shadows, the debris cap, particle density and
-- bloom. Lights and emitters created later (tunnel lamps, chambers, flashlights) follow the
-- current level as they appear.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Quality)

local VoxelRender = require(script.Parent.VoxelRender)
local DigFX = require(script.Parent.DigFX)

local Quality = {}

local level = #Config.Levels
local baseRate: { [ParticleEmitter]: number } = {}
local baseShadows: { [Instance]: boolean } = {}
-- every light / emitter in the workspace (collected once, then kept up to date), so a level change
-- doesn't walk the whole workspace again
local tracked: { [Instance]: true } = {}
local applyToken = 0

function Quality.level(): (number, string)
	return level, Config.Levels[level].name
end

local function applyLight(l: Instance)
	if l:IsA("PointLight") or l:IsA("SpotLight") or l:IsA("SurfaceLight") then
		if baseShadows[l] == nil then
			baseShadows[l] = l.Shadows
		end
		l.Shadows = (baseShadows[l] :: boolean) and Config.Levels[level].shadows
	elseif l:IsA("ParticleEmitter") then
		if baseRate[l] == nil then
			baseRate[l] = l.Rate
		end
		l.Rate = (baseRate[l] :: number) * Config.Levels[level].particles
	end
end

local function isTracked(d: Instance): boolean
	return d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") or d:IsA("ParticleEmitter")
end

local function apply()
	local q = Config.Levels[level]
	VoxelRender.setBudget(q.stream, q.lights, q.shadows)
	DigFX.setMaxDebris(q.debris)
	-- the lights in batches of 200 per frame (a step down happens exactly when frames are slow)
	applyToken += 1
	local mine = applyToken
	local list = {}
	for d in tracked do
		table.insert(list, d)
	end
	task.spawn(function()
		for i, d in list do
			if applyToken ~= mine then
				return
			end
			if d.Parent then
				applyLight(d)
			end
			if i % 200 == 0 then
				task.wait()
			end
		end
	end)
	for _, e in Lighting:GetChildren() do
		if e:IsA("BloomEffect") then
			e.Enabled = q.bloom
		end
	end
end

function Quality.start()
	for _, d in workspace:GetDescendants() do
		if isTracked(d) then
			tracked[d] = true
		end
	end
	apply()
	workspace.DescendantAdded:Connect(function(d)
		if isTracked(d) then
			tracked[d] = true
			-- (one frame later: the creator sets its properties after parenting sometimes)
			task.defer(applyLight, d)
		end
	end)
	workspace.DescendantRemoving:Connect(function(d)
		tracked[d] = nil
		baseRate[d :: any] = nil
		baseShadows[d] = nil
	end)
	local frames, windowStart = 0, os.clock()
	local lowFor, highFor, lastChange = 0, 0, os.clock()
	RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		local span = now - windowStart
		if span < 1 then
			return
		end
		local fps = frames / span
		frames, windowStart = 0, now
		if fps < Config.DropBelow then
			lowFor += span
			highFor = 0
		elseif fps > Config.RaiseAbove then
			highFor += span
			lowFor = 0
		else
			lowFor, highFor = 0, 0
		end
		if now - lastChange < Config.Cooldown then
			return
		end
		if lowFor >= Config.DropSeconds and level > 1 then
			level -= 1
			lowFor, lastChange = 0, now
			apply()
		elseif highFor >= Config.RaiseSeconds and level < #Config.Levels then
			level += 1
			highFor, lastChange = 0, now
			apply()
		end
	end)
end

return Quality
