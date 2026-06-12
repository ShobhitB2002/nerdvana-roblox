--!strict
-- CompanionDB: companions (pets) + egg definitions

export type Boosts = {
	gold: number?,
	xp: number?,
	gather: number?,
	damage: number?,
	luck: number?,
}

export type CompanionDef = {
	id: string,
	name: string,
	rarity: string, -- Common/Uncommon/Rare/Epic/Legendary/Mythic
	color: Color3,
	boosts: Boosts,
	fuseInto: string?, -- 3x this companion -> 1x fuseInto
}

export type EggPoolEntry = { id: string, weight: number }

export type EggDef = {
	id: string,
	name: string,
	currency: string, -- "gold" | "diamonds"
	cost: number,
	pool: { EggPoolEntry },
}

local CompanionDB = {}

CompanionDB.Companions = {
	-- Basic Egg line
	["chick"] = { id = "chick", name = "Chick", rarity = "Common", color = Color3.fromRGB(255, 230, 100), boosts = { gold = 1.05 }, fuseInto = "puppy" },
	["bunny"] = { id = "bunny", name = "Bunny", rarity = "Common", color = Color3.fromRGB(230, 230, 230), boosts = { gather = 1.05 }, fuseInto = "kitten" },
	["puppy"] = { id = "puppy", name = "Puppy", rarity = "Uncommon", color = Color3.fromRGB(180, 130, 80), boosts = { gold = 1.08 }, fuseInto = "piglet" },
	["kitten"] = { id = "kitten", name = "Kitten", rarity = "Uncommon", color = Color3.fromRGB(120, 120, 130), boosts = { xp = 1.08 }, fuseInto = "piglet" },
	["piglet"] = { id = "piglet", name = "Piglet", rarity = "Rare", color = Color3.fromRGB(255, 170, 180), boosts = { gold = 1.12 }, fuseInto = "fox" },
	["fox"] = { id = "fox", name = "Fox", rarity = "Epic", color = Color3.fromRGB(230, 110, 40), boosts = { gather = 1.12, gold = 1.08 } },

	-- Forest Egg line
	["squirrel"] = { id = "squirrel", name = "Squirrel", rarity = "Common", color = Color3.fromRGB(170, 110, 60), boosts = { xp = 1.07 }, fuseInto = "owl" },
	["owl"] = { id = "owl", name = "Owl", rarity = "Uncommon", color = Color3.fromRGB(150, 140, 120), boosts = { xp = 1.1 }, fuseInto = "stag" },
	["boar"] = { id = "boar", name = "Boar", rarity = "Uncommon", color = Color3.fromRGB(90, 70, 60), boosts = { damage = 1.1 }, fuseInto = "stag" },
	["stag"] = { id = "stag", name = "Stag", rarity = "Rare", color = Color3.fromRGB(200, 170, 120), boosts = { gold = 1.15 }, fuseInto = "treeling" },
	["treeling"] = { id = "treeling", name = "Treeling", rarity = "Epic", color = Color3.fromRGB(80, 160, 70), boosts = { xp = 1.18, gather = 1.1 }, fuseInto = "forest_spirit" },
	["forest_spirit"] = { id = "forest_spirit", name = "Forest Spirit", rarity = "Legendary", color = Color3.fromRGB(140, 255, 170), boosts = { gold = 1.2, luck = 0.15 } },

	-- Corrupted Egg line
	["shade"] = { id = "shade", name = "Shade", rarity = "Uncommon", color = Color3.fromRGB(60, 50, 80), boosts = { damage = 1.12 }, fuseInto = "imp" },
	["imp"] = { id = "imp", name = "Imp", rarity = "Rare", color = Color3.fromRGB(150, 60, 200), boosts = { gold = 1.18 }, fuseInto = "void_pup" },
	["void_pup"] = { id = "void_pup", name = "Void Pup", rarity = "Epic", color = Color3.fromRGB(100, 40, 160), boosts = { damage = 1.2, xp = 1.1 }, fuseInto = "crystal_wisp" },
	["crystal_wisp"] = { id = "crystal_wisp", name = "Crystal Wisp", rarity = "Legendary", color = Color3.fromRGB(140, 220, 255), boosts = { luck = 0.2, gold = 1.15 }, fuseInto = "corrupted_wolf" },
	["corrupted_wolf"] = { id = "corrupted_wolf", name = "Corrupted Wolf", rarity = "Mythic", color = Color3.fromRGB(170, 40, 255), boosts = { damage = 1.35, gold = 1.25 } },

	-- Royal Egg line (premium)
	["royal_corgi"] = { id = "royal_corgi", name = "Royal Corgi", rarity = "Rare", color = Color3.fromRGB(255, 200, 120), boosts = { gold = 1.2 }, fuseInto = "gilded_cat" },
	["gilded_cat"] = { id = "gilded_cat", name = "Gilded Cat", rarity = "Epic", color = Color3.fromRGB(255, 215, 0), boosts = { gold = 1.25 }, fuseInto = "phoenix" },
	["phoenix"] = { id = "phoenix", name = "Phoenix", rarity = "Legendary", color = Color3.fromRGB(255, 110, 40), boosts = { xp = 1.3, damage = 1.15 }, fuseInto = "dragon_whelp" },
	["dragon_whelp"] = { id = "dragon_whelp", name = "Dragon Whelp", rarity = "Mythic", color = Color3.fromRGB(200, 40, 40), boosts = { gold = 1.3, xp = 1.3, damage = 1.3 } },
	["cherub"] = { id = "cherub", name = "Angelic Cherub", rarity = "Mythic", color = Color3.fromRGB(255, 255, 220), boosts = { luck = 0.35, gold = 1.3 } },
	["void_lord"] = { id = "void_lord", name = "VOID LORD", rarity = "Mythic", color = Color3.fromRGB(20, 0, 40), boosts = { gold = 1.5, xp = 1.5, damage = 1.5, gather = 1.5, luck = 0.5 } },
} :: { [string]: CompanionDef }

