local _, ns = ...

-- Replaces Blizzard's paged inbox (7 mails per page) with a summary and one
-- scrolling list of every mail the client has. The view is a child of
-- InboxFrame, so it shows and hides with the Inbox tab. Opening a mail still
-- uses Blizzard's letter view (OpenMailFrame).
--
-- Blizzard's paged widgets are moved to a hidden frame rather than hidden,
-- because InboxFrame:Update and the gamepad code keep calling Show on them.

local ROW_HEIGHT = 44
local ICON_SIZE = 36
local ATTACH_SIZE = 22
local MAX_ATTACH_ICONS = 5
local MAX_RECEIVE = ATTACHMENTS_MAX_RECEIVE or 16
local EXPIRY_WARN_DAYS = 3
local ATTACH_X = 260 -- left edge of the attachment icons in a row

local view
local stash
local stashed = {}
local active = false

local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor

---------------------------------------------------------------------------
-- Reading the inbox
---------------------------------------------------------------------------

local function readMail(index)
    local packageIcon, stationeryIcon, sender, subject, money, cod, daysLeft, itemCount,
        wasRead, wasReturned, _, _, isGM = GetInboxHeaderInfo(index)
    local mail = {
        index = index,
        icon = (packageIcon and not isGM) and packageIcon or stationeryIcon,
        sender = sender or UNKNOWN or "Unknown",
        subject = subject or "",
        money = money or 0,
        cod = cod or 0,
        daysLeft = daysLeft or 0,
        wasRead = wasRead,
        wasReturned = wasReturned,
        isGM = isGM,
        items = {},
        itemTotal = 0,
    }
    if itemCount and itemCount > 0 then
        for slot = 1, MAX_RECEIVE do
            local name, itemID, texture, count, quality = GetInboxItem(index, slot)
            if name or itemID then
                count = count or 1
                table.insert(mail.items, {
                    slot = slot, name = name, id = itemID, icon = texture, count = count, quality = quality,
                })
                mail.itemTotal = mail.itemTotal + count
            end
        end
    end
    return mail
end

local function moneyText(copper)
    if GetMoneyString then
        return GetMoneyString(copper, true)
    end
    return ("%dg %ds %dc"):format(copper / 10000, (copper / 100) % 100, copper % 100)
end

local function plural(n, word)
    return ("|cffffffff%d|r %s%s"):format(n, word, n == 1 and "" or "s")
end

local function expiryText(days)
    if days >= 1 then
        local color = days < EXPIRY_WARN_DAYS and "|cffff9900" or "|cff20ff20"
        return color .. (DAYS_ABBR and DAYS_ABBR:format(math.floor(days)) or ("%dd"):format(days)) .. "|r"
    end
    local seconds = math.floor(days * 24 * 60 * 60)
    return "|cffff2020" .. (SecondsToTime and SecondsToTime(seconds) or ("%dm"):format(seconds / 60)) .. "|r"
end

local function qualityColor(quality)
    if quality and GetItemQualityColor then
        local r, g, b = GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    return 1, 1, 1
end

local function isOpen(index)
    return OpenMailFrame and OpenMailFrame:IsShown() and InboxFrame.openMailID == index
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

-- Reuses Blizzard's click handler so the letter view behaves as usual; it only
-- reads GetChecked from the button it's given.
local function toggleMail(index)
    local open = not isOpen(index)
    InboxFrame_OnClick({ GetChecked = function() return open end }, index)
end

-- Takes all items and gold. COD mail has to be opened and paid by hand,
-- as with Blizzard's Open All.
local function takeAll(mail)
    if mail.cod > 0 then
        toggleMail(mail.index)
    elseif not (C_Mail and C_Mail.IsCommandPending and C_Mail.IsCommandPending()) then
        AutoLootMailItem(mail.index)
    end
end

