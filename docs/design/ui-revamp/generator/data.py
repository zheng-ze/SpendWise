"""Seed records, labelled sample history and shared screen pieces."""
from comp import *

FRAMES = []  # registry of every drawn frame


def reg(fid, area, group, title, html, caption, code, inv=(), kind="phone"):
    FRAMES.append(dict(id=fid, area=area, group=group, title=title, html=html, caption=caption,
                       code=code, inv=list(inv), kind=kind))


# ---------- seed (today = Saturday 3 October 2026) ----------
OCT = [
    (3, "Monthly salary", "Salary", "DBS Checking", 3200.00, False),
    (3, "To savings", "Transfer", "DBS Checking to OCBC Savings", 500.00, True),
    (3, "FairPrice groceries", "Supermarket", "Amex Card", -42.50, False),
    (3, "MRT to work", "Transport", "Amex Card", -3.20, False),
    (2, "Dinner with friends", "Dining", "Amex Card", -28.90, False),
    (2, "Tekka wet market", "Fresh Market", "DBS Checking", -18.60, False),
    (2, "Cold Storage", "Groceries", "DBS Checking", -12.40, False),
    (1, "Grab home", "Transport", "Amex Card", -6.80, False),
    (1, "Lunch at Maxwell", "Dining", "Amex Card", -55.00, False),
]
SEP_SEED = [
    (25, "Monthly salary", "Salary", "DBS Checking", 3200.00, False),
    (18, "Weekly groceries", "Groceries", "Amex Card", -74.20, False),
    (12, "Grab to airport", "Transport", "Amex Card", -18.00, False),
    (5, "Birthday dinner", "Dining", "Amex Card", -96.50, False),
]
SEP_SAMPLE = [
    (28, "Lunch near the office", "Dining", "Amex Card", -24.30, False),
    (29, "Grocery top-up", "Groceries", "Amex Card", -31.80, False),
    (30, "Grab to meeting", "Transport", "Amex Card", -18.40, False),
]
SEP = sorted(SEP_SEED + SEP_SAMPLE, key=lambda entry: -entry[0])
DOW = {3: "Saturday", 2: "Friday", 1: "Thursday", 30: "Wednesday", 29: "Tuesday", 28: "Monday", 25: "Friday", 18: "Friday", 12: "Saturday", 5: "Saturday"}

# Sample monthly spending history carried from Harbour glass dark revision 2 (rounds 6-8).
MONTHS = [760, 890, 735, 760, 790, 835, 780, 805, 765, 795, 820, 940,
          815, 945, 800, 820, 835, 895, 845, 865, 830, 850, 880, 1000,
          855, 995, 845, 875, 860, 940, 900, None, 263.20, 167.40]
SAMPLE_MONTHLY_SALARY = 3200.00
SAMPLE_COMPLETE_MONTHS = [(2025, 10), (2025, 11)] + [(2026, month) for month in range(7)]
COMPLETE_MONTHS = SAMPLE_COMPLETE_MONTHS + [(2026, 8)]
BUDGET_LIMITS = {"Dining": 350, "Groceries": 450, "Transport": 120}
PARENT_CATEGORY = {"Supermarket": "Groceries", "Fresh Market": "Groceries"}
INSIGHT_USUAL_START = {"Groceries": 45.00, "Dining": 58.00}
GROCERIES_INSIGHT_WINDOWS = (40.00, 50.00, 45.00)
assert sum(GROCERIES_INSIGHT_WINDOWS) / 3 == INSIGHT_USUAL_START["Groceries"]
WEEKDAY_SHARES = [10, 11, 12, 13, 16, 22, 16]
assert sum(WEEKDAY_SHARES) == 100

DBS_CHECKING = 10869.00
OCBC_OWN_BALANCE = 1700.00
OCBC_SAVINGS = 10350.00
AMEX_LIMIT = 5000.00
AMEX_DUE_DAY = "5 November"
AMEX_CLOSE_DAY = 15
SPENDABLE_ACCOUNTS = {"DBS Checking", "OCBC Savings"}

NETFLIX_PREVIOUS_PRICE = 17.98
GYM_MONTHLY_PLAN = ("1", "Nov", "Gym membership", "Every month / Needs attention", -98.00)
NET_WORTH_SAMPLE_NOV_TO_JUL = [8240.00, 9150.00, 10380.00, 11020.00, 11960.00, 12610.00, 13240.00, 13780.00, 14300.00]
HELD_IMPORT = ("NTUC FP 0210", 14.30, "2 Oct")
SYNC_PAUSED_ACCOUNT = "OCBC Savings"
SYNC_LAST_DAY = "1 Oct"

MSHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
MLONG = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]


def month_value(year, m):
    i = (year - 2024) * 12 + m
    if i < 0 or i >= len(MONTHS):
        return "x"
    return MONTHS[i]


