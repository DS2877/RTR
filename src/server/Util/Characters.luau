--!strict
-- Real Roblox characters for the NPCs. Build.npc makes an instant blocky stand-in (tag "NPC",
-- attributes Role + Feet); Characters.upgradeAll then swaps every stand-in for an R15 avatar built
-- from a HumanoidDescription (Config/Assets.Outfits: catalog shirts, pants, caps, hair), with a
-- skin tone and an idle animation. If an avatar can't be built, the stand-in simply stays.
-- Characters.publishTemplates puts a guard avatar in ReplicatedStorage.NPCTemplates for the
-- patrolling guards (the client clones and animates it: Controllers/GuardController).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Characters = {}

local templates: { [string]: Model } = {}

local function describe(role: string, variant: number, glasses: boolean): HumanoidDescription
	local o = Assets.Outfits[role] or Assets.Outfits.inmate
	local d = Instance.new("HumanoidDescription")
	if o.Shirt then
		d.Shirt = o.Shirt
	end
	if o.Pants then
		d.Pants = o.Pants
	end
	if o.Hat then
		d.HatAccessory = o.Hat
	end
	if o.Waist then
		d.WaistAccessory = o.Waist
	end
	if o.Hair then
		d.HairAccessory = o.Hair[(variant - 1) % #o.Hair + 1]
	end
	if glasses then
		d.FaceAccessory = Assets.Outfits.glasses
	end
	return d
end

-- A built avatar for this role (cached per role + hair variant; nil if it can't be built).
local function template(role: string, variant: number, glasses: boolean?): Model?
	local key = role .. variant .. (if glasses then "g" else "")
	local t = templates[key]
	if t then
		return t
	end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(
			describe(role, variant, glasses == true),
			Enum.HumanoidRigType.R15
		)
	end)
	if not ok or not rig then
		warn("[Characters] could not build", role, rig)
		return nil
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	templates[key] = rig
	return rig
end

local function feetOffset(rig: Model): number
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local hrp = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	return (if humanoid then humanoid.HipHeight else 2) + (if hrp then hrp.Size.Y / 2 else 1)
end

local function skin(rig: Model, seed: number)
	local c = Assets.Skin[seed % #Assets.Skin + 1]
	local color = Color3.fromRGB(c[1], c[2], c[3])
	for _, part in rig:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = color
		end
	end
end

local function idle(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local ok, track = pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = Assets.Animations.IdleR15
		return (animator :: Animator):LoadAnimation(a)
	end)
	if ok and track then
		track.Looped = true
		track:Play(0, 1, 0.8 + math.random() * 0.4)
		track.TimePosition = math.random() * 2 -- not everyone breathing in sync
	end
end

-- Replaces one stand-in's parts with an avatar (keeps the Model, its name and its tags).
function Characters.upgrade(m: Model)
	local role = m:GetAttribute("Role")
	local feet = m:GetAttribute("Feet")
	if typeof(role) ~= "string" or typeof(feet) ~= "CFrame" then
		return
	end
	local seed = math.floor(math.abs(feet.Position.X * 7 + feet.Position.Z * 13))
	local t = template(role, seed % 4 + 1, m:GetAttribute("Glasses") == true)
	if not t then
		return
	end
	local rig = t:Clone()
	skin(rig, seed)
	local hrp = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		rig:Destroy()
		return
	end
	local off = feetOffset(rig)
	rig:PivotTo(feet * CFrame.new(0, off, 0))
	hrp.Anchored = true
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = true
		end
	end
	-- lights on the old head (the inspection guard's torch) move to the new head
	local oldHead = m:FindFirstChild("Head")
	local newHead = rig:FindFirstChild("Head")
	if oldHead and newHead then
		for _, l in oldHead:GetChildren() do
			if l:IsA("Light") then
				l.Parent = newHead
			end
		end
	end
	-- out with the blocks, in with the avatar (the Model itself stays: others hold references)
	for _, c in m:GetChildren() do
		c:Destroy()
	end
	for _, c in rig:GetChildren() do
		c.Parent = m
	end
	rig:Destroy()
	m.PrimaryPart = hrp
	hrp.PivotOffset = CFrame.new(0, -off, 0) -- the Model's pivot stays at the feet
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	if humanoid then
		idle(humanoid)
	end
	m:SetAttribute("Avatar", true)
end

function Characters.upgradeAll()
	for _, m in CollectionService:GetTagged("NPC") do
		if m:IsA("Model") and m.Parent then
			local ok, err = pcall(Characters.upgrade, m)
			if not ok then
				warn("[Characters] upgrade failed", m:GetFullName(), err)
			end
		end
	end
end

-- The patrolling guards' look, for the client to clone.
function Characters.publishTemplates()
	local folder = Instance.new("Folder")
	folder.Name = "NPCTemplates"
	local t = template("guard", 1)
	if t then
		local g = t:Clone()
		g.Name = "Guard"
		g:SetAttribute("FeetOffset", feetOffset(g))
		g.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

return Characters
