from data import *
from s_add import add_sheet, amount_field, expense_fields
from s_money import money_head
from s_settings import settings_phone

F = "fresh"
L = "states"


def build_fresh():
    ov = (overview_head() + tray("Start with an account", '<div class="lab">Add where you keep your money, then record what comes in and goes out.</div>' + btn("Add account"))
          + '<div class="tray today"><div class="lab">Today / 3 October</div><div class="mid" style="margin:6px 0 2px">Nothing recorded today</div><div class="link">Add your first entry</div></div>'
          + tray("Recent entries", '<div class="lab">Your entries will appear here.</div>')
          + tray("Coming up", '<div class="lab">No known dates in the next six weeks.</div>', aside="<small>Next 6 weeks</small>"))
    reg("fr-overview", F, "Fresh install", "Overview, fresh install", phone(ov, "Overview"),
        "A new install with no data. The default widgets each give one next step; unknown spending is never drawn as zero.",
        "New screen (round 8); app/lib/ui/transactions/daily_list/empty_state.dart")

    hi = header("History", "All accounts") + period("October 2026") + seg(["List", "Calendar"], "List") + empty("history", "Record your first entry", "Add an account, then record money coming in or going out.", "Add entry")
    reg("fr-history", F, "Fresh install", "History, fresh install", phone(hi, "History"),
        "Proposed empty copy from the earlier atlas, kept.", "app/lib/ui/transactions/daily_list/empty_state.dart", ["Transactions, fresh install"])

    tr = header("Trends") + seg(["Expense", "Income"], "Expense") + seg(["Month by month", "Year by year"], "Month by month") + period("Nov 2025 - Oct 2026", prev_off=True, next_off=True) + empty("trends", "See where your money goes", "Record an expense to start your monthly picture and breakdown.")
    reg("fr-trends", F, "Fresh install", "Trends, no spending yet", phone(tr, "Trends"),
        "No bars, no zero amounts. Both arrows are off because there is no earlier record.", "app/lib/ui/stats/analysis/analysis_flow.dart", ["Stats, no expenses", "Monthly transactions, empty"])

    cd = header("Groceries", "October 2026", back="Trends", gear=False) + empty("cart", "No Groceries entries in October", "Choose Groceries when you add an entry.")
    reg("fr-category", F, "Fresh install", "Category detail, no entries", phone(cd, "Trends"),
        "A category with no entries in the chosen period.", "app/lib/ui/common/day_sectioned_entry_list.dart", ["Category detail, no entries"])

    bu = money_head("Budgets") + period("October 2026") + empty("gauge", "Give your spending a limit", "Add a budget for one category or all your spending.", "Add budget")
    reg("fr-budgets", F, "Fresh install", "Budgets, fresh install", phone(bu, "Money"),
        "Proposed empty copy, kept.", "app/lib/ui/budgets/budget_list/budgets_flow.dart", ["Budgets, fresh install"])

    bd = header("Dining", "October 2026", back="Budgets", gear=False) + tray("", '<div class="big">S$350.00 left</div><div class="lab">Spent S$0.00 of S$350.00</div><div class="ctrack"><i style="width:0"></i></div>') + empty("dining", "No Dining spending yet this month", "Choose Dining when you add an expense.")
    reg("fr-budget-detail", F, "Fresh install", "Budget detail, no entries", phone(bd, "Money"),
        "A budget with no matching entries this month. Sample limit; here spent is a recorded S$0.00 against a set limit.", "app/lib/ui/budgets/budget_detail/budget_detail_screen.dart", ["Budget detail, no entries"])

    ac = money_head("Accounts") + empty("bank", "Add your first account", "Add where you keep your money: a bank account, cash, a card or a loan.", "Add account")
    reg("fr-accounts", F, "Fresh install", "Accounts, fresh install", phone(ac, "Money"),
        "Proposed empty copy, made specific.", "app/lib/ui/accounts/accounts_screen.dart", ["Accounts, fresh install"])

    pl = money_head("Plans") + empty("repeat", "Make regular entries easier", "Choose Repeat when adding an entry to create a plan.")
    reg("fr-plans", F, "Fresh install", "Plans, fresh install", phone(pl, "Money"),
        "Plans are created only from Repeat in Add entry, so there is no add button here.", "app/lib/ui/settings/plan/plan_list_screen.dart", ["Recurring plans, fresh install"])

    ca = header("Categories", back="Settings", gear=False) + empty("tag", "Name your first category", "Group your income and expenses so Trends and budgets can use them.", "Add category")
    reg("fr-categories", F, "Fresh install", "Categories, fresh install", settings_phone(ca, False),
        "Proposed empty copy, kept.", "app/lib/ui/settings/category/category_list_screen.dart", ["Categories, fresh install"])

    rb = header("Recycle bin", back="Settings", gear=False) + empty("trash", "Nothing in the recycle bin", "Accounts, pockets, categories and entries you remove appear here until you restore or delete them.")
    reg("fr-bin", F, "Fresh install", "Recycle bin, empty", settings_phone(rb, False),
        "Rewritten from the earlier atlas copy to say what appears here.", "app/lib/ui/settings/recycle_bin/recycle_bin_screen.dart", ["Recycle bin, empty"])


