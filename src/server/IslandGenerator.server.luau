--!strict
-- IslandGenerator: Hand-built 2000x2000 island with three biomes (deterministic layout)
--
--   Center : Village safe zone — fountain, lamps, NPCs, all stations, statues
--   West   : FOREST biome — wood is king (dense trees, Ancient trees), wolves
--   North  : SNOW biome — ore is king (ore fields + Frozen Mine), golems, boss arena + portal
--   South+East : DESERT biome — stone is king (stone fields), bandits, fortress, oasis lake
-- Corrupted island (NG+) sits far east at GameConfig.CORRUPT_OFFSET.

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local rng = Random.new(42) -- deterministic: same island every server

local CORRUPT_OFFSET = GameConfig.CORRUPT_OFFSET

local Island = Instance.new("Folder")
Island.Name = "Island"
Island.Parent = workspace

local Decor = Instance.new("Folder")
Decor.Name = "Decor"
Decor.Parent = workspace

local Stations = Instance.new("Folder")
Stations.Name = "Stations"
Stations.Parent = workspace

local NPCs = Instance.new("Folder")
NPCs.Name = "NPCs"
NPCs.Parent = workspace

local Portals = Instance.new("Folder")
Portals.Name = "Portals"
Portals.Parent = workspace

if not workspace:FindFirstChild("Mobs") then
	local Mobs = Instance.new("Folder")
	Mobs.Name = "Mobs"
	Mobs.Parent = workspace
end

-- Animated parts registry (spinning blades, bobbing eggs, floating crystals, flickering fires)
type Anim = { part: Part, kind: string, base: CFrame, light: PointLight? }
local Animated: { Anim } = {}

local function makePart(
	name: string,
	size: Vector3,
	position: Vector3,
	colorName: string,
	parent: Instance?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.BrickColor = BrickColor.new(colorName :: any)
	p.Anchored = true
	p.Parent = parent or Island
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function decoPart(name: string, size: Vector3, position: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = Decor
	return p
end

local function makeBillboard(part: BasePart, text: string, color: Color3?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 160, 0, 44)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Text = text
	lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	lbl.BackgroundTransparency = 0.5
	lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Parent = bb
	bb.Parent = part
end

local function makeLabel(part: BasePart, text: string)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 200, 0, 36)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(255, 230, 100)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Gotham
	lbl.Parent = bb
	bb.Parent = part
end

local function sparkles(parent: BasePart, color: Color3, rate: number, size: number)
	local att = Instance.new("Attachment")
	att.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.8, 1.6)
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	pe.Color = ColorSequence.new(color)
	pe.Parent = att
	return pe
end

local function fire(parent: BasePart, color: Color3): PointLight
	local f = Instance.new("Fire")
	f.Color = color
	f.SecondaryColor = Color3.fromRGB(60, 30, 10)
	f.Size = 4
	f.Heat = 6
	f.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 2
	light.Parent = parent
	return light
end

-- ============================================================
-- TERRAIN: base ground + biome patches
-- ============================================================

local ground = makePart("Ground", Vector3.new(2000, 2, 2000), Vector3.new(0, -1, 0), "Bright green")
ground.Material = Enum.Material.Grass

local water = makePart("Water", Vector3.new(3000, 1, 3000), Vector3.new(0, -4.5, 0), "Bright blue")
water.Material = Enum.Material.SmoothPlastic
water.Transparency = 0.45
water.CanCollide = false

-- FOREST floor (west): darker lush green
local forestFloor = makePart("ForestFloor", Vector3.new(880, 0.4, 1100), Vector3.new(-540, 0.2, 0), "Earth green")
forestFloor.Material = Enum.Material.Grass

-- SNOW floor (north)
local snowFloor = makePart("SnowFloor", Vector3.new(1500, 0.4, 800), Vector3.new(200, 0.2, -580), "White")
snowFloor.Material = Enum.Material.Sand

-- DESERT floor (south + east)
local desertFloorS = makePart("DesertFloorSouth", Vector3.new(1500, 0.4, 800), Vector3.new(-100, 0.2, 580), "Brick yellow")
desertFloorS.Material = Enum.Material.Sand
local desertFloorE = makePart("DesertFloorEast", Vector3.new(700, 0.4, 700), Vector3.new(640, 0.2, 180), "Brick yellow")
desertFloorE.Material = Enum.Material.Sand

local plaza = makePart("VillagePlaza", Vector3.new(150, 0.5, 150), Vector3.new(0, 0.45, 0), "Tan")
plaza.Material = Enum.Material.SmoothPlastic

local function makePath(p1: Vector3, p2: Vector3, width: number)
	local mid = (p1 + p2) / 2
	local length = (p2 - p1).Magnitude
	local pathY = 0.62
	local path = makePart("Path", Vector3.new(width, 0.25, length), mid + Vector3.new(0, pathY, 0), "Sand yellow")
	path.Material = Enum.Material.SmoothPlastic
	path.CFrame = CFrame.lookAt(mid + Vector3.new(0, pathY, 0), p2 + Vector3.new(0, pathY, 0))
end

makePath(Vector3.new(0, 0, -75), Vector3.new(0, 0, -320), 12) -- north to portal
makePath(Vector3.new(0, 0, 75), Vector3.new(0, 0, 700), 12) -- south to fortress
makePath(Vector3.new(-75, 0, 0), Vector3.new(-900, 0, 0), 12) -- west through forest
makePath(Vector3.new(75, 0, 0), Vector3.new(560, 0, 0), 12) -- east toward desert
makePath(Vector3.new(380, 0, -60), Vector3.new(600, 0, -560), 10) -- to frozen mine
makePath(Vector3.new(300, 0, 300), Vector3.new(480, 0, 440), 10) -- to oasis lake

-- ============================================================
-- VILLAGE: fountain, lamps, buildings, stations, NPCs, statues
-- ============================================================

