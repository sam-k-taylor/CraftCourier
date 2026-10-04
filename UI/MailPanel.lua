local _, ns = ...

-- Panel docked to the right of the mailbox. Each category row has two actions:
-- "One Click Send" mails everything immediately, "Review and Send" fills in the
-- send form and leaves the user to press Send.

local PANEL_WIDTH = 270
local ROW_HEIGHT = 46
local ROW_SPACING = 4
local TOP_OFFSET = 30
local BUTTON_HEIGHT = 20
local FOOTER_HEIGHT = 90

local panel
local rows = {}
local lastScan = {}

local function showRowTooltip(row)
    local cat = row.category
    local entry = lastScan[cat.key]
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns:CategoryDisplayName(cat))
    local recipient = ns:GetRecipient(cat.key)
    if recipient then
        GameTooltip:AddLine("To: " .. recipient, 1, 1, 1)
    else
        GameTooltip:AddLine("No recipient set. Type /craftcourier to set one.", 1, 0.3, 0.3)
    end
    if entry then
        GameTooltip:AddLine(" ")
        for _, item in pairs(entry.items) do
            GameTooltip:AddDoubleLine(("|T%s:14|t %s"):format(item.icon or "", item.name), item.count, 1, 1, 1, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function start(keys, mode)
    if ns.Mailer:Queue(keys) > 0 then
        ns.Mailer:Start(mode)
    else
        ns:Print("Nothing to send.")
    end
end

local function allKeys()
    local keys = {}
    for _, cat in ipairs(ns.categories) do
        table.insert(keys, cat.key)
    end
    return keys
end

local function createButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, BUTTON_HEIGHT)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function createRow(index)
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(PANEL_WIDTH - 24, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -(TOP_OFFSET + (index - 1) * (ROW_HEIGHT + ROW_SPACING)))
    row:EnableMouse(true)
    row:SetScript("OnEnter", showRowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("TOPLEFT", 2, -2)
    row.label:SetPoint("TOPRIGHT", -2, -2)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    local halfWidth = (PANEL_WIDTH - 24 - 4) / 2
    row.send = createButton(row, "One Click Send", halfWidth, function()
        start({ row.category.key }, "auto")
    end)
    row.send:SetPoint("BOTTOMLEFT")

    row.review = createButton(row, "Review and Send", halfWidth, function()
        start({ row.category.key }, "review")
    end)
    row.review:SetPoint("BOTTOMRIGHT")

    rows[index] = row
    return row
end

local function createPanel()
    panel = CreateFrame("Frame", "CraftCourierMailPanel", MailFrame, "BasicFrameTemplateWithInset")
    panel:SetWidth(PANEL_WIDTH)
    panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
    panel:SetFrameStrata("HIGH")

    local title = panel.TitleText or panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not panel.TitleText then
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("CraftCourier")

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    panel.empty:SetPoint("TOP", 0, -TOP_OFFSET - 4)
    panel.empty:SetText("Nothing to send.")

    panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.status:SetPoint("BOTTOMLEFT", 12, 64)
    panel.status:SetPoint("BOTTOMRIGHT", -12, 64)

    local halfWidth = (PANEL_WIDTH - 24 - 4) / 2

    -- Doubles as "Stop" while the mailer is busy.
    panel.sendAll = createButton(panel, "Send All", halfWidth, function()
        if ns.Mailer:IsBusy() then
            ns.Mailer:Stop("Stopped.", true)
        else
            start(allKeys(), "auto")
        end
    end)
    panel.sendAll:SetPoint("BOTTOMLEFT", 12, 38)

    panel.reviewAll = createButton(panel, "Review All", halfWidth, function()
        start(allKeys(), "review")
    end)
    panel.reviewAll:SetPoint("LEFT", panel.sendAll, "RIGHT", 4, 0)

    panel.options = createButton(panel, "Settings", halfWidth, function() ns:ToggleConfig() end)
    panel.options:SetPoint("BOTTOMLEFT", 12, 12)

    panel.log = createButton(panel, "Log", halfWidth, function() ns:ToggleLog() end)
    panel.log:SetPoint("LEFT", panel.options, "RIGHT", 4, 0)
end

local function statusText()
    if not ns.Mailer:IsBusy() then return "" end
    local sent, total = ns.Mailer:GetProgress()
    if ns.Mailer:GetMode() == "review" then
        return ("Mail %d of %d is ready. Check it, then click Send."):format(sent + 1, total)
    end
    return ("Sending mail %d of %d..."):format(sent + 1, total)
end

function ns:RefreshMailPanel()
    if not panel or not panel:IsShown() then return end

    local busy = ns.Mailer:IsBusy()
    lastScan = ns:ScanBags()

    local shown, anySendable = 0, false
    for _, cat in ipairs(ns.categories) do
        local entry = lastScan[cat.key]
        local recipient = ns:GetRecipient(cat.key)
        -- Hide categories this character is the recipient for; it already has them.
        if entry and not (recipient and ns:IsSelf(recipient)) then
            shown = shown + 1
            local row = rows[shown] or createRow(shown)
            row.category = cat
            row.label:SetText(("|T%s:16|t %s (%d) |cffffffff-> %s|r"):format(
                cat.icon, ns:CategoryDisplayName(cat), entry.total, recipient or "|cffff5555no recipient|r"))
            local enabled = recipient ~= nil and not busy
            row.send:SetEnabled(enabled)
            row.review:SetEnabled(enabled)
            row:Show()
            anySendable = anySendable or recipient ~= nil
        end
    end
    for i = shown + 1, #rows do
        rows[i]:Hide()
    end

    panel.empty:SetShown(shown == 0)
    panel.sendAll:SetText(busy and "Stop" or "Send All")
    panel.sendAll:SetEnabled(busy or anySendable)
    panel.reviewAll:SetEnabled(anySendable and not busy)
    panel.status:SetText(statusText())

    local listHeight = math.max(shown, 1) * (ROW_HEIGHT + ROW_SPACING)
    panel:SetHeight(TOP_OFFSET + listHeight + FOOTER_HEIGHT)
end

ns:RegisterEvent("MAIL_SHOW", function()
    if not ns.db or not ns.db.showPanel then return end
    if not panel then createPanel() end
    panel:Show()
    ns:RefreshMailPanel()
end)

ns:RegisterEvent("BAG_UPDATE_DELAYED", function() ns:RefreshMailPanel() end)

-- BoE detection needs item info that may not be cached on first scan. These
-- events can arrive in bursts, so refresh at most once per short delay.
local refreshQueued = false
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
    if refreshQueued or not (panel and panel:IsShown()) then return end
    refreshQueued = true
    C_Timer.After(0.2, function()
        refreshQueued = false
        ns:RefreshMailPanel()
    end)
end)
ns:On("MAILER_STATE", function() ns:RefreshMailPanel() end)
ns:On("CONFIG_CHANGED", function() ns:RefreshMailPanel() end)
