import math
from html import escape
from html.parser import HTMLParser

ICONS = {
    "home": "M4 11l8-7 8 7v8a1 1 0 0 1-1 1h-4v-6h-6v6H5a1 1 0 0 1-1-1z",
    "history": "M7 3h10a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM9 8h6M9 12h6M9 16h4",
    "trends": "M3 20h18M6 17v-6M10 17V6M14 17v-8M18 17v-4",
    "money": "M4 7h15a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1zM4 7l3-3h10v3M15 13.5h2",
    "plus": "M12 5v14M5 12h14",
    "gear": "M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z",
    "cart": "M3 4h2.2l2.3 10.5h10l2.3-7.5H6.4M9 19.5h.01M17 19.5h.01",
    "bag": "M5.5 8h13l-1 12h-11zM9 8V7a3 3 0 0 1 6 0v1",
    "leaf": "M5 19c0-8 6-13.5 14-14 0 9-5 14-13 14zM5 19l7-7",
    "tram": "M7 3h10a2 2 0 0 1 2 2v9a3 3 0 0 1-3 3H8a3 3 0 0 1-3-3V5a2 2 0 0 1 2-2zM5 10h14M9 13.5h.01M15 13.5h.01M8.5 21l1.5-4M15.5 21l-1.5-4",
    "dining": "M7 3v18M4.5 3v5a2.5 2.5 0 0 0 5 0V3M17 21V3c-2.5 1.5-3 6-3 8.5h3",
    "dollar": "M12 3v18M16 7.5c0-1.7-1.8-3-4-3s-4 1.3-4 3 1.8 2.6 4 3 4 1.3 4 3-1.8 3-4 3-4-1.3-4-3",
    "transfer": "M4 8h15l-3.5-3.5M20 16H5l3.5 3.5",
    "card": "M3 6h18v12H3zM3 10h18M7 14.5h3",
    "bank": "M3 10l9-6 9 6M5 10v8M9.5 10v8M14.5 10v8M19 10v8M3 20h18",
    "jar": "M8 3h8M8 3v3L6 9v10a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V9l-2-3V3M9 13h6",
    "pocket": "M5 5h14v7a7 7 0 0 1-14 0zM9 10l3 3 3-3",
    "calendar": "M4 6h16v14H4zM4 10h16M8 3v4M16 3v4",
    "repeat": "M17 2l3 3-3 3M4 11V9a4 4 0 0 1 4-4h12M7 22l-3-3 3-3M20 13v2a4 4 0 0 1-4 4H4",
    "receipt": "M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6M9 16h3",
    "camera": "M4 7h3l2-3h6l2 3h3v12H4zM12 10a3 3 0 1 0 0 6 3 3 0 0 0 0-6z",
    "image": "M4 5h16v14H4zM4 16l5-5 4 4 3-3 4 4M15 9h.01",
    "search": "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4",
    "left": "M15 6l-6 6 6 6",
    "right": "M9 6l6 6-6 6",
    "down": "M6 9l6 6 6-6",
    "up": "M6 15l6-6 6 6",
    "check": "M5 12.5l4.5 4.5L19 7",
    "grip": "M9 6h.01M15 6h.01M9 12h.01M15 12h.01M9 18h.01M15 18h.01",
    "close": "M6 6l12 12M18 6L6 18",
    "cloud": "M7 18a4 4 0 0 1-.6-8A6 6 0 0 1 18 9a4.5 4.5 0 0 1-.5 9z",
    "alert": "M12 3.5l9 15.5H3zM12 10v4M12 16.5h.01",
    "trash": "M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3",
    "pencil": "M4 20h4L19 9l-4-4L4 16zM14 6l4 4",
    "tag": "M3 12V4h8l10 10-8 8zM7.5 8.5h.01",
    "lock": "M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3",
    "devices": "M3 5h13v9H3zM1 17h17M19 8h3v11h-3z",
    "mail": "M3 6h18v12H3zM3 7l9 6 9-6",
    "info": "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 11v5M12 7.5h.01",
    "play": "M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zM10 9v6l5-3z",
    "dumbbell": "M6.5 7v10M3.5 9.5v5M17.5 7v10M20.5 9.5v5M6.5 12h11",
    "shield": "M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z",
    "car": "M4 16h16M5.5 16l1.5-5h10l1.5 5M4.5 16v3h2.5v-2M19.5 16v3H17v-2M8 13.5h.01M16 13.5h.01",
    "house": "M4 11l8-7 8 7v9H4zM10 20v-5h4v5",
    "donut": "M12 3a9 9 0 1 0 9 9M12 3v6a3 3 0 1 0 3 3h6A9 9 0 0 0 12 3z",
    "map": "M3 4h9v16H3zM12 4h9v9h-9zM12 13h9v7h-9z",
    "statement": "M7 3h10v18H7zM10 8h4M10 12h4M10 16h2",
    "more": "M5 12h.01M12 12h.01M19 12h.01",
    "restore": "M4 12a8 8 0 1 0 2.3-5.7L4 8.5M4 3.5v5h5",
    "bulb": "M9 18h6M10 21h4M12 3a6 6 0 0 0-4 10.5c.7.7 1 1.5 1 2.5h6c0-1 .3-1.8 1-2.5A6 6 0 0 0 12 3z",
    "target": "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 7.5a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9zM12 11.2a.8.8 0 1 0 0 1.6.8.8 0 0 0 0-1.6z",
    "gauge": "M4 17a8 8 0 1 1 16 0M12 17l4-5",
    "server": "M4 4h16v6H4zM4 14h16v6H4zM8 7h.01M8 17h.01",
    "key": "M8 15a4 4 0 1 1 3.5-6H21v4h-3v3h-3v-3h-3.5A4 4 0 0 1 8 15z",
    "backspace": "M21 6H9l-6 6 6 6h12zM12 10l4 4M16 10l-4 4",
    "crop": "M6 2v14a2 2 0 0 0 2 2h14M2 6h14a2 2 0 0 1 2 2v14",
    "week": "M4 6h16v14H4zM4 10h16M8 3v4M16 3v4M7 14h10",
    "filter": "M4 7h10M18 7h2M4 17h4M12 17h8M16 5v4M10 15v4",
    "wallet": "M4 7h15a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1zM4 7l3-3h10v3M15 13.5h2",
    "palette": "M12 3a9 9 0 1 0 0 18c1 0 1.5-.7 1.5-1.5 0-.5-.2-.8-.5-1.2-.3-.3-.5-.7-.5-1.2 0-.9.7-1.6 1.6-1.6H16a5 5 0 0 0 5-5c0-4-4-7.5-9-7.5zM7.5 12h.01M9.5 8h.01M14.5 8h.01",
}


