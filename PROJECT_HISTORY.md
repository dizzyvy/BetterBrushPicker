# Better Brush Picker — Complete Project History

Project: BetterBrushPicker / Better Brush Picker
Author: Dizzy
Game: Project Zomboid Build 42
Latest development build: v0.6.0

## Repository purpose

This repository is the continuity/archive record for the Better Brush Picker development session. The root contains the newest development build. The versions directory contains every build artifact currently available in the development workspace, including alternate, safe, cache, fixed, direct-enumeration, and diagnostic builds.

The exact ZIP artifacts are retained rather than replacing older experiments with later revisions. This matters because several revisions document approaches that were tested and then deliberately rejected.

## User development requirements

- Beginner-friendly implementation and explanations are required.
- Project Zomboid APIs and behavior must be researched and verified rather than guessed.
- Vanilla B42 Lua/engine behavior and actual console logs are primary evidence.
- A build must not be described as runtime-proven until it has been tested in-game.
- GitHub can be treated as an archive, but the chat/development record remains the primary source when repository contents lag behind the actual session.

## Target features

- Search tiles by useful terms such as chair, fridge, window, wall, door, table, and bed.
- Individual tile visual browser rather than only selecting a whole tilesheet first.
- Categories: furniture, walls, floors, decor, doors, windows, plants, roofs, other.
- Favorites and recent tiles.
- Sorting and tileset filters.
- Resizable UI.
- Keyboard navigation later.
- Reuse the vanilla brush placement/cursor system.
- Persistent tile indexing/cache across launches.
- Efficient enumeration of actual tile definitions.

## Verified vanilla B42 findings

The vanilla brush tool uses BrushToolManager, BrushToolChooseTileUI, BrushToolTilePickerList, and ISBrushToolTileCursor. The normal selection path constructs ISBrushToolTileCursor with the selected tile name and then activates it with getCell():setDrag.

The vanilla tile picker renders eight columns and up to 256 rows, forming tile IDs from a tilesheet/image name plus a numeric suffix. That 2048-slot behavior belongs to the vanilla UI; it was later removed as a hard validity restriction in Better Brush Picker because Build 42 tile-definition lists can expose additional numeric entries.

## Verified B42 tile enumeration findings

IsoWorld exposes getAllTiles(), getAllTiles(String filename), and getAllTilesName(). The direct Java HashMap keySet()/iterator path was tried through Lua/Kahlua and failed in the target build with an iterator-of-non-table error. The reliable route became getWorld():getAllTilesName() followed by getWorld():getAllTiles(filename).

Vanilla ISTilesPickerDebugUI.lua directly demonstrates getAllTilesName() with size()/get(i), which supported using that API route in the mod.

One development test environment reported 61,740 actual tile IDs across 515 definition lists with zero definition-list failures. This was a modded environment and should not be interpreted as a universal vanilla tile count.

## Engine texture findings

Research of B42/decompiled engine code established that ordinary tile-definition sprites are represented by IsoSprite objects managed by IsoSpriteManager. Relevant IsoSprite state includes texture, currentAnim, hasNoTextures(), getTextureForCurrentFrame(direction), and related frame accessors.

Texture.getTexture performs texture lookups, but earlier versions used texture probing too aggressively and a Mac test crashed during a large scan. Later versions therefore moved toward verifying actual IsoSprite state and avoided retaining huge numbers of Texture references.

## Development timeline

### v0.1.0
Initial diagnostic picker: search, categories, larger tile preview, exact tile name display, and vanilla brush cursor machinery.

### v0.1.1
Fixed load timing/hooking so the custom picker appeared reliably.

### v0.2.0
Moved to individual tile results with a visual grid. Added categories, broader search against IDs, tileset names and sprite metadata/aliases, and background indexing.

### v0.2.1
Early persistent caching. Fixed-range probing combined with texture/metadata work proved too expensive in a large modded environment; a Mac test later crashed around 39,000 actual tiles.

### v0.2.1-safe
Alternate safer build from the same development stage, preserved separately.

### v0.2.2-cache
Introduced burst-based indexing and persistent per-tileset caches so completed tilesets could survive a restart.

### v0.2.2-fixed
Follow-up cache/UI correction build.

### v0.2.3
Fixed a missing buildSearchText helper created during refactoring.

### v0.2.4
First direct-enumeration attempt through IsoWorld tile data. The initial Java iterator pattern failed through the Lua/Kahlua bridge.

### v0.2.5-direct-enumeration
Continued the direct-enumeration approach while changing how the Build 42 collections were consumed from Lua.

### v0.2.6-direct-enumeration
Switched to getAllTilesName plus getAllTiles(filename). The development environment found 61,740 actual IDs across 515 definition lists. A missing cache-prefix constant then caused a cache filename error involving a null value and PuffinsPosterBin2.txt.

### v0.2.7-fixed
Restored the cache prefix and tightened the persistent cache. A later log showed all 515 definition lists and 61,740 tiles loaded from cache. A tile-selection crash was reported afterward, but the supplied log contained no click-time exception.

