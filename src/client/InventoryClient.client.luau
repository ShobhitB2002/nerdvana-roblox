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
local UIStyle = require(ReplicatedStorage.Modules.UIStyle)

local invGui = PlayerGui:WaitForChild("InventoryGui") :: ScreenGui
local background = invGui:WaitForChild("Background") :: Frame
local itemList = background:WaitForChild("ItemList") :: ScrollingFrame
local tabRow = background:WaitForChild("TabRow") :: Frame
local invCloseBtn = background:WaitForChild("CloseButton") :: TextButton
local invBackdrop = invGui:WaitForChild("Backdrop") :: TextButton
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

local currentTab = "All"
local currentInventory: Shared.CategorizedInventory? = nil

local function flattenCategorizedInventory(categorizedInv: Shared.CategorizedInventory): { Shared.InventorySlot }
	local flat: { Shared.InventorySlot } = {}

	if currentTab == "All" then
		for _, category in pairs(categorizedInv :: { [string]: { Shared.InventorySlot } }) do
			for _, slot in ipairs(category) do
				table.insert(flat, slot)
			end
		end
		return flat
	end

	local category = (categorizedInv :: { [string]: { Shared.InventorySlot } })[currentTab:lower()]
	if category then
		for _, slot in ipairs(category) do
			table.insert(flat, slot)
		end
	end

	return flat
end

local function renderInventory()
	for _, child in ipairs(itemList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local y = 0

	if not currentInventory then
		return
	end
	local inventoryToRender = flattenCategorizedInventory(currentInventory :: Shared.CategorizedInventory)
	
	for _, slot in ipairs(inventoryToRender) do
		local def = ItemDB.Get(slot.id)
		if not def then
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
			equipBtn.Position = UDim2.new(1, -120, 0.5, -11)
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
		elseif def.type == "Consumables" and def.stats and def.stats.healAmount then
			local useBtn = Instance.new("TextButton")
			useBtn.Size = UDim2.new(0, 55, 0, 22)
			useBtn.Position = UDim2.new(1, -120, 0.5, -11)
			useBtn.Text = "Use"
			useBtn.Font = Enum.Font.GothamBold
			useBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			useBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 160)
			useBtn.BorderSizePixel = 0
			useBtn.TextScaled = true
			useBtn.Parent = row
			useBtn.MouseButton1Click:Connect(function()
				GatherResource:FireServer("use", slot.id)
			end)
		end

		-- Add inventory management buttons for stackable items
		if def.stackable and slot.quantity and slot.quantity > 1 then
			local splitBtn = Instance.new("TextButton")
			splitBtn.Size = UDim2.new(0, 55, 0, 22)
			splitBtn.Position = UDim2.new(1, -125, 0.5, -11)
			splitBtn.Text = "Split"
			splitBtn.Font = Enum.Font.GothamBold
			splitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			splitBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
			splitBtn.BorderSizePixel = 0
			splitBtn.TextScaled = true
			splitBtn.Parent = row
			splitBtn.MouseButton1Click:Connect(function()
				print("[InventoryClient] Split clicked for:", slot.id, "quantity:", slot.quantity)
				GatherResource:FireServer("split", slot.id)
			end)
		end

		-- Add Drop button for all items
		local dropBtn = Instance.new("TextButton")
		dropBtn.Size = UDim2.new(0, 55, 0, 22)
		dropBtn.Position = UDim2.new(1, -60, 0.5, -11)
		dropBtn.Text = "Drop"
		dropBtn.Font = Enum.Font.GothamBold
		dropBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		dropBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
		dropBtn.BorderSizePixel = 0
		dropBtn.TextScaled = true
		dropBtn.Parent = row
		dropBtn.MouseButton1Click:Connect(function()
			GatherResource:FireServer("drop", slot.id)
		end)

		y += 55
	end
	itemList.CanvasSize = UDim2.new(0, 0, 0, y)
	UIStyle.Apply(background)
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

local function setInventoryOpen(open: boolean)
	invOpen = open
	background.Visible = open
	invBackdrop.Visible = open
end

local function toggleInventory()
	setInventoryOpen(not invOpen)
end

backpackButton.MouseButton1Click:Connect(function()
	toggleInventory()
end)
invCloseBtn.MouseButton1Click:Connect(function()
	setInventoryOpen(false)
end)
invBackdrop.MouseButton1Click:Connect(function()
	setInventoryOpen(false)
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
		currentInventory = inventory :: Shared.CategorizedInventory
	end
	renderInventory()
end)

-- Add inventory management buttons
local manageRow = Instance.new("Frame")
manageRow.Size = UDim2.new(1, -20, 0, 30)
manageRow.Position = UDim2.new(0, 10, 0, 10)
manageRow.BackgroundTransparency = 1
manageRow.Parent = background

itemList.Size = UDim2.new(1, -20, 1, -110)
itemList.Position = UDim2.new(0, 10, 0, 100)

local autoStackBtn = Instance.new("TextButton")
autoStackBtn.Size = UDim2.new(0, 80, 0, 25)
autoStackBtn.Position = UDim2.new(0, 0, 0, 0)
autoStackBtn.Text = "Auto Stack"
autoStackBtn.Font = Enum.Font.GothamBold
autoStackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoStackBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
autoStackBtn.BorderSizePixel = 0
autoStackBtn.TextScaled = true
autoStackBtn.Parent = manageRow
autoStackBtn.MouseButton1Click:Connect(function()
	print("[InventoryClient] Auto Stack clicked")
	-- Implement auto-stack functionality
	GatherResource:FireServer("autoStack")
end)

local autoArrangeBtn = Instance.new("TextButton")
autoArrangeBtn.Size = UDim2.new(0, 80, 0, 25)
autoArrangeBtn.Position = UDim2.new(0, 90, 0, 0)
autoArrangeBtn.Text = "Auto Arrange"
autoArrangeBtn.Font = Enum.Font.GothamBold
autoArrangeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoArrangeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
autoArrangeBtn.BorderSizePixel = 0
autoArrangeBtn.TextScaled = true
autoArrangeBtn.Parent = manageRow
autoArrangeBtn.MouseButton1Click:Connect(function()
	print("[InventoryClient] Auto Arrange clicked")
	-- Implement auto-arrange functionality
	GatherResource:FireServer("autoArrange")
end)

background.Visible = false

local RequestSync = Remotes:WaitForChild("RequestSync") :: RemoteEvent
RequestSync:FireServer()
