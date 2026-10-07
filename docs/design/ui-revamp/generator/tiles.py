import math
from datetime import date, timedelta

import data
from comp import daterow, ic, month_bars, tray

TODAY = date(2026, 10, 3)
DAYS_ELAPSED = 3
DAYS_IN_MONTH = 31
CURRENT_WEEK_START = date(2026, 9, 28)
WEEK_BAR_MAX = 70.0
CASH_FLOW_WINDOW_DAYS = 30
AXIS_STEP = 500
CHART_PAD = 7.0
DOT_CLASS = "tl-dot"
MONTH_SHORT = data.MSHORT
PERIOD_MONTHS = [(2025, 10), (2025, 11)] + [(2026, month) for month in range(10)]
RECORDED_PERIOD_MONTHS = [key for key in PERIOD_MONTHS if key != (2026, 7)]
SEED_FIGURES = ("10,869.00", "10,350.00", "1,700.00", data.f2(data.AMEX_OWED), data.f2(data.NET_WORTH_NOW))


def assert_seed_figures(accounts_markup):
    assert all(text in accounts_markup + data.w_balances() for text in SEED_FIGURES)
    assert f"S${data.f2(data.AMEX_OWED)}" in data.w_card()
    assert f"-{data.f2(data.OCTOBER_SPENT)}" in data.w_month()
    for name, spent in data.OCTOBER_CATEGORY_SPENT.items():
        assert data.f2(spent) in data.w_top()


def money(value):
    return f"S${data.f2(value)}"


def percent(value, places=1):
    return f"{value:.{places}f}%"


def october_expenses():
    return data.expense_entries(data.OCT)


def september_expenses():
    return data.expense_entries(data.SEP)


def usual_month():
    return sum(data.month_value(*key) for key in data.COMPLETE_MONTHS) / len(data.COMPLETE_MONTHS)


def sample_category_totals():
    sample_total = sum(data.month_value(*key) for key in data.SAMPLE_COMPLETE_MONTHS)
    return dict(zip(data.BUDGET_LIMITS, data.split48(sample_total)))


def category_averages():
    sample = sample_category_totals()
    return {name: (sample[name] + data.SEPTEMBER_CATEGORY_SPENT[name]) / len(data.COMPLETE_MONTHS) for name in data.BUDGET_LIMITS}


def period_category_totals():
    sample = sample_category_totals()
    return {name: round(sample[name] + data.SEPTEMBER_CATEGORY_SPENT[name] + data.OCTOBER_CATEGORY_SPENT[name], 2) for name in data.BUDGET_LIMITS}


assert abs(sum(category_averages().values()) - usual_month()) < 0.005


def budgets():
    rows = [(name, data.OCTOBER_CATEGORY_SPENT[name], limit) for name, limit in data.BUDGET_LIMITS.items()]
    assert rows == sorted(rows, key=lambda row: row[1] / row[2], reverse=True)
    return rows


def cumulative_october_spend():
    running, series = 0.0, []
    for day in range(1, DAYS_ELAPSED + 1):
        running += sum(value for entry_day, _, _, _, value in october_expenses() if entry_day == day)
        series.append(round(running, 2))
    assert series[-1] == data.OCTOBER_SPENT
    return series


def _x(value, low, high):
    return CHART_PAD + (value - low) / (high - low) * (100 - 2 * CHART_PAD)


def _y(value, low, high):
    return CHART_PAD + (1 - (value - low) / (high - low)) * (100 - 2 * CHART_PAD)


def line_chart(series, x_range, y_range, label, marks=()):
    """series: (css class, [(x, y)]); marks: (x, y, css class). Coordinates are data values."""
    lines = ''.join(
        f'<polyline class="tl-line {css}" points="{" ".join(f"{_x(x, *x_range):.2f},{_y(y, *y_range):.2f}" for x, y in points)}"/>'
        for css, points in series)
    dots = ''.join(f'<i class="{DOT_CLASS} {css}" style="left:{_x(x, *x_range):.2f}%;top:{_y(y, *y_range):.2f}%"></i>' for x, y, css in marks)
    return f'<div class="tl-chart" role="img" aria-label="{label}"><svg viewBox="0 0 100 100" preserveAspectRatio="none">{lines}</svg>{dots}</div>'


def legend(entries):
    return '<div class="adjl">' + ''.join(f'<span><i style="--c:var({color})"></i>{text}</span>' for color, text in entries) + '</div>'


