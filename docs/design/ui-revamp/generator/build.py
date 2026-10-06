import json
import sys
from html import escape
from pathlib import Path

from styles import PAGE_CSS, APP_CSS
from tokens import TOKENS
from comp import *
import data
import s_overview, s_history_trends, s_add, s_money, s_settings, s_states

BASE = Path(__file__).resolve().parent
OUT = BASE.parent / "spendwise-reference.html"
FRAMES_JSON = BASE.parent / "frames.json"

s_overview.build()
s_history_trends.build_history()
s_history_trends.build_trends()
s_add.build()
s_money.build()
s_settings.build_settings()
s_settings.build_sync()
s_states.build_fresh()
s_states.build_states()
FR = data.FRAMES

AREAS = [
    ("overview", "Overview", "Today, recent entries and what is coming up. Notices sit above the widgets; Edit Overview chooses the rest."),
    ("history", "History", "The dense record: month list with signed day totals, week totals, calendar and search."),
    ("trends", "Trends", "Month by month or year by year, one spread per arrow, and the selected period's expense or income breakdown. Chart and level come from Settings."),
    ("add", "Add and edit", "The Add sheet from the tab bar, the receipt path, pickers and editing. Amount first; Update before Delete; Undo after."),
    ("money", "Money", "Budgets, accounts and plans, kept separate. Pockets are counted once; card statement cuts are not due dates."),
    ("settings", "Settings", "Reached from the gear. Appearance, the Trends breakdown choices, categories and the recycle bin."),
    ("sync", "Sync", "Hosted sync by default: email and a code. Repair, renewal and the own-server path keep the app's fixed messages."),
    ("fresh", "Fresh install", "Every empty screen offers one next step and never draws unknown spending as zero."),
    ("states", "Loading, errors and app start", "Skeletons while loading, a named failure with Try again, save failures in transient sheet banners and the boot screens."),
]

NOT_DRAWN = {
    "Add account, no pocketable parents": "Not drawn: pockets are now added from an everyday account's page, so the locked state cannot occur.",
    "Legacy read-only entry view": "Not drawn: superseded by tap to edit; Edit entry draws the replacement.",
    "Swipe-to-delete entry confirmation": "Not drawn: superseded by Delete entry in the edit sheet, followed by Undo.",
    "Native receipt capture / camera": "Not drawn: platform camera UI.",
    "Native photo / file picker": "Not drawn: platform picker UI.",
    "Camera / photo permission prompt": "Not drawn: platform system dialog; the app's denied message is drawn.",
    "Conflict review": "Not drawn: no current screen or route, and no round approves one.",
    "Recycle bin filter": "Not drawn: the bin has section groups and no filter; none approved.",
    "Dedicated hosted sync status page": "Not drawn: status lives inline in Settings; all six states are drawn there.",
}
EXTRA_MAP = {
    "Transactions, daily, Evergreen dark": "hi-oct",
    "Stats, expenses, Evergreen dark": "tr-july",
    "Accounts, Evergreen dark": "mo-accounts",
}

# ---------- coverage check against the earlier 177-row inventory ----------
inv = json.loads((BASE.parent / "inventory.json").read_text(encoding="utf-8"))
covered = {}
for f in FR:
    for n in f["inv"]:
        covered.setdefault(n, []).append(f["id"])
for n, fid in EXTRA_MAP.items():
    covered.setdefault(n, []).append(fid)
missing = [r[0] for r in inv if r[0] not in covered and r[0] not in NOT_DRAWN]
if missing:
    print("UNMAPPED:", missing)
    sys.exit(1)
ids = [f["id"] for f in FR]
assert len(ids) == len(set(ids)), "duplicate ids"
extra_inv = {}
for n, fid in EXTRA_MAP.items():
    extra_inv.setdefault(fid, []).append(n)


def caption(f):
    return f'<figcaption><b>{f["title"]}</b>{f["caption"]}<br><code>{escape(f["code"])}</code></figcaption>'


