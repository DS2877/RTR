--!strict
-- Shared bits for the cinematics (Controllers/Breakout, the escape in Controllers/Moments): hide
-- every HUD layer while the camera is scripted, and bring back exactly what was hidden.

local Players = game:GetService("Players")

local Cinematic = {}

-- Disables every enabled ScreenGui except `keep` (and never the touch controls or chat: the
-- joystick is how you run on a phone). Returns what it hid, for Cinematic.showHud.
function Cinematic.hideHud(keep: ScreenGui?): { ScreenGui }
	local hidden: { ScreenGui } = {}
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return hidden
	end
	for _, g in playerGui:GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled and g ~= keep and g.Name ~= "TouchGui" and g.Name ~= "Chat" then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	return hidden
end

function Cinematic.showHud(hidden: { ScreenGui })
	for _, g in hidden do
		if g.Parent then
			g.Enabled = true
		end
	end
	table.clear(hidden)
end

return Cinematic
