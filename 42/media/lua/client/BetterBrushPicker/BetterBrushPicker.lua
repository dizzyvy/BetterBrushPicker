-- Better Brush Picker
-- Build 42
-- Version 0.6.0
-- Author: Dizzy
--
-- v0.6.0 validates each candidate against the IsoSprite loaded by B42 and uses a new cache generation so older unverified entries cannot re-enter the picker.
-- v0.5.1 is a ground-up UI rebuild: the gallery uses native ISScrollingListBox rows.
-- v0.6.0 rebuilds the tile index around B42-loaded IsoSprite objects and invalidates the older unverified cache.
-- The picker no longer requires the
-- user to choose a tilesheet before browsing results. Search results are
-- individual sprite/tile IDs and selection still uses the vanilla
-- ISBrushToolTileCursor.

local BetterBrushPicker = {}
BetterBrushPicker.installed = false
BetterBrushPicker.indexReady = false
BetterBrushPicker.indexBuilding = false
BetterBrushPicker.index = {}
BetterBrushPicker.tilesets = {}
BetterBrushPicker.activeCategory = "All"
BetterBrushPicker.lastSearch = ""
BetterBrushPicker.indexState = nil

-- Persistent cache and incremental work settings.
local CACHE_PREFIX = "BetterBrushPicker_v060_tileset_"
local CACHE_HEADER = "BBP_CACHE_8"
local TILES_PER_BURST = 96

BetterBrushPicker.categories = {
    "All", "Furniture", "Walls", "Floors", "Decor", "Doors", "Windows", "Plants", "Roofs", "Other"
}

-- These aliases are deliberately broad. They supplement the actual sprite
-- and tileset names and will be refined in later versions with more exact
-- per-sprite semantic tagging.
BetterBrushPicker.aliases = {
    chair = "chair chairs seat seating stool bench furniture",
    couch = "couch sofa sofas loveseat seating furniture",
    sofa = "sofa sofas couch couches loveseat seating furniture",
    table = "table tables desk furniture",
    desk = "desk desks table furniture office",
    bed = "bed beds bedding furniture",
    dresser = "dresser dressers storage furniture",
    shelf = "shelf shelves shelving storage furniture",
    cabinet = "cabinet cabinets cupboard storage furniture",
    locker = "locker lockers storage",
    fridge = "fridge refrigerator refrigeration freezer appliance appliances",
    refrigerator = "fridge refrigerator refrigeration freezer appliance appliances",
    freezer = "fridge refrigerator refrigeration freezer appliance appliances",
    stove = "stove cooker oven cooking appliance appliances",
    oven = "oven stove cooker cooking appliance appliances",
    microwave = "microwave appliance appliances cooking",
    sink = "sink sinks bathroom plumbing fixture fixtures counter",
    toilet = "toilet toilets bathroom plumbing fixture fixtures",
    bathtub = "bathtub tub bathroom plumbing fixture fixtures",
    shower = "shower bathroom plumbing fixture fixtures",
    window = "window windows curtain curtains fixture fixtures",
    door = "door doors doorway frame gate fixture fixtures",
    wall = "wall walls brick wood stone clapboard fence fencing railing",
    floor = "floor floors ground street road sidewalk curb carpet wood tile stone gravel dirt grass",
    plant = "plant plants tree trees bush bushes flower flowers vine vines vegetation foliage",
    tree = "tree trees vegetation foliage",
    grass = "grass vegetation foliage floor",
    roof = "roof roofs snow roofcap",
    lamp = "lamp lighting light lights fixture fixtures",
    light = "lamp lighting light lights fixture fixtures",
    rug = "rug rugs carpet carpets floor",
    sign = "sign signs signage notice notices poster advertising",
}

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function contains(text, needle)
    return string.find(lower(text), lower(needle), 1, true) ~= nil
end

local function categoryFor(name)
    local n = lower(name)
    if contains(n, "door") or contains(n, "gate") then return "Doors" end
    if contains(n, "window") then return "Windows" end
    if contains(n, "roof") then return "Roofs" end
    if contains(n, "floor") or contains(n, "street") or contains(n, "curb") or contains(n, "blend") then return "Floors" end
    if contains(n, "wall") or contains(n, "fenc") or contains(n, "rail") then return "Walls" end
    if contains(n, "furniture") or contains(n, "appliance") or contains(n, "seating") or contains(n, "shelving")
        or contains(n, "storage") or contains(n, "counter") or contains(n, "sink") or contains(n, "bathroom")
        or contains(n, "bedding") or contains(n, "table") or contains(n, "desks") then return "Furniture" end
    if contains(n, "tree") or contains(n, "bush") or contains(n, "flower") or contains(n, "plant")
        or contains(n, "vegetation") or contains(n, "foliage") then return "Plants" end
    if contains(n, "sign") or contains(n, "notice") or contains(n, "overlay") or contains(n, "graffiti")
        or contains(n, "grime") or contains(n, "trash") or contains(n, "junk") or contains(n, "lighting")
        or contains(n, "light") or contains(n, "curtain") or contains(n, "rug") then return "Decor" end
    return "Other"
