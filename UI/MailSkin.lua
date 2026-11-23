local _, ns = ...

-- Restyles Blizzard's mailbox in the chosen window style (UI/Style.lua):
-- the mail window and its tabs, Blizzard's paged inbox, the Send Mail form
-- and the open letter.
--
-- Nothing of Blizzard's is replaced or hidden with Hide(): its art is faded
-- with SetAlpha, our backgrounds are separate frames behind its widgets,
-- and its text is recoloured (and put back for the Blizzard style). Its
-- code keeps running untouched, so switching to the Blizzard style shows
-- the mailbox exactly as Blizzard drew it.

local Style
local skinned = false

local function named(...)
    local list = {}
    for i = 1, select("#", ...) do
        local region = _G[select(i, ...)]
        if region then table.insert(list, region) end
    end
    return list
end

-- A frame's labels: its font strings that already have text (an edit box's
-- own text region starts empty, so it's left alone).
local function labels(frame)
    local list = {}
    if not frame then return list end
    for _, fs in ipairs(Style.FontStrings(frame)) do
        local text = fs:GetText()
        if text and text ~= "" then table.insert(list, fs) end
    end
    return list
end

local function skinButtons(...)
    for _, button in ipairs(named(...)) do Style.SkinButton(button) end
end

-- A themed box covering `region`'s area, on its own frame (so fading the
-- region's art doesn't fade the box too).
local function areaBehind(parent, region, hide)
    local area = CreateFrame("Frame", nil, parent)
    area:SetAllPoints(region)
    return Style.SkinArea(area, hide)
end

---------------------------------------------------------------------------
-- Blizzard's paged inbox (shown when the mailbox isn't extended)
---------------------------------------------------------------------------

local function recolorInboxItems()
    if not Style.IsCustom() then return end -- Blizzard's colours are right for it
    local t = Style.Theme()
    for i = 1, INBOXITEMS_TO_DISPLAY or 7 do
        local sender, subject = _G["MailItem" .. i .. "Sender"], _G["MailItem" .. i .. "Subject"]
        if sender and subject then
            -- Blizzard greys read mail (0.75); keep that distinction.
            local read = sender:GetTextColor() < 0.8 and select(2, sender:GetTextColor()) < 0.8
            sender:SetTextColor(unpack(read and t.muted or t.heading))
            subject:SetTextColor(unpack(read and t.muted or t.text))
        end
    end
end

local function skinInbox()
    for i = 1, INBOXITEMS_TO_DISPLAY or 7 do
        local item = _G["MailItem" .. i]
        if item then
            local art = {}
            for _, region in ipairs({ item:GetRegions() }) do
                if region:IsObjectType("Texture") then table.insert(art, region) end
            end
            Style.SkinArea(item, art)
        end
    end
    for i = 1, INBOXITEMS_TO_DISPLAY or 7 do
        Style.TextAll(named("MailItem" .. i .. "Sender"), "heading")
        Style.TextAll(named("MailItem" .. i .. "Subject"), "text")
    end
    if InboxFrame and InboxFrame.Update then
        hooksecurefunc(InboxFrame, "Update", recolorInboxItems)
    end
    Style.TextAll(named("InboxCurrentPage"), "heading")
    if InboxFrame then
        Style.TextAll(labels(InboxFrame.PrevPageButton), "heading")
        Style.TextAll(labels(InboxFrame.NextPageButton), "heading")
    end
    skinButtons("OpenAllMail")
end

---------------------------------------------------------------------------
-- Send Mail form
---------------------------------------------------------------------------

