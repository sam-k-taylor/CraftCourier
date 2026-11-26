local _, ns = ...

-- Recipient settings, grouped under the headings in ns.categorySections,
-- shown in three places built from the same form:
--   * a canvas panel under Options > AddOns
--   * a small standalone window for /craftcourier and the docked mailbox panel
--   * the Settings tab on the extended mailbox (UI/Mailbox.lua)

local ROW_HEIGHT = 25

local forms = {}
local category
local window

-- ScrollFrameTemplate puts its scroll bar just outside the frame's right edge.
local SCROLLBAR_SPACE = 28

local HEADER_HEIGHT = 30
local SECTION_GAP = 10
local CLASS_ICON_SIZE = 16

local TOGGLES = {
    { key = "extendMailbox",     text = "Extend the mailbox (wider inbox, send panel and Settings tab)" },
    { key = "showPanel",         text = "Show the CraftCourier panel beside the inbox" },
    { key = "keepFirstAidCloth", text = "Keep the cloth my First Aid skill still needs" },
    { key = "playSounds",        text = "Play sounds when mail is sent" },
}
-- The toggles' own section; it collapses like the category sections.
local MAILBOX_SECTION = { key = "mailbox", label = "Mailbox" }

local function isCollapsed(key)
    return ns.db.collapsedSections[key] and true or false
end

-- The Mailbox section's rows: the toggles, then the window style dropdown.
local MAILBOX_ROWS = #TOGGLES + 1

-- Rows a section takes: none when collapsed, else its categories split into
-- columns, or one line for the hint under an empty Custom section.
local function sectionRows(group, columns)
    if isCollapsed(group.section.key) then return 0 end
    return math.max(1, math.ceil(#group.categories / columns))
end

-- Height of the whole form: each section's heading and rows, then the
-- Mailbox heading and its toggles. Must match form:Layout().
local function formHeight(columns)
    columns = columns or 1
    local height = 0
    for _, group in ipairs(ns:CategoriesBySection()) do
        height = height + HEADER_HEIGHT + sectionRows(group, columns) * ROW_HEIGHT + SECTION_GAP
    end
    local toggleRows = isCollapsed(MAILBOX_SECTION.key) and 0 or MAILBOX_ROWS
    return height + HEADER_HEIGHT + toggleRows * ROW_HEIGHT + 4
end

local function relayoutForms()
    for _, form in ipairs(forms) do
        form:Layout()
    end
end

local function toggleSection(key)
    ns.db.collapsedSections[key] = not isCollapsed(key) or nil
    if SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    relayoutForms()
end

-- Class icon beside the box and the name in class colour, when the text is
-- one of your recorded alts. (The Letter style keeps names in ink.)
local function updateClass(box)
    local theme = ns.Style.Theme(box.ccScope)
    local char = ns:FindCharacter(strtrim(box:GetText() or ""))
    local class = char and char.class
    if class and ns.Style.SetClassIcon(box.classIcon, class) then
        box.classIcon:Show()
        if theme.classText then
            box:SetTextColor(ns.Style.ClassColor(class))
            return
        end
    else
        box.classIcon:Hide()
    end
    box:SetTextColor(unpack(theme.inputText))
end

-- Radio menu of the window styles; picking one restyles everything at once.
local function styleMenu(_, root)
    for _, key in ipairs(ns.Style.THEME_ORDER) do
        root:CreateRadio(ns.Style.THEMES[key].label,
            function(value) return ns.Style.Theme().key == value end,
            function(value) ns.Style.SetTheme(value) end,
            key)
    end
end

-- Builds the recipient rows and the mailbox toggles into `host`, starting at
-- `top`. opts: labelX, boxX (relative to each column), boxWidth, columns,
-- columnWidth, and `bottom`: if set, the form scrolls in a frame that ends
-- `bottom` pixels above the host's bottom edge (there are too many categories
-- to fit the smaller hosts). Returns a form object with a Load() method.
local function buildForm(host, top, opts)
    local form = { boxes = {}, rows = {}, toggles = {}, headers = {} }
    local columns = opts.columns or 1
    -- nil: follows the window style; "blizzard" on a Blizzard background.
    local scope = opts.scope

    local parent, scrollChild = host, nil
    if opts.bottom then
        local scroll = CreateFrame("ScrollFrame", nil, host, "ScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, -top)
        scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR_SPACE, opts.bottom)
        parent = CreateFrame("Frame", nil, scroll)
        parent:SetSize(1, formHeight(columns))
        scroll:SetScrollChild(parent)
        scroll:HookScript("OnSizeChanged", function(_, width) parent:SetWidth(width) end)
        scrollChild = parent
        top = 0
    end

    local function save(box)
        if not box.categoryKey then return end
        local text = strtrim(box:GetText() or "")
        ns.db.recipients[box.categoryKey] = text ~= "" and text or nil
        ns:Fire("CONFIG_CHANGED")
    end

    local function createRow()
        local row = {}
        row.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)
        ns.Style.Text(row.label, "text", scope)

        local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        box:SetSize(opts.boxWidth or 170, 20)
        box:SetAutoFocus(false)
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

        box.classIcon = parent:CreateTexture(nil, "ARTWORK")
        box.classIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
        box.classIcon:SetPoint("LEFT", box, "RIGHT", 4, 0)
        box.classIcon:Hide()
        box.ccScope = scope
        box.ccKeepColor = true -- updateClass colours the text
        ns.Style.SkinEditBox(box, scope)
        box:HookScript("OnTextChanged", updateClass)

        row.box = box
        return row
    end

    local function hideRow(row)
        if row.box:HasFocus() then row.box:ClearFocus() end
        row.box.categoryKey = nil
        row.label:Hide()
        row.box:Hide()
        row.box.classIcon:Hide()
    end

    -- A clickable section heading: +/- then gold title, a rule under it.
    local function getHeader(i)
        local header = form.headers[i]
        if not header then
            header = CreateFrame("Button", nil, parent)
            header:SetHeight(HEADER_HEIGHT - 8)
            header.toggle = header:CreateTexture(nil, "ARTWORK")
            header.toggle:SetSize(14, 14)
            header.toggle:SetPoint("LEFT", 0, 0)
            header.text, header.line = ns.Style.Heading(header, nil, nil, scope)
            header.text:SetPoint("LEFT", header.toggle, "RIGHT", 6, 0)
            header.line:ClearAllPoints()
            header.line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
            header.line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -1)
            header:SetScript("OnClick", function(self) toggleSection(self.sectionKey) end)
            header:SetScript("OnEnter", function(self)
                self.text:SetTextColor(1, 1, 1)
                GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
                GameTooltip:AddLine(isCollapsed(self.sectionKey) and "Click to expand" or "Click to collapse")
                GameTooltip:Show()
            end)
            header:SetScript("OnLeave", function(self)
                self.text:SetTextColor(unpack(ns.Style.Theme(scope).heading))
                GameTooltip:Hide()
            end)
            form.headers[i] = header
        end
        return header
    end
    local function placeHeader(i, section, y)
        local header = getHeader(i)
        header.sectionKey = section.key
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", opts.labelX - 4, -(y + 2))
        header:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
        header.text:SetText(section.label)
        header.toggle:SetTexture(isCollapsed(section.key)
            and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        header:Show()
        return header
    end

    -- Under an empty Custom section, and a shortcut beside its heading.
    form.customHint = ns.Style.Text(parent:CreateFontString(nil, "OVERLAY", "GameFontDisable"), "muted", scope)
    form.customHint:SetJustifyH("LEFT")
    form.customHint:SetText("None yet. Make your own on the Item Filters screen.")
    form.customButton = ns.Style.Button(parent, "Item Filters", 110, 20, function() ns:ShowFilters() end, scope)

    -- "Window style" row at the end of the Mailbox section.
    form.styleLabel = ns.Style.Text(parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), "text", scope)
    form.styleLabel:SetText("Window style:")
    form.styleDropdown = ns.Style.Dropdown(parent, 180, styleMenu,
        function() return ns.Style.Theme().label end, scope)

    -- Sections of rows, each under its heading, then the Mailbox toggles.
    -- Reruns when custom categories change or a section is collapsed: rows
    -- and headings are reused, spare ones hidden.
    function form:Layout()
        wipe(self.boxes)
        local y = top
        local rowIndex, headerIndex = 0, 0
        self.customHint:Hide()
        self.customButton:Hide()
        for _, group in ipairs(ns:CategoriesBySection()) do
            headerIndex = headerIndex + 1
            local header = placeHeader(headerIndex, group.section, y)
            y = y + HEADER_HEIGHT
            local collapsed = isCollapsed(group.section.key)

            if group.section.key == "custom" then
                self.customButton:ClearAllPoints()
                self.customButton:SetPoint("BOTTOMRIGHT", header.line, "TOPRIGHT", 0, 3)
                self.customButton:SetFrameLevel(header:GetFrameLevel() + 2)
                self.customButton:Show()
                self.customHint:ClearAllPoints()
                self.customHint:SetPoint("TOPLEFT", opts.labelX, -(y + 4))
                self.customHint:SetShown(#group.categories == 0 and not collapsed)
            end

            if not collapsed then
                local perColumn = math.ceil(#group.categories / columns)
                for i, cat in ipairs(group.categories) do
                    rowIndex = rowIndex + 1
                    local row = self.rows[rowIndex]
                    if not row then
                        row = createRow()
                        self.rows[rowIndex] = row
                    end
                    local column = math.floor((i - 1) / perColumn)
                    local x = column * (opts.columnWidth or 0)
                    local rowY = -(y + ((i - 1) % perColumn) * ROW_HEIGHT)
                    row.label:ClearAllPoints()
                    row.label:SetPoint("TOPLEFT", x + opts.labelX, rowY - 4)
                    row.label:SetText(("|T%s:16|t %s"):format(cat.icon, ns:CategoryDisplayName(cat)))
                    -- Custom names can be long; cut them off before the box. (0 = no
                    -- limit, as the built-in labels have always been.)
                    row.label:SetWidth(cat.custom and (opts.boxX - opts.labelX - 6) or 0)
                    row.box:ClearAllPoints()
                    row.box:SetPoint("TOPLEFT", x + opts.boxX, rowY)
                    if row.box.categoryKey ~= cat.key then
                        if row.box:HasFocus() then row.box:ClearFocus() end
                        row.box.categoryKey = cat.key
                        row.box:SetText(ns:GetRecipient(cat.key) or "")
                        row.box:SetCursorPosition(0)
                    end
                    row.label:Show()
                    row.box:Show()
                    updateClass(row.box)
                    self.boxes[cat.key] = row.box
                end
            end
            y = y + sectionRows(group, columns) * ROW_HEIGHT + SECTION_GAP
        end
        for i = rowIndex + 1, #self.rows do
            hideRow(self.rows[i])
        end

        headerIndex = headerIndex + 1
        placeHeader(headerIndex, MAILBOX_SECTION, y)
        y = y + HEADER_HEIGHT
        local togglesShown = not isCollapsed(MAILBOX_SECTION.key)
        for i, toggle in ipairs(self.toggles) do
            toggle:ClearAllPoints()
            toggle:SetPoint("TOPLEFT", opts.labelX - 4, -(y + (i - 1) * ROW_HEIGHT))
            toggle:SetShown(togglesShown)
        end
        local styleY = y + #self.toggles * ROW_HEIGHT
        self.styleLabel:ClearAllPoints()
        self.styleLabel:SetPoint("TOPLEFT", opts.labelX, -(styleY + 6))
        self.styleDropdown:ClearAllPoints()
        self.styleDropdown:SetPoint("LEFT", self.styleLabel, "RIGHT", 10, 0)
        self.styleLabel:SetShown(togglesShown)
        self.styleDropdown:SetShown(togglesShown)
        for i = headerIndex + 1, #self.headers do
            self.headers[i]:Hide()
        end

        if scrollChild then
            scrollChild:SetHeight(formHeight(columns))
        end
    end

    for _, def in ipairs(TOGGLES) do
        local toggle = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        toggle:SetScript("OnClick", function(self)
            ns.db[def.key] = self:GetChecked()
            ns:Fire("CONFIG_CHANGED")
        end)
        local label = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", toggle, "RIGHT", 2, 0)
        ns.Style.Text(label, "text", scope)
        label:SetText(def.text)
        toggle.key = def.key
        table.insert(form.toggles, toggle)
    end
    form:Layout()

    function form:Load()
        for key, box in pairs(self.boxes) do
            if not box:HasFocus() then
                box:SetText(ns:GetRecipient(key) or "")
                -- Text set before the box is laid out can render scrolled out
                -- of view (blank); resetting the cursor scrolls it back.
                box:SetCursorPosition(0)
            end
            updateClass(box)
        end
        for _, toggle in ipairs(self.toggles) do
            toggle:SetChecked(ns.db[toggle.key])
        end
    end

    -- Load now and again next frame, once the parent has been sized and laid out.
    host:HookScript("OnShow", function()
        form:Load()
        C_Timer.After(0, function() form:Load() end)
    end)
    host:HookScript("OnHide", function() ns:HideSuggestions() end)
    table.insert(forms, form)
    return form
end

-- Used by the Settings tab on the mailbox (UI/Mailbox.lua).
function ns:BuildConfigForm(parent, top, opts)
    return buildForm(parent, top, opts)
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
    title:SetText(ns.Style.Logo(24) .. " CraftCourier")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    hint:SetText("Who should receive each material? Start typing for suggestions from your alts and friends.")

    -- The Options page is a Blizzard background, so it keeps their look.
    local filters = ns.Style.Button(panel, "Item Filters", 120, 22, function() ns:ShowFilters() end, "blizzard")
    filters:SetPoint("TOPRIGHT", -16, -14)

    local form = buildForm(panel, 70, { labelX = 20, boxX = 200, bottom = 16, scope = "blizzard" })

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
        ns.db.playSounds = true
        ns.Style.SetTheme(ns.Style.DEFAULT_THEME)
        wipe(ns.db.collapsedSections)
        relayoutForms()
        ns:Fire("CONFIG_CHANGED")
    end

    category = Settings.RegisterCanvasLayoutCategory(panel, "CraftCourier")
    Settings.RegisterAddOnCategory(category)
end

---------------------------------------------------------------------------
-- Small standalone window
---------------------------------------------------------------------------

local function createWindow()
    -- Capped so it fits small screens; the form scrolls past that.
    window = ns.Style.CreateWindow("CraftCourierConfigFrame", "CraftCourier Settings",
        490 + SCROLLBAR_SPACE, math.min(100 + formHeight(1) + 20, 600))
    window:SetPoint("CENTER")
    local body = window.body

    local hint = ns.Style.Text(body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), "hint")
    hint:SetPoint("TOPLEFT", 6, -8)
    hint:SetText("Recipient for each material (Name or Name-Realm):")

    local filters = ns.Style.Button(body, "Item Filters", 100, 20, function() ns:ShowFilters() end)
    filters:SetPoint("TOPRIGHT", -2, -2)

    buildForm(body, 30, { labelX = 12, boxX = 150, bottom = 4 })
end

---------------------------------------------------------------------------

ns:On("READY", function()
    createSettingsPanel()
    createWindow()
end)

-- Recolour names (class colours depend on the style) and the style dropdown.
ns:On("STYLE_CHANGED", function()
    for _, form in ipairs(forms) do
        form:Load()
        form.styleDropdown:GenerateMenu()
    end
end)

-- A custom category was added, renamed or deleted.
ns:On("CATEGORIES_CHANGED", relayoutForms)

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
