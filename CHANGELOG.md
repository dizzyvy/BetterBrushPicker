# Better Brush Picker Changelog

## v0.6.0
- Rebuilt the tile data layer around B42-loaded `IsoSprite` objects.
- Added `BBP_CACHE_8` with a definition fingerprint so the old unverified cache is not reused.
- Indexes only candidates whose current `IsoSprite` reports a real texture.
- Removed the artificial 0..2047 index limit.
- Deduplicates tile IDs across definition lists.
- Thumbnail rendering now reads `IsoSprite.texture` first and existing directional frames second.
- Removed thumbnail-time calls to `LoadFrameExplicit()` and `LoadFramesNoDirPageSimple()` so the picker no longer mutates engine sprite state while browsing.
- Added separate raw-candidate, verified, rejected, duplicate, cache, and thumbnail statistics.
- Kept the working native `ISScrollingListBox` gallery and vanilla brush cursor.

## v0.5.2
- Improved thumbnail resolution using IsoSprite:LoadFrameExplicit() as the primary fallback.
- Added current-frame and frame-0 sprite fallbacks plus direct sprite.texture fallback.
- Added a bounded 512-entry thumbnail cache.
- Selection now uses the same thumbnail resolver, so tiles loaded by the fallback remain selectable.
- Added resolver statistics to the console for diagnosis.

## v0.5.1
- Ground-up UI rebuild from the stable v0.2.9 indexing base.
- Removed the previous custom tile-grid scrolling/stencil implementation.
- Uses Project Zomboid's native `ISScrollingListBox` for gallery rows and scrolling.
- Eight tiles per row with visible white card borders.
- Search and category filtering retained.
- Vanilla `ISBrushToolTileCursor` retained for placement.