def figure(f):
    if f["kind"] == "desktop":
        return f'<figure class="wide" id="{f["id"]}">{f["html"]}{caption(f)}</figure>'
    return f'<figure id="{f["id"]}">{f["html"]}{caption(f)}</figure>'


def render_area(key, title, intro):
    frames = [f for f in FR if f["area"] == key]
    groups = []
    for f in frames:
        if f["group"] not in groups:
            groups.append(f["group"])
    out = [f'<section class="area" id="area-{key}"><header><h2>{title}</h2><p>{intro}</p></header>']
    for g in groups:
        gf = [f for f in frames if f["group"] == g]
        phones = "".join(figure(f) for f in gf if f["kind"] != "desktop")
        desks = "".join(figure(f) for f in gf if f["kind"] == "desktop")
        out.append(f'<div class="group"><h3>{g}</h3>')
        if phones:
            out.append(f'<div class="frames">{phones}</div>')
        out.append(desks + "</div>")
        if key == "overview" and g == "Edit Overview":
            out.append('<div class="group" id="widget-catalogue"><h3>Widget catalogue</h3><p>All twelve widgets in their usual and sparse states, drawn at phone width. Usual states use seed values and the labelled samples named under each.</p>'
                       + s_overview.catalogue() + "</div>")
    out.append("</section>")
    return "".join(out)


def inventory_table():
    rows = []
    for key, title, _ in AREAS:
        rows.append(f'<tr class="areahead"><td colspan="4">{title}</td></tr>')
        for f in [f for f in FR if f["area"] == key]:
            earlier = f["inv"] + extra_inv.get(f["id"], [])
            e = escape(", ".join(earlier)) if earlier else "New in the approved design"
            kind = " (desktop)" if f["kind"] == "desktop" else ""
            rows.append(f'<tr><td><a href="#{f["id"]}">{f["title"]}</a>{kind}</td><td>{title} / {f["group"]}</td><td>{escape(f["code"])}</td><td>{e}</td></tr>')
    rows.append('<tr class="areahead"><td colspan="4">Listed in the earlier inventory, not drawn</td></tr>')
    for r in inv:
        if r[0] in NOT_DRAWN and r[0] not in covered:
            rows.append(f'<tr class="nd"><td>{r[0]}</td><td>{NOT_DRAWN[r[0]]}</td><td>{escape(r[1])}</td><td>{r[0]}</td></tr>')
    return ('<div class="inventory-wrap"><table class="inv"><thead><tr><th>Screen or state</th><th>Section</th><th>Code location</th><th>Earlier inventory row</th></tr></thead><tbody>'
            + "".join(rows) + "</tbody></table></div>")


def side_by_side():
    picks = [("ov-default", "Overview"), ("tr-july", "Trends"), ("hi-oct", "History"), ("add-expense", "Add sheet"), ("mo-budgets", "Money"), ("st-root", "Settings")]
    byid = {f["id"]: f for f in FR}
    out = []
    for fid, label in picks:
        h = byid[fid]["html"]
        lt = h.replace('class="app ', 'class="app force-light ', 1)
        dk = h.replace('class="app ', 'class="app force-dark ', 1)
        out.append(f'<div class="pair"><h4><a href="#{fid}">{label}</a></h4><div class="two"><div><small>Light</small>{lt}</div><div><small>Dark</small>{dk}</div></div></div>')
    return '<div class="pairs">' + "".join(out) + "</div>"


