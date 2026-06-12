--!strict
-- DeathServer: Durability loss + random drop on player death

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServer = require(script.Parent.DataServer)
local Shared = require(ReplicatedStorage.Modules.Shared)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent
local PlayerDied = Remotes:WaitForChild("PlayerDied") :: RemoteEvent

local function onPlayerDied(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end

	for slotName, itemId in pairs(data.equipped) do
		if itemId and typeof(itemId) == "string" then
			local _, _, invSlot = Shared.FindInCategorizedInventory(data.inventory, itemId)
			if invSlot then
				invSlot.durability = (invSlot.durability or 0) - 10
				if invSlot.durability <= 0 then
					DataServer.RemoveFromInventory(player, itemId, 1);
					(data.equipped :: { [string]: string? })[slotName] = nil
				end
			end
		end
	end

	-- Respawning returns you to the village; you are no longer in the corrupted zone
	data.isCorrupted = false

	local dropped = Shared.RandomDropCategorized(data.inventory)
	local dropPos: Vector3
	local char = player.Character
	if char and char.PrimaryPart then
		dropPos = char.PrimaryPart.Position
	else
		dropPos = Vector3.new(0, 2, 0)
	end

	if dropped then
		local def = ItemDB.Get(dropped.id)
		local dropPart = Instance.new("Part")
		dropPart.Name = "Drop_" .. dropped.id
		dropPart.Size = Vector3.new(1, 1, 1)
		dropPart.Position = dropPos + Vector3.new(math.random(-3, 3), 1, math.random(-3, 3))
		dropPart.BrickColor = BrickColor.new("Bright yellow")
		dropPart.Material = Enum.Material.Neon
		dropPart.Parent = workspace

		local dtag = Instance.new("StringValue")
		dtag.Name = "ItemId"
		dtag.Value = dropped.id
		dtag.Parent = dropPart

		local qtag = Instance.new("IntValue")
		qtag.Name = "Quantity"
		qtag.Value = dropped.quantity or 1
		qtag.Parent = dropPart

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Pick up " .. (if def then def.name else dropped.id)
		prompt.MaxActivationDistance = 5
		prompt.Parent = dropPart

		prompt.Triggered:Connect(function(p: Player)
			local d = DataServer.Get(p)
			if not d then
				return
			end
			DataServer.AddToInventory(p, dropped.id, dropped.quantity or 1, dropped.rarity)
			UpdateInventory:FireClient(p, d.inventory, d.equipped)
			dropPart:Destroy()
		end)

		task.delay(120, function()
			if dropPart.Parent then
				dropPart:Destroy()
			end
		end)
	end

	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
	PlayerDied:FireClient(player, dropped)
end

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		local hum = character:WaitForChild("Humanoid") :: Humanoid
		hum.Died:Connect(function()
			task.wait(0.1)
			onPlayerDied(player)
		end)
	end)
end)

print("[DeathServer] Ready.")
