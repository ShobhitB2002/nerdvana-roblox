--!strict
-- UIStyle: one call makes any window kid-friendly — rounded corners, strokes, gradients.
-- Idempotent: safe to call repeatedly after re-renders.

local UIStyle = {}

local function ensureCorner(inst: Instance, radius: number)
	if not inst:FindFirstChildOfClass("UICorner") then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = inst
	end
end

local function ensureStroke(inst: Instance, thickness: number, color: Color3, transparency: number)
	if not inst:FindFirstChildOfClass("UIStroke") then
		local s = Instance.new("UIStroke")
		s.Thickness = thickness
		s.Color = color
		s.Transparency = transparency
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = inst
	end
end

local function ensureGradient(inst: Instance)
	if not inst:FindFirstChildOfClass("UIGradient") then
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 185, 200)),
		})
		g.Parent = inst
	end
end

-- Style every element under root (a ScreenGui or Frame)
function UIStyle.Apply(root: Instance)
	local items = root:GetDescendants()
	table.insert(items, root)
	for _, inst in ipairs(items) do
		if inst:IsA("TextButton") or inst:IsA("TextBox") then
			if inst.BackgroundTransparency < 1 then
				ensureCorner(inst, 8)
				ensureStroke(inst, 1.5, Color3.fromRGB(0, 0, 0), 0.55)
			end
		elseif inst:IsA("Frame") then
			if inst.BackgroundTransparency < 1 then
				local px = inst.AbsoluteSize.X
				if px > 320 or inst.Size.X.Offset > 320 or inst.Size.X.Scale >= 0.4 then
					-- Big window panel
					ensureCorner(inst, 14)
					ensureStroke(inst, 2.5, Color3.fromRGB(255, 255, 255), 0.75)
					ensureGradient(inst)
				else
					ensureCorner(inst, 8)
				end
			end
		elseif inst:IsA("ScrollingFrame") then
			if inst.BackgroundTransparency < 1 then
				ensureCorner(inst, 10)
			end
		end
	end
end

return UIStyle