-- Spawn ring (the SpawnLocation itself sits at 0,0.95,0 from the project file)
do
	local ring = makePart("SpawnRing", Vector3.new(0.8, 12, 12), Vector3.new(0, 0.78, 0), "Medium stone grey")
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(0, 0.78, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Slate
	sparkles(ring, Color3.fromRGB(140, 220, 255), 6, 0.6)
end

-- Fountain (offset from spawn)
do
	local base = makePart("FountainBase", Vector3.new(1.6, 16, 16), Vector3.new(0, 1.2, 24), "Medium stone grey")
	base.Shape = Enum.PartType.Cylinder
	base.CFrame = CFrame.new(0, 1.2, 24) * CFrame.Angles(0, 0, math.rad(90))
	base.Material = Enum.Material.Slate
	local pool = makePart("FountainWater", Vector3.new(0.6, 13, 13), Vector3.new(0, 1.8, 24), "Cyan")
	pool.Shape = Enum.PartType.Cylinder
	pool.CFrame = CFrame.new(0, 1.8, 24) * CFrame.Angles(0, 0, math.rad(90))
	pool.Material = Enum.Material.Glass
	pool.Transparency = 0.3
	local pillar = makePart("FountainPillar", Vector3.new(2, 6, 2), Vector3.new(0, 4.5, 24), "Medium stone grey")
	pillar.Material = Enum.Material.Slate
	local jet = sparkles(pillar, Color3.fromRGB(150, 220, 255), 22, 0.7)
	jet.Speed = NumberRange.new(6, 10)
	jet.SpreadAngle = Vector2.new(25, 25)
	jet.Lifetime = NumberRange.new(0.6, 1.1)
end

-- Lamp posts around the plaza (offset half-step so they sit between stations)
for i = 1, 8 do
	local angle = (i / 8) * math.pi * 2 + math.pi / 8
	local pos = Vector3.new(math.cos(angle) * 80, 0, math.sin(angle) * 80)
	local pole = makePart("LampPole", Vector3.new(0.8, 9, 0.8), pos + Vector3.new(0, 5.1, 0), "Black")
	pole.Material = Enum.Material.Metal
	local lamp = makePart("LampHead", Vector3.new(1.8, 1.8, 1.8), pos + Vector3.new(0, 10, 0), "Bright yellow")
	lamp.Material = Enum.Material.Neon
	lamp.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = lamp
end

-- Banner poles at the four plaza entrances
for _, def in ipairs({
	{ pos = Vector3.new(0, 0, -74), color = "Bright violet" },
	{ pos = Vector3.new(0, 0, 74), color = "Bright orange" },
	{ pos = Vector3.new(-74, 0, 0), color = "Bright green" },
	{ pos = Vector3.new(74, 0, 0), color = "Cyan" },
}) do
	local pole = makePart("BannerPole", Vector3.new(0.7, 12, 0.7), def.pos + Vector3.new(0, 6.6, 0), "Dark taupe")
	pole.Material = Enum.Material.Wood
	local banner = makePart("Banner", Vector3.new(3, 4.5, 0.2), def.pos + Vector3.new(0, 9.6, 0), def.color)
	banner.Material = Enum.Material.Fabric
	local _ = pole
end

local function makeBuilding(name: string, pos: Vector3, size: Vector3, roofColor: string, wallColor: string)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Island
	local walls = makePart("Walls", size, pos + Vector3.new(0, size.Y / 2 + 0.6, 0), wallColor, folder)
	walls.Material = Enum.Material.SmoothPlastic
	local roof = Instance.new("WedgePart")
	roof.Name = "Roof"
	roof.Size = Vector3.new(size.X + 2, size.Y * 0.55, size.Z + 2)
	roof.CFrame = CFrame.new(pos + Vector3.new(0, size.Y + 0.6 + roof.Size.Y / 2, 0))
	roof.BrickColor = BrickColor.new(roofColor :: any)
	roof.Anchored = true
	roof.Material = Enum.Material.SmoothPlastic
	roof.Parent = folder

	-- Door + windows facing village center
	local toCenter = -pos
	local facingX = math.abs(toCenter.X) > math.abs(toCenter.Z)
	local sx = if facingX then math.sign(toCenter.X) else 0
	local sz = if facingX then 0 else math.sign(toCenter.Z)
	local wallHalf = if facingX then size.X / 2 else size.Z / 2

	local doorSize = if facingX then Vector3.new(0.3, 4.5, 2.6) else Vector3.new(2.6, 4.5, 0.3)
	local door = makePart("Door", doorSize, pos + Vector3.new(sx * (wallHalf + 0.2), 2.85, sz * (wallHalf + 0.2)), "Brown", folder)
	door.Material = Enum.Material.Wood

	local winSize = if facingX then Vector3.new(0.3, 1.8, 2) else Vector3.new(2, 1.8, 0.3)
	local sideOffset = if facingX then Vector3.new(0, 0, size.Z / 2 - 2.4) else Vector3.new(size.X / 2 - 2.4, 0, 0)
	for _, side in ipairs({ -1, 1 }) do
		local win = makePart(
			"Window",
			winSize,
			pos + Vector3.new(sx * (wallHalf + 0.2), 4.4, sz * (wallHalf + 0.2)) + sideOffset * side,
			"Pastel light blue",
			folder
		)
		win.Material = Enum.Material.Glass
		win.Transparency = 0.3
	end

	local chimney = makePart(
		"Chimney",
		Vector3.new(1.5, 3.5, 1.5),
		pos + Vector3.new(size.X / 2 - 1.5, size.Y + 1.8, -size.Z / 2 + 1.5),
		"Medium stone grey",
		folder
	)
	chimney.Material = Enum.Material.Brick
	-- Cozy chimney smoke
	local att = Instance.new("Attachment")
	att.Parent = chimney
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 2
	smoke.Lifetime = NumberRange.new(2, 3.5)
	smoke.Speed = NumberRange.new(1, 2)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 3),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Parent = att
end

makeBuilding("Guide_House", Vector3.new(-55, 0, -28), Vector3.new(14, 9, 14), "Bright blue", "White")
makeBuilding("Sawmill_House", Vector3.new(55, 0, -28), Vector3.new(16, 9, 14), "Bright orange", "Bright yellow")
makeBuilding("Tanner_House", Vector3.new(-55, 0, 28), Vector3.new(14, 9, 14), "Reddish brown", "Sand yellow")
makeBuilding("Blacksmith_House", Vector3.new(55, 0, 28), Vector3.new(16, 9, 14), "Dark grey", "Medium stone grey")
makeBuilding("Merchant_House", Vector3.new(-28, 0, 55), Vector3.new(14, 9, 14), "Bright green", "White")
makeBuilding("QuestElder_House", Vector3.new(28, 0, 55), Vector3.new(14, 9, 14), "Gold", "Tan")

-- Crates & barrels near the merchant
for i = 1, 4 do
	local crate = makePart("Crate", Vector3.new(2.2, 2.2, 2.2), Vector3.new(-20 - i * 2.6, 1.7, 50 + (i % 2) * 2.5), "Brown")
	crate.Material = Enum.Material.WoodPlanks
	crate.Rotation = Vector3.new(0, i * 15, 0)
end
for i = 1, 3 do
	local barrel = makePart("Barrel", Vector3.new(2, 2.8, 2), Vector3.new(-34, 2, 44 + i * 2.6), "Reddish brown")
	barrel.Shape = Enum.PartType.Cylinder
	barrel.CFrame = CFrame.new(-34, 2, 44 + i * 2.6) * CFrame.Angles(0, 0, math.rad(90))
	barrel.Material = Enum.Material.Wood
end

-- ============================================================
-- STATIONS: composite builds with particles + animation
-- ============================================================

type StationDef = { name: string, label: string, pos: Vector3, color: string, comingSoon: boolean? }
local stationDefs: { StationDef } = {
	{ name = "Sawmill", label = "Sawmill", pos = Vector3.new(44, 0, -14), color = "Bright orange" },
	{ name = "TanningRack", label = "Tanning Rack", pos = Vector3.new(-44, 0, 14), color = "Reddish brown" },
	{ name = "Forge", label = "Forge", pos = Vector3.new(44, 0, 14), color = "Dark grey" },
	{ name = "CraftingBench", label = "Crafting Bench", pos = Vector3.new(0, 0, 36), color = "Bright yellow" },
	{ name = "Smeltery", label = "Smeltery", pos = Vector3.new(20, 0, -50), color = "Dark grey" },
	{ name = "Stonecutter", label = "Stonecutter", pos = Vector3.new(-20, 0, -50), color = "Medium stone grey" },
	{ name = "MerchantStall", label = "Merchant Stall", pos = Vector3.new(-14, 0, 44), color = "Bright green" },
	{ name = "ExchangeBoard", label = "Marketplace Board", pos = Vector3.new(14, 0, 44), color = "Medium stone grey", comingSoon = true },
	{ name = "RebirthShrine", label = "Rebirth Shrine", pos = Vector3.new(0, 0, -38), color = "Royal purple" },
	{ name = "EggStand", label = "Companion Eggs", pos = Vector3.new(-38, 0, -38), color = "Bright violet" },
}

