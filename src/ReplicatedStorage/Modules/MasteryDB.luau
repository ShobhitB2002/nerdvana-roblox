--!strict
-- MasteryDB: Mastery XP thresholds and tier definitions

local MasteryDB = {}

MasteryDB.Lines = {
	"Wood", "Hide", "Ore", "Stone", "Fishing", -- Gathering
	"Sword", "Bow", "Staff", "Dagger", -- Combat
	"Leather", "Blacksmithing", "Tool", "Refining", -- Crafting
}

MasteryDB.TierThresholds = {
	[1] = 0,
	[2] = 100,
	[3] = 300,
	[4] = 700,
	[5] = 1300,
	[6] = 2100,
	[7] = 3200,
	[8] = 4700,
}

function MasteryDB.GetTier(xp: number): number
	local tier = 1
	for t = 8, 1, -1 do
		local thresh = MasteryDB.TierThresholds[t]
		if thresh ~= nil and xp >= thresh then
			tier = t
			break
		end
	end
	return tier
end

function MasteryDB.GetNextThreshold(xp: number): number
	local tier = MasteryDB.GetTier(xp)
	if tier >= 8 then
		return MasteryDB.TierThresholds[8] :: number
	end
	return MasteryDB.TierThresholds[tier + 1] :: number
end

function MasteryDB.GetCurrentThreshold(xp: number): number
	local tier = MasteryDB.GetTier(xp)
	return MasteryDB.TierThresholds[tier] :: number
end

return MasteryDB
