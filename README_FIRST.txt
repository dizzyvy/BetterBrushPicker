BETTER BRUSH PICKER v0.6.0
Author: Dizzy

VERIFIED SPRITE INDEX REBUILD

This build keeps the working native ISScrollingListBox UI from v0.5.x but rebuilds the tile catalog around the IsoSprite objects Project Zomboid itself loads from tile-definition files.

The old unverified cache generation is intentionally ignored. A new BBP_CACHE_8 cache is generated.

A candidate is indexed only when B42's current IsoSprite reports a real texture. This prevents the picker from filling with definition entries that cannot be rendered.

Thumbnails use the texture already attached to the IsoSprite. The mod does not call LoadFrameExplicit() or LoadFramesNoDirPageSimple() during browsing, because those methods mutate sprite state and are not needed for ordinary tile-definition sprites.

The first run after upgrading may take some time while the verified index is built. Completed definition lists are cached and reused on later launches when their definition fingerprint still matches.

On startup, the console should contain:
[BetterBrushPicker] Installed v0.6.0 successfully.
[BetterBrushPicker] Verified index: cached rows are accepted only when their current IsoSprite has a real texture; new cache header BBP_CACHE_8.