local function stationBase(parent: Instance, name: string, pos: Vector3): Part
	-- Interact pad: holds the StationType tag + ProximityPrompt
	local pad = makePart(name, Vector3.new(7, 1, 7), pos + Vector3.new(0, 1.1, 0), "Dark taupe", parent)
	pad.Material = Enum.Material.WoodPlanks
	return pad
end

local function buildStation(sd: StationDef, parent: Folder, posOverride: Vector3?)
	local pos = posOverride or sd.pos
	local pad = stationBase(parent, sd.name, pos)

	local tag = Instance.new("StringValue")
	tag.Name = "StationType"
	tag.Value = sd.name
	tag.Parent = pad
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use " .. sd.label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.Parent = pad
	if sd.comingSoon then
		prompt.Enabled = false
		makeLabel(pad, sd.label .. "\n[Coming Soon]")
	else
		makeLabel(pad, sd.label)
	end

	local name = sd.name
	if name == "Sawmill" then
		local table_ = makePart(name .. "_Table", Vector3.new(6, 1.6, 4), pos + Vector3.new(0, 2.4, 0), "Brown", parent)
		table_.Material = Enum.Material.Wood
		local log = makePart(name .. "_Log", Vector3.new(5, 1.4, 1.4), pos + Vector3.new(0, 3.9, -0.8), "Reddish brown", parent)
		log.Shape = Enum.PartType.Cylinder
		log.Material = Enum.Material.Wood
		local blade = makePart(name .. "_Blade", Vector3.new(0.3, 3.4, 3.4), pos + Vector3.new(0, 4.4, 0.8), "Institutional white", parent)
		blade.Shape = Enum.PartType.Cylinder
		blade.Material = Enum.Material.Metal
		table.insert(Animated, { part = blade, kind = "spinX", base = blade.CFrame })
		local dust = sparkles(table_, Color3.fromRGB(200, 160, 100), 5, 0.4)
		dust.LightEmission = 0
	elseif name == "Forge" or name == "Smeltery" then
		local hearth = makePart(name .. "_Hearth", Vector3.new(6, 3.5, 6), pos + Vector3.new(0, 3.2, 0), "Dark grey", parent)
		hearth.Material = Enum.Material.Brick
		local chimney = makePart(name .. "_Chimney", Vector3.new(2, 5, 2), pos + Vector3.new(1.6, 7.2, -1.6), "Really black", parent)
		chimney.Material = Enum.Material.Brick
		local coals = makePart(name .. "_Coals", Vector3.new(3.4, 1, 3.4), pos + Vector3.new(0, 5.2, 0), "Neon orange", parent)
		coals.Material = Enum.Material.Neon
		local light = fire(coals, Color3.fromRGB(255, 120, 30))
		table.insert(Animated, { part = coals, kind = "flicker", base = coals.CFrame, light = light })
		if name == "Smeltery" then
			sparkles(coals, Color3.fromRGB(255, 140, 40), 8, 0.5)
		end
	elseif name == "TanningRack" then
		for _, x in ipairs({ -2.2, 2.2 }) do
			local post = makePart(name .. "_Post", Vector3.new(0.6, 5.5, 0.6), pos + Vector3.new(x, 3.4, 0), "Brown", parent)
			post.Material = Enum.Material.Wood
		end
		local bar = makePart(name .. "_Bar", Vector3.new(5.4, 0.5, 0.5), pos + Vector3.new(0, 6, 0), "Brown", parent)
		bar.Material = Enum.Material.Wood
		local hide = makePart(name .. "_Hide", Vector3.new(3.6, 3.2, 0.25), pos + Vector3.new(0, 4.2, 0), "Nougat", parent)
		hide.Material = Enum.Material.Fabric
	elseif name == "CraftingBench" then
		local bench = makePart(name .. "_Top", Vector3.new(6, 0.8, 3.6), pos + Vector3.new(0, 3, 0), "Bright yellow", parent)
		bench.Material = Enum.Material.WoodPlanks
		for _, off in ipairs({ Vector3.new(-2.6, 2.2, -1.4), Vector3.new(2.6, 2.2, -1.4), Vector3.new(-2.6, 2.2, 1.4), Vector3.new(2.6, 2.2, 1.4) }) do
			local leg = makePart(name .. "_Leg", Vector3.new(0.6, 1.8, 0.6), pos + off, "Brown", parent)
			leg.Material = Enum.Material.Wood
		end
		local hammer = makePart(name .. "_Hammer", Vector3.new(0.4, 1.6, 0.4), pos + Vector3.new(-1.5, 3.9, 0), "Dark grey", parent)
		hammer.Rotation = Vector3.new(0, 0, 65)
		local saw = makePart(name .. "_Saw", Vector3.new(1.8, 0.15, 0.6), pos + Vector3.new(1.4, 3.6, 0.6), "Institutional white", parent)
		saw.Material = Enum.Material.Metal
	elseif name == "Stonecutter" then
		local slab = makePart(name .. "_Slab", Vector3.new(5.5, 2.2, 4), pos + Vector3.new(0, 2.7, 0), "Medium stone grey", parent)
		slab.Material = Enum.Material.Slate
		local blade = makePart(name .. "_Blade", Vector3.new(0.3, 2.8, 2.8), pos + Vector3.new(0, 4.4, 0), "Institutional white", parent)
		blade.Shape = Enum.PartType.Cylinder
		blade.Material = Enum.Material.Metal
		table.insert(Animated, { part = blade, kind = "spinX", base = blade.CFrame })
	elseif name == "MerchantStall" then
		local counter = makePart(name .. "_Counter", Vector3.new(7, 2.6, 3), pos + Vector3.new(0, 2.7, 0), "Brown", parent)
		counter.Material = Enum.Material.WoodPlanks
		for i = 0, 3 do
			local stripe = makePart(
				name .. "_Awning",
				Vector3.new(1.9, 0.3, 4.6),
				pos + Vector3.new(-2.85 + i * 1.9, 6.4, 0),
				if i % 2 == 0 then "Bright green" else "White",
				parent
			)
			stripe.Material = Enum.Material.Fabric
			stripe.Rotation = Vector3.new(8, 0, 0)
		end
		for _, x in ipairs({ -3.2, 3.2 }) do
			local post = makePart(name .. "_Post", Vector3.new(0.5, 5.5, 0.5), pos + Vector3.new(x, 3.4, 1.8), "Brown", parent)
			post.Material = Enum.Material.Wood
		end
		local bread = makePart(name .. "_Bread", Vector3.new(1.4, 0.8, 0.8), pos + Vector3.new(-1.5, 4.4, 0), "Br. yellowish orange", parent)
		bread.Shape = Enum.PartType.Cylinder
	elseif name == "ExchangeBoard" then
		local board = makePart(name .. "_Board", Vector3.new(5, 5.5, 0.8), pos + Vector3.new(0, 4.4, 0), "Brown", parent)
		board.Material = Enum.Material.WoodPlanks
		local paper = makePart(name .. "_Paper", Vector3.new(3.6, 3.6, 0.2), pos + Vector3.new(0, 4.6, 0.5), "Institutional white", parent)
		local _ = paper
	elseif name == "RebirthShrine" then
		local pedestal = makePart(name .. "_Pedestal", Vector3.new(5, 2.6, 5), pos + Vector3.new(0, 2.6, 0), "Medium stone grey", parent)
		pedestal.Material = Enum.Material.Slate
		local crystal = makePart(name .. "_Crystal", Vector3.new(2.4, 4, 2.4), pos + Vector3.new(0, 7, 0), "Royal purple", parent)
		crystal.Material = Enum.Material.Neon
		crystal.Transparency = 0.15
		crystal.Rotation = Vector3.new(45, 0, 45)
		table.insert(Animated, { part = crystal, kind = "floatSpin", base = crystal.CFrame })
		sparkles(crystal, Color3.fromRGB(190, 110, 255), 16, 0.9)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(170, 70, 255)
		light.Range = 22
		light.Brightness = 1.6
		light.Parent = crystal
	elseif name == "EggStand" then
		local nest = makePart(name .. "_Nest", Vector3.new(1.6, 6.5, 6.5), pos + Vector3.new(0, 2, 0), "Dark taupe", parent)
		nest.Shape = Enum.PartType.Cylinder
		nest.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		nest.Material = Enum.Material.Wood
		local eggColors: { { c: Color3, off: Vector3 } } = {
			{ c = Color3.fromRGB(245, 240, 220), off = Vector3.new(-1.6, 4.2, 0.6) },
			{ c = Color3.fromRGB(110, 200, 110), off = Vector3.new(1.4, 4.2, -0.8) },
			{ c = Color3.fromRGB(170, 90, 240), off = Vector3.new(0.2, 4.4, 1.4) },
		}
		for i, e in ipairs(eggColors) do
			local egg = Instance.new("Part")
			egg.Name = name .. "_Egg" .. i
			egg.Size = Vector3.new(1.7, 2.3, 1.7)
			egg.Position = pos + e.off
			egg.Color = e.c
			egg.Anchored = true
			egg.CanCollide = false
			egg.Shape = Enum.PartType.Ball
			egg.Material = Enum.Material.SmoothPlastic
			egg.Parent = parent
			table.insert(Animated, { part = egg, kind = "bob", base = egg.CFrame })
		end
		sparkles(nest, Color3.fromRGB(255, 200, 255), 10, 0.7)
	end
