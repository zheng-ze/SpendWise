import 'package:flutter/material.dart';

const double _underlineThickness = 3;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / titles.length;
        return SizedBox(
          height: 44,
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
                                  ? FontWeight.w700
                                  : FontWeight.w400,
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
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: tabWidth * selectedIndex,
                bottom: 0,
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
