--!strict
-- GatheringServer: Tree gathering via ProximityPrompt

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServer = require(script.Parent.DataServer)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent
local UpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent
local QuestUpdate = Remotes:WaitForChild("QuestUpdate") :: RemoteEvent
local GatherFeedback = Remotes:WaitForChild("GatherFeedback") :: RemoteEvent

local Cooldowns: { [string]: boolean } = {}
local DroppedItems: { [Instance]: number } = {}

local function dropItem(player: Player, itemId: string)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	
	-- Find the item in inventory
	local slotToRemove = nil
	for i, slot in ipairs(data.inventory) do
		if slot.id == itemId then
			slotToRemove = slot
			table.remove(data.inventory, i)
			break
		end
	end
	
	if not slotToRemove then
		return
	end
	
	-- Create dropped item in world
	local def = ItemDB.Get(itemId)
	local dropPos: Vector3
	local char = player.Character
	if char and char.PrimaryPart then
		dropPos = char.PrimaryPart.Position + Vector3.new(math.random(-2, 2), 1, math.random(-2, 2))
	else
		dropPos = Vector3.new(0, 2, 0)
	end
	
	local dropPart = Instance.new("Part")
	dropPart.Name = "Drop_" .. itemId
	dropPart.Size = Vector3.new(1, 1, 1)
	dropPart.Position = dropPos
	dropPart.BrickColor = BrickColor.new("Bright yellow")
	dropPart.Material = Enum.Material.Neon
	dropPart.Parent = workspace
	
	-- Add item identification
	local dtag = Instance.new("StringValue")
	dtag.Name = "ItemId"
	dtag.Value = itemId
	dtag.Parent = dropPart
	
	local qtyTag = Instance.new("IntValue")
	qtyTag.Name = "Quantity"
	qtyTag.Value = slotToRemove.quantity or 1
	qtyTag.Parent = dropPart
	
	-- Add pickup prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up " .. (if def then def.name else itemId)
	prompt.MaxActivationDistance = 5
	prompt.Parent = dropPart
	
	-- Set up 5-minute cleanup timer
	local cleanupTime = 300 -- 5 minutes in seconds
	DroppedItems[dropPart] = tick() + cleanupTime
	
	-- Update client inventory
	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
end

local function cleanupDroppedItems()
	local currentTime = tick()
	for dropPart, expireTime in pairs(DroppedItems) do
		if currentTime >= expireTime and dropPart.Parent then
			dropPart:Destroy()
			DroppedItems[dropPart] = nil
		end
	end
end

-- Run cleanup every 30 seconds
task.spawn(function()
	while true do
		task.wait(30)
		cleanupDroppedItems()
	end
end)

local function onGather(player: Player, trunk: BasePart)
	print("[GatheringServer] onGather called by:", player.Name)
	local resourceTag = trunk:FindFirstChild("ResourceType")
	local xpTag = trunk:FindFirstChild("MasteryXP")
	if not resourceTag or not resourceTag:IsA("StringValue") then
		print("[GatheringServer] No ResourceType tag found")
		return
	end

	local resourceId = resourceTag.Value
	local masteryXP = if xpTag and xpTag:IsA("IntValue") then xpTag.Value else 1
	print("[GatheringServer] Gathering:", resourceId, "XP:", masteryXP)

	local uid = tostring(player.UserId) .. "_" .. trunk:GetFullName()
	if Cooldowns[uid] then
		return
	end

	local data = DataServer.Get(player)
	if not data then
		return
	end

	local toolId = data.equipped.tool
	local gatherQty = 1
	local cooldownTime = 3
	if toolId then
		local toolDef = ItemDB.Get(toolId)
		if toolDef and toolDef.stats then
			gatherQty += toolDef.stats.gatherBonus or 0
			local gsp = toolDef.stats.gatherSpeed or 1.0
			cooldownTime = cooldownTime / gsp
			for _, slot in ipairs(data.inventory) do
				if slot.id == toolId then
					slot.durability = (slot.durability or 100) - 1
					if slot.durability <= 0 then
						data.equipped.tool = nil
						DataServer.RemoveFromInventory(player, toolId, 1)
						UpdateInventory:FireClient(player, data.inventory, data.equipped)
					end
					break
				end
			end
		end
	end

	local ok, reason = DataServer.AddToInventory(player, resourceId, gatherQty, nil)
	if not ok then
		if reason == "overweight" then
			UpdateInventory:FireClient(player, data.inventory, data.equipped)
			DataServer.PushHUD(player)
		end
		return
	end

	DataServer.AddMastery(player, "Wood", masteryXP * gatherQty)
	UpdateMastery:FireClient(player, data.mastery)
	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	QuestUpdate:FireClient(player, "collect", resourceId, gatherQty)

	local itemDef = ItemDB.Get(resourceId)
	GatherFeedback:FireClient(player, resourceId, gatherQty, trunk.Position, if itemDef then itemDef.name else resourceId)

	Cooldowns[uid] = true
	task.delay(cooldownTime, function()
		Cooldowns[uid] = nil
	end)