def sprite():
    out = ['<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs>']
    for k, d in ICONS.items():
        out.append(f'<symbol id="i-{k}" viewBox="0 0 24 24"><path d="{d}"/></symbol>')
    out.append("</defs></svg>")
    return "".join(out)


def ic(name, cls=""):
    return f'<svg class="i {cls}" aria-hidden="true"><use href="#i-{name}"/></svg>'


# ---------- money ----------

def f2(v):
    return f"{abs(v):,.2f}"


def sm(v, cur=False, plus=True):
    sign = "+" if v > 0 and plus else ("-" if v < 0 else "")
    return f"{sign}{'S$' if cur else ''}{f2(v)}"


def kind_of(v, moved=False):
    if moved:
        return "mov"
    return "inc" if v > 0 else ("exp" if v < 0 else "mov")


def amt(v, moved=False, cur=False, extra=""):
    text = (("S$" if cur else "") + f2(v)) if moved else sm(v, cur)
    return f'<span class="amt {kind_of(v, moved)}">{text}{extra}</span>'


# ---------- categories ----------

CAT = {
    "Dining": ("dining", "dining"),
    "Groceries": ("cart", "groceries"),
    "Supermarket": ("bag", "supermarket"),
    "Fresh Market": ("leaf", "freshmarket"),
    "Direct to Groceries": ("cart", "groceries"),
    "Transport": ("tram", "transport"),
    "Salary": ("dollar", "salary"),
    "Transfer": ("transfer", "subtext"),
    "No category": ("tag", "subtext"),
    "Opening balance": ("lock", "subtext"),
    "Fitness": ("dumbbell", "fitness"),
    "Insurance": ("shield", "housing"),
    "Subscription": ("play", "dining"),
    "Statement": ("statement", "action"),
    "Adjustment": ("pencil", "subtext"),
}


