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
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local RemotesMobDied = Remotes:WaitForChild("MobDied") :: RemoteEvent
local RemotesUpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent
local RemotesQuestUpdate = Remotes:WaitForChild("QuestUpdate") :: RemoteEvent
local RemotesBossDefeated = Remotes:WaitForChild("BossDefeated") :: RemoteEvent

export type SpawnPoint = {
	mobId: string,
	pos: Vector3,
	count: number,
}

local SpawnPoints: { SpawnPoint } = {
	-- Forest biome (northwest) - Wolves and Bears
	{ mobId = "Wolf", pos = Vector3.new(-200, 1, -200), count = 8 },
	{ mobId = "Wolf", pos = Vector3.new(-150, 1, -150), count = 6 },
	{ mobId = "Bear", pos = Vector3.new(-220, 1, -220), count = 4 },
	{ mobId = "ForestMiniboss", pos = Vector3.new(-180, 1, -180), count = 1 },
	
	-- Mountain biome (northeast) - Elementals and Bandits
	{ mobId = "Elemental", pos = Vector3.new(200, 1, -200), count = 6 },
	{ mobId = "Elemental", pos = Vector3.new(220, 1, -220), count = 5 },
	{ mobId = "Bandit", pos = Vector3.new(180, 1, -180), count = 7 },
	{ mobId = "MountainMiniboss", pos = Vector3.new(200, 1, -200), count = 1 },
	
	-- Plains biome (southwest) - Wolves and Bandits
	{ mobId = "Wolf", pos = Vector3.new(-200, 1, 200), count = 6 },
	{ mobId = "Bandit", pos = Vector3.new(-180, 1, 180), count = 5 },
	{ mobId = "Bandit", pos = Vector3.new(-220, 1, 220), count = 4 },
	
	-- Swamp biome (southeast) - Swamp Beasts and Wolves
	{ mobId = "SwampBeast", pos = Vector3.new(200, 1, 200), count = 7 },
	{ mobId = "SwampBeast", pos = Vector3.new(180, 1, 180), count = 5 },
	{ mobId = "Wolf", pos = Vector3.new(220, 1, 220), count = 4 },
	
	-- Central area - Mixed encounters
	{ mobId = "Wolf", pos = Vector3.new(120, 1, 0), count = 4 },
	{ mobId = "Bandit", pos = Vector3.new(-120, 1, 0), count = 4 },
	{ mobId = "Elemental", pos = Vector3.new(0, 1, 120), count = 3 },
	
	-- Boss encounters (outer edges)
	{ mobId = "WolfBoss", pos = Vector3.new(350, 1, 100), count = 1 },
	{ mobId = "BanditCaptain", pos = Vector3.new(-350, 1, -100), count = 1 },
	{ mobId = "BeastBoss", pos = Vector3.new(0, 1, -450), count = 1 },
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

local function makeMobModel(mobId: string, position: Vector3): Model?
	local def = MobDB.Get(mobId)
	if not def then
		return nil
	end

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
			RemotesQuestUpdate:FireClient(nearestPlayer, "kill", mobId, 1)

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
		local newModel = makeMobModel(mobId, spawnPoint.pos + offset)
		if newModel then
			local def2 = MobDB.Get(mobId)
			if def2 then
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
			if char and char.PrimaryPart then
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
	local def = MobDB.Get(sp.mobId)
	if def then
		for _j = 1, sp.count do
			local offset = Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
			local model = makeMobModel(sp.mobId, sp.pos + offset)
			if model then
				setupMobBehavior(model, sp.mobId, def, sp)
			end
		end
	end
end

print("[MobAI] All mobs spawned.")
