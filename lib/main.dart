import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:rustnithm_server/src/rust/frb_generated.dart';
import 'package:rustnithm_server/data/state.dart';
import 'package:rustnithm_server/data/io.dart';

import 'widgets/Header.dart';
import 'widgets/Config.dart';
import 'widgets/Visualizer.dart';

class ThemeController extends ChangeNotifier {
  final ServerIO _configIo;
  ThemeMode _themeMode;

  ThemeController({AppConfig? initialConfig, ServerIO? io})
    : _configIo = io ?? ServerIO(),
      _themeMode = _themeModeFromConfig(initialConfig?.themeMode) {
    if (initialConfig == null) _themeMode = ThemeMode.system;
  }

  static ThemeMode _themeModeFromConfig(String? value) {
    switch (value) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    if (_themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.light;
    } else if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    _saveThemeMode();
    _updateWindowEffect();
    notifyListeners();
  }

  void setThemeMode(int index) {
    if (index < 0 || index >= ThemeMode.values.length) return;
    _themeMode = ThemeMode.values[index];
    _saveThemeMode();
    _updateWindowEffect();
    notifyListeners();
  }

  void _saveThemeMode() {
    final value = switch (_themeMode) {
      ThemeMode.system => 'Auto',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
    _configIo.saveConfigPatch({'themeMode': value});
  }

  void _updateWindowEffect() {
    if (!Platform.isWindows) return;

    final brightness = PlatformDispatcher.instance.platformBrightness;
    bool isDark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system && brightness == Brightness.dark);

    Window.setEffect(effect: WindowEffect.tabbed, dark: isDark);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final configIo = ServerIO();
  final appConfig = await configIo.loadConfig();
  await RustLib.init();

  if (Platform.isWindows) {
    await Window.initialize();
    await windowManager.ensureInitialized();
  }

  if (Platform.isWindows) {
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      minimumSize: Size(950, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: "Rustnithm Server",
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      final brightness = PlatformDispatcher.instance.platformBrightness;
      final configuredTheme = ThemeController._themeModeFromConfig(
        appConfig.themeMode,
      );
      final isDark =
          configuredTheme == ThemeMode.dark ||
          (configuredTheme == ThemeMode.system &&
              brightness == Brightness.dark);
      await Window.setEffect(effect: WindowEffect.tabbed, dark: isDark);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ServerState(initialConfig: appConfig, io: configIo),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ThemeController(initialConfig: appConfig, io: configIo),
        ),
      ],
      child: const RustnithmApp(),
    ),
  );
}

class RustnithmApp extends StatelessWidget {
  const RustnithmApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeController>().themeMode;

    return MaterialApp(
      title: 'Rustnithm Server',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 8, 32, 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 258, child: HeaderBrand()),
                    SizedBox(width: 48),
                    Expanded(child: HeaderConfig()),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: Visualizer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
