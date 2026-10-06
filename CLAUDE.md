# CraftCourier

A World of Warcraft addon in Lua that mails crafting materials and unbound BoE gear to alts the user has assigned to each category. Users configure it in a settings window, and it acts from a panel docked to the mailbox.

## Target client

- **WoW Forever**, `## Interface: 16001`. The client is built on the modern (retail/mainline) codebase, so `C_Container`, `C_Item`, `Enum.ItemClass` and the mainline frame templates are all available.
- Use Blizzard's UI source on the `forever` branch as the reference: https://github.com/Gethe/wow-ui-source/tree/forever
  - Mail frame: `Interface/AddOns/Blizzard_MailFrame/MailFrame.lua`
  - API docs: `Interface/AddOns/Blizzard_APIDocumentationGenerated/`
  - Templates: `Interface/AddOns/Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml`
- Forever loads the **Camelot** variants of Blizzard files (`[AllowLoadGameType camelot]` in the TOCs). Where both a `Mainline/` and a `Camelot/` version of a file exist, read the `Camelot/` one.
- **Characters have surnames.** `UnitName(unit)` returns `name, surname`, not `name, realm` as the generated API docs say. A character's full name is `name .. CHARACTERNAME_SURNAME_SEPARATOR .. surname` (e.g. "Greeb Deez"), and that is what users type as a mail recipient. Use `ns:GetPlayerName()`, never `UnitName("player")` alone.
- Settings canvas frames (`Settings.RegisterCanvasLayoutCategory`) must start hidden, or `OnShow` never fires when Options displays them. Text set into an `EditBox` before it's laid out can render blank, so reload a frame later and call `SetCursorPosition(0)`.
- Before you use a global function, template or constant, check that it exists on that branch. Don't assume anything from retail or classic. If you can't confirm it, guard it (`if X then`) or avoid it.

## Layout

| File | Responsibility |
| --- | --- |
| `CraftCourier.toc` | Manifest; the load order is the file order |
| `package.sh` | Builds the release zip (see Releasing) |
| `Media/Icon.tga` | AddOns list icon (`## IconTexture`), 64×64 TGA rendered from `logo.svg` |
| `Core.lua` | `ns` setup, `CraftCourierDB` defaults, API shims, the event and message bus, `ns:GetPlayerName()` / `ns:IsSelf()`, slash commands (including `item` and `debug` for diagnostics) |
| `Categories.lua` | `ns.categories` (also sets the UI order), `ns:Classify`, `ns:ScanBags`, `ns:CategoryDisplayName`. BoE categories have a `quality` field. `Classify` checks for BoE (`bindType == Enum.ItemBind.OnEquip`) before trade goods. |
| `Mailer.lua` | `ns.Mailer` queue: `Queue(keys)`, `Start(mode)` where `mode` is `"auto"` or `"review"`, `Stop(reason, clearForm)` |
| `Log.lua` | Hooks `SendMail` to read the attachments while the Mailer is busy, then commits the entry on `MAIL_SEND_SUCCESS` (and drops it on `MAIL_FAILED`). Capped at 1000 entries. |
| `UI/LogWindow.lua` | Log window (`ns:ToggleLog()`), a `WowScrollBoxList` with a filter |
| `UI/MailPanel.lua` | Mailbox panel, rebuilt by `ns:RefreshMailPanel()` |
| `UI/Suggest.lua` | Recipient suggestions: `ns:GetRecipientCandidates(text)`, `ns:AttachSuggestions(editBox)`. Sources: `C_AutoComplete.GetAutoCompleteResults` with `AUTOCOMPLETE_LIST.MAIL` (the same as Blizzard's mail box), recorded alts, existing recipients, friends list, Battle.net. `collectBlocked()` hides characters known to be on another realm or faction (friends via GUID server ID and race, Battle.net via `realmID` and `factionName`, as Blizzard's Camelot FriendsFrame does). |
| `UI/Config.lua` | One recipient form (`buildForm`) used in two places: a canvas page in Options → AddOns (`ns:OpenSettingsPanel()`), and a small window (`ns:ToggleConfig()`, used by the slash command and the mailbox panel). Both reload on `CONFIG_CHANGED`. |

## Conventions

- All addon state lives on the private namespace `ns` (`local _, ns = ...`). The only globals are `CraftCourierDB`, the `SLASH_CRAFTCOURIER*` slash command entries and the named frames.
- Register for game events with `ns:RegisterEvent(event, fn)`. Several modules can listen to the same event.
- Internal messages use `ns:On(msg, fn)` and `ns:Fire(msg, ...)`. The current messages are `READY`, `CONFIG_CHANGED`, `MAILER_STATE` and `LOG_UPDATED`.
- Call WoW APIs through the shims in `Core.lua` (`ns.GetContainerItemInfo`, `ns.PickupContainerItem` and so on), not directly.
- `ns.db` is only valid after `ADDON_LOADED`, so don't touch it when a file loads.
- Style: 4-space indent, `local` everything, short comments that explain *why*.

## Mailing rules (don't break these)

- The client has a single outgoing mail. The Mailer sends one mail, then waits for `MAIL_SEND_SUCCESS` before building the next. On `MAIL_FAILED`, `MAIL_CLOSED` or a timeout it calls `Stop`.
- Review mode fills `SendMailNameEditBox` and `SendMailSubjectEditBox` but never calls `SendMail`. It moves to the next batch only on `MAIL_SEND_SUCCESS`, and ignores `MAIL_FAILED` so the user can retry.
- A mail holds at most `ATTACHMENTS_MAX_SEND` (12) attachments.
- Before attaching a stack, check that its bag slot still holds the scanned `itemID` and isn't locked.
- Never send to the logged-in character (`ns:IsSelf`), and don't show mailbox rows for categories assigned to it. Skip bound items.
- `Queue` refuses to run while the Mailer is busy, so a stack can't be queued twice.

## Saved variables (`CraftCourierDB`)

```lua
recipients = { [categoryKey] = "Name" | "Name-Realm" }
overrides  = { [itemID] = categoryKey | "ignore" }
characters = { ["Name Surname-Realm"] = { name, realm, class, faction } } -- recorded on PLAYER_LOGIN; name includes the surname
log        = { { time, from, realm, to, mode, items = { {id, name, icon, count} } } } -- oldest first
showPanel  = true
```

If you change this shape, add a migration in the `ADDON_LOADED` handler in `Core.lua`.

## Testing

There are no automated tests. Test in game:

1. Copy or symlink the repo into `Interface/AddOns/CraftCourier`, then run `/reload` after each change. Adding or renaming a file in the TOC needs a full game restart, not just `/reload`.
2. Turn on Lua errors with `/console scriptErrors 1`, or use BugSack.
3. Open a mailbox carrying several material types, more than 12 stacks of at least one of them, and a soulbound item. Check the counts, tooltips, chunking, Send All grouping, and that closing the mailbox mid-send stops cleanly.

## Releasing

- `./package.sh [version]` builds `.release/CraftCourier-<version>.zip`, with the version taken from `## Version:` in the TOC by default. When you add a new top-level file or folder that the addon loads, add it to `package.sh` too.
- Bump `## Version:` in `CraftCourier.toc` for each release.

## Docs

- `README.md`: for developers and GitHub readers.
- `CURSE.md`: the CurseForge project page, written for players. Keep it in sync when you add features.
- `.github/ISSUE_TEMPLATE/`: issue forms for missing categories, items not picked up and items in the wrong category. They ask for `/ccr item` output, so keep that command's output stable.
