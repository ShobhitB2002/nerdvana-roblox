--!strict
-- SFXClient: lightweight sound feedback using built-in Roblox audio assets.
-- Swap SOUND ids for marketplace audio later if you want richer sounds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local _player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder

local SOUNDS = {
	gather = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, speed = 1.2 },
	craft = { id = "rbxasset://sounds/snap.mp3", volume = 0.6, speed = 1 },
	craftFail = { id = "rbxasset://sounds/snap.mp3", volume = 0.4, speed = 0.6 },
	mobDied = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.6, speed = 0.9 },
	quest = { id = "rbxasset://sounds/victory.wav", volume = 0.5, speed = 1 },
	rebirth = { id = "rbxasset://sounds/victory.wav", volume = 0.8, speed = 0.8 },
	hatch = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, speed = 0.8 },
	reward = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 1.5 },
}

local function play(name: string)
	local def = SOUNDS[name]
	if not def then
		return
	end
	pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = def.id
		s.Volume = def.volume
		s.PlaybackSpeed = def.speed
		s.Parent = SoundService
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
		task.delay(5, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	end)
end

local GatherFeedback = Remotes:WaitForChild("GatherFeedback") :: RemoteEvent
GatherFeedback.OnClientEvent:Connect(function()
	play("gather")
end)

local CraftItem = Remotes:WaitForChild("CraftItem") :: RemoteEvent
CraftItem.OnClientEvent:Connect(function(success: unknown)
	play(if success == true then "craft" else "craftFail")
end)

local MobDied = Remotes:WaitForChild("MobDied") :: RemoteEvent
MobDied.OnClientEvent:Connect(function()
	play("mobDied")
end)

local QuestUpdate = Remotes:WaitForChild("QuestUpdate") :: RemoteEvent
QuestUpdate.OnClientEvent:Connect(function(state: unknown)
	if typeof(state) == "table" and typeof((state :: any).justCompleted) == "string" then
		play("quest")
	end
end)

local RebirthAction = Remotes:WaitForChild("RebirthAction") :: RemoteEvent
RebirthAction.OnClientEvent:Connect(function(kind: unknown)
	if kind == "rebirthed" then
		play("rebirth")
	end
end)

local CompanionAction = Remotes:WaitForChild("CompanionAction") :: RemoteEvent
CompanionAction.OnClientEvent:Connect(function(kind: unknown)
	if kind == "hatched" then
		play("hatch")
	end
end)

local RewardsAction = Remotes:WaitForChild("RewardsAction") :: RemoteEvent
RewardsAction.OnClientEvent:Connect(function(kind: unknown)
	if kind == "claimed" then
		play("reward")
	end
end)
