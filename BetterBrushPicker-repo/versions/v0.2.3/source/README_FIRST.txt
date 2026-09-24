Better Brush Picker
Author: Dizzy
Steam: https://steamcommunity.com/id/illMindOfDizzy/

BETTER BRUSH PICKER — BUILD 42
Version 0.2.3

WHAT THIS VERSION DOES
- Replaces the vanilla Brush Tool tile picker window.
- Builds an index of individual tiles/sprites instead of requiring a tilesheet first.
- Shows visual tile results in a scrollable grid.
- Searches individual tile IDs plus tileset names, categories, and semantic aliases.
- Includes broad aliases for common searches such as chair, fridge, window, door, wall, table, bed, toilet, sink, etc.
- Keeps the vanilla ISBrushToolTileCursor for actual tile placement/dragging.
- Adds category filters.
- The tile index is built gradually after the game starts to avoid a large one-time freeze.

PERSISTENT BURST CACHE
- The full available tile catalog is still scanned.
- Scanning happens in small bursts of 32 tile checks per game tick.
- Each completed tileset is written to its own persistent cache file in the Project Zomboid user-data area.
- Cached tilesets are loaded on later launches instead of being rescanned.
- If the game crashes or closes during a scan, completed tilesets remain cached and the next launch resumes with the missing tilesets.
- Indexing does not keep every texture loaded; tile existence is checked with getSprite(), while textures are requested when visible results are rendered.
- Cache files use the BBP_CACHE_2 header so a future cache-format change can invalidate them safely.

V0.2.3 FIX
- Restored the searchable-text helper used by both cache loading and live indexing.
- The helper is declared before either call site, preventing the nil-call error that occurred in v0.2.2.
- The mod description and version metadata are synchronized to 0.2.3.

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
