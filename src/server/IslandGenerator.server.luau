--!strict
-- IslandGenerator: Expanded tutorial island with multiple biomes (1024x1024 stud play space)

local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

print("[IslandGenerator] Script loaded, checking server environment...")

if not RunService:IsServer() then
	print("[IslandGenerator] ERROR: Not running on server!")
	return
end

print("[IslandGenerator] Server confirmed, starting generation...")

-- Expanded map dimensions (1024x1024)
local ISLAND_HALF = 512
local PLAZA_SIZE = 160
local WATER_HALF = 600
local BIOME_SIZE = 360

print("[IslandGenerator] Creating workspace folders...")

local Island = Instance.new("Folder")
Island.Name = "Island"
Island.Parent = workspace
print("[IslandGenerator] Island folder created")

local Stations = Instance.new("Folder")
Stations.Name = "Stations"
Stations.Parent = workspace
print("[IslandGenerator] Stations folder created")

local NPCs = Instance.new("Folder")
NPCs.Name = "NPCs"
NPCs.Parent = workspace
print("[IslandGenerator] NPCs folder created")

local Portals = Instance.new("Folder")
Portals.Name = "Portals"
Portals.Parent = workspace
print("[IslandGenerator] Portals folder created")

if not workspace:FindFirstChild("Mobs") then
	local Mobs = Instance.new("Folder")
	Mobs.Name = "Mobs"
	Mobs.Parent = workspace
	print("[IslandGenerator] Mobs folder created")
else
	print("[IslandGenerator] Mobs folder already exists")
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
print("[IslandGenerator] Creating ground...")
local ground = makePart("Ground", Vector3.new(ISLAND_HALF * 2, 2, ISLAND_HALF * 2), Vector3.new(0, -1, 0), "Bright green", true, Island)
ground.Material = Enum.Material.Grass
ground.CastShadow = false
print("[IslandGenerator] Ground created successfully")

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

-- Forest biome (northwest) - scaled for 1024x1024 map
print("[IslandGenerator] Creating Forest biome...")
local forestBiome = createBiome("Forest", Vector3.new(-360, 0, -360), BIOME_SIZE, "Bright green", Enum.Material.Grass)
print("[IslandGenerator] Forest biome created")

-- Mountain biome (northeast) - scaled for 1024x1024 map
print("[IslandGenerator] Creating Mountain biome...")
local mountainBiome = createBiome("Mountain", Vector3.new(360, 0, -360), BIOME_SIZE, "Medium stone grey", Enum.Material.Slate)
print("[IslandGenerator] Mountain biome created")

-- Plains biome (southwest) - scaled for 1024x1024 map
print("[IslandGenerator] Creating Plains biome...")
local plainsBiome = createBiome("Plains", Vector3.new(-360, 0, 360), BIOME_SIZE, "Sand yellow", Enum.Material.Sand)
print("[IslandGenerator] Plains biome created")

-- Swamp biome (southeast) - scaled for 1024x1024 map
print("[IslandGenerator] Creating Swamp biome...")
local swampBiome = createBiome("Swamp", Vector3.new(360, 0, 360), BIOME_SIZE, "Dark green", Enum.Material.Grass)
print("[IslandGenerator] Swamp biome created")

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

-- Cardinal paths (~600 studs from center toward edges for ~35s walks)
local pathEnd = 600
makePath(Vector3.new(0, 0, PLAZA_SIZE / 2), Vector3.new(0, 0, pathEnd), 12)
makePath(Vector3.new(0, 0, -PLAZA_SIZE / 2), Vector3.new(0, 0, -pathEnd), 12)
makePath(Vector3.new(PLAZA_SIZE / 2, 0, 0), Vector3.new(pathEnd, 0, 0), 12)
makePath(Vector3.new(-PLAZA_SIZE / 2, 0, 0), Vector3.new(-pathEnd, 0, 0), 12)

-- Diagonal paths to biomes
makePath(Vector3.new(-30, 0, -30), Vector3.new(-250, 0, -250), 10)
makePath(Vector3.new(30, 0, -30), Vector3.new(250, 0, -250), 10)
makePath(Vector3.new(-30, 0, 30), Vector3.new(-250, 0, 250), 10)
makePath(Vector3.new(30, 0, 30), Vector3.new(250, 0, 250), 10)

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