end

for _, sd in ipairs(stationDefs) do
	buildStation(sd, Stations)
end

-- NPCs with role props
local SKIN = Color3.fromRGB(230, 190, 150)

type NPCDef = { name: string, pos: Vector3, color: string, prop: string? }
local npcDefs: { NPCDef } = {
	{ name = "Guide", pos = Vector3.new(-44, 1, -22), color = "Bright blue", prop = "backpack" },
	{ name = "SawmillMaster", pos = Vector3.new(38, 1, -22), color = "Bright orange", prop = "axe" },
	{ name = "Tanner", pos = Vector3.new(-38, 1, 22), color = "Reddish brown", prop = "hide" },
	{ name = "Blacksmith", pos = Vector3.new(38, 1, 22), color = "Dark grey", prop = "hammer" },
	{ name = "Merchant", pos = Vector3.new(-22, 1, 38), color = "Bright green", prop = "pouch" },
	{ name = "QuestElder", pos = Vector3.new(22, 1, 38), color = "Gold", prop = "staff" },
	{ name = "PortalKeeper", pos = Vector3.new(8, 1, -150), color = "Medium lilac", prop = "orb" },
}

for _, nd in ipairs(npcDefs) do
	local groundPos = Vector3.new(nd.pos.X, 0.6, nd.pos.Z)
	local look = Vector3.new(-nd.pos.X, 0, -nd.pos.Z)
	if look.Magnitude < 1 then
		look = Vector3.new(0, 0, 1)
	end
	local base = CFrame.lookAt(groundPos, groundPos + look.Unit)

	local function npcPart(name: string, size: Vector3, offset: Vector3, color: Color3?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = base * CFrame.new(offset)
		p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if color then
			p.Color = color
		else
			p.BrickColor = BrickColor.new(nd.color :: any)
		end
		p.Parent = NPCs
		return p
	end

	npcPart(nd.name .. "_LegL", Vector3.new(0.9, 1.4, 0.9), Vector3.new(-0.55, 0.7, 0), Color3.fromRGB(70, 70, 80))
	npcPart(nd.name .. "_LegR", Vector3.new(0.9, 1.4, 0.9), Vector3.new(0.55, 0.7, 0), Color3.fromRGB(70, 70, 80))
	local torso = npcPart(nd.name .. "_Body", Vector3.new(2.2, 2, 1.2), Vector3.new(0, 2.4, 0))
	npcPart(nd.name .. "_ArmL", Vector3.new(0.7, 1.9, 0.7), Vector3.new(-1.45, 2.45, 0), SKIN)
	npcPart(nd.name .. "_ArmR", Vector3.new(0.7, 1.9, 0.7), Vector3.new(1.45, 2.45, 0), SKIN)
	local head = npcPart(nd.name .. "_Head", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 4.15, 0), SKIN)
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	npcPart(nd.name .. "_HatBrim", Vector3.new(1.9, 0.2, 1.9), Vector3.new(0, 5, 0))
	npcPart(nd.name .. "_HatTop", Vector3.new(1.2, 0.7, 1.2), Vector3.new(0, 5.45, 0))

	-- Role props
	if nd.prop == "axe" then
		npcPart(nd.name .. "_AxeHandle", Vector3.new(0.3, 2.4, 0.3), Vector3.new(1.85, 2.6, -0.4), Color3.fromRGB(120, 80, 40))
		npcPart(nd.name .. "_AxeHead", Vector3.new(0.9, 0.7, 0.25), Vector3.new(1.85, 3.7, -0.4), Color3.fromRGB(190, 190, 200))
	elseif nd.prop == "hammer" then
		npcPart(nd.name .. "_HammerHandle", Vector3.new(0.3, 2, 0.3), Vector3.new(1.85, 2.5, -0.3), Color3.fromRGB(120, 80, 40))
		npcPart(nd.name .. "_HammerHead", Vector3.new(1, 0.6, 0.6), Vector3.new(1.85, 3.5, -0.3), Color3.fromRGB(80, 80, 90))
		npcPart(nd.name .. "_Apron", Vector3.new(1.8, 1.7, 0.2), Vector3.new(0, 2.2, -0.72), Color3.fromRGB(60, 45, 35))
	elseif nd.prop == "staff" then
		npcPart(nd.name .. "_Staff", Vector3.new(0.35, 5, 0.35), Vector3.new(1.9, 2.5, 0), Color3.fromRGB(110, 80, 50))
		local gem = npcPart(nd.name .. "_Gem", Vector3.new(0.8, 0.8, 0.8), Vector3.new(1.9, 5.2, 0), Color3.fromRGB(255, 215, 0))
		gem.Material = Enum.Material.Neon
		gem.Shape = Enum.PartType.Ball
	elseif nd.prop == "backpack" then
		npcPart(nd.name .. "_Backpack", Vector3.new(1.6, 1.8, 0.8), Vector3.new(0, 2.5, 0.95), Color3.fromRGB(140, 100, 60))
	elseif nd.prop == "pouch" then
		local pouch = npcPart(nd.name .. "_Pouch", Vector3.new(0.9, 0.9, 0.9), Vector3.new(-1.1, 1.6, -0.5), Color3.fromRGB(200, 170, 60))
		pouch.Shape = Enum.PartType.Ball
	elseif nd.prop == "hide" then
		npcPart(nd.name .. "_HideRoll", Vector3.new(0.8, 1.8, 0.8), Vector3.new(-1.85, 2.7, 0), Color3.fromRGB(190, 150, 110))
	elseif nd.prop == "orb" then
		local orb = npcPart(nd.name .. "_Orb", Vector3.new(0.9, 0.9, 0.9), Vector3.new(1.7, 3.6, -0.5), Color3.fromRGB(170, 70, 255))
		orb.Material = Enum.Material.Neon
		orb.Shape = Enum.PartType.Ball
		sparkles(orb, Color3.fromRGB(190, 110, 255), 6, 0.4)
	end

	makeBillboard(head, nd.name, Color3.fromRGB(255, 230, 100))
	local tag = Instance.new("StringValue")
	tag.Name = "NPCId"
	tag.Value = nd.name
	tag.Parent = torso
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk to " .. nd.name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 12
	prompt.Parent = torso
