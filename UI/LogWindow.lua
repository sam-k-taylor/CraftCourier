local _, ns = ...

-- Window listing the send log, newest first, with a text filter. Names are
-- in class colour when they're recorded alts; items show as icons.

local ROW_HEIGHT = 24
local ITEM_ICON = 20
local ITEM_GAP = 2
local MORE_WIDTH = 30
local COLUMNS = {
    { key = "when",  label = "When",  width = 110 },
    { key = "from",  label = "From",  width = 120 },
    { key = "to",    label = "To",    width = 120 },
    { key = "items", label = "Items", width = 250 },
}

local window

local itemsWidth
for _, col in ipairs(COLUMNS) do
    if col.key == "items" then itemsWidth = col.width end
end
-- As many icons as fit, leaving room for "+N".
local MAX_ITEM_ICONS = math.floor((itemsWidth - 8 - MORE_WIDTH) / (ITEM_ICON + ITEM_GAP))

local function matchesFilter(entry, filter)
    if filter == "" then return true end
    local function has(text)
        return text and text:lower():find(filter, 1, true)
    end
    if has(entry.from) or has(entry.to) or has(entry.realm) then return true end
    for _, item in ipairs(entry.items) do
        if has(item.name) then return true end
    end
    return false
end

local function showEntryTooltip(row)
    local entry = row.entry
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(date("%Y-%m-%d %H:%M:%S", entry.time))
    -- The tooltip is Blizzard's, so names use the Blizzard palette.
    GameTooltip:AddLine(("%s-%s  ->  %s"):format(ns.Style.ColorName(entry.from, "blizzard") or "?", entry.realm or "?",
        ns.Style.ColorName(entry.to, "blizzard") or "?"), 1, 1, 1)
    GameTooltip:AddLine(entry.mode == "review" and "Review and Send" or "One Click Send", 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    for _, item in ipairs(entry.items) do
        GameTooltip:AddDoubleLine(("|T%s:14|t %s"):format(item.icon or "", item.name or ("item:" .. item.id)),
            item.count, 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function buildRow(row)
    ns.Style.DecorateRow(row)
    row.cells = {}
    local x = 4
    for _, col in ipairs(COLUMNS) do
        if col.key == "items" then
            row.itemsX = x
        else
            local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cell:SetPoint("LEFT", x, 0)
            cell:SetWidth(col.width - 8)
            cell:SetJustifyH("LEFT")
            cell:SetWordWrap(false)
            ns.Style.Text(cell, "text")
            row.cells[col.key] = cell
        end
        x = x + col.width
    end

    row.icons = {}
    for i = 1, MAX_ITEM_ICONS do
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ITEM_ICON, ITEM_ICON)
        icon:SetPoint("LEFT", row.itemsX + (i - 1) * (ITEM_ICON + ITEM_GAP), 0)
        local count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 0)
        row.icons[i] = { icon = icon, count = count }
    end
    row.more = ns.Style.Text(row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), "muted")
    row.more:SetPoint("LEFT", row.itemsX + MAX_ITEM_ICONS * (ITEM_ICON + ITEM_GAP) + 2, 0)

    row:SetScript("OnEnter", showEntryTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function initRow(row, entry)
    if not row.cells then buildRow(row) end
    row.entry = entry
    local index = row.GetElementDataIndex and row:GetElementDataIndex() or 1
    ns.Style.SetRowStripe(row, index)
    row.cells.when:SetText(date("%Y-%m-%d %H:%M", entry.time))
    row.cells.from:SetText(ns.Style.ColorName(entry.from) or "?")
    row.cells.to:SetText(ns.Style.ColorName(entry.to) or "?")

    for i, slot in ipairs(row.icons) do
        local item = entry.items[i]
        slot.icon:SetShown(item ~= nil)
        slot.count:SetShown(item ~= nil)
        if item then
            slot.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            slot.count:SetText(item.count > 1 and item.count or "")
        end
    end
    local extra = #entry.items - MAX_ITEM_ICONS
    row.more:SetText(extra > 0 and ("+" .. extra) or "")
end

local function refresh()
    if not (window and window:IsShown()) then return end
    local filter = strtrim(window.search:GetText() or ""):lower()
    local data = CreateDataProvider()
    local log = ns.db.log
    for i = #log, 1, -1 do
        if matchesFilter(log[i], filter) then
            data:Insert(log[i])
        end
    end
    window.scrollBox:SetDataProvider(data, true)
    window.empty:SetShown(data:GetSize() == 0)
    window.count:SetText(("%d of %d mail(s)"):format(data:GetSize(), #log))
end

local function createWindow()
    local width = 24 + 20 + 16
    for _, col in ipairs(COLUMNS) do width = width + col.width end

    window = ns.Style.CreateWindow("CraftCourierLogFrame", "CraftCourier Log", width, 480)
    window:SetPoint("CENTER")
    local body = window.body

    local searchLabel = ns.Style.Text(body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"), "heading")
    searchLabel:SetPoint("TOPLEFT", body, "TOPLEFT", 6, -8)
    searchLabel:SetText("Filter:")

    window.search = CreateFrame("EditBox", nil, body, "InputBoxTemplate")
    window.search:SetSize(200, 20)
    window.search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    window.search:SetAutoFocus(false)
    window.search:SetScript("OnTextChanged", refresh)
    window.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    window.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    ns.Style.SkinEditBox(window.search)

    window.count = ns.Style.Text(body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"), "muted")
    window.count:SetPoint("LEFT", window.search, "RIGHT", 12, 0)

    -- Clearing needs a second click within a few seconds, instead of a popup.
    local clear = ns.Style.Button(body, "Clear Log", 130, 22)
    clear:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -2)
    clear:SetText("Clear Log")
    clear:SetScript("OnClick", function(self)
        if self.armed then
            self.armed = nil
            self:SetText("Clear Log")
            ns:ClearLog()
        else
            self.armed = true
            self:SetText("Click to confirm")
            C_Timer.After(3, function()
                if self.armed then
                    self.armed = nil
                    self:SetText("Clear Log")
                end
            end)
        end
    end)

    local x = 6
    for _, col in ipairs(COLUMNS) do
        local header = ns.Style.Text(body:CreateFontString(nil, "OVERLAY", "GameFontNormal"), "heading")
        header:SetPoint("TOPLEFT", body, "TOPLEFT", x, -38)
        header:SetText(col.label)
        x = x + col.width
    end
    local rule = ns.Style.Divider(body)
    rule:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -54)
    rule:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, -54)

    window.scrollBox = CreateFrame("Frame", nil, body, "WowScrollBoxList")
    window.scrollBox:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -58)
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
    window.empty:SetText("No mail logged yet.")

    window:SetScript("OnShow", refresh)
end

function ns:ToggleLog()
    if not window then createWindow() end
    window:SetShown(not window:IsShown())
end

ns:On("LOG_UPDATED", refresh)
ns:On("STYLE_CHANGED", refresh) -- names are coloured by style
