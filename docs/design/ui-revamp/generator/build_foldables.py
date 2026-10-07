from html import escape
from pathlib import Path

import data
import s_add
import s_history_trends
import s_money
import s_overview
import s_settings
import tiles
from comp import donut, header, ic, month_bars, period, phone, rank, seg, setrow, sprite, tray
from foldable_frames import FOLDABLE_CSS, Element, Markup, confirmation_parts, desktop_panes, frame, phone_body
from styles import APP_CSS, PAGE_CSS


def approved_frames():
    data.FRAMES.clear()
    s_overview.build()
    s_history_trends.build_history()
    s_history_trends.build_trends()
    s_add.build()
    s_money.build()
    s_settings.build_settings()
    return {item["id"]: item for item in data.FRAMES}


POPULATED = {"w_insights": tiles.w_insights, "w_week": tiles.w_week}
ALL_WIDGETS = [(widget.__name__, POPULATED.get(widget.__name__, widget)) for widget in tiles.ALL_WIDGETS]


def overview_page(widgets=None):
    widgets = ALL_WIDGETS if widgets is None else widgets
    spans = {"w_today", "w_recent", "w_overtime"} | tiles.WIDE_NEW_WIDGETS
    cards = ''.join(f'<div class="fold-widget {"wide" if name in spans else ""}" data-widget="{name}">{widget()}</div>' for name, widget in widgets)
    return data.overview_head() + f'<div class="fold-overview">{cards}</div>'


def highlight(markup, class_name, selected):
    root = Markup(markup).root
    matches = []

    def visit(node):
        if node.has_class(class_name) and selected in node.inner():
            node.start = node.start.replace('class="', 'class="fold-selected-row ', 1)
            matches.append(node)
            return
        for child in node.children:
            if isinstance(child, Element):
                visit(child)

    visit(root)
    assert len(matches) in (1, 2), (class_name, selected, len(matches))
    return root.inner()


def detail_panel(title, content, subtitle="", actions=""):
    close = f'<span class="fold-close">{ic("close", "s")}Close</span>'
    return header(title, subtitle, actions + close, gear=False) + f'<div class="fold-detail-scroll">{content}</div>'


def strip_heading(markup):
    root = Markup(markup).root
    holder = root.find("pane") or root
    heading = holder.find("hd") or holder.find("th") or holder.find("bkh")
    assert heading in holder.children
    holder.children.remove(heading)
    return holder.inner()


def select_card(markup):
    return markup.replace('class="tray', 'class="tray fold-selected-card', 1)


def insight(text, detail, action=""):
    link = f'<div class="link">{action}</div>' if action else ""
    return f'<div class="ins"><div class="t"><b>{text}</b></div><small>{detail}</small>{link}</div>'


def day_figures():
    figures = {}
    for day, _, _, _, amount, moved in data.OCT:
        if moved:
            continue
        entry = figures.setdefault(day, {"net": 0.0, "spent": 0.0, "income": 0.0})
        entry["net"] += amount
        entry["spent" if amount < 0 else "income"] += abs(amount)
    return figures


EXPENSE_TINT_FLOOR = 8
EXPENSE_TINT_RANGE = 14