local function takeItem(mail, slot)
    if mail.cod > 0 then
        toggleMail(mail.index)
    else
        TakeInboxItem(mail.index, slot)
    end
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local function showMailTooltip(row)
    local mail = row.mail
    if not mail then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(mail.subject ~= "" and mail.subject or "(no subject)", 1, 1, 1, true)
    GameTooltip:AddLine("From: " .. mail.sender)
    if mail.wasReturned then
        GameTooltip:AddLine("Returned to you", 0.6, 0.6, 0.6)
    end
    if #mail.items > 0 then
        GameTooltip:AddLine(" ")
        for _, item in ipairs(mail.items) do
            local r, g, b = qualityColor(item.quality)
            GameTooltip:AddDoubleLine(("|T%s:14|t %s"):format(item.icon or "", item.name or ("item:" .. tostring(item.id))),
                item.count, r, g, b, 1, 1, 1)
        end
    end
    if mail.money > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Gold", moneyText(mail.money), 1, 0.82, 0, 1, 1, 1)
    end
    if mail.cod > 0 then
        local short = mail.cod > GetMoney()
        GameTooltip:AddDoubleLine("COD", moneyText(mail.cod), 1, 0.3, 0.3, 1, short and 0.3 or 1, short and 0.3 or 1)
    end
    GameTooltip:AddLine(" ")
    local fate = InboxItemCanDelete(mail.index) and "Deleted in " or "Returned in "
    GameTooltip:AddLine(fate .. expiryText(mail.daysLeft), 1, 1, 1)
    GameTooltip:AddLine("Click to open. Shift-click to take everything.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function createAttachButton(row, i)
    local button = CreateFrame("Button", nil, row)
    button:SetSize(ATTACH_SIZE, ATTACH_SIZE)
    button:SetPoint("LEFT", row, "LEFT", ATTACH_X + (i - 1) * (ATTACH_SIZE + 3), 0)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.count:SetPoint("BOTTOMRIGHT", 2, -1)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInboxItem(row.mail.index, self.slot)
        GameTooltip:AddLine("Click to take this item.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self) takeItem(row.mail, self.slot) end)
    return button
end

local function buildRow(row)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
        if IsModifiedClick and IsModifiedClick("MAILAUTOLOOTTOGGLE") then
            takeAll(self.mail)
        else
            toggleMail(self.mail.index)
        end
    end)
    row:SetScript("OnEnter", showMailTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(1, 1, 1, 0.04)

    row.selected = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.selected:SetAllPoints()
    row.selected:SetColorTexture(1, 0.82, 0, 0.15)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", 4, 0)

    row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 2)

    row.sender = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.sender:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
    row.sender:SetWidth(ATTACH_X - ICON_SIZE - 20)
    row.sender:SetJustifyH("LEFT")
    row.sender:SetWordWrap(false)

    row.subject = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.subject:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 3)
    row.subject:SetWidth(ATTACH_X - ICON_SIZE - 20)
    row.subject:SetJustifyH("LEFT")
    row.subject:SetWordWrap(false)

    row.attach = {}
    for i = 1, MAX_ATTACH_ICONS do
        row.attach[i] = createAttachButton(row, i)
    end
    row.more = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.more:SetPoint("LEFT", row.attach[MAX_ATTACH_ICONS], "RIGHT", 4, 0)

    row.take = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.take:SetSize(64, 22)
    row.take:SetPoint("RIGHT", -6, 0)
    row.take:SetScript("OnClick", function(self) takeAll(self:GetParent().mail) end)

    row.expiry = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.expiry:SetPoint("RIGHT", row.take, "LEFT", -10, 0)
    row.expiry:SetWidth(70)
    row.expiry:SetJustifyH("RIGHT")

    row.money = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.money:SetPoint("RIGHT", row.expiry, "LEFT", -10, 0)
    row.money:SetWidth(120)
    row.money:SetJustifyH("RIGHT")
end