def med(cat, icon=None):
    icn, color = CAT.get(cat, ("tag", "subtext"))
    return f'<span class="med" style="--c:var(--{color})">{ic(icon or icn)}</span>'


def row(name, meta, value, cat, moved=False, extra_amt="", icon=None, cls=""):
    return (
        f'<div class="row {cls}">{med(cat, icon)}<div class="rc"><b>{name}</b><small>{meta}</small></div>'
        f"{amt(value, moved, extra=extra_amt)}</div>"
    )


def daterow(day, mon, name, meta, value, moved=False, value_text=None):
    a = f'<span class="amt {kind_of(value, moved)}">{value_text}</span>' if value_text else amt(value, moved)
    return (
        f'<div class="row"><div class="date"><b>{day}</b><small>{mon}</small></div>'
        f'<div class="rc"><b>{name}</b><small>{meta}</small></div>{a}</div>'
    )


# ---------- frame chrome ----------

def statusbar():
    return '<div class="st"><span>9:41</span><span>5G</span></div>'


TABS = [("Overview", "home"), ("History", "history"), ("Trends", "trends"), ("Money", "money")]


def tabbar(active):
    parts = []
    for name, icon in TABS:
        on = " on" if name == active else ""
        parts.append(f'<span class="{on.strip()}">{ic(icon)}{name}</span>')
    parts.append(f'<span class="add">{ic("plus")}Add</span>')
    return f'<div class="tabbar">{"".join(parts)}</div>'


def header(title, date=None, acts="", gear=True, back=None):
    b = f'<div class="back">{ic("left")}{back}</div>' if back else ""
    d = f'<div class="dl">{date}</div>' if date else ""
    g = ic("gear") if gear else ""
    return f'<div class="hd">{b}{d}<div class="tr"><h4>{title}</h4><div class="acts">{acts}{g}</div></div></div>'


def phone(body, tab=None, cls="", force="", extra="", body_cls=""):
    tb = tabbar(tab) if tab else ""
    fc = f" force-{force}" if force else ""
    return (
        f'<div class="app phone{fc} {cls}">{statusbar()}<div class="pb {body_cls}">{body}</div>'
        f'{extra}{tb}<div class="homebar"></div></div>'
    )


class SheetParts(HTMLParser):
    def __init__(self, markup):
        super().__init__(convert_charrefs=False)
        self.markup = markup
        self.depth = 0
        self.parts = []
        self.offsets = [0]
        for line in markup.splitlines(keepends=True):
            self.offsets.append(self.offsets[-1] + len(line))
        self.feed(markup)

    def position(self):
        line, column = self.getpos()
        return self.offsets[line - 1] + column

    def handle_starttag(self, tag, attrs):
        if self.depth == 0:
            self.start = self.position()
            self.classes = dict(attrs).get("class", "").split()
        if tag not in {"br", "img", "input", "hr", "meta", "link", "source", "wbr"}:
            self.depth += 1

    def handle_endtag(self, tag):
        self.depth -= 1
        if self.depth == 0:
            end = self.markup.index(">", self.position()) + 1
            self.parts.append((self.classes, self.markup[self.start:end]))


def sheet_contents(sheet):
    header, body, actions, input_pad = [], [], [], []
    has_input = 'class="pad"' in sheet or 'class="kbd"' in sheet
    for classes, markup in SheetParts(sheet).parts:
        target = header if "shh" in classes else input_pad if "pad" in classes or "kbd" in classes else body if has_input and any(c in classes for c in ("danger", "quiet", "sec")) else actions if "btn" in classes else body
        target.append(markup)
    footer = "".join(actions + input_pad)
    return ("".join(header) + '<div class="sheet-scroll">' + "".join(body) + '</div>'
            + (f'<div class="sheet-footer">{footer}</div>' if footer else ""))


def sheet_surface(sheet, cls=""):
    if 'class="pad"' in sheet:
        cls = (cls + " keypad").strip()
    return f'<div class="sheet {cls}"><div class="handle"></div>{sheet_contents(sheet)}</div>'


def sheet_alert(title, detail="", tone="error"):
    heading = f"<b>{title}</b>" if detail else title
    text = f"<small>{detail}</small>" if detail else ""
    role = "alert" if tone == "error" else "status"
    return f'<div class="sheet-alert {tone}" role="{role}">{heading}{text}</div>'


