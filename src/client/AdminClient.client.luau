--!strict
-- AdminClient: admin panel UI (P to toggle). Only appears for admins —
-- the server tells us via the AdminCommand "state" message and validates every command.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local AdminCommand = Remotes:WaitForChild("AdminCommand") :: RemoteEvent

type AdminState = {
	gatherMult: number,
	xpMult: number,
	damageMult: number,
	rarityBoost: boolean,
	speed: number,
	god: boolean,
}

local panel: Frame? = nil
local statusLabel: TextLabel? = nil
local godBtn: TextButton? = nil
local rarityBtn: TextButton? = nil
local boxes: { [string]: TextBox } = {}

local function buildPanel()
	if panel then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 90
	gui.Parent = PlayerGui

	local p = Instance.new("Frame")
	p.Name = "AdminPanel"
	p.Position = UDim2.new(1, -290, 0.5, -260)
	p.Size = UDim2.new(0, 280, 0, 540)
	p.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	p.BackgroundTransparency = 0.05
	p.BorderSizePixel = 0
	p.Visible = false
	p.Parent = gui
	panel = p

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Text = "ADMIN PANEL  [P]"
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 80, 80)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Parent = p

	local closeBtn = Instance.new("TextButton")
	closeBtn.Position = UDim2.new(1, -28, 0, 2)
	closeBtn.Size = UDim2.new(0, 26, 0, 26)
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextScaled = true
	closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.BorderSizePixel = 0
	closeBtn.Parent = p
	closeBtn.MouseButton1Click:Connect(function()
		p.Visible = false
	end)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 5, 0, 32)
	list.Size = UDim2.new(1, -10, 1, -60)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.BorderSizePixel = 0
	list.Parent = p

	local y = 0

	local function inputRow(label: string, key: string, default: string, cmd: string)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 30)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundTransparency = 1
		row.Parent = list

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.45, 0, 1, 0)
		lbl.Text = label
		lbl.Font = Enum.Font.Gotham
		lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
		lbl.BackgroundTransparency = 1
		lbl.TextScaled = true
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = row

		local box = Instance.new("TextBox")
		box.Position = UDim2.new(0.47, 0, 0.1, 0)
		box.Size = UDim2.new(0.28, 0, 0.8, 0)
		box.Text = default
		box.Font = Enum.Font.Gotham
		box.TextColor3 = Color3.fromRGB(255, 255, 255)
		box.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		box.BorderSizePixel = 0
		box.TextScaled = true
		box.ClearTextOnFocus = false
		box.Parent = row
		boxes[key] = box

		local btn = Instance.new("TextButton")
		btn.Position = UDim2.new(0.78, 0, 0.1, 0)
		btn.Size = UDim2.new(0.22, 0, 0.8, 0)
		btn.Text = "Set"
		btn.Font = Enum.Font.GothamBold
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
		btn.BorderSizePixel = 0
		btn.TextScaled = true
		btn.Parent = row
		btn.MouseButton1Click:Connect(function()
			local n = tonumber(box.Text)
			if n then
				AdminCommand:FireServer(cmd, n)
			end
		end)

		y += 34
	end

	local function buttonRow(label: string, color: Color3, onClick: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -8, 0, 30)
		btn.Position = UDim2.new(0, 0, 0, y)
		btn.Text = label
		btn.Font = Enum.Font.GothamBold
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.BackgroundColor3 = color
		btn.BorderSizePixel = 0
		btn.TextScaled = true
		btn.Parent = list
		btn.MouseButton1Click:Connect(onClick)
		y += 34
		return btn
	end

	inputRow("Walk Speed", "speed", "16", "setSpeed")
	inputRow("Gather x", "gatherMult", "1", "gatherMult")
	inputRow("XP x", "xpMult", "1", "xpMult")
	inputRow("Damage x", "damageMult", "1", "damageMult")
	inputRow("Give Gold", "gold", "100", "giveGold")
	inputRow("Give Diamonds", "diamonds", "10", "giveDiamonds")

	-- Give item: id + qty
	do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 30)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundTransparency = 1
		row.Parent = list

		local idBox = Instance.new("TextBox")
		idBox.Size = UDim2.new(0.5, 0, 0.8, 0)
		idBox.Position = UDim2.new(0, 0, 0.1, 0)
		idBox.Text = "sword_t2"
		idBox.Font = Enum.Font.Gotham
		idBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		idBox.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		idBox.BorderSizePixel = 0
		idBox.TextScaled = true
		idBox.ClearTextOnFocus = false
		idBox.Parent = row

		local qtyBox = Instance.new("TextBox")
		qtyBox.Size = UDim2.new(0.18, 0, 0.8, 0)
		qtyBox.Position = UDim2.new(0.52, 0, 0.1, 0)
		qtyBox.Text = "1"
		qtyBox.Font = Enum.Font.Gotham
		qtyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
		qtyBox.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		qtyBox.BorderSizePixel = 0
		qtyBox.TextScaled = true
		qtyBox.ClearTextOnFocus = false
		qtyBox.Parent = row

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.28, 0, 0.8, 0)
		btn.Position = UDim2.new(0.72, 0, 0.1, 0)
		btn.Text = "Give"
		btn.Font = Enum.Font.GothamBold
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
		btn.BorderSizePixel = 0
		btn.TextScaled = true
		btn.Parent = row
		btn.MouseButton1Click:Connect(function()
			AdminCommand:FireServer("giveItem", { id = idBox.Text, qty = tonumber(qtyBox.Text) or 1 })
		end)
		y += 34
	end

	godBtn = buttonRow("God Mode: OFF", Color3.fromRGB(90, 60, 120), function()
		local on = (godBtn :: TextButton).Text:find("OFF") ~= nil
		AdminCommand:FireServer("god", on)
	end)
	rarityBtn = buttonRow("Rarity Boost: OFF", Color3.fromRGB(90, 60, 120), function()
		local on = (rarityBtn :: TextButton).Text:find("OFF") ~= nil
		AdminCommand:FireServer("rarityBoost", on)
	end)
	buttonRow("Heal Full", Color3.fromRGB(60, 120, 60), function()
		AdminCommand:FireServer("heal")
	end)
	buttonRow("TP Village", Color3.fromRGB(50, 90, 140), function()
		AdminCommand:FireServer("tpVillage")
	end)
	buttonRow("TP Corrupted Island", Color3.fromRGB(110, 50, 140), function()
		AdminCommand:FireServer("tpCorrupted")
	end)
	buttonRow("Unlock Portal + Seal", Color3.fromRGB(110, 50, 140), function()
		AdminCommand:FireServer("unlockPortal")
	end)
	buttonRow("Skip Current Quest", Color3.fromRGB(140, 110, 40), function()
		AdminCommand:FireServer("skipQuest")
	end)
	buttonRow("WIPE MY DATA", Color3.fromRGB(160, 40, 40), function()
		AdminCommand:FireServer("wipeData")
	end)

	list.CanvasSize = UDim2.new(0, 0, 0, y)

	local status = Instance.new("TextLabel")
	status.Position = UDim2.new(0, 5, 1, -26)
	status.Size = UDim2.new(1, -10, 0, 22)
	status.Text = ""
	status.Font = Enum.Font.Gotham
	status.TextColor3 = Color3.fromRGB(255, 120, 120)
	status.BackgroundTransparency = 1
	status.TextScaled = true
	status.Parent = p
	statusLabel = status
