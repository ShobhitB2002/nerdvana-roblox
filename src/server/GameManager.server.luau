--!strict
-- GameManager: Bootstraps shared server modules early.
-- The .server.luau Scripts in ServerScriptService run on their own;
-- only ModuleScripts (DataServer, QuestServer, BossServer) need requiring.

print("[Nerdvana] GameManager starting...")

local ok, err = pcall(function()
	require(script.Parent.DataServer)
	require(script.Parent.QuestServer)
	require(script.Parent.BossServer)
end)
if ok then
	print("[Nerdvana] All systems loaded.")
else
	warn("[GameManager] Module bootstrap failed: " .. tostring(err))
end
