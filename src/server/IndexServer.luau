--!strict
-- IndexServer: collection log + milestone rewards

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataServer = require(script.Parent.DataServer)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)
local MobDB = require(ReplicatedStorage.Modules.MobDB)
local CompanionDB = require(ReplicatedStorage.Modules.CompanionDB)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local IndexAction = Remotes:WaitForChild("IndexAction") :: RemoteEvent

local IndexServer = {}

-- Milestone rewards in diamonds, per category, at 25/50/75/100% discovered
local MILESTONES = { 25, 50, 75, 100 }
local MILESTONE_DIAMONDS = { 5, 10, 15, 30 }

local function countTotal(category: string): number
	local n = 0
	if category == "items" then
		for _ in pairs(ItemDB.Items) do
			n += 1
		end
	elseif category == "mobs" then
		for _ in pairs(MobDB.Mobs) do
			n += 1
		end
	elseif category == "companions" then
		for _ in pairs(CompanionDB.Companions) do
			n += 1
		end
	end
	return n
end

local function countDiscovered(data: any, category: string): number
	local n = 0
	for _ in pairs(data.index[category] or {}) do
		n += 1
	end
	return n
end

local function pctFor(data: any, category: string): number
	local total = countTotal(category)
	if total == 0 then
		return 0
	end
	return math.floor(countDiscovered(data, category) / total * 100)
end

local function pushState(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local cats = {}
	for _, category in ipairs({ "items", "mobs", "companions" }) do
		cats[category] = {
			discovered = data.index[category],
			total = countTotal(category),
			pct = pctFor(data, category),
		}
	end
	IndexAction:FireClient(player, "state", {
		categories = cats,
		claimed = data.indexClaimed,
	})
end

local function claim(player: Player, category: string, milestoneIdx: number)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local pctNeeded = MILESTONES[milestoneIdx]
	if not pctNeeded then
		return
	end
	local key = category .. "_" .. tostring(pctNeeded)
	if data.indexClaimed[key] then
		return
	end
	if pctFor(data, category) < pctNeeded then
		IndexAction:FireClient(player, "error", "Not discovered enough yet")
		return
	end
	data.indexClaimed[key] = true
	DataServer.AddDiamonds(player, MILESTONE_DIAMONDS[milestoneIdx])
	DataServer.Save(player)
	IndexAction:FireClient(player, "claimed", { category = category, pct = pctNeeded, diamonds = MILESTONE_DIAMONDS[milestoneIdx] })
	pushState(player)
end

IndexAction.OnServerEvent:Connect(function(player: Player, cmd: unknown, payload: unknown)
	if cmd == "hello" then
		pushState(player)
	elseif cmd == "claim" and typeof(payload) == "table" then
		local p = payload :: { category: unknown, milestone: unknown }
		if typeof(p.category) == "string" and typeof(p.milestone) == "number" then
			claim(player, p.category :: string, p.milestone :: number)
		end
	end
end)

IndexServer.MILESTONES = MILESTONES
IndexServer.MILESTONE_DIAMONDS = MILESTONE_DIAMONDS

return IndexServer