def spread(end_year, end_month, selected=None, letters=True, fn=None, maxv=1000.0):
    """12-month spread ending at end_month (0-based). Returns items for month_bars.
    fn(year, month, total) maps a month total to the plotted value (category trends)."""
    items = []
    for k in range(11, -1, -1):
        y, m = end_year, end_month - k
        while m < 0:
            m += 12
            y -= 1
        v = month_value(y, m)
        lab = MSHORT[m][0] if letters else MSHORT[m]
        key = (y, m)
        if v == "x":
            items.append((lab, None, "x", False))
            continue
        if v is None:
            items.append((lab, None, "g", key == selected))
            continue
        if fn:
            v = fn(y, m, v)
        kind = "p" if key == (2026, 9) else "c"
        items.append((lab, v * 1000.0 / maxv, kind, key == selected))
    return items


def split48(total):
    cents = round(total * 100)
    d = round(cents * 0.48)
    g = round(cents * 0.36)
    return d / 100, g / 100, (cents - d - g) / 100


def expense_entries(entries):
    return [(day, name, category, account, -value) for day, name, category, account, value, moved in entries if value < 0 and not moved]


def category_spend(entries):
    totals = {name: 0.0 for name in BUDGET_LIMITS}
    for _, _, category, _, value in expense_entries(entries):
        totals[PARENT_CATEGORY.get(category, category)] += value
    return {name: round(value, 2) for name, value in totals.items()}


OCTOBER_CATEGORY_SPENT = category_spend(OCT)
SEPTEMBER_CATEGORY_SPENT = category_spend(SEP)
OCTOBER_SPENT = round(sum(OCTOBER_CATEGORY_SPENT.values()), 2)
SEPTEMBER_SPENT = round(sum(SEPTEMBER_CATEGORY_SPENT.values()), 2)
assert OCTOBER_SPENT == MONTHS[-1] == 167.40
assert round(-sum(entry[4] for entry in SEP_SAMPLE), 2) == 74.50
assert SEPTEMBER_SPENT == 263.20


assert MONTHS[-2] == SEPTEMBER_SPENT


def amex_expenses(entries):
    return [entry for entry in expense_entries(entries) if entry[3] == "Amex Card"]


AMEX_OWED = round(sum(entry[4] for entry in amex_expenses(SEP + OCT)), 2)
AMEX_CYCLE = round(sum(entry[4] for entry in amex_expenses(OCT) + [e for e in amex_expenses(SEP) if e[0] >= AMEX_CLOSE_DAY]), 2)
ASSETS = round(DBS_CHECKING + OCBC_SAVINGS, 2)
NET_WORTH_NOW = round(ASSETS - AMEX_OWED, 2)


# ---------- shared rows ----------

def today_rows(prefix="Today / "):
    out = []
    for d, n, c, a, v, mv in OCT[:4]:
        meta = f"{prefix}{'Transfer / DBS to OCBC' if mv else c + ' / ' + a}"
        out.append(row(n, meta, v, c, moved=mv))
    return "".join(out)


def day_groups(entries, mon="October", skip=(), totals=True):
    out = []
    cards = []
    days = []
    for e in entries:
        if e[0] not in days:
            days.append(e[0])
    for d in days:
        es = [e for e in entries if e[0] == d and e[1] not in skip]
        net = sum(e[4] for e in es if not e[5])
        tot = f'<span class="amt {kind_of(net)}" aria-label="Day total">{sm(net)}</span>' if totals else ""
        group = [f'<div class="dayh"><b>{DOW.get(d, "")} {d} {mon}</b>{tot}</div>']
        for dd, n, c, a, v, mv in es:
            meta = "Transfer / DBS Checking to OCBC Savings" if mv else f"{c} / {a}"
            group.append(row(n, meta, v, c, moved=mv))
        content = "".join(group)
        out.append(content)
        cards.append(f'<div class="light-card day-card">{content}</div>')
    return light_sections("".join(cards), "".join(out))


def band(net, spent, income, moved, lead_label="Net"):
    return (
        f'<div class="band"><div class="lead"><small>{lead_label}</small><b class="{kind_of(net)}">{sm(net, True)}</b></div>'
        f'<div><small>Spent</small><b class="exp">{sm(-spent)}</b></div>'
        f'<div><small>Income</small><b class="inc">{sm(income)}</b></div>'
        f'<div><small>Moved</small><b>{f2(moved)}</b></div></div>'
    )


# ---------- Overview widgets ----------

def w_today(cap=True, desktop=False):
    guide = ('<div class="guide">Daily guide: about S$39</div><div class="lab">From your S$1,200 monthly cap.</div>' if cap else
             '<div class="lab" style="margin-top:6px">Set a monthly cap to see a daily guide.</div><div class="link">Set a monthly cap</div>')
    return f'<div class="tray today"><div class="lab">Today / 3 October</div><div class="hero">S$45.70</div>{guide}</div>'


def w_month():
    return tray("This month", (
        '<div class="kv"><span>Spent so far</span><b class="exp">-167.40</b></div>'
        '<div class="kv"><span>Income</span><b class="inc">+3,200.00</b></div>'
        '<div class="kv"><span>Net from recorded entries</span><b class="inc">+3,032.60</b></div>'
        '<div class="lab" style="margin-top:6px">1-3 October / Transfers excluded</div>'))


