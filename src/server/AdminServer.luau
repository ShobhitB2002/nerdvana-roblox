--!strict
-- AdminServer: server-validated admin commands + global multipliers.
-- Admins: Studio playtests, the game owner, and any UserId in ADMIN_USER_IDS.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataServer = require(script.Parent.DataServer)
local QuestServer = require(script.Parent.QuestServer)
local Shared = require(ReplicatedStorage.Modules.Shared)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local AdminCommand = Remotes:WaitForChild("AdminCommand") :: RemoteEvent
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent
local UpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent
local UnlockPortal = Remotes:WaitForChild("UnlockPortal") :: RemoteEvent

-- Add your Roblox UserIds here to be admin in live servers
local ADMIN_USER_IDS: { number } = {}

local AdminServer = {}

-- Global server-wide tuning, read by gathering/combat/refining systems
AdminServer.State = {
	gatherMult = 1,
	xpMult = 1,
	damageMult = 1,
	rarityBoost = false,
}

function AdminServer.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(ADMIN_USER_IDS, player.UserId) ~= nil
end

local function pushState(player: Player)
	AdminCommand:FireClient(player, "state", {
		gatherMult = AdminServer.State.gatherMult,
		xpMult = AdminServer.State.xpMult,
		damageMult = AdminServer.State.damageMult,
		rarityBoost = AdminServer.State.rarityBoost,
		speed = player:GetAttribute("AdminSpeed") or 16,
		god = player:GetAttribute("AdminGod") == true,
	})
end

local function pushAll(player: Player)
	local data = DataServer.Get(player)
	if data then
		UpdateInventory:FireClient(player, data.inventory, data.equipped)
		UpdateMastery:FireClient(player, data.mastery)
		DataServer.PushHUD(player)
	end
end

local function setGod(player: Player, on: boolean)
	player:SetAttribute("AdminGod", on)
	local char = player.Character
	if char then
		local ff = char:FindFirstChildOfClass("ForceField")
		if on and not ff then
			local f = Instance.new("ForceField")
			f.Parent = char
		elseif not on and ff then
			ff:Destroy()
		end
	end
end

local function teleport(player: Player, markerName: string)
	local portals = workspace:FindFirstChild("Portals")
	local marker = if portals then portals:FindFirstChild(markerName) else nil
	local char = player.Character
	if marker and marker:IsA("BasePart") and char then
		char:PivotTo(CFrame.new(marker.Position + Vector3.new(0, 4, 0)))
	end
end

local function num(v: unknown, min: number, max: number): number?
	if typeof(v) ~= "number" or v ~= v then
		return nil
	end
	return math.clamp(v, min, max)
end

AdminCommand.OnServerEvent:Connect(function(player: Player, cmd: unknown, payload: unknown)
	if not AdminServer.IsAdmin(player) then
		return
	end

	if cmd == "hello" then
		pushState(player)
	elseif cmd == "setSpeed" then
		local n = num(payload, 8, 200)
		if n then
			player:SetAttribute("AdminSpeed", n)
			local char = player.Character
			local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
			if hum then
				hum.WalkSpeed = n
			end
		end
	elseif cmd == "gatherMult" then
		local n = num(payload, 1, 100)
		if n then
			AdminServer.State.gatherMult = n
		end
	elseif cmd == "xpMult" then
		local n = num(payload, 1, 100)
		if n then
			AdminServer.State.xpMult = n
		end
	elseif cmd == "damageMult" then
		local n = num(payload, 1, 1000)
		if n then
			AdminServer.State.damageMult = n
		end
	elseif cmd == "rarityBoost" then
		AdminServer.State.rarityBoost = payload == true
	elseif cmd == "giveGold" then
		local n = num(payload, -1000000, 1000000)
		if n then
			DataServer.AddGold(player, n)
		end
	elseif cmd == "giveDiamonds" then
		local n = num(payload, -1000000, 1000000)
		local data = DataServer.Get(player)
		if n and data then
			data.diamonds = math.max(0, data.diamonds + n)
			DataServer.PushHUD(player)
		end
	elseif cmd == "giveItem" then
		if typeof(payload) ~= "table" then
			return
		end
		local p = payload :: { id: unknown, qty: unknown }
		local qty = num(p.qty, 1, 10000) or 1
		if typeof(p.id) == "string" and ItemDB.Get(p.id :: string) then
			local data = DataServer.Get(player)
			if data then
				-- bypasses weight limit on purpose (admin)
				Shared.AddToCategorizedInventory(data.inventory, p.id :: string, qty)
				pushAll(player)
			end
		else
			AdminCommand:FireClient(player, "error", "Unknown item id: " .. tostring(p.id))
		end
	elseif cmd == "god" then
		setGod(player, payload == true)
	elseif cmd == "heal" then
		local char = player.Character
		local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil
		if hum then
			hum.Health = hum.MaxHealth
		end
	elseif cmd == "tpVillage" then
		local data = DataServer.Get(player)
		if data then
			data.isCorrupted = false
		end
		teleport(player, "VillageSpawn")
	elseif cmd == "tpCorrupted" then
		local data = DataServer.Get(player)
		if data then
			data.isCorrupted = true
		end
		teleport(player, "CorruptedSpawn")
	elseif cmd == "unlockPortal" then
		local data = DataServer.Get(player)
		if data then
			data.portalUnlocked = true
			local _, _, seal = Shared.FindInCategorizedInventory(data.inventory, "boss_seal")
			if not seal then
				Shared.AddToCategorizedInventory(data.inventory, "boss_seal", 1)
			end
			UnlockPortal:FireClient(player)
			pushAll(player)
		end
	elseif cmd == "skipQuest" then
		QuestServer.ForceComplete(player)
	elseif cmd == "wipeData" then
		DataServer.Reset(player)
		QuestServer.PushState(player)
	end

	pushState(player)
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(char: Model)
		if player:GetAttribute("AdminGod") == true then
			local f = Instance.new("ForceField")
			f.Parent = char
		end
		local speed = player:GetAttribute("AdminSpeed")
		if typeof(speed) == "number" then
			local hum = char:WaitForChild("Humanoid") :: Humanoid
			hum.WalkSpeed = speed
		end
	end)

	task.delay(3, function()
		if player.Parent and AdminServer.IsAdmin(player) then
			pushState(player)
		end
	end)
end)

return AdminServer
