from html import escape
from html.parser import HTMLParser

import data
import s_history_trends
import s_add
import s_overview
import s_money
import s_settings
import tiles
from comp import donut, header, ic, month_bars, period, phone, rank, seg, sheet_surface, statusbar, tray


class Element:
    def __init__(self, tag="", attrs=(), start=""):
        self.tag = tag
        self.attrs = dict(attrs)
        self.start = start
        self.end = ""
        self.children = []

    def inner(self):
        return "".join(child.html() if isinstance(child, Element) else child for child in self.children)

    def html(self):
        return self.start + self.inner() + self.end

    def has_class(self, name):
        return name in self.attrs.get("class", "").split()

    def find(self, name):
        if self.has_class(name):
            return self
        for child in self.children:
            if isinstance(child, Element):
                found = child.find(name)
                if found is not None:
                    return found
        return None


class Markup(HTMLParser):
    def __init__(self, markup):
        super().__init__(convert_charrefs=False)
        self.root = Element()
        self.stack = [self.root]
        self.feed(markup)
        self.close()
        assert len(self.stack) == 1, "Unclosed source markup"

    def handle_starttag(self, tag, attrs):
        node = Element(tag, attrs, self.get_starttag_text())
        self.stack[-1].children.append(node)
        if tag not in {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(Element(tag, attrs, self.get_starttag_text()))

    def handle_endtag(self, tag):
        assert self.stack[-1].tag == tag, f"Unbalanced source tag: {tag}"
        self.stack.pop().end = f"</{tag}>"

    def handle_data(self, data):
        self.stack[-1].children.append(data)

    def handle_entityref(self, name):
        self.handle_data(f"&{name};")

    def handle_charref(self, name):
        self.handle_data(f"&#{name};")


def phone_body(frame):
    body = Markup(frame["html"]).root.find("pb")
    assert body is not None
    return body.inner()


def desktop_panes(frame):
    root = Markup(frame["html"]).root
    group = root.find("dg2") or root.find("dg2e")
    assert group is not None
    panes = [child.html() for child in group.children if isinstance(child, Element)]
    assert len(panes) == 2
    return panes


def confirmation_parts(frame):
    body = Markup(frame["html"]).root.find("pb")
    scrim = body.find("scrim")
    assert scrim is not None
    backdrop = "".join(child.html() if isinstance(child, Element) else child
                       for child in body.children if child is not scrim)
    return backdrop, scrim.inner()


def rail(active):
    items = [("Overview", "home"), ("History", "history"), ("Money", "money"), ("Settings", "gear"), ("Add", "plus")]
    return '<nav class="fold-rail" aria-label="Main navigation"><div class="fold-tabs">' + "".join(
        f'<span class="{"on" if title == active else ""}">{ic(icon)}<small>{title}</small></span>'
        for title, icon in items) + '</div></nav>'


def frame(identifier, label, caption, body, active="Overview", detail="", form="", dialog="", folded=False, fab="", full=False):
    if folded:
        display = body
    else:
        if detail:
            content = f'<div class="fold-selection"><div class="fold-list">{body}</div><aside class="fold-detail">{detail}</aside></div>'
        elif form:
            content = (f'<div class="fold-add-context"><div class="fold-page-scroll">{body}</div></div>'
                       f'<aside class="fold-entry">{sheet_surface(form)}</aside>')
        else:
            content = f'<div class="fold-page-scroll"><div class="fold-page">{body}</div></div>'
        fab_button = f'<div class="fab">{ic("plus")}{fab}</div>' if fab else ""
        overlay = f'<div class="fold-confirmation">{dialog}</div>' if dialog else ""
        display = (f'<div class="app fold-display">{statusbar()}'
                   f'<div class="fold-body">{content}{fab_button}<div class="fold-dock">{rail(active)}</div>{overlay}</div>'
                   '<div class="homebar"></div><div class="crease" aria-hidden="true"></div></div>')
    posture = "folded" if folded else "open"
    markup = (f'<figure class="fold-figure {posture}{" full" if full else ""}" id="{identifier}" '
              f'data-posture="{posture}">'
              f'<figcaption><b>{escape(label)}</b><p>{escape(caption)}</p></figcaption>'
              f'<div class="fold-shell">{display}</div></figure>')
    return dict(id=identifier, title=label, caption=caption, posture=posture, html=markup)


FOLDABLE_CSS = """
:root{--fold-scroll-pad:6px;--fold-heading-gap:18px}
.fold-scroll{overflow-x:auto;padding-bottom:var(--fold-scroll-pad)}
.fold-section>h3{margin-bottom:var(--fold-heading-gap)}
.fold-figure{width:max-content;margin-bottom:26px}
.fold-figure>figcaption{width:auto;max-width:960px;margin:0 0 12px;color:var(--ink);font-size:15px}
.fold-figure>figcaption b{font-weight:600}
.fold-figure>figcaption p{font-size:12px;max-width:none;color:var(--quiet);margin-top:3px}
.fold-shell{width:max-content;background:var(--ink);padding:6px;border:1px solid var(--line);border-radius:26px;box-shadow:0 8px 24px rgba(0,0,0,.07)}
.fold-display{width:960px;height:720px;aspect-ratio:4/3;display:flex;flex-direction:column;overflow:hidden;border-radius:20px;position:relative}
.fold-display>.st{height:28px;padding:4px 18px 0;flex-shrink:0}
.fold-display>.st:before{display:none}
.fold-display>.homebar{height:14px}
.fold-body{flex:1;min-height:0;position:relative;overflow:hidden}
.fold-page-scroll{height:100%;overflow:auto;overscroll-behavior:contain;scrollbar-width:thin}
.fold-page{padding:14px 86px 80px 18px;min-height:100%;position:relative}
.fold-display .hd{margin-bottom:14px}
.fold-display .hd .acts{font-size:11px;gap:12px}
.fold-overview{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;align-items:stretch}
.fold-widget{min-width:0;margin:0}
.fold-widget.wide{grid-column:span 2}
.fold-widget>.tray{height:100%;margin-bottom:0}
.fold-overview .kv{gap:8px}
.fold-overview .kv b{white-space:normal;text-align:right}
.fold-overview .split{flex-wrap:wrap;gap:10px}
.fold-overview .hero{font-size:42px}
.fold-period-chart .bars{height:160px}
.fold-breakdown{display:grid;grid-template-columns:150px minmax(0,1fr);gap:18px;align-items:center;padding:4px 0}
.fold-breakdown .donut{width:150px;height:150px;margin:6px auto}
.fold-compact .fold-breakdown{grid-template-columns:104px minmax(0,1fr);gap:12px}
.fold-compact .fold-breakdown .donut{width:104px;height:104px}
.fold-compact .wk .wb{height:26px}
.fold-band .band{grid-template-columns:repeat(4,minmax(0,1fr));align-items:center}
.fold-band .band .lead{grid-column:auto}
.fold-history-grid{display:grid;grid-template-columns:minmax(0,3fr) minmax(0,2fr);gap:10px;align-items:start}
.fold-history-grid>div{min-width:0}
.fold-pair{display:grid;grid-template-columns:minmax(0,3fr) minmax(0,2fr);gap:10px;align-items:stretch}
.fold-pair>.tray{margin:0}
.trend-shared-top{display:grid;grid-template-columns:minmax(250px,1fr) minmax(0,2fr);gap:18px;align-items:center;margin-bottom:12px}
.trend-shared-top>.trend-shared-controls>.seg{margin-bottom:8px}
.trend-shared-top .bars{height:150px;margin-top:0}
.trend-shared-bottom{display:grid;grid-template-columns:minmax(0,1.08fr) minmax(0,1fr);gap:12px;align-items:start}
.trend-shared-bottom>div:first-child,.trend-shared-right{display:flex;flex-direction:column;gap:12px;min-width:0}
.trend-shared-bottom .pane{margin:0}
.trend-shared-right>.usual{margin:0;padding:14px;background:var(--surface);border:1px solid var(--edge);border-radius:14px}
.trend-shared-breakdown .scope{margin:0 0 8px}
.trend-shared-breakdown .selp{margin:0 0 4px}
.trend-shared-breakdown .fold-breakdown{grid-template-columns:130px minmax(0,1fr);gap:12px}
.trend-shared-breakdown .donut{width:130px;height:130px}
.trend-shared-breakdown .rr{grid-template-columns:10px minmax(0,1fr) auto;gap:8px;padding:7px 0}
.trend-averages{width:100%;border-collapse:collapse;table-layout:fixed;font-size:11px}
.trend-averages th,.trend-averages td{padding:9px 0;border-bottom:1px solid var(--edge);text-align:right;vertical-align:middle}
.trend-averages th{font-size:10px;color:var(--subtext);font-weight:500}
.trend-averages th:first-child,.trend-averages td:first-child{width:38%;text-align:left}
.trend-averages td:first-child>span{display:flex;align-items:center;gap:6px}
.trend-averages td:not(:first-child){white-space:nowrap}
.trend-averages td:last-child{color:var(--subtext)}
.trend-averages tr:last-child td{border-bottom:0}
.trend-shared-right .avg{font-size:11px;color:var(--subtext);white-space:nowrap}
.fold-money-grid{display:grid;grid-template-columns:minmax(0,2fr) minmax(0,1fr);gap:10px;align-items:stretch}
.fold-money-cards{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;align-items:stretch}
.fold-money-cards>.tray{margin:0}
.fold-money-side{display:flex;flex-direction:column}
.fold-money-side>.tray{flex:1;margin:0}
.fold-tiles{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;align-items:stretch}
.fold-tiles>.tray{margin:0}
.fold-masonry{column-count:2;column-gap:10px}
.fold-masonry>.tray{break-inside:avoid}
.fold-settings-list>.tray:last-child,.fold-list>.tray:last-child{margin-bottom:0}
.mcal{display:grid;grid-template-columns:repeat(7,minmax(0,1fr));gap:3px;text-align:center}
.mcal .mh{font-size:10px;color:var(--subtext);padding:3px 0}
.mc{position:relative;display:flex;flex-direction:column;align-items:center;gap:2px;min-height:46px;padding:5px 1px 4px;border-radius:7px;color:var(--text)}
.mc b{font-size:11px;font-weight:600;line-height:1.1;color:var(--text)}
.mc .amt{font-size:9px;line-height:1.1;letter-spacing:-.2px}
.mc-today{outline:1.5px solid var(--text);outline-offset:-1px}
.mc-dot{position:absolute;top:4px;right:4px;width:5px;height:5px;border-radius:50%;background:var(--income);display:inline-block}
.mc-legend i.mc-dot{position:static;width:7px;height:7px}
.mc-key-today{width:10px;height:10px;border-radius:3px;outline:1.5px solid var(--text);outline-offset:-1px;display:inline-block}
.mc-legend{flex-wrap:nowrap;white-space:nowrap;margin:8px 0 0}
.mc-foot{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;border-top:1px solid var(--edge);margin-top:8px;padding-top:8px}
.mc-foot small{display:block;font-size:10px;color:var(--subtext)}
.mc-foot b{font-size:12px;font-weight:600;font-variant-numeric:tabular-nums}
.fold-selected-card{background:var(--tint);box-shadow:inset 3px 0 var(--action)}
.cmp-head{display:grid;grid-template-columns:minmax(0,1fr) 84px 84px;gap:8px;font-size:10px;color:var(--subtext);margin:8px 0 2px;text-align:right}
.cmp-head span:first-child{grid-column:2}
.cmp .rr{grid-template-columns:12px minmax(0,1fr) 84px 84px}
.cmp .amt,.cmp .avg{text-align:right}
.cmp .avg{color:var(--subtext)}
.fold-selection{height:100%;margin-right:72px;display:grid;grid-template-columns:calc(50% + 36px) minmax(0,1fr)}
.fold-list{min-width:0;overflow:auto;padding:14px 16px 80px 18px;scrollbar-width:thin;position:relative}
.fold-detail{min-width:0;height:100%;border-left:1px solid var(--edge);display:flex;flex-direction:column;padding:14px 16px 16px}
.fold-detail>.hd{flex-shrink:0;margin-bottom:12px}
.fold-detail .hd h4{font-size:23px}
.fold-detail .hd .acts{gap:9px;font-size:11px}
.fold-detail-scroll{flex:1;min-height:0;overflow:auto;scrollbar-width:thin}
.fold-detail .donut{margin:18px auto;width:178px;height:178px}
.fold-detail .pane{padding:0;border:0;border-radius:0;background:transparent}
.fold-selected-row{background:var(--tint);box-shadow:inset 3px 0 var(--action);border-radius:9px;padding:10px!important}
.fold-close{display:inline-flex;align-items:center;gap:3px;color:var(--action);white-space:nowrap}
.fold-dock{position:absolute;right:9px;bottom:10px;display:flex;flex-direction:column;align-items:flex-end;gap:10px;z-index:6}
.fold-rail{width:54px;padding:12px 2px;background:var(--surface);border:1px solid var(--edge);border-radius:18px;z-index:6}
.fold-tabs{display:flex;flex-direction:column;gap:14px}
.fold-tabs>span{display:flex;flex-direction:column;gap:4px;align-items:center;color:var(--subtext)}
.fold-tabs>span.on{color:var(--action);font-weight:600}
.fold-tabs small{font-size:8px;line-height:1.2}
.fold-tabs>span:last-child{color:var(--action);margin-top:2px;font-weight:600}
.fold-tabs>span:last-child svg{background:var(--action);color:var(--onaction);border-radius:10px;padding:5px;width:32px;height:32px}
.fold-body>.fab{right:75px;bottom:10px;z-index:6;width:max-content}
.fold-display .reserve{display:none}
.fold-detail .selp{flex-wrap:wrap}
.fold-list .fold-period-chart .bars{height:140px}
.fold-detail .fld>b{white-space:normal;text-align:right;max-width:72%}
.fold-add-context{position:absolute;left:0;right:50%;top:0;bottom:0}
.fold-add-context .fold-page-scroll{padding:14px 18px 22px}
.fold-add-context .fold-overview{grid-template-columns:minmax(0,1fr);gap:10px}
.fold-add-context .fold-widget.wide{grid-column:auto}
.fold-entry{position:absolute;left:50%;right:0;top:0;bottom:0;background:var(--surface)}
.fold-entry .sheet{height:100%;max-height:none;border:0;border-left:1px solid var(--edge);border-radius:0;box-shadow:none;padding:16px 82px 14px 16px}
.fold-entry .handle{display:none}
.fold-entry .sheet-scroll{flex:1}
.fold-entry .shh{grid-template-columns:58px minmax(0,1fr) 58px;margin-bottom:14px}
.fold-entry .shh h4{font-size:21px}
.fold-entry .key{font-size:22px;padding:8px 0}
.fold-entry .sheet-footer .btn{padding:12px}
.fold-entry .sheet.keypad .fld{padding:11px 0}
.fold-confirmation{position:absolute;inset:0 72px 0 0;display:grid;place-items:center;background:rgba(0,0,0,.2);z-index:10}
.fold-confirmation .dialog{width:308px;max-width:308px;margin:0;padding:20px;box-shadow:0 12px 40px rgba(0,0,0,.15)}
.crease{position:absolute;left:calc(50% - 2px);top:0;bottom:0;width:4px;background:linear-gradient(90deg,transparent,rgba(0,0,0,.055),rgba(255,255,255,.24),transparent);z-index:7;pointer-events:none}
html[data-app=dark] .app .crease{background:linear-gradient(90deg,transparent,rgba(0,0,0,.22),rgba(255,255,255,.045),transparent)}
.fold-continuity{display:flex;align-items:flex-start;gap:24px;width:max-content}
.folded .fold-shell{padding:0;border:0;background:transparent;border-radius:38px;box-shadow:none}
.folded .phone.long{height:760px;min-height:760px}
.folded .phone.long .pb{overflow:auto;scrollbar-width:thin}
.folded>figcaption{max-width:320px}
.folded.full .phone.long{height:auto;min-height:760px}
.folded.full .phone.long .pb{overflow:visible}
.fold-phones{display:flex;flex-wrap:wrap;align-items:flex-start;gap:24px;width:max-content;max-width:100%}
.fold-pair{margin-bottom:10px}
.fold-band .band.three{grid-template-columns:repeat(3,minmax(0,1fr))}
"""


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
    return header(title, subtitle, actions + close) + f'<div class="fold-detail-scroll">{content}</div>'


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
    heading = header("History", "All accounts") + period("October 2026") + seg(["List", "Calendar"], "List")
    summary = f'<div class="fold-band">{data.band(3032.60, 167.40, 3200.00, 500.00)}</div>'
    top = data.top_categories(data.OCT)
    if selected:
        return heading + summary + top + week_card(True) + register(True) + calendar_card() + tiles.biggest_entries() + tiles.by_account()
    side = top + week_card() + calendar_card() + tiles.biggest_entries() + tiles.by_account()
    return heading + summary + f'<div class="fold-history-grid"><div>{register(False)}</div><div>{side}</div></div>'


def trends_chart(selected=False):
    chart = (seg(["Expense", "Income"], "Expense") + seg(["Month by month", "Year by year"], "Month by month")
             + period("Nov 2025 - Oct 2026", next_off=True)
             + month_bars(data.spread(2026, 9, (2026, 6) if selected else None), label="Monthly spending; July selected" if selected else "Monthly spending; no month selected")
)
    return header("Trends", back="History") + tray("Period chart", chart, "fold-period-chart")


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
    return s_history_trends.shared_trends_page()


def trends_selected_page():
    return s_history_trends.shared_trends_page(selected_scope=True)


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
    return (heading + f'<div class="search">{ic("search", "s")}Search entries</div>' + summary + data.top_categories(data.OCT) + week_card()
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
    return header("Settings") + f'<div class="{layout}">{groups}</div>'


SAMPLE_NOTE = tiles.sample_note()




FRAME_COUNT = 21
FOLDED_COUNT = 7
DEVICE_NAMES = ("Samsung Galaxy Z Fold8", "Apple iPhone Duo")
INTRO = ("Samsung Galaxy Z Fold8 and Apple iPhone Duo share one design: the approved phone design opens into a 4:3 landscape canvas "
         "with right-edge navigation within thumb reach. Charts, amounts and seed content come from the frames above; app controls depict "
         "states, and each display scrolls to show its full content.")


def check_references(approved):
    continuity_widgets = [data.w_today, data.w_recent, data.w_coming]
    assert phone_body(approved["ov-default"]) == data.overview_head() + ''.join(widget() for widget in continuity_widgets)
    assert ''.join(widget() for widget in tiles.ALL_WIDGETS) == phone_body(approved["ov-custom"]).removeprefix(data.overview_head())
    assert phone_budgets() == phone_body(approved["mo-budgets"])
    assert phone_accounts() == phone_body(approved["mo-accounts"])
    assert phone_plans() == phone_body(approved["mo-plans-attention"])
    assert tiles.current_week_spent() == round(data.OCTOBER_SPENT + sum(entry[4] for entry in data.expense_entries(data.SEP_SAMPLE)), 2)
    tiles.assert_seed_figures(s_money.accounts_body())


def overview_section():
    open_note = "All 16 widgets (the 12 approved plus Safe to spend, Pace vs usual, Subscriptions and Needs attention) share one scrolling dashboard with mixed card sizes." + s_overview.OPEN_TRENDS_NOTE
    overview = frame("overview", "Overview - open", open_note + SAMPLE_NOTE, overview_page())
    return "Overview", "", [overview]


def history_section(approved):
    _, edit = desktop_panes(approved["hi-desk"])
    detail = detail_panel("Edit entry", strip_heading(edit), "3 October 2026")
    full_note = "The month summary band spans the top with the Top categories card below it; the day register (left) and By week, the calendar, Biggest entries and By account (right) scroll together."
    selected_note = "Left, one column: summary band, Top categories, By week, the full register with FairPrice highlighted, the calendar, Biggest entries and By account; the edit form is on the right."
    full = frame("history-full", "History - open, nothing selected", full_note + SAMPLE_NOTE, history_page(), "History")
    selected = frame("history-selected", "History - open, entry selected", selected_note + SAMPLE_NOTE, history_page(True), "History", detail=detail)
    return "History", "", [full, selected]


def trends_section():
    full_note = "Opened from History, which stays selected in the rail, and Back reads History. October 2026 is selected. The full-width chart card sits above the shared whole-period breakdown and Insights on the left, with the selected-period headline and Category averages on the right."
    selected_note = "Opened from History. October 2026 is selected. The same full-screen composition switches the shared breakdown scope to Selected month; the selected-period headline and Category averages stay in the right column."
    full = frame("trends-full", "Trends - open, whole-period scope", full_note + SAMPLE_NOTE, trends_page(), "History")
    selected = frame("trends-selected", "Trends - open, selected-month scope", selected_note + SAMPLE_NOTE, trends_selected_page(), "History")
    return "Trends", "", [full, selected]


def money_section(approved):
    dining = detail_panel("Dining", strip_heading(phone_body(approved["mo-budget-detail"])), "October 2026", '<span>Edit</span>')
    full_note = "All spending spans the top; budget cards with their month-end forecast and Coming up (left) and Observations (right) scroll together and end level, with Add budget floating just left of the navigation."
    selected_note = "Left, one column: All spending, every budget card with its month-end forecast and Dining highlighted, Observations and Coming up; the Dining detail is on the right."
    accounts_note = "The reference account list (left) sits beside Net worth trend and Card utilisation, with Add account floating above the navigation."
    plans_note = "The reference plan list (left) sits beside Plans cash flow with its lowest point labelled."
    return "Money", "", [
        frame("money-full", "Money - open, nothing selected", full_note, money_page(), "Money", fab="Add budget"),
        frame("money-selected", "Money - open, budget selected", selected_note, money_page(True), "Money", detail=dining),
        frame("money-accounts", "Money Accounts - open, nothing selected", accounts_note, accounts_page(), "Money", fab="Add account"),
        frame("money-plans", "Money Plans - open, nothing selected", plans_note, plans_page(), "Money"),
    ]


def settings_section(approved):
    detail = detail_panel("Trends breakdown", strip_heading(phone_body(approved["st-trends"])))
    selected_note = "Left, one column: the same six group cards with Trends breakdown highlighted; its controls are on the right."
    full = frame("settings-full", "Settings - open, nothing selected", "The six phone settings groups sit as separate cards in two packed columns.", settings_page(), "Settings")
    selected = frame("settings-selected", "Settings - open, group selected", selected_note, settings_page(True), "Settings", detail=detail)
    return "Settings", "", [full, selected]


def add_section():
    note = "Left, one column: all 16 Overview widgets; the full-height Add entry form with number pad is on the right."
    return "Add entry", "", [frame("add-entry", "Add entry - open, expense draft", note + SAMPLE_NOTE, overview_page(), form=s_add.add_sheet())]


def phone_frame(identifier, label, caption, body, tab):
    return frame(identifier, label, caption, phone(body, tab, "long"), folded=True, full=True)


def phone_section():
    history_note = "The Top categories card follows the summary band; Biggest entries and By account sit between By week and the day register."
    trends_note = "Opened from History, so History is the selected tab and Back reads History. The four trend tiles follow the whole-period breakdown."
    return "Phone", "fold-phones", [
        phone_frame("phone-overview", "Phone Overview - full scroll", "All 16 widgets in catalogue order; the four new ones close the page." + s_overview.OPEN_TRENDS_NOTE + SAMPLE_NOTE, phone_overview(), "Overview"),
        phone_frame("phone-history", "Phone History - full scroll", history_note + SAMPLE_NOTE, phone_history(), "History"),
        phone_frame("phone-trends", "Phone Trends - full scroll", trends_note + SAMPLE_NOTE, phone_trends(), "History"),
        phone_frame("phone-budgets", "Phone Money Budgets - full scroll", "Each category budget bar carries its month-end forecast and limit marker.", phone_budgets(), "Money"),
        phone_frame("phone-accounts", "Phone Money Accounts - full scroll", "Net worth trend follows the summary band; Card utilisation follows Credit cards.", phone_accounts(), "Money"),
        phone_frame("phone-plans", "Phone Money Plans - full scroll", "Plans cash flow follows the Next up list.", phone_plans(), "Money"),
    ]


def confirmation_section(approved):
    dining = detail_panel("Dining", strip_heading(phone_body(approved["mo-budget-detail"])), "October 2026", '<span>Edit</span>')
    _, dialog = confirmation_parts(approved["mo-budget-delete"])
    note = "A compact centered confirmation overlays the selected Dining budget and its detail pane."
    return "Confirmation dialog", "", [frame("confirmation", "Money - open, delete confirmation", note, money_page(True), "Money", detail=dining, dialog=dialog)]


def continuity_section(approved):
    widgets = [("w_today", data.w_today), ("w_recent", data.w_recent), ("w_coming", data.w_coming)]
    folded = frame("continuity-folded", "Overview - folded, 3 October", "Approved phone Overview with tabs and Add.", approved["ov-default"]["html"], folded=True)
    opened = frame("continuity-open", "Overview - open, 3 October", "The same three widgets and seed values reflow across the open display.", overview_page(widgets))
    return "Folding continuity", "fold-continuity", [folded, opened]


def build(approved):
    check_references(approved)
    return [overview_section(), history_section(approved), trends_section(), money_section(approved), settings_section(approved),
            add_section(), phone_section(), confirmation_section(approved), continuity_section(approved)]


def frames_of(sections):
    return [item for _, _, frames in sections for item in frames]


def render_section(title, wrapper, frames):
    markup = "".join(item["html"] for item in frames)
    if wrapper:
        markup = f'<div class="{wrapper}">{markup}</div>'
    return f'<div class="group fold-section"><h3>{escape(title)}</h3><div class="fold-scroll">{markup}</div></div>'


def render(sections):
    groups = "".join(render_section(*section) for section in sections)
    return f'<section class="area" id="area-foldables"><header><h2>Foldables</h2><p>{INTRO}</p></header>{groups}</section>'


def collect_figures(node, found):
    if node.tag == "figure":
        found.append(node)
    for child in node.children:
        if isinstance(child, Element):
            collect_figures(child, found)


def check_foldables(sections, markup):
    figures = []
    collect_figures(Markup(markup).root, figures)
    assert len(figures) == FRAME_COUNT == len(frames_of(sections)), len(figures)
    assert len({node.attrs["id"] for node in figures}) == FRAME_COUNT
    assert sum(node.attrs["data-posture"] == "folded" for node in figures) == FOLDED_COUNT
    assert chr(0x2014) not in markup
    for name in DEVICE_NAMES:
        assert markup.count(name) == 1
        assert all(name not in node.find("fold-shell").inner() for node in figures)
