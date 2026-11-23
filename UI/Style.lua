local _, ns = ...

-- Shared look for every CraftCourier screen, in four window styles the user
-- picks from (db.windowStyle):
--   satchel  - the logo as a window: dark leather, rounded gold frame,
--              parchment title strip, wax-seal close button (default)
--   letter   - a parchment page in dark ink
--   flat     - flat dark panels, square corners, thin gold accents
--   blizzard - Blizzard's own portrait window and red buttons
--
-- Everything is drawn from tintable textures (Blizzard's tooltip border,
-- WHITE8X8 and the portrait mask), so there are no image files per style.
--
-- Every skinned region registers an apply function with Style.Register.
-- Changing the style reruns them all (live, no /reload) and fires
-- STYLE_CHANGED, so lists can redraw rows whose text embeds colour codes.
--
-- The mailbox itself is restyled too (UI/MailSkin.lua): Blizzard's windows
-- keep working, with their art faded out and ours drawn behind.
--
-- Scope: content on a background we don't restyle (the Options → AddOns
-- page, tooltips) passes scope "blizzard" and keeps the Blizzard palette
-- whatever the chosen style. Everything else follows the style.

local Style = {}
ns.Style = Style

Style.LOGO = "Interface\\AddOns\\CraftCourier\\Media\\Icon"

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROUND_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
local ROW_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local CLOSE_X = "Interface\\Buttons\\UI-StopButton"

---------------------------------------------------------------------------
-- Styles
---------------------------------------------------------------------------

local function rgb(hexText, a)
    local r, g, b = hexText:match("(%x%x)(%x%x)(%x%x)")
    return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, a or 1 }
end

-- Colours from logo.svg.
local GOLD, BRONZE, LEATHER, SLOT = rgb("b8862b"), rgb("5a4020"), rgb("1e160d"), rgb("2c2114")
local PARCHMENT, PARCHMENT_DARK, INK = rgb("f0dfb4"), rgb("e4cc94"), rgb("3a2200")
local YELLOW = rgb("ffd100")

Style.THEMES = {
    satchel = {
        key = "satchel", label = "Courier's Satchel",
        chrome = "custom", edge = "round", close = "seal", titleStrip = true,
        bg = rgb("1e160d", 0.97), border = GOLD, inner = BRONZE,
        -- Ink on the parchment title strip: no drop shadow there.
        titleBg = PARCHMENT_DARK, titleBorder = GOLD, titleText = INK, titleNoShadow = true,
        text = PARCHMENT, muted = rgb("a89a80"), heading = YELLOW, hint = PARCHMENT_DARK,
        line = rgb("b8862b", 0.45),
        inputBg = rgb("120d07"), inputBorder = BRONZE, inputText = PARCHMENT,
        buttonBg = SLOT, buttonBorder = BRONZE, buttonHover = GOLD, buttonText = YELLOW,
        stripe = { 1, 1, 1, 0.04 }, selected = { 1, 0.82, 0, 0.15 },
        groove = rgb("120d07"), grooveBorder = GOLD, fill = YELLOW,
        good = rgb("33ff33"), warn = rgb("ff9900"), bad = rgb("ff5555"),
        classText = true,
    },
    letter = {
        key = "letter", label = "Letter",
        chrome = "custom", edge = "round", close = "seal", titleStrip = false, underlineInputs = true,
        -- Dark ink on a light page: the game fonts' black drop shadow smears.
        noShadow = true,
        -- Aged parchment rather than the logo's near-white envelope, which
        -- was glaring across whole windows. Ink still reads strongly on it.
        bg = rgb("cdb78c", 0.98), border = GOLD, inner = rgb("6b4e22", 0.6),
        titleText = INK,
        text = INK, muted = BRONZE, heading = INK, hint = BRONZE,
        line = rgb("7a5a2a", 0.6),
        inputBg = { 0, 0, 0, 0 }, inputBorder = rgb("7a5a2a"), inputText = rgb("2a1800"),
        buttonBg = rgb("b9a174"), buttonBorder = rgb("6b4e22"), buttonHover = GOLD, buttonText = INK,
        stripe = rgb("6b4e22", 0.1), selected = rgb("8a6420", 0.25),
        groove = rgb("b9a174"), grooveBorder = rgb("6b4e22"), fill = rgb("8a6420"),
        -- Darker status colours that still read on parchment.
        good = rgb("1f6b1f"), warn = rgb("a05200"), bad = rgb("a01818"),
        -- Class colours are unreadable on parchment: names stay in ink with a class icon.
        classText = false,
    },
    flat = {
        key = "flat", label = "Flat",
        chrome = "custom", edge = "square", close = "x", titleStrip = true,
        bg = rgb("151515", 0.97), border = rgb("3a3a3a"),
        titleBg = rgb("1f1f1f"), titleBorder = rgb("3a3a3a"), titleText = YELLOW, titleRule = YELLOW,
        text = rgb("d6d6d6"), muted = rgb("9a9a9a"), heading = YELLOW, hint = rgb("bdbdbd"),
        line = rgb("ffd100", 0.35),
        inputBg = rgb("0d0d0d"), inputBorder = rgb("333333"), inputText = rgb("e6e6e6"),
        buttonBg = rgb("262626"), buttonBorder = rgb("3a3a3a"), buttonHover = YELLOW, buttonText = rgb("e6e6e6"),
        stripe = { 1, 1, 1, 0.03 }, selected = { 1, 0.82, 0, 0.12 },
        groove = rgb("222222"), grooveBorder = rgb("3a3a3a"), fill = YELLOW,
        good = rgb("33ff33"), warn = rgb("ff9900"), bad = rgb("ff5555"),
        classText = true,
    },
    blizzard = {
        key = "blizzard", label = "Blizzard",
        chrome = "blizzard",
        text = { 1, 1, 1, 1 }, muted = { 0.6, 0.6, 0.6, 1 }, heading = { 1, 0.82, 0, 1 }, hint = { 1, 1, 1, 1 },
        line = { 1, 0.82, 0, 0.25 },
        inputText = { 1, 1, 1, 1 },
        stripe = { 1, 1, 1, 0.04 }, selected = { 1, 0.82, 0, 0.15 },
        groove = { 0, 0, 0, 0.5 }, grooveBorder = { 1, 0.82, 0, 0.25 }, fill = YELLOW,
        good = rgb("20ff20"), warn = rgb("ff9900"), bad = rgb("ff5555"),
        classText = true,
    },
}
Style.THEME_ORDER = { "satchel", "letter", "flat", "blizzard" }
Style.DEFAULT_THEME = "satchel"

-- Colours that don't change with the style.
Style.COLOR = {
    gold    = { 1, 0.82, 0 },
    success = { 0.25, 1, 0.25 },
}

