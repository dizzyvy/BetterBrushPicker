-- Better Brush Picker
-- Build 42
-- Version 0.2.1-safe
-- Author: Dizzy
--
-- Safety-first individual-tile browser.
-- IMPORTANT: this version does NOT scan every tile in every tilesheet at startup.
-- It indexes only the lightweight tilesheet-name list, then scans individual
-- tiles only for sheets that match the user's search. This avoids the large
-- getTexture() storm that caused the previous 39,000-tile scan to exhaust memory.

local BetterBrushPicker = {}
BetterBrushPicker.installed = false
BetterBrushPicker.tilesets = {}
BetterBrushPicker.activeCategory = "All"
BetterBrushPicker.lastSearch = ""
BetterBrushPicker.scan = nil
BetterBrushPicker.scanGeneration = 0
BetterBrushPicker.currentResults = {}

BetterBrushPicker.categories = {
    "All", "Furniture", "Walls", "Floors", "Decor", "Doors", "Windows", "Plants", "Roofs", "Other"
}

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

local function tileBaseName(fullName)
    local s = tostring(fullName or "")
    return s:match("^([^%.]+)") or s
end

local function splitSearch(text)
    local tokens = {}
    for token in lower(text):gmatch("%S+") do
        table.insert(tokens, token)
    end
    return tokens
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
        or contains(n, "bedding") or contains(n, "table") or contains(n, "desk") then return "Furniture" end
    if contains(n, "tree") or contains(n, "bush") or contains(n, "flower") or contains(n, "plant")
        or contains(n, "vegetation") or contains(n, "foliage") then return "Plants" end
    if contains(n, "sign") or contains(n, "notice") or contains(n, "overlay") or contains(n, "graffiti")
        or contains(n, "grime") or contains(n, "trash") or contains(n, "junk") or contains(n, "lighting")
        or contains(n, "light") or contains(n, "curtain") or contains(n, "rug") then return "Decor" end
    return "Other"
end

local function tilesetSearchText(tileset)
    local text = lower(tileset .. " " .. categoryFor(tileset))
    local n = lower(tileset)
    if contains(n, "seating") then text = text .. " chair chairs seat seating stool bench couch sofa " end
    if contains(n, "bedding") then text = text .. " bed beds mattress bedding " end
    if contains(n, "refriger") then text = text .. " fridge refrigerator freezer " end
    if contains(n, "cooking") then text = text .. " stove oven cooker microwave cooking " end
    if contains(n, "bathroom") then text = text .. " toilet sink bathtub tub shower bathroom " end
    if contains(n, "window") then text = text .. " window windows " end
    if contains(n, "door") then text = text .. " door doors " end
    if contains(n, "table") then text = text .. " table tables " end
    if contains(n, "shelving") then text = text .. " shelf shelves shelving " end
    if contains(n, "storage") then text = text .. " cabinet cupboard locker storage " end
    if contains(n, "lighting") then text = text .. " lamp light lighting " end
    if contains(n, "plant") or contains(n, "vegetation") then text = text .. " plant tree bush flower vine vegetation " end
    return text
end

local function tokenMatches(text, token)
    if string.find(text, token, 1, true) then return true end
    local alias = BetterBrushPicker.aliases[token]
    if alias and string.find(text .. " " .. alias, token, 1, true) then
        return true
    end
    return false
end

local function tilesetMatches(tileset, tokens)
    local text = tilesetSearchText(tileset)
    for i = 1, #tokens do
        if not tokenMatches(text, tokens[i]) then return false end
    end
    return true
end

local function collectTilesets()
    local result, seen = {}, {}
    local images = getWorld():getTileImageNames()
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

