/// Window-width thresholds that decide the shell's navigation layout.
///
/// The rail and extended-rail switches each use two thresholds: one to enter
/// the mode and a lower one to leave it.
class LayoutBreakpoints {
  const LayoutBreakpoints._();

  /// Width at or above which the shell switches from a bottom [NavigationBar]
  /// to a side [NavigationRail].
  static const railEnter = 720.0;

  /// Width below which a shell already in rail mode switches back to the
  /// bottom bar.
  static const railExit = 680.0;

  /// Width at or above which a [NavigationRail] shows full labels
  /// ([NavigationRail.extended]) instead of icons with compact labels.
  static const extendedRailEnter = 1000.0;

  /// Width below which a shell already showing an extended rail switches
  /// back to the compact rail.
  static const extendedRailExit = 960.0;
}
