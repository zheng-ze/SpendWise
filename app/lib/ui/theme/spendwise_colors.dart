import 'package:flutter/material.dart';

class SpendWiseColors extends ThemeExtension<SpendWiseColors> {
  const SpendWiseColors({
    required this.base,
    required this.surface,
    required this.raised,
    required this.tint,
    required this.text,
    required this.subtext,
    required this.edge,
    required this.control,
    required this.action,
    required this.selectedMark,
    required this.pressed,
    required this.onAction,
    required this.income,
    required this.expense,
    required this.dining,
    required this.groceries,
    required this.transport,
    required this.supermarket,
    required this.freshMarket,
    required this.salary,
    required this.gap,
    required this.incomplete,
    required this.focus,
    required this.notice,
    required this.noticeBg,
    required this.error,
    required this.errorBg,
    required this.onCategory,
    required this.bezel,
    required this.fitness,
    required this.housing,
  });

  static const light = SpendWiseColors(
    base: Color(0xFFEDF4F8),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    tint: Color(0xFFF0F1F2),
    text: Color(0xFF25272A),
    subtext: Color(0xFF5B5F66),
    edge: Color(0xFFDDDFE2),
    control: Color(0xFF73777F),
    action: Color(0xFF205F83),
    selectedMark: Color(0xFF8B48A0),
    pressed: Color(0xFF174B6A),
    onAction: Color(0xFFFFFFFF),
    income: Color(0xFF28684F),
    expense: Color(0xFF964B44),
    dining: Color(0xFF986421),
    groceries: Color(0xFF29755E),
    transport: Color(0xFF6861A4),
    supermarket: Color(0xFF237642),
    freshMarket: Color(0xFF257B66),
    salary: Color(0xFF28684F),
    gap: Color(0xFF73777F),
    incomplete: Color(0xFF94ADBC),
    focus: Color(0xFF205F83),
    notice: Color(0xFF7E5B1C),
    noticeBg: Color(0xFFF5ECD7),
    error: Color(0xFF993F3F),
    errorBg: Color(0xFFF8E9E8),
    onCategory: Color(0xFFFFFFFF),
    bezel: Color(0xFF73777F),
    fitness: Color(0xFF8A4F7D),
    housing: Color(0xFF5B6B78),
  );

  static const dark = SpendWiseColors(
    base: Color(0xFF101112),
    surface: Color(0xFF1C1D1F),
    raised: Color(0xFF282A2D),
    tint: Color(0xFF242629),
    text: Color(0xFFF2F3F5),
    subtext: Color(0xFFB9BCC2),
    edge: Color(0xFF4C4F54),
    control: Color(0xFF8B8F96),
    action: Color(0xFF98C5E8),
    selectedMark: Color(0xFFD8A3EB),
    pressed: Color(0xFF7EB0D7),
    onAction: Color(0xFF101112),
    income: Color(0xFFA4D5B5),
    expense: Color(0xFFEBAEA8),
    dining: Color(0xFFE6B679),
    groceries: Color(0xFF8FC69B),
    transport: Color(0xFFB5A9E6),
    supermarket: Color(0xFF82C68F),
    freshMarket: Color(0xFF84CDB9),
    salary: Color(0xFFA4D5B5),
    gap: Color(0xFFA1A5AD),
    incomplete: Color(0xFF8A8F97),
    focus: Color(0xFFB7D9F4),
    notice: Color(0xFFE4C48A),
    noticeBg: Color(0xFF302C24),
    error: Color(0xFFF0AAA8),
    errorBg: Color(0xFF352627),
    onCategory: Color(0xFF101112),
    bezel: Color(0xFF8B8F96),
    fitness: Color(0xFFD9A8CC),
    housing: Color(0xFFAEB9C2),
  );

  final Color base;
  final Color surface;
  final Color raised;
  final Color tint;
  final Color text;
  final Color subtext;
  final Color edge;
  final Color control;
  final Color action;
  final Color selectedMark;
  final Color pressed;
  final Color onAction;
  final Color income;
  final Color expense;
  final Color dining;
  final Color groceries;
  final Color transport;
  final Color supermarket;
  final Color freshMarket;
  final Color salary;
  final Color gap;
  final Color incomplete;
  final Color focus;
  final Color notice;
  final Color noticeBg;
  final Color error;
  final Color errorBg;
  final Color onCategory;
  final Color bezel;
  final Color fitness;
  final Color housing;

