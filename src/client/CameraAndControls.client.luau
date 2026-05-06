--!strict
-- Camera zoom: two-finger pinch (touch). Keyboard [ ] / - = for desktop Studio testing.
-- Default mouse wheel still uses Roblox's built-in camera zoom on PC.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local MIN_Z = 4
local MAX_Z = 160

local function applyZoom(delta: number)
	local cur = player.CameraMaxZoomDistance
	local nextZoom = math.clamp(cur + delta, MIN_Z, MAX_Z)
	player.CameraMaxZoomDistance = nextZoom
	player.CameraMinZoomDistance = math.min(6, nextZoom * 0.15)
end

-- Pinch: scale is distance ratio vs previous frame (>1 = fingers apart → zoom out / farther)
local PINCH_SENSITIVITY = 45
UserInputService.TouchPinch:Connect(function(_touchPositions: any, scale: number, _velocity: Vector3, _state: Enum.UserInputState, processed: boolean)
	if processed then
		return
	end
	if math.abs(scale - 1) < 0.008 then
		return
	end
	local raw = (scale - 1) * PINCH_SENSITIVITY
	local step = math.clamp(raw, -18, 18)
	applyZoom(step)
end)

-- Desktop fallback (optional)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftBracket or input.KeyCode == Enum.KeyCode.Minus then
		applyZoom(10)
	elseif input.KeyCode == Enum.KeyCode.RightBracket or input.KeyCode == Enum.KeyCode.Equals then
		applyZoom(-10)
	end
end)

player.CameraMaxZoomDistance = math.clamp(player.CameraMaxZoomDistance, MIN_Z, MAX_Z)