end

local function tileBaseName(fullName)
    local s = tostring(fullName or "")
    local base = s:match("^([^%.]+)")
    return base or s
end

local function isNumericTileId(tileName)
    local s = tostring(tileName or "")
    if s == "" then return false end
    local numericIndex = tonumber(s:match("_(%d+)$"))
    return numericIndex ~= nil and numericIndex >= 0
end

local function splitSearch(text)
    local tokens = {}
    for token in lower(text):gmatch("%S+") do
        table.insert(tokens, token)
    end
    return tokens
end

local function matchesTokens(searchText, tokens)
    if #tokens == 0 then return true end

    local text = lower(searchText)
    for i = 1, #tokens do
        local token = lower(tokens[i])
        local matched = string.find(text, token, 1, true) ~= nil

        if not matched then
            local aliasText = BetterBrushPicker.aliases[token]
            if aliasText ~= nil then
                for aliasToken in lower(aliasText):gmatch("%S+") do
                    if string.find(text, aliasToken, 1, true) ~= nil then
                        matched = true
                        break
                    end
                end
            end
        end

        if not matched then return false end
    end

    return true
end

local function buildSearchText(tileName, tilesetName, category, parent, spriteType)
    local text = lower(tostring(tileName or "") .. " " .. tostring(tilesetName or "") .. " " .. tostring(category or "") .. " " .. tostring(parent or "") .. " " .. tostring(spriteType or ""))

    -- Add semantic aliases based on the actual tileset name. These aliases
    -- improve searches such as "chair", "fridge", and "window" while each
    -- result remains the individual tile ID.
    local n = lower(tilesetName)
    if contains(n, "seating") then text = text .. " chair chairs seat seating stool bench couch sofa loveseat " end
    if contains(n, "bedding") then text = text .. " bed beds mattress bedding " end
    if contains(n, "refriger") then text = text .. " fridge refrigerator freezer appliance " end
    if contains(n, "cooking") then text = text .. " stove oven cooker microwave cooking appliance " end
    if contains(n, "bathroom") then text = text .. " toilet sink bathtub tub shower bathroom plumbing fixture " end
    if contains(n, "windows") then text = text .. " window windows curtain curtains " end
    if contains(n, "doors") then text = text .. " door doors doorway frame gate " end
    if contains(n, "tables") then text = text .. " table tables desk " end
    if contains(n, "shelving") then text = text .. " shelf shelves shelving storage " end
    if contains(n, "storage") then text = text .. " cabinet cupboard locker storage " end
    if contains(n, "lighting") then text = text .. " lamp light lighting fixture " end
    if contains(n, "plants") or contains(n, "vegetation") then text = text .. " plant tree bush flower vine vegetation foliage " end

    return text
end

local function uniqueTilesets()
    local result = {}
    local seen = {}
    local world = getWorld()

    -- Prefer the same definition-name list used by B42's direct tile API.
    local namesOk, names = pcall(function() return world:getAllTilesName() end)
    if namesOk and names ~= nil then
        for i = 0, names:size() - 1 do
            local imageName = tostring(names:get(i))
            local base = imageName:match("^([^%.]+)") or imageName
            if base ~= "" and not seen[base] then
                seen[base] = true
                table.insert(result, base)
            end
        end
    end

    -- Fallback only if the direct definition-name API returns nothing.
    if #result == 0 then
        local images = world:getTileImageNames()
        if images == nil then return result end
        for i = 0, images:size() - 1 do
            local imageName = tostring(images:get(i))
            local base = imageName:match("^([^%.]+)") or imageName
            if base ~= "" and not seen[base] then
                seen[base] = true
                table.insert(result, base)
            end
        end
    end

    table.sort(result)
    return result
end

-- Build a candidate queue from B42's loaded tile-definition lists.
-- The game exposes the definition names through getAllTilesName(), and the
-- individual tile-name lists through getAllTiles(filename). We then verify
-- each candidate against the IsoSprite already loaded by B42.
local function getTileDefinitionNames(world)
    local ok, names = pcall(function() return world:getAllTilesName() end)
    if not ok or names == nil then
        return nil, "IsoWorld:getAllTilesName() failed"
    end

    local sizeOk, size = pcall(function() return names:size() end)
    if not sizeOk or size == nil then
        return nil, "IsoWorld:getAllTilesName() returned an unusable list"
    end

    return names, nil
end

local function listValue(tileList, index)
    local ok, value = pcall(function() return tileList:get(index) end)
    if not ok or value == nil then return nil end
    local result = tostring(value)
    if result == "" or result == "nil" then return nil end
    return result
end

