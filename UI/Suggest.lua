local _, ns = ...

-- Recipient name suggestions for edit boxes. Sources, best first:
--   * the game's own mail autocomplete (every character on the account,
--     friends, guild, recently interacted players) - needs typed text
--   * alts recorded on login, names already used as recipients
--   * character friends and Battle.net friends playing this game flavor
-- Only characters the player can actually mail (same realm and faction) are
-- suggested.

local MAX_SUGGESTIONS = 8
local ROW_HEIGHT = 18

local SOURCE_LABELS = {
    alt = "|cff33ff99Alt|r",
    friend = "|cff66bbffFriend|r",
    guild = "|cff40ff40Guild|r",
    bnet = "|cff00ccffBattle.net|r",
    used = "|cffccccccRecipient|r",
    recent = "|cffccccccRecent|r",
}

-- Enum.AutoCompletePriority -> source label key.
local function sourceForPriority(priority)
    local p = Enum and Enum.AutoCompletePriority
    if not p then return "recent" end
    if priority == p.AccountCharacter or priority == p.AccountCharacterSameRealm then return "alt" end
    if priority == p.Friend then return "friend" end
    if priority == p.Guild then return "guild" end
    return "recent"
end

-- Mail only reaches characters on the player's realm and faction. These
-- mirror the checks Blizzard_FriendsFrame/Camelot/FriendsFrame.lua uses.
local function guidServerID(guid)
    return guid and guid:match("^Player%-(%d+)%-")
end

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

-- Realm from the GUID's server ID; faction from the character's race.
-- Unknown information doesn't block (the GUID may not be cached yet).
local function isMailableGUID(guid)
    if not guid or guid == "" then return true end
    local theirs, mine = guidServerID(guid), guidServerID(UnitGUID("player"))
    if theirs and mine and theirs ~= mine then return false end
    local _, _, _, englishRace = GetPlayerInfoByGUID(guid)
    local faction = englishRace and factionForRace(englishRace)
    return not faction or faction == UnitFactionGroup("player")
end

local function isMailableAlt(char)
    return ns:IsPlayerRealm(char.realm)
        and (not char.faction or char.faction == UnitFactionGroup("player"))
end

local function isMailableBNetCharacter(game)
    return game.clientProgram == BNET_CLIENT_WOW
        and game.characterName and game.characterName ~= ""
        and (not WOW_PROJECT_ID or game.wowProjectID == WOW_PROJECT_ID)
        and game.factionName == UnitFactionGroup("player")
        -- Compare realm IDs rather than names, as Blizzard does.
        and game.realmID and game.realmID > 0 and game.realmID == GetRealmID()
end

local function addCandidate(list, seen, value, source, class)
    -- "Name-OurRealm" mails the same as "Name"; show the shorter form.
    -- Any other realm can't be mailed, so drop it (except names the user
    -- already chose as recipients).
    local name, realm = value:match("^(.-)%-([^%-]+)$")
    if name then
        if ns:IsPlayerRealm(realm) then
            value = name
        elseif source ~= "used" then
            return
        end
    end
    local key = value:lower()
    if seen[key] or ns:IsSelf(value) then return end
    seen[key] = true
    table.insert(list, { value = value, source = source, class = class })
end

