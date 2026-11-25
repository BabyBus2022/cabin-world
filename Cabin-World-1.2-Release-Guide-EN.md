# Cabin World 1.2 | What Changed Since 1.1

This edition starts new players as Tuantuan. The livestock shop in Qingxi Village sells cat food and dog food for three coins per portion. Approach your pet and press E to feed it. The pet hospital is excluded.

**Windows x64 public release · Revised November 23, 2026**

Version 1.2 connects the park to Qingxi Village (清溪村). You can take the bus to an empty farm, dig a pond, lay a wooden bridge one tile at a time, and bring home a live fish you caught in the river. Little Whale (小鲸鱼), the resident included in this edition, can work on the farm and invite you to play at the arcade. You also have your own playable character and can build a cottage on the farm.

This guide compares the revised 1.2 build with the final November 13 public release of 1.1, `CabinWorld-1.1-win64.zip` (choice1). Chinese names in parentheses identify locations and controls in the footage.

## Changes verified on a clean install

- New players start with the current Settings window, the renovated arcade and Little Whale's Character Workshop animation set (113 actions, 991 frames). The module selector still supports individual choices.
- At Little Whale's front door, press **E** to choose the park or take the marked path to the beach. The beach also offers a return walk. Both trips use the character's normal navigation.
- Minesweeper has raised covered tiles, flat revealed tiles and numbered clues. Minesweeper and Tetris have single-player panels. On the Xiangqi board, the river labels, palace diagonals and starting-position marks help orient the viewer. The last move appears in Chinese notation from the moving side's perspective.
- At the park stop the bus pulls in, opens its doors and departs before the village loads. In the main world's bathhouse, enter the central pool, swim with WASD or the arrow keys and press **E** to climb out.
- Village arrivals no longer show the background-growth notification. The red-roof pet shelter is available as furniture on the farm. Place it to open an adoption point, or remove it in the editor. The starting farm is empty.

## Three scenes to capture

| Scene | What to show |
|---|---|
| From the park to a farm of your own | Start at the park bus stop. Cut from the empty farm and its signpost to the player digging water tiles and laying a wooden bridge. Widen the deck by adding a second row, then show a fish swimming underneath. |
| From the river to the pond | Cast into the village river, wait for a bite, and reel in the catch. Show its species and length, carry it to the farm, then release it into the pond. Use the village river for white crests where currents meet and the farm pond for reflections and rain rings. |
| An invitation from Little Whale | Launch with `start.cmd`. Show Little Whale’s invitation, accept it in Observer mode, then cut to the Xiangqi board. Xiangqi (Chinese chess) and Gomoku were already playable in 1.1. The 1.2 addition here is the way a resident invites the player and the player joins. |

## Getting started

Extract the entire ZIP. Open `CabinWorld.exe` to play, or double-click `start.cmd` to run both the game and the local bridge for resident automation or your own bot. The bundle includes everything needed for either route. Use `selfcheck.cmd` to check the installation. For a first visit, follow **Park (公园) bus stop → Qingxi Village → Home Farm (自家农场)**. For an existing save, see the setup and migration guide, `开始使用与升级.md`, inside the ZIP.

## 1. New and expanded features

