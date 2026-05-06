--!strict
-- Hold LeftShift to sprint

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local WALK = 16
local SPRINT = 26

local sprinting = false

local function setSprint(on: boolean)
	local char = player.Character
	if not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	sprinting = on
	hum.WalkSpeed = if on then SPRINT else WALK
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprint(true)
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprint(false)
	end
end)

player.CharacterAdded:Connect(function(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.WalkSpeed = if sprinting then SPRINT else WALK
end)

-- Gamepad B / ButtonL2 style sprint optional — keep keyboard only for simplicity
