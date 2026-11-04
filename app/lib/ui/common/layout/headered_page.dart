import 'package:flutter/material.dart';

class HeaderedPage extends StatelessWidget {
  const HeaderedPage({super.key, required this.header, required this.body});

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }
}
