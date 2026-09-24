BETTER BRUSH PICKER — Project Zomboid Build 42 — v0.1.1

WHAT THIS IS
------------
The first working test build of Better Brush Picker.
It improves the vanilla Brush Tool tile-picker window without replacing the actual Brush Tool
placement system.

WHAT IT ADDS
------------
- Larger tile-picker window.
- Search box for tileset/category keywords.
- Quick category buttons: All, Furniture, Walls, Floors, Decor, Doors, Windows, Plants, Roofs, Other.
- Clear category tags beside tileset names.
- Exact selected tile name shown at the bottom after clicking a tile.
- Vanilla ISBrushToolTileCursor is still used for placement.
- Vanilla [ and ] tile cycling remains untouched.

INSTALL
-------
1. Open your Project Zomboid user folder:
   ~/Zomboid/mods/

2. Put the entire "BetterBrushPicker" folder from this archive into that "mods" folder.

3. The important files should end up like this:

   ~/Zomboid/mods/BetterBrushPicker/common/mod.info
   ~/Zomboid/mods/BetterBrushPicker/42/mod.info
   ~/Zomboid/mods/BetterBrushPicker/42/media/lua/client/BetterBrushPicker/BetterBrushPicker.lua

4. Start Project Zomboid Build 42.

5. Open the Mods menu and enable "Better Brush Picker".

6. In a debug/admin game, open the Brush Tool Manager and click "Choose tile".

USING IT
--------
- Search terms such as: furniture, chair, seat, table, bed, wall, fence, floor, road, door,
  window, plant, tree, roof, sign, trash, fridge, sink, etc.
- Click a category button to narrow the tileset list.
- Click a tileset on the left.
- Click the desired tile in the large grid on the right.
- The normal Brush Tool cursor is equipped immediately.

IMPORTANT LIMITATION OF V0.1
-----------------------------
The search currently searches tileset names plus common category aliases. It does NOT yet
understand the visual contents of a tile. For example, "chair" can bring up furniture/seating
sheets, but it does not automatically know which numbered tile on that sheet is a chair.
That is intentional for the first test build: it keeps this version fast and safe while we
verify the UI and placement hook on your installation.

NEXT DEVELOPMENT STAGE
----------------------
After you confirm this build opens and places tiles correctly, the next version can add a true
individual-tile search/index, favorites, recently used tiles, and better visual filtering.

IF IT DOES NOT WORK
-------------------
Open:
   C:\Users\YOUR-WINDOWS-NAME\Zomboid\console.txt

Search for:
   [BetterBrushPicker]

Send me that section. Also tell me whether the mod appeared in the Mods menu and what happened
when you clicked Brush Tool Manager -> Choose tile.


V0.1.1 FIX
-----------
The installer now waits for the vanilla Brush Tool classes to exist before applying the UI hook.
This fixes the case where the mod is enabled but the Better Brush Picker window does not appear.
