--!strict
-- CompanionClient: egg shop, hatch reveal, companion management (Pets button / C key)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local CompanionAction = Remotes:WaitForChild("CompanionAction") :: RemoteEvent
local OpenStation = Remotes:WaitForChild("OpenStation") :: RemoteEvent

local CompanionDB = require(ReplicatedStorage.Modules.CompanionDB)
local UIStyle = require(ReplicatedStorage.Modules.UIStyle)

local gui = Instance.new("ScreenGui")
gui.Name = "CompanionGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 46
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
win.Position = UDim2.new(0.5, -260, 0.5, -240)
win.Size = UDim2.new(0, 520, 0, 480)
win.BackgroundColor3 = Color3.fromRGB(24, 18, 14)
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

label(win, { Text = "COMPANIONS", Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 180, 80) })

local closeBtn = button(win, {
	Position = UDim2.new(1, -32, 0, 4),
	Size = UDim2.new(0, 28, 0, 28),
	Text = "X",
	BackgroundColor3 = Color3.fromRGB(180, 40, 40),
	ZIndex = 5,
})

local slotsLbl = label(win, { Text = "", Position = UDim2.new(0, 10, 0, 36), Size = UDim2.new(1, -20, 0, 22) })

-- Tabs: Eggs / My Companions
local eggsTabBtn = button(win, {
	Position = UDim2.new(0, 10, 0, 62),
	Size = UDim2.new(0.46, 0, 0, 28),
	Text = "EGGS",
	BackgroundColor3 = Color3.fromRGB(90, 60, 30),
})
local mineTabBtn = button(win, {
	Position = UDim2.new(0.52, 0, 0, 62),
	Size = UDim2.new(0.46, 0, 0, 28),
	Text = "MY COMPANIONS",
	BackgroundColor3 = Color3.fromRGB(50, 40, 30),
})

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.new(0, 8, 0, 96)
content.Size = UDim2.new(1, -16, 1, -106)
content.BackgroundTransparency = 1
content.ScrollBarThickness = 6
content.BorderSizePixel = 0
content.Parent = win

type CState = {
	companions: { [string]: number },
	equipped: { string },
	maxSlots: number,
}

local lastState: CState? = nil
local currentTab = "eggs"

local function setOpen(open: boolean)
	win.Visible = open
	backdropBtn.Visible = open
	if open then
		CompanionAction:FireServer("hello")
	end
end

local function boostText(def: CompanionDB.CompanionDef): string
	local parts: { string } = {}
	if def.boosts.gold then
		table.insert(parts, string.format("+%d%% Gold", math.floor((def.boosts.gold - 1) * 100 + 0.5)))
	end
	if def.boosts.xp then
		table.insert(parts, string.format("+%d%% XP", math.floor((def.boosts.xp - 1) * 100 + 0.5)))
	end
	if def.boosts.gather then
		table.insert(parts, string.format("+%d%% Gather", math.floor((def.boosts.gather - 1) * 100 + 0.5)))
	end
	if def.boosts.damage then
		table.insert(parts, string.format("+%d%% Damage", math.floor((def.boosts.damage - 1) * 100 + 0.5)))
	end
	if def.boosts.luck then
		table.insert(parts, string.format("+%d%% Luck", math.floor(def.boosts.luck * 100 + 0.5)))
	end
	return table.concat(parts, "  ")
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function renderEggs()
	clearContent()
	local y = 0
	for _, egg in ipairs(CompanionDB.Eggs) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 110)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(40, 32, 24)
		row.BorderSizePixel = 0
		row.Parent = content

		label(row, { Text = egg.name, Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(0.6, 0, 0, 24), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })

		-- Drop list with odds
		local total = 0
		for _, e in ipairs(egg.pool) do
			total += e.weight
		end
		local lines: { string } = {}
		for _, e in ipairs(egg.pool) do
			local def = CompanionDB.Get(e.id)
			if def then
				local pct = e.weight / total * 100
				local pctText = if pct < 0.1 then "<0.1%" else string.format("%.1f%%", pct)
				table.insert(lines, def.name .. " (" .. pctText .. ")")
			end
		end
		local listLbl = label(row, {
			Text = table.concat(lines, "  •  "),
			Position = UDim2.new(0, 8, 0, 30),
			Size = UDim2.new(1, -16, 0, 48),
			TextColor3 = Color3.fromRGB(180, 170, 160),
		})
		listLbl.TextWrapped = true

		local cur = if egg.currency == "gold" then "Gold" else "Diamonds"
		button(row, {
			Position = UDim2.new(0.62, 0, 0, 4),
			Size = UDim2.new(0.36, 0, 0, 24),
			Text = "HATCH — " .. tostring(egg.cost) .. " " .. cur,
			BackgroundColor3 = if egg.currency == "gold" then Color3.fromRGB(160, 130, 40) else Color3.fromRGB(60, 130, 190),
		}).MouseButton1Click:Connect(function()
			CompanionAction:FireServer("hatch", egg.id)
		end)

		y += 116
	end
	content.CanvasSize = UDim2.new(0, 0, 0, y)
end