end

-- Faction lore statues
local statueDefs = {
	{ pos = Vector3.new(-16, 0, -66), label = "Human Faction", color = "Bright yellow" },
	{ pos = Vector3.new(0, 0, -69), label = "Angel Faction", color = "White" },
	{ pos = Vector3.new(16, 0, -66), label = "Demon Faction", color = "Bright red" },
}
for _, s in ipairs(statueDefs) do
	local base = makePart("Statue_Base", Vector3.new(5, 4, 5), s.pos + Vector3.new(0, 2.6, 0), s.color)
	base.Material = Enum.Material.Marble
	local pillar = makePart("Statue_Pillar", Vector3.new(2.5, 7, 2.5), s.pos + Vector3.new(0, 8, 0), "Medium stone grey")
	pillar.Material = Enum.Material.Marble
	makeLabel(pillar, s.label)
end

-- ============================================================
-- RESOURCE NODE BUILDERS
-- ============================================================

local function plantTree(pos: Vector3, tier: number, corrupted: boolean, yieldBonus: number?)
	local folder = Instance.new("Folder")
	folder.Name = "Tree_T" .. tostring(tier)
	folder.Parent = Island
	local big = (yieldBonus or 0) > 0
	local scale = if big then 1.8 else 1
	local trunkColor = if corrupted then "Black" elseif big then "Dark taupe" else "Reddish brown"
	local leafColor = if corrupted then "Dark indigo" else (if tier == 1 then "Bright green" else "Dark green")
	local trunk = makePart("Trunk", Vector3.new(2 * scale, (6 + tier * 2) * scale, 2 * scale), pos + Vector3.new(0, (3 + tier) * scale, 0), trunkColor, folder)
	trunk.Material = Enum.Material.Wood
	local leaves = makePart("Leaves", Vector3.new(8 + tier, 6 + tier, 8 + tier) * scale, pos + Vector3.new(0, (8 + tier * 2) * scale, 0), leafColor, folder)
	leaves.Shape = Enum.PartType.Ball
	leaves.Material = Enum.Material.Grass
	local rtag = Instance.new("StringValue")
	rtag.Name = "ResourceType"
	rtag.Value = "raw_wood_t" .. tostring(tier)
	rtag.Parent = trunk
	local xptag = Instance.new("IntValue")
	xptag.Name = "MasteryXP"
	xptag.Value = if corrupted then tier * 2 else tier
	xptag.Parent = trunk
	if yieldBonus and yieldBonus > 0 then
		local ytag = Instance.new("IntValue")
		ytag.Name = "YieldBonus"
		ytag.Value = yieldBonus
		ytag.Parent = trunk
		makeLabel(trunk, "Ancient Tree")
		sparkles(leaves, Color3.fromRGB(170, 255, 170), 4, 0.6)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if big then "Chop Ancient (T" .. tostring(tier) .. ")" else "Chop (T" .. tostring(tier) .. ")"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = if big then 2.5 else 1.5
	prompt.Parent = trunk
end

local function plantNode(pos: Vector3, tier: number, resource: string, actionText: string, corrupted: boolean)
	local folder = Instance.new("Folder")
	folder.Name = resource .. "_T" .. tostring(tier)
	folder.Parent = Island
	local color = if corrupted then "Dark indigo" elseif resource == "raw_ore" then "Dark grey" else "Medium stone grey"
	local node = makePart("Node", Vector3.new(3.5, 3, 3.5), pos + Vector3.new(0, 1.5, 0), color, folder)
	node.Material = Enum.Material.Slate
	node.Shape = Enum.PartType.Ball
	if resource == "raw_ore" then
		-- glinting ore veins
		local vein = makePart("Vein", Vector3.new(1.2, 1.2, 1.2), pos + Vector3.new(0.9, 2.3, 0.6), if tier >= 2 then "Cyan" else "Neon orange", folder)
		vein.Material = Enum.Material.Neon
		vein.Shape = Enum.PartType.Ball
		vein.CanCollide = false
	end
	local rtag = Instance.new("StringValue")
	rtag.Name = "ResourceType"
	rtag.Value = resource .. "_t" .. tostring(tier)
	rtag.Parent = node
	local xptag = Instance.new("IntValue")
	xptag.Name = "MasteryXP"
	xptag.Value = if corrupted then (tier + 1) * 2 else tier + 1
	xptag.Parent = node
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText .. " (T" .. tostring(tier) .. ")"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 2.0
	prompt.Parent = node
end

