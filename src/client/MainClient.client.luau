--!strict
-- MainClient: client bootstrap + core UI toggles + landscape lock
--
-- Landscape-only play on phones/tablets: enforced via code for 2024/2025 Roblox Studio

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

-- Lock orientation to landscape for mobile devices
StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

local player = Players.LocalPlayer

player.CharacterAdded:Connect(function(_char: Model) end)

-- Default Roblox backpack bar is for Tools; we use a custom inventory (Bag / I). Hide to avoid confusion.
task.defer(function()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end)

print("[Nerdvana Client] Loaded for", player.Name)
