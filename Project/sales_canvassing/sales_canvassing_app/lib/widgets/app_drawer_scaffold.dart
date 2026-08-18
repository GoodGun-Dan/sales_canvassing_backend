import 'package:flutter/material.dart';
import '../main.dart' show mainNavScaffoldKey;

/// Scaffold dengan AppBar + tombol drawer untuk layar di MainNavigation.
class AppDrawerScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AppDrawerScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainNavScaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(title),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Drawer jika layar di tab utama; tombol back jika dibuka lewat Navigator.push.
Widget buildScreenShell(
  BuildContext context, {
  required String title,
  required Widget body,
  List<Widget>? actions,
  Widget? floatingActionButton,
}) {
  if (Navigator.of(context).canPop()) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
  return AppDrawerScaffold(
    title: title,
    body: body,
    actions: actions,
    floatingActionButton: floatingActionButton,
  );
}
