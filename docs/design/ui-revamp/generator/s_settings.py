from data import *

S = "settings"
Y = "sync"
ROOT = "app/lib/ui/settings/settings_root_screen.dart"
ENR = "app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_screens.dart"
PICK = "app/lib/ui/sync/enrollment/backend_picker/backend_picker_screen.dart"
EMAIL = "name@example.com"


def opt3(active):
    return '<div class="opt3">' + "".join(f'<span class="{"on" if o == active else ""}">{o}</span>' for o in ["Light", "Dark", "System"]) + "</div>"


def appearance_tray():
    return tray("Appearance", '<div class="lab">Choose how SpendWise looks.</div>'
                f'<span class="vl">{opt3("Light")}</span><span class="vd">{opt3("Dark")}</span>'
                '<div class="lab" style="margin-top:6px">System follows your device setting.</div>')


def breakdown_tray(chart="Donut", level="Categories"):
    return tray("Trends breakdown", '<div class="lab">How Trends breaks down the selected period.</div>'
                '<div class="setlab">Chart</div>' + seg(["Donut", "Category map"], chart)
                + '<div class="setlab" style="margin-top:2px">Breakdown level</div>' + seg(["Categories", "Subcategories"], level)
                + setrow("Chart colours", "", "My category colours"))


SYNC = {
    "off": setrow("Sync across devices", "Use SpendWise on your phone and computer", "Set up"),
    "pending": setrow("Sync across devices", "Finishing setup on this device", '<span class="tag warn">Pending</span>'),
    "ready": setrow("Sync across devices", EMAIL, '<span class="tag ok">On</span>'),
    "repair": setrow("Sync across devices", "Binding repair needed", '<span class="tag warn">Paused</span>', chevron=False)
    + notice("Device access needs repair", "Device access must be authorized again. Reconciliation will run before sync writes resume.", ["Repair device access"]),
    "expired": setrow("Sync across devices", "Sign-in expired", '<span class="tag warn">Paused</span>', chevron=False)
    + notice("Sign in again", "Your sync sign-in expired. Existing device access will be kept.", ["Repair device access"]),
    "unsupported": setrow("Sync across devices", "Unsupported endpoint", '<span class="tag bad">Off</span>', chevron=False)
    + '<div class="err"><b>Custom server not supported</b><small>Custom endpoints are not supported by sync protocol v2.</small></div>',
    "unavailable": setrow("Sync across devices", "Status unavailable", '<span class="tag bad">Unknown</span>', chevron=False)
    + '<div class="err"><b>Sync status could not be read.</b><small>Your entries are saved on this device.</small></div>',
}


def settings_body(sync="off", chart="Donut", level="Categories"):
    return (header("Settings", back="Overview", gear=False) + appearance_tray()
            + tray("Sync", SYNC[sync]) + breakdown_tray(chart, level)
            + tray("Overview", setrow("Overview insights", "Category changes and usual pace") + setrow("Edit Overview", "Choose and order widgets"))
            + tray("Manage", setrow("Categories", "Income and expense groups") + setrow("Receipt entry", "Show scan and upload when adding", switch=True))
            + tray("", setrow("Currency", "Amounts display in Singapore dollars", "SGD", chevron=False)
                   + setrow("Recycle bin", "Accounts, pockets, categories and entries") + setrow("About SpendWise", "")))


def settings_phone(body, long=True):
    return phone(body, "none", "long" if long else "")


