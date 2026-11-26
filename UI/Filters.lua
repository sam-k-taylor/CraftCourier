local _, ns = ...

-- Item filters window (ns:ToggleFilters()): per-item overrides of the
-- category CraftCourier puts an item in, or "ignore".
--   * top: an item slot, like the one on the enchanting screen. Click it to
--     pick from the items in your bags, or drop an item on it. Then choose
--     its category in the dropdown, or tick Ignore.
--   * middle: custom categories. Type a name and Add (it takes the selected
--     item's icon), click one to rename it, X twice to delete it.
--   * bottom: every item with an override, click one to edit it, X to remove.

local ROW_HEIGHT = 24
local CUSTOM_ROW_HEIGHT = 22
local CUSTOM_VISIBLE_ROWS = 4
local PICKER_COLUMNS = 8
local PICKER_BUTTON = 34
local EMPTY_SLOT = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

local window
local selected        -- { itemID, quality } of the item in the slot
local pendingCategory -- the dropdown's choice while Ignore is ticked: a key or "default"
local refreshQueued
local editingKey      -- custom category being renamed
local armedDelete     -- custom category whose X was clicked once
local refresh         -- defined below the sections it refreshes

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function itemName(itemID)
    local name, _, quality = GetItemInfo(itemID)
    return name, quality
end

-- Name coloured by quality, or "item:123" while it isn't cached.
local function coloredName(itemID)
    local name, quality = itemName(itemID)
    if not name then return "item:" .. itemID end
    -- Common (white) items take the style's text colour: white would vanish
    -- on the Letter style's parchment.
    if quality == 1 then return name end
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and color.hex then
        return color.hex .. name .. "|r"
    end
    return name
end

local function itemIcon(itemID)
    return (GetItemIcon and GetItemIcon(itemID)) or select(5, ns.GetItemInfoInstant(itemID)) or QUESTION_MARK
end

local function categoryText(key)
    if key == "ignore" then return "|cffff6060Ignored|r" end
    local cat = key and ns.categoryByKey[key]
    if not cat then return "|cff888888not sent|r" end
    return ("|T%s:14|t %s"):format(cat.icon, ns:CategoryDisplayName(cat))
end

local function setOverride(itemID, value)
    ns.db.overrides[itemID] = value
    ns:Fire("CONFIG_CHANGED")
end

-- The dropdown's current value for the selected item: a category key or "default".
local function currentChoice()
    if not selected then return "default" end
    local override = ns.db.overrides[selected.itemID]
    if override == "ignore" then return pendingCategory or "default" end
    return override or "default"
end

-- Unbound items in the bags, one entry per itemID. Bound items are never
-- mailed, so there's nothing to filter.
local function bagItems()
    local list, byID = {}, {}
    for bag = 0, ns.LAST_BAG do
        for slot = 1, ns.GetContainerNumSlots(bag) or 0 do
            local info = ns.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isBound then
                local entry = byID[info.itemID]
                if not entry then
                    entry = {
                        itemID = info.itemID,
                        icon = info.iconFileID,
                        quality = info.quality,
                        name = info.hyperlink and info.hyperlink:match("%[(.-)%]") or "",
                        count = 0,
                        bag = bag,
                        slot = slot,
                    }
                    byID[info.itemID] = entry
                    table.insert(list, entry)
                end
                entry.count = entry.count + (info.stackCount or 1)
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

---------------------------------------------------------------------------
-- Selected item
---------------------------------------------------------------------------

local function refreshSelection()
    local top = window.top
    if not selected then
        top.slot.icon:SetTexture(EMPTY_SLOT)
        top.name:SetText("No item selected")
        top.info:SetText("Click the slot to choose an item from your bags, or drop one on it.")
        top.dropdown:SetEnabled(false)
        top.ignore:SetChecked(false)
        top.ignore:SetEnabled(false)
        top.clear:Hide()
        top.dropdown:GenerateMenu()
        return
    end

    local itemID = selected.itemID
    local name = itemName(itemID)
    top.slot.icon:SetTexture(itemIcon(itemID))
    top.name:SetText(coloredName(itemID))
    local default = ns:DefaultCategory(itemID, name, selected.quality)
    top.info:SetText("Default: " .. categoryText(default))

    local ignored = ns.db.overrides[itemID] == "ignore"
    top.ignore:SetEnabled(true)
    top.ignore:SetChecked(ignored)
    top.dropdown:SetEnabled(not ignored)
    top.clear:SetShown(ns.db.overrides[itemID] ~= nil)
    top.dropdown:GenerateMenu()
end

local function selectItem(itemID, quality)
    if selected and selected.itemID == itemID then
        selected.quality = quality or selected.quality
    else
        selected = { itemID = itemID, quality = quality }
        pendingCategory = nil
    end
    if window.picker then window.picker:Hide() end
    refresh() -- also marks the item's row in the list
end

-- Takes an item held on the cursor (dragged from the bags) into the slot.
local function takeCursorItem()
    if not GetCursorInfo then return false end
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID then return false end
    ClearCursor() -- drops it back into its bag slot
    selectItem(itemID)
    return true
end

---------------------------------------------------------------------------
-- Bag item picker (the flyout under the slot)
---------------------------------------------------------------------------

local function showPickerTooltip(button)
    local entry = button.entry
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if GameTooltip.SetBagItem then
        GameTooltip:SetBagItem(entry.bag, entry.slot)
    else
        GameTooltip:SetItemByID(entry.itemID)
    end
    local override = ns.db.overrides[entry.itemID]
    local key = override or ns:DefaultCategory(entry.itemID, entry.name, entry.quality)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("CraftCourier:", categoryText(key) .. (override and " (filter)" or ""), 0.2, 1, 0.6, 1, 1, 1)
    GameTooltip:Show()
end

local function refreshPicker()
    local picker = window.picker
    if not (picker and picker:IsShown()) then return end
    local items = bagItems()
    for i, entry in ipairs(items) do
        local button = picker.buttons[i]
        if not button then
            button = CreateFrame("Button", nil, picker)
            button:SetSize(PICKER_BUTTON, PICKER_BUTTON)
            local col = (i - 1) % PICKER_COLUMNS
            local row = math.floor((i - 1) / PICKER_COLUMNS)
            button:SetPoint("TOPLEFT", 10 + col * (PICKER_BUTTON + 4), -28 - row * (PICKER_BUTTON + 4))
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetAllPoints()
            button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            button.count:SetPoint("BOTTOMRIGHT", -2, 2)
            button.mark = button:CreateTexture(nil, "OVERLAY")
            button.mark:SetSize(14, 14)
            button.mark:SetPoint("TOPLEFT", 1, -1)
            button.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            button:SetScript("OnClick", function(self) selectItem(self.entry.itemID, self.entry.quality) end)
            button:SetScript("OnEnter", showPickerTooltip)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
            picker.buttons[i] = button
        end
        button.entry = entry
        button.icon:SetTexture(entry.icon or QUESTION_MARK)
        button.count:SetText(entry.count > 1 and entry.count or "")
        -- Ticked: this item already has a filter.
        button.mark:SetShown(ns.db.overrides[entry.itemID] ~= nil)
        button:Show()
    end
    for i = #items + 1, #picker.buttons do
        picker.buttons[i]:Hide()
    end

    local rows = math.max(1, math.ceil(#items / PICKER_COLUMNS))
    picker:SetSize(20 + PICKER_COLUMNS * (PICKER_BUTTON + 4) - 4, 38 + rows * (PICKER_BUTTON + 4))
    picker.empty:SetShown(#items == 0)
end

local function createPicker()
    local picker = CreateFrame("Frame", nil, window.body)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetPoint("TOPLEFT", window.top.slot, "BOTTOMLEFT", -6, -4)
    picker:EnableMouse(true)
    picker:Hide()
    ns.Style.Panel(picker)

    local title = ns.Style.Text(picker:CreateFontString(nil, "OVERLAY", "GameFontNormal"), "heading")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetText("Choose an item from your bags")

    picker.empty = ns.Style.Text(picker:CreateFontString(nil, "OVERLAY", "GameFontDisable"), "muted")
    picker.empty:SetPoint("TOPLEFT", 10, -32)
    picker.empty:SetText("No unbound items in your bags.")

    picker.buttons = {}
    picker:SetScript("OnShow", refreshPicker)
    window.picker = picker
end

---------------------------------------------------------------------------
-- Top section: slot, dropdown, Ignore
---------------------------------------------------------------------------

local function setupDropdown(dropdown)
    local function isSelected(value)
        return currentChoice() == value
    end
    local function setSelected(value)
        if not selected then return end
        if ns.db.overrides[selected.itemID] == "ignore" then
            pendingCategory = value
            return
        end
        setOverride(selected.itemID, value ~= "default" and value or nil)
    end

    dropdown:SetupMenu(function(_, root)
        if root.SetScrollMode then
            root:SetScrollMode(400)
        end
        if not selected then
            root:CreateTitle("Choose an item first")
            return
        end
        local name = itemName(selected.itemID)
        local default = ns:DefaultCategory(selected.itemID, name, selected.quality)
        local defaultCat = default and ns.categoryByKey[default]
        root:CreateRadio(("Default (%s)"):format(defaultCat and defaultCat.label or "not sent"),
            isSelected, setSelected, "default")
        for _, group in ipairs(ns:CategoriesBySection()) do
            if #group.categories > 0 then
                root:CreateDivider()
                if root.CreateTitle then root:CreateTitle(group.section.label) end
                for _, cat in ipairs(group.categories) do
                    root:CreateRadio(("|T%s:14|t %s"):format(cat.icon, ns:CategoryDisplayName(cat)),
                        isSelected, setSelected, cat.key)
                end
            end
        end
    end)
end

-- The category dropdown (ns.Style.Dropdown: Blizzard's, or a fallback
-- button that opens the same menu).
local function createDropdown(parent)
    local generator
    setupDropdown({ SetupMenu = function(_, fn) generator = fn end })
    return ns.Style.Dropdown(parent, 220, generator, function()
        local cat = ns.categoryByKey[currentChoice()]
        return cat and cat.label or "Default"
    end)
end

local function createTop()
    local top = CreateFrame("Frame", nil, window.body)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(110)
    window.top = top

    local slot = CreateFrame("Button", nil, top)
    slot:SetSize(44, 44)
    slot:SetPoint("TOPLEFT", 10, -10)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetAllPoints()
    slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:SetScript("OnClick", function(_, button)
        if takeCursorItem() then return end
        if button == "RightButton" then
            selected = nil
            pendingCategory = nil
            window.picker:Hide()
            refresh()
            return
        end
        window.picker:SetShown(not window.picker:IsShown())
    end)
    slot:SetScript("OnReceiveDrag", takeCursorItem)
    slot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if selected then
            GameTooltip:SetItemByID(selected.itemID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Left-click to choose another item, right-click to clear.", 0.6, 0.6, 0.6)
        else
            GameTooltip:AddLine("Choose an item")
            GameTooltip:AddLine("Click to pick from your bags, or drop an item here.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    top.slot = slot

    top.name = ns.Style.Text(top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), "text")
    top.name:SetPoint("TOPLEFT", slot, "TOPRIGHT", 10, -4)
    top.name:SetPoint("RIGHT", -10, 0)
    top.name:SetJustifyH("LEFT")
    top.name:SetWordWrap(false)

    top.info = ns.Style.Text(top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), "text")
    top.info:SetPoint("TOPLEFT", top.name, "BOTTOMLEFT", 0, -6)
    top.info:SetPoint("RIGHT", -10, 0)
    top.info:SetJustifyH("LEFT")

    local label = ns.Style.Text(top:CreateFontString(nil, "OVERLAY", "GameFontNormal"), "heading")
    label:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -18)
    label:SetText("Category:")

    top.dropdown = createDropdown(top)
    top.dropdown:SetPoint("LEFT", label, "RIGHT", 10, 0)

    top.ignore = CreateFrame("CheckButton", nil, top, "UICheckButtonTemplate")
    top.ignore:SetPoint("LEFT", top.dropdown, "RIGHT", 12, 0)
    top.ignore:SetScript("OnClick", function(self)
        if not selected then return end
        if self:GetChecked() then
            pendingCategory = currentChoice()
            setOverride(selected.itemID, "ignore")
        else
            local choice = pendingCategory or "default"
            pendingCategory = nil
            setOverride(selected.itemID, choice ~= "default" and choice or nil)
        end
    end)
    local ignoreLabel = ns.Style.Text(top.ignore:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), "text")
    ignoreLabel:SetPoint("LEFT", top.ignore, "RIGHT", 2, 0)
    ignoreLabel:SetText("Ignore")

    -- Removes the filter for the selected item (back to the default category).
    top.clear = ns.Style.Button(top, "Remove", 90, 22, function()
        if not selected then return end
        pendingCategory = nil
        setOverride(selected.itemID, nil)
    end)
    top.clear:SetPoint("TOPRIGHT", -10, -14)
end

---------------------------------------------------------------------------
-- Custom categories
---------------------------------------------------------------------------

local function filtersIn(key)
    local n = 0
    for _, target in pairs(ns.db.overrides) do
        if target == key then n = n + 1 end
    end
    return n
end

local function resetCustomEdit()
    local custom = window.custom
    editingKey = nil
    custom.box:SetText("")
    custom.box:ClearFocus()
    custom.add:SetText("Add")
    custom.cancel:Hide()
    custom.error:SetText("")
end

local function startRename(key)
    local cat = ns.categoryByKey[key]
    if not cat then return end
    local custom = window.custom
    editingKey = key
    custom.box:SetText(cat.label)
    custom.box:SetFocus()
    custom.box:HighlightText()
    custom.add:SetText("Rename")
    custom.cancel:Show()
    custom.error:SetText("")
end

local function submitCustom()
    local custom = window.custom
    local text = custom.box:GetText()
    local cat, err
    if editingKey then
        cat, err = ns:RenameCustomCategory(editingKey, text)
    else
        cat, err = ns:AddCustomCategory(text, selected and itemIcon(selected.itemID) or nil)
    end
    if not cat then
        custom.error:SetText(err)
        return
    end
    resetCustomEdit()
end

local function initCustomRow(row, cat)
    if not row.icon then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 4, 0)

        row.remove = CreateFrame("Button", nil, row)
        row.remove:SetSize(16, 16)
        row.remove:SetPoint("RIGHT", -4, 0)
        row.remove:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        row.remove:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
        -- Deleting also drops the category's filters and recipient, so it
        -- takes a second click within a few seconds.
        row.remove:SetScript("OnClick", function(self)
            local key = self:GetParent().cat.key
            if armedDelete == key then
                armedDelete = nil
                if editingKey == key then resetCustomEdit() end
                ns:DeleteCustomCategory(key)
                return
            end
            armedDelete = key
            refresh()
            C_Timer.After(3, function()
                if armedDelete == key then
                    armedDelete = nil
                    refresh()
                end
            end)
        end)
        row.remove:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Delete category")
            GameTooltip:AddLine("Its items go back to their default category.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row.remove:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.count = ns.Style.Text(row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), "muted")
        row.count:SetPoint("RIGHT", row.remove, "LEFT", -8, 0)
        row.count:SetJustifyH("RIGHT")

        row.name = ns.Style.Text(row:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), "text")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        ns.Style.DecorateRow(row)
        row:SetScript("OnClick", function(self) startRename(self.cat.key) end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.cat.label)
            local recipient = ns:GetRecipient(self.cat.key)
            GameTooltip:AddLine("Recipient: " .. (recipient or "none, set one in Settings"), 1, 1, 1)
            GameTooltip:AddLine("Click to rename.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    row.cat = cat
    ns.Style.SetRowStripe(row, row.GetElementDataIndex and row:GetElementDataIndex() or 1)
    row.icon:SetTexture(cat.icon)
    row.name:SetText(cat.label)
    if armedDelete == cat.key then
        row.count:SetText("|cffff6060Click X again to delete|r")
    else
        local n = filtersIn(cat.key)
        row.count:SetText(n == 1 and "1 item" or (n .. " items"))
    end
end

local function refreshCustom()
    local data = CreateDataProvider()
    for _, cat in ipairs(ns.categories) do
        if cat.custom then data:Insert(cat) end
    end
    local custom = window.custom
    custom.scrollBox:SetDataProvider(data, true)
    custom.empty:SetShown(data:GetSize() == 0)
    custom.title:SetText(("Custom categories (%d)"):format(data:GetSize()))
    if editingKey and not ns.categoryByKey[editingKey] then
        resetCustomEdit()
    end
end

local function createCustomSection(anchor)
    local custom = {}
    window.custom = custom

    custom.title = ns.Style.Text(window.body:CreateFontString(nil, "OVERLAY", "GameFontNormal"), "heading")
    custom.title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 4, -10)

    custom.error = window.body:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    custom.error:SetPoint("LEFT", custom.title, "RIGHT", 12, 0)
    custom.error:SetPoint("RIGHT", window.body, "RIGHT", -4, 0)
    custom.error:SetJustifyH("RIGHT")

    custom.box = CreateFrame("EditBox", nil, window.body, "InputBoxTemplate")
    custom.box:SetSize(200, 20)
    custom.box:SetPoint("TOPLEFT", custom.title, "BOTTOMLEFT", 6, -8)
    custom.box:SetAutoFocus(false)
    custom.box:SetMaxLetters(32)
    custom.box:SetScript("OnEnterPressed", submitCustom)
    custom.box:SetScript("OnEscapePressed", resetCustomEdit)
    custom.box:SetScript("OnTextChanged", function() custom.error:SetText("") end)
    ns.Style.SkinEditBox(custom.box)

    custom.add = ns.Style.Button(window.body, "Add", 80, 22, submitCustom)
    custom.add:SetPoint("LEFT", custom.box, "RIGHT", 8, 0)

    custom.cancel = ns.Style.Button(window.body, "Cancel", 70, 22, resetCustomEdit)
    custom.cancel:SetPoint("LEFT", custom.add, "RIGHT", 4, 0)
    custom.cancel:Hide()

    custom.scrollBox = CreateFrame("Frame", nil, window.body, "WowScrollBoxList")
    custom.scrollBox:SetPoint("TOPLEFT", custom.box, "BOTTOMLEFT", -12, -6)
    custom.scrollBox:SetPoint("RIGHT", window.body, "RIGHT", -20, 0)
    custom.scrollBox:SetHeight(CUSTOM_ROW_HEIGHT * CUSTOM_VISIBLE_ROWS)

    custom.scrollBar = CreateFrame("EventFrame", nil, window.body, "MinimalScrollBar")
    custom.scrollBar:SetPoint("TOPLEFT", custom.scrollBox, "TOPRIGHT", 6, 0)
    custom.scrollBar:SetPoint("BOTTOMLEFT", custom.scrollBox, "BOTTOMRIGHT", 6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(CUSTOM_ROW_HEIGHT)
    view:SetElementInitializer("Button", initCustomRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(custom.scrollBox, custom.scrollBar, view)

    custom.empty = ns.Style.Text(window.body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"), "muted")
    custom.empty:SetPoint("CENTER", custom.scrollBox, "CENTER")
    custom.empty:SetWidth(360)
    custom.empty:SetText("Add a category to group items your own way. It takes the selected item's icon.")

    return custom.scrollBox
end

---------------------------------------------------------------------------
-- Filter list
---------------------------------------------------------------------------

local function initRow(row, entry)
    if not row.icon then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)

        row.remove = CreateFrame("Button", nil, row)
        row.remove:SetSize(18, 18)
        row.remove:SetPoint("RIGHT", -4, 0)
        row.remove:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        row.remove:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
        row.remove:SetScript("OnClick", function(self)
            setOverride(self:GetParent().entry.itemID, nil)
        end)
        row.remove:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Remove filter")
            GameTooltip:Show()
        end)
        row.remove:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.category = ns.Style.Text(row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), "text")
        row.category:SetPoint("RIGHT", row.remove, "LEFT", -8, 0)
        row.category:SetWidth(170)
        row.category:SetJustifyH("LEFT")
        row.category:SetWordWrap(false)

        row.name = ns.Style.Text(row:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), "text")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.category, "LEFT", -8, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        ns.Style.DecorateRow(row)
        row:SetScript("OnClick", function(self) selectItem(self.entry.itemID) end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.entry.itemID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to edit.", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    row.entry = entry
    ns.Style.SetRowStripe(row, row.GetElementDataIndex and row:GetElementDataIndex() or 1)
    row.selected:SetShown(selected ~= nil and selected.itemID == entry.itemID)
    row.icon:SetTexture(itemIcon(entry.itemID))
    row.name:SetText(coloredName(entry.itemID))
    row.category:SetText(categoryText(entry.key))
end

local function refreshList()
    local list = {}
    for itemID, key in pairs(ns.db.overrides) do
        table.insert(list, { itemID = itemID, key = key, sortName = (itemName(itemID) or ""):lower() })
    end
    table.sort(list, function(a, b)
        if a.sortName ~= b.sortName then return a.sortName < b.sortName end
        return a.itemID < b.itemID
    end)
    local data = CreateDataProvider()
    for _, entry in ipairs(list) do
        data:Insert(entry)
    end
    window.scrollBox:SetDataProvider(data, true)
    window.empty:SetShown(#list == 0)
    window.listTitle:SetText(("Item filters (%d)"):format(#list))
end

function refresh()
    if not (window and window:IsShown()) then return end
    refreshSelection()
    refreshCustom()
    refreshList()
    refreshPicker()
end

-- Item names arrive in bursts after GET_ITEM_INFO_RECEIVED; refresh once per burst.
local function queueRefresh()
    if refreshQueued or not (window and window:IsShown()) then return end
    refreshQueued = true
    C_Timer.After(0.2, function()
        refreshQueued = nil
        refresh()
    end)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function createWindow()
    window = ns.Style.CreateWindow("CraftCourierFilterFrame", "CraftCourier Item Filters", 500, 660)
    window:SetPoint("CENTER")
    local body = window.body

    createTop()
    createPicker()

    local divider = ns.Style.Divider(body)
    divider:SetPoint("TOPLEFT", window.top, "BOTTOMLEFT", 6, -4)
    divider:SetPoint("TOPRIGHT", window.top, "BOTTOMRIGHT", -6, -4)

    local customList = createCustomSection(divider)

    local divider2 = ns.Style.Divider(body)
    divider2:SetPoint("TOPLEFT", customList, "BOTTOMLEFT", 6, -8)
    divider2:SetPoint("RIGHT", body, "RIGHT", -6, 0)

    window.listTitle = ns.Style.Text(body:CreateFontString(nil, "OVERLAY", "GameFontNormal"), "heading")
    window.listTitle:SetPoint("TOPLEFT", divider2, "BOTTOMLEFT", 4, -10)

    window.scrollBox = CreateFrame("Frame", nil, body, "WowScrollBoxList")
    window.scrollBox:SetPoint("TOPLEFT", window.listTitle, "BOTTOMLEFT", -6, -8)
    window.scrollBox:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -20, 2)

    window.scrollBar = CreateFrame("EventFrame", nil, body, "MinimalScrollBar")
    window.scrollBar:SetPoint("TOPLEFT", window.scrollBox, "TOPRIGHT", 6, 0)
    window.scrollBar:SetPoint("BOTTOMLEFT", window.scrollBox, "BOTTOMRIGHT", 6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(window.scrollBox, window.scrollBar, view)

    window.empty = ns.Style.Text(body:CreateFontString(nil, "OVERLAY", "GameFontDisable"), "muted")
    window.empty:SetPoint("CENTER", window.scrollBox, "CENTER")
    window.empty:SetWidth(360)
    window.empty:SetText("No item filters yet. Choose an item above to add one.")

    window:SetScript("OnShow", refresh)
    window:SetScript("OnHide", function()
        window.picker:Hide()
        resetCustomEdit()
    end)
end

function ns:ToggleFilters()
    if not window then createWindow() end
    window:SetShown(not window:IsShown())
end

-- Opens the window with an item already in the slot (e.g. /ccr filters [item]).
function ns:ShowFilters(itemID)
    if not window then createWindow() end
    window:Show()
    if itemID then selectItem(itemID) end
end

ns:On("CONFIG_CHANGED", refresh)
ns:On("STYLE_CHANGED", refresh)
ns:RegisterEvent("BAG_UPDATE_DELAYED", queueRefresh)
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", queueRefresh)
