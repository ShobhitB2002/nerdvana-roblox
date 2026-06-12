--!strict
-- GameConfig: shared tuning constants for all systems

local GameConfig = {}

-- World
GameConfig.MAP_HALF = 800 -- main island is 1600x1600
GameConfig.VILLAGE_RADIUS = 95
GameConfig.CORRUPT_OFFSET = Vector3.new(3000, 0, 0)
GameConfig.CORRUPT_SAFE_RADIUS = 45

-- Rebirth
GameConfig.REBIRTH_GOLD_XP_PER = 0.25 -- +25% gold & XP per rebirth (additive)
GameConfig.REBIRTH_DMG_TAKEN_PER = 0.12 -- mobs hit +12% harder per rebirth
GameConfig.REBIRTH_TOKENS = function(newRebirthCount: number): number
	return 1 + math.floor(newRebirthCount / 5)
end

export type RebirthPerk = {
	id: string,
	name: string,
	desc: string,
	cost: number,
}

GameConfig.REBIRTH_PERKS = {
	{ id = "auto_pickup", name = "Magnet Soul", desc = "Loot near you is picked up automatically", cost = 3 },
	{ id = "bag_core", name = "Bag of Holding", desc = "+40 base carry weight", cost = 2 },
	{ id = "gold_aura", name = "Golden Touch", desc = "+10% Gold forever", cost = 2 },
	{ id = "xp_aura", name = "Wise Spirit", desc = "+10% Mastery XP forever", cost = 2 },
	{ id = "lucky_soul", name = "Lucky Soul", desc = "+10% rare craft luck forever", cost = 3 },
} :: { RebirthPerk }

GameConfig.REBIRTH_TITLES = {
	{ at = 1, title = "Reborn", color = Color3.fromRGB(120, 220, 120) },
	{ at = 3, title = "Corrupted", color = Color3.fromRGB(170, 80, 255) },
	{ at = 5, title = "Void Touched", color = Color3.fromRGB(120, 60, 200) },
	{ at = 10, title = "Void Walker", color = Color3.fromRGB(80, 40, 160) },
	{ at = 25, title = "Ascended", color = Color3.fromRGB(255, 215, 0) },
	{ at = 50, title = "NERDVANA", color = Color3.fromRGB(255, 60, 60) },
}

function GameConfig.GetTitle(rebirths: number): (string?, Color3?)
	local best: string? = nil
	local color: Color3? = nil
	for _, t in ipairs(GameConfig.REBIRTH_TITLES) do
		if rebirths >= t.at then
			best = t.title
			color = t.color
		end
	end
	return best, color
end

-- Daily login rewards (7-day cycle; day 7 is the big one)
export type DailyReward = { gold: number?, diamonds: number? }
GameConfig.DAILY_REWARDS = {
	{ gold = 100 },
	{ gold = 250 },
	{ diamonds = 5 },
	{ gold = 500 },
	{ diamonds = 10 },
	{ gold = 1000 },
	{ diamonds = 25, gold = 1000 },
} :: { DailyReward }
GameConfig.DAILY_COOLDOWN = 20 * 3600 -- claimable every 20h
GameConfig.DAILY_STREAK_BREAK = 48 * 3600 -- streak resets after 48h gap

-- Playtime chests (session minutes -> reward)
export type PlaytimeChest = { minutes: number, gold: number?, diamonds: number? }
GameConfig.PLAYTIME_CHESTS = {
	{ minutes = 5, gold = 100 },
	{ minutes = 15, gold = 300 },
	{ minutes = 30, diamonds = 5 },
	{ minutes = 60, gold = 1500 },
	{ minutes = 90, diamonds = 10 },
	{ minutes = 120, gold = 4000, diamonds = 15 },
} :: { PlaytimeChest }

return GameConfig
