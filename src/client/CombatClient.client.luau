--!strict
-- CombatClient

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local CombatHit = Remotes:WaitForChild("CombatHit") :: RemoteEvent
local PlayerDied = Remotes:WaitForChild("PlayerDied") :: RemoteEvent

local ItemDB = require(ReplicatedStorage.Modules.ItemDB)

local swingCooldown = false

local function tryHit()
	if swingCooldown then
		return
	end
	swingCooldown = true

	local char = player.Character
	if not char then
		swingCooldown = false
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		swingCooldown = false
		return
	end

	local origin = root.Position
	local direction = root.CFrame.LookVector * 8

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(origin, direction, params)
	if result then
		local hit = result.Instance
		local model = hit:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChild("MobId") then
			CombatHit:FireServer(model)

			local sel = Instance.new("SelectionBox")
			sel.Adornee = hit
			sel.Color3 = Color3.fromRGB(255, 50, 50)
			sel.LineThickness = 0.08
			sel.Parent = workspace
			task.delay(0.15, function()
				sel:Destroy()
			end)
		end
	end

	task.delay(0.6, function()
		swingCooldown = false
	end)
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		tryHit()
	end
end)

PlayerDied.OnClientEvent:Connect(function(dropped: unknown)
	local msg = "You died! Durability lost."
	if typeof(dropped) == "table" then
		local d = dropped :: { id: string }
		local def = ItemDB.Get(d.id)
		msg = msg .. " Dropped: " .. (if def then def.name else d.id)
	end
	local notifGui = PlayerGui:FindFirstChild("NotificationGui")
	if notifGui and notifGui:IsA("ScreenGui") then
		local frame = notifGui:FindFirstChild("NotifFrame")
		if frame and frame:IsA("Frame") then
			local lbl = frame:FindFirstChildOfClass("TextLabel")
			if lbl and lbl:IsA("TextLabel") then
				lbl.Text = msg
				frame.Visible = true
				task.delay(4, function()
					frame.Visible = false
				end)
			end
		end
	end
end)