end

local function applyState(s: AdminState)
	buildPanel()
	if boxes.speed then
		boxes.speed.Text = tostring(s.speed)
	end
	if boxes.gatherMult then
		boxes.gatherMult.Text = tostring(s.gatherMult)
	end
	if boxes.xpMult then
		boxes.xpMult.Text = tostring(s.xpMult)
	end
	if boxes.damageMult then
		boxes.damageMult.Text = tostring(s.damageMult)
	end
	if godBtn then
		godBtn.Text = "God Mode: " .. (if s.god then "ON" else "OFF")
	end
	if rarityBtn then
		rarityBtn.Text = "Rarity Boost: " .. (if s.rarityBoost then "ON" else "OFF")
	end
end

AdminCommand.OnClientEvent:Connect(function(kind: unknown, payload: unknown)
	if kind == "state" and typeof(payload) == "table" then
		applyState(payload :: AdminState)
	elseif kind == "error" and statusLabel then
		statusLabel.Text = tostring(payload)
		task.delay(4, function()
			if statusLabel then
				statusLabel.Text = ""
			end
		end)
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.P and panel then
		(panel :: Frame).Visible = not (panel :: Frame).Visible
	end
end)

-- Ask the server whether we're an admin (it answers with "state" only for admins)
AdminCommand:FireServer("hello")
