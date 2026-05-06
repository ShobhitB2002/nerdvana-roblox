--!strict
-- InventoryClient

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local GatherResource = Remotes:WaitForChild("GatherResource") :: RemoteEvent
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent

local ItemDB = require(ReplicatedStorage.Modules.ItemDB)
local Shared = require(ReplicatedStorage.Modules.Shared)

local invGui = PlayerGui:WaitForChild("InventoryGui") :: ScreenGui
local background = invGui:WaitForChild("Background") :: Frame
local itemList = background:WaitForChild("ItemList") :: ScrollingFrame
local tabRow = background:WaitForChild("TabRow") :: Frame
local hud = PlayerGui:WaitForChild("HUD") :: ScreenGui
local backpackButton = hud:WaitForChild("BackpackButton") :: TextButton

local RarityColors: { [string]: Color3 } = {
	Common = Color3.fromRGB(220, 220, 220),
	Uncommon = Color3.fromRGB(80, 220, 80),
	Rare = Color3.fromRGB(60, 120, 255),
	Epic = Color3.fromRGB(160, 60, 255),
	Legendary = Color3.fromRGB(255, 165, 0),
	Mythic = Color3.fromRGB(255, 40, 40),
}

local currentTab = "Materials"
local currentInventory: { Shared.InventorySlot } = {}

local function renderInventory()
	for _, child in ipairs(itemList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local y = 0
	for _, slot in ipairs(currentInventory) do
		local def = ItemDB.Get(slot.id)
		if not def then
			continue
		end
		if def.type ~= currentTab then
			continue
		end

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 50)
		row.Position = UDim2.new(0, 5, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		row.BorderSizePixel = 0
		row.Parent = itemList

		local rarity = slot.rarity or "Common"
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.6, 0, 0.6, 0)
		nameLabel.Position = UDim2.new(0.02, 0, 0.1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextColor3 = RarityColors[rarity] or Color3.fromRGB(220, 220, 220)
		nameLabel.Text = def.name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextScaled = true
		nameLabel.Parent = row

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(0.35, 0, 0.4, 0)
		rarityLabel.Position = UDim2.new(0.62, 0, 0.05, 0)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Font = Enum.Font.Gotham
		rarityLabel.TextColor3 = RarityColors[rarity] or Color3.fromRGB(220, 220, 220)
		rarityLabel.Text = rarity
		rarityLabel.TextScaled = true
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
		rarityLabel.Parent = row

		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(0.8, 0, 0.4, 0)
		subLabel.Position = UDim2.new(0.02, 0, 0.5, 0)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.Gotham
		subLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
		subLabel.TextXAlignment = Enum.TextXAlignment.Left

		local subText = "T" .. tostring(def.tier or 1)
		if def.stackable then
			subText = subText .. "  x" .. tostring(slot.quantity or 1)
		elseif slot.durability then
			subText = subText .. "  Dur: " .. tostring(slot.durability) .. "/" .. tostring(def.durabilityMax or "?")
		end
		subLabel.Text = subText
		subLabel.TextScaled = true
		subLabel.Parent = row

		if def.type == "Gear" or def.type == "Tools" then
			local equipBtn = Instance.new("TextButton")
			equipBtn.Size = UDim2.new(0, 55, 0, 22)
			equipBtn.Position = UDim2.new(1, -60, 0.5, -11)
			equipBtn.Text = "Equip"
			equipBtn.Font = Enum.Font.GothamBold
			equipBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			equipBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
			equipBtn.BorderSizePixel = 0
			equipBtn.TextScaled = true
			equipBtn.Parent = row
			equipBtn.MouseButton1Click:Connect(function()
				GatherResource:FireServer("equip", slot.id)
			end)
		end

		y += 55
	end
	itemList.CanvasSize = UDim2.new(0, 0, 0, y)
end

for _, tab in ipairs(tabRow:GetChildren()) do
	if tab:IsA("TextButton") then
		tab.MouseButton1Click:Connect(function()
			currentTab = string.gsub(tab.Name, "Tab", "")
			renderInventory()
		end)
	end
end

local invOpen = false

local function toggleInventory()
	invOpen = not invOpen
	background.Visible = invOpen
end

backpackButton.MouseButton1Click:Connect(function()
	toggleInventory()
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		toggleInventory()
	end
end)

UpdateInventory.OnClientEvent:Connect(function(inventory: unknown, _equipped: unknown)
	if typeof(inventory) == "table" then
		currentInventory = inventory :: { Shared.InventorySlot }
	end
	renderInventory()
end)

background.Visible = false