end

local function onPickup(player: Player, dropPart: BasePart)
	local itemIdTag = dropPart:FindFirstChild("ItemId")
	local qtyTag = dropPart:FindFirstChild("Quantity")
	if not itemIdTag or not itemIdTag:IsA("StringValue") then
		return
	end
	
	local itemId = itemIdTag.Value
	local quantity = if qtyTag and qtyTag:IsA("IntValue") then qtyTag.Value else 1
	
	-- Add to player inventory
	local ok, reason = DataServer.AddToInventory(player, itemId, quantity, nil)
	if not ok then
		if reason == "overweight" then
			local data = DataServer.Get(player)
			if data then
				UpdateInventory:FireClient(player, data.inventory, data.equipped)
				DataServer.PushHUD(player)
			end
		end
		return
	end
	
	-- Remove dropped item from world
	DroppedItems[dropPart] = nil
	dropPart:Destroy()
	
	-- Update client
	local data = DataServer.Get(player)
	if data then
		UpdateInventory:FireClient(player, data.inventory, data.equipped)
		DataServer.PushHUD(player)
		QuestUpdate:FireClient(player, "collect", itemId, quantity)
		
		-- Show pickup feedback
		local itemDef = ItemDB.Get(itemId)
		GatherFeedback:FireClient(player, itemId, quantity, dropPart.Position, if itemDef then itemDef.name else itemId)
	end
end

local function hookTreeTrunk(part: Instance)
	if part:IsA("BasePart") then
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		local rtag = part:FindFirstChild("ResourceType")
		if prompt and rtag then
			prompt.Triggered:Connect(function(player: Player)
				onGather(player, part)
			end)
		end
		
		-- Hook up dropped item pickup
		local itemIdTag = part:FindFirstChild("ItemId")
		if itemIdTag and itemIdTag:IsA("StringValue") then
			local prompt = part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function(player: Player)
					onPickup(player, part)
				end)
			end
		end
	end
end

local function autoStackInventory(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	
	-- Group items by ID
	local itemGroups: { [string]: { Shared.InventorySlot } } = {}
	for _, slot in ipairs(data.inventory) do
		if not itemGroups[slot.id] then
			itemGroups[slot.id] = {}
		end
		table.insert(itemGroups[slot.id], slot)
	end
	
	-- Consolidate stacks
	local newInventory: { Shared.InventorySlot } = {}
	for itemId, slots in pairs(itemGroups) do
		local totalQty = 0
		for _, slot in ipairs(slots) do
			totalQty += (slot.quantity or 1)
		end
		
		if totalQty > 1 then
			-- Create consolidated stack
			table.insert(newInventory, {
				id = itemId,
				quantity = totalQty,
				durability = slots[1].durability,
				rarity = slots[1].rarity
			})
		else
			-- Keep single items as-is
			table.insert(newInventory, slots[1])
		end
	end
	
	data.inventory = newInventory
	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
end

local function autoArrangeInventory(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	
	-- Sort by item type, then by name, then by tier
	table.sort(data.inventory, function(a, b)
		local defA = ItemDB.Get(a.id)
		local defB = ItemDB.Get(b.id)
		if not defA or not defB then
			return false
		end
		
		-- Sort by type first
		if defA.type ~= defB.type then
			return defA.type < defB.type
		end
		
		-- Then by name
		if defA.name ~= defB.name then
			return defA.name < defB.name
		end
		
		-- Finally by tier
		return (defA.tier or 1) < (defB.tier or 1)
	end)
	
	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
end

local function splitItem(player: Player, itemId: string)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	
	-- Find the item to split
	for i, slot in ipairs(data.inventory) do
		if slot.id == itemId and slot.quantity and slot.quantity > 1 then
			local halfQty = math.floor(slot.quantity / 2)
			slot.quantity = slot.quantity - halfQty
			
			-- Create new stack with half quantity
			table.insert(data.inventory, i + 1, {
				id = itemId,
				quantity = halfQty,
				durability = slot.durability,
				rarity = slot.rarity
			})
			
			UpdateInventory:FireClient(player, data.inventory, data.equipped)
			DataServer.PushHUD(player)
			return
		end
	end
end

-- Handle remote events
local GatherResource = Remotes:WaitForChild("GatherResource") :: RemoteEvent
GatherResource.OnServerEvent:Connect(function(player: Player, action: string, itemId: string)
	print("[GatheringServer] Received action:", action, "itemId:", itemId)
	
	if action == "drop" then
		dropItem(player, itemId)
	elseif action == "autoStack" then
		autoStackInventory(player)
	elseif action == "autoArrange" then
		autoArrangeInventory(player)
	elseif action == "split" then
		splitItem(player, itemId)
	else
		print("[GatheringServer] Unknown action:", action)
	end
end)

for _, desc in ipairs(workspace:GetDescendants()) do
	hookTreeTrunk(desc)
end
workspace.DescendantAdded:Connect(hookTreeTrunk)

print("[GatheringServer] Ready.")