def axis(labels):
    return '<div class="tl-axis">' + ''.join(f'<span>{label}</span>' for label in labels) + '</div>'


def row_pair(title, detail, value_markup):
    return f'<div class="tl-row"><b>{title}</b>{value_markup}<small>{detail}</small></div>'


def sample_note(week=True):
    sample_total = round(-sum(entry[4] for entry in data.SEP_SAMPLE), 2)
    week_part = f" and the 28 Sep week ({money(current_week_spent())})" if week else ""
    return f" Sample: three entries on 28-30 September ({money(sample_total)}, Amex Card) are part of September ({money(data.SEPTEMBER_SPENT)}){week_part}."


def day_label(when):
    return f"{when.day} {MONTH_SHORT[when.month - 1]}"


# ---------- Overview widgets ----------

def safe_to_spend_figures():
    payday = int(next(entry for entry in data.COMING if entry[2] == "Monthly salary")[0])
    outflows = [entry for entry in data.COMING if entry[1] == "Oct" and entry[4] is not None and entry[4] < 0 and int(entry[0]) < payday]
    spendable = data.DBS_CHECKING + data.OCBC_OWN_BALANCE
    planned = -sum(entry[4] for entry in outflows)
    return payday, spendable, data.AMEX_OWED, planned, round(spendable - data.AMEX_OWED - planned, 2)


def w_safe():
    payday, spendable, owed, planned, safe = safe_to_spend_figures()
    return tray("Safe to spend", (
        f'<div class="kv"><span>Spendable balances</span><b>{money(spendable)}</b></div>'
        f'<div class="kv"><span>Amex Card balance owed</span><b class="exp">-{money(owed)}</b></div>'
        f'<div class="kv"><span>Card plans before payday</span><b class="exp">-{money(planned)}</b></div>'
        f'<div class="kv tl-total"><span>Safe to spend</span><b>{money(safe)}</b></div>'
        f'<div class="lab">Card balances count as committed. Until the {payday} October salary; savings pockets stay out.</div>'
        f'<div class="link">View Coming up{ic("right", "s")}</div>'))


def pace_figures():
    actual = cumulative_october_spend()
    total = usual_month()
    usual = [(day, round(total * day / DAYS_IN_MONTH, 2)) for day in range(1, DAYS_IN_MONTH + 1)]
    return actual, usual, round(actual[-1] - usual[DAYS_ELAPSED - 1][1], 2)


def w_pace():
    actual, usual, gap = pace_figures()
    usual_today = usual[DAYS_ELAPSED - 1][1]
    wording = "ahead of" if gap > 0 else "behind"
    chart = line_chart(
        [("ref", usual), ("main", list(enumerate(actual, 1)))],
        (1, DAYS_IN_MONTH), (0, usual[-1][1]), "Cumulative October spending against a usual month across the whole month",
        [(DAYS_ELAPSED, actual[-1], "sel")])
    return tray("Pace vs usual", (
        f'<div class="mid {"exp" if gap > 0 else "inc"}">{money(abs(gap))} {wording} usual</div>'
        f'<div class="lab">{money(actual[-1])} spent by 3 October; a usual month is {money(usual_today)} by then and {money(usual[-1][1])} by 31 October.</div>'
        + chart + axis(["1 Oct", "16 Oct", "31 Oct"])
        + legend([("--action", "October so far"), ("--gap", "Usual month")])))


def subscription_figures():
    netflix = next(plan for plan in data.SEED_PLANS if plan[2] == "Netflix")
    charges = [netflix, data.GYM_MONTHLY_PLAN]
    return charges, round(-sum(entry[4] for entry in charges), 2)


def w_subs():
    charges, total = subscription_figures()
    rows = ''.join(daterow(day, month, name, meta, value) for day, month, name, meta, value in charges)
    change = round(-charges[0][4] - data.NETFLIX_PREVIOUS_PRICE, 2)
    flag = (f'<div class="tl-flag">{ic("alert", "s")}<span><b>Netflix price changed</b> from {money(data.NETFLIX_PREVIOUS_PRICE)} to {money(-charges[0][4])}, '
            f'up {money(change)}.</span></div>')
    return tray("Subscriptions", (
        f'<div class="selp" style="margin-top:0"><span class="lab">Monthly total<small>{len(charges)} recurring plans</small></span><span class="mid exp">-{money(total)}</span></div>'
        f'<div class="lab" style="margin-top:6px">Next two charges</div>{rows}{flag}'))


