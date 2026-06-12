--!strict
-- RebirthClient: rebirth window (Rebirth Shrine, HUD button, or R key)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local RebirthAction = Remotes:WaitForChild("RebirthAction") :: RemoteEvent
local OpenStation = Remotes:WaitForChild("OpenStation") :: RemoteEvent

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local gui = Instance.new("ScreenGui")
gui.Name = "RebirthGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 45
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
win.Name = "RebirthFrame"
win.Position = UDim2.new(0.5, -210, 0.5, -230)
win.Size = UDim2.new(0, 420, 0, 460)
win.BackgroundColor3 = Color3.fromRGB(22, 14, 32)
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

label(win, { Text = "REBIRTH", Size = UDim2.new(1, 0, 0, 36), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(190, 110, 255) })

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

local statsLbl = label(win, { Position = UDim2.new(0, 10, 0, 40), Size = UDim2.new(1, -20, 0, 56), Text = "" })
statsLbl.TextWrapped = true

local infoLbl = label(win, {
	Position = UDim2.new(0, 10, 0, 98),
	Size = UDim2.new(1, -20, 0, 48),
	Text = "Rebirth resets your gold, items, gear, mastery and quests — but grants a PERMANENT multiplier and Rebirth Tokens. Defeat the Beast Boss to unlock.",
	TextColor3 = Color3.fromRGB(170, 170, 190),
})
infoLbl.TextWrapped = true

local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Position = UDim2.new(0.1, 0, 0, 152)
rebirthBtn.Size = UDim2.new(0.8, 0, 0, 44)
rebirthBtn.Font = Enum.Font.GothamBold
rebirthBtn.TextScaled = true
rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthBtn.BorderSizePixel = 0
rebirthBtn.Text = "REBIRTH"
rebirthBtn.Parent = win

label(win, { Text = "REBIRTH SHOP (Tokens)", Position = UDim2.new(0, 0, 0, 202), Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 215, 0) })

local perkList = Instance.new("ScrollingFrame")
perkList.Position = UDim2.new(0, 8, 0, 230)
perkList.Size = UDim2.new(1, -16, 1, -240)
perkList.BackgroundTransparency = 1
perkList.ScrollBarThickness = 6
perkList.BorderSizePixel = 0
perkList.Parent = win

type RState = {
	rebirths: number,
	tokens: number,
	canRebirth: boolean,
	multiplier: number,
	nextMultiplier: number,
	nextTokens: number,
	perks: { [string]: boolean },
}

local lastState: RState? = nil
local confirming = false

local function setOpen(open: boolean)
	win.Visible = open
	backdropBtn.Visible = open
	if open then
		RebirthAction:FireServer("hello")
	end
end

local function render()
	local s = lastState
	if not s then
		return
	end
	statsLbl.Text = string.format(
		"Rebirths: %d   |   Tokens: %d\nCurrent multiplier: x%.2f  →  next: x%.2f (+%d tokens)",
		s.rebirths,
		s.tokens,
		s.multiplier,
		s.nextMultiplier,
		s.nextTokens
	)
	if confirming then
		rebirthBtn.Text = "ARE YOU SURE? Click again"
		rebirthBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	elseif s.canRebirth then
		rebirthBtn.Text = "REBIRTH NOW"
		rebirthBtn.BackgroundColor3 = Color3.fromRGB(140, 60, 200)
	else
		rebirthBtn.Text = "Defeat the Beast Boss first"
		rebirthBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	end

	for _, child in ipairs(perkList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local y = 0
	for _, perk in ipairs(GameConfig.REBIRTH_PERKS) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 48)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
		row.BorderSizePixel = 0
		row.Parent = perkList

		label(row, { Text = perk.name, Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(0.7, 0, 0.5, 0), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
		label(row, { Text = perk.desc, Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.new(0.7, 0, 0.45, 0), TextColor3 = Color3.fromRGB(170, 170, 190), TextXAlignment = Enum.TextXAlignment.Left })

		local buy = Instance.new("TextButton")
		buy.Position = UDim2.new(0.74, 0, 0.18, 0)
		buy.Size = UDim2.new(0.24, 0, 0.64, 0)
		buy.Font = Enum.Font.GothamBold
		buy.TextScaled = true
		buy.TextColor3 = Color3.fromRGB(255, 255, 255)
		buy.BorderSizePixel = 0
		if s.perks[perk.id] then
			buy.Text = "OWNED"
			buy.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
			buy.Active = false
		else
			buy.Text = perk.cost .. " Tokens"
			buy.BackgroundColor3 = if s.tokens >= perk.cost then Color3.fromRGB(140, 60, 200) else Color3.fromRGB(70, 70, 80)
			local id = perk.id
			buy.MouseButton1Click:Connect(function()
				RebirthAction:FireServer("buyPerk", id)
			end)
		end
		buy.Parent = row
		y += 52
	end
	perkList.CanvasSize = UDim2.new(0, 0, 0, y)
end

rebirthBtn.MouseButton1Click:Connect(function()
	local s = lastState
	if not s or not s.canRebirth then
		return
	end
	if not confirming then
		confirming = true
		render()
		task.delay(4, function()
			confirming = false
			render()
		end)
	else
		confirming = false
		RebirthAction:FireServer("rebirth")
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)
backdropBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

RebirthAction.OnClientEvent:Connect(function(kind: unknown, payload: unknown)
	if kind == "state" and typeof(payload) == "table" then
		lastState = payload :: RState
		render()
		-- Flash the HUD button when rebirth is ready
		local hud = PlayerGui:FindFirstChild("HUD")
		local btn = if hud then hud:FindFirstChild("RebirthButton") else nil
		if btn and btn:IsA("TextButton") then
			btn.BackgroundColor3 = if (lastState :: RState).canRebirth
				then Color3.fromRGB(170, 70, 255)
				else Color3.fromRGB(80, 40, 110)
		end
	elseif kind == "rebirthed" then
		setOpen(false)
		local notifGui = PlayerGui:FindFirstChild("NotificationGui")
		if notifGui and notifGui:IsA("ScreenGui") then
			local frame = notifGui:FindFirstChild("NotifFrame")
			if frame and frame:IsA("Frame") then
				local lbl = frame:FindFirstChildOfClass("TextLabel")
				if lbl then
					lbl.Text = "REBIRTH " .. tostring(payload) .. "! Permanent multiplier increased!"
					lbl.TextColor3 = Color3.fromRGB(190, 110, 255)
					frame.Visible = true
					task.delay(5, function()
						frame.Visible = false
					end)
				end
			end
		end
	end
end)

OpenStation.OnClientEvent:Connect(function(stationKey: unknown)
	if stationKey == "rebirthshrine" then
		setOpen(true)
	end
end)

local hud = PlayerGui:WaitForChild("HUD") :: ScreenGui
local rebirthHudBtn = hud:WaitForChild("RebirthButton") :: TextButton
rebirthHudBtn.MouseButton1Click:Connect(function()
	setOpen(not win.Visible)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		setOpen(not win.Visible)
	end
end)

RebirthAction:FireServer("hello")
