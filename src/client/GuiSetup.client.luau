--!strict
-- Builds PlayerGui for Nerdvana (Rojo-friendly; matches script WaitForChild paths)

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- DisplayOrder: HUD stays low; modals above so ProximityPrompt-open UIs receive clicks.
local function screenGui(name: string, displayOrder: number): ScreenGui
	local s = Instance.new("ScreenGui")
	s.Name = name
	s.ResetOnSpawn = false
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.DisplayOrder = displayOrder
	s.Parent = pg
	return s
end

local function frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	for k, v in pairs(props) do
		(f :: any)[k] = v
	end
	return f
end

local function textLabel(props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	for k, v in pairs(props) do
		(t :: any)[k] = v
	end
	return t
end

local function textButton(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	for k, v in pairs(props) do
		(b :: any)[k] = v
	end
	return b
end

-- Invisible full-screen button: clicking outside a window closes it
local function backdrop(parent: ScreenGui): TextButton
	return textButton({
		Name = "Backdrop",
		Parent = parent,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0.5,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		Text = "",
		Visible = false,
		ZIndex = 0,
		BorderSizePixel = 0,
	})
end

-- Red X pinned to a window's top-right corner
local function closeX(parent: GuiObject): TextButton
	return textButton({
		Name = "CloseButton",
		Parent = parent,
		Position = UDim2.new(1, -32, 0, 4),
		Size = UDim2.new(0, 28, 0, 28),
		Text = "X",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		BackgroundColor3 = Color3.fromRGB(180, 40, 40),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 5,
	})
end

-- HUD
do
	local hud = screenGui("HUD", 0)
	local healthBar = frame({
		Name = "HealthBar",
		Parent = hud,
		Position = UDim2.new(0, 10, 1, -90),
		Size = UDim2.new(0, 200, 0, 20),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BorderSizePixel = 0,
	})
	local healthFill = frame({
		Name = "Fill",
		Parent = healthBar,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(80, 220, 80),
		BorderSizePixel = 0,
		ZIndex = 1,
	})
	textLabel({
		Name = "GoldLabel",
		Parent = hud,
		Position = UDim2.new(0, 10, 0, 10),
		Size = UDim2.new(0, 180, 0, 30),
		Text = "Gold: 10",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 215, 0),
		BackgroundTransparency = 0.5,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		TextScaled = true,
	})
	textLabel({
		Name = "DiamondLabel",
		Parent = hud,
		Position = UDim2.new(0, 200, 0, 10),
		Size = UDim2.new(0, 180, 0, 30),
		Text = "Diamonds: 0",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(100, 200, 255),
		BackgroundTransparency = 0.5,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		TextScaled = true,
	})
	local weightBar = frame({
		Name = "WeightBar",
		Parent = hud,
		Position = UDim2.new(0, 10, 1, -60),
		Size = UDim2.new(0, 200, 0, 20),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BorderSizePixel = 0,
	})
	frame({
		Name = "Fill",
		Parent = weightBar,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(200, 140, 60),
		BorderSizePixel = 0,
		ZIndex = 1,
	})
	textLabel({
		Name = "WeightLabel",
		Parent = weightBar,
		Size = UDim2.new(1, 0, 1, 0),
		Text = "0.0/50 kg",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		TextScaled = true,
		ZIndex = 2,
	})
	-- Backpack (opens same inventory as I key)
	textButton({
		Name = "BackpackButton",
		Parent = hud,
		Position = UDim2.new(1, -56, 1, -120),
		Size = UDim2.new(0, 44, 0, 44),
		Text = "Bag",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		BackgroundColor3 = Color3.fromRGB(55, 45, 35),
		TextColor3 = Color3.fromRGB(255, 230, 160),
		BorderSizePixel = 0,
	})
	-- Pinch-to-zoom: see CameraAndControls.client.luau (no on-screen +/-)
	frame({
		Name = "QuestTrackerFrame",
		Parent = hud,
		Position = UDim2.new(1, -230, 0, 60),
		Size = UDim2.new(0, 220, 0, 100),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	})
	-- health fill is found by name in HUDClient
	local _ = healthFill
end

-- Inventory
do
	local inv = screenGui("InventoryGui", 25)
	backdrop(inv)
	local bg = frame({
		Name = "Background",
		Parent = inv,
		Position = UDim2.new(0.5, -250, 0.1, 0),
		Size = UDim2.new(0, 500, 0.8, 0),
		BackgroundColor3 = Color3.fromRGB(18, 18, 28),
		Visible = false,
		BorderSizePixel = 0,
	})
	textLabel({
		Name = "TitleLabel",
		Parent = bg,
		Size = UDim2.new(1, 0, 0, 40),
		Text = "INVENTORY",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 230, 100),
		BackgroundTransparency = 1,
		TextScaled = true,
	})
	local tabRow = frame({
		Name = "TabRow",
		Parent = bg,
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 35),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
	local tabs = { "All", "Materials", "Gear", "Tools", "Consumables", "Quest", "Currency" }
	for i, name in ipairs(tabs) do
		textButton({
			Name = name .. "Tab",
			Parent = tabRow,
			Position = UDim2.new((i - 1) / 7, 0, 0, 0),
			Size = UDim2.new(1 / 7, 0, 1, 0),
			Text = name,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			BackgroundColor3 = Color3.fromRGB(45, 45, 60),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
		})
	end
	closeX(bg)
	local list = Instance.new("ScrollingFrame")
	list.Name = "ItemList"
	list.Parent = bg
	list.Position = UDim2.new(0, 0, 0, 75)
	list.Size = UDim2.new(1, 0, 1, -75)
	list.BackgroundTransparency = 0.8
	list.ScrollBarThickness = 6
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
end

-- Mastery
do
	local mg = screenGui("MasteryGui", 12)
	local panel = frame({
		Name = "MasteryPanel",
		Parent = mg,
		Position = UDim2.new(0, 10, 0.3, 0),
		Size = UDim2.new(0, 220, 0, 280),
		BackgroundColor3 = Color3.fromRGB(18, 18, 28),
		BackgroundTransparency = 0.1,
		Visible = false,
		BorderSizePixel = 0,
	})
	textLabel({
		Name = "Title",
		Parent = panel,
		Size = UDim2.new(1, 0, 0, 30),
		Text = "MASTERY",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 230, 100),
		BackgroundTransparency = 1,
		TextScaled = true,
	})
	local lines = { "Wood", "Hide", "Sword", "Leather", "Tool" }
	local y0 = 35
	for i, line in ipairs(lines) do
		local bar = frame({
			Name = line .. "MasteryBar",
			Parent = panel,
			Position = UDim2.new(0, 5, 0, y0 + (i - 1) * 45),
			Size = UDim2.new(1, -10, 0, 40),
			BackgroundColor3 = Color3.fromRGB(30, 30, 40),
			BorderSizePixel = 0,
		})
		frame({
			Name = "Fill",
			Parent = bar,
			Size = UDim2.new(0.1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(140, 90, 40),
			BorderSizePixel = 0,
		})
		textLabel({
			Name = "NameLabel",
			Parent = bar,
			Size = UDim2.new(0.5, 0, 0.5, 0),
			Text = line .. " T1",
			Font = Enum.Font.GothamBold,
			BackgroundTransparency = 1,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 255, 255),
		})
		textLabel({
			Name = "XPLabel",
			Parent = bar,
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0.5, 0, 0.5, 0),
			Text = "0/100",
			BackgroundTransparency = 1,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(200, 200, 200),
		})
	end
