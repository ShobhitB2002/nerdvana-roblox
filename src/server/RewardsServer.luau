--!strict
-- RewardsServer: daily login streak + session playtime chests (+ codes in Phase 3)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataServer = require(script.Parent.DataServer)
local QuestServer = require(script.Parent.QuestServer)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local RewardsAction = Remotes:WaitForChild("RewardsAction") :: RemoteEvent

local RewardsServer = {}

-- Session playtime chest tracking (not persisted)
local SessionStart: { [number]: number } = {}
local ChestsClaimed: { [number]: { [number]: boolean } } = {}

local function dailyAvailable(data: any): boolean
	return os.time() - data.lastDailyClaim >= GameConfig.DAILY_COOLDOWN
end

-- ============================================================
-- Daily quest: one rotating task per UTC day, same for everyone
-- ============================================================

type DailyTask = { action: string, key: string, qty: number, label: string }
local DAILY_TASKS: { DailyTask } = {
	{ action = "kill", key = "Wolf", qty = 20, label = "Slay 20 Wolves" },
	{ action = "collect", key = "raw_wood_t1", qty = 100, label = "Gather 100 Raw Wood" },
	{ action = "kill", key = "Bandit", qty = 15, label = "Defeat 15 Bandits" },
	{ action = "collect", key = "raw_fish", qty = 15, label = "Catch 15 Fish" },
	{ action = "collect", key = "raw_stone_t1", qty = 50, label = "Quarry 50 Stone" },
	{ action = "craft", key = "refine_raw_wood_t1", qty = 10, label = "Refine 10 Planks" },
	{ action = "collect", key = "raw_ore_t1", qty = 50, label = "Mine 50 Ore" },
}
local DAILY_QUEST_GOLD = 750
local DAILY_QUEST_DIAMONDS = 5

local function utcDay(): number
	return math.floor(os.time() / 86400)
end

