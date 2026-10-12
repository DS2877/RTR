--!strict
-- How each rich person looks: suit color + a themed hat, dressed onto a Roblox R15 rig.
-- Used by the owner NPCs that stand among their crates and chase thieves (Services/Guards).

local Rig = require(script.Parent.Rig)

local RichLook = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

RichLook.Styles = {
	Grandpa = { suit = rgb(130, 95, 70), hat = "cap" },
	Jeweler = { suit = rgb(70, 72, 84), hat = "top" },
	Archeologist = { suit = rgb(196, 170, 112), hat = "safari" },
	Mafia = { suit = rgb(22, 22, 26), hat = "fedora" },
	Celebrity = { suit = rgb(255, 120, 190), hat = "shades" },
	Pirate = { suit = rgb(140, 30, 35), hat = "tricorn" },
	Museum = { suit = rgb(240, 240, 245), hat = "none" }, -- white shirt, like a curator
	GoldTycoon = { suit = rgb(255, 200, 40), hat = "top" },
} :: { [string]: { suit: Color3, hat: string } }

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A fresh R15 rig for vault `def` (nil if rigs can't be built), dressed in its style.
function RichLook.build(def: any): Model?
	local style = RichLook.Styles[def.id] or { suit = rgb(40, 40, 50), hat = "top" }
	local rig = Rig.build(
		"rich_" .. def.id,
		{ head = rgb(255, 205, 160), torso = style.suit, arms = style.suit, legs = rgb(30, 30, 40) }
	)
	if not rig then
		return nil
	end
	local head = rig:FindFirstChild("Head") :: BasePart?
	local chest = rig:FindFirstChild("UpperTorso") :: BasePart?
	if not head or not chest then
		rig:Destroy()
		return nil
	end
	local trim = rgb(def.trim[1], def.trim[2], def.trim[3])
	local top = head.Size.Y / 2
	local hf = -head.Size.Z / 2
	local function hat(name: string, size: Vector3, offset: CFrame, color: Color3)
		Rig.attach(head, part(rig, name, size, color), offset)
	end
	if style.hat == "cap" then
		hat("Cap", Vector3.new(1.3, 0.4, 1.3), CFrame.new(0, top + 0.15, 0), rgb(110, 90, 70))
		hat("Brim", Vector3.new(1.3, 0.12, 0.6), CFrame.new(0, top, hf - 0.25), rgb(110, 90, 70))
	elseif style.hat == "top" then
		hat("HatBrim", Vector3.new(1.7, 0.15, 1.7), CFrame.new(0, top + 0.05, 0), rgb(20, 20, 25))
		hat("TopHat", Vector3.new(1.1, 1.3, 1.1), CFrame.new(0, top + 0.75, 0), rgb(20, 20, 25))
		hat("HatBand", Vector3.new(1.15, 0.2, 1.15), CFrame.new(0, top + 0.25, 0), trim)
	elseif style.hat == "tricorn" then
		hat("Tricorn", Vector3.new(1.9, 0.5, 1.4), CFrame.new(0, top + 0.2, 0), rgb(25, 25, 30))
		hat("TricornTrim", Vector3.new(1.95, 0.12, 1.45), CFrame.new(0, top, 0), rgb(255, 200, 40))
	elseif style.hat == "safari" then
		hat("SafariHat", Vector3.new(1.3, 0.6, 1.3), CFrame.new(0, top + 0.25, 0), rgb(214, 196, 140))
		hat("SafariBrim", Vector3.new(2, 0.12, 2), CFrame.new(0, top + 0.02, 0), rgb(200, 180, 124))
	elseif style.hat == "fedora" then
		hat("Fedora", Vector3.new(1.25, 0.6, 1.25), CFrame.new(0, top + 0.28, 0), rgb(20, 20, 24))
		hat("FedoraBrim", Vector3.new(1.9, 0.12, 1.9), CFrame.new(0, top + 0.02, 0), rgb(20, 20, 24))
		hat("FedoraBand", Vector3.new(1.28, 0.16, 1.28), CFrame.new(0, top + 0.1, 0), rgb(200, 40, 50))
	elseif style.hat == "shades" then
		hat("Shades", Vector3.new(1.1, 0.3, 0.12), CFrame.new(0, 0.12, hf - 0.06), rgb(20, 20, 25))
		hat("Hair", Vector3.new(1.25, 0.45, 1.25), CFrame.new(0, top + 0.1, 0.05), rgb(250, 220, 120))
	elseif style.hat == "captain" then
		hat("CaptainHat", Vector3.new(1.4, 0.5, 1.4), CFrame.new(0, top + 0.2, 0), rgb(255, 255, 255))
		hat("CaptainBrim", Vector3.new(1.4, 0.12, 0.6), CFrame.new(0, top, hf - 0.25), rgb(20, 30, 80))
	end
	-- dark hair under hatless heads (reads as a person from far away)
	if style.hat == "none" then
		hat("Hair", Vector3.new(1.25, 0.45, 1.25), CFrame.new(0, top + 0.1, 0.05), rgb(35, 25, 20))
	end
	Rig.attach(
		chest,
		part(rig, "Tie", Vector3.new(0.3, 1.1, 0.1), trim),
		CFrame.new(0, 0.1, -chest.Size.Z / 2 - 0.05)
	)
	if def.id == "GoldTycoon" or def.id == "Mafia" then
		Rig.attach(
			chest,
			part(rig, "Chain", Vector3.new(1.1, 0.15, 0.1), rgb(255, 210, 60), Enum.Material.Neon),
			CFrame.new(0, 0.45, -chest.Size.Z / 2 - 0.08)
		)
	end
	return rig
end

return RichLook
