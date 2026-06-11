--!strict
-- Chopping feedback: particles + floating text (GatherFeedback from server)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local _player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local GatherFeedback = Remotes:WaitForChild("GatherFeedback") :: RemoteEvent

local ItemDB = require(ReplicatedStorage.Modules.ItemDB)

local function burstWoodChips(worldPos: Vector3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.05, 0.05, 0.05)
	holder.Position = worldPos + Vector3.new(0, 2, 0)
	holder.Parent = workspace

	local att = Instance.new("Attachment")
	att.Parent = holder

	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/smoke_main.dds"
	p.Rate = 0
	p.Lifetime = NumberRange.new(0.4, 0.9)
	p.Speed = NumberRange.new(2, 8)
	p.SpreadAngle = Vector2.new(45, 45)
	p.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	p.Color = ColorSequence.new(Color3.fromRGB(120, 90, 50), Color3.fromRGB(60, 45, 25))
	p.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	p.Parent = att
	p:Emit(22)

	Debris:AddItem(holder, 1.2)
end

local function showFloat(text: string, color: Color3, worldPos: Vector3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = worldPos + Vector3.new(0, 3, 0)
	part.Parent = workspace

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 200, 0, 48)
	bb.AlwaysOnTop = true
	bb.StudsOffset = Vector3.new(0, 0, 0)
	bb.Parent = part

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Parent = bb

	local tween = TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 4, 0),
	})
	tween:Play()
	task.delay(0.85, function()
		local fade = TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 1 })
		fade:Play()
	end)
	Debris:AddItem(part, 1.3)
end

GatherFeedback.OnClientEvent:Connect(function(resourceId: unknown, qty: unknown, worldPos: unknown, displayName: unknown)
	if typeof(resourceId) ~= "string" or typeof(qty) ~= "number" then
		return
	end
	local pos = if typeof(worldPos) == "Vector3" then worldPos :: Vector3 else Vector3.new()
	local nameStr = if typeof(displayName) == "string" then displayName :: string else resourceId
	local def = ItemDB.Get(resourceId)
	if def then
		nameStr = def.name
	end

	burstWoodChips(pos)
	showFloat("+" .. tostring(qty) .. " " .. nameStr, Color3.fromRGB(180, 255, 120), pos)
end)
