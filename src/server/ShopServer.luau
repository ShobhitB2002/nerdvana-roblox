--!strict
-- ShopServer: gamepass perks, developer product receipts, diamond cosmetics

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataServer = require(script.Parent.DataServer)
local BoostServer = require(script.Parent.BoostServer)
local RebirthServer = require(script.Parent.RebirthServer)
local MonetizationConfig = require(ReplicatedStorage.Modules.MonetizationConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local ShopAction = Remotes:WaitForChild("ShopAction") :: RemoteEvent

local ShopServer = {}

-- ============================================================
-- Gamepass ownership
-- ============================================================

local PassOwned: { [number]: { [string]: boolean } } = {}

local function ownsPass(player: Player, passKey: string): boolean
	local cache = PassOwned[player.UserId]
	return cache ~= nil and cache[passKey] == true
end

local function applyPassPerks(player: Player)
	if ownsPass(player, "AutoPickup") then
		player:SetAttribute("AutoPickup", true)
	end
	if ownsPass(player, "AutoGather") then
		player:SetAttribute("AutoGather", true)
	end
	if ownsPass(player, "BiggerBag") then
		player:SetAttribute("BagBonus", 50)
	end
	if ownsPass(player, "CompanionSlots") then
		player:SetAttribute("CompanionSlotBonus", 3)
	end
	DataServer.PushHUD(player)
end

local function refreshPasses(player: Player)
	local cache: { [string]: boolean } = {}
	for key, passId in pairs(MonetizationConfig.Gamepasses) do
		if passId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			cache[key] = ok and owns == true
		else
			cache[key] = false
		end
	end
	PassOwned[player.UserId] = cache
	applyPassPerks(player)
end

-- VIP / Luck2x / potions feed the global boost system
BoostServer.RegisterProvider(function(player: Player)
	local m = { gold = 1, xp = 1, gather = 1, damage = 1, luck = 0 }
	if ownsPass(player, "VIP") then
		m.gold *= 1.25
		m.xp *= 1.25
	end
	if ownsPass(player, "Luck2x") then
		m.luck += 1
	end
	local data = DataServer.Get(player)
	if data then
		local now = os.time()
		if (data.boostsUntil["luck"] or 0) > now then
			m.luck += 1
		end
		if (data.boostsUntil["gold"] or 0) > now then
			m.gold *= 2
		end
	end
	return m
end)

-- ============================================================
-- Cosmetic auras
-- ============================================================

local function applyAura(player: Player)
	local data = DataServer.Get(player)
	local char = player.Character
	if not data or not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local existing = root:FindFirstChild("CosmeticAura")
	if existing then
		existing:Destroy()
	end
	local auraId = data.cosmetics.equippedAura
	if not auraId then
		return
	end
	local def = MonetizationConfig.GetAura(auraId)
	if not def then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "CosmeticAura"
	att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 10
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.LightEmission = 0.7
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	pe.Color = ColorSequence.new(def.color)
	pe.Parent = att
end

-- ============================================================
-- State sync
-- ============================================================

local function pushState(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local now = os.time()
	ShopAction:FireClient(player, "state", {
		passes = PassOwned[player.UserId] or {},
		aurasOwned = data.cosmetics.owned,
		equippedAura = data.cosmetics.equippedAura,
		luckPotionLeft = math.max(0, (data.boostsUntil["luck"] or 0) - now),
		goldPotionLeft = math.max(0, (data.boostsUntil["gold"] or 0) - now),
	})
end

ShopAction.OnServerEvent:Connect(function(player: Player, cmd: unknown, payload: unknown)
	local data = DataServer.Get(player)
	if not data then
		return
	end

	if cmd == "hello" then
		pushState(player)
	elseif cmd == "buyAura" and typeof(payload) == "string" then
		local def = MonetizationConfig.GetAura(payload :: string)
		if not def or data.cosmetics.owned[def.id] then
			return
		end
		if not DataServer.SpendDiamonds(player, def.cost) then
			ShopAction:FireClient(player, "error", "Not enough Diamonds")
			return
		end
		data.cosmetics.owned[def.id] = true
		data.cosmetics.equippedAura = def.id
		DataServer.Save(player)
		applyAura(player)
		pushState(player)
	elseif cmd == "equipAura" and typeof(payload) == "string" then
		local id = payload :: string
		if data.cosmetics.owned[id] then
			data.cosmetics.equippedAura = id
			applyAura(player)
			pushState(player)
		end
	elseif cmd == "unequipAura" then
		data.cosmetics.equippedAura = nil
		applyAura(player)
		pushState(player)
	end
end)

-- ============================================================
-- Developer product receipts
-- ============================================================

local function addPotion(data: any, kind: string, seconds: number)
	local now = os.time()
	local base = math.max(now, data.boostsUntil[kind] or 0)
	data.boostsUntil[kind] = base + seconds
end

local productHandlers: { [string]: (player: Player) -> () } = {
	Diamonds100 = function(player)
		DataServer.AddDiamonds(player, 100)
	end,
	Diamonds550 = function(player)
		DataServer.AddDiamonds(player, 550)
	end,
	Diamonds1200 = function(player)
		DataServer.AddDiamonds(player, 1200)
	end,
	Diamonds3000 = function(player)
		DataServer.AddDiamonds(player, 3000)
	end,
	Gold5k = function(player)
		DataServer.AddGold(player, 5000)
	end,
	Gold25k = function(player)
		DataServer.AddGold(player, 25000)
	end,
	LuckPotion30 = function(player)
		local data = DataServer.Get(player)
		if data then
			addPotion(data, "luck", 30 * 60)
		end
	end,
	GoldPotion30 = function(player)
		local data = DataServer.Get(player)
		if data then
			addPotion(data, "gold", 30 * 60)
		end
	end,
	InstantRebirth = function(player)
		RebirthServer.DoRebirth(player, true)
	end,
}

MarketplaceService.ProcessReceipt = function(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataServer.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Idempotency: never grant the same receipt twice
	local pid = tostring(receiptInfo.PurchaseId)
	if table.find(data.purchaseIds, pid) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Resolve which product this is
	local productKey: string? = nil
	for key, id in pairs(MonetizationConfig.Products) do
		if id == receiptInfo.ProductId then
			productKey = key
			break
		end
	end
	if not productKey then
		warn("[ShopServer] Unknown ProductId: " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local handler = productHandlers[productKey :: string]
	if not handler then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	handler(player)
	table.insert(data.purchaseIds, pid)
	while #data.purchaseIds > 50 do
		table.remove(data.purchaseIds, 1)
	end
	DataServer.Save(player)
	pushState(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Re-check passes right after a purchase prompt closes
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, _passId: number, purchased: boolean)
	if purchased then
		refreshPasses(player)
		pushState(player)
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyAura(player)
	end)
	task.spawn(function()
		-- Wait for data, then load passes
		for _ = 1, 100 do
			if DataServer.Get(player) then
				break
			end
			task.wait(0.2)
		end
		refreshPasses(player)
		applyAura(player)
		pushState(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	PassOwned[player.UserId] = nil
end)

return ShopServer
