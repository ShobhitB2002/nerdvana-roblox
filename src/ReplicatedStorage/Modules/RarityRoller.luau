--!strict
-- RarityRoller: Rolls item rarity on craft

local RarityRoller = {}

export type RarityEntry = {
	rarity: string,
	color: Color3,
	weight: number,
}

RarityRoller.Table = {
	{ rarity = "Common", color = Color3.fromRGB(220, 220, 220), weight = 550 },
	{ rarity = "Uncommon", color = Color3.fromRGB(80, 220, 80), weight = 250 },
	{ rarity = "Rare", color = Color3.fromRGB(60, 120, 255), weight = 120 },
	{ rarity = "Epic", color = Color3.fromRGB(160, 60, 255), weight = 60 },
	{ rarity = "Legendary", color = Color3.fromRGB(255, 165, 0), weight = 17 },
	{ rarity = "Mythic", color = Color3.fromRGB(255, 40, 40), weight = 3 },
}

RarityRoller.Multipliers = {
	Common = 1.00,
	Uncommon = 1.08,
	Rare = 1.18,
	Epic = 1.32,
	Legendary = 1.50,
	Mythic = 1.75,
}

RarityRoller.CorruptedLuck = 0.15 -- luck bonus while in the corrupted zone

-- luckBoost: 0 = normal odds; 1 = rare+ weights doubled
function RarityRoller.Roll(luckBoost: number): (string, Color3)
	local boost = math.clamp(luckBoost, 0, 10)
	local rolled: { RarityEntry } = {}
	local totalWeight = 0
	for _, entry in ipairs(RarityRoller.Table) do
		local w = entry.weight
		if
			entry.rarity == "Rare"
			or entry.rarity == "Epic"
			or entry.rarity == "Legendary"
			or entry.rarity == "Mythic"
		then
			w = math.floor(w * (1 + boost))
		end
		table.insert(rolled, { rarity = entry.rarity, color = entry.color, weight = w })
		totalWeight += w
	end
	local roll = math.random(1, totalWeight)
	local cumulative = 0
	for _, entry in ipairs(rolled) do
		cumulative += entry.weight
		if roll <= cumulative then
			return entry.rarity, entry.color
		end
	end
	return "Common", Color3.fromRGB(220, 220, 220)
end

function RarityRoller.ApplyBonus(baseStats: { [string]: number }, rarity: string): { [string]: number }
	local multiplier = RarityRoller.Multipliers[rarity] or 1.0
	local boosted: { [string]: number } = {}
	for stat, value in pairs(baseStats) do
		boosted[stat] = math.floor(value * multiplier)
	end
	return boosted
end

function RarityRoller.GetColor(rarity: string): Color3
	for _, entry in ipairs(RarityRoller.Table) do
		if entry.rarity == rarity then
			return entry.color
		end
	end
	return Color3.fromRGB(220, 220, 220)
end

return RarityRoller