def sheet_phone(under, sheet, tab=None, cls="", force="", under_cls="", sheet_cls="", alert="", under_sheet=""):
    fc = f" force-{force}" if force else ""
    tb = tabbar(tab) if tab else ""
    cls = " ".join(c for c in cls.split() if c != "long")
    background = f'<div class="under">{under}</div>'
    if under_sheet:
        background = f'<div class="sheet-backdrop">{background}{sheet_surface(under_sheet)}</div><div class="under"></div>'
        sheet_cls = (sheet_cls + " sheet-front").strip()
    return (
        f'<div class="app phone{fc} {cls}">{statusbar()}<div class="pb sheetwrap">'
        f'{background}{sheet_surface(sheet, sheet_cls)}'
        f'</div>{alert}{tb}<div class="homebar"></div></div>'
    )


def sheet_head(title, left="Cancel", right=""):
    return f'<div class="shh"><span>{left}</span><h4>{title}</h4><span class="{"primary-action" if right else ""}">{right}</span></div>'


def dialog(title, text, actions):
    acts = "".join(f'<span class="{c}">{t}</span>' for t, c in actions)
    p = f"<p>{text}</p>" if text else ""
    return f'<div class="scrim"><div class="dialog"><h4>{title}</h4>{p}<div class="da">{acts}</div></div></div>'


def snack(text, action=""):
    a = f"<b>{action}</b>" if action else ""
    return f'<div class="snack"><span>{text}</span>{a}</div>'


def light_card(body, cls=""):
    if cls == "form-card":
        return f'<div class="form-card">{body}</div>'
    return f'<div class="vl light-only"><div class="light-card {cls}">{body}</div></div><div class="vd">{body}</div>'


def light_sections(light, dark):
    return f'<div class="vl light-only">{light}</div><div class="vd">{dark}</div>'


def tray(title, body, cls="", aside=""):
    t = f'<div class="th">{title}{aside}</div>' if title else ""
    return f'<div class="tray {cls}">{t}{body}</div>'


def seg(options, active, cls=""):
    return f'<div class="seg {cls}">' + "".join(
        f'<span class="{"on" if o == active else ""}">{o}</span>' for o in options
    ) + "</div>"


def chips(options, active):
    return '<div class="chips">' + "".join(
        f'<span class="{"on" if o == active else ""}">{o}</span>' for o in options
    ) + "</div>"


def period(label, sub="", prev_off=False, next_off=False):
    s = f"<small>{sub}</small>" if sub else ""
    return (
        f'<div class="period"><span class="ar {"off" if prev_off else ""}">{ic("left","s")}</span>'
        f'<b>{label}{s}</b><span class="ar {"off" if next_off else ""}">{ic("right","s")}</span></div>'
    )


def fld(label, value, cls="", chevron=False):
    ch = ic("right") if chevron else ""
    return f'<div class="fld {cls}"><span>{label}</span><b>{value}{ch}</b></div>'


def toggle_fld(label, on=True, hint=""):
    h = f"<small>{hint}</small>" if hint else ""
    return (
        f'<div class="setrow"><div><b style="font-weight:500">{label}</b>{h}</div>'
        f'<span class="sw {"on" if on else ""}"></span></div>'
    )


def setrow(title, sub="", val="", chevron=True, switch=None):
    s = f"<small>{sub}</small>" if sub else ""
    if switch is not None:
        right = f'<span class="sw {"on" if switch else ""}"></span>'
    else:
        right = f'<span class="val">{val}{ic("right") if chevron else ""}</span>'
    return f'<div class="setrow"><div><b>{title}</b>{s}</div>{right}</div>'


def btn(text, kind="", icon=None):
    i = ic(icon, "s") if icon else ""
    style = ' style="display:flex;align-items:center;justify-content:center;gap:6px"' if icon else ""
    return f'<div class="btn {kind}"{style}>{i}{text}</div>'


def numpad():
    keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", ic("backspace")]
    inner = "".join(
        f'<div class="key" style="display:grid;place-items:center">{k}</div>' if k.startswith("<svg") else f'<div class="key">{k}</div>'
        for k in keys
    )
    return f'<div class="pad" aria-label="Number pad">{inner}</div>'


