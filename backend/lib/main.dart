import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'router.dart';
import 'theme/smartflow_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const SmartflowApp());
}

class SmartflowApp extends StatefulWidget {
  const SmartflowApp({super.key});

  @override
  State<SmartflowApp> createState() => _SmartflowAppState();
}

class _SmartflowAppState extends State<SmartflowApp> {
  late final AuthProvider _auth = AuthProvider();
  late final GoRouter _router = createRouter(_auth);

  @override
  void initState() {
    super.initState();
    _auth.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _auth,
      child: AnimatedBuilder(
        animation: _auth,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'SmartFlow',
            theme: buildSmartflowTheme(),
            themeMode: ThemeMode.light,
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
            // One MaterialApp for the whole session — swapping MaterialApp vs
            // MaterialApp.router was leaving a 0×0 surface on some devices.
            builder: (context, child) {
              // Keep the router subtree mounted with expand constraints. Replacing
              // `child` entirely during bootstrap left a 0×0 surface on emulators.
              return ColoredBox(
                color: SfColors.bg,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (child != null) Positioned.fill(child: child),
                    if (_auth.loading)
                      const Positioned.fill(child: _BootstrapSplash()),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Shown while saved session is restored — matches app sky gradient (not black).
class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SfColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: SfGradients.pageSky),
        child: const Center(
          child: CircularProgressIndicator(color: SfColors.blue),
        ),
      ),
    );
  }
}
