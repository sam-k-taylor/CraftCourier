# CraftCourier

A World of Warcraft addon in Lua that mails crafting materials and unbound BoE gear to alts the user has assigned to each category. It extends Blizzard's mailbox: double width, a scrolling inbox with a summary, the send panel in the Send Mail tab, and a Settings tab.

## Target client

- **WoW Forever**, `## Interface: 16001`. The client is built on the modern (retail/mainline) codebase, so `C_Container`, `C_Item`, `Enum.ItemClass` and the mainline frame templates are all available.
- Use Blizzard's UI source on the `forever` branch as the reference: https://github.com/Gethe/wow-ui-source/tree/forever
  - Mail frame: `Interface/AddOns/Blizzard_MailFrame/MailFrame.lua`
  - API docs: `Interface/AddOns/Blizzard_APIDocumentationGenerated/`
  - Templates: `Interface/AddOns/Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml`
- Forever loads the **Camelot** variants of Blizzard files (`[AllowLoadGameType camelot]` in the TOCs). Where both a `Mainline/` and a `Camelot/` version of a file exist, read the `Camelot/` one.
- **Characters have surnames.** `UnitName(unit)` returns `name, surname`, not `name, realm` as the generated API docs say. A character's full name is `name .. CHARACTERNAME_SURNAME_SEPARATOR .. surname` (e.g. "Greeb Deez"), and that is what users type as a mail recipient. Use `ns:GetPlayerName()`, never `UnitName("player")` alone.
- **Realms are shards of a ruleset.** Realm names look like `CAMWOWEU4Realm1PvE`; the suffix is the ruleset (PvE, PvP, RPPvE, RPPvP) and everyone on one ruleset shares a world and can mail each other, whatever the realm. Compare worlds with `ns:IsSameWorld(realm)` / `ns:WorldKey(realm)`, never realm names or `GetRealmID()`. The client can also report no realm at all (`GetNormalizedRealmName()` returns `""`, `GetRealmID()` returns 0); treat that as unknown, not as a different realm.
- Settings canvas frames (`Settings.RegisterCanvasLayoutCategory`) must start hidden, or `OnShow` never fires when Options displays them. Text set into an `EditBox` before it's laid out can render blank, so reload a frame later and call `SetCursorPosition(0)`.
- Before you use a global function, template or constant, check that it exists on that branch. Don't assume anything from retail or classic. If you can't confirm it, guard it (`if X then`) or avoid it.

## Layout