def attention_row(icon, title, detail, fix):
    return (f'<div class="row"><span class="med" style="--c:var(--action)">{ic(icon)}</span><div class="rc"><b>{title}</b><small>{detail}</small></div>'
            f'<span class="tl-fix">{fix}</span></div>')


def w_attention():
    name, value, day = data.HELD_IMPORT
    fair_price = next(entry for entry in october_expenses() if entry[1] == "FairPrice groceries")
    return tray("Needs attention", (
        attention_row("tag", f"{name} has no category", f"Held import / {money(value)} / {day}, not counted yet", "Choose category")
        + attention_row("camera", "FairPrice groceries has no receipt", f"{fair_price[0]} Oct / {money(fair_price[4])}", "Attach receipt")
        + attention_row("cloud", f"{data.SYNC_PAUSED_ACCOUNT} sync paused", f"Last synced {data.SYNC_LAST_DAY}", "Retry sync")),
        aside="<small>3 items</small>")


def over_budget_label(count):
    if count == 0:
        return "No budgets on course to go over this month."
    return f'{count} {"budget" if count == 1 else "budgets"} on course to go over this month.'


def w_budgetwatch():
    averages = category_averages()
    rows = ''.join(forecast_budget_row(name, spent, limit, averages[name], compact=True) for name, spent, limit in budgets())
    over = sum(1 for name, spent, limit in budgets() if projected_month_end(spent, averages[name]) > limit)
    return tray("Budget watch", (
        f'<div class="lab">{over_budget_label(over)}</div>' + rows
        + '<div class="qual">The line marks the month-end forecast at the current pace.</div>'))


def week_figures():
    october_days = {day: sum(value for entry_day, _, _, _, value in october_expenses() if entry_day == day) for day in (1, 2, 3)}
    this_week = [value for _, _, _, _, value in data.expense_entries(data.SEP_SAMPLE)] + [october_days[day] for day in (1, 2, 3)]
    earlier = []
    for weeks_back in (3, 2, 1):
        start = CURRENT_WEEK_START - timedelta(weeks=weeks_back)
        window = [start + timedelta(days=offset) for offset in range(6)]
        assert window[-1] < CURRENT_WEEK_START
        earlier.append(round(sum(value for day, _, _, _, value in september_expenses() if date(2026, 9, day) in window), 2))
    return this_week, earlier


def current_week_spent():
    return round(sum(week_figures()[0]), 2)


def w_week():
    this_week, earlier = week_figures()
    spent = sum(this_week)
    usual = sum(earlier) / len(earlier)
    gap = spent - usual
    items = [(letter, this_week[weekday] if weekday < 6 else None, "c" if weekday < 6 else "x", weekday == 5) for weekday, letter in enumerate("MTWTFSS")]
    return tray("Week so far", (
        f'<div class="selp" style="margin-top:0"><span class="lab">28 Sep - 3 Oct<small>Monday to Saturday</small></span><span class="big exp">-{money(spent)}</span></div>'
        f'<div class="guide" style="margin-top:6px">{money(abs(gap))} {"more" if gap > 0 else "less"} than usual</div>'
        + month_bars(items, "mini", maxv=WEEK_BAR_MAX, label="Daily spending this week")
        + f'<div class="qual">Usual is {money(usual)}, the same days in the three weeks before ({", ".join(f"{value:.2f}" for value in earlier)}).</div>'))


def w_insights():
    return data.w_insights("shown")


NEW_WIDGETS = [w_safe, w_pace, w_subs, w_attention]
WIDE_NEW_WIDGETS = {"w_pace", "w_attention"}
ALL_WIDGETS = [data.w_today, data.w_month, data.w_recent, data.w_top, data.w_card, data.w_coming, data.w_balances, data.w_overtime,
               data.w_pocket, w_budgetwatch, data.w_insights, data.w_week] + NEW_WIDGETS


# ---------- History ----------

def biggest_entries():
    top = sorted(october_expenses(), key=lambda entry: entry[4], reverse=True)[:3]
    rows = ''.join(daterow(str(day), "Oct", name, f"{category} / {account}", -value) for day, name, category, account, value in top)
    return tray("Biggest entries", rows, aside="<small>October, spending</small>")


