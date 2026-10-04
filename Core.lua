local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

local defaults = {
    recipients = {}, -- [categoryKey] = "Name" or "Name-Realm"
    overrides = {},  -- [itemID] = categoryKey or "ignore"
    characters = {}, -- ["Name-Realm"] = { name, realm, class, faction }; every alt seen with the addon
    log = {},        -- sent mails, oldest first: { time, from, realm, to, mode, items = { {id, name, icon, count} } }
    showPanel = true,
}

function ns:Print(...)
    print("|cff33ff99CraftCourier|r:", ...)
end

---------------------------------------------------------------------------
-- API compatibility (retail C_Container vs. older globals)
---------------------------------------------------------------------------

ns.GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
ns.PickupContainerItem = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
ns.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

if C_Container and C_Container.GetContainerItemInfo then
    ns.GetContainerItemInfo = C_Container.GetContainerItemInfo
else
    function ns.GetContainerItemInfo(bag, slot)
        local icon, count, locked, _, _, _, link, _, _, itemID, isBound = GetContainerItemInfo(bag, slot)
        if not icon then return nil end
        return {
            iconFileID = icon,
            stackCount = count,
            isLocked = locked,
            hyperlink = link,
            itemID = itemID,
            isBound = isBound,
        }
    end
end

-- Backpack (0) through the last equipped bag; includes the reagent bag on retail.
ns.LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

---------------------------------------------------------------------------
-- Events and internal messages
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}
local messageHandlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(eventHandlers[event]) do
        fn(event, ...)
    end
end)

function ns:RegisterEvent(event, fn)
    if not eventHandlers[event] then
        eventHandlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(eventHandlers[event], fn)
end

function ns:On(message, fn)
    messageHandlers[message] = messageHandlers[message] or {}
    table.insert(messageHandlers[message], fn)
end

function ns:Fire(message, ...)
    for _, fn in ipairs(messageHandlers[message] or {}) do
        fn(...)
    end
end

ns:RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then return end
    CraftCourierDB = CraftCourierDB or {}
    for k, v in pairs(defaults) do
        if CraftCourierDB[k] == nil then
            CraftCourierDB[k] = type(v) == "table" and CopyTable(v) or v
        end
    end
    ns.db = CraftCourierDB
    ns:Fire("READY")
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function ns:GetPlayerRealm()
    return (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName():gsub("[%s%-]", ""))
end

local function normalizeRealm(realm)
    return (realm:gsub("[%s%-']", "")):lower()
end

-- Same realm as the logged-in character, ignoring spaces/case.
function ns:IsPlayerRealm(realm)
    return realm == nil or realm == "" or normalizeRealm(realm) == normalizeRealm(self:GetPlayerRealm())
end

-- WoW Forever characters have a surname: UnitName returns (name, surname),
-- and the game joins them with CHARACTERNAME_SURNAME_SEPARATOR, as in
-- Blizzard_FrameXMLUtil/Camelot/NameUtil.lua.
function ns:GetPlayerName()
    local name, surname = UnitName("player")
    if not name then return nil end
    if surname and surname ~= "" then
        local consts = Constants and Constants.CharacterNameSeparatorConsts
        local separator = (consts and consts.CHARACTERNAME_SURNAME_SEPARATOR) or " "
        return name .. separator .. surname, name, surname
    end
    return name, name, nil
end

-- Remember this character so it can be suggested as a recipient on alts.
ns:RegisterEvent("PLAYER_LOGIN", function()
    local fullName, firstName = ns:GetPlayerName()
    local realm = ns:GetPlayerRealm()
    if not fullName or not realm then return end
    -- Drop the entry older versions saved under the first name only.
    if firstName ~= fullName then
        ns.db.characters[firstName .. "-" .. realm] = nil
    end
    local _, class = UnitClass("player")
    ns.db.characters[fullName .. "-" .. realm] = {
        name = fullName,
        realm = realm,
        class = class,
        faction = UnitFactionGroup("player"),
    }
end)

-- Lowercase with spaces, hyphens and apostrophes removed, so "Name-Realm",
-- "Name - Realm", "Name Realm" and "NameRealm" all compare equal.
local function squash(text)
    return (strtrim(text):gsub("[%s%-']", "")):lower()
end

-- True if the recipient string refers to the character currently logged in,
-- written either as the bare name or with the realm in any common form.
function ns:IsSelf(recipient)
    if not recipient or recipient == "" then return false end
    local name = self:GetPlayerName()
    if not name then return false end
    local target = squash(recipient)
    return target == squash(name) or target == squash(name .. self:GetPlayerRealm())
end

function ns:GetRecipient(key)
    local r = self.db.recipients[key]
    if r and r ~= "" then return r end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function printHelp()
    ns:Print("commands:")
    print("  /craftcourier  - open the settings window")
    print("  /craftcourier set <category> <Name Surname[-Realm]>")
    print("  /craftcourier clear <category>")
    print("  /craftcourier log  - show the send log")
    print("  /craftcourier list")
    print("  /craftcourier categories")
    print("  /craftcourier assign <item link> <category|ignore>")
    print("  /craftcourier unassign <item link>")
    print("  /craftcourier item <item link>  - show how an item is categorised")
    print("  /craftcourier debug  - show who CraftCourier thinks you are")
end

local commands = {}

function commands.set(rest)
    -- The recipient may contain a space: Forever names include a surname.
    local catName, recipient = rest:match("^(%S+)%s+(.-)%s*$")
    local cat = catName and ns:FindCategory(catName)
    if not cat or recipient == "" then
        ns:Print("usage: /craftcourier set <category> <Name Surname[-Realm]>")
        return
    end
    ns.db.recipients[cat.key] = recipient
    ns:Print(cat.label, "->", recipient)
    ns:Fire("CONFIG_CHANGED")
end

function commands.clear(rest)
    local cat = ns:FindCategory(rest)
    if not cat then
        ns:Print("unknown category:", rest)
        return
    end
    ns.db.recipients[cat.key] = nil
    ns:Print(cat.label, "recipient cleared")
    ns:Fire("CONFIG_CHANGED")
end

function commands.debug()
    local fullName, firstName, surname = ns:GetPlayerName()
    ns:Print(("you are '%s' (name '%s', surname '%s') on realm '%s'"):format(
        tostring(fullName), tostring(firstName), tostring(surname), tostring(ns:GetPlayerRealm())))
    local candidates = ns:GetRecipientCandidates("")
    local names = {}
    for i = 1, math.min(#candidates, 10) do
        names[i] = candidates[i].value .. " (" .. candidates[i].source .. ")"
    end
    ns:Print(("%d saved suggestion(s): %s"):format(#candidates, table.concat(names, ", ")))
    for _, cat in ipairs(ns.categories) do
        local recipient = ns:GetRecipient(cat.key)
        if recipient then
            print(("  %s: '%s'%s"):format(cat.label, recipient, ns:IsSelf(recipient) and " |cff33ff99(this character)|r" or ""))
        end
    end
end

-- Prints what CraftCourier knows about an item, for bug reports.
function commands.item(rest)
    local itemID = tonumber(rest:match("item:(%d+)")) or tonumber(rest)
    if not itemID then
        ns:Print("usage: /craftcourier item <item link or ID>")
        return
    end
    local _, itemType, itemSubType, _, _, classID, subclassID = ns.GetItemInfoInstant(itemID)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, _, quality, _, _, _, _, _, _, _, _, _, _, bindType = getInfo(itemID)
    if not classID then
        ns:Print("unknown item", itemID)
        return
    end
    local key = ns:Classify(itemID, name, quality)
    local cat = key and ns.categoryByKey[key]
    ns:Print(("item %d [%s] class %s/%s (%s/%s) quality %s bind %s override %s -> %s"):format(
        itemID, tostring(name or "not cached, try again"),
        tostring(classID), tostring(subclassID), tostring(itemType), tostring(itemSubType),
        tostring(quality), tostring(bindType), tostring(ns.db.overrides[itemID] or "none"),
        cat and cat.label or "not sent"))
end

function commands.log()
    ns:ToggleLog()
end

function commands.list()
    for _, cat in ipairs(ns.categories) do
        print(("  %s: %s"):format(cat.label, ns:GetRecipient(cat.key) or "|cff888888(none)|r"))
    end
end

function commands.categories()
    local keys = {}
    for _, cat in ipairs(ns.categories) do
        table.insert(keys, cat.key)
    end
    ns:Print("categories:", table.concat(keys, ", "))
end

function commands.assign(rest)
    local itemID = tonumber(rest:match("item:(%d+)"))
    local target = rest:match("(%S+)%s*$")
    if not itemID or not target then
        ns:Print("usage: /craftcourier assign <item link> <category|ignore>")
        return
    end
    if target:lower() == "ignore" then
        ns.db.overrides[itemID] = "ignore"
        ns:Print("item", itemID, "will be ignored")
    else
        local cat = ns:FindCategory(target)
        if not cat then
            ns:Print("unknown category:", target)
            return
        end
        ns.db.overrides[itemID] = cat.key
        ns:Print("item", itemID, "->", cat.label)
    end
    ns:Fire("CONFIG_CHANGED")
end

function commands.unassign(rest)
    local itemID = tonumber(rest:match("item:(%d+)"))
    if not itemID then
        ns:Print("usage: /craftcourier unassign <item link>")
        return
    end
    ns.db.overrides[itemID] = nil
    ns:Print("override removed for item", itemID)
    ns:Fire("CONFIG_CHANGED")
end

SLASH_CRAFTCOURIER1 = "/craftcourier"
SLASH_CRAFTCOURIER2 = "/ccr"
SlashCmdList.CRAFTCOURIER = function(msg)
    msg = strtrim(msg or "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "config" or cmd == "options" then
        ns:ToggleConfig()
    elseif commands[cmd] then
        commands[cmd](rest)
    else
        printHelp()
    end
end
