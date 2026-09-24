# Development Changelog

This archive preserves the builds created during the development session, in chronological order.

## v0.1.0

Initial diagnostic / first picker UI build. Established the basic direction: search, categories, larger tile preview, exact tile name display, and use of the vanilla brush-tool cursor machinery.

## v0.1.1

Fixed the load timing / hook so the custom picker actually appeared reliably.

## v0.2.0

Moved to individual tile results with a visual grid. Added categories and broader search matching against tile IDs, tileset names, and sprite metadata/aliases. Began background indexing.

## v0.2.1

Added an early persistent-caching approach. The first implementation probed tiles in fixed ranges and performed texture/metadata work during indexing. This proved too expensive in a large modded setup.

### v0.2.1-safe

Alternate safer build from the same development stage, preserved separately rather than replacing the original v0.2.1 archive.

## v0.2.2-cache

Introduced burst-based indexing and persistent per-tileset caches. Completed tilesets could be written to disk so indexing could resume across game launches.

## v0.2.2-fixed

Follow-up fix build correcting issues in the v0.2.2 cache implementation and UI refactor.

## v0.2.3

Fixed the missing `buildSearchText()` helper that had been removed during refactoring while still being called by the indexer/search path. Also corrected the accompanying wording typo.

## v0.2.4

Attempted direct tile enumeration through the Build 42 `IsoWorld:getAllTiles()` data instead of probing a large unused slot space. The initial implementation used a Java iterator pattern that did not work correctly through the game's Lua/Kahlua bridge.

## v0.2.5-direct-enumeration

Continued the direct-enumeration approach while correcting the enumeration strategy for Build 42's Lua-accessible collections.

## v0.2.6-direct-enumeration

Switched to the verified Build 42 pattern using `getAllTilesName()` followed by `getAllTiles(filename)`. The build successfully found **61,740 actual tile IDs across 515 tilesets** in the test environment. A missing cache-prefix constant then caused a cache filename error.

## v0.2.7-fixed

Restored the cache prefix and tightened the persistent cache format/naming. The test log showed all **515 tilesets / 61,740 tiles** loading from the persistent cache on the next run.

## v0.2.8

Added additional selection safety and cache invalidation while limiting indexed IDs to the atlas-style numeric slot range used by the vanilla picker.

## v0.2.9

Reduced the amount of work performed at scan completion and during search-result generation, with smaller indexing bursts, to address the main-thread freeze observed when processing the large indexed result set.

## Important archive note

The version archive contains every build that was present in the development workspace, including builds with suffixes such as `-safe`, `-cache`, `-fixed`, and `-direct-enumeration`. These are intentionally preserved rather than silently deduplicated.
