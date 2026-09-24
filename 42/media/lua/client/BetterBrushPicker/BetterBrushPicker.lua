-- Better Brush Picker
-- Build 42
-- Version 0.2.9
-- Author: Dizzy
--
-- v0.2.8 replaces the old fixed-slot probing scan with direct enumeration of the tiles exposed by IsoWorld:getAllTiles. Persistent per-definition-list caching is kept.
-- v0.2.9 avoids full-index and full-result sorting so completion does not block the game thread on ~61k entries.
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
local CACHE_PREFIX = "BetterBrushPicker_tileset_"
local TILES_PER_BURST = 128

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

local function isBrushTileId(tileName)
    local s = tostring(tileName or "")
    if s == "" then return false end
    local numericIndex = tonumber(s:match("_(%d+)$"))
    if numericIndex == nil then return false end
    return numericIndex >= 0 and numericIndex <= 2047
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

-- Build a direct queue from B42's actual tile-definition lists.
-- IMPORTANT: getAllTiles() returns a Java HashMap, but its keySet()/iterator()
-- methods are not exposed to Kahlua reliably in the target B42 build. The
-- public getAllTilesName() + getAllTiles(filename) route is safer here.
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

local function buildDirectTileLookup()
    local world = getWorld()
    local names, namesError = getTileDefinitionNames(world)
    if names == nil then
        print("[BetterBrushPicker] ERROR: " .. tostring(namesError))
        return nil, 0, 0
    end

    local queue = {}
    local seen = {}
    local totalDirectIds = 0
    local failedSets = 0
    local definitionCount = names:size()

    for i = 0, definitionCount - 1 do
        local nameOk, filename = pcall(function() return tostring(names:get(i)) end)
        if nameOk and filename ~= nil and filename ~= "" and filename ~= "nil" then
            -- Keep the exact filename returned by B42. Do not strip its
            -- extension before calling getAllTiles(filename).
            local tileset = tileBaseName(filename)
            if tileset ~= "" and not seen[tileset] then
                local listOk, tileList = pcall(function()
                    return world:getAllTiles(filename)
                end)

                -- Defensive fallback for builds where the list is keyed by
                -- the base name rather than the definition filename.
                if (not listOk or tileList == nil) and tileset ~= filename then
                    listOk, tileList = pcall(function()
                        return world:getAllTiles(tileset)
                    end)
                end

                local count = 0
                if listOk and tileList ~= nil then
                    local sizeOk, size = pcall(function() return tileList:size() end)
                    if sizeOk and size ~= nil then
                        count = size
                    else
                        listOk = false
                    end
                end

                seen[tileset] = true
                if listOk and tileList ~= nil then
                    table.insert(queue, {
                        tileset = tileset,
                        filename = filename,
                        tiles = tileList,
                        count = count,
                    })
                    totalDirectIds = totalDirectIds + count
                else
                    failedSets = failedSets + 1
                    print(string.format("[BetterBrushPicker] WARNING: could not enumerate tile IDs for %s", filename))
                end
            end
        end
    end

    print(string.format(
        "[BetterBrushPicker] Direct tile enumeration found %d actual tile IDs across %d tilesets (%d definition lists failed).",
        totalDirectIds, #queue, failedSets
    ))
    return queue, totalDirectIds, failedSets
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

local function readCacheFile(fileName)
    local reader = getFileReader(fileName, false)
    if not reader then return nil end

    local rows = {}
    local line = reader:readLine()
    if line ~= "BBP_CACHE_7" then
        reader:close()
        return nil
    end

    line = reader:readLine()
    while line ~= nil do
        if line == "END" then
            reader:close()
            return rows
        end
        local id, tileset, category = line:match("^([^|]*)|([^|]*)|([^|]*)$")
        if id and tileset and category and isBrushTileId(id) then
            table.insert(rows, {
                id = id,
                name = id,
                tileset = tileset,
                category = category,
                parent = "",
                spriteType = "",
                searchText = buildSearchText(id, tileset, category, "", ""),
            })
        else
            reader:close()
            return nil
        end
        line = reader:readLine()
    end

    reader:close()
    return nil
