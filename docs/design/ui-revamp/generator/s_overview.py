from data import *

A = "overview"
NEW8 = "New screen: Overview (round 8); no current app route"


def default_body(notices=""):
    return overview_head() + notices + w_today() + w_recent() + w_coming()


def build():
    reg("ov-default", A, "Home", "Overview, default widgets",
        phone(default_body(), "Overview", "long"),
        "The default set: Today, Recent entries and Coming up. Seed: today is 42.50 + 3.20 = S$45.70; the transfer is Moved, not spending. Coming up lists the Amex cut (15 Oct, this cycle S$210.60), the seeded Netflix and salary plans, and the two seeded entries dated ahead (Rent 3 Nov, Cold Storage 8 Nov). The S$1,200 cap is a labelled sample; the guide is the cap over 31 days. Full scroll shown.",
        NEW8)

    full = overview_head() + "".join(w() for w in ALL_WIDGETS)
    reg("ov-custom", A, "Home", "Overview, all 12 widgets",
        phone(full, "Overview", "long"),
        "Every widget added, in one order. This month: -167.40 spent, +3,200.00 income, net +3,032.60, transfer excluded. OCBC Savings 10,350.00 already includes its pockets. Insights and Week so far state the history they need. Sample: cap, budget limits 450/350/120. Full scroll shown.",
        NEW8)

    ins = overview_head() + w_today() + w_insights("shown") + w_recent()
    reg("ov-insights", A, "Home", "Overview, insights with enough history",
        phone(ins, "Overview", "long"),
        "Sample history (round 4 matched windows): with the three previous months complete, at most two category changes appear, each dismissible for the month. Groceries 73.50 against a usual 45.00; Dining 83.90 against 58.00. Transport is unchanged and stays out. Seed-only history shows the More daily history needed state instead.",
        NEW8)

    ev = (header("Groceries compared", "1-3 October / Usual start", back="Overview", gear=False)
          + tray("", '<div class="split"><div><span class="lab">Recorded</span><b>S$73.50</b></div><div><span class="lab">Usual 1-3</span><b>S$45.00</b></div></div>'
                     '<div class="guide" style="margin-top:8px">S$28.50 higher / 63.3%</div><div class="lab">Same elapsed days, not whole months.</div>')
          + tray("Usual start", '<div class="kv"><span>1-3 July</span><b>40.00</b></div><div class="kv"><span>1-3 August</span><b>50.00</b></div>'
                 '<div class="kv"><span>1-3 September</span><b>45.00</b></div><div class="kv"><span>(40.00 + 50.00 + 45.00) / 3</span><b>45.00</b></div>', aside="<small>Previous 3 months</small>")
          + tray("1-3 October", row("FairPrice groceries", "3 Oct / Supermarket / Amex Card", -42.50, "Supermarket")
                 + row("Tekka wet market", "2 Oct / Fresh Market / DBS Checking", -18.60, "Fresh Market")
                 + row("Cold Storage", "2 Oct / Groceries / DBS Checking", -12.40, "Groceries"), aside="<small>3 entries</small>")
          + btn("Open in Trends") + btn("Dismiss for October", "quiet"))
    reg("ov-evidence", A, "Home", "Insight evidence",
        phone(ev, "Overview", "long"),
        "Opened from See comparison. Sample baseline windows: July 40.00, August 50.00, September 45.00, the three months before October. Current entries 42.50 + 18.60 + 12.40 = 73.50; 73.50 - 45.00 = 28.50; 28.50 / 45.00 = 63.3%. Dismiss hides it for October only.",
        NEW8)

    sync = notice("Sync is paused", "Reconnect to send your latest entries. Your entries are saved on this device.", ["Reconnect sync"])
    reg("ov-sync-paused", A, "Notices", "Notice, sync paused",
        phone(default_body(sync), "Overview", "long"),
        "Shown on every tab while sign-in has expired or device access needs repair; it takes precedence over the save notice. Notices sit above the widgets and cannot be hidden in Edit Overview. Sample state over seed values.",
        "app/lib/ui/shell/status_banner.dart", ["Device access attention banner"])

    save = notice("Couldn't save changes", "Retrying.")
    reg("ov-save-retry", A, "Notices", "Notice, save retry",
        phone(default_body(save), "Overview", "long"),
        "Uses the same slot as the sync notice when sync is fine, and clears once the save succeeds. Sample state.",
        "app/lib/ui/shell/banner_state.dart; app/lib/ui/shell/status_banner.dart")

    plan = tray("", '<div style="display:flex;gap:9px;align-items:flex-start">' + med("Fitness", "alert")
                + '<div class="rc"><b>A plan needs attention</b><small style="font-size:12px;color:var(--text);margin-top:3px">Gym membership could not add its 1 October entry.</small><div class="link">Review' + ic("right", "s") + "</div></div></div>",
                cls="")
    plan = plan.replace('class="tray "', 'class="tray" style="border-color:var(--notice);border-left-width:3px"')
    reg("ov-plan-attention", A, "Notices", "Notice, plan needs attention",
        phone(default_body(plan), "Overview", "long"),
        "Stays until fixed, instead of a four-second banner. Gym membership and its 1 October date are samples outside the seed; Review opens the Plans tab with the reason and one fix.",
        "app/lib/ui/shell/banner_state.dart (missed occurrence)")

    syncing = '<div class="statusline"><span class="spin" style="width:13px;height:13px"></span>Syncing...</div>'
    reg("ov-syncing", A, "Notices", "Status, syncing",
        phone(default_body(syncing), "Overview", "long"),
        "A quiet timed status line in the notice slot while a sync runs. It leaves on its own and never covers content.",
        "app/lib/ui/shell/status_banner.dart", ["Sync status banner"])

    # Edit Overview
    def erow(name, sub, first=False, last=False):
        up = f'<span class="{"off" if first else ""}">{ic("up")}</span>'
        dn = f'<span class="{"off" if last else ""}">{ic("down")}</span>'
        return (f'<div class="editrow"><span class="grip">{ic("grip")}</span><div class="rc"><b>{name}</b><small>{sub}</small></div>'
                f'<span class="mv">{up}{dn}</span><span class="hide">Hide</span></div>')
    shown = erow("Today", "Spending and daily guide", first=True) + erow("Recent entries", "Your latest entries") + erow("Coming up", "Plans, entries dated ahead and statement cuts", last=True)
    add_rows = "".join(
        f'<div class="chooser"><div><b>{n}</b><small>{d}</small></div><span class="ad">+ Add</span></div>'
        for n, d in [("This month", "Spent, income and net so far"), ("Budget watch", "Limits close to their cap"), ("Spending over time", "Last 12 months")])
    ed = (sheet_head("Edit Overview", "Cancel", "Done")
          + '<div class="lab" style="margin:4px 0 2px">Choose what belongs on your home. Notices stay visible when needed.</div>'
          + shown + '<div class="setlab">Add widgets</div>' + add_rows
          + '<div class="link">See all widgets' + ic("right", "s") + "</div>" + btn("Restore default", "sec"))
    reg("ov-edit", A, "Edit Overview", "Edit Overview",
        phone(ed, "Overview", "long"),
        "Opened from Edit Overview in the header. Grips drag; the up and down controls do the same without dragging and disable at the edges. Hide changes the home only, never entries. Done saves; Cancel restores the previous layout; Restore default brings back the three starting widgets. Full scroll shown.",
        NEW8)

    cat = [("Today and daily guide", "What have I spent today?"), ("Recent entries", "Did I record the right things?"), ("Coming up", "What money dates are ahead?"),
           ("This month", "How does this month add up?"), ("Budget watch", "Which limits should I check?"), ("Top categories", "Where is my spending going?"),
           ("Account balances", "What money do I have?"), ("Card statement", "When does my card statement close?"), ("Spending over time", "What does a longer pattern look like?"),
           ("Insights", "Has something meaningfully changed?"), ("Savings pocket", "How close am I to this goal?"), ("Week so far", "How does this week compare with usual?")]
    lst = "".join(
        f'<div class="chooser"><div><b>{n}</b><small>{d}</small></div><span class="ad {"done" if i < 3 else ""}">{"Added" if i < 3 else "+ Add"}</span></div>'
        for i, (n, d) in enumerate(cat))
    under = overview_head()
    reg("ov-addwidgets", A, "Edit Overview", "Add widgets, full list",
        sheet_phone(under, sheet_head("Add widgets", "Back", "") + lst, cls="long", under_cls="none"),
        "The widget catalogue as the app shows it: twelve widgets, each named by the question it answers. Widgets already on the home say Added; Add appends a widget once, at the end. The catalogue scrolls inside the capped sheet.",
        NEW8)

    # Desktop Overview
    order = [w_today, w_month, w_recent, w_top, w_card, w_coming, w_balances, w_overtime, w_pocket, w_budgetwatch, w_insights, w_week]
    cols = [[], [], []]
    for i, w in enumerate(order):
        cols[i % 3].append(w())
    content = '<div class="dg3">' + "".join(f'<div class="dcol">{"".join(c)}</div>' for c in cols) + "</div>"
    reg("ov-desk", A, "Desktop", "Overview, desktop",
        desktop("Overview", content, "Overview", "Saturday, 3 October 2026",
                acts=f'<span>Edit Overview</span><span class="sbtn">{ic("search","s")}Search</span><span class="pbtn">{ic("plus","s")}Add entry</span>'),
        "One shared macOS and Windows window. The same widget order fills three columns at wide sizes and two below 1250 px. Same seed values and samples as the phone.",
        "app/lib/ui/shell/app_shell.dart; app/lib/ui/shell/layout_breakpoints.dart", kind="desktop")

    shown_d = erow("Today", "Spending and daily guide", first=True) + erow("Recent entries", "Your latest entries") + erow("Coming up", "Plans, entries dated ahead and statement cuts", last=True)
    avail = "".join(
        f'<div class="chooser"><div><b>{n}</b><small>{d}</small></div><span class="ad">+ Add</span></div>' for n, d in cat[3:])
    content = (f'<div class="lab" style="margin:-6px 0 12px">Notices stay visible when needed. Hiding a widget keeps your entries.</div>'
               f'<div class="dg2e"><div class="pane"><div class="th" style="font-size:14px;font-weight:600;margin-bottom:6px">Shown on Overview</div>{shown_d}{btn("Restore default","sec")}</div>'
               f'<div class="pane"><div class="th" style="font-size:14px;font-weight:600;margin-bottom:6px">Add widgets</div>{avail}</div></div>')
    reg("ov-desk-edit", A, "Desktop", "Edit Overview, desktop",
        desktop("Overview", content, "Edit Overview", "Saturday, 3 October 2026",
                acts='<span class="sbtn">Cancel</span><span class="pbtn">Save changes</span>'),
        "Shown and available widgets side by side. Mouse dragging and keyboard Move up and Move down share one order. Saving is per device.",
        NEW8, kind="desktop")


