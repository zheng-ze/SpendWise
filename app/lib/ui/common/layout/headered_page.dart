import 'package:flutter/material.dart';

class HeaderedPage extends StatelessWidget {
  const HeaderedPage({super.key, this.header, required this.body});

  final Widget? header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    if (header == null) return body;
    return Column(
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }
}
