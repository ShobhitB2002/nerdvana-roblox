--!strict
-- RefinementServer: Crafting / refining at stations

local RunService = game:GetService("RunService")

if not RunService:IsServer() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataServer = require(script.Parent.DataServer)
local RecipeDB = require(ReplicatedStorage.Modules.RecipeDB)
local Shared = require(ReplicatedStorage.Modules.Shared)
local RarityRoller = require(ReplicatedStorage.Modules.RarityRoller)

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local CraftItem = Remotes:WaitForChild("CraftItem") :: RemoteEvent
local UpdateInventory = Remotes:WaitForChild("UpdateInventory") :: RemoteEvent
local UpdateMastery = Remotes:WaitForChild("UpdateMastery") :: RemoteEvent
local QuestUpdate = Remotes:WaitForChild("QuestUpdate") :: RemoteEvent

CraftItem.OnServerEvent:Connect(function(player: Player, recipeId: unknown)
	if typeof(recipeId) ~= "string" then
		return
	end
	local data = DataServer.Get(player)
	if not data then
		return
	end

	local recipe = RecipeDB.GetById(recipeId)
	if not recipe then
		return
	end

	local ok, missing = Shared.HasItems(data.inventory, recipe.inputs)
	if not ok then
		CraftItem:FireClient(player, false, "Missing: " .. tostring(missing))
		return
	end

	if recipe.previousTier then
		local _, slot = Shared.FindInInventory(data.inventory, recipe.previousTier)
		if not slot then
			CraftItem:FireClient(player, false, "Need previous tier item")
			return
		end
	end

	for itemId, qty in pairs(recipe.inputs) do
		DataServer.RemoveFromInventory(player, itemId, qty)
	end

	local rarity, _color = RarityRoller.Roll(data.isCorrupted)
	DataServer.AddToInventory(player, recipe.output, recipe.outputQty, rarity)

	DataServer.AddMastery(player, recipe.masteryLine, recipe.masteryXP)
	UpdateMastery:FireClient(player, data.mastery)
	UpdateInventory:FireClient(player, data.inventory, data.equipped)
	CraftItem:FireClient(player, true, recipe.output, rarity)

	QuestUpdate:FireClient(player, "craft", recipeId, 1)
end)

print("[RefinementServer] Ready.")