def account_figures():
    figures = {}
    for _, _, _, account, value, moved in data.OCT:
        if moved:
            continue
        entry = figures.setdefault(account, {"spent": 0.0, "income": 0.0})
        entry["spent" if value < 0 else "income"] += abs(value)
    return figures


def by_account():
    figures = account_figures()
    figures.setdefault(data.SYNC_PAUSED_ACCOUNT, {"spent": 0.0, "income": 0.0})
    order = ["DBS Checking", "OCBC Savings", "Amex Card"]
    assert set(figures) == set(order)
    total_spent = sum(entry["spent"] for entry in figures.values())
    assert round(total_spent, 2) == data.OCTOBER_SPENT
    rows = []
    for account in order:
        spent, income = figures[account]["spent"], figures[account]["income"]
        share = spent / total_spent * 100
        rows.append(
            f'<div class="tl-acct"><b>{account}</b><span class="amt exp">{data.sm(-spent)}</span>'
            f'<span class="amt inc">{data.sm(income) if income else "0.00"}</span>'
            f'<div class="ctrack"><i style="width:{share:.1f}%"></i></div><small>{percent(share)} of spending</small></div>')
    head = '<div class="tl-acct tl-acct-head"><span></span><span>Spent</span><span>Income</span></div>'
    return tray("By account", head + ''.join(rows), aside="<small>October</small>")


# ---------- Trends ----------

def category_movers():
    rows = []
    for name, usual in data.INSIGHT_USUAL_START.items():
        higher = data.insight_gap(name)
        rows.append(row_pair(f'<span class="tl-arrow exp">{ic("up", "s")}</span>{name}',
                             f"{money(data.OCTOBER_CATEGORY_SPENT[name])} so far against {money(usual)} usual for 1-3 Oct",
                             f'<span class="amt exp">+{money(higher)}<small>+{percent(higher / usual * 100)}</small></span>'))
    return tray("Category movers", ''.join(rows)
                + '<div class="qual">Same baseline as the Overview Insights: the same days in July, August and September. It covers Groceries and Dining only, so no category shows a fall.</div>',
                aside="<small>1-3 October</small>")


def recorded_weekday_counts():
    counts = [0] * 7
    day = date(2025, 11, 1)
    while day <= TODAY:
        if (day.year, day.month - 1) != (2026, 7):
            counts[day.weekday()] += 1
        day += timedelta(days=1)
    return counts


def weekday_averages(period_total):
    counts = recorded_weekday_counts()
    averages = [period_total * share / 100 / count for share, count in zip(data.WEEKDAY_SHARES, counts)]
    assert abs(sum(a * c for a, c in zip(averages, counts)) - period_total) < 0.01
    return averages, counts


def day_of_week_pattern(period_total):
    averages, _ = weekday_averages(period_total)
    peak = max(range(7), key=lambda weekday: averages[weekday])
    top = averages[peak]
    items = [(letter, averages[weekday] * 1000.0 / top, "c", weekday == peak) for weekday, letter in enumerate("MTWTFSS")]
    names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    return tray("Day-of-week pattern", (
        f'<div class="selp" style="margin-top:0"><span class="lab">{names[peak]} is highest<small>Average per {names[peak]}</small></span><span class="mid exp">-{money(top)}</span></div>'
        + month_bars(items, "mini tl-dow", label="Average spending for each weekday")
        + '<div class="qual">Sample split of the period total across weekdays, divided by the recorded days of each weekday. August has no records.</div>'),
        aside="<small>Nov 2025 - Oct 2026</small>")


def fixed_vs_flexible(period_total):
    charges, monthly = subscription_figures()
    complete_months = len(data.COMPLETE_MONTHS)
    fixed = round(monthly * complete_months, 2)
    flexible = round(period_total - fixed, 2)
    fixed_share, flexible_share = fixed / period_total * 100, flexible / period_total * 100
    split = (f'<div class="tl-split" role="img" aria-label="Planned recurring and everyday spending"><i style="width:{fixed_share:.2f}%;background:var(--action)"></i>'
             f'<i style="width:{flexible_share:.2f}%;background:var(--incomplete)"></i></div>')
    columns = (f'<div class="tl-two"><div><span class="lab"><i class="km" style="--c:var(--action)"></i> Planned recurring</span><b class="amt exp">-{money(fixed)}</b><small>{percent(fixed_share)}</small></div>'
               f'<div><span class="lab"><i class="km" style="--c:var(--incomplete)"></i> Everyday spending</span><b class="amt exp">-{money(flexible)}</b><small>{percent(flexible_share)}</small></div></div>')
    return tray("Fixed vs flexible", split + columns
                + f'<div class="qual">Recurring is {money(monthly)} a month ({" and ".join(entry[2] for entry in charges)}) over the {complete_months} complete months.</div>',
                aside="<small>Nov 2025 - Oct 2026</small>")


