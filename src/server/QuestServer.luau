--!strict
-- QuestServer: Server-authoritative quest progress, rewards and sync

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataServer = require(script.Parent.DataServer)
local QuestDB = require(ReplicatedStorage.Modules.QuestDB)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local QuestUpdate = Remotes:WaitForChild("QuestUpdate") :: RemoteEvent
local UpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent

-- Per-session objective progress (objective key -> count) for the active quest
local Progress: { [number]: { [string]: number } } = {}

local QuestServer = {}

local function objectiveKey(obj: QuestDB.Objective): string
	return obj.item or obj.mob or obj.target or obj.recipeId or "?"
end

function QuestServer.PushState(player: Player, justCompleted: string?)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	QuestUpdate:FireClient(player, {
		activeQuestId = data.quests.active,
		progress = Progress[player.UserId] or {},
		justCompleted = justCompleted,
	})
end

local function checkCompletion(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local quest = QuestDB.Get(data.quests.active)
	if not quest then
		return
	end
	local prog = Progress[player.UserId] or {}
	for _, obj in ipairs(quest.objectives) do
		if (prog[objectiveKey(obj)] or 0) < (obj.qty or 1) then
			return
		end
	end

	-- Quest complete: grant rewards, advance
	if quest.rewards.gold > 0 then
		DataServer.AddGold(player, quest.rewards.gold)
	end
	for line, xp in pairs(quest.rewards.xp) do
		DataServer.AddMastery(player, line, xp)
	end
	UpdateMastery:FireClient(player, data.mastery)

	table.insert(data.quests.completed, quest.id)
	Progress[player.UserId] = {}
	if quest.nextQuest then
		data.quests.active = quest.nextQuest
	else
		data.quests.active = ""
	end
	DataServer.Save(player)
	QuestServer.PushState(player, quest.id)
end

-- Admin: instantly complete the active quest
function QuestServer.ForceComplete(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local quest = QuestDB.Get(data.quests.active)
	if not quest then
		return
	end
	local prog = Progress[player.UserId]
	if not prog then
		prog = {}
		Progress[player.UserId] = prog
	end
	for _, obj in ipairs(quest.objectives) do
		prog[objectiveKey(obj)] = obj.qty or 1
	end
	checkCompletion(player)
end

function QuestServer.Progress(player: Player, actionType: string, key: string, qty: number?)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local quest = QuestDB.Get(data.quests.active)
	if not quest then
		return
	end

	local prog = Progress[player.UserId]
	if not prog then
		prog = {}
		Progress[player.UserId] = prog
	end

	local amount = qty or 1
	local changed = false
	for _, obj in ipairs(quest.objectives) do
		local matches = (actionType == "collect" and obj.type == "collect" and obj.item == key)
			or (actionType == "kill" and obj.type == "kill" and obj.mob == key)
			or (actionType == "craft" and obj.type == "craft" and obj.recipeId == key)
			or (actionType == "interact" and obj.type == "interact" and obj.target == key)
		if matches then
			local k = objectiveKey(obj)
			prog[k] = (prog[k] or 0) + amount
			changed = true
		end
	end

	if changed then
		QuestServer.PushState(player)
		checkCompletion(player)
	end
end

local RequestSync = Remotes:WaitForChild("RequestSync") :: RemoteEvent
RequestSync.OnServerEvent:Connect(function(player: Player)
	QuestServer.PushState(player)
end)

Players.PlayerAdded:Connect(function(player: Player)
	-- Wait for DataServer to finish loading, then sync quest state to client
	task.spawn(function()
		for _ = 1, 100 do
			if DataServer.Get(player) then
				break
			end
			task.wait(0.2)
		end
		QuestServer.PushState(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	Progress[player.UserId] = nil
end)

return QuestServer