def w_recent(n=4):
    return tray("Recent entries", today_rows() + '<div class="link">View History' + ic("right", "s") + "</div>")


COMING = [
    ("15", "Oct", "Amex statement closes", f"This cycle so far: S${f2(AMEX_CYCLE)}", None),
    ("20", "Oct", "Netflix", "Plan / Amex Card", -19.98),
    ("25", "Oct", "Monthly salary", "Plan / DBS Checking", 3200.00),
    ("3", "Nov", "Rent", "Dated ahead / DBS Checking", -1200.00),
    ("8", "Nov", "Cold Storage", "Dated ahead / Amex Card", -33.40),
]
SEED_PLANS = [(day, month, name, meta.replace("Plan / ", "Every month / "), value)
              for day, month, name, meta, value in COMING if meta.startswith("Plan / ")]
GYM_PLAN_ACCOUNT = "DBS Checking"
PLAN_ACCOUNT = {"Netflix": "Amex Card", "Monthly salary": "DBS Checking", "Gym membership": GYM_PLAN_ACCOUNT}


def coming_rows(rows=COMING):
    out = []
    for d, m, n, meta, v in rows:
        if v is None:
            out.append(f'<div class="row"><div class="date"><b>{d}</b><small>{m}</small></div><div class="rc"><b>{n}</b><small>{meta}</small></div><span class="amt mov">{ic("statement","s")}</span></div>')
        else:
            out.append(daterow(d, m, n, meta, v))
    return "".join(out)


def w_coming():
    return tray("Coming up", coming_rows(), aside="<small>Next 6 weeks</small>")


def w_top():
    return tray("Top categories", (
        '<div class="lab" style="margin-bottom:4px">October so far</div>'
        + cattrack("Dining", 83.90, 100, "dining")
        + cattrack("Groceries", 73.50, 73.50 / 83.90 * 100, "groceries")
        + cattrack("Transport", 10.00, 10 / 83.90 * 100, "transport")
        + '<div class="link">Open Trends' + ic("right", "s") + "</div>"))


def w_card():
    return tray("Card statement", (
        f'<div class="split"><div><span class="lab">Payable</span><b>S${f2(AMEX_OWED)}</b></div><div><span class="lab">To statement cut</span><b>12 days</b></div></div>'
        f'<div class="lab" style="margin-top:8px">Amex Card / closes 15 October</div><div class="kv"><span>This cycle</span><b>S${f2(AMEX_CYCLE)}</b></div>'))


def w_balances():
    return tray("Account balances", (
        '<div class="kv"><span style="color:var(--text);font-weight:600">OCBC Savings</span><b>10,350.00</b></div>'
        '<div class="lab">Own balance and two pockets, counted once</div>'
        '<div class="pocket" style="padding-left:0"><span>Own balance</span><b>1,700.00</b></div>'
        '<div class="pocket" style="padding-left:0"><span>Emergency Fund</span><b>8,000.00</b></div>'
        '<div class="pocket" style="padding-left:0"><span>Holiday</span><b>650.00</b></div>'))


def w_overtime():
    return tray("Spending over time", (
        '<div class="lab">Nov 2025 - Oct 2026</div>'
        + month_bars(spread(2026, 9), "mini")
        + '<div class="qual">August has no records; October is incomplete.</div>'
        + '<div class="link">Open Trends' + ic("right", "s") + "</div>"))


def w_pocket():
    return tray("Savings pocket", (
        '<div class="kv"><span>Holiday pocket</span><b>S$650.00</b></div>'
        '<div class="lab" style="margin-top:6px">Set a target to see your progress.</div><div class="link">Set target</div>'))


def insight_gap(category):
    return round(OCTOBER_CATEGORY_SPENT[category] - INSIGHT_USUAL_START[category], 2)


def insight_card(subject, category):
    return (f'<div class="ins"><div class="t"><b>{subject} S${f2(insight_gap(category))} higher than your usual start.</b><span class="x">{ic("close","s")}</span></div>'
            '<small>1-3 Oct against the same days in July, August and September</small><div class="link" style="margin-top:4px">See comparison</div></div>')


def w_insights(state="history"):
    if state == "history":
        body = ('<div class="lab" style="color:var(--text);font-weight:600">More daily history needed.</div>'
                '<div class="lab" style="margin-top:3px">Keep adding entries to compare the same days in earlier months.</div>')
    else:
        body = insight_card("Groceries are", "Groceries") + insight_card("Dining is", "Dining")
    return tray("Insights", body)


def w_week():
    return tray("Week so far", (
        '<div class="lab" style="color:var(--text);font-weight:600">More daily history needed.</div>'
        '<div class="lab" style="margin-top:3px">Record more entries over the last three weeks to compare this week fairly.</div>'))


def overview_head(edit=True):
    acts = '<span>Edit Overview</span>' if edit else ""
    return header("Overview", "Saturday, 3 October", acts)
