# LifeBusinessGame - Project Memory and AI Handoff

Last updated: 2026-10-20 (Asia/Calcutta). Latest build: Demo v0.8 (Indian town, co-op); newer work below is not built yet.
Current status: playable development prototype, not a release-ready demo.
Latest demo usability feature: a compact First Day guide appears below the clock
and points to the next unfinished retail objective. It hides while a tablet or
other menu is open; the full five-goal checklist remains in the tablet Goals tab.
Latest performance feature: Low (Fast) graphics removes optional outdoor visual
effects on lower-end PCs while preserving the road, shop, warehouse, racks, products
and farm. Auto selects it for the NVIDIA GeForce MX110.
Latest shop addition: orderable 3-row x 4-column produce tables with 12 configurable
baskets, tablet purchasing and mixed-product stocking. See Produce Tables below.
Latest feature: playable tomato farming, a Farm tablet tab/seed stall, three farm
expansions, tomato warehouse/shelf/checkout integration, a road-end Coming Next
board and a local suggestion form. See Farming section below for controls and limits.

## Controls, G-Move Furniture, Talk Boxes, Shop Levels (2026-10-20)

- Keys: Tab opens/closes the tablet (E no longer opens it in the physical shop; the
  old non-physical shop keeps E). Right mouse button leaves the PC. A "+" crosshair
  (crosshair.gd) shows while the mouse looks around; the hint sits under it.
- Carrying a box at a rack: E puts 1 item on the shelf, Q takes 1 back into the box
  (business_backend.gd `unshelve_one`, forwarded in co-op).
- G (shop_operations.gd -> rack_furnishing.gd `move_key`): aims with a ray at racks,
  the checkout counter or the PC desk. Move mode: LMB/E place, R/wheel rotate,
  Q packs an empty bought rack into its box, RMB/G/Esc cancel; move_mode_bar.gd shows
  the buttons and a green/red reason line.
