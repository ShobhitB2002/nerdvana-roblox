--!strict
-- GatheringServer: Tree gathering via ProximityPrompt

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServer = require(script.Parent.DataServer)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent
local UpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent
local QuestUpdate = Remotes:WaitForChild("QuestUpdate") :: RemoteEvent
local GatherFeedback = Remotes:WaitForChild("GatherFeedback") :: RemoteEvent

local Cooldowns: { [string]: boolean } = {}

local function onGather(player: Player, trunk: BasePart)
	local resourceTag = trunk:FindFirstChild("ResourceType")
	local xpTag = trunk:FindFirstChild("MasteryXP")
	if not resourceTag or not resourceTag:IsA("StringValue") then
		return
	end

	local resourceId = resourceTag.Value
	local masteryXP = if xpTag and xpTag:IsA("IntValue") then xpTag.Value else 1

	local uid = tostring(player.UserId) .. "_" .. trunk:GetFullName()
	if Cooldowns[uid] then
		return
	end

	local data = DataServer.Get(player)
	if not data then
		return
	end

	local toolId = data.equipped.tool
	local gatherQty = 1
	local cooldownTime = 3
	if toolId then
		local toolDef = ItemDB.Get(toolId)
		if toolDef and toolDef.stats then
			gatherQty += toolDef.stats.gatherBonus or 0
			local gsp = toolDef.stats.gatherSpeed or 1.0
			cooldownTime = cooldownTime / gsp
			for _, slot in ipairs(data.inventory) do
				if slot.id == toolId then
					slot.durability = (slot.durability or 100) - 1
					if slot.durability <= 0 then
						data.equipped.tool = nil
						DataServer.RemoveFromInventory(player, toolId, 1)
						UpdateInventory:FireClient(player, data.inventory, data.equipped)
					end
					break
				end
			end
		end
	end

	local ok, reason = DataServer.AddToInventory(player, resourceId, gatherQty, nil)
	if not ok then
		if reason == "overweight" then
			UpdateInventory:FireClient(player, data.inventory, data.equipped)
			DataServer.PushHUD(player)
		end
		return
	end

	DataServer.AddMastery(player, "Wood", masteryXP * gatherQty)
	UpdateMastery:FireClient(player, data.mastery)
	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	QuestUpdate:FireClient(player, "collect", resourceId, gatherQty)

	local itemDef = ItemDB.Get(resourceId)
	GatherFeedback:FireClient(player, resourceId, gatherQty, trunk.Position, if itemDef then itemDef.name else resourceId)

	Cooldowns[uid] = true
	task.delay(cooldownTime, function()
		Cooldowns[uid] = nil
	end)
end

local function hookTreeTrunk(part: Instance)
	if part:IsA("BasePart") then
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		local rtag = part:FindFirstChild("ResourceType")
		if prompt and rtag then
			prompt.Triggered:Connect(function(player: Player)
				onGather(player, part)
			end)
		end
	end
end

for _, desc in ipairs(workspace:GetDescendants()) do
	hookTreeTrunk(desc)
end
workspace.DescendantAdded:Connect(hookTreeTrunk)

print("[GatheringServer] Ready.")
