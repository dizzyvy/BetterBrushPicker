Better Brush Picker
Author: Dizzy
Steam: https://steamcommunity.com/id/illMindOfDizzy/

BETTER BRUSH PICKER — BUILD 42
Version 0.2.1

WHAT THIS VERSION DOES
- Replaces the vanilla Brush Tool tile picker window.
- Builds an index of individual tiles/sprites instead of requiring a tilesheet first.
- Shows visual tile results in a scrollable grid.
- Searches individual tile IDs plus tileset names and available sprite metadata.
- Includes broad aliases for common searches such as chair, fridge, window, door, wall, table, bed, toilet, sink, etc.
- Keeps the vanilla ISBrushToolTileCursor for actual tile placement/dragging.
- Adds category filters.
- The tile index is built gradually after the game starts to avoid a large one-time freeze.

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

V0.2 LIMITATION
The game does not provide a universal natural-language name like "red kitchen chair" for every individual sprite. Search therefore combines the exact tile ID, tileset name, category, available sprite metadata, and broad semantic aliases. Later versions can add more exact per-tile tagging.

DEBUGGING
If the window still shows the old vanilla "Tiles" interface, quit the game and send the relevant portion of:
~/Zomboid/console.txt

Do not delete the old version until the new version is confirmed working.
