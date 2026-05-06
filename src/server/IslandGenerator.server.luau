--!strict
-- IslandGenerator: Expanded tutorial island with multiple biomes (512x512 stud play space)

local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

if not RunService:IsServer() then
	return
end

-- Expanded map dimensions
local ISLAND_HALF = 256
local PLAZA_SIZE = 120
local WATER_HALF = 300
local BIOME_SIZE = 180

local Island = Instance.new("Folder")
Island.Name = "Island"
Island.Parent = workspace

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

local function makePart(
	name: string,
	size: Vector3,
	position: Vector3,
	colorName: string,
	anchored: boolean?,
	parent: Instance?,
	shape: string?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.BrickColor = BrickColor.new(colorName)
	p.Anchored = if anchored == nil then true else anchored
	p.Parent = parent or Island
	if shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function makeBillboard(part: BasePart, text: string, color: Color3?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 160, 0, 44)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = false
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
	return bb
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

-- Ground (top surface y = 0). Avoid overlapping other parts at y=0 to prevent z-fighting flicker.
local ground = makePart("Ground", Vector3.new(ISLAND_HALF * 2, 2, ISLAND_HALF * 2), Vector3.new(0, -1, 0), "Bright green", true, Island)
ground.Material = Enum.Material.Grass
ground.CastShadow = false

-- Create multiple biomes
local function createBiome(name: string, offset: Vector3, size: number, groundColor: string, groundMaterial: Enum.Material)
	local biomeFolder = Instance.new("Folder")
	biomeFolder.Name = name
	biomeFolder.Parent = Island
	
	local biomeGround = makePart(name .. "_Ground", Vector3.new(size, 2, size), offset + Vector3.new(0, -1, 0), groundColor, true, biomeFolder)
	biomeGround.Material = groundMaterial
	biomeGround.CastShadow = false
	
	return biomeFolder
end

-- Forest biome (northwest)
local forestBiome = createBiome("Forest", Vector3.new(-180, 0, -180), BIOME_SIZE, "Bright green", Enum.Material.Grass)

-- Mountain biome (northeast)
local mountainBiome = createBiome("Mountain", Vector3.new(180, 0, -180), BIOME_SIZE, "Medium stone grey", Enum.Material.Stone)

-- Plains biome (southwest)
local plainsBiome = createBiome("Plains", Vector3.new(-180, 0, 180), BIOME_SIZE, "Sand yellow", Enum.Material.Sand)

-- Swamp biome (southeast)
local swampBiome = createBiome("Swamp", Vector3.new(180, 0, 180), BIOME_SIZE, "Dark green", Enum.Material.Grass)

local water = makePart("Water", Vector3.new(WATER_HALF * 2, 1, WATER_HALF * 2), Vector3.new(0, -4.5, 0), "Bright blue", true, Island)
water.Material = Enum.Material.SmoothPlastic
water.Transparency = 0.45
water.CastShadow = false

-- Plaza sits clearly above grass top (y=0): bottom ~0.15
local plaza = makePart("VillagePlaza", Vector3.new(PLAZA_SIZE, 0.5, PLAZA_SIZE), Vector3.new(0, 0.4, 0), "Tan", true, Island)
plaza.Material = Enum.Material.SmoothPlastic
plaza.CastShadow = false

local function makePath(p1: Vector3, p2: Vector3, width: number)
	local mid = (p1 + p2) / 2
	local length = (p2 - p1).Magnitude
	local dir = (p2 - p1).Unit
	local pathHeight = 0.25
	local pathY = 0.12 + pathHeight / 2
	local path = makePart("Path", Vector3.new(width, pathHeight, length), mid + Vector3.new(0, pathY, 0), "Sand yellow", true, Island)
	path.Material = Enum.Material.SmoothPlastic
	path.CastShadow = false
	path.CFrame = CFrame.lookAt(mid + Vector3.new(0, pathY, 0), mid + dir + Vector3.new(0, pathY, 0))
end

-- Cardinal paths (~400 studs from center toward edges for ~25s walks)
local pathEnd = 400
makePath(Vector3.new(0, 0, PLAZA_SIZE / 2), Vector3.new(0, 0, pathEnd), 12)
makePath(Vector3.new(0, 0, -PLAZA_SIZE / 2), Vector3.new(0, 0, -pathEnd), 12)
makePath(Vector3.new(PLAZA_SIZE / 2, 0, 0), Vector3.new(pathEnd, 0, 0), 12)
makePath(Vector3.new(-PLAZA_SIZE / 2, 0, 0), Vector3.new(-pathEnd, 0, 0), 12)

-- Diagonal paths to biomes
makePath(Vector3.new(-30, 0, -30), Vector3.new(-180, 0, -180), 10)
makePath(Vector3.new(30, 0, -30), Vector3.new(180, 0, -180), 10)
makePath(Vector3.new(-30, 0, 30), Vector3.new(-180, 0, 180), 10)
makePath(Vector3.new(30, 0, 30), Vector3.new(180, 0, 180), 10)

-- Faction statues (plaza corners)
local statuePositions = {
	{ pos = Vector3.new(-38, 1, -38), label = "Human Faction", color = "Bright yellow" },
	{ pos = Vector3.new(38, 1, -38), label = "Angel Faction", color = "White" },
	{ pos = Vector3.new(0, 1, -42), label = "Demon Faction", color = "Bright red" },
}
for _, s in ipairs(statuePositions) do
	local base = makePart("Statue_Base", Vector3.new(5, 4, 5), s.pos, s.color, true, Island)
	base.Material = Enum.Material.SmoothPlastic
	local pillar = makePart("Statue_Pillar", Vector3.new(2.5, 7, 2.5), s.pos + Vector3.new(0, 5.5, 0), "Medium stone grey", true, Island)
	makeLabel(pillar, s.label)
end

local function makeBuilding(name: string, pos: Vector3, size: Vector3, roofColor: string, wallColor: string)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Island
	local walls = makePart("Walls", size, pos + Vector3.new(0, size.Y / 2, 0), wallColor, true, folder)
	walls.Material = Enum.Material.SmoothPlastic
	local roof = Instance.new("WedgePart")
	roof.Name = "Roof"
	roof.Size = Vector3.new(size.X + 2, size.Y * 0.55, size.Z / 2 + 1)
	roof.CFrame = CFrame.new(pos + Vector3.new(0, size.Y + roof.Size.Y / 2, 0))
	roof.BrickColor = BrickColor.new(roofColor)
	roof.Anchored = true
	roof.Material = Enum.Material.SmoothPlastic
	roof.Parent = folder
	local roof2 = roof:Clone()
	roof2.CFrame = CFrame.lookAt(
		pos + Vector3.new(0, size.Y + roof.Size.Y / 2, 0),
		pos + Vector3.new(0, size.Y + roof.Size.Y / 2, 0) - Vector3.new(0, 0, 1)
	)
	roof2.Parent = folder
	return folder
end

-- Village ring (inner district)
makeBuilding("Guide_House", Vector3.new(-52, 0, -8), Vector3.new(14, 9, 14), "Bright blue", "White")
makeBuilding("Sawmill_House", Vector3.new(52, 0, -8), Vector3.new(16, 9, 14), "Bright orange", "Bright yellow")
makeBuilding("Tanner_House", Vector3.new(-8, 0, 52), Vector3.new(14, 9, 14), "Reddish brown", "Sand yellow")
makeBuilding("Blacksmith_House", Vector3.new(-8, 0, -52), Vector3.new(16, 9, 14), "Dark grey", "Medium stone grey")
makeBuilding("Merchant_House", Vector3.new(-52, 0, 52), Vector3.new(14, 9, 14), "Bright green", "White")
makeBuilding("QuestElder_House", Vector3.new(52, 0, 52), Vector3.new(14, 9, 14), "Gold", "Tan")

-- Stations along paths (spread; crafting loop ~150–220 studs)
local stationDefs = {
	{ name = "Sawmill", pos = Vector3.new(210, 1, 35), color = "Bright orange", size = Vector3.new(8, 5, 10) },
	{ name = "TanningRack", pos = Vector3.new(-35, 1, 210), color = "Reddish brown", size = Vector3.new(6, 4, 4) },
	{ name = "Forge", pos = Vector3.new(-210, 1, -35), color = "Dark grey", size = Vector3.new(8, 5, 8) },
	{ name = "CraftingBench", pos = Vector3.new(35, 1, -210), color = "Bright yellow", size = Vector3.new(6, 3, 4) },
	{ name = "MerchantStall", pos = Vector3.new(-150, 1, -150), color = "Bright green", size = Vector3.new(8, 4, 6) },
	{ name = "ExchangeBoard", pos = Vector3.new(150, 1, -150), color = "Medium stone grey", size = Vector3.new(5, 6, 1) },
}
for _, sd in ipairs(stationDefs) do
	local sp = makePart(sd.name, sd.size, sd.pos, sd.color, true, Stations)
	sp.Material = Enum.Material.SmoothPlastic
	makeLabel(sp, sd.name)
	local tag = Instance.new("StringValue")
	tag.Name = "StationType"
	tag.Value = sd.name
	tag.Parent = sp
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use " .. sd.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.Parent = sp
	if sd.name == "ExchangeBoard" then
		prompt.ActionText = "Exchange Board (Coming Soon)"
		prompt.Enabled = false
		makeLabel(sp, "Exchange Board\n[Coming Soon]")
	end
end

local npcDefs = {
	{ name = "Guide", pos = Vector3.new(-44, 1, -8), color = "Bright blue" },
	{ name = "SawmillMaster", pos = Vector3.new(44, 1, -8), color = "Bright orange" },
	{ name = "Tanner", pos = Vector3.new(-8, 1, 44), color = "Reddish brown" },
	{ name = "Blacksmith", pos = Vector3.new(-8, 1, -44), color = "Dark grey" },
	{ name = "Merchant", pos = Vector3.new(-44, 1, 44), color = "Bright green" },
	{ name = "QuestElder", pos = Vector3.new(44, 1, 44), color = "Gold" },
	{ name = "PortalKeeper", pos = Vector3.new(0, 1, -125), color = "Medium lilac" },
}

for _, nd in ipairs(npcDefs) do
	local body = makePart(nd.name .. "_Body", Vector3.new(2.2, 3.2, 2.2), nd.pos, nd.color, true, NPCs)
	body.Material = Enum.Material.SmoothPlastic
	local head = makePart(nd.name .. "_Head", Vector3.new(2.2, 2.2, 2.2), nd.pos + Vector3.new(0, 2.6, 0), nd.color, true, NPCs)
	head.Shape = Enum.PartType.Ball
	makeBillboard(head, nd.name, Color3.fromRGB(255, 230, 100))
	local tag = Instance.new("StringValue")
	tag.Name = "NPCId"
	tag.Value = nd.name
	tag.Parent = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk to " .. nd.name
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 12
	prompt.Parent = body
end

math.randomseed(os.time())

local function plantTree(pos: Vector3, tier: number, isCorrupted: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "Tree_T" .. tostring(tier)
	folder.Parent = Island
	local trunkColor = if isCorrupted then "Dark grey" else "Reddish brown"
	local leafColor = if isCorrupted then "Black" else (if tier == 1 then "Bright green" else "Dark green")
	local trunk = makePart("Trunk", Vector3.new(2, 6 + tier * 2, 2), pos + Vector3.new(0, 3 + tier, 0), trunkColor, true, folder)
	trunk.Material = Enum.Material.Wood
	local leaves = makePart("Leaves", Vector3.new(8 + tier, 6 + tier, 8 + tier), pos + Vector3.new(0, 8 + tier * 2, 0), leafColor, true, folder)
	leaves.Shape = Enum.PartType.Ball
	leaves.Material = Enum.Material.Grass
	local rtag = Instance.new("StringValue")
	rtag.Name = "ResourceType"
	rtag.Value = "raw_wood_t" .. tostring(tier)
	rtag.Parent = trunk
	local xptag = Instance.new("IntValue")
	xptag.Name = "MasteryXP"
	xptag.Value = tier
	xptag.Parent = trunk
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Chop (T" .. tostring(tier) .. ")"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 1.5
	prompt.Parent = trunk
	return folder
end

local function plantOre(pos: Vector3, tier: number, oreType: string)
	local folder = Instance.new("Folder")
	folder.Name = oreType .. "_T" .. tostring(tier)
	folder.Parent = Island
	
	local color = if oreType == "raw_ore" then "Dark grey" else "Medium stone grey"
	local size = Vector3.new(3, 2.5, 3)
	local ore = makePart("Ore", size, pos + Vector3.new(0, 1.25, 0), color, true, folder)
	ore.Material = if oreType == "raw_ore" then Enum.Material.Stone else Enum.Material.Concrete
	ore.Shape = Enum.PartType.Ball
	
	local rtag = Instance.new("StringValue")
	rtag.Name = "ResourceType"
	rtag.Value = oreType .. "_t" .. tostring(tier)
	rtag.Parent = ore
	local xptag = Instance.new("IntValue")
	xptag.Name = "MasteryXP"
	xptag.Value = tier + 1
	xptag.Parent = ore
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Mine (T" .. tostring(tier) .. ")"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 2.0
	prompt.Parent = ore
	return folder
end

local function plantStone(pos: Vector3, tier: number)
	local folder = Instance.new("Folder")
	folder.Name = "Stone_T" .. tostring(tier)
	folder.Parent = Island
	
	local size = Vector3.new(4, 3, 4)
	local stone = makePart("Stone", size, pos + Vector3.new(0, 1.5, 0), "Medium stone grey", true, folder)
	stone.Material = Enum.Material.Stone
	
	local rtag = Instance.new("StringValue")
	rtag.Name = "ResourceType"
	rtag.Value = "raw_stone_t" .. tostring(tier)
	rtag.Parent = stone
	local xptag = Instance.new("IntValue")
	xptag.Name = "MasteryXP"
	xptag.Value = tier
	xptag.Parent = stone
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Quarry (T" .. tostring(tier) .. ")"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 2.5
	prompt.Parent = stone
	return folder
end

-- Expanded tree placement with biome-specific distribution

-- Forest biome (northwest) - Dense T1-T2 trees
for i = 1, 50 do
	local angle = (i / 50) * math.pi * 2
	local radius = 60 + math.random(-30, 30)
	local pos = Vector3.new(-180, 0, -180) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, math.random(1, 2), false)
end

-- Mountain biome (northeast) - Sparse T2 trees, more ore nodes
for i = 1, 20 do
	local angle = (i / 20) * math.pi * 2
	local radius = 60 + math.random(-25, 25)
	local pos = Vector3.new(180, 0, -180) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, 2, false)
end

-- Add ore nodes to mountain biome
for i = 1, 30 do
	local angle = (i / 30) * math.pi * 2
	local radius = 50 + math.random(-20, 20)
	local pos = Vector3.new(180, 0, -180) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantOre(pos, math.random(1, 2), "raw_ore")
end

-- Add stone nodes to mountain biome
for i = 1, 20 do
	local angle = (i / 20) * math.pi * 2
	local radius = 40 + math.random(-15, 15)
	local pos = Vector3.new(180, 0, -180) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantStone(pos, math.random(1, 2))
end

-- Plains biome (southwest) - Moderate T1 trees
for i = 1, 30 do
	local angle = (i / 30) * math.pi * 2
	local radius = 60 + math.random(-20, 20)
	local pos = Vector3.new(-180, 0, 180) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, 1, false)
end

-- Swamp biome (southeast) - Dense T1 trees
for i = 1, 40 do
	local angle = (i / 40) * math.pi * 2
	local radius = 60 + math.random(-25, 25)
	local pos = Vector3.new(180, 0, 180) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, 1, false)
end

-- Central area trees
for i = 1, 15 do
	local angle = (i / 15) * math.pi * 2
	local radius = 140 + math.random(-20, 20)
	local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, 1, false)
end

-- Corrupted portal (north path)
local portalZ = -200
local portalBase = makePart("CorruptedPortal_Base", Vector3.new(12, 1, 12), Vector3.new(0, 0.5, portalZ), "Dark purple", true, Portals)
portalBase.Material = Enum.Material.Neon

local portalFrame = makePart("CorruptedPortal_Frame", Vector3.new(12, 14, 1.2), Vector3.new(0, 7, portalZ), "Black", true, Portals)
portalFrame.Material = Enum.Material.SmoothPlastic

local portalInner = makePart("CorruptedPortal_Inner", Vector3.new(9, 11, 0.6), Vector3.new(0, 7, portalZ), "Dark purple", true, Portals)
portalInner.Material = Enum.Material.Neon
portalInner.Transparency = 0.5

local portalPrompt = Instance.new("ProximityPrompt")
portalPrompt.ActionText = "Enter Corrupted Portal"
portalPrompt.KeyboardKeyCode = Enum.KeyCode.E
portalPrompt.MaxActivationDistance = 12
portalPrompt.Enabled = false
portalPrompt.Parent = portalInner

makeLabel(portalFrame, "Corrupted Portal\n[Locked]")

local pval = Instance.new("BoolValue")
pval.Name = "PortalUnlocked"
pval.Value = false
pval.Parent = Portals

print("[IslandGenerator] Island built successfully.")
