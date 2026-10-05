# CraftCourier

<p align="center"><img src="logo.png" alt="CraftCourier logo" width="160"></p>

A World of Warcraft addon (WoW Forever, interface `16001`) that mails crafting materials and unbound BoE gear to your alts with one click.

Pick a character for each type of material: cloth, leather, herbs, ore, bars and so on. When you open a mailbox, CraftCourier looks through your bags and shows a button for each material type you're carrying. Click a button and the addon writes and sends the mail for you, attaching every matching stack.

## Features

- A recipient for each material type: Cloth, Leather, Herbs, Ore, Bars, Stone, Gems, Enchanting, Elemental, Cooking, Parts and Other Trade Goods.
- A recipient for **unbound Bind on Equip items** of each rarity: BoE Uncommon, Rare and Epic.
- Settings in two places: a page under **Options → AddOns → CraftCourier**, and a small window opened with `/craftcourier` or the mailbox panel's **Settings** button. As you type a recipient, it suggests names from the game's own mail autocomplete (every character on your account, friends, guild members and people you've played with recently), recipients you've already set, and Battle.net friends playing this version of WoW. Only characters you can actually mail (same realm and faction) are suggested.
- A panel docked beside the mailbox, listing each material type in your bags with its item count and two buttons:
  - **One Click Send** attaches the stacks and sends the mails automatically.
  - **Review and Send** attaches the stacks and fills in the recipient and subject, but you press Send yourself. If a material needs more than one mail, the next one is filled in after each send.

  Material types assigned to the character you're logged in on are hidden.
- **Send All** and **Review All**: the same two options for every material type at once. Material types going to the same character share mails. While mails are being sent, **Send All** becomes **Stop**.
- Mails are filled to the 12-attachment limit, and the addon keeps sending until everything is gone.
- Soulbound items are skipped, and so is any material type whose recipient is the character you're logged in on.
- Per-item overrides fix wrong classifications, or stop an item from ever being sent.
- A **send log** of every mail CraftCourier sends: when it was sent, from which character, to whom, and the items attached. It's shared across all your characters, can be filtered by name or item, and keeps the latest 1000 mails. Open it with `/craftcourier log` or the mailbox panel's **Log** button.

## Installation

Copy or symlink this folder into your AddOns directory, so the path is `Interface/AddOns/CraftCourier/CraftCourier.toc`:

```sh
ln -s ~/dev/CraftCourier "<WoW install>/<flavor>/Interface/AddOns/CraftCourier"
```

## Usage

1. Type `/craftcourier` (or `/ccr`) to open the settings window, or use **Options → AddOns → CraftCourier**. Enter a recipient for each material type, using the character's full name including surname (e.g. `Greeb Deez`). Add `-Realm` for another realm. Start typing to see suggestions: use the arrow keys to move through them and Tab or Enter to pick one.
   Characters on your account are suggested as soon as you type. With an empty box, the list shows alts you've logged into with CraftCourier installed, plus recipients you've already set.
2. Open any mailbox. The CraftCourier panel appears to the right of the mail window.
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
UI/MailPanel.lua   Panel docked to the mailbox
UI/Suggest.lua     Recipient name suggestions (game autocomplete, alts, friends, Battle.net), filtered to mailable characters
UI/LogWindow.lua   Send log window with filter
UI/Config.lua      Recipient form, shown as the Options > AddOns page and as a small window
.pkgmeta           CurseForge/BigWigs packager config
package.sh         Builds the release zip into .release/
CURSE.md           CurseForge project description
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
