import 'package:flutter/material.dart';

class IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final bool? bold;
  final int maxLines;

  const IconText({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.bold,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: bold == true ? FontWeight.bold : null),
          ),
        ),
      ],
    );
  }
}
