--!strict
-- QuestClient

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

local activeQuestId = "q1_gather_wood"
local objectiveProgress: { [string]: number } = {}

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

local function checkQuestCompletion()
	local quest = QuestDB.Get(activeQuestId)
	if not quest then
		return
	end
	local allDone = true
	for _, obj in ipairs(quest.objectives) do
		local key = obj.item or obj.mob or obj.target or obj.recipeId or "?"
		local progress = objectiveProgress[key] or 0
		if progress < (obj.qty or 1) then
			allDone = false
			break
		end
	end
	if allDone then
		local notifGui = PlayerGui:FindFirstChild("NotificationGui")
		if notifGui and notifGui:IsA("ScreenGui") then
			local frame = notifGui:FindFirstChild("NotifFrame")
			if frame and frame:IsA("Frame") then
				local lbl = frame:FindFirstChildOfClass("TextLabel")
				if lbl and lbl:IsA("TextLabel") then
					lbl.Text = "Quest Complete: " .. quest.title
					frame.Visible = true
					task.delay(4, function()
						frame.Visible = false
					end)
				end
			end
		end
		if quest.nextQuest then
			objectiveProgress = {}
			activeQuestId = quest.nextQuest
			updateTrackerUI()
		end
	end
end

QuestUpdate.OnClientEvent:Connect(function(actionType: unknown, key: unknown, qty: unknown)
	if typeof(actionType) ~= "string" then
		return
	end
	local quest = QuestDB.Get(activeQuestId)
	if not quest then
		return
	end

	local qAmt = if typeof(qty) == "number" then qty else 1

	for _, obj in ipairs(quest.objectives) do
		local objKey = obj.item or obj.mob or obj.target or obj.recipeId or "?"
		local matches = false
		if actionType == "collect" and obj.type == "collect" and obj.item == key then
			matches = true
		elseif actionType == "kill" and obj.type == "kill" and obj.mob == key then
			matches = true
		elseif actionType == "craft" and obj.type == "craft" and obj.recipeId == key then
			matches = true
		elseif actionType == "interact" and obj.type == "interact" and obj.target == key then
			matches = true
		end
		if matches then
			objectiveProgress[objKey] = (objectiveProgress[objKey] or 0) + qAmt
		end
	end

	updateTrackerUI()
	checkQuestCompletion()
end)

UnlockPortal.OnClientEvent:Connect(function()
	local notifGui = PlayerGui:FindFirstChild("NotificationGui")
	if notifGui and notifGui:IsA("ScreenGui") then
		local frame = notifGui:FindFirstChild("NotifFrame")
		if frame and frame:IsA("Frame") then
			local lbl = frame:FindFirstChildOfClass("TextLabel")
			if lbl and lbl:IsA("TextLabel") then
				lbl.Text = "Corrupted Portal Unlocked! Seek the Portal Keeper."
				lbl.TextColor3 = Color3.fromRGB(180, 60, 255)
				frame.Visible = true
				task.delay(6, function()
					frame.Visible = false
				end)
			end
		end
	end
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

		local notifGui = PlayerGui:FindFirstChild("NotificationGui")
		if notifGui and notifGui:IsA("ScreenGui") then
			local frame = notifGui:FindFirstChild("NotifFrame")
			if frame and frame:IsA("Frame") then
				local lbl = frame:FindFirstChildOfClass("TextLabel")
				if lbl and lbl:IsA("TextLabel") then
					lbl.Text = "Entering Corrupted Zone. Better drops. Harder enemies."
					lbl.TextColor3 = Color3.fromRGB(200, 80, 255)
					frame.Visible = true
					task.delay(5, function()
						frame.Visible = false
					end)
				end
			end
		end
	else
		local notifGui = PlayerGui:FindFirstChild("NotificationGui")
		if notifGui and notifGui:IsA("ScreenGui") then
			local frame = notifGui:FindFirstChild("NotifFrame")
			if frame and frame:IsA("Frame") then
				local lbl = frame:FindFirstChildOfClass("TextLabel")
				if lbl and lbl:IsA("TextLabel") then
					lbl.Text = tostring(reason or "Portal is locked.")
					lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
					frame.Visible = true
					task.delay(3, function()
						frame.Visible = false
					end)
				end
			end
		end
	end
end)

updateTrackerUI()
