from html import escape
from html.parser import HTMLParser

from comp import ic, sheet_surface, statusbar


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
    items = [("Overview", "home"), ("History", "history"), ("Trends", "trends"),
             ("Money", "money"), ("Settings", "gear"), ("Add", "plus")]
    return '<nav class="fold-rail" aria-label="Main navigation"><div class="fold-tabs">' + "".join(
        f'<span class="{"on" if title == active else ""}">{ic(icon)}<small>{title}</small></span>'
        for title, icon in items) + '</div></nav>'


def frame(identifier, label, caption, body, active="Overview", theme="light", detail="", form="", dialog="", folded=False, fab="", full=False):
    if folded:
        display = body.replace('class="app phone', 'class="app force-light phone', 1)
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
        display = (f'<div class="app fold-display force-{theme}">{statusbar()}'
                   f'<div class="fold-body">{content}{fab_button}<div class="fold-dock">{rail(active)}</div>{overlay}</div>'
                   '<div class="homebar"></div><div class="crease" aria-hidden="true"></div></div>')
    return (f'<figure class="fold-figure {"folded" if folded else "open"}{" full" if full else ""}" id="{identifier}" '
            f'data-theme="{theme}" data-posture="{"folded" if folded else "open"}">'
            f'<figcaption><b>{escape(label)}</b><p>{escape(caption)}</p></figcaption>'
            f'<div class="fold-shell">{display}</div></figure>')


FOLDABLE_CSS = """
body{overflow-x:auto}
main{max-width:1400px;padding:32px 36px 60px}
.fold-header{padding-bottom:26px;border-bottom:2px solid var(--line)}
.fold-header h1{font-size:42px;line-height:1.1;letter-spacing:-1px;font-weight:600}
.fold-header p{max-width:none;font-size:14px;color:var(--quiet);margin-top:10px}
.fold-header .targets{white-space:nowrap}
.fold-section{margin-top:38px}
.fold-section h2{font-size:24px;font-weight:600;margin-bottom:18px}
.fold-figure{width:max-content;margin-bottom:26px}
.fold-figure>figcaption{width:auto;max-width:960px;margin:0 0 12px;color:var(--ink);font-size:15px}
.fold-figure>figcaption b{font-weight:600}
.fold-figure>figcaption p{font-size:12px;max-width:none;color:var(--quiet);margin-top:3px}
.fold-shell{width:max-content;background:#25272A;padding:6px;border:1px solid #3B3E43;border-radius:26px;box-shadow:0 8px 24px rgba(0,0,0,.07)}
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
.force-dark .crease{background:linear-gradient(90deg,transparent,rgba(0,0,0,.22),rgba(255,255,255,.045),transparent)}
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
.fold-footer{margin-top:30px;font-size:12px;color:var(--quiet);max-width:none}
"""