def keyboard():
    r1 = "".join(f"<span>{c}</span>" for c in "qwertyuiop")
    r2 = "".join(f"<span>{c}</span>" for c in "asdfghjkl")
    r3 = '<span class="w">shift</span>' + "".join(f"<span>{c}</span>" for c in "zxcvbnm") + '<span class="w">del</span>'
    r4 = '<span class="w">123</span><span class="sp">space</span><span class="w">return</span>'
    return f'<div class="kbd"><div>{r1}</div><div>{r2}</div><div>{r3}</div><div>{r4}</div></div>'


def notice(title, text, actions=()):
    a = "".join(f"<span>{x}</span>" for x in actions)
    na = f'<div class="na">{a}</div>' if actions else ""
    return f'<div class="notice" role="status"><b>{title}</b>{text}{na}</div>'


def error_box(title, detail="", action=""):
    d = f"<small>{detail}</small>" if detail else ""
    return f'<div class="err" role="alert"><b>{title}</b>{d}</div>' + (btn(action) if action else "")


def empty(icon, title, text, action="", cat="Transfer"):
    a = btn(action) if action else ""
    a = f'<div style="margin-top:12px">{a}</div>' if action else ""
    return (
        f'<div class="empty"><span class="med" style="--c:var(--action)">{ic(icon)}</span>'
        f"<b>{title}</b><p>{text}</p>{a}</div>"
    )


def fab(text):
    return f'<div class="fab">{ic("plus")}{text}</div>'


# ---------- charts ----------

def month_bars(items, cls="", maxv=1000.0, label="Monthly spending bars"):
    """items: list of (axis_label, value or None, kind c|p|g|x, selected)."""
    n = len(items)
    bars, axis = [], []
    for lab, v, k, sel in items:
        h = 0 if v is None else max(3.0, v / maxv * 100)
        st = f' style="height:{h:.1f}%"' if k in ("c", "p") else ""
        bars.append(f'<div class="b {k}{" sel" if sel else ""}"><i{st}></i></div>')
        axis.append(f'<span class="{"sel" if sel else ""}">{lab}</span>')
    return (
        f'<div class="bars {cls}" style="--n:{n}" role="img" aria-label="{label}">{"".join(bars)}</div>'
        f'<div class="axis {cls}" style="--n:{n}">{"".join(axis)}</div>'
    )


def year_bars(items, maxv=7000.0):
    bars, axis = [], []
    for lab, v, sel in items:
        bars.append(f'<div class="b{" sel" if sel else ""}"><i style="height:{v / maxv * 100:.1f}%"></i></div>')
        axis.append(f'<span class="{"sel" if sel else ""}">{lab}</span>')
    return f'<div class="bars yr">{"".join(bars)}</div><div class="axis yr">{"".join(axis)}</div>'


def donut(segs, center_name, center_share, size=""):
    r = 46
    circ = 2 * math.pi * r
    gap = 1.8
    off = 0.0
    parts = []
    for name, share, color in segs:
        length = circ * share / 100.0
        dash = max(length - gap, 0.6)
        parts.append(
            f'<circle cx="60" cy="60" r="{r}" fill="none" stroke="var(--{color})" stroke-width="17" '
            f'stroke-dasharray="{dash:.2f} {circ - dash:.2f}" stroke-dashoffset="{-off:.2f}"/>'
        )
        off += length
    st = f' style="width:{size}px;height:{size}px"' if size else ""
    ctr = f'<div class="ctr"><b>{center_name}</b><small>{center_share}</small></div>' if center_name else ""
    return f'<div class="donut"{st} role="img" aria-label="Donut chart"><svg viewBox="0 0 120 120">{"".join(parts)}</svg>{ctr}</div>'