def skel_trays(n=3):
    t = '<div class="tray"><div class="skel w4"></div><div class="skel t"></div><div class="skel w8"></div><div class="skel w6"></div></div>'
    return t * n


def load_err(fid, title, page_head, tab, what, code, inv_load, inv_err, form=False, settings=False):
    if form:
        under = page_head
        load_sheet = sheet_head(title, "Cancel", "") + '<div class="center" style="padding:30px 0"><span class="spin l"></span><span class="lab">Loading</span></div>'
        err_sheet = sheet_head(title, "Cancel", "") + btn("Try again") 
        lo = sheet_phone(under, load_sheet, cls="compact", under_cls="short")
        er = sheet_phone(under, err_sheet, cls="compact", under_cls="short", alert=sheet_alert(f"Couldn't load {what}", "StateError: Data unavailable"))
    else:
        mk = (lambda b: settings_phone(b, False).replace('class="app phone ', 'class="app phone compact ')) if settings else (lambda b: phone(b, tab, "compact"))
        lo = mk(page_head + skel_trays()).replace('class="app phone compact ', 'class="app phone ')
        er = mk(page_head + f'<div class="err" role="alert"><b>Couldn\'t load {what}</b><small>StateError: Data unavailable</small></div>' + btn("Try again"))
    reg(fid + "-load", L, "Loading and load errors", f"{title}, loading", lo, "Skeleton trays hold the layout while data loads.", code, [inv_load])
    reg(fid + "-err", L, "Loading and load errors", f"{title}, load error", er,
        "The failed load says what failed and offers Try again. The detail line shows the thrown reason; this text is illustrative.", code, [inv_err])


