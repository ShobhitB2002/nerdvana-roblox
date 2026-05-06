--!strict
-- GameManager: Bootstraps server systems (DataServer must load first)

local success, result = pcall(function()
	return require(script.Parent.DataServer)
end)
if not success then
	warn("[GameManager] Failed to load DataServer: " .. tostring(result))
	return
end

print("[Nerdvana] GameManager starting...")

-- Load systems with error handling
local systems = {
	"IslandGenerator",
	"MobAI", 
	"GatheringServer",
	"CraftingServer",
	"RefinementServer",
	"CombatServer",
	"DeathServer",
	"PortalServer",
	"NPCDialogServer"
}

for _, system in ipairs(systems) do
	local success, result = pcall(function()
		return require(script.Parent[system])
	end)
	if success then
		print("[GameManager] " .. system .. " loaded successfully")
	else
		warn("[GameManager] Failed to load " .. system .. ": " .. tostring(result))
	end
end

print("[Nerdvana] All systems loaded.")