| No. | Feature | What you can do or see in 1.2 |
|---|---|---|
| 01 | Player and Observer modes | Switch modes in Settings. In Player mode, walk up to an object and press **E** to interact. In Observer mode, pan the camera, follow a resident, or explore the map. |
| 02 | Bus service to Qingxi Village | Catch the bus in the park and ride back from the village. A loading screen marks the crossing between worlds. |
| 03 | Village destinations | The top bar gives quick access to the farm, barn (牧场屋), home cottage (自家小屋), bathhouse (暖汤屋), seed shop, and livestock shop. The barn and cottage become available once you build them. |
| 04 | Villagers and their homes | Visit villagers in furnished rooms with fixed layouts. Look for the little Tuantuan villagers (团团) moving around the fields and village. |
| 05 | Village shops and bathhouse | Little Bell General Store (小铃杂货) follows the Cabin World shop layout, with shelves, refrigerated cases, and a checkout. The bathhouse has a lit interior you can enter. The seed and livestock shops each carry their own stock. |
| 06 | Build your farm | Till plots, lay paths and flooring, dig channels, and place fences, gates, and equipment. Right-click a tile to remove what you placed there, one layer at a time. |
| 07 | Modular wooden bridges | Lay one full tile of decking at a time. Add rows beside it to make a wider deck you can walk across sideways. Edge beams join along the outside, and fish can swim underneath. |
| 08 | Grow crops | Till, sow, water, harvest, and sell. Water a single plant or use the watering can on nearby plots. Individual plants sway in the wind, and light catches their leaves as they turn. |
| 09 | Four kinds of livestock | Raise chickens, cows, pigs, and sheep. Feed and water them, collect their produce, and pair them for breeding. Let them roam or build an enclosure. |
| 10 | A shared feed trough | One trough serves all four species and tracks their feed separately. Chickens eat wheat. Cows and sheep eat hay. |
| 11 | A pond of your own | Join water tiles on the farm to form a pond. Stock it with fry, add feed, check which fish live there, and harvest them. Both species and growth stage affect a fish’s visible size. |
| 12 | River fishing and live catches | Fish in the park river, village river, or farm pond. Cast, wait for a bite, then reel in. Each catch has a species and a length. Sell it, keep it for cooking, or take a live river fish home to raise. |
| 13 | Pet varieties and growth | Choose from orange, Chinese tabby (狸花), and white cats, or Golden Retrievers, Shiba Inus, and Corgis. Each has juvenile and adult stages and four-direction walking animations. |
| 14 | Pet ownership, following, and beds | Press **E** near a pet to see its owner. Its owner can rename it and ask it to follow, even between worlds. Place a pet bed at home and the pet can settle there when its resident owner goes to sleep. |
| 15 | A cottage with room to share | Expand the rural cottage, move between floors, and rest in separate beds. The game tracks occupied beds when residents share a room. Light through the windows changes with the time and weather. |
| 16 | Lighting for the farm and village | Place an incandescent hanging lamp or a twin lamp with wider coverage. Turn a fixture and the light stays with its bulbs. Village lanterns, campfires, and lit interiors also brighten the night. |
| 17 | Riverbeds, pond surfaces, and swimming fish | Stones vary in size, spacing, and position while retaining their texture. Pebbles and moss show through the shallows, and the water darkens with depth. Crossing ripples form white crests on the village river. The farm pond has reflections, rain rings, and animated fish. |
| 18 | Join, watch, and replay arcade games | Accept a resident’s invitation in the game, play or spectate, and start a rematch. Version 1.2 expands how players take part in existing games such as Xiangqi and Gomoku. |
| 19 | Resident appearance and animation packs | Configure a resident’s look and animations. The release updates character art, portraits, and action poses, and includes Little Whale and the player character. |
| 20 | Residents can interact with the village | The public bridge lists actions for fields, livestock, ponds, pets, cottages, and shops. A connected bot can query the farm, walk to a target, act, and read the game’s confirmation through the existing `cabin_go`, `cabin_catalog`, and `cabin_use` tools. |
| 21 | Usage journal | When the host supplies usage data, browse model calls by date, input and output tokens, cache hits, and usage by activity. A fresh installation starts with an empty journal. |
| 22 | Optional upgrades and a bundled runtime | On first launch the installer asks whether the player has an existing save. First-time players get the full release. Returning players select their old game folder, import their progress and choose from nine optional upgrades. Qingxi Village, farm gameplay, shared storage, resident farm care, livestock resupply and village visual effects form one choice. Existing 1.1 settings carry forward. The Windows x64 Node.js runtime for the local bridge is included. |
| 23 | Residents can queue their next steps | A player or connected bot can queue several destinations and actions. A resident finishes the current activity, then works through the plan in order. Queued plans survive a restart. |
| 24 | Residents respond to hunger and thirst | A resident who needs a drink or a meal can act on that need. Options include drinking from the backpack, buying water, drinking at the point of purchase when the bag is full, and having tea where available. |
| 25 | Residents can help care for the farm | When livestock feed runs low, an available resident can buy supplies and refill the trough. Tending existing crop plots has its own switch. |
| 26 | Resident invitations and action confirmations | The local bridge lets a resident invite the player to a game. The invitation card shows the words sent with that invitation. Connected bots can check current conditions and read the game’s confirmation of farm actions. |