  @override
  SpendWiseColors copyWith({
    Color? base,
    Color? surface,
    Color? raised,
    Color? tint,
    Color? text,
    Color? subtext,
    Color? edge,
    Color? control,
    Color? action,
    Color? selectedMark,
    Color? pressed,
    Color? onAction,
    Color? income,
    Color? expense,
    Color? dining,
    Color? groceries,
    Color? transport,
    Color? supermarket,
    Color? freshMarket,
    Color? salary,
    Color? gap,
    Color? incomplete,
    Color? focus,
    Color? notice,
    Color? noticeBg,
    Color? error,
    Color? errorBg,
    Color? onCategory,
    Color? bezel,
    Color? fitness,
    Color? housing,
  }) {
    return SpendWiseColors(
      base: base ?? this.base,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      tint: tint ?? this.tint,
      text: text ?? this.text,
      subtext: subtext ?? this.subtext,
      edge: edge ?? this.edge,
      control: control ?? this.control,
      action: action ?? this.action,
      selectedMark: selectedMark ?? this.selectedMark,
      pressed: pressed ?? this.pressed,
      onAction: onAction ?? this.onAction,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      dining: dining ?? this.dining,
      groceries: groceries ?? this.groceries,
      transport: transport ?? this.transport,
      supermarket: supermarket ?? this.supermarket,
      freshMarket: freshMarket ?? this.freshMarket,
      salary: salary ?? this.salary,
      gap: gap ?? this.gap,
      incomplete: incomplete ?? this.incomplete,
      focus: focus ?? this.focus,
      notice: notice ?? this.notice,
      noticeBg: noticeBg ?? this.noticeBg,
      error: error ?? this.error,
      errorBg: errorBg ?? this.errorBg,
      onCategory: onCategory ?? this.onCategory,
      bezel: bezel ?? this.bezel,
      fitness: fitness ?? this.fitness,
      housing: housing ?? this.housing,
    );
  }

  @override
  SpendWiseColors lerp(ThemeExtension<SpendWiseColors>? other, double t) {
    if (other is! SpendWiseColors) return this;
    Color lerpColor(Color a, Color b) => Color.lerp(a, b, t)!;
    return SpendWiseColors(
      base: lerpColor(base, other.base),
      surface: lerpColor(surface, other.surface),
      raised: lerpColor(raised, other.raised),
      tint: lerpColor(tint, other.tint),
      text: lerpColor(text, other.text),
      subtext: lerpColor(subtext, other.subtext),
      edge: lerpColor(edge, other.edge),
      control: lerpColor(control, other.control),
      action: lerpColor(action, other.action),
      selectedMark: lerpColor(selectedMark, other.selectedMark),
      pressed: lerpColor(pressed, other.pressed),
      onAction: lerpColor(onAction, other.onAction),
      income: lerpColor(income, other.income),
      expense: lerpColor(expense, other.expense),
      dining: lerpColor(dining, other.dining),
      groceries: lerpColor(groceries, other.groceries),
      transport: lerpColor(transport, other.transport),
      supermarket: lerpColor(supermarket, other.supermarket),
      freshMarket: lerpColor(freshMarket, other.freshMarket),
      salary: lerpColor(salary, other.salary),
      gap: lerpColor(gap, other.gap),
      incomplete: lerpColor(incomplete, other.incomplete),
      focus: lerpColor(focus, other.focus),
      notice: lerpColor(notice, other.notice),
      noticeBg: lerpColor(noticeBg, other.noticeBg),
      error: lerpColor(error, other.error),
      errorBg: lerpColor(errorBg, other.errorBg),
      onCategory: lerpColor(onCategory, other.onCategory),
      bezel: lerpColor(bezel, other.bezel),
      fitness: lerpColor(fitness, other.fitness),
      housing: lerpColor(housing, other.housing),
    );
  }
}
