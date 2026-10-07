from data import *
import tiles

H = "history"
T = "trends"
SEPTEMBER_WEEK_SPENT = round(-sum(entry[4] for entry in SEP_SAMPLE), 2)
BIGGEST_ENTRIES_NOTE = ", ".join(f2(entry[4]) for entry in sorted(tiles.october_expenses(), key=lambda entry: entry[4], reverse=True)[:3])
TREND_TILES_NOTE = (" Category movers, Day-of-week pattern, Fixed vs flexible and Savings rate follow the breakdown and cover Nov 2025 - Oct 2026 whichever month is selected."
                    + tiles.sample_note(week=False))


def week_strip(weeks, maxv):
    cells = []
    for start, v, state in weeks:
        if state == "ahead":
            bar, val = '<div class="wb"></div>', "<b style='color:var(--subtext);font-weight:400'>Ahead</b>"
        elif v is None:
            bar, val = '<div class="wb"><i class="g"></i></div>', "<b>None</b>"
        else:
            bar = f'<div class="wb"><i style="height:{max(4, v / maxv * 100):.0f}%"></i></div>'
            val = f"<b>S${f2(v)}</b>"
        cells.append(f"<div>{bar}{val}<small>{start}</small></div>")
    return '<div class="wk">' + "".join(cells) + "</div>"


def history_oct(skip=(), band_override=None):
    b = band_override or band(3032.60, 167.40, 3200.00, 500.00)
    spent = -sum(v for _, name, _, _, v, moved in OCT if name not in skip and v < 0 and not moved) + SEPTEMBER_WEEK_SPENT
    wk = tray("By week", week_strip([("28 Sep", spent, ""), ("5 Oct", None, "ahead"), ("12 Oct", None, "ahead"), ("19 Oct", None, "ahead"), ("26 Oct", None, "ahead")], SEPTEMBER_WEEK_SPENT + OCTOBER_SPENT),
              aside="<small>Spending, weeks start Monday</small>")
    return (header("History", "All accounts") + period("October 2026") + seg(["List", "Calendar"], "List")
            + f'<div class="search">{ic("search","s")}Search entries</div>' + b + wk + tiles.biggest_entries() + tiles.by_account() + day_groups(OCT, skip=skip))