def appendix():
    trows = "".join(
        f'<tr><td>{t[3]}<br><small style="color:var(--quiet)">--{t[0]}</small></td><td><span class="swatch" style="background:{t[1]}"></span>{t[1]}</td>'
        f'<td><span class="swatch" style="background:{t[2]}"></span>{t[2]}</td><td>{t[4]}</td><td>{t[5]}</td></tr>' for t in TOKENS)
    colours = (f'<section><h3>Colour, light and dark</h3><div class="inventory-wrap" style="max-height:none;margin-top:0"><table class="tok"><thead><tr><th>Role and token</th><th>Light</th><th>Dark</th><th>Contrast, light</th><th>Contrast, dark</th></tr></thead><tbody>{trows}</tbody></table></div>'
               '<p style="font-size:12px;color:var(--quiet);margin-top:8px">WCAG ratios for the current token values. Text needs 4.5:1, essential marks and control boundaries 3:1. Decorative dividers carry no meaning. Every app frame on this page reads these two sets from one table.</p></section>')
    scale = [("34", "Today amount, hero balances", "500"), ("26", "Page titles, selected period amount", "600 / 500"), ("18", "Sheet titles, secondary amounts", "600 / 500"),
             ("14", "Tray titles, empty-state titles", "600"), ("12", "Rows, body, amounts in rows, buttons", "400 / 600"), ("10", "Meta lines, labels, chart axes, tab labels", "400")]
    sc = "".join(f'<div><span>{s} px</span><b style="font-size:{s}px;font-weight:{w.split(" ")[0]};line-height:1.15">S$45.70 Groceries</b><small style="margin-left:auto;color:var(--quiet);font-size:12px;text-align:right">{u}</small></div>' for s, u, w in scale)
    type_ = (f'<section><h3>Type scale</h3><p style="font-size:13px;margin-bottom:8px">Instrument Sans for every role, Arial offline. Tabular numerals for money. Names left, signed amounts right.</p><div class="scale">{sc}</div></section>')
    space = ('<section><h3>Spacing, radii and elevation</h3><table class="tok"><tbody>'
             '<tr><th>Spacing</th><td>4 px unit. Phone gutter 14, tray padding 12 (Today 14), gap between trays 10, desktop workspace 18 to 22, desktop columns 14 to 18.</td></tr>'
             '<tr><th>Radii</th><td>Today 20 20 7 20 (asymmetric). Record trays 14. Controls and buttons 8 to 10. Floating bottom tab bars 20. Sheets 22 at the top. Medallions 9. Map blocks 8.</td></tr>'
             '<tr><th>Elevation</th><td>Light content sections sit in white cards on a light blue canvas, separated by neutral hairlines. Dark surfaces retain their lightness steps: canvas, tray, level 2. Only sheets, side panels and menus lift: a neutral soft shadow in light; in dark, the level 2 surface and a control-colour top edge. Every phone sheet sizes to content, up to two thirds of the phone height. Headers, actions and input pads remain pinned while taller content scrolls inside. Desktop flows use compact content-sized dialogs. No dimming veil appears behind sheets; compact confirmation dialogs use a light scrim.</td></tr>'
             '<tr><th>Focus</th><td>Underline only: a 2 px focus-colour underline and a thin caret on the active field. No rings or tinted boxes inside the app.</td></tr>'
             '</tbody></table></section>')
    chart_content = (month_bars([("Complete", 860, "c", False), ("Selected", 900, "c", True), ("No records", None, "g", False), ("Incomplete", 188.7, "p", False)]).replace('--n:4', '--n:4')
                  + '<div class="adjl" style="margin-top:10px"><span><i style="--c:var(--dining)"></i>Dining</span><span><i style="--c:var(--groceries)"></i>Groceries</span><span><i style="--c:var(--transport)"></i>Transport</span><span><i style="--c:var(--supermarket)"></i>Supermarket</span><span><i style="--c:var(--freshmarket)"></i>Fresh Market</span></div>')
    chart_spec = '<div class="app specimen">' + light_card(chart_content, "chart-card") + '</div>'
    charts = ('<section><h3>Chart rules</h3>' + chart_spec +
              '<p style="font-size:13px;margin-top:10px">Bars are flat-topped accent columns. A selected bar uses the prominent purple selected-mark fill in both themes, with no border, outline or ring. A selected incomplete bar uses that same fill; its caption still identifies the incomplete period. An incomplete period is a paler fill with an accent outline and one sentence below the chart. A month with no records is a short dashed stub, never a zero bar; slots before the first record stay blank. Values live in the selection line, not on bars. Donuts name the largest category and share in the centre. Map blocks show name and share; a block too small for both gets an adjacent colour-linked label, never a bare number. The ranked list always follows with names, shares and signed amounts. Category colours come from each saved category colour through its light or dark counterpart.</p></section>')
    icons = ["home", "history", "trends", "money", "plus", "gear", "cart", "bag", "leaf", "dining", "tram", "dollar", "transfer", "card", "bank", "jar", "calendar", "repeat", "receipt", "camera", "search", "alert", "lock", "trash"]
    icon_spec = '<div class="app specimen" style="display:flex;flex-wrap:wrap;gap:14px;color:var(--text)">' + "".join(ic(i, "l") for i in icons) + "</div>"
    icon_sec = f'<section><h3>Icon style</h3>{icon_spec}<p style="font-size:13px;margin-top:10px">Rounded 1.8 px line icons on a 24 px grid. Category icons sit in medallions: a 30 px rounded square in the tint surface with the icon in the category colour. Canvas headline amounts use Instrument Sans with the standard amount weight and expense colour, without an adjacent icon. Labels always carry the meaning.</p></section>'

    comps = [
        ("Record tray", tray("Recent entries", row("FairPrice groceries", "Today / Supermarket / Amex Card", -42.50, "Supermarket")), "Surface, 1 px divider edge, radius 14. Lists sit inside trays; Today uses white with a neutral hairline in light, tint in dark, and the asymmetric corner."),
        ("Medallion row", row("To savings", "Transfer / DBS to OCBC", 500.00, "Transfer", moved=True) + row("Monthly salary", "Salary / DBS Checking", 3200.00, "Salary"), "Medallion, name, meta line, right-aligned signed amount. Transfers carry no sign and stay neutral."),
        ("Summary band", data.band(3032.60, 167.40, 3200.00, 500.00), "The signed net leads and takes the colour of its sign; spent, income and moved follow at row size."),
        ("Segmented control", seg(["Month by month", "Year by year"], "Month by month"), "White track and neutral hairline in light; tint track and control boundary in dark. The chosen part has an accent underline."),
        ("FAB", '<div style="position:relative;height:52px">' + fab("Add budget") + "</div>", "Compact and labelled, inside list screens only (Add budget, Add account, Add category). Lists reserve 58 px of end space under it. Add entry lives in the tab bar."),
        ("Widget card", data.w_card(), "A tray with a plain title naming the question it answers; one link at most."),
        ("Notice", notice("Sync is paused", "Reconnect to send your latest entries. Your entries are saved on this device.", ["Reconnect sync"]), "One warm tone reserved for notices. Errors use the error pair. Notices sit above content, never over it."),
        ("Sheet", '<div class="sheet" style="border-radius:22px;flex:none"><div class="handle"></div>' + sheet_head("Add entry", "Cancel", "") + light_card(fld("Category", "Groceries / Supermarket", chevron=True), "form-card") + "</div>", "Light blue sheet backing with white amount, form and number-pad cards and a neutral top hairline in light; level 2 backing, surface form groups and a control-colour top edge in dark. Form rows use 10 px vertical padding, or 8 px with a number pad. 22 px top radius and handle. The only raised layer besides menus."),
        ("Number pad", '<div class="amtf"><small>Amount / SGD</small><strong>-42.50<span class="caret"></span></strong></div>' + numpad(), "Amount first. The amount block and number pad use surface cards, white in light. The pad hands off to the system keyboard when a text field takes focus."),
    ]
    cl = "".join(f'<div><h4>{n}</h4><div class="app specimen">{h}</div><p>{d}</p></div>' for n, h, d in comps)
    return (f'<section class="area" id="appendix"><header><h2>Design tokens</h2><p>The compact reference behind every frame on this page.</p></header>'
            f'<div class="appendix-grid">{colours}{type_}{space}{charts}{icon_sec}</div>'
            f'<div class="group"><h3>Components</h3><div class="complist">{cl}</div></div></section>')


