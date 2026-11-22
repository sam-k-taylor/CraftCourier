# CraftCourier

<p align="center"><img src="logo.png" alt="CraftCourier logo" width="160"></p>

A World of Warcraft addon (WoW Forever, interface `16001`) that mails crafting materials and unbound BoE gear to your alts with one click.

Pick a character for each type of material: cloth, leather, herbs, ore, bars and so on. When you open a mailbox, CraftCourier looks through your bags and shows a button for each material type you're carrying. Click a button and the addon writes and sends the mail for you, attaching every matching stack.

## Features

- A recipient for each material type: Cloth, Leather, Herbs, Ore, Bars, Stone, Gems, Enchanting, Elemental, Cooking, Parts and Other Trade Goods.
- A recipient for **unbound Bind on Equip items** of each rarity: BoE Uncommon, Rare and Epic.
- An **extended mailbox**: Blizzard's mail window doubles in width.
  - **Inbox** tab: a summary (number of mails, items, attached gold, unread, COD, mails expiring within 3 days, and mail still waiting on the server) above one scrolling list of every mail, with no pages. Each row shows the sender, subject, attachments, gold or COD and time left. Click a mail to open it, shift-click or press **Take** to take everything, or click an attachment to take just that item.
  - **Send Mail** tab: Blizzard's send form on the left, and the CraftCourier send panel on the right.
  - On the **Inbox** tab the send panel docks beside the mailbox, so you can send as soon as you open it. It steps aside while a letter is open.
  - **Settings** tab: the recipient form.

  Turn off **Extend the mailbox** in settings to keep Blizzard's mail window as it is and dock the CraftCourier panel beside it instead.
