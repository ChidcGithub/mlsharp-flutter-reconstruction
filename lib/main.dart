import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'theme/app_theme.dart';
import 'providers/app_settings_provider.dart';
import 'services/inference_logger.dart';
import 'pages/onboarding_page.dart';
import 'pages/home_page.dart';
import 'pages/local_inference_page.dart';
import 'pages/terminal_page.dart';
import 'pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsProvider = AppSettingsProvider();
  await settingsProvider.init();

  // 初始化 Sentry
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://example@sentry.io/example'; // 占位 DSN
      options.tracesSampleRate = 1.0;
      options.reportSilentFlutterErrors = true;
    },
    appRunner: () => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => settingsProvider),
          ChangeNotifierProvider(create: (_) => InferenceLogger()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsProvider>(
      builder: (context, settings, _) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            ColorScheme lightColorScheme;
            ColorScheme darkColorScheme;

            if (settings.useDynamicColor && lightDynamic != null && darkDynamic != null) {
              lightColorScheme = lightDynamic.harmonized();
              darkColorScheme = darkDynamic.harmonized();
            } else {
              lightColorScheme = ColorScheme.fromSeed(
                seedColor: settings.seedColor,
                brightness: Brightness.light,
              );
              darkColorScheme = ColorScheme.fromSeed(
                seedColor: settings.seedColor,
                brightness: Brightness.dark,
              );
            }

            return MaterialApp(
              title: 'MLSharp 3D Maker',
              theme: AppTheme.lightTheme(colorScheme: lightColorScheme),
              darkTheme: AppTheme.darkTheme(colorScheme: darkColorScheme),
              themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              navigatorObservers: [
                SentryNavigatorObserver(),
              ],
              home: settings.onboardingCompleted 
                  ? const MyHomePage(title: 'MLSharp 3D Maker')
                  : const OnboardingPage(),
              routes: {
                '/home': (context) => const MyHomePage(title: 'MLSharp 3D Maker'),
                '/onboarding': (context) => const OnboardingPage(),
              },
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const LocalInferencePage(),
    const TerminalPage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: _onItemTapped,
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '主页',
          ),
          NavigationDestination(
            icon: Icon(Icons.computer_outlined),
            selectedIcon: Icon(Icons.computer),
            label: '本地推理',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: '终端',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
