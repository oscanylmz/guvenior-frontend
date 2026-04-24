import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/reset_password_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/web/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  await initializeDateFormatting('tr', null);
  await ApiService.loadToken();
  runApp(const GuveniorApp());
}

class GuveniorApp extends StatefulWidget {
  const GuveniorApp({super.key});

  @override
  State<GuveniorApp> createState() => _GuveniorAppState();
}

class _GuveniorAppState extends State<GuveniorApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Cold start
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      _handleIncomingUri(initial);
    }

    // While running
    _appLinks.uriLinkStream.listen(_handleIncomingUri);
  }

  void _handleIncomingUri(Uri uri) {
    // Supports:
    // - Web: http://localhost:59162/reset-password?email=...&token=...
    // - Mobile deep link: guvenior://reset-password?email=...&token=...
    final isReset = uri.path == '/reset-password' || uri.host == 'reset-password';
    if (!isReset) return;

    final email = uri.queryParameters['email'];
    final token = uri.queryParameters['token'];

    final route = Uri(
      path: '/reset-password',
      queryParameters: {
        if (email != null) 'email': email,
        if (token != null) 'token': token,
      },
    ).toString();

    _navigatorKey.currentState?.pushNamed(route);
  }

  String _initialRoute() {
    // Web: allow direct navigation to `/reset-password?...`
    final initialPath = Uri.base.path;
    return (initialPath == '/reset-password') ? '/reset-password' : '/';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Güvenior',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: _initialRoute(),
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        final uri = Uri.tryParse(name) ?? Uri(path: name);

        switch (uri.path) {
          case '/':
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => ApiService.hasToken
                  ? const DashboardScreen()
                  : const LoginScreen(),
            );
          case '/reset-password':
            final email = uri.queryParameters['email'];
            final token = uri.queryParameters['token'];
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => ResetPasswordScreen(
                email: email,
                token: token,
              ),
            );
          default:
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const Scaffold(
                body: Center(
                  child: Text('Sayfa bulunamadı'),
                ),
              ),
            );
        }
      },
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('tr'), Locale('en')],
    );
  }
}
