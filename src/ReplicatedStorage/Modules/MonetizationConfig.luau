--!strict
-- MonetizationConfig: ALL Robux product IDs live here.
--
-- HOW TO GO LIVE (after publishing the game):
--   1. create.roblox.com → your experience → Monetization → Passes: create each
--      gamepass below, then paste its numeric ID over the 0.
--   2. Monetization → Developer Products: create each product below, paste IDs.
--   3. Republish. Items with ID 0 show as "Coming Soon" in the in-game shop.
-- Full details (names, prices, descriptions): see MONETIZATION_SETUP.md in the repo.

local MonetizationConfig = {}

-- One-time purchases (Gamepasses)
MonetizationConfig.Gamepasses = {
	VIP = 1876070427, -- +25% Gold & XP forever, VIP chat tag color
	AutoGather = 1876196416, -- automatically gathers nearby resources
	AutoPickup = 1876010429, -- automatically picks up nearby loot
	Luck2x = 1876412411, -- double odds for rare crafts & eggs
	CompanionSlots = 1874496420, -- +3 equipped companion slots (6 total)
	BiggerBag = 1875764438, -- +50 carry weight forever
}

-- Repeatable purchases (Developer Products)
MonetizationConfig.Products = {
	Diamonds100 = 3604109258,
	Diamonds550 = 3604109416, -- 10% bonus
	Diamonds1200 = 3604109581, -- 20% bonus
	Diamonds3000 = 3604109713, -- 50% bonus
	Gold5k = 3604109919,
	Gold25k = 3604110250,
	LuckPotion30 = 3604110394, -- 30 min of 2x luck
	GoldPotion30 = 3604110536, -- 30 min of 2x gold
	InstantRebirth = 3604110946, -- rebirth without beating the boss
}

export type AuraDef = { id: string, name: string, cost: number, color: Color3 }

-- Diamond-shop cosmetics (no Robux needed — drives diamond demand)
MonetizationConfig.Auras = {
	{ id = "aura_blue", name = "Azure Aura", cost = 75, color = Color3.fromRGB(80, 160, 255) },
	{ id = "aura_gold", name = "Golden Aura", cost = 200, color = Color3.fromRGB(255, 215, 0) },
	{ id = "aura_void", name = "Void Aura", cost = 500, color = Color3.fromRGB(140, 40, 220) },
	{ id = "aura_blood", name = "Blood Aura", cost = 1000, color = Color3.fromRGB(255, 40, 40) },
} :: { AuraDef }

function MonetizationConfig.GetAura(id: string): AuraDef?
	for _, a in ipairs(MonetizationConfig.Auras) do
		if a.id == id then
			return a
		end
	end
	return nil
end

return MonetizationConfig