local function renderMine()
	clearContent()
	local s = lastState
	if not s then
		return
	end
	local y = 0
	-- Sort: equipped first, then by name
	local ids: { string } = {}
	for id in pairs(s.companions) do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		local ea = table.find(s.equipped, a) ~= nil
		local eb = table.find(s.equipped, b) ~= nil
		if ea ~= eb then
			return ea
		end
		return a < b
	end)

	if #ids == 0 then
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 40)
		row.BackgroundTransparency = 1
		row.Parent = content
		label(row, { Text = "No companions yet — hatch an egg!", Size = UDim2.new(1, 0, 1, 0) })
		return
	end

	for _, id in ipairs(ids) do
		local def = CompanionDB.Get(id)
		if not def then
			continue
		end
		local count = s.companions[id]
		local isEquipped = table.find(s.equipped, id) ~= nil

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 56)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundColor3 = if isEquipped then Color3.fromRGB(50, 45, 28) else Color3.fromRGB(38, 32, 26)
		row.BorderSizePixel = 0
		row.Parent = content

		label(row, {
			Text = def.name .. "  x" .. tostring(count),
			Position = UDim2.new(0, 8, 0, 2),
			Size = UDim2.new(0.5, 0, 0, 24),
			Font = Enum.Font.GothamBold,
			TextColor3 = CompanionDB.RarityColors[def.rarity] or Color3.fromRGB(220, 220, 220),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		label(row, {
			Text = boostText(def),
			Position = UDim2.new(0, 8, 0, 28),
			Size = UDim2.new(0.5, 0, 0, 22),
			TextColor3 = Color3.fromRGB(180, 170, 160),
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		local eqBtn = button(row, {
			Position = UDim2.new(0.54, 0, 0.16, 0),
			Size = UDim2.new(0.2, 0, 0.68, 0),
			Text = if isEquipped then "UNEQUIP" else "EQUIP",
			BackgroundColor3 = if isEquipped then Color3.fromRGB(140, 80, 40) else Color3.fromRGB(60, 130, 60),
		})
		eqBtn.MouseButton1Click:Connect(function()
			CompanionAction:FireServer(if isEquipped then "unequip" else "equip", id)
		end)

		if def.fuseInto then
			local target = CompanionDB.Get(def.fuseInto :: string)
			local fuseBtn = button(row, {
				Position = UDim2.new(0.76, 0, 0.16, 0),
				Size = UDim2.new(0.22, 0, 0.68, 0),
				Text = "FUSE 3 → " .. (if target then target.name else "?"),
				BackgroundColor3 = if count >= 3 then Color3.fromRGB(140, 60, 200) else Color3.fromRGB(60, 55, 70),
			})
			fuseBtn.MouseButton1Click:Connect(function()
				CompanionAction:FireServer("fuse", id)
			end)
		end

		y += 60
	end
	content.CanvasSize = UDim2.new(0, 0, 0, y)
end

local function render()
	local s = lastState
	if s then
		slotsLbl.Text = "Equipped: " .. tostring(#s.equipped) .. "/" .. tostring(s.maxSlots) .. "   (companions boost gold, XP, damage and luck)"
	end
	eggsTabBtn.BackgroundColor3 = if currentTab == "eggs" then Color3.fromRGB(90, 60, 30) else Color3.fromRGB(50, 40, 30)
	mineTabBtn.BackgroundColor3 = if currentTab == "mine" then Color3.fromRGB(90, 60, 30) else Color3.fromRGB(50, 40, 30)
	if currentTab == "eggs" then
		renderEggs()
	else
		renderMine()
	end
	UIStyle.Apply(win)
end

eggsTabBtn.MouseButton1Click:Connect(function()
	currentTab = "eggs"
	render()
end)
mineTabBtn.MouseButton1Click:Connect(function()
	currentTab = "mine"
	render()
end)

-- Hatch reveal overlay
local function showHatch(name: string, rarity: string, fused: boolean?)
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.ZIndex = 50
	overlay.Parent = gui

	local egg = Instance.new("TextLabel")
	egg.Size = UDim2.new(0, 120, 0, 140)
	egg.Position = UDim2.new(0.5, -60, 0.5, -110)
	egg.Text = "🥚"
	egg.TextScaled = true
	egg.BackgroundTransparency = 1
	egg.ZIndex = 51
	egg.Parent = overlay

	local reveal = label(overlay, {
		Text = "",
		Position = UDim2.new(0.25, 0, 0.62, 0),
		Size = UDim2.new(0.5, 0, 0, 60),
		Font = Enum.Font.GothamBold,
		TextColor3 = CompanionDB.RarityColors[rarity] or Color3.fromRGB(255, 255, 255),
	})
	reveal.ZIndex = 51

	-- Shake then reveal
	task.spawn(function()
		for i = 1, 6 do
			local tween = TweenService:Create(egg, TweenInfo.new(0.08), {
				Rotation = if i % 2 == 0 then 12 else -12,
			})
			tween:Play()
			tween.Completed:Wait()
		end
		egg.Rotation = 0
		egg.Text = "✨"
		reveal.Text = (if fused then "FUSED: " else "") .. rarity .. " " .. name .. "!"
		task.wait(2.2)
		overlay:Destroy()
	end)
end

CompanionAction.OnClientEvent:Connect(function(kind: unknown, payload: unknown)
	if kind == "state" and typeof(payload) == "table" then
		lastState = payload :: CState
		render()
	elseif kind == "hatched" and typeof(payload) == "table" then
		local p = payload :: { id: string, name: string, rarity: string, fused: boolean? }
		showHatch(p.name, p.rarity, p.fused)
		CompanionAction:FireServer("hello")
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

OpenStation.OnClientEvent:Connect(function(stationKey: unknown)
	if stationKey == "eggstand" then
		currentTab = "eggs"
		setOpen(true)
	end
end)

local hud = PlayerGui:WaitForChild("HUD") :: ScreenGui
local petsBtn = hud:WaitForChild("PetsButton") :: TextButton
petsBtn.MouseButton1Click:Connect(function()
	setOpen(not win.Visible)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.C then
		setOpen(not win.Visible)
	end
end)

CompanionAction:FireServer("hello")
