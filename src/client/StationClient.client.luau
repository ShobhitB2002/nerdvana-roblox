--!strict
-- StationClient

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder
local CraftItem = Remotes:WaitForChild("CraftItem") :: RemoteEvent
local OpenStation = Remotes:WaitForChild("OpenStation") :: RemoteEvent

local RecipeDB = require(ReplicatedStorage.Modules.RecipeDB)
local ItemDB = require(ReplicatedStorage.Modules.ItemDB)

local stationGui = PlayerGui:WaitForChild("StationGui") :: ScreenGui
local stationFrame = stationGui:WaitForChild("StationFrame") :: Frame
local recipeList = stationFrame:WaitForChild("RecipeList") :: ScrollingFrame
local craftBtn = stationFrame:WaitForChild("CraftButton") :: TextButton
local resultLabel = stationFrame:WaitForChild("ResultLabel") :: TextLabel
local closeBtn = stationFrame:WaitForChild("CloseButton") :: TextButton
local backdropBtn = stationGui:WaitForChild("Backdrop") :: TextButton

local function setOpen(open: boolean)
	stationFrame.Visible = open
	backdropBtn.Visible = open
end

local selectedRecipeId: string? = nil

local function renderRecipes(_stationKey: string, recipes: { RecipeDB.Recipe })
	for _, child in ipairs(recipeList:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
	resultLabel.Text = ""
	selectedRecipeId = nil

	local y = 0
	for _, recipe in ipairs(recipes) do
		local outputDef = ItemDB.Get(recipe.output)
		if not outputDef then
			continue
		end

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 60)
		btn.Position = UDim2.new(0, 5, 0, y)
		btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.Parent = recipeList

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -5, 0.55, 0)
		titleLbl.Position = UDim2.new(0, 5, 0.05, 0)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = outputDef.name
		titleLbl.TextColor3 = Color3.fromRGB(255, 230, 100)
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.TextScaled = true
		titleLbl.Parent = btn

		local ingList: { string } = {}
		for itemId, qty in pairs(recipe.inputs) do
			local d = ItemDB.Get(itemId)
			table.insert(ingList, (if d then d.name else itemId) .. " x" .. tostring(qty))
		end
		if recipe.goldCost and recipe.goldCost > 0 then
			table.insert(ingList, tostring(recipe.goldCost) .. " Gold")
		end
		local ingLbl = Instance.new("TextLabel")
		ingLbl.Size = UDim2.new(1, -5, 0.4, 0)
		ingLbl.Position = UDim2.new(0, 5, 0.55, 0)
		ingLbl.BackgroundTransparency = 1
		ingLbl.Text = table.concat(ingList, " | ")
		ingLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
		ingLbl.Font = Enum.Font.Gotham
		ingLbl.TextXAlignment = Enum.TextXAlignment.Left
		ingLbl.TextScaled = true
		ingLbl.Parent = btn

		local recipeId = recipe.id
		btn.MouseButton1Click:Connect(function()
			selectedRecipeId = recipeId
			for _, child in ipairs(recipeList:GetChildren()) do
				if child:IsA("TextButton") then
					child.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
				end
			end
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
			resultLabel.Text = "Selected: " .. outputDef.name
		end)

		y += 65
	end
	recipeList.CanvasSize = UDim2.new(0, 0, 0, y)
	setOpen(true)
end

OpenStation.OnClientEvent:Connect(function(stationKey: unknown, recipes: unknown)
	if typeof(stationKey) ~= "string" then
		return
	end
	if stationKey == "rebirthshrine" or stationKey == "eggstand" then
		return -- handled by RebirthClient / CompanionClient
	end
	local r: { RecipeDB.Recipe }
	if typeof(recipes) == "table" then
		r = recipes :: { RecipeDB.Recipe }
	else
		r = RecipeDB.GetByStation(stationKey)
	end
	renderRecipes(stationKey, r)
end)

craftBtn.MouseButton1Click:Connect(function()
	if not selectedRecipeId then
		resultLabel.Text = "Select a recipe first."
		return
	end
	resultLabel.Text = "Crafting..."
	CraftItem:FireServer(selectedRecipeId)
end)

CraftItem.OnClientEvent:Connect(function(success: unknown, outputOrError: unknown, rarity: unknown)
	if success == true then
		local outId = outputOrError :: string
		local ItemDB_ = ItemDB.Get(outId)
		resultLabel.Text = "Crafted "
			.. (if ItemDB_ then ItemDB_.name else outId)
			.. " ["
			.. (if typeof(rarity) == "string" then rarity else "Common")
			.. "]"
		resultLabel.TextColor3 = Color3.fromRGB(80, 220, 80)
	else
		resultLabel.Text = "Failed: " .. tostring(outputOrError)
		resultLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)
backdropBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

setOpen(false)
