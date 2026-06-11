--!strict
-- DialogueClient

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local DialogueEvent = Remotes:WaitForChild("DialogueEvent") :: RemoteEvent

local QuestDB = require(ReplicatedStorage.Modules.QuestDB)

local dialogueGui = PlayerGui:WaitForChild("DialogueGui") :: ScreenGui
local dialogueBox = dialogueGui:WaitForChild("DialogueBox") :: Frame
local npcNameLabel = dialogueBox:WaitForChild("NPCNameLabel") :: TextLabel
local dialogueText = dialogueBox:WaitForChild("DialogueText") :: TextLabel
local optionsFrame = dialogueBox:WaitForChild("OptionsFrame") :: ScrollingFrame
local closeBtn = dialogueBox:WaitForChild("CloseButton") :: TextButton
local backdropBtn = dialogueGui:WaitForChild("Backdrop") :: TextButton

local function setOpen(open: boolean)
	dialogueBox.Visible = open
	backdropBtn.Visible = open
end

type Dlg = {
	greeting: string,
	quests: { string },
}

local NPC_DIALOGUE: { [string]: Dlg } = {
	Guide = {
		greeting = "Welcome to Nerdvana, adventurer! Your journey starts here. Head to the trees and gather wood — survival demands it.",
		quests = { "q1_gather_wood" },
	},
	SawmillMaster = {
		greeting = "The sawmill turns raw wood into planks. No raw material can be used directly — you must refine everything.",
		quests = { "q2_refine_planks", "q3_craft_axe" },
	},
	Tanner = {
		greeting = "Wolf hides must be tanned before they're useful. Bring me your raw hides and I'll show you the craft.",
		quests = { "q5_tan_hide", "q6_craft_armor" },
	},
	Blacksmith = {
		greeting = "You want a real weapon? Bring me T2 planks and your T1 sword. The forge demands sacrifice.",
		quests = { "q7_craft_sword" },
	},
	Merchant = {
		greeting = "I trade in common goods. Buy yourself some bread — staying alive is step one.",
		quests = {},
	},
	QuestElder = {
		greeting = "The outskirts are dangerous. Prove yourself against the Bandit Captain, then face the Ancient Gorehorn.",
		quests = { "q8_humanoid_boss", "q9_beast_boss" },
	},
	PortalKeeper = {
		greeting = "The Corrupted Portal leads to darker lands. Only those bearing the Beast Seal may pass. Are you ready for what lies beyond?",
		quests = { "q10_portal" },
	},
}

DialogueEvent.OnClientEvent:Connect(function(npcId: unknown)
	if typeof(npcId) ~= "string" then
		return
	end
	local dlg = NPC_DIALOGUE[npcId]
	if not dlg then
		return
	end

	npcNameLabel.Text = npcId
	dialogueText.Text = dlg.greeting

	for _, child in ipairs(optionsFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local y = 0
	for _, questId in ipairs(dlg.quests) do
		local quest = QuestDB.Get(questId)
		if quest then
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -10, 0, 36)
			btn.Position = UDim2.new(0, 5, 0, y)
			btn.Text = quest.title
			btn.Font = Enum.Font.GothamBold
			btn.TextColor3 = Color3.fromRGB(255, 230, 100)
			btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
			btn.BorderSizePixel = 0
			btn.TextScaled = true
			btn.Parent = optionsFrame
			local qref = quest
			btn.MouseButton1Click:Connect(function()
				dialogueText.Text = qref.description
			end)
			y += 40
		end
	end
	optionsFrame.CanvasSize = UDim2.new(0, 0, 0, y)

	setOpen(true)
end)

closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)
backdropBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

setOpen(false)
