--!strict
-- GameManager: Bootstraps server systems (DataServer must load first)

require(script.Parent.DataServer)

print("[Nerdvana] GameManager starting...")

require(script.Parent.IslandGenerator)
require(script.Parent.MobAI)
require(script.Parent.GatheringServer)
require(script.Parent.CraftingServer)
require(script.Parent.RefinementServer)
require(script.Parent.CombatServer)
require(script.Parent.DeathServer)
require(script.Parent.PortalServer)
require(script.Parent.NPCDialogServer)

print("[Nerdvana] All systems loaded.")