local function definitionFingerprint(tileList, count)
    if count == nil or count <= 0 then
        return "0||||"
    end

    local points = {
        0,
        math.floor((count - 1) / 3),
        math.floor(((count - 1) * 2) / 3),
        count - 1,
    }

    local samples = {}
    local seen = {}
    for i = 1, #points do
        local p = points[i]
        if p >= 0 and p < count and not seen[p] then
            seen[p] = true
            samples[#samples + 1] = listValue(tileList, p) or "?"
        end
    end

    return tostring(count) .. "|" .. table.concat(samples, "|")
end

local function spriteHasUsableTexture(sprite)
    if sprite == nil then return false end

    local noTextureOk, noTexture = pcall(function() return sprite:hasNoTextures() end)
    if not noTextureOk or noTexture then
        return false
    end

    -- Normal tile-definition sprites are loaded by IsoSpriteManager using
    -- IsoSprite:LoadSingleTexture(), which stores the texture in sprite.texture.
    -- Check that field first without mutating the sprite.
    local fieldOk, fieldTexture = pcall(function() return sprite.texture end)
    if fieldOk and fieldTexture ~= nil then
        local nameOk, texName = pcall(function() return fieldTexture:getName() end)
        if nameOk and texName ~= nil and contains(texName, "missing-tile") then
            return false
        end
        return true
    end

    -- A small number of sprites can use directional animation frames rather
    -- than sprite.texture.  Inspect the existing frames; do not call any load
    -- method here because loading/mutating the sprite would change engine state.
    local directions = {
        IsoDirections.N, IsoDirections.NE, IsoDirections.E, IsoDirections.SE,
        IsoDirections.S, IsoDirections.SW, IsoDirections.W, IsoDirections.NW
    }

    for i = 1, #directions do
        local dir = directions[i]
        if dir ~= nil then
            local texOk, texture = pcall(function()
                return sprite:getTextureForCurrentFrame(dir)
            end)
            if texOk and texture ~= nil then
                local nameOk, texName = pcall(function() return texture:getName() end)
                if not (nameOk and texName ~= nil and contains(texName, "missing-tile")) then
                    return true
                end
            end
        end
    end

    return false
end

local function spriteForTile(tileName)
    local ok, sprite = pcall(function() return getSprite(tileName) end)
    if ok and sprite ~= nil then
        return sprite
    end
    return nil
end

local function verifiedTile(tileName)
    if not isNumericTileId(tileName) then return false end
    local sprite = spriteForTile(tileName)
    if sprite == nil then return false end
    return spriteHasUsableTexture(sprite)
end

local function buildDirectTileLookup()
    local world = getWorld()
    local names, namesError = getTileDefinitionNames(world)
    if names == nil then
        print("[BetterBrushPicker] ERROR: " .. tostring(namesError))
        return nil, 0, 0
    end

    local queue = {}
    local seen = {}
    local rawTotal = 0
    local failedSets = 0
    local definitionCount = names:size()

    for i = 0, definitionCount - 1 do
        local nameOk, definitionName = pcall(function() return tostring(names:get(i)) end)
        if nameOk and definitionName ~= nil and definitionName ~= "" and definitionName ~= "nil" then
            local tileset = tileBaseName(definitionName)
            if tileset ~= "" and not seen[definitionName] then
                local listOk, tileList = pcall(function()
                    return world:getAllTiles(definitionName)
                end)

                if (not listOk or tileList == nil) and tileset ~= definitionName then
                    listOk, tileList = pcall(function()
                        return world:getAllTiles(tileset)
                    end)
                end

                if listOk and tileList ~= nil then
                    local sizeOk, size = pcall(function() return tileList:size() end)
                    if sizeOk and size ~= nil then
                        local count = size
                        local fingerprint = definitionFingerprint(tileList, count)
                        queue[#queue + 1] = {
                            tileset = tileset,
                            filename = definitionName,
                            tiles = tileList,
                            count = count,
                            fingerprint = fingerprint,
                            rows = {},
                        }
                        rawTotal = rawTotal + count
                    else
                        failedSets = failedSets + 1
                    end
                else
                    failedSets = failedSets + 1
                end

                seen[definitionName] = true
            end
        end
    end

    local imageCount = 0
    local imagesOk, images = pcall(function() return world:getTileImageNames() end)
    if imagesOk and images ~= nil then
        local sizeOk, size = pcall(function() return images:size() end)
        if sizeOk and size ~= nil then imageCount = size end
    end

    print(string.format(
        "[BetterBrushPicker] B42 sources: %d tile-definition lists, %d tile-image names, %d raw tile IDs.",
        #queue, imageCount, rawTotal
    ))
    print(string.format(
        "[BetterBrushPicker] The raw-ID count is only a candidate count; verified indexing will keep only loaded IsoSprites with real textures."
    ))

    return queue, rawTotal, failedSets
end

local function sanitizeFilePart(value)
    local s = tostring(value or "")
    s = s:gsub("[^%w%._%-]", "_")
    if s == "" then s = "unknown" end
    return s
end

local function cacheFileFor(definitionFilename)
    return CACHE_PREFIX .. sanitizeFilePart(definitionFilename) .. ".txt"
end

local function writeLine(writer, value)
    writer:write(tostring(value or "") .. "\n")
end

local function cacheRow(id, tileset)
    local category = categoryFor(tileset)
    return {
        id = id,
        name = id,
        tileset = tileset,
        category = category,
        parent = "",
        spriteType = "",
        searchText = buildSearchText(id, tileset, category, "", ""),
    }
end

local function readCacheFile(fileName, expectedFingerprint)
    local reader = getFileReader(fileName, false)
    if not reader then return nil end

    local header = reader:readLine()
    if header ~= CACHE_HEADER then
        reader:close()
        return nil
    end

    local metaLine = reader:readLine()
    if metaLine == nil or string.sub(metaLine, 1, 5) ~= "META|" then
        reader:close()
        return nil
    end

    local cachedFingerprint = string.sub(metaLine, 6)
    if expectedFingerprint ~= nil and cachedFingerprint ~= expectedFingerprint then
        reader:close()
        return nil
    end

    local rows = {}
    local seen = {}
    local line = reader:readLine()
    while line ~= nil do
        if line == "END" then
            reader:close()
            return rows
        end

        local id, tileset, category = line:match("^([^|]*)|([^|]*)|([^|]*)$")
        if id == nil or tileset == nil or category == nil or not isNumericTileId(id) or seen[id] then
            reader:close()
            return nil
        end

        seen[id] = true
        rows[#rows + 1] = {
            id = id,
            name = id,
            tileset = tileset,
            category = category,
            parent = "",
            spriteType = "",
            searchText = buildSearchText(id, tileset, category, "", ""),
        }

        line = reader:readLine()
    end

    reader:close()
    return nil
end

local function writeCacheFile(definitionFilename, fingerprint, rows)
    local fileName = cacheFileFor(definitionFilename)
    local writer = getFileWriter(fileName, true, false)
    if not writer then return false end

    writeLine(writer, CACHE_HEADER)
    writeLine(writer, "META|" .. tostring(fingerprint or ""))
    for i = 1, #rows do
        local result = rows[i]
        writeLine(writer, result.id .. "|" .. result.tileset .. "|" .. result.category)
    end
    writeLine(writer, "END")
    writer:close()
    return true
end

local function loadExistingCacheSets(tilesetQueue, failedDefinitions)
    local loaded = {}
    local missing = {}
    local loadedSeen = {}
    local cachedSets = 0
    local cachedTiles = 0

    for i = 1, #tilesetQueue do
        local entry = tilesetQueue[i]
        local rows = readCacheFile(cacheFileFor(entry.filename or entry.tileset), entry.fingerprint)
        if rows ~= nil then
            local validRows = {}
            for j = 1, #rows do
                local row = rows[j]
                if not loadedSeen[row.id] and verifiedTile(row.id) then
                    loadedSeen[row.id] = true
                    validRows[#validRows + 1] = row
                    loaded[#loaded + 1] = row
                end
            end
            if #validRows == #rows then
                cachedSets = cachedSets + 1
                cachedTiles = cachedTiles + #validRows
            else
                -- Don't partially trust a cache file. Rebuild the complete
                -- definition list when even one cached row no longer validates.
                for j = #loaded, 1, -1 do
                    local row = loaded[j]
                    if row ~= nil and row.tileset == entry.tileset and loadedSeen[row.id] then
                        loadedSeen[row.id] = nil
                        table.remove(loaded, j)
                    end
                end
                table.insert(missing, entry)
            end
        else
            missing[#missing + 1] = entry
        end
    end

    BetterBrushPicker.index = loaded
    BetterBrushPicker.tilesets = missing
    BetterBrushPicker.indexSeen = loadedSeen
    BetterBrushPicker.indexState = {
        tilesetIndex = 1,
        tileIndex = 0,
        added = #loaded,
        checked = 0,
        rawCandidates = 0,
        rejectedMissingTexture = 0,
        duplicates = 0,
        cached = cachedSets,
        cachedTiles = cachedTiles,
        totalTilesets = #tilesetQueue,
        totalRawTiles = 0,
        missingTilesets = 0,
        failedDefinitions = failedDefinitions or 0,
    }

    for i = 1, #tilesetQueue do
        BetterBrushPicker.indexState.totalRawTiles = BetterBrushPicker.indexState.totalRawTiles + (tilesetQueue[i].count or 0)
    end

    for i = 1, #missing do
        local count = missing[i].count or 0
        if count == 0 then
            BetterBrushPicker.indexState.missingTilesets = BetterBrushPicker.indexState.missingTilesets + 1
        end
    end

    print(string.format(
        "[BetterBrushPicker] Cache check: %d/%d definition lists accepted, %d cached verified tiles reused, %d lists require verification.",
        cachedSets, #tilesetQueue, cachedTiles, #missing
    ))

    return cachedSets > 0 or #missing == 0
end

local function finishIndex()
    local state = BetterBrushPicker.indexState
    BetterBrushPicker.indexBuilding = false
    BetterBrushPicker.indexReady = true

    print(string.format(
        "[BetterBrushPicker] VERIFIED INDEX READY: %d unique drawable tiles; raw candidates=%d; checked=%d; rejected(no texture)=%d; duplicates=%d; cached sets=%d.",
        state and state.added or #BetterBrushPicker.index,
        state and state.totalRawTiles or 0,
        state and state.checked or 0,
        state and state.rejectedMissingTexture or 0,
        state and state.duplicates or 0,
        state and state.cached or 0
    ))

    if BrushToolChooseTileUI ~= nil and BrushToolChooseTileUI.instance ~= nil then
        BrushToolChooseTileUI.instance:refreshResults()
    end
end

function BetterBrushPicker.startIndexBuild()
    if BetterBrushPicker.indexBuilding or BetterBrushPicker.indexReady then return end

    local tileQueue, rawTotal, failedSets = buildDirectTileLookup()
    BetterBrushPicker.index = {}
    BetterBrushPicker.tilesets = {}
    BetterBrushPicker.indexSeen = {}

    if tileQueue == nil then tileQueue = {} end
    loadExistingCacheSets(tileQueue, failedSets)

    if #tileQueue == 0 or rawTotal == 0 then
        BetterBrushPicker.indexBuilding = false
        BetterBrushPicker.indexReady = false
        BetterBrushPicker.indexState.error = "B42 returned no tile-definition candidates"
        print("[BetterBrushPicker] ERROR: no tile-definition candidates were returned; index build stopped.")
        return
    end

    if #BetterBrushPicker.tilesets == 0 then
        finishIndex()
        return
    end

    BetterBrushPicker.indexBuilding = true
    BetterBrushPicker.indexReady = false
    print(string.format(
        "[BetterBrushPicker] Verified sprite index build: %d definition lists remaining, %d candidates per burst.",
        #BetterBrushPicker.tilesets, TILES_PER_BURST
    ))
end

function BetterBrushPicker.tickIndexBuild()
    local state = BetterBrushPicker.indexState
    if not BetterBrushPicker.indexBuilding or state == nil then return end

    local budget = TILES_PER_BURST
    while budget > 0 and state.tilesetIndex <= #BetterBrushPicker.tilesets do
        local entry = BetterBrushPicker.tilesets[state.tilesetIndex]
        local tileset = entry.tileset
        local tileList = entry.tiles
        local tileCount = entry.count or 0

        if tileList == nil or state.tileIndex >= tileCount then
            local writeOk = writeCacheFile(entry.filename or tileset, entry.fingerprint, entry.rows or {})
            if writeOk then
                state.cached = (state.cached or 0) + 1
                print(string.format(
                    "[BetterBrushPicker] Verified/cache tileset %s: %d drawable tiles from %d candidates.",
                    tileset, #(entry.rows or {}), tileCount
                ))
            else
                print("[BetterBrushPicker] WARNING: could not write verified cache for " .. tostring(entry.filename or tileset))
            end

            state.tileIndex = 0
            state.tilesetIndex = state.tilesetIndex + 1
            break
        end

        local tileName = listValue(tileList, state.tileIndex)
        state.tileIndex = state.tileIndex + 1
        state.checked = state.checked + 1
        budget = budget - 1
        state.rawCandidates = (state.rawCandidates or 0) + 1

        if tileName == nil or not isNumericTileId(tileName) then
            state.rejectedMissingTexture = (state.rejectedMissingTexture or 0) + 1
        else
            local duplicate = false
            if BetterBrushPicker.indexSeen ~= nil and BetterBrushPicker.indexSeen[tileName] then
                duplicate = true
            end

            if duplicate then
                state.duplicates = (state.duplicates or 0) + 1
            elseif verifiedTile(tileName) then
                local result = cacheRow(tileName, tileset)
                BetterBrushPicker.indexSeen[tileName] = true
                entry.rows[#entry.rows + 1] = result
                BetterBrushPicker.index[#BetterBrushPicker.index + 1] = result
                state.added = state.added + 1
            else
                state.rejectedMissingTexture = (state.rejectedMissingTexture or 0) + 1
            end
        end
    end

    if state.tilesetIndex > #BetterBrushPicker.tilesets then
        finishIndex()
    end
end

BetterBrushPicker.indexSeen = {}

BetterBrushPickerTileRowList = ISScrollingListBox:derive("BetterBrushPickerTileRowList")

local TILE_COLUMNS = 8
local TILE_ROW_HEIGHT = 132
local TILE_GAP = 6

local thumbnailCache = {}
local thumbnailCacheOrder = {}
local THUMBNAIL_CACHE_LIMIT = 768
local thumbnailStats = { spriteTexture = 0, currentFrame = 0, directFallback = 0, missing = 0 }

local function cacheThumbnail(id, texture)
    thumbnailCache[id] = texture
    for i = #thumbnailCacheOrder, 1, -1 do
        if thumbnailCacheOrder[i] == id then
            table.remove(thumbnailCacheOrder, i)
            break
        end
    end
    table.insert(thumbnailCacheOrder, id)
    while #thumbnailCacheOrder > THUMBNAIL_CACHE_LIMIT do
        local oldId = table.remove(thumbnailCacheOrder, 1)
        thumbnailCache[oldId] = nil
    end
end

local function usableTexture(texture)
    if texture == nil then return false end
    local ok, name = pcall(function() return texture:getName() end)
    if ok and name ~= nil and contains(name, "missing-tile") then
        return false
    end
    return true
end

local function resolveTileTexture(tileName)
    local id = tostring(tileName or "")
    if id == "" then return nil end

    local cached = thumbnailCache[id]
    if cached ~= nil then return cached end

    -- The tile-definition loader creates the authoritative IsoSprite and loads
    -- its texture through Texture.getSharedTexture(). Use that already-loaded
    -- sprite first instead of global getTexture(), which follows a different
    -- texture-bucket path.
    local sprite = spriteForTile(id)
    if sprite ~= nil then
        local fieldOk, fieldTexture = pcall(function() return sprite.texture end)
        if fieldOk and usableTexture(fieldTexture) then
            thumbnailStats.spriteTexture = thumbnailStats.spriteTexture + 1
            cacheThumbnail(id, fieldTexture)
            return fieldTexture
        end

        local directions = {
            IsoDirections.N, IsoDirections.NE, IsoDirections.E, IsoDirections.SE,
            IsoDirections.S, IsoDirections.SW, IsoDirections.W, IsoDirections.NW
        }
        for i = 1, #directions do
            local dir = directions[i]
            if dir ~= nil then
                local ok, texture = pcall(function() return sprite:getTextureForCurrentFrame(dir) end)
                if ok and usableTexture(texture) then
                    thumbnailStats.currentFrame = thumbnailStats.currentFrame + 1
                    cacheThumbnail(id, texture)
                    return texture
                end
            end
        end
    end

    -- Last-resort fallback only; valid indexed tiles should normally have been
    -- resolved by their IsoSprite above.
    local directOk, directTexture = pcall(function() return getTexture(id) end)
    if directOk and usableTexture(directTexture) then
        thumbnailStats.directFallback = thumbnailStats.directFallback + 1
        cacheThumbnail(id, directTexture)
        return directTexture
    end

    thumbnailStats.missing = thumbnailStats.missing + 1
    return nil
end

local thumbnailSampleLogged = false
local function logThumbnailSample()
    if thumbnailSampleLogged then return end
    if #BetterBrushPicker.index == 0 then return end
    thumbnailSampleLogged = true
    local okCount = 0
    for i = 1, math.min(10, #BetterBrushPicker.index) do
        local id = BetterBrushPicker.index[i].id
        if resolveTileTexture(id) ~= nil then okCount = okCount + 1 end
    end
    print(string.format("[BetterBrushPicker] Thumbnail sample: %d/%d first indexed tiles resolved via IsoSprite texture paths.", okCount, math.min(10, #BetterBrushPicker.index)))
end

local function drawTileCard(self, result, x, y, cardW, cardH, selected, hovered)
    local alpha = hovered and 1.0 or 0.85
    -- White outline makes dark/empty tile cards visible.
    self:drawRectBorder(x, y, cardW, cardH, alpha, 1, 1, 1)
    if selected then
        self:drawRectBorder(x + 1, y + 1, cardW - 2, cardH - 2, 1.0, 1, 1, 1)
    end

    local texture = resolveTileTexture(result.id)
    if texture ~= nil then
        local maxW = cardW - 12
        local maxH = 88
        local tw = texture:getWidth()
        local th = texture:getHeight()
        local scale = 1.0
        if tw > maxW then scale = maxW / tw end
        if th * scale > maxH then scale = maxH / th end
        local dw = tw * scale
        local dh = th * scale
        self:drawTextureScaled(texture,
            x + (cardW - dw) / 2,
            y + 4 + (maxH - dh) / 2,
            dw, dh, 1, 1, 1, 1)
    else
        self:drawTextCentre("?", x + cardW / 2, y + 34, 1, 1, 1, 0.9, UIFont.Large)
    end

    local label = tostring(result.id or "")
    self:drawTextCentre(label, x + cardW / 2, y + 96, 1, 1, 1, 0.95, UIFont.Small)
end

function BetterBrushPickerTileRowList:new(x, y, w, h, character, owner)
    local o = ISScrollingListBox.new(self, x, y, w, h)
    o.character = character
    o.owner = owner
    o.itemheight = TILE_ROW_HEIGHT
    o.drawBorder = true
    o.backgroundColor = {r=0, g=0, b=0, a=0.55}
    o.items = {}
    o.count = 0
    o.selected = -1
    o.mouseoverselected = -1
    o.doDrawItem = function(list, yy, item, alt)
        if (yy + list:getYScroll() + TILE_ROW_HEIGHT < 0) or (yy + list:getYScroll() >= list.height) then
            return yy + TILE_ROW_HEIGHT
        end

        local innerW = list.width - (list.vscroll and list.vscroll.width or 0)
        local cardW = math.floor((innerW - TILE_GAP * (TILE_COLUMNS + 1)) / TILE_COLUMNS)
        if cardW < 60 then cardW = 60 end

        for col = 1, TILE_COLUMNS do
            local result = item.item[col]
            if result ~= nil then
                local xx = TILE_GAP + (col - 1) * (cardW + TILE_GAP)
                local selected = list.owner ~= nil and list.owner.selectedResult == result
                local hovered = (list.mouseoverselected == item.index and list:isMouseOver()) and list.hoveredColumn == col
                drawTileCard(list, result, xx, yy + TILE_GAP, cardW, TILE_ROW_HEIGHT - TILE_GAP * 2, selected, hovered)
            end
        end
        return yy + TILE_ROW_HEIGHT
    end
    return o
end

function BetterBrushPickerTileRowList:setResults(results)
    self:clear()
    print(string.format("[BetterBrushPicker] Thumbnail stats: spriteTexture=%d currentFrame=%d directFallback=%d missing=%d",
        thumbnailStats.spriteTexture, thumbnailStats.currentFrame, thumbnailStats.directFallback, thumbnailStats.missing))
    self.items = {}
    self.count = 0
    self.selected = -1

    local row = nil
    local col = 0
    for i = 1, #(results or {}) do
        if col == 0 then
            row = {}
            self:addItem("", row)
            col = 1
        else
            col = col + 1
        end
        row[col] = results[i]
        if col == TILE_COLUMNS then col = 0 end
    end

    self:setScrollHeight(math.max(self.height, #self.items * TILE_ROW_HEIGHT))
end

function BetterBrushPickerTileRowList:onMouseMove(dx, dy)
    if self:isMouseOverScrollBar() then
        self.hoveredColumn = nil
        return
    end
    self.mouseoverselected = self:rowAt(self:getMouseX(), self:getMouseY())
    local innerW = self.width - (self.vscroll and self.vscroll.width or 0)
    local cardW = math.floor((innerW - TILE_GAP * (TILE_COLUMNS + 1)) / TILE_COLUMNS)
    if cardW < 60 then cardW = 60 end
    local x = self:getMouseX() - TILE_GAP
    local col = math.floor(x / (cardW + TILE_GAP)) + 1
    if col >= 1 and col <= TILE_COLUMNS then
        self.hoveredColumn = col
    else
        self.hoveredColumn = nil
    end
end

function BetterBrushPickerTileRowList:onMouseMoveOutside(x, y)
    self.mouseoverselected = -1
    self.hoveredColumn = nil
end

function BetterBrushPickerTileRowList:onMouseDown(x, y)
    if #self.items == 0 then return end
    local rowIndex = self:rowAt(x, y)
    local rowItem = self.items[rowIndex]
    if rowIndex < 1 or rowItem == nil or rowItem.item == nil then return end

    local innerW = self.width - (self.vscroll and self.vscroll.width or 0)
    local cardW = math.floor((innerW - TILE_GAP * (TILE_COLUMNS + 1)) / TILE_COLUMNS)
    if cardW < 60 then cardW = 60 end
    local col = math.floor((x - TILE_GAP) / (cardW + TILE_GAP)) + 1
    if col < 1 or col > TILE_COLUMNS then return end

    local result = rowItem.item[col]
    if result == nil then return end

    self.selected = rowIndex
    if self.owner ~= nil then
        self.owner:selectTileResult(result)
    end
end

function BetterBrushPickerTileRowList:onMouseWheel(del)
    ISScrollingListBox.onMouseWheel(self, del)
    return true
end

local function install()
    if BetterBrushPicker.installed then return end
    if BrushToolChooseTileUI == nil or ISBrushToolTileCursor == nil or ISScrollingListBox == nil then
        return false
    end

    BetterBrushPicker.installed = true

    function BrushToolChooseTileUI.openPanel(x, y, playerObj)
        if y < 0 then y = 0 end
        if BrushToolChooseTileUI.instance == nil then
            local window = BrushToolChooseTileUI:new(x, y, 1180, 720, playerObj)
            window:initialise()
            window:addToUIManager()
            BrushToolChooseTileUI.instance = window
        end
    end

    function BrushToolChooseTileUI:createChildren()
        ISCollapsableWindow.createChildren(self)

        local th = self:titleBarHeight()
        self.selectedTileName = "No tile selected"
        self.selectedResult = nil

        self.searchEntryBox = ISTextEntryBox:new("", 10, th + 8, 450, 24)
        self.searchEntryBox.font = UIFont.Small
        self.searchEntryBox.onTextChange = BrushToolChooseTileUI.onTextChange
        self:addChild(self.searchEntryBox)

        local catY = th + 42
        local catX = 10
        local catW = 104
        for i = 1, #BetterBrushPicker.categories do
            local category = BetterBrushPicker.categories[i]
            local button = ISButton:new(catX, catY, catW, 24, category, self, BrushToolChooseTileUI.onCategoryClick)
            button.internal = category
            button:initialise()
            button:instantiate()
            self:addChild(button)
            catX = catX + catW + 5
        end

        local contentTop = catY + 32
        local footer = 42
        local tilesHeight = self.height - contentTop - footer

        self.tilesList = BetterBrushPickerTileRowList:new(10, contentTop, self.width - 20, tilesHeight, self.character, self)
        self.tilesList.anchorRight = true
        self.tilesList.anchorBottom = true
        self.tilesList:initialise()
        self.tilesList:instantiate()
        self.tilesList:addScrollBars()
        self:addChild(self.tilesList)

        BetterBrushPicker.startIndexBuild()
        self:refreshResults()
    end

    function BrushToolChooseTileUI:onTextChange()
        if BrushToolChooseTileUI.instance ~= nil then
            BrushToolChooseTileUI.instance.selectedResult = nil
            BrushToolChooseTileUI.instance:refreshResults()
        end
    end

    function BrushToolChooseTileUI:onCategoryClick(button)
        BetterBrushPicker.activeCategory = button.internal or "All"
        self.selectedResult = nil
        self:refreshResults()
    end

    function BrushToolChooseTileUI:refreshResults()
        if self.tilesList == nil then return end
        if not BetterBrushPicker.indexReady then
            self.tilesList:setResults({})
            self.selectedTileName = BetterBrushPicker.indexBuilding and "Indexing tiles..." or "Preparing index..."
            return
        end

        local searchText = self.searchEntryBox and self.searchEntryBox:getInternalText() or ""
        BetterBrushPicker.lastSearch = searchText
        local tokens = splitSearch(searchText)
        local category = BetterBrushPicker.activeCategory
        local results = {}

        for i = 1, #BetterBrushPicker.index do
            local result = BetterBrushPicker.index[i]
            if (category == "All" or result.category == category) and matchesTokens(result.searchText, tokens) then
                table.insert(results, result)
            end
        end

        self.currentResults = results
        self.tilesList:setResults(results)
        logThumbnailSample()
        if #results == 0 then
            self.selectedTileName = "No matching tiles"
        else
            self.selectedTileName = "Results: " .. tostring(#results) .. " (click a tile)"
        end
    end

    function BrushToolChooseTileUI:selectTileResult(result)
        if result == nil then return end
        local spriteName = tostring(result.id or "")
        if spriteName == "" then return end

        local character = self.character or getPlayer()
        if character == nil then return end

        if not verifiedTile(spriteName) then
            print("[BetterBrushPicker] Refusing tile with no verified IsoSprite texture: " .. spriteName)
            return
        end

        local cursorOk, cursor = pcall(function()
            return ISBrushToolTileCursor:new(spriteName, spriteName, character)
        end)
        if not cursorOk or cursor == nil then
            print("[BetterBrushPicker] Cursor creation failed for tile: " .. spriteName)
            return
        end

        local numOk, playerNum = pcall(function() return character:getPlayerNum() end)
        if not numOk or playerNum == nil then return end

        local dragOk = pcall(function()
            getCell():setDrag(cursor, playerNum)
        end)
        if not dragOk then return end

        self.selectedResult = result
        self.selectedTileName = spriteName
    end

    function BrushToolChooseTileUI:render()
        ISCollapsableWindow.render(self)
        local footerY = self.height - 30
        self:drawText("Selected: " .. tostring(self.selectedTileName or "None"), 10, footerY, 1, 1, 1, 0.95, UIFont.Small)

        local state = BetterBrushPicker.indexState
        local progress
        if BetterBrushPicker.indexReady and state ~= nil then
            progress = string.format("Verified %d tiles", state.added)
        elseif BetterBrushPicker.indexBuilding and state ~= nil then
            progress = string.format("Verifying: %d / %d", state.checked, state.totalRawTiles or 0)
        else
            progress = "Starting verified tile index..."
        end
        self:drawText(progress, self.width - 180, footerY, 1, 1, 1, 0.8, UIFont.Small)
    end

    function BrushToolChooseTileUI:close()
        BrushToolChooseTileUI.instance = nil
        self:setVisible(false)
        self:removeFromUIManager()
    end

    function BrushToolChooseTileUI:new(x, y, width, height, character)
        local o = ISCollapsableWindow.new(self, x, y, width, height)
        o:setResizable(true)
        o.title = "Better Brush Picker — Individual Tiles"
        o.character = character
        return o
    end

    print("[BetterBrushPicker] Installed v0.6.0 successfully.")
    print("[BetterBrushPicker] Version marker: BetterBrushPicker source v0.6.0")
    print("[BetterBrushPicker] Verified index: old cache generation is ignored; new cache header BBP_CACHE_8 is used.")
    print("[BetterBrushPicker] UI: native ISScrollingListBox rows, 8 tiles per row; thumbnail rendering uses already-loaded IsoSprite textures.")
    return true
end

local function tick()
    if not BetterBrushPicker.installed then
        install()
    end
    if BetterBrushPicker.installed then
        BetterBrushPicker.tickIndexBuild()
    end
end

local function onGameBoot()
    install()
    Events.OnTick.Add(tick)
end

Events.OnGameBoot.Add(onGameBoot)
