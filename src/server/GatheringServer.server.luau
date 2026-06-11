--!strict
-- GatheringServer: Tree gathering via ProximityPrompt

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServer = require(script.Parent.DataServer)
local QuestServer = require(script.Parent.QuestServer)
local AdminServer = require(script.Parent.AdminServer)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)
local Shared = require(ReplicatedStorage.Modules.Shared)
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent
local UpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent
local GatherFeedback = Remotes:WaitForChild("GatherFeedback") :: RemoteEvent

local Cooldowns: { [string]: boolean } = {}
local DroppedItems: { [Instance]: number } = {}

local function dropItem(player: Player, itemId: string)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	
	-- Find the item in the categorized inventory and remove the whole stack
	local catName, idx, slotToRemove = Shared.FindInCategorizedInventory(data.inventory, itemId)
	if not catName or not idx or not slotToRemove then
		return
	end
	table.remove((data.inventory :: any)[catName], idx)
	
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

-- Which mastery line each resource trains (design doc: Wood/Hide/Ore/Stone)
local function masteryLineFor(resourceId: string): string
	if string.find(resourceId, "raw_wood", 1, true) then
		return "Wood"
	elseif string.find(resourceId, "raw_hide", 1, true) then
		return "Hide"
	elseif string.find(resourceId, "raw_ore", 1, true) then
		return "Ore"
	elseif string.find(resourceId, "raw_stone", 1, true) then
		return "Stone"
	end
	return "Wood"
end

local function onGather(player: Player, trunk: BasePart)
	local resourceTag = trunk:FindFirstChild("ResourceType")
	local xpTag = trunk:FindFirstChild("MasteryXP")
	if not resourceTag or not resourceTag:IsA("StringValue") then
		return
	end

	local resourceId = resourceTag.Value
	local masteryXP = if xpTag and xpTag:IsA("IntValue") then xpTag.Value else 1

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
			local _, _, slot = Shared.FindInCategorizedInventory(data.inventory, toolId)
			if slot then
				slot.durability = (slot.durability or 100) - 1
				if slot.durability <= 0 then
					data.equipped.tool = nil
					DataServer.RemoveFromInventory(player, toolId, 1)
					UpdateInventory:FireClient(player, data.inventory, data.equipped)
				end
			end
		end
	end

	gatherQty = math.max(1, math.floor(gatherQty * AdminServer.State.gatherMult))

	local ok, reason = DataServer.AddToInventory(player, resourceId, gatherQty, nil)
	if not ok then
		if reason == "overweight" then
			UpdateInventory:FireClient(player, data.inventory, data.equipped)
			DataServer.PushHUD(player)
		end
		return
	end

	DataServer.AddMastery(player, masteryLineFor(resourceId), math.floor(masteryXP * gatherQty * AdminServer.State.xpMult))
	UpdateMastery:FireClient(player, data.mastery)
	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	QuestServer.Progress(player, "collect", resourceId, gatherQty)

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
		QuestServer.Progress(player, "collect", itemId, quantity)
		
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
			local pickupPrompt = part:FindFirstChildOfClass("ProximityPrompt")
			if pickupPrompt then
				pickupPrompt.Triggered:Connect(function(player: Player)
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

	-- Consolidate duplicate stackable stacks within each category
	for _, categoryInventory in pairs(data.inventory :: { [string]: { Shared.InventorySlot } }) do
		local merged: { [string]: Shared.InventorySlot } = {}
		local newList: { Shared.InventorySlot } = {}
		for _, slot in ipairs(categoryInventory) do
			local def = ItemDB.Get(slot.id)
			if def and def.stackable then
				local existing = merged[slot.id]
				if existing then
					existing.quantity = (existing.quantity or 1) + (slot.quantity or 1)
				else
					merged[slot.id] = slot
					table.insert(newList, slot)
				end
			else
				table.insert(newList, slot)
			end
		end
		table.clear(categoryInventory)
		table.move(newList, 1, #newList, 1, categoryInventory)
	end

	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
end

local function autoArrangeInventory(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end

	-- Sort each category by tier, then name
	for _, categoryInventory in pairs(data.inventory :: { [string]: { Shared.InventorySlot } }) do
		table.sort(categoryInventory, function(a, b)
			local defA = ItemDB.Get(a.id)
			local defB = ItemDB.Get(b.id)
			if not defA or not defB then
				return false
			end
			if (defA.tier or 1) ~= (defB.tier or 1) then
				return (defA.tier or 1) < (defB.tier or 1)
			end
			return defA.name < defB.name
		end)
	end

	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
end

local function splitItem(player: Player, itemId: string)
	local data = DataServer.Get(player)
	if not data then
		return
	end

	local catName, idx, slot = Shared.FindInCategorizedInventory(data.inventory, itemId)
	if not catName or not idx or not slot then
		return
	end
	if not slot.quantity or slot.quantity <= 1 then
		return
	end

	local halfQty = math.floor(slot.quantity / 2)
	slot.quantity -= halfQty
	table.insert((data.inventory :: any)[catName], idx + 1, {
		id = itemId,
		quantity = halfQty,
		durability = slot.durability,
		rarity = slot.rarity,
	})

	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	DataServer.PushHUD(player)
end

-- Handle remote events
local GatherResource = Remotes:WaitForChild("GatherResource") :: RemoteEvent
GatherResource.OnServerEvent:Connect(function(player: Player, action: string, itemId: string)
	if action == "drop" then
		dropItem(player, itemId)
	elseif action == "autoStack" then
		autoStackInventory(player)
	elseif action == "autoArrange" then
		autoArrangeInventory(player)
	elseif action == "split" then
		splitItem(player, itemId)
	end
	-- "equip" / "use" are handled by CraftingServer on this same remote
end)

for _, desc in ipairs(workspace:GetDescendants()) do
	hookTreeTrunk(desc)
end
workspace.DescendantAdded:Connect(hookTreeTrunk)

print("[GatheringServer] Ready.")