def savings_rate_figures():
    rates = {key: (data.SAMPLE_MONTHLY_SALARY - data.month_value(*key)) / data.SAMPLE_MONTHLY_SALARY * 100 for key in RECORDED_PERIOD_MONTHS}
    complete = [rate for key, rate in rates.items() if key in data.COMPLETE_MONTHS]
    return rates, sum(complete) / len(complete), len(complete)


def savings_rate():
    rates, average, complete_count = savings_rate_figures()
    items = []
    for year, month in PERIOD_MONTHS:
        key = (year, month)
        letter = MONTH_SHORT[month][0]
        if key not in rates:
            items.append((letter, None, "g", False))
            continue
        items.append((letter, rates[key] * 10, "c" if key in data.COMPLETE_MONTHS else "p", key == (2026, 9)))
    return tray("Savings rate", (
        f'<div class="selp" style="margin-top:0"><span class="lab">Period average<small>{complete_count} complete months</small></span><span class="mid inc">{percent(average)}</span></div>'
        + month_bars(items, "mini tl-rate", label="Savings rate for each month")
        + f'<div class="qual">October {percent(rates[(2026, 9)])} is incomplete and stays out of the average. August has no records.</div>'),
        aside="<small>Income minus spending</small>")


# ---------- Money ----------

def projected_month_end(spent, average):
    return spent + average * (DAYS_IN_MONTH - DAYS_ELAPSED) / DAYS_IN_MONTH


def forecast_budget_row(name, spent, limit, average, compact=False):
    projected = projected_month_end(spent, average)
    over = projected > limit
    if not over:
        chip = '<span class="tl-chip">On pace</span>'
    else:
        wording = f"Over by {money(projected - limit)}" + ("" if compact else " at this pace")
        chip = f'<span class="tl-chip over">{wording}</span>'
    line_position = "calc(100% - 2px)" if over else f"{projected / limit * 100:.2f}%"
    return (
        f'<div class="catrow"><b>{name}</b><span class="amt" style="font-weight:500">{money(spent)} of {money(limit)}</span>'
        f'<div class="tl-fbar" style="--c:var(--{name.lower()})"><div class="tl-fill"><i style="width:{min(spent / limit * 100, 100):.1f}%"></i></div>'
        f'<s class="{"over" if over else ""}" style="left:{line_position}"></s></div>'
        f'<div class="tl-status"><small class="sub">{money(limit - spent)} left / {percent(spent / limit * 100)} used</small>{chip}</div></div>')


def category_budget_rows():
    averages = category_averages()
    return ''.join(forecast_budget_row(name, spent, limit, averages[name]) for name, spent, limit in budgets())


def forecast_legend():
    return ('<div class="adjl tl-legend"><span><i style="--c:var(--c0,var(--control))"></i>Fill: spent</span>'
            '<span><i style="--c:var(--text);width:2px"></i>Line: month-end forecast</span></div>')


def with_forecast_legend(card):
    assert card.endswith("</div>")
    return card.removesuffix("</div>") + forecast_legend() + "</div>"


def net_worth_series():
    oct_net = sum(value for *_, value, moved in data.OCT if not moved)
    sep_net = sum(value for *_, value, moved in data.SEP if not moved)
    september = round(data.NET_WORTH_NOW - oct_net, 2)
    august = round(september - sep_net, 2)
    return data.NET_WORTH_SAMPLE_NOV_TO_JUL + [august, september, data.NET_WORTH_NOW]


