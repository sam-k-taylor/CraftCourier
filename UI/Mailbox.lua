local _, ns = ...

-- Extends Blizzard's mailbox instead of docking a separate window beside it:
--   * MailFrame is twice its normal width
--   * Inbox tab: summary and one scrolling list of mail (UI/Inbox.lua)
--   * Send Mail tab: Blizzard's form on the left, the CraftCourier send
--     panel on the right (UI/MailPanel.lua)
--   * a new Settings tab with the recipient form
-- Turning db.extendMailbox off puts the frame back the way Blizzard built it
-- and docks the send panel beside it again.
--
-- Nothing here replaces a Blizzard function. Tabs are switched by hooking
-- MailFrameTab_OnClick, and MailFrame.activeSubFrame is never written, so
-- Blizzard's tab code keeps running untainted.

local FALLBACK_WIDTH = 384

local baseWidth
local extended = false
local settingsTab, settingsPage

local function selectSettingsTab(selected)
    if selected then
        PanelTemplates_SelectTab(settingsTab)
    else
        PanelTemplates_DeselectTab(settingsTab)
    end
end

local function showSettingsTab()
    InboxFrame:Hide()
    SendMailFrame:Hide()
    for i = 1, 2 do
        local tab = _G["MailFrameTab" .. i]
        if tab then PanelTemplates_DeselectTab(tab) end
    end
    selectSettingsTab(true)

    ButtonFrameTemplate_HideButtonBar(MailFrame)
    if MailFrameInset then
        MailFrameInset:SetPoint("TOPLEFT", 4, -58)
    end
    SetSendMailShowing(false)
    if MailFrame.SetTitle then
        MailFrame:SetTitle("CraftCourier Settings")
    end
    settingsPage:Show()
    if SOUNDKIT then PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN) end
end

local function createSettingsPage()
    settingsPage = CreateFrame("Frame", nil, MailFrame)
    settingsPage:SetPoint("TOPLEFT", 4, -60)
    settingsPage:SetPoint("BOTTOMRIGHT", -4, 4)
    -- Start hidden so the form loads in OnShow.
    settingsPage:Hide()

    local hint = ns.Style.Text(settingsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), "hint")
    hint:SetPoint("TOPLEFT", 16, -14)
    hint:SetText("Who should receive each material? Start typing for suggestions from your alts and friends.")

    -- Scrolls above the Open Log button; leave room for the scroll bar.
    local half = (baseWidth * 2 - 8 - 28) / 2
    ns:BuildConfigForm(settingsPage, 44, { labelX = 16, boxX = 170, boxWidth = 134, columns = 2, columnWidth = half, bottom = 40 })

    local log = ns.Style.Button(settingsPage, "Open Log", 120, 22, function() ns:ToggleLog() end)
    log:SetPoint("BOTTOMRIGHT", -12, 10)

    local filters = ns.Style.Button(settingsPage, "Item Filters", 120, 22, function() ns:ToggleFilters() end)
    filters:SetPoint("RIGHT", log, "LEFT", -8, 0)

    settingsTab = CreateFrame("Button", nil, CreateFrame("Frame", nil, MailFrame), "PanelTabButtonTemplate")
    settingsTab:SetText("Settings")
    settingsTab:SetPoint("TOPLEFT", MailFrameTab2, "TOPRIGHT", 3, 0)
    settingsTab:SetScript("OnClick", showSettingsTab)
    selectSettingsTab(false)
    settingsTab:Hide() -- shown by setExtended
    -- Blizzard's two tabs and ours, restyled as one row (UI/Style.lua).
    ns.Style.SkinTabs(MailFrame, { MailFrameTab1, MailFrameTab2, settingsTab })

    -- Blizzard's Inbox and Send Mail tabs (and MailFrame_Show, which selects
    -- the Inbox) all go through MailFrameTab_OnClick.
    hooksecurefunc("MailFrameTab_OnClick", function()
        settingsPage:Hide()
        selectSettingsTab(false)
    end)
end

local function setExtended(on)
    if on == extended then return end
    if not on and settingsPage:IsShown() then
        MailFrameTab_OnClick(nil, 1)
    end
    extended = on

    MailFrame:SetWidth(on and baseWidth * 2 or baseWidth)

    -- Pin Blizzard's send form to its original width, so its right-anchored
    -- widgets (postage cost, Send and Cancel) stay put.
    SendMailFrame:ClearAllPoints()
    SendMailFrame:SetPoint("TOPLEFT")
    if on then
        SendMailFrame:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMLEFT", baseWidth, 0)
    else
        SendMailFrame:SetPoint("BOTTOMRIGHT")
    end

    settingsTab:SetShown(on)
    ns:SetInboxExtended(on)

    -- Re-lay out the open panels for the new width (the letter view and bags).
    if MailFrame:IsShown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(MailFrame)
    end
end

local function apply()
    setExtended(ns.db.extendMailbox and true or false)
    ns:PlaceMailPanel(extended)
end

local function init()
    baseWidth = MailFrame:GetWidth()
    if not baseWidth or baseWidth < 200 then
        baseWidth = FALLBACK_WIDTH
    end
    ns:SkinMailFrame()
    ns:AttachMailSuggestions()
    createSettingsPage()
    apply()
    ns:On("CONFIG_CHANGED", apply)
end

-- Opens the settings where they're most convenient: the Settings tab when
-- the extended mailbox is open, otherwise the small settings window.
function ns:ShowSettings()
    if extended and MailFrame:IsShown() then
        showSettingsTab()
    else
        self:ToggleConfig()
    end
end

ns:On("READY", function()
    if MailFrame then
        init()
        return
    end
    ns:RegisterEvent("ADDON_LOADED", function(_, name)
        if name == "Blizzard_MailFrame" and MailFrame and not baseWidth then
            init()
        end
    end)
end)
