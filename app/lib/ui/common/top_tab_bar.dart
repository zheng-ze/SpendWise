import 'package:flutter/material.dart';

// MARK: - Constants

const _regularWeight = FontWeight.w400;

const _boldWeight = FontWeight.w700;

const double _underlineThickness = 3;

const _indicatorBottom = 0.0;

// MARK: - TopTabBar
class TopTabBar extends StatelessWidget {
  const TopTabBar({
    super.key,
    required this.titles,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> titles;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _barHeight = 44.0;

  static const _indicatorAnimation = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / titles.length;
        return SizedBox(
          height: _barHeight,
          child: Stack(
            children: [
              Row(
                children: [
                  for (var index = 0; index < titles.length; index++)
                    Expanded(
                      child: InkWell(
                        onTap: () => onSelected(index),
                        child: Center(
                          child: Text(
                            titles[index],
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: index == selectedIndex
                                  ? _boldWeight
                                  : _regularWeight,
                              color: index == selectedIndex
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedPositioned(
                duration: _indicatorAnimation,
                curve: Curves.easeOut,
                left: tabWidth * selectedIndex,
                bottom: _indicatorBottom,
                width: tabWidth,
                height: _underlineThickness,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
