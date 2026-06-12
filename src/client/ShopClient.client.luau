--!strict
-- ShopClient: Robux shop (gamepasses + dev products) and diamond cosmetics (Shop button / B key)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local ShopAction = Remotes:WaitForChild("ShopAction") :: RemoteEvent

local MonetizationConfig = require(ReplicatedStorage.Modules.MonetizationConfig)

local gui = Instance.new("ScreenGui")
gui.Name = "ShopGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 48
gui.Parent = PlayerGui

local backdropBtn = Instance.new("TextButton")
backdropBtn.Name = "Backdrop"
backdropBtn.Size = UDim2.new(1, 0, 1, 0)
backdropBtn.BackgroundTransparency = 0.5
backdropBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdropBtn.Text = ""
backdropBtn.Visible = false
backdropBtn.ZIndex = 0
backdropBtn.BorderSizePixel = 0
backdropBtn.Parent = gui

local win = Instance.new("Frame")
win.Position = UDim2.new(0.5, -250, 0.5, -240)
win.Size = UDim2.new(0, 500, 0, 480)
win.BackgroundColor3 = Color3.fromRGB(20, 16, 26)
win.BorderSizePixel = 0
win.Visible = false
win.Parent = gui

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextColor3 = Color3.fromRGB(230, 230, 230)
	l.TextScaled = true
	for k, v in pairs(props) do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.BorderSizePixel = 0
	for k, v in pairs(props) do
		(b :: any)[k] = v
	end
	b.Parent = parent
	return b
end

label(win, { Text = "SHOP", Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(120, 230, 160) })

local closeBtn = button(win, {
	Position = UDim2.new(1, -32, 0, 4),
	Size = UDim2.new(0, 28, 0, 28),
	Text = "X",
	BackgroundColor3 = Color3.fromRGB(180, 40, 40),
	ZIndex = 5,
})

local tabRow = Instance.new("Frame")
tabRow.Position = UDim2.new(0, 8, 0, 38)
tabRow.Size = UDim2.new(1, -16, 0, 28)
tabRow.BackgroundTransparency = 1
tabRow.Parent = win

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.new(0, 8, 0, 72)
content.Size = UDim2.new(1, -16, 1, -82)
content.BackgroundTransparency = 1
content.ScrollBarThickness = 6
content.BorderSizePixel = 0
content.Parent = win

type SState = {
	passes: { [string]: boolean },
	aurasOwned: { [string]: boolean },
	equippedAura: string?,
	luckPotionLeft: number,
	goldPotionLeft: number,
}

local lastState: SState? = nil
local currentTab = "passes"
local tabButtons: { [string]: TextButton } = {}

local PASS_INFO = {
	{ key = "VIP", name = "VIP", desc = "+25% Gold & XP forever" },
	{ key = "AutoGather", name = "Auto-Gather", desc = "Gathers nearby resources for you" },
	{ key = "AutoPickup", name = "Auto-Pickup", desc = "Loot flies into your bag" },
	{ key = "Luck2x", name = "2x Luck", desc = "Double rare odds on crafts & eggs" },
	{ key = "CompanionSlots", name = "+3 Companion Slots", desc = "Equip 6 companions at once" },
	{ key = "BiggerBag", name = "Bigger Bag", desc = "+50 carry weight forever" },
}

local PRODUCT_INFO = {
	{ key = "Diamonds100", name = "100 Diamonds", desc = "Starter pack" },
	{ key = "Diamonds550", name = "550 Diamonds", desc = "+10% bonus" },
	{ key = "Diamonds1200", name = "1,200 Diamonds", desc = "+20% bonus" },
	{ key = "Diamonds3000", name = "3,000 Diamonds", desc = "+50% bonus — best value" },
	{ key = "Gold5k", name = "5,000 Gold", desc = "Quick gold boost" },
	{ key = "Gold25k", name = "25,000 Gold", desc = "Big gold boost" },
	{ key = "LuckPotion30", name = "Luck Potion (30 min)", desc = "2x rare odds for 30 minutes" },
	{ key = "GoldPotion30", name = "Gold Potion (30 min)", desc = "2x gold for 30 minutes" },
	{ key = "InstantRebirth", name = "Instant Rebirth", desc = "Rebirth right now, no boss needed" },
}

