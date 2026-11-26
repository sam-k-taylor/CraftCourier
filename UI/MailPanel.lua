local _, ns = ...

-- The CraftCourier send panel: one row per category with items in the bags.
-- "One Click Send" mails everything immediately, "Review and Send" fills in
-- the send form and leaves the user to press Send.
--
-- The same content frame has two homes (ns:PlaceMailPanel):
--   embedded - the right half of the extended Send Mail tab (UI/Mailbox.lua)
--   docked   - a separate window beside the mailbox, as in older versions

local DOCKED_WIDTH = 270
local ROW_HEIGHT = 46
local ROW_SPACING = 4
local BUTTON_HEIGHT = 20

local content, docked
local embedded = false
local extendedMode = false -- UI/Mailbox.lua has widened the mailbox
local placedIn             -- the frame content is currently anchored in
local dockedClosed = false -- the user closed the docked window this visit
local lastScan = {}
local finished             -- { text, expires } after a batch completes
local FINISHED_SHOW_TIME = 8
local PROGRESS_HEIGHT = 20

local function showRowTooltip(row)
    local data = row.data
    if not data then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns:CategoryDisplayName(data.category))
    if data.recipient then
        GameTooltip:AddLine("To: " .. data.recipient, 1, 1, 1)
    else
        GameTooltip:AddLine("No recipient set. Set one in Settings.", 1, 0.3, 0.3)
    end
    GameTooltip:AddLine(" ")
    for _, item in pairs(data.entry.items) do
        GameTooltip:AddDoubleLine(("|T%s:14|t %s"):format(item.icon or "", item.name), item.count, 1, 1, 1, 1, 1, 1)
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

-- Width comes from anchors.
local function createButton(parent, text, onClick)
    return ns.Style.Button(parent, text, nil, BUTTON_HEIGHT, onClick)
end

