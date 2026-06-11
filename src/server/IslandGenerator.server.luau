--!strict
-- IslandGenerator: Hand-built Tutorial Island (deterministic layout)
--
-- Layout (main island, 900x900, village at origin):
--   Center  : Village safe zone — NPCs, all crafting stations, statues, exchange board
--   West    : Forest (T1/T2 trees, wolves, Alpha Wolf, Ancient Treant)
--   East    : Rocks (ore + stone nodes, elementals, Mountain Giant)
--   South   : Plains + bandit camp (bandits, Bandit Captain arena)
--   North   : Beast boss arena + Corrupted Portal
-- Corrupted island (NG+) at +3000 X: darker, harder, better rewards.

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local rng = Random.new(42) -- deterministic: same island every server

local CORRUPT_OFFSET = Vector3.new(3000, 0, 0)

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

-- ============================================================
-- TERRAIN
-- ============================================================

local ground = makePart("Ground", Vector3.new(900, 2, 900), Vector3.new(0, -1, 0), "Bright green")
ground.Material = Enum.Material.Grass

local water = makePart("Water", Vector3.new(1400, 1, 1400), Vector3.new(0, -4.5, 0), "Bright blue")
water.Material = Enum.Material.SmoothPlastic
water.Transparency = 0.45
water.CanCollide = false

local plaza = makePart("VillagePlaza", Vector3.new(150, 0.5, 150), Vector3.new(0, 0.4, 0), "Tan")
plaza.Material = Enum.Material.SmoothPlastic

-- East rocky ground patch
local rocky = makePart("RockyGround", Vector3.new(280, 0.4, 360), Vector3.new(260, 0.2, 0), "Medium stone grey")
rocky.Material = Enum.Material.Slate

-- South plains patch
local plains = makePart("PlainsGround", Vector3.new(540, 0.4, 260), Vector3.new(0, 0.2, 280), "Sand yellow")
plains.Material = Enum.Material.Sand

local function makePath(p1: Vector3, p2: Vector3, width: number)
	local mid = (p1 + p2) / 2
	local length = (p2 - p1).Magnitude
	local pathY = 0.55
	local path = makePart("Path", Vector3.new(width, 0.25, length), mid + Vector3.new(0, pathY, 0), "Sand yellow")
	path.Material = Enum.Material.SmoothPlastic
	path.CFrame = CFrame.lookAt(mid + Vector3.new(0, pathY, 0), p2 + Vector3.new(0, pathY, 0))
end

makePath(Vector3.new(0, 0, -75), Vector3.new(0, 0, -320), 12) -- north to portal
makePath(Vector3.new(0, 0, 75), Vector3.new(0, 0, 360), 12) -- south to bandit camp
makePath(Vector3.new(-75, 0, 0), Vector3.new(-380, 0, 0), 12) -- west to forest
makePath(Vector3.new(75, 0, 0), Vector3.new(380, 0, 0), 12) -- east to rocks

-- ============================================================
-- VILLAGE: buildings, NPCs, stations, statues
-- ============================================================

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

	-- Door + windows on the wall facing the village center
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
end

makeBuilding("Guide_House", Vector3.new(-55, 0, -28), Vector3.new(14, 9, 14), "Bright blue", "White")
makeBuilding("Sawmill_House", Vector3.new(55, 0, -28), Vector3.new(16, 9, 14), "Bright orange", "Bright yellow")
makeBuilding("Tanner_House", Vector3.new(-55, 0, 28), Vector3.new(14, 9, 14), "Reddish brown", "Sand yellow")
makeBuilding("Blacksmith_House", Vector3.new(55, 0, 28), Vector3.new(16, 9, 14), "Dark grey", "Medium stone grey")
makeBuilding("Merchant_House", Vector3.new(-28, 0, 55), Vector3.new(14, 9, 14), "Bright green", "White")
makeBuilding("QuestElder_House", Vector3.new(28, 0, 55), Vector3.new(14, 9, 14), "Gold", "Tan")

-- Crafting stations inside the village (clear, kid-readable loop)
type StationDef = { name: string, label: string, pos: Vector3, color: string, size: Vector3, comingSoon: boolean? }
local stationDefs: { StationDef } = {
	{ name = "Sawmill", label = "Sawmill", pos = Vector3.new(44, 0, -14), color = "Bright orange", size = Vector3.new(8, 5, 8) },
	{ name = "TanningRack", label = "Tanning Rack", pos = Vector3.new(-44, 0, 14), color = "Reddish brown", size = Vector3.new(6, 4, 4) },
	{ name = "Forge", label = "Forge", pos = Vector3.new(44, 0, 14), color = "Dark grey", size = Vector3.new(8, 5, 8) },
	{ name = "CraftingBench", label = "Crafting Bench", pos = Vector3.new(0, 0, 36), color = "Bright yellow", size = Vector3.new(6, 3, 4) },
	{ name = "Smeltery", label = "Smeltery", pos = Vector3.new(20, 0, -50), color = "Dark grey", size = Vector3.new(8, 6, 8) },
	{ name = "Stonecutter", label = "Stonecutter", pos = Vector3.new(-20, 0, -50), color = "Medium stone grey", size = Vector3.new(8, 5, 8) },
	{ name = "MerchantStall", label = "Merchant Stall", pos = Vector3.new(-14, 0, 44), color = "Bright green", size = Vector3.new(8, 4, 6) },
	{ name = "ExchangeBoard", label = "Marketplace Board", pos = Vector3.new(14, 0, 44), color = "Medium stone grey", size = Vector3.new(5, 6, 1), comingSoon = true },
}