local function setOpen(open: boolean)
	win.Visible = open
	backdropBtn.Visible = open
	if open then
		ShopAction:FireServer("hello")
	end
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function makeRow(y: number, titleText: string, descText: string): (Frame, number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 56)
	row.Position = UDim2.new(0, 0, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(34, 28, 44)
	row.BorderSizePixel = 0
	row.Parent = content
	label(row, { Text = titleText, Position = UDim2.new(0, 8, 0, 2), Size = UDim2.new(0.62, 0, 0, 26), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
	label(row, { Text = descText, Position = UDim2.new(0, 8, 0, 30), Size = UDim2.new(0.62, 0, 0, 22), TextColor3 = Color3.fromRGB(170, 165, 185), TextXAlignment = Enum.TextXAlignment.Left })
	return row, y + 60
end

local function render()
	local s = lastState
	for key, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = if currentTab == key then Color3.fromRGB(60, 45, 90) else Color3.fromRGB(38, 32, 52)
	end
	clearContent()
	local y = 0

	if currentTab == "passes" then
		for _, info in ipairs(PASS_INFO) do
			local row
			row, y = makeRow(y, info.name, info.desc)
			local passId = (MonetizationConfig.Gamepasses :: any)[info.key] :: number
			local owned = s and s.passes[info.key] == true
			local btn = button(row, {
				Position = UDim2.new(0.66, 0, 0.2, 0),
				Size = UDim2.new(0.32, 0, 0.6, 0),
				Text = if owned then "OWNED" elseif passId == 0 then "COMING SOON" else "BUY (Robux)",
				BackgroundColor3 = if owned
					then Color3.fromRGB(60, 110, 60)
					elseif passId == 0 then Color3.fromRGB(60, 55, 70)
					else Color3.fromRGB(60, 160, 80),
			})
			if not owned and passId ~= 0 then
				btn.MouseButton1Click:Connect(function()
					MarketplaceService:PromptGamePassPurchase(player, passId)
				end)
			end
		end
	elseif currentTab == "products" then
		if s and (s.luckPotionLeft > 0 or s.goldPotionLeft > 0) then
			local row
			row, y = makeRow(y, "Active Boosts", string.format("Luck: %dm   Gold: %dm", math.ceil(s.luckPotionLeft / 60), math.ceil(s.goldPotionLeft / 60)))
			row.BackgroundColor3 = Color3.fromRGB(40, 50, 36)
		end
		for _, info in ipairs(PRODUCT_INFO) do
			local row
			row, y = makeRow(y, info.name, info.desc)
			local productId = (MonetizationConfig.Products :: any)[info.key] :: number
			local btn = button(row, {
				Position = UDim2.new(0.66, 0, 0.2, 0),
				Size = UDim2.new(0.32, 0, 0.6, 0),
				Text = if productId == 0 then "COMING SOON" else "BUY (Robux)",
				BackgroundColor3 = if productId == 0 then Color3.fromRGB(60, 55, 70) else Color3.fromRGB(60, 130, 190),
			})
			if productId ~= 0 then
				btn.MouseButton1Click:Connect(function()
					MarketplaceService:PromptProductPurchase(player, productId)
				end)
			end
		end
	else -- cosmetics
		for _, aura in ipairs(MonetizationConfig.Auras) do
			local row
			row, y = makeRow(y, aura.name, tostring(aura.cost) .. " Diamonds")
			local owned = s and s.aurasOwned[aura.id] == true
			local equipped = s and s.equippedAura == aura.id
			local btn = button(row, {
				Position = UDim2.new(0.66, 0, 0.2, 0),
				Size = UDim2.new(0.32, 0, 0.6, 0),
				Text = if equipped then "UNEQUIP" elseif owned then "EQUIP" else "BUY",
				BackgroundColor3 = if equipped
					then Color3.fromRGB(140, 80, 40)
					elseif owned then Color3.fromRGB(60, 130, 60)
					else Color3.fromRGB(60, 130, 190),
			})
			local id = aura.id
			btn.MouseButton1Click:Connect(function()
				if equipped then
					ShopAction:FireServer("unequipAura")
				elseif owned then
					ShopAction:FireServer("equipAura", id)
				else
					ShopAction:FireServer("buyAura", id)
				end
			end)
		end
	end

	content.CanvasSize = UDim2.new(0, 0, 0, y)
end

local TABS = {
	{ key = "passes", title = "Gamepasses" },
	{ key = "products", title = "Diamonds & Boosts" },
	{ key = "cosmetics", title = "Cosmetics" },
}
for i, tabDef in ipairs(TABS) do
	local btn = button(tabRow, {
		Position = UDim2.new((i - 1) / 3, 2, 0, 0),
		Size = UDim2.new(1 / 3, -4, 1, 0),
		Text = tabDef.title,
		BackgroundColor3 = Color3.fromRGB(38, 32, 52),
	})
	tabButtons[tabDef.key] = btn
	btn.MouseButton1Click:Connect(function()
		currentTab = tabDef.key
		render()
	end)
end

ShopAction.OnClientEvent:Connect(function(kind: unknown, payload: unknown)
	if kind == "state" and typeof(payload) == "table" then
		lastState = payload :: SState
		render()
	elseif kind == "error" then
		local notifGui = PlayerGui:FindFirstChild("NotificationGui")
		if notifGui and notifGui:IsA("ScreenGui") then
			local frame = notifGui:FindFirstChild("NotifFrame")
			if frame and frame:IsA("Frame") then
				local lbl = frame:FindFirstChildOfClass("TextLabel")
				if lbl then
					lbl.Text = tostring(payload)
					lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
					frame.Visible = true
					task.delay(3, function()
						frame.Visible = false
					end)
				end
			end
		end
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)
backdropBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

local hud = PlayerGui:WaitForChild("HUD") :: ScreenGui
local shopBtn = hud:WaitForChild("ShopButton") :: TextButton
shopBtn.MouseButton1Click:Connect(function()
	setOpen(not win.Visible)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		setOpen(not win.Visible)
	end
end)

ShopAction:FireServer("hello")
