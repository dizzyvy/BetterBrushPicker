Better Brush Picker
Author: Dizzy
Steam: https://steamcommunity.com/id/illMindOfDizzy/

BETTER BRUSH PICKER — BUILD 42
Version 0.2.4

WHAT THIS VERSION DOES
- Replaces the vanilla Brush Tool tile picker window.
- Builds an index of individual tiles/sprites instead of requiring a tilesheet first.
- Shows visual tile results in a scrollable grid.
- Searches individual tile IDs plus tileset names, categories, and semantic aliases.
- Includes broad aliases for common searches such as chair, fridge, window, door, wall, table, bed, toilet, sink, etc.
- Keeps the vanilla ISBrushToolTileCursor for actual tile placement/dragging.
- Adds category filters.
- The tile index is built gradually after the game starts to avoid a large one-time freeze.

PERSISTENT DIRECT CACHE
- The full available tile catalog is still indexed.
- The scanner now uses IsoWorld:getAllTiles() / getAllTiles(filename) to enumerate actual tile IDs exposed by Build 42 instead of probing thousands of possible numeric slots.
- Scanning happens in bursts of up to 256 actual tile IDs per game tick.
- Each completed tileset is written to its own persistent cache file in the Project Zomboid user-data area.
- Cached tilesets are loaded on later launches instead of being rescanned.
- If the game crashes or closes during a scan, completed tilesets remain cached and the next launch resumes with the missing tilesets.
- Cache files use the BBP_CACHE_4 header because the index source changed from fixed-slot probing to direct enumeration.

V0.2.4 FIX
- Replaced the million-slot fixed scan with direct B42 tile-ID enumeration.
- Restored the searchable-text helper and added the token-matching helper used by the result search.
- Cache format bumped to BBP_CACHE_4 so older fixed-slot caches are not trusted as complete.
- The mod description and version metadata are synchronized to 0.2.4.

INSTALLATION (MAC)
1. Quit Project Zomboid.
2. Put the BetterBrushPicker folder directly in:
   ~/Zomboid/mods/
3. Enable Better Brush Picker in the Mods menu.
4. Start/load your world.
5. Open Debug -> Brush Tool -> Choose tile.
6. The window should say:
   Better Brush Picker — Individual Tiles

IMPORTANT
- Do NOT put the ZIP file itself in ~/Zomboid/mods/.
- Keep this folder named BetterBrushPicker.
- Keep the 42/ folder structure intact.
- Remove/replace older Better Brush Picker copies so that only the intended version is enabled.

DEBUGGING
If the window shows an error/debug screen, quit the game and send the relevant portion of:
~/Zomboid/console.txt

Do not delete working cache files unless a future release specifically asks you to clear them.
