--!strict
-- IndexClient: collection log with milestone rewards (Index button / N key)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local IndexAction = Remotes:WaitForChild("IndexAction") :: RemoteEvent

local ItemDB = require(ReplicatedStorage.Modules.ItemDB)
local MobDB = require(ReplicatedStorage.Modules.MobDB)
local CompanionDB = require(ReplicatedStorage.Modules.CompanionDB)

local MILESTONES = { 25, 50, 75, 100 }
local MILESTONE_DIAMONDS = { 5, 10, 15, 30 }

local gui = Instance.new("ScreenGui")
gui.Name = "IndexGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 47
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
win.BackgroundColor3 = Color3.fromRGB(14, 20, 26)
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

label(win, { Text = "COLLECTION INDEX", Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(110, 200, 255) })

local closeBtn = Instance.new("TextButton")
closeBtn.Position = UDim2.new(1, -32, 0, 4)
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextScaled = true
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 5
closeBtn.Parent = win

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

type CatState = { discovered: { [string]: boolean }, total: number, pct: number }
type IState = {
	categories: { [string]: CatState },
	claimed: { [string]: boolean },
}

local lastState: IState? = nil
local currentTab = "items"
local tabButtons: { [string]: TextButton } = {}

local TABS = {
	{ key = "items", title = "Items" },
	{ key = "mobs", title = "Mobs" },
	{ key = "companions", title = "Companions" },
}

local function setOpen(open: boolean)
	win.Visible = open
	backdropBtn.Visible = open
	if open then
		IndexAction:FireServer("hello")
	end
end

local function entriesFor(category: string): { { id: string, name: string, rarity: string? } }
	local out: { { id: string, name: string, rarity: string? } } = {}
	if category == "items" then
		for id, def in pairs(ItemDB.Items) do
			table.insert(out, { id = id, name = def.name, rarity = nil })
		end
	elseif category == "mobs" then
		for id, def in pairs(MobDB.Mobs) do
			table.insert(out, { id = id, name = def.displayName, rarity = nil })
		end
	elseif category == "companions" then
		for id, def in pairs(CompanionDB.Companions) do
			table.insert(out, { id = id, name = def.name, rarity = def.rarity })
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

local function render()
	local s = lastState
	if not s then
		return
	end

	for _, tabDef in ipairs(TABS) do
		local btn = tabButtons[tabDef.key]
		if btn then
			local cat = s.categories[tabDef.key]
			btn.Text = tabDef.title .. " " .. tostring(if cat then cat.pct else 0) .. "%"
			btn.BackgroundColor3 = if currentTab == tabDef.key then Color3.fromRGB(40, 80, 110) else Color3.fromRGB(30, 45, 60)
		end
	end

	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local cat = s.categories[currentTab]
	if not cat then
		return
	end

	local y = 0

	-- Milestone claim row
	for i, pct in ipairs(MILESTONES) do
		local key = currentTab .. "_" .. tostring(pct)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 30)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(24, 34, 44)
		row.BorderSizePixel = 0
		row.Parent = content

		label(row, {
			Text = tostring(pct) .. "% discovered → " .. tostring(MILESTONE_DIAMONDS[i]) .. " Diamonds",
			Position = UDim2.new(0, 6, 0, 0),
			Size = UDim2.new(0.66, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		local btn = Instance.new("TextButton")
		btn.Position = UDim2.new(0.7, 0, 0.12, 0)
		btn.Size = UDim2.new(0.28, 0, 0.76, 0)
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.BorderSizePixel = 0
		if s.claimed[key] then
			btn.Text = "CLAIMED"
			btn.BackgroundColor3 = Color3.fromRGB(40, 55, 48)
		elseif cat.pct >= pct then
			btn.Text = "CLAIM"
			btn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
			local mi = i
			btn.MouseButton1Click:Connect(function()
				IndexAction:FireServer("claim", { category = currentTab, milestone = mi })
			end)
		else
			btn.Text = "LOCKED"
			btn.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
		end
		btn.Parent = row
		y += 34
	end

	y += 6

	for _, entry in ipairs(entriesFor(currentTab)) do
		local found = cat.discovered[entry.id] == true
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 26)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundColor3 = if found then Color3.fromRGB(26, 40, 30) else Color3.fromRGB(22, 26, 32)
		row.BorderSizePixel = 0
		row.Parent = content

		local nameText = if found then entry.name else "???"
		local color = Color3.fromRGB(120, 120, 130)
		if found then
			color = if entry.rarity then (CompanionDB.RarityColors[entry.rarity :: string] or Color3.fromRGB(230, 230, 230)) else Color3.fromRGB(230, 230, 230)
		end
		label(row, {
			Text = (if found then "✔ " else "✖ ") .. nameText,
			Position = UDim2.new(0, 6, 0, 0),
			Size = UDim2.new(1, -12, 1, 0),
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		y += 28
	end

	content.CanvasSize = UDim2.new(0, 0, 0, y)
end

for i, tabDef in ipairs(TABS) do
	local btn = Instance.new("TextButton")
	btn.Position = UDim2.new((i - 1) / 3, 2, 0, 0)
	btn.Size = UDim2.new(1 / 3, -4, 1, 0)
	btn.Text = tabDef.title
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.BackgroundColor3 = Color3.fromRGB(30, 45, 60)
	btn.BorderSizePixel = 0
	btn.Parent = tabRow
	tabButtons[tabDef.key] = btn
	btn.MouseButton1Click:Connect(function()
		currentTab = tabDef.key
		render()
	end)
end

IndexAction.OnClientEvent:Connect(function(kind: unknown, payload: unknown)
	if kind == "state" and typeof(payload) == "table" then
		lastState = payload :: IState
		render()
	elseif kind == "claimed" and typeof(payload) == "table" then
		local p = payload :: { diamonds: number }
		local notifGui = PlayerGui:FindFirstChild("NotificationGui")
		if notifGui and notifGui:IsA("ScreenGui") then
			local frame = notifGui:FindFirstChild("NotifFrame")
			if frame and frame:IsA("Frame") then
				local lbl = frame:FindFirstChildOfClass("TextLabel")
				if lbl then
					lbl.Text = "Index reward: +" .. tostring(p.diamonds) .. " Diamonds!"
					lbl.TextColor3 = Color3.fromRGB(110, 200, 255)
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
local indexBtn = hud:WaitForChild("IndexButton") :: TextButton
indexBtn.MouseButton1Click:Connect(function()
	setOpen(not win.Visible)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.N then
		setOpen(not win.Visible)
	end
end)

IndexAction:FireServer("hello")
