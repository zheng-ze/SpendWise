"""Single source for the Harbour glass light and dark token sets."""

# role: (light, dark, label, contrast note light, contrast note dark)
TOKENS = [
    ("base", "#EDF4F8", "#101112", "Canvas", "primary text 13.48:1", "primary text 17.03:1"),
    ("surface", "#FFFFFF", "#1C1D1F", "Record tray / level 1", "primary text 14.98:1", "primary text 15.19:1"),
    ("raised", "#FFFFFF", "#282A2D", "Sheet and selected control / level 2", "primary text 14.98:1", "primary text 12.96:1"),
    ("tint", "#F0F1F2", "#242629", "Neutral tracks and medallions", "primary text 13.24:1", "primary text 13.66:1"),
    ("text", "#25272A", "#F2F3F5", "Primary text and amounts", "canvas 13.48, tray 14.98, level 2 14.98, Today 14.98", "canvas 17.03, tray 15.19, level 2 12.96, Today 13.66"),
    ("subtext", "#5B5F66", "#B9BCC2", "Secondary text and chart labels", "canvas 5.77, tray 6.42, level 2 6.42, Today 6.42", "canvas 9.93, tray 8.86, level 2 7.56, Today 7.97"),
    ("edge", "#DDDFE2", "#4C4F54", "Decorative divider", "canvas 1.20 (decorative only)", "canvas 2.30 (decorative only)"),
    ("control", "#73777F", "#8B8F96", "Essential control boundary", "canvas 4.04, tray 4.49, level 2 4.49", "canvas 5.82, tray 5.19, level 2 4.43"),
    ("action", "#205F83", "#98C5E8", "Accent, action text and bars", "canvas 6.24, tray 6.94, level 2 6.94", "canvas 10.34, tray 9.23, level 2 7.87"),
    ("selectedmark", "#8B48A0", "#D8A3EB", "Selected chart mark", "canvas 5.35, tray 5.95", "canvas 9.32, tray 8.32"),
    ("pressed", "#174B6A", "#7EB0D7", "Accent pressed", "canvas 8.39, tray 9.33", "canvas 8.17, tray 7.29"),
    ("onaction", "#FFFFFF", "#101112", "Label on accent", "accent 6.94, pressed 9.33", "accent 10.34, pressed 8.17"),
    ("income", "#28684F", "#A4D5B5", "Income amount, plus sign", "canvas 5.94, tray 6.60, level 2 6.60", "canvas 11.49, tray 10.25, level 2 8.75"),
    ("expense", "#964B44", "#EBAEA8", "Expense amount, minus sign", "canvas 5.58, tray 6.20, level 2 6.20", "canvas 10.04, tray 8.96, level 2 7.64"),
    ("dining", "#986421", "#E6B679", "Dining mark", "canvas 4.52, tray 5.02", "canvas 10.20, tray 9.10"),
    ("groceries", "#29755E", "#8FC69B", "Groceries mark", "canvas 4.97, tray 5.53", "canvas 9.65, tray 8.61"),
    ("transport", "#6861A4", "#B5A9E6", "Transport mark", "canvas 4.93, tray 5.48", "canvas 8.81, tray 7.86"),
    ("supermarket", "#237642", "#82C68F", "Supermarket mark", "canvas 5.05, tray 5.61", "canvas 9.38, tray 8.37"),
    ("freshmarket", "#257B66", "#84CDB9", "Fresh Market mark", "canvas 4.60, tray 5.12", "canvas 10.27, tray 9.17"),
    ("salary", "#28684F", "#A4D5B5", "Salary mark (income family)", "canvas 5.94, tray 6.60", "canvas 11.49, tray 10.25"),
    ("gap", "#73777F", "#A1A5AD", "Missing records, dashed stub", "canvas 4.04, tray 4.49", "canvas 7.65, tray 6.83"),
    ("incomplete", "#94ADBC", "#8A8F97", "Incomplete bar fill", "canvas 2.11 plus accent outline 6.24", "canvas 5.81, tray 5.19"),
    ("focus", "#205F83", "#B7D9F4", "Focus underline", "canvas 6.24, tray 6.94", "canvas 12.82, tray 11.44"),
    ("notice", "#7E5B1C", "#E4C48A", "Notice text and boundary", "notice surface 5.25", "notice surface 8.31"),
    ("noticebg", "#F5ECD7", "#302C24", "Notice surface", "notice text 5.25", "notice text 8.31"),
    ("error", "#993F3F", "#F0AAA8", "Error text and boundary", "error surface 5.68", "error surface 7.56"),
    ("errorbg", "#F8E9E8", "#352627", "Error surface", "error text 5.68", "error text 7.56"),
    ("oncategory", "#FFFFFF", "#101112", "Text inside category map blocks", "dining 5.02, groceries 5.53, transport 5.48", "dining 10.20, groceries 9.65, transport 8.81"),
    ("bezel", "#73777F", "#8B8F96", "Device frame (drawing only)", "-", "-"),
]

# Sample categories outside the seed, used only in labelled sample states.
SAMPLE_TOKENS = [
    ("fitness", "#8A4F7D", "#D9A8CC"),
    ("housing", "#5B6B78", "#AEB9C2"),
]


def css_block(index):
    return ";".join(f"--{t[0]}:{t[index]}" for t in TOKENS) + ";" + ";".join(
        f"--{t[0]}:{t[index]}" for t in SAMPLE_TOKENS
    )


LIGHT = css_block(1)
DARK = css_block(2)