def calendar_card():
    figures = day_figures()
    peak_spend = max(entry["spent"] for entry in figures.values())
    cells = ['<div class="mcal">'] + [f'<span class="mh">{d}</span>' for d in "MTWTFSS"] + ['<span class="mb"></span>'] * 3
    for day in range(1, 32):
        entry = figures.get(day)
        classes, style, body = "mc", "", f"<b>{day}</b>"
        if day == 3:
            classes += " mc-today"
        if entry:
            if entry["spent"]:
                tint = EXPENSE_TINT_FLOOR + EXPENSE_TINT_RANGE * entry["spent"] / peak_spend
                style = f' style="background:color-mix(in srgb,var(--expense) {tint:.1f}%,transparent)"'
            dot = '<i class="mc-dot" aria-label="Income"></i>' if entry["income"] else ""
            body += dot + f'<span class="amt {data.kind_of(entry["net"])}" aria-label="Day net">{data.sm(entry["net"])}</span>'
        cells.append(f'<div class="{classes}"{style}>{body}</div>')
    cells.append("</div>")
    spent = sum(entry["spent"] for entry in figures.values())
    income = sum(entry["income"] for entry in figures.values())
    assert (round(spent, 2), round(income, 2), round(income - spent, 2)) == (data.OCTOBER_SPENT, data.SAMPLE_MONTHLY_SALARY, round(data.SAMPLE_MONTHLY_SALARY - data.OCTOBER_SPENT, 2))
    legend = ('<div class="adjl mc-legend"><span><i style="--c:color-mix(in srgb,var(--expense) 22%,transparent)"></i>Spend intensity</span>'
              '<span><i class="mc-dot"></i>Income</span><span><i class="mc-key-today"></i>Today</span><span>Amount: day net</span></div>')
    foot = (f'<div class="mc-foot"><div><small>Spent</small><b class="exp">{data.sm(-spent)}</b></div>'
            f'<div><small>Income</small><b class="inc">{data.sm(income)}</b></div>'
            f'<div><small>Net</small><b class="{data.kind_of(income - spent)}">{data.sm(income - spent)}</b></div></div>')
    return tray("Money calendar", "".join(cells) + legend + foot, aside="<small>October 2026</small>")


def week_card(compact=False):
    strip = s_history_trends.week_strip([
        ("28 Sep", tiles.current_week_spent(), ""), ("5 Oct", None, "ahead"), ("12 Oct", None, "ahead"),
        ("19 Oct", None, "ahead"), ("26 Oct", None, "ahead")], tiles.current_week_spent())
    return tray("By week", strip, "fold-compact" if compact else "", aside="<small>Spending, weeks start Monday</small>")


def register(selected):
    entries = data.day_groups(data.OCT)
    if selected:
        entries = highlight(entries, "row", "FairPrice groceries")
    return f'<div class="search">{ic("search", "s")}Search entries</div>' + entries


def history_page(selected=False):
    heading = header("History", "All accounts", gear=False) + period("October 2026") + seg(["List", "Calendar"], "List")
    summary = f'<div class="fold-band">{data.band(3032.60, 167.40, 3200.00, 500.00)}</div>'
    if selected:
        return heading + summary + week_card(True) + register(True) + calendar_card() + tiles.biggest_entries() + tiles.by_account()
    side = week_card() + calendar_card() + tiles.biggest_entries() + tiles.by_account()
    return heading + summary + f'<div class="fold-history-grid"><div>{register(False)}</div><div>{side}</div></div>'


def trends_chart(selected=False):
    chart = (seg(["Expense", "Income"], "Expense") + seg(["Month by month", "Year by year"], "Month by month")
             + period("Nov 2025 - Oct 2026", next_off=True)
             + month_bars(data.spread(2026, 9, (2026, 6) if selected else None), label="Monthly spending; July selected" if selected else "Monthly spending; no month selected")
             + '<div class="qual">August has no records; October is incomplete.</div>')
    return header("Trends", gear=False) + tray("Period chart", chart, "fold-period-chart")


def period_figures():
    totals = tiles.period_category_totals()
    peak_year, peak_month = max(data.COMPLETE_MONTHS, key=lambda key: data.month_value(*key))
    return totals, tiles.category_averages(), (data.MLONG[peak_month], peak_year, data.month_value(peak_year, peak_month))


def whole_period_card(compact=False):
    totals, _, _ = period_figures()
    total = sum(totals.values())
    rows = [(name, f'{value / total * 100:.1f}%', value, name.lower(), "") for name, value in totals.items()]
    shares = [(name, value / total * 100, name.lower()) for name, value in totals.items()]
    top = max(shares, key=lambda share: share[1])
    body = (f'<div class="selp"><span class="lab">Nov 2025 - Oct 2026<small>Recorded spending in this period</small></span><span class="big exp">{data.sm(-total, True)}</span></div>'
            + f'<div class="fold-breakdown">{donut(shares, top[0], f"{top[1]:.1f}%")}{rank(rows)}</div>')
    return tray("Whole-period expense breakdown", body, "fold-compact" if compact else "", aside="<small>By category</small>")