CompanionDB.Eggs = {
	{
		id = "egg_basic",
		name = "Basic Egg",
		currency = "gold",
		cost = 750,
		pool = {
			{ id = "chick", weight = 4500 },
			{ id = "bunny", weight = 3000 },
			{ id = "puppy", weight = 1200 },
			{ id = "kitten", weight = 800 },
			{ id = "piglet", weight = 400 },
			{ id = "fox", weight = 100 },
		},
	},
	{
		id = "egg_forest",
		name = "Forest Egg",
		currency = "gold",
		cost = 4000,
		pool = {
			{ id = "squirrel", weight = 4200 },
			{ id = "owl", weight = 2500 },
			{ id = "boar", weight = 2000 },
			{ id = "stag", weight = 900 },
			{ id = "treeling", weight = 350 },
			{ id = "forest_spirit", weight = 50 },
		},
	},
	{
		id = "egg_corrupted",
		name = "Corrupted Egg",
		currency = "gold",
		cost = 15000,
		pool = {
			{ id = "shade", weight = 5000 },
			{ id = "imp", weight = 3000 },
			{ id = "void_pup", weight = 1500 },
			{ id = "crystal_wisp", weight = 450 },
			{ id = "corrupted_wolf", weight = 50 },
		},
	},
	{
		id = "egg_royal",
		name = "Royal Egg",
		currency = "diamonds",
		cost = 99,
		pool = {
			{ id = "royal_corgi", weight = 5500 },
			{ id = "gilded_cat", weight = 2800 },
			{ id = "phoenix", weight = 1200 },
			{ id = "dragon_whelp", weight = 350 },
			{ id = "cherub", weight = 145 },
			{ id = "void_lord", weight = 5 }, -- 1 in 2000
		},
	},
} :: { EggDef }

function CompanionDB.Get(id: string): CompanionDef?
	return CompanionDB.Companions[id]
end

function CompanionDB.GetEgg(id: string): EggDef?
	for _, egg in ipairs(CompanionDB.Eggs) do
		if egg.id == id then
			return egg
		end
	end
	return nil
end

CompanionDB.RarityColors = {
	Common = Color3.fromRGB(220, 220, 220),
	Uncommon = Color3.fromRGB(80, 220, 80),
	Rare = Color3.fromRGB(60, 120, 255),
	Epic = Color3.fromRGB(160, 60, 255),
	Legendary = Color3.fromRGB(255, 165, 0),
	Mythic = Color3.fromRGB(255, 40, 40),
} :: { [string]: Color3 }

return CompanionDB