def build_history():
    reg("hi-oct", H, "Register", "History, October list",
        phone(history_oct(), "History", "long"),
        "All nine seeded October entries, newest first, with signed day totals: 3 Oct +3,154.30 (the 500.00 transfer is Moved and stays neutral), 2 Oct -59.90, 1 Oct -61.80. The band leads with the signed net +S$3,032.60 = 3,200.00 - 167.40. The 28 September week counts the sample entries of 28-30 September (74.50) and 1-3 October (167.40), 241.90 together; later weeks say Ahead. Biggest entries lists October's three largest expenses (" + BIGGEST_ENTRIES_NOTE + "); By account splits the 167.40 across DBS Checking, OCBC Savings and Amex Card with each share of spending. Full scroll shown.",
        "app/lib/ui/transactions/daily_list/daily_transactions_screen.dart", ["Transactions, daily"])

    sep_band = band(SAMPLE_MONTHLY_SALARY - SEPTEMBER_SPENT, SEPTEMBER_SPENT, SAMPLE_MONTHLY_SALARY, 0.00)
    wk = tray("By week", week_strip([("31 Aug", 96.50, ""), ("7 Sep", 18.00, ""), ("14 Sep", 74.20, ""), ("21 Sep", None, ""), ("28 Sep", SEPTEMBER_WEEK_SPENT + OCTOBER_SPENT, "")], SEPTEMBER_WEEK_SPENT + OCTOBER_SPENT),
              aside="<small>Spending, weeks start Monday</small>")
    body = (header("History", "All accounts") + period("September 2026") + seg(["List", "Calendar"], "List")
            + f'<div class="search">{ic("search","s")}Search entries</div>' + sep_band + wk + day_groups(SEP, mon="September"))
    reg("hi-sep", H, "Register", "History, September with week totals",
        phone(body, "History", "long"),
        "September: spent 96.50 + 18.00 + 74.20 + 24.30 + 31.80 + 18.40 = 263.20, income +3,200.00, net +2,936.80; the last three entries (28-30 September, 74.50) are samples. Weeks keep their full range, so the 28 September week also counts 1-3 October: 74.50 + 167.40 = 241.90. A week with no records says None. Tapping a week scrolls the list to it.",
        "app/lib/ui/transactions/monthly/monthly_transactions_view.dart", ["Transactions, expanded month"])

    cal = ['<div class="cal">'] + [f'<span class="h">{d}</span>' for d in "MTWTFSS"] + ["<span></span>"] * 3
    for d in range(1, 32):
        c = "sel today" if d == 3 else ("rec" if d in (1, 2) else ("plan" if d in (20, 25) else ""))
        cal.append(f'<span class="{c}">{d}</span>')
    cal.append("</div>")
    body = (header("History", "All accounts") + period("October 2026") + seg(["List", "Calendar"], "Calendar")
            + tray("", "".join(cal) + '<div class="adjl" style="margin-top:8px"><span><i style="--c:var(--tint);border:1px solid var(--control)"></i>Recorded</span><span><i style="--c:transparent;border:1.5px dashed var(--control)"></i>Plan</span></div>')
            + light_card('<div class="dayh"><b>Saturday 3 October</b><span class="amt inc">+3,154.30</span></div>'
                         + today_rows("") + '<div class="lab" style="margin-top:8px">Next plan: Netflix on 20 October, -19.98.</div>', "day-card"))
    reg("hi-cal", H, "Register", "History, calendar",
        phone(body, "History", "long"),
        "Same month, as a calendar. 1 October is a Thursday. Days with records are filled; plan dates (20 and 25 October) are outlined. Unrecorded days never read as zero spending. The selected day lists its four seeded entries.",
        "New view (round 4); app/lib/ui/transactions/daily_list/daily_transactions_screen.dart")

    october_matches = ('<div class="dayh"><b>October</b></div>'
                       + row("FairPrice groceries", "3 Oct / Supermarket / Amex Card", -42.50, "Supermarket")
                       + row("Tekka wet market", "2 Oct / Fresh Market / DBS Checking", -18.60, "Fresh Market")
                       + row("Cold Storage", "2 Oct / Groceries / DBS Checking", -12.40, "Groceries"))
    september_matches = '<div class="dayh"><b>September</b></div>' + row("Grocery top-up", "29 Sep / Groceries / Amex Card", -31.80, "Groceries") + row("Weekly groceries", "18 Sep / Groceries / Amex Card", -74.20, "Groceries")
    body = (header("History", "Search") + f'<div class="search focus">{ic("search","s")}Groceries<span class="caret"></span></div>'
            + chips(["Sep - Oct 2026", "All accounts", "Expense"], "") +
            '<div class="selp" style="margin:2px 0 6px"><span class="lab">5 matches<small>Groceries includes its subcategories</small></span><span class="mid exp">-S$179.50</span></div>'
            + light_sections('<div class="light-card day-card">' + october_matches + '</div><div class="light-card day-card">' + september_matches + '</div>' + keyboard(), october_matches + september_matches + keyboard()))
    reg("hi-search", H, "Register", "History, search",
        phone(body, None, "long"),
        "Search combines names, categories, accounts and dates; chips narrow the range, account and type. Seed matches: 42.50 + 18.60 + 12.40 + 31.80 + 74.20 = 179.50. The 8 November Cold Storage entry is outside the chosen range. Full scroll shown.",
        "New view (round 4); app/lib/ui/common/day_sectioned_entry_list.dart")

    grid = '<div class="mgrid">' + "".join(f'<span class="{"on" if m == "Oct" else ""}">{m}</span>' for m in MSHORT) + "</div>"
    sh = sheet_head("Choose month") + period("2026") + grid + btn("Show October 2026")
    reg("hi-period", H, "Register", "Choose month",
        sheet_phone(history_oct(), sh, cls="", under_cls="", sheet_cls="content"),
        "Tapping the month between the arrows opens this sheet; the arrows step one month. Swipes on the list also change the month.",
        "app/lib/ui/common/month_year_selector.dart", ["Month and year picker"])


# ---------- Trends ----------

def oct_cats():
    return [("Dining", 50.1, "dining"), ("Groceries", 43.9, "groceries"), ("Transport", 6.0, "transport")]


