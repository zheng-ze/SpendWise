from data import *
from s_add import amount_field
import tiles

M = "money"


def money_head(tab):
    return header("Money") + seg(["Budgets", "Accounts", "Plans"], tab)


def budgets_body():
    allsp = tray("All spending", '<div class="big">S$1,032.60</div><div class="lab">left of S$1,200.00 this month</div>'
                 '<div class="ctrack"><i style="width:13.95%"></i></div><div class="kv" style="margin-top:4px"><span>Spent so far</span><b>S$167.40</b></div>'
                 '<div class="lab">From 4 October: about S$36.88 a day.</div>' + tiles.forecast_legend())
    cats = tray("Category budgets", tiles.category_budget_rows(), aside="<small>Most used first</small>")
    return money_head("Budgets") + period("October 2026") + allsp + cats + '<div class="reserve"></div>' + fab("Add budget")


def acct_row(name, meta, value, icon, cat="Transfer", owed=False):
    cls = "exp" if owed else "mov"
    return (f'<div class="row"><span class="med" style="--c:var(--action)">{ic(icon)}</span><div class="rc"><b>{name}</b><small>{meta}</small></div>'
            f'<span class="amt {cls}">{value}</span></div>')


def accounts_body(with_tiles=True):
    b = (f'<div class="band three"><div class="lead"><small>Net worth</small><b class="inc">+S${f2(NET_WORTH_NOW)}</b></div>'
         f'<div><small>Assets</small><b>S${f2(ASSETS)}</b></div><div><small>Owed</small><b class="exp">S${f2(AMEX_OWED)}</b></div></div>')
    every = tray("Everyday money", acct_row("DBS Checking", "Checking", "10,869.00", "bank")
                 + acct_row("OCBC Savings", "Savings / includes 2 pockets", "10,350.00", "jar")
                 + '<div class="pocket"><span>Own balance</span><b>1,700.00</b></div><div class="pocket"><span>Emergency Fund</span><b>8,000.00</b></div><div class="pocket"><span>Holiday</span><b>650.00</b></div>')
    cards = tray("Credit cards", acct_row("Amex Card", f"Statement day 15 / this cycle S${f2(AMEX_CYCLE)}", f"-{f2(AMEX_OWED)}", "card", owed=True))
    net_worth = tiles.net_worth_trend() if with_tiles else ""
    utilisation = tiles.card_utilisation() if with_tiles else ""
    return money_head("Accounts") + b + net_worth + every + cards + utilisation + '<div class="reserve"></div>' + fab("Add account")


def plan_rows(attention=False):
    return SEED_PLANS + [GYM_MONTHLY_PLAN] if attention else list(SEED_PLANS)


def plans_body(attention=False, with_tile=True):
    att = notice("Gym membership missed 1 October", "Its category, Fitness, is in the recycle bin.", ["Restore Fitness", "Change category"]) if attention else ""
    rows = plan_rows(attention)
    t = tray("Next up", "".join(daterow(*r) for r in rows), aside=f"<small>{len(rows)} plans</small>")
    cash_flow = tiles.plans_cash_flow(rows) if with_tile else ""
    return money_head("Plans") + att + t + cash_flow + '<div class="lab" style="margin-top:4px">To add a plan, add an entry and choose how often it repeats.</div>'


def acct_page(title, sub, balance, bal_label, entries, extra="", chips_html="", back="Money", menu=True):
    acts = ic("more") if menu else ""
    return (header(title, sub, acts=acts, gear=False, back=back) + chips_html
            + tray("", f'<div class="lab">{bal_label}</div><div class="hero" style="font-size:30px">{balance}</div>{extra}')
            + entries)


DBS_ENTRIES = (
    '<div class="dayh"><b>3 October</b></div>' + row("Monthly salary", "Salary", 3200.00, "Salary")
    + row("To savings", "Moved to OCBC Savings", -500.00, "Transfer", moved=True).replace(">500.00<", ">500.00<")
    + '<div class="dayh"><b>2 October</b></div>' + row("Tekka wet market", "Fresh Market", -18.60, "Fresh Market") + row("Cold Storage", "Groceries", -12.40, "Groceries")
    + '<div class="dayh"><b>25 September</b></div>' + row("Monthly salary", "Salary", 3200.00, "Salary")
    + '<div class="dayh"><b>1 August</b></div>' + row("Opening balance", "Outside Trends and budgets", 5000.00, "Opening balance", moved=True)
)


