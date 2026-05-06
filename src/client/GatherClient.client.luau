--!strict
-- GatherClient

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local MobDied = Remotes:WaitForChild("MobDied") :: RemoteEvent

local function showFloatingText(text: string, color: Color3?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 160, 0, 44)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	local char = player.Character
	if char and char.PrimaryPart then
		bb.Adornee = char.PrimaryPart
	end
	bb.AlwaysOnTop = false
	bb.Parent = workspace

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = color or Color3.fromRGB(255, 255, 100)
	lbl.Text = text
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Parent = bb

	local start = tick()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - start
		if elapsed > 1.5 then
			bb:Destroy()
			conn:Disconnect()
			return
		end
		bb.StudsOffset = Vector3.new(0, 5 + elapsed * 3, 0)
		lbl.TextTransparency = elapsed / 1.5
	end)
end

MobDied.OnClientEvent:Connect(function(mobId: unknown, goldAmt: unknown)
	if typeof(goldAmt) == "number" then
		showFloatingText("+" .. tostring(goldAmt) .. " Gold", Color3.fromRGB(255, 215, 0))
	end
	if typeof(mobId) == "string" then
		showFloatingText(mobId .. " slain!", Color3.fromRGB(255, 80, 80))
	end
end)