## 2. Fixes included in 1.2

The list includes issues reported in 1.1 and issues found while developing the village and other 1.2 features.

| No. | What players saw | What changed |
|---|---|---|
| 01 | The player character appeared in the village in Observer mode. | Observer mode hides the character. Player mode makes it visible again. |
| 02 | Switching from Observer to Player sent you back to the park. | Switching modes keeps you at your current location. |
| 03 | Following Little Whale from the village failed when she was in the other world. | The Observer camera switches to her world. In Player mode, your character finds a route to her. |
| 04 | Clicking a village destination in the top bar did nothing in Observer mode. | The destination buttons move the camera and adapt to the available width. |
| 05 | Observer mode had no minimap, and the **T** prompt covered its corner. | Observers now have a minimap. The return prompt sits in the upper-right corner. |
| 06 | Pressing **T** to change scenes made the screen appear frozen. | A loading screen gives visible feedback during the transition. |
| 07 | The camera was stuck in the shared cottage, and Observer mode had no ambient sound. | The indoor camera can move, and ambient audio plays for observers. |
| 08 | Choosing the livestock shop from the seed shop sent you to the farm. | Navigation takes you to the shop you selected. |
| 09 | The editing grid disappeared, and observers had trouble placing objects. | Edit mode shows the grid. Observers can build while their character stays hidden. |
| 10 | In Observer edit mode, the preview appeared two tiles away from the cursor. | Hit detection and the placement preview now use the same viewport coordinates. |
| 11 | Removing a fence required selecting a fence in the hotbar first. | Right-click removes the placed object under the cursor. Furniture comes up before the floor beneath it. Planted plots retain their protection. |
| 12 | Bridge ends met the banks abruptly, and the large lamp base blocked narrow ground. | The bridge meets the banks more naturally. A smaller lamp footprint leaves room to walk on grass and small islands. |
| 13 | Street lamps could not turn, and the bright center barely lit the surrounding area. | Lamp rotation, bulb positions, light radius, and the twin lamp’s central brightness were adjusted. |
| 14 | A village lantern would not turn on, a bench faced the wrong way, and the campfire gave little light. | The lantern responds to interaction, the bench back faces the viewer, and the campfire has animated flames and a wider glow. |
| 15 | Livestock struggled to enter or leave the barn and ignored water beside the bank. | Barn access and reachable drinking spots were adjusted. All four species can wade in shallow water. Deep water blocks them. |
| 16 | Chickens had wheat in the trough, yet the game warned that they needed a fenced trough. | Free-range animals can use a reachable shared trough. The game checks the feed for the animal’s species. |
| 17 | Feed ran out so quickly that an entire flock could starve in a short time. | Feed consumption and the starvation grace period were rebalanced. The farm reports shortages so residents can restock. |
| 18 | A bot said it had placed chickens or released fry, yet the player could find neither. | Farm actions return confirmation from the game. Residents can inspect crops, livestock, and pond stock. Stocking fry targets an actual pond on the home farm. |
| 19 | Fry and fish feed were missing from the shop, and residents appeared to work from a distance. | The livestock shop stocks both. Reaching the shore, releasing fry, feeding, casting, and harvesting are distinct steps. Farm work that requires proximity checks arrival. |
| 20 | Young fish were hard to see, and larger fish looked as though they swam on their sides. | Juveniles are easier to spot. Swimming posture, direction, tail movement, and the way fish appear in deep water were adjusted. |
| 21 | Rain rings formed a rigid grid, and sharp seams appeared near lily pads. | Raindrops vary in position and size. Cloud shadows and surface ripples continue across patch boundaries. |
| 22 | Pets stood still after a follow command, and another person could rename them. | Following movement and cross-scene synchronization were corrected. Follow and rename commands check ownership. |
| 23 | Furniture in villagers’ homes faced the wrong way or looked out of scale, and its icons were blurry. | Furniture proportions, facing, and catalog previews were revised. Field edges, scarecrows, village paths, and stairs in the shared cottage are easier to read. |
| 24 | The village and Cabin World showed different balances for the same player. | Village purchases and sales use the player’s Cabin World wallet. Residents keep their own spending money. |
| 25 | Village items appeared under internal English names in the backpack, and the counts looked wrong. | The sidebar now reads village item names and quantities, with Chinese labels for produce, fry, and feed. |
| 26 | A thirsty resident with a full bag repeatedly logged a failed attempt to drink. | A resident can buy water and drink it on the spot with a full bag. Ordinary purchases still check capacity. |
| 27 | Other interface panels covered the board after the player chose to spectate from the sidebar. | The spectator window keeps the board and its controls visible. |
| 28 | Accepting an invitation as an observer produced a “player not present” message. | Observers can enter the invited game directly. Player mode handles seating the character. |
| 29 | Invitation portraits stretched vertically, and every card repeated the same line. | Portraits keep their proportions. Each card displays the message for that invitation. |
| 30 | After a rematch request, the resident stayed in the match while the player could not enter. | The rematch uses the previous participants and match state and lets the player enter the new round. |
| 31 | Snake blamed the opponent for crashing when the player had crashed first. | The result names the snake that actually crashed and handles simultaneous collisions separately. |
| 32 | A falling block stopped moving left with no visible edge to explain why. | The board grid and both side boundaries match the playable area. |
| 33 | One click in Minesweeper exposed every mine. | Unopened tiles stay covered. Revealed tiles show adjacent mine counts, empty areas expand, flags mark suspected mines, and hitting a mine ends the round. |
| 34 | Characters blocked each other in narrow arcade aisles, and the game could freeze for long stretches. | Pathfinding uses a spatial index so characters can make way without repeatedly recalculating the entire map. |
| 35 | The public park retained a dead-end exit after a private room was removed. | The park map, old layout, and navigation data now agree. Each remaining exit has a destination. |
| 36 | Village dorm furniture depended on room textures missing from the public download. | Plants, books, lamps, and seating use public assets. The barn and private cottage were both entered during release testing. |
| 37 | Remodeling a cabin left the old floor and walking area in place. | The reported floor, walls, doors, and grid origin were applied to a publishable room. After a restart, the rendered floor and walkable tiles matched the edit. If the old layout leaves a piece of furniture unsupported, the game identifies it by name. |
| 38 | Assigning an unfurnished custom map to a resident left only the doorway usable. | On the reported 30 × 20 map, the resident received a bed, desk, and fish tank, each with a working interaction area. |
| 39 | Remodeling could report a missing furniture-library entry and lose a custom placement. | A PNG item created in the workshop retained its asset, instance ID, and placed position after publishing the edited room and restarting. The report omitted the two original furniture PNGs, so the test used newly created artwork. |

