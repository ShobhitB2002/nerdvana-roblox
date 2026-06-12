--!strict
-- BoostServer: single source of truth for every multiplier in the game.
-- Combines rebirths, rebirth perks, admin multipliers, and any registered
-- providers (companions, gamepasses, potions register themselves here).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataServer = require(script.Parent.DataServer)
local AdminServer = require(script.Parent.AdminServer)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

export type Mults = {
	gold: number,
	xp: number,
	gather: number,
	damage: number,
	luck: number, -- additive luck bonus (0 = none)
}

type Provider = (player: Player) -> Mults?

local providers: { Provider } = {}

local BoostServer = {}

function BoostServer.RegisterProvider(fn: Provider)
	table.insert(providers, fn)
end

function BoostServer.GetMults(player: Player): Mults
	local m: Mults = { gold = 1, xp = 1, gather = 1, damage = 1, luck = 0 }

	local data = DataServer.Get(player)
	if data then
		local rebirthBonus = 1 + data.rebirths * GameConfig.REBIRTH_GOLD_XP_PER
		m.gold *= rebirthBonus
		m.xp *= rebirthBonus
		if data.rebirthPerks["gold_aura"] then
			m.gold *= 1.1
		end
		if data.rebirthPerks["xp_aura"] then
			m.xp *= 1.1
		end
		if data.rebirthPerks["lucky_soul"] then
			m.luck += 0.1
		end
		if data.isCorrupted then
			m.luck += 0.15
		end
	end

	for _, fn in ipairs(providers) do
		local extra = fn(player)
		if extra then
			m.gold *= extra.gold
			m.xp *= extra.xp
			m.gather *= extra.gather
			m.damage *= extra.damage
			m.luck += extra.luck
		end
	end

	-- Admin/global multipliers apply last
	m.gold *= 1 -- admin has no gold mult; gather/xp/damage below
	m.xp *= AdminServer.State.xpMult
	m.gather *= AdminServer.State.gatherMult
	m.damage *= AdminServer.State.damageMult
	if AdminServer.State.rarityBoost then
		m.luck += 1
	end

	return m
end

return BoostServer