local function skinSendMail()
    -- The gold bars under the address and under the body: faded, with our
    -- rules in their place.
    local keep = {}
    if SendMailErrorCoin then keep[SendMailErrorCoin] = true end
    local rules = {}
    for _, bar in ipairs(named("SendMailHorizontalBarLeft", "SendMailHorizontalBarLeft2")) do
        local rule = Style.Divider(SendMailFrame)
        rule:SetPoint("LEFT", bar, "LEFT", 8, 0)
        rule:SetPoint("RIGHT", SendMailFrame, "RIGHT", -12, 0)
        table.insert(rules, rule)
    end
    Style.Register(function(t)
        local custom = t.chrome == "custom"
        Style.TextureAlpha(SendMailFrame, custom and 0 or 1, keep)
        for _, rule in ipairs(rules) do rule:SetShown(custom) end
    end)

    -- Address and subject.
    for _, box in ipairs(named("SendMailNameEditBox", "SendMailSubjectEditBox")) do
        Style.SkinEditBox(box, nil, true, 4)
        Style.TextAll({ box }, "inputText")
        Style.TextAll(labels(box), "heading")
    end
    Style.TextAll(labels(SendMailCostMoneyFrame), "heading")

    -- The letter body: our input box instead of the stationery.
    if SendMailScrollFrame then
        Style.SkinArea(SendMailScrollFrame, named("SendStationeryBackgroundLeft", "SendStationeryBackgroundRight"))
    end
    Style.TextAll(named("SendMailBodyEditBox"), "inputText")

    -- Money: one box in place of Blizzard's inset and gold edge.
    if SendMailMoneyBg then
        areaBehind(SendMailFrame, SendMailMoneyBg, named("SendMailMoneyInset", "SendMailMoneyBg"))
    end
    Style.TextAll(named("SendMailMoneyText"), "heading")

    skinButtons("SendMailMailButton", "SendMailCancelButton")
end

---------------------------------------------------------------------------
-- The open letter
---------------------------------------------------------------------------

-- SimpleHTML takes a text type ("P", "H1"...) before the colour.
local function setBodyColor(r, g, b)
    if not OpenMailBodyText then return end
    for _, textType in ipairs({ "P", "H1", "H2", "H3" }) do
        pcall(OpenMailBodyText.SetTextColor, OpenMailBodyText, textType, r, g, b)
    end
end

local function skinOpenMail()
    if not OpenMailFrame then return end
    Style.SkinBlizzardWindow(OpenMailFrame)
    -- The gold bar under the sender and subject.
    local rule = Style.Divider(OpenMailFrame)
    if OpenMailHorizontalBarLeft then
        rule:SetPoint("LEFT", OpenMailHorizontalBarLeft, "LEFT", 8, 0)
        rule:SetPoint("RIGHT", OpenMailFrame, "RIGHT", -12, 0)
    end
    local bodyR, bodyG, bodyB = 0.18, 0.1, 0
    if MailTextFontNormal then bodyR, bodyG, bodyB = MailTextFontNormal:GetTextColor() end
    Style.Register(function(t)
        local custom = t.chrome == "custom"
        Style.TextureAlpha(OpenMailFrame, custom and 0 or 1)
        rule:SetShown(custom and OpenMailHorizontalBarLeft ~= nil)
        if custom then
            setBodyColor(unpack(t.inputText))
        else
            setBodyColor(bodyR, bodyG, bodyB)
        end
    end)

    if OpenMailScrollFrame then
        Style.SkinArea(OpenMailScrollFrame, named("OpenStationeryBackgroundLeft", "OpenStationeryBackgroundRight"))
    end
    Style.TextAll(named("OpenMailSenderLabel", "OpenMailSubjectLabel"), "muted")
    Style.TextAll(named("OpenMailSubject"), "text")
    if OpenMailSender and OpenMailSender.Name then
        Style.TextAll({ OpenMailSender.Name }, "heading")
    end
    -- Auction house invoices.
    Style.TextAll(named("OpenMailInvoiceItemLabel", "OpenMailInvoicePurchaser", "OpenMailInvoiceSalePrice",
        "OpenMailInvoiceDeposit", "OpenMailInvoiceHouseCut", "OpenMailInvoiceAmountReceived",
        "OpenMailInvoiceNotYetSent", "OpenMailInvoiceMoneyDelay"), "inputText")

    skinButtons("OpenMailReportSpamButton", "OpenMailReplyButton", "OpenMailDeleteButton", "OpenMailCancelButton")
end

---------------------------------------------------------------------------

-- Called once by UI/Mailbox.lua when Blizzard's mail frame exists.
function ns:SkinMailFrame()
    if skinned or not MailFrame then return end
    skinned = true
    Style = ns.Style

    Style.SkinBlizzardWindow(MailFrame, named("InboxFrameBg"))
    skinInbox()
    skinSendMail()
    skinOpenMail()
end