def build_settings():
    reg("st-root", S, "Settings", "Settings",
        settings_phone(settings_body()),
        "Reached from the gear on every tab. Appearance offers Light, Dark and System; the drawn selection follows this page's app theme switch. Trends breakdown holds both choices that left the Trends screen: Chart (Donut or Category map) and Breakdown level (Categories or Subcategories). Full scroll shown.",
        ROOT, ["Settings", "Appearance settings", "Settings, Evergreen dark"])

    def prev(kind, on):
        if kind == "Donut":
            chart = (f'<div class="mini-d">{donut([("Dining", 50.1, "dining"), ("Groceries", 43.9, "groceries"), ("Transport", 6.0, "transport")], "", "", "58")}</div>'
                     + '<div class="adjl"><span><i style="--c:var(--dining)"></i>Dining 50.1%</span><span><i style="--c:var(--groceries)"></i>Groceries 43.9%</span><span><i style="--c:var(--transport)"></i>Transport 6.0%</span></div>')
        else:
            chart = cmap([("Dining", 50.1, "dining"), ("Groceries", 43.9, "groceries"), ("Transport", 6.0, "transport")], 58, min_label=(999, 999))
        mark = '<span style="color:var(--action)">' + ic("check", "s") + "</span>" if on else ""
        return f'<div class="{"on" if on else ""}">{chart}<span style="display:flex;justify-content:center;gap:4px;align-items:center;font-weight:{600 if on else 400}">{mark}{kind}</span></div>'

    def levels(active):
        return "".join(
            f'<div class="pick" style="{"font-weight:600" if n == active else ""}"><span>{n}<small>{d}</small></span>{"<span class=ck>" + ic("check","s") + "</span>" if n == active else ""}</div>'
            for n, d in [("Categories", "Dining, Groceries, Transport"), ("Subcategories", "Supermarket and Fresh Market on their own")])

    def trends_page(chart, level):
        return (header("Trends breakdown", back="Settings", gear=False)
                + '<div class="lab" style="margin:-6px 0 6px">Trends shows the selected month or year this way. Tapping a category still opens its subcategories and entries.</div>'
                + '<div class="setlab">Chart</div><div class="prevs">' + prev("Donut", chart == "Donut") + prev("Category map", chart == "Category map") + "</div>"
                + '<div class="setlab">Breakdown level</div>' + tray("", levels(level))
                + '<div class="setlab">Chart colours</div>' + '<div class="opt3" style="margin-top:0">' + "".join(
                    f'<span class="{"on" if o == "My category colours" else ""}" style="font-size:10px">{o}</span>' for o in ["My category colours", "Theme shades", "Contrasting"]) + "</div>"
                + '<div class="lab" style="margin-top:6px">Names and shares always accompany the colours.</div>')

    reg("st-trends", S, "Settings", "Trends breakdown, donut and categories",
        settings_phone(trends_page("Donut", "Categories")),
        "The dedicated page with previews, carrying the existing chart colour choice. Donut and Categories are the defaults. Preview shares are seed October.",
        ROOT + " + ui-redesign.html Decisions", ["Stats chart settings"])

    reg("st-trends-alt", S, "Settings", "Trends breakdown, category map and subcategories",
        settings_phone(trends_page("Category map", "Subcategories")),
        "The other combination. With these choices Trends draws the subcategory map (see Trends, October, subcategories, category map).",
        ROOT)

    ins = (header("Overview insights", back="Settings", gear=False)
           + tray("", toggle_fld("Category changes", True, "Compare the same days in earlier months") + toggle_fld("Usual pace", True, "Use eligible complete months only"))
           + '<div class="lab">Insights need the three previous months to be complete. They report a difference and never forecast. Dismissing one hides it for that month.</div>')
    reg("st-insights", S, "Settings", "Overview insights",
        settings_phone(ins, False),
        "Proposed preferences from round 4. Switching both off removes insights from the Insights widget.",
        "New screen (round 4)")

    # categories
    def catline(name, cat, sub="", indent=False):
        st = ' style="padding-left:22px"' if indent else ""
        return f'<div class="row"{st}>{med(cat)}<div class="rc"><b>{name}</b><small>{sub}</small></div>{ic("right","s")}</div>'
    cats = (header("Categories", back="Settings", gear=False)
            + tray("Expense", catline("Dining", "Dining") + catline("Groceries", "Groceries", "2 subcategories") + catline("Supermarket", "Supermarket", "", True)
                   + catline("Fresh Market", "Fresh Market", "", True) + catline("Transport", "Transport"))
            + tray("Income", catline("Salary", "Salary")) + '<div class="reserve"></div>' + fab("Add category"))
    reg("st-categories", S, "Categories", "Categories",
        settings_phone(cats),
        "Seed categories with their saved icons and colours, shown in Harbour glass counterparts. Subcategories sit under their parent.",
        "app/lib/ui/settings/category/category_list_screen.dart", ["Categories"])

    edit = (sheet_head("Edit category", "Cancel", "Save") + fld("Name", "Groceries") + fld("Icon and colour", ic("cart", "s") + "Cart", chevron=True)
            + '<div class="setlab">Subcategories</div>' + fld("Supermarket", "", chevron=True) + fld("Fresh Market", "", chevron=True)
            + '<div class="link">' + ic("plus", "s") + "Add subcategory</div>"
            + '<div class="setlab">More options</div>' + toggle_fld("Count in Trends and budgets", True, "Turn off for money you get back, such as work expenses you claim.")
            + fld("Type", ic("lock", "s") + "Expense", "locked") + '<div class="fhint">The type is fixed once entries use this category.</div>'
            + btn("Move to recycle bin", "danger"))
    reg("st-cat-edit", S, "Categories", "Edit category, More options open",
        sheet_phone(cats, edit, under_cls="short"),
        "The analysis switch and the type sit under More options, drawn open; it starts closed. Seed category Groceries.",
        "app/lib/ui/settings/category/category_form.dart", ["Edit category"])

    add = (sheet_head("Add category", "Cancel", "Save") + seg(["Expense", "Income"], "Expense") + fld("Name", 'Household<span class="caret"></span>', "focus")
           + fld("Icon and colour", ic("house", "s") + "House", chevron=True) + fld("Inside", "Top level", chevron=True)
           + setrow("More options", "Count in Trends and budgets") + btn("Save category") + keyboard())
    reg("st-cat-add", S, "Categories", "Add category",
        sheet_phone(cats, add, under_cls="short"),
        "Household is a sample name. Inside chooses a parent to make it a subcategory.",
        "app/lib/ui/settings/category/category_form.dart", ["Add category"])

    addsub = (sheet_head("Add subcategory", "Cancel", "Save") + fld("Name", "Supermarket") + fld("Inside", "Groceries", chevron=True)
              + fld("Icon and colour", ic("bag", "s") + "Shopping bag", chevron=True) + setrow("More options", "Count in Trends and budgets") )
    reg("st-sub-add", S, "Categories", "Add subcategory",
        sheet_phone(cats, addsub, under_cls="short"),
        "From Add subcategory on a category. Seed subcategory Supermarket under Groceries.",
        "app/lib/ui/settings/category/category_form.dart", ["Add subcategory"])

    editsub = (sheet_head("Edit subcategory", "Cancel", "Save") + fld("Name", "Supermarket") + fld("Inside", "Groceries", chevron=True)
               + fld("Icon and colour", ic("bag", "s") + "Shopping bag", chevron=True) + setrow("More options", "Count in Trends and budgets, type")
               + btn("Move to recycle bin", "danger"))
    reg("st-sub-edit", S, "Categories", "Edit subcategory",
        sheet_phone(cats, editsub, under_cls="short"),
        "Same form, with its parent shown.",
        "app/lib/ui/settings/category/category_form.dart", ["Edit subcategory"])

    pp = sheet_head("Inside which category?", "Cancel", "") + "".join(
        f'<div class="pick" style="{"font-weight:600" if n == "Groceries" else ""}">{n}{"<span class=ck>" + ic("check","s") + "</span>" if n == "Groceries" else ""}</div>'
        for n in ["Top level", "Dining", "Groceries", "Transport"])
    reg("st-parent-pick", S, "Categories", "Parent category picker",
        sheet_phone(cats, pp, under_cls="short", sheet_cls="content"),
        "Same-type parents only; Top level clears the parent.",
        "app/lib/ui/settings/category/category_form.dart", ["Category parent picker"])

    icons = ["cart", "bag", "leaf", "dining", "tram", "dollar", "house", "car", "play", "dumbbell", "shield", "tag", "receipt", "card", "jar", "bulb"]
    grid = '<div class="mgrid">' + "".join(f'<span class="{"on" if i == "cart" else ""}" style="display:grid;place-items:center;padding:8px 0">{ic(i)}</span>' for i in icons) + "</div>"
    colours = ["groceries", "supermarket", "freshmarket", "dining", "transport", "salary", "fitness", "housing"]
    sw = '<div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:6px">' + "".join(
        f'<span style="width:26px;height:26px;border-radius:8px;background:var(--{c});{"outline:2px solid var(--text);outline-offset:2px" if c == "groceries" else ""}"></span>' for c in colours) + "</div>"
    sy = sheet_head("Icon and colour", "Cancel", "Done") + '<div class="setlab">Icon</div>' + grid + '<div class="setlab">Colour</div>' + sw
    reg("st-symbol", S, "Categories", "Icon and colour picker",
        sheet_phone(cats, sy, under_cls="short", sheet_cls="content"),
        "A subset of the scrollable icon grid, then the colour swatches. Each saved colour is shown through its light or dark counterpart.",
        "app/lib/ui/common/pickers/symbol_picker.dart", ["Category symbol picker"])

    reg("st-cat-delete", S, "Categories", "Move category to recycle bin",
        settings_phone(cats + dialog("Move Groceries to the recycle bin?", "Entries keep their category. You can restore it from the recycle bin.", [("Cancel", ""), ("Move", "d")]), False),
        "Archives the category into the existing Recycle bin.",
        "app/lib/ui/common/delete_confirmation.dart", ["Delete category confirmation"])

    def binrow(name, sub, cat, value=None):
        right = f'<span class="amt exp">{sm(value)}</span>' if value is not None else ""
        return f'<div class="row">{med(cat)}<div class="rc"><b>{name}</b><small>{sub}</small></div>{right}<span class="link" style="margin:0 0 0 6px">Restore</span></div>'
    binb = (header("Recycle bin", back="Settings", gear=False)
            + tray("Entries", binrow("FairPrice groceries", "3 Oct 2026 / Amex Card", "Supermarket", -42.50))
            + tray("Accounts", binrow("DBS Checking", "Used by 7 entries", "Transfer").replace('--c:var(--subtext)', '--c:var(--action)'))
            + tray("Pockets", binrow("Holiday", "Used by 1 entry", "Transfer").replace('--c:var(--subtext)', '--c:var(--action)'))
            + tray("Categories", binrow("Groceries", "Used by 3 entries", "Groceries"))
            + '<div class="lab">Swipe right to restore or left to delete permanently.</div>')
    reg("st-bin", S, "Recycle bin", "Recycle bin, with entry restoration",
        settings_phone(binb),
        "Illustrative archived items using seed names and their real entry counts. The Entries section is the approved entry-restoration proposal and needs implementation; accounts, pockets and categories restore today.",
        "app/lib/ui/settings/recycle_bin/recycle_bin_screen.dart", ["Recycle bin", "Recycle bin, entry restoration"])

    sw_restore = (header("Recycle bin", back="Settings", gear=False) + '<div class="setlab">Pockets</div>'
                  + f'<div class="swipe"><span class="act r">{ic("restore","s")}Restore</span><div class="row"><div class="rc"><b>Holiday</b><small>Used by 1 entry</small></div></div></div>')
    reg("st-bin-restore", S, "Recycle bin", "Recycle bin, swipe to restore",
        settings_phone(sw_restore, False),
        "A leading swipe restores at once, with no extra confirmation, as today. The Restore text on each row does the same without a gesture.",
        "app/lib/ui/settings/recycle_bin/recycle_bin_screen.dart", ["Recycle bin, restore gesture"])

    sw_purge = (header("Recycle bin", back="Settings", gear=False) + '<div class="setlab">Categories</div>'
                + f'<div class="swipe"><div class="row"><div class="rc"><b>Groceries</b><small>Used by 3 entries</small></div></div><span class="act d">{ic("trash","s")}Delete</span></div>')
    reg("st-bin-purge", S, "Recycle bin", "Recycle bin, swipe to delete",
        settings_phone(sw_purge, False),
        "A trailing swipe opens the permanent deletion confirmation.",
        "app/lib/ui/settings/recycle_bin/recycle_bin_screen.dart", ["Recycle bin, purge gesture"])

    reg("st-bin-confirm", S, "Recycle bin", "Delete permanently",
        settings_phone(binb + dialog("Delete permanently?", "Groceries leaves the bin for good. Existing transactions keep the name but it can no longer be restored.", [("Cancel", ""), ("Delete", "d")]), False),
        "The existing warning, word for word.",
        "app/lib/ui/settings/recycle_bin/recycle_bin_screen.dart", ["Permanent deletion confirmation"])

    # sync states inline in Settings
    for key, title, inv, cap in [
        ("pending", "Settings, sync setup pending", "Settings, hosted sync setup pending", "Setup started on this device and is finishing."),
        ("ready", "Settings, sync on", "Settings, hosted sync ready", "Sync is on; the row names the email in use. Sample address."),
        ("repair", "Settings, device access needs repair", "Settings, hosted sync binding repair needed", "The fixed source message and its one action. The Overview notice appears on every tab at the same time."),
        ("expired", "Settings, sign-in expired", "Settings, hosted sync sign-in expired", "Existing device access is kept; signing in again resumes sync."),
        ("unsupported", "Settings, unsupported server", "Settings, hosted sync unsupported endpoint", "A saved custom endpoint that the sync protocol does not support."),
        ("unavailable", "Settings, sync status unavailable", "Settings, hosted sync status unavailable", "The status could not be read; entries stay on the device."),
    ]:
        reg(f"st-sync-{key}", Y, "Status in Settings", title, settings_phone(settings_body(key)),
            cap + " Status lives inline in Settings; there is no separate status page. Full scroll shown.", ROOT, [inv])

    # Desktop settings
    left = settings_body().replace(header("Settings", back="Overview", gear=False), "")
    right = trends_page("Donut", "Categories").replace(header("Trends breakdown", back="Settings", gear=False), '<div class="th" style="font-size:18px;font-weight:600;margin-bottom:8px">Trends breakdown</div>')
    reg("st-desk", S, "Desktop", "Settings, desktop",
        desktop("Settings", f'<div class="dg2e"><div>{left}</div><div class="pane raised">{right}</div></div>', "Settings", "", acts=""),
        "Settings opens from the sidebar. The list stays on the left and the chosen page opens beside it, here Trends breakdown.",
        ROOT + "; app/lib/ui/shell/app_shell.dart", ["Settings, macOS"], kind="desktop")