local function plantPine(pos: Vector3, choppable: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "Pine"
	folder.Parent = if choppable then Island else Decor
	local trunk = makePart("Trunk", Vector3.new(1.6, 6, 1.6), pos + Vector3.new(0, 3, 0), "Reddish brown", folder)
	trunk.Material = Enum.Material.Wood
	if not choppable then
		trunk.CanQuery = false
	end
	local sizes = { 9, 6.5, 4 }
	for i, s in ipairs(sizes) do
		local disc = makePart("Foliage", Vector3.new(1.8, s, s), pos + Vector3.new(0, 5 + i * 2.2, 0), "Dark green", folder)
		disc.Shape = Enum.PartType.Cylinder
		disc.CFrame = CFrame.new(pos + Vector3.new(0, 5 + i * 2.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		disc.Material = Enum.Material.Grass
		disc.CanQuery = false
	end
	local cap = makePart("SnowCap", Vector3.new(2.6, 1, 2.6), pos + Vector3.new(0, 12.2, 0), "White", folder)
	cap.Shape = Enum.PartType.Ball
	cap.CanQuery = false
	if choppable then
		local rtag = Instance.new("StringValue")
		rtag.Name = "ResourceType"
		rtag.Value = "raw_wood_t2"
		rtag.Parent = trunk
		local xptag = Instance.new("IntValue")
		xptag.Name = "MasteryXP"
		xptag.Value = 2
		xptag.Parent = trunk
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Chop Pine (T2)"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 10
		prompt.HoldDuration = 1.5
		prompt.Parent = trunk
	end
end

-- ============================================================
-- DECORATION SCATTER (fills the barren space)
-- ============================================================

local function scatter(count: number, xMin: number, xMax: number, zMin: number, zMax: number, builder: (pos: Vector3) -> ())
	for _ = 1, count do
		local pos = Vector3.new(rng:NextNumber(xMin, xMax), 0, rng:NextNumber(zMin, zMax))
		-- keep the plaza clear
		if math.abs(pos.X) > 85 or math.abs(pos.Z) > 85 then
			builder(pos)
		end
	end
end

local function grassTuft(pos: Vector3)
	local g = decoPart("Grass", Vector3.new(1.4, rng:NextNumber(0.8, 1.6), 1.4), pos + Vector3.new(0, 0.8, 0), Color3.fromRGB(70, rng:NextInteger(150, 200), 70))
	g.Rotation = Vector3.new(0, rng:NextNumber(0, 90), 0)
	g.Material = Enum.Material.Grass
end

local function flower(pos: Vector3)
	local colors = {
		Color3.fromRGB(255, 90, 120),
		Color3.fromRGB(255, 200, 60),
		Color3.fromRGB(150, 110, 255),
		Color3.fromRGB(255, 255, 255),
	}
	decoPart("FlowerStem", Vector3.new(0.2, 1, 0.2), pos + Vector3.new(0, 0.9, 0), Color3.fromRGB(60, 140, 60))
	decoPart("FlowerHead", Vector3.new(0.7, 0.7, 0.7), pos + Vector3.new(0, 1.5, 0), colors[rng:NextInteger(1, #colors)], Enum.PartType.Ball)
end

local function bush(pos: Vector3)
	local b = decoPart("Bush", Vector3.new(rng:NextNumber(2.5, 4), rng:NextNumber(1.8, 2.6), rng:NextNumber(2.5, 4)), pos + Vector3.new(0, 1.2, 0), Color3.fromRGB(50, rng:NextInteger(120, 160), 60), Enum.PartType.Ball)
	b.Material = Enum.Material.Grass
end

local function pebble(pos: Vector3)
	local s = rng:NextNumber(0.8, 2)
	local p = decoPart("Pebble", Vector3.new(s, s * 0.7, s), pos + Vector3.new(0, s * 0.3, 0), Color3.fromRGB(140, 140, 145), Enum.PartType.Ball)
	p.Material = Enum.Material.Slate
end

local function mushroom(pos: Vector3)
	decoPart("MushStem", Vector3.new(0.5, 1, 0.5), pos + Vector3.new(0, 0.9, 0), Color3.fromRGB(235, 225, 205))
	local cap = decoPart("MushCap", Vector3.new(1.4, 0.8, 1.4), pos + Vector3.new(0, 1.6, 0), Color3.fromRGB(220, 60, 60), Enum.PartType.Ball)
	local _ = cap
end

local function fallenLog(pos: Vector3)
	local log = decoPart("FallenLog", Vector3.new(rng:NextNumber(4, 7), 1.4, 1.4), pos + Vector3.new(0, 0.8, 0), Color3.fromRGB(110, 75, 45), Enum.PartType.Cylinder)
	log.Material = Enum.Material.Wood
	log.Rotation = Vector3.new(0, rng:NextNumber(0, 180), 0)
end

local function cactus(pos: Vector3)
	local h = rng:NextNumber(3, 5.5)
	local body = decoPart("Cactus", Vector3.new(1.4, h, 1.4), pos + Vector3.new(0, h / 2 + 0.4, 0), Color3.fromRGB(70, 150, 80))
	body.Material = Enum.Material.Grass
	if rng:NextNumber() < 0.6 then
		local arm = decoPart("CactusArm", Vector3.new(0.9, 2, 0.9), pos + Vector3.new(1.1, h * 0.6, 0), Color3.fromRGB(70, 150, 80))
		arm.Material = Enum.Material.Grass
	end
	if rng:NextNumber() < 0.3 then
		decoPart("CactusFlower", Vector3.new(0.6, 0.6, 0.6), pos + Vector3.new(0, h + 0.7, 0), Color3.fromRGB(255, 120, 180), Enum.PartType.Ball)
	end
end

local function desertRock(pos: Vector3)
	local s = rng:NextNumber(1.5, 3.5)
	local r = decoPart("DesertRock", Vector3.new(s, s * 0.8, s * 1.2), pos + Vector3.new(0, s * 0.35, 0), Color3.fromRGB(190, 160, 120))
	r.Material = Enum.Material.Sandstone
	r.Rotation = Vector3.new(0, rng:NextNumber(0, 90), 0)
end

local function deadBush(pos: Vector3)
	local b = decoPart("DeadBush", Vector3.new(1.8, 1.4, 1.8), pos + Vector3.new(0, 0.9, 0), Color3.fromRGB(150, 120, 80), Enum.PartType.Ball)
	b.Material = Enum.Material.Wood
end

local function snowPile(pos: Vector3)
	local s = rng:NextNumber(2, 4.5)
	local p = decoPart("SnowPile", Vector3.new(s, s * 0.5, s), pos + Vector3.new(0, s * 0.18, 0), Color3.fromRGB(240, 245, 255), Enum.PartType.Ball)
	p.Material = Enum.Material.Sand
end

local function iceCrystal(pos: Vector3)
	local h = rng:NextNumber(2, 4)
	local c = decoPart("IceCrystal", Vector3.new(1, h, 1), pos + Vector3.new(0, h / 2 + 0.3, 0), Color3.fromRGB(150, 220, 255))
	c.Material = Enum.Material.Ice
	c.Rotation = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(0, 90), rng:NextNumber(-12, 12))
	c.Transparency = 0.2
end

-- Central meadows (default green zone around the village)
scatter(160, -450, 450, -200, 200, grassTuft)
scatter(70, -350, 350, -180, 180, flower)
scatter(35, -400, 400, -190, 190, bush)
scatter(30, -400, 400, -190, 190, pebble)

-- FOREST (west)
scatter(140, -940, -140, -480, 480, grassTuft)
scatter(60, -900, -160, -460, 460, flower)
scatter(50, -900, -160, -460, 460, bush)
scatter(30, -900, -200, -440, 440, mushroom)
scatter(14, -880, -220, -420, 420, fallenLog)

-- DESERT (south + east)
scatter(45, -700, 850, 220, 920, cactus)
scatter(45, -700, 880, 200, 930, desertRock)
scatter(30, -650, 850, 240, 900, deadBush)
scatter(28, 360, 930, -120, 200, cactus)
scatter(25, 380, 930, -130, 200, desertRock)

-- SNOW (north)
scatter(55, -420, 900, -930, -250, snowPile)
scatter(35, -400, 880, -920, -260, iceCrystal)
for _ = 1, 55 do
	local pos = Vector3.new(rng:NextNumber(-420, 900), 0, rng:NextNumber(-920, -260))
	plantPine(pos, false)
end

-- ============================================================
-- FOREST biome resources (wood is king)
-- ============================================================

for _ = 1, 70 do
	local pos = Vector3.new(rng:NextNumber(-420, -130), 0, rng:NextNumber(-260, 260))
	plantTree(pos, 1, false)
end
for _ = 1, 55 do
	local pos = Vector3.new(rng:NextNumber(-760, -420), 0, rng:NextNumber(-380, 380))
	plantTree(pos, 2, false)
end
for _ = 1, 14 do
	local pos = Vector3.new(rng:NextNumber(-900, -560), 0, rng:NextNumber(-300, 300))
	plantTree(pos, 2, false, 2)
end
-- A few trees ringing the village so q1 is close by
for i = 1, 12 do
	local angle = (i / 12) * math.pi * 2
	local r = 105 + rng:NextNumber(-8, 12)
	plantTree(Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), 1, false)
end

-- ============================================================
-- SNOW biome resources (ore is king) + Frozen Mine + boss arena
-- ============================================================

for _ = 1, 20 do
	local pos = Vector3.new(rng:NextNumber(-350, 400), 0, rng:NextNumber(-850, -350))
	plantNode(pos, if rng:NextNumber() < 0.35 then 2 else 1, "raw_ore", "Mine", false)
end
for _ = 1, 8 do
	local pos = Vector3.new(rng:NextNumber(-300, 350), 0, rng:NextNumber(-800, -380))
	plantNode(pos, 1, "raw_stone", "Quarry", false)
end
for _ = 1, 12 do
	local pos = Vector3.new(rng:NextNumber(-380, 420), 0, rng:NextNumber(-880, -300))
	plantPine(pos, true)
end

-- Frozen Mine (walled quarry, dense T2 ore)
do
	local center = Vector3.new(600, 0, -600)
	local caveFloor = makePart("CaveFloor", Vector3.new(320, 0.4, 320), center + Vector3.new(0, 0.3, 0), "Light blue")
	caveFloor.Material = Enum.Material.Ice

	for i = 0, 23 do
		local angle = (i / 24) * math.pi * 2
		local towardVillage = math.atan2(-center.Z, -center.X)
		local diff = math.abs(math.atan2(math.sin(angle - towardVillage), math.cos(angle - towardVillage)))
		if diff > 0.4 then
			local wallPos = center + Vector3.new(math.cos(angle) * 150, 9, math.sin(angle) * 150)
			local wall = makePart("CaveWall", Vector3.new(42, 20, 14), wallPos, "Light blue")
			wall.Material = Enum.Material.Ice
			wall.CFrame = CFrame.lookAt(wallPos, Vector3.new(center.X, 9, center.Z))
		end
	end

	for _ = 1, 24 do
		local pos = center + Vector3.new(rng:NextNumber(-130, 130), 0, rng:NextNumber(-130, 130))
		plantNode(pos, if rng:NextNumber() < 0.55 then 2 else 1, "raw_ore", "Mine", false)
	end
	for _ = 1, 10 do
		local pos = center + Vector3.new(rng:NextNumber(-130, 130), 0, rng:NextNumber(-130, 130))
		plantNode(pos, 2, "raw_stone", "Quarry", false)
	end
	makeLabel(makePart("CaveSign", Vector3.new(1, 5, 1), center + Vector3.new(-110, 3, 110), "Light blue"), "The Frozen Mine — rich ore inside")
end

-- Beast boss arena (snow, guards the portal)
for i = 1, 10 do
	local angle = (i / 10) * math.pi * 2
	local pillar = makePart(
		"ArenaPillar",
		Vector3.new(3, 10, 3),
		Vector3.new(math.cos(angle) * 38, 5.6, -230 + math.sin(angle) * 38),
		"Light blue"
	)
	pillar.Material = Enum.Material.Ice
end

-- ============================================================
-- DESERT biome resources (stone is king) + fortress + oasis
-- ============================================================

for _ = 1, 26 do
	local pos = Vector3.new(rng:NextNumber(-550, 800), 0, rng:NextNumber(250, 880))
	plantNode(pos, if rng:NextNumber() < 0.3 then 2 else 1, "raw_stone", "Quarry", false)
end
for _ = 1, 16 do
	local pos = Vector3.new(rng:NextNumber(400, 900), 0, rng:NextNumber(-100, 180))
	plantNode(pos, 1, "raw_stone", "Quarry", false)
end
for _ = 1, 8 do
	local pos = Vector3.new(rng:NextNumber(-450, 700), 0, rng:NextNumber(300, 850))
	plantNode(pos, 1, "raw_ore", "Mine", false)
end

-- Bandit Fortress
do
	local center = Vector3.new(0, 0, 630)
	local wallDefs = {
		{ size = Vector3.new(70, 14, 4), off = Vector3.new(-55, 7, -90) },
		{ size = Vector3.new(70, 14, 4), off = Vector3.new(55, 7, -90) },
		{ size = Vector3.new(184, 14, 4), off = Vector3.new(0, 7, 90) },
		{ size = Vector3.new(4, 14, 184), off = Vector3.new(-90, 7, 0) },
		{ size = Vector3.new(4, 14, 184), off = Vector3.new(90, 7, 0) },
	}
	for _, w in ipairs(wallDefs) do
		local wall = makePart("FortWall", w.size, center + w.off, "Brick yellow")
		wall.Material = Enum.Material.Sandstone
	end
	for i = -1, 1 do
		local hut = makePart("FortHut", Vector3.new(12, 8, 12), center + Vector3.new(i * 34, 4.6, 30), "Brown")
		hut.Material = Enum.Material.Wood
	end
	local throne = makePart("BanditThrone", Vector3.new(6, 8, 4), center + Vector3.new(0, 4.6, 60), "Really black")
	makeLabel(throne, "Bandit Lord's Throne")
	local brazier1 = makePart("Brazier", Vector3.new(2, 3, 2), center + Vector3.new(-8, 2.1, -88), "Dark grey")
	fire(brazier1, Color3.fromRGB(255, 120, 30))
	local brazier2 = makePart("Brazier", Vector3.new(2, 3, 2), center + Vector3.new(8, 2.1, -88), "Dark grey")
	fire(brazier2, Color3.fromRGB(255, 120, 30))
	makeLabel(makePart("FortSign", Vector3.new(1, 5, 1), center + Vector3.new(0, 3, -100), "Brick yellow"), "BANDIT FORTRESS — boss inside")
end

-- Oasis lake (fishing)
do
	local center = Vector3.new(520, 0, 470)
	local lake = makePart("Lake", Vector3.new(1.2, 180, 180), center + Vector3.new(0, -0.3, 0), "Bright blue")
	lake.Material = Enum.Material.Glass
	lake.Transparency = 0.35
	lake.Shape = Enum.PartType.Cylinder
	lake.CFrame = CFrame.new(center + Vector3.new(0, -0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))

	-- Palm trees around the oasis
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2 + 0.3
		local pos = center + Vector3.new(math.cos(angle) * 105, 0, math.sin(angle) * 105)
		local trunk = decoPart("PalmTrunk", Vector3.new(1.2, 9, 1.2), pos + Vector3.new(0, 4.7, 0), Color3.fromRGB(160, 120, 70))
		trunk.Material = Enum.Material.Wood
		trunk.Rotation = Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		for j = 1, 4 do
			local leafAngle = (j / 4) * math.pi * 2
			local leaf = decoPart(
				"PalmLeaf",
				Vector3.new(5, 0.3, 1.6),
				pos + Vector3.new(math.cos(leafAngle) * 2.4, 9.4, math.sin(leafAngle) * 2.4),
				Color3.fromRGB(70, 170, 80)
			)
			leaf.Material = Enum.Material.Grass
			leaf.Rotation = Vector3.new(0, math.deg(leafAngle), 12)
		end
	end

	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * 95, 0, math.sin(angle) * 95)
		local post = makePart("FishingSpot", Vector3.new(2, 4, 2), pos + Vector3.new(0, 2.2, 0), "Brown")
		post.Material = Enum.Material.Wood
		local rtag = Instance.new("StringValue")
		rtag.Name = "ResourceType"
		rtag.Value = "raw_fish"
		rtag.Parent = post
		local xptag = Instance.new("IntValue")
		xptag.Name = "MasteryXP"
		xptag.Value = 2
		xptag.Parent = post
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Fish"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 10
		prompt.HoldDuration = 3
		prompt.Parent = post
		sparkles(post, Color3.fromRGB(150, 220, 255), 3, 0.4)
	end
	makeLabel(makePart("LakeSign", Vector3.new(1, 4, 1), center + Vector3.new(-100, 2.6, -100), "Brown"), "Oasis Lake — Fishing")
end

-- ============================================================
-- SEALED FACTION GATES
-- ============================================================

local function sealedGate(pos: Vector3, name: string, color: string, glowColor: Color3)
	local frame = makePart(name .. "_Frame", Vector3.new(40, 36, 6), pos + Vector3.new(0, 18, 0), color)
	frame.Material = Enum.Material.Marble
	frame.CFrame = CFrame.lookAt(pos + Vector3.new(0, 18, 0), Vector3.new(0, 18, 0))
	local door = makePart(name .. "_Door", Vector3.new(26, 28, 2), pos + Vector3.new(0, 14, 0), "Really black")
	door.Material = Enum.Material.Metal
	door.CFrame = frame.CFrame
	makeBillboard(frame, name .. "\n[ Coming Soon ]", Color3.fromRGB(255, 230, 100))
	sparkles(door, glowColor, 8, 1)
end

sealedGate(Vector3.new(-200, 0, -930), "ANGEL GATE", "White", Color3.fromRGB(255, 255, 200))
sealedGate(Vector3.new(930, 0, 250), "DEMON GATE", "Bright red", Color3.fromRGB(255, 60, 60))

-- ============================================================
-- PORTALS
-- ============================================================

local function buildPortal(parent: Folder, basePos: Vector3, innerName: string, labelText: string, actionText: string)
	local base = makePart(innerName .. "_BasePad", Vector3.new(24, 2, 24), basePos + Vector3.new(0, 0.5, 0), "Dark purple", parent)
	base.Material = Enum.Material.Neon
	local frame = makePart(innerName .. "_Frame", Vector3.new(24, 28, 2.4), basePos + Vector3.new(0, 7, 0), "Black", parent)
	frame.Material = Enum.Material.SmoothPlastic
	local inner = makePart(innerName, Vector3.new(18, 22, 1.2), basePos + Vector3.new(0, 7, 0), "Dark purple", parent)
	inner.Material = Enum.Material.Neon
	inner.Transparency = 0.5
	inner.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.Enabled = true
	prompt.Parent = inner
	makeLabel(frame, labelText)

	local pe = sparkles(inner, Color3.fromRGB(180, 80, 255), 14, 1.2)
	pe.Speed = NumberRange.new(2, 5)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 70, 255)
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = inner
end

buildPortal(Portals, Vector3.new(0, 0, -300), "CorruptedPortal_Inner", "Corrupted Portal\nBeast Seal required", "Enter Corrupted Portal")

local villageSpawn = makePart("VillageSpawn", Vector3.new(2, 1, 2), Vector3.new(0, 1, 20), "Bright green", Portals)
villageSpawn.Transparency = 1
villageSpawn.CanCollide = false

local corruptedSpawn = makePart("CorruptedSpawn", Vector3.new(2, 1, 2), CORRUPT_OFFSET + Vector3.new(0, 1, 30), "Bright red", Portals)
corruptedSpawn.Transparency = 1
corruptedSpawn.CanCollide = false

local pval = Instance.new("BoolValue")
pval.Name = "PortalUnlocked"
pval.Value = false
pval.Parent = Portals

-- ============================================================
-- CORRUPTED ISLAND (New Game+)
-- ============================================================

local cGround = makePart("CorruptedGround", Vector3.new(620, 2, 620), CORRUPT_OFFSET + Vector3.new(0, -1, 0), "Dark indigo")
cGround.Material = Enum.Material.Slate

local cPlaza = makePart("CorruptedPlaza", Vector3.new(80, 0.5, 80), CORRUPT_OFFSET + Vector3.new(0, 0.4, 0), "Black")
cPlaza.Material = Enum.Material.SmoothPlastic

buildPortal(Portals, CORRUPT_OFFSET + Vector3.new(0, 0, -34), "ReturnPortal_Inner", "Return Portal\nBack to the village", "Return to Village")

local corruptedStationNames: { [string]: boolean } = { Sawmill = true, TanningRack = true, Forge = true, CraftingBench = true }
local cOffsets: { Vector3 } = {
	Vector3.new(-28, 0, 10),
	Vector3.new(28, 0, 10),
	Vector3.new(-28, 0, 30),
	Vector3.new(28, 0, 30),
}
local ci = 1
for _, sd in ipairs(stationDefs) do
	if corruptedStationNames[sd.name] then
		buildStation(sd, Stations, CORRUPT_OFFSET + cOffsets[ci])
		ci += 1
	end
end

for _ = 1, 36 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(90, 270)
	plantTree(CORRUPT_OFFSET + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), 2, true)
end
for _ = 1, 14 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(90, 260)
	plantNode(CORRUPT_OFFSET + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), 2, "raw_ore", "Mine", true)
