--!strict
-- MasteryClient

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local UpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent

local MasteryDB = require(ReplicatedStorage.Modules.MasteryDB)

local masteryGui = PlayerGui:WaitForChild("MasteryGui") :: ScreenGui
local panel = masteryGui:WaitForChild("MasteryPanel") :: Frame

local BarMap: { [string]: Frame } = {
	Wood = panel:WaitForChild("WoodMasteryBar") :: Frame,
	Hide = panel:WaitForChild("HideMasteryBar") :: Frame,
	Sword = panel:WaitForChild("SwordMasteryBar") :: Frame,
	Leather = panel:WaitForChild("LeatherMasteryBar") :: Frame,
	Tool = panel:WaitForChild("ToolMasteryBar") :: Frame,
}

local MasteryColors: { [string]: Color3 } = {
	Wood = Color3.fromRGB(140, 90, 40),
	Hide = Color3.fromRGB(200, 140, 80),
	Sword = Color3.fromRGB(100, 180, 255),
	Leather = Color3.fromRGB(180, 100, 60),
	Tool = Color3.fromRGB(160, 160, 160),
}

local function updateBars(mastery: { [string]: number })
	for line, xp in pairs(mastery) do
		local bar = BarMap[line]
		if not bar then
			continue
		end
		local tier = MasteryDB.GetTier(xp)
		local curThresh = MasteryDB.GetCurrentThreshold(xp)
		local nextThresh = MasteryDB.GetNextThreshold(xp)
		local progress = 0
		if nextThresh > curThresh then
			progress = (xp - curThresh) / (nextThresh - curThresh)
		else
			progress = 1
		end

		local fill = bar:FindFirstChild("Fill")
		if fill and fill:IsA("Frame") then
			fill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
			fill.BackgroundColor3 = MasteryColors[line] or Color3.fromRGB(200, 200, 200)
		end

		local nameLabel = bar:FindFirstChild("NameLabel")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = line .. " T" .. tostring(tier)
		end
		local xpLabel = bar:FindFirstChild("XPLabel")
		if xpLabel and xpLabel:IsA("TextLabel") then
			xpLabel.Text = tostring(xp) .. "/" .. tostring(nextThresh) .. " XP"
		end
	end
end

local open = false
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		open = not open
		panel.Visible = open
	end
end)

UpdateMastery.OnClientEvent:Connect(function(mastery: unknown)
	if typeof(mastery) == "table" then
		updateBars(mastery :: { [string]: number })
	end
end)

panel.Visible = false

local RequestSync = Remotes:WaitForChild("RequestSync") :: RemoteEvent
RequestSync:FireServer()