| File | Responsibility |
| --- | --- |
| `CraftCourier.toc` | Manifest; the load order is the file order |
| `package.sh` | Builds the release zip (see Releasing) |
| `Media/Icon.tga` | AddOns list icon (`## IconTexture`), 64×64 TGA rendered from `logo.svg` |
| `Media/TabEdge.tga` | 8×16 white line with soft top and bottom edges, tinted for the tab outlines (`Style.SkinTabs`) |
| `Core.lua` | `ns` setup, `CraftCourierDB` defaults, API shims, the event and message bus, `ns:GetPlayerName()` / `ns:IsSelf()` / `ns:FindCharacter()` (the recorded alt a recipient string names), slash commands (including `item` and `debug` for diagnostics) |
| `Categories.lua` | `ns.categories` (also sets the UI order; built-ins first, then the user's custom categories from `db.customCategories`, `custom = true`. `ns:RebuildCategories()` refills `ns.categories` and `ns.categoryByKey` in place, so never cache a copy. `ns:AddCustomCategory` / `RenameCustomCategory` / `DeleteCustomCategory` fire `CATEGORIES_CHANGED` then `CONFIG_CHANGED`; delete also drops the category's recipient and overrides. Labels must be unique, see `ns:ValidateCategoryLabel`. Items only reach a custom category through an override. Every category has a `section` (`materials`, `professions` for plans and Comprehension Scrolls, `gear` for BoE, `custom`); `ns.categorySections` gives the headings and their order, and `ns:CategoriesBySection()` groups categories under them), `ns:Classify`, `ns:ScanBags`, `ns:CategoryDisplayName`. BoE categories have a `quality` field. `Classify` applies `db.overrides`, then `ns:DefaultCategory` (the built-in rules). It checks for BoE (`bindType == Enum.ItemBind.OnEquip`) before trade goods. Consumable / Scroll items (class 0/4) go to `scrolls` (Comprehension Scrolls) if named "Scroll: …" (the undeciphered drops) or if their tooltip has the Mage-only `ITEM_CLASSES_ALLOWED` line or "Requires Comprehension" (`ITEM_MIN_SKILL`) (`C_TooltipInfo.GetItemByID`; only hits are cached). Recipe-class items (class 9) go to `plans_<profession>` by `Enum.ItemRecipeSubclass` (`recipeSubclassMap`), checked before BoE; Book/Fishing are skipped. Identified Waylaid Crates (`waylaidCrates`, by itemID, checked first after overrides) go to the category of their fill materials. Vendor reagents (vials, flux, thread…) go to a `plans_*` category, and dyes to `dyes`, via `professionSupplies`, also by itemID. Both tables may give a list of keys; `pickCategory` takes the first with a recipient. Other consumables are skipped. With `db.keepFirstAidCloth`, `ScanBags` leaves out the cloth for the character's current First Aid bracket and every higher one (`ns:FirstAidClothKept()` returns a set of itemIDs; skill line 129 via `C_SkillInfo`). Brackets: Linen <81, Wool <151, Silk <211, Mageweave <261, Runecloth <300. |
| `Mailer.lua` | `ns.Mailer` queue: `Queue(keys)`, `Start(mode)` where `mode` is `"auto"` or `"review"`, `Stop(reason, clearForm)`. Plays the send and finish sounds; when a run completes it fires `MAILER_FINISHED(sent, alts)` (`ns:SentSummary` words it). |
| `Log.lua` | Hooks `SendMail` to read the attachments while the Mailer is busy, then commits the entry on `MAIL_SEND_SUCCESS` (and drops it on `MAIL_FAILED`). Capped at 1000 entries. |
| `UI/Style.lua` | `ns.Style`, the shared look, in four window styles chosen by `db.windowStyle` (`THEMES`: `satchel` default, `letter`, `flat`, `blizzard`). Loads before the other UI files. Everything is drawn from tintable textures (tooltip border, `WHITE8X8`, the portrait mask), so styles need no image files. Every skinned piece calls `Style.Register(apply, scope)`; `Style.SetTheme(key)` reruns them all live and fires `STYLE_CHANGED` (lists redraw rows whose text embeds colour codes). Scope `"blizzard"` keeps the Blizzard palette on backgrounds we don't restyle (Options → AddOns page, tooltips). Blizzard's widgets are skinned without touching their tables: art faded with `SetAlpha` (never `Hide`), our backgrounds on separate `Backing` frames behind them, text recoloured with `TextAll` (which restores the original colour for the Blizzard style). `SkinBlizzardWindow` does this for a `ButtonFrameTemplate` window (mirrors `SetTitle`, our close button clicks theirs); In the custom styles the window border is drawn, not a backdrop: `buildChrome` fills the background exactly to the outline (bands plus quarter circles of the portrait mask in the corners) and traces the outer and inner border lines as one path of `CreateLine`s with `Media/TabEdge.tga` (soft-edged, so curves and slants don't stair-step), sizes from `outlineGeometry(t)`. `SkinTabs(edge, tabs)` draws tapered Filofax tabs (own art frames on `edge`: a cap and a body narrowed at the bottom with `SetVertexOffset`) and tells the window's chrome (`windowChromes[edge]:SetTab`) which tab is selected, so the window's outline dips round it and its inner line stops at it; unselected tabs, behind the window, get their own outline; the selected tab above the window in its colour, its cap covering the window's bottom border, the rest below the window; tab buttons raised above the art), restores Blizzard's saved anchors and heights for the Blizzard style, and re-lays out after `PanelTemplates_SelectTab`/`DeselectTab` and the tabs' `OnShow`/`OnHide`; buttons and tabs keep their own font objects, recoloured (copies made per style and base font), so Blizzard's narrow buttons don't wrap; `SkinArea` puts an input-coloured box behind a region. Helpers: `CreateWindow` (custom chrome with a wax-seal or X close button, plus a `ButtonFrameTemplate` child shown for the Blizzard style; content goes in `frame.body`; `opts.onClose`), `Panel`, `Text(fs, role)`, `Colorize`, `Heading`, `Divider`, `DecorateRow` / `SetRowStripe`, `Button` / `SkinButton` (over `UIPanelButtonTemplate`), `SkinEditBox` (over `InputBoxTemplate`; set `box.ccKeepColor` to colour the text yourself), `ProgressBar`, `Dropdown`, `IconButton`, `ClassColor` / `SetClassIcon` / `ClassIconMarkup` / `ColorName` (Letter shows a class icon instead of class-coloured text, which doesn't read on parchment), `Logo`, `Green`, `PlaySound`. Use these rather than raw templates or colours. |
| `UI/LogWindow.lua` | Log window (`ns:ToggleLog()`), a `WowScrollBoxList` with a filter, class-coloured From/To and item icons ("+N" past what fits) |
| `UI/MailSkin.lua` | `ns:SkinMailFrame()` (called once from `UI/Mailbox.lua`): restyles Blizzard's `MailFrame` and tabs, the paged inbox (`MailItem1..7`, recoloured after `InboxFrame:Update`), the Send Mail form (address boxes, stationery, money box, buttons) and `OpenMailFrame` (stationery, body text, invoice text, buttons) through `ns.Style`. |
| `UI/Mailbox.lua` | Extends `MailFrame` when `db.extendMailbox` is on: doubles its width, pins `SendMailFrame` to the original width, adds a Settings tab (hooks `MailFrameTab_OnClick`, never writes `MailFrame.activeSubFrame`). `ns:ShowSettings()`. Turning it off restores Blizzard's layout. |
| `UI/Inbox.lua` | `ns:SetInboxExtended(on)`: summary and one `WowScrollBoxList` of every mail inside `InboxFrame`. Blizzard's paged widgets are reparented to a hidden frame (its code keeps calling `Show` on them). Refreshes from a hook on `InboxFrame:Update`; opening a mail goes through `InboxFrame_OnClick`. |
| `UI/MailPanel.lua` | Send panel, rebuilt by `ns:RefreshMailPanel()`. A progress bar shows "Mail 3 of 8" while sending, then the green summary from `MAILER_FINISHED` for a few seconds. `ns:PlaceMailPanel(extended)` records the mode; `place()` (rerun from `OnShow`/`OnHide` hooks on `InboxFrame`, `SendMailFrame` and `OpenMailFrame`) puts it in the right half of the Send Mail tab when extended, otherwise in the docked `CraftCourierMailPanel` window. Docked shows if `db.showPanel`, not on the extended Settings tab, and not while a letter is open (the letter opens where it sits). |
| `UI/Suggest.lua` | Recipient suggestions: `ns:GetRecipientCandidates(text)`, `ns:AttachSuggestions(editBox, opts)` (`opts.excludeSelf`), `ns:AttachMailSuggestions()` (called from `UI/Mailbox.lua`: replaces Blizzard's autocomplete on `SendMailNameEditBox` by clearing its `autoCompleteSource`; `UI/MailSkin.lua` colours that box and adds a class icon for recorded alts). Sources: `C_AutoComplete.GetAutoCompleteResults` with `AUTOCOMPLETE_LIST.MAIL` (the same as Blizzard's mail box), recorded alts, existing recipients, friends list, Battle.net. `collectBlocked()` hides characters known to be on another ruleset or faction (alts via their recorded realm, friends via `GetPlayerInfoByGUID` realm and race, Battle.net via `realmName` and `factionName`). The game's `AccountCharacterSameRealm` results are always shown. `ns:DebugSuggestions(text)` backs `/ccr debug <name>`. |
| `UI/Filters.lua` | Item filters window (`ns:ToggleFilters()`, `ns:ShowFilters(itemID)`, `/ccr filters [item]`, and an Item Filters button on each settings host) for editing `db.overrides`. An item slot at the top (click for a picker of the unbound items in the bags, or drop an item on it), a category dropdown (`WowStyle1DropdownTemplate` from `Blizzard_Menu`, with a context-menu fallback) whose first entry, Default, removes the override, and an Ignore tick box. In the middle, custom categories: add (takes the selected item's icon), click to rename, X twice to delete. At the bottom, a `WowScrollBoxList` of every override; click to edit, X to remove. Shows the built-in category from `ns:DefaultCategory`. |
| `UI/Config.lua` | One recipient form (`buildForm`; `form:Layout()` lays it out as a clickable, collapsible heading per section from `ns:CategoriesBySection()` (state in `db.collapsedSections`, shared by all three forms), its rows (an empty Custom section shows a hint), then a Mailbox heading with the `TOGGLES` and the Window style dropdown. `opts.scope` = `"blizzard"` on the Options page. Each box shows the class icon and colour of the alt it names; it creates or reuses rows and reruns on `CATEGORIES_CHANGED`. `formHeight()` must match it, exposed as `ns:BuildConfigForm`, optionally in columns, and scrolling in a `ScrollFrameTemplate` when `opts.bottom` is set, since the category list is taller than its hosts) used in three places: the mailbox Settings tab, a canvas page in Options → AddOns (`ns:OpenSettingsPanel()`), and a small window (`ns:ToggleConfig()`, used by the slash command and the docked panel). All reload on `CONFIG_CHANGED`. |

## Conventions

- All addon state lives on the private namespace `ns` (`local _, ns = ...`). The only globals are `CraftCourierDB`, the `SLASH_CRAFTCOURIER*` slash command entries and the named frames.
- Register for game events with `ns:RegisterEvent(event, fn)`. Several modules can listen to the same event.
- Internal messages use `ns:On(msg, fn)` and `ns:Fire(msg, ...)`. The current messages are `READY`, `CATEGORIES_CHANGED` (a custom category was added, renamed or deleted; the recipient forms re-lay out their rows), `CONFIG_CHANGED`, `STYLE_CHANGED` (the window style changed), `MAILER_STATE`, `MAILER_FINISHED` and `LOG_UPDATED`.
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
customCategories = { { key = "custom_<n>", label, icon } } -- display order; icon is a path or file ID
characters = { ["Name Surname-<ruleset>"] = { name, realm, class, faction } } -- recorded on PLAYER_LOGIN/PLAYER_ENTERING_WORLD; key is ns:WorldKey(realm), realm is the last shard seen; name includes the surname
log        = { { time, from, realm, to, mode, items = { {id, name, icon, count} } } } -- oldest first
showPanel  = true  -- docked panel; on the Inbox tab only when extendMailbox is on
extendMailbox = true
playSounds = true  -- coin sound per mail sent, chime when a run finishes
windowStyle = "satchel"  -- "satchel" | "letter" | "flat" | "blizzard"
collapsedSections = { [sectionKey] = true }  -- settings form sections folded away ("mailbox" for the toggles)
keepFirstAidCloth = false  -- don't mail cloth this character's First Aid still needs (current bracket and up)
```

If you change this shape, add a migration in the `ADDON_LOADED` handler in `Core.lua`.

## Testing

There are no automated tests. Test in game:

1. Copy or symlink the repo into `Interface/AddOns/CraftCourier`, then run `/reload` after each change. Adding or renaming a file in the TOC needs a full game restart, not just `/reload`.
2. Turn on Lua errors with `/console scriptErrors 1`, or use BugSack.
3. Open a mailbox carrying several material types, more than 12 stacks of at least one of them, and a soulbound item. Check the counts, tooltips, chunking, Send All grouping, and that closing the mailbox mid-send stops cleanly.
4. With more than 7 mails (ideally more than the server sends at once), check the inbox summary, scrolling, Take, shift-click, opening a mail, and COD mail. Toggle **Extend the mailbox** off and on with the mailbox open and check that Blizzard's layout comes back intact.

## Releasing

- `./package.sh [version]` builds `.release/CraftCourier-<version>.zip`, with the version taken from `## Version:` in the TOC by default. When you add a new top-level file or folder that the addon loads, add it to `package.sh` too.
- Bump `## Version:` in `CraftCourier.toc` for each release.

## Docs

- `README.md`: for developers and GitHub readers.
- `docs/items.md`: where the item-ID tables in `Categories.lua` (`waylaidCrates`, `professionSupplies`, `recipeSubclassMap`) come from: Wowhead data, the reason for each mapping, items left out on purpose, and what is still unconfirmed. Update it when those tables change, and record the date checked. Not shipped (ignored in `.pkgmeta`, not copied by `package.sh`).
- `CURSE.md`: the CurseForge project page, written for players. Keep it in sync when you add features.
- `.github/ISSUE_TEMPLATE/`: issue forms for missing categories, items not picked up and items in the wrong category. They ask for `/ccr item` output, so keep that command's output stable.