def build():
    reg("mo-budgets", M, "Budgets", "Money, budgets",
        phone(budgets_body(), "Money", "long"),
        "Sample limits: all spending S$1,200.00, Dining 350, Groceries 450, Transport 120. Spending is seed October: 1,200.00 - 167.40 = 1,032.60 left, over 28 days from 4 October about 36.88 a day. Category caps sit inside the overall cap and are not added to it. Each category bar fills with what is spent; a vertical line marks the month-end forecast (spent so far plus the category's monthly average over the remaining 28 of 31 days, pinned to the right end in the expense colour when over the limit) and a chip says On pace or Over by the amount at this pace. The legend sits in All spending. The compact labelled button keeps end space reserved below the last row." + tiles.sample_note(week=False),
        "app/lib/ui/budgets/budget_list/budgets_flow.dart", ["Stats, budgets"])

    sh = (sheet_head("Add budget", "Cancel", "") + fld("Category", "Supermarket", chevron=True) + amount_field("60.00", True, "Monthly limit / SGD")
          + fld("Applies from", "October 2026", chevron=True) + numpad() + btn("Save budget"))
    reg("mo-budget-add", M, "Budgets", "Add budget",
        sheet_phone(budgets_body(), sh, under_cls="short"),
        "Sample: a S$60.00 monthly limit for Supermarket. A limit can start in any month.",
        "app/lib/ui/budgets/budget_list/budget_form.dart", ["Add budget"])

    bp = (sheet_head("Choose category", "Cancel", "")
          + '<div class="pick dis">All spending<small>Has a budget</small></div><div class="pick dis">Dining<small>Has a budget</small></div>'
          + '<div class="pick dis">Groceries<small>Has a budget</small></div><div class="pick ind" style="font-weight:600">Supermarket<span class="ck">' + ic("check", "s") + '</span></div>'
          + '<div class="pick ind">Fresh Market</div><div class="pick dis">Transport<small>Has a budget</small></div>')
    reg("mo-budget-pick", M, "Budgets", "Budget category picker",
        sheet_phone(budgets_body(), bp, under_cls="short", sheet_cls="content"),
        "All spending and every expense category; rows that already have a budget are shown but cannot be chosen.",
        "app/lib/ui/budgets/budget_list/budget_form.dart", ["Budget category picker"])

    # Dining budget detail with year chart and limit markers
    vals = []
    for m in range(12):
        v = month_value(2026, m)
        if m == 8:
            v = SEPTEMBER_CATEGORY_SPENT["Dining"]
        elif m == 9:
            v = 83.90
        elif v not in (None, "x") and m < 8:
            v = split48(v)[0]
        vals.append(v)
    bars, axis = [], []
    for m, v in enumerate(vals):
        kind = "x" if m > 9 else ("g" if v is None else ("p" if m == 9 else "c"))
        h = "" if kind in ("x", "g") else f' style="height:{v / 500 * 100:.1f}%"'
        limit = f'<s style="position:absolute;left:8%;right:8%;bottom:{350 / 500 * 100:.0f}%;border-top:1.5px dashed var(--text)"></s>' if m >= 8 else ""
        bars.append(f'<div class="b {kind}{" sel" if m == 9 else ""}" style="position:relative"><i{h}></i>{limit}</div>')
        axis.append(f'<span class="{"sel" if m == 9 else ""}">{MSHORT[m][0]}</span>')
    chart = f'<div class="bars mini" style="height:80px">{"".join(bars)}</div><div class="axis mini">{"".join(axis)}</div>'
    detail = (header("Dining", "October 2026", acts="<span>Edit</span>", gear=False, back="Budgets")
              + tray("", '<div class="big">S$266.10 left</div><div class="lab">Spent S$83.90 of S$350.00</div><div class="ctrack" style="--c:var(--dining)"><i style="width:24%"></i></div>')
              + tray("2026 at a glance", chart + '<div class="qual">Dashed marks show the S$350.00 limit from September. August has no records; October is incomplete.</div>')
              + '<div class="tray" style="padding:0 12px">' + setrow("Limit changes", "Default S$350.00 from September 2026") + "</div>"
              + tray("October entries", '<div class="dayh"><b>2 October</b></div>' + row("Dinner with friends", "Amex Card", -28.90, "Dining")
                     + '<div class="dayh"><b>1 October</b></div>' + row("Lunch at Maxwell", "Amex Card", -55.00, "Dining")))
    reg("mo-budget-detail", M, "Budgets", "Budget detail, Dining",
        phone(detail, "Money", "long"),
        "This month first, then the year at a glance. Seed October Dining: 28.90 + 55.00 = 83.90 of the sample 350.00 limit. Earlier 2026 bars use the sample 48% Dining share; September is 120.80 = 96.50 + 24.30. The limit started in September (sample).",
        "app/lib/ui/budgets/budget_detail/budget_detail_screen.dart", ["Dining budget detail"])

    months = "".join(
        f'<div class="kv"><span>{MLONG[m]} 2026</span><b style="{"color:var(--subtext);font-weight:400" if m < 8 else ""}">{"No budget" if m < 8 else "S$350.00"}</b></div>'
        for m in range(12))
    lim = (header("Limit changes", "Dining", gear=False, back="Dining")
           + tray("Default limit", '<div class="kv"><span>From September 2026 onward</span><b>S$350.00</b></div><div class="link">Change default</div>')
           + period("2026", next_off=True) + tray("", months))
    reg("mo-budget-limits", M, "Budgets", "Budget limit changes",
        phone(lim, "Money", "long"),
        "The closed Limit changes row opens this history: the default timeline and any single-month overrides. Sample limits.",
        "app/lib/ui/budgets/budget_detail/budget_limit_screen.dart", ["Budget limit history"])

    sh = (sheet_head("Default limit", "Cancel", "") + amount_field("350.00", True, "Monthly limit / SGD") + fld("Applies from", "September 2026 onward", chevron=True)
          + numpad() + btn("Save"))
    reg("mo-budget-edit-default", M, "Budgets", "Edit default limit",
        sheet_phone(lim, sh, under_cls="short"),
        "Changes the default from a chosen month onward. Sample limit.",
        "app/lib/ui/budgets/budget_detail/budget_limit_screen.dart", ["Edit default budget limit"])

    sh = (sheet_head("October 2026", "Cancel", "") + '<div class="lab" style="margin:2px 0 4px">Only October 2026. Other months keep the default.</div>'
          + amount_field("350.00", True, "Limit for this month / SGD") + numpad() + btn("Save") + btn("Use the default", "quiet"))
    reg("mo-budget-edit-month", M, "Budgets", "Edit one month's limit",
        sheet_phone(lim, sh, under_cls="short"),
        "A one-month override, as the app supports today. Sample limit.",
        "app/lib/ui/budgets/budget_detail/budget_limit_screen.dart", ["Edit September budget limit"])

    reg("mo-budget-delete", M, "Budgets", "Delete budget",
        phone(detail + dialog("Delete the Dining budget?", "Your entries stay as they are. Only the limit is removed.", [("Cancel", ""), ("Delete", "d")]), "Money"),
        "Delete budget is reached from Edit on the budget page. Shared confirmation pattern. The underlying detail uses the sample S$350 limit and revision 2 monthly history with September (120.80) and October Dining amounts.",
        "app/lib/ui/common/delete_confirmation.dart", ["Delete budget confirmation"])

    body = header("Dining", "", gear=False, back="Budgets") + empty("gauge", "This budget was deleted", "It was removed on another screen or device.", "Back to Budgets")
    reg("mo-budget-deleted", M, "Budgets", "Budget deleted elsewhere",
        phone(body, "Money"),
        "Shown when the open budget is deleted elsewhere, on the detail or limit page.",
        "app/lib/ui/budgets/budget_detail/budget_detail_screen.dart; app/lib/ui/budgets/budget_detail/budget_limit_screen.dart", ["Budget deleted"])

    # Accounts
    reg("mo-accounts", M, "Accounts", "Money, accounts",
        phone(accounts_body(), "Money", "long"),
        "Balances through 3 October. Assets 10,869.00 + 10,350.00 = 21,219.00; owed 399.60 on the card; net worth +20,819.40. OCBC Savings already includes its own 1,700.00 and both pockets, counted once. Entries dated ahead (Rent, 8 Nov Cold Storage) are not in today's balances. "
        f"Net worth trend follows the summary band and Card utilisation follows Credit cards: Amex Card {f2(AMEX_OWED)} of a {f2(AMEX_LIMIT)} limit (sample), statement payable {f2(AMEX_OWED)} by {AMEX_DUE_DAY} (sample), closing {AMEX_CLOSE_DAY} October." + tiles.sample_note(week=False),
        "app/lib/ui/accounts/accounts_screen.dart", ["Accounts", "Accounts, expanded pockets"])

    ahead = tray("Dated ahead", daterow("3", "Nov", "Rent", "No category", -1200.00))
    dbs = acct_page("DBS Checking", "Checking", "S$10,869.00", "Balance through 3 October", tray("Entries", DBS_ENTRIES) + ahead)
    reg("mo-dbs", M, "Accounts", "Account, DBS Checking",
        phone(dbs, "Money", "long"),
        "Opening an account shows its own entries. 5,000.00 + 3,200.00 + 3,200.00 - 500.00 - 18.60 - 12.40 = 10,869.00. The seeded Rent on 3 November waits under Dated ahead and is not in today's balance.",
        "app/lib/ui/accounts/accounts_flow.dart; app/lib/ui/transactions/daily_list/daily_transactions_screen.dart", ["DBS Checking"])

    ocbc_entries = tray("Entries", '<div class="dayh"><b>3 October</b></div>' + row("To savings", "Moved from DBS Checking", 500.00, "Transfer", moved=True)
                        + '<div class="dayh"><b>1 August</b></div>' + row("Opening balance", "Own balance / outside Trends and budgets", 1200.00, "Opening balance", moved=True)
                        + row("Opening balance", "Emergency Fund / outside Trends and budgets", 8000.00, "Opening balance", moved=True)
                        + row("Opening balance", "Holiday / outside Trends and budgets", 650.00, "Opening balance", moved=True))
    pockets = ('<div class="kv"><span>Own balance</span><b>1,700.00</b></div><div class="kv"><span>Emergency Fund</span><b>8,000.00</b></div>'
               '<div class="kv"><span>Holiday</span><b>650.00</b></div><div class="link">Manage pockets</div>')
    ch = chips(["All", "Own balance", "Emergency Fund", "Holiday"], "All")
    ocbc = acct_page("OCBC Savings", "Savings", "S$10,350.00", "Total balance, including two pockets", ocbc_entries, extra=pockets, chips_html=ch)
    reg("mo-ocbc", M, "Accounts", "Account, OCBC Savings",
        phone(ocbc, "Money", "long"),
        "Own balance 1,200.00 + 500.00 = 1,700.00; with Emergency Fund 8,000.00 and Holiday 650.00 the total is 10,350.00. The transfer is activity, not income.",
        "app/lib/ui/accounts/accounts_flow.dart", ["OCBC Savings"])

    own_entries = tray("Entries", '<div class="dayh"><b>3 October</b></div>' + row("To savings", "Moved from DBS Checking", 500.00, "Transfer", moved=True)
                       + '<div class="dayh"><b>1 August</b></div>' + row("Opening balance", "Outside Trends and budgets", 1200.00, "Opening balance", moved=True))
    own = acct_page("OCBC Savings", "Savings", "S$1,700.00", "Own balance, without pockets", own_entries, chips_html=chips(["All", "Own balance", "Emergency Fund", "Holiday"], "Own balance"))
    reg("mo-ocbc-own", M, "Accounts", "Account, own balance only",
        phone(own, "Money"),
        "The Own balance chip leaves the pockets out: 1,200.00 + 500.00 = 1,700.00.",
        "app/lib/ui/accounts/accounts_flow.dart", ["OCBC Savings, excluding subpockets"])

    pk = acct_page("Emergency Fund", "Pocket in OCBC Savings", "S$8,000.00", "Balance", tray("Entries", '<div class="dayh"><b>1 August</b></div>' + row("Opening balance", "Outside Trends and budgets", 8000.00, "Opening balance", moved=True)), back="OCBC Savings")
    reg("mo-pocket", M, "Accounts", "Pocket, Emergency Fund",
        phone(pk, "Money"),
        "A pocket opens like an account. Seed: one opening balance of 8,000.00 on 1 August.",
        "app/lib/ui/accounts/accounts_flow.dart", ["Emergency Fund"])

    amex_entries = tray("This cycle, since 15 September", '<div class="dayh"><b>3 October</b></div>' + row("FairPrice groceries", "Supermarket", -42.50, "Supermarket") + row("MRT to work", "Transport", -3.20, "Transport")
                        + '<div class="dayh"><b>2 October</b></div>' + row("Dinner with friends", "Dining", -28.90, "Dining")
                        + '<div class="dayh"><b>1 October</b></div>' + row("Grab home", "Transport", -6.80, "Transport") + row("Lunch at Maxwell", "Dining", -55.00, "Dining")
                        + "".join(f'<div class="dayh"><b>{day} September</b></div>' + row(name, category, value, category) for day, name, category, _, value, _ in SEP_SAMPLE[::-1])
                        + '<div class="dayh"><b>18 September</b></div>' + row("Weekly groceries", "Groceries", -74.20, "Groceries"))
    before = tray("Before 15 September", row("Grab to airport", "12 Sep / Transport", -18.00, "Transport") + row("Birthday dinner", "5 Sep / Dining", -96.50, "Dining"))
    card_extra = (f'<div class="split" style="margin-top:6px"><div><span class="lab">This cycle</span><b>S${f2(AMEX_CYCLE)}</b></div><div><span class="lab">Statement closes</span><b>15 Oct</b></div></div>'
                  '<div class="lab" style="margin-top:6px">Statement day 15 is when the cycle closes, not a payment due date.</div>')
    amex = acct_page("Amex Card", "Credit card", f"S${f2(AMEX_OWED)}", "Owed", amex_entries + before + tray("Dated ahead", daterow("8", "Nov", "Cold Storage", "Groceries", -33.40)), extra=card_extra)
    amex = amex.replace(f'<div class="hero" style="font-size:30px">S${f2(AMEX_OWED)}', f'<div class="hero exp" style="font-size:30px">S${f2(AMEX_OWED)}')
    reg("mo-amex", M, "Accounts", "Card, Amex",
        phone(amex, "Money", "long"),
        "Card statement day only appears for cards. This cycle since 15 September: 74.20 + 74.50 (the 28-30 September sample entries) + 136.40 = 285.10. Owed is every card expense to date: 285.10 + 18.00 + 96.50 = 399.60. 12 days to the cut.",
        "app/lib/ui/accounts/accounts_flow.dart", [])

    menu = ('<div class="menu"><span>' + ic("pencil", "s") + 'Fix balance</span><span>' + ic("gear", "s") + 'Edit account</span><span class="d">' + ic("trash", "s") + "Move to recycle bin</span></div>")
    reg("mo-acct-menu", M, "Accounts", "Account menu",
        phone(dbs + menu, "Money"),
        "The menu on an account page. Fix balance is a repair tool for when the bank figure differs; it sits here, off the main path.",
        "app/lib/ui/accounts/source_edit/source_edit_form.dart")

    sh = (sheet_head("Fix balance", "Cancel", "") + '<div class="lab" style="margin:2px 0 6px">SpendWise shows 10,869.00 for DBS Checking. Enter the balance your bank shows.</div>'
          + amount_field("10,900.00", True, "Balance today / SGD") + '<div class="fhint">Adds an adjustment of +31.00, kept out of Trends and budgets.</div>'
          + numpad() + btn("Fix balance"))
    reg("mo-fix-balance", M, "Accounts", "Fix balance",
        sheet_phone(dbs, sh, under_cls="short"),
        "Sample bank figure 10,900.00; 10,900.00 - 10,869.00 = +31.00 posts an adjustment entry outside analysis, as balance edits do today.",
        "app/lib/ui/accounts/source_edit/source_edit_form.dart")

    kinds = [("Everyday money", "Cash, checking, savings or prepaid"), ("Credit card", "Asks for the statement day"),
             ("Investments and insurance", "Tracked, not spent from"), ("Loan or overdraft", "Money you owe")]

    def kind_list(sel):
        return "".join(
            f'<div class="pick" style="{"font-weight:600" if k == sel else ""}"><span>{k}<small>{d}</small></span>{"<span class=ck>" + ic("check","s") + "</span>" if k == sel else ""}</div>'
            for k, d in kinds)
    sh = (sheet_head("Add account", "Cancel", "") + fld("Name", "Car loan") + '<div class="setlab">What kind of account?</div>' + kind_list("Loan or overdraft")
          + seg(["Loan", "Overdraft"], "Loan", "sm") + fld("Owed today", "18,400.00") + toggle_fld("Payments into it count as spending", True)
          + '<div class="fhint">You can change this later in the account\'s More options.</div>' + btn("Add account"))
    reg("mo-add-account", M, "Accounts", "Add account, four kinds",
        sheet_phone(accounts_body(), sh, under_cls="tiny"),
        "Four plain kinds replace the ten types; the exact type is one tap deeper. Owed today (Balance today for others) posts the opening-balance entry outside analysis. Loans and overdrafts turn on Payments into it count as spending by default. Car loan and 18,400.00 are samples.",
        "app/lib/ui/accounts/account_form/account_form.dart", ["Add account"])

    sh = (sheet_head("Add account", "Cancel", "") + fld("Name", "Amex Card") + '<div class="setlab">What kind of account?</div>' + kind_list("Credit card")
          + fld("Statement day", "15", chevron=True) + fld("Owed today", "0.00") + btn("Add account"))
    reg("mo-add-card", M, "Accounts", "Add account, credit card",
        sheet_phone(accounts_body(), sh, under_cls="short"),
        "Choosing Credit card asks for the statement day. Seed card: Amex Card, statement day 15.",
        "app/lib/ui/accounts/account_form/account_form.dart", ["Add card account"])

    tp = sheet_head("Everyday money", "Back", "") + '<div class="lab" style="margin:2px 0 4px">Which type is it?</div>' + "".join(
        f'<div class="pick" style="{"font-weight:600" if t == "Checking" else ""}">{t}{"<span class=ck>" + ic("check","s") + "</span>" if t == "Checking" else ""}</div>'
        for t in ["Cash", "Checking", "Savings", "Prepaid", "Other"])
    reg("mo-type-pick", M, "Accounts", "Exact account type",
        sheet_phone(accounts_body(), tp, under_cls="short", sheet_cls="content"),
        "One tap deeper than the kind. Everyday money holds Cash, Checking, Savings, Prepaid and Other; the other kinds hold Card, Investment and Insurance, and Loan and Overdraft.",
        "app/lib/ui/common/pickers/account_type_picker.dart", ["Account type picker"])

    days = '<div class="cal" style="gap:5px">' + "".join(f'<span class="{"sel" if d == 15 else ""}" style="border:1px solid var(--edge)">{d}</span>' for d in range(1, 29)) + "</div>"
    sp = sheet_head("Statement day", "Cancel", "Done") + '<div class="lab" style="margin:2px 0 8px">The day each statement cycle closes, from 1 to 28.</div>' + days
    reg("mo-statement-pick", M, "Accounts", "Statement day picker",
        sheet_phone(accounts_body(), sp, under_cls="", sheet_cls="content"),
        "Days 1 to 28, so every month has the day.",
        "app/lib/ui/common/statement_day_picker.dart", ["Card statement day picker"])

    sh = (sheet_head("Add pocket", "Cancel", "") + fld("Name", "Holiday") + fld("Inside", "OCBC Savings", chevron=True) + fld("Balance today", "650.00")
          + '<div class="fhint">A pocket sets money aside inside its account. The account total still counts it once.</div>' + btn("Add pocket"))
    reg("mo-add-pocket", M, "Accounts", "Add pocket",
        sheet_phone(ocbc, sh, under_cls="short"),
        "From Manage pockets on an everyday account. Seed pocket: Holiday, 650.00 in OCBC Savings.",
        "app/lib/ui/accounts/account_form/account_form.dart", ["Add subpocket"])

    pp = (sheet_head("Inside which account?", "Cancel", "") + '<div class="pick">DBS Checking</div>'
          + '<div class="pick" style="font-weight:600">OCBC Savings<span class="ck">' + ic("check", "s") + "</span></div>"
          + '<div class="lab" style="margin-top:8px">Cards cannot hold pockets.</div>')
    reg("mo-pocket-parent", M, "Accounts", "Pocket account picker",
        sheet_phone(ocbc, pp, under_cls="short", sheet_cls="content"),
        "Active everyday accounts only.",
        "app/lib/ui/accounts/account_form/account_form.dart", ["Subpocket parent picker"])

    mo = ('<div class="setlab">More options</div>' + toggle_fld("Include in net worth", True, "Turn off for money you hold for someone else.")
          + toggle_fld("Payments into it count as spending", False, "On by default for loans and overdrafts."))
    sh = (sheet_head("Edit account", "Cancel", "Save") + fld("Name", "DBS Checking") + fld("Kind", "Everyday money / Checking", chevron=True)
          + mo + btn("Move to recycle bin", "danger"))
    reg("mo-edit-account", M, "Accounts", "Edit account, More options open",
        sheet_phone(dbs, sh, under_cls="short"),
        "Accounting switches live under More options, drawn open; it starts closed. Balance changes go through Fix balance.",
        "app/lib/ui/accounts/source_edit/source_edit_form.dart", ["Edit account"])

    sh = (sheet_head("Edit account", "Cancel", "Save") + fld("Name", "Amex Card") + fld("Kind", "Credit card", chevron=True) + fld("Statement day", "15", chevron=True)
          + setrow("More options", "Net worth and spending rules") + btn("Move to recycle bin", "danger"))
    reg("mo-edit-card", M, "Accounts", "Edit card",
        sheet_phone(amex, sh, under_cls="short"),
        "The statement day stays editable; More options is closed.",
        "app/lib/ui/accounts/source_edit/source_edit_form.dart", ["Edit card account"])

    sh = (sheet_head("Edit pocket", "Cancel", "Save") + fld("Name", "Emergency Fund") + fld("Inside", "OCBC Savings")
          + '<div class="setlab">More options</div>' + toggle_fld("Money moved in counts as spending", False, "Turn on to treat transfers into this pocket as spending in Trends.")
          + btn("Move to recycle bin", "danger"))
    reg("mo-edit-pocket", M, "Accounts", "Edit pocket",
        sheet_phone(pk, sh, under_cls="short"),
        "The pocket keeps the existing per-account transfer rule under More options.",
        "app/lib/ui/accounts/source_edit/source_edit_form.dart", ["Edit subpocket"])

    reg("mo-delete-account", M, "Accounts", "Move account to recycle bin",
        phone(dbs + dialog("Move DBS Checking to the recycle bin?", "Its entries stay. You can restore it from Settings, Recycle bin.", [("Cancel", ""), ("Move", "d")]), "Money"),
        "Archives the account into the existing Recycle bin.",
        "app/lib/ui/common/delete_confirmation.dart", ["Delete account confirmation"])

    reg("mo-delete-pocket", M, "Accounts", "Move pocket to recycle bin",
        phone(ocbc + dialog("Move Holiday to the recycle bin?", "Its entries stay. You can restore it from Settings, Recycle bin.", [("Cancel", ""), ("Move", "d")]), "Money"),
        "Same pattern for a pocket.",
        "app/lib/ui/common/delete_confirmation.dart", ["Delete subpocket confirmation"])

    # Plans
    reg("mo-plans", M, "Plans", "Money, plans",
        phone(plans_body(), "Money"),
        "Seeded plans sorted by next date: Netflix -19.98 on 20 October (Amex Card) and Monthly salary +3,200.00 on 25 October (DBS Checking). Plans are created only through Repeat in Add entry. Plans cash flow follows Next up: the spendable balance of " + f2(DBS_CHECKING + OCBC_OWN_BALANCE) + " (DBS Checking plus OCBC Savings own balance) plus Monthly salary on 25 October; Netflix is charged to Amex and does not move it.",
        "app/lib/ui/settings/plan/plan_list_screen.dart", ["Recurring plans"])

    reg("mo-plans-attention", M, "Plans", "Plans, a plan needs attention",
        phone(plans_body(True), "Money"),
        "Sample: Gym membership (-98.00, Fitness) could not add its 1 October entry because Fitness is in the recycle bin. The notice states the reason and one fix, and stays until fixed. Plans cash flow follows Next up and counts the Gym membership plan on 1 November (" + sm(GYM_MONTHLY_PLAN[4]) + ", charged to " + GYM_PLAN_ACCOUNT + ", sample) alongside Monthly salary; Netflix is charged to Amex and does not move it.",
        "app/lib/ui/settings/plan/plan_list_screen.dart; app/lib/ui/shell/banner_state.dart")

    pdet = (header("Netflix", "Plan", gear=False, back="Plans", acts="")
            + tray("", '<div class="big exp">-S$19.98</div><div class="lab">Every month</div>'
                   '<div class="kv" style="margin-top:6px"><span>Next</span><b>20 October 2026</b></div><div class="kv"><span>Account</span><b>Amex Card</b></div>'
                   '<div class="kv"><span>Category</span><b>Dining</b></div><div class="kv"><span>Started</span><b>20 October 2026</b></div>'
                   '<div class="kv"><span>Last added</span><b>Not yet</b></div><div class="kv"><span>Ends</span><b>Never</b></div>')
            + btn("Edit plan") + btn("Delete plan", "danger"))
    reg("mo-plan-detail", M, "Plans", "Plan detail",
        phone(pdet, "Money"),
        "Last added is the only trace of occurrence matching a user needs. The seeded Netflix plan starts on 20 October, so nothing has been added yet.",
        "app/lib/ui/settings/plan/plan_list_screen.dart", ["Recurring plans, delete controls"])

    def plan_sheet(ends):
        e = fld("Ends", "Never", chevron=True) if not ends else fld("Ends", "On a date", chevron=True) + fld("End date", "20 October 2027", chevron=True)
        return (sheet_head("Edit plan", "Cancel", "") + fld("Name", "Netflix") + amount_field("-19.98", False)
                + fld("Account", ic("lock", "s") + "Amex Card", "locked") + fld("Repeat", "Every month", chevron=True) + fld("First date", "20 October 2026", chevron=True)
                + e + btn("Save plan"))
    reg("mo-plan-edit", M, "Plans", "Edit plan",
        sheet_phone(pdet, plan_sheet(False), under_cls="short"),
        "Amount, repeat and dates are editable; the account stays as set.",
        "app/lib/ui/settings/plan/plan_form.dart", ["Edit recurring plan"])

    reg("mo-plan-end", M, "Plans", "Edit plan, end date",
        sheet_phone(pdet, plan_sheet(True), under_cls="short"),
        "Choosing On a date reveals the end date. Sample end date.",
        "app/lib/ui/settings/plan/plan_form.dart", ["Edit plan, end date"])

    reg("mo-plan-delete", M, "Plans", "Delete plan",
        phone(pdet + dialog("Delete the Netflix plan?", "Entries it already added stay in History.", [("Cancel", ""), ("Delete", "d")]), "Money"),
        "Shared confirmation pattern.",
        "app/lib/ui/common/delete_confirmation.dart", ["Delete recurring plan"])

    # Desktop
    bl = budgets_body().replace(fab("Add budget"), "").replace(money_head("Budgets"), "")
    right = detail.replace(header("Dining", "October 2026", acts="<span>Edit</span>", gear=False, back="Budgets"),
                           '<div class="th" style="font-size:18px;font-weight:600;display:flex;justify-content:space-between;margin-bottom:8px"><span>Dining</span><span class="link" style="margin:0">Edit</span></div>')
    reg("mo-desk-budgets", M, "Desktop", "Budgets, desktop",
        desktop("Budgets", f'<div class="dg2e"><div>{bl}</div><div class="pane raised">{right}</div></div>', "Budgets", "October 2026",
                acts=f'<span class="sbtn">{ic("plus","s")}Add budget</span><span class="pbtn">{ic("plus","s")}Add entry</span>'),
        "Budgets, Accounts and Plans each have a sidebar place on desktop. The selected budget opens beside the list. Same sample limits and seed spending; the category bars carry the month-end forecast line and chip as on the phone.",
        "app/lib/ui/budgets/budget_list/budgets_flow.dart", kind="desktop")

    al = accounts_body().replace(fab("Add account"), "").replace(money_head("Accounts"), "")
    amex_side = amex.replace(header("Amex Card", "Credit card", acts=ic("more"), gear=False, back="Money"),
                             '<div class="th" style="font-size:18px;font-weight:600;display:flex;justify-content:space-between;margin-bottom:8px"><span>Amex Card</span><span class="link" style="margin:0">Edit</span></div>')
    reg("mo-desk-accounts", M, "Desktop", "Accounts with card page, desktop",
        desktop("Accounts", f'<div class="dg2e"><div>{al}</div><div class="pane raised">{amex_side}</div></div>', "Accounts", "Balances through 3 October 2026",
                acts=f'<span class="sbtn">{ic("plus","s")}Add account</span><span class="pbtn">{ic("plus","s")}Add entry</span>'),
        "The account page opens beside the list. Parent totals include pockets once; the card shows payable, this cycle and its statement cut separately. Net worth trend and Card utilisation sit in the list column, as on the phone.",
        "app/lib/ui/accounts/accounts_screen.dart; app/lib/ui/shell/app_shell.dart", ["Accounts, macOS"], kind="desktop")

    pl = plans_body().replace(money_head("Plans"), "")
    pd = pdet.replace(header("Netflix", "Plan", gear=False, back="Plans", acts=""), '<div class="th" style="font-size:18px;font-weight:600;margin-bottom:8px">Netflix</div>')
    reg("mo-desk-plans", M, "Desktop", "Plans, desktop",
        desktop("Plans", f'<div class="dg2e"><div>{pl}</div><div class="pane raised">{pd}</div></div>', "Plans", "Sorted by next date"),
        "The plan list with the selected plan beside it. Seeded plans only; Plans cash flow below the list follows them.",
        "app/lib/ui/settings/plan/plan_list_screen.dart", kind="desktop")
