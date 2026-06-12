--!strict
-- DataServer: Per-player data + DataStore persistence (UpdateAsync with retries, autosave)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage.Modules.Shared)
local WeightSystem = require(ReplicatedStorage.Modules.WeightSystem)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

export type Equipped = {
	helmet: string?,
	chest: string?,
	boots: string?,
	bag: string?,
	weapon: string?,
	tool: string?,
}

export type QuestState = {
	active: string,
	completed: { string },
}

export type Stats = {
	totalGoldEarned: number,
	playtime: number,
	mobKills: number,
	gathered: number,
}

export type PlayerSave = {
	version: number,
	gold: number,
	diamonds: number,
	inventory: Shared.CategorizedInventory,
	equipped: Equipped,
	mastery: { [string]: number },
	quests: QuestState,
	portalUnlocked: boolean,
	isCorrupted: boolean,
	-- Rebirth
	rebirths: number,
	rebirthTokens: number,
	rebirthPerks: { [string]: boolean },
	canRebirth: boolean,
	-- Meta progression
	stats: Stats,
	lastDailyClaim: number,
	dailyStreak: number,
	companions: { [string]: number },
	equippedCompanions: { string },
	index: { items: { [string]: boolean }, mobs: { [string]: boolean }, companions: { [string]: boolean } },
	indexClaimed: { [string]: boolean },
	redeemedCodes: { [string]: boolean },
	boostsUntil: { [string]: number },
	purchaseIds: { string },
	cosmetics: { owned: { [string]: boolean }, equippedAura: string? },
}

local SAVE_ENABLED = true
local DATASTORE_NAME = "Nerdvana_v1"
local AUTOSAVE_INTERVAL = 90
local SAVE_RETRIES = 3

local PlayerDataStore: DataStore?
local okInit, errInit = pcall(function()
	PlayerDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
end)
if not okInit then
	warn("[DataServer] DataStore init failed (Studio API access?): ", errInit)
	PlayerDataStore = nil
end

local PlayerData: { [number]: PlayerSave } = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local UpdateHUD = Remotes:WaitForChild("UpdateHUD") :: RemoteEvent
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent
local UpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent

local MASTERY_LINES = { "Wood", "Hide", "Ore", "Stone", "Fishing", "Sword", "Bow", "Staff", "Dagger", "Leather", "Blacksmithing", "Tool", "Refining" }

local function defaultData(): PlayerSave
	local mastery: { [string]: number } = {}
	for _, line in ipairs(MASTERY_LINES) do
		mastery[line] = 0
	end
	return {
		version = 2,
		gold = 10,
		diamonds = 0,
		inventory = {
			materials = {},
			gear = {},
			tools = {},
			consumables = {},
			quest = {},
			currency = {},
		},
		equipped = { helmet = nil, chest = nil, boots = nil, bag = nil, weapon = nil, tool = nil },
		mastery = mastery,
		quests = { active = "q1_gather_wood", completed = {} },
		portalUnlocked = false,
		isCorrupted = false,
		rebirths = 0,
		rebirthTokens = 0,
		rebirthPerks = {},
		canRebirth = false,
		stats = { totalGoldEarned = 0, playtime = 0, mobKills = 0, gathered = 0 },
		lastDailyClaim = 0,
		dailyStreak = 0,
		companions = {},
		equippedCompanions = {},
		index = { items = {}, mobs = {}, companions = {} },
		indexClaimed = {},
		redeemedCodes = {},
		boostsUntil = {},
		purchaseIds = {},
		cosmetics = { owned = {}, equippedAura = nil },
	}
end

local function mergeNum(d: { [string]: any }, l: { [string]: any }, key: string)
	if typeof(l[key]) == "number" then
		d[key] = l[key]
	end
end

local function mergeBool(d: { [string]: any }, l: { [string]: any }, key: string)
	if typeof(l[key]) == "boolean" then
		d[key] = l[key]
	end
end

local function mergeTable(d: { [string]: any }, l: { [string]: any }, key: string)
	if typeof(l[key]) == "table" then
		d[key] = l[key]
	end
end

