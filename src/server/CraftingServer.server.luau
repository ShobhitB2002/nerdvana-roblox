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
	if action ~= "equip" or typeof(itemId) ~= "string" then
		return
	end
	local data = DataServer.Get(player)
	if not data then
		return
	end

	local _, slot = Shared.FindInInventory(data.inventory, itemId)
	if not slot then
		return
	end
	local def = ItemDB.Get(itemId)
	if not def then
		return
	end
	if def.type == "Gear" then
		local slot = def.slot
		if slot == "helmet" or slot == "chest" or slot == "boots" or slot == "bag" then
			data.equipped[slot] = itemId
		else
			data.equipped.weapon = itemId
		end
	elseif def.type == "Tools" then
		data.equipped.tool = itemId
	end
	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
end)

print("[CraftingServer] Ready.")
