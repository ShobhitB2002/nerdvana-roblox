--!strict
-- NPCDialogServer: NPC prompts + station UI open

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local DialogueEvent = Remotes:WaitForChild("DialogueEvent") :: RemoteEvent
local OpenStation = Remotes:WaitForChild("OpenStation") :: RemoteEvent

local function hookNPC(body: Instance)
	if not body:IsA("BasePart") then
		return
	end
	local npcTag = body:FindFirstChild("NPCId")
	local prompt = body:FindFirstChildOfClass("ProximityPrompt")
	if not npcTag or not npcTag:IsA("StringValue") or not prompt then
		return
	end

	prompt.Triggered:Connect(function(player: Player)
		DialogueEvent:FireClient(player, npcTag.Value)
	end)
end

local npcFolder = workspace:WaitForChild("NPCs", 30)
if npcFolder then
	for _, desc in ipairs(npcFolder:GetDescendants()) do
		hookNPC(desc)
	end
	npcFolder.DescendantAdded:Connect(hookNPC)
end

local function hookStation(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local stTag = part:FindFirstChild("StationType")
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not stTag or not stTag:IsA("StringValue") or not prompt then
		return
	end
	if stTag.Value == "ExchangeBoard" then
		return
	end

	prompt.Triggered:Connect(function(player: Player)
		local stationName = stTag.Value
		local stationMap: { [string]: string } = {
			Sawmill = "sawmill",
			TanningRack = "tanning_rack",
			Forge = "forge",
			CraftingBench = "crafting_bench",
			MerchantStall = "merchant",
		}
		local key = stationMap[stationName] or string.lower(stationName)
		OpenStation:FireClient(player, key)
	end)
end

local stationsFolder = workspace:WaitForChild("Stations", 30)
if stationsFolder then
	for _, desc in ipairs(stationsFolder:GetDescendants()) do
		hookStation(desc)
	end
	stationsFolder.DescendantAdded:Connect(hookStation)
end

print("[NPCDialogServer] Ready.")
