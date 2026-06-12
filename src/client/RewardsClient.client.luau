--!strict
-- RewardsClient: daily login rewards + playtime chests + promo codes (Gifts button / G key)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local RewardsAction = Remotes:WaitForChild("RewardsAction") :: RemoteEvent

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local UIStyle = require(ReplicatedStorage.Modules.UIStyle)

local gui = Instance.new("ScreenGui")
gui.Name = "RewardsGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 44
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
win.Position = UDim2.new(0.5, -240, 0.5, -235)
win.Size = UDim2.new(0, 480, 0, 470)
win.BackgroundColor3 = Color3.fromRGB(16, 24, 18)
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

label(win, { Text = "DAILY GIFTS", Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(120, 230, 140) })

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

-- Daily strip
local dailyRow = Instance.new("Frame")
dailyRow.Position = UDim2.new(0, 8, 0, 38)
dailyRow.Size = UDim2.new(1, -16, 0, 86)
dailyRow.BackgroundTransparency = 1
dailyRow.Parent = win

local dayCards: { TextLabel } = {}
for i = 1, 7 do
	local card = Instance.new("Frame")
	card.Position = UDim2.new((i - 1) / 7, 2, 0, 0)
	card.Size = UDim2.new(1 / 7, -4, 1, -26)
	card.BackgroundColor3 = Color3.fromRGB(30, 45, 34)
	card.BorderSizePixel = 0
	card.Parent = dailyRow
	label(card, { Text = "Day " .. i, Size = UDim2.new(1, 0, 0.32, 0), Font = Enum.Font.GothamBold })
	local r = GameConfig.DAILY_REWARDS[i]
	local txt = ""
	if r.gold then
		txt ..= tostring(r.gold) .. "g"
	end
	if r.diamonds then
		txt ..= (if txt ~= "" then " + " else "") .. tostring(r.diamonds) .. " dia"
	end
	local body = label(card, { Text = txt, Position = UDim2.new(0, 0, 0.34, 0), Size = UDim2.new(1, 0, 0.6, 0), TextColor3 = Color3.fromRGB(255, 215, 0) })
	body.TextWrapped = true
	dayCards[i] = body
end

local claimDailyBtn = Instance.new("TextButton")
claimDailyBtn.Position = UDim2.new(0.25, 0, 0, 100)
claimDailyBtn.Size = UDim2.new(0.5, 0, 0, 30)
claimDailyBtn.Font = Enum.Font.GothamBold
claimDailyBtn.TextScaled = true
claimDailyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
claimDailyBtn.BorderSizePixel = 0
claimDailyBtn.Text = "..."
claimDailyBtn.Parent = win

local dailyQuestLbl = label(win, { Text = "", Position = UDim2.new(0, 10, 0, 134), Size = UDim2.new(1, -20, 0, 24), TextColor3 = Color3.fromRGB(255, 230, 120) })

label(win, { Text = "PLAYTIME CHESTS (this session)", Position = UDim2.new(0, 0, 0, 162), Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 200, 90) })

local chestList = Instance.new("ScrollingFrame")
chestList.Position = UDim2.new(0, 8, 0, 186)
chestList.Size = UDim2.new(1, -16, 1, -256)
chestList.BackgroundTransparency = 1
chestList.ScrollBarThickness = 6
chestList.BorderSizePixel = 0
chestList.Parent = win

-- Code redeem row
label(win, { Text = "CODE:", Position = UDim2.new(0, 10, 1, -58), Size = UDim2.new(0, 70, 0, 28), Font = Enum.Font.GothamBold })
local codeBox = Instance.new("TextBox")
codeBox.Position = UDim2.new(0, 84, 1, -58)
codeBox.Size = UDim2.new(0, 200, 0, 28)
codeBox.Font = Enum.Font.Gotham
codeBox.TextScaled = true
codeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
codeBox.BackgroundColor3 = Color3.fromRGB(40, 55, 45)
codeBox.BorderSizePixel = 0
codeBox.PlaceholderText = "enter code"
codeBox.ClearTextOnFocus = false
codeBox.Parent = win

local codeBtn = Instance.new("TextButton")
codeBtn.Position = UDim2.new(0, 292, 1, -58)
codeBtn.Size = UDim2.new(0, 90, 0, 28)
codeBtn.Text = "Redeem"
codeBtn.Font = Enum.Font.GothamBold
codeBtn.TextScaled = true
codeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
codeBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
codeBtn.BorderSizePixel = 0
codeBtn.Parent = win

local codeResult = label(win, { Text = "", Position = UDim2.new(0, 10, 1, -26), Size = UDim2.new(1, -20, 0, 20) })

type ChestState = { minutes: number, gold: number?, diamonds: number?, ready: boolean, claimed: boolean }
type DailyQuestState = { label: string, progress: number, qty: number, done: boolean, gold: number, diamonds: number }
type RState = {
	dailyAvailable: boolean,
	streak: number,
	nextDailyIn: number,
	sessionMinutes: number,
	chests: { ChestState },
	dailyQuest: DailyQuestState?,
}