local function mergeLoaded(loaded: { [string]: any }): PlayerSave
	local d = defaultData()
	local da = d :: any

	mergeNum(da, loaded, "gold")
	mergeNum(da, loaded, "diamonds")
	mergeNum(da, loaded, "rebirths")
	mergeNum(da, loaded, "rebirthTokens")
	mergeNum(da, loaded, "lastDailyClaim")
	mergeNum(da, loaded, "dailyStreak")
	mergeBool(da, loaded, "portalUnlocked")
	mergeBool(da, loaded, "canRebirth")
	mergeTable(da, loaded, "rebirthPerks")
	mergeTable(da, loaded, "companions")
	mergeTable(da, loaded, "equippedCompanions")
	mergeTable(da, loaded, "indexClaimed")
	mergeTable(da, loaded, "redeemedCodes")
	mergeTable(da, loaded, "boostsUntil")
	mergeTable(da, loaded, "purchaseIds")

	if typeof(loaded.index) == "table" then
		local idx = loaded.index :: { [string]: any }
		if typeof(idx.items) == "table" then
			d.index.items = idx.items
		end
		if typeof(idx.mobs) == "table" then
			d.index.mobs = idx.mobs
		end
		if typeof(idx.companions) == "table" then
			d.index.companions = idx.companions
		end
	end

	if typeof(loaded.cosmetics) == "table" then
		local c = loaded.cosmetics :: { [string]: any }
		if typeof(c.owned) == "table" then
			d.cosmetics.owned = c.owned
		end
		if typeof(c.equippedAura) == "string" then
			d.cosmetics.equippedAura = c.equippedAura
		end
	end

	if typeof(loaded.stats) == "table" then
		local s = loaded.stats :: { [string]: any }
		for _, k in ipairs({ "totalGoldEarned", "playtime", "mobKills", "gathered" }) do
			if typeof(s[k]) == "number" then
				(d.stats :: any)[k] = s[k]
			end
		end
	end

	if typeof(loaded.inventory) == "table" then
		if #loaded.inventory > 0 then
			-- Migrate v0 flat inventory to categorized
			d.inventory = {
				materials = {},
				gear = {},
				tools = {},
				consumables = {},
				quest = {},
				currency = {},
			}
			for _, slot in ipairs(loaded.inventory :: { Shared.InventorySlot }) do
				Shared.AddToCategorizedInventory(d.inventory, slot.id, slot.quantity, slot.quality, slot.rarity)
			end
		else
			local inv = loaded.inventory :: any
			-- Guard against missing categories from older saves
			for _, cat in ipairs({ "materials", "gear", "tools", "consumables", "quest", "currency" }) do
				if typeof(inv[cat]) ~= "table" then
					inv[cat] = {}
				end
			end
			d.inventory = inv :: Shared.CategorizedInventory
		end
	end

	if typeof(loaded.equipped) == "table" then
		local e = loaded.equipped :: { [string]: any }
		d.equipped = {
			helmet = if typeof(e.helmet) == "string" then e.helmet else nil,
			chest = if typeof(e.chest) == "string" then e.chest else nil,
			boots = if typeof(e.boots) == "string" then e.boots else nil,
			bag = if typeof(e.bag) == "string" then e.bag else nil,
			weapon = if typeof(e.weapon) == "string" then e.weapon else nil,
			tool = if typeof(e.tool) == "string" then e.tool else nil,
		}
	end

	if typeof(loaded.mastery) == "table" then
		local m = loaded.mastery :: { [string]: any }
		for _, line in ipairs(MASTERY_LINES) do
			if typeof(m[line]) == "number" then
				d.mastery[line] = m[line]
			end
		end
	end

	if typeof(loaded.quests) == "table" then
		local q = loaded.quests :: { [string]: any }
		if typeof(q.active) == "string" then
			d.quests.active = q.active
		end
		if typeof(q.completed) == "table" then
			d.quests.completed = q.completed :: { string }
		end
	end

	mergeBool(da, loaded, "isCorrupted")
	return d
end

local DataServer = {}

function DataServer.GetMaxWeight(player: Player): number
	local d = PlayerData[player.UserId]
	if not d then
		return WeightSystem.BaseCapacity
	end
	local cap = WeightSystem.GetCapacity(d.equipped.bag)
	if d.rebirthPerks["bag_core"] then
		cap += 40
	end
	-- Phase 3: gamepass bag bonus is added via the BiggerBag attribute
	local extra = player:GetAttribute("BagBonus")
	if typeof(extra) == "number" then
		cap += extra
	end
	return cap
end

function DataServer.PushHUD(player: Player)
	local d = PlayerData[player.UserId]
	if not d then
		return
	end
	local w = Shared.CalculateCategorizedWeight(d.inventory)
	UpdateHUD:FireClient(player, {
		gold = d.gold,
		diamonds = d.diamonds,
		weight = w,
		maxWeight = DataServer.GetMaxWeight(player),
		rebirths = d.rebirths,
		goldMult = 1 + d.rebirths * GameConfig.REBIRTH_GOLD_XP_PER,
	})
end

function DataServer.Get(player: Player): PlayerSave?
	return PlayerData[player.UserId]
end

function DataServer.Save(player: Player)
	if not SAVE_ENABLED or not PlayerDataStore then
		return
	end
	local data = PlayerData[player.UserId]
	if not data then
		return
	end
	local uid = "player_" .. tostring(player.UserId)
	for attempt = 1, SAVE_RETRIES do
		local ok, err = pcall(function()
			(PlayerDataStore :: DataStore):UpdateAsync(uid, function()
				return data
			end)
		end)
		if ok then
			return
		end
		warn("[DataServer] Save attempt " .. attempt .. " failed for " .. player.Name .. ": " .. tostring(err))
		if attempt < SAVE_RETRIES then
			task.wait(attempt * 2)
		end
	end