-- The style for a scope: "blizzard" content always gets the Blizzard palette.
function Style.Theme(scope)
    if scope == "blizzard" then return Style.THEMES.blizzard end
    local key = ns.db and ns.db.windowStyle
    return Style.THEMES[key] or Style.THEMES[Style.DEFAULT_THEME]
end

function Style.IsCustom(scope)
    return Style.Theme(scope).chrome == "custom"
end

local registry = {}

-- Runs apply(theme) now and whenever the style changes. Returns a function
-- that reruns it (for skins that also depend on other state).
function Style.Register(apply, scope)
    local function run() apply(Style.Theme(scope)) end
    table.insert(registry, run)
    run()
    return run
end

function Style.SetTheme(key)
    if not Style.THEMES[key] or not ns.db then return false end
    ns.db.windowStyle = key
    for _, run in ipairs(registry) do run() end
    ns:Fire("STYLE_CHANGED")
    return true
end

-- Finds a style by key or label, case-insensitive.
function Style.FindTheme(text)
    text = strtrim(text or ""):lower()
    for _, key in ipairs(Style.THEME_ORDER) do
        local theme = Style.THEMES[key]
        if key == text or theme.label:lower() == text then return theme end
    end
end

---------------------------------------------------------------------------
-- Text helpers
---------------------------------------------------------------------------

-- "|T...|t" markup for the logo, to put in front of a title.
function Style.Logo(size)
    return ("|T%s:%d|t"):format(Style.LOGO, size or 16)
end

-- "|cffRRGGBB" for 0-1 colour components.
local function hex(r, g, b)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

function Style.Green(text)
    local c = Style.COLOR.success
    return hex(c[1], c[2], c[3]) .. text .. "|r"
end

-- Text wrapped in a style colour ("text", "muted", "heading"...), for strings
-- built at refresh time. Redraw them on STYLE_CHANGED.
function Style.Colorize(text, role, scope)
    local c = Style.Theme(scope)[role] or Style.Theme(scope).text
    return hex(c[1], c[2], c[3]) .. text .. "|r"
end

-- Drops the text shadow for styles with a light background (Letter), or
-- wherever `noShadow` says (text on a light title strip), and puts the
-- font's own shadow back otherwise. Works on font strings and edit boxes.
local shadows = setmetatable({}, { __mode = "k" })
local function applyShadow(fs, t, noShadow)
    if not (fs.SetShadowOffset and fs.GetShadowOffset) then return end
    local saved = shadows[fs]
    if not saved then
        local x, y = fs:GetShadowOffset()
        local r, g, b, a = fs:GetShadowColor()
        saved = { x, y, r, g, b, a }
        shadows[fs] = saved
    end
    if noShadow == nil then noShadow = t.noShadow end
    if noShadow then
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(0, 0, 0, 0)
    else
        fs:SetShadowOffset(saved[1], saved[2])
        fs:SetShadowColor(saved[3], saved[4], saved[5], saved[6])
    end
end
Style.ApplyShadow = applyShadow

-- Colours a font string by role and keeps it in step with the style.
function Style.Text(fs, role, scope)
    Style.Register(function(t)
        local c = t[role] or t.text
        fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        applyShadow(fs, t)
    end, scope)
    return fs
end

---------------------------------------------------------------------------
-- Backdrops
---------------------------------------------------------------------------

local function ensureBackdrop(frame)
    if not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
        frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
    end
    return frame.SetBackdrop ~= nil
end

-- Rounded (tooltip border) or square (1px) backdrop; size "large" for
-- window frames, "small" for buttons, inputs and slots.
local function backdropFor(theme, size)
    if theme.edge == "square" then
        return { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
    end
    if size == "large" then
        return { bgFile = WHITE, edgeFile = ROUND_EDGE, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } }
    end
    return { bgFile = WHITE, edgeFile = ROUND_EDGE, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }
end

-- Paints `frame` (any frame) with a backdrop, or clears it when bg is nil.
local function paint(frame, theme, size, bg, border)
    if not ensureBackdrop(frame) then return end
    if not bg then
        frame:SetBackdrop(nil)
        return
    end
    frame:SetBackdrop(backdropFor(theme, size))
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    if border then
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    else
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

---------------------------------------------------------------------------
-- Lines, headings, rows
---------------------------------------------------------------------------

-- A 1px rule in the style's line colour. Anchor it yourself.
function Style.Divider(parent, vertical, scope)
    local line = parent:CreateTexture(nil, "ARTWORK")
    if vertical then line:SetWidth(1) else line:SetHeight(1) end
    Style.Register(function(t) line:SetColorTexture(unpack(t.line)) end, scope)
    return line
end

-- Heading text with a rule under it. Anchor the text, then give the rule a
-- RIGHT point (it already starts under the text).
function Style.Heading(parent, text, font, scope)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormalLarge")
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(text) end
    Style.Text(fs, "heading", scope)
    local line = Style.Divider(parent, false, scope)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
    return fs, line
end

-- Stripe, selection tint and hover glow for a list row (a Button).
-- Call Style.SetRowStripe(row, index) when the row is (re)initialised.
function Style.DecorateRow(row, scope)
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.selected = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.selected:SetAllPoints()
    row.selected:Hide()
    Style.Register(function(t)
        row.stripe:SetColorTexture(unpack(t.stripe))
        row.selected:SetColorTexture(unpack(t.selected))
    end, scope)
    if row.SetHighlightTexture then
        row:SetHighlightTexture(ROW_HIGHLIGHT, "ADD")
    end
end

function Style.SetRowStripe(row, index)
    row.stripe:SetShown(index % 2 == 0)
end

-- A square icon button with a hover glow and a one-line tooltip.
function Style.IconButton(parent, size, texture, tooltip, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button:SetNormalTexture(texture)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    if onClick then button:SetScript("OnClick", onClick) end
    if tooltip then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.tooltip or tooltip)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return button
end

-- A frame just behind `target`, painted by skins. Blizzard's widgets are
-- skinned this way rather than by mixing a backdrop into their own tables,
-- which would add our keys to Blizzard frames. sameLevel: at the target's
-- level (window backgrounds, under the target's children) instead of below.
local backings = setmetatable({}, { __mode = "k" })
local function backing(target, sameLevel)
    local bg = backings[target]
    if not bg then
        bg = CreateFrame("Frame", nil, target)
        bg:SetAllPoints()
        local function relevel()
            bg:SetFrameLevel(math.max(0, target:GetFrameLevel() - (sameLevel and 0 or 1)))
        end
        relevel()
        -- List rows get their level after creation; keep the backing under.
        target:HookScript("OnShow", relevel)
        backings[target] = bg
    end
    return bg
end
Style.Backing = backing

-- Sets the alpha of a frame's own textures (not its children's), except
-- the ones in `except`. Blizzard art is hidden with alpha, never Hide(),
-- since Blizzard's code shows and hides some of it itself.
local function textureAlpha(frame, alpha, except)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and not (except and except[region]) then
            region:SetAlpha(alpha)
        end
    end