def feedback():
    areas = [a[1] for a in AREAS] + ["Design tokens and components"]
    boxes = "".join(f'<label>{a}<textarea data-area="{a}" placeholder="A correction for {a}"></textarea></label>' for a in areas)
    return (f'<section class="area" id="feedback"><header><h2>Flag a correction</h2><p>One note per area, then an overall note. Prepare feedback collects them into one message to copy.</p></header>'
            f'<div class="feedback"><div class="fbgrid">{boxes}</div><label style="display:block;margin-top:16px;font-size:13px;font-weight:600">Overall<textarea id="fb-overall" placeholder="Overall note"></textarea></label>'
            '<div class="fbactions"><button type="button" id="fb-prepare">Prepare feedback</button><button type="button" id="fb-copy">Copy</button><small id="fb-status">Nothing prepared yet.</small></div>'
            '<textarea id="fb-out" readonly aria-label="Prepared feedback"></textarea></div></section>')


EXTRA_CSS = """
.wcat{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:28px 20px;margin-top:20px}
.wcell{min-width:0}
.wcell>h4{font-size:14px;font-weight:600;margin-bottom:6px}
.wcell .wl{display:block;font-size:11px;color:var(--quiet);margin:8px 0 4px}
.wcell>p{font-size:12px;color:var(--quiet);margin-top:8px}
.wpanel{padding:10px;border-radius:14px;border:1px solid var(--edge)}
.wpanel .tray{margin:0}
.specimen .tray{margin:0}
.specimen .seg:last-child{margin-bottom:0}
.swatch{display:inline-block;width:15px;height:15px;border-radius:4px;border:1px solid var(--quiet);vertical-align:-3px;margin-right:6px}
.pairs{grid-template-columns:repeat(auto-fill,minmax(540px,1fr))}
.pair .two .phone{zoom:.8}
.pair .two>div{display:flex;flex-direction:column;align-items:center}
@media(max-width:1250px){.wcat{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media(max-width:1000px){.wcat{grid-template-columns:repeat(2,minmax(0,1fr))}.pairs{grid-template-columns:1fr}}
@media(max-width:760px){.wcat{grid-template-columns:1fr}.pair .two{grid-template-columns:1fr}}
"""

