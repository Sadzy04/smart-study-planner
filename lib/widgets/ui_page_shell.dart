import 'package:flutter/material.dart';

class UiPageShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const UiPageShell({
    super.key,
    required this.child,
    this.maxWidth = 980,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 32),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8F5FC),
            Color(0xFFF6F3FB),
            Color(0xFFF2F7FF),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}