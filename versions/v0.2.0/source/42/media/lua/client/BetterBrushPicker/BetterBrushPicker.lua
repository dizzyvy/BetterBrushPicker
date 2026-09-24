-- Better Brush Picker
-- Build 42
-- Version 0.2.0
--
-- v0.2 adds an individual-tile index. The picker no longer requires the
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

local function splitSearch(text)
    local tokens = {}
    for token in lower(text):gmatch("%S+") do
        table.insert(tokens, token)
    end
    return tokens
end

local function getSpriteMetadata(tileName)
    local parent = ""
    local spriteType = ""

    -- getSprite(String) is part of the current Lua global API. Guard it so
    -- a missing/invalid sprite can never break the indexing pass.
    local ok, sprite = pcall(function()
        return getSprite(tileName)
    end)

    if ok and sprite ~= nil then
        local okParent, valueParent = pcall(function()
            return sprite:getParentObjectName()
        end)
        if okParent and valueParent ~= nil then
            parent = tostring(valueParent)
        end

        local okType, valueType = pcall(function()
            return sprite:getType()
        end)
        if okType and valueType ~= nil then
            spriteType = tostring(valueType)
        end
    end

    return parent, spriteType
end

local function buildSearchText(tileName, tilesetName, category, parent, spriteType)
    local text = lower(tileName .. " " .. tilesetName .. " " .. category .. " " .. parent .. " " .. spriteType)

    -- Add semantic aliases based on the actual tileset name. This lets a
    -- search like "chair" find individual tiles from seating sheets while
    -- keeping each result as a distinct tile ID.
    local n = lower(tilesetName)
    if contains(n, "seating") then text = text .. " chair chairs seat seating stool bench couch sofa " end
    if contains(n, "bedding") then text = text .. " bed beds mattress bedding " end
    if contains(n, "refriger") then text = text .. " fridge refrigerator freezer " end
    if contains(n, "cooking") then text = text .. " stove oven cooker microwave cooking " end
    if contains(n, "bathroom") then text = text .. " toilet sink bathtub tub shower bathroom " end
    if contains(n, "windows") then text = text .. " window windows " end
    if contains(n, "doors") then text = text .. " door doors " end
    if contains(n, "tables") then text = text .. " table tables " end
    if contains(n, "shelving") then text = text .. " shelf shelves shelving " end
    if contains(n, "storage") then text = text .. " cabinet cupboard locker storage " end
    if contains(n, "lighting") then text = text .. " lamp light lighting " end
    if contains(n, "plants") or contains(n, "vegetation") then text = text .. " plant tree bush flower vine vegetation " end

    return text
end

local function matchesTokens(searchText, tokens)
    for i = 1, #tokens do
        local token = tokens[i]
        local alias = BetterBrushPicker.aliases[token]
        if alias ~= nil then
            searchText = searchText .. " " .. alias
        end
        if string.find(searchText, token, 1, true) == nil then
            return false
        end
    end
    return true
end

local function uniqueTilesets()
    local images = getWorld():getTileImageNames()
    local seen = {}
    local result = {}
    if images == nil then return result end

    for i = 0, images:size() - 1 do
        local name = tileBaseName(images:get(i))
        if name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(result, name)
        end
    end

    table.sort(result)
    return result
end

function BetterBrushPicker.startIndexBuild()
    if BetterBrushPicker.indexBuilding or BetterBrushPicker.indexReady then return end

    local names = uniqueTilesets()
    BetterBrushPicker.index = {}
    BetterBrushPicker.tilesets = names
    BetterBrushPicker.indexBuilding = true
    BetterBrushPicker.indexReady = false
    BetterBrushPicker.indexState = {
        tilesetIndex = 1,
        tileIndex = 0,
        added = 0,
        checked = 0,
    }

    print(string.format("[BetterBrushPicker] Building individual tile index (%d tilesets)...", #names))
end

function BetterBrushPicker.tickIndexBuild()
    local state = BetterBrushPicker.indexState
    if not BetterBrushPicker.indexBuilding or state == nil then return end

    local budget = 256
    while budget > 0 and state.tilesetIndex <= #BetterBrushPicker.tilesets do
        local tileset = BetterBrushPicker.tilesets[state.tilesetIndex]
        local tileName = tileset .. "_" .. tostring(state.tileIndex)
        state.tileIndex = state.tileIndex + 1
        state.checked = state.checked + 1
        budget = budget - 1

        local texture = getTexture(tileName)
        if texture ~= nil then
            local category = categoryFor(tileset)
            local parent, spriteType = getSpriteMetadata(tileName)
            local searchText = buildSearchText(tileName, tileset, category, parent, spriteType)
            table.insert(BetterBrushPicker.index, {
                id = tileName,
                name = tileName,
                tileset = tileset,
                category = category,
                parent = parent,
                spriteType = spriteType,
                searchText = searchText,
            })
            state.added = state.added + 1
        end

        if state.tileIndex >= 2048 then
            state.tileIndex = 0
            state.tilesetIndex = state.tilesetIndex + 1
        end
    end

    if state.tilesetIndex > #BetterBrushPicker.tilesets then
        BetterBrushPicker.indexBuilding = false
        BetterBrushPicker.indexReady = true
        table.sort(BetterBrushPicker.index, function(a, b)
            if a.tileset == b.tileset then return a.id < b.id end
            return a.tileset < b.tileset
        end)
        print(string.format("[BetterBrushPicker] Index ready: %d individual tiles checked=%d.", state.added, state.checked))

        if BrushToolChooseTileUI ~= nil and BrushToolChooseTileUI.instance ~= nil then
            BrushToolChooseTileUI.instance:refreshResults()
        end
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

        local texture = getTexture(result.id)
        if texture == nil then return end

        if self.owner ~= nil then
            self.owner.selectedTileName = result.id
            self.owner.selectedResult = result
        end

        local cursor = ISBrushToolTileCursor:new(result.id, result.id, self.character)
        getCell():setDrag(cursor, self.character:getPlayerNum())
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

        table.sort(results, function(a, b)
            if a.tileset == b.tileset then return a.id < b.id end
            return a.tileset < b.tileset
        end)

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
            progress = string.format("Indexing tiles: %d found / %d checked", state.added, state.checked)
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

    print("[BetterBrushPicker] Installed v0.2.0 successfully.")
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