- Settings in three places: the mailbox's **Settings** tab, a page under **Options → AddOns → CraftCourier**, and a small window opened with `/craftcourier`. As you type a recipient, it suggests names from the game's own mail autocomplete (every character on your account, friends, guild members and people you've played with recently), recipients you've already set, and Battle.net friends playing this version of WoW. Only characters you can actually mail (same realm and faction) are suggested.
- **Keep the cloth my First Aid skill still needs** (off by default): the send panel leaves out the cloth for the logged-in character's current First Aid bracket and every higher one (Linen below 81, Wool below 151, Silk below 211, Mageweave below 261, Runecloth below 300), so only cloth it has outgrown is mailed. Updates as the skill rises.
- A send panel listing each material type in your bags with its item count and two buttons:
  - **One Click Send** attaches the stacks and sends the mails automatically.
  - **Review and Send** attaches the stacks and fills in the recipient and subject, but you press Send yourself. If a material needs more than one mail, the next one is filled in after each send.

  Material types assigned to the character you're logged in on are hidden.
- **Send All** and **Review All**: the same two options for every material type at once. Material types going to the same character share mails. While mails are being sent, **Send All** becomes **Stop**.
- Mails are filled to the 12-attachment limit, and the addon keeps sending until everything is gone.
- Soulbound items are skipped, and so is any material type whose recipient is the character you're logged in on.
- Per-item overrides fix wrong classifications, or stop an item from ever being sent.
- A **send log** of every mail CraftCourier sends: when it was sent, from which character, to whom, and the items attached. It's shared across all your characters, can be filtered by name or item, and keeps the latest 1000 mails. Open it with `/craftcourier log` or the **Log** button on the send panel.

## Installation

Copy or symlink this folder into your AddOns directory, so the path is `Interface/AddOns/CraftCourier/CraftCourier.toc`:

```sh
ln -s ~/dev/CraftCourier "<WoW install>/<flavor>/Interface/AddOns/CraftCourier"
```

## Usage

1. Type `/craftcourier` (or `/ccr`) to open the settings window, or use **Options → AddOns → CraftCourier**. Enter a recipient for each material type, using the character's full name including surname (e.g. `Greeb Deez`). Add `-Realm` for another realm. Start typing to see suggestions: use the arrow keys to move through them and Tab or Enter to pick one.
   Characters on your account are suggested as soon as you type. With an empty box, the list shows alts you've logged into with CraftCourier installed, plus recipients you've already set.
2. Open any mailbox. The CraftCourier panel is docked beside the inbox, and fills the right half of the **Send Mail** tab.
3. Click **One Click Send** or **Review and Send** on a material type, or **Send All** or **Review All** at the bottom. Click **Stop** to cancel. In review mode, Stop also takes the items back out of the mail.

Hover over a button to see the recipient and every item that will be sent.

### Slash commands

| Command | Description |
| --- | --- |
| `/craftcourier` or `/ccr` | Open or close the settings window |
| `/craftcourier set <category> <Name Surname[-Realm]>` | Set a recipient, e.g. `/ccr set leather Greeb Deez` |
| `/craftcourier clear <category>` | Remove a recipient |
| `/craftcourier log` | Open or close the send log |
| `/craftcourier list` | Show all recipients |
| `/craftcourier categories` | List the category keys |
| `/craftcourier assign <item link> <category\|ignore>` | Put an item in a different category, or ignore it |
| `/craftcourier unassign <item link>` | Remove an item override |
| `/craftcourier item <item link or ID>` | Show an item's ID, class, quality, bind type and CraftCourier category (useful for issue reports) |
| `/craftcourier debug` | Show which character and realm CraftCourier thinks you are on, and which recipients match it |

Shift-click an item to insert its link into the chat box.

## How items are classified

Items that are **Bind on Equip** and not yet bound go to the BoE category for their rarity (Uncommon, Rare or Epic), whatever kind of item they are. Common and Legendary BoE items aren't sent, and nor are bound items.

Apart from those, only items in the **Trade Goods** item class are considered. They're sorted by item subclass (Cloth, Leather, Herb and so on). The game puts ore, bars and stone together in one **Metal & Stone** subclass, so CraftCourier splits them by English item name:

- a name containing "Ore" goes to **Ore**
- a name containing "Bar" or "Ingot" goes to **Bars**
- everything else goes to **Stone**

**Comprehension Scrolls** are the Mage-only scrolls for the Forever Comprehension skill: the undeciphered "Scroll: …" drops and the scrolls they decipher into. Among items in the Consumable / Scroll subclass, CraftCourier picks out those named "Scroll: …" and those whose tooltip says *Classes: Mage* (in the client's language) or *Requires Comprehension*. Other consumables aren't sent.

**Plans** (items in the Recipe class: plans, patterns, schematics, formulas, recipes and manuals) are sorted by recipe subclass into one category per profession: **Alchemist**, **Blacksmith**, **Enchanter**, **Engineer**, **Leatherworker**, **Tailor**, **Cook** and **First Aid**. They're checked before BoE gear, so Bind on Equip plans go to the profession rather than to a BoE category. Fishing books and other Book items aren't sent.

The same profession categories also get the vendor reagents each profession uses, matched by item ID: vials go to Alchemist, flux and coal to Blacksmith, thread to Tailor, salt to Leatherworker, Copper Rods and Simple Wood to Enchanter, and Fused Wiring and gun stocks to Engineer. Items that more than one profession uses go to the first one with a recipient: vials go to the Enchanter if there's no Alchemist, flux and coal to the Engineer, and thread to the Leatherworker. Dyes, which several professions use, have their own **Dyes** category.

**Waylaid Crates** that you've identified go to whoever holds what fills them, going by each crate's fill list: Herbs to **Herbs**, Ore to **Ore**, Ingots to **Bars**, Parts to **Parts** and Curiosities to **Enchanting**. Textiles and Fabrics take cloth or leather, so they go to **Cloth**, or to **Leather** if only Leather has a recipient. The crates are matched by item ID. The unidentified Waylaid Crate isn't sent.

If an item lands in the wrong place, use `/craftcourier assign`.

## Reporting issues

If a category is missing, an item isn't picked up, or an item is in the wrong category, [open an issue](https://github.com/sam-k-taylor/CraftCourier/issues/new/choose) and include the output of `/craftcourier item [item link]`.

## Project layout

```
CraftCourier.toc   Addon manifest
Core.lua           Saved variables, API compatibility, events, slash commands
Categories.lua     Category list, item classification, bag scanning
Log.lua            Records each sent mail (time, from, to, items)
Mailer.lua         Mail queue: attaches stacks, then sends (auto) or waits for you to send (review), one mail at a time
UI/Mailbox.lua     Extends Blizzard's mail window: double width, Settings tab
UI/Inbox.lua       Inbox summary and scrolling mail list
UI/MailPanel.lua   Send panel (inside the Send Mail tab, or docked beside the inbox)
UI/Suggest.lua     Recipient name suggestions (game autocomplete, alts, friends, Battle.net), filtered to mailable characters
UI/LogWindow.lua   Send log window with filter
UI/Config.lua      Recipient form, shown on the Settings tab, the Options > AddOns page and a small window
.pkgmeta           CurseForge/BigWigs packager config
package.sh         Builds the release zip into .release/
CURSE.md           CurseForge project description
docs/items.md      Item reference: where the item-ID tables come from and why each item maps where it does
.github/           Issue forms: missing category, item not picked up, wrong category
LICENSE            MIT License
logo.svg/.png      Project logo (400x400 PNG for CurseForge, rendered from the SVG)
```

## Releasing

The version is set by `## Version:` in `CraftCourier.toc` (currently `0.0.1`). To build a release:

```sh
./package.sh          # uses the TOC version -> .release/CraftCourier-0.0.1.zip
./package.sh 0.0.2    # or give a version; it's written into the packaged TOC
```

The zip contains only the addon (`CraftCourier.toc`, the `.lua` files, `UI/` and `LICENSE`), ready to upload to CurseForge. `.release/` is git-ignored.

## License

CraftCourier is released under the [MIT License](LICENSE).
