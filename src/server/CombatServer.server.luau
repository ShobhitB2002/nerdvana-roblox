--!strict
-- CombatServer: Player hits vs mobs

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServer = require(script.Parent.DataServer)
local BoostServer = require(script.Parent.BoostServer)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)
local Shared = require(ReplicatedStorage.Modules.Shared)
local RarityRoller = require(ReplicatedStorage.Modules.RarityRoller)
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local CombatHit = Remotes:WaitForChild("CombatHit") :: RemoteEvent
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent

local SwingCooldowns: { [number]: boolean } = {}

CombatHit.OnServerEvent:Connect(function(player: Player, mobModel: unknown)
	if typeof(mobModel) ~= "Instance" or not mobModel:IsA("Model") then
		return
	end

	local uid = player.UserId
	if SwingCooldowns[uid] then
		return
	end

	local data = DataServer.Get(player)
	if not data then
		return
	end

	local weaponId = data.equipped.weapon
	local damage = 8
	local attackSpeed = 1.0
	if weaponId then
		local wDef = ItemDB.Get(weaponId)
		if wDef and wDef.stats then
			damage = wDef.stats.damage or damage
			attackSpeed = wDef.stats.speed or 1.0
			local _, _, slot = Shared.FindInCategorizedInventory(data.inventory, weaponId)
			if slot then
				-- Rarity quality bonus (Common +0% ... Mythic +20% per design doc)
				local mult = RarityRoller.Multipliers[slot.rarity or "Common"] or 1.0
				damage = math.floor(damage * mult)
				slot.durability = (slot.durability or 80) - 1
				if slot.durability <= 0 then
					data.equipped.weapon = nil
					DataServer.RemoveFromInventory(player, weaponId, 1)
				end
			end
		end
	end

	local healthVal = mobModel:FindFirstChild("Health")
	if not healthVal or not healthVal:IsA("IntValue") then
		return
	end

	healthVal.Value -= math.max(1, math.floor(damage * BoostServer.GetMults(player).damage))

	SwingCooldowns[uid] = true
	task.delay(1 / attackSpeed, function()
		SwingCooldowns[uid] = nil
	end)

	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
end)

print("[CombatServer] Ready.")