def trends_insights_card():
    totals, _, (peak_name, peak_year, peak_value) = period_figures()
    total = sum(totals.values())
    top = max(totals, key=totals.get)
    body = (insight(f"{top} is the largest category at {totals[top] / total * 100:.1f}% of the period.", "Nov 2025 - Oct 2026, recorded spending")
            + insight(f"{peak_name} {peak_year} is the highest month at S${data.f2(peak_value)}.", f"Of the {len(data.COMPLETE_MONTHS)} complete months, Nov 2025 - Jul 2026 and Sep 2026")
            + insight("August has no records; October is incomplete.", "Gaps and incomplete months are marked in the chart"))
    return tray("Insights", body)


def trends_page():
    return (trends_chart() + f'<div class="fold-pair">{whole_period_card()}{trends_insights_card()}</div>'
            + f'<div class="fold-tiles">{"".join(tiles.trend_tiles())}</div>')


def trends_selected_page():
    return trends_chart(True) + whole_period_card(True) + trends_insights_card() + "".join(tiles.trend_tiles())


def month_detail():
    _, averages, _ = period_figures()
    month_split = dict(zip(("Dining", "Groceries", "Transport"), data.split48(900.00)))
    shares = dict((name, share) for name, share, _ in s_history_trends.SPLIT)
    rows = ''.join(
        f'<div class="rr"><span class="km" style="--c:var(--{name.lower()})"></span><div><b>{name}</b><small>{shares[name]:.1f}%</small></div>'
        f'<span class="amt">{data.sm(-month_split[name])}</span><span class="avg">{data.f2(averages[name])}</span></div>'
        for name in month_split)
    compare = ('<div class="cmp-head"><span>July</span><span>Monthly average</span></div>'
               f'<div class="rank cmp">{rows}</div>'
               f'<div class="qual">Monthly average is over the {len(data.COMPLETE_MONTHS)} complete months, Nov 2025 - Jul 2026 and Sep 2026.</div>')
    header_card = tray("", '<div class="selp" style="margin-top:0"><span class="lab">July 2026<small>Spent</small></span><span class="big exp">-S$900.00</span></div>'
                       '<div class="usual"><b>Compared with usual: 0.9% higher</b><small>Usual is S$891.67, the April to June average.</small></div>')
    breakdown = tray("Expense breakdown", donut(s_history_trends.SPLIT, "Dining", "48.0%") + compare, aside="<small>By category</small>")
    return header_card + breakdown


def all_spending_card():
    root = Markup(s_money.budgets_body()).root
    return next(node for node in root.children if isinstance(node, Element) and node.has_class("tray")).html()


def budget_cards(selected=""):
    averages = period_figures()[1]
    cards = [tray("", tiles.forecast_budget_row(name, spent, limit, averages[name])) for name, spent, limit in tiles.budgets()]
    return [select_card(card) if name == selected else card for card, (name, _, _) in zip(cards, tiles.budgets())]


def money_observations_card():
    elapsed = tiles.DAYS_ELAPSED / tiles.DAYS_IN_MONTH * 100
    name, spent, limit = max(tiles.budgets(), key=lambda budget: budget[1] / budget[2])
    body = (insight(f"{name} is closest to its limit: {spent / limit * 100:.1f}% used, {elapsed:.1f}% of October gone.",
                    f"S${data.f2(spent)} of S${data.f2(limit)} after {tiles.DAYS_ELAPSED} of {tiles.DAYS_IN_MONTH} days", f"Open {name} budget")
            + insight("Supermarket has S$42.50 recorded and no budget of its own.",
                      "It counts inside the Groceries budget today", "Add a Supermarket budget")
            + insight("Stay within S$1,200.00 by spending about S$36.88 a day.",
                      "S$1,032.60 left over 28 days from 4 October"))
    return tray("Observations", body)