-- Village ring (inner district) - scaled for larger map
makeBuilding("Guide_House", Vector3.new(-104, 0, -16), Vector3.new(14, 9, 14), "Bright blue", "White")
makeBuilding("Sawmill_House", Vector3.new(104, 0, -16), Vector3.new(16, 9, 14), "Bright orange", "Bright yellow")
makeBuilding("Tanner_House", Vector3.new(-16, 0, 104), Vector3.new(14, 9, 14), "Reddish brown", "Sand yellow")
makeBuilding("Blacksmith_House", Vector3.new(-16, 0, -104), Vector3.new(16, 9, 14), "Dark grey", "Medium stone grey")
makeBuilding("Merchant_House", Vector3.new(-104, 0, 104), Vector3.new(14, 9, 14), "Bright green", "White")
makeBuilding("QuestElder_House", Vector3.new(104, 0, 104), Vector3.new(14, 9, 14), "Gold", "Tan")

-- Stations along paths (spread; crafting loop ~200–400 studs for larger map)
local stationDefs = {
	{ name = "Sawmill", pos = Vector3.new(300, 1, 50), color = "Bright orange", size = Vector3.new(8, 5, 10) },
	{ name = "TanningRack", pos = Vector3.new(-50, 1, 300), color = "Reddish brown", size = Vector3.new(6, 4, 4) },
	{ name = "Forge", pos = Vector3.new(-300, 1, -50), color = "Dark grey", size = Vector3.new(8, 5, 8) },
	{ name = "CraftingBench", pos = Vector3.new(50, 1, -300), color = "Bright yellow", size = Vector3.new(6, 3, 4) },
	{ name = "MerchantStall", pos = Vector3.new(-200, 1, -200), color = "Bright green", size = Vector3.new(8, 4, 6) },
	{ name = "ExchangeBoard", pos = Vector3.new(200, 1, -200), color = "Medium stone grey", size = Vector3.new(5, 6, 1) },
	-- Additional stations for larger map
	{ name = "Smeltery", pos = Vector3.new(180, 1, 180), color = "Dark grey", size = Vector3.new(10, 6, 8) },
	{ name = "Stonecutter", pos = Vector3.new(-180, 1, 180), color = "Medium stone grey", size = Vector3.new(8, 5, 8) },
}
print("[IslandGenerator] Creating production stations...")
for _, sd in ipairs(stationDefs) do
	print("[IslandGenerator] Creating station: " .. sd.name)
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
	print("[IslandGenerator] Station created: " .. sd.name)
end
print("[IslandGenerator] All stations created successfully")

local npcDefs = {
	{ name = "Guide", pos = Vector3.new(-88, 1, -16), color = "Bright blue" },
	{ name = "SawmillMaster", pos = Vector3.new(88, 1, -16), color = "Bright orange" },
	{ name = "Tanner", pos = Vector3.new(-16, 1, 88), color = "Reddish brown" },
	{ name = "Blacksmith", pos = Vector3.new(-16, 1, -88), color = "Dark grey" },
	{ name = "Merchant", pos = Vector3.new(-88, 1, 88), color = "Bright green" },
	{ name = "QuestElder", pos = Vector3.new(88, 1, 88), color = "Gold" },
	{ name = "PortalKeeper", pos = Vector3.new(0, 1, -250), color = "Medium lilac" },
}

print("[IslandGenerator] Creating NPCs...")
for _, nd in ipairs(npcDefs) do
	print("[IslandGenerator] Creating NPC: " .. nd.name)
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
	print("[IslandGenerator] NPC created: " .. nd.name)
end
print("[IslandGenerator] All NPCs created successfully")

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
	ore.Material = if oreType == "raw_ore" then Enum.Material.Slate else Enum.Material.Concrete
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
	stone.Material = Enum.Material.Slate
	
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

