-- Better Brush Picker
-- Build 42
-- Version 0.1.0
--
-- This mod improves the VANILLA Brush Tool tile picker UI.
-- It does not replace tile placement: selecting a tile still creates
-- the normal ISBrushToolTileCursor used by Project Zomboid.

local BetterBrushPicker = {}

BetterBrushPicker.installed = false
BetterBrushPicker.activeCategory = "All"
BetterBrushPicker.categories = {
    "All",
    "Furniture",
    "Walls",
    "Floors",
    "Decor",
    "Doors",
    "Windows",
    "Plants",
    "Roofs",
    "Other",
}

-- Search aliases make common words useful even when they aren't literally
-- present in a tileset's name.
BetterBrushPicker.aliases = {
    furniture = "chair seat seating table desk bed cabinet shelf storage counter sink toilet bathtub appliance refrigerator fridge stove oven microwave dresser locker furniture",
    walls     = "wall walls brick wood stone clapboard siding fence fencing railing doorframe frame wall",
    floors    = "floor floors ground street road sidewalk curb carpet wood tile tiles stone gravel dirt grass",
    decor     = "decor decoration overlay graffiti grime blood trash junk sign signage notice poster lamp light lighting curtain rug carpet plant",
    doors     = "door doors doorway frame gate fence",
    windows   = "window windows curtain curtains",
    plants    = "plant plants tree trees bush bushes flowers flower vines vine vegetation foliage grass",
    roofs     = "roof roofs roofcap snow",
    other     = "other industry machine vehicle car truck sewer pylon radio tower sports escalator stairs bunker",
}

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function categoryFor(name)
    local n = lower(name)

    if string.find(n, "door", 1, true) or string.find(n, "gate", 1, true) then
        return "Doors"
    end
    if string.find(n, "window", 1, true) then
        return "Windows"
    end
    if string.find(n, "roof", 1, true) then
        return "Roofs"
    end
    if string.find(n, "floor", 1, true)
        or string.find(n, "street", 1, true)
        or string.find(n, "curb", 1, true)
        or string.find(n, "blend", 1, true) then
        return "Floors"
    end
    if string.find(n, "wall", 1, true)
        or string.find(n, "fenc", 1, true)
        or string.find(n, "rail", 1, true) then
        return "Walls"
    end
    if string.find(n, "furniture", 1, true)
        or string.find(n, "appliance", 1, true)
        or string.find(n, "seating", 1, true)
        or string.find(n, "shelving", 1, true)
        or string.find(n, "storage", 1, true)
        or string.find(n, "counter", 1, true)
        or string.find(n, "sink", 1, true)
        or string.find(n, "bathroom", 1, true)
        or string.find(n, "bedding", 1, true)
        or string.find(n, "table", 1, true) then
        return "Furniture"
    end
    if string.find(n, "tree", 1, true)
        or string.find(n, "bush", 1, true)
        or string.find(n, "flower", 1, true)
        or string.find(n, "plant", 1, true)
        or string.find(n, "vegetation", 1, true)
        or string.find(n, "foliage", 1, true) then
        return "Plants"
    end
    if string.find(n, "sign", 1, true)
        or string.find(n, "notice", 1, true)
        or string.find(n, "overlay", 1, true)
        or string.find(n, "graffiti", 1, true)
        or string.find(n, "grime", 1, true)
        or string.find(n, "trash", 1, true)
        or string.find(n, "junk", 1, true)
        or string.find(n, "lighting", 1, true)
        or string.find(n, "light", 1, true)
        or string.find(n, "curtain", 1, true)
        or string.find(n, "rug", 1, true) then
        return "Decor"
    end

    return "Other"
end

local function splitSearch(text)
    local tokens = {}
    for token in lower(text):gmatch("%S+") do
        table.insert(tokens, token)
    end
    return tokens
end

local function matchesSearch(name, category, searchText)
    local tokens = splitSearch(searchText)
    if #tokens == 0 then
        return true
    end

    local alias = BetterBrushPicker.aliases[lower(category)] or ""
    local haystack = lower(name .. " " .. category .. " " .. alias)

    for i = 1, #tokens do
        if not string.find(haystack, tokens[i], 1, true) then
            return false
        end
    end

    return true
end