local function initRow(row, data)
    if not row.label then
        row:EnableMouse(true)
        row:SetScript("OnEnter", showRowTooltip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("TOPLEFT", 2, -2)
        row.label:SetPoint("TOPRIGHT", -2, -2)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        ns.Style.Text(row.label, "heading")

        -- Each button takes half the row, whatever width the list gives it.
        row.send = createButton(row, "One Click Send", function(self)
            start({ self:GetParent().data.category.key }, "auto")
        end)
        row.send:SetPoint("BOTTOMLEFT", 0, ROW_SPACING)
        row.send:SetPoint("BOTTOMRIGHT", row, "BOTTOM", -2, ROW_SPACING)

        row.review = createButton(row, "Review and Send", function(self)
            start({ self:GetParent().data.category.key }, "review")
        end)
        row.review:SetPoint("BOTTOMLEFT", row, "BOTTOM", 2, ROW_SPACING)
        row.review:SetPoint("BOTTOMRIGHT", 0, ROW_SPACING)
    end

    row.data = data
    -- Rebuilt on STYLE_CHANGED, since the colours come from the style.
    row.label:SetText(("|T%s:16|t %s (%d) %s %s"):format(
        data.category.icon, ns:CategoryDisplayName(data.category), data.entry.total,
        ns.Style.Colorize("->", "text"),
        data.recipient and ns.Style.Colorize(ns.Style.ColorName(data.recipient), "text") or ns.Style.Colorize("no recipient", "bad")))
    local enabled = data.recipient ~= nil and not ns.Mailer:IsBusy()
    row.send:SetEnabled(enabled)
    row.review:SetEnabled(enabled)
end

local function createContent()
    content = CreateFrame("Frame")

    content.title = ns.Style.Text(content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), "heading")
    content.title:SetPoint("TOPLEFT", 2, 0)
    content.title:SetText(ns.Style.Logo(20) .. " CraftCourier")

    -- Separates the embedded panel from Blizzard's send form.
    content.divider = ns.Style.Divider(content, true)
    content.divider:SetPoint("TOPRIGHT", content, "TOPLEFT", -6, 0)
    content.divider:SetPoint("BOTTOMRIGHT", content, "BOTTOMLEFT", -6, 0)

    content.scrollBox = CreateFrame("Frame", nil, content, "WowScrollBoxList")
    content.scrollBar = CreateFrame("EventFrame", nil, content, "MinimalScrollBar")
    content.scrollBar:SetPoint("TOPLEFT", content.scrollBox, "TOPRIGHT", 4, 0)
    content.scrollBar:SetPoint("BOTTOMLEFT", content.scrollBox, "BOTTOMRIGHT", 4, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Frame", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(content.scrollBox, content.scrollBar, view)

    content.empty = ns.Style.Text(content:CreateFontString(nil, "OVERLAY", "GameFontDisable"), "muted")
    content.empty:SetPoint("TOP", content.scrollBox, "TOP", 0, -8)
    content.empty:SetText("Nothing to send.")

    -- Progress while sending ("Mail 3 of 8"), then the result in green for a
    -- few seconds.
    content.progress = ns.Style.ProgressBar(content, PROGRESS_HEIGHT)
    content.progress:Hide()
    content.status = content.progress.text

    -- Doubles as "Stop" while the mailer is busy.
    content.sendAll = createButton(content, "Send All", function()
        if ns.Mailer:IsBusy() then
            ns.Mailer:Stop("Stopped.", true)
        else
            start(allKeys(), "auto")
        end
    end)
    content.reviewAll = createButton(content, "Review All", function()
        start(allKeys(), "review")
    end)
    content.settings = createButton(content, "Settings", function() ns:ShowSettings() end)
    content.log = createButton(content, "Log", function() ns:ToggleLog() end)

    content:SetScript("OnShow", function() ns:RefreshMailPanel() end)
end

-- Embedded: one row of buttons along the bottom, level with Blizzard's
-- Send/Cancel. Settings is a tab there, so its button is hidden.
-- Docked: two rows of two, as before.
local function layout()
    local buttons = { content.sendAll, content.reviewAll, content.settings, content.log }
    for _, button in ipairs(buttons) do
        button:ClearAllPoints()
    end
    content.progress:ClearAllPoints()
    content.scrollBox:ClearAllPoints()

    local footer
    if embedded then
        content.settings:Hide()
        content.sendAll:SetPoint("BOTTOMLEFT", 0, 0)
        content.sendAll:SetPoint("BOTTOMRIGHT", content, "BOTTOMLEFT", 116, 0)
        content.reviewAll:SetPoint("TOPLEFT", content.sendAll, "TOPRIGHT", 4, 0)
        content.reviewAll:SetPoint("BOTTOMRIGHT", content, "BOTTOMLEFT", 236, 0)
        content.log:SetPoint("TOPLEFT", content.reviewAll, "TOPRIGHT", 4, 0)
        content.log:SetPoint("BOTTOMRIGHT", 0, 0)
        footer = BUTTON_HEIGHT + 4
    else
        content.settings:Show()
        content.settings:SetPoint("BOTTOMLEFT", 0, 0)
        content.settings:SetPoint("BOTTOMRIGHT", content, "BOTTOM", -2, 0)
        content.log:SetPoint("BOTTOMLEFT", content, "BOTTOM", 2, 0)
        content.log:SetPoint("BOTTOMRIGHT", 0, 0)
        content.sendAll:SetPoint("BOTTOMLEFT", content.settings, "TOPLEFT", 0, 6)
        content.sendAll:SetPoint("BOTTOMRIGHT", content.settings, "TOPRIGHT", 0, 6)
        content.reviewAll:SetPoint("BOTTOMLEFT", content.log, "TOPLEFT", 0, 6)
        content.reviewAll:SetPoint("BOTTOMRIGHT", content.log, "TOPRIGHT", 0, 6)
        footer = 2 * BUTTON_HEIGHT + 10
    end

    content.progress:SetPoint("BOTTOMLEFT", 0, footer + 4)
    content.progress:SetPoint("BOTTOMRIGHT", 0, footer + 4)

    local top = embedded and 26 or 0
    content.title:SetShown(embedded)
    content.divider:SetShown(embedded)
    content.scrollBox:SetPoint("TOPLEFT", 0, -top)
    content.scrollBox:SetPoint("BOTTOMRIGHT", -16, footer + PROGRESS_HEIGHT + 10)
end

local function createDocked()
    -- Closing the window keeps it closed until the mailbox is next opened,
    -- rather than until the next tab switch.
    docked = ns.Style.CreateWindow("CraftCourierMailPanel", "CraftCourier", DOCKED_WIDTH, 400, {
        parent = MailFrame, strata = "HIGH", movable = false, closeOnEscape = false,
        compact = true, -- same title bar as the mailbox beside it
        onClose = function() dockedClosed = true end,
    })
    docked:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
    docked:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMRIGHT", 4, 0)
end

-- Extended mailbox: embedded on the Send Mail tab, docked on the Inbox tab
-- (the inbox list needs the full width), neither on the Settings tab.
-- Plain mailbox: docked on every tab.
local function place()
    local embed = extendedMode and SendMailFrame:IsShown()
    local showDocked = not embed and ns.db.showPanel and not dockedClosed
        and (not extendedMode or InboxFrame:IsShown())
        -- Blizzard opens a letter exactly where the docked window sits.
        and not (OpenMailFrame and OpenMailFrame:IsShown())

    local home = embed and SendMailFrame or docked
    if home ~= placedIn then
        placedIn = home
        embedded = embed
        content:ClearAllPoints()
        if embedded then
            -- Blizzard's form keeps the left half (SendMailFrame is pinned to its
            -- original width); the panel fills the rest of the Send Mail tab.
            content:SetParent(SendMailFrame)
            content:SetPoint("TOPLEFT", SendMailFrame, "TOPRIGHT", 14, -88)
            content:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -10, 5)
        else
            content:SetParent(docked)
            content:SetPoint("TOPLEFT", docked.body, "TOPLEFT", 2, -2)
            content:SetPoint("BOTTOMRIGHT", docked.body, "BOTTOMRIGHT", -2, 2)
        end
        content:Show()
        layout()
    end
    docked:SetShown(showDocked)
    ns:RefreshMailPanel()
