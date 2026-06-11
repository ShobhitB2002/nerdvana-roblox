--!strict
-- Shared utility functions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)

export type InventorySlot = {
	id: string,
	quantity: number?,
	durability: number?,
	quality: number?,
	rarity: string?,
}

export type CategorizedInventory = {
	materials: { InventorySlot },
	gear: { InventorySlot },
	tools: { InventorySlot },
	consumables: { InventorySlot },
	quest: { InventorySlot },
	currency: { InventorySlot },
}

local Shared = {}

function Shared.FindInInventory(inventory: { InventorySlot }, itemId: string): (number?, InventorySlot?)
	for i, slot in ipairs(inventory) do
		if slot.id == itemId then
			return i, slot
		end
	end
	return nil, nil
end

function Shared.AddToInventory(inventory: { InventorySlot }, itemId: string, qty: number?, quality: number?, rarity: string?): boolean
	local def = ItemDB.Get(itemId)
	if not def then
		return false
	end
	local amount = qty or 1
	if def.stackable then
		local _idx, slot = Shared.FindInInventory(inventory, itemId)
		if slot then
			slot.quantity = (slot.quantity or 1) + amount
			return true
		end
	end
	local newSlot: InventorySlot = {
		id = itemId,
		quantity = amount,
		durability = def.durabilityMax,
		rarity = rarity or "Common",
		quality = quality or 1.0,
	}
	table.insert(inventory, newSlot)
	return true
end

function Shared.RemoveFromInventory(inventory: { InventorySlot }, itemId: string, qty: number?): boolean
	local amount = qty or 1
	local idx, slot = Shared.FindInInventory(inventory, itemId)
	if not slot then
		return false
	end
	if (slot.quantity or 1) < amount then
		return false
	end
	local remaining = (slot.quantity or 1) - amount
	slot.quantity = remaining
	if remaining <= 0 then
		table.remove(inventory, idx :: number)
	end
	return true
end

function Shared.HasItems(inventory: { InventorySlot }, requirements: { [string]: number }): (boolean, string?)
	for itemId, reqQty in pairs(requirements) do
		local _, slot = Shared.FindInInventory(inventory, itemId)
		if not slot or (slot.quantity or 1) < reqQty then
			return false, itemId
		end
	end
	return true, nil
end

function Shared.RandomDrop(inventory: { InventorySlot }): InventorySlot?
	if #inventory == 0 then
		return nil
	end
	local filteredIdx: { number } = {}
	for i, slot in ipairs(inventory) do
		local def = ItemDB.Get(slot.id)
		if def and def.type ~= "Quest" and def.type ~= "Currency" then
			table.insert(filteredIdx, i)
		end
	end
	if #filteredIdx == 0 then
		return nil
	end
	local pick = filteredIdx[math.random(1, #filteredIdx)]
	local dropped = inventory[pick]
	table.remove(inventory, pick)
	return dropped
end

function Shared.GetCategory(itemId: string): string?
	local def = ItemDB.Get(itemId)
	if not def then
		return nil
	end
	
	if def.type == "Materials" then
		return "materials"
	elseif def.type == "Gear" then
		if def.slot == "bag" then
			return "gear"
		else
			return "gear"
		end
	elseif def.type == "Tools" then
		return "tools"
	elseif def.type == "Consumables" then
		return "consumables"
	elseif def.type == "Quest" then
		return "quest"
	elseif def.type == "Currency" then
		return "currency"
	end
	
	return "materials"
end

function Shared.AddToCategorizedInventory(inventory: CategorizedInventory, itemId: string, qty: number?, quality: number?, rarity: string?): boolean
	local def = ItemDB.Get(itemId)
	if not def then
		return false
	end
	
	local category = Shared.GetCategory(itemId)
	if not category then
		return false
	end
	
	local amount = qty or 1
	local categoryInventory = inventory[category] :: { InventorySlot }

	if def.stackable then
		local _idx, slot = Shared.FindInInventory(categoryInventory, itemId)
		if slot then
			slot.quantity = (slot.quantity or 1) + amount
			return true
		end
	end

	local newSlot: InventorySlot = {
		id = itemId,
		quantity = amount,
		durability = def.durabilityMax,
		rarity = rarity or "Common",
		quality = quality or 1.0,
	}
	table.insert(categoryInventory, newSlot)
	return true
end

function Shared.RemoveFromCategorizedInventory(inventory: CategorizedInventory, itemId: string, qty: number?): boolean
	local category = Shared.GetCategory(itemId)
	if not category then
		return false
	end
	
	local amount = qty or 1
	local categoryInventory = inventory[category] :: { InventorySlot }
	local idx, slot = Shared.FindInInventory(categoryInventory, itemId)
	if not slot then
		return false
	end

	if (slot.quantity or 1) < amount then
		return false
	end

	local remaining = (slot.quantity or 1) - amount
	slot.quantity = remaining
	if remaining <= 0 then
		table.remove(categoryInventory, idx :: number)
	end

	return true
end

function Shared.FindInCategorizedInventory(inventory: CategorizedInventory, itemId: string): (string?, number?, InventorySlot?)
	local category = Shared.GetCategory(itemId)
	if category then
		local categoryInventory = inventory[category] :: { InventorySlot }
		local idx, slot = Shared.FindInInventory(categoryInventory, itemId)
		if slot then
			return category, idx, slot
		end
	end

	-- Fallback: scan every category (handles items saved under an old category)
	for catName, categoryInventory in pairs(inventory :: { [string]: { InventorySlot } }) do
		local idx, slot = Shared.FindInInventory(categoryInventory, itemId)
		if slot then
			return catName, idx, slot
		end
	end

	return nil, nil, nil
end

function Shared.HasItemsCategorized(inventory: CategorizedInventory, requirements: { [string]: number }): (boolean, string?)
	for itemId, reqQty in pairs(requirements) do
		local _, _, slot = Shared.FindInCategorizedInventory(inventory, itemId)
		if not slot or (slot.quantity or 1) < reqQty then
			return false, itemId
		end
	end
	return true, nil
end

function Shared.RandomDropCategorized(inventory: CategorizedInventory): InventorySlot?
	local candidates: { { cat: { InventorySlot }, idx: number } } = {}
	for catName, categoryInventory in pairs(inventory :: { [string]: { InventorySlot } }) do
		if catName ~= "quest" and catName ~= "currency" then
			for i, slot in ipairs(categoryInventory) do
				local def = ItemDB.Get(slot.id)
				if def and def.type ~= "Quest" and def.type ~= "Currency" then
					table.insert(candidates, { cat = categoryInventory, idx = i })
				end
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	local pick = candidates[math.random(1, #candidates)]
	local dropped = pick.cat[pick.idx]
	table.remove(pick.cat, pick.idx)
	return dropped
end

function Shared.CalculateCategorizedWeight(inventory: CategorizedInventory): number
	local totalWeight = 0
	for _, category in pairs(inventory) do
		for _, slot in ipairs(category) do
			local def = ItemDB.Get(slot.id)
			if def then
				local qty = slot.quantity or 1
				totalWeight += def.weight * qty
			end
		end
	end
	return totalWeight
end

return Shared