local function buildStation(sd: StationDef, parent: Folder, posOverride: Vector3?)
	local pos = posOverride or sd.pos
	local sp = makePart(sd.name, sd.size, pos + Vector3.new(0, sd.size.Y / 2 + 0.6, 0), sd.color, parent)
	sp.Material = Enum.Material.SmoothPlastic
	local tag = Instance.new("StringValue")
	tag.Name = "StationType"
	tag.Value = sd.name
	tag.Parent = sp
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use " .. sd.label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.Parent = sp
	if sd.comingSoon then
		prompt.Enabled = false
		makeLabel(sp, sd.label .. "\n[Coming Soon]")
	else
		makeLabel(sp, sd.label)
	end

	-- Per-station accents so each reads at a glance
	if sd.name == "Forge" or sd.name == "Smeltery" then
		local ember = makePart(sd.name .. "_Ember", Vector3.new(2.5, 0.6, 2.5), pos + Vector3.new(0, sd.size.Y + 0.9, 0), "Neon orange", parent)
		ember.Material = Enum.Material.Neon
	elseif sd.name == "Sawmill" then
		local blade = makePart(sd.name .. "_Blade", Vector3.new(0.4, 3.2, 3.2), pos + Vector3.new(0, sd.size.Y + 1.6, 0), "Medium stone grey", parent)
		blade.Shape = Enum.PartType.Cylinder
		blade.Material = Enum.Material.Metal
	elseif sd.name == "TanningRack" then
		local hide = makePart(sd.name .. "_Hide", Vector3.new(3, 2.4, 0.3), pos + Vector3.new(0, sd.size.Y + 1.4, 0), "Nougat", parent)
		hide.Material = Enum.Material.Fabric
	end
end

for _, sd in ipairs(stationDefs) do
	buildStation(sd, Stations)
end

-- NPCs
type NPCDef = { name: string, pos: Vector3, color: string }
local npcDefs: { NPCDef } = {
	{ name = "Guide", pos = Vector3.new(-44, 1, -22), color = "Bright blue" },
	{ name = "SawmillMaster", pos = Vector3.new(38, 1, -22), color = "Bright orange" },
	{ name = "Tanner", pos = Vector3.new(-38, 1, 22), color = "Reddish brown" },
	{ name = "Blacksmith", pos = Vector3.new(38, 1, 22), color = "Dark grey" },
	{ name = "Merchant", pos = Vector3.new(-22, 1, 38), color = "Bright green" },
	{ name = "QuestElder", pos = Vector3.new(22, 1, 38), color = "Gold" },
	{ name = "PortalKeeper", pos = Vector3.new(8, 1, -150), color = "Medium lilac" },
}

local SKIN = Color3.fromRGB(230, 190, 150)

for _, nd in ipairs(npcDefs) do
	-- Each NPC is a simple anchored figure facing the village center
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

-- Faction lore statues (Humans / Angels / Demons foreshadowing)
local statueDefs = {
	{ pos = Vector3.new(-16, 0, -66), label = "Human Faction", color = "Bright yellow" },
	{ pos = Vector3.new(0, 0, -69), label = "Angel Faction", color = "White" },
	{ pos = Vector3.new(16, 0, -66), label = "Demon Faction", color = "Bright red" },
}
for _, s in ipairs(statueDefs) do
	local base = makePart("Statue_Base", Vector3.new(5, 4, 5), s.pos + Vector3.new(0, 2.6, 0), s.color)
	base.Material = Enum.Material.SmoothPlastic
	local pillar = makePart("Statue_Pillar", Vector3.new(2.5, 7, 2.5), s.pos + Vector3.new(0, 8, 0), "Medium stone grey")
	makeLabel(pillar, s.label)
end

-- ============================================================
-- RESOURCE NODES
-- ============================================================

