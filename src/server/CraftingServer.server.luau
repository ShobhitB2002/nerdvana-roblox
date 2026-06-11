--!strict
-- CraftingServer: Equip actions (GatherResource remote)

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServer = require(script.Parent.DataServer)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)
local Shared = require(ReplicatedStorage.Modules.Shared)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local GatherResource = Remotes:WaitForChild("GatherResource") :: RemoteEvent
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent

GatherResource.OnServerEvent:Connect(function(player: Player, action: unknown, itemId: unknown)
	if typeof(itemId) ~= "string" then
		return
	end
	local data = DataServer.Get(player)
	if not data then
		return
	end

	local _, _, slot = Shared.FindInCategorizedInventory(data.inventory, itemId)
	if not slot then
		return
	end
	local def = ItemDB.Get(itemId)
	if not def then
		return
	end

	if action == "equip" then
		if def.type == "Gear" then
			local gearSlot = def.slot
			if gearSlot == "helmet" or gearSlot == "chest" or gearSlot == "boots" or gearSlot == "bag" then
				data.equipped[gearSlot] = itemId
			else
				data.equipped.weapon = itemId
			end
		elseif def.type == "Tools" then
			data.equipped.tool = itemId
		else
			return
		end
	elseif action == "use" then
		if def.type ~= "Consumables" or not def.stats or not def.stats.healAmount then
			return
		end
		local char = player.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if not hum or hum.Health <= 0 then
			return
		end
		DataServer.RemoveFromInventory(player, itemId, 1)
		hum.Health = math.min(hum.MaxHealth, hum.Health + def.stats.healAmount)
	else
		return
	end

	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
end)

print("[CraftingServer] Ready.")