def net_worth_trend():
    series = net_worth_series()
    assert len(series) == 12
    change = series[-1] - series[0]
    low, high = min(series), max(series)
    chart = line_chart([("main", list(enumerate(series)))], (0, 11), (low, high), "Net worth over twelve months", [(11, series[-1], "sel")])
    labels = [MONTH_SHORT[month][0] for _, month in PERIOD_MONTHS]
    return tray("Net worth trend", (
        f'<div class="selp" style="margin-top:0"><span class="lab">Assets minus cards<small>Now, 3 October</small></span><span class="mid inc">{data.sm(series[-1], True)}</span></div>'
        f'<div class="lab inc" style="margin-top:2px">{data.sm(change, True)} over 12 months, +{percent(change / series[0] * 100)}</div>'
        + chart + axis(labels)
        + '<div class="qual">November to July use sample history; August to October follow from the recorded entries.</div>'),
        aside="<small>Nov 2025 - Oct 2026</small>")


def card_utilisation():
    used = data.AMEX_OWED / data.AMEX_LIMIT * 100
    return tray("Card utilisation", (
        '<div class="catrow"><b>Amex Card total balance</b>'
        f'<span class="amt" style="font-weight:500">{money(data.AMEX_OWED)} of {money(data.AMEX_LIMIT)} limit</span>'
        f'<div class="ctrack" style="--c:var(--action)"><i style="width:{used:.1f}%"></i></div>'
        f'<small class="sub">{percent(used)} of the limit used / {money(data.AMEX_LIMIT - data.AMEX_OWED)} available</small></div>'
        f'<div class="kv"><span>Statement payable</span><b>{money(data.AMEX_OWED)}</b></div>'
        f'<div class="kv"><span>Payable by</span><b>{data.AMEX_DUE_DAY}</b></div>'
        f'<div class="kv"><span>Statement closes</span><b>{data.AMEX_CLOSE_DAY} October</b></div>'),
        aside="<small>1 card</small>")


def plan_events(plans):
    events = []
    for day, month, name, _, value in plans:
        when = date(2026, MONTH_SHORT.index(month) + 1, int(day))
        if 0 <= (when - TODAY).days <= CASH_FLOW_WINDOW_DAYS:
            events.append((when, value, name, data.PLAN_ACCOUNT[name]))
    return sorted(events, key=lambda event: event[0])