-- Forest biome (northwest) - Dense T1-T2 trees (doubled)
print("[IslandGenerator] Creating Forest biome trees...")
for i = 1, 100 do
	local angle = (i / 100) * math.pi * 2
	local radius = 120 + math.random(-40, 40)
	local pos = Vector3.new(-360, 0, -360) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, math.random(1, 2), false)
end
print("[IslandGenerator] Forest trees created: 100")

-- Mountain biome (northeast) - Sparse T2 trees, more ore nodes (doubled)
print("[IslandGenerator] Creating Mountain biome trees...")
for i = 1, 40 do
	local angle = (i / 40) * math.pi * 2
	local radius = 120 + math.random(-40, 40)
	local pos = Vector3.new(360, 0, -360) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, 2, false)
end
print("[IslandGenerator] Mountain trees created: 40")

-- Add ore nodes to mountain biome (doubled)
print("[IslandGenerator] Creating Mountain biome ore nodes...")
for i = 1, 60 do
	local angle = (i / 60) * math.pi * 2
	local radius = 100 + math.random(-30, 30)
	local pos = Vector3.new(360, 0, -360) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantOre(pos, math.random(1, 2), "raw_ore")
end
print("[IslandGenerator] Mountain ore nodes created: 60")

-- Add stone nodes to mountain biome (doubled)
print("[IslandGenerator] Creating Mountain biome stone nodes...")
for i = 1, 40 do
	local angle = (i / 40) * math.pi * 2
	local radius = 80 + math.random(-20, 20)
	local pos = Vector3.new(360, 0, -360) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantStone(pos, math.random(1, 2))
end
print("[IslandGenerator] Mountain stone nodes created: 40")

-- Plains biome (southwest) - Moderate T1 trees (doubled)
print("[IslandGenerator] Creating Plains biome trees...")
for i = 1, 60 do
	local angle = (i / 60) * math.pi * 2
	local radius = 120 + math.random(-30, 30)
	local pos = Vector3.new(-360, 0, 360) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, 1, false)
end
print("[IslandGenerator] Plains trees created: 60")

-- Swamp biome (southeast) - Dense T1 trees (doubled)
print("[IslandGenerator] Creating Swamp biome trees...")
for i = 1, 80 do
	local angle = (i / 80) * math.pi * 2
	local radius = 120 + math.random(-40, 40)
	local pos = Vector3.new(360, 0, 360) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, 1, false)
end
print("[IslandGenerator] Swamp trees created: 80")

-- Central area trees (doubled)
print("[IslandGenerator] Creating Central area trees...")
for i = 1, 30 do
	local angle = (i / 30) * math.pi * 2
	local radius = 280 + math.random(-30, 30)
	local pos = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	plantTree(pos, 1, false)
end
print("[IslandGenerator] Central trees created: 30")

-- Corrupted portal (north path) - scaled for larger map
local portalZ = -400
local portalBase = makePart("CorruptedPortal_Base", Vector3.new(24, 2, 24), Vector3.new(0, 0.5, portalZ), "Dark purple", true, Portals)
portalBase.Material = Enum.Material.Neon

local portalFrame = makePart("CorruptedPortal_Frame", Vector3.new(24, 28, 2.4), Vector3.new(0, 7, portalZ), "Black", true, Portals)
portalFrame.Material = Enum.Material.SmoothPlastic

local portalInner = makePart("CorruptedPortal_Inner", Vector3.new(18, 22, 1.2), Vector3.new(0, 7, portalZ), "Dark purple", true, Portals)
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

print("[IslandGenerator] Island built successfully!")
print("[IslandGenerator] TOTALS CREATED:")
print("[IslandGenerator] - Trees: 310 total (100 Forest, 40 Mountain, 60 Plains, 80 Swamp, 30 Central)")
print("[IslandGenerator] - Ore nodes: 60 total (Mountain biome)")
print("[IslandGenerator] - Stone nodes: 40 total (Mountain biome)")
print("[IslandGenerator] - Production stations: 8 total")
print("[IslandGenerator] - NPCs: 7 total")
print("[IslandGenerator] - Map size: 1024x1024 studs")
print("[IslandGenerator] Generation complete!")
