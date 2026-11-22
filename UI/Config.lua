local _, ns = ...

-- Recipient settings, shown in two places built from the same form:
--   * a canvas panel under Options > AddOns
--   * a small standalone window for /craftcourier and the docked mailbox panel
--   * the Settings tab on the extended mailbox (UI/Mailbox.lua)

local ROW_HEIGHT = 25

local forms = {}
local category
local window

-- Builds the recipient rows and the mailbox toggles into `parent`, starting at
-- `top`. opts: labelX, boxX (relative to each column), columns, columnWidth.
-- Returns a form object with a Load() method.
local function buildForm(parent, top, opts)
    local form = { boxes = {}, toggles = {} }
    local columns = opts.columns or 1
    local perColumn = math.ceil(#ns.categories / columns)

    local function save(box)
        local text = strtrim(box:GetText() or "")
        ns.db.recipients[box.categoryKey] = text ~= "" and text or nil
        ns:Fire("CONFIG_CHANGED")
    end

    for i, cat in ipairs(ns.categories) do
        local column = math.floor((i - 1) / perColumn)
        local x = column * (opts.columnWidth or 0)
        local y = -(top + ((i - 1) % perColumn) * ROW_HEIGHT)

        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", x + opts.labelX, y - 4)
        label:SetText(("|T%s:16|t %s"):format(cat.icon, ns:CategoryDisplayName(cat)))

        local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetSize(170, 20)
        box:SetPoint("TOPLEFT", x + opts.boxX, y)
        box:SetAutoFocus(false)
        box.categoryKey = cat.key
        box:SetScript("OnEnterPressed", function(self)
            if not ns:AcceptSuggestion(self) then
                self:ClearFocus()
            end
        end)
        box:SetScript("OnEscapePressed", function(self)
            ns:HideSuggestions()
            self:SetText(ns:GetRecipient(self.categoryKey) or "")
            self:ClearFocus()
        end)
        box:SetScript("OnEditFocusLost", save)
        ns:AttachSuggestions(box)
        form.boxes[cat.key] = box
    end

    local toggleTop = top + perColumn * ROW_HEIGHT + 4
    local function addToggle(key, text)
        local toggle = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        toggle:SetPoint("TOPLEFT", opts.labelX - 4, -(toggleTop + #form.toggles * ROW_HEIGHT))
        toggle:SetScript("OnClick", function(self)
            ns.db[key] = self:GetChecked()
            ns:Fire("CONFIG_CHANGED")
        end)
        local label = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", toggle, "RIGHT", 2, 0)
        label:SetText(text)
        toggle.key = key
        table.insert(form.toggles, toggle)
    end
    addToggle("extendMailbox", "Extend the mailbox (wider inbox, send panel and Settings tab)")
    addToggle("showPanel", "Show the CraftCourier panel beside the inbox")
    addToggle("keepFirstAidCloth", "Keep the cloth my First Aid skill still needs")

    function form:Load()
        for key, box in pairs(self.boxes) do
            if not box:HasFocus() then
                box:SetText(ns:GetRecipient(key) or "")
                -- Text set before the box is laid out can render scrolled out
                -- of view (blank); resetting the cursor scrolls it back.
                box:SetCursorPosition(0)
            end
        end
        for _, toggle in ipairs(self.toggles) do
            toggle:SetChecked(ns.db[toggle.key])
        end
    end

    -- Load now and again next frame, once the parent has been sized and laid out.
    parent:HookScript("OnShow", function()
        form:Load()
        C_Timer.After(0, function() form:Load() end)
    end)
    parent:HookScript("OnHide", function() ns:HideSuggestions() end)
    table.insert(forms, form)
    return form
end

-- Used by the Settings tab on the mailbox (UI/Mailbox.lua).
function ns:BuildConfigForm(parent, top, opts)
    return buildForm(parent, top, opts)
end

-- Height of a form built with the given number of columns.
function ns:ConfigFormHeight(columns)
    return math.ceil(#ns.categories / (columns or 1)) * ROW_HEIGHT + 4 + 3 * ROW_HEIGHT
end

---------------------------------------------------------------------------
-- Options > AddOns panel
---------------------------------------------------------------------------

local function createSettingsPanel()
    local panel = CreateFrame("Frame", "CraftCourierSettingsPanel")
    -- Start hidden so OnShow fires when the Settings window displays it.
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("CraftCourier")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    hint:SetText("Who should receive each material? Start typing for suggestions from your alts and friends.")

    local form = buildForm(panel, 70, { labelX = 20, boxX = 200 })

    -- Settings panel callbacks (see Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua).
    function panel:OnRefresh()
        form:Load()
        C_Timer.After(0, function() form:Load() end)
    end

    function panel:OnDefault()
        wipe(ns.db.recipients)
        ns.db.showPanel = true
        ns.db.extendMailbox = true
        ns.db.keepFirstAidCloth = false
        ns:Fire("CONFIG_CHANGED")
    end

    category = Settings.RegisterCanvasLayoutCategory(panel, "CraftCourier")
    Settings.RegisterAddOnCategory(category)
end

---------------------------------------------------------------------------
-- Small standalone window
---------------------------------------------------------------------------

local function createWindow()
    window = CreateFrame("Frame", "CraftCourierConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(470, 56 + ns:ConfigFormHeight(1) + 16)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    if UISpecialFrames then
        tinsert(UISpecialFrames, window:GetName()) -- close with Escape
    end

    local title = window.TitleText or window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not window.TitleText then
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("CraftCourier Settings")

    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -32)
    hint:SetText("Recipient for each material (Name or Name-Realm):")

    buildForm(window, 56, { labelX = 16, boxX = 150 })
end

---------------------------------------------------------------------------

ns:On("READY", function()
    createSettingsPanel()
    createWindow()
end)

ns:On("CONFIG_CHANGED", function()
    for _, form in ipairs(forms) do
        form:Load()
    end
end)

-- Small window (slash command, docked mailbox panel).
function ns:ToggleConfig()
    if window then
        window:SetShown(not window:IsShown())
    end
end

-- Full Options > AddOns page.
function ns:OpenSettingsPanel()
    if category then
        Settings.OpenToCategory(category:GetID())
    end
end