def plans_cash_flow(plans):
    events = plan_events(plans)
    spendable = data.DBS_CHECKING + data.OCBC_OWN_BALANCE
    moving = [event for event in events if event[3] in data.SPENDABLE_ACCOUNTS]
    other = [event for event in events if event[3] not in data.SPENDABLE_ACCOUNTS]
    balance, points = spendable, [(0, spendable)]
    lowest = (0, balance, TODAY)
    for when, value, _, _ in moving:
        offset = (when - TODAY).days
        points.append((offset, balance))
        balance = round(balance + value, 2)
        points.append((offset, balance))
        if balance < lowest[1]:
            lowest = (offset, balance, when)
    points.append((CASH_FLOW_WINDOW_DAYS, balance))
    low = math.floor(lowest[1] / AXIS_STEP) * AXIS_STEP
    high = math.ceil(max(value for _, value in points) / AXIS_STEP) * AXIS_STEP
    chart = line_chart([("ref", [(0, spendable), (CASH_FLOW_WINDOW_DAYS, spendable)]), ("main", points)], (0, CASH_FLOW_WINDOW_DAYS), (low, high),
                       "Running spendable balance over thirty days", [(lowest[0], lowest[1], "sel")])
    end = TODAY + timedelta(days=CASH_FLOW_WINDOW_DAYS)
    movers = " and ".join(event[2] for event in moving)
    skipped = " and ".join(f"{event[2]} is charged to {event[3].removesuffix(' Card')}" for event in other)
    explanation = f'{movers} {"moves" if len(moving) == 1 else "move"} it' + (f", {skipped} and does not" if other else "")
    today_note = " (today)" if lowest[2] == TODAY else ""
    return tray("Plans cash flow", (
        f'<div class="selp" style="margin-top:0"><span class="lab">Spendable after plans<small>On {day_label(end)}, from {money(spendable)} today</small></span><span class="mid">{money(balance)}</span></div>'
        + chart + axis([day_label(TODAY), day_label(TODAY + timedelta(days=CASH_FLOW_WINDOW_DAYS // 2)), day_label(end)])
        + f'<div class="lab" style="margin-top:6px"><i class="km" style="--c:var(--selectedmark)"></i> Lowest balance: {money(lowest[1])} on {day_label(lowest[2])}{today_note}</div>'
        + f'<div class="qual">Axis runs from {money(low)} to {money(high)}, not from zero. Dashed line: today\'s balance. DBS Checking plus OCBC Savings own balance; {explanation}.</div>'),
        aside="<small>Next 30 days</small>")


def trend_tiles():
    total = sum(period_category_totals().values())
    return [category_movers(), day_of_week_pattern(total), fixed_vs_flexible(total), savings_rate()]


TILE_CSS = """
.tl-fbar{position:relative;grid-column:1 / -1;margin-top:5px}
.tl-fill{display:flex;height:7px;border-radius:4px;background:var(--tint);overflow:hidden}
.tl-fill i{display:block;height:100%;background:var(--c)}
.tl-fbar s{position:absolute;top:-3px;bottom:-3px;width:2px;border-radius:1px;background:var(--text)}
.tl-fbar s.over{background:var(--expense)}
.tl-status{grid-column:1 / -1;display:flex;flex-wrap:wrap;justify-content:space-between;align-items:center;gap:3px 8px}
.tl-chip{padding:1px 7px;border-radius:8px;background:var(--tint);color:var(--income);font-size:10px;font-weight:600;white-space:nowrap;margin-left:auto}
.tl-chip.over{background:color-mix(in srgb,var(--expense) 14%,transparent);color:var(--expense)}
.tl-legend{margin:8px 0 0;flex-wrap:nowrap;white-space:nowrap}
.tl-chart{position:relative;height:84px;margin:10px 0 4px;border-bottom:1px solid var(--control)}
.tl-chart svg{position:absolute;inset:0;width:100%;height:100%;overflow:visible}
.tl-line{fill:none;stroke-width:2;vector-effect:non-scaling-stroke;stroke-linejoin:round;stroke-linecap:round}
.tl-line.main{stroke:var(--action)}
.tl-line.ref{stroke:var(--gap);stroke-width:1.5;stroke-dasharray:4 3}
.tl-dot{position:absolute;width:10px;height:10px;margin:-5px 0 0 -5px;border-radius:50%;background:var(--action)}
.tl-dot.sel{background:var(--selectedmark)}
.tl-axis{display:flex;justify-content:space-between;padding:0 3%;font-size:10px;color:var(--subtext)}
.tl-total{border-top:1px solid var(--edge);border-bottom:0}
.tl-total span{color:var(--text);font-weight:600}
.tl-total b{font-size:18px;font-weight:500;letter-spacing:-.3px}
.tl-flag{display:flex;gap:8px;align-items:flex-start;margin-top:8px;padding:8px 10px;background:var(--noticebg);color:var(--notice);border:1px solid var(--notice);border-left-width:3px;border-radius:10px;font-size:10px;line-height:1.4}
.tl-flag b{font-size:12px;display:block}
.tl-fix{flex-shrink:0;border:1px solid var(--control);border-radius:8px;padding:5px 9px;font-size:10px;font-weight:600;color:var(--action);white-space:nowrap;background:var(--surface)}
.tl-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:1px 10px;padding:8px 0;border-bottom:1px solid var(--edge);align-items:baseline}
.tl-row>b{font-size:12px;font-weight:600;display:flex;align-items:center;gap:6px}
.tl-row>small{grid-column:1;font-size:10px;color:var(--subtext)}
.tl-row>.amt{grid-column:2;grid-row:1 / span 2;align-self:center}
.tl-arrow{display:inline-flex}
.tl-acct{display:grid;grid-template-columns:minmax(0,1fr) 64px 64px;gap:2px 8px;align-items:baseline;padding:7px 0;border-bottom:1px solid var(--edge)}
.tl-acct:last-child{border-bottom:0}
.tl-acct>b{font-size:12px;font-weight:600}
.tl-acct .ctrack{grid-column:1 / -1}
.tl-acct>small{grid-column:1 / -1;font-size:10px;color:var(--subtext)}
.tl-acct-head{padding:0 0 3px;font-size:10px;color:var(--subtext);text-align:right}
.tl-split{display:flex;gap:2px;height:14px;border-radius:7px;overflow:hidden;margin:8px 0}
.tl-two{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.tl-two b{display:block;font-size:14px;font-weight:600;text-align:left;margin-top:2px}
.tl-two small{font-size:10px;color:var(--subtext)}
.bars.mini.tl-dow,.bars.mini.tl-rate{height:72px}
"""
