from data import *
import tiles
from s_history_trends import history_oct, band
from s_overview import default_body

A = "add"
NEWF = "app/lib/ui/transactions/entry/new_entry_form.dart"
FIELDS = "app/lib/ui/transactions/entry/entry_fields.dart"


def under_overview():
    return overview_head()


def amount_field(value, focus=True, label="Amount / SGD"):
    caret = '<span class="caret"></span>' if focus else ""
    return f'<div class="amtf {"" if focus else "idle"}"><small>{label}</small><strong>{value}{caret}</strong></div>'


def receipt_row(text="Add receipt", icon="camera", extra=""):
    return f'<div class="fld" style="color:var(--action);font-weight:600"><span style="color:var(--action);display:flex;gap:6px;align-items:center">{ic(icon,"s")}{text}</span><b>{extra}</b></div>'


def expense_fields(name="FairPrice groceries", cat="Groceries / Supermarket", acct="Amex Card", date="3 October 2026", repeat="Does not repeat", name_focus=False, note_focus=False):
    nm = f'{name}<span class="caret"></span>' if name_focus else name
    return (fld("Name", nm, "focus" if name_focus else "") + fld("Category", cat, chevron=True) + fld("Account", acct, chevron=True)
            + fld("Date", date, chevron=True) + fld("Repeat", repeat, chevron=True)
            + fld("Note", '<span class="caret"></span>' if note_focus else "", "focus" if note_focus else "")
            + '<div class="fld"><span>Include in analysis</span><span class="sw on"></span></div>')


def add_sheet(kind="Expense", amount="-42.50", fields=None, pad=True, action="Save entry", title="Add entry", extra="", focus=True, receipt=True):
    f = fields if fields is not None else expense_fields()
    r = receipt_row() if receipt else ""
    p = numpad() if pad else ""
    return (sheet_head(title, "Cancel", "") + seg(["Expense", "Income", "Transfer"], kind) + amount_field(amount, focus)
            + light_card(f + r + extra, "form-card") + p + btn(action))


