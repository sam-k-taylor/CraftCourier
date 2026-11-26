local _, ns = ...

-- Recipient name suggestions for edit boxes. Sources, best first:
--   * the game's own mail autocomplete (every character on the account,
--     friends, guild, recently interacted players) - needs typed text
--   * alts recorded on login, names already used as recipients
--   * character friends and Battle.net friends playing this game flavor
-- Only characters the player can actually mail (same faction, and same world:
-- on Forever that's the ruleset, see ns:IsSameWorld) are suggested.

local VISIBLE_ROWS = 10      -- the list scrolls past this
local MAX_AUTOCOMPLETE = 50  -- results asked of the game per query
local ROW_HEIGHT = 18

local SOURCE_LABELS = {
    self = "|cffffd100You|r",
    alt = "|cff33ff99Alt|r",
    friend = "|cff66bbffFriend|r",
    guild = "|cff40ff40Guild|r",
    bnet = "|cff00ccffBattle.net|r",
    used = "|cffccccccRecipient|r",
    recent = "|cffccccccRecent|r",
}

-- Forever's realms are shards, so an alt on another shard of the same ruleset
-- may come back as AccountCharacter rather than AccountCharacterSameRealm.
-- Accept both; addCandidate drops "Name-Realm" results from another ruleset.
local function isAccountPriority(priority)
    local p = Enum and Enum.AutoCompletePriority
    return p and priority ~= nil
        and (priority == p.AccountCharacter or priority == p.AccountCharacterSameRealm) or false
end

-- Enum.AutoCompletePriority -> source label key.
local function sourceForPriority(priority)
    local p = Enum and Enum.AutoCompletePriority
    if not p then return "recent" end
    if isAccountPriority(priority) then return "alt" end
    if priority == p.Friend then return "friend" end
    if priority == p.Guild then return "guild" end
    return "recent"
end

-- Mail only reaches characters in the player's world and faction. Faction
-- checks mirror Blizzard_FriendsFrame/Camelot/FriendsFrame.lua; realm checks
-- compare rulesets instead of realm IDs (see ns:IsSameWorld).

local factionByRace = {}
local function factionForRace(englishRace)
    if factionByRace[englishRace] == nil then
        factionByRace[englishRace] = false
        if C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
            for raceID = 1, 100 do
                local info = C_CreatureInfo.GetRaceInfo(raceID)
                if info and info.clientFileString == englishRace then
                    local faction = C_CreatureInfo.GetFactionInfo(raceID)
                    factionByRace[englishRace] = faction and faction.groupTag or false
                    break
                end
            end
        end
    end
    return factionByRace[englishRace] or nil
end

-- Realm name and race from the GUID ("" realm means ours). Unknown
-- information doesn't block (the GUID may not be cached yet).
local function isMailableGUID(guid)
    if not guid or guid == "" then return true end
    local _, _, _, englishRace, _, _, realmName = GetPlayerInfoByGUID(guid)
    if not ns:IsSameWorld(realmName) then return false end
    local faction = englishRace and factionForRace(englishRace)
    return not faction or faction == UnitFactionGroup("player")
end

local function isMailableAlt(char)
    return ns:IsSameWorld(char.realm)
        and (not char.faction or char.faction == UnitFactionGroup("player"))
end

local function isMailableBNetCharacter(game)
    if not (game.clientProgram == BNET_CLIENT_WOW
            and game.characterName and game.characterName ~= ""
            and (not WOW_PROJECT_ID or game.wowProjectID == WOW_PROJECT_ID)
            and game.factionName == UnitFactionGroup("player")) then
        return false
    end
    -- Not realm IDs as Blizzard does: different shards of one ruleset differ.
    return ns:IsSameWorld(game.realmName)
end

local function addCandidate(list, seen, value, source, class)
    -- "Name-Realm" in our world mails the same as "Name"; show the shorter
    -- form. Other worlds can't be mailed, so drop them (except names the
    -- user already chose as recipients).
    local name, realm = value:match("^(.-)%-([^%-]+)$")
    if name then
        if ns:IsSameWorld(realm) then
            value = name
        elseif source ~= "used" then
            return
        end
    end
    local key = value:lower()
    -- The logged-in character is only listed through the "self" entry.
    if seen[key] or (ns:IsSelf(value) and source ~= "self") then return end
    seen[key] = true
    table.insert(list, { value = value, source = source, class = class })