def catalogue():
    """Widget catalogue: every widget in its normal state and its sparse state."""
    sparse = {
        "Today and daily guide": w_today(cap=False),
        "This month": tray("This month", '<div class="kv"><span>Spent so far</span><b class="exp">-167.40</b></div><div class="kv"><span>Income</span><b>No income recorded</b></div><div class="kv"><span>From recorded entries</span><b class="exp">-167.40</b></div>'),
        "Recent entries": tray("Recent entries", '<div class="lab">No entries yet.</div><div class="link">Add your first entry</div>'),
        "Top categories": tray("Top categories", '<div class="lab">No spending recorded this month.</div>'),
        "Card statement": tray("Card statement", '<div class="lab">Choose a card to follow its statement.</div><div class="link">Choose a card</div>'),
        "Coming up": tray("Coming up", '<div class="lab">No known dates in the next six weeks.</div>', aside="<small>Next 6 weeks</small>"),
        "Account balances": tray("Account balances", '<div class="lab">Choose the accounts to show here.</div><div class="link">Choose an account</div>'),
        "Spending over time": tray("Spending over time", '<div class="lab">Your monthly totals appear here once you record spending.</div>'),
        "Savings pocket": tray("Savings pocket", '<div class="lab">Choose a pocket and set a target to see progress.</div><div class="link">Choose a pocket</div>'),
        "Budget watch": tray("Budget watch", '<div class="lab">No budgets yet.</div><div class="link">Add a budget</div>'),
        "Insights": w_insights("history"),
        "Week so far": w_week(),
    }
    normal = {
        "Today and daily guide": w_today(), "This month": w_month(), "Recent entries": w_recent(),
        "Top categories": w_top(), "Card statement": w_card(), "Coming up": w_coming(),
        "Account balances": w_balances(), "Spending over time": w_overtime(), "Savings pocket": w_pocket(),
        "Budget watch": w_budgetwatch(), "Insights": w_insights("shown"), "Week so far": w_week(),
    }
    notes = {
        "Today and daily guide": "Default. Sample monthly cap: S$1,200. Without a cap it offers Set a monthly cap.",
        "Recent entries": "Default. Signs, categories and accounts, then View History.",
        "Coming up": "Default. Plans, entries dated ahead and card cuts in the next six weeks.",
        "This month": "Spent, income and net, transfers excluded.",
        "Budget watch": "Budgets at 80% or more of their limit. Sample limits: Groceries 450, Dining 350, Transport 120. None reach it in October.",
        "Top categories": "Three largest categories this month.",
        "Account balances": "Chosen accounts; pockets counted once.",
        "Card statement": "Payable, this cycle and days to the cut. Not a due date.",
        "Spending over time": "Last 12 months from revision 2 sample history, with a gap stub and a pale incomplete bar.",
        "Insights": "At most two changes with evidence. Normal state uses round 4 sample windows.",
        "Savings pocket": "A target is new; Holiday has none yet, so it asks for one.",
        "Week so far": "Needs three complete weeks; states that instead of guessing.",
    }
    cells = []
    for name in normal:
        cells.append(
            f'<div class="wcell"><h4>{name}</h4><small class="wl">Usual state</small><div class="app wpanel">{normal[name]}</div>'
            f'<small class="wl">Sparse state</small><div class="app wpanel">{sparse[name]}</div><p>{notes[name]}</p></div>')
    return '<div class="wcat">' + "".join(cells) + "</div>"
