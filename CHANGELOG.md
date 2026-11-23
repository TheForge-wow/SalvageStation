# Salvage Station

## v1.0.2 — Auction scanner fixes and /salvage debug

- **Fixed:** items were marked **Needs 200** (or similar) and skipped by Disenchant Next. WoW Forever lets any Enchanting level disenchant anything, so the skill check has been removed.
- **Fixed:** with **Uncommon** turned on, the auction scanner only ever found green items, even with Rare and Epic on too. Each rarity is now loaded on its own, Epic first, so Rares and Epics always come through.
- **Fixed:** deals could vanish from the auction list at the start of a new pass. A deal now only leaves the list once a pass shows it's sold, expired or no longer a deal.
- **Faster passes with lots of green gear:** the scanner now prices gear from its rarity, item level and type straight from the auction listing, without waiting for each item's details to load. With 20,000+ green items, many used to time out and be skipped every pass.
- **`/salvage debug`** now opens the debug report, the same command as Lifeline's `/ll debug`. The window matches Lifeline's too: the report is already selected, so just press Ctrl+C and paste it in Discord. `/salvage copy` still works.
- The **Self-check** button in **Settings › Window** is now called **Debug report**.

## v1.0.1 — Auction scanner upgrades

**Auction scanner**
- Gear with random "of the ..." names (like *of the Owl*) is now checked once and remembered, instead of being searched again on every pass while its item data loaded.
- Clearer counts: how many weapons and armor are listed, how many could be deals, and how many unchanged items each pass skipped.
- **Minimum profit** now takes gold, silver and copper, like the auction house, so you can set amounts like 50 silver. Your old setting carries over.
- **Pick rarities to scan:** Uncommon, Rare and Epic buttons on the Auction page. Only the rarities you pick are searched, so a scan finishes sooner. Changing them restarts a running scan.
- The scan only looks at the **Weapons** and **Armor** categories, and anything else is dropped straight away without loading its details.
- New **Rarity** sort: click it to list Epics first, click again for Uncommons first.
- New switch in **Settings › Prices**: **Keep watching after a full pass**. Turn it off to stop after checking the whole auction house once.

## v1.0.0 — First release

One-click disenchanting built for WoW Forever, taking the best ideas from TSM's Destroying window and Disenchantry.

**Disenchant page**
- The selected item at the top with its **possible results**: chance, average amount and range (for example `75% Strange Dust x1.85 [2-3]`).
- A simple item list: click a row to select it. **Disenchant Next** disenchants the selected item and waits for the loot before moving on.
- Blue **AH** and gold **Vendor** tags on items worth more sold than disenchanted.
- **Hide** any item: click the hide icon to hide it until you log out, Shift+click to ignore it permanently.
- **Skip** an item until the window is closed.
- Items the game won't disenchant are blocked automatically.

**Compact bar**
- A small floating bar with the next item, its possible results, arrows to step through your items, and Skip / Hide / Disenchant buttons.
- Switch between the compact bar and the full window at any time.

**Tooltip panel**
- A **Salvage Station panel** under item tooltips, only on items you can disenchant, exactly as wide as the tooltip.
- Each possible material with a chance bar, and **Disenchant**, **Vendor** and **Auction** values side by side with the best one marked.
- A clear verdict: **Disenchant**, **Vendor it** or **Auction it**, and by how much. Auction prices have the 5% cut taken off, and soulbound items skip the auction house.
- **Learning bar:** a thin bar along the bottom fills as Salvage Station learns from your own disenchants. After 10 of the same kind it switches to **YOUR RESULTS** and shows what the estimate was.
- **Full** or **Compact** style, Shift-only mode, and switches for the verdict, the learning bar and the learning count. With the panel off, you get plain tooltip lines instead.

**Statistics**
- This session and all-time totals: items disenchanted, materials received with their value, and **profit or loss** compared with selling the items.
- Breakdown by quality and your most valuable disenchant.
- **Knowledge** view: every kind of item it's learning, with a progress bar. A **Learned!** message pops up when one switches to your own results.

**Auction house scanner**
- Scans the auction house for gear worth more disenchanted than its buyout, with a minimum profit you choose.
- **Live results:** deals appear as they're found, with a progress line and a green **NEW** tag on later finds.
- Click a column header (**Item**, **Buyout**, **Disenchant**, **Profit** or **%**) to sort, like the auction house.
- Click a lot to check it's still there, then click **Buy**. Nothing is bought without your click.
- Buying only pauses the scan, and the next item is selected straight away so you can keep buying.
- A **Salvage** button on the auction house window opens it.

**Protection** (protected items stay listed, but Disenchant Next skips them unless you select one)
- **Upgrade guard**: protects items that would be an upgrade for you.
- **Item level protection** with a **Suggest** button that fills in your lowest equipped item level.
- **Value protection**: protects items worth more than an amount you set.
- Protect gear-set items, or hide protected items completely.
- **Alt+Right-click** any item in your bags to ignore it.

**Safety**
- Confirm before disenchanting Epics, Rare BoE items, items worth more sold, or anything over a gold amount you set.
- **Don't ask again for this item this session**: one switch in the confirm box. Undo it from the Ignored page or Settings › Protection.

**Better WoW Forever data**
- Disenchant tables include WoW Forever specifics: the uncommon weapon essence change, estimates for new crafted items, and wands that can't be disenchanted.
- Learns from your own disenchants by item-level range. Results with the Salvager buff are tracked separately.

**Everything else**
- Prices from TSM first, then Auctionator (last-seen or average price).
- **Hotkey**: set a key in Settings to disenchant the next item while the window is open.
- Shows up automatically when you have something to disenchant and closes when you're done (both optional), plus optional opening at vendors or with your bags.
- Settings in tabs: **General**, **Protection**, **Tooltips**, **Prices** and **Window**. Every option has its own on/off switch.
- Six accent colors, minimap button with a count badge, and data bar support (EllesmereUI, ElvUI, Titan Panel and more).
- `/salvage check` runs a self-check, and `/salvage copy` opens a report you can paste into a bug report.

Thanks to Disenchantry (MIT License) for its auction scanning code and WoW Forever disenchant data. See NOTICE.txt.