local lastState: RState? = nil
local autoOpened = false

local function setOpen(open: boolean)
	win.Visible = open
	backdropBtn.Visible = open
	if open then
		RewardsAction:FireServer("hello")
	end
end

local function render()
	local s = lastState
	if not s then
		return
	end

	local nextDay = (s.streak % 7) + 1
	for i = 1, 7 do
		local card = dayCards[i].Parent :: Frame
		if i < nextDay or (i == nextDay and not s.dailyAvailable) then
			card.BackgroundColor3 = Color3.fromRGB(20, 30, 24)
		elseif i == nextDay then
			card.BackgroundColor3 = Color3.fromRGB(50, 90, 60)
		else
			card.BackgroundColor3 = Color3.fromRGB(30, 45, 34)
		end
	end

	if s.dailyAvailable then
		claimDailyBtn.Text = "CLAIM DAY " .. tostring(nextDay)
		claimDailyBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
	else
		local hrs = math.floor(s.nextDailyIn / 3600)
		local mins = math.floor((s.nextDailyIn % 3600) / 60)
		claimDailyBtn.Text = string.format("Next gift in %dh %dm (streak %d)", hrs, mins, s.streak)
		claimDailyBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 65)
	end

	local dq = s.dailyQuest
	if dq then
		if dq.done then
			dailyQuestLbl.Text = "Daily Quest: " .. dq.label .. " — DONE!"
			dailyQuestLbl.TextColor3 = Color3.fromRGB(120, 230, 140)
		else
			dailyQuestLbl.Text = string.format("Daily Quest: %s (%d/%d) — %dg + %d dia", dq.label, dq.progress, dq.qty, dq.gold, dq.diamonds)
			dailyQuestLbl.TextColor3 = Color3.fromRGB(255, 230, 120)
		end
	end

	for _, child in ipairs(chestList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local y = 0
	for i, chest in ipairs(s.chests) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 36)
		row.Position = UDim2.new(0, 0, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(35, 45, 38)
		row.BorderSizePixel = 0
		row.Parent = chestList

		local txt = tostring(chest.minutes) .. " min — "
		if chest.gold then
			txt ..= tostring(chest.gold) .. " Gold "
		end
		if chest.diamonds then
			txt ..= tostring(chest.diamonds) .. " Diamonds"
		end
		label(row, { Text = txt, Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(0.66, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })

		local btn = Instance.new("TextButton")
		btn.Position = UDim2.new(0.7, 0, 0.12, 0)
		btn.Size = UDim2.new(0.28, 0, 0.76, 0)
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.BorderSizePixel = 0
		if chest.claimed then
			btn.Text = "CLAIMED"
			btn.BackgroundColor3 = Color3.fromRGB(45, 55, 48)
		elseif chest.ready then
			btn.Text = "CLAIM"
			btn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
			local idx = i
			btn.MouseButton1Click:Connect(function()
				RewardsAction:FireServer("claimChest", idx)
			end)
		else
			btn.Text = tostring(math.max(0, chest.minutes - s.sessionMinutes)) .. "m left"
			btn.BackgroundColor3 = Color3.fromRGB(60, 70, 65)
		end
		btn.Parent = row
		y += 40
	end
	chestList.CanvasSize = UDim2.new(0, 0, 0, y)
	UIStyle.Apply(win)
end

claimDailyBtn.MouseButton1Click:Connect(function()
	RewardsAction:FireServer("claimDaily")
end)

codeBtn.MouseButton1Click:Connect(function()
	if codeBox.Text ~= "" then
		RewardsAction:FireServer("redeemCode", codeBox.Text)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)
backdropBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

RewardsAction.OnClientEvent:Connect(function(kind: unknown, payload: unknown)
	if kind == "state" and typeof(payload) == "table" then
		lastState = payload :: RState
		render()
		-- Auto-open once per session when the daily gift is ready
		if (lastState :: RState).dailyAvailable and not autoOpened then
			autoOpened = true
			setOpen(true)
		end
		local hud = PlayerGui:FindFirstChild("HUD")
		local btn = if hud then hud:FindFirstChild("GiftsButton") else nil
		if btn and btn:IsA("TextButton") then
			btn.BackgroundColor3 = if (lastState :: RState).dailyAvailable
				then Color3.fromRGB(70, 190, 100)
				else Color3.fromRGB(40, 80, 50)
		end
	elseif kind == "codeResult" and typeof(payload) == "table" then
		local p = payload :: { ok: boolean, msg: string }
		codeResult.Text = p.msg
		codeResult.TextColor3 = if p.ok then Color3.fromRGB(120, 230, 140) else Color3.fromRGB(255, 100, 100)
	end
end)

local hud = PlayerGui:WaitForChild("HUD") :: ScreenGui
local giftsBtn = hud:WaitForChild("GiftsButton") :: TextButton
giftsBtn.MouseButton1Click:Connect(function()
	setOpen(not win.Visible)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.G then
		setOpen(not win.Visible)
	end
end)

RewardsAction:FireServer("hello")
