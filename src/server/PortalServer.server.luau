--!strict
-- PortalServer: Corrupted portal entry/exit + teleport

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServer = require(script.Parent.DataServer)
local QuestServer = require(script.Parent.QuestServer)
local Shared = require(ReplicatedStorage.Modules.Shared)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local EnterPortal = Remotes:WaitForChild("EnterPortal") :: RemoteEvent

local function teleportTo(player: Player, target: BasePart?)
	if not target then
		return
	end
	local char = player.Character
	if char and char.PrimaryPart then
		char:PivotTo(CFrame.new(target.Position + Vector3.new(0, 4, 0)))
	end
end

local function hookPortals()
	local portals = workspace:WaitForChild("Portals", 60)
	if not portals then
		warn("[PortalServer] Portals folder never appeared")
		return
	end

	local portalInner = portals:WaitForChild("CorruptedPortal_Inner", 60)
	local corruptedSpawn = portals:WaitForChild("CorruptedSpawn", 60)
	local villageSpawn = portals:WaitForChild("VillageSpawn", 60)
	local returnInner = portals:WaitForChild("ReturnPortal_Inner", 60)

	if portalInner and portalInner:IsA("BasePart") then
		local prompt = portalInner:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				local data = DataServer.Get(player)
				if not data then
					return
				end
				local _, _, sealSlot = Shared.FindInCategorizedInventory(data.inventory, "boss_seal")
				if not sealSlot and not data.portalUnlocked then
					EnterPortal:FireClient(player, false, "You need the Beast Seal.")
					return
				end
				data.isCorrupted = true
				teleportTo(player, corruptedSpawn :: BasePart)
				EnterPortal:FireClient(player, true)
				QuestServer.Progress(player, "interact", "CorruptedPortal", 1)
			end)
		end
	end

	if returnInner and returnInner:IsA("BasePart") then
		local prompt = returnInner:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				local data = DataServer.Get(player)
				if not data then
					return
				end
				data.isCorrupted = false
				teleportTo(player, villageSpawn :: BasePart)
				EnterPortal:FireClient(player, true, "returned")
			end)
		end
	end
end

task.spawn(hookPortals)

print("[PortalServer] Ready.")