def oct_subs():
    return [("Dining", 50.1, "dining"), ("Supermarket", 25.4, "supermarket"), ("Fresh Market", 11.1, "freshmarket"),
            ("Direct to Groceries", 7.4, "groceries"), ("Transport", 6.0, "transport")]


def rank_oct_cats():
    return rank([("Dining", "50.1%", 83.90, "dining", ""), ("Groceries", "43.9%", 73.50, "groceries", ""), ("Transport", "6.0%", 10.00, "transport", "")])


def rank_oct_subs():
    return rank([("Dining", "50.1%", 83.90, "dining", ""), ("Supermarket", "25.4%", 42.50, "supermarket", "Groceries"),
                 ("Fresh Market", "11.1%", 18.60, "freshmarket", "Groceries"), ("Direct to Groceries", "7.4%", 12.40, "groceries", "Groceries"),
                 ("Transport", "6.0%", 10.00, "transport", "")])


def rank_split(total):
    d, g, t = split48(total)
    return rank([("Dining", "48.0%", d, "dining", ""), ("Groceries", "36.0%", g, "groceries", ""), ("Transport", "16.0%", t, "transport", "")])


def scoped_seed_trend(october, september=None):
    months = ["N", "D", "J", "F", "M", "A", "M", "J", "J", "A", "S", "O"]
    items = [(label, None, "x", False) for label in months[:-2]]
    items += [("S", None if september is None else september * 10, "x" if september is None else "c", False), ("O", october * 10, "p", True)]
    return tray("Monthly trend", seg(["Month by month", "Year by year"], "Month by month", "sm")
                + period("Nov 2025 - Oct 2026", prev_off=True, next_off=True) + month_bars(items, "mini")
                + '<div class="qual">October is incomplete.</div>')


SPLIT = [("Dining", 48.0, "dining"), ("Groceries", 36.0, "groceries"), ("Transport", 16.0, "transport")]


def trends_body(chart, breakdown, mode="Expense"):
    light = f'<div class="light-card chart-card">{chart}</div><div class="light-card breakdown-card">{breakdown}</div>'
    return header("Trends") + seg(["Expense", "Income"], mode) + light_sections(light, chart + breakdown)


def trends_month(selected, sel_label, sel_sub, amount, usual_b, usual_s, chart, level="By category", end=(2026, 9), period_label="Nov 2025 - Oct 2026",
                 prev_off=False, quality=True):
    q = '<div class="qual">August has no records; October is incomplete.</div>' if quality else ""
    us = f'<div class="usual"><b>{usual_b}</b><small>{usual_s}</small></div>'
    chart_body = (seg(["Month by month", "Year by year"], "Month by month") + period(period_label, prev_off=prev_off, next_off=end == (2026, 9))
                  + month_bars(spread(end[0], end[1], selected)) + q
                  + f'<div class="selp"><span class="lab">{sel_label}<small>{sel_sub}</small></span><span class="big exp">{sm(-amount, True)}</span></div>' + us)
    breakdown = f'<div class="bkh"><h5>Expense breakdown</h5><small>{level}</small></div>' + chart
    return trends_body(chart_body, breakdown) + "".join(tiles.trend_tiles())


def income_chart(selected=(2026, 9)):
    income = {(2026, 8): sum(v for _, _, _, _, v, moved in SEP if v > 0 and not moved),
              (2026, 9): sum(v for _, _, _, _, v, moved in OCT if v > 0 and not moved)}
    items = []
    for offset in range(11, -1, -1):
        month = 9 - offset
        year = 2026 if month >= 0 else 2025
        month %= 12
        value = income.get((year, month))
        items.append((MSHORT[month][0], None if value is None else value / 3.2,
                      "x" if value is None else ("p" if (year, month) == (2026, 9) else "c"), (year, month) == selected))
    detail = ('<div class="selp"><span class="lab">October 2026<small>Recorded so far, 1-3 October</small></span>'
              '<span class="big inc">+S$3,200.00</span></div>') if selected == (2026, 9) else '<div class="selp"><span class="lab">July 2026<small>No income recorded</small></span></div>'
    return (seg(["Month by month", "Year by year"], "Month by month")
            + period("Nov 2025 - Oct 2026", prev_off=True, next_off=True)
            + month_bars(items, label="Monthly income bars")
            + '<div class="qual">Only September and October have recorded income. October is incomplete.</div>'
            + detail + '<div class="usual"><b>Compared with usual</b><small>More complete months needed.</small></div>')