end
Style.TextureAlpha = textureAlpha

-- Alpha on named regions or frames, skipping missing ones.
local function setAlpha(list, alpha)
    for _, region in pairs(list) do
        if region and region.SetAlpha then region:SetAlpha(alpha) end
    end
end

-- A floating panel (popups such as the Item Filters bag picker): the
-- style's frame, or a dark tooltip-like box for the Blizzard style.
function Style.Panel(frame, scope)
    Style.Register(function(t)
        if t.chrome == "custom" then
            paint(frame, t, "large", t.bg, t.border)
        else
            paint(frame, Style.THEMES.satchel, "large", { 0, 0, 0, 0.95 }, { 0.6, 0.6, 0.6, 1 })
        end
    end, scope)
    return frame
end

-- A themed box behind a Blizzard region (the mail body, the money input):
-- `anchor` gets a backing in the input colours, its own art hidden via
-- `hide` (a list of regions). Nothing for the Blizzard style.
function Style.SkinArea(anchor, hide, scope, inset)
    local bg = backing(anchor)
    if inset then
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", -inset, inset)
        bg:SetPoint("BOTTOMRIGHT", inset, -inset)
    end
    Style.Register(function(t)
        local custom = t.chrome == "custom"
        setAlpha(hide or {}, custom and 0 or 1)
        bg:SetShown(custom)
        if custom then paint(bg, t, "small", t.inputBg[4] == 0 and t.bg or t.inputBg, t.inputBorder) end
    end, scope)
    return bg
end

---------------------------------------------------------------------------
-- Buttons, tabs and input boxes (skins over Blizzard's templates)
---------------------------------------------------------------------------

local styledFonts = {}

-- A copy of `base` (a font object) in `color`, for the custom styles. Kept
-- per style and base font, so each button keeps its own font and size.
local function styledFont(t, base, color, slot)
    local id = ("%s_%s_%d"):format(t.key, base and base:GetName() or "GameFontNormal", slot)
    local font = styledFonts[id]
    if not font then
        font = CreateFont("CraftCourierFont_" .. id)
        font:CopyFontObject(base or GameFontNormal)
        styledFonts[id] = font
    end
    font:SetTextColor(color[1], color[2], color[3], 1)
    if t.noShadow then
        font:SetShadowOffset(0, 0)
        font:SetShadowColor(0, 0, 0, 0)
    end
    return font
end

-- Skins a button's fonts: its own fonts recoloured for the custom styles
-- (normal / highlight / disabled = colors[1..3]), the originals back for the
-- Blizzard style. Returns a function(t, colors) to call from the skin.
local function fontSkin(button)
    local original = {
        button:GetNormalFontObject() or GameFontNormal,
        button:GetHighlightFontObject() or GameFontHighlight,
        button:GetDisabledFontObject() or GameFontDisable,
    }
    local fs = button:GetFontString()
    if fs then fs:SetWordWrap(false) end
    return function(t, colors)
        local fonts = original
        if t.chrome == "custom" then
            fonts = {}
            for i = 1, 3 do fonts[i] = styledFont(t, original[i], colors[i], i) end
        end
        button:SetNormalFontObject(fonts[1])
        button:SetHighlightFontObject(fonts[2])
        button:SetDisabledFontObject(fonts[3])
    end
end

local function setTemplateTextures(widget, alpha)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        if widget[key] then widget[key]:SetAlpha(alpha) end
    end
    local name = widget:GetName()
    if name then
        setAlpha({ _G[name .. "Left"], _G[name .. "Middle"], _G[name .. "Right"] }, alpha)
    end
    local highlight = widget.GetHighlightTexture and widget:GetHighlightTexture()
    if highlight then highlight:SetAlpha(alpha) end
end

-- Skins a UIPanelButtonTemplate button (ours or Blizzard's): a tile with a
-- border that lights up on hover; Blizzard's red button for that style.
function Style.SkinButton(button, scope)
    local bg = backing(button)
    local setFonts = fontSkin(button)
    local function border(t, hover)
        if t.chrome ~= "custom" then return end
        local c = (hover and button:IsEnabled()) and t.buttonHover or t.buttonBorder
        bg:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 1)
    end
    Style.Register(function(t)
        local custom = t.chrome == "custom"
        setTemplateTextures(button, custom and 0 or 1)
        bg:SetShown(custom)
        if custom then paint(bg, t, "small", t.buttonBg, t.buttonBorder) end
        setFonts(t, { t.buttonText, t.text, t.muted })
    end, scope)
    button:HookScript("OnEnter", function() border(Style.Theme(scope), true) end)
    button:HookScript("OnLeave", function() border(Style.Theme(scope), false) end)
    return button
end

-- A UIPanelButtonTemplate button, already skinned.
function Style.Button(parent, text, width, height, onClick, scope)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 100, height or 22)
    button:SetText(text)
    if onClick then button:SetScript("OnClick", onClick) end
    return Style.SkinButton(button, scope)
end