end

-- Station
do
	local sg = screenGui("StationGui", 35)
	backdrop(sg)
	local stationFrame = frame({
		Name = "StationFrame",
		Parent = sg,
		Position = UDim2.new(0.5, -220, 0.1, 0),
		Size = UDim2.new(0, 440, 0.75, 0),
		BackgroundColor3 = Color3.fromRGB(18, 18, 28),
		Visible = false,
		BorderSizePixel = 0,
	})
	textLabel({
		Name = "TitleLabel",
		Parent = stationFrame,
		Size = UDim2.new(1, 0, 0, 35),
		Text = "STATION",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 230, 100),
		BackgroundTransparency = 1,
		TextScaled = true,
	})
	local recipeList = Instance.new("ScrollingFrame")
	recipeList.Name = "RecipeList"
	recipeList.Parent = stationFrame
	recipeList.Position = UDim2.new(0, 0, 0, 35)
	recipeList.Size = UDim2.new(1, 0, 0.75, -35)
	recipeList.BackgroundTransparency = 0.8
	recipeList.ScrollBarThickness = 6
	recipeList.BorderSizePixel = 0
	textButton({
		Name = "CraftButton",
		Parent = stationFrame,
		Position = UDim2.new(0.05, 0, 0.77, 0),
		Size = UDim2.new(0.5, 0, 0.1, 0),
		Text = "CRAFT",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundColor3 = Color3.fromRGB(60, 120, 60),
		BorderSizePixel = 0,
		TextScaled = true,
	})
	textLabel({
		Name = "ResultLabel",
		Parent = stationFrame,
		Position = UDim2.new(0, 0, 0.88, 0),
		Size = UDim2.new(1, 0, 0.12, 0),
		Text = "",
		Font = Enum.Font.Gotham,
		BackgroundTransparency = 1,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	})
	closeX(stationFrame)
end

-- Dialogue
do
	local dg = screenGui("DialogueGui", 40)
	backdrop(dg)
	local box = frame({
		Name = "DialogueBox",
		Parent = dg,
		Position = UDim2.new(0.15, 0, 0.55, 0),
		Size = UDim2.new(0.7, 0, 0.38, 0),
		BackgroundColor3 = Color3.fromRGB(15, 15, 25),
		BackgroundTransparency = 0.05,
		Visible = false,
		BorderSizePixel = 0,
	})
	textLabel({
		Name = "NPCNameLabel",
		Parent = box,
		Size = UDim2.new(1, 0, 0, 32),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 230, 100),
		BackgroundTransparency = 1,
		TextScaled = true,
	})
	textLabel({
		Name = "DialogueText",
		Parent = box,
		Position = UDim2.new(0, 5, 0, 35),
		Size = UDim2.new(1, -10, 0, 80),
		Text = "",
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(220, 220, 220),
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextSize = 16,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local opt = Instance.new("ScrollingFrame")
	opt.Name = "OptionsFrame"
	opt.Parent = box
	opt.Position = UDim2.new(0, 0, 0, 120)
	opt.Size = UDim2.new(1, 0, 1, -125)
	opt.BackgroundTransparency = 1
	opt.ScrollBarThickness = 4
	opt.BorderSizePixel = 0
	closeX(box)
end

-- Notification
do
	local ng = screenGui("NotificationGui", 100)
	local nf = frame({
		Name = "NotifFrame",
		Parent = ng,
		Position = UDim2.new(0.25, 0, 0.05, 0),
		Size = UDim2.new(0.5, 0, 0, 60),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		BackgroundTransparency = 0.1,
		Visible = false,
		BorderSizePixel = 0,
	})
	textLabel({
		Parent = nf,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 255, 100),
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextScaled = true,
	})
end

print("[Nerdvana] GuiSetup ready")