end

-- Same source and filter Blizzard's SendMailNameEditBox uses (MailFrame.xml).
local function addGameAutoComplete(text, add)
    if text == "" or not (C_AutoComplete and C_AutoComplete.GetAutoCompleteResults) then return end
    local mail = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
    local include = mail and mail.include or 0xffffffff
    local exclude = mail and mail.exclude or 8 -- Enum.AutoCompleteEntryFlag.Bnet
    local ok, results = pcall(C_AutoComplete.GetAutoCompleteResults, text, MAX_AUTOCOMPLETE, #text, true, include, exclude)
    if not ok or type(results) ~= "table" then return end

    for _, result in ipairs(results) do
        if result.name and result.name ~= "" then
            local p = Enum and Enum.AutoCompletePriority
            add(result.name, sourceForPriority(result.priority), nil,
                p and result.priority == p.AccountCharacterSameRealm)
        end
    end
end

-- Every same-realm character on the account, from the game's autocomplete.
-- It needs typed text, so ask once per letter. Covers alts that were never
-- logged in with the addon. Cached briefly, since this runs per keystroke.
local accountCache, accountCacheTime
local function getAccountCharacters()
    if accountCache and GetTime() - accountCacheTime < 30 then return accountCache end
    accountCache, accountCacheTime = {}, GetTime()
    if not (C_AutoComplete and C_AutoComplete.GetAutoCompleteResults) then
        return accountCache
    end
    local mail = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
    local include = mail and mail.include or 0xffffffff
    local exclude = mail and mail.exclude or 8
    local seen = {}
    for letter in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
        local ok, results = pcall(C_AutoComplete.GetAutoCompleteResults, letter, MAX_AUTOCOMPLETE, 1, true, include, exclude)
        if ok and type(results) == "table" then
            for _, result in ipairs(results) do
                local name = result.name
                if name and name ~= "" and isAccountPriority(result.priority)
                        and not seen[name:lower()] then
                    seen[name:lower()] = true
                    table.insert(accountCache, {
                        name = name,
                        sameRealm = result.priority == Enum.AutoCompletePriority.AccountCharacterSameRealm,
                    })
                end
            end
        end
    end
    return accountCache
end

-- Lowercased name (without realm) -> true for characters known to be on
-- another realm or faction. Applied to every source, because the friends
-- list and the game's autocomplete return bare names with no realm/faction.
local function collectBlocked()
    local blocked = {}
    local function block(name)
        if name and name ~= "" then
            blocked[(name:match("^(.-)%-") or name):lower()] = true
        end
    end

    -- The same name can be recorded on several realms; only block it if no
    -- recorded copy of it is mailable.
    local mailableAlt = {}
    for _, char in pairs(ns.db.characters) do
        if isMailableAlt(char) then mailableAlt[char.name:lower()] = true end
    end
    for _, char in pairs(ns.db.characters) do
        if not isMailableAlt(char) and not mailableAlt[char.name:lower()] then block(char.name) end
    end

    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.name and not isMailableGUID(info.guid) then
                block(info.name)
            end
        end
    end

    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendNumGameAccounts then
        for i = 1, BNGetNumFriends() or 0 do
            for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
                local game = C_BattleNet.GetFriendGameAccountInfo(i, j)
                if game and game.characterName and not isMailableBNetCharacter(game) then
                    block(game.characterName)
                end
            end
        end
    end

    return blocked
end

-- For /ccr debug <text>: why a name is or isn't suggested.
function ns:DebugSuggestions(text)
    local priorities = {}
    for k, v in pairs(Enum and Enum.AutoCompletePriority or {}) do
        priorities[v] = k
    end
    print(("  realm '%s' (ruleset %s, realmID %s), faction %s"):format(self:GetPlayerRealm(),
        tostring(self:RulesetOf(self:GetPlayerRealm()) or "unknown"),
        tostring(GetRealmID and GetRealmID()), tostring(UnitFactionGroup("player"))))

    local blocked = collectBlocked()
    print("  recorded characters:")
    for key, char in pairs(self.db.characters) do
        print(("    %s: realm '%s' faction %s%s"):format(key, tostring(char.realm), tostring(char.faction),
            isMailableAlt(char) and "" or " |cffff6060(other ruleset/faction)|r"))
    end
    local names = {}
    for name in pairs(blocked) do table.insert(names, name) end
    print("  hidden as other ruleset/faction: " .. (#names > 0 and table.concat(names, ", ") or "none"))

    if text ~= "" and C_AutoComplete and C_AutoComplete.GetAutoCompleteResults then
        local mail = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
        local ok, results = pcall(C_AutoComplete.GetAutoCompleteResults, text, MAX_AUTOCOMPLETE, #text, true,
            mail and mail.include or 0xffffffff, mail and mail.exclude or 8)
        print(("  game autocomplete for '%s':"):format(text))
        if not ok then
            print("    error: " .. tostring(results))
        else
            for _, r in ipairs(results or {}) do
                print(("    %s (priority %s)"):format(tostring(r.name),
                    priorities[r.priority] or tostring(r.priority)))
            end
        end
    end

    local shown = {}
    local lower = text:lower()
    for _, entry in ipairs(self:GetRecipientCandidates(text)) do
        if entry.value:lower():find(lower, 1, true) then
            table.insert(shown, entry.value .. " (" .. entry.source .. ")")
        end
    end
    print("  suggested: " .. (#shown > 0 and table.concat(shown, ", ") or "none"))
end

function ns:GetRecipientCandidates(text)
    local list, seen = {}, {}
    local blocked = collectBlocked()

    -- sameRealm: the game itself says this character is on our realm.
    local function add(value, source, class, sameRealm)
        local bare = (value:match("^(.-)%-") or value):lower()
        if blocked[bare] and source ~= "used" and not sameRealm then return end
        addCandidate(list, seen, value, source, class)
    end

    -- The current character can't be mailed from here, but users still assign
    -- it categories (it receives them when they play another character).
    local me = self:GetPlayerName()
    if me then
        local _, class = UnitClass("player")
        addCandidate(list, seen, me, "self", class)
    end

    -- Recorded alts first, as they carry a class for colouring.
    for _, char in pairs(self.db.characters) do
        add(char.name, "alt", char.class)
    end
    for _, alt in ipairs(getAccountCharacters()) do
        add(alt.name, "alt", nil, alt.sameRealm)
    end

    addGameAutoComplete(text or "", add)

    for _, recipient in pairs(self.db.recipients) do
        add(recipient, "used")
    end

    if C_FriendList and C_FriendList.GetNumFriends then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.name then
                add(info.name, "friend")
            end
        end
    end

    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendNumGameAccounts then
        for i = 1, BNGetNumFriends() or 0 do
            for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
                local game = C_BattleNet.GetFriendGameAccountInfo(i, j)
                if game and game.characterName and game.characterName ~= "" then
                    add(game.characterName, "bnet", game.classFilename)
                end
            end
        end
    end

    -- Alts first, then everyone else, alphabetically within each.
    table.sort(list, function(a, b)
        local aAlt = a.source == "alt" or a.source == "self"
        local bAlt = b.source == "alt" or b.source == "self"
        if aAlt ~= bAlt then return aAlt end
        return a.value:lower() < b.value:lower()
    end)
    return list
end

---------------------------------------------------------------------------
-- Dropdown
---------------------------------------------------------------------------

local dropdown
local activeBox
local matches = {}
local selected = 0
local offset = 0 -- index in matches of the row above the first visible one
local exactMatch = false -- the box's text already names a candidate

-- The list sits on a dark tooltip in every style, so class colours always read.
local function colorize(entry)
    local r, g, b = ns.Style.ClassColor(entry.class)
    if r then
        return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), entry.value)
    end
    return entry.value
end

local function hide()
    if dropdown then dropdown:Hide() end
    activeBox = nil
    selected = 0
    offset = 0
    exactMatch = false
end

local function accept(index)
    local entry = matches[index]
    if not (entry and activeBox) then return end
    local box = activeBox
    box:SetText(entry.value)
    box:SetCursorPosition(#entry.value)
    hide()
    -- Commit through the box's OnEditFocusLost. A mouse click on a row has
    -- already taken focus away, so in that case run the handler directly.
    if box:HasFocus() then
        box:ClearFocus()
    else
        local onFocusLost = box:GetScript("OnEditFocusLost")
        if onFocusLost then onFocusLost(box) end
    end
end

local function render()
    local maxOffset = math.max(#matches - VISIBLE_ROWS, 0)
    offset = math.min(math.max(offset, 0), maxOffset)
    for i, row in ipairs(dropdown.rows) do
        local entry = matches[offset + i]
        if entry then
            row.name:SetText(colorize(entry))
            row.source:SetText(SOURCE_LABELS[entry.source])
            row.selected:SetShown(offset + i == selected)
            row:Show()
        else
            row:Hide()
        end
    end
    if maxOffset > 0 then
        dropdown.more:SetFormattedText("%d-%d of %d (scroll for more)",
            offset + 1, math.min(offset + VISIBLE_ROWS, #matches), #matches)
        dropdown.more:Show()
    else
        dropdown.more:Hide()
    end
end

local function highlight(index)
    selected = index
    -- Keep the selected row in view.
    if index > 0 then
        if index <= offset then
            offset = index - 1
        elseif index > offset + VISIBLE_ROWS then
            offset = index - VISIBLE_ROWS
        end
    end
    render()
end

local function createDropdown()
    dropdown = CreateFrame("Frame", "CraftCourierSuggestFrame", UIParent, "TooltipBackdropTemplate")
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetClampedToScreen(true)
    dropdown:EnableMouseWheel(true)
    dropdown:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta
        render()
    end)
    dropdown:Hide()
    dropdown.rows = {}

    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, dropdown)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * ROW_HEIGHT)

        row.selected = row:CreateTexture(nil, "BACKGROUND")
        row.selected:SetAllPoints()
        row.selected:SetColorTexture(1, 1, 1, 0.15)
        row.selected:Hide()
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        row.source = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.source:SetPoint("RIGHT", -4, 0)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetPoint("RIGHT", row.source, "LEFT", -8, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        row:SetScript("OnClick", function() accept(offset + i) end)
        dropdown.rows[i] = row
    end

    dropdown.more = dropdown:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dropdown.more:SetPoint("BOTTOM", 0, 6)
end

-- typing: true when called from user input, so the first match is
-- pre-selected and Enter/Tab picks it (like Blizzard's name boxes).
local function update(box, typing)
    local text = strtrim(box:GetText() or ""):lower()
    local exact = false
    local excludeSelf = box.ccSuggestOpts and box.ccSuggestOpts.excludeSelf
    wipe(matches)

    -- Prefix matches first, then substring matches.
    local candidates = ns:GetRecipientCandidates(strtrim(box:GetText() or ""))
    for pass = 1, 2 do
        for _, entry in ipairs(candidates) do
            local pos = entry.value:lower():find(text, 1, true)
            exact = exact or entry.value:lower() == text
            local wanted = (pass == 1 and pos == 1) or (pass == 2 and pos and pos > 1)
            if excludeSelf and entry.source == "self" then wanted = false end
            if wanted and entry.value:lower() ~= text then
                table.insert(matches, entry)
            end
        end
    end

    if #matches == 0 then
        hide()
        return
    end

    if not dropdown then createDropdown() end
    activeBox = box
    offset = 0
    exactMatch = exact
    -- Don't pre-select when the text already names someone, so Enter keeps it.
    highlight((typing and text ~= "" and not exact) and 1 or 0)
    local rows = math.min(#matches, VISIBLE_ROWS)
    local footer = #matches > VISIBLE_ROWS and ROW_HEIGHT or 0
    dropdown:ClearAllPoints()
    dropdown:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, 0)
    dropdown:SetSize(math.max(box:GetWidth() + 12, 280), rows * ROW_HEIGHT + footer + 12)
    dropdown:Show()
end

-- Adds suggestions to an EditBox. Arrow keys move, Tab/Enter accept, Escape closes.
-- opts.excludeSelf: leave out the logged-in character (it can't be mailed).
function ns:AttachSuggestions(box, opts)
    box.ccSuggestOpts = opts
    box:SetAltArrowKeyMode(false)

    box:HookScript("OnTextChanged", function(self, userInput)
        if userInput then update(self, true) end
    end)
    box:HookScript("OnEditFocusGained", function(self) update(self) end)
    box:HookScript("OnEditFocusLost", function(self)
        -- Focus is lost on mouse down, but a row's OnClick fires on mouse up,
        -- so keep the list open while the cursor is over it.
        local function check()
            if activeBox ~= self or self:HasFocus() then return end
            if dropdown and dropdown:IsShown() and dropdown:IsMouseOver() then
                C_Timer.After(0.1, check)
            else
                hide()
            end
        end
        C_Timer.After(0.1, check)
    end)
    box:HookScript("OnArrowPressed", function(self, key)
        if activeBox ~= self or #matches == 0 then return end
        if key == "DOWN" then
            highlight(selected % #matches + 1)
        elseif key == "UP" then
            highlight((selected - 2) % #matches + 1)
        end
    end)
    -- Tab takes the highlighted row, or the first one, but never replaces a
    -- name that's already complete.
    box:HookScript("OnTabPressed", function(self)
        if activeBox == self and (selected > 0 or not exactMatch) then
            accept(math.max(selected, 1))
        end
    end)
end

-- The Send Mail "To:" box gets the same list as the settings boxes in place
-- of Blizzard's autocomplete popup and inline completion.
function ns:AttachMailSuggestions()
    local box = SendMailNameEditBox
    if not box or box.ccSuggestOpts then return end
    -- Without a source, AutoComplete_Update and the inline completion
    -- (AutoCompleteEditBox_AddHighlightedText) return early.
    box.autoCompleteSource = nil
    box.addHighlightedText = nil
    if AutoComplete_HideIfAttachedTo then AutoComplete_HideIfAttachedTo(box) end
    self:AttachSuggestions(box, { excludeSelf = true })

    -- Enter takes the highlighted row, then moves on to the subject as
    -- Blizzard's handler does.
    local onEnter = box:GetScript("OnEnterPressed")
    box:SetScript("OnEnterPressed", function(b, ...)
        if ns:AcceptSuggestion(b) then
            if SendMailSubjectEditBox then SendMailSubjectEditBox:SetFocus() end
        elseif onEnter then
            onEnter(b, ...)
        end
    end)
    -- The first Escape closes the list, the next leaves the box.
    local onEscape = box:GetScript("OnEscapePressed")
    box:SetScript("OnEscapePressed", function(b, ...)
        if activeBox == b and dropdown and dropdown:IsShown() then
            hide()
        elseif onEscape then
            onEscape(b, ...)
        end
    end)
    if MailFrame then MailFrame:HookScript("OnHide", hide) end
end

-- Called by the box's own OnEnterPressed; returns true if a suggestion was taken.
function ns:AcceptSuggestion(box)
    if activeBox == box and selected > 0 then
        accept(selected)
        return true
    end
    return false
end

function ns:HideSuggestions()
    hide()
end
