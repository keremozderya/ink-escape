import 'package:flutter/widgets.dart';

/// Center short menus; let taller menus scroll without clipping their buttons.
class InkCenteredMenu extends StatelessWidget {
  const InkCenteredMenu({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );
}
