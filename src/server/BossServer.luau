--!strict
-- BossServer: Beast boss rewards + portal unlock (called from MobAI on server)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataServer = require(script.Parent.DataServer)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local UnlockPortal = Remotes:WaitForChild("UnlockPortal") :: RemoteEvent
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent

local BossServer = {}

function BossServer.OnBeastBossDefeated(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end

	DataServer.AddToInventory(player, "boss_seal", 1, nil)
	data.portalUnlocked = true
	UnlockPortal:FireClient(player)

	local portalInner = Workspace:FindFirstChild("Portals")
	if portalInner then
		local inner = portalInner:FindFirstChild("CorruptedPortal_Inner")
		if inner and inner:IsA("BasePart") then
			local prompt = inner:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = true
			end
		end
	end

	local data2 = DataServer.Get(player)
	if data2 then
		UpdateInventory:FireClient(player, data2.inventory, data2.equipped)
	end
	DataServer.PushHUD(player)
end

return BossServer
