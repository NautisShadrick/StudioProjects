# Merge Island

Merge Island is a private merge board that each player plays on their own, modelled on Coin Master's Merge Island. Tapping the generator spends Merge Tokens and spawns an item. Dragging one item onto a matching item merges them into the next of 12 tiers. Dropping an item on the faded "ghost" of its tier unlocks more of the 7x7 island. The first time a player makes a tier, it fills that tier's slot on the discovery track and pays the tier's reward. Making all 12 tiers wins the jackpot set, once per event.

It runs standalone in FurnitureGames and is built to become a Game Event Kit feature (`GEK/Optional/MergeIsland`, flag `merge_island`). Every kit service it uses goes through one adapter, so the port is mechanical. See [Porting to the Game Event Kit](#porting-to-the-game-event-kit).

| File | Side | Role |
|---|---|---|
| `MergeIslandConfig.lua` | module | Holds the pure shared rules: the board, the ladder, `ResolveDrop`, spawn tuning, the economy helpers (each takes a reward table as an argument), `STRINGS` / `Text()`, and `ValidateRewardTables`. |
| `MergeIslandManager.lua` | module | The server game, which has the final say on every outcome. It handles spawns and the token debit, moves, discovery and payouts, the payout ledger, packs and cheats. On the client it holds the player's local copy of their own state and the HUD's subscriptions. |
| `MergeIslandKit.lua` | module | The kit seam. Each function has the contract of the GEK member named in its comment. Standalone, it also holds the reward tables. |
| `UI/MergeIslandHUD.*` | UI | The full-screen board, track, jackpot panel, overlays and the standalone world-top button. |
| `UI/Art/` | | All art. `ArtSource/MergeIsland` holds the SVG sources (`node render.mjs`, then `python check.py`). |

All three modules sit on the scene's `MergeIsland` object, and `MergeIslandHUD` sits on its own object.

## A turn

1. **Spawn.** The client sends `SpawnRequest(multiplier, requestId)`. The server checks, in this order: the records have loaded, the window is open, the multiplier is unlocked, the balance minus the tokens already committed covers the cost, and a free cell exists. It then holds a free cell for this tap and queues it. Only one token debit is in flight at a time, and taps that arrive meanwhile are paid with **one** `Debit` of their total. When the debit lands, the server rolls each spawn's luck and tier into its held cell. **Every request is answered by its id**, whether accepted (`spawns`) or refused (`spawnRejects`). A failed debit refuses the whole batch and spends nothing.
2. **Move.** The client sends `MoveRequest(from, to, requestId)`. The server runs `ResolveDrop`, refuses a target cell held for a spawn that is still being paid for, and answers with `move = { requestId, from, to, kind, tier }`. The HUD animates that answer, not its own prediction. An unlock also grows the board (`ExpandFrom`).
3. **Discovery.** A merge, unlock or spawn that produces a tier above `highestTier` pays the discovery rewards of every tier it passes. Making the top tier also wins the jackpot. Both go into **one** payout (see below), and the snapshot carries `paid` and `payoutId` so the reveal shows exactly what was granted.
4. **Packs.** When out of tokens, the player is offered the token packs, each buyable once per event. The client sends `RequestTopUp`. The server's `FulfillTopUp(player, offerIndex, purchaseId, cb)` is the receipt handler.

## Records

The player's state is split across three stores. Each store has one write in flight per player, and saves requested meanwhile are combined into one follow-up write, so a write can never land out of order:

- **Wallet:** Merge Tokens, an event-inventory item (`merge_token`, bet `merge_island`). The backend owns this balance and the game keeps no copy of it.
- **Board (`MergeIslandBoard`):** the cells, `SAVE_VERSION` and the event id. Saves are delayed and batched. A board from another event or version, or one that can't be read, is replaced by a fresh board, and nothing else is lost.
- **Ledger (`MergeIslandLedger`):** what every payout depends on: `highestTier`, `paidThroughTier`, `jackpotPaid`, `offersBought`, `purchases` (every receipt ever fulfilled), the `owed` list and `starterGranted`. It is written immediately. Board resets and format changes never touch it.

Until all three records have loaded, every request is refused (`loading`). A record that fails its load retries at 2, 5 and 10 s, then stays unloaded. The HUD shows "couldn't load", and the player cannot play rather than start over a fresh record.

## Payouts: mark first, grant at most once

1. **Mark.** The action advances the ledger's marks and adds one `owed` entry holding the exact rewards. Tickets are already boosted, so the amount recorded is the amount granted.
2. **Mark the attempt.** Granting an entry first saves it as `attempted`, then makes one `GrantRewards` call.
3. **Settle.** Whether the grant succeeds or fails, the entry is then removed.
   - A reported failure is never retried, because a timeout can hide a grant that actually landed. It raises an `ALERT` for a manual comp.
   - An entry still marked `attempted` on a later load is treated the same way.
   - An entry that was never attempted is simply paid on the next load. So a disconnect or a storage error can delay a payout, but never drop it or pay it twice.
4. **Hold while watched.** A payout the player is watching is held until the HUD sends `PresentationDoneRequest(payoutId)`. This happens when the reveal is collected, or for the jackpot when the win screen is collected. A 30 s fallback releases it if the HUD never reports. Closing the HUD sends `PAYOUT_ALL`. This exists because item grants pop the platform's reward screen as soon as they land.
5. **Disconnect.** A held payout is not granted on disconnect. It stays owed and is paid on the next load.

If the reward tables fail validation, the server grants nothing and leaves every mark where it is. Once the tables are fixed, everything earned in the meantime is paid.

## Per-event configuration

There are three tables. Standalone, they live in `MergeIslandKit.lua`'s `REWARD_TABLES` and are read with `RewardTable(id)`. The rows are already shaped like the kit's JSON:

| Table | Shape | Notes |
|---|---|---|
| `mergeIslandDiscovery` | `[{ tier, rewards: [{ kind, itemId?, amount, label }] }]` | Paid once per tier per event. Merge Tokens are `kind: "coins"`; `"tokens"` means lucky tokens. A tier missing from the table pays nothing. |
| `mergeIslandJackpot` | `[{ kind, itemId?, amount, label, icon? }]` | At most 4 entries (`MAX_JACKPOT_ENTRIES`). `icon` is the standalone card art class. |
| `mergeIslandTopUps` | `[{ amount, productId, priceLabel }]` | Each pack is buyable once per event. The amounts, prices and product ids are **placeholders**. |

`ValidateRewardTables` checks all three tables at Awake. The rules, tuning, ladder names and art live in `MergeIslandConfig.lua`; they belong to the kit and stay the same from event to event.

## QA

All of these are inspector fields, and every one **must be off for release**.

| Flag | On | Effect |
|---|---|---|
| `_debugCheats` | `MergeIslandKit` | Shows the HUD's RESET button and allows `CheatRequest`: `reset_board` (keeps the discoveries and payouts), `reset_all` (also resets the track, the jackpot and the starter tokens), and `replay_topup` (redelivers the last debug receipt, which must grant nothing). |
| `_debugWindowClosed` | `MergeIslandKit` | The schedule window reads as closed. Spawns are refused, but merges still work. |
| `_debugCurrencyLatency` | `MergeIslandKit` | Adds this many seconds to every currency call, to simulate the backend round trip. |
| `_debugFailLoad` | `MergeIslandKit` | Every record load fails after its retries, so the HUD shows "couldn't load". |
| `_debugFreeTopUp` | `MergeIslandManager` | A pack is fulfilled at once with a synthetic receipt. |

Standalone, the starter grant (`STANDALONE_STARTER_TOKENS`, 51 tokens, once per event) stands in for the participation track. Bumping `STANDALONE_EVENT_ID` starts a new event: fresh board, ledger and wallet. Tickets and items are logged as `REWARD (standalone, not granted)`. Merge Tokens are real.

The server's log lines are data: every spend, earning, receipt and `ALERT` is kept. `[MergeTelemetry]` lines carry the spec'd telemetry events, and `MergeIslandKit` prints a `SESSION_SUMMARY` of per-player counters when the player leaves.

## Porting to the Game Event Kit

1. **Run `Highrise > GEK > New Feature...` with "Merge Island" and the reward table option unticked.** Then put these files in `GEK/Optional/MergeIsland/`, renamed with the `_GEK` suffix:
   - `MergeIslandManager` → `MergeIslandModule_GEK`
   - `MergeIslandConfig` → `MergeIslandRules_GEK`
   - `MergeIslandHUD` → `MergeIslandUI/MergeIslandUI_GEK`

   Update the `require`s and the HUD's `TweenModule` → `EventTweenModule_GEK` (same `Tween` / `Easing` API). Attach the modules to the kit prefab's `Modules` object.
2. **Replace `MergeIslandKit` with kit calls**, one function at a time, using the GEK member named in each function's comment. The members that change shape are:
   - `currency.GetBalance(pData)`
   - `GEK.CanUseCheats(player.name)`
   - `NewCurrency` (no `ServerInit` / `IsReady`; readiness comes from `PlayerTracker_GEK`)
   - `NewRecordStore`: the kit's version also needs this store's serialized writes, `MarkDirty`, `IsLoadFailed` and `SetOnLoadFailed`. Upstream them into `MinigameUtils_GEK.NewRecordStore`, which helps every user of that store.
   - `STANDALONE_STARTER_TOKENS` becomes 0.
3. **Reward tables.** Copy the three `REWARD_TABLES` entries into `GEK/RewardDefaults/<id>.json` and as `_mergeIslandDiscovery` / `_mergeIslandJackpot` / `_mergeIslandTopUps` fields on `EventSettings_GEK.lua`. Add their `GEKRewardRegistry.cs` sections, with `ValidateRewardTables`' rules as validators. Move the jackpot item ids to real items, drawn from kit item art instead of `icon`.
4. **Purchases.** The client's `RequestTopUp` opens the pack's product through `PurchaseManager_GEK`. Its receipt router sends the product to `FulfillTopUp`, a feature-fulfilled receipt that acknowledges when `cb(true)`. Register `merge_token` as an event-inventory item on the backend.
5. **Opening the game.** Add `MergeIslandPanel` as the **last** `--!SerializeField` on `EventUIModule_GEK`, plus `OpenMergeIslandPanel` / `CloseMergeIslandPanel`, which call the HUD's `Open()` / `Close()`. Add a v2 HUD widget (`v2EventHUDModule_GEK`, which also goes into `SCHEDULED_FEATURES`) and a legacy sticker in `HudButtonsUI_GEK`. Remove the HUD's `buildWorldTopButton`. The HUD should also refresh its balance on `playerInventory.Changed`, since track grants arrive outside this feature.
6. **Icons.** Map `merge_token` to an icon in `EventUIModule_GEK`, `RewardParticle_GEK` and `MiniItemRewards_GEK`.
7. **Schedule and docs.** Give the `merge_island` flag a window in the feature schedule. Add a `## MergeIslandModule_GEK` section to `PUBLIC_API.md` covering `FulfillTopUp`, the debug flags and anything a world calls. Turn this README into the feature folder's README.
8. **Art.** Rewrite `project://database/Assets/MergeIsland/` to `project://database/Assets/GEK/Optional/MergeIsland/` in the USS.
9. **Localization.** Turn `MergeIslandConfig.STRINGS` into `merge_island_*` keys and replace `Text()` with the kit's localization lookup. These static UXML strings also need keys:
   - Find all items to win
   - Higher Power Boost Available!
   - Merge Island
   - Tap to Collect
   - You Win!
   - Collect
   - How to Play
   - the two non-economy How-to-Play lines
   - Got it!
   - Out of Merge Tokens!
   - the pack subtitle
   - Not now

## Not built yet

The delivery and bonus-spinner features from the spec are not in the code. `Assets/MergeIsland/energy.png` and `UI/Art/map.png` are not referenced by anything.