JS = r"""
(function(){
  var root=document.documentElement;
  function wire(attr){
    document.querySelectorAll('[data-set-'+attr+']').forEach(function(b){
      b.addEventListener('click',function(){
        root.setAttribute('data-'+attr,b.getAttribute('data-set-'+attr));
        document.querySelectorAll('[data-set-'+attr+']').forEach(function(x){x.setAttribute('aria-pressed',String(x===b));});
      });
    });
  }
  wire('app'); wire('page');
  var out=document.getElementById('fb-out'), status=document.getElementById('fb-status');
  document.getElementById('fb-prepare').addEventListener('click',function(){
    var lines=['SpendWise reference feedback',''];
    document.querySelectorAll('textarea[data-area]').forEach(function(t){ if(t.value.trim()) lines.push(t.dataset.area+': '+t.value.trim()); });
    var o=document.getElementById('fb-overall').value.trim(); if(o) lines.push('Overall: '+o);
    lines.push('','App theme viewed: '+(root.getAttribute('data-app')||'light'));
    out.value=lines.join('\n');
    status.textContent=lines.length>4?'Prepared. Copy it into your reply.':'Prepared with no notes yet.';
  });
  document.getElementById('fb-copy').addEventListener('click',function(){
    if(!out.value){status.textContent='Prepare feedback first.';return;}
    out.select();
    try{navigator.clipboard.writeText(out.value).then(function(){status.textContent='Copied.';},function(){status.textContent='Select the text and copy it.';});}
    catch(e){status.textContent='Select the text and copy it.';}
  });
})();
"""