-- Skins a row of PanelTabButtonTemplate tabs (the mailbox's) as Filofax
-- tabs along the bottom of `edge` (the window frame), in the custom styles:
-- each tab is wider where it meets the window and narrower at the bottom,
-- drawn from a cap (a strip reaching up into the window), a body whose
-- bottom corners are pulled in (Texture:SetVertexOffset) and three Lines
-- for its slanted sides and bottom.
--   * The selected tab is drawn above the window in the window's colour; its
--     cap covers the window's bottom border, so the window flows into it.
--   * The others are drawn beneath the window, tucked behind its edge.
-- Tabs touch at the top and taper apart. The art is our own frames on
-- `edge`, and the tab buttons are raised above it so their labels stay on
-- top. Blizzard's anchors, sizes, levels and text nudge are saved and
-- restored for the Blizzard style.
local tabSkins = setmetatable({}, { __mode = "k" })
local TAB_GAP, TAB_PAD, TAB_TUCK = 0, 14, 8
local TAB_EDGE = "Interface\\AddOns\\CraftCourier\\Media\\TabEdge"
local LOWER_LEFT, LOWER_RIGHT = LOWER_LEFT_VERTEX or 2, LOWER_RIGHT_VERTEX or 4

-- A colour moved `amount` of the way towards white (keeps its alpha).
local function lighten(c, amount)
    return { c[1] + (1 - c[1]) * amount, c[2] + (1 - c[2]) * amount, c[3] + (1 - c[3]) * amount, c[4] or 1 }
end

local function createTabArt(edge)
    local art = CreateFrame("Frame", nil, edge)
    art.cap = art:CreateTexture(nil, "BACKGROUND")
    art.body = art:CreateTexture(nil, "BACKGROUND")
    -- Outline of an unselected tab: right, bottom, left. (The selected tab's
    -- outline is part of the window's, drawn by its chrome.)
    art.outer = {}
    for i = 1, 3 do
        art.outer[i] = art:CreateLine(nil, "BORDER")
        art.outer[i]:SetTexture(TAB_EDGE)
    end
    function art:SetFill(c)
        self.cap:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        self.body:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
    return art
end

-- The window outline, shared by the window border and the tabs: where its
-- outer line runs (`d` from the frame's edge), its width, corner radius and
-- brightness, and the same for the inner frame line. Letter's inner line
-- and everything in Flat are square-cornered.
local function outlineGeometry(t)
    local round = t.edge ~= "square"
    local squareInner = not round or t.key == "letter"
    return {
        d = 1, width = 2, radius = round and 7 or 0, shade = round and 0.55 or 1,
        innerD = squareInner and 7.5 or 6.5, innerWidth = 1.5,
        innerRadius = squareInner and 0 or 3, innerShade = squareInner and 1 or 0.55,
    }
end

local function shade(c, f)
    return { c[1] * f, c[2] * f, c[3] * f, c[4] or 1 }
end

---------------------------------------------------------------------------
-- Drawn outlines: pools of Lines on a host frame, tracing paths given in
-- the host's coordinates (from its bottom-left, y up). Lines use the soft
-- TAB_EDGE texture, so slants and curves don't stair-step.
---------------------------------------------------------------------------

local CORNER_STEPS = 6

local function linePool(host)
    return { host = host, lines = {}, used = 0 }
end

local function poolStart(pool) pool.used = 0 end

local function poolFinish(pool)
    for i = pool.used + 1, #pool.lines do pool.lines[i]:Hide() end
end

-- Draws a polyline. Each segment is stretched a little at both ends so
-- the joins close.
local function drawPath(pool, pts, closed, width, color)
    local n = #pts
    for i = 1, closed and n or n - 1 do
        local a, b = pts[i], pts[i % n + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0.01 then
            local ex, ey = dx / len * width / 4, dy / len * width / 4
            pool.used = pool.used + 1
            local line = pool.lines[pool.used]
            if not line then
                line = pool.host:CreateLine(nil, "ARTWORK")
                line:SetTexture(TAB_EDGE)
                pool.lines[pool.used] = line
            end
            line:SetStartPoint("BOTTOMLEFT", pool.host, a[1] - ex, a[2] - ey)
            line:SetEndPoint("BOTTOMLEFT", pool.host, b[1] + ex, b[2] + ey)
            line:SetThickness(width)
            line:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
            line:Show()
        end
    end
end

-- Appends a corner: an arc of radius r round (cx, cy) from angle a0 to a1
-- (degrees), or the single corner point for square corners.
local function addArc(pts, cx, cy, r, a0, a1)
    if r <= 0 then
        -- Square corner: the "centre" is the corner itself.
        table.insert(pts, { cx, cy })
        return
    end
    for i = 0, CORNER_STEPS do
        local a = math.rad(a0 + (a1 - a0) * i / CORNER_STEPS)
        table.insert(pts, { cx + r * math.cos(a), cy + r * math.sin(a) })
    end
end

-- The left side of a tab runs from (0, 0) to (slant, -h), from its top-left.
-- Returns the x of a line parallel to it, `d` px inside it (a perpendicular
-- distance, so the gap is even all the way down), at height y.
local function sideX(y, h, slant, d)
    return -slant * y / h + d * math.sqrt(1 + (slant / h) ^ 2)
end

-- The window's outer line: round the frame (W by H) `d` in from its edge,
-- with corners of radius r, dipping down round `tab` if one is selected
-- (tab = { x, w, h, slant }: its left edge from the frame's left, its top on
-- the frame's bottom edge).
local function framePath(W, H, d, r, tab)
    local pts = {}
    addArc(pts, d + r, H - d - r, r, 180, 90)
    addArc(pts, W - d - r, H - d - r, r, 90, 0)
    addArc(pts, W - d - r, d + r, r, 0, -90)
    if tab then
        local right, left = tab.x + tab.w, tab.x
        table.insert(pts, { right - sideX(d, tab.h, tab.slant, d), d })
        table.insert(pts, { right - sideX(-tab.h + d, tab.h, tab.slant, d), -tab.h + d })
        table.insert(pts, { left + sideX(-tab.h + d, tab.h, tab.slant, d), -tab.h + d })
        table.insert(pts, { left + sideX(d, tab.h, tab.slant, d), d })
    end
    addArc(pts, d + r, d + r, r, -90, -180)
    return pts
end

-- The window's inner line, `di` in with corners of radius ri. With a tab it
-- stops where it meets the tab's outline (at `d`), on both sides.
local function innerPath(W, H, di, ri, d, tab)
    local pts = {}
    if tab then
        table.insert(pts, { tab.x + sideX(di, tab.h, tab.slant, d), di })
    end
    addArc(pts, di + ri, di + ri, ri, -90, -180)
    addArc(pts, di + ri, H - di - ri, ri, 180, 90)
    addArc(pts, W - di - ri, H - di - ri, ri, 90, 0)
    addArc(pts, W - di - ri, di + ri, ri, 0, -90)
    if tab then
        table.insert(pts, { tab.x + tab.w - sideX(di, tab.h, tab.slant, d), di })
    end
    return pts
end

-- The window's background, filling exactly to the outline: a middle band,
-- strips along the top and bottom, and a quarter circle in each corner (the
-- round portrait mask), so the rounded corners have nothing poking out.
local CORNER_COORDS = { { 0, 0.5, 0, 0.5 }, { 0.5, 1, 0, 0.5 }, { 0.5, 1, 0.5, 1 }, { 0, 0.5, 0.5, 1 } }

local function createFill(host)
    local fill = { host = host, rects = {}, corners = {} }
    for i = 1, 3 do fill.rects[i] = host:CreateTexture(nil, "BACKGROUND", nil, -8) end
    for i = 1, 4 do
        fill.corners[i] = host:CreateTexture(nil, "BACKGROUND", nil, -8)
        fill.corners[i]:SetTexture(CIRCLE)
    end
    return fill
end

local function hideFill(fill)
    for _, tex in ipairs(fill.rects) do tex:Hide() end
    for _, tex in ipairs(fill.corners) do tex:Hide() end
end

local function layoutFill(fill, W, H, d, r, c)
    local host = fill.host
    local function place(tex, x1, y1, x2, y2)
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", x1, y1)
        tex:SetPoint("TOPRIGHT", host, "BOTTOMLEFT", x2, y2)
        tex:Show()
    end
    for _, tex in ipairs(fill.rects) do tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    if r <= 0 then
        place(fill.rects[1], d, d, W - d, H - d)
        fill.rects[2]:Hide()
        fill.rects[3]:Hide()
        for _, tex in ipairs(fill.corners) do tex:Hide() end
        return
    end
    place(fill.rects[1], d, d + r, W - d, H - d - r)
    place(fill.rects[2], d + r, H - d - r, W - d - r, H - d)
    place(fill.rects[3], d + r, d, W - d - r, d + r)
    local spots = { { d, H - d - r }, { W - d - r, H - d - r }, { W - d - r, d }, { d, d } }
    for i, tex in ipairs(fill.corners) do
        tex:SetTexCoord(unpack(CORNER_COORDS[i]))
        tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        place(tex, spots[i][1], spots[i][2], spots[i][1] + r, spots[i][2] + r)
    end
end

-- Chromes by window frame, so a row of tabs can tell its window which one
-- is selected (its outline then dips round that tab).
local windowChromes = setmetatable({}, { __mode = "k" })

---------------------------------------------------------------------------
-- Tab shapes
---------------------------------------------------------------------------

local function colorLines(lines, c)
    for _, line in ipairs(lines) do line:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
end

-- Shapes the art around `tab` (w by h): the cap above the tab's top (the
-- thin strip between the tab and the window's fill) and the body,
-- tapered by `slant` at the bottom, both ending on the outline's centre so
-- the line covers their hard edges. Unselected tabs also get their own
-- outline; the selected tab's is part of the window's.
local function shapeTabArt(art, tab, w, h, slant, t, selected)
    local g = outlineGeometry(t)
    local d = g.d
    art:ClearAllPoints()
    art:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, TAB_TUCK)
    art:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)

    -- The cap only bridges the tab's top and the window's background (which
    -- stops `d` above the window's edge). It must not reach further in: the
    -- window's own widgets (the Send Mail money box and buttons) sit right
    -- on its bottom edge.
    local top, bottom = sideX(0, h, slant, d), sideX(-h + d, h, slant, d)
    art.cap:ClearAllPoints()
    art.cap:SetPoint("BOTTOMLEFT", tab, "TOPLEFT", top, 0)
    art.cap:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -top, d + 0.5)
    art.body:ClearAllPoints()
    art.body:SetPoint("TOPLEFT", tab, "TOPLEFT", top, 0)
    art.body:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -top, d)
    if art.body.SetVertexOffset then
        art.body:SetVertexOffset(LOWER_LEFT, bottom - top, 0)
        art.body:SetVertexOffset(LOWER_RIGHT, top - bottom, 0)
    end

    local o = art.outer
    for _, line in ipairs(o) do line:SetShown(not selected) end
    if not selected then
        for _, line in ipairs(o) do line:SetThickness(g.width) end
        local xTop, xBottom = sideX(0, h, slant, d), sideX(-h + d, h, slant, d)
        o[1]:SetStartPoint("TOPLEFT", tab, w - xTop, 0)
        o[1]:SetEndPoint("TOPLEFT", tab, w - xBottom, -h + d)
        o[2]:SetStartPoint("TOPLEFT", tab, w - xBottom, -h + d)
        o[2]:SetEndPoint("TOPLEFT", tab, xBottom, -h + d)
        o[3]:SetStartPoint("TOPLEFT", tab, xBottom, -h + d)
        o[3]:SetEndPoint("TOPLEFT", tab, xTop, 0)
        colorLines(o, shade(t.inner or t.buttonBorder, g.innerShade))
    end
end

function Style.SkinTabs(edge, tabs, scope)
    local row = {}
    for _, tab in ipairs(tabs) do
        local points = {}
        for i = 1, tab:GetNumPoints() do points[i] = { tab:GetPoint(i) } end
        local skin = {
            tab = tab, selected = false, art = createTabArt(edge), setFonts = fontSkin(tab),
            points = points, height = tab:GetHeight(), level = tab:GetFrameLevel(),
        }
        tabSkins[tab] = skin
        table.insert(row, skin)

        -- Hover lightens the tab's fill a little; the outline stays as it is,
        -- so a hovered tab never looks like the selected one.
        tab:HookScript("OnEnter", function()
            local t = Style.Theme(scope)
            if t.chrome == "custom" and not skin.selected then skin.art:SetFill(lighten(t.buttonBg, 0.12)) end
        end)
        tab:HookScript("OnLeave", function()
            local t = Style.Theme(scope)
            if t.chrome == "custom" and not skin.selected then skin.art:SetFill(t.buttonBg) end
        end)
    end

    local function layout(t)
        local custom = t.chrome == "custom"
        local base = edge:GetFrameLevel()
        local x = 14
        local selectedTab
        for _, skin in ipairs(row) do
            local tab, art = skin.tab, skin.art
            local text = tab.Text or tab:GetFontString()
            tab:ClearAllPoints()
            if custom then
                local height = skin.selected and 26 or 23
                local slant = math.floor(height * 0.3)
                local width = math.max((text and text:GetStringWidth() or 40) + (TAB_PAD + slant) * 2, 72)
                tab:SetWidth(width)
                tab:SetHeight(height)
                tab:SetPoint("TOPLEFT", edge, "BOTTOMLEFT", x, 0)
                tab:SetFrameLevel(base + 4)
                skin.x, skin.slant = x, slant

                shapeTabArt(art, tab, width, height, slant, t, skin.selected)
                -- Selected: in front of the window. Others: behind it.
                art:SetFrameLevel(skin.selected and base + 2 or math.max(0, base - 1))
                art:SetFill(skin.selected and t.bg or t.buttonBg)
                if text then
                    text:ClearAllPoints()
                    text:SetPoint("CENTER", tab, "CENTER", 0, 1)
                end
                -- Hidden tabs (Settings when the mailbox isn't extended) take no space.
                if tab:IsShown() then x = x + width + TAB_GAP end
            else
                for _, point in ipairs(skin.points) do tab:SetPoint(unpack(point)) end
                tab:SetHeight(skin.height)
                tab:SetFrameLevel(skin.level)
                if text then
                    text:ClearAllPoints()
                    text:SetPoint("CENTER", tab, "CENTER", 0,
                        skin.selected and (tab.selectedTextY or -3) or (tab.deselectedTextY or 2))
                end
            end
            art:SetShown(custom and tab:IsShown())
            textureAlpha(tab, custom and 0 or 1)
            local highlight = tab:GetHighlightTexture()
            if highlight then highlight:SetAlpha(custom and 0 or 1) end
            -- Hovered labels keep their colour; selected tabs are disabled
            -- buttons, so "disabled" is the selected colour.
            skin.setFonts(t, { t.buttonText, t.buttonText, t.heading })
            if custom and skin.selected and tab:IsShown() then
                selectedTab = { x = skin.x, w = tab:GetWidth(), h = tab:GetHeight(), slant = skin.slant }
            end
        end
        local chrome = windowChromes[edge]
        if chrome then chrome.SetTab(selectedTab, t) end
    end

    local run = Style.Register(layout, scope)
    for _, skin in ipairs(row) do
        skin.run = run
        -- Blizzard resizes tabs when they're shown; lay out again after it.
        skin.tab:HookScript("OnShow", run)
        skin.tab:HookScript("OnHide", run)
    end
end

-- Blizzard's tab code swaps art and fonts on select; reapply after it.
if PanelTemplates_SelectTab then
    hooksecurefunc("PanelTemplates_SelectTab", function(tab)
        local skin = tabSkins[tab]
        if skin then skin.selected = true; skin.run() end
    end)
end
if PanelTemplates_DeselectTab then
    hooksecurefunc("PanelTemplates_DeselectTab", function(tab)
        local skin = tabSkins[tab]
        if skin then skin.selected = false; skin.run() end
    end)
end

-- Skins an edit box (InputBoxTemplate, or Blizzard's mail boxes with
-- $parentLeft/Middle/Right art): a filled, bordered box, or for the Letter
-- style an underline on the parchment. Set box.ccKeepColor (ours only) to
-- colour the text yourself.
local underlines = setmetatable({}, { __mode = "k" })
function Style.SkinEditBox(box, scope, keepColor, inset)
    local bg = backing(box)
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", -(inset or 0), 0)
    bg:SetPoint("BOTTOMRIGHT", 0, 0)
    local underline = bg:CreateTexture(nil, "BORDER")
    underline:SetHeight(1)
    underline:SetPoint("BOTTOMLEFT", 0, 1)
    underline:SetPoint("BOTTOMRIGHT", 0, 1)
    underlines[box] = underline
    Style.Register(function(t)
        local custom = t.chrome == "custom"
        setTemplateTextures(box, custom and 0 or 1)
        local lined = custom and t.underlineInputs
        bg:SetShown(custom)
        underline:SetShown(lined and true or false)
        if lined then
            underline:SetColorTexture(unpack(t.inputBorder))
            paint(bg, t, "small", nil)
        elseif custom then
            paint(bg, t, "small", t.inputBg, t.inputBorder)
        end
        if not (keepColor or box.ccKeepColor) then
            box:SetTextColor(unpack(t.inputText))
        end
        applyShadow(box, t)
    end, scope)
    return box
end

-- Colours Blizzard font strings or edit boxes by role in the custom styles
-- and puts their original colour back for the Blizzard style.
function Style.TextAll(list, role, scope)
    for _, fs in pairs(list) do
        if fs and fs.SetTextColor and fs.GetTextColor then
            local r, g, b, a = fs:GetTextColor()
            Style.Register(function(t)
                if t.chrome == "custom" then
                    local c = t[role] or t.text
                    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
                else
                    fs:SetTextColor(r, g, b, a)
                end
                applyShadow(fs, t)
            end, scope)
        end
    end
end

-- The font strings among a frame's own regions.
function Style.FontStrings(frame)
    local list = {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("FontString") then table.insert(list, region) end
    end
    return list
end

---------------------------------------------------------------------------
-- Progress bar
---------------------------------------------------------------------------

function Style.ProgressBar(parent, height, scope)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(height)
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT", 3, -3)
    bar:SetPoint("BOTTOMRIGHT", -3, 3)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)
    frame.bar = bar
    frame.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.text:SetPoint("LEFT", 4, 0)
    frame.text:SetPoint("RIGHT", -4, 0)
    frame.text:SetWordWrap(false)
    frame.text:SetShadowOffset(1, -1)
    frame.text:SetShadowColor(0, 0, 0, 1)
    Style.Register(function(t)
        local round = t.chrome == "custom" and t.edge == "round"
        paint(frame, round and t or Style.THEMES.flat, "small", t.groove, t.grooveBorder)
        -- Light text on the dark groove, ink on the Letter's parchment groove.
        frame.text:SetTextColor(unpack(t.key == "letter" and t.text or { 1, 1, 1, 1 }))
        frame.text:SetShadowColor(0, 0, 0, t.key == "letter" and 0 or 1)
    end, scope)
    -- Fill colour: "progress" (the style's) or "success".
    function frame:SetState(state)
        local c = state == "success" and Style.COLOR.success or Style.Theme(scope).fill
        bar:SetStatusBarColor(c[1], c[2], c[3], 1)
    end
    return frame
end

---------------------------------------------------------------------------
-- Dropdowns
---------------------------------------------------------------------------

-- A WowStyle1DropdownTemplate (Blizzard_Menu) set up with `generator`; if
-- the template is missing, a button that opens the same menu as a context
-- menu, labelled by getText(). Call :GenerateMenu() to refresh its text.
function Style.Dropdown(parent, width, generator, getText, scope)
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if ok and dropdown and dropdown.SetupMenu then
        dropdown:SetWidth(width)
        dropdown:SetupMenu(generator)
        return dropdown
    end
    local button = Style.Button(parent, "", width, 22, function(self)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, generator)
        end
    end, scope)
    function button:GenerateMenu() self:SetText(getText and getText() or "") end
    button:GenerateMenu()
    return button
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------

-- Puts the logo in a portrait frame's portrait, clipped to the circle.
local function setPortrait(frame)
    if not (frame.SetPortraitToAsset and frame.GetPortrait) then return end
    frame:SetPortraitToAsset(Style.LOGO)
    local portrait = frame:GetPortrait()
    if portrait and portrait.AddMaskTexture and not portrait.ccMask then
        local mask = frame:CreateMaskTexture()
        mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(portrait)
        portrait:AddMaskTexture(mask)
        portrait.ccMask = mask
    end
end

-- Blizzard's window, as a child filling ours, shown for the Blizzard style.
local function createBlizzardChrome(frame, title, close)
    local ok, chrome = pcall(CreateFrame, "Frame", nil, frame, "ButtonFrameTemplate")
    if not (ok and chrome and chrome.Inset) then
        if ok and chrome then chrome:Hide() end
        chrome = CreateFrame("Frame", nil, frame, "BasicFrameTemplateWithInset")
    end
    chrome:SetAllPoints()
    chrome:EnableMouse(false) -- drags and clicks fall through to the window
    if chrome.PortraitContainer then
        if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(chrome) end
        setPortrait(chrome)
    end
    if chrome.SetTitle then
        chrome:SetTitle(title)
    else
        local text = chrome.TitleText or chrome:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        if not chrome.TitleText then text:SetPoint("TOP", 0, -5) end
        text:SetText(Style.Logo(14) .. " " .. title)
    end
    -- The template's close button hides its parent, which is this child.
    if chrome.CloseButton then chrome.CloseButton:SetScript("OnClick", close) end
    return chrome
end

-- A circle in `color`, `inset` pixels inside `parent`.
local function circle(parent, layer, sublevel, inset)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(CIRCLE)
    tex:SetPoint("TOPLEFT", inset, -inset)
    tex:SetPoint("BOTTOMRIGHT", -inset, inset)
    return tex
end

-- The custom close button: a red wax seal, or a plain X for Flat.
local function createCloseButton(frame, close)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(24, 24)
    button:SetScript("OnClick", close)
    button.rim = circle(button, "ARTWORK", 1, 0)
    button.wax = circle(button, "ARTWORK", 2, 2)
    button.ring = circle(button, "ARTWORK", 3, 5)
    button.core = circle(button, "ARTWORK", 4, 6)
    button.x = button:CreateTexture(nil, "OVERLAY")
    button.x:SetPoint("CENTER")
    button.x:SetTexture(CLOSE_X)
    button:SetScript("OnEnter", function(self) self.x:SetVertexColor(1, 1, 1) end)
    button:SetScript("OnLeave", function(self) self.x:SetVertexColor(unpack(self.xColor or { 1, 1, 1 })) end)
    function button:Apply(t, compact)
        local seal = t.close == "seal"
        for _, tex in ipairs({ self.rim, self.wax, self.ring, self.core }) do tex:SetShown(seal) end
        if seal then
            local size = compact and 18 or 24
            self:SetSize(size, size)
            self.ring:ClearAllPoints()
            self.ring:SetPoint("TOPLEFT", size * 0.2, -size * 0.2)
            self.ring:SetPoint("BOTTOMRIGHT", -size * 0.2, size * 0.2)
            self.core:ClearAllPoints()
            self.core:SetPoint("TOPLEFT", size * 0.25, -size * 0.25)
            self.core:SetPoint("BOTTOMRIGHT", -size * 0.25, size * 0.25)
            self.rim:SetVertexColor(unpack(rgb("5a1210")))
            self.wax:SetVertexColor(unpack(rgb("c0302a")))
            self.ring:SetVertexColor(unpack(rgb("e86a5a")))
            self.core:SetVertexColor(unpack(rgb("c0302a")))
            self.x:SetSize(size / 2, size / 2)
            self.xColor = PARCHMENT
        else
            self:SetSize(20, 20)
            self.x:SetSize(14, 14)
            self.xColor = { 0.75, 0.75, 0.75 }
        end
        self.x:SetVertexColor(unpack(self.xColor))
    end
    return button
end

-- The custom chrome on `frame`: the background (on `bgFrame`), the drawn
-- border (outer and inner lines, one path that dips round a selected tab),
-- and a title strip with the logo, title and close button.
-- compact: a slimmer title bar for Blizzard's windows, whose content starts
-- 30px from the top. Returns { Apply(t) (hides it all for the Blizzard
-- style), SetTitle(text), SetTab(tab, t), strip }.
local function buildChrome(frame, bgFrame, title, close, compact)
    local chrome = {}
    local fill = createFill(bgFrame)
    -- Above the background and a selected tab's fill (level +2), below the
    -- tab labels (+4) and the title strip (+5).
    local border = CreateFrame("Frame", nil, frame)
    border:SetAllPoints(frame)
    border:SetFrameLevel(frame:GetFrameLevel() + 3)
    local outerPool, innerPool = linePool(border), linePool(border)
    local strip = CreateFrame("Frame", nil, frame)
    strip:SetFrameLevel(frame:GetFrameLevel() + 5)
    local logo = strip:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(Style.LOGO)
    local titleText = strip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    titleText:SetText(title or "")
    local rule = strip:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    local closeButton = createCloseButton(strip, close)
    chrome.strip = strip

    function chrome.SetTitle(text) titleText:SetText(text or "") end

    -- Background and border, for the window's current size and selected tab.
    function chrome.Redraw(t)
        local W, H = frame:GetWidth(), frame:GetHeight()
        poolStart(outerPool)
        poolStart(innerPool)
        if t.chrome ~= "custom" or not W or W <= 0 or H <= 0 then
            hideFill(fill)
        else
            local g = outlineGeometry(t)
            layoutFill(fill, W, H, g.d, g.radius, t.bg)
            drawPath(outerPool, framePath(W, H, g.d, g.radius, chrome.tab), true, g.width, shade(t.border, g.shade))
            if t.inner then
                drawPath(innerPool, innerPath(W, H, g.innerD, g.innerRadius, g.d, chrome.tab), not chrome.tab,
                    g.innerWidth, shade(t.inner, g.innerShade))
            end
        end
        poolFinish(outerPool)
        poolFinish(innerPool)
    end

    -- The selected tab ({ x, w, h, slant }, or nil), from Style.SkinTabs.
    function chrome.SetTab(tab, t)
        chrome.tab = tab
        chrome.Redraw(t)
    end

    frame:HookScript("OnSizeChanged", function() chrome.Redraw(Style.Theme()) end)
    windowChromes[frame] = chrome

    function chrome.Apply(t)
        local custom = t.chrome == "custom"
        strip:SetShown(custom)
        chrome.Redraw(t)
        if not custom then return end

        strip:ClearAllPoints()
        logo:ClearAllPoints()
        titleText:ClearAllPoints()
        closeButton:ClearAllPoints()
        closeButton:Apply(t, compact)
        local font = compact and GameFontNormal or GameFontNormalLarge
        -- The title bar sits just inside the innermost border line, so it
        -- never covers the border (it's drawn above it). Compact bars are 20
        -- tall to end before 30px, where Blizzard's mail content starts.
        local g = outlineGeometry(t)
        local inset = t.inner and (g.innerD + g.innerWidth / 2 + 1.5) or (g.d + g.width / 2 + 0.5)
        if t.key == "flat" then
            strip:SetPoint("TOPLEFT", inset, -inset)
            strip:SetPoint("TOPRIGHT", -inset, -inset)
            strip:SetHeight(compact and 20 or 24)
            titleText:SetFontObject(GameFontNormal)
            logo:SetSize(16, 16)
        elseif t.titleStrip then
            strip:SetPoint("TOPLEFT", inset, -inset)
            strip:SetPoint("TOPRIGHT", -inset, -inset)
            strip:SetHeight(compact and 20 or 34)
            titleText:SetFontObject(font)
            logo:SetSize(compact and 16 or 24, compact and 16 or 24)
        else -- letter: title written on the page, a rule under it
            local x, y = compact and inset + 1 or math.max(inset, 14), compact and inset or math.max(inset, 12)
            strip:SetPoint("TOPLEFT", x, -y)
            strip:SetPoint("TOPRIGHT", -x, -y)
            strip:SetHeight(compact and 20 or 36)
            titleText:SetFontObject(font)
            logo:SetSize(compact and 16 or 28, compact and 16 or 28)
        end
        -- After SetFontObject, which resets colour and shadow.
        titleText:SetTextColor(unpack(t.titleText))
        applyShadow(titleText, t, t.noShadow or t.titleNoShadow)
        logo:SetPoint("LEFT", compact and 4 or 8, 0)
        titleText:SetPoint("LEFT", logo, "RIGHT", 6, 0)
        titleText:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
        closeButton:SetPoint("RIGHT", compact and -3 or -6, 0)
        paint(strip, t, "small", t.titleStrip and t.titleBg or nil, t.titleStrip and t.titleBorder or nil)
        local ruleColor = t.titleRule or (not t.titleStrip and t.line) or nil
        rule:SetShown(ruleColor ~= nil)
        if ruleColor then rule:SetColorTexture(unpack(ruleColor)) end
    end
    return chrome
end

-- A window in the chosen style. Content goes in `frame.body`, which is
-- re-anchored for each style. opts: parent, strata ("DIALOG"), movable
-- (true), closeOnEscape (true, needs a name), onClose (called when the
-- user clicks close), compact (the slim title bar the mailbox uses, for
-- windows that sit beside it).
function Style.CreateWindow(name, title, width, height, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", name, opts.parent or UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata(opts.strata or "DIALOG")
    frame:EnableMouse(true)
    -- Toplevel: a click raises the window with everything in it, and so does
    -- showing it. Otherwise two overlapping windows interleave, since each
    -- body sits several levels above its own frame.
    frame:SetToplevel(true)
    frame:HookScript("OnShow", frame.Raise)
    frame:Hide()
    if opts.movable ~= false then
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    end
    if opts.closeOnEscape ~= false and name and UISpecialFrames then
        tinsert(UISpecialFrames, name)
    end
    local function close()
        frame:Hide()
        if opts.onClose then opts.onClose() end
    end

    local blizzard = createBlizzardChrome(frame, title, close)
    local chrome = buildChrome(frame, frame, title, close, opts.compact)

    local body = CreateFrame("Frame", nil, frame)
    body:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.body = body

    Style.Register(function(t)
        local custom = t.chrome == "custom"
        blizzard:SetShown(not custom)
        chrome.Apply(t)
        body:ClearAllPoints()
        if custom then
            body:SetPoint("TOPLEFT", chrome.strip, "BOTTOMLEFT", t.key == "flat" and 10 or 4, opts.compact and -6 or -8)
            body:SetPoint("BOTTOMRIGHT", -13, 13)
        elseif blizzard.Inset then
            body:SetPoint("TOPLEFT", blizzard.Inset, "TOPLEFT", 6, -6)
            body:SetPoint("BOTTOMRIGHT", blizzard.Inset, "BOTTOMRIGHT", -6, 6)
        else
            body:SetPoint("TOPLEFT", 10, -30)
            body:SetPoint("BOTTOMRIGHT", -10, 10)
        end
    end)
    return frame
end

-- Restyles one of Blizzard's ButtonFrameTemplate windows (MailFrame,
-- OpenMailFrame) in place: its art is faded out (alpha, never Hide) and our
-- chrome drawn behind its content on separate frames. Its title is mirrored
-- from SetTitle, and our close button clicks Blizzard's, so Blizzard's own
-- code (UI panel handling included) runs unchanged. `extra` is more of its
-- art to fade (a list of regions or frames).
function Style.SkinBlizzardWindow(frame, extra)
    local art = {
        frame.NineSlice, frame.Bg, frame.TopTileStreaks, frame.PortraitContainer,
        frame.Inset, frame.CloseButton, frame.TitleContainer,
    }
    for _, region in ipairs(extra or {}) do table.insert(art, region) end

    local function close()
        if frame.CloseButton then frame.CloseButton:Click() else HideUIPanel(frame) end
    end
    local titleFs = frame.GetTitleText and frame:GetTitleText()
    local chrome = buildChrome(frame, backing(frame, true), titleFs and titleFs:GetText(), close, true)
    if frame.SetTitle then
        hooksecurefunc(frame, "SetTitle", function(_, text) chrome.SetTitle(text) end)
    end

    Style.Register(function(t)
        setAlpha(art, t.chrome == "custom" and 0 or 1)
        backing(frame, true):SetShown(t.chrome == "custom")
        chrome.Apply(t)
    end)
end

---------------------------------------------------------------------------
-- Class colours and icons (for characters recorded in db.characters)
---------------------------------------------------------------------------

function Style.ClassColor(class)
    if not class then return nil end
    local color = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if color then return color.r, color.g, color.b end
end

-- Sets a texture to the round class icon. Returns false if unknown.
function Style.SetClassIcon(texture, class)
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if not coords then return false end
    texture:SetTexture(CLASS_CIRCLES)
    texture:SetTexCoord(unpack(coords))
    return true
end

function Style.ClassIconMarkup(class, size)
    local c = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if not c then return "" end
    size = size or 14
    return ("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t"):format(CLASS_CIRCLES, size, size,
        math.floor(c[1] * 256), math.floor(c[2] * 256), math.floor(c[3] * 256), math.floor(c[4] * 256))
end

-- A recorded alt's name in class colour, or (Letter style, where class
-- colours don't read on parchment) with its class icon in front.
function Style.ColorName(name, scope)
    if not name or name == "" then return name end
    local char = ns:FindCharacter(name)
    local class = char and char.class
    if not class then return name end
    if not Style.Theme(scope).classText then
        return Style.ClassIconMarkup(class, 12) .. " " .. name
    end
    local r, g, b = Style.ClassColor(class)
    if not r then return name end
    return hex(r, g, b) .. name .. "|r"
end

---------------------------------------------------------------------------
-- Sounds (off with db.playSounds = false)
---------------------------------------------------------------------------

local SOUNDS = {
    send   = "LOOT_WINDOW_COIN_SOUND",  -- each mail sent
    finish = "UI_AUTO_QUEST_COMPLETE",  -- the whole batch is done
}

function Style.PlaySound(which)
    if not (ns.db and ns.db.playSounds) or not (SOUNDKIT and PlaySound) then return end
    local id = SOUNDKIT[SOUNDS[which] or ""]
    if id then PlaySound(id) end
end