-- Same source and filter Blizzard's SendMailNameEditBox uses (MailFrame.xml).
local function addGameAutoComplete(text, add)
    if text == "" or not (C_AutoComplete and C_AutoComplete.GetAutoCompleteResults) then return end
    local mail = AUTOCOMPLETE_LIST and AUTOCOMPLETE_LIST.MAIL
    local include = mail and mail.include or 0xffffffff
    local exclude = mail and mail.exclude or 8 -- Enum.AutoCompleteEntryFlag.Bnet
    local ok, results = pcall(C_AutoComplete.GetAutoCompleteResults, text, MAX_SUGGESTIONS, #text, true, include, exclude)
    if not ok or type(results) ~= "table" then return end

    local priorities = Enum and Enum.AutoCompletePriority
    for _, result in ipairs(results) do
        -- Account characters on other realms come back as AccountCharacter
        -- rather than AccountCharacterSameRealm; mail can't reach them.
        local otherRealmAlt = priorities and result.priority == priorities.AccountCharacter
        if result.name and result.name ~= "" and not otherRealmAlt then
            add(result.name, sourceForPriority(result.priority))
        end
    end
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

    for _, char in pairs(ns.db.characters) do
        if not isMailableAlt(char) then block(char.name) end
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

function ns:GetRecipientCandidates(text)
    local list, seen = {}, {}
    local blocked = collectBlocked()

    local function add(value, source, class)
        local bare = (value:match("^(.-)%-") or value):lower()
        if blocked[bare] and source ~= "used" then return end
        addCandidate(list, seen, value, source, class)
    end

    addGameAutoComplete(text or "", add)

    for _, char in pairs(self.db.characters) do
        add(char.name, "alt", char.class)
    end

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

    table.sort(list, function(a, b) return a.value:lower() < b.value:lower() end)
    return list
end

---------------------------------------------------------------------------
-- Dropdown
---------------------------------------------------------------------------

local dropdown
local activeBox
local matches = {}
local selected = 0

local function colorize(entry)
    local color = entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
    if color then
        return ("|cff%02x%02x%02x%s|r"):format(math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255), entry.value)
    end
    return entry.value
end

local function hide()
    if dropdown then dropdown:Hide() end
    activeBox = nil
    selected = 0
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

local function highlight(index)
    selected = index
    for i, row in ipairs(dropdown.rows) do
        row.selected:SetShown(i == index)
    end
end

local function createDropdown()
    dropdown = CreateFrame("Frame", "CraftCourierSuggestFrame", UIParent, "TooltipBackdropTemplate")
    dropdown:SetFrameStrata("TOOLTIP")
    dropdown:SetClampedToScreen(true)
    dropdown:Hide()
    dropdown.rows = {}

    for i = 1, MAX_SUGGESTIONS do
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

        row:SetScript("OnClick", function() accept(i) end)
        dropdown.rows[i] = row
    end
end

-- typing: true when called from user input, so the first match is
-- pre-selected and Enter/Tab picks it (like Blizzard's name boxes).
local function update(box, typing)
    local text = strtrim(box:GetText() or ""):lower()
    local exact = false
    wipe(matches)

    -- Prefix matches first, then substring matches.
    local candidates = ns:GetRecipientCandidates(strtrim(box:GetText() or ""))
    for pass = 1, 2 do
        for _, entry in ipairs(candidates) do
            local pos = entry.value:lower():find(text, 1, true)
            exact = exact or entry.value:lower() == text
            local wanted = (pass == 1 and pos == 1) or (pass == 2 and pos and pos > 1)
            if wanted and entry.value:lower() ~= text and #matches < MAX_SUGGESTIONS then
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
    for i, row in ipairs(dropdown.rows) do
        local entry = matches[i]
        if entry then
            row.name:SetText(colorize(entry))
            row.source:SetText(SOURCE_LABELS[entry.source])
            row:Show()
        else
            row:Hide()
        end
    end
    -- Don't pre-select when the text already names someone, so Enter keeps it.
    highlight((typing and text ~= "" and not exact) and 1 or 0)
    dropdown:ClearAllPoints()
    dropdown:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -6, 0)
    dropdown:SetSize(math.max(box:GetWidth() + 12, 280), #matches * ROW_HEIGHT + 12)
    dropdown:Show()
end

-- Adds suggestions to an EditBox. Arrow keys move, Tab/Enter accept, Escape closes.
function ns:AttachSuggestions(box)
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
    box:HookScript("OnTabPressed", function(self)
        if activeBox == self then accept(math.max(selected, 1)) end
    end)
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