### v0.2.8
Added stronger selection safety and a BBP_CACHE_6 invalidation while restricting numeric suffixes to the vanilla-style 0..2047 range. This revision subsequently exhibited an apparent freeze/infinite load during the large-index workflow.

### v0.2.9
Returned to the direct-enumeration base and fixed performance by using smaller bursts and eliminating full-dataset sorting during index completion and search-result generation. User confirmed this build as working. Cache generation was BBP_CACHE_7.

### v0.3.0
Kept the v0.2.9 indexing/cache path and centralized validation, selection, and result-building helpers.

### v0.3.1
Fixed UI text, cards, and scrolling presentation. A persistent thumbnail problem became clear: only the first eight rows displayed thumbnails while later rows were blank/black.

### v0.3.2
Adjusted scroll clamping. The thumbnail problem remained.

### v0.3.3
Adjusted the custom grid stencil/render path. The thumbnail problem remained.

### v0.4.0
Added favorites, recent tiles with a target of 50, persistent state, and All/Favorites/Recent controls.

### v0.4.1-diagnostic
Added viewport diagnostics. The measurements showed scrolling itself was functioning: around 61,740 results, seven columns, 8,820 rows, content/scroll height around 1.48 million pixels, and changing yScroll values. The later-row thumbnail problem therefore was not simply a scroll calculation issue.

### v0.4.2
Removed inheritance from vanilla BrushToolTilePickerList and based the custom grid directly on ISPanel. Thumbnail problem persisted.

### v0.4.3
Added tileset texture warmup. 515 tilesets were attempted and 463 returned a sheet texture. No BetterBrushPicker errors were observed, but later thumbnails remained blank.

### v0.4.4
Moved thumbnail resolution toward IsoSprite frame/texture access and warmed from actual tile-definition IDs.

### v0.4.5
Continued thumbnail-resolution iteration.

### v0.4.6
Continued thumbnail-resolution iteration and packaging.

### v0.5.0
Further UI/index integration iteration leading into the native list rebuild.

### v0.5.1
Ground-up gallery rebuild using native ISScrollingListBox. Eight tiles per row, visible white card borders, search/category filtering, persistent index, and vanilla ISBrushToolTileCursor placement.

### v0.5.2
Used getTexture plus IsoSprite frame-loading fallbacks and a bounded thumbnail cache. Later analysis determined LoadFrameExplicit and LoadFramesNoDirPageSimple mutate sprite state and are not appropriate normal browsing operations.

### v0.6.0
Rebuilt the tile data layer around B42-loaded IsoSprite objects. Added BBP_CACHE_8 and a definition fingerprint; verifies candidates through IsoSprite; removes the hard 0..2047 restriction; deduplicates tile IDs; uses existing IsoSprite texture/frame state for thumbnails; removes LoadFrameExplicit and LoadFramesNoDirPageSimple from browsing; keeps native ISScrollingListBox and vanilla brush cursor; adds raw/verified/rejected/duplicate/cache/thumbnail statistics.

## v0.6.0 implementation details

Cache constants:
- CACHE_PREFIX = BetterBrushPicker_v060_tileset_
- CACHE_HEADER = BBP_CACHE_8
- TILES_PER_BURST = 96

Enumeration:
- getWorld():getAllTilesName()
- getWorld():getAllTiles(definitionName)
- stripped-base fallback for definition names
- fingerprint contains count plus four sampled IDs
- no global completion sort
- per-definition rows retained for cache writing
- duplicate IDs suppressed through indexSeen

Verification:
- candidate must have underscore-plus-digits suffix
- getSprite(tileName) must succeed
- IsoSprite hasNoTextures must report usable texture state
- missing-tile textures are rejected
- existing directional frame textures are checked as a fallback

Thumbnail resolution:
- getSprite(id) first
- sprite.texture first
- existing directional frame texture second
- getTexture(id) only as final fallback
- no LoadFrameExplicit
- no LoadFramesNoDirPageSimple
- bounded thumbnail cache of 768 entries

Selection:
- verify the tile first
- construct ISBrushToolTileCursor:new(spriteName, spriteName, character)
- activate through getCell():setDrag(cursor, playerNum)

UI:
- native ISScrollingListBox
- eight tiles per row
- white card outline
- search/category filters
- footer reports verified/indexing progress

## Current testing state

v0.6.0 was packaged and statically inspected, but it had not yet been runtime-tested by the user in B42.20.4 when this archive was created. The thumbnail fix is therefore a design hypothesis pending the next console log, not a proven result.

## Development constraints that should not regress

- Do not probe enormous arbitrary numeric ranges.
- Do not restore 0..2047 as a hard validity requirement.
- Do not use HashMap keySet()/iterator through Lua/Kahlua in the target build.
- Prefer getAllTilesName plus getAllTiles(filename).
- Avoid retaining huge Texture reference sets.
- Avoid whole-dataset sorting around the 61k-result scale.
- Do not use LoadFrameExplicit or LoadFramesNoDirPageSimple for ordinary thumbnail browsing.
- Preserve vanilla brush cursor placement.
- Use actual console.txt logs for runtime diagnosis.
