--!strict
-- DataServer: Per-player data + DataStore persistence

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = require(ReplicatedStorage.Modules.Shared)
local WeightSystem = require(ReplicatedStorage.Modules.WeightSystem)

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

export type PlayerSave = {
	gold: number,
	diamonds: number,
	inventory: Shared.CategorizedInventory,
	equipped: Equipped,
	mastery: { [string]: number },
	quests: QuestState,
	portalUnlocked: boolean,
	isCorrupted: boolean,
}

local SAVE_ENABLED = true
local DATASTORE_NAME = "Nerdvana_v1"

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

local function defaultData(): PlayerSave
	return {
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
		mastery = { Wood = 0, Hide = 0, Ore = 0, Stone = 0, Sword = 0, Bow = 0, Staff = 0, Dagger = 0, Leather = 0, Blacksmithing = 0, Tool = 0, Refining = 0 },
		quests = { active = "q1_gather_wood", completed = {} },
		portalUnlocked = false,
		isCorrupted = false,
	}
end

local function mergeLoaded(loaded: { [string]: any }): PlayerSave
	local d = defaultData()
	if typeof(loaded.gold) == "number" then
		d.gold = loaded.gold
	end
	if typeof(loaded.diamonds) == "number" then
		d.diamonds = loaded.diamonds
	end
	if typeof(loaded.inventory) == "table" then
		-- Convert old flat inventory to categorized if needed
		if #loaded.inventory > 0 then
			d.inventory = {
				materials = {},
				gear = {},
				tools = {},
				consumables = {},
				quest = {},
				currency = {},
			}
			-- Migrate existing items to categorized system
			for _, slot in ipairs(loaded.inventory :: { Shared.InventorySlot }) do
				Shared.AddToCategorizedInventory(d.inventory, slot.id, slot.quantity, slot.quality, slot.rarity)
			end
		else
			d.inventory = loaded.inventory :: Shared.CategorizedInventory
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
		for _, line in ipairs({ "Wood", "Hide", "Ore", "Stone", "Sword", "Bow", "Staff", "Dagger", "Leather", "Blacksmithing", "Tool", "Refining" }) do
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
	if typeof(loaded.portalUnlocked) == "boolean" then
		d.portalUnlocked = loaded.portalUnlocked
	end
	if typeof(loaded.isCorrupted) == "boolean" then
		d.isCorrupted = loaded.isCorrupted
	end
	return d
end

local DataServer = {}

function DataServer.PushHUD(player: Player)
	local d = PlayerData[player.UserId]
	if not d then
		return
	end
	local w = Shared.CalculateCategorizedWeight(d.inventory)
	local maxW = WeightSystem.GetCapacity(d.equipped.bag)
	UpdateHUD:FireClient(player, {
		gold = d.gold,
		diamonds = d.diamonds,
		weight = w,
		maxWeight = maxW,
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
	pcall(function()
		PlayerDataStore:SetAsync(uid, data)
	end)
end

function DataServer.AddGold(player: Player, amount: number)
	local d = PlayerData[player.UserId]
	if d then
		d.gold += amount
		DataServer.PushHUD(player)
	end
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
	local maxWeight = WeightSystem.GetCapacity(d.equipped.bag)
	local itemDef = ItemDB.Get(itemId)
	if itemDef then
		local itemWeight = (itemDef.weight * (qty or 1))
		if currentWeight + itemWeight > maxWeight then
			return false, "overweight"
		end
	end
	Shared.AddToCategorizedInventory(d.inventory, itemId, qty, nil, rarity)
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

local function loadData(player: Player)
	-- Reserve slot immediately so gathering/combat cannot run with nil data while GetAsync yields.
	PlayerData[player.UserId] = defaultData()

	if SAVE_ENABLED and PlayerDataStore then
		local uid = "player_" .. tostring(player.UserId)
		local ok, data = pcall(function()
			return PlayerDataStore:GetAsync(uid)
		end)
		if ok and data and typeof(data) == "table" then
			PlayerData[player.UserId] = mergeLoaded(data :: { [string]: any })
		end
	end

	local d = PlayerData[player.UserId] :: PlayerSave
	DataServer.PushHUD(player)
	UpdateInventory:FireClient(player, d.inventory, d.equipped)
	UpdateMastery:FireClient(player, d.mastery)
end

Players.PlayerAdded:Connect(function(player: Player)
	loadData(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	DataServer.Save(player)
	PlayerData[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataServer.Save(player)
	end
end)

return DataServer
