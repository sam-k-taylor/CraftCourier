local _, ns = ...

-- Records every mail CraftCourier sends: when, from which character, to whom,
-- and what was attached. Contents are read when SendMail is called (so review
-- mode logs what the user actually sent) and committed on MAIL_SEND_SUCCESS.

local MAX_ENTRIES = 1000
local MAX_ATTACHMENTS = ATTACHMENTS_MAX_SEND or 12

local pending

local function readAttachments()
    local items, byID = {}, {}
    for i = 1, MAX_ATTACHMENTS do
        local name, itemID, icon, count = GetSendMailItem(i)
        if itemID then
            local item = byID[itemID]
            if not item then
                item = { id = itemID, name = name, icon = icon, count = 0 }
                byID[itemID] = item
                table.insert(items, item)
            end
            item.count = item.count + (count or 1)
        end
    end
    return items
end

-- SendMail is called by our Mailer (auto mode) and by Blizzard's Send button
-- (review mode). Only mails sent while the Mailer is running are logged.
hooksecurefunc("SendMail", function(recipient)
    if not (ns.db and ns.Mailer:IsBusy()) then return end
    local items = readAttachments()
    if #items == 0 then return end
    local from = ns:GetPlayerName()
    pending = {
        time = time(),
        from = from,
        realm = ns:GetPlayerRealm(),
        to = recipient,
        mode = ns.Mailer:GetMode(),
        items = items,
    }
end)

ns:RegisterEvent("MAIL_SEND_SUCCESS", function()
    if not pending then return end
    local log = ns.db.log
    table.insert(log, pending)
    pending = nil
    while #log > MAX_ENTRIES do
        table.remove(log, 1)
    end
    ns:Fire("LOG_UPDATED")
end)

ns:RegisterEvent("MAIL_FAILED", function()
    pending = nil
end)

function ns:ClearLog()
    wipe(self.db.log)
    self:Fire("LOG_UPDATED")
end