def income_breakdown():
    return ('<div class="bkh"><h5>Income breakdown</h5><small>October 2026 / By category</small></div>'
            + donut([("Salary", 100.0, "salary")], "Salary", "100.0%")
            + rank([("Salary", "100.0%", 3200.00, "salary", "")], income=True))


def build_trends():
    july = trends_month((2026, 6), "July 2026", "Spent", 900.00, "Compared with usual: 0.9% higher", "Usual is S$891.67, the April to June average.",
                        donut(SPLIT, "Dining", "48.0%") + rank_split(900.00))
    reg("tr-july", T, "Month by month", "Trends, month by month, July",
        phone(july, "Trends", "long"),
        "Sample history (revision 2). July 2026 S$900.00 against usual (875 + 860 + 940) / 3 = 891.67, so 0.9% higher. The breakdown uses the Settings choices, here Donut and Categories; breakdown choices stay in Settings. Sample split: 432.00 + 324.00 + 144.00 = 900.00. Tapping a row opens its category." + TREND_TILES_NOTE,
        "app/lib/ui/stats/stats_root_screen.dart", ["Stats, expenses", "Transactions, monthly"])

    octm = trends_month((2026, 9), "October 2026", "Recorded so far, 1-3 October", 167.40, "Compared with usual", "More complete months needed.",
                        cmap(oct_cats()) + rank_oct_cats())
    reg("tr-oct-map", T, "Month by month", "Trends, October, category map",
        phone(octm, "Trends", "long"),
        "Monthly bars use revision 2 sample history. Seed October: Dining 83.90 + Groceries 73.50 + Transport 10.00 = 167.40. Settings chart is Category map. Transport is too small for its name, so it gets an adjacent colour-linked label instead of a bare number. The selected purple bar marks October, and the caption identifies it as incomplete; usual needs three complete preceding months, and August is missing." + TREND_TILES_NOTE,
        "app/lib/ui/stats/analysis/analysis_flow.dart", ["Stats, category map"])

    octs = trends_month((2026, 9), "October 2026", "Recorded so far, 1-3 October", 167.40, "Compared with usual", "More complete months needed.",
                        donut(oct_subs(), "Dining", "50.1%") + rank_oct_subs(), level="By subcategory")
    reg("tr-oct-sub-donut", T, "Month by month", "Trends, October, subcategories, donut",
        phone(octs, "Trends", "long"),
        "Monthly bars use revision 2 sample history. Settings level is Subcategories. Groceries splits into Supermarket 42.50, Fresh Market 18.60 and Direct to Groceries 12.40 (73.50 together); rounded displayed shares of 167.40 add to 100.0%." + TREND_TILES_NOTE,
        "app/lib/ui/stats/analysis/analysis_flow.dart", ["Stats, subcategory donut"])

    octsm = trends_month((2026, 9), "October 2026", "Recorded so far, 1-3 October", 167.40, "Compared with usual", "More complete months needed.",
                         cmap(oct_subs()) + rank_oct_subs(), level="By subcategory")
    reg("tr-oct-sub-map", T, "Month by month", "Trends, October, subcategories, category map",
        phone(octsm, "Trends", "long"),
        "Monthly bars use revision 2 sample history; the October breakdown uses seed amounts. Subcategories with Category map. Blocks that cannot hold a name and share carry adjacent labels; the ranked list keeps every name, share and amount." + TREND_TILES_NOTE,
        "app/lib/ui/stats/analysis/analysis_flow.dart", ["Stats, subcategory map"])

    yr_chart = (seg(["Month by month", "Year by year"], "Year by year") + period("2024 - 2026", "January to July in each year", True, True)
          + year_bars([("2024", 5550, False), ("2025", 5955, False), ("2026", 6270, True)])
          + '<div class="qual">2026 is incomplete, so every year uses the same complete months.</div>'
          + f'<div class="selp"><span class="lab">2026<small>January to July</small></span><span class="big exp">-S$6,270.00</span></div>'
          )
    yr = trends_body(yr_chart, '<div class="bkh"><h5>Expense breakdown</h5><small>By category</small></div>' + donut(SPLIT, "Dining", "48.0%") + rank_split(6270.00))
    reg("tr-year", T, "Year by year", "Trends, year by year",
        phone(yr, "Trends", "long"),
        "Sample: January to July totals 2024 S$5,550.00, 2025 S$5,955.00, 2026 S$6,270.00. Selected 2026 splits 3,009.60 + 2,257.20 + 1,003.20 = 6,270.00. Both arrows are off because all recorded years fit this spread. Year mode has no usual row.",
        "app/lib/ui/stats/stats_root_screen.dart", ["Stats, annual expenses", "Stats period range menu"])

    first_chart = (seg(["Month by month", "Year by year"], "Month by month") + period("Jan - Oct 2024", prev_off=True)
             + month_bars(spread(2024, 9, (2024, 2)))
             + f'<div class="selp"><span class="lab">March 2024<small>Spent</small></span><span class="big exp">-S$735.00</span></div>'
             + '<div class="usual"><b>Compared with usual</b><small>More complete months needed.</small></div>'
             )
    first = trends_body(first_chart, '<div class="bkh"><h5>Expense breakdown</h5><small>By category</small></div>' + donut(SPLIT, "Dining", "48.0%") + rank_split(735.00))
    reg("tr-first", T, "Month by month", "Trends, first spread",
        phone(first, "Trends", "long"),
        "The earliest spread stops at the first sample record, January 2024. November and December 2023 stay blank, not zero and not dashed. Earlier is off. March has only two complete months before it, so usual is unavailable. Sample split 352.80 + 264.60 + 117.60 = 735.00.",
        "app/lib/ui/stats/stats_root_screen.dart")

    reg("tr-income", T, "Month by month", "Trends, monthly income",
        phone(trends_body(income_chart(), income_breakdown(), "Income"), "Trends", "long"),
        "Seed income only: September salary +3,200.00 on 25 September and October salary +3,200.00 on 3 October, both into DBS Checking. Earlier months stay blank. Selected October uses the selected-mark token; its Salary breakdown is 100.0%. No sample income history is assumed.",
        "app/lib/ui/stats/stats_root_screen.dart", ["Stats, income"])
    no_income = '<div class="bkh"><h5>Income breakdown</h5><small>July 2026</small></div>' + empty("dollar", "No income recorded", "Income entries in this period will appear here.")
    reg("tr-no-income", T, "Month by month", "Trends, no income in selected month",
        phone(trends_body(income_chart((2026, 6)), no_income, "Income"), "Trends", "long"),
        "July has no recorded seed income, so the selected period has no amount or breakdown. The monthly chart keeps only September and October salary +3,200.00 each; all other months stay blank.",
        "app/lib/ui/stats/stats_root_screen.dart", ["Stats, no income"])

    # Category detail
    gro_fn = lambda y, m, v: SEPTEMBER_CATEGORY_SPENT["Groceries"] if (y, m) == (2026, 8) else (73.50 if (y, m) == (2026, 9) else split48(v)[1])
    trend = tray("Monthly trend", seg(["Month by month", "Year by year"], "Month by month", "sm") + period("Nov 2025 - Oct 2026", next_off=True)
                 + month_bars(spread(2026, 9, (2026, 9), fn=gro_fn, maxv=400.0), "mini")
                 + '<div class="qual">August has no records; October is incomplete.</div>')
    subs = tray("Subcategories",
                "".join(f'<div class="rr" style="display:grid;grid-template-columns:12px minmax(0,1fr) auto;gap:8px;align-items:center;padding:7px 0;border-bottom:1px solid var(--edge)"><span class="km" style="--c:var(--{c})"></span><div><b style="font-size:12px;font-weight:600;display:block">{n}</b><small class="sub">{p} of Groceries</small></div><span class="amt exp">{sm(-v)}</span></div>'
                        for n, p, v, c in [("Supermarket", "57.8%", 42.50, "supermarket"), ("Fresh Market", "25.3%", 18.60, "freshmarket"), ("Direct to Groceries", "16.9%", 12.40, "groceries")]))
    ents = tray("Entries", '<div class="dayh"><b>3 October</b></div>' + row("FairPrice groceries", "Supermarket / Amex Card", -42.50, "Supermarket")
                + '<div class="dayh"><b>2 October</b></div>' + row("Tekka wet market", "Fresh Market / DBS Checking", -18.60, "Fresh Market")
                + row("Cold Storage", "Direct to Groceries / DBS Checking", -12.40, "Groceries"))
    head = (header("Groceries", "1-3 October 2026", back="Trends", gear=False)
            + f'<div class="canvas-amount"><strong>-S$73.50</strong></div>')
    body = head + chips(["All Groceries", "Supermarket", "Fresh Market", "Direct to Groceries"], "All Groceries") + subs + ents + trend
    reg("tr-cat", T, "Category detail", "Category detail, Groceries",
        phone(body, "Trends", "long"),
        "Opened from the Groceries row or block, keeping the period. Seed: 42.50 + 18.60 + 12.40 = 73.50 (57.8%, 25.3%, 16.9%). Directly assigned spending is named Direct to Groceries. The trend card uses the same modes and spreads as Trends; sample months use the 36% Groceries share; September (106.00 = 74.20 + 31.80) and October are entry values.",
        "app/lib/ui/stats/category_detail/category_detail_screen.dart", ["Groceries, category detail"])

    body = (head.replace("-S$73.50", "-S$42.50") + chips(["All Groceries", "Supermarket", "Fresh Market", "Direct to Groceries"], "Supermarket")
            + tray("Entries", '<div class="dayh"><b>3 October</b></div>' + row("FairPrice groceries", "Supermarket / Amex Card", -42.50, "Supermarket")) + scoped_seed_trend(42.50))
    reg("tr-cat-sub", T, "Category detail", "Category detail, Supermarket scope",
        phone(body, "Trends", "long"),
        "A scope chip narrows the page to one subcategory: Groceries / Supermarket 42.50, one entry. Its monthly trend uses seed records only: October 42.50, earlier slots before the first record blank. No sample subcategory history is assumed. Chips appear only when a category has subcategories. Full scroll shown.",
        "app/lib/ui/stats/category_detail/category_detail_screen.dart", ["Groceries, subcategory detail"])

    body = (head.replace("-S$73.50", "-S$12.40") + chips(["All Groceries", "Supermarket", "Fresh Market", "Direct to Groceries"], "Direct to Groceries")
            + tray("Entries", '<div class="dayh"><b>2 October</b></div>' + row("Cold Storage", "Direct to Groceries / DBS Checking", -12.40, "Groceries")) + scoped_seed_trend(12.40, SEPTEMBER_CATEGORY_SPENT["Groceries"]))
    reg("tr-cat-direct", T, "Category detail", "Category detail, Direct to Groceries",
        phone(body, "Trends", "long"),
        "Spending assigned to Groceries itself: Cold Storage 12.40. Its monthly trend uses seed records only: September Weekly groceries 74.20 plus Grocery top-up 31.80 (106.00, both assigned to Groceries itself) and October Cold Storage 12.40. Earlier slots before the first record stay blank; no sample subdivision is assumed. Full scroll shown.",
        "app/lib/ui/stats/category_detail/category_detail_screen.dart", ["Groceries, direct entries"])

    trend_sep = tray("Monthly trend", seg(["Month by month", "Year by year"], "Month by month", "sm") + period("Nov 2025 - Oct 2026", next_off=True)
                     + month_bars(spread(2026, 9, (2026, 8), fn=gro_fn, maxv=400.0), "mini")
                     + '<div class="qual">August has no records; October is incomplete.</div>'
                     + '<div class="selp"><span class="lab">September 2026<small>Groceries</small></span><span class="mid exp">-S$106.00</span></div>'
                     + row("Grocery top-up", "29 Sep / Groceries / Amex Card", -31.80, "Groceries") + row("Weekly groceries", "18 Sep / Groceries / Amex Card", -74.20, "Groceries"))
    body = (f'<div class="back">{ic("left")}Trends</div><div style="font-size:18px;font-weight:600;margin-bottom:10px">Groceries</div>'
            + trend_sep)
    reg("tr-cat-trend", T, "Category detail", "Category trend, month selected",
        phone(body, "Trends"),
        "Selecting a bar in the trend card shows that month's Groceries amount and entries: September 2026, Grocery top-up 31.80 on 29 September and Weekly groceries 74.20 on 18 September (106.00). Other monthly bars use revision 2 sample totals at the 36% Groceries share.",
        "app/lib/ui/stats/category_detail/category_trend_card.dart", ["Category trend, selected month"])

    # Desktop Trends
    left = (f'<div class="pane">{seg(["Expense", "Income"], "Expense")}{seg(["Month by month", "Year by year"], "Month by month")}{period("Nov 2025 - Oct 2026", next_off=True)}'
            f'{month_bars(spread(2026, 9, (2026, 6)), "")}<div class="qual">August has no records; October is incomplete.</div>'
            '<div class="selp"><span class="lab">July 2026<small>Spent</small></span><span class="big exp">-S$900.00</span></div>'
            '<div class="usual"><b>Compared with usual: 0.9% higher</b><small>Usual is S$891.67, the April to June average.</small></div></div>')
    right = (f'<div class="pane"><div class="bkh" style="margin-top:0"><h5>Expense breakdown</h5><small>July 2026 / By category</small></div>'
             f'{donut(SPLIT, "Dining", "48.0%")}{rank_split(900.00)}</div>')
    trend_tiles = tiles.trend_tiles()
    lower = f'<div class="dg2e" style="margin-top:18px"><div class="dcol">{trend_tiles[0]}{trend_tiles[2]}</div><div class="dcol">{trend_tiles[1]}{trend_tiles[3]}</div></div>'
    reg("tr-desk", T, "Desktop", "Trends with breakdown, desktop",
        desktop("Trends", f'<div class="dg2">{left}{right}</div>' + lower, "Trends", "All accounts / Spending"),
        "The period chart and the selected breakdown sit side by side; selecting a bar updates the breakdown without leaving the page. Same sample July values and Settings choices as the phone. Left and right arrow keys move one spread. Category movers and Fixed vs flexible fill the left column below, Day-of-week pattern and Savings rate the right." + tiles.sample_note(week=False),
        "app/lib/ui/shell/app_shell.dart; app/lib/ui/stats/stats_root_screen.dart", ["Stats, expenses, macOS"], kind="desktop")

    left_income = '<div class="pane">' + seg(["Expense", "Income"], "Income") + income_chart() + '</div>'
    right_income = '<div class="pane">' + income_breakdown() + '</div>'
    reg("tr-desk-income", T, "Desktop", "Trends, monthly income, desktop",
        desktop("Trends", f'<div class="dg2">{left_income}{right_income}</div>', "Trends", "All accounts / Income"),
        "The existing desktop chart-and-breakdown pattern carries the income view. Seed September and October salary +3,200.00 each; selected October has Salary 100.0%, +3,200.00. Earlier months stay blank.",
        "app/lib/ui/shell/app_shell.dart; app/lib/ui/stats/stats_root_screen.dart", kind="desktop")

    left = (f'<div class="pane"><div class="lab">1-3 October 2026</div><div class="canvas-amount"><strong>-S$73.50</strong></div>'
            + chips(["All Groceries", "Supermarket", "Fresh Market", "Direct to Groceries"], "All Groceries")
            + cmap([("Supermarket", 57.8, "supermarket"), ("Fresh Market", 25.3, "freshmarket"), ("Direct to Groceries", 16.9, "groceries")], 120)
            + '</div>')
    right = ents.replace('class="tray"', 'class="pane"') + "<div style='height:14px'></div>" + trend.replace('class="tray"', 'class="pane"')
    reg("tr-desk-cat", T, "Desktop", "Category detail, desktop",
        desktop("Trends", f'<div class="dg2e">{left}<div>{right}</div></div>', "Groceries", "Trends / October 2026",
                acts=f'<span>{ic("left","s")}Back to Trends</span><span class="pbtn">{ic("plus","s")}Add entry</span>'),
        "Desktop category detail: scope, subcategory map and entries together. The map labels every block that fits; the chips name every scope. The Groceries trend uses revision 2 sample monthly totals at the 36% share, with September 106.00 (74.20 + 31.80) and October 73.50.",
        "app/lib/ui/stats/category_detail/category_detail_screen.dart", kind="desktop")
