--!strict
-- CompanionServer: egg hatching, equip/fuse, follow visuals, boost provider

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataServer = require(script.Parent.DataServer)
local BoostServer = require(script.Parent.BoostServer)
local CompanionDB = require(ReplicatedStorage.Modules.CompanionDB)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local CompanionAction = Remotes:WaitForChild("CompanionAction") :: RemoteEvent

local BASE_SLOTS = 3

local CompanionServer = {}

local function maxSlots(player: Player): number
	local extra = player:GetAttribute("CompanionSlotBonus")
	return BASE_SLOTS + (if typeof(extra) == "number" then extra else 0)
end

local function pushState(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	CompanionAction:FireClient(player, "state", {
		companions = data.companions,
		equipped = data.equippedCompanions,
		maxSlots = maxSlots(player),
	})
end

-- Equipped companions feed the global boost system
BoostServer.RegisterProvider(function(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return nil
	end
	local m = { gold = 1, xp = 1, gather = 1, damage = 1, luck = 0 }
	for _, compId in ipairs(data.equippedCompanions) do
		local def = CompanionDB.Get(compId)
		if def then
			m.gold *= def.boosts.gold or 1
			m.xp *= def.boosts.xp or 1
			m.gather *= def.boosts.gather or 1
			m.damage *= def.boosts.damage or 1
			m.luck += def.boosts.luck or 0
		end
	end
	return m
end)

local function hatch(player: Player, eggId: string)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local egg = CompanionDB.GetEgg(eggId)
	if not egg then
		return
	end

	-- Pay
	if egg.currency == "gold" then
		if not DataServer.SpendGold(player, egg.cost) then
			CompanionAction:FireClient(player, "error", "Not enough Gold")
			return
		end
	else
		if not DataServer.SpendDiamonds(player, egg.cost) then
			CompanionAction:FireClient(player, "error", "Not enough Diamonds")
			return
		end
	end

	-- Weighted roll; luck boosts Rare+ entries
	local luck = BoostServer.GetMults(player).luck
	local entries: { { id: string, weight: number } } = {}
	local total = 0
	for _, entry in ipairs(egg.pool) do
		local def = CompanionDB.Get(entry.id)
		local w = entry.weight
		if def and (def.rarity == "Rare" or def.rarity == "Epic" or def.rarity == "Legendary" or def.rarity == "Mythic") then
			w = math.floor(w * (1 + math.clamp(luck, 0, 10)))
		end
		table.insert(entries, { id = entry.id, weight = w })
		total += w
	end
	local roll = math.random(1, total)
	local cum = 0
	local resultId = entries[1].id
	for _, entry in ipairs(entries) do
		cum += entry.weight
		if roll <= cum then
			resultId = entry.id
			break
		end
	end

	data.companions[resultId] = (data.companions[resultId] or 0) + 1
	data.index.companions[resultId] = true
	DataServer.Save(player)

	local def = CompanionDB.Get(resultId)
	CompanionAction:FireClient(player, "hatched", {
		id = resultId,
		name = if def then def.name else resultId,
		rarity = if def then def.rarity else "Common",
	})
	pushState(player)
end

local function equip(player: Player, compId: string)
	local data = DataServer.Get(player)
	if not data or (data.companions[compId] or 0) < 1 then
		return
	end
	if table.find(data.equippedCompanions, compId) then
		return
	end
	if #data.equippedCompanions >= maxSlots(player) then
		CompanionAction:FireClient(player, "error", "All companion slots full — unequip one first")
		return
	end
	table.insert(data.equippedCompanions, compId)
	DataServer.PushHUD(player)
	pushState(player)
end

local function unequip(player: Player, compId: string)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local idx = table.find(data.equippedCompanions, compId)
	if idx then
		table.remove(data.equippedCompanions, idx)
		DataServer.PushHUD(player)
		pushState(player)
	end
end

local function fuse(player: Player, compId: string)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local def = CompanionDB.Get(compId)
	if not def or not def.fuseInto then
		return
	end
	if (data.companions[compId] or 0) < 3 then
		CompanionAction:FireClient(player, "error", "Need 3x " .. def.name .. " to fuse")
		return
	end
	data.companions[compId] -= 3
	if data.companions[compId] <= 0 then
		data.companions[compId] = nil
		-- If they fused away an equipped companion they no longer own, unequip it
		local idx = table.find(data.equippedCompanions, compId)
		if idx then
			table.remove(data.equippedCompanions, idx)
		end
	end
	local target = def.fuseInto :: string
	data.companions[target] = (data.companions[target] or 0) + 1
	data.index.companions[target] = true
	DataServer.Save(player)

	local tdef = CompanionDB.Get(target)
	CompanionAction:FireClient(player, "hatched", {
		id = target,
		name = if tdef then tdef.name else target,
		rarity = if tdef then tdef.rarity else "Common",
		fused = true,
	})
	pushState(player)
end

CompanionAction.OnServerEvent:Connect(function(player: Player, cmd: unknown, payload: unknown)
	if cmd == "hello" then
		pushState(player)
	elseif cmd == "hatch" and typeof(payload) == "string" then
		hatch(player, payload :: string)
	elseif cmd == "equip" and typeof(payload) == "string" then
		equip(player, payload :: string)
	elseif cmd == "unequip" and typeof(payload) == "string" then
		unequip(player, payload :: string)
	elseif cmd == "fuse" and typeof(payload) == "string" then
		fuse(player, payload :: string)
	end
end)

-- ============================================================
-- Follow visuals: small floating cubes trailing each player
-- ============================================================

local visuals: { [number]: { Part } } = {}

local function clearVisuals(userId: number)
	for _, part in ipairs(visuals[userId] or {}) do
		part:Destroy()
	end
	visuals[userId] = nil
end

local function syncVisuals(player: Player)
	local data = DataServer.Get(player)
	if not data then
		return
	end
	local current = visuals[player.UserId] or {}
	local want = data.equippedCompanions

	-- Rebuild when the set size changed or ids changed
	local needRebuild = #current ~= #want
	if not needRebuild then
		for i, part in ipairs(current) do
			if part:GetAttribute("CompanionId") ~= want[i] then
				needRebuild = true
				break
			end
		end
	end
	if not needRebuild then
		return
	end

	clearVisuals(player.UserId)
	local parts: { Part } = {}
	for i, compId in ipairs(want) do
		local def = CompanionDB.Get(compId)
		if def then
			local rarityColor = CompanionDB.RarityColors[def.rarity] or Color3.fromRGB(220, 220, 220)

			local p = Instance.new("Part")
			p.Name = "Companion_" .. compId
			p.Size = Vector3.new(1.8, 1.8, 1.8)
			p.Shape = Enum.PartType.Ball
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
			p.Color = def.color
			p.Material = Enum.Material.SmoothPlastic
			p:SetAttribute("CompanionId", compId)

			-- Little face so it reads as a creature
			local face = Instance.new("Decal")
			face.Texture = "rbxasset://textures/face.png"
			face.Face = Enum.NormalId.Front
			face.Parent = p

			-- Rarity-colored trail
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 0.6, 0)
			a0.Parent = p
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.6, 0)
			a1.Parent = p
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(rarityColor)
			trail.Transparency = NumberSequence.new(0.4, 1)
			trail.Lifetime = 0.45
			trail.LightEmission = 0.6
			trail.Parent = p

			-- Epic+ sparkle aura
			if def.rarity == "Epic" or def.rarity == "Legendary" or def.rarity == "Mythic" then
				local pe = Instance.new("ParticleEmitter")
				pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				pe.Rate = 6
				pe.Lifetime = NumberRange.new(0.5, 1)
				pe.Speed = NumberRange.new(0.5, 1.5)
				pe.SpreadAngle = Vector2.new(180, 180)
				pe.LightEmission = 0.8
				pe.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.5),
					NumberSequenceKeypoint.new(1, 0.05),
				})
				pe.Color = ColorSequence.new(rarityColor)
				pe.Parent = a0
			end

			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(0, 120, 0, 24)
			bb.StudsOffset = Vector3.new(0, 1.4, 0)
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.TextScaled = true
			lbl.Text = def.name
			lbl.TextColor3 = rarityColor
			lbl.Parent = bb
			bb.Parent = p

			local char = player.Character
			if char and char.PrimaryPart then
				p.CFrame = CFrame.new(char.PrimaryPart.Position + Vector3.new(i * 2 - 4, 2, 3))
			end
			p.Parent = workspace
			table.insert(parts, p)
		end
	end
	visuals[player.UserId] = parts
end

RunService.Heartbeat:Connect(function(dt: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local parts = visuals[player.UserId]
		local char = player.Character
		local root = if char then char.PrimaryPart else nil
		if parts and root then
			local t = os.clock()
			for i, part in ipairs(parts) do
				local angle = (i / #parts) * math.pi * 2 + t * 0.8
				local target = root.Position
					+ Vector3.new(math.cos(angle) * 4, 2.2 + math.sin(t * 2 + i) * 0.4, math.sin(angle) * 4)
				-- face the player so the little face shows (guard against zero direction)
				local lookDir = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
				local goal = if lookDir.Magnitude > 0.05
					then CFrame.lookAt(target, target + lookDir)
					else CFrame.new(target)
				part.CFrame = part.CFrame:Lerp(goal, math.clamp(dt * 6, 0, 1))
			end
		end
	end
end)

-- Keep visuals in sync (cheap poll; equip changes are rare)
task.spawn(function()
	while true do
		task.wait(2)
		for _, player in ipairs(Players:GetPlayers()) do
			syncVisuals(player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	clearVisuals(player.UserId)
end)

return CompanionServer
