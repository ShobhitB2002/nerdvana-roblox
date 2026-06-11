--!strict
-- Hold LeftShift to sprint. Base speed can be overridden by the admin panel (AdminSpeed attribute).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local sprinting = false

local function baseSpeed(): number
	local s = player:GetAttribute("AdminSpeed")
	return if typeof(s) == "number" then s else 16
end

local function applySpeed()
	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local base = baseSpeed()
	hum.WalkSpeed = if sprinting then base * 1.6 else base
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = true
		applySpeed()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, _processed: boolean)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = false
		applySpeed()
	end
end)

player:GetAttributeChangedSignal("AdminSpeed"):Connect(applySpeed)

player.CharacterAdded:Connect(function(char: Model)
	char:WaitForChild("Humanoid")
	applySpeed()
end)