## Public build revisions from the simulation tests

| Report | Change |
|---|---|
| A1 | Residents can walk to the farm noticeboard, inspect it, survey the farm, and ask for guidance on a topic. |
| B1, B2 | Shop listings reflect seasonal availability. Disabling Gomoku also removes it from the chess table description and general hints. |
| B3, C4 | Shelves quote the game's current sale price. The seed shop checks the entire order and reports both the total cost and the available balance. |
| B4, C6 | A loss briefly affects mood. A later game, a favorite meal, or a soak can change how a resident feels. Activities also update the resident's current thought. |
| B5 | Farm inspections return summaries specific to the location. Longer lists are paginated. Prices, breeds, growth, and rules can be requested separately. |
| B6 | Liking a restaurant meal records a taste preference and can fulfill the favorite-food wish. Rating the same meal again counts only once. |
| C1, C2, C3 | Ending a leisure activity early has a clear confirmation. Changing clothes waits for the game to confirm the saved outfit. Shopping and changing clothes have action-specific descriptions. |
| C5 | The park bus stop has a location name in resident reports. |

New players appear as Tuantuan in a green apron. The cabin and village share the same character, including the portrait, directional walking animations, and sleeping pose.

## 3. Saves, optional modules, and connected bots

**Your first farm.** The game reads from the current user’s data directory. A new farm starts as open ground with a signpost at the entrance. Place the barn yourself. It starts with one storey, and you can add stairs, floors, and furniture later.

