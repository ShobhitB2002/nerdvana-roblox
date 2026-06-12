--!strict
-- HUD: gold, diamonds, weight, health

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local UpdateHUD = Remotes:WaitForChild("UpdateHUD") :: RemoteEvent

local pg = player:WaitForChild("PlayerGui")
local hud = pg:WaitForChild("HUD") :: ScreenGui
local goldLabel = hud:WaitForChild("GoldLabel") :: TextLabel
local diamondLabel = hud:WaitForChild("DiamondLabel") :: TextLabel
local weightBar = hud:WaitForChild("WeightBar") :: Frame
local weightFill = weightBar:WaitForChild("Fill") :: Frame
local weightLabel = weightBar:WaitForChild("WeightLabel") :: TextLabel
local healthBar = hud:WaitForChild("HealthBar") :: Frame
local healthFill = healthBar:WaitForChild("Fill") :: Frame
local rebirthLabel = hud:WaitForChild("RebirthLabel") :: TextLabel

local function setHealth(humanoid: Humanoid)
	local pct = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 0
	healthFill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
end

local function hookCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	setHealth(hum)
	hum.HealthChanged:Connect(function()
		setHealth(hum)
	end)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		setHealth(hum)
	end)
end

if player.Character then
	hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

export type HudPayload = {
	gold: number,
	diamonds: number,
	weight: number,
	maxWeight: number,
	rebirths: number?,
	goldMult: number?,
}

UpdateHUD.OnClientEvent:Connect(function(payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local p = payload :: HudPayload
	goldLabel.Text = "Gold: " .. tostring(p.gold)
	diamondLabel.Text = "Diamonds: " .. tostring(p.diamonds)
	local maxW = math.max(0.001, p.maxWeight)
	local r = math.clamp(p.weight / maxW, 0, 1)
	weightFill.Size = UDim2.new(r, 0, 1, 0)
	weightLabel.Text = string.format("%.1f/%.0f kg", p.weight, p.maxWeight)
	if typeof(p.rebirths) == "number" and p.rebirths > 0 then
		rebirthLabel.Text = string.format("Rebirth %d  (x%.2f)", p.rebirths, p.goldMult or 1)
	else
		rebirthLabel.Text = ""
	end
end)

local RequestSync = Remotes:WaitForChild("RequestSync") :: RemoteEvent
RequestSync:FireServer()
