--!strict
-- Camera juice: short shakes (steal, caught, slap) and a field-of-view kick while you run with loot.
-- Applied after the default camera each frame, so it never fights the player's own camera control.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shake = {}

local trauma = 0
local fovValue = Instance.new("NumberValue")
fovValue.Value = 0

-- amount 0..1: 0.3 = bump, 0.7 = big hit
function Shake.kick(amount: number)
	trauma = math.min(1, trauma + amount)
end

-- extra field of view in degrees (e.g. 8 while carrying), eased
function Shake.fov(extra: number)
	TweenService:Create(fovValue, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Value = extra }):Play()
end

function Shake.start()
	local baseFov = 70
	local t = 0
	RunService:BindToRenderStep("DigOut_Shake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		t += dt
		camera.FieldOfView = baseFov + fovValue.Value
		if trauma > 0 then
			local s = trauma * trauma
			local rx = math.noise(t * 25, 1) * s * 0.06
			local ry = math.noise(t * 25, 2) * s * 0.06
			local rz = math.noise(t * 25, 3) * s * 0.04
			camera.CFrame = camera.CFrame * CFrame.Angles(rx, ry, rz)
			trauma = math.max(0, trauma - dt * 1.8)
		end
	end)
end

return Shake