local function ensureDailyQuest(data: any)
	local today = utcDay()
	if data.dailyQuest.day ~= today then
		data.dailyQuest.day = today
		data.dailyQuest.taskIdx = (today % #DAILY_TASKS) + 1
		data.dailyQuest.progress = 0
		data.dailyQuest.done = false
	end
end

local function pushState(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	ensureDailyQuest(data)
	local task_ = DAILY_TASKS[data.dailyQuest.taskIdx] or DAILY_TASKS[1]
	local sessionMinutes = (os.time() - (SessionStart[player.UserId] or os.time())) / 60
	local chests = {}
	for i, chest in ipairs(GameConfig.PLAYTIME_CHESTS) do
		table.insert(chests, {
			minutes = chest.minutes,
			gold = chest.gold,
			diamonds = chest.diamonds,
			ready = sessionMinutes >= chest.minutes,
			claimed = (ChestsClaimed[player.UserId] or {})[i] == true,
		})
	end
	RewardsAction:FireClient(player, "state", {
		dailyAvailable = dailyAvailable(data),
		streak = data.dailyStreak,
		nextDailyIn = math.max(0, GameConfig.DAILY_COOLDOWN - (os.time() - data.lastDailyClaim)),
		sessionMinutes = math.floor(sessionMinutes),
		chests = chests,
		dailyQuest = {
			label = task_.label,
			progress = math.min(data.dailyQuest.progress, task_.qty),
			qty = task_.qty,
			done = data.dailyQuest.done,
			gold = DAILY_QUEST_GOLD,
			diamonds = DAILY_QUEST_DIAMONDS,
		},
	})
end

local function grant(player: Player, gold: number?, diamonds: number?)
	if gold and gold > 0 then
		DataServer.AddGold(player, gold)
	end
	if diamonds and diamonds > 0 then
		DataServer.AddDiamonds(player, diamonds)
	end
end

local function claimDaily(player: Player)
	local data = DataServer.Get(player)
	if not data or not dailyAvailable(data) then
		return
	end
	-- Streak resets if they skipped more than the break window
	if os.time() - data.lastDailyClaim > GameConfig.DAILY_STREAK_BREAK then
		data.dailyStreak = 0
	end
	data.dailyStreak += 1
	data.lastDailyClaim = os.time()

	local dayIdx = ((data.dailyStreak - 1) % #GameConfig.DAILY_REWARDS) + 1
	local reward = GameConfig.DAILY_REWARDS[dayIdx]
	grant(player, reward.gold, reward.diamonds)
	DataServer.Save(player)
	RewardsAction:FireClient(player, "claimed", { kind = "daily", day = dayIdx, gold = reward.gold, diamonds = reward.diamonds })
	pushState(player)
end

local function claimChest(player: Player, idx: number)
	local chest = GameConfig.PLAYTIME_CHESTS[idx]
	if not chest then
		return
	end
	local claimed = ChestsClaimed[player.UserId]
	if not claimed then
		claimed = {}
		ChestsClaimed[player.UserId] = claimed
	end
	if claimed[idx] then
		return
	end
	local sessionMinutes = (os.time() - (SessionStart[player.UserId] or os.time())) / 60
	if sessionMinutes < chest.minutes then
		return
	end
	claimed[idx] = true
	grant(player, chest.gold, chest.diamonds)
	RewardsAction:FireClient(player, "claimed", { kind = "chest", idx = idx, gold = chest.gold, diamonds = chest.diamonds })
	pushState(player)
end

-- Promo codes (Phase 3 fills the table; system live now)
local CODES: { [string]: { gold: number?, diamonds: number? } } = {
	RELEASE = { diamonds = 25 },
	NERDVANA = { gold = 500 },
}

function RewardsServer.RedeemCode(player: Player, code: string)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local key = string.upper((string.gsub(code, "%s", "")))
	local reward = CODES[key]
	if not reward then
		RewardsAction:FireClient(player, "codeResult", { ok = false, msg = "Invalid code" })
		return
	end
	if data.redeemedCodes[key] then
		RewardsAction:FireClient(player, "codeResult", { ok = false, msg = "Already redeemed" })
		return
	end
	data.redeemedCodes[key] = true
	grant(player, reward.gold, reward.diamonds)
	DataServer.Save(player)
	RewardsAction:FireClient(player, "codeResult", { ok = true, msg = "Code redeemed!" })
	pushState(player)
end

RewardsAction.OnServerEvent:Connect(function(player: Player, cmd: unknown, payload: unknown)
	if cmd == "hello" then
		pushState(player)
	elseif cmd == "claimDaily" then
		claimDaily(player)
	elseif cmd == "claimChest" then
		if typeof(payload) == "number" then
			claimChest(player, payload :: number)
		end
	elseif cmd == "redeemCode" then
		if typeof(payload) == "string" then
			RewardsServer.RedeemCode(player, payload :: string)
		end
	end
end)

-- Track player actions for the daily quest
QuestServer.RegisterListener(function(player: Player, actionType: string, key: string, qty: number)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	ensureDailyQuest(data)
	if data.dailyQuest.done then
		return
	end
	local task_ = DAILY_TASKS[data.dailyQuest.taskIdx]
	if not task_ or task_.action ~= actionType or task_.key ~= key then
		return
	end
	data.dailyQuest.progress += qty
	if data.dailyQuest.progress >= task_.qty then
		data.dailyQuest.done = true
		grant(player, DAILY_QUEST_GOLD, DAILY_QUEST_DIAMONDS)
		DataServer.Save(player)
		RewardsAction:FireClient(player, "claimed", { kind = "dailyQuest", gold = DAILY_QUEST_GOLD, diamonds = DAILY_QUEST_DIAMONDS })
	end
	pushState(player)
end)

Players.PlayerAdded:Connect(function(player: Player)
	SessionStart[player.UserId] = os.time()
	ChestsClaimed[player.UserId] = {}
	task.delay(5, function()
		if player.Parent then
			pushState(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	SessionStart[player.UserId] = nil
	ChestsClaimed[player.UserId] = nil
end)

-- Periodically refresh chest readiness so the client timer stays honest
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			pushState(player)
		end
	end
end)

return RewardsServer
