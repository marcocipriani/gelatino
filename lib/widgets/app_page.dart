import 'package:flutter/material.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:gelatino/design/responsive.dart';

class AppPage extends StatelessWidget {
  const AppPage({required this.child, this.fullBleed = false, super.key});

  final Widget child;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaWidth = MediaQuery.sizeOf(context).width;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaWidth;
        final finiteWidth = availableWidth.isFinite
            ? availableWidth
            : AppLayout.maxContent;

        if (fullBleed) {
          return SizedBox(width: finiteWidth, child: child);
        }

        final responsiveClass = ResponsiveClass.fromWidth(finiteWidth);
        return SizedBox(
          width: finiteWidth,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: responsiveClass.horizontalPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.maxContent,
                ),
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
