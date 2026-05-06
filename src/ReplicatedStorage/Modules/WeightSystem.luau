--!strict
-- WeightSystem: Carry weight calculations

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)

type InventorySlot = {
	id: string,
	quantity: number?,
	durability: number?,
	quality: number?,
	rarity: string?,
}

local WeightSystem = {}

WeightSystem.BaseCapacity = 50
WeightSystem.BagBonus = { bag_t1 = 20, bag_t2 = 35 } :: { [string]: number }

function WeightSystem.GetCapacity(equippedBag: string?): number
	local bonus = 0
	if equippedBag then
		local b = WeightSystem.BagBonus[equippedBag]
		if b then
			bonus = b
		end
	end
	return WeightSystem.BaseCapacity + bonus
end

function WeightSystem.CalculateWeight(inventory: { InventorySlot }): number
	local total = 0
	for _, slot in ipairs(inventory) do
		local def = ItemDB.Get(slot.id)
		if def then
			local qty = slot.quantity or 1
			total += def.weight * qty
		end
	end
	return total
end

function WeightSystem.CanAdd(inventory: { InventorySlot }, itemId: string, qty: number?, equippedBag: string?): boolean
	local def = ItemDB.Get(itemId)
	if not def then
		return false
	end
	local currentWeight = WeightSystem.CalculateWeight(inventory)
	local addWeight = def.weight * (qty or 1)
	local cap = WeightSystem.GetCapacity(equippedBag)
	return (currentWeight + addWeight) <= cap
end

return WeightSystem
