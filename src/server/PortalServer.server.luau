--!strict
-- PortalServer: Corrupted portal entry validation

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServer = require(script.Parent.DataServer)
local Shared = require(ReplicatedStorage.Modules.Shared)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local EnterPortal = Remotes:WaitForChild("EnterPortal") :: RemoteEvent
local QuestUpdate = Remotes:WaitForChild("QuestUpdate") :: RemoteEvent

local function hookPortal()
	local portals = workspace:FindFirstChild("Portals")
	if not portals then
		task.wait(1)
		hookPortal()
		return
	end
	local portalInner = portals:FindFirstChild("CorruptedPortal_Inner")
	if not portalInner or not portalInner:IsA("BasePart") then
		task.wait(1)
		hookPortal()
		return
	end
	local prompt = portalInner:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end

	prompt.Triggered:Connect(function(player: Player)
		local data = DataServer.Get(player)
		if not data then
			return
		end
		local _, sealSlot = Shared.FindInInventory(data.inventory, "boss_seal")
		if not sealSlot and not data.portalUnlocked then
			EnterPortal:FireClient(player, false, "You need the Beast Seal.")
			return
		end
		data.isCorrupted = true
		EnterPortal:FireClient(player, true)
		QuestUpdate:FireClient(player, "interact", "CorruptedPortal", 1)
	end)
end

task.spawn(hookPortal)

print("[PortalServer] Ready.")