def sync_page(title, body, back="Settings", alert=""):
    return sheet_phone(settings_body(), sheet_head(title, "Cancel", "") + body, alert=alert)


def build_sync():
    setup_body = ('<div class="lab" style="margin:-6px 0 10px">Your iPhone and Mac keep the same accounts and entries.</div>'
                  + tray("", fld("Email", EMAIL) + '<div class="fhint">We send a six-digit code to this address.</div>')
                  + btn("Send code")
                  + tray("", '<b style="font-size:12px">Already set up on another device?</b><div class="lab" style="margin-top:3px">Use the same email. Your entries join once the code is confirmed.</div>').replace('class="tray"', 'class="tray" style="margin-top:14px"')
                  + '<div class="link" style="justify-content:center">Use my own server</div>')
    reg("sy-setup", Y, "Set up", "Sync setup, email",
        sync_page("Sync across devices", setup_body),
        "Hosted sync is the default, so email and a code are the only steps. The custom server waits behind Use my own server. Placeholder address.",
        ENR, ["Hosted sync sign-in", "Choose sync backend"])

    focus_setup = setup_body.replace(fld("Email", EMAIL), fld("Email", EMAIL + '<span class="caret"></span>', "focus"))
    reg("sy-cancelled", Y, "Set up", "Sync setup, back from the code",
        sync_page("Sync across devices", focus_setup),
        "Leaving the code step returns here with the email kept. Cancelling is not an error, so no message appears.",
        ENR, ["Sign-in after code cancellation"])

    cool = setup_body.replace(btn("Send code"), btn("Send code", "dis") + '<div class="fhint" style="text-align:center">You can request a new code in 60s.</div>')
    reg("sy-cooldown", Y, "Set up", "Sync setup, code cooldown",
        sync_page("Sync across devices", cool),
        "Right after a code is requested, Send code waits out the cooldown.",
        ENR, ["Sign-in request cooldown"])

    def code_body(state="", extra=""):
        cls = {"": "focus", "bad": "bad"}.get(state, "")
        digits = "".join(f"<span>{d}</span>" for d in "482916")
        resend = '<div class="link" style="justify-content:center">Send a new code</div>' if state == "bad" else '<div class="lab" style="text-align:center;margin-top:8px">Send a new code in 60s</div>'
        return (f'<div class="lab" style="margin:-6px 0 4px">We sent a six-digit code to {EMAIL}.</div>{extra}<div class="code6 {cls}">{digits}</div>'
                + btn("Confirm code") + resend)
    reg("sy-code", Y, "Set up", "Enter the code",
        sync_page("Enter the code", code_body(), back="Sync"),
        "Six digits, as the source requires. Sample code.",
        ENR, ["Enter verification code"])
    reg("sy-code-failure", Y, "Set up", "Code failure",
        sync_page("Enter the code", code_body("bad"), back="Sync", alert=sheet_alert("The code is incorrect or expired. Request a new code and try again.")),
        "The fixed failure message. Send a new code is available at once.",
        ENR, ["Verification code failure"])

    def centre(msg, spinner=True, title="", action="", tone="", icon=None):
        s = '<span class="sync-progress"><span class="spin l"></span></span>' if spinner else ""
        if icon:
            s = f'<span class="med sync-symbol" style="--c:var(--income);width:44px;height:44px;border-radius:13px">{ic(icon)}</span>'
        t = f'<b style="font-size:18px">{title}</b>' if title else ""
        a = btn(action, tone) if action else ""
        return f'<div class="center" style="padding:24px 0">{s}{t}<div class="lab" style="font-size:12px;max-width:240px">{msg}</div></div>' + a

    reg("sy-finishing", Y, "Set up", "Finishing setup",
        sync_page("Sync across devices", centre("Finishing hosted sync enrollment. Keep the app open.")),
        "In-flight resume state, with no invented progress steps.",
        ENR, ["Finishing sync enrollment"])
    reg("sy-failure", Y, "Set up", "Setup failure",
        sync_page("Sync across devices", btn("Try again"), alert=sheet_alert("Sync is not on yet", "Hosted sync could not finish. Try again.")),
        "Phase-aware failure copy from the app; entries stay on this device.",
        ENR, ["Sync enrollment failure"])
    reg("sy-enrolled", Y, "Set up", "Sync on",
        sync_page("Sync across devices", centre(f"This device now syncs with {EMAIL}.", False, "Sync is on", "Done", icon="check")),
        "Completion. Done returns to Settings, where the row now says On.",
        ENR, ["Sync enrolled"])
    reg("sy-prev-finishing", Y, "Set up", "Finishing the previous attempt",
        sync_page("Sync across devices", centre("Finishing the previous attempt. This usually takes a few seconds.")),
        "A bounded wait before a fresh setup starts.",
        "app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart", ["Finishing previous enrollment attempt"])
    reg("sy-prev-timeout", Y, "Set up", "Previous attempt still finishing",
        sync_page("Sync across devices", btn("Try again"), alert=sheet_alert("The previous attempt is still finishing. Try again in a moment.", tone="warning")),
        "When the bounded wait runs out. Back stays available.",
        "app/lib/ui/sync/enrollment/sync_enrollment/sync_enrollment_flow.dart", ["Previous attempt wait timed out"])

    def custom(url, extra="", focus=False, cont=None, err=False):
        cls = "invalid" if err else ("focus" if focus else "")
        return ('<div class="lab" style="margin:-6px 0 10px">Sync through your own server over HTTPS.</div>'
                + tray("", fld("Server URL", url + ('<span class="caret"></span>' if focus else ""), cls) + extra)
                + (cont if cont is not None else btn("Continue")) + '<div class="link" style="justify-content:center">Use hosted sync instead</div>')
    reg("sy-custom", Y, "Own server", "Use my own server",
        sync_page("Use my own server", custom("https://sync.example.com", focus=True), back="Sync"),
        "The former backend picker's custom choice, reached from Use my own server. Placeholder URL.",
        PICK, ["Custom sync backend"])
    reg("sy-custom-invalid", Y, "Own server", "Own server, address check",
        sync_page("Use my own server", custom("http://sync.example.com", err=True), back="Sync", alert=sheet_alert("Use an HTTPS server URL.")),
        "Validation copy from the app.",
        PICK, ["Custom endpoint validation"])
    inline = sheet_alert("Custom servers are not yet available.", tone="neutral")
    reg("sy-custom-unavailable", Y, "Own server", "Own server, not available yet",
        sync_page("Use my own server", custom("https://sync.example.com"), back="Sync", alert=inline),
        "The valid choice is saved, then the app explains that custom servers are not yet available.",
        "app/lib/ui/sync/enrollment/backend_picker/backend_picker_flow.dart", ["Custom server unavailable"])
    saving = '<div class="btn dis" style="display:flex;gap:8px;justify-content:center;align-items:center"><span class="spin" style="width:13px;height:13px;border-top-color:var(--onaction)"></span>Saving</div>'
    reg("sy-saving", Y, "Own server", "Saving the sync choice",
        sync_page("Use my own server", custom("https://sync.example.com", cont=saving), back="Sync"),
        "Back and the field are off while the choice saves.",
        PICK, ["Backend selection saving"])
    reg("sy-save-failure", Y, "Own server", "Sync choice save failure",
        sync_page("Use my own server", custom("https://sync.example.com"), back="Sync", alert=sheet_alert("Could not save your sync choice. Please try again.")),
        "Fixed source copy; Continue retries.",
        PICK, ["Backend selection save failure"])

    def repair_body():
        return (tray("", fld("Email", EMAIL) + '<div class="fhint">A one-time code will be sent to this address.</div>')
                + '<div class="lab">Requesting a new code replaces the previous one. Only the newest code will work.</div>' + btn("Send code"))
    reg("sy-repair", Y, "Repair", "Repair device access",
        sync_page("Repair device access", repair_body(), alert=sheet_alert("Device access", "Device access must be authorized again. Reconciliation will run before sync writes resume.", "warning")),
        "Opened from the notice or the Settings row. Repair skips the server choice.",
        ENR, ["Repair device access"])
    reg("sy-renew", Y, "Repair", "Renew sign-in",
        sync_page("Repair device access", repair_body(), alert=sheet_alert("Device access", "Your sync sign-in expired. Existing device access will be kept.", "warning")),
        "The same flow for an expired sign-in.",
        ENR, ["Renew expired sign-in"])
    reg("sy-repair-code", Y, "Repair", "Repair, enter the code",
        sync_page("Enter the code", code_body(extra='<div class="lab" style="margin-bottom:4px">Requesting a new code replaces the previous one.</div>'), back="Repair"),
        "Code replacement and resend cooldown, as today.",
        ENR, ["Repair device access, verification code"])
    reg("sy-repair-progress", Y, "Repair", "Repair in progress",
        sync_page("Repair device access", centre("Restoring device access. Reconciling and publishing this device. Keep the app open.")),
        "Reconciliation runs before sync writes resume.",
        ENR, ["Repair device access, progress"])
    reg("sy-restored", Y, "Repair", "Device access restored",
        sync_page("Repair device access", centre("Sync writes have resumed.", False, "Device access restored", "Done")),
        "Repair completion; the notice leaves every tab.",
        ENR, ["Device access restored"])