def page():
    phones = sum(1 for f in FR if f["kind"] != "desktop")
    desks = sum(1 for f in FR if f["kind"] == "desktop")
    nd = sum(1 for r in inv if r[0] in NOT_DRAWN and r[0] not in covered)
    earlier_cov = sum(1 for r in inv if r[0] in covered)
    toc = "".join(f'<a href="#area-{k}">{t}</a>' for k, t, _ in AREAS)
    head = f"""<!doctype html><html lang="en" data-page="light" data-app="light"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>SpendWise reference</title><meta name="description" content="Final reference draft of every SpendWise screen in Harbour glass, light and dark, phone and desktop.">
<style>{PAGE_CSS}{APP_CSS}{EXTRA_CSS}</style></head><body>{sprite()}<main>"""
    mast = f"""<header class="masthead"><div><h1>Every SpendWise screen.<span>Harbour glass, light and dark.</span></h1>
<p>The implementation reference for the approved Daylight structure: Overview, History, Trends and Money, with Add in the tab bar and Settings behind the gear. Every frame below is drawn from one token table and follows the app theme switch.</p></div>
<div class="controlbox"><div class="ctl"><b>App theme<small>Switches every drawn app frame. The side-by-side pairs stay fixed.</small></b><span class="toggle-group" role="group" aria-label="App theme"><button type="button" data-set-app="light" aria-pressed="true">Light</button><button type="button" data-set-app="dark" aria-pressed="false">Dark</button></span></div>
<div class="ctl"><b>Page background<small>Changes only this page around the frames.</small></b><span class="toggle-group" role="group" aria-label="Page background"><button type="button" data-set-page="light" aria-pressed="true">Light</button><button type="button" data-set-page="dark" aria-pressed="false">Dark</button></span></div></div></header>
<nav class="toc" aria-label="Sections"><a href="#inventory">Screen inventory</a><a href="#side-by-side">Light and dark side by side</a>{toc}<a href="#appendix">Design tokens</a><a href="#feedback">Flag a correction</a></nav>
<div class="snapshot"><div><b>Seed snapshot</b>Saturday 3 October 2026, SGD, from app/lib/boot/seed_data.dart. October 1-3 spending: Dining 83.90, Groceries 73.50, Transport 10.00, total 167.40. Income +3,200.00, net +3,032.60. Balances run through today; the two November entries are dated ahead.</div>
<div><b>Labelled samples</b>Monthly history January 2024 to July 2026 (August missing, September sparse seed), the 48 / 36 / 16 category split for sample months, round 4 matched-day windows for insights, the S$1,200 cap and the 450 / 350 / 120 budget limits. Captions name every sample.</div>
<div><b>How to read</b>Phone frames show the whole scroll where a caption says so. Desktop windows share one neutral macOS and Windows frame. Captions carry the arithmetic and the code location; nothing inside a drawn screen is an annotation.</div></div>"""
    inv_sec = f"""<section class="area" id="inventory"><header><h2>Screen inventory</h2><p>Every drawn screen, its section, its code location from the earlier atlas inventory and the earlier rows it covers. New Daylight screens have no current code route.</p></header>
<div class="counts"><span><b>{len(FR)}</b>screens drawn ({phones} phone, {desks} desktop)</span><span><b>{len(FR) + nd}</b>listed, including {nd} not drawn</span><span><b>{earlier_cov}</b>of 177 earlier rows covered</span><span><b>12</b>widgets in the catalogue</span></div>
{inventory_table()}</section>"""
    sbs = f"""<section class="area" id="side-by-side"><header><h2>Light and dark side by side</h2><p>The main screens with both appearances fixed, for direct comparison. These frames do not follow the app theme switch.</p></header>{side_by_side()}</section>"""
    areas = "".join(render_area(*a) for a in AREAS)
    foot = '<p class="footer">Static, portable reference. Inline CSS and JavaScript; Instrument Sans from Google Fonts with Arial as fallback. Drawn controls are static; only the two theme switches and the feedback form work.</p>'
    return head + mast + inv_sec + sbs + areas + appendix() + feedback() + foot + f"</main><script>{JS}</script></body></html>"


html = page()
for bad in [chr(0x2014)]:
    assert bad not in html, "em dash found"
OUT.write_text(html, encoding="utf-8")
manifest = [dict(id=f["id"], area=f["area"], inventory_rows=f["inv"] + extra_inv.get(f["id"], []),
                      form_factor="desktop" if f["kind"] == "desktop" else "phone") for f in FR]
for bad in [chr(0x2014)]:
    assert bad not in json.dumps(manifest), "em dash found"
FRAMES_JSON.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print("frames", len(FR), "bytes", len(html))
print("inventory", sum(1 for r in inv if r[0] in covered), "of", len(inv))
