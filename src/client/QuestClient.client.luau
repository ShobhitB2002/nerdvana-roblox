--!strict
-- QuestClient: renders server-authoritative quest state

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local QuestUpdate = Remotes:WaitForChild("QuestUpdate") :: RemoteEvent
local UnlockPortal = Remotes:WaitForChild("UnlockPortal") :: RemoteEvent
local EnterPortal = Remotes:WaitForChild("EnterPortal") :: RemoteEvent

local QuestDB = require(ReplicatedStorage.Modules.QuestDB)

local hud = PlayerGui:WaitForChild("HUD") :: ScreenGui
local tracker = hud:WaitForChild("QuestTrackerFrame") :: Frame

local activeQuestId = ""
local objectiveProgress: { [string]: number } = {}

local function notify(text: string, color: Color3?, duration: number?)
	local notifGui = PlayerGui:FindFirstChild("NotificationGui")
	if notifGui and notifGui:IsA("ScreenGui") then
		local frame = notifGui:FindFirstChild("NotifFrame")
		if frame and frame:IsA("Frame") then
			local lbl = frame:FindFirstChildOfClass("TextLabel")
			if lbl and lbl:IsA("TextLabel") then
				lbl.Text = text
				lbl.TextColor3 = color or Color3.fromRGB(255, 255, 100)
				frame.Visible = true
				task.delay(duration or 4, function()
					frame.Visible = false
				end)
			end
		end
	end
end

local function updateTrackerUI()
	local quest = QuestDB.Get(activeQuestId)
	if not quest then
		tracker.Visible = false
		return
	end

	tracker.Visible = true
	for _, child in ipairs(tracker:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -10, 0, 24)
	titleLbl.Position = UDim2.new(0, 5, 0, 2)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = quest.title
	titleLbl.TextColor3 = Color3.fromRGB(255, 230, 100)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextScaled = true
	titleLbl.Parent = tracker

	local y = 26
	for _, obj in ipairs(quest.objectives) do
		local key = obj.item or obj.mob or obj.target or obj.recipeId or "?"
		local progress = objectiveProgress[key] or 0
		local required = obj.qty or 1
		local done = progress >= required

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -10, 0, 20)
		lbl.Position = UDim2.new(0, 10, 0, y)
		lbl.BackgroundTransparency = 1
		lbl.Text = (if done then "OK " else "… ")
			.. tostring(key)
			.. ": "
			.. tostring(math.min(progress, required))
			.. "/"
			.. tostring(required)
		lbl.TextColor3 = if done then Color3.fromRGB(80, 220, 80) else Color3.fromRGB(200, 200, 200)
		lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextScaled = true
		lbl.Parent = tracker
		y += 22
	end
	tracker.Size = UDim2.new(0, 220, 0, y + 5)
end

type QuestState = {
	activeQuestId: string?,
	progress: { [string]: number }?,
	justCompleted: string?,
}

QuestUpdate.OnClientEvent:Connect(function(state: unknown)
	if typeof(state) ~= "table" then
		return
	end
	local s = state :: QuestState

	if typeof(s.justCompleted) == "string" then
		local done = QuestDB.Get(s.justCompleted)
		if done then
			local rewardText = if done.rewards.gold > 0 then " (+" .. tostring(done.rewards.gold) .. " Gold)" else ""
			notify("Quest Complete: " .. done.title .. rewardText, Color3.fromRGB(80, 220, 80))
		end
	end

	activeQuestId = if typeof(s.activeQuestId) == "string" then s.activeQuestId else ""
	objectiveProgress = if typeof(s.progress) == "table" then s.progress :: { [string]: number } else {}
	updateTrackerUI()
end)

UnlockPortal.OnClientEvent:Connect(function()
	notify("Corrupted Portal Unlocked! Seek the Portal Keeper.", Color3.fromRGB(180, 60, 255), 6)
end)

EnterPortal.OnClientEvent:Connect(function(success: unknown, reason: unknown)
	if success == true then
		local overlay = Instance.new("Frame")
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = Color3.fromRGB(80, 0, 120)
		overlay.BackgroundTransparency = 0.3
		overlay.ZIndex = 100
		local parentGui = PlayerGui:FindFirstChild("NotificationGui")
		if parentGui and parentGui:IsA("ScreenGui") then
			overlay.Parent = parentGui
		else
			overlay.Parent = PlayerGui
		end
		task.delay(1.5, function()
			overlay:Destroy()
		end)

		if reason == "returned" then
			notify("Back in the village. Safe and sound.", Color3.fromRGB(120, 220, 120), 4)
		else
			notify("Entering Corrupted Zone. Better drops. Harder enemies.", Color3.fromRGB(200, 80, 255), 5)
		end
	else
		notify(tostring(reason or "Portal is locked."), Color3.fromRGB(255, 80, 80), 3)
	end
end)

updateTrackerUI()

local RequestSync = Remotes:WaitForChild("RequestSync") :: RemoteEvent
RequestSync:FireServer()
