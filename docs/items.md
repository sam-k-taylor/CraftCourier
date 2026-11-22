# Item reference

Where the item-ID tables in `Categories.lua` come from, and why each item maps where it does. The data was taken from Wowhead's Forever database ([wowhead.com/forever](https://www.wowhead.com/forever/)), checked **2026-11-22** unless a row says otherwise.

Update this file whenever `waylaidCrates`, `professionSupplies` or `recipeSubclassMap` changes. Forever hides item details until a player discovers them, so Wowhead can be incomplete. Anything marked *unconfirmed* should be checked in game with `/ccr item <id>`.

This file is for developers. `package.sh` doesn't ship it.

## Waylaid Crates (`waylaidCrates`)

The unidentified **Waylaid Crate** ([248549](https://www.wowhead.com/forever/item=248549)) is a Consumable, item level 1, requires level 10, stacks to 20, added in patch 1.60.1. Its tooltip reads "Use: Read the label to identify the shipment." It has no fill list, so CraftCourier doesn't mail it.

Reading the label turns it into one of the crates below. Each is item level 1, Drop, Consumable, "Crafting Reagent", and stacks to 5. Each one's tooltip says "Use: Fill the crate with any bundle from the following list:", followed by the bundles listed here. A crate goes to the category that holds its bundles.

*Unconfirmed:* whether the crates are soulbound. Wowhead had no bind line. If they are, `ScanBags` skips them like any other bound item.

### Herbs → `herbs`

| ID | Crate | Req. | Fill bundles |
| --- | --- | --- | --- |
| [248682](https://www.wowhead.com/forever/item=248682) | Apprentice Herbs | 10 | 20 Peacebloom, 20 Silverleaf, 10 Earthroot, 10 Mageroyal, 10 Briarthorn |
| [248686](https://www.wowhead.com/forever/item=248686) | Journeyman Herbs | 10 | 10 Stranglekelp, 10 Bruiseweed, 10 Wild Steelbloom, 10 Grave Moss, 10 Kingsblood |
| [248690](https://www.wowhead.com/forever/item=248690) | Earthly Expert Herbs | 20 | 20 Liferoot, 10 Fadeleaf, 10 Goldthorn, 10 Khadgar's Whisker |
| [248691](https://www.wowhead.com/forever/item=248691) | Flowering Expert Herbs | 20 | 10 Wintersbite, 10 Firebloom, 20 Purple Lotus, 10 Arthas' Tears |
| [248695](https://www.wowhead.com/forever/item=248695) | Earthly Artisan Herbs | 35 | 10 Golden Sansam, 20 Sungrass, 10 Blindweed, 10 Ghost Mushroom, 10 Gromsblood |
| [248696](https://www.wowhead.com/forever/item=248696) | Flowering Artisan Herbs | 35 | 20 Dreamfoil, 20 Mountain Silversage, 20 Plaguebloom, 20 Icecap |

### Ore → `ore`

| ID | Crate | Req. | Fill bundles |
| --- | --- | --- | --- |
| [248683](https://www.wowhead.com/forever/item=248683) | Apprentice Ore | 10 | 20 Copper Ore, 20 Tin Ore |
| [248687](https://www.wowhead.com/forever/item=248687) | Journeyman Ore | 10 | 10 Silver Ore, 20 Iron Ore |
| [248692](https://www.wowhead.com/forever/item=248692) | Expert Ore | 20 | 10 Gold Ore, 20 Mithril Ore |
| [248697](https://www.wowhead.com/forever/item=248697) | Artisan Ore | 35 | 10 Truesilver Ore, 20 Thorium Ore, 20 Dark Iron Ore |

### Ingots → `bars`

| ID | Crate | Req. | Fill bundles |
| --- | --- | --- | --- |
| [248703](https://www.wowhead.com/forever/item=248703) | Apprentice Ingots | 10 | 20 Copper Bar, 20 Tin Bar, 10 Bronze Bar |
| [248706](https://www.wowhead.com/forever/item=248706) | Journeyman Ingots | 10 | 10 Silver Bar, 20 Iron Bar |
| [248709](https://www.wowhead.com/forever/item=248709) | Expert Ingots | 20 | 20 Mithril Bar, 15 Steel Bar, 10 Gold Bar |
| [248712](https://www.wowhead.com/forever/item=248712) | Artisan Ingots | 35 | 2 Dark Iron Bar, 10 Truesilver Bar, 20 Thorium Bar |

### Parts → `parts`

| ID | Crate | Req. | Fill bundles |
| --- | --- | --- | --- |
| [248704](https://www.wowhead.com/forever/item=248704) | Apprentice Parts | 10 | 16 Handful of Copper Bolts, 16 Copper Tube, 4 Copper Modulator |
| [248707](https://www.wowhead.com/forever/item=248707) | Journeyman Parts | 10 | 8 Bronze Tube, 7 Whirring Bronze Gizmo, 4 Bronze Framework, 45 Gold Power Core |
| [248710](https://www.wowhead.com/forever/item=248710) | Expert Parts | 20 | 8 Iron Strut, 5 Mithril Tube, 12 Unstable Trigger, 5 Mithril Casing |
| [248713](https://www.wowhead.com/forever/item=248713) | Artisan Parts | 35 | 5 Thorium Widget, 5 Truesilver Transformer, 2 Thorium Tube |

### Curiosities → `enchanting`

| ID | Crate | Req. | Fill bundles |
| --- | --- | --- | --- |
| [248685](https://www.wowhead.com/forever/item=248685) | Apprentice Curiosities | 10 | 20 Strange Dust, 4 Greater Magic Essence, 6 Small Glimmering Shard, 2 Large Glimmering Shard |
| [248689](https://www.wowhead.com/forever/item=248689) | Journeyman Curiosities | 10 | 20 Soul Dust, 4 Greater Astral Essence, 6 Small Glowing Shard, 2 Large Glowing Shard |
| [248694](https://www.wowhead.com/forever/item=248694) | Expert Curiosities | 20 | 20 Vision Dust, 4 Greater Mystic Essence, 6 Small Radiant Shard, 2 Large Radiant Shard |
| [248699](https://www.wowhead.com/forever/item=248699) | Artisan Curiosities | 35 | 20 Dream Dust, 4 Greater Nether Essence, 6 Small Brilliant Shard, 2 Large Brilliant Shard |

### Textiles and Fabrics → `cloth`, else `leather`

These take cloth **or** leather, so they go to `cloth`, or to `leather` if only Leather has a recipient (`TEXTILES` in the code).

| ID | Crate | Req. | Fill bundles |
| --- | --- | --- | --- |
| [248684](https://www.wowhead.com/forever/item=248684) | Apprentice Textiles | 10 | 40 Linen Cloth, 20 Light Leather |
| [248688](https://www.wowhead.com/forever/item=248688) | Journeyman Textiles | 10 | 20 Wool Cloth, 40 Silk Cloth, 20 Medium Leather |
| [248693](https://www.wowhead.com/forever/item=248693) | Expert Textiles | 20 | 40 Mageweave Cloth, 20 Heavy Leather |
| [248698](https://www.wowhead.com/forever/item=248698) | Artisan Textiles | 35 | 40 Runecloth, 20 Thick Leather, 20 Rugged Leather |
| [248702](https://www.wowhead.com/forever/item=248702) | Apprentice Fabrics | 10 | 2 Cured Light Hide, 20 Bolt of Linen Cloth |
| [248705](https://www.wowhead.com/forever/item=248705) | Journeyman Fabrics | 10 | 6 Bolt of Woolen Cloth, 10 Bolt of Silk Cloth, 2 Cured Medium Hide |
| [248708](https://www.wowhead.com/forever/item=248708) | Expert Fabrics | 20 | 8 Bolt of Mageweave, 2 Cured Heavy Hide |
| [248711](https://www.wowhead.com/forever/item=248711) | Artisan Fabrics | 35 | 8 Bolt of Runecloth, 2 Cured Thick Hide |

IDs 248700 and 248701 fall between the two ranges. They weren't in Wowhead's "See also" list for the Waylaid Crate, so they aren't mapped.

## Profession supplies (`professionSupplies`)

Vendor reagents that the game puts in Trade Goods / Other. Without this table they'd land in "Other Trade Goods". Only the names were checked on Wowhead; which profession uses each item comes from the recipes that call for it. Where more than one profession uses an item, the first category listed that has a recipient gets it.

| ID | Item | Category | Fallback | Why |
| --- | --- | --- | --- | --- |
| 3371 | Empty Vial | Alchemist | Enchanter | Potions; enchanting oils also use vials |
| 3372 | Leaded Vial | Alchemist | Enchanter | as above |
| 8925 | Crystal Vial | Alchemist | Enchanter | as above |
| 18256 | Imbued Vial | Alchemist | Enchanter | as above |
| 2880 | Weak Flux | Blacksmith | Engineer | Both professions' recipes |
| 3466 | Strong Flux | Blacksmith | Engineer | as above |
| 3857 | Coal | Blacksmith | Engineer | Sold by blacksmithing suppliers. Before this table it went to Stone. |
| 2320 | Coarse Thread | Tailor | Leatherworker | Both professions' recipes |
| 2321 | Fine Thread | Tailor | Leatherworker | as above |
| 4291 | Silken Thread | Tailor | Leatherworker | as above |
| 8343 | Heavy Silken Thread | Tailor | Leatherworker | as above |
| 14341 | Rune Thread | Tailor | Leatherworker | as above |
| 2604 | Red Dye | Dyes | | Several professions use dyes, so they have their own category. The category's icon comes from this item. |
| 2605 | Green Dye | Dyes | | |
| 2325 | Black Dye | Dyes | | |
| 4340 | Gray Dye | Dyes | | |
| 4341 | Yellow Dye | Dyes | | |
| 4342 | Purple Dye | Dyes | | |
| 6260 | Blue Dye | Dyes | | |
| 6261 | Orange Dye | Dyes | | |
| 10290 | Pink Dye | Dyes | | |
| 4289 | Salt | Leatherworker | | Salting hides |
| 6217 | Copper Rod | Enchanter | | Runed Copper Rod |
| 4470 | Simple Wood | Enchanter | | Enchanting rods and wands |
| 11291 | Star Wood | Enchanter | Engineer | |
| 7191 | Fused Wiring | Engineer | | |
| 4399 | Wooden Stock | Engineer | | Guns |
| 4400 | Heavy Stock | Engineer | | Guns |

### Considered and left out

These were looked at and deliberately not mapped. Add them only for a clear reason.

| ID | Item | Why not |
| --- | --- | --- |
| 814 | Flask of Oil | Unclear which profession uses it |
| 10647 | Engineer's Ink | Unclear whether it's sold or crafted on Forever |
| 10648 | Blank Parchment | No clear profession |
| 4471 | Flint and Tinder | Not a crafting reagent |
| 6530 | Nightcrawlers | Fishing bait |
| 18240 | Ogre Tannin | A drop, not a vendor reagent |
| 14256 | Felcloth | Already classified as cloth |
| 2678 | Mild Spices | Already classified as cooking (Trade Goods / Cooking) |

## Plans (`recipeSubclassMap`)

Items in the Recipe class (`Enum.ItemClass.Recipe` = 9) are sorted by `Enum.ItemRecipeSubclass`. These values come from `Blizzard_APIDocumentationGenerated/ItemConstantsDocumentation.lua` on the `forever` branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever).

| Value | Subclass | Category |
| --- | --- | --- |
| 0 | Book | not mailed |
| 1 | Leatherworking | Leatherworker (`plans_leatherworking`) |
| 2 | Tailoring | Tailor (`plans_tailoring`) |
| 3 | Engineering | Engineer (`plans_engineering`) |
| 4 | Blacksmithing | Blacksmith (`plans_blacksmithing`) |
| 5 | Cooking | Cook (`plans_cooking`) |
| 6 | Alchemy | Alchemist (`plans_alchemy`) |
| 7 | First Aid | First Aid (`plans_firstaid`) |
| 8 | Enchanting | Enchanter (`plans_enchanting`) |
| 9 | Fishing | not mailed |
| 10 | Jewelcrafting | not mailed (not in Forever) |
| 11 | Inscription | not mailed (not in Forever) |

The plans check runs before the BoE check, so Bind on Equip plans go to the profession.

## Getting data from Wowhead

- An item's tooltip text, including Wowhead's "Fill the crate…" lists, is embedded in its page as `tooltip_enus`.
- An item's "See also" tab lists its variants. That's where the 30 crates came from.
- Wowhead sometimes shows a human-verification page instead of the item. Don't try to get around it: check in game with `/ccr item <id>`, or have a person look it up.