def build_states():
    # shell
    boot = '<div class="boot"><div class="wordmark">Spend<i>Wise</i></div><span class="spin l"></span></div>'
    reg("sh-loading", L, "App start", "App loading", f'<div class="app phone compact">{statusbar()}{boot}<div class="homebar" style="background:var(--base)"></div></div>',
        "Before the tabs are available.", "app/lib/ui/shell/boot_chrome.dart", ["App loading"])
    fail = ('<div class="boot"><div class="wordmark">Spend<i>Wise</i></div><b style="font-size:18px">Couldn\'t load your data</b>'
            '<div class="lab" style="font-size:12px;text-align:center">Something went wrong loading your data. Please try again.</div><div style="width:100%">' + btn("Retry") + "</div></div>")
    reg("sh-failure", L, "App start", "App load failure", f'<div class="app phone compact">{statusbar()}{fail}<div class="homebar" style="background:var(--base)"></div></div>',
        "The exact recovery copy from the app.", "app/lib/ui/shell/boot_chrome.dart", ["App load failure"])

    H = header("History", "All accounts") + period("October 2026")
    load_err("le-history", "History", H, "History", "your entries", "app/lib/ui/transactions/daily_list/daily_transactions_screen.dart", "Transactions, loading", "Transactions, load error")
    load_err("le-add", "Add entry", overview_head(), None, "the entry form", "app/lib/ui/transactions/entry/entry_form.dart", "Add entry, loading", "Add entry, load error", form=True)
    T = header("Trends") + seg(["Expense", "Income"], "Expense") + seg(["Month by month", "Year by year"], "Month by month")
    load_err("le-trends", "Trends", T, "Trends", "your spending", "app/lib/ui/stats/analysis/analysis_flow.dart", "Stats, loading", "Stats, load error")
    G = header("Groceries", "1-3 October 2026", back="Trends", gear=False)
    load_err("le-category", "Category detail", G, "Trends", "Groceries", "app/lib/ui/stats/category_detail/category_detail_screen.dart", "Groceries, loading", "Groceries, load error")
    B = money_head("Budgets") + period("October 2026")
    load_err("le-budgets", "Budgets", B, "Money", "your budgets", "app/lib/ui/budgets/budget_list/budgets_flow.dart", "Budgets, loading", "Budgets, load error")
    load_err("le-budget-add", "Add budget", money_head("Budgets"), None, "the budget form", "app/lib/ui/budgets/budget_list/budget_form.dart", "Add budget, loading", "Add budget, load error", form=True)
    D = header("Dining", "October 2026", back="Budgets", gear=False)
    load_err("le-budget-detail", "Budget detail", D, "Money", "this budget", "app/lib/ui/budgets/budget_detail/budget_detail_screen.dart", "Dining, loading", "Dining, load error")
    LC = header("Limit changes", "Dining", back="Dining", gear=False)
    load_err("le-budget-limit", "Limit changes", LC, "Money", "the limit history", "app/lib/ui/budgets/budget_detail/budget_limit_screen.dart", "Budget limit, loading", "Budget limit, load error")
    AC = money_head("Accounts")
    load_err("le-accounts", "Accounts", AC, "Money", "your accounts", "app/lib/ui/accounts/accounts_screen.dart", "Accounts, loading", "Accounts, load error")
    load_err("le-account-add", "Add account", AC, None, "the account form", "app/lib/ui/accounts/account_form/account_form.dart", "Add account, loading", "Add account, load error", form=True)
    load_err("le-account-edit", "Edit account", header("DBS Checking", "Checking", back="Money", gear=False), None, "this account", "app/lib/ui/accounts/source_edit/source_edit_form.dart", "Edit account, loading", "Edit account, load error", form=True)
    CA = header("Categories", back="Settings", gear=False)
    load_err("le-categories", "Categories", CA, None, "your categories", "app/lib/ui/settings/category/category_list_screen.dart", "Categories, loading", "Categories, load error", settings=True)
    load_err("le-category-add", "Add category", CA, None, "the category form", "app/lib/ui/settings/category/category_form.dart", "Add category, loading", "Add category, load error", form=True)
    PL = money_head("Plans")
    load_err("le-plans", "Plans", PL, "Money", "your plans", "app/lib/ui/settings/plan/plan_list_screen.dart", "Recurring plans, loading", "Recurring plans, load error")
    load_err("le-plan-edit", "Edit plan", header("Netflix", "Plan", back="Plans", gear=False), None, "this plan", "app/lib/ui/settings/plan/plan_form.dart", "Edit plan, loading", "Edit plan, load error", form=True)
    RB = header("Recycle bin", back="Settings", gear=False)
    load_err("le-bin", "Recycle bin", RB, None, "the recycle bin", "app/lib/ui/settings/recycle_bin/recycle_bin_screen.dart", "Recycle bin, loading", "Recycle bin, load error", settings=True)

    # save failures
    def fail_box(what):
        return sheet_alert(f"Could not save {what}", "Invalid value")
    kinds = '<div class="pick" style="font-weight:600"><span>Everyday money<small>Cash, checking, savings or prepaid</small></span><span class="ck">' + ic("check", "s") + "</span></div>"
    sh = sheet_head("Add account", "Cancel", "") + fld("Name", "DBS Checking") + kinds + fld("Type", "Checking", chevron=True) + fld("Balance today", "5,000.00") + btn("Add account")
    reg("sf-account-add", L, "Save failures", "Add account, save failure", sheet_phone(money_head("Accounts"), sh, under_cls="short", alert=fail_box("account")),
        "The form keeps its values and shows the reason in a transient banner above the sheet. Error detail is illustrative.", "app/lib/ui/accounts/account_form/account_form.dart", ["Add account, save failure"])
    sh = sheet_head("Edit account", "Cancel", "Save") + fld("Name", "DBS Checking") + fld("Kind", "Everyday money / Checking", chevron=True) + setrow("More options", "Net worth and spending rules") 
    reg("sf-account-edit", L, "Save failures", "Edit account, save failure", sheet_phone(money_head("Accounts"), sh, under_cls="short", alert=fail_box("account")),
        "Same pattern.", "app/lib/ui/accounts/source_edit/source_edit_form.dart", ["Edit account, save failure"])
    sh = sheet_head("Edit category", "Cancel", "Save") + fld("Name", "Groceries") + fld("Icon and colour", ic("cart", "s") + "Cart", chevron=True) + setrow("More options", "Count in Trends and budgets, type") 
    reg("sf-category", L, "Save failures", "Edit category, save failure", sheet_phone(header("Categories", back="Settings", gear=False), sh, under_cls="short", alert=fail_box("category")),
        "Same pattern.", "app/lib/ui/settings/category/category_form.dart", ["Edit category, save failure"])
    sh = sheet_head("Edit plan", "Cancel", "") + fld("Name", "Netflix") + amount_field("-19.98", False) + fld("Repeat", "Every month", chevron=True) + fld("First date", "20 October 2026", chevron=True) + btn("Save plan")
    reg("sf-plan", L, "Save failures", "Edit plan, save failure", sheet_phone(money_head("Plans"), sh, under_cls="short", alert=fail_box("plan")),
        "Same pattern.", "app/lib/ui/settings/plan/plan_form.dart", ["Edit plan, save failure"])
    sh = sheet_head("Add budget", "Cancel", "") + fld("Category", "Supermarket", chevron=True) + amount_field("60.00", False, "Monthly limit / SGD") + btn("Save budget")
    reg("sf-budget", L, "Save failures", "Add budget, save failure", sheet_phone(money_head("Budgets"), sh, under_cls="short", alert=fail_box("budget")),
        "Same pattern. Sample limit.", "app/lib/ui/budgets/budget_list/budget_form.dart", ["Add budget, save failure"])
    sh = sheet_head("Default limit", "Cancel", "") + amount_field("350.00", False, "Monthly limit / SGD") + fld("Applies from", "September 2026 onward", chevron=True) + btn("Save")
    reg("sf-limit", L, "Save failures", "Budget limit, save failure", sheet_phone(header("Limit changes", "Dining", back="Dining", gear=False), sh, under_cls="short", alert=fail_box("budget limit")),
        "Same pattern. Sample limit.", "app/lib/ui/budgets/budget_detail/budget_limit_screen.dart", ["Budget limit, save failure"])