- Counter and desk are "fixtures" in rack_store.gd (`fixtures`, FIXTURE_HOME, saved as
  `shop_fixtures`, validated). The counter carries QUEUE_ZONE (in front) and
  CASHIER_ZONE (behind) in its own frame; racks avoid them. shop_operations.gd moves
  the counter/desk nodes with `fixture_transform()` and derives cashier_point,
  queue_position, queue_entry (customers' path to the queue), customer_exit_route and
  CustomerPurchasePoint from the counter. The counter can't move while customers are
  heading to, waiting at or paying at it. At the home spot everything is exactly as
  before (old saves stay valid). `move_fixture` is forwarded in co-op.
- dustbin.gd: green WET / blue DRY twin bins on a stand right of the shop door.
- conversation_box.gd: bottom talk box (portrait initial, name, tag, typed line,
  replies by click or keys 1-4, Esc leaves). staff_dialog.gd (E on Ramesh/Sunil,
  replies include "Open staff page") and customer_chat.gd (E on a shopper in the
  aisles/queue: help or sorry +30 s patience and -10 s felt wait, suggest one more
  shelved product that some add to the basket, ask about prices vs Sharma). Each works
  once per shopper; shoppers stand still while talking (customer.gd `chatting`).
- shop_style.gd (under ShopPresentation): each business level has its own look.
  1 Apna Mart; 2 Apna Super Mart (blue fascia, LED frame, blade sign, ice-cream
  freezer, grey tiles, LED panels, banners); 3 Apna Mega Mart (maroon/gold, stone
  pillars, bunting, AC unit, marble floor, offer screen, CCTV). Only walls, ceiling and
  outside props, so floor rules are unchanged. Tablet upgrade button names the level.
- Shop expansions (PC Supplier menu, Space tab): business_backend.gd `expand_shop()`
  (EXPANSION_COSTS 6,000 and 12,000; `shop_expansion`, `expansion_expenses`, saved and
  validated, part of total_expenses and the money check). Each moves the back wall
  2.25 m onto the cement ExpansionPlot behind the shop (60 -> 74 -> 87 m2) and allows
  2 more racks (rack_store.gd rack_limit 8/10/12; MAX_RACKS 12 is the save cap).
  rack_store.gd floor_rect(expansion) replaces the fixed FLOOR for racks, fixtures
  and the route grid (region now reaches z -12.5). shop_operations.gd
  `_update_room_size` sizes the room from the expansion; `follow_back_wall()` moves
  ShopDecor's BackWallDecor, stretches side paint and skirting, moves the interior
  sign, shows one extra ceiling light per expansion and shrinks the roped plot. A
  hidden GrassMask keeps grass off the whole plot. `expand_shop` is forwarded in co-op.
- One free rack: new games from the menu (game_session.gd new_game ->
  business_backend.gd `start_with_one_rack()`) keep only the cold drink rack;
  `starting_racks` (saved, default 3 for older saves) replaces the fixed "3 starting
  racks" in RackStore.valid (base param), the furnishing expense check, pack_rack and
  the pack buttons. With 1 free rack, shop_operations.gd skips the built-in snack/soap
  racks and rack_furnishing.gd maps only rack 0; bought racks are PurchasedRack nodes.
  Test fixtures (Backend.new()/main.tscn) still start with 3 racks.
- Brick buildings (brick_works.gd, press-kit style): procedural world-mapped brick
  material, steel truss / I-beams, blue roller shutter, pink-framed glass window,
  skylight, hedge planter, hanging bay board. Warehouse (warehouse.gd _brick_details):
  brick walls, dark roof/fascia + orange stripe, office window, 2 shutters, 3 planters
  (with colliders, clear of both bays and doors), 6 skylights, trusses at z 19/25 and
  A1-D4 bay boards above the storage racks. Shop (shop_presentation.gd): brick walls,
  pink window/door frames (old WindowGlass hidden, WindowSill removed), goods shutter
  on the left outer wall, I-beams at z 1.9/-0.4/-4.2/-6.5 (clear of fans and lights).
- Shop matched to the owner's APNA MART reference sheet: FrontWall meshes are an
  ArrayMesh with a real 1.6 x 1.7 m window opening (shop_operations.gd _window_wall;
  the full-size collider stays, so _update_room_size no longer resizes FrontWall),
  clear glass in pink frames, sloped striped awning with valance, pink Parapet*
  roof edge (resized with expansions), dark ceiling (neighbourhood.gd no longer
  recolours RoofTrim in the full shop), wooden checkout counter, AC unit at every
  level, corner CCTV + "Better Choices Everyday!" poster on the left wall,
  BackWallInside (store-room door, clock) and BackWallOutside (back door, vent,
  downpipe, step) moved by follow_back_wall. tools/shop_views.gd renders the six
  reference views (front, interior, top with roof hidden, left, back, floor plan).
- Shop interior matched to the reference: racks are a merged RackFrame (steel
  gondola: slotted posts, back panel, plinth, shelf lips, top cap); the old Upright/
  Shelf meshes are gone but their *Body colliders and the 3 rows of 10 stay. Produce
  table = wooden ProduceStand (3 plank steps, wooden crates, FRESH VEGGIES DAILY
  chalkboard; TableBaseBody collider kept). Fridge header is blue. Counter: wooden
  with CounterFront (planks, kick plate, orange trim, APNA MART logo panel, UPI QR
  stand); CheckoutSign moved under the logo. Level 1 floor is grey tiles (shop_style
  _tiles(1)). Green SASTA / GOOD FOOD posters on the left wall. PC Furniture
  pictures re-rendered (tools/rack_thumbnails.gd).
- Counter orders (2026-10-21, kirana style): in real solo games EVERY town (owner: no self-service)
  customers (customer.gd COUNTER_ORDER_CHANCE, counter_order) walk straight to the
  till and wait in State.ORDERING (appended last). E at the till: hear the list
  (order_lines, max 3 products x 3; shown by order_panel.gd on the right), E: take a
  carry bag (business.use_carry_bag, shop_operations.holding_bag), E at a rack: put
  one listed item in (customer.add_to_bag -> bag_lines, reserved in
  rack_furnishing.available and available_stock), Q: take one out / put an empty
  bag back, E at the till: hand_over_bag -> basket fields filled, all "scanned",
  prepare_payment -> normal payment menu. Partial bags sell what is there. Timeout
  ORDER_PATIENCE 150 s x patience factor; a hired cashier fills untaken orders when
  nobody is at the till. Carry bags: business carry_bags (STARTER_BAGS 20, saved,
  validated <= 20 + packs x 25) and bag_expenses (in the money identity); PC
  Wholesale > Supplies sells packs of 25 for Rs50 (buy_carry_bags). Bag stand with
  count on the counter (BagLayer*, BagStandLabel), CounterBag shown at payment.
  How to Play has a Counter orders page. Off in co-op.
  Polish from the owner's video reference: every rack wears an orange code plate
  (rack_furnishing.gd code_for -> "R1".., product_code finds the rack holding a
  product); OrderScreen on the counter (tilted, faces the cashier) shows each listed
  product's picture, rack code and how many are still needed; order_panel.gd rows
  have the picture + rack code; the bags sit in a white box on the counter; the held
  bag is bigger with an APNA MART / Shukriya print. Screen and list refresh 4x/s.
- Carry bag models (2026-10-21): tools/blender/build_carry_bag.py (headless Blender
  5.2) makes assets/props/carry_bag/carry_bag.glb (empty, open; HeldCarryBag in the
  player's hand) and carry_bag_full.glb (bread, chips, cold drink, dhaniya on top;
  CounterBag and customers' HeldBag), sharing carry_bag_print.png (front APNA MART
  badge + "Shukriya! Phir aana", back "Your daily kirana / Reusable bag", white hem
  with stitching, gussets). Same 0.26 x 0.30 x 0.11 m size as the old box bag, print
  on +z, 480 / 792 faces. make_carry_bag(parent, name, offset, full := true) loads
  them; editable source/carry_bag.blend (.gdignore).
- Shop fixture models (2026-10-21): tools/blender/build_shop_fixtures.py makes
  assets/props/shop/{counter, rack, fridge, carton, bag_box, folded_bag}.glb on one
  atlas shop_fixtures_print.png (wood counter with APNA MART / UPI print, granite
  top, drawers + cupboards on the cashier side, QR card; gondola with pegboard and
  APNA MART end panels; THANDA cooler body with wire shelves and door frames; kraft
  carton with tape, shipping label, handling marks; bag dispenser). All at the old
  sizes and heights, so gameplay nodes did not move. shop_operations._prop(parent,
  name, "shop/<model>", offset) loads them: CheckoutCounter keeps its collider (mesh
  null) + CounterModel; build_stock_rack(..., frame := "rack"|"fridge") adds
  RackFrame; build_fridge keeps only the glass, lit header, sign and light strip in
  code; _crate holds Carton + BoxLabel/SupplierLabel (z 0.405). tools/blender/
  prop_kit.py is the shared Sheet (print atlas) + Builder (box/lathe/UV) for both
  scripts. Next from the 3D list: Indian products, houses, vehicles, home, warehouse.
- First person everywhere (2026-10-21, owner: "FPP all in game"): player.gd keeps
  spring_length 0 and hides the body indoors and out, no wheel zoom, look limit
  +-70 deg, small head bob on camera_pivot (EYE_HEIGHT 0.7); box_carry_visual.gd
  always uses the first-person arms. Tests updated (business_backend, box_carry).
- APNA EXPORT (2026-10-22, international orders): export_store.gd (business.exports,
  saved as "export"): daily offers from 7 cities (one per city), unit price = shop
  price x1.5 (Rs50-200), states offer -> accepted -> packed -> on_pad -> shipped;
  max 2 active. Packed/on_pad units count as supply in the save check; shipping adds
  to sales_revenue/items_sold/money. export_page.gd = PC app "Export" (6th tile,
  taskbar button). export_world.gd (child of the world, made by shop_operations):
  packing room on the shop's left (x -9.72..-6.06, z -4.02..2.56; doorway in the
  shop's left wall z 0.75..1.95 via shop_operations _left_wall_with_door, which also
  splits its collider), prepare-order table (E: carton / seal), outgoing shelf,
  street door + APNA EXPORT fascia; airport south of the warehouse (town edge
  MAX_Z 70): runway z 51-65, terminal (16, 41.5), tower (28.2, 40), export platform
  (7.2, 47.4) with flight board, walkway x 7.2; cargo plane flies at 10/13/16/19 h
  when parcels are on the pad (dotted path shown 1 h before). Carton items are
  reserved via export_world.bag_lines. Props: tools/blender/build_export_props.py ->
  assets/props/export/*.glb. Moved: BackLaneWest x -10.6, sleeping dog, goods
  shutter/poster/CCTV/AC onto the packing room, 3 far trees off the airport.
- Warehouse model (2026-10-22): tools/blender/build_warehouse.py builds APNA STORAGE
  in world coordinates (origin = game origin at floor, placed at y 0.1):
  warehouse_brick.glb (facade + plinth, given Bricks.brick_material), warehouse_cladding
  (ribbed walls + gables, Bricks.cladding_material), warehouse_shell (pitched roof,
  skylights, parapet sign, entrance canopy, office door/window, loading bays, lamps,
  columns, 5 trusses at x -14/-9/-4/1/5) and storage_rack.glb (one MultiMesh
  RackBatch for all 16 racks). warehouse.gd hides the old wall/roof boxes (their
  colliders stay) and keeps doors, lights, floor, labels, planters. Packing room:
  sliding glass street door, pink trim on the shop doorway, supply_shelf.glb,
  stacked parcels; streetlight -8 moved to -12.6, dog to -14.4.
- Cargo terminal inside (2026-10-22): export_terminal.glb has real 0.2 m walls, a
  walk-in door in the west wall (world x 8, z 42.8..45.2, off the walkway) and the
  runway door open (x 10.5..17.5); export_world.gd builds matching wall colliders, 5
  pallet racks (warehouse storage_rack.glb) full of stored parcels as MultiMeshes, a
  second working packing station at TERMINAL_TABLE (11.5, 38) with a supply shelf,
  an OUTBOUND floor bay, lights. _at_table() = shop table or terminal station.
  Shop: the left paint band/stripe and skirting stop at the packing room doorway
  (shop_decor SIDE_DOOR, DoorSkirting); a DoorThreshold floor strip fills the wall gap.
- Licences (2026-10-22): business LICENCES basics (bottle, snack, soap; free),
  dairy (milk, bread; Rs2000), packaged (oil, chocolate, honey; Rs3500), fresh (5
  produce; Rs5000, shop level 2). licences {id: paid} + licence_expenses saved and in
  the money check; a fresh Backend owns all (tests), game_session new games call
  start_with_licences(); old saves get basics + groups they bought. can_order_stock /
  order_cart need the licence; pc_store shows "Needs licence". licence_page.gd = PC
  app "Licences" (7th tile, tiles at 64%). Export offers only use licensed products
  on the shelves (export_prices -> {price, stock}), counts capped by stock; opening
  APNA Export withdraws offers that no longer fit; accepted orders can be cancelled
  (export_cancel). Held carton/parcel smaller, low on the right.
- Bigger town (2026-10-22): town_boundary MIN_X -72, MAX_X 72, MIN_Z -52, MAX_Z 68;
  town_expansion.gd opens FutureTown at build (market street x 50 with 8 shops, 16
  houses, chai stall, autos) and builds Airport Road (z 45.5, x 30..47.25) from the
  market street to the cargo terminal yard, with a footpath, 2 lamps, a car park with
  2 parked cars and green APNA AIRPORT signs (main road x 45.2 z 12.6, turn x 46 z
  40.2). town_life_test expects the open town and the new edge. Licence cards show a
  product name tag on hover (and a tooltip).
- Ground and grass for the bigger town (2026-10-22): environment_details.gd stretches
  the lawn ground mesh and its collider to 150 x 176 m at z 2 (into the hills, the
  Landscape Terrain3D has no collision), grows grass blades over the whole town
  edge rect (mask MASK_WIDTH x MASK_HEIGHT from town_boundary), and town_expansion
  _grass_hills paints the Terrain3D colour map with the lawn colours (sRGB / 0.92).
  South edge MAX_Z 62 (terrain flat to z 60); runway z 51.5..62.5 (RUNWAY_Z 57,
  11 m), plane drawn at 0.85. Departures board: posts behind, title band, centred lines.
- North river (2026-10-27): land_shape.gd now covers z -256..127 (6 Terrain3D regions;
  bake_land.gd adds the 2 north ones and regenerates mipmaps, else far land shows
  white). RIVER_Z -146 meander, WATER_Y -3, road pass at NORTH_ROAD_X 50 to z -230.
  north_river.gd (from town_expansion.gd): North Road boxes + one markings mesh, the
  Blender arch bridge (tools/blender/build_bridge.py -> assets/props/bridge, 40 m,
  deck top = origin at road level) and one water strip. No traffic yet. The giant
  policeman stands on the north meadow (-20, -1, -185), scale 80. The see-through
  edge walls are hidden (town_boundary.gd SHOW_WALLS false); the stop still works.
- Whole land open (2026-10-28): no send-home barrier/countdown any more; town_boundary.gd
  is constants only (TOWN_NAME, town rect for grass, lane, LAND_* end walls built in
  neighbourhood.gd). north_river.gd walls both river banks (RiverBanks, gap at the
  bridge). Hill forest: up to 1300 trees (neem below 7 m, pines higher) in 64 m
  MultiMesh squares with trunk colliders (ForestTrunks). Wild grass: 8 m squares
  within 2 of the player on the terrain (environment_details.gd _wild_chunk). Ground
  texture: tools/bake_terrain_texture.gd (256 px grass detail + normal, depth 0.6).
- North Road open (2026-10-28, lane walls later removed): town_boundary.gd ROAD_MIN_X/MAX_X 40..60 to ROAD_END_Z
  -232 (distance_to_edge = max of town and lane); neighbourhood.gd splits the north
  wall and walls the lane; the Landscape has collision_mode 1 (dynamic, game only);
  north_river.gd adds bridge deck/rail colliders and bank walls. Grass along the lane
  stands on the terrain (environment_details.gd _road_grass).
- Gufa Darwaza dungeon M1 (2026-10-29, plan: ~/.claude/plans/melodic-toasting-hamster.md):
  cave mouth + gate ring in Blender (tools/blender/build_cave_entrance.py ->
  assets/props/dungeon) at land_shape.gd CAVE_X/Z -94/-32 on the west hill, facing +x;
  land_shape levels an apron and cuts the hill under the tunnel (_cave_ground, re-baked).
  dungeon_world.gd (made by shop_operations.gd like export_world; E/hint hooked first):
  FLOORS schedule (E 06-22, C 18-02, A every 7th night 20-04), portal swirl
  (portal.gdshader), enter = fade, hide every visible top-level Node3D, camera far 150,
  day_night.set_underground(profile) (sky/sun/moon off, cave ambient/fog), build the floor
  at UNDER (x 1000); leave = reverse. Shut in co-op. dungeon_test_room.gd is a stand-in
  room until the Blender kit (M2). Shaders: toon.gdshader (3 bands, rim), outline.gdshader
  (inverted hull, next_pass). 120+ FPS inside on Low. Next: M2 Floor 1 kit + layout +
  loot + Darwaza Guild office to sell treasure (guild_income in the money identity).
- Market street (2026-10-28): 8 Blender shop-houses (tools/blender/build_market_shops.py
  -> assets/props/market/market_shop_<i>.glb, names printed on the boards) with body and
  counter colliders and a shopkeeper each (town_expansion.gd _shop). market_life.gd: 6
  walkers on the pavements and 8 vehicles (scooters, autos, cars) on one loop, left-hand
  lanes x 50 -+ 1.2, U-turns at z 1 and z -226 (past the bridge), keep 7 m gaps, stop for
  the player. Parked scooters/auto moved to the road edge. Night shutters fit the fronts.
- Blender trees (2026-10-28, tools/blender/build_trees.py, tree_models.gd): pine_tree
  for HillForest, neem_tree for every town tree (neighbourhood.gd _tree keeps only
  colliders; _plant_trees draws them all as one MultiMesh TownTrees).
- Performance (2026-10-27, measured on the owner MX110): GPU-bound (sky alone ~90 fps).
  4-split sun shadows halved FPS: shadows 1 now ORTHOGONAL, 2 = 2 splits
  (game_settings.gd). draw_distance.gd gives every built mesh a draw distance by size
  and turns off shadows under 1 m (run from environment_details.gd). Owner saved
  settings were Custom with far shadows/full grass (~12-20 fps); Low preset ~43 fps.
- Giant policeman (2026-10-27, giant_police.gd, added by town_expansion.gd): an 89 m
  khaki constable (tools/blender/build_giant_police.py -> assets/props/police body+head
  glb, 430+252 faces, one swatch atlas) at (-20, -10, -152) behind the north hills,
  scale 75 (~140 m, head drawn 1.4x, tilted 0.4 down, seen over the roofs from the main road); the head follows the player (clamped +-0.75 rad), body turns 20%. No shadows.
- Clouds (2026-10-23, environment_details.gd _build_clouds): ~36 clouds spread over the
  whole sky (x/z +-150, 28-48 m, at least 34 m apart), small/medium/big, each one merged
  mesh (5 puff shapes from _cloud_mesh, flat bottoms, grey-blue underside to white top
  by vertex colour, unshaded; day/night tint via albedo_color). They drift east at
  0.3-0.55 m/s and wrap at x +-160. Hidden on Fastest (set_quality).
- Town name (2026-10-23): Dholkarpur Gaon (town_boundary.gd TOWN_NAME): top-centre HUD
  label (game_ui.gd TownLabel), welcome gates over the main road at x +-66
  (town_expansion.gd _welcome_gates: sandstone pillars, saffron domes, maroon board,
  one merged mesh each plus pillar colliders), the edge notice, guide and new-game text.
- Mountains (2026-10-22, baked 2026-10-23): land_shape.gd shape(data) sets the
  Terrain3D heights; tools/bake_land.gd saves them into assets/terrain/neighbourhood
  (re-run it after changing land_shape.gd, then tools/bake_editor_preview.gd), so the
  game does no shaping at load and the editor shows the same hills. town_expansion.gd
  only plants the pines (deferred, heights from data.get_height). Land: flat town rect (-74..74, -56..60), foothills 1.5-9 m from a
  wavy line, then rounded mountains (smooth mass seed 3 + soft ridges seed 7 + bumps
  seed 19, ~55 m max), the road valley pass (_lower_valley) which mountains close
  again past |x| 100 (the road is hidden behind the crest there), colour map by
  height/steepness (lawn, forest green, rock above ~26 m or steep, snow above ~44 m)
  and ~450 pines as one MultiMesh (HillForest, sunk 0.45*size). The last 12 m before
  the land's edge (+-128) slope down behind the outer crest: Terrain3D blends the
  edge towards white, which showed as a white skyline line. day_night.gd: daylight
  fog 0.0016 for haze on the hills; the sky below the horizon (ground_bottom_color)
  is the horizon haze colour, so no green "beam" shows through any gap. Heights are
  kept in land_heights while shaping. The terrain has no collision (town edge stops you).
- Startup check (2026-10-20): the player spawns beside the bed from frame 0; only the
  very first frame (behind the loading screen) shows the home without its walls
  (HomeDecor is added deferred). One replay showed a ~2 m slide toward the door just
  after start that did not repeat; not fixed, owner stopped further testing.
- Farm detailing (farm_details.gd, built by town_fill.gd): tube-well pump room with a
  cement tank and water, scarecrow, two hay stacks, gunny sacks, a charpai and a red
  tractor (vehicle_models.gd tractor), merged into one mesh plus water and tractor.
- Udhaar khata (business_backend.gd): regular town customers sometimes ask for credit
  at the till (customer.gd wants_udhaar, 18%); checkout_menu.gd shows "Write in khata"
  / "No udhaar". give_udhaar moves the amount from the till into `khata` (due in 2
  days); each new day due entries are paid back (70%) or lost after 5 more days
  (khata_news signal -> HUD). Saved: khata, udhaar_given, udhaar_collected; the money
  check subtracts (given - collected). Limit Rs2,000. Bank page shows the khata.
- Cold-drink fridge: display "fridge" (rack_store.gd FRIDGE_PRODUCTS bottle+milk);
  bought cold-drink/milk racks are fridges (RackStore.display_for), built by
  shop_operations.gd build_fridge; Wholesale > Furniture card; a stocked fridge makes
  cold drinks a likelier pick (x2, x4 at 12:00-17:00, customer.gd).
- Rack rules: racks.strict (games with 1 free rack) -> products need their kind of
  rack (fridge / produce table / shelf); the free rack is a fridge; wrong-rack E/hint
  says where it goes (Store.place_hint); Wholesale cards warn "Needs a ...". Older
  saves keep mixed shelves (only fridges are drinks-only).
- Difficulty (game_session.gd new_game(path, difficulty)): Aasaan Rs15,000 / Normal
  Rs10,000 / Mushkil Rs6,000 starting money; patience x1.3/1/0.75; town budgets
  x1.15/1/0.85. New Game always asks (main menu; ConfirmButton is Normal).
- Wall shelves show real stock (shop_decor.gd show_stock): items owned on racks, in
  storage, at the bay and in hand, per product.
- How to Play (how_to_play.gd, "Ui/HowToPlay" in game, also in the main menu): 10
  picture pages (assets/ui/howto/*.jpg rendered by tools/how_to_play_pictures.gd),
  key chips, page dots, Back/Next/Close, arrows/Enter/Esc. Opens from the main menu
  and pause menu buttons, F1 in the game, and once by itself in a player's first new
  game from the menu (user://help.cfg remembers). Counts as a menu (player locked,
  clock paused).
- Detailing (no downloads): vehicle_models.gd builds one-mesh auto-rickshaw, scooter,
  hatchback and cycle-rickshaw; traffic.gd uses them (bus unchanged). town_fill.gd
  parks an auto and a cycle-rickshaw at the West Park and scooters by new houses, and
  adds two roadside hoardings (Apna Mart, Apna Bank). shop_decor.gd: counter details
  (khata, pen, calculator, digital scale, phone) as one mesh on the counter, and the
  wall shelves show real catalog products (baked make_product meshes, batched).
- PC Wholesale has a Furniture category (pc_store.gd): Shelf rack and Produce table
  cards with pictures (assets/ui/products/rack_*.png from tools/rack_thumbnails.gd)
  and an Order button (order_racks; a shelf gets the first product without a restock
  rack). The package arrives at the warehouse and is unpacked there with E.
- KayKit (CC0) packs from the official GitHub repos: assets/furniture/kaykit (Furniture
  Bits) and assets/restaurant/kaykit (Restaurant Bits, meat/burger items removed),
  each with LICENSE.txt, pruned to the models in use (home: couch, armchair, lamp,
  rug, picture, cactus; town_fill.gd: chai stall, crates, porch chairs/tables/plants).
  The full packs are on GitHub (KayKit-Game-Assets). Load with kenney_assets.gd `fit()`.
- town_fill.gd (built by neighbourhood.gd after the lanes): 8 new houses (back row
  x -15/-6/3/12 at z -26.5 and an east colony x 19.5/27.5 at z -18 and -26.5), Back
  Street (z -22.2) with 3 link lanes to the back lane, door steps, 5 glow-only lamps,
  and a West Park (x -30..-19, z -30..-14) with a chai stall (KayKit pot, fridge,
  round tables, chairs), a sabzi stall with KayKit vegetable crates, benches, trees.
  Tree (23,-18) moved to (25.5,-9.5) for the east colony.
- PC: APNA Builders site (builders_page.gd; desktop tile "Builders", taskbar "Build"):
  picture cards for Back Room (6,000) and Grand Hall (12,000) expansions and the
  Super Store (2,500) / Mega Mart (5,000) makeovers; Built/Done badges, Locked until
  the one before. Pictures in assets/ui/pc/ are rendered by tools/pc_builder_pictures.gd
  (run with a window, then `--import`). Desktop tiles are now 80% size to fit five.
- PC open flicker fixed (computer_terminal.gd `_show_full_screen`): the flat screen
  shows at full alpha when the zoom ends and only the dark border fades in (the old
  fade from black flashed once).
- Owner asked (2026-10-20) not to run tests routinely; tests were updated but the last
  changes (Builders site, test edits in pc_desktop/shop_space) were not run.
- Co-op quick chat: E on a friend opens friend_chat.gd (4 set lines); the line shows
  over the sender's head for others (coop_world.gd `_quick_line`).
- Tests: fixture_move_test, conversation_test, shop_expansion_test; shop_presentation_test
  checks the levels; coop_test checks a quick chat line.

## Demo v0.8: Indian Town, Co-op, Graphics Settings (2026-10-19)

- Build: `build/LifeBusinessGame_Demo_v0.8.zip` (44 MB, same layout as v0.7: exe, pck,
  libterrain release DLL, READ ME with a co-op section). Version v0.8 in the lobby and
  the exe (export_presets 0.8.0.0); `editor_preview/*` is excluded from the export.
- Exporting while the Godot editor is open prints "Can't open GDExtension" for
  Terrain3D (the editor locks the debug DLL). The pack is still correct: an export
  from an unlocked project copy produced a byte-identical .pck.
- Lobby background (assets/ui/main_menu_shop_v2.png) recaptured with
  tests/menu_background_capture.gd `-- --polished`, now on High graphics.
- In this release, committed by the owner as 53999fe and earlier: the Indian town
  (indian_house.gd, indian_street.gd), Indian music (tools/make_audio.gd), blade grass
  and the ground shader, block_path.gd paths, the home yard, lamps on Low, the road
  horizon (horizon.gd), the editor preview, graphics presets and day length
  (game_settings.gd, settings_menu.gd), and co-op (coop.gd, coop_world.gd,
  remote_backend.gd, coop_menu.gd; tests/coop_test.gd runs 2 processes).

## Full-Screen PC, APNA OS Desktop, Staff Page, Checkout Click Fix (2026-10-18)

- Checkout payment (checkout_menu.gd): `_refresh()` ran every frame and set the
  Cash/Card/UPI buttons disabled then enabled; Godot cancels a press when a button is
  disabled, so real clicks never fired. Now `disabled = not paying` once per frame.
  checkout_test clicks with press/release on different frames (old code hangs).
- computer_terminal.gd: the SubViewport renders at 1920x1080 with
  `size_2d_override` 960x540 (layout/input still in 960x540). After the 0.3 s camera
  move, `_fit_transform()` puts the camera so the monitor fills the window
  (letterboxed if not 16:9) and a CanvasLayer (layer 2) shows the sharp texture
  exactly over the projected monitor, so `screen_point()` mouse mapping is unchanged.
- Desktop home (`app` = home/store/staff/manager/bank, `show_app()`): app tiles,
  Shelf Stock card (racked products, fewest first), Today card, taskbar with Exit PC.
  Shop PC opens on home; warehouse PC (`open(true)`) opens the manager window.
  The manager window (supplier_menu copy) hides the Staff/People tabs on the PC and
  its X button returns home. Game feedback shows as a toast over the PC.
- staff_page.gd "APNA JOBS": portrait cards (assets/ui/staff/<role>.png made by
  tools/staff_portraits.gd), hire / hire again, cashier L1-L3 chips, manage panel
  (hours -/+ and save, Working/Day off, auto-collect, assign box, talk, overtime).
  Talk opens the staff dialog, which closes the PC. Test: tests/pc_desktop_test.gd.
- loading_screen.gd: Continue/New Game add a root-level CanvasLayer (layer 100,
  PROCESS_MODE_ALWAYS) that shows the threaded scene load as real progress, says
  "Building the town" before the blocking scene change, keeps covering the first
  frames (shader/physics hitches), then pauses the tree with "Press any key to start"
  and fades out with a welcome toast. It holds the loaded PackedScene so launch_game
  reuses it (before, the menu's threaded load was dropped and loaded again).
  main_menu_test goes through it with `_through_loading()`.
- Checkout counter sits 0.3 m lower (top 0.88 m for the 1.45 m characters) and the
  checkout monitor moved to the cashier's side (x 1.0, turned 0.6 rad) so it no longer
  hides the customer; the card terminal moved to the customer side.
- Tablet and PC Shop Manager restyle is drawn on the copy panel's `draw` signal (no
  extra child controls, so the no-overlap layout tests still hold): tablet teal header,
  stat tiles on Overview, white content card; Shop Manager amber header with Back,
  money and Shop online, product picture on Orders, Space tab hidden on the PC.
- Town customers (scene meta `town_customers`, set by launch_game like
  `mixed_baskets`; test scenes keep the old short door route): SHOPPER_TYPES quick
  35% (1 item), regular 40% (1-3 + maybe 1 extra), family 20% (2-4 + 1-2 extra
  products x1-2, no haggling), bulk 5% (5-7 of one product). Budget per item varies by
  type and they pick an affordable in-stock product. They start 22-28 m down the
  shop-side pavement (z 3.9 +-0.3), walk to the door, and after shopping walk out to
  x +-32 (70% carry on, 30% turn back) before being freed. The spawner counts only
  non-leaving customers toward its 3-shopper limit (8 in total). Checkout basket
  shows two rows of five. Test: tests/town_customers_test.gd.
- Orders tab: Sharma's line moves with the order column and was tightened to fit
  640x480 (physical_shop_test passes again); multi-box status is one line.

## Demo v0.7: Beginner Money, Faster Loading (2026-10-18)

- Owner: "demo work only" from now on (polish, fixes, build), no big new systems.
- New Game starts with `BEGINNER_MONEY` Rs10,000 (game_session.new_game). Saves store
  `starting_money`; saves without it are legacy Rs50,000 starts. Validation accepts
  only those two amounts. Backend.new() (tests, direct editor play) still 50,000.
- Loading fix: pc_store.gd and bank_page.gd filled their Kenney Theme AFTER assigning
  it, so every theme change re-themed the page on the first frame (~30 s for the two
  PCs). Build the Theme first, then assign. Continue went ~70 s -> ~30 s headless.
  Still slow (measured with `tools/load_timing.gd`): runtime `load()` of models in
  _ready (home decor ~3-5 s, the PCs' _configure ~1.5 s each, FutureTown houses).
  Owner said to look at the rest later.
- Lobby: version v0.7 and a new What's New list (card grows to fit the text).

## Traffic, Price War, Night Life, Nature Music, Town Edge (2026-10-18)

- `traffic.gd` (Neighbourhood/Traffic): 8 vehicles (autos, scooters, car, city bus)
  on the main road, left-hand traffic (east lane z 5.6, west lane z 8.4). They slow
  and stop for the player, customers and staff in their lane, keep a gap to the
  vehicle ahead, wrap at x +-76, and have AnimatableBody3D colliders. The bus halts
  6 s at the bus stop (x -45) by day; the waiting passenger boards. At night (and on
  Low graphics) half the fleet rests; headlights glow 18:30-06:30.
- `night_life.gd`: market shutters down 21:00-08:00, chai stall open 05:00-23:00,
  porch lamps + light pools on the 16 town houses, 1 in 3 passers-by at night.
  `day_night.gd`: navy night sky, star dome (one MultiMesh), brighter lamp lenses,
  glow-only expansion streetlights (`_streetlight(..., real_light false)` adds a
  ground light pool instead of a SpotLight3D; still 8 real lights).
- Price war: `rival_sale_for_day(day)` is deterministic (about 70% of days from day 3:
  Rs10/20 off one product, never below Rs50); `rival_price_today()` feeds
  `price_index()`. Sale board by Sharma's path, notification when you sell that
  product dearer, customers say "Sharma sells this for RsX!" at the till
  (`customer.say()`), Orders tab shows "Sharma today" with a Match button, and the
  day report names the coming sale. Nothing new is saved.
- Music: `background_music.gd` keeps ONE `BackgroundMusic` player under the tree root
  (process always) so `music_nature.wav` (96 s seamless: pads, flute, kalimba,
  stream, birds) plays continuously from lobby into the game. It uses the "Music"
  bus; Settings has "Master volume" and "Music volume" (`music_volume`, default 0.6).
  Night swaps street ambience for `ambience_night.wav` (crickets). The old raag
  tracks were removed; regenerate all with `tools/make_audio.gd` (~1.5 min).
- Open town = the OLD 64 m map (owner's call): solid walls at x/z +-31.5
  (neighbourhood.gd) and `town_boundary.gd`, a see-through blue barrier on all four
  sides (always faint, brighter within 14 m); within 2 m a "This area opens in a
  future update / Returning home in 3..2..1" countdown, then
  `House/HouseArea.spawn_player()`. Stepping back cancels.
- Next phase: town_expansion.gd builds the market street, 8 shops, 16 houses, chai
  stall and parked vehicles under `Neighbourhood/FutureTown`, hidden with
  PROCESS_MODE_DISABLED (no collisions). `unlock_future_town()` opens it; then move
  the walls/barrier out to x +-74, z -55..59 and widen street_life (x +-70).
  Outside the wall the road, lamps and trees stay visible; traffic drives through.
  The bus stop is inside the town at x -24.
- Tests: `town_life_test` (traffic, bus, edge, night), `economy_world_test` (sale,
  Match, music bus). `tests/menu_background_capture.gd` is a window-only tool that
  rewrites the lobby image; skip it in suite runs.

## End-of-Day Report Screen (2026-10-18)

- Sleeping opens `day_report_screen.gd` (Ui/DayReportScreen): full-screen dim, big
  PROFIT/LOSS banner, Income (revenue, items sold, best seller, missed sales) and
  Expenses breakdown (stock, staff, rent/bills, marketing, upgrades, farm, loan
  interest, total), money now, reputation, loan left, tomorrow's weather forecast,
  a tip, and START DAY N. The tree is paused until Space/Enter or the button.
- `day_report.gd` counters now carry `costs` per category (`COSTS`, `COST_NAMES`);
  saves from before have no start costs, so that first report shows only the total.
- The old 15-second HUD summary card was removed. Preview: `tools/day_report_preview.gd`.

## Bigger Town and Sharma Shop Life (2026-10-18)

- Land grew to x +-74, z -56..60 (`main.tscn.tscn` Ground box 150x120; terrain
  regenerated with `tools/build_landscape.gd -- --rebuild`, flat with hills beyond),
  but the open town is still the old 64 m map; see the section above.
- `town_expansion.gd` (built by `neighbourhood.gd`): main road extended both ways,
  market street at x 50 with 8 Indian shops (Chai Point, Gupta Medical, Mithai House,
  Mobile Repair, Pani Puri, Tailor, Hardware, Bakery), crossing, streetlights, 16
  Kenney houses with colliders and garden paths, chai stall with chaiwala and two
  customers, bus stop with a waiting passenger, parked autos/scooters, 15 trees.
- `rival_shop.gd`: Sharma General Store gets a path and forecourt to the pavement,
  a produce display, Mr. Sharma (name tag) at the door from day 3, and two shoppers
  who walk from the street, go inside for 6 s and walk away (only while shops open).
- `street_life.gd`: 12 passers-by on both pavements (bounce at x +-29).
- Pure scenery: no save/economy change. Tests: `town_life_test`, updated
  `terrain_landscape_test` and `street_assets_test`. Preview: `tools/map_overview.gd`
  (top/angle/west/market/road/rival PNGs in %TEMP%).

## Music, Save Slots, Bank Loan, Weather, Rival Shop (2026-10-18)

- Music/ambience: tools/make_audio.gd composes original WAVs in assets/audio/generated
  (ambience_street: breeze, birds, traffic, horn; rain). .import loop_mode=2.
  world_audio.gd (added by neighbourhood): ambience quieter indoors, rain sound and
  CPUParticles3D rain that follow the camera (350 drops on Low, 900 otherwise).
  The first raag music tracks were replaced by continuous nature music (see above).
- Save slots (main_menu.gd): SlotRow with Slot1..3; slot_path(base, n) = base for 1,
  "<name>_<n>.json" otherwise; last slot remembered in <settings dir>/lobby.cfg;
  returning from a slot-n game recovers base_save_path and slot. Compact lobby
  tightens spacing/buttons and hides the tagline. Test: save_slots_test.
- Bank loan (APNA BANK page, bank_page.gd, PC taskbar "Bank"): Rs20,000, 10 daily
  instalments of Rs2,200 (10% interest) paid in _bill_new_day after bills; missed
  instalments counted (loan_missed_payments, notification). repay_loan() pays the
  rest + 10%. Saved loan_received/loan_principal_repaid/loan_interest_paid/
  loan_missed_payments; interest is in total_expenses; validation adds
  received - repaid back to the money equation and checks interest = 10% of repaid.
- Weather: weather_for_day(day) = seeded RNG (hash(day*2654435761+12345)), 25% rain,
  day 1 sunny, first rain day 4. Rain: customer interval x1.25, beds planted or
  waiting are watered (_rain_waters_farm at day change, planting in rain), darker
  sky/fog in day_night, clock shows "| Rain"/"| Sunny" (ClockLabel now 240 px).
- Rival: "Sharma General Store" from day 3 (store front on the south house at x 25,
  Neighbourhood/RivalStore). rival_traffic_factor = clamp(1 + (price_index-1) +
  (55 - reputation)/200, 0.85, 1.4); price_index compares your prices with catalog
  defaults for stocked products. Notification when your prices are >5% higher.
- Test: economy_world_test (loan, weather, rival, audio/bank wiring). Previews:
  tools/bank_preview.gd, tools/weather_preview.gd.

## Lobby Page and Credits (2026-10-18)

- main_menu.gd is now a game lobby: left-to-right dark gradient over the shop
  background, dark glass LobbyPanel behind the menu column, "LIFE BUSINESS GAME" logo
  in Kenney Future, green tagline, SaveCard label, Kenney buttons Continue (green
  PrimaryButton), New Game (blue InfoButton; green when there is no save), Settings
  (grey), Quit (red DangerButton). Right-side "WHAT'S NEW" card (WHATS_NEW list,
  hidden below 900x560). Bottom credits "Made by Bucketstudy team" (footer/Credits)
  and version "Development Demo | v0.6". Node names used by tests are unchanged.
- tools/lobby_preview.gd captures 1152x648 and 640x480. main_menu_test passes.
- Pause menu and Settings now use UiStyle.glass_box (dark glass) with white labels,
  Kenney-font titles, coloured buttons (Resume green, others blue InfoButton) and a
  panel fitted to its contents. KenneyTheme: CheckButton/CheckBox have no button
  background, Kenney check icons for CheckButton, CheckBox keeps the fallback font;
  InfoButton (blue) is a shared variation. Compact tablet tabs use the fallback font
  (Kenney Future is too wide for 360 px). Checkout scan/pay buttons use the fallback
  font. Full suite 43/43 after these fixes (checkout/staff rerun individually).
  tools/pause_preview.gd captures the pause menu and settings.

## Kenney UI Theme and PC Wholesale Store (2026-10-17)

- kenney_theme.gd: Kenney UI Pack (assets/ui/kenney_pack, owner's local CC0 download)
  9-slice depth buttons (grey normal, blue hover, green pressed/primary), card panels,
  inputs, green selected tabs, Kenney Future Narrow font on buttons/tabs/headings.
  Type variations: PrimaryButton (green), DangerButton (red), HeadingLabel. Applied
  on top of ui_style.gd by menu_skin.apply (tablet/menus) and the PC desktop_theme;
  PC copies use theme_type_variation instead of flat style overrides. Tab font 15.
- Product pictures: tools/product_thumbnails.gd renders the in-game product models
  to assets/ui/products/<id>.png (256 px, transparent). Re-run it after adding SKUs.
- pc_store.gd "APNA WHOLESALE": website-style page drawn over the PC operations
  window (opened by the green "Shop online" header button or the taskbar "Store"
  button; Back/close hide it). Category sidebar (All, Groceries, Fresh produce,
  Household), product cards (picture, price per box, shelf/warehouse stock, Add to
  cart), cart with +/- per line, per-line 10% bulk discount, totals and Place order.
  Backend order_cart({id: boxes}) is all-or-nothing (money + 20-box supply limit);
  order_stock now shares _place_order().
- Dropdowns (PopupMenu) got dark readable text and a teal hover row.
- Tests: pc_store_test (new); tablet_test now checks Kenney textures. Preview tool:
  tools/store_preview.gd, tools/dropdown_preview.gd.

## Mixed Baskets, Bulk Discount, Queue Labels, Farm Worker (2026-10-17)

- Mixed baskets (customer.gd): with scene meta "mixed_baskets" (set by
  game_session.launch_game; fixed test scenes stay single-product), 50% of customers
  add 1-2 other affordable products (extra_lines {product, rack, count, taken}),
  walk to those racks (State.SHOPPING_MORE = 11, appended to the enum), and bring up
  to 5 items. total_items()/basket_products()/taken_lines()/scanned_total() drive
  checkout (extra counter item slots are created as needed), monitor, hint and
  checkout menu. Extras sell at retail; bargaining only for single-product baskets.
  Backend sell_mixed_basket(lines, budget) is all-or-nothing; save validation accepts
  "Basket of N items for RsX"; demo revenue cap per customer raised to 1000.
  rack_furnishing.available()/shop_operations.available_stock() reserve taken extras.
- Bulk supplier discount: order_cost(id, boxes) gives 10% off for 5+ boxes; paid cost
  goes to restocking_expenses and the discount to saved supplier_discounts, which
  validation adds back to rebuild full-price purchase accounting. PC Orders shows it.
- Queue labels: patience labels smaller and staggered by queue position; customers
  get random first names from 5 per personality.
- Farm worker Kiran (farm_worker.gd, spawned by farm_world): hire Rs1500 (Farm tab
  HireFarmerButton), Rs50 per harvest; both recorded in farm.worker_fees (part of
  farm.expenses()). Backend farm_worker_next_bed()/farm_worker_work(): 06:00-20:00,
  harvest first, then water, then plant (selected crop or any crop with seeds);
  harvests go into warehouse storage (Sunil restocks with Auto collect).
  _commit_farm now also rolls back logistics.
- Tests: mixed_basket_test, farm_worker_test (also bulk discount). Previews:
  tools/farm_worker_preview.gd.

## More Farm Crops (2026-10-17)

- farm_store.gd: CROPS tomato/carrot/cabbage/corn/apple with SEED_COSTS 100/80/120/
  100/150 and CROP_NAMES. Selected `crop` plus per-crop crop_seeds/crop_bought/
  crop_harvested dicts (sums must equal the old totals seeds/bought/harvested); each
  plot has optional "crop" (missing = tomato). Older saves restore all counts as
  tomato. expenses() sums per-crop seed costs.
- Backend: buy_seeds(q, crop), set_farm_crop(crop), plant_crop(index, crop),
  harvest_crop uses the plot's crop for the box/inventory. Save validation counts
  farm-grown units per crop (crop_harvested) instead of tomato only.
- Catalog: new SKUs carrot (box 400 / sell 60), cabbage (450/70), corn (400/60),
  apple (600/90); shop_operations PRODUCE_SIZES renders all crops with Kenney produce
  models (shelves, baskets, checkout, beds).
- UI: Farm tab "Crop: X >" button (FarmCropButton) cycles crops (dropdowns do not work
  well inside the 3D tablet); SeedQuantityLabel kept in place but hidden. Bed labels
  "EMPTY | E: PLANT CARROT (n)", "CARROT | 120m remaining", "HARVEST CARROT"; farm_world
  swaps fruit models per bed (_show_crop). Seed sign "FARM CROPS"; notification
  "Crops ready to harvest".
- tests/farm_crops_test.gd (new) and tools/farm_preview.gd.

## Daily Report and Reputation Traffic (2026-10-17)

- day_report.gd: `start` = counters at the start of the current day (items sold,
  revenue, total_expenses, missed sales, reputation, review count, per-SKU sold);
  close() builds `last` (day, items_sold, revenue, expenses, profit, missed, best
  seller, reputation change, reviews) and starts the next day. Closed in
  advance_clock on midnight rollover and in sleep_until_morning when the day changes,
  BEFORE _bill_new_day, so a day's bills land in the following day's report.
  Saved as optional "day_report" {start, last} (validated; numbers int-normalised).
- game_ui: non-blocking "Day N summary" card (DayReport panel, UiStyle card) shown
  for 15 s after sleeping (sleep_area.try_sleep -> ui.show_day_report()).
- Reputation traffic: customer_spawn_interval *= reputation_traffic_factor() =
  1 - (reputation - 50) / 200 (100 -> 0.75x wait, 0 -> 1.25x, 50 unchanged).
  Tablet reputation tooltip shows "Customer visits +N%".
- tests/day_report_test.gd and tools/day_report_preview.gd added.

## Current status (2026-10-17)

COMMITTED as one commit after the full suite passed 38/38 (400 s, headless, only the
editor open). Covers: visual upgrade, mixed racks, modern UI, 5 new products, sounds,
jump, Sunil storage restock, rack packing and the new family home + spawn. Owner wants
ONE commit per finished piece of work and to be asked before any push to GitHub.
The "to do" list below is history except items 4-5 (export templates, next features).

Added at the end of the session:
- Jump: Space (player.gd jump_velocity 6.5, ~1 m); Kenney "jump" one-shot in
  character_visual (jump_shot node) when the body leaves the floor upward.
- Sunil restocks from warehouse storage when "Auto collect" is ON: backend
  storage_restock_slot() picks a stored box whose product has <=3 on shelves and
  fits in free shelf space; worker_retrieve_stored_box(slot) puts it in his hands.
  stock_worker.gd: fetch_from_storage(), fetch_slot, warehouse exit/entry legs.
- Pack rack: PC Racks tab "Pack rack into warehouse" (PackRackButton). Backend
  pack_rack(id): only bought (id>=3), empty racks; later rack ids shift down by one;
  restock flag handed to another rack of that product; package appended to
  logistics.rack_delivered (saved) and can be unpacked again with E.
  rack_furnishing.pack(id) remaps models after the id shift.
- New test tests/storage_restock_test.gd: PASS (jump, storage restock, pack/unpack, reload).

Added 2026-10-17 (owner request): new family home, owned from the start.
- home_decor.gd now builds the whole house: 6.4 x 5.5 m (house-local x +-3.2,
  z 1.9..-3.6; fits inside the garden fences), 3 m walls with colliders, gable roof
  (30 deg slabs, gable prisms, ridge), framed windows, door posts/lintel, porch,
  bedroom partition, raised wood floor (1.5 cm above the ground plane). Kenney
  furniture: double bed, wardrobe, side table+lamp, sofa facing TV cabinet, rug,
  coffee table, bookcase, kitchen fridge/stove/sink, dining table + 2 chairs, plants,
  porch lamp. Old house.tscn walls/roof/windows are hidden with colliders disabled;
  Bed (+SleepArea), InteriorArea, HouseSign and InteriorLight are re-fitted.
- Ownership: backend grant_home() (free). house_area._start_at_home() grants it and
  spawns the player at home_decor.SPAWN (beside the bed, facing the door) on every
  scene start (New Game and Continue). Save validation now accepts an owned home
  with property_expenses 0 (granted) or HOUSE_COST (bought in older saves).
  buy_house() still exists for backend/legacy use; the in-game buy button is disabled.

To do next session, in order:
1. DONE (2026-10-17): mixed_shelves_test updated to the mixed-rack rule ("no shelf
   space" now means every row is physically full; it fills rows with purchase_stock
   and frees one by selling bottles). It passes.
2. Run the FULL suite (38 tests incl. storage_restock_test). checkout_test line 132
   has failed only under heavy CPU load (owner's game + suite at once) and passed on
   a clean rerun; rerun failures individually before changing code.
3. If all pass: single commit of all the work above, then ask owner about push.
4. Owner to install export templates (Editor > Manage Export Templates) -> build .exe.
5. Next feature ideas offered: daily report at sleep, reputation affecting customer
   traffic, more farm crops, name-label overlap fix.

## Visual Upgrade, Mixed Racks and Modern UI (2026-10-16, Claude Code)

- Characters: character_visual.gd keeps its hidden block rig (carry grips, hands,
  tests) and shows an animated Kenney Mini Characters model (CC0, assets/characters/
  kenney). AnimationTree: idle/walk blend, arm-only "holding-both" carry blend,
  "interact-right" one-shot for work/scan. Scale 2.15, model yawed PI. Player=male-d,
  Ramesh=male-a, Sunil=male-e, Anil=male-b; customers/passers-by random (`model` export).
  Walking now uses speed (<12 m/s) instead of per-frame distance, so legs animate
  during frame drops. Carry boxes lowered to 0.72 m; name tags to ~1.85 m; third-person
  block grips hidden (box_carry_visual.gd).
- Shop decor (shop_decor.gd, wall/ceiling/counter only so rack placement is unaffected):
  MultiMesh-batched Food Kit groceries on high wall shelves, ceiling fans, paint band,
  signs, counter sweets, door mat. Shop PC now uses the warehouse-style fitted casing
  so the live screen sits inside the bezel. Home (home_decor.gd): Furniture Kit bed,
  TV, sofa, kitchen, plants with simple colliders; box bed mesh hidden, collider and
  SleepArea unchanged. Street: 10 City Kit Suburban houses replace block buildings
  (colliders kept; windows no longer batched). Helper: kenney_assets.gd.
- Products: bottle cap is a small cylinder on the model's real neck; bottle label is
  a wrap-around band; snack seal strip sits on the real bag top (_asset_box).
- Mixed racks: an EMPTY row now accepts any SKU (rack_store supports/free_space/
  add_stock); occupied rows keep one SKU. Rack headers show contents ("MIXED
  PRODUCTS" / product / "OPEN SHELF - ANY PRODUCT"); empty rows say "Empty row |
  any product". Wrong-rack tests updated to the new rule (box_carry, product_workflow).
- UI: ui_style.gd = modern flat web-dashboard look (white rounded cards, pill tabs,
  teal primary buttons, navy bars). menu_skin.apply now uses it (tablet + menus) and
  computer_terminal uses it for the PC; primary buttons detected by text prefix.
- Main menu loads main.tscn on a background thread from menu open and shows
  "Loading game... %". Load time is dominated by GDScript compilation (~10 s on the
  MX110 with the editor/game running); new assets add ~0.3 s.
- Preview tools (graphical, temp saves): tools/character_preview, shelf_preview,
  home_preview, street_preview, ui_preview, guide_preview, character_lineup.
- Busy-shop probe with animated characters: ~13-14.5 ms median (was 11.4 ms).
- New SKUs (Kenney Food Kit models, no packaging labels): oil (box Rs1000, sell Rs150),
  milk (400/60), bread (350/50), chocolate (300/50), honey (1200/180). Catalog now has
  EXTRA (all non-bottle inventory SKUs) and OPTIONAL (zeroed for old saves); backend
  save validation and rack_store.valid loop over these lists. make_product uses
  GROCERY_SIZES for the new models with a hidden Cap node for scan hooks.
  tools/products_preview.gd stocks all five, verifies save/reload and screenshots.
- Audio: shop_audio.gd loads Kenney CC0 OGGs (assets/audio/kenney): scan=select_002,
  payment=handleCoins, door=bong_001, delivery=impactGeneric_light_002, stock=drop_002,
  click=click_002 (every BaseButton via node_added), plus player footsteps
  (footstep_concrete_000-004 every 0.42 s while moving on floor). Generated tones
  remain only as fallbacks.

## Status Audit, Git and Export Preset (2026-10-15, Claude Code)

- Status: COMPLETE. No gameplay scripts or scenes changed; owner saves untouched.
- Full suite rerun headless: 37/37 tests PASS, zero SCRIPT ERROR/assertion lines.
- Busy-shop probe rerun on the MX110 with the owner's settings (Auto -> Low Fast),
  Godot editor open in background: frame median 11.41 ms, p95 21.59 ms, physics
  1.30 ms, 550 draws; save median 1.34 ms. Previous record (2026-10-14) was
  55.29 ms median / 40.15 ms physics. The busy-shop stutter is largely resolved;
  no further performance work is urgent. Re-measure after large scene additions.
- Git: repo exists with GitHub remote origin (rohann-bhoye/life-business-game),
  branch main. The "no Git repository" note in section 4 is outdated. /demo/
  (Terrain3D sample content, unused by the game) is untracked and git-ignored but
  still on disk. /build/ and *.tmp are ignored. Deleted a stray .uid*.tmp test file.
- Added export_presets.cfg: "Windows Desktop", x86_64, output
  build/windows/LifeBusinessGame.exe, excludes demo/, tests/, tools/ and this file.
  Godot recognises the preset; export is BLOCKED only by missing 4.7.2 export
  templates (Editor > Manage Export Templates > Download and Install).
- Correction: project.godot main scene is res://main_menu.tscn (it loads
  main.tscn.tscn). Catalog now has 4 SKUs (tomato added); section 5/10 tables
  listing three products are historical.
- Next recommendation: install templates, export, then owner plays one full day
  in the exported build and lists bugs; then onboarding polish.

## Farming and Player Roadmap (2026-10-14)

### Low (Fast) Graphics Preset (2026-10-15)

- Low is now labelled "Low (Fast)" in Settings. It is the existing quality value 0,
  so old saved settings and Auto selection remain compatible. Auto picks it for the
  MX110, Intel/integrated/Vega-like adapters and <=4 CPU threads. Balanced and High
  retain the decorative effects.
- Low Fast disables sun shadows, animated grass, moving clouds, the water-flow
  pond, tree rendering/colliders, ambient street pedestrians, fog and night
  street/interior light effects. It also stops the grass/cloud and pedestrian
  processing. The road, buildings, static street furniture, shop, warehouse,
  racks, stock, farm, player, customers and gameplay collision remain present.
  Trees are intentionally non-solid while hidden in Low Fast; they restore with
  their collider layer in Balanced/High.
- game_settings applies quality consistently to EnvironmentDetails, Neighbourhood
  and DayNight. environment_details keeps its basic cached ground material in Low.
  day_night keeps the clock/sun/sky usable but turns fog and costly night lights off
  in Low. This is a runtime visual preference and never changes game progress.
- On the same 1152x648 busy-street probe, Low Fast measured 74.7 FPS, p95 22.2 ms,
  614 draw calls and 728 objects. The immediately preceding Low probe measured
  12.6 FPS, p95 111.8 ms, 803 draws and 917 objects. The probe conditions were
  short and laptop load/temperature can vary, so these are directional measurements,
  not a hardware guarantee. CPU process time remained 37.75 ms in the faster run,
  so occasional stutters may still occur under a busy shop.
- light_graphics_test verifies Fast removes only decorative components and Balanced
  restores them. main_menu, neighbourhood, day_night (explicit Balanced), terrain,
  street assets, ground-box and produce-table tests passed afterward. Visual preview:
  TEMP/light_graphics_preview.png. Logs: TEMP/*-light*.log and
  TEMP/after-light-graphics.*.log.

### First-Day Objective Guide (2026-10-15)

- `game_ui.gd` now displays one lightweight desktop HUD panel: the next action in
  the existing five-goal demo sequence (order, manual stocking, customers, Sunil,
  sales). It uses saved `DemoProgress` state and adds no new save data or runtime
  world objects.
- The guide is deliberately hidden during tablet/overlay interaction and once all
  goals are complete. Players can review exact counters in the tablet's Goals tab.
- `tests/demo_progress_test.gd` passed after the change, covering persistence,
  goal counts, tablet layout and one-time completion behavior.

### Q Release and Saved Ground Boxes

- Q places a carried product box on the nearby surface in front of the player,
  freeing both hands; aimed E picks it up again. This is controlled placement,
  not a physics projectile or deletion. The usual E return-at-delivery-bay remains.
  Q cancels an active furniture placement. Open menus and key-repeat events do
  not trigger release. Added the white Q key to the existing desktop control hint.
- shop_logistics.gd stores optional ground_boxes with product, amount and finite
  world coordinates. Old saves default to an empty list. Ground units count in
  SKU conservation and the existing 20-supply-box limit; warehouse storage remains
  separate. Box positions are normalized to JSON precision before committing.
- business_backend.put_down_box/pick_up_ground_box save transactionally and restore
  logistics, active delivery/queue state and carry counts on failure. Partial boxes
  retain their amount, and another delivery may become active while hands are free.
  Dropped boxes are manually recoverable, not automatically shelved by staff.
- shop_operations renders labelled ground crates with collision, hiding/removing
  collision when collected. Surface, clearance and wall checks avoid placing boxes
  in occupied spaces, unsupported terrain or through walls. Ground crates are
  static, not rolling physical bodies. Ground-box pickup is aimed and within 1.8 m.
- ground_box_test covers Q/E events, partial quantities, saved positions, multiple
  delivery accounting, invalid data, failed-save rollback, menu/echo guards and
  collider lifecycle. Preview: TEMP/ground_box_preview.png; logs TEMP/ground-box.*.log.
  Final graphical ground test and six regressions passed: multi_box, box_carry,
  warehouse, farm, produce_table and business_backend. Final logs are
  TEMP/*-ground-final.*.log. The ground test also verifies through-wall rejection.

### Produce Tables and Configurable Displays

- Farm tablet tab now orders a produce table for Rs1000. Management PC Racks also
  offers it through the tomato furniture choice. Tables follow the existing
  furniture truck -> warehouse package -> E unpack -> placement workflow; R rotates
  and E confirms. Existing move/aisle/actor checks apply. No table auto-appears.
- New produce tables have optional saved display="produce", twelve slots arranged
  in 3 rows x 4 columns, capacity 10 per basket (120 total). rack_store.slot_count
  selects 12 for tables or the existing 3 for shelves. The footprint and approach
  are unchanged, retaining navigation checks. Rs1000 accounting and 8-display limit
  include both types. Moving preserves kind, slots and inventory.
- New purchased shelves and tables start with unassigned slots, not fixed contents.
  Stocking fills matching assigned slots first, then claims empty unassigned slots.
  Any current SKU can occupy a basket or shelf row; occupied slots cannot be
  reassigned. PC Slots selects basket R1 C1..R3 C4 or the usual three shelf rows.
  A basket holds one SKU, but a table can hold different SKUs across baskets.
  Existing occupied/assigned shelves are preserved; change their empty rows in PC
  Slots. Bottle-labelled furniture does not permanently restrict the contents.
- rack_furnishing renders actual slot products, prices and counts, and shared
  customer reservations/stocking/sales work for tables. Small basket items retain
  their scale after the stocking animation. Ordinary shelf labels remain dynamic.
  Old saves without display default to shelves, including earlier tomato shelves;
  no automatic conversion or stock reset occurs.
- produce_table_test passed with graphical table and PC previews, tablet ordering,
  twelve-slot selection, mixed SKUs, capacity rejection, sale, moves, reload,
  malformed data and save rollback. Eight related regressions passed: rack_furnishing,
  mixed_shelves, farm, tablet, business_backend, warehouse, checkout, computer_terminal.
  Rack test now explicitly assigns its unused row before testing wrong-product
  rejection. Logs: TEMP/*-produce*.log. Previews: TEMP/produce_table_preview.png,
  produce_table_pc_preview.png and produce_table_tablet_preview.png.
  Farm summary uses a smaller explicit font to avoid overlapping the seed quantity
  row; the produce table test checks this spacing as well as the new buy action.
- This adds display furniture, not additional crop SKUs. Tomatoes remain the only
  playable produce crop. Apples, carrots, cabbage and corn at the seed stall remain
  decorative until their catalog/farming/economy implementation is added.

### Farm Entrance and Produce Assets

- Replaced the floating farm title with a fixed entrance board at (-24, 2.72,
  -0.65). A 2 m paved approach joins the north roadside pavement to the farm's
  walking strip. The perimeter is fenced, with a 2.4 m opening between gate posts;
  fence rails have collision while the entrance remains clear. Static posts are
  batched. The four free level-1 beds now occupy the entrance-side row (z -3);
  expansion rows extend backwards to z -11. IDs and saved crop progress are
  unchanged; existing crops move with their beds rather than being reset.
- Added five unmodified Kenney Food Kit 2.0 GLB assets under assets/produce/kenney
  with their original CC0 license and colormap. Source: https://kenney.nl/assets/food-kit.
  produce_assets.gd lazily caches scenes/bounds and fits models uniformly. Tomatoes
  replace placeholders in ripe crops, shop shelves, carried items and checkout.
  Apple, carrot, cabbage and corn are decorative seed-stall displays only; they
  are not new playable crops or saleable SKUs. Seed-stall text now has a fixed board.
- Expanded farm_test checks imported meshes, entrance clearance, solid fence
  collision and tomato checkout mesh. Graphical test passed on MX110, including
  farming, saves, storage, sale and tablet actions. Previews: TEMP/farm_preview.png
  and TEMP/farm_produce_preview.png. The earlier 34-test audit predates this visual
  pass; it was not rerun in full. No new performance benchmark was taken.

- farm_store.gd holds 24 stable bed records, level, seed purchase/use and harvest
  counters. Level 1 opens 4 beds; level 2 opens 12 for Rs2000 after shop level 2;
  level 3 opens 24 for Rs5000 after shop level 3. A seed packet costs Rs100 and
  yields one ten-item tomato box. Growth starts after watering and takes 360/300/
  240 in-game minutes at levels 1/2/3. Existing planted beds keep their recorded
  duration when upgrading. Empty hands are required for planting/watering/harvest.
- farm_world.gd builds beds west of home (-28..-20.2, z -11..-3), walking gaps,
  seed stall, seed packets, growth stages and ripe tomato models. Aim at a bed
  and E plants, waters or harvests according to its state. Harvest puts a box in
  the player's hands; stock never silently appears on shop shelves. Ready crops
  generate a nonblocking notification. Work gesture and stock SFX accompany actions.
  Fixed soil/timber geometry is batched to limit extra draw calls on lower-end PCs.
- Farm tab on the held tablet buys 1..10 seeds per action and expands the farm.
  E at the seed stall opens that tab. Tomatoes may also be ordered wholesale.
  Assign an empty shelf slot to tomatoes using PC Slots, or order/place a tomato
  rack; harvest boxes use normal warehouse storage/retrieval/manual stocking.
  Customers browse/scan/pay for tomatoes through the existing checkout pipeline.
- Catalog adds tomato as fourth SKU while retaining the original three initial
  racks and SKU indices. Farm harvest counts separately from wholesale purchasing
  for expense/conservation validation. farm is an optional v10 save field; old
  inventories missing tomatoes acquire a zeroed entry on load. Growth uses saved
  game clock time, including sleep; closing the game does not add offline growth.
- Farm transactions roll back seed counts, beds, money, inventory and carry/queue
  changes on save failure. JSON numeric values are validated and normalized to ints.
- Coming Next board at (29, 1.8, 1.3), near the east road end, opens a scrollable
  planned-feature list with E. Suggestion TextEdit accepts 5..1000 characters, up
  to 100 records, and saves via temporary-file replacement to user://player_suggestions.json.
  It is explicitly local-only, not transmitted. Tests redirect it to TEMP. Menu
  locks movement/look, and Escape or Close dismisses it. Future features are planned,
  not delivered promises or release dates.
- farm_test covers purchase, locks, watering/time, no duplicate harvest, warehouse
  storage, mixed shelf stocking, tomato sale, scan/payment, expansions, reload,
  invalid data, failed-save rollback, legacy defaults, tablet actions and suggestions.
  Graphical farm/roadmap check passed; TEMP/farm_preview.png and roadmap_preview.png.
- The 34-test regression run passed apart from two outdated expectations, which
  were corrected and rerun: last dropdown item now tomatoes; smallest legacy tablet
  uses tighter tab padding/font. customer_reviews runner false-negative was an
  empty-error-log handling bug; its test log contains PASS. Final logs are
  TEMP/*-farm-suite.*.log plus computer_terminal_test/tablet_test-farm-fix.*.log.
  Final audit confirmed 34/34 PASS with no script/parse errors in those logs.
- Only tomatoes are implemented as a farm crop. More crops, irrigation tools,
  weather, farm workers, crop loss/expiry and dedicated farm animations remain planned.
  Demo onboarding and unresolved physics/frame-time optimization are still pending.

Graphics presets added on 2026-10-14: Auto (default), Low, Balanced and High in Settings.
Auto uses the adapter name and CPU thread count as a conservative heuristic. MX/Intel
integrated/Vega or <=4 CPU threads choose Low; GTX chooses Balanced; RTX/RX 6/7/9
choose High. Unknown adapters choose Low. This is not a full VRAM/thermal benchmark.
Low disables expensive sun shadows, reduces grass to 130 blades within 28 m, uses
a cached noise ground texture and fewer clouds. Balanced uses 28 m sun shadows;
High retains 60 m shadows. Preset persists in settings.cfg and applies on startup
and from pause Settings. Game progress is unaffected.
Verified settings persistence, Auto Low startup and immediate Balanced application
with main_menu_test. Corrected Low probe measured 30.8 FPS/p95 84.2 ms and 974 draws
on the MX110 at 1152x648. Draw calls fell from the earlier 2257, but substantial
stuttering remains; repeated-object batching and CPU profiling are still needed.

Performance pass (2026-10-14): scenery_batch.gd combines fixed warehouse rack boxes,
tree canopies and selected street geometry into MultiMeshes grouped by material.
Original named mesh nodes are retained with layers=0; colliders and interaction
targets remain independent. Moving shop racks/products are not batched.
Staff-tab periodic refresh runs at 0.15 seconds only while open, with immediate
business-event updates to prevent stale work/collection controls. Distant character
poses (>25 m) update at 0.12 seconds; navigation/job simulation is unchanged.
Inactive computer screens already use UPDATE_ONCE and required no change.
Final isolated Low MX110 street measurement: 32.4 FPS, p95 68.5 ms, 724 draws/828
objects (previous Low: 30.8 FPS, p95 84.2 ms, 974 draws). Runtime process monitor
reported 59.04 ms and physics 6.52 ms; these engine-wide timings do not isolate
individual GDScript functions or prove a specific CPU bottleneck. Laptop load and
thermal conditions can affect these short measurements. Significant stutter remains.
computer_terminal_test, employee_actions_test and character_visual_test passed.
Visual preview checked: TEMP/performance_low_preset.png. Next: detailed profiler
capture with a busy saved shop and resolution scaling for Low if GPU-bound.
Resolution experiment (2026-10-14): same-run native 16.3 FPS/p95 85.3 ms versus
75% bilinear 16.5 FPS/p95 82.8 ms. No meaningful gain; automatic downscaling was
rejected and removed, preserving native sharpness. Diagnostic --scaling remains
in tools/performance_probe.gd; screenshots TEMP/performance_native.png and
performance_scaled_75.png. Comparison was under variable laptop load; two other
Godot processes remained open. Do not call this an isolated hardware capacity test.
Added --cpu diagnostics: 100 zero-delta samples in a fresh isolated save averaged
Ui 0.104 ms, ShopOperations 0.053 ms, Warehouse 0.012 ms, RackFurnishing 0.002 ms,
EnvironmentDetails 0.028 ms, NotificationFeed 0.009 ms. These microbenchmarks omit
busy-shop NPC physics, save writes, driver wait and rendering; remaining stutter
is not explained by the sampled recurring scripts. Busy-shop/engine profiler and
a standalone run without competing Godot instances remain necessary.
Busy-shop profiling (2026-10-14): tools/busy_shop_probe.gd creates an isolated
temporary save with 3 customers, 3 stocked product shelves, all staff hired and
8 delivery boxes. Native MX110 run: median frame 55.29 ms/p95 82.17 ms, physics
40.15 ms, 503 draws. Script medians: UI 0.701 ms, operations 0.283 ms, warehouse
0.021 ms, notifications 0.097 ms. Save writes measured median 37.70 ms/max 51.31 ms.
Backend now builds/serializes one snapshot, reuses known-valid exact payloads and
skips unchanged saves only when both primary and backup exactly match the cached
successful payload. File content is checked (bounded to 64 KiB), so external edits,
corruption, missing files and changed save paths do not incorrectly skip writes.
Atomic temporary-file replacement and backup recovery behavior are preserved.
Repeated-save probe after change: median 3.32 ms/max 31.94 ms (initial backup write).
This does not eliminate synchronous writes for changed transactions or clock state.
Preview TEMP/busy_shop_profile.png; remaining physics/engine load needs investigation.
business_backend_test (including same-instance external-corruption repair) and
main_menu_test passed after the save optimization. Owner saves were untouched.
Latest game task: mixed-product shelf rows/capacity, warehouse sliding doors,
office lighting/chair orientation, responsive mouse-look and articulated carrying.
The warehouse office has a framed automatic wooden exterior door in the front wall
directly behind the management monitor. The rejected side divider was removed and
the -11.75 aisle restored. The live monitor uses a fitted procedural casing/stand,
without the overlapping imported screen body.
The office door rotates around a true side hinge and swings outward, so its panel
does not remain in the center of the opening.
The door is manual and persistent in its current session state: aim and press E to
open, then E again to close; it never auto-closes. The desk setup is rotated against
the left wall, and the exterior tree was moved away from a new paved office footpath.
Desktop movement now restores captured mouse input when WASD begins, accumulated
mouse input is disabled for direct look response, and a bottom-right white-keycap
WASD/mouse/E HUD appears during gameplay and hides while menus are open.
Environment density pass adds wind-animated roadside grass, clustered swaying trees,
moving low-poly clouds, atmospheric day/night fog, varied asphalt wear/repair patches,
manholes, drains, planters, bins and shrubs. Grass ground uses a procedural world-space
surface shader. GardenWater at (19, 0.15, -9) has animated waves/flow and a raised rim.
Grass placement excludes warehouse, delivery bays and the home approach. Clouds darken
with the game clock. Existing Terrain3D region data and player save data are preserved.
Validated on 2026-10-14: day_night_test, neighbourhood_test and terrain_landscape_test
passed without script errors. Native Compatibility renderer environment preview also
passed; screenshots TEMP/environment_street.png and TEMP/environment_garden.png.
The entire regression suite was not rerun for this scenery pass. Character skeletal
asset replacement and additional playable buildings remain future work.
Current handoff: all 33 regression checks passed (TEMP/*-polish-final.log; UI fixture
rerun replaced its initial parse failure). Mixed shelves and warehouse/carry graphics
passed. Final knee-pose focused checks are recorded in TEMP/*-polish-last.log.
Focused warehouse geometry, terminal routing and graphical office-door checks pass;
latest previews are TEMP/warehouse_office_lit.png and warehouse_office_door.png.
Desktop PC is the current target; owner game saves remain untouched.
Next recommendation: demo onboarding and release QA; player skills remain Phase 2.

## Current Handoff Checklist (2026-10-13)

- Completed recent work: two-hand box carrying and sway; wrong-rack HUD warnings;
  one-item shelf stocking with partial save/return/pickup; shelf placement gesture;
  aimed checkout scans, scanner effects, matching payment choice and receipts;
  customer satisfaction and saved reputation with tablet feedback; queue patience,
  countdowns, impatient warnings and safe reserved-stock return on abandonment;
  mixed multi-box ordering, quantity controls, separate pickup boxes and Sunil batches;
  full-device tablet framing, licensed UI assets and consistent menu skins;
  saved demo objectives, one-time completion results and continued gameplay;
  startup main menu, confirmed archived New Game, Continue, real settings and pause;
  night-only sleep with daytime HUD warning and full-day staff integration checks;
  spaced tablet tabs, two licensed product models, six passers-by and six buildings;
  enabled installed Terrain3D 1.0.2 and added saved surrounding hills/grass;
  textured shop/road/paving, readable fascia, shelf price tags and labelled products.
  Also completed: saved rack placement/movement, persistent Sunil assignments,
  multi-rack furniture orders/separate truck, warehouse storage and retrieval.
  Wider central/side/outer aisles, forecourt product/rack bays and warehouse PC.
- Latest addition: licensed imported desk/monitor/keyboard/mouse/chair assets,
  monitor-rendered operations desktop with camera zoom, wider left warehouse office,
  Anil's separate receiving job, persistent work hours/work switch and carried box.
- Also completed: three mixed-product shelf rows per rack with 10 items per row,
  PC Slots editor, saved assignments/counts, partial-box stocking, per-SKU customer
  reservations, Sunil's shelf-full wait/resume and left-side warning. Warehouse now
  has solid automatic doors, brighter office/entrance lighting and a correctly
  oriented chair. Carrying has bent elbows, unscaled shoulders, animated calves,
  aligned body and warehouse first-person hands. Mouse-look runs before GUI input.
- Current verification: all 33 tests passed in TEMP/*-polish-final.log, including
  mixed_shelves_test and warehouse_polish_test. Final night office/closed door/daytime
  carry screenshots: warehouse_office_lit.png, warehouse_door_closed.png and
  third_person_carry_pose.png in TEMP; graphical log warehouse-polish-graph-final.log.
  Post-knee graphical verification: warehouse-polish-graph-last.log; additional
  walking-pose capture third_person_carry_walk.png. All four post-knee focused
  checks passed (character_visual, box_carry, warehouse_polish, employee_actions).
  Mixed rack/PC captures: mixed_shop_shelves.png, mixed_shelves_pc.png; log
  mixed-shelves-graph.log. Post-knee focused logs: TEMP/*-polish-last.log.
- Last verification: all 31 checks passed (TEMP/*-office-final.log). Final focused
  graphical check: TEMP/office-graph-last.log. Screenshots: office_desktop_1152.png,
  office_desktop_1920.png, office_orders.png and office_asset.png in TEMP. Includes
  real product popup keyboard/mouse input, one-charge ordering, independent Sunil/
  Anil stock ownership, overtime/pay/wage/rehire accounting, rollback and old saves.
  Final post-polish focused checks also passed: warehouse_test, physical_shop_test,
  staff_test and computer_terminal_test (TEMP/*-office-last.log).
  Previous: all 30 checks passed (TEMP/*-forecourt-final.log), with the
  physical pickup fixture updated for the relocated product bay. Final graphical
  test: forecourt-visual-final.log; focused box_carry/worker_assignment checks:
  TEMP/*-forecourt-last.log. Earlier: all 30 headless tests passed (*-warehouse-final.log),
  plus warehouse-focus-final.log and warehouse-graphical-final.log. Previous:
  all 29 headless tests passed (TEMP/*-assignment-final.log).
  worker-assignment-focus-final.log and worker-assignment-graphical.log also passed.
  Previous full rack run: all 28 headless tests passed (TEMP/*-rack-final.log). Focused
  rack follow-up passed with real E/R/Escape events and purchased-rack stocking
  guards. Desktop rack UI inspected at 1152x648; captures also cover 1920x1080.
  Owner saves untouched; all test saves use TEMP.
- User priority: rack purchases now arrive in boxes on a separate truck; a large
  separate warehouse opposite the shop is implemented, without merging shop rooms.
  Owner clarified the computer belongs inside the warehouse and ALL deliveries
  should unload in the warehouse forecourt. Those changes are implemented.
  Saved rack placement/movement remains implemented. Desktop PC only;
  no new portrait/mobile work. Preserve existing responsive code without refactoring
  it away. Player XP/skill purchases remain Phase 2, not part of the terrain pass.
- Pending tasks: onboarding, remaining visual/audio polish and demo release testing.
  Mixed-product shelf slots and capacity limits are implemented. Optional later:
  reputation affecting traffic, daily reports and employee/player skills.
- Immediate next recommendation: a clear new-game demo flow, then end-to-end
  playthrough/performance/export testing. Do not treat historical mixed-shelf
  recommendations below as pending; current handoff takes precedence.
- Resume by reading this file and inspecting actual scripts. Preserve working
  features and node names, explain changed files/nodes, verify the complete task,
  then update this file. Keep historical recommendations below as history; the
  current handoff above takes precedence.
- Owner request "save briend file": saved this shared project memory only.

## Mixed Shelves and Warehouse/Carry Polish (2026-10-13)

- rack_store.gd keeps stable rack IDs/geometry/primary product/restock flags and adds
  slots: three {product,count} rows per rack, capacity 10 each, and legacy_overflow.
  amount remains the total across all SKUs on the rack. Blank product means unassigned
  and requires count 0. Occupied rows cannot be reassigned. Stocking fills matching
  assigned rows first, then assigns unassigned rows when needed. Wrong SKU/full rows
  reject without mutation. remove_stock debits only the requested SKU/rack.
- Migration keeps all old stock. Old rack amounts >30 become 30 visible items and
  legacy_overflow. That surplus is consumed/refills visible rows as customers buy;
  new stocking into that rack is blocked while surplus remains. No new capacity
  upgrade was invented. Valid snapshots enforce per-row capacity, SKU IDs, aggregate
  totals, blank-row counts and full original-product rows when surplus is present.
  New data stays in optional v10 fields; old saves without slots remain supported.
- business_backend.gd assign_shelf_slot saves transactionally. shelve_one/shelve_box
  and legacy purchase_stock now roll back stock, inventory, racks, carry/queue state,
  expenses and demo counters on save failure. shelve_box can stock only the available
  capacity and retain the remaining carton instead of discarding it.
- SupplierMenu adds Slots tab (index 5; prior tab indices unchanged), rack/shelf/SKU
  selectors, capacity and three-row summary. Assignments work through the live PC
  monitor mirror. Rack selectors name mixed racks correctly. Assignment is disabled
  for occupied rows or legacy surplus. User-facing warnings stay nonblocking HUD text.
- RackFurnishing displays the actual SKU model on each row, replaces only changed
  models, shows mixed categories and row prices/counts, and computes availability by
  SKU after customer reservations. Customer browse/take/payment still uses its saved
  selected rack ID and the existing payment/stock guards; basket remains one SKU.
  Rack movement preserves slots/surplus. Existing placement/navigation/colliders remain.
- Sunil prefers the selected restocking rack when it has capacity, otherwise another
  compatible/unassigned row. Partial cartons continue to the next available rack.
  When no space exists he holds the remaining carton, shows Waiting for shelf space,
  and emits a left-side warning. Creating space resumes exactly once. Anil's separate
  warehouse receiving/storage job remains unchanged.
- WarehouseDoor reuses generalized sliding_door.gd with width 4 m/height 3.6 m at
  x=-3,z=14.48. Two solid glass panels slide outward automatically for player, Sunil
  and Anil; actor group door_actors includes the nested warehouse receiver. Frames,
  hold-open timer and existing door SFX are retained. Shop door defaults are unchanged.
- OfficeChair imported model rotated PI to face the monitor. Two emissive ceiling
  fixtures at x=-14,z=18/26 add cool-white, non-shadowed office lights (energy 2.2,
  range 9), plus entrance light. Existing central warehouse lights stay intact.
- player.gd handles captured mouse motion in _input before GUI can swallow it, while
  keeping menu/pause locks, sensitivity/invert settings and camera pitch limits.
- character_visual.gd uses an explicit two-segment elbow pose instead of stretching
  shoulder pivots. Hands remain at the carton sides; torso faces its carried box.
  Legs keep opposite stride phases and now have thigh/calf segments with knee flex;
  carry strides are slightly shorter. Existing Body/Head/Hand/Shoe paths and character
  colliders remain intact. Pose reset restores idle/walk limb transforms after release.
  Player box and Sunil/Anil cartons all set carry_target. box_carry_visual.gd uses the
  articulated pose in TPP and camera-relative hands in shop/home/warehouse FPP;
  warehouse was previously missing from that FPP condition. Existing sway/placing
  arc/grips remain, original player hands hidden only to avoid duplicate grip meshes.
- tests/mixed_shelves_test.gd covers three SKUs on one rack, capacity/full guards,
  partial boxes, reservations, render models/tags, manual warnings, Sunil wait/resume,
  PC assignment, legacy 100-item migration and failed-save rollback. Existing debt
  fixtures in business_backend_test/shop_upgrade_test/ui_visual_test now purchase
  cartons into warehouse storage instead of expecting unlimited shop shelf capacity.
  Unwritable instant-purchase fixture now asserts rollback, not an unsaved purchase.
- tests/warehouse_polish_test.gd covers solid closed/open doors, employee sensor,
  chair direction, lights, mouse-look/menu lock, shoulder scale, wrist contact, bent
  elbows/knees, warehouse FPP hands and pose reset. All 33 headless regressions passed;
  graphical mixed rack and office/door/carry tests passed. Owner saves untouched.
- Next: demo onboarding/release QA. More product SKUs, mixed-SKU baskets, skill trees,
  shelf-capacity upgrades and animated/skeletal asset replacements remain later work.

## Imported PCs and Warehouse Receiver (2026-10-13)

- Owner wanted actual PC assets, more left-side workspace, separate warehouse jobs,
  and a Windows-like interface on the physical monitor instead of a floating menu.
- Imported unmodified Kenney Furniture Kit computerScreen/computerKeyboard/
  computerMouse/desk/chairDesk GLBs to assets/office/kenney. CC0 License.txt and
  README.md preserve attribution/source: https://kenney.nl/assets/furniture-kit.
  office_assets.gd uniformly fits imported bounds using existing product asset helper.
  Shop management PC and warehouse ordering PC use imported models. Checkout POS
  remains independent. No plugin installation or unrelated character changes.
- Warehouse left wall now x=-16.5 (was -12.4), right=6.4; width=22.9 m, front/back
  z=14.5/30.5 and height=5.2 unchanged. Roof/floor/area/forecourt/front fascia expand
  together. Rack positions/IDs/256 slots and delivery bays are unchanged, preserving
  stored stock. SouthBuilding1 moved to x=-24,z=26 to clear the expanded office.
  PC desk at (-14.2,0.1,17.2), chair behind it; Anil idle (-12.4,0.1,19) stands
  aside from the desk approach. Desk has a matching collision footprint.
- computer_terminal.gd is shared by both management PCs. A 960x540 SubViewport
  renders a light operations window and taskbar onto the monitor's live QuadMesh.
  E at a PC smoothly switches to a focus camera in 0.3 seconds; mouse rays map to
  viewport coordinates. Source SupplierMenu stays invisible (alpha 0), noninteractive
  and authoritative for all existing actions, prices, order quantities and saves.
  Controls mirror source signals without duplicating transactions. Product/rack
  option items resync dynamically. Embedded popup mouse input and explicit popup
  keyboard focus/selection keep dropdowns on the monitor. E/Escape/close restore
  player camera, terrain camera, mouse/focus settings and source alpha. Popup menus
  are hidden on exit; mirror references are cleared on scene teardown.
- SupplierMenu adds Warehouse receiver role, Anil status, hire button, receiving
  switch and role-specific work-hour settings. Taskbar warehouse-staff action opens
  that role. People tab and existing StaffDialog support warehouse mood, overtime,
  pay and quitting. Shop tablet's existing two-role employee controls remain intact.
- employee_relations.gd now has cashier/stock/warehouse records; missing warehouse
  records in old saves default to fresh unhired state. business_backend.gd persists
  optional warehouse hired/hire-day/shift fields in v10, bills INR200/day and charges
  INR1000 hiring. Ledger validation includes current/retired hires, wage days and
  overtime. Failed warehouse hiring/pickup/storage saves roll back without lost money
  or boxes. Legacy saves remain compatible; no owner save was reset or modified.
- warehouse_receiver.gd is Anil's physical bay-to-storage job. warehouse.gd uses
  AStarGrid2D routes around desk/rack footprints and service aisles; outdoor waypoints
  go through the forecourt entrance, avoiding loaded bays. Anil carries each carton
  to a reserved free warehouse slot, never auto-fills the shop shelves. Sunil still
  handles shop restocking. Anil can collect queued cartons but cannot take the primary
  carton assigned to Sunil. Player, Sunil and Anil use separate carry ownership.
- ShopLogistics saves warehouse_carry {product,amount,slot}; its reserved slot is
  excluded from other placements and validates against storage duplicates/capacity.
  Continue restores receiving switch, hours and in-flight carton; work-off pauses,
  resume completes exactly once. Full storage leaves deliveries outside. When paused
  or home/quit, a recoverable parked carton appears by the office; E retrieves it
  through transactional retrieve_receiver_box(), subject to existing carry/bay limits.
- tests/computer_terminal_test.gd covers real receiving routes for all 16 racks,
  multiple cartons, independent jobs, reserved slots, work pause/Continue, live
  monitor clicks/popups, camera restore, imported render/pixel checks at 1152x648 and
  1920x1080, failed save rollback, overtime/day wages/quit/rehire and legacy saves.
  tests/warehouse_test.gd wall/PC fixtures now use expanded shell and relocated desk.
  Full 31-test pass logs: TEMP/*-office-final.log; final graphics: office-graph-last.log.
  Existing Terrain3D physics interpolation deprecation remains upstream. Editor-only
  import can report a locked Terrain3D DLL/owner settings permission; runtime tests
  loaded correctly and all office assets imported. Do not alter owner's editor settings.
- Next planned feature remains mixed-product shelf slots/capacity, followed by demo
  onboarding and release QA. Warehouse receiver currently moves delivered product
  cartons into storage only, not furniture installation or warehouse-to-shop hauling.

## Warehouse Space, Computer and Forecourt (2026-10-13)

- Owner screenshot showed cramped walking space. Warehouse shell now x=-12.4..6.4,
  front z=14.5, back z=30.5: 18.8 x 16 m, 5.2 m height. Front set back 2.5 m,
  creating a 3.1 m deep forecourt behind the existing south pavement. Shop remains
  a separate building across the road; no merge or shop room-size change.
- Storage rack columns x=-9.8,-5.8,-0.2,3.8; rows z=16.5,20.5,24.5,28.5.
  Shelves 2.6 m wide, uprights at +/-1.3. Approximately 2.9 m central aisle,
  1.3 m side aisles, outer wall walking lanes, and 2.9 m cross aisles. Marked central
  walkway edges; room and racks remain within existing world bounds. Stable rack
  and slot IDs preserve all stored boxes; still 16 racks and 256 box slots.
- SouthBuilding1 moved to x=-17,z=26 to clear the wider shell; all six named
  background building/collider objects retained. Earlier SouthBuilding2/3 changes
  remain. Existing shop/home, road, terrain and pedestrian routes preserved.
- Added physical WarehouseDesk/WarehousePC near the front-left rack, with screen,
  stand, keyboard and ORDERS label. Monitor faces the aisle. Aim and E opens the
  existing SupplierMenu with WAREHOUSE ORDERS title and Orders tab. E closes without
  reopening; Escape retains existing close behavior. PC reachable without blocking
  the first rack's service point or wall-side walking lane.
- SupplierMenu has a desktop company sidebar on Orders/Racks: Apna Wholesale for
  products; Rackworks Furniture for racks. Clicking a company switches the real tab
  and matching order controls. Product choice and multi-box/rack quantities retain
  original purchase/accounting actions. This is category-based supplier selection,
  not a new pricing/discount system. Desktop order panel width 720, left column 176;
  other tabs keep 440. Existing compact behavior preserved, no new mobile feature work.
- Yellow outline/stencilled delivery bays on the forecourt: ProductBay rectangle
  x=-11.3..-7.5,z=11.5..14.35; RackBay x=-0.8..3.8,same z. Entrance/walkway remains
  clear between bays. Bay names face the road and sit outside the box footprint,
  so a full delivery cannot cover them. Marks have no collision bodies.
- ALL product deliveries moved from the shop-side point to product drop
  (-10.8,0.1,11.85). 20 cartons fit a 5-column x 4-row grid, 0.7 m spacing; scaled
  to 0.75, with positions derived by product_delivery_point(slot). Furniture packages
  occupy a separate 3-column/two-row arrangement at x=0.1/1.4/2.7,z=12.1/13.4.
  Shipments/quantities still saved in original manifests; no migration stock loss.
- Product van uses south lane z=8.6, stops x=-9.4; furniture truck stops x=1.4.
  Shared unloading-lane dispatch queues the two trucks rather than overlapping
  visible vehicles. Incoming orders remain pending/saved while the other truck is
  unloading/leaving; idle process resumes dispatch. No new second-charge behavior.
- Sunil's collection/return routes include crossing points (4,0.1,3.9) and
  (4,0.1,10.7). Outside restart/cancel cases choose the correct side of the crossing.
  Physics travel consumes remaining distance across route waypoints in a frame,
  avoiding artificial stalls on the interior 0.25 m AStar nodes. Shift/work-off,
  carried-box restoration, restock destination and assignment persistence retained.
- Cartons now have white ShippingLabel panels, green stripe, readable item quantity
  and SupplierLabel (APNA WHOLESALE or RACKWORKS). Outside cartons face the road;
  stored box labels retain their warehouse orientation. Existing BoxLabel names,
  tape/carry behavior, target centres and inventory logic unchanged.
- Notifications identify the warehouse product bay rather than the former shop
  delivery spot. Orders status, purchase quantities and storage counts still live.
- Expanded warehouse test checks 0.9 m walking-body clearance through central,
  side, outer and cross aisles, 20-carton bay bounds, PC aim/open/close, company
  switching, simultaneous product/rack dispatch queuing, labels and ground-text
  orientation. Physical-shop fixture now uses operations.drop_point instead of old
  hard-coded pickup location. Worker assignment test checks crossing waypoints.
- All 30 forecourt regression logs pass; the physical test was rerun after its
  location fixture fix. Final focused box carrying and worker assignment passed.
  Graphical forecourt-visual-final.log passed at 1152x648/1920x1080. TEMP warehouse
  front, inside, products, stock and orders images inspected; upside-down stencil
  caught and corrected. No owner save data modified. Prototype still not release-ready.

## Bulk Rack Delivery and Warehouse (2026-10-13)

Historical first warehouse pass: footprint, computer, delivery positions and routes
are superseded by Warehouse Space, Computer and Forecourt above; storage ledger remains.

- Management PC > Racks now orders 1-5 shop racks per batch, with product choice,
  a numeric quantity field, total cost and transit/delivered counts. Total placed
  plus unplaced shop racks still limited to 8. INR 1,000 per rack paid at ORDER time,
  not placement. Cannot overorder by ignoring incoming/delivered packages.
- New shop_logistics.gd RefCounted stores rack_incoming, rack_delivered and storage.
  business_backend.gd version 10 gains optional logistics dictionary; old saves
  default to empty logistics and preserve existing rack_layout. Furniture expenses
  now equal all paid placed AND unplaced rack units. Unpacking never charges again.
- New warehouse.gd root Warehouse after RackFurnishing in actual main.tscn.tscn.
  Separate blue/yellow FurnitureTruck drives on the opposite lane (z=8.6), unloads
  packages and leaves. Product DeliveryVan is unchanged. Restarting an incoming
  order rebuilds its truck; delivered packages rebuild without duplicate unloading.
- Packages unload on the warehouse forecourt (z=11.5), five positions around the
  clear entrance; not on product delivery/drop points or active shop queues. Aim
  at a package and E to unpack into placement mode, walk to the shop, R rotates,
  E/Enter confirms, Escape cancels. Package remains until valid saved placement.
  Move/rotate and Restock here controls remain unchanged. Internal direct-place
  backend API remains for legacy tests; runtime purchases use delivered packages.
- Warehouse StorageBuilding occupies x=-11..5, z=12..30, opposite shop across the
  road. Separate 16x18 m building, 5.2 m walls/roof, 4 m loading entrance, floor
  texture from existing atlas, signs, clear aisles and three shadowless fill lamps.
  Does NOT extend or merge the 60 m2 shop floor. Demo warehouse is available by
  default with included fixtures; ownership/rent/warehouse hiring not implemented.
- 16 large storage fixtures in 4 rows x 4 columns (A1..D4), each with 4 shelves
  and 4 box slots per shelf. Total capacity 256 PRODUCT BOXES. Slots are saved
  IDs 0..255; original product quantities and partial boxes (1..10 items) preserved.
  Only occupied boxes create product crate models. Slot labels show rack count / 16.
- Carry a product box to a storage rack and E to put it in the first free slot;
  full rack gives a nonblocking warning. Aim at a stored box and E to retrieve.
  Retrieval requires empty hands and an available delivery-area handling slot.
  It preserves existing outside boxes by queuing the active one; never overwrites.
  Stored boxes are NOT on shop shelves and are NOT automatically stocked. Warehouse
  storage/retrieval is currently manual; Sunil's existing delivery work remains intact.
- Storage product amounts participate in purchased/sold/shelf/supply accounting,
  but warehouse boxes do not consume the 20-box outside/in-transit order limit.
  Unique finite slots, products, amount bounds and rack manifests validated before
  saves. Logistics operations roll back on save failure. Restoring normalizes IDs
  and quantities; no paid inventory discarded. Invalid/corrupt saves still protected.
- Player warehouse_indoors separately controls first-person camera/body hiding;
  upper look limit increases to 55 degrees inside warehouse for high box pickup.
  Shop/home camera flags unchanged. Aimed box pickups check distance/alignment and
  physics visibility, rejecting selection through walls/shelves.
- StockWorker assignment now also handles starting outside the shop. Manual pickup
  can cancel collection while Sunil is on the forecourt; a later assignment uses
  the outside drop-point route instead of failing an interior AStar grid lookup.
  Worker assignment regression covers this cancellation/reassignment case.
- Two overlapping south-side background buildings moved to x=15/25,z=26; all six
  named building/collider objects retained. One tree shifted to x=-13,z=12. Shop,
  home, road, terrain, customer queues and boundaries preserved and regression-tested.
- Orders tab shows Warehouse units separately from Shelf stock. Notification feed
  points low-stock items to stored warehouse supplies and reports incoming/delivered
  furniture packages, with persistent notices after Continue.
- tests/warehouse_test.gd covers bulk multi-product rack orders, separate physical
  truck/unload, boxed placement/cancellation/no second charge, 16 physical racks,
  all slot limits, partial product boxes, actual E pickup, area/camera flag, saved
  manifests/storage, money/product accounting, full racks, corruption, rollback,
  warehouse notifications and entrance/wall collision. Existing rack test updated
  for the new order-then-unpack flow; cancellation still preserves the paid package.
- Full 30-test headless suite passed; expanded focused warehouse test and graphical
  Windows test passed. TEMP/warehouse_front_1152.png and _1920.png, inside, stock,
  orders captures inspected; no owner save data touched. Final focused notification,
  UI and backend checks passed after notice changes. Final worker_assignment,
  warehouse and rack_furnishing focused rechecks passed after the outside-route fix
  (TEMP/*-warehouse-last.log).
- Next approved foundation remains mixed-product SHOP shelf slots/capacity limits.
  Warehouse finite box slots are complete, but mixed shop shelves remain unimplemented.
  Preserve old unlimited shop rack quantities when designing that migration.

## Worker Assignment Continue Fix (2026-10-13)

- Manual Assign delivered box previously kept only StockWorker.route/collecting in
  memory. Employment, work_enabled and assistant_auto_collect already persisted,
  but a manually assigned job before pickup disappeared on Continue.
- business_backend.gd now saves optional boolean stock_collection_assigned in
  version 10; old saves default false. assign_stock_collection saves accepted jobs
  immediately, with rollback on save failure. Successful worker/player pickup clears
  the pending collection atomically. Player pickup also cancels the obsolete route.
- stock_worker.gd reconstructs assigned collection routes after Continue when on
  shift and work enabled, without enabling automatic collection. Paused jobs remain
  pending. Carry-stage restoration derives destination directly from backend rack
  records, avoiding initialization order where RackFurnishing was not ready yet.
- Employee home/pay transitions return unfinished carried stock with a pending job
  for a later eligible shift; quitting clears the assignment. Management PC identifies
  pending collection as assigned/paused instead of claiming it awaits assignment.
- Existing saves cannot recover a route that was never serialized. Owner should
  assign Sunil once after this update; future Continue preserves that assignment.
  Position is not serialized: restarted jobs route from the worker's spawn/work spot.
- tests/worker_assignment_test.gd uses temporary saves and real scene reloads before
  pickup and during carrying; checks work-off/on pause, moved-rack destination, exactly
  one fulfillment, manual pickup cancellation, legacy missing field and bad types.
  Final full 29-test regression run passed (TEMP/*-assignment-final.log), plus focused
  shift-start/bad-type recheck and Windows graphical assignment test. Owner saves
  were not modified.

## Latest Rack Furnishing Pass (2026-10-13)

Historical first pass: runtime buying/payment now superseded by the bulk boxed rack
delivery flow above; placement, saved counts and restock destinations remain in use.

- Management PC now has a fifth Racks tab (existing tab indices unchanged).
  Select a product, Buy and place rack, or select an existing rack to Move / rotate.
  Cost INR 1,000, charged only after valid placement and successful save. Moving
  costs nothing. R rotates 90 degrees, E/Enter confirms, Escape cancels without
  opening pause. Movement/mouselook stay active; original rack remains until commit.
- New rack_furnishing.gd, root RackFurnishing after ShopPresentation in the actual
  main.tscn.tscn. Transparent green/red native rack preview with no collisions.
  Rejects walls/outside, furniture overlap, protected door/queue/working aisles,
  unreachable service points, actors and their active route waypoints. Busy racks
  cannot move while customers browse that product or Sunil is walking a job.
- New rack_store.gd uses native AStarGrid2D for interior paths. Fixed default rack
  IDs 0 bottle / 1 snack / 2 soap remain compatible with existing scene paths.
  Purchased rack IDs append, maximum 8 total (valid floor space also required).
  Single product type per rack in this pass; mixed-product slots are NOT implemented.
- Business version 10 gains optional rack_layout and furnishing_expenses. Older
  saves without these fields derive default rack counts from the product ledger.
  Reload normalizes JSON IDs/turn/amount to integers and positions to floats.
  Layout/type/count/restock destination checks and furnishing expense accounting
  prevent invalid saves. Failed placement saves roll back both layout and payment.
- Stock belongs to a saved rack: manual shelving chooses the nearby matching rack;
  customers reserve and purchase from their selected rack; refused/abandoned baskets
  release only that rack's display reservation. Global product totals still match
  summed rack amounts. Purchase/move never destroys stock or changes its product.
- Restock here chooses one destination per product. Sunil targets that rack and
  follows interior paths through the entry, stocks it, then returns to his idle spot.
  New purchases become the destination for their product. Manual stocking remains
  possible at any matching rack. Wrong-product rack attempts use existing HUD warnings.
- shop_operations.gd shares build_stock_rack for original and purchased fixtures;
  shop_presentation.gd shares category/price decoration. Existing node names, product
  models, collision geometry, cashier/checkout, tablet and settings remain intact.
- tests/rack_furnishing_test.gd covers invalid placement/no charge, buying, free
  moves, selected-rack sales, JSON roundtrip, legacy optional fields, invalid records,
  save-failure rollback, UI buttons, real E/R/Escape, manual wrong-rack warnings,
  customer reservations/paths and physical Sunil stocking. Desktop captures in TEMP:
  racks_1152.png, racks_1920.png, racks_menu_1152.png, racks_menu_1920.png,
  racks_preview.png. Full 28-test headless suite passed; focus and graphical rechecks.
- Next: explicit shelf slot assignments for multiple products and capacity limits.
  This pass intentionally preserves legacy unlimited rack quantities, displaying
  up to the existing 30 item models. Do not claim mixed shelves/capacity complete.
  Decide a migration policy for old saves whose stock exceeds future slot capacity;
  never silently discard paid stock. Player XP/skills remain Phase 2.

## Latest Streetlamp Direction Fix (2026-10-13)

- Owner screenshot showed both road-side lamp rows pointing in the same direction.
  neighbourhood.gd _streetlight now accepts facing=0.0; the z=10.7 south row is
  created with PI rotation, while z=3.3 north row keeps zero. Rotates the complete
  arm/housing/lens/light assembly. Pole positions and symmetric pole colliders,
  eight-lamp count, light settings, day/night timing and gameplay remain unchanged.
- tests/day_night_test.gd now verifies four lamps per side, housing/lens/light
  positions closer to road centre z=7 on both rows, and spotlights pointing down.
  Existing night on/off, emissive materials, save reload, billing and sleep remain
  covered. Headless day_night/neighbourhood and graphical day_night tests passed.
  TEMP/life_business_daynight_night.png inspected. No owner save data changed.
- Stop current run and F5 to rebuild runtime lamps. Rack buying/placement/movement
  remains the next approved gameplay task; mixed shelf capacity follows.

## Latest Shop Art Pass (2026-10-13)

- Owner asked why graphics looked low and approved polishing one shop scene first.
  This is a first environment/art pass, not a finished town or character replacement.
  Compatibility renderer, gameplay routes, economics, stock/checkout, UI controls,
  collisions and owner saves remain unchanged.
- Added shop_presentation.gd as main.tscn.tscn root ShopPresentation. It runs after
  the room/neighbourhood are built; disabled physical-shop fixtures skip shop decor.
  Uses shared world-space atlas materials for wall plaster, tiled floor, asphalt,
  sidewalks and home path. New decorative pieces do not add collision bodies.
- assets/materials/shop_surfaces.png generated with the built-in image-generation
  tool, copied into project; original left in Codex generated_images. Four quadrants:
  plaster, ceramic floor, asphalt, paving. Full prompt/source/mode saved in
  assets/materials/README.md. shop_surface.gdshader samples the atlas directly, one
  sample per fragment; no edits/crops to the bitmap. Asphalt detail reduced to 0.3
  for restrained aggregate contrast. Textures are actual project runtime assets.
- Road BoxMesh previously had custom_aabb with nonzero position but zero size,
  causing the road to cull/disappear in rendered views despite passing size-only
  checks. Removed that invalid override. Road mesh position/size/collision unchanged.
  New test asserts a fully empty default AABB and rendered neutral asphalt pixels.
- Store fascia has working art name APNA MART, categories, hours and payment window
  decals; original ShopSign remains a level badge and still updates SHOP/II/III.
  Added window/entrance trim, wall skirting, two emissive ceiling fixtures with
  cheap shadowless fill lights and adjusted existing ShopLight colour/energy.
  No global sun, time-of-day or environment logic was replaced.
- Shelves have category boards, white price rails and live INR price cards driven
  by business.changed. Original stock count labels remain, resized/repositioned.
  product_assets.gd decorates imported bottle/snack wrappers with physical sleeves
  and PackageLabel; soap also labelled via shop_operations.gd. Cap scan feedback,
  identifiers and inventory remain intact. New checkout products inherit labels.
- Enlarged storefront text after rendered inspection and corrected inward wall-sign
  rotation (initial version was mirrored). All package/shelf signs are world objects,
  not new screen overlays or unsupported menu actions.
- Added tests/shop_presentation_test.gd: material paths, store signs, three live
  prices, all product labels/Cap, real snack/soap stocking, original ground and no
  decor economy mutation. Graphical mode checks image contrast and a road pixel
  patch, captures TEMP/shop_polish_front_day.png, interior_day.png, products.png,
  road.png and front_night.png at 1600x900. Final graphical test passed and inspected.
- Refreshed lobby to assets/ui/main_menu_shop_v2.png with real scene capture.
  Old main_menu_shop.png preserved. main_menu.gd points to v2; background capture
  helper supports -- --polished for sibling output. Actual lobby save/settings test
  rechecked after import; owner saves never used.
- Full 27 headless regressions passed. Final focused checks and graphical shader/
  road/day/night checks passed after small final adjustments. Native Terrain3D's
  deprecation warning and sandbox editor-settings write warning remain environmental/
  upstream, not new application errors. No FPS/export performance guarantee claimed.
- Next approved gameplay task remains rack purchase/place/move and mixed shelves.
  Character model replacement, wider town art and demo export QA remain pending.
  Player XP/skill purchases are Phase 2; desktop-only target unchanged.

## Latest Terrain3D Task (2026-10-13)

- Owner installed addons/terrain_3d themselves. Checked plugin.cfg: version 1.0.2;
  terrain.gdextension minimum Godot 4.4, Windows debug/release DLLs present. Native
  classes loaded and worked in Godot 4.7.2 Compatibility. No addon files changed.
- project.godot enables res://addons/terrain_3d/plugin.cfg. Renderer, physics engine
  and startup menu remain unchanged. Native addon APIs were checked against the
  official Terrain3D 1.0.2 docs; installation docs support later versions provisionally,
  so the actual project was tested rather than assuming compatibility.
- Added neighbourhood_landscape.tscn as root Landscape instance in main.tscn.tscn.
  Four saved 128m regions span x/z -128..127. Central gameplay remains flat at
  terrain height 0.08m below the existing 0.1m ground; hills blend in past 38m.
  Existing boundaries remain at +/-31.5m: surrounding hills are scenery only.
- Terrain collision disabled; mesh size 16, five LODs, no cast shadows. Existing
  Ground/road/shop/house collision and customer/delivery paths are unchanged.
  Tiny generated grass albedo/flat normal resources and assets/material lists are
  stored under assets/terrain/neighbourhood. Texture resources remain loaded for
  the small editable asset list (free_editor_textures=false).
- tools/build_landscape.gd is an explicit build tool, not a runtime generator.
  Refuses to overwrite existing terrain unless -- --rebuild is provided. Rebuild
  only intentionally; it would overwrite later hand-sculpted maps. See
  assets/terrain/README.md for editing/data/source instructions.
- Native Terrain3D initialization creates some resources/settings on tree entry;
  builder applies settings afterwards, then saves external texture/assets/material
  resource paths explicitly. Initial setup failures were corrected and retested.
- tests/terrain_landscape_test.gd passed headless and graphically. Checks native
  version/classes, four saved regions, flat centre/road/drop-point/house, hill
  heights, original physics/boundaries, economy unchanged and second scene reload.
  Desktop-only screenshots/pixel visibility checks at 1152x648 and 1920x1080 passed:
  TEMP/terrain_neighbourhood_1152x648.png and terrain_neighbourhood_1920x1080.png.
- Full verification: all 26 headless regressions passed after terrain integration;
  no application script/assertion failures remained. Scenery resources total about
  259 KiB, excluding the owner's already-installed native addon. No Windows export
  benchmark was claimed; include the complete data directory in later export QA.
- Terrain3D 1.0.2 uses deprecated instance_reset_physics_interpolation on Godot 4.7;
  warning remains upstream. Do not patch the installed addon just to silence it.
  Headless root-certificate warning/editor-settings sandbox write failure are
  environmental. Actual graphical terrain shader/pixels and application assertions
  were tested. Owner progress was not used or changed.
- Next approved task: complete rack purchase/placement/movement and mixed slots,
  as detailed in Requested Graphics/Furnishing Direction. XP/skills stay Phase 2.

## Latest Sleep/Staff Audit Task (2026-10-12)

- business_backend.gd sleep_time_allowed() permits 20:00-07:59. Owned-home sleep
  during 08:00-19:59 returns false without modifying time, money, inventory or save.
  Evening sleep advances to next day 08:00 and bills once. After-midnight sleep
  wakes at the current day's 08:00 without adding another day or duplicate bill.
- sleep_area.gd preserves ownership, bed overlap, indoor/menu guards and one-second
  cooldown. Early E is consumed and shows nonmodal HUD feedback: "It's too early
  to sleep. You can sleep after 20:00." Bed sign and game_ui.gd interaction hint
  show "Sleep after 20:00" during daytime; night shows "Sleep until morning".
  Successful E still reports the new day and morning wake time in HUD feedback.
- tests/sleep_staff_day_test.gd covers morning/noon/19:59 blocking, 20:00/23:59
  next-day sleep, 00:00/07:59 same-day wake, no double billing, repeat guards,
  daytime bed feedback and actual night E input. Backend regressions updated to
  reach bedtime before sleeping; existing sleep ownership/overflow tests remain.
- Full-day actual-scene audit: Sunil carries soap, owner pauses, saves/reloads
  mid-box, resumes and shelves both boxes; level-2 Ramesh scans two products with
  real timers then receives payment. At shift end both stop; Sunil goes home,
  Ramesh works an extra hour, receives INR 50 once, and both return next morning.
  Overnight daily INR 500 charge, stock preservation and save roundtrip checked.
  No additional employee implementation changes were required by these checks.
- Graphical test passed; TEMP/sleep_daytime_feedback.png inspected. Tests use only
  temporary saves; owner progress remains untouched. No nodes were renamed.
- Verification: all 24 tests/*_test.gd passed in TEMP/*-sleep-final.log; final
  focused E recheck and graphical sleep-staff-graphical-final.log passed too.
  Godot's headless root-certificate-store warning is environmental, not a script
  failure. No new application assertions or script errors were found.
- Next: onboarding and complete fresh-demo/export QA, not unbounded new features.

## Requested Graphics/Furnishing Direction (2026-10-12)

Owner explicitly requested better product assets, more neighbourhood buildings,
ambient pedestrians (some pass, some shop), tablet button spacing, purchasable and
movable racks, multiple products on one rack with limited space, and a later player
experience/skill purchase menu. Skills are Phase 2, not part of the immediate demo.

Current implementation pass:
- menu_skin.gd now uses TabBar tab_separation (not just h_separation, which spaces
  elements inside a tab). Tablet theme uses 10px wide/6px compact gaps and larger
  wide padding. Compact 8px padding keeps all five tabs inside the 352px content
  area. Tests await tab layout before inspecting rectangles after resizing.
- Godot native Theme/Control/SubViewport remains the UI stack; no third-party UI
  library is needed. Kenney PNGs are appearance assets, not a gameplay/UI framework.
- Imported two official Kenney Food Kit 2.0 CC0 models: soda-bottle.glb and bag.glb,
  and their external Textures/colormap.png, in assets/products/kenney with LICENSE.md.
  A first white render exposed the missing dependency; the two generated model
  imports were rebuilt after adding it. product_assets.gd caches model scenes
  and mesh bounds, scales uniformly, centers and grounds each product on its shelf.
  shop_operations.gd uses them for bottle/snack displays; existing Cap scan effects,
  item wrappers, product IDs, prices and saves remain unchanged. Soap still uses its
  original procedural model. This is not a complete art replacement.
- neighbourhood.gd adds six solid south-side buildings outside shopping routes.
  street_life.gd adds six bounded sidewalk walkers with existing character models,
  colors and movement animation. They are ambient, not checkout customers and do
  not reserve stock or change money. Existing customer spawner still handles shop
  arrivals. Shared pedestrian-to-shop conversion has NOT been implemented.
- tests/street_assets_test.gd checks walking/reversal/bounds, generated building
  colliders, no ambient economy mutation, product bounds/grounding, Cap presence
  and imported material textures. Graphical mode stocks snacks through real order,
  delivery and shelving actions and captures street/products to TEMP screenshots.
- Verification: five existing affected headless tests passed in TEMP/*-visual-pass.log;
  new headless street_assets-material-check.log passed. Graphical tablet-graphics-final
  and street_assets-colour-render logs passed. Final screenshots inspected:
  TEMP/street_assets_products.png, street_assets_neighbourhood.png and desktop/
  portrait tablet previews. Initial missing-texture and test-layout/type/float
  failures were corrected and rerun. Owner saves were never used or changed.
- Stop/restart the running game to rebuild runtime neighbourhood/tablet/product nodes.
  Additional nodes are Neighbourhood/StreetLife/Passerby0..5, SouthBuilding0..5 and
  ProductAsset under bottle/snack wrappers; existing gameplay paths remain intact.

Next complete gameplay task: shop furnishing and mixed shelf slots.
1. Add a validated saved rack inventory/layout with legacy-save migration. Seed
   existing racks so loading owner progress never deletes or duplicates stock.
2. Management-PC Furniture catalog: buy rack, show cost, pay only once on confirmed
   valid placement; cancel leaves money/layout unchanged.
3. Placement ghost, rotate/move existing rack, collision/door/queue clearance checks.
   Invalid placement shows HUD feedback. Keep inventory attached to rack when moved.
4. Shelf slots store product ID/count/capacity independently. Different SKUs can use
   different slots on the same rack. Full/wrong-assigned slots reject stocking; an
   empty slot can be assigned a product. Do not silently mix items in one slot.
5. Player shelving and Sunil's restock routes target slots from current rack layout;
   customers find actual stocked slots and preserve reserved-stock/payment guards.
6. Test purchase/cancel/reposition, blocked doors/queues, capacity, mixed products,
   customer selection, mid-carry load, worker routes and old-save migration together.
7. Then finish matching soap/building art, richer street browsing/shop entry behavior,
   fresh-player onboarding and performance/export QA.

Phase 2: player experience and skill purchases (saved earned XP, explicit skill
costs and real gameplay effects). Do not add a decorative nonfunctional skill menu.

Asset sources checked online:
- https://kenney.nl/assets/food-kit (CC0, actual two models imported).
- https://kenney.nl/assets/city-kit-commercial (CC0 candidate only, NOT imported).
- https://docs.godotengine.org/en/stable/classes/class_tabbar.html (tab_separation).
- https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html
  (native viewport texture approach already used by the held tablet).

## Latest Main Menu/Settings Task (2026-10-12)

- Added main_menu.tscn/main_menu.gd and changed project.godot run/main_scene to it.
  F5 (Run Project) now opens the lobby; F6 on main.tscn.tscn still starts gameplay
  directly. Menu offers Continue, New Game, Settings and Quit. Last-save day/time,
  money and stock are shown; Continue is disabled if no valid save can be found.
- Background assets/ui/main_menu_shop.png is a real render of the current shop,
  generated by tests/menu_background_capture.gd with only a TEMP save. Menu entry
  does not instantiate the gameplay world or advance time/money. Existing Kenney
  assets style its panels/buttons. No external images or additional dependencies.
- game_session.gd handles read-only save summary using existing backend recovery,
  scene transitions with explicit save/settings paths, and safe New Game setup.
  New Game requires confirmation when previous data exists. It copies primary,
  backup and recovery files into user://save_history before writing a fresh active
  save. Archive failure aborts. It does not recursively delete anything. This is
  one active slot with archives, not a multi-slot save browser.
- main_menu.gd NewGameConfirmation/Message uses three bounded lines, word wrap and
  clip_text guard. Owner screenshot showed an older live instance with the old
  one-line message overflowing. Stop/restart F5 is needed to rebuild live nodes.
  Main actions resize/recenter when their minimum size changes; labels have text
  shadows for contrast on the full-bleed shop background.
- game_settings.gd persists volume, fullscreen, look sensitivity, invert-Y and
  camera FOV in user://settings.cfg. Settings are separate from business saves,
  range/type checked on load, and applied to audio/window/player controls.
- settings_menu.gd builds reusable settings form with sliders/toggles. Apply/Back
  stay pinned outside the scrolling form even at 640x480. No gameplay changes
  occur on Back; Apply saves settings before applying them. Inline failures leave
  the settings menu open. Fullscreen is an actual DisplayServer mode, not cosmetic.
- pause_menu.gd is runtime Ui/PauseMenu plus sibling Ui/PauseSettingsMenu. Escape
  outside existing interaction menus pauses the tree (clock/NPC/timers freeze).
  Resume/Escape restores gameplay. Settings can apply while paused. Save & Main
  Menu captures marketing time and saves first; errors keep the game open.
- game_ui.gd adds the pause control without changing existing shop/tablet paths.
  player.gd applies saved camera/input settings, supports invert-Y, includes pause
  in menu locking, and opens pause on Escape only when no existing menu is open.
- Added tests/main_menu_test.gd: disabled Continue/new save, actual scene metadata
  paths, settings persistence/application, real pause timing, save-return-resume,
  cancel without writes, archived New Game, backup Continue, responsive menus and
  bounded confirmation text. Existing 22 regressions still passed (23 total).
- Graphical integration passed and inspected main lobby, portrait lobby, pinned
  settings footer, pause and confirmation. Final focused test passed after adding
  clip_text. Tests only use TEMP files; original Downloads and owner saves untouched.
- Latest previews: TEMP/main_menu_3300890/menu_1152x648.png and new_confirmation.png.
- Next remains full-day staff audit, onboarding/polish and Windows export testing.

## Latest Demo Goals Task (2026-10-12)

- Added demo_progress.gd (RefCounted): five objectives driven by successful actions:
  order products, manually stock 10 items, serve 10 customer transactions, have
  Sunil finish stocking a box, and earn at least INR 2,000 in sales. Goals can be
  completed in any order. Hiring alone does not credit Sunil's job. Manual stocking
  tracks the first 10 items; transaction count is separate from items sold.
- business_backend.gd records order_stock, player shelve_one/shelve_box, worker
  shelve_box and successful sell_basket events before normal atomic autosave.
  Failed actions do not count. The result freezes when all goals are achieved;
  normal business transactions continue after completion without changing results.
- Added optional demo_progress dictionary to version 10 snapshots, validated for
  types/ranges, revenue/transaction consistency and completion acknowledgement.
  Old saves missing it start a fresh goal checklist without changing finances,
  inventory, ownership or employees. Their historical sales are not retrocredited.
- game_ui.gd adds Goals as fifth tablet tab with runtime Ui/ShopMenu/DemoStatusLabel,
  DemoGoal0...4, DemoResultsLabel and DemoContinueButton. Preserves all existing
  menu nodes/signals and the held-tablet source/view contract. Completion shows
  customer transactions, demo sales, manual stocking goal and Sunil's completed job.
- Completion opens the Goals/results tablet once when no other menu is open;
  it never interrupts checkout/management/dialogues. completion_seen is autosaved
  so reload or E/Escape does not reopen the results endlessly. Continue shop uses
  the existing close path, restoring movement without resetting anything.
- Added tests/demo_progress_test.gd: real backend actions, invalid actions, customer
  vs item counts, hiring vs fulfillment, old-save preservation, mid-task reload,
  corrupted progress, safe deferred completion, responsive tablet results,
  continue/resume, frozen summary and acknowledged restart. Expanded tablet_test
  to click/verify all five tabs using its existing real viewport input.
- All 22 headless scripts passed. Graphical demo test passed and desktop 1152x648
  plus portrait 360x640 progress/results screenshots were inspected. TEMP saves
  only; no owner-save changes. Existing Windows certificate warning remains.
- No scene files, initial money/stock, customer AI, employee scripts or prices
  changed. This completes objectives/end milestone, not release readiness. Still
  pending: full-day employee audit, onboarding/settings, polish and Windows export.

## Latest Tablet Hand Occlusion Fix (2026-10-12)

- User screenshot showed the tablet screen drawing over hands/sleeves at the edges.
  Existing no-depth-test materials had screen priority 112 but palm/sleeve 111.
- shop_tablet.gd now draws sleeves at 113, palms 114 and thumbs 115, in front of
  screen 112. Grip centers move slightly outward (+0.015) and forward (+0.02) so
  they hold the bezel instead of appearing underneath the screen texture.
- Existing full-device safe framing still includes the new grip transforms;
  desktop/portrait layouts and accurate input rays remain unchanged.
- tablet_test.gd checks every hand material is above the screen priority. Its
  graphical capture also samples both projected thumb centers and verifies brown
  hand pixels rather than white screen pixels. Headless and graphical tests passed
  across viewport sizes and FOV/aspect modes. Inspected Marketing at 994x618.
- No gameplay/backend/save changes. Latest preview: TEMP/tablet_994x618_tab3.png.

## Latest Local Kenney Pack Task (2026-10-12)

- Found Downloads/kenney_ui-pack and kenney_ui-pack.zip. Verified Grey/Default/
  button_rectangle_flat.png matches the existing project asset by SHA-256.
- Copied the owner's Green/Default/button_rectangle_depth_flat.png into
  assets/ui/kenney/active.png. Added its original path to LICENSE.md.
- menu_skin.gd uses the actual green asset for selected tabs/pressed buttons and
  a brighter version for hover_pressed. Employee role buttons therefore remain
  visibly selected while hovering. Existing routes and controls are unchanged.
- tablet_test.gd asserts active asset use for both selected and selected-hover
  styles. Focused headless tablet/employee_actions/ui_visual tests passed; graphical
  tablet test passed across desktop/portrait and FOV modes. Inspected active
  Overview preview at 994x618. Owner progress and Downloads source files untouched.
- Latest preview: TEMP/tablet_994x618_tab0.png (regenerated by graphical tests).

## Latest Tablet/UI Assets Task (2026-10-12)

- Owner reported a cut-off tablet bottom and requested online UI assets/menu polish.
  Root cause: shop_tablet.gd originally sized only the screen quad, excluding the
  bezel and hands/sleeves from viewport limits. Menu content itself was in bounds.
- shop_tablet.gd now projects the AABB corners of TabletBody, TabletScreen and
  both hand meshes, then scales/recenters the full device inside a safe rectangle
  (24px sides, 56px top, 24px bottom). Resting position is preserved through the
  opening animation. Portrait uses proportionate hand/bezel sizes. Input ray
  mapping still uses the real device transform, so clicks remain accurate.
- Downloaded Kenney UI Pack 2.0 from the creator's official site:
  https://kenney.nl/assets/ui-pack (CC0, personal/commercial use). Only 11 relevant
  unmodified PNGs were copied into assets/ui/kenney; source names/license links
  are preserved in assets/ui/kenney/LICENSE.md. No fonts added; existing rupee
  support preserved. Assets are local/offline, no runtime downloads or dependencies.
- Added menu_skin.gd: shared nine-slice texture styles for menu panels, buttons,
  tabs, inputs and progress bars; checkbox/close/checkmark/arrows from the pack.
  Dark popup and light tablet variants have matching contrast. Checkbox icons
  render at 18px and arrows at 12px rather than their large native dimensions.
  This fixed a staff-menu row overlap discovered by the regression tests.
- game_ui.gd applies the skin to existing menu themes, uses a close icon/pay-bills
  checkmark, adds HeaderDivider/FooterDivider to the held tablet, and places the
  six Overview statistics in two columns on wider screens. Compact keeps stacked
  rows with 18px source text. Existing labels, commands, tabs and signals preserved.
- Tablet sync now copies button icons along with text/state. Source Ui/ShopMenu
  remains authoritative; viewport duplicate is still only the view/input proxy.
- Expanded tablet_test.gd: full bezel/hand bounds, texture theme, 994x618 screenshot
  resolution, 1152x648/640x480/360x640, both camera aspect modes and FOV 50/90,
  actual clicks/tabs/close/price inputs. Checkout/staff layout tests now give named
  controls in overlap errors. Existing gameplay assertions remain intact.
- All 21 headless scripts passed after icon sizing fixes. Final graphical tablet
  and checkout tests passed; inspected desktop Overview, portrait Overview, Staff,
  management work-hours and compact UPI payment screenshots. Only the existing
  Windows headless certificate-store warning remains, not script/assertion errors.
- No scene files, backend/save schema, business/employee/customer behavior changed.
  Tests use TEMP saves, not the owner's progress. Next remains demo objectives.

## Latest Multi-Box Ordering Task (2026-10-12)

- business_backend.gd now accepts order_stock(product, boxes=1), 1-10 boxes per
  purchase and up to 20 outstanding boxes total. Product/quantity/funds/capacity
  are validated before charging the full wholesale total. Each box contains 10
  items. New orders may be placed while boxes are in transit, outside or carried.
- Added incoming_boxes and queued_boxes manifests, each entry {product, amount}.
  supply_in_transit is the incoming total, while boxed_stock/carried_stock/
  worker_carried_stock and pending_product retain the existing active-box contract.
  Player and Sunil still share ONE active handling slot: concurrent carrying is not
  implemented. Incoming/outside boxes do not change the carried product or rack.
- receive_delivery moves the incoming batch outside, even while stocking another
  box. The next outside box becomes active only when the previous is finished.
  pick_up_box(false, queue_index) can select a different outside box and preserve
  the former active one (including partial quantity) in the queue. Existing
  single-item manual shelving, wrong-rack guards and partial returns are preserved.
- Save version 10 retained with optional incoming_boxes/queued_boxes fields.
  Old snapshots without either manifest migrate their one in-transit box; existing
  outside/carried state stays unchanged. New manifests validate amounts, capacity,
  active-slot exclusivity, transit totals and per-SKU inventory conservation.
  JSON quantities normalize to ints on restore. Backup/recovery remains in use.
- supplier_menu.gd preserves ProductSelector and adds BoxQuantityLabel and
  BoxQuantityInput (SpinBox). Orders show selected product, shelf stock, box count,
  total items/cost and supply status; order remains available while Sunil works.
  Not enough funds/20-box limit disables ordering with a tooltip. Each click is a
  distinct paid purchase; the old one-pending-order duplicate guard was removed.
- shop_operations.gd retains DeliveryBox and CarriedBox and builds additional
  DeliveryBox2... nodes for queued outside crates in a spaced grid. Each is labelled
  with quantity and its own SKU. Nearby aimed E chooses that crate; the original
  first-box nearby-E fallback remains compatible. Pickup HUD now uses real partial
  quantity rather than hardcoded 10. The held final-placement label stays on the
  previous product even when the next queued box becomes active.
- Sunil's existing assignment/opt-in automatic workflow uses the active manifest
  box without rewriting stock_worker.gd. Automatic mode processes multiple boxes
  sequentially; manual assignment is still one box per assignment. Paused/carrying
  worker prevents player pickup until that active box is resolved.
- notification_feed.gd shows the actual number of outside boxes and detects
  incoming/outside boxes per SKU for low-stock advice, including while Sunil carries.
- Added tests/multi_box_test.gd: mixed orders, costs/capacity, labelled crates and
  aimed selection, active-product protection, partial return/reload, old-save
  migration, invalid manifests, Sunil batch routing and responsive UI. Updated
  physical_shop_test.gd/product_workflow_test.gd to expect repeat ordering allowed,
  while retaining invalid-quantity and duplicate pickup/shelving guards.
- All 21 headless tests passed. Graphical multi-box test passed; inspected menu
  screenshots at 1152x648 and 360x640 plus the outside delivery grid. All fixtures
  use TEMP saves. Existing Windows certificate-store warning remains headless-only.
- No scene files, existing node names, checkout or customer logic changed.
- Next recommended task: demo starting objectives and success milestone. Current
  system supports selecting a product and ordering several boxes per purchase;
  it does not yet have a mixed-product cart/one combined checkout purchase.

## Latest Queue Patience Task (2026-10-12)

- customer.gd adds runtime Customer/PatienceLabel, billboarded above the customer's
  head. While physically QUEUING, it shows name and remaining real-time seconds.
  Bargain hunters have 90 seconds, regulars 120, hurried customers 60. At 75% elapsed
  the text turns amber. Only queue time counts toward this limit; the existing
  scanning/payment/bargaining stage timers remain unchanged.
- At queue expiry, record one missed sale and timeout review, leave the queue,
  release reserved products using existing leave_shop/remove_customer/update_rack,
  and show a brief nonmodal departure message. Money, sold stock and revenue do
  not change. Labels hide after departure or transition to checkout. Shop closing
  takes precedence and remains neutral, without an extra missed sale/review.
- notification_feed.gd adds one deduplicated left-side warning per impatient
  queued customer. Remaining seconds update with existing 0.25-second refresh;
  rows disappear when the customer leaves or starts checkout. No modal or input
  lock, and existing staff/stock/bill notifications remain unchanged.
- Added tests/queue_patience_test.gd: personality limits, countdown, warning,
  queue expiry, stock reservation return, ordering, duplicate guards, checkout
  transition, neutral closing and unchanged accounting. Graphical test uses its
  own fixed preview camera so it does not alter the gameplay camera.
- All 20 headless tests passed. Graphical queue test passed; desktop 1152x648 and
  portrait 360x640 countdown/warning screenshots inspected. Tests use TEMP saves.
- No scene files, existing node names, backend schema or checkout UI were changed.
- Demo scope agreed: one shop, three products, physical ordering/stocking,
  checkout/bargaining and two employees. Remaining packages: demo progression,
  employee reliability, UI/onboarding/settings, graphics/sound and release testing.
  More businesses, vehicles and family remain outside the first demo.

## Latest Customer Reviews Task (2026-10-12)

- Added customer_reviews.gd: neutral reputation 50/100. One review per resolved
  visit; fast purchase score 80, minus one per two real service-wait seconds
  (maximum 120 seconds counted), plus 10 for a completed discounted purchase.
  Sold scores clamp to 20-100. Empty shelves score 25, refused price 40, checkout
  timeout 10. Reputation change: +2 for score >=70; -4 below30; -2 below50;
  otherwise unchanged. Reputation clamps to 0-100; review count bounded/validated.
- business_backend.gd owns the review module and commits reviews through normal
  autosave/changed signals. Added optional customer_reviews dictionary to version
  10 snapshots. Saves without it load neutral defaults; malformed present data
  is rejected through existing recovery. No accounting or stock rules changed.
- customer.gd tracks service wait while queuing/buying/scanning/bargaining/paying.
  Departures record once; duplicate payments/departures cannot add reviews.
  Shop closing/manual neutral departure creates no negative review. Both legacy
  direct sales and physical checkout integrate outcomes. Existing timeout and
  stock-return behavior remains; queue abandonment is NOT implemented yet.
- game_ui.gd adds runtime Ui/ShopMenu/ReputationLabel in Marketing, with current
  reputation and last satisfaction; tooltip shows review count. Held tablet copies
  it using existing rendering/sync. No scene files or existing node names changed.
  Receipts remain short to preserve SaveStatusLabel layout.
- Added tests/customer_reviews_test.gd for scores, discounts, invalid inputs,
  bounds, unchanged finances, save roundtrip and old-save defaults. Expanded
  checkout_test.gd for wait-based score, duplicate guards, wrong-payment neutrality,
  empty stock and timeout reviews. tablet_test.gd checks synced reputation label.
- Full 19-script headless audit completed; two layout failures were fixed and
  affected employee_actions/ui_visual tests rerun successfully. Expanded checkout
  test rerun successfully. Graphical tablet test passed, including 1152x648,
  640x480 and 360x640; desktop/portrait Marketing screenshots visually inspected.
  Headless logs have the existing Windows certificate-store warning, not script
  errors. All saves/tests use TEMP fixtures, never owner progress.
- Reputation currently gives feedback only, not traffic/budget/bargaining changes.
  User's "next" and "continue work" authorized this scoped feature.

## Latest Physical Checkout Task (2026-10-11)

- Edited customer.gd: manual scans identify individual basket item indexes, reject
  duplicate scans and retain scan_next() for Ramesh's automatic work. Successful
  payment now produces a short Receipt HUD message. Sales still commit only once.
- Edited shop_operations.gd: while the first queued customer is scanning, aim at
  an unscanned counter product and press E. Missing the item produces nonmodal HUD
  guidance. Each scanned product moves over the scanner to the completed side,
  changes cap color, plays the scan tone and briefly flashes runtime Scanner/
  ScanLight. Checkout display remains live. Checkout takes priority over talking
  to a nearby employee while the player is actively serving a customer.
- Edited checkout_menu.gd: scanning is physical rather than a menu button. Once
  scanning/bargaining finishes, the payment panel shows customer, product/count,
  total, presented method and cash/change details. Cash, Card and UPI buttons are
  explicit choices. A wrong method does not sell or charge and shows an inline
  warning; selecting the customer's actual method completes payment and closes.
- Ramesh still scans and completes payment automatically when on shift and the
  player is away. Bargaining, customer timeout, queue order and stock reservations
  remain integrated. No backend/save schema or scene file changes.
- Updated tests/checkout_test.gd and physical_shop_test.gd. Coverage includes real
  E input, aim miss, all individual item indexes, scanner motion/light, all three
  payment methods, wrong choice, cash change, bargaining transition, receipt,
  duplicate completion guards, employee auto-checkout and responsive layouts.
- All 18 headless regression scripts passed with no script/assertion errors. The
  graphical checkout test passed; desktop cash and mobile UPI/wrong-choice views
  were inspected. Tests use temporary saves and do not touch owner progress.
- Recommended next task: customer satisfaction/reputation affected by wait time,
  correct checkout, bargaining and stock availability. Do not implement without
  agreement.

## Latest Shelf Animation Task (2026-10-11)

- Edited box_carry_visual.gd: play_place_animation() makes the right hand/thumb
  reach from the box and gently shifts the held box during each placement. It is
  camera-relative in first person and drives the existing arm target in third
  person. The final empty box remains visible for the 0.32-second gesture, then
  hides and restores the normal character hands.
- Edited shop_operations.gd: after the backend accepts exactly one item, the newly
  visible rack product starts small and offset toward the aisle, then settles into
  its existing shelf position over 0.28 seconds. Bottle, snack and soap racks use
  their existing product nodes. Rapid presses animate independent products and do
  not alter the backend's one-item-per-press accounting.
- The existing short stock sound plays with the gesture. Wrong-rack actions,
  returned boxes, Sunil's automatic stocking and saved partial quantities remain
  unchanged. No scene files, node names, save fields or migrations changed.
- Expanded tests/box_carry_test.gd to verify animation state, moving right-hand
  grip, visible/scaled new shelf item, settled final transform and delayed final
  box hide. All 18 headless regression scripts passed.
- The graphical placement test passed. Inspected the first-person rack screenshot
  during the hand reach with the box showing 9 items and the new bottle visible.
  Tests use temporary saves and do not touch owner progress.
- Recommended next task: improve manual checkout so the player aims at and scans
  each item with visible scanner feedback before choosing cash/card/UPI payment.
  Do not implement without agreement.

## Latest Individual Shelving Task (2026-10-11)

- Edited business_backend.gd: added shelve_one() for an atomic one-item transfer
  from the player's carried box to the matching product inventory. Partial boxes
  from 1-10 are now valid saved supply state. Partial boxes can be returned to the
  delivery point and picked up again. Existing save version 10 remains compatible;
  no new fields or migration are needed.
- Existing shelve_box() remains for Sunil and backend compatibility, including a
  partial returned box Sunil may collect. Sunil still completes his assigned box
  automatically; player manual stocking is the deliberate one-at-a-time workflow.
- Edited shop_operations.gd: correct-rack E places one item, updates rack visuals,
  shows remaining quantity in HUD feedback/prompt and keeps the box until empty.
  Delivery and carried box labels show their live quantity. Wrong-rack behavior
  remains nonmodal and preserves all state.
- Edited shop_audio.gd: added a brief stock-placement sound. Edited stock_worker.gd
  so Sunil's carried-box label also uses the actual remaining quantity.
- Expanded tests/box_carry_test.gd, product_workflow_test.gd and
  physical_shop_test.gd. Coverage includes all products, ten E placements,
  quantity labels, one-item inventory transfer, partial save/reload, partial
  return/pickup, final empty box and unchanged wrong-rack guards.
- All 18 headless regression scripts passed. The graphical carry test passed;
  inspected the partial-box screenshot at 9 items with both hands and HUD text.
  Tests use temporary saves and do not touch owner progress.
- Files/nodes preserved: no scene files or node names changed. Runtime CarriedBox,
  its existing BoxLabel and rack product meshes are updated in place.
- Recommended next task: a brief hand-to-shelf placement animation and subtle
  product landing motion/sound polish. Do not implement without agreement.

## Latest Carry Task (2026-10-11)

- Added box_carry_visual.gd on existing runtime Player/CarriedBox. Adds LeftGrip,
  RightGrip, LeftThumb, RightThumb, LeftCarryForearm and RightCarryForearm.
- First-person box follows camera pitch; both grips stay attached to the box.
  Gentle walking bob/sway settles when stationary. Third-person existing arm
  pivots reach the grips; duplicate original hands are hidden while carrying,
  then hands and normal arm scales restore after shelving/returning.
- Edited shop_operations.gd: initialize carry visuals; a wrong product rack
  consumes the E interaction and shows red HUD feedback. No menu/tablet opens;
  box, inventory and money stay unchanged. Correct-rack and return actions remain.
- Added tests/box_carry_test.gd: all three SKUs and six wrong-rack combinations,
  E input, unchanged transaction state, HUD/no-menu guards, both grips, first/third
  person, pitch following, walking input/sway/settling, shelving and box return.
- Updated tests/product_workflow_test.gd to expect handled wrong-rack feedback.
- All 18 headless test scripts passed. Isolated graphical carry test passed;
  inspected desktop first/third-person and 640x480 screenshots. Initial preview
  framing was adjusted; a timer-based graphical walking assertion was replaced
  with deterministic physics-frame input verification and passed on rerun.
  A final headless walking check exposed sway settling between physics updates;
  carry now also reads horizontal velocity, with headless/graphical reruns passing.
- Tests use temporary saves. No backend, accounting, save schema, scene files,
  player movement, character_visual.gd or stock_worker.gd changes. Existing
  character arm nodes are posed by the new carry script, not renamed.
- Limitations: low-poly placeholder hands; Sunil's carry pose is unchanged.
  Correct-rack stocking still unloads ten at once. Manual owner playtest remains.
- Recommended next task: individual shelf placement from the carried box, with
  partial-box counts and save compatibility. Do not implement without agreement.

## Latest Notification Task (2026-10-11)

- Added notification_feed.gd: nonblocking left HUD messages for employee requests,
  stock at 2 units or less, empty products, delivered boxes and unpaid bills.
- Added runtime Ui/NotificationFeed/NotificationScroll/NotificationList and rows.
  Rows update in place, clear when resolved, wrap and scroll. No duplicate spam.
  Never-ordered products do not generate empty-stock warnings.
- Edited game_ui.gd to create the feed; staff_dialog.gd no longer opens requests
  automatically. Click an employee notice to open existing dialogue. Closing
  without replying leaves the request available. Feed hides while menus are open.
- Existing employee E/Talk still works. To click HUD notices during captured mouse
  look, use the existing Escape mouse-release behavior. Gameplay is not paused.
- Added tests/notification_test.gd and updated tests/employee_life_test.gd.
- Notification tests passed headless and graphically, including real mouse click,
  overtime/pay clearing, duplicate suppression, low/empty stock, refill clearing,
  delivery/bills and responsive bounds. Desktop/portrait screenshots inspected.
- Initial regression run stalled after physical_shop_test.gd. The later full
  verification task below completed all 17 scripts successfully.
- No scene, backend, stock-worker, movement or save-schema changes. Tests used
  temporary fixture saves, not the owner's save. This memory file was updated.

## 1. Read This First

This is the shared project memory for the owner and any future AI developer.
Read it before changing code, then inspect the actual files. Code and observed
runtime behavior take precedence if this document becomes outdated.

This file does NOT update itself. The AI working on a task must update it before
ending that task. Do not claim that memory updates are automated.

Copy this instruction into a new AI conversation:

> Read PROJECT_MEMORY.md first. Inspect the existing Godot scripts and scenes.
> Preserve working features and existing node names. Implement only my current
> task, finish its backend/UI integration and tests, then update PROJECT_MEMORY.md
> with what changed, verification results, limitations, and the next handoff.

## 2. The Game We Want

Build a low-poly 3D life and business simulator with an Indian small-shop identity.
The player starts with one small business and makes practical daily decisions:
buy products, receive deliveries, carry boxes, stock shelves, serve customers,
negotiate prices, collect payments, manage employees, and live at home.

The goal is an enjoyable, distinctive demo first, then a larger game that players
could choose to buy. Do not build every long-term system before proving the demo.
There is no confirmed release date, sale price, platform/store, or final title.

Distinctive direction discussed with the owner:
- Indian-style bargaining: some customers ask for a lower price.
- Hands-on retail work, not stock magically appearing on shelves.
- Cash, card, and UPI-style payments.
- Employees with work hours, overtime requests, respect, happiness, and reactions.
- A connection between running the shop and the player's daily life.

Long-term ambitions, NOT completed features:
- Own multiple businesses and properties.
- Buy/build and improve a house.
- Family and deeper life simulation.
- Vehicles and a larger neighborhood.
- More products, employee roles, and business growth.

## 3. Owner's Working Rules

1. Inspect the current project before editing. Do not assume an old screenshot
   reflects the latest code.
2. Keep existing node names and working scene references wherever possible.
3. Preserve movement, camera modes, shop interaction, checkout, saving, and home.
4. Use simple, modular Godot code. Do not rewrite the entire game at once.
5. Finish a complete feature, including conditions, money/stock rules, UI, and
   tests. Do not hand over disconnected half-code.
6. Explain the edited files and changed/added nodes before asking the owner to test.
7. Never reset or overwrite the owner's saved progress for testing.
8. Use actual in-engine screenshots for verification; generated concept images
   are not evidence that gameplay works.
9. Latest room decision: provide a larger room from the start with the queue
   inside. Do not restore the old level-locked floor expansion unintentionally.
10. Automatic restocking is an explicit option for Sunil, not the default.
    Delivery arrival alone must never add products to shelves.

## 4. Project and Run Information

- Workspace: `C:\Users\Lenovo\Documents\life-business-game`.
- Engine currently tested: Godot 4.7.2 stable, GL Compatibility renderer.
- Main scene: `main.tscn.tscn`. The double extension is intentional existing state.
- Other scenes: `customer.tscn`, `worker.tscn`, `house.tscn`.
- Engine executable on this machine:
  `C:\Users\Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`.
- Open `project.godot` in Godot and run the project to play.
- There is no Git repository in this directory as of this handoff.
- Do not edit generated `.godot` cache files as source code.

## 5. Completed Systems and Current Rules

### Player, Camera, and World

- WASD movement and mouse look.
- Third-person outdoors; first-person in the shop and house.
- Outdoor camera distance adjusts with the mouse wheel.
- Menus lock movement and mouse look; closing restores mouse capture.
- Existing low-poly humanoid parts, walking/idle motion, and work gestures.
- Player, customers, and staff are still placeholder-quality characters.
- Shop, road, house, collision geometry, lighting, and day/night presentation.
- Shop room is approximately 6 x 10 m, with a 3.8 m wall/ceiling-height setting.
- Full room exists at every business level. Existing levels increase customer
  arrival frequency; they no longer unlock physical rear floor space.
- Automatic glass sliding doors open near player/customers/staff and then close.

### Economy, Time, and Home

- Fresh game: INR 50,000 money, 10 bottles, day 1 at 08:00.
- Existing saves keep their progress instead of restarting at these defaults.
- Shop is open from 08:00 inclusive to 20:00 exclusive.
- Clock runs at 2 game minutes per real second.
- Clock pauses while the employee reply dialogue is visible. This is not a
  universal simulation pause; customer processing can still continue.
- Items sold, revenue, expenses, missed sales, last visit, and cash balance update.
- Shop operating charge: INR 100 per game day.
- Employee wage: INR 200 per employed role per day; currently not proportional
  to the number of scheduled work hours.
- Arrears and bill repayment are supported; unpaid wages prevent staff working.
- Home purchase: INR 15,000. Purchase closes the menu and updates ownership.
- Owned home supports entry and sleeping until the next morning, with billing.
- Marketing: INR 200 for 60 real seconds; increases customer arrival frequency.
- Business upgrades: level 2 costs INR 2,500; level 3 costs INR 5,000.
- Base customer spawn intervals: 10, 8, and 6 seconds by level. Marketing applies
  a 0.85 multiplier. The physical shop has at most three spawned customers.
- Displayed net profit is revenue minus recorded expenses, including purchases
  of unsold inventory. It is a simple cash-flow measure, not full accounting.

### Products, Ordering, and Physical Restocking

| Product ID | Product | Wholesale box of 10 | Default unit sale price |
| --- | --- | --- | --- |
| `bottle` | Reusable bottles | INR 500 | INR 100 |
| `snack` | Snack packs | INR 400 | INR 80 |
| `soap` | Soap bars | INR 600 | INR 120 |

- Only bottles have initial stock. Snacks and soap must be ordered.
- Management PC Orders tab selects a product and its retail price.
- Retail prices currently range INR 50-200, in increments of INR 10.
- Only one box/order can be outstanding at a time across all products.
- Ordering subtracts money and records expenses; it does NOT increase shelf stock.
- Van arrives, unloads one product box outside, and leaves.
- Player uses E to pick up the box, then E near the matching product rack to stock it.
- Player can return a carried box to the delivery point.
- Product-specific shelves, carried-box labels, and checkout visuals are present.
- Sunil can physically collect and stock a delivered box by assignment.
- Optional automatic collection is saved and OFF by default. It only collects
  existing deliveries while he is on shift; it never purchases products.
- Original instant `purchase_stock()` remains for legacy/nonphysical test paths.
  Normal physical-shop gameplay uses `order_stock()` and box delivery.

### Customers, Checkout, and Bargaining

- Customers enter, walk to a stocked product rack, take products, and queue.
- Each basket contains 1-3 units of ONE product type, not a mixed-product basket.
- Shelf availability subtracts customer reservations to prevent overselling.
- Queue has three indoor positions; customers face the checkout while waiting.
- Checkout monitor and management PC are separate objects.
- Products appear on the checkout table and are scanned one by one.
- Monitor displays scanned count, subtotal, live cashier scan timer/status, and
  payment method; screen color changes for the payment stage.
- Manual checkout is available when the player stands behind the counter.
- Cashier steps aside when the player occupies the checkout position.
- Cashier automates scanning and payment when on shift and the player is away.
- Cash has tendered amount and change. Card and UPI have distinct payment props.
- Money and stock change only on successful final payment, not when an item is
  taken or scanned. Duplicate payment attempts are guarded.
- Customers have simple personalities/budgets and can ask for a discount.
- Player can accept, counter, or keep the price. Refusal/timeouts/closed shop
  release reservations and return unpurchased items to available stock.
- These are scripted state machines, not generative dialogue or general NPC AI.

### Employees and Conversations

- Ramesh: cashier. Sunil: stock assistant. Names appear above their characters.
- Cashier hiring levels: INR 1,000 / 2,000 / 3,000.
- Corresponding scan times: 3 / 2 / 1 real seconds per item.
- Stock assistant hiring cost: INR 1,000.
- Roles have independent work-hour controls in the management PC Staff tab.
- Hours use whole-hour boundaries between 06:00 and 22:00, with end after start.
- At shift end, employees ask whether they can go home.
- Player can let them leave, politely request one extra hour, or insist.
- One overtime hour creates INR 50 owed. Money is NOT deducted immediately.
- After overtime, employee asks for payment. Payment requires enough money and
  can be made through the reply dialogue or management PC People tab.
- Refusing payment preserves the debt and reduces happiness.
- Starting happiness: 70/100. Kind/rude daily conversation affects happiness;
  the daily talk choice cannot be repeated to farm unlimited happiness changes.
- At happiness <= 35 an employee refuses an overtime request.
- At happiness <= 20 an employee quits. Unpaid overtime remains owed.
- Quit employees can be rehired after settling their overtime debt.
- Leaving/quitting stock assistants return a carried box to the delivery state.
- Off-duty employees leave/hide and return for the next eligible shift.
- Sunil's menu status distinguishes waiting/assignment, restocking, and off shift.

### UI, Sound, and Saving

- Shop menu tabs, money/time HUD, interaction feedback, home menu, bargaining,
  checkout, management PC, and employee reply dialogue are integrated.
- Management PC tabs: Orders, Staff, Space, People.
- Space tab reports the full room; its expansion button is disabled.
- Responsive UI checks cover 1152x648, 640x480, and 360x640 viewports.
- Simple generated scan, payment, door, and delivery sound effects are included.
  These are placeholder tones, not recorded ambience, speech, or final audio.
- Save format is version 10. Prior formats 1-9 are migrated and validated.
- Save path: `user://business_save.json`; save writes use temporary/backup files.
- Save includes business/product inventory, pending supply, employee relations,
  overtime debt, work hours, ownership, clock, and automatic collection preference.
- Actor movement, customer basket/queue progress, and exact player/NPC positions
  are not persistent world snapshots. Do not promise resuming a mid-scan customer.

## 6. Code Ownership Map

| File | Responsibility |
| --- | --- |
| `business_backend.gd` | Authoritative money, aggregate/product stock, transactions, billing, upgrades, save validation and migration |
| `product_catalog.gd` | Product IDs, names, wholesale costs, extra-product inventory defaults and validation |
| `shop_area.gd` | Shop interaction, backend ownership, timers, existing shop labels/buttons, money formatting |
| `shop_operations.gd` | Runtime room/racks/PCs/counter/van/boxes, queue, reservations, physical interaction, monitor, staff presence |
| `customer.gd` | Customer movement and shopping/scanning/bargaining/payment state machine |
| `customer_spawner.gd` | Spawn timing, customer limit, marketing/level arrival changes |
| `checkout_menu.gd` | Manual scan and payment UI |
| `bargain_menu.gd` | Price negotiation UI |
| `supplier_menu.gd` | Management PC ordering, pricing, hiring, hours, stock assignments, employee mood/pay |
| `employee_relations.gd` | Employee shift requests, replies, mood, overtime, quitting/rehiring, employment history |
| `staff_dialog.gd` | Employee conversation popup opened explicitly through employee actions or request notices |
| `stock_worker.gd` | Sunil's physical collection/carrying/shelving routes |
| `worker.gd` | Existing cashier worker integration and legacy behavior |
| `sliding_door.gd` | Automatic entrance panels, collision, proximity sensing, opening/closing |
| `shop_audio.gd` | Generated sound streams and effect players |
| `game_ui.gd` | Shared UI theme, runtime menus, layouts, HUD, feedback, upgrade integration |
| `notification_feed.gd` | Nonblocking left HUD requests, stock warnings, delivery and bill notices |
| `shop_tablet.gd` | Held 3D device, viewport UI projection, clicks, input drafts, close keys and model synchronization |
| `player.gd` | Movement, look, camera modes, menu input lock and Escape |
| `character_visual.gd` | Low-poly humanoid parts and simple animation |
| `neighbourhood.gd` | Runtime world geometry/collision and shop construction integration |
| `house_area.gd`, `sleep_area.gd` | Home purchase, ownership, bed interaction and sleep |
| `day_clock.gd`, `day_night.gd` | Clock progression/HUD and lighting presentation |

Important: `stock` is aggregate shelf inventory across all products, not bottles
alone. `product_stock("bottle")` derives bottle stock by subtracting snack/soap
stock. Use product APIs for product-specific gameplay. Do not subtract aggregate
stock independently from a UI or NPC script.

## 7. Important Nodes and Spatial Contracts

Preserve existing scene nodes:
- `Player/CameraPivot/SpringArm3D/Camera3D` and player collision/mesh.
- `Shop/ShopArea`, `ShopDoor`, `ShopSign`, `MarketingTimer`, `AutosaveTimer`.
- `ShopOperations`, `Neighbourhood`, `DayClock`, `DayNight`, `Worker`.
- `Customer`, `CustomerSpawner/SpawnTimer`, `CustomerSpawnPoint`,
  `CustomerPurchasePoint`, `CustomerExitPoint`.
- `Ui/ShopMenu`, including `MoneyLabel`, `StockLabel`, `BuyStockButton`,
  `CloseButton`, and other existing controls.
- `Ui/HouseMenu`, `House/HouseArea`, `House/InteriorArea`, `House/Bed/SleepArea`.

Important runtime-created nodes (not all appear in the editor's local scene tree):
- `ShopOperations/StockRack`, `SnackRack`, `SoapRack`.
- `CheckoutCounter/CheckoutPC/Screen` and `TotalDisplay` under ShopOperations.
- `ComputerDesk/ShopPC` under ShopOperations: management, not checkout.
- `DeliveryVan`, `DeliveryBox`, `SlidingDoor/LeftPanel`, `SlidingDoor/RightPanel`,
  `ShopAudio` and four effect players under ShopOperations.
- `Player/CarriedBox`; root `StockWorker/WorkerBox`.
- `Worker/EmployeeNameLabel`, `StockWorker/EmployeeNameLabel`.
- `Ui/SupplierMenu`, `CheckoutMenu`, `BargainMenu`, `StaffDialog`.
- `Ui/NotificationFeed/NotificationScroll/NotificationList` and condition-based
  notice rows. Employee notice clicks open StaffDialog; unresolved requests persist.
- `Player/CameraPivot/SpringArm3D/Camera3D/ShopTablet`: TabletBody, TabletScreen,
  TabletViewport/ShopMenu, LeftHand and RightHand. The original Ui/ShopMenu
  remains the authoritative control/signal model; its alpha is zero, NOT hidden
  while the tablet is open, so existing menu locks and references still work.
- Tablet Staff controls under Ui/ShopMenu: CashierSelectButton, StockSelectButton,
  WorkSwitch, AutoCollectSwitch, CollectDeliveryButton, TalkEmployeeButton.
  SectionLabel is also added at runtime. Controls are duplicated into TabletViewport,
  but backend transactions are forwarded to originals, not executed twice.
- Supplier controls include `ProductSelector`, `RetailPriceInput`,
  `AutomaticCollection`, `HappinessBar`, and `PayOvertimeButton`.

Current world coordinates worth checking before moving furniture:
- Entrance center: (-3, 0.1, 2.5); room rear: z = -7.5.
- Cashier job point: (-2.5, 0.1, -0.6).
- Counter: (-2.5, 0.6, 0.4); queue head: (-2.5, 0.1, 1.2).
- Next queue slots: x = -3.35 and -4.2, same z = 1.2.
- Bottle rack interaction: (-4.6, 0.1, -0.5).
- Snack/soap rack interaction: (-4.6, 0.1, -3.3 / -6.0).
- Delivery pickup: (-6.8, 0.1, 3.5).
- Character model forward is local -Z; cashier faces the customers with yaw PI.

Geometry helper `_box()` can create a mesh and a separate sibling static body
named `<meshName>Body`. Move/resize BOTH mesh and collision when changing room
geometry. Godot sanitizes names containing dots; use `validate_node_name()` when
addressing generated names such as `SideWall-3.0`.

## 8. How to Implement the Next Task Properly

1. Read this file and the user's latest request. Newer requests override older
   plans, especially room-size and manual/automatic stocking decisions.
2. Inspect relevant scripts, scene references, and tests. Check local changes.
3. State the task's scope and expected behavior before editing.
4. Implement authoritative rules in the existing backend/module first; add
   guards for funds, stock, shift state, duplicate actions, and invalid inputs.
5. Connect physical objects/NPC states and UI through existing methods/signals.
   Keep management and checkout PCs separate.
6. If persistent state changes, increment the schema version, provide migration,
   preserve accounting/inventory invariants, and test old saves.
7. Add focused tests; run the broader suite for shared/backend/scene changes.
8. Use temporary save paths, then inspect graphical previews where visuals change.
9. Explain files/nodes changed, test results, and any unfinished limitations.
10. Update this file: current status, completed systems, limits, verification,
    next recommendation, and a dated history entry. Do this BEFORE final handoff.

Never mark a feature complete only because its UI exists. Complete means backend,
physical gameplay, UI, save behavior where relevant, and verification agree.

## 9. Verification and Testing

Last full game verification: 2026-10-11, all 17 tests passed, zero script or
assertion errors. Fresh headless logs: Windows TEMP/<test-name>-audit.log.
The seven previously unfinished tests also passed individually as *-recheck.log.
No graphical tests were rerun for this verification-only task; the following
graphical checks refer to the earlier implementation milestones.
Graphical tablet and employee-action tests passed; desktop and portrait images
inspected. Tablet test checks nonblank viewport pixels, screen framing, real mouse
clicks, all tabs, labels, input drafts and close keys. Employee test checks both role
layouts, independent job pauses, scanning/payment pause, box resume and save loading.
Windows headless certificate-store warning is unrelated to gameplay.

The suite contains:
`business_backend_test.gd`, `bargaining_test.gd`, `character_visual_test.gd`,
`day_night_test.gd`, `neighbourhood_test.gd`, `shop_hours_test.gd`,
`shop_upgrade_test.gd`, `ui_visual_test.gd`, `physical_shop_test.gd`,
`checkout_test.gd`, `staff_test.gd`, `shop_space_test.gd`,
`employee_life_test.gd`, `product_workflow_test.gd`, `tablet_test.gd`,
`employee_actions_test.gd`, `notification_test.gd` in `tests/`.

Run all tests from the project directory in PowerShell:

```powershell
$godot = 'C:\Users\Lenovo\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
Get-ChildItem tests -Filter '*_test.gd' | ForEach-Object {
    $log = Join-Path $env:TEMP ($_.BaseName + '-verification.log')
    Start-Process -FilePath $godot -ArgumentList @(
        '--headless', '--path', '.', '--script', ('res://tests/' + $_.Name),
        '--quit-after', '1200', '--log-file', $log
    ) -WindowStyle Hidden -Wait
    Write-Output $_.Name
    Select-String -LiteralPath $log -Pattern 'PASS:|SCRIPT ERROR:|Assertion failed'
}
```

Require a PASS and no script/assertion errors in EACH log. Exit code alone is
insufficient; an assertion in an awaited helper can fail while later code prints
PASS. `Start-Process -Wait` avoids reading logs before Godot has finished.

For graphical previews, remove `--headless` and run the employee/product tests.
Follow the active environment's permission rules for launching GUI programs.
Screenshots and test saves go to the Windows TEMP directory, not the owner's save.
Preview files include `employee_live_scan.png`, `employee_overtime_pay.png`,
`products_orders.png`, `products_racks.png`, and `products_indoor_queue.png`.
TEMP previews are disposable, not permanent project assets.

Known test-environment noise: headless Godot can print
`Failed to read the root certificate store.` This is separate from script errors.
Legacy tests sometimes disable `ShopOperations` intentionally. Do not disable
the actual physical shop to make those fixtures pass.

Manual acceptance checks:
1. Load existing progress; confirm money/ownership/staff persist. Do not delete save.
2. Walk/look outdoors and enter the shop/home; confirm camera switches and collision.
3. Order each product at management PC; verify money changes but shelf stock does not.
4. Wait for delivery; pick up and stock the correct rack. Wrong rack must not stock it.
5. Hire Sunil, set hours, assign a box; then test automatic collection ON and OFF.
6. Watch three customers take products and queue indoors without duplicate reservations.
7. Scan manually and with different cashier levels; check total, bargain, payment/change.
8. At shift end test leaving, overtime, owed payment, daily conversation and happiness.
9. Check doors, sounds, Close/Escape, menu movement lock, sleep, and save/reload.
10. E in the shop opens the held tablet; E, Enter, Escape or X puts it away.
    Enter commits an edited sale price before closing. Mouse look/movement stay locked.
11. Look at a nearby employee indoors and press E: Staff opens with that person
    selected, ahead of checkout interaction. Box pickup/shelving retains priority.
12. Toggle Work OFF/ON separately for cashier and stock assistant. OFF pauses jobs,
    not employment, wages, scheduled hours or shift-end conversations. A paused box
    stays with Sunil and resumes correctly; no automatic stock creation occurs.
13. Sunil starts with manual collection: use Collect delivery after a box arrives,
    or explicitly enable Auto collect deliveries. He never purchases stock himself.
    Waiting for delivery, delivery ready, restocking, off shift, unpaid wages and
    owner-paused states distinguish why he is not working. Talk opens existing dialogue.

## 10. Remaining Limitations and Demo Priorities

These are recommendations, NOT completed work or authorization to implement all:

1. Owner playtest and bug fixing of the current complete retail loop first.
2. Improve physical scanning feel, customer spacing/routes, and readable shelf
   signage without breaking transaction guards.
3. Improve character proportions/animations, interior lighting/materials, and
   UI presentation together as a small visual-polish milestone.
4. Add a short demo objective/progression and clear feedback for why a customer
   or employee is waiting. Agree the objective with the owner before implementing.
5. Balance prices, bargaining, wages, marketing, and day length through playtests.
6. Add settings, audio volume controls, pause behavior, and demo onboarding.
7. Test packaging/export, save compatibility, performance, and a complete new-player
   session before calling it a release-ready demo.
8. Only after the demo works, expand into more roles, mixed baskets, multiple
   businesses, family, vehicles, and deeper life systems.

Current limitations to remember:
- Fixed waypoint routes, not navigation-mesh avoidance or a general crowd system.
- Only three product types, one outstanding box, one product type per basket.
- Current character/product/world assets and sounds are placeholders.
- Conversation branches are scripted and employee names/roles are fixed.
- Room is fully available; no new paid floor-space purchase mechanic is active.
- A three-customer indoor queue is verified, not arbitrary crowd sizes.
- No confirmed demo objective, final balance, store integration, or export verification.
- This memory file requires explicit updates by the working AI.
- Only the shop management menu is on the held tablet; management-PC, checkout,
  home and conversation overlays remain separate. Placeholder hands are not rigged.
- Employee targeting is a close-range camera aim test, not a general interactable
  raycast system. Fixed roles/names and existing physical routes remain unchanged.

## 11. Task History and Next Handoff

Earlier completed milestones (sequence reconstructed from discussion and files;
individual completion dates are not recorded here):
1. Movement, shop E interaction, buy stock, money/stock labels and closing menu.
2. Customers purchasing stock and leaving.
3. Sales/revenue/expenses, prices, missed sales and bargaining.
4. Marketing, hiring, wages and saving.
5. Home ownership, indoor camera, sleeping, clock/day-night.
6. Low-poly characters and reorganized shop/HUD UI.
7. Physical shop, separate PCs, delivery boxes, shelves, queue and per-item checkout.
8. Employee levels/hours, staff orientation/name tags and taller shop.

2026-10-11 - Latest verified gameplay milestone:
- Added product catalog, employee relations/dialogue, sliding door and sound scripts.
- Integrated product-specific ordering/manual stocking/optional Sunil collection,
  full starting room, indoor queue, larger dynamic checkout monitor and payment props.
- Updated backend save format to 10 and legacy migrations/validation.
- Added `employee_life_test.gd` and `product_workflow_test.gd`; updated backend,
  checkout, physical-shop, upgrade, space and staff regression fixtures.
- All 14 tests passed; graphical previews passed. Tests used temporary saves.
- Existing node names were retained; this latest gameplay milestone changed scripts,
  not scene files. Runtime nodes are created by those scripts.

2026-10-11 - Memory handoff task:
- Added ONLY `PROJECT_MEMORY.md` after inspecting current scripts/scenes and logs.
- No gameplay scripts, scenes, project settings, or player saves changed for this task.
- Next action: owner chooses/tests the next feature or polish task; do not silently
  start implementing the entire long-term roadmap.

2026-10-11 - Held tablet and employee work actions (COMPLETE):
- Added shop_tablet.gd and tests/tablet_test.gd, tests/employee_actions_test.gd.
- Edited game_ui.gd: light readable tablet layout, role selector, real work switches,
  delivery assignment/automatic collection and talk actions; compact controls stacked.
- Edited shop_operations.gd: aimed nearby employee interaction/hint before checkout,
  after physical box actions. No scene nodes renamed or scene files changed.
- Edited business_backend.gd: validated set_employee_work and role job guards.
- Edited employee_relations.gd: optional boolean work_enabled in each saved employee
  record, true by default; restore supplies it for older saves. Save version remains
  10 because this is a backward-compatible optional field. Invalid non-booleans rejected.
- Edited stock_worker.gd: pausing work does not clear an overtime/assigned box route.
- Updated this PROJECT_MEMORY.md. Player movement/camera scripts untouched.
- All 16 headless scripts passed on final code. Graphical tablet/employee tests passed
  with screenshots and layout checks; one earlier graphical click assertion failed
  during concurrent testing, isolated rerun passed. Owner playtest remains important.
- Tests use temporary fixture saves, never the owner's real save.
- No broader product, hiring, shift or conversation redesign was added in this task.
- Next recommendation: owner tests this interaction flow before further features.

2026-10-11 - Complete remaining tests and check for regressions (COMPLETE):
- Inspected project memory, notification implementation, product workflow test
  and temporary-save usage before running tests.
- Reran product_workflow, shop_hours, shop_space, shop_upgrade, staff, tablet and
  ui_visual individually: all seven passed. Earlier Windows stall did not recur.
- Reran all 17 test scripts sequentially using Godot 4.7.2 headless with
  --quit-after 700. Inspected every audit log: all include PASS, with no script,
  parse or assertion errors. Certificate-store warning remains environment noise.
- Coverage includes movement/camera/menu locks, money/stock transactions,
  three products, physical deliveries/Sunil, checkout/payment/bargaining,
  employee shifts/overtime/work switches, notifications, save migration/recovery,
  time/sleep, shop upgrades, collision/world, characters and responsive UI bounds.
- Edited ONLY PROJECT_MEMORY.md to record results and correct outdated handoff
  references. No confirmed test failure required a gameplay or test-script change.
- No scene/node, stock_worker.gd, backend or save-schema changes. Owner progress
  was not used: tests use temporary fixture saves. All test processes completed.
- No new graphical screenshots generated in this audit; earlier previews remain
  implementation evidence, not proof of a fresh manual playtest.
- Recommended next step: owner plays one complete order/delivery/stock/checkout/
  employee-request loop before agreeing the next demo feature.

Template to fill in after every future task:

```text
Date:
User-requested task:
Status: COMPLETE / PARTIAL / BLOCKED
Implemented behavior:
Files changed:
Nodes changed/added:
Backend and save/migration changes:
Tests run and actual results:
Screenshots/manual checks:
Known limitations or unfinished work:
Next agreed task (or recommendation, clearly labeled):
```
