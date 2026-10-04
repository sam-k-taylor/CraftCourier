local _, ns = ...

-- Window listing the send log, newest first, with a text filter.

local ROW_HEIGHT = 20
local COLUMNS = {
    { key = "when",  label = "When",  width = 110 },
    { key = "from",  label = "From",  width = 120 },
    { key = "to",    label = "To",    width = 120 },
    { key = "items", label = "Items", width = 250 },
}

local window

local function itemSummary(entry)
    local parts = {}
    for _, item in ipairs(entry.items) do
        table.insert(parts, ("%dx %s"):format(item.count, item.name or ("item:" .. item.id)))
    end
    return table.concat(parts, ", ")
end

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
    GameTooltip:AddLine(("%s-%s  ->  %s"):format(entry.from or "?", entry.realm or "?", entry.to or "?"), 1, 1, 1)
    GameTooltip:AddLine(entry.mode == "review" and "Review and Send" or "One Click Send", 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    for _, item in ipairs(entry.items) do
        GameTooltip:AddDoubleLine(("|T%s:14|t %s"):format(item.icon or "", item.name or ("item:" .. item.id)),
            item.count, 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function initRow(row, entry)
    if not row.cells then
        row.cells = {}
        local x = 4
        for _, col in ipairs(COLUMNS) do
            local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cell:SetPoint("LEFT", x, 0)
            cell:SetWidth(col.width - 8)
            cell:SetJustifyH("LEFT")
            cell:SetWordWrap(false)
            row.cells[col.key] = cell
            x = x + col.width
        end
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:SetScript("OnEnter", showEntryTooltip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    row.entry = entry
    row.cells.when:SetText(date("%Y-%m-%d %H:%M", entry.time))
    row.cells.from:SetText(entry.from or "?")
    row.cells.to:SetText(entry.to or "?")
    row.cells.items:SetText(itemSummary(entry))
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
    local width = 24 + 20
    for _, col in ipairs(COLUMNS) do width = width + col.width end

    window = CreateFrame("Frame", "CraftCourierLogFrame", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(width, 440)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    if UISpecialFrames then
        tinsert(UISpecialFrames, window:GetName())
    end

    local title = window.TitleText or window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not window.TitleText then
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("CraftCourier Log")

    local searchLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("TOPLEFT", 16, -36)
    searchLabel:SetText("Filter:")

    window.search = CreateFrame("EditBox", nil, window, "InputBoxTemplate")
    window.search:SetSize(200, 20)
    window.search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
    window.search:SetAutoFocus(false)
    window.search:SetScript("OnTextChanged", refresh)
    window.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    window.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    window.count = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    window.count:SetPoint("LEFT", window.search, "RIGHT", 12, 0)

    -- Clearing needs a second click within a few seconds, instead of a popup.
    local clear = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    clear:SetSize(130, 22)
    clear:SetPoint("TOPRIGHT", -14, -32)
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

    local x = 16
    for _, col in ipairs(COLUMNS) do
        local header = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", x, -66)
        header:SetText(col.label)
        x = x + col.width
    end

    window.scrollBox = CreateFrame("Frame", nil, window, "WowScrollBoxList")
    window.scrollBox:SetPoint("TOPLEFT", 12, -84)
    window.scrollBox:SetPoint("BOTTOMRIGHT", -30, 12)

    window.scrollBar = CreateFrame("EventFrame", nil, window, "MinimalScrollBar")
    window.scrollBar:SetPoint("TOPLEFT", window.scrollBox, "TOPRIGHT", 6, 0)
    window.scrollBar:SetPoint("BOTTOMLEFT", window.scrollBox, "BOTTOMRIGHT", 6, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(window.scrollBox, window.scrollBar, view)

    window.empty = window:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    window.empty:SetPoint("CENTER", window.scrollBox, "CENTER")
    window.empty:SetText("No mail logged yet.")

    window:SetScript("OnShow", refresh)
end

function ns:ToggleLog()
    if not window then createWindow() end
    window:SetShown(not window:IsShown())
end

ns:On("LOG_UPDATED", refresh)