end

function DataServer.AddGold(player: Player, amount: number)
	local d = PlayerData[player.UserId]
	if d then
		d.gold = math.max(0, d.gold + amount)
		if amount > 0 then
			d.stats.totalGoldEarned += amount
		end
		DataServer.PushHUD(player)
	end
end

function DataServer.SpendGold(player: Player, amount: number): boolean
	local d = PlayerData[player.UserId]
	if not d or d.gold < amount then
		return false
	end
	d.gold -= amount
	DataServer.PushHUD(player)
	return true
end

function DataServer.AddDiamonds(player: Player, amount: number)
	local d = PlayerData[player.UserId]
	if d then
		d.diamonds = math.max(0, d.diamonds + amount)
		DataServer.PushHUD(player)
	end
end

function DataServer.SpendDiamonds(player: Player, amount: number): boolean
	local d = PlayerData[player.UserId]
	if not d or d.diamonds < amount then
		return false
	end
	d.diamonds -= amount
	DataServer.PushHUD(player)
	return true
end

function DataServer.AddMastery(player: Player, line: string, xp: number)
	local d = PlayerData[player.UserId]
	if d and d.mastery[line] ~= nil then
		d.mastery[line] += xp
	end
end

function DataServer.AddToInventory(player: Player, itemId: string, qty: number?, rarity: string?): (boolean, string?)
	local d = PlayerData[player.UserId]
	if not d then
		return false, "nodata"
	end
	local currentWeight = Shared.CalculateCategorizedWeight(d.inventory)
	local maxWeight = DataServer.GetMaxWeight(player)
	local itemDef = ItemDB.Get(itemId)
	if itemDef then
		local itemWeight = (itemDef.weight * (qty or 1))
		if currentWeight + itemWeight > maxWeight then
			return false, "overweight"
		end
	end
	Shared.AddToCategorizedInventory(d.inventory, itemId, qty, nil, rarity)
	d.index.items[itemId] = true
	DataServer.PushHUD(player)
	return true, nil
end

function DataServer.RemoveFromInventory(player: Player, itemId: string, qty: number?): boolean
	local d = PlayerData[player.UserId]
	if not d then
		return false
	end
	local ok = Shared.RemoveFromCategorizedInventory(d.inventory, itemId, qty)
	if ok then
		DataServer.PushHUD(player)
	end
	return ok
end

function DataServer.PushAll(player: Player)
	local d = PlayerData[player.UserId]
	if not d then
		return
	end
	DataServer.PushHUD(player)
	UpdateInventory:FireClient(player, d.inventory, d.equipped)
	UpdateMastery:FireClient(player, d.mastery)
end

function DataServer.Reset(player: Player)
	PlayerData[player.UserId] = defaultData()
	DataServer.PushAll(player)
	DataServer.Save(player)
end

-- Rebirth: wipe the "life" but keep meta progression
function DataServer.ResetLife(player: Player)
	local d = PlayerData[player.UserId]
	if not d then
		return
	end
	local fresh = defaultData()
	d.gold = fresh.gold
	d.inventory = fresh.inventory
	d.equipped = fresh.equipped
	d.mastery = fresh.mastery
	d.quests = fresh.quests
	d.portalUnlocked = false
	d.isCorrupted = false
	d.canRebirth = false
	DataServer.PushAll(player)
end

local function loadData(player: Player)
	-- Reserve slot immediately so gathering/combat cannot run with nil data while GetAsync yields.
	PlayerData[player.UserId] = defaultData()

	if SAVE_ENABLED and PlayerDataStore then
		local uid = "player_" .. tostring(player.UserId)
		local ok, data = pcall(function()
			return (PlayerDataStore :: DataStore):GetAsync(uid)
		end)
		if ok and data and typeof(data) == "table" then
			PlayerData[player.UserId] = mergeLoaded(data :: { [string]: any })
		elseif not ok then
			warn("[DataServer] Load failed for " .. player.Name .. ": " .. tostring(data))
		end
	end

	local d = PlayerData[player.UserId] :: PlayerSave
	-- Players always respawn in the main village, never inside the corrupted zone
	d.isCorrupted = false
	DataServer.PushAll(player)
end

Players.PlayerAdded:Connect(function(player: Player)
	loadData(player)
end)

-- Clients request a full resync once their UI scripts have bound their listeners
local RequestSync = Remotes:WaitForChild("RequestSync") :: RemoteEvent
RequestSync.OnServerEvent:Connect(function(player: Player)
	if PlayerData[player.UserId] then
		DataServer.PushAll(player)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	DataServer.Save(player)
	PlayerData[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataServer.Save(player)
	end
	task.wait(2)
end)

-- Autosave + playtime accumulation
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local d = PlayerData[player.UserId]
			if d then
				d.stats.playtime += AUTOSAVE_INTERVAL
				task.spawn(DataServer.Save, player)
			end
		end
	end
end)

return DataServer
