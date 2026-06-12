--!strict
-- LeaderboardServer: OrderedDataStore leaderboards + physical boards in the village

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local DataServer = require(script.Parent.DataServer)

type BoardDef = {
	key: string,
	title: string,
	color: Color3,
	pos: Vector3,
	getValue: (data: any) -> number,
	format: (n: number) -> string,
}

local function fmtInt(n: number): string
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(n)
end

local BOARDS: { BoardDef } = {
	{
		key = "LB_Rebirths_v1",
		title = "TOP REBIRTHS",
		color = Color3.fromRGB(170, 80, 255),
		pos = Vector3.new(-40, 0, -62),
		getValue = function(data)
			return data.rebirths
		end,
		format = fmtInt,
	},
	{
		key = "LB_Gold_v1",
		title = "TOP GOLD EARNED",
		color = Color3.fromRGB(255, 215, 0),
		pos = Vector3.new(40, 0, -62),
		getValue = function(data)
			return math.floor(data.stats.totalGoldEarned)
		end,
		format = fmtInt,
	},
	{
		key = "LB_Playtime_v1",
		title = "TOP PLAYTIME",
		color = Color3.fromRGB(100, 200, 255),
		pos = Vector3.new(-62, 0, -40),
		getValue = function(data)
			return math.floor(data.stats.playtime)
		end,
		format = function(n)
			return string.format("%.1fh", n / 3600)
		end,
	},
}

local stores: { [string]: OrderedDataStore } = {}
for _, b in ipairs(BOARDS) do
	pcall(function()
		stores[b.key] = DataStoreService:GetOrderedDataStore(b.key)
	end)
end

local boardGuis: { [string]: TextLabel } = {}
local nameCache: { [number]: string } = {}

local function buildBoard(b: BoardDef)
	local stand = Instance.new("Part")
	stand.Name = "Leaderboard_" .. b.title
	stand.Size = Vector3.new(10, 12, 1)
	stand.Position = b.pos + Vector3.new(0, 6.6, 0)
	stand.Anchored = true
	stand.Color = Color3.fromRGB(25, 25, 35)
	stand.Material = Enum.Material.SmoothPlastic
	stand.CFrame = CFrame.lookAt(stand.Position, Vector3.new(0, 6.6, 0))
	stand.Parent = workspace

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = stand

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.12, 0)
	title.Text = b.title
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = b.color
	title.BackgroundTransparency = 1
	title.Parent = sg

	local body = Instance.new("TextLabel")
	body.Position = UDim2.new(0, 10, 0.13, 0)
	body.Size = UDim2.new(1, -20, 0.86, 0)
	body.Text = "Loading..."
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.fromRGB(230, 230, 230)
	body.TextScaled = true
	body.BackgroundTransparency = 1
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = sg

	boardGuis[b.key] = body
end

local function playerName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local name = "???"
	pcall(function()
		name = Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = name
	return name
end

local function refreshBoard(b: BoardDef)
	local store = stores[b.key]
	local gui = boardGuis[b.key]
	if not store or not gui then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if not ok then
		return
	end
	local lines: { string } = {}
	local rank = 1
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(string.match(entry.key, "%d+"))
		local name = if userId then playerName(userId) else "???"
		table.insert(lines, string.format("%d. %s — %s", rank, name, b.format(entry.value)))
		rank += 1
	end
	if #lines == 0 then
		gui.Text = "No entries yet — be the first!"
	else
		gui.Text = table.concat(lines, "\n")
	end
end

local function submitScores(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	for _, b in ipairs(BOARDS) do
		local store = stores[b.key]
		if store then
			local value = b.getValue(data)
			if value > 0 then
				pcall(function()
					store:SetAsync("u_" .. tostring(player.UserId), value)
				end)
			end
		end
	end
end

for _, b in ipairs(BOARDS) do
	buildBoard(b)
end

Players.PlayerRemoving:Connect(submitScores)

task.spawn(function()
	while true do
		for _, b in ipairs(BOARDS) do
			refreshBoard(b)
			task.wait(5)
		end
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			submitScores(player)
		end
	end
end)

print("[LeaderboardServer] Ready.")