def build():
    reg("add-expense", A, "Add entry", "Add entry, expense",
        sheet_phone(under_overview(), add_sheet(), under_cls="short"),
        "Add in the tab bar opens this sheet from any tab. Amount comes first with the decimal number pad; the focused field shows a thicker accent underline and a thin caret, nothing else. The draft mirrors the seeded FairPrice entry (-42.50, Groceries / Supermarket, Amex Card, 3 October).",
        NEWF, ["Add entry, expense"])

    sh = (sheet_head("Add entry", "Cancel", "") + seg(["Expense", "Income", "Transfer"], "Expense") + amount_field("-42.50", False)
          + light_card(expense_fields(note_focus=True) + receipt_row(), "form-card")
          + btn("Save entry") + keyboard())
    reg("add-note", A, "Add entry", "Add entry, note with keyboard",
        sheet_phone(under_overview(), sh, under_cls="short"),
        "Tapping Note hands off from the number pad to the system keyboard. The complete form remains available: Name, Category, Account, Date, Repeat, Note, Include in analysis and Add receipt. Note has the focused underline and caret. The form scrolls above the pinned Save entry and keyboard.",
        FIELDS, ["Add entry, note focus"])

    f = (fld("Name", "Monthly salary") + fld("Category", "Salary", chevron=True) + fld("Account", "DBS Checking", chevron=True)
         + fld("Date", "3 October 2026", chevron=True) + fld("Repeat", "Does not repeat", chevron=True) + fld("Note", "")
         + '<div class="fld"><span>Include in analysis</span><span class="sw on"></span></div>')
    reg("add-income", A, "Add entry", "Add entry, income",
        sheet_phone(under_overview(), add_sheet("Income", "+3,200.00", f), under_cls="short"),
        "Income keeps its plus sign and income colour. Seeded salary: +3,200.00 into DBS Checking on 3 October.",
        NEWF, ["Add entry, income"])

    f = (fld("Name", "To savings") + fld("From", "DBS Checking", chevron=True) + fld("To", "OCBC Savings", chevron=True)
         + fld("Date", "3 October 2026", chevron=True) + fld("Repeat", "Does not repeat", chevron=True) + fld("Note", ""))
    reg("add-transfer", A, "Add entry", "Add entry, transfer",
        sheet_phone(under_overview(), add_sheet("Transfer", "500.00", f, receipt=False), under_cls="short"),
        "A transfer has From and To instead of a category, carries no sign and never counts as income or spending. Seeded 500.00 from DBS Checking to OCBC Savings.",
        FIELDS, ["Add entry, transfer"])

    f = (fld("Name", "Netflix") + fld("Category", "Dining", chevron=True) + fld("Account", "Amex Card", chevron=True)
         + fld("Date", "20 October 2026", chevron=True) + fld("Repeat", "Every month", chevron=True)
         + '<div class="fld"><span>Ends</span><b>Never' + ic("right") + "</b></div>"
         + fld("Note", "") + '<div class="fhint">Saving creates a plan. Review it in Money, Plans.</div>')
    reg("add-repeat", A, "Add entry", "Add entry, repeating",
        sheet_phone(under_overview(), add_sheet("Expense", "-19.98", f, receipt=False), under_cls="tiny"),
        "Plans start where entries start: choosing Repeat creates a plan. This is how the seeded Netflix plan was made: -19.98, Dining, Amex Card, monthly from 20 October 2026. Ends opens an end date.",
        NEWF, ["Add entry, recurring"])

    # pickers
    cp = (sheet_head("Choose category", "Cancel", "")
          + '<div class="twocol"><div>'
          + '<div class="pick">Dining' + ic("right", "s") + '</div><div class="pick" style="font-weight:600">Groceries' + ic("right", "s") + '</div><div class="pick">Transport</div>'
          + '</div><div>'
          + '<div class="pick">All Groceries</div><div class="pick" style="font-weight:600">Supermarket<span class="ck">' + ic("check", "s") + '</span></div><div class="pick">Fresh Market</div>'
          + "</div></div>" + '<div class="pick">No category</div>' + '<div class="link">Manage categories</div>')
    reg("pick-category", A, "Pickers", "Category picker",
        sheet_phone(under_overview(), cp, under_cls="short", sheet_cls="content"),
        "Expense categories only for this expense draft: parents on the left, the chosen parent's subcategories on the right. Income drafts show income categories only; transfers have no category picker. All Groceries assigns the parent directly (shown later as Direct to Groceries).",
        "app/lib/ui/common/pickers/category_picker.dart", ["Entry category picker"])

    ap = (sheet_head("Choose account", "Cancel", "") + '<div class="grouph">Everyday money</div>'
          + '<div class="pick"><span>DBS Checking</span><span class="sub">10,869.00</span></div>'
          + '<div class="pick"><span>OCBC Savings<small>Own balance</small></span><span class="sub">1,700.00</span></div>'
          + '<div class="pick ind"><span>Emergency Fund</span><span class="sub">8,000.00</span></div>'
          + '<div class="pick ind"><span>Holiday</span><span class="sub">650.00</span></div>'
          + '<div class="grouph">Credit cards</div><div class="pick" style="font-weight:600"><span>Amex Card<small>Owed ' + f2(AMEX_OWED) + '</small></span><span class="ck">' + ic("check", "s") + "</span></div>")
    reg("pick-account", A, "Pickers", "Account and pocket picker",
        sheet_phone(under_overview(), ap, under_cls="short", sheet_cls="content"),
        "Pockets are selectable under their account. Balances through 3 October: 10,869.00 + 1,700.00 + 8,000.00 + 650.00 in assets, 399.60 owed on the card.",
        "app/lib/ui/common/pickers/source_picker.dart", ["Account and pocket picker"])

    rp = sheet_head("Repeat", "Cancel", "") + "".join(
        f'<div class="pick" style="{"font-weight:600" if o == "Does not repeat" else ""}">{o}{"<span class=ck>" + ic("check","s") + "</span>" if o == "Does not repeat" else ""}</div>'
        for o in ["Does not repeat", "Every week", "Every two weeks", "Every month", "Every three months", "Every year"])
    reg("pick-repeat", A, "Pickers", "Repeat picker",
        sheet_phone(under_overview(), rp, under_cls="short", sheet_cls="content"),
        "Shared by Add entry and Edit plan. The six options map to the existing one time, weekly, biweekly, monthly, quarterly and yearly recurrences.",
        "app/lib/ui/common/pickers/recurrence_picker.dart", ["Recurrence picker"])

    cal = ['<div class="cal">'] + [f'<span class="h">{d}</span>' for d in "MTWTFSS"] + ["<span></span>"] * 3
    for d in range(1, 32):
        cal.append(f'<span class="{"sel" if d == 3 else ""}">{d}</span>')
    cal.append("</div>")
    dp = sheet_head("Date", "Cancel", "Done") + period("October 2026") + "".join(cal) + btn("Today, 3 October", "sec")
    reg("pick-date", A, "Pickers", "Date picker",
        sheet_phone(under_overview(), dp, under_cls="", sheet_cls="content"),
        "Used for an entry date, a plan's first date and its end date. Today is selected.",
        "app/lib/ui/transactions/transactions_flow.dart; app/lib/ui/settings/plan/plan_form.dart", ["Entry and plan date picker"])

    # receipt
    rc = (sheet_head("Add receipt", "Cancel", "") + '<div class="lab" style="margin:2px 0 8px">Scanning fills in a draft. You check it before saving.</div>'
          + '<div class="pick"><span style="display:flex;gap:9px;align-items:center">' + ic("camera") + 'Scan receipt</span></div>'
          + '<div class="pick"><span style="display:flex;gap:9px;align-items:center">' + ic("image") + "Choose photo</span></div>")
    reg("rc-choose", A, "Receipt", "Add receipt",
        sheet_phone(under_overview(), rc, sheet_cls="content", under_sheet=add_sheet()),
        "From Add receipt in the entry sheet. The platform camera and photo picker take over from here; they are not drawn.",
        "app/lib/ui/transactions/receipt_scan/receipt_scan_strip.dart")

    blank = expense_fields("", "Choose", "Amex Card", "3 October 2026")
    busy = '<div class="fld"><span style="display:flex;gap:8px;align-items:center;color:var(--text)"><span class="spin"></span>Reading receipt...</span><b style="color:var(--subtext)">Scan off</b></div>'
    reg("rc-reading", A, "Receipt", "Receipt, reading",
        sheet_phone(under_overview(), add_sheet(amount="0.00", fields=blank, receipt=False, extra=busy, focus=False), under_cls="short"),
        "While recognition runs, scanning and choosing a photo are off and the fields wait for the draft.",
        "app/lib/ui/transactions/receipt_scan/receipt_scan_strip.dart", ["Receipt recognition in progress"])

    inline = sheet_alert("Camera or photo library access was denied.", tone="neutral")
    reg("rc-denied", A, "Receipt", "Receipt, access denied",
        sheet_phone(under_overview(), add_sheet(amount="0.00", fields=blank, focus=False), under_cls="none", alert=inline),
        "The existing message when camera or photo access is denied. The draft stays open for manual entry.",
        "app/lib/ui/transactions/receipt_scan/receipt_scan_strip.dart", ["Receipt access denied"])

    reg("rc-notext", A, "Receipt", "Receipt, no text found",
        sheet_phone(under_overview(), add_sheet(amount="0.00", fields=blank, focus=True), under_cls="short"),
        "No text, or a recognition failure, returns a blank draft with the amount focused, as the app does today. No separate error screen.",
        "app/lib/ui/transactions/receipt_scan/receipt_scan_flow.dart", ["Receipt returns no text"])

    hint = sheet_alert("Check before saving", "Check scanned amounts, dates and categories before saving.", "warning")
    att = receipt_row("Receipt attached", "receipt", '<span style="color:var(--action)">Adjust corners</span>')
    reg("rc-draft", A, "Receipt", "Receipt, scanned draft",
        sheet_phone(under_overview(), add_sheet(fields=expense_fields(), receipt=False, extra=att, focus=False), under_cls="none", alert=hint),
        "Recognition prefills an editable draft and never saves on its own. Illustrative scan of the seeded FairPrice receipt: -42.50 on 3 October.",
        "app/lib/ui/transactions/receipt_scan/receipt_scan_flow.dart")

    receipt = ('<div class="croparea"><div class="receipt-img"><b>FairPrice</b>3 Oct 2026<br><br>Groceries<span style="float:right">42.50</span><br>'
               '<br><b>Total<span style="float:right">S$42.50</span></b><br>Thank you</div>'
               '<span class="hdl" style="left:-4px;top:-4px"></span><span class="hdl" style="right:-4px;top:-4px"></span>'
               '<span class="hdl" style="left:-4px;bottom:-4px"></span><span class="hdl" style="right:-4px;bottom:-4px"></span></div>')
    body = sheet_head("Adjust corners", "Cancel", "Use photo") + '<div class="lab" style="text-align:center">Drag the corners to the edges of the receipt.</div>' + receipt
    reg("rc-crop", A, "Receipt", "Receipt, adjust corners",
        sheet_phone(under_overview(), body),
        "Offered from Adjust corners on the attached photo; most scans never need it. Illustrative receipt image.",
        "app/lib/ui/transactions/document_crop/document_crop_screen.dart", ["Crop receipt"])

    body = sheet_head("Adjust corners", "Cancel", '<span style="opacity:.45">Use photo</span>') + '<div class="center" style="padding:30px 0"><span class="spin l"></span><span class="lab">Preparing photo</span></div>'
    reg("rc-crop-loading", A, "Receipt", "Receipt, preparing photo",
        sheet_phone(under_overview(), body),
        "While the image decodes, Use photo stays off.",
        "app/lib/ui/transactions/document_crop/document_crop_screen.dart", ["Crop receipt, loading"])

    # edit
    ed = (sheet_head("Edit entry", "Cancel", "") + seg(["Expense", "Income", "Transfer"], "Expense") + amount_field("-42.50", True)
          + light_card(expense_fields(), "form-card") + numpad() + btn("Update entry") + btn("Delete entry", "danger"))
    reg("edit-entry", A, "Edit entry", "Edit entry",
        sheet_phone(history_oct(), ed, under_cls="tiny"),
        "Tap any entry to edit it. The same fields and pad as Add entry; Update entry leads and Delete entry is the quiet last action.",
        "app/lib/ui/transactions/entry/edit_entry_form.dart", ["Edit entry"])

    sys = (sheet_head("Edit entry", "Cancel", "") + '<div class="tag" style="display:inline-block;margin:2px 0 6px">Opening balance</div>'
           + amount_field("5,000.00", True) + light_card(fld("Name", ic("lock", "s") + "Opening balance", "locked") + fld("Account", "DBS Checking")
           + fld("Date", "1 August 2026", chevron=True) + fld("Category", ic("lock", "s") + "None", "locked"), "form-card")
           + f'<div class="lockmsg">{ic("info","s")}Name, category and Include in analysis stay fixed for opening balances. They stay out of Trends and budgets.</div>'
           + numpad() + btn("Update entry"))
    reg("edit-system", A, "Edit entry", "Edit opening balance",
        sheet_phone(history_oct(), sys, under_cls="short"),
        "System entries keep their locks. Seed: DBS Checking opened with 5,000.00 on 1 August 2026.",
        FIELDS, ["Edit system entry"])

    nb = band(3075.10, 124.90, 3200.00, 500.00)
    body = history_oct(skip=("FairPrice groceries",), band_override=nb).replace("+3,154.30", "+3,196.80")
    reg("edit-deleted", A, "Edit entry", "After deleting an entry",
        phone(body + '<div class="reserve"></div>' + snack("Entry deleted", "Undo"), "History", "long"),
        "After Delete entry, the list updates at once and Undo is offered. Without FairPrice: spent 124.90, net +3,075.10, 3 October +3,196.80. Undo and later restoration from the Recycle bin are approved proposals that need implementation.",
        "app/lib/ui/transactions/entry/edit_entry_form.dart", ["After deleting an entry"])

    err = sheet_alert("Could not save entry", "Invalid amount")
    reg("add-save-failure", A, "Edit entry", "Entry save failure",
        sheet_phone(under_overview(), add_sheet(), under_cls="none", alert=err),
        "The form stays open with the error in a transient banner above the sheet. Error detail is illustrative; the app shows the thrown reason.",
        "app/lib/ui/common/error_section.dart", ["Entry save failure"])

    # Desktop Add panel and History
    panel = ('<div class="wscrim"></div><div class="dpanel app-panel">' + sheet_contents(sheet_head("Add entry", "Cancel", "")
             + seg(["Expense", "Income", "Transfer"], "Expense") + amount_field("-42.50", True) + light_card(expense_fields() + receipt_row("Attach receipt photo", "image"), "form-card")
             + btn("Save entry")) + "</div>")
    cols = '<div class="dg3">' + f'<div class="dcol">{w_today()}</div><div class="dcol">{w_recent()}</div><div class="dcol">{w_coming()}</div>' + "</div>"
    reg("add-desk", A, "Desktop", "Add entry panel, desktop",
        desktop("Overview", cols, "Overview", "Saturday, 3 October 2026", overlay=panel,
                acts=f'<span>Edit Overview</span><span class="pbtn">{ic("plus","s")}Add entry</span>'),
        "On desktop, Add entry (or Cmd+N / Ctrl+N) opens a small content-sized dialog over the current page. The amount is typed; Tab moves through the fields; Escape closes with a discard choice when there are changes. Desktop offers a photo, not a camera scan.",
        NEWF, kind="desktop")

    rows = []
    for d, n, c, a, v, mv in OCT:
        cls = "sel" if n == "FairPrice groceries" else ""
        cat = "Transfer" if mv else c
        acct = "DBS to OCBC" if mv else a
        rows.append(f'<tr class="{cls}"><td>{d} Oct</td><td><b>{n}</b></td><td>{cat}</td><td>{acct}</td><td class="r">{amt(v, mv)}</td></tr>')
    reg_table = ('<table class="reg"><thead><tr><th>Date</th><th>Entry</th><th>Category</th><th>Account</th><th class="r">Amount</th></tr></thead><tbody>'
                 + "".join(rows) + "</tbody></table>")
    left = (f'<div class="pane">{period("October 2026")}{seg(["List", "Calendar"], "List")}{band(3032.60, 167.40, 3200.00, 500.00)}{reg_table}</div>')
    right = ('<div class="pane raised">' + '<div class="th" style="font-size:14px;font-weight:600;display:flex;justify-content:space-between"><span>Edit entry</span><span class="sub">3 October</span></div>'
             + seg(["Expense", "Income", "Transfer"], "Expense") + amount_field("-42.50", False) + light_card(expense_fields(), "form-card") + btn("Update entry") + btn("Delete entry", "danger") + "</div>")
    reg("hi-desk", "history", "Desktop", "History with selected entry, desktop",
        desktop("History", f'<div class="dg2">{left}{right}</div><div class="dg2e" style="margin-top:18px">{tiles.biggest_entries()}{tiles.by_account()}</div>', "History", "All accounts"),
        "A dense register with the selected entry open for editing beside it; the register and filters stay in place. Arrow keys move the selection. All nine seeded October entries; net +3,032.60. Biggest entries and By account sit below, side by side.",
        "app/lib/ui/shell/app_shell.dart; app/lib/ui/transactions/daily_list/daily_transactions_screen.dart", ["Transactions, daily, macOS"], kind="desktop")
