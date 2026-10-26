import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'router.dart';
import 'theme/smartflow_theme.dart';
import 'widgets/api_connection_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SmartflowApp());
}

class SmartflowApp extends StatefulWidget {
  const SmartflowApp({super.key});

  @override
  State<SmartflowApp> createState() => _SmartflowAppState();
}

class _SmartflowAppState extends State<SmartflowApp>
    with WidgetsBindingObserver {
  late final AuthProvider _auth = AuthProvider();
  late final GoRouter _router = createRouter(_auth);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth.bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _auth.checkSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    _auth.dispose();
    super.dispose();
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
                    if (child != null)
                      Positioned.fill(
                        child: Column(
                          children: [
                            const ApiConnectionBanner(),
                            Expanded(child: child),
                          ],
                        ),
                      ),
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

/// Shown while the saved session is restored. It continues the Android launch screen (the SmartFlow mark, same size and
/// place, on the brand navy) so opening the app never flashes a different screen. Android 12 and newer draw the mark on
/// their launch screen (dot, S, QR square); this screen starts from the finished mark.
class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SfColors.navy,
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/brand/smartflow_splash.png',
              width: 134,
              semanticLabel: 'SmartFlow',
            ),
          ),
          const Align(
            alignment: Alignment(0, 0.42),
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF9EC0EA),
              ),
            ),
          ),
        ],
      ),
    );
  }
}