local _, ns = ...

-- Builds queued mails one at a time. The client only has one outgoing mail,
-- so each mail waits for MAIL_SEND_SUCCESS before the next is built.
--
-- Modes:
--   "auto"   - attach and send each mail without user input
--   "review" - attach and fill in the send form, then wait for the user to
--              press Send; the next batch is prepared after it succeeds

local Mailer = {}
ns.Mailer = Mailer

local MAX_ATTACHMENTS = ATTACHMENTS_MAX_SEND or 12
local SEND_DELAY = 0.3
local SEND_TIMEOUT = 15

local queue = {}
local current
local busy = false
local mode = "auto"
local sentCount, totalCount = 0, 0

function Mailer:IsBusy()
    return busy
end

function Mailer:GetMode()
    return mode
end

-- True while a reviewed mail is filled in and waiting for the user to send it.
function Mailer:IsAwaitingReview()
    return busy and mode == "review" and current ~= nil
end

function Mailer:GetProgress()
    return sentCount, totalCount
end

-- Queues mails for the given category keys. Categories that share a recipient
-- are packed into the same mails. Returns the number of mails queued.
function Mailer:Queue(keys)
    if busy then return 0 end
    local scan = ns:ScanBags()
    local byRecipient, order = {}, {}

    for _, key in ipairs(keys) do
        local recipient = ns:GetRecipient(key)
        local entry = scan[key]
        if recipient and entry and not ns:IsSelf(recipient) then
            local id = recipient:lower()
            local group = byRecipient[id]
            if not group then
                group = { recipient = recipient, labels = {}, stacks = {} }
                byRecipient[id] = group
                table.insert(order, group)
            end
            table.insert(group.labels, ns.categoryByKey[key].label)
            for _, stack in ipairs(entry.stacks) do
                table.insert(group.stacks, stack)
            end
        end
    end

    local queued = 0
    for _, group in ipairs(order) do
        local subject = "CraftCourier: " .. table.concat(group.labels, ", ")
        for i = 1, #group.stacks, MAX_ATTACHMENTS do
            local chunk = {}
            for j = i, math.min(i + MAX_ATTACHMENTS - 1, #group.stacks) do
                table.insert(chunk, group.stacks[j])
            end
            table.insert(queue, { recipient = group.recipient, subject = subject, stacks = chunk })
            queued = queued + 1
        end
    end
    return queued
end

function Mailer:Start(startMode)
    if busy or #queue == 0 then return end
    mode = startMode or "auto"
    busy = true
    sentCount, totalCount = 0, #queue
    ns:Fire("MAILER_STATE")
    self:SendNext()
end

-- clearForm releases attachments from a mail that was filled but not sent.
function Mailer:Stop(reason, clearForm)
    wipe(queue)
    if clearForm and current then
        ClearSendMail()
        if SendMailFrame_Reset then SendMailFrame_Reset() end
    end
    current = nil
    if busy then
        busy = false
        if reason then ns:Print(reason) end
        ns:Fire("MAILER_STATE")
    end
end

local function showSendTab()
    if SendMailFrame and not SendMailFrame:IsShown() and MailFrameTab_OnClick then
        MailFrameTab_OnClick(nil, 2)
    end
end

-- Attaches each stack that is still where we scanned it. Returns attachment count.
local function attachStacks(stacks)
    local attached = 0
    for _, stack in ipairs(stacks) do
        local info = ns.GetContainerItemInfo(stack.bag, stack.slot)
        if info and info.itemID == stack.itemID and not info.isLocked then
            ClearCursor()
            ns.PickupContainerItem(stack.bag, stack.slot)
            if CursorHasItem() then
                ClickSendMailItemButton(attached + 1)
                if CursorHasItem() then
                    -- Attachment refused (e.g. not mailable); put it back.
                    ClearCursor()
                else
                    attached = attached + 1
                end
            end
        end
    end
    return attached
end

function Mailer:SendNext()
    if not busy then return end
    if not (MailFrame and MailFrame:IsShown()) then
        self:Stop("Mailbox closed, stopped sending.")
        return
    end

    local job = table.remove(queue, 1)
    if not job then
        busy = false
        if sentCount > 0 then
            ns:Print(("Done. Sent %d mail(s)."):format(sentCount))
        end
        ns:Fire("MAILER_STATE")
        return
    end

    showSendTab()
    ClearSendMail()
    job.attached = attachStacks(job.stacks)
    if job.attached == 0 then
        totalCount = totalCount - 1
        self:SendNext()
        return
    end

    current = job
    ns:Fire("MAILER_STATE")

    if mode == "review" then
        -- Fill the form and leave sending to the user.
        SendMailNameEditBox:SetText(job.recipient)
        SendMailSubjectEditBox:SetText(job.subject)
        SendMailNameEditBox:ClearFocus()
        return
    end

    SendMail(job.recipient, job.subject, "")

    C_Timer.After(SEND_TIMEOUT, function()
        if current == job then
            self:Stop("Timed out waiting for the mail to send.")
        end
    end)
end

ns:RegisterEvent("MAIL_SEND_SUCCESS", function()
    if not current then return end
    sentCount = sentCount + 1
    ns:Print(("Sent %d stack(s) to %s."):format(current.attached, current.recipient))
    current = nil
    ns:Fire("MAILER_STATE")
    C_Timer.After(SEND_DELAY, function() Mailer:SendNext() end)
end)

ns:RegisterEvent("MAIL_FAILED", function()
    if not current then return end
    -- In review mode the user can fix the form and press Send again.
    if mode == "review" then return end
    ClearSendMail()
    Mailer:Stop("Mail to " .. current.recipient .. " failed, stopped sending.")
end)

ns:RegisterEvent("MAIL_CLOSED", function()
    Mailer:Stop(busy and "Mailbox closed, stopped sending." or nil)
end)