end
for _ = 1, 10 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(90, 260)
	plantNode(CORRUPT_OFFSET + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), 2, "raw_stone", "Quarry", true)
end

-- Corrupted ambience: floating purple crystals
for _ = 1, 18 do
	local angle = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(60, 280)
	local pos = CORRUPT_OFFSET + Vector3.new(math.cos(angle) * r, rng:NextNumber(4, 12), math.sin(angle) * r)
	local c = decoPart("VoidCrystal", Vector3.new(1.4, 3, 1.4), pos, Color3.fromRGB(140, 60, 220))
	c.Material = Enum.Material.Neon
	c.Transparency = 0.25
	c.Rotation = Vector3.new(rng:NextNumber(0, 45), rng:NextNumber(0, 90), rng:NextNumber(0, 45))
	table.insert(Animated, { part = c, kind = "floatSpin", base = c.CFrame })
end

-- ============================================================
-- ANIMATION LOOP (blades spin, eggs bob, crystals float, fires flicker)
-- ============================================================

task.spawn(function()
	while true do
		local dt = task.wait(0.05)
		local t = os.clock()
		for _, a in ipairs(Animated) do
			if a.part.Parent then
				if a.kind == "spinX" then
					a.part.CFrame = a.base * CFrame.Angles(t * 4 % (math.pi * 2), 0, 0)
				elseif a.kind == "floatSpin" then
					a.part.CFrame = a.base * CFrame.new(0, math.sin(t * 1.5) * 0.8, 0) * CFrame.Angles(0, t % (math.pi * 2), 0)
				elseif a.kind == "bob" then
					a.part.CFrame = a.base * CFrame.new(0, math.sin(t * 2 + a.base.Position.X) * 0.35, 0)
				elseif a.kind == "flicker" and a.light then
					a.light.Brightness = 1.6 + math.sin(t * 9 + a.base.Position.X) * 0.5
				end
			end
		end
		local _ = dt
	end
end)

local _ = TweenService

print("[IslandGenerator] 2000x2000 three-biome island built.")
