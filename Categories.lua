local _, ns = ...

local TRADEGOODS = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or 7
local METAL_AND_STONE = 7

-- Display order matters: it is the order rows appear in the UI.
ns.categories = {
    { key = "cloth",       label = "Cloth",       icon = "Interface\\Icons\\INV_Fabric_Linen_01" },
    { key = "leather",     label = "Leather",     icon = "Interface\\Icons\\INV_Misc_LeatherScrap_03" },
    { key = "herbs",       label = "Herbs",       icon = "Interface\\Icons\\INV_Misc_Herb_07" },
    { key = "ore",         label = "Ore",         icon = "Interface\\Icons\\INV_Ore_Copper_01" },
    { key = "bars",        label = "Bars",        icon = "Interface\\Icons\\INV_Ingot_02" },
    { key = "stone",       label = "Stone",       icon = "Interface\\Icons\\INV_Stone_15" },
    { key = "gems",        label = "Gems",        icon = "Interface\\Icons\\INV_Misc_Gem_01" },
    { key = "enchanting",  label = "Enchanting",  icon = "Interface\\Icons\\INV_Enchant_DustArcane" },
    { key = "elemental",   label = "Elemental",   icon = "Interface\\Icons\\INV_Elemental_Primal_Fire" },
    { key = "cooking",     label = "Cooking",     icon = "Interface\\Icons\\INV_Misc_Food_15" },
    { key = "parts",       label = "Parts",       icon = "Interface\\Icons\\INV_Misc_Gear_01" },
    { key = "other",       label = "Other Trade Goods", icon = "Interface\\Icons\\INV_Misc_Bag_10" },

    -- Unbound Bind on Equip items, one category per quality.
    { key = "boe_uncommon",  label = "BoE Uncommon",  icon = "Interface\\Icons\\INV_Sword_04", quality = 2 },
    { key = "boe_rare",      label = "BoE Rare",      icon = "Interface\\Icons\\INV_Sword_04", quality = 3 },
    { key = "boe_epic",      label = "BoE Epic",      icon = "Interface\\Icons\\INV_Sword_04", quality = 4 },
}

ns.categoryByKey = {}
local boeByQuality = {}
for _, cat in ipairs(ns.categories) do
    ns.categoryByKey[cat.key] = cat
    if cat.quality then
        boeByQuality[cat.quality] = cat.key
    end
end

local BIND_ON_EQUIP = (Enum and Enum.ItemBind and Enum.ItemBind.OnEquip) or 2
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor

-- Category label for the UI, coloured by item quality for BoE categories.
-- (Mail subjects use the plain cat.label.)
function ns:CategoryDisplayName(cat)
    if cat.quality and GetItemQualityColor then
        local r, g, b = GetItemQualityColor(cat.quality)
        if r then
            return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), cat.label)
        end
    end
    return cat.label
end

-- Trade Goods subclass ID -> category key. Metal & Stone (7) is split by name below.
local subclassMap = {
    [1] = "parts",
    [4] = "gems",
    [5] = "cloth",
    [6] = "leather",
    [8] = "cooking",
    [9] = "herbs",
    [10] = "elemental",
    [12] = "enchanting",
}

-- Accepts a key or a label, case-insensitive.
function ns:FindCategory(text)
    if not text then return nil end
    text = text:lower()
    for _, cat in ipairs(self.categories) do
        if cat.key == text or cat.label:lower() == text then
            return cat
        end
    end
end

-- The client has no ore/bar/stone split, so this relies on English item names.
-- Anything that doesn't match can be fixed with /craftcourier assign.
local function splitMetalAndStone(name)
    if not name then return "stone" end
    if name:find("Ore") then return "ore" end
    if name:find("Bar") or name:find("Ingot") then return "bars" end
    return "stone"
end

-- Returns the BoE category key for an unbound Bind on Equip item, else nil.
-- Item info may not be cached yet; GET_ITEM_INFO_RECEIVED triggers a rescan.
local function classifyBoE(itemID, quality)
    local _, _, itemQuality, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(itemID)
    if bindType ~= BIND_ON_EQUIP then return nil end
    return boeByQuality[quality or itemQuality]
end

-- Returns the category key for an item, or nil if CraftCourier should not mail it.
-- `quality` comes from the bag slot; bound items never reach this.
function ns:Classify(itemID, name, quality)
    local override = self.db.overrides[itemID]
    if override then
        if override == "ignore" then return nil end
        return override
    end

    local boe = classifyBoE(itemID, quality)
    if boe then return boe end

    local _, _, _, _, _, classID, subclassID = self.GetItemInfoInstant(itemID)
    if classID ~= TRADEGOODS then return nil end

    if subclassID == METAL_AND_STONE then
        return splitMetalAndStone(name)
    end
    return subclassMap[subclassID] or "other"
end

-- Scans bags and groups mailable crafting materials by category.
-- Returns { [key] = { total = n, stacks = { {bag, slot, itemID, count} }, items = { [itemID] = {name, count, icon} } } }
function ns:ScanBags()
    local result = {}
    for bag = 0, self.LAST_BAG do
        for slot = 1, self.GetContainerNumSlots(bag) or 0 do
            local info = self.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isBound then
                local name = info.hyperlink and info.hyperlink:match("%[(.-)%]")
                local key = self:Classify(info.itemID, name, info.quality)
                if key then
                    local entry = result[key]
                    if not entry then
                        entry = { total = 0, stacks = {}, items = {} }
                        result[key] = entry
                    end
                    local count = info.stackCount or 1
                    entry.total = entry.total + count
                    table.insert(entry.stacks, { bag = bag, slot = slot, itemID = info.itemID, count = count })
                    local item = entry.items[info.itemID]
                    if not item then
                        item = { name = name or ("item:" .. info.itemID), count = 0, icon = info.iconFileID }
                        entry.items[info.itemID] = item
                    end
                    item.count = item.count + count
                end
            end
        end
    end
    return result
end
