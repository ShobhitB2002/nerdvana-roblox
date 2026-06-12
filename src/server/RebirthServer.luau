--!strict
-- RebirthServer: rebirth flow, token perk shop, overhead rebirth titles

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataServer = require(script.Parent.DataServer)
local QuestServer = require(script.Parent.QuestServer)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local RebirthAction = Remotes:WaitForChild("RebirthAction") :: RemoteEvent

local RebirthServer = {}

local function perkById(id: string): GameConfig.RebirthPerk?
	for _, p in ipairs(GameConfig.REBIRTH_PERKS) do
		if p.id == id then
			return p
		end
	end
	return nil
end

function RebirthServer.PushState(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local owned: { [string]: boolean } = {}
	for k, v in pairs(data.rebirthPerks) do
		owned[k] = v
	end
	RebirthAction:FireClient(player, "state", {
		rebirths = data.rebirths,
		tokens = data.rebirthTokens,
		canRebirth = data.canRebirth,
		multiplier = 1 + data.rebirths * GameConfig.REBIRTH_GOLD_XP_PER,
		nextMultiplier = 1 + (data.rebirths + 1) * GameConfig.REBIRTH_GOLD_XP_PER,
		nextTokens = GameConfig.REBIRTH_TOKENS(data.rebirths + 1),
		perks = owned,
	})
end

local function applyTitle(player: Player)
	local data = DataServer.Get(player)
	local char = player.Character
	if not data or not char then
		return
	end
	local head = char:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local existing = head:FindFirstChild("RebirthTitle")
	if existing then
		existing:Destroy()
	end
	if data.rebirths <= 0 then
		return
	end
	local title, color = GameConfig.GetTitle(data.rebirths)
	local bb = Instance.new("BillboardGui")
	bb.Name = "RebirthTitle"
	bb.Size = UDim2.new(0, 200, 0, 30)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = false
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = color or Color3.fromRGB(120, 220, 120)
	lbl.Text = "[" .. tostring(data.rebirths) .. "] " .. (title or "Reborn")
	lbl.Parent = bb
	bb.Parent = head
end

function RebirthServer.DoRebirth(player: Player, force: boolean?): boolean
	local data = DataServer.Get(player)
	if not data then
		return false
	end
	if not data.canRebirth and not force then
		return false
	end

	data.rebirths += 1
	data.rebirthTokens += GameConfig.REBIRTH_TOKENS(data.rebirths)
	DataServer.ResetLife(player)
	DataServer.Save(player)
	QuestServer.ResetProgress(player)
	QuestServer.PushState(player)

	-- Back to the village spawn
	local char = player.Character
	local portals = workspace:FindFirstChild("Portals")
	local marker = if portals then portals:FindFirstChild("VillageSpawn") else nil
	if char and marker and marker:IsA("BasePart") then
		char:PivotTo(CFrame.new(marker.Position + Vector3.new(0, 4, 0)))
	end

	applyTitle(player)
	RebirthServer.PushState(player)
	RebirthAction:FireClient(player, "rebirthed", data.rebirths)
	return true
end

RebirthAction.OnServerEvent:Connect(function(player: Player, cmd: unknown, payload: unknown)
	local data = DataServer.Get(player)
	if not data then
		return
	end

	if cmd == "hello" then
		RebirthServer.PushState(player)
	elseif cmd == "rebirth" then
		RebirthServer.DoRebirth(player, false)
	elseif cmd == "buyPerk" then
		if typeof(payload) ~= "string" then
			return
		end
		local perk = perkById(payload :: string)
		if not perk then
			return
		end
		if data.rebirthPerks[perk.id] then
			return
		end
		if data.rebirthTokens < perk.cost then
			RebirthAction:FireClient(player, "error", "Not enough Rebirth Tokens")
			return
		end
		data.rebirthTokens -= perk.cost
		data.rebirthPerks[perk.id] = true
		DataServer.Save(player)
		DataServer.PushHUD(player)
		RebirthServer.PushState(player)
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyTitle(player)
	end)
	task.delay(3, function()
		if player.Parent then
			applyTitle(player)
			RebirthServer.PushState(player)
		end
	end)
end)

return RebirthServer