local function install()
    if BetterBrushPicker.installed then
        return
    end

    if BrushToolChooseTileUI == nil then
        print("[BetterBrushPicker] ERROR: vanilla BrushToolChooseTileUI was not loaded.")
        return
    end

    if BrushToolTilePickerList == nil or ISBrushToolTileCursor == nil then
        print("[BetterBrushPicker] ERROR: vanilla Brush Tool tile-picker classes were not loaded.")
        return
    end

    BetterBrushPicker.installed = true

    ------------------------------------------------------------------------
    -- Custom tile grid: inherit the vanilla grid renderer/scroll behavior,
    -- but report the exact tile name when a tile is clicked.
    ------------------------------------------------------------------------

    BetterBrushPickerTileGrid = BrushToolTilePickerList:derive("BetterBrushPickerTileGrid")

    function BetterBrushPickerTileGrid:new(x, y, w, h, character, owner)
        local o = BrushToolTilePickerList.new(self, x, y, w, h, character)
        o.owner = owner
        return o
    end

    function BetterBrushPickerTileGrid:onMouseDown(x, y)
        local c = math.floor(x / 64)
        local r = math.floor(y / 128)

        if c >= 0 and c < 8 and r >= 0 and r < 128 then
            local row = self.posToTileNameTable[r + 1]
            if row ~= nil and row[c + 1] ~= nil then
                local tileName = row[c + 1]
                local texture = getTexture(tileName)

                if texture ~= nil then
                    if self.owner ~= nil then
                        self.owner.selectedTileName = tileName
                    end

                    local cursor = ISBrushToolTileCursor:new(
                        tileName,
                        tileName,
                        self.character
                    )
                    getCell():setDrag(cursor, self.character:getPlayerNum())
                end
            end
        end
    end

    ------------------------------------------------------------------------
    -- Replace the vanilla window's open function. The Brush Tool Manager
    -- still calls BrushToolChooseTileUI.openPanel(), so no placement code
    -- needs to be changed.
    ------------------------------------------------------------------------

    function BrushToolChooseTileUI.openPanel(x, y, playerObj)
        if y < 0 then y = 0 end

        if BrushToolChooseTileUI.instance == nil then
            local window = BrushToolChooseTileUI:new(x, y, 1100, 720, playerObj)
            window:initialise()
            window:addToUIManager()
            BrushToolChooseTileUI.instance = window
        end
    end

    function BrushToolChooseTileUI:createChildren()
        ISCollapsableWindow.createChildren(self)

        local titleHeight = self:titleBarHeight()
        local topY = titleHeight + 6
        local gap = 4

        -- Search box.
        self.searchEntryBox = ISTextEntryBox:new("", 8, topY, 285, 22)
        self.searchEntryBox.font = UIFont.Small
        self.searchEntryBox.onTextChange = BrushToolChooseTileUI.onTextChange
        self:addChild(self.searchEntryBox)

        -- Category buttons.
        local buttonX = self.searchEntryBox:getRight() + 8
        local buttonWidth = 80
        local buttonHeight = 22

        for i = 1, #BetterBrushPicker.categories do
            local category = BetterBrushPicker.categories[i]
            local button = ISButton:new(
                buttonX,
                topY,
                buttonWidth,
                buttonHeight,
                category,
                self,
                BrushToolChooseTileUI.onCategoryClick
            )
            button.internal = category
            button:initialise()
            button:instantiate()
            self:addChild(button)
            buttonX = buttonX + buttonWidth + gap
        end

        -- Left: list of matching tilesets.
        local contentTop = topY + buttonHeight + 6
        local bottomHeight = 30
        local listWidth = 355
        local listHeight = self.height - contentTop - bottomHeight - 6

        self.imageList = ISScrollingListBox:new(
            8,
            contentTop,
            listWidth,
            listHeight
        )
        self.imageList.anchorBottom = true
        self.imageList:initialise()
        self.imageList:instantiate()
        self.imageList.itemheight = getTextManager():getFontHeight(UIFont.Small) + 4
        self.imageList.selected = 1
        self.imageList.font = UIFont.Small
        self.imageList.doDrawItem = BrushToolChooseTileUI.doDrawImageListItem
        self.imageList.drawBorder = true
        self.imageList.onmousedown = BrushToolChooseTileUI.onSelectImage
        self:addChild(self.imageList)

        -- Right: vanilla tile grid renderer with our click callback.
        local gridX = self.imageList:getRight() + 6
        local gridWidth = self.width - gridX - 8
        local gridHeight = listHeight

        self.tilesList = BetterBrushPickerTileGrid:new(
            gridX,
            contentTop,
            gridWidth,
            gridHeight,
            self.character,
            self
        )
        self.tilesList.anchorRight = true
        self.tilesList.anchorBottom = true
        self.tilesList:initialise()
        self.tilesList:instantiate()
        self.tilesList:addScrollBars()
        self:addChild(self.tilesList)

        self.selectedTileName = "No tile selected yet"

        -- Draw once immediately.
        self:populateList()
    end

    function BrushToolChooseTileUI:onTextChange()
        if BrushToolChooseTileUI.instance ~= nil then
            BrushToolChooseTileUI.instance:populateList()
        end
    end

    function BrushToolChooseTileUI:onCategoryClick(button)
        BetterBrushPicker.activeCategory = button.internal or "All"
        self:populateList()
    end

    function BrushToolChooseTileUI:doDrawImageListItem(y, item, alt)
        self:drawRectBorder(
            0,
            y,
            self:getWidth(),
            self.itemheight - 1,
            0.9,
            self.borderColor.r,
            self.borderColor.g,
            self.borderColor.b
        )

        if self.selected == item.index then
            self:drawRect(
                0,
                y,
                self:getWidth(),
                self.itemheight - 1,
                0.3,
                0.7,
                0.35,
                0.15
            )
        end

        self:drawText(
            item.text,
            8,
            y + (self.itemheight - getTextManager():getFontHeight(UIFont.Small)) / 2,
            1,
            1,
            1,
            0.9,
            self.font
        )

        return y + self.itemheight
    end

    function BrushToolChooseTileUI.onSelectImage(_, item)
        if BrushToolChooseTileUI.instance ~= nil and item ~= nil then
            local instance = BrushToolChooseTileUI.instance
            instance.tilesList.imageName = item.item
            instance.tilesList.posToTileNameTable = {}
            instance.selectedTileName = item.item
                .. "  (tileset selected — click a tile on the right)"
        end
    end

    function BrushToolChooseTileUI:populateList()
        if self.imageList == nil or self.tilesList == nil then
            return
        end

        local searchText = self.searchEntryBox:getInternalText()
        self.imageList:clear()

        local bufferImages = {}
        local resultImages = {}
        local images = getWorld():getTileImageNames()

        if images == nil then
            return
        end

        for i = 0, images:size() - 1 do
            local fullName = tostring(images:get(i))
            local name = fullName:match("^([^%.]+)") or fullName
            local category = categoryFor(name)

            if (BetterBrushPicker.activeCategory == "All"
                or category == BetterBrushPicker.activeCategory)
                and getTexture(name .. "_0") ~= nil
                and matchesSearch(name, category, searchText) then
                bufferImages[name] = category
            end
        end

        for name, category in pairs(bufferImages) do
            local display = "[" .. string.upper(category) .. "] " .. name
            table.insert(resultImages, { display, name })
        end

        table.sort(resultImages, function(a, b)
            return a[1] < b[1]
        end)

        for i = 1, #resultImages do
            self.imageList:addItem(resultImages[i][1], resultImages[i][2])
        end

        if #self.imageList.items > 0 then
            self.imageList.selected = 1
            local first = self.imageList.items[1]
            self.tilesList.imageName = first.item
            self.tilesList.posToTileNameTable = {}
            self.selectedTileName = first.item
                .. "  (tileset selected — click a tile on the right)"
        else
            self.tilesList.imageName = nil
            self.tilesList.posToTileNameTable = {}
            self.selectedTileName = "No matching tilesets"
        end
    end

    function BrushToolChooseTileUI:render()
        ISCollapsableWindow.render(self)

        local bottomY = self.height - 24
        self:drawText(
            "Selected: " .. tostring(self.selectedTileName or "None"),
            10,
            bottomY,
            1,
            1,
            1,
            0.95,
            UIFont.Small
        )
    end

    function BrushToolChooseTileUI:close()
        BrushToolChooseTileUI.instance = nil
        self:setVisible(false)
        self:removeFromUIManager()
    end

    function BrushToolChooseTileUI:new(x, y, width, height, character)
        local o = ISCollapsableWindow.new(self, x, y, width, height)
        o:setResizable(false)
        o.title = "Better Brush Picker"
        o.character = character
        return o
    end

    print("[BetterBrushPicker] Installed successfully.")
end

-- Vanilla exposes this event and uses it after game startup.
Events.OnGameBoot.Add(install)
