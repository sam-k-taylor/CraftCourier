# CraftCourier

**Stop dragging mats into the mail one stack at a time.**

CraftCourier lets you assign a character to each type of crafting material, and to unbound BoE gear of each rarity. When you visit a mailbox, it sends everything to the right alt in one click.

## How it works

1. Type **/craftcourier** (or use **Options → AddOns → CraftCourier**) and choose who gets what. Names are suggested as you type: characters on your account, friends, guild members and Battle.net friends, as long as they're on your ruleset (PvE, PvP, RP-PvE or RP-PvP) and faction. For example, your tailor gets Cloth, your leatherworker gets Leather, your alchemist gets Herbs, and so on.
2. Open any mailbox. The CraftCourier panel beside the inbox (and on the **Send Mail** tab) lists each material type in your bags and how many you have.
3. For each material type, choose **One Click Send** to mail it right away, or **Review and Send** to have the mail filled in so you can check it and press Send yourself. **Send All** and **Review All** do the same for everything.

CraftCourier attaches the stacks, fills each mail to the 12-attachment limit and keeps sending until your bags are empty of that material.

## Features

- **13 material types:** Cloth, Leather, Herbs, Ore, Bars, Stone, Gems, Enchanting, Elemental, Cooking, Parts, Dyes and Other Trade Goods.
- **Comprehension Scrolls:** send the Mage-only scrolls you loot (deciphered or not) to your mage.
- **Profession plans and supplies:** plans, patterns and recipes go to the alt with that profession: Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Cooking and First Aid. Bind on Equip plans included. Vendor supplies go there too: vials to your alchemist, flux to your blacksmith, thread to your tailor and so on.
- **Waylaid Crates:** identified crates go to the alt who holds what fills them (Herbs crates to your herb alt, Ingots to your bars alt and so on).
- **BoE gear by rarity:** send unbound Bind on Equip items to a different alt for each rarity (Uncommon, Rare, Epic). Ideal for an auction alt or a disenchanter.
- **One Click Send** or **Review and Send** for every material type, right inside the mailbox.
- **A better inbox:** the mail window is twice as wide, with a summary of your mail (how many, items, gold, COD and anything about to expire) and one scrolling list of every mail, with no pages. Take a whole mail with one click, or just one attachment.
- **Settings tab** on the mailbox, so you can change recipients without leaving it. Prefer Blizzard's mailbox? Turn off **Extend the mailbox** and the panel docks beside it instead.
- **Send All** packs material types that go to the same alt into shared mails, so you pay for fewer mails.
- **Name suggestions** as you type, showing only characters you can actually mail, in the settings and in the Send Mail **To:** box, with your alts in their class colours.
- **Smart hiding:** on your herbalism alt, the Herbs button doesn't appear, because it's already the right character.
- **Tooltips** show exactly which items will go to whom before you click.
- **Safe:** soulbound items are skipped, it never mails the character you're playing, and sending stops if a mail fails or you close the mailbox.
- **Send log:** see every mail CraftCourier has sent, from any of your characters: when it went, who sent it, who received it (in class colours) and what was in it, shown as item icons. Filter by name or item.
- **See your alts at a glance:** in Settings, each recipient shows its class icon and class colour. Sections (Materials, Plans and Profession Items, Bind on Equip Gear, Custom, Mailbox) fold away with a click.
- **Window styles:** pick how CraftCourier's windows look in Settings → Mailbox → Window style (or `/ccr style`). **Courier's Satchel** (dark leather, gold frame, wax-seal close button), **Letter** (a parchment page in dark ink), **Flat** (clean, dark and square), or **Blizzard** (the game's own windows). The style covers the whole mailbox too: the inbox, the Send Mail form and opened letters. Changes apply instantly.
- **Progress bar:** watch "Mail 3 of 8" fill up while sending, then a summary such as "Sent 8 mails to 3 alts". A coin sound plays for each mail and a chime when it's done; turn sounds off in Settings.
- **Keep cloth for First Aid:** turn on **Keep the cloth my First Aid skill still needs** and CraftCourier holds back the cloth your character's First Aid still needs: the one for your current level and every type above it. For example, at 120 it keeps Wool, Silk, Mageweave and Runecloth and mails your Linen. (Linen is used below 81, Wool below 151, Silk below 211, Mageweave below 261, Runecloth below 300.)
- **Item filters:** reassign any item to a different category, or tell CraftCourier to ignore it. Open **Item Filters** (on the Settings tab, in the settings window, or with `/ccr filters`), click the item slot to pick something from your bags (or drop an item on it), then choose its category or tick **Ignore**. Every filter you've added is listed below, where you can edit or remove it.
- **Custom categories:** make your own categories on the Item Filters screen, such as "Quest items" or "Transmog", and give each one a recipient in Settings like any other. Put items in them with the category dropdown. Deleting a category sends its items back to their usual category.

## Commands

- `/craftcourier` or `/ccr`: open the settings window
- `/craftcourier set <category> <Name Surname>`: set a recipient, e.g. `/ccr set leather Greeb Deez`
- `/craftcourier clear <category>`: remove a recipient
- `/craftcourier log`: open the send log
- `/craftcourier style <satchel|letter|flat|blizzard>`: change the window style
- `/craftcourier list`: show your recipients
- `/craftcourier filters`: open the item filters window
- `/craftcourier assign [item link] <category|ignore>`: fix an item's category
- `/craftcourier unassign [item link]`: undo an override
- `/craftcourier item [item link]`: show how an item is categorised (handy for bug reports)
- `/craftcourier debug`: show which character CraftCourier thinks you're on

## Notes

- Ore, Bars and Stone are told apart by item name, so this works best with an English client. Use **Item Filters** or `/craftcourier assign` for anything that's sorted wrong.
- Normal postage applies to every mail.

## Help improve CraftCourier

Please [open a GitHub issue](https://github.com/sam-k-taylor/CraftCourier/issues) if:

- **A category is missing:** there's a type of material or item you'd like to send to its own alt.
- **An item isn't being picked up:** it's in your bags but doesn't appear in the CraftCourier panel.
- **An item is in the wrong category**, for example a bar showing up under Stone.

The issue forms will ask you to run `/ccr item` and shift-click the item into it, e.g. `/ccr item [Copper Bar]`. That prints everything we need to sort it correctly. Paste the output, along with the category you expected. Bug reports and other suggestions are welcome there too.

## License

CraftCourier is open source under the [MIT License](https://github.com/sam-k-taylor/CraftCourier/blob/master/LICENSE).
