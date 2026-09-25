# Better Brush Picker

Project Zomboid Build 42 mod by **Dizzy**.

## v0.6.0 — Verified Sprite Index

This version keeps the working native scrolling UI from v0.5.x but rebuilds the tile data layer around the sprites Project Zomboid itself loaded from its tile-definition files.

### Core features
- Search individual tile IDs.
- Category filtering.
- Eight-tile visual rows.
- White tile-card outlines.
- Native Project Zomboid scrolling list.
- Vanilla brush cursor selection.
- Persistent verified tile cache.

### What changed
- Old `BBP_CACHE_7` / unverified caches are no longer used.
- New cache generation uses `BBP_CACHE_8` plus a definition fingerprint.
- Every new tile candidate is checked against the current `IsoSprite` loaded by B42.
- A tile is indexed only when its `IsoSprite` reports a real texture (`hasNoTextures() == false`).
- Thumbnail rendering reads the already-loaded sprite texture instead of trying to reconstruct textures with `LoadFrameExplicit()` or `LoadFramesNoDirPageSimple()`.
- The old artificial `0..2047` tile-index restriction is removed. The engine's tile-definition lists determine which indices exist.
- Duplicate tile IDs are removed.

### Expected first-run behavior
The first run after v0.6.0 will rebuild the verified index because it uses a new cache generation. The log separates raw candidate IDs from verified drawable tiles.

The goal is not to force an exact count. B42.20's official vanilla tile count is about 35,000; your runtime can contain additional tiles from active mods.

### Console markers
```text
[BetterBrushPicker] Installed v0.6.0 successfully.
[BetterBrushPicker] Verified index: cached rows are accepted only when their current IsoSprite has a real texture; new cache header BBP_CACHE_8.
```