local function plantTree(pos: Vector3, tier: number, corrupted: boolean)
	local folder = Instance.new("Folder")
	folder.Name = "Tree_T" .. tostring(tier)
	folder.Parent = Island
	local trunkColor = if corrupted then "Black" else "Reddish brown"
	local leafColor = if corrupted then "Dark indigo" else (if tier == 1 then "Bright green" else "Dark green")
	local trunk = makePart("Trunk", Vector3.new(2, 6 + tier * 2, 2), pos + Vector3.new(0, 3 + tier, 0), trunkColor, folder)
	trunk.Material = Enum.Material.Wood
	local leaves = makePart("Leaves", Vector3.new(8 + tier, 6 + tier, 8 + tier), pos + Vector3.new(0, 8 + tier * 2, 0), leafColor, folder)
	leaves.Shape = Enum.PartType.Ball
	leaves.Material = Enum.Material.Grass
	local rtag = Instance.new("StringValue")
	rtag.Name = "ResourceType"
	rtag.Value = "raw_wood_t" .. tostring(tier)
	rtag.Parent = trunk
	local xptag = Instance.new("IntValue")
	xptag.Name = "MasteryXP"
	xptag.Value = if corrupted then tier * 2 else tier -- corrupted zone = faster mastery
	xptag.Parent = trunk
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Chop (T" .. tostring(tier) .. ")"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 1.5
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

-- West forest: dense T1 near the road, T2 deeper in
for _ = 1, 60 do
	local pos = Vector3.new(rng:NextNumber(-300, -130), 0, rng:NextNumber(-180, 200))
	plantTree(pos, 1, false)
end
for _ = 1, 18 do
	local pos = Vector3.new(rng:NextNumber(-400, -300), 0, rng:NextNumber(-160, 180))
	plantTree(pos, 2, false)
end

-- East rocks: ore + stone, T2 deeper
for _ = 1, 16 do
	local pos = Vector3.new(rng:NextNumber(150, 300), 0, rng:NextNumber(-150, 160))
	plantNode(pos, 1, "raw_ore", "Mine", false)
end
for _ = 1, 8 do
	local pos = Vector3.new(rng:NextNumber(300, 400), 0, rng:NextNumber(-140, 150))
	plantNode(pos, 2, "raw_ore", "Mine", false)
end
for _ = 1, 14 do
	local pos = Vector3.new(rng:NextNumber(150, 380), 0, rng:NextNumber(-160, 170))
	plantNode(pos, 1, "raw_stone", "Quarry", false)
end
for _ = 1, 6 do
	local pos = Vector3.new(rng:NextNumber(320, 410), 0, rng:NextNumber(-120, 130))
	plantNode(pos, 2, "raw_stone", "Quarry", false)
end

-- South plains: sparse T1 trees around the bandit camp
for _ = 1, 25 do
	local pos = Vector3.new(rng:NextNumber(-250, 250), 0, rng:NextNumber(160, 380))
	if math.abs(pos.X) > 60 or pos.Z < 280 then -- keep the camp clearing open
		plantTree(pos, 1, false)
	end
end

-- Bandit camp huts (mini boss arena)
for i = -1, 1 do
	local hut = makePart("BanditHut", Vector3.new(10, 7, 10), Vector3.new(i * 26, 4, 350), "Reddish brown")
	hut.Material = Enum.Material.Wood
end
makeLabel(makePart("CampSign", Vector3.new(1, 4, 1), Vector3.new(0, 2.6, 300), "Reddish brown"), "Bandit Camp — DANGER")

-- A few trees ringing the village so q1 is close by
for i = 1, 12 do
	local angle = (i / 12) * math.pi * 2
	local r = 105 + rng:NextNumber(-8, 12)
	plantTree(Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r), 1, false)
end

-- ============================================================
-- NORTH: beast boss arena + corrupted portal
-- ============================================================

for i = 1, 10 do
	local angle = (i / 10) * math.pi * 2
	local pillar = makePart(
		"ArenaPillar",
		Vector3.new(3, 10, 3),
		Vector3.new(math.cos(angle) * 38, 5.6, -230 + math.sin(angle) * 38),
		"Medium stone grey"
	)
	pillar.Material = Enum.Material.Slate
end

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

	-- Swirling purple sparkles
	local att = Instance.new("Attachment")
	att.Parent = inner
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 14
	pe.Lifetime = NumberRange.new(1, 2)
	pe.Speed = NumberRange.new(2, 5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 0.8
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	pe.Color = ColorSequence.new(Color3.fromRGB(180, 80, 255), Color3.fromRGB(90, 20, 140))
	pe.Parent = att

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(170, 70, 255)
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = inner
end

buildPortal(Portals, Vector3.new(0, 0, -300), "CorruptedPortal_Inner", "Corrupted Portal\nBeast Seal required", "Enter Corrupted Portal")

-- Teleport markers used by PortalServer
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

-- Corrupted crafting stations: craft here for boosted rarity odds
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

-- Corrupted nodes: T2 resources, double mastery XP
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

print("[IslandGenerator] Tutorial Island + Corrupted Island built.")
