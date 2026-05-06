--!strict
-- QuestDB: All tutorial quests

export type Objective = {
	type: string,
	item: string?,
	qty: number?,
	mob: string?,
	recipeId: string?,
	target: string?,
}

export type Quest = {
	id: string,
	title: string,
	description: string,
	npc: string,
	objectives: { Objective },
	rewards: { gold: number, xp: { [string]: number } },
	nextQuest: string?,
}

local QuestDB: { Quests: { Quest } } = {} :: any

QuestDB.Quests = {
	{
		id = "q1_gather_wood",
		title = "First Cut",
		description = "Gather 10 Raw Wood from the trees beyond the village.",
		npc = "Guide",
		objectives = { { type = "collect", item = "raw_wood_t1", qty = 10 } },
		rewards = { gold = 5, xp = {} },
		nextQuest = "q2_refine_planks",
	},
	{
		id = "q2_refine_planks",
		title = "Sawmill Basics",
		description = "Refine your wood into 2 Planks at the Sawmill.",
		npc = "Sawmill Master",
		objectives = { { type = "craft", recipeId = "refine_raw_wood_t1", qty = 2 } },
		rewards = { gold = 5, xp = {} },
		nextQuest = "q3_craft_axe",
	},
	{
		id = "q3_craft_axe",
		title = "The Woodcutter's Edge",
		description = "Craft a Wooden Axe at the Crafting Bench.",
		npc = "Sawmill Master",
		objectives = { { type = "craft", recipeId = "craft_axe_t1", qty = 1 } },
		rewards = { gold = 8, xp = {} },
		nextQuest = "q4_kill_wolves",
	},
	{
		id = "q4_kill_wolves",
		title = "Wolf Problem",
		description = "Slay 3 wolves in the outskirts.",
		npc = "Guide",
		objectives = { { type = "kill", mob = "Wolf", qty = 3 } },
		rewards = { gold = 15, xp = {} },
		nextQuest = "q5_tan_hide",
	},
	{
		id = "q5_tan_hide",
		title = "Tanner's Craft",
		description = "Tan your wolf hides into 2 Leather at the Tanning Rack.",
		npc = "Tanner",
		objectives = { { type = "craft", recipeId = "refine_raw_hide_t1", qty = 2 } },
		rewards = { gold = 10, xp = {} },
		nextQuest = "q6_craft_armor",
	},
	{
		id = "q6_craft_armor",
		title = "Dressed for Battle",
		description = "Craft a full T1 armor set: Helmet, Chest, Boots, Bag.",
		npc = "Tanner",
		objectives = {
			{ type = "craft", recipeId = "craft_helmet_t1", qty = 1 },
			{ type = "craft", recipeId = "craft_chest_t1", qty = 1 },
			{ type = "craft", recipeId = "craft_boots_t1", qty = 1 },
			{ type = "craft", recipeId = "craft_bag_t1", qty = 1 },
		},
		rewards = { gold = 20, xp = {} },
		nextQuest = "q7_craft_sword",
	},
	{
		id = "q7_craft_sword",
		title = "Edge of Steel",
		description = "Craft a T2 Sword at the Forge. You will need T2 Planks and a T1 Sword.",
		npc = "Blacksmith",
		objectives = { { type = "craft", recipeId = "craft_sword_t2", qty = 1 } },
		rewards = { gold = 25, xp = {} },
		nextQuest = "q8_humanoid_boss",
	},
	{
		id = "q8_humanoid_boss",
		title = "Bandit Captain",
		description = "Defeat the Humanoid Mini Boss in the outskirts.",
		npc = "Quest Elder",
		objectives = { { type = "kill", mob = "BanditCaptain", qty = 1 } },
		rewards = { gold = 40, xp = {} },
		nextQuest = "q9_beast_boss",
	},
	{
		id = "q9_beast_boss",
		title = "The Beast Awaits",
		description = "Slay the Final Beast Boss to earn the Beast Seal.",
		npc = "Quest Elder",
		objectives = { { type = "kill", mob = "BeastBoss", qty = 1 } },
		rewards = { gold = 60, xp = {} },
		nextQuest = "q10_portal",
	},
	{
		id = "q10_portal",
		title = "Corrupted Call",
		description = "Use the Beast Seal to unlock and enter the Corrupted Portal.",
		npc = "Portal Keeper",
		objectives = { { type = "interact", target = "CorruptedPortal" } },
		rewards = { gold = 0, xp = {} },
		nextQuest = nil,
	},
}

function QuestDB.Get(id: string): Quest?
	for _, q in ipairs(QuestDB.Quests) do
		if q.id == id then
			return q
		end
	end
	return nil
end

return QuestDB