function BetterBrushPicker.prepare()
    BetterBrushPicker.tilesets = collectTilesets()
    print(string.format("[BetterBrushPicker] Ready: %d tilesets indexed. Individual tiles are scanned on demand.", #BetterBrushPicker.tilesets))
end

function BetterBrushPicker.cancelScan()
    BetterBrushPicker.scan = nil
    BetterBrushPicker.scanGeneration = BetterBrushPicker.scanGeneration + 1
end

function BetterBrushPicker.beginScan(tilesets)
    BetterBrushPicker.cancelScan()
    BetterBrushPicker.currentResults = {}

    if #tilesets == 0 then return end

    BetterBrushPicker.scanGeneration = BetterBrushPicker.scanGeneration + 1
    BetterBrushPicker.scan = {
        generation = BetterBrushPicker.scanGeneration,
        tilesets = tilesets,
        tilesetIndex = 1,
        tileIndex = 0,
        checked = 0,
        found = 0,
        results = {},
    }

    print(string.format("[BetterBrushPicker] On-demand scan: %d matching tileset(s).", #tilesets))
end

function BetterBrushPicker.tickScan()
    local scan = BetterBrushPicker.scan
    if scan == nil then return end

    -- Small bounded budget. Never scan tens of thousands of textures in one go.
    local budget = 32

    while budget > 0 and scan.tilesetIndex <= #scan.tilesets do
        local tileset = scan.tilesets[scan.tilesetIndex]
        local tileName = tileset .. "_" .. tostring(scan.tileIndex)
        scan.tileIndex = scan.tileIndex + 1
        scan.checked = scan.checked + 1
        budget = budget - 1

        -- The texture is used only as an existence check and is not retained.
        local texture = getTexture(tileName)
        if texture ~= nil then
            local category = categoryFor(tileset)
            table.insert(scan.results, {
                id = tileName,
                name = tileName,
                tileset = tileset,
                category = category,
            })
            scan.found = scan.found + 1
        end

        if scan.tileIndex >= 2048 then
            scan.tileIndex = 0
            scan.tilesetIndex = scan.tilesetIndex + 1
        end
    end

    if scan.tilesetIndex > #scan.tilesets then
        BetterBrushPicker.currentResults = scan.results
        BetterBrushPicker.scan = nil
        table.sort(BetterBrushPicker.currentResults, function(a, b)
            return a.id < b.id
        end)
        print(string.format("[BetterBrushPicker] Scan complete: %d tiles found; %d texture checks.", scan.found, scan.checked))

        if BrushToolChooseTileUI ~= nil and BrushToolChooseTileUI.instance ~= nil then
            BrushToolChooseTileUI.instance:refreshResults()
        end
    end
end

local function resultMatches(result, tokens, category)
    if category ~= "All" and result.category ~= category then return false end
    local text = lower(result.id .. " " .. result.tileset .. " " .. result.category)
    for i = 1, #tokens do
        local token = tokens[i]
        local alias = BetterBrushPicker.aliases[token]
        if alias then text = text .. " " .. alias end
        if string.find(text, token, 1, true) == nil then return false end
    end
    return true
end

local function matchingTilesets(searchText, category)
    local tokens = splitSearch(searchText)
    local results = {}

    for i = 1, #BetterBrushPicker.tilesets do
        local tileset = BetterBrushPicker.tilesets[i]
        local cat = categoryFor(tileset)
        if (category == "All" or cat == category) and tilesetMatches(tileset, tokens) then
            table.insert(results, tileset)
        end
    end

    return results, tokens
end

BetterBrushPickerTileGrid = nil

local function install()
    if BetterBrushPicker.installed then return true end
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
        self.columns = math.max(1, math.floor(self.width / self.cellSize))
        local rows = math.ceil(#self.results / self.columns)
        self:setScrollHeight(math.max(self.height, rows * self.rowHeight))
    end

    function BetterBrushPickerTileGrid:render()
        ISPanel.render(self)
        local columns, rowHeight, cellSize = self.columns, self.rowHeight, self.cellSize
        local scrollY = self:getYScroll()
        local firstRow = math.max(0, math.floor(-scrollY / rowHeight) - 1)
        local visibleRows = math.ceil(self.height / rowHeight) + 2
        local lastRow = math.min(math.ceil(#self.results / columns) - 1, firstRow + visibleRows)

        for row = firstRow, lastRow do
            for col = 0, columns - 1 do
                local index = row * columns + col + 1
                local result = self.results[index]
                if result ~= nil then
                    local x, y = col * cellSize + 4, row * rowHeight + 4
                    self:drawRectBorder(x, y, cellSize - 8, rowHeight - 8, 0.8, 0.5, 0.5, 0.5)
                    local texture = getTexture(result.id)
                    if texture ~= nil then
                        local maxW, maxH = cellSize - 18, 88
                        local tw, th = texture:getWidth(), texture:getHeight()
                        local scale = math.min(1.0, maxW / tw, maxH / th)
                        self:drawTextureScaled(texture,
                            x + (cellSize - 8 - tw * scale) / 2,
                            y + 4 + texture:getOffsetY() * scale,
                            tw * scale, th * scale, 1, 1, 1, 1)
                    end
                    self:drawTextCentre(result.id, x + (cellSize - 8) / 2, y + 93,
                        1, 1, 1, 0.95, UIFont.Small)
                end
            end
        end
    end

    function BetterBrushPickerTileGrid:onMouseDown(x, y)
        local col = math.floor(x / self.cellSize)
        local row = math.floor(y / self.rowHeight)
        local index = row * self.columns + col + 1
        local result = self.results[index]
        if result == nil then return end

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
            local button = ISButton:new(x, topY, 70, 24, category, self, BrushToolChooseTileUI.onCategoryClick)
            button.internal = category
            button:initialise()
            button:instantiate()
            self:addChild(button)
            x = x + 73
        end

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

        self.selectedTileName = "Type a search to scan matching tiles"
        self.selectedResult = nil
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

        local searchText = self.searchEntryBox:getInternalText()
        BetterBrushPicker.lastSearch = searchText
        local category = BetterBrushPicker.activeCategory
        local tokens = splitSearch(searchText)

        -- Empty search deliberately does NOT scan every tilesheet.
        if #tokens == 0 then
            BetterBrushPicker.cancelScan()
            self.currentResults = {}
            self.tilesList:setResults({})
            self.selectedTileName = "Type a search term (e.g. chair, fridge, window)"
            return
        end

        local candidates = matchingTilesets(searchText, category)
        if #candidates == 0 then
            BetterBrushPicker.cancelScan()
            self.currentResults = {}
            self.tilesList:setResults({})
            self.selectedTileName = "No matching tilesets"
            return
        end

        -- If the current scan already targets these candidates, leave it alone.
        local scan = BetterBrushPicker.scan
        local same = scan ~= nil and #scan.tilesets == #candidates
        if same then
            for i = 1, #candidates do
                if candidates[i] ~= scan.tilesets[i] then same = false break end
            end
        end

        if not same then
            BetterBrushPicker.beginScan(candidates)
        end

        local results = {}
        for i = 1, #BetterBrushPicker.currentResults do
            local result = BetterBrushPicker.currentResults[i]
            if resultMatches(result, tokens, category) then
                table.insert(results, result)
            end
        end

        self.currentResults = results
        self.tilesList:setResults(results)
        if BetterBrushPicker.scan ~= nil then
            self.selectedTileName = string.format("Scanning %d tileset(s): %d checked / %d found",
                #candidates, BetterBrushPicker.scan.checked, BetterBrushPicker.scan.found)
        elseif #results == 0 then
            self.selectedTileName = "Scan complete — no matching tiles"
        else
            self.selectedTileName = "Results: " .. tostring(#results) .. " (click a tile)"
        end
    end

    function BrushToolChooseTileUI:render()
        ISCollapsableWindow.render(self)
        local footerY = self.height - 34
        self:drawText("Selected: " .. tostring(self.selectedTileName or "None"),
            10, footerY, 1, 1, 1, 0.95, UIFont.Small)
        self:drawTextRight("On-demand scan — no full 39,000-tile startup scan",
            self.width - 10, footerY, 1, 1, 1, 0.8, UIFont.Small)
    end

    function BrushToolChooseTileUI:close()
        BetterBrushPicker.cancelScan()
        BrushToolChooseTileUI.instance = nil
        self:setVisible(false)
        self:removeFromUIManager()
    end

    function BrushToolChooseTileUI:new(x, y, width, height, character)
        local o = ISCollapsableWindow.new(self, x, y, width, height)
        o:setResizable(true)
        o.title = "Better Brush Picker — Safe Individual Tiles"
        o.character = character
        return o
    end

    BetterBrushPicker.prepare()
    print("[BetterBrushPicker] Installed safe indexing build.")
    return true
end

local function tick()
    if not BetterBrushPicker.installed then
        install()
    end
    if BetterBrushPicker.installed then
        BetterBrushPicker.tickScan()
    end
end

local function onGameBoot()
    install()
    Events.OnTick.Add(tick)
end

Events.OnGameBoot.Add(onGameBoot)
