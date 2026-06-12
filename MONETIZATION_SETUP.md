# NERDVANA — Monetization Setup Guide

Follow this AFTER publishing the game. Total time: ~20 minutes.
Until you do this, the in-game Shop shows everything as "Coming Soon" — safe to launch either way.

## Step 1 — Publish

Open `Nerdvana.rbxlx` in Roblox Studio → File → **Publish to Roblox** → create a new experience.

## Step 2 — Create Gamepasses

Go to [create.roblox.com](https://create.roblox.com) → Creations → your experience → **Monetization → Passes** → Create Pass.
Create these 6 (icon: any 512x512 image; simple colored icons with an emoji-style symbol work fine):

| Name | Price (Robux) | Description to paste |
| --- | --- | --- |
| ⭐ VIP | 249 | +25% Gold and XP forever! Stand out with permanent VIP boosts. |
| 🪓 Auto-Gather | 199 | Automatically gathers nearby trees, ore, stone and fish for you. AFK farming! |
| 🧲 Auto-Pickup | 99 | All nearby loot flies straight into your bag. Never click a drop again. |
| 🍀 2x Luck | 299 | DOUBLE your odds of rare, epic, legendary and mythic crafts AND egg hatches! |
| 🐾 +3 Companion Slots | 199 | Equip 6 companions at once instead of 3. Stack those boosts! |
| 🎒 Bigger Bag | 99 | +50 carry weight forever. Gather longer, return less. |

After creating each pass, open it and copy the number from the URL (`.../game-passes/123456789/...`).

## Step 3 — Create Developer Products

Same page → **Developer Products** → Create:

| Name | Price (Robux) | Grants |
| --- | --- | --- |
| 💎 100 Diamonds | 49 | 100 Diamonds |
| 💎 550 Diamonds | 199 | 550 Diamonds (+10% bonus) |
| 💎 1,200 Diamonds | 399 | 1,200 Diamonds (+20% bonus) |
| 💎 3,000 Diamonds | 799 | 3,000 Diamonds (+50% bonus) |
| 🪙 5,000 Gold | 99 | 5,000 Gold |
| 🪙 25,000 Gold | 349 | 25,000 Gold |
| 🍀 Luck Potion (30 min) | 79 | 2x luck for 30 minutes |
| 🪙 Gold Potion (30 min) | 79 | 2x gold for 30 minutes |
| ⟲ Instant Rebirth | 149 | Rebirth instantly without beating the boss |

Copy each product's ID (shown in the product list).

## Step 4 — Paste IDs into the game

Open [src/ReplicatedStorage/Modules/MonetizationConfig.luau](src/ReplicatedStorage/Modules/MonetizationConfig.luau) and replace each `0` with the real ID:

```lua
MonetizationConfig.Gamepasses = {
	VIP = 123456789,        -- your real pass ID
	AutoGather = 234567890,
	...
```

Then rebuild (`rojo build -o Nerdvana.rbxlx`) and republish — or edit the same values directly in Studio (ReplicatedStorage → Modules → MonetizationConfig) and republish.

## Step 5 — Game settings checklist (create.roblox.com → your experience)

- **Access**: Public
- **Genre**: RPG / Adventure
- **Devices**: PC + Mobile + Tablet (Console optional — UI works but untested)
- **Icon + Thumbnails**: screenshot the village plaza, the corrupted island, and a boss fight. Bright, readable, big text overlay ("REBIRTH!", "HATCH PETS!").
- **Name suggestion**: `NERDVANA RPG [REBIRTH + PETS]` — searchable keywords matter.
- **Monetization → Badges** (optional but free engagement): "First Rebirth", "Beat the Beast Boss".

## What's already wired in code (nothing more to build)

- Pass perks auto-apply on join and immediately after purchase (no rejoin needed)
- Dev product receipts are idempotent (no double-grants, safe on crashes)
- Diamond cosmetics shop (4 auras) creates diamond demand
- Promo codes: edit the `CODES` table in [src/server/RewardsServer.luau](src/server/RewardsServer.luau) — `RELEASE` (25 diamonds) and `NERDVANA` (500 gold) are live; post codes on socials for free marketing
- Admin panel (P key) works for you in live servers (game owner auto-detected)

## Pricing philosophy already enforced

No direct combat-power sales. Everything is convenience (auto-gather), speed (potions), capacity (bag/slots), luck (RNG odds) or cosmetics — free players can earn everything except auras' diamond costs faster by buying. This keeps ratings healthy, which keeps Roblox's algorithm recommending the game.

## Revenue levers after launch

1. Watch which products sell in Creator Hub → Analytics → Monetization.
2. Add limited-time eggs/auras during events (FOMO is the biggest spender driver).
3. Raise/lower prices freely — existing owners keep their passes.
4. Premium Payouts are automatic: longer sessions = more Robux. The daily streak, playtime chests and rebirth loop are doing this work.