def cmap(blocks, height=136, min_label=(64, 34)):
    """blocks: list of (name, share, color). Slice layout: first block left column, second top-right, rest bottom-right row.
    Blocks too small for a name and share get an adjacent label below the map."""
    total = sum(b[1] for b in blocks)
    W, H, g = 100.0, float(height), 4.0
    rects = []
    first = blocks[0]
    w1 = first[1] / total * W
    rects.append((first, 0, 0, w1, H))
    rest = blocks[1:]
    rest_total = sum(b[1] for b in rest)
    if rest:
        top = rest[0]
        h2 = top[1] / rest_total * H if len(rest) > 1 else H
        rects.append((top, w1, 0, W - w1, h2))
        bottom = rest[1:]
        bt = sum(b[1] for b in bottom)
        x = w1
        for b in bottom:
            bw = b[1] / bt * (W - w1)
            rects.append((b, x, h2, bw, H - h2))
            x += bw
    html, adjacent = [], []
    for (name, share, color), x, y, w, h in rects:
        px_w = w / 100 * 288
        label_width = px_w - 16
        word_width = max(len(word) for word in name.split()) * 7
        lines = max(1, math.ceil(len(name) * 6.5 / max(label_width, 1)))
        label_height = 16 + lines * 14.4 + 14 + 2
        fits = px_w >= min_label[0] and word_width <= label_width and h >= max(min_label[1], label_height)
        label = f"<span>{name}</span><small>{share:.1f}%</small>" if fits else ""
        style = (
            f"left:calc({x:.2f}% + {0 if x == 0 else g / 2}px);top:{y + (0 if y == 0 else g / 2):.1f}px;"
            f"width:calc({w:.2f}% - {g / 2 if x == 0 or x + w >= 99.9 else g}px);height:{h - (g / 2 if y == 0 or y + h >= H - .1 else g):.1f}px;"
            f"background:var(--{color})"
        )
        html.append(f'<div class="blk" style="{style}" title="{name} {share:.1f}%">{label}</div>')
        if not fits:
            adjacent.append(f'<span><i style="--c:var(--{color})"></i>{name} {share:.1f}%</span>')
    adj = f'<div class="adjl">{"".join(adjacent)}</div>' if adjacent else ""
    return f'<div class="cmap" style="height:{height}px" role="img" aria-label="Category map">{"".join(html)}</div>{adj}'


def rank(items, chevron=True, income=False):
    """items: (name, share_text, amount, color, sub)"""
    out = ['<div class="rank">']
    for name, share, value, color, sub in items:
        s = f"{share}" + (f" / {sub}" if sub else "")
        out.append(
            f'<div class="rr"><span class="km" style="--c:var(--{color})"></span><div><b>{name}</b><small>{s}</small></div>'
            f'<span class="amt{ " inc" if income else "" }">{sm(abs(value) if income else -abs(value))}</span>{ic("right") if chevron else "<span></span>"}</div>'
        )
    out.append("</div>")
    return "".join(out)


def cattrack(name, value, pct, color, right_text=None, over=False):
    rt = right_text or sm(-abs(value))
    return (
        f'<div class="catrow"><b>{name}</b><span class="amt exp">{rt}</span>'
        f'<div class="ctrack {"over" if over else ""}" style="--c:var(--{color})"><i style="width:{min(pct, 100):.1f}%"></i></div></div>'
    )


# ---------- desktop ----------

SIDE = [("Overview", "home"), ("History", "history"), ("Trends", "trends"), ("Budgets", "gauge"), ("Accounts", "bank"), ("Plans", "repeat")]


def desktop(active, content, title, sub="", acts=None, force="", overlay="", sync="Sync on"):
    items = "".join(
        f'<span class="{"on" if n == active else ""}">{ic(i, "s")}{n}</span>' for n, i in SIDE
    )
    settings = f'<span class="{"on" if active == "Settings" else ""}">{ic("gear", "s")}Settings</span>'
    acts = acts if acts is not None else (
        f'<span class="sbtn">{ic("search", "s")}Search</span><span class="pbtn">{ic("plus", "s")}Add entry</span>'
    )
    s = f'<div class="sub">{sub}</div>' if sub else ""
    fc = f" force-{force}" if force else ""
    return (
        f'<div class="app win{fc}"><div class="wbar"><span class="dots"><i></i><i></i><i></i></span><span>SpendWise</span><span class="dots"><i></i><i></i><i></i></span></div>'
        f'<div class="wbody"><nav class="side"><div class="wordmark">Spend<i>Wise</i></div>{items}<div class="gap"></div>{settings}<small class="syn">{sync}</small></nav>'
        f'<div class="ws"><div class="whead"><div>{s}<h4>{title}</h4></div><div class="acts">{acts}</div></div>{content}{overlay}</div></div></div>'
    )