def money_coming_card():
    october = [entry for entry in data.COMING if entry[1] == "Oct" and entry[4] is not None]
    budgets = {"Netflix": "draws from All spending", "Monthly salary": "income, draws from no budget"}
    rows = ''.join(data.daterow(day, month, name, f'{meta.removeprefix("Plan / ")} / {budgets[name]}', value)
                   for day, month, name, meta, value in october)
    return tray("Coming up", rows, aside="<small>October</small>")


def money_page(selected=False):
    heading = s_money.money_head("Budgets") + period("October 2026")
    if selected:
        return (heading + all_spending_card() + ''.join(budget_cards("Dining"))
                + money_observations_card() + money_coming_card())
    cards = ''.join(budget_cards()) + money_coming_card()
    return (heading + all_spending_card()
            + f'<div class="fold-money-grid"><div class="fold-money-cards">{cards}</div>'
            f'<div class="fold-money-side">{money_observations_card()}</div></div>')


def body_parts(markup):
    return [(node.attrs.get("class", ""), node.html()) for node in Markup(markup).root.children if isinstance(node, Element)]


def accounts_page():
    parts = dict(body_parts(s_money.accounts_body(with_tiles=False)))
    trays = [html for name, html in body_parts(s_money.accounts_body(with_tiles=False)) if name.split()[0] == "tray"]
    assert len(trays) == 2 and "band three" in parts
    list_side = ''.join(trays)
    side = tiles.net_worth_trend() + tiles.card_utilisation()
    return (s_money.money_head("Accounts") + f'<div class="fold-band">{parts["band three"]}</div>'
            + f'<div class="fold-history-grid"><div>{list_side}</div><div>{side}</div></div>')


def plans_page():
    body = s_money.plans_body(True, with_tile=False)
    head = s_money.money_head("Plans")
    assert body.startswith(head)
    return head + f'<div class="fold-history-grid"><div>{body.removeprefix(head)}</div><div>{tiles.plans_cash_flow(s_money.plan_rows(True))}</div></div>'


def phone_overview():
    return data.overview_head() + ''.join(widget() for _, widget in ALL_WIDGETS)


def phone_history():
    heading = header("History", "All accounts") + period("October 2026") + seg(["List", "Calendar"], "List")
    summary = data.band(3032.60, 167.40, 3200.00, 500.00)
    return (heading + f'<div class="search">{ic("search", "s")}Search entries</div>' + summary + week_card()
            + tiles.biggest_entries() + tiles.by_account() + data.day_groups(data.OCT))


def phone_trends():
    return trends_chart() + whole_period_card(True) + ''.join(tiles.trend_tiles())


def phone_budgets():
    return s_money.budgets_body()


def phone_accounts():
    return s_money.accounts_body()


def phone_plans():
    return s_money.plans_body(True)


def settings_groups(selected=False):
    root = Markup(s_settings.settings_body()).root
    groups = [node.html() for node in root.children if isinstance(node, Element) and node.has_class("tray")]
    assert len(groups) == 6
    if selected:
        marked = [select_card(group) if "Trends breakdown" in group else group for group in groups]
        assert sum("fold-selected-card" in group for group in marked) == 1
        return marked
    return groups


def settings_page(selected=False):
    groups = ''.join(settings_groups(selected))
    layout = "fold-settings-list" if selected else "fold-masonry"
    return header("Settings", gear=False) + f'<div class="{layout}">{groups}</div>'


SAMPLE_NOTE = tiles.sample_note()


def section(title, frames):
    return f'<section class="fold-section"><h2>{escape(title)}</h2>{"".join(frames)}</section>'


