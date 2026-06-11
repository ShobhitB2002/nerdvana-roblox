--!strict
-- MobAI: Spawns mobs + simple combat AI

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MobDB = require(ReplicatedStorage.Modules.MobDB)
local DataServer = require(script.Parent.DataServer)
local BossServer = require(script.Parent.BossServer)
local QuestServer = require(script.Parent.QuestServer)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local RemotesMobDied = Remotes:WaitForChild("MobDied") :: RemoteEvent
local RemotesUpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent
local RemotesBossDefeated = Remotes:WaitForChild("BossDefeated") :: RemoteEvent

export type SpawnPoint = {
	mobId: string,
	pos: Vector3,
	count: number,
	corrupted: boolean?,
}

-- Safe zones: mobs never aggro or damage players inside these
local CORRUPT_OFFSET = Vector3.new(3000, 0, 0)
local SafeZones: { { center: Vector3, radius: number } } = {
	{ center = Vector3.new(0, 0, 0), radius = 95 }, -- village plaza
	{ center = CORRUPT_OFFSET, radius = 45 }, -- corrupted return pad
}

local function inSafeZone(pos: Vector3): boolean
	for _, z in ipairs(SafeZones) do
		local d = Vector3.new(pos.X - z.center.X, 0, pos.Z - z.center.Z).Magnitude
		if d < z.radius then
			return true
		end
	end
	return false
end

-- Corrupted variants: tougher, better rewards (New Game+ loop)
local function resolveDef(mobId: string, corrupted: boolean?): MobDB.MobDef?
	local def = MobDB.Get(mobId)
	if not def then
		return nil
	end
	if not corrupted then
		return def
	end
	local c = table.clone(def)
	c.displayName = "Corrupted " .. def.displayName
	c.health = math.floor(def.health * 1.75)
	c.damage = math.floor(def.damage * 1.5)
	c.masteryXP = def.masteryXP * 2
	c.goldDrop = { min = def.goldDrop.min * 2, max = def.goldDrop.max * 2 }
	c.modelColor = Color3.fromRGB(80, 20, 110)
	return c
end

local SpawnPoints: { SpawnPoint } = {
	-- West forest: wolves near the treeline, alpha deep in the woods
	{ mobId = "Wolf", pos = Vector3.new(-190, 3, -60), count = 5 },
	{ mobId = "Wolf", pos = Vector3.new(-240, 3, 90), count = 5 },
	{ mobId = "Bear", pos = Vector3.new(-330, 3, -120), count = 3 },
	{ mobId = "WolfBoss", pos = Vector3.new(-380, 3, 20), count = 1 },
	{ mobId = "ForestMiniboss", pos = Vector3.new(-340, 3, 160), count = 1 },

	-- East rocks: elementals guard the ore fields
	{ mobId = "Elemental", pos = Vector3.new(220, 3, -60), count = 4 },
	{ mobId = "Elemental", pos = Vector3.new(290, 3, 90), count = 3 },
	{ mobId = "MountainMiniboss", pos = Vector3.new(380, 3, 0), count = 1 },

	-- South plains: bandit camp + captain arena
	{ mobId = "Bandit", pos = Vector3.new(120, 3, 220), count = 4 },
	{ mobId = "Bandit", pos = Vector3.new(-110, 3, 250), count = 4 },
	{ mobId = "BanditCaptain", pos = Vector3.new(0, 3, 330), count = 1 },
	{ mobId = "SwampBeast", pos = Vector3.new(280, 3, 300), count = 4 },

	-- North: beast boss arena guards the portal
	{ mobId = "Wolf", pos = Vector3.new(-90, 3, -200), count = 3 },
	{ mobId = "BeastBoss", pos = Vector3.new(0, 3, -230), count = 1 },

	-- Corrupted island (NG+): harder versions, double rewards
	{ mobId = "Wolf", pos = CORRUPT_OFFSET + Vector3.new(-120, 3, -80), count = 5, corrupted = true },
	{ mobId = "Bandit", pos = CORRUPT_OFFSET + Vector3.new(110, 3, 130), count = 5, corrupted = true },
	{ mobId = "Bear", pos = CORRUPT_OFFSET + Vector3.new(-140, 3, 120), count = 3, corrupted = true },
	{ mobId = "Elemental", pos = CORRUPT_OFFSET + Vector3.new(150, 3, -110), count = 3, corrupted = true },
	{ mobId = "WolfBoss", pos = CORRUPT_OFFSET + Vector3.new(0, 3, -180), count = 1, corrupted = true },
	{ mobId = "BanditCaptain", pos = CORRUPT_OFFSET + Vector3.new(0, 3, 190), count = 1, corrupted = true },
	{ mobId = "BeastBoss", pos = CORRUPT_OFFSET + Vector3.new(180, 3, 0), count = 1, corrupted = true },
}