local function initRow(row, mail)
    if not row.icon then buildRow(row) end
    row.mail = mail

    row.stripe:SetShown(mail.index % 2 == 0)
    row.selected:SetShown(isOpen(mail.index))

    row.icon:SetTexture(mail.icon)
    row.icon:SetDesaturated(mail.wasRead and true or false)
    row.count:SetText(mail.itemTotal > 1 and mail.itemTotal or "")

    row.sender:SetText(mail.sender)
    if mail.wasRead then
        row.sender:SetTextColor(0.75, 0.75, 0.75)
        row.subject:SetTextColor(0.75, 0.75, 0.75)
    else
        row.sender:SetTextColor(1, 0.82, 0)
        row.subject:SetTextColor(1, 1, 1)
    end
    row.subject:SetText(mail.subject)

    for i, button in ipairs(row.attach) do
        local item = mail.items[i]
        if item then
            button.slot = item.slot
            button.icon:SetTexture(item.icon)
            button.count:SetText(item.count > 1 and item.count or "")
            button:Show()
        else
            button:Hide()
        end
    end
    local extra = #mail.items - MAX_ATTACH_ICONS
    row.more:SetText(extra > 0 and ("+" .. extra) or "")

    if mail.cod > 0 then
        row.money:SetText("|cffff5555COD|r " .. moneyText(mail.cod))
    elseif mail.money > 0 then
        row.money:SetText(moneyText(mail.money))
    else
        row.money:SetText("")
    end
    row.expiry:SetText(expiryText(mail.daysLeft))

    local hasContents = #mail.items > 0 or mail.money > 0
    row.take:SetShown(hasContents)
    row.take:SetText(mail.cod > 0 and "Open" or "Take")
end

---------------------------------------------------------------------------
-- View
---------------------------------------------------------------------------

local function refresh()
    if not (active and view:IsVisible()) then return end

    local numItems, totalItems = GetInboxNumItems()
    local data = CreateDataProvider()
    local items, gold, unread, cods, codTotal, expiring = 0, 0, 0, 0, 0, 0
    for index = 1, numItems do
        local mail = readMail(index)
        data:Insert(mail)
        items = items + mail.itemTotal
        gold = gold + mail.money
        if not mail.wasRead then unread = unread + 1 end
        if mail.cod > 0 then
            cods = cods + 1
            codTotal = codTotal + mail.cod
        end
        if mail.daysLeft < EXPIRY_WARN_DAYS then expiring = expiring + 1 end
    end
    view.scrollBox:SetDataProvider(data, true)
    view.empty:SetShown(numItems == 0)

    if numItems == 0 then
        view.summary:SetText("No mail.")
    else
        view.summary:SetText(("%s     %s     %s"):format(
            plural(numItems, "mail"), plural(items, "item"),
            gold > 0 and ("|cffffffff" .. moneyText(gold) .. "|r") or "no gold"))
    end

    local details = {}
    if unread > 0 then table.insert(details, ("%d unread"):format(unread)) end
    if cods > 0 then
        table.insert(details, ("|cffff5555%d COD (%s)|r"):format(cods, moneyText(codTotal)))
    end
    if expiring > 0 then
        table.insert(details, ("|cffff9900%d expiring within %d days|r"):format(expiring, EXPIRY_WARN_DAYS))
    end
    if totalItems and totalItems > numItems then
        -- The server sends at most 50-100 mails at a time; the rest arrive
        -- as these are taken.
        table.insert(details, ("|cffff5555%d more waiting on the server|r"):format(totalItems - numItems))
    end
    view.details:SetText(table.concat(details, "   |cff666666·|r   "))
end

-- InboxFrame:Update runs on every inbox change, several times a second while
-- Open All is running. Coalesce into one refresh per frame.
local refreshQueued = false
local function queueRefresh()
    if refreshQueued or not active then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        refresh()
    end)
end