end

local function writeCacheFile(tileset, definitionFilename, rows)
    local fileName = cacheFileFor(definitionFilename or tileset)
    local writer = getFileWriter(fileName, true, false)
    if not writer then return false end

    writeLine(writer, "BBP_CACHE_7")
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
    local cachedSets = 0

    for i = 1, #tilesetQueue do
        local entry = tilesetQueue[i]
        local tileset = entry.tileset
        local rows = readCacheFile(cacheFileFor(entry.filename or tileset))
        if rows then
            for j = 1, #rows do table.insert(loaded, rows[j]) end
            cachedSets = cachedSets + 1
        else
            table.insert(missing, entry)
        end
    end

    BetterBrushPicker.index = loaded
    BetterBrushPicker.tilesets = missing
    BetterBrushPicker.indexState = {
        tilesetIndex = 1,
        tileIndex = 0,
        added = #loaded,
        checked = 0,
        cached = cachedSets,
        totalTilesets = #tilesetQueue,
        totalActualTiles = 0,
        missingTilesets = 0,
        failedDefinitions = failedDefinitions or 0,
    }

    for i = 1, #missing do
        local count = missing[i].count or 0
        BetterBrushPicker.indexState.totalActualTiles = BetterBrushPicker.indexState.totalActualTiles + count
        if count == 0 then BetterBrushPicker.indexState.missingTilesets = BetterBrushPicker.indexState.missingTilesets + 1 end
    end

    if cachedSets > 0 then
        print(string.format("[BetterBrushPicker] Loaded %d cached tilesets (%d tiles); %d tilesets remain for direct enumeration.", cachedSets, #loaded, #missing))
    end

    return cachedSets > 0 or #missing == 0
end

local function finishIndex()
    local state = BetterBrushPicker.indexState
    BetterBrushPicker.indexBuilding = false
    BetterBrushPicker.indexReady = true
    print(string.format("[BetterBrushPicker] Full index ready: %d individual tiles checked=%d; cached sets=%d (no final global sort).",
        state and state.added or #BetterBrushPicker.index,
        state and state.checked or 0,
        state and state.cached or 0))

    if BrushToolChooseTileUI ~= nil and BrushToolChooseTileUI.instance ~= nil then
        BrushToolChooseTileUI.instance:refreshResults()
    end
end

function BetterBrushPicker.startIndexBuild()
    if BetterBrushPicker.indexBuilding or BetterBrushPicker.indexReady then return end

    local allTilesets = uniqueTilesets()
    local tileQueue, directTotal, failedSets = buildDirectTileLookup()
    BetterBrushPicker.index = {}
    BetterBrushPicker.tilesets = {}

    if tileQueue == nil then
        tileQueue = {}
    end

    loadExistingCacheSets(tileQueue, failedSets)

    if (#tileQueue == 0 or directTotal == 0) and #allTilesets > 0 then
        BetterBrushPicker.indexBuilding = false
        BetterBrushPicker.indexReady = false
        BetterBrushPicker.indexState.error = "B42 did not return usable tile IDs through IsoWorld:getAllTiles(filename)"
        print("[BetterBrushPicker] ERROR: direct tile enumeration returned zero usable IDs. Scan stopped; no empty caches were intentionally generated.")
        return
    end

    if #BetterBrushPicker.tilesets == 0 then
        BetterBrushPicker.indexReady = true
        BetterBrushPicker.indexBuilding = false
        BetterBrushPicker.indexState.cached = #allTilesets
        BetterBrushPicker.indexState.totalTilesets = #allTilesets
        print(string.format("[BetterBrushPicker] All %d tilesets loaded from persistent cache.", #allTilesets))
        return
    end

    BetterBrushPicker.indexBuilding = true
    BetterBrushPicker.indexReady = false
    print(string.format("[BetterBrushPicker] Direct index build/resume: %d tilesets remaining, %d actual tile IDs per burst.", #BetterBrushPicker.tilesets, TILES_PER_BURST))

    if (BetterBrushPicker.indexState.failedDefinitions or 0) > 0 then
        print(string.format("[BetterBrushPicker] WARNING: %d definition lists could not be enumerated and were skipped; no empty cache was written for them.", BetterBrushPicker.indexState.failedDefinitions))
    end
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
            local rows = {}
            local prefix = tileset .. "_"
            for i = #BetterBrushPicker.index, 1, -1 do
                local result = BetterBrushPicker.index[i]
                if string.sub(result.id, 1, #prefix) == prefix then
                    table.insert(rows, 1, result)
                else
                    break
                end
            end

            if writeCacheFile(tileset, entry.filename, rows) then
                state.cached = (state.cached or 0) + 1
                print(string.format("[BetterBrushPicker] Cached tileset %s (%s): %d tiles.", tileset, tostring(entry.filename or ""), #rows))
            else
                print("[BetterBrushPicker] WARNING: could not write cache for " .. tostring(entry.filename or tileset))
            end

            if tileCount == 0 then
                print("[BetterBrushPicker] WARNING: no direct tile IDs reported for " .. tileset)
            end

            state.tileIndex = 0
            state.tilesetIndex = state.tilesetIndex + 1
            -- Yield after each completed tileset.
            break
        end

        local ok, tileName = pcall(function()
            return tostring(tileList:get(state.tileIndex))
        end)
        state.tileIndex = state.tileIndex + 1
        state.checked = state.checked + 1
        budget = budget - 1

        if ok and tileName ~= nil and tileName ~= "nil" and tileName ~= "" and isBrushTileId(tileName) then
            local category = categoryFor(tileset)
            table.insert(BetterBrushPicker.index, {
                id = tileName,
                name = tileName,
                tileset = tileset,
                category = category,
                parent = "",
                spriteType = "",
                searchText = buildSearchText(tileName, tileset, category, "", ""),
            })
            state.added = state.added + 1
        end
    end

    if state.tilesetIndex > #BetterBrushPicker.tilesets then
        finishIndex()
    end
end

BetterBrushPickerTileGrid = nil

local function install()
    if BetterBrushPicker.installed then return end
    if BrushToolChooseTileUI == nil or BrushToolTilePickerList == nil or ISBrushToolTileCursor == nil then
        return false
    end

    BetterBrushPicker.installed = true

    BetterBrushPickerTileGrid = BrushToolTilePickerList:derive("BetterBrushPickerTileGrid")

    function BetterBrushPickerTileGrid:new(x, y, w, h, character, owner)
        local o = BrushToolTilePickerList.new(self, x, y, w, h, character)
        o.owner = owner
        o.results = {}
        o.cellSize = 104
        o.columns = math.max(1, math.floor(w / o.cellSize))
        o.rowHeight = 132
        return o
    end

    function BetterBrushPickerTileGrid:setResults(results)
        self.results = results or {}
        self.posToTileNameTable = {}
        local columns = math.max(1, math.floor(self.width / self.cellSize))
        self.columns = columns
        local rows = math.ceil(#self.results / columns)
        self:setScrollHeight(math.max(self.height, rows * self.rowHeight))
    end

    function BetterBrushPickerTileGrid:render()
        ISPanel.render(self)

        local columns = math.max(1, self.columns)
        local rowHeight = self.rowHeight
        local cellSize = self.cellSize
        local scrollY = self:getYScroll()
        local firstRow = math.max(0, math.floor(-scrollY / rowHeight) - 1)
        local visibleRows = math.ceil(self.height / rowHeight) + 2
        local lastRow = math.min(math.ceil(#self.results / columns) - 1, firstRow + visibleRows)

        for row = firstRow, lastRow do
            for col = 0, columns - 1 do
                local index = row * columns + col + 1
                local result = self.results[index]
                if result ~= nil then
                    local x = col * cellSize + 4
                    local y = row * rowHeight + 4
                    local texture = getTexture(result.id)

                    self:drawRectBorder(x, y, cellSize - 8, rowHeight - 8, 0.8, 0.5, 0.5, 0.5)

                    if texture ~= nil then
                        local maxW = cellSize - 18
                        local maxH = 88
                        local tw = texture:getWidth()
                        local th = texture:getHeight()
                        local scale = 1.0
                        if tw > maxW then scale = maxW / tw end
                        if th * scale > maxH then scale = maxH / th end

                        self:drawTextureScaled(
                            texture,
                            x + (cellSize - 8 - tw * scale) / 2,
                            y + 4 + texture:getOffsetY() * scale,
                            tw * scale,
                            th * scale,
                            1, 1, 1, 1
                        )
                    end

                    self:drawTextCentre(
                        result.id,
                        x + (cellSize - 8) / 2,
                        y + 93,
                        1, 1, 1, 0.95,
                        UIFont.Small
                    )
                end
            end
        end
    end

    function BetterBrushPickerTileGrid:onMouseDown(x, y)
        local columns = math.max(1, self.columns)
        local row = math.floor((y - 0) / self.rowHeight)
        local col = math.floor(x / self.cellSize)
        local index = row * columns + col + 1
        local result = self.results[index]

        if result == nil then return end

        local spriteName = tostring(result.id or "")
        if spriteName == "" then return end

        -- BrushToolTilePickerList only ever selects atlas-style IDs of the
        -- form <tileset>_<numeric index>. Reject everything else before it
        -- reaches ISBrushToolTileCursor / IsoObject.
        local tileIndex = tonumber(spriteName:match("_(%d+)$"))
        if tileIndex == nil or tileIndex < 0 or tileIndex > 2047 then
            print("[BetterBrushPicker] Refusing non-brush tile ID: " .. spriteName)
            return
        end

        local textureOk, texture = pcall(function() return getTexture(spriteName) end)
        if not textureOk or texture == nil then
            print("[BetterBrushPicker] Refusing tile with no texture: " .. spriteName)
            return
        end

        local spriteOk, sprite = pcall(function() return getSprite(spriteName) end)
        if not spriteOk or sprite == nil then
            print("[BetterBrushPicker] Refusing tile with no sprite: " .. spriteName)
            return
        end

        local character = self.character or getPlayer()
        if character == nil then
            print("[BetterBrushPicker] Refusing tile selection because no player character is available.")
            return
        end

        if self.owner ~= nil then
            self.owner.selectedTileName = spriteName
            self.owner.selectedResult = result
        end

        local cursorOk, cursor = pcall(function()
            return ISBrushToolTileCursor:new(spriteName, spriteName, character)
        end)
        if not cursorOk or cursor == nil then
            print("[BetterBrushPicker] Cursor creation failed for tile: " .. spriteName)
            return
        end

        local playerOk, playerNum = pcall(function() return character:getPlayerNum() end)
        if not playerOk or playerNum == nil then
            print("[BetterBrushPicker] Could not determine player number for tile: " .. spriteName)
            return
        end

        local dragOk = pcall(function()
            getCell():setDrag(cursor, playerNum)
        end)
        if not dragOk then
            print("[BetterBrushPicker] Failed to activate brush cursor for tile: " .. spriteName)
            return
        end
    end

    function BetterBrushPickerTileGrid:onMouseWheel(del)
        self:setYScroll(self:getYScroll() - del * 128)
        return true
    end

    function BrushToolChooseTileUI.openPanel(x, y, playerObj)
        if y < 0 then y = 0 end
        if BrushToolChooseTileUI.instance == nil then
            local window = BrushToolChooseTileUI:new(x, y, 1220, 760, playerObj)
            window:initialise()
            window:addToUIManager()
            BrushToolChooseTileUI.instance = window
        end
    end

    function BrushToolChooseTileUI:createChildren()
        ISCollapsableWindow.createChildren(self)
        local th = self:titleBarHeight()
        local topY = th + 6

        self.searchEntryBox = ISTextEntryBox:new("", 8, topY, 420, 24)
        self.searchEntryBox.font = UIFont.Small
        self.searchEntryBox.onTextChange = BrushToolChooseTileUI.onTextChange
        self:addChild(self.searchEntryBox)

        local x = self.searchEntryBox:getRight() + 8
        for i = 1, #BetterBrushPicker.categories do
            local category = BetterBrushPicker.categories[i]
            local width = 70
            local button = ISButton:new(x, topY, width, 24, category, self, BrushToolChooseTileUI.onCategoryClick)
            button.internal = category
            button:initialise()
            button:instantiate()
            self:addChild(button)
            x = x + width + 3
        end

        self.statusLabel = nil

        local contentTop = topY + 30
        local bottomHeight = 46
        local tilesWidth = self.width - 16
        local tilesHeight = self.height - contentTop - bottomHeight

        self.tilesList = BetterBrushPickerTileGrid:new(8, contentTop, tilesWidth, tilesHeight, self.character, self)
        self.tilesList.anchorRight = true
        self.tilesList.anchorBottom = true
        self.tilesList:initialise()
        self.tilesList:instantiate()
        self.tilesList:addScrollBars()
        self:addChild(self.tilesList)

        self.selectedTileName = "No tile selected"
        self.selectedResult = nil

        BetterBrushPicker.startIndexBuild()
        self:refreshResults()
    end

    function BrushToolChooseTileUI:onTextChange()
        if BrushToolChooseTileUI.instance ~= nil then
            BrushToolChooseTileUI.instance:refreshResults()
        end
    end

    function BrushToolChooseTileUI:onCategoryClick(button)
        BetterBrushPicker.activeCategory = button.internal or "All"
        self:refreshResults()
    end

    function BrushToolChooseTileUI:refreshResults()
        if self.tilesList == nil then return end

        if not BetterBrushPicker.indexReady then
            self.tilesList:setResults({})
            self.selectedTileName = BetterBrushPicker.indexBuilding and "Indexing tiles..." or "Preparing index..."
            return
        end

        local searchText = self.searchEntryBox:getInternalText()
        BetterBrushPicker.lastSearch = searchText
        local tokens = splitSearch(searchText)
        local results = {}
        local category = BetterBrushPicker.activeCategory

        for i = 1, #BetterBrushPicker.index do
            local result = BetterBrushPicker.index[i]
            if (category == "All" or result.category == category) and matchesTokens(result.searchText, tokens) then
                table.insert(results, result)
            end
        end

        self.currentResults = results
        self.tilesList:setResults(results)

        if #results == 0 then
            self.selectedTileName = "No matching tiles"
        elseif self.selectedResult == nil then
            self.selectedTileName = "Results: " .. tostring(#results) .. " (click a tile)"
        end
    end

    function BrushToolChooseTileUI:render()
        ISCollapsableWindow.render(self)
        local footerY = self.height - 34
        self:drawText(
            "Selected: " .. tostring(self.selectedTileName or "None"),
            10, footerY, 1, 1, 1, 0.95, UIFont.Small
        )

        local state = BetterBrushPicker.indexState
        local progress = ""
        if BetterBrushPicker.indexReady and state ~= nil then
            progress = string.format("Indexed %d tiles", state.added)
        elseif BetterBrushPicker.indexBuilding and state ~= nil then
            progress = string.format("Indexing tiles: %d found / %d actual IDs processed", state.added, state.checked)
        else
            progress = "Starting tile index..."
        end
        self:drawTextRight(progress, self.width - 10, footerY, 1, 1, 1, 0.8, UIFont.Small)
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

    print("[BetterBrushPicker] Installed v0.2.9 successfully.")
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