local function getMobsFolder(): Folder
	local f = workspace:FindFirstChild("Mobs")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "Mobs"
	nf.Parent = workspace
	return nf
end

local function makeMobModel(mobId: string, def: MobDB.MobDef, position: Vector3): Model?
	local model = Instance.new("Model")
	model.Name = mobId

	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = if def.isBoss then Vector3.new(5, 8, 5) else Vector3.new(3, 5, 3)
	body.CFrame = CFrame.new(position)
	body.Anchored = false
	body.Parent = model
	body.BrickColor = BrickColor.new("Medium stone grey")
	body.Color = def.modelColor

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = def.health
	hum.Health = def.health
	hum.WalkSpeed = def.speed
	hum.DisplayName = def.displayName
	hum.Parent = model

	local hval = Instance.new("IntValue")
	hval.Name = "Health"
	hval.Value = def.health
	hval.Parent = model

	local mobTag = Instance.new("StringValue")
	mobTag.Name = "MobId"
	mobTag.Value = mobId
	mobTag.Parent = model

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 160, 0, 48)
	bb.StudsOffset = Vector3.new(0, if def.isBoss then 6 else 4, 0)
	bb.Parent = body
	local nlbl = Instance.new("TextLabel")
	nlbl.Size = UDim2.new(1, 0, 0.5, 0)
	nlbl.Text = def.displayName
	nlbl.TextColor3 = if def.isBoss then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(220, 220, 80)
	nlbl.BackgroundTransparency = 1
	nlbl.TextScaled = true
	nlbl.Font = Enum.Font.GothamBold
	nlbl.Parent = bb
	local hlbl = Instance.new("TextLabel")
	hlbl.Name = "HealthLabel"
	hlbl.Size = UDim2.new(1, 0, 0.5, 0)
	hlbl.Position = UDim2.new(0, 0, 0.5, 0)
	hlbl.Text = tostring(def.health) .. "/" .. tostring(def.health)
	hlbl.TextColor3 = Color3.fromRGB(255, 100, 100)
	hlbl.BackgroundTransparency = 1
	hlbl.TextScaled = true
	hlbl.Font = Enum.Font.Gotham
	hlbl.Parent = bb

	model.PrimaryPart = body
	model.Parent = getMobsFolder()
	return model
end

local function dropLoot(def: MobDB.MobDef, position: Vector3)
	for _, drop in ipairs(def.drops) do
		if math.random() <= drop.chance then
			local itemDef = ItemDB.Get(drop.item)
			if itemDef then
				local part = Instance.new("Part")
				part.Name = "Loot_" .. drop.item
				part.Size = Vector3.new(1, 1, 1)
				part.Position = position + Vector3.new(math.random(-4, 4), 1, math.random(-4, 4))
				part.BrickColor = BrickColor.new("Bright yellow")
				part.Material = Enum.Material.Neon
				part.Parent = workspace

				local ltag = Instance.new("StringValue")
				ltag.Name = "ItemId"
				ltag.Value = drop.item
				ltag.Parent = part

				local qtag = Instance.new("IntValue")
				qtag.Name = "Quantity"
				qtag.Value = drop.qty
				qtag.Parent = part

				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Pick up " .. itemDef.name
				prompt.MaxActivationDistance = 6
				prompt.Parent = part

				prompt.Triggered:Connect(function(player: Player)
					local data = DataServer.Get(player)
					if not data then
						return
					end
					DataServer.AddToInventory(player, drop.item, drop.qty, nil)
					local inv = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent
					inv:FireClient(player, data.inventory, data.equipped)
					part:Destroy()
				end)

				task.delay(60, function()
					if part.Parent then
						part:Destroy()
					end
				end)
			end
		end
	end
end

local function onMobDeath(
	model: Model,
	mobId: string,
	def: MobDB.MobDef,
	spawnPoint: SpawnPoint,
	_setup: (Model, string, MobDB.MobDef, SpawnPoint) -> ()
)
	local pos = if model.PrimaryPart then model.PrimaryPart.Position else spawnPoint.pos

	local nearestPlayer: Player? = nil
	local minDist = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char.PrimaryPart then
			local dist = (char.PrimaryPart.Position - pos).Magnitude
			if dist < minDist then
				minDist = dist
				nearestPlayer = player
			end
		end
	end

	if nearestPlayer and minDist < 80 then
		local data = DataServer.Get(nearestPlayer)
		if data then
			local goldAmt = math.random(def.goldDrop.min, def.goldDrop.max)
			DataServer.AddGold(nearestPlayer, goldAmt)
			DataServer.AddMastery(nearestPlayer, def.masteryLine, def.masteryXP)
			RemotesUpdateMastery:FireClient(nearestPlayer, data.mastery)
			RemotesMobDied:FireClient(nearestPlayer, mobId, goldAmt)
			QuestServer.Progress(nearestPlayer, "kill", mobId, 1)

			if def.isBoss then
				RemotesBossDefeated:FireClient(nearestPlayer, mobId)
			end

			if mobId == "BeastBoss" then
				BossServer.OnBeastBossDefeated(nearestPlayer)
			end
		end
	end

	dropLoot(def, pos)
	model:Destroy()

	task.delay(def.respawnTime, function()
		local offset = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
		local def2 = resolveDef(mobId, spawnPoint.corrupted)
		if def2 then
			local newModel = makeMobModel(mobId, def2, spawnPoint.pos + offset)
			if newModel then
				_setup(newModel, mobId, def2, spawnPoint)
			end
		end
	end)
end

local function setupMobBehavior(model: Model, mobId: string, def: MobDB.MobDef, spawnPoint: SpawnPoint)
	local hval = model:FindFirstChild("Health")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hval or not hum or not hval:IsA("IntValue") then
		return
	end

	local dead = false

	hval.Changed:Connect(function()
		if dead then
			return
		end
		local newVal = hval.Value
		hum.Health = newVal
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local bb = root:FindFirstChildOfClass("BillboardGui")
			if bb then
				local hl = bb:FindFirstChild("HealthLabel")
				if hl and hl:IsA("TextLabel") then
					hl.Text = tostring(math.max(0, newVal)) .. "/" .. tostring(def.health)
				end
			end
		end
		if newVal <= 0 then
			dead = true
			onMobDeath(model, mobId, def, spawnPoint, setupMobBehavior)
		end
	end)

	local lastAttack = 0

	RunService.Heartbeat:Connect(function(dt: number)
		if dead or not model.Parent then
			return
		end
		local root = model.PrimaryPart
		if not root then
			return
		end

		local nearestPlayer: Player? = nil
		local nearestDist = def.aggroRange
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if char and char.PrimaryPart and not inSafeZone(char.PrimaryPart.Position) then
				local dist = (char.PrimaryPart.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestPlayer = player
				end
			end
		end

		if nearestPlayer then
			local charRoot = nearestPlayer.Character and nearestPlayer.Character.PrimaryPart
			if charRoot then
				local dist = (charRoot.Position - root.Position).Magnitude
				if dist > def.attackRange then
					local dir = (charRoot.Position - root.Position).Unit
					root.CFrame = root.CFrame + dir * def.speed * dt
				else
					local now = tick()
					if now - lastAttack >= def.attackCooldown then
						lastAttack = now
						local data = DataServer.Get(nearestPlayer)
						if data then
							local char = nearestPlayer.Character
							if char then
								local hum2 = char:FindFirstChildOfClass("Humanoid")
								if hum2 then
									local defense = 0
									for _, slotName in ipairs({ "helmet", "chest", "boots" }) do
										local armorId = data.equipped[slotName]
										if armorId then
											local aDef = ItemDB.Get(armorId)
											if aDef and aDef.stats and aDef.stats.defense then
												defense += aDef.stats.defense
											end
										end
									end
									local finalDmg = math.max(1, def.damage - math.floor(defense * 0.3))
									hum2:TakeDamage(finalDmg)
								end
							end
						end
					end
				end
			end
		else
			local spawnPos = spawnPoint.pos
			local dist = (root.Position - spawnPos).Magnitude
			if dist > 20 then
				local dir = (Vector3.new(spawnPos.X, root.Position.Y, spawnPos.Z) - root.Position).Unit
				root.CFrame = root.CFrame + dir * def.speed * 0.5 * dt
			end
		end
	end)
end

for _, sp in ipairs(SpawnPoints) do
	local def = resolveDef(sp.mobId, sp.corrupted)
	if def then
		for _j = 1, sp.count do
			local offset = Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
			local model = makeMobModel(sp.mobId, def, sp.pos + offset)
			if model then
				setupMobBehavior(model, sp.mobId, def, sp)
			end
		end
	end
end

print("[MobAI] All mobs spawned.")