On first launch the installer asks whether the player has an existing save. First-time players get the full release. Returning players select their old game folder, import their progress and choose from nine optional upgrades. Qingxi Village, farm gameplay, shared storage, resident farm care, livestock resupply and village visual effects form one choice. Existing 1.1 settings carry forward.

**Resident tools.** While the local bridge runs, residents can buy food or water, refill troughs, tend tilled fields, and invite you to the arcade. Use `cabin_plan` to view, add, cancel, or revise a plan. It advances on confirmed actions. If a connection drops mid-action and the outcome is unknown, the step is flagged for review to avoid spending money twice. Use `cabin_invite_player` to supply the resident’s own invitation text. `cabin_game_context` exposes stable game rules alongside current state and farm-action confirmations so a bot integration can reuse a stable prompt prefix. The integration handles QQ recipients, who is being addressed in a group, and private-message delivery. Actual model-cache hit rates depend on the integration and provider.

## 4. How the release was checked

- **Asset comparison.** The 1.1 pack contains 1,414 entries and the revised 1.2 pack contains 10,223. Comparing paths and content digests yields 8,811 additions, 89 changes at existing paths and 2 removals. These counts include animation frames, imported textures and scripts.
- **Public-build checks.** The game was launched with isolated data. Checks covered the character roster, every map exit, entering the village in Observer mode, and seven village quick-travel destinations. The barn and cottage checks used a test farm where those buildings had already been placed.
- **Local-bridge checks.** Little Whale walked to the park, took the bus to the farm, read its state, and returned to the park. Further checks covered shopping, drinking, feeding the fish at home, visiting the bathhouse, stopping an action, and lighting permissions. The release ships with an empty data directory.
- **Test coverage.** The fix list also draws on tests performed during development. The final public-build checks did not include raising every pet variety to adulthood, finishing every minigame, or connecting to a live QQ group.


See [the current build update](Release-Update-EN.md) for the appearance settings, farming, sound and editable resources.

## Shared farm storage and resident decisions

Place a shared chest, press E, and choose an item and quantity. Residents can approach it through the local bridge and withdraw seeds for planting. The public bridge exposes editable budgeting guidance and an optional group-turn routing helper. Chat adapters supply their own group events, mentions and quoted authors. Shared storage follows the Qingxi Village selection. Budgeting and group-turn guidance are independent choices.

The planting menu shows all seven crops in a four-column icon grid. Each choice shows the available seed count. Out-of-stock crops are dimmed.

The planting menu shows all seven crops in a four-column icon grid. Each choice shows the available seed count. Out-of-stock crops are dimmed.

Shared storage accepts item IDs, crop seed names, and the common Chinese aliases for cabbage seeds in both directions. The bridge advertises the chest as supported. Takeaway dishes use the live game catalog for their names and can be eaten from the bag with cabin_eat. Livestock care alerts show the animal identifier once.