def page():
    approved = approved_frames()
    _, history_edit = desktop_panes(approved["hi-desk"])
    history_detail = detail_panel("Edit entry", strip_heading(history_edit), "3 October 2026")
    trends_detail = detail_panel("July 2026", month_detail())
    dining_detail = detail_panel("Dining", strip_heading(phone_body(approved["mo-budget-detail"])), "October 2026", '<span>Edit</span>')
    settings_detail = detail_panel("Trends breakdown", strip_heading(phone_body(approved["st-trends"])))
    _, confirmation = confirmation_parts(approved["mo-budget-delete"])
    continuity_widgets = [("w_today", data.w_today), ("w_recent", data.w_recent), ("w_coming", data.w_coming)]
    assert phone_body(approved["ov-default"]) == data.overview_head() + ''.join(widget() for _, widget in continuity_widgets)
    assert ''.join(widget() for widget in tiles.ALL_WIDGETS) == phone_body(approved["ov-custom"]).removeprefix(data.overview_head())
    assert phone_budgets() == phone_body(approved["mo-budgets"])
    assert phone_accounts() == phone_body(approved["mo-accounts"])
    assert phone_plans() == phone_body(approved["mo-plans-attention"])
    assert tiles.current_week_spent() == round(data.OCTOBER_SPENT + sum(entry[4] for entry in data.expense_entries(data.SEP_SAMPLE)), 2)
    tiles.assert_seed_figures(s_money.accounts_body())
    sections = [
        section("Overview", [
            frame("overview-light", "Overview - open, light", "All 16 widgets (the 12 approved plus Safe to spend, Pace vs usual, Subscriptions and Needs attention) share one scrolling dashboard with mixed card sizes." + SAMPLE_NOTE, overview_page()),
            frame("overview-dark", "Overview - open, dark", "The same 16-widget dashboard uses neutral near-black surfaces and blue chart accents." + SAMPLE_NOTE, overview_page(), theme="dark")]),
        section("History", [
            frame("history-full", "History - open, nothing selected", "The month summary band spans the top; the day register (left) and By week, the calendar, Biggest entries and By account (right) scroll together." + SAMPLE_NOTE, history_page(), "History"),
            frame("history-selected", "History - open, entry selected", "Left, one column: summary band, By week, the full register with FairPrice highlighted, the calendar, Biggest entries and By account; the edit form is on the right." + SAMPLE_NOTE, history_page(True), "History", detail=history_detail)]),
        section("Trends", [
            frame("trends-full", "Trends - open, nothing selected", "The period chart spans the top; the whole-period breakdown and Insights sit side by side, with Category movers, Day-of-week pattern, Fixed vs flexible and Savings rate packed in two columns below." + SAMPLE_NOTE, trends_page(), "Trends"),
            frame("trends-selected", "Trends - open, month selected", "Left, one column: the chart with July marked, the compact whole-period breakdown, Insights and the four trend tiles; July's detail with period averages is on the right." + SAMPLE_NOTE, trends_selected_page(), "Trends", detail=trends_detail)]),
        section("Money", [
            frame("money-full", "Money - open, nothing selected", "All spending spans the top; budget cards with their month-end forecast and Coming up (left) and Observations (right) scroll together and end level, with Add budget floating just left of the navigation.", money_page(), "Money", fab="Add budget"),
            frame("money-selected", "Money - open, budget selected", "Left, one column: All spending, every budget card with its month-end forecast and Dining highlighted, Observations and Coming up; the Dining detail is on the right.", money_page(True), "Money", detail=dining_detail),
            frame("money-accounts", "Money Accounts - open, nothing selected", "The reference account list (left) sits beside Net worth trend and Card utilisation, with Add account floating above the navigation.", accounts_page(), "Money", fab="Add account"),
            frame("money-plans", "Money Plans - open, nothing selected", "The reference plan list (left) sits beside Plans cash flow with its lowest point labelled.", plans_page(), "Money")]),
        section("Settings", [
            frame("settings-full", "Settings - open, nothing selected", "The six phone settings groups sit as separate cards in two packed columns.", settings_page(), "Settings"),
            frame("settings-selected", "Settings - open, group selected", "Left, one column: the same six group cards with Trends breakdown highlighted; its controls are on the right.", settings_page(True), "Settings", detail=settings_detail)]),
        section("Add entry", [
            frame("add-entry", "Add entry - open, expense draft", "Left, one column: all 16 Overview widgets; the full-height Add entry form with number pad is on the right." + SAMPLE_NOTE, overview_page(), form=s_add.add_sheet())]),
        section("Phone", ['<div class="fold-phones">'
            + frame("phone-overview", "Phone Overview - full scroll", "All 16 widgets in catalogue order; the four new ones close the page." + SAMPLE_NOTE, phone(phone_overview(), "Overview", "long"), folded=True, full=True)
            + frame("phone-history", "Phone History - full scroll", "Biggest entries and By account sit between By week and the day register." + SAMPLE_NOTE, phone(phone_history(), "History", "long"), folded=True, full=True)
            + frame("phone-trends", "Phone Trends - full scroll", "The four trend tiles follow the whole-period breakdown." + SAMPLE_NOTE, phone(phone_trends(), "Trends", "long"), folded=True, full=True)
            + frame("phone-budgets", "Phone Money Budgets - full scroll", "Each category budget bar carries its month-end forecast and limit marker.", phone(phone_budgets(), "Money", "long"), folded=True, full=True)
            + frame("phone-accounts", "Phone Money Accounts - full scroll", "Net worth trend follows the summary band; Card utilisation follows Credit cards.", phone(phone_accounts(), "Money", "long"), folded=True, full=True)
            + frame("phone-plans", "Phone Money Plans - full scroll", "Plans cash flow follows the Next up list.", phone(phone_plans(), "Money", "long"), folded=True, full=True)
            + '</div>']),
        section("Confirmation dialog", [
            frame("confirmation", "Money - open, delete confirmation", "A compact centered confirmation overlays the selected Dining budget and its detail pane.", money_page(True), "Money", detail=dining_detail, dialog=confirmation)]),
        section("Folding continuity", [
            '<div class="fold-continuity">'
            + frame("continuity-folded", "Overview - folded, 3 October", "Approved phone Overview with tabs and Add.", approved["ov-default"]["html"], folded=True)
            + frame("continuity-open", "Overview - open, 3 October", "The same three widgets and seed values reflow across the open display.", overview_page(continuity_widgets))
            + '</div>'])]
    return ('<!doctype html><html lang="en" data-page="light" data-app="light"><head>'
            '<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
            '<title>SpendWise - Foldables</title>'
            f'<style>{PAGE_CSS}{APP_CSS}{FOLDABLE_CSS}{tiles.TILE_CSS}</style></head><body>{sprite()}<main>'
            '<header class="fold-header"><h1>SpendWise on foldables</h1>'
            '<p class="targets">Targets: Samsung Galaxy Z Fold8 and Apple iPhone Duo - one shared design.</p>'
            '<p>The approved phone design opens into a 4:3 landscape canvas with right-edge navigation within thumb reach.</p></header>'
            + ''.join(sections)
            + '<p class="fold-footer">Static design mockup. Charts, amounts and seed content come from the approved reference. App controls depict states; scroll within each display to review its full content. Visual acceptance belongs to the owner in Lavish.</p>'
            + '</main></body></html>')


if __name__ == "__main__":
    markup = page()
    parsed = Markup(markup)
    frames = []
    def visit(node):
        if node.tag == "figure":
            frames.append(node)
        for child in node.children:
            if isinstance(child, Element):
                visit(child)
    visit(parsed.root)
    assert len(frames) == 22, len(frames)
    assert len({node.attrs["id"] for node in frames}) == 22
    assert sum(node.attrs["data-posture"] == "folded" for node in frames) == 7
    assert chr(0x2014) not in markup
    for name in ("Samsung Galaxy Z Fold8", "Apple iPhone Duo"):
        assert markup.count(name) == 1
        assert all(name not in node.find("fold-shell").inner() for node in frames)
    target = Path(__file__).resolve().parent.parent / "spendwise-foldables.html"
    target.write_text(markup, encoding="utf-8")
    print("frames", len(frames), "bytes", target.stat().st_size)