end

local function hookPlacement()
    local frames = { InboxFrame, SendMailFrame, OpenMailFrame }
    for _, frame in pairs(frames) do
        frame:HookScript("OnShow", place)
        frame:HookScript("OnHide", place)
    end
end

-- Called by UI/Mailbox.lua whenever the mailbox is extended or restored.
function ns:PlaceMailPanel(extended)
    if not MailFrame then return end
    if not content then
        createContent()
        createDocked()
        hookPlacement()
    end
    extendedMode = extended
    place()
end

local function statusText()
    local sent, total = ns.Mailer:GetProgress()
    if ns.Mailer:GetMode() == "review" then
        return ("Mail %d of %d is ready. Check it, then click Send."):format(sent + 1, total)
    end
    return ("Sending mail %d of %d..."):format(sent + 1, total)
end

local function updateProgress()
    local progress, bar = content.progress, content.progress.bar
    if ns.Mailer:IsBusy() then
        local sent, total = ns.Mailer:GetProgress()
        bar:SetMinMaxValues(0, math.max(total, 1))
        bar:SetValue(sent)
        progress:SetState("progress")
        content.status:SetText(statusText())
        progress:Show()
    elseif finished and GetTime() < finished.expires then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        progress:SetState("success")
        content.status:SetText(finished.text)
        progress:Show()
    else
        finished = nil
        progress:Hide()
    end
end

function ns:RefreshMailPanel()
    if not content or not content:IsVisible() then return end

    local busy = ns.Mailer:IsBusy()
    lastScan = ns:ScanBags()

    local data = CreateDataProvider()
    local anySendable = false
    for _, cat in ipairs(ns.categories) do
        local entry = lastScan[cat.key]
        local recipient = ns:GetRecipient(cat.key)
        -- Hide categories this character is the recipient for; it already has them.
        if entry and not (recipient and ns:IsSelf(recipient)) then
            data:Insert({ category = cat, entry = entry, recipient = recipient })
            anySendable = anySendable or recipient ~= nil
        end
    end
    content.scrollBox:SetDataProvider(data, true)

    content.empty:SetShown(data:GetSize() == 0)
    content.sendAll:SetText(busy and "Stop" or "Send All")
    content.sendAll:SetEnabled(busy or anySendable)
    content.reviewAll:SetEnabled(anySendable and not busy)
    updateProgress()
end

ns:RegisterEvent("MAIL_SHOW", function()
    dockedClosed = false
    if content then place() end
end)
ns:RegisterEvent("BAG_UPDATE_DELAYED", function() ns:RefreshMailPanel() end)
-- A First Aid skill-up can move the kept cloth to the next tier.
ns:RegisterEvent("SKILL_LINES_CHANGED", function() ns:RefreshMailPanel() end)

-- BoE detection needs item info that may not be cached on first scan. These
-- events can arrive in bursts, so refresh at most once per short delay.
local refreshQueued = false
ns:RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
    if refreshQueued or not (content and content:IsVisible()) then return end
    refreshQueued = true
    C_Timer.After(0.2, function()
        refreshQueued = false
        ns:RefreshMailPanel()
    end)
end)
ns:On("MAILER_STATE", function() ns:RefreshMailPanel() end)
ns:On("MAILER_FINISHED", function(sent, alts)
    if sent == 0 then return end
    finished = { text = ns:SentSummary(sent, alts), expires = GetTime() + FINISHED_SHOW_TIME }
    ns:RefreshMailPanel()
    C_Timer.After(FINISHED_SHOW_TIME + 0.1, function() ns:RefreshMailPanel() end)
end)
ns:On("CONFIG_CHANGED", function() ns:RefreshMailPanel() end)
ns:On("STYLE_CHANGED", function() ns:RefreshMailPanel() end)