local function createView()
    view = CreateFrame("Frame", nil, InboxFrame)
    view:SetPoint("TOPLEFT", 12, -64)
    view:SetPoint("BOTTOMRIGHT", -12, 10)

    view.summary = view:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    view.summary:SetPoint("TOPLEFT", 4, -4)
    view.summary:SetJustifyH("LEFT")

    view.details = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    view.details:SetPoint("TOPLEFT", view.summary, "BOTTOMLEFT", 0, -6)
    view.details:SetJustifyH("LEFT")

    local headers = {
        { text = "From / Subject", x = 48 },
        { text = "Attachments", x = ATTACH_X },
    }
    for _, h in ipairs(headers) do
        local fs = view:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", h.x, -52)
        fs:SetText(h.text)
    end
    local expiresHeader = view:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    expiresHeader:SetPoint("TOPRIGHT", -(20 + 6 + 64 + 10), -52)
    expiresHeader:SetText("Expires")
    local moneyHeader = view:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    moneyHeader:SetPoint("TOPRIGHT", -(20 + 6 + 64 + 10 + 70 + 10), -52)
    moneyHeader:SetText("Gold / COD")

    view.scrollBox = CreateFrame("Frame", nil, view, "WowScrollBoxList")
    view.scrollBox:SetPoint("TOPLEFT", 0, -66)
    view.scrollBox:SetPoint("BOTTOMRIGHT", -20, 0)

    view.scrollBar = CreateFrame("EventFrame", nil, view, "MinimalScrollBar")
    view.scrollBar:SetPoint("TOPLEFT", view.scrollBox, "TOPRIGHT", 6, 0)
    view.scrollBar:SetPoint("BOTTOMLEFT", view.scrollBox, "BOTTOMRIGHT", 6, 0)

    local scrollView = CreateScrollBoxListLinearView()
    scrollView:SetElementExtent(ROW_HEIGHT)
    scrollView:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(view.scrollBox, view.scrollBar, scrollView)

    view.empty = view:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    view.empty:SetPoint("CENTER", view.scrollBox, "CENTER")
    view.empty:SetText("Your inbox is empty.")

    view:SetScript("OnShow", refresh)

    stash = CreateFrame("Frame")
    stash:Hide()

    hooksecurefunc(InboxFrame, "Update", queueRefresh)
    if OpenMailFrame then
        -- Keeps the open-mail highlight in step with the letter view.
        OpenMailFrame:HookScript("OnShow", queueRefresh)
        OpenMailFrame:HookScript("OnHide", queueRefresh)
    end
end

-- Blizzard's paged inbox widgets, hidden while the view is active.
local function blizzardWidgets()
    local frames = {
        InboxFrame.PrevPageButton, InboxFrame.NextPageButton,
        InboxFrame.PageTurnIndicatorLeft, InboxFrame.PageTurnIndicatorRight,
        InboxTooMuchMail,
    }
    for i = 1, INBOXITEMS_TO_DISPLAY or 7 do
        table.insert(frames, _G["MailItem" .. i])
    end
    return frames, { InboxFrameBg, InboxCurrentPage }
end

-- Called by UI/Mailbox.lua when the mailbox is extended or restored.
function ns:SetInboxExtended(on)
    if not InboxFrame or on == active then return end
    if not view then createView() end
    active = on

    local frames, regions = blizzardWidgets()
    if on then
        wipe(stashed)
        for _, frame in ipairs(frames) do
            if frame then
                stashed[frame] = frame:GetParent()
                frame:SetParent(stash)
            end
        end
    else
        for frame, parent in pairs(stashed) do
            frame:SetParent(parent)
        end
        wipe(stashed)
    end
    for _, region in ipairs(regions) do
        if region then region:SetShown(not on) end
    end

    -- Blizzard's Open All button moves up beside the summary.
    local openAll = InboxFrame.OpenAllMail
    if openAll then
        openAll:ClearAllPoints()
        if on then
            openAll:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, -2)
        else
            openAll:SetPoint("CENTER", InboxFrame, "BOTTOM", 0, 26)
        end
    end

    view:SetShown(on)
    if on then refresh() end
end
