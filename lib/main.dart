import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:rustnithm_server/src/rust/frb_generated.dart';
import 'package:rustnithm_server/data/state.dart';

import 'widgets/Header.dart';
import 'widgets/Config.dart';
import 'widgets/Visualizer.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    if (_themeMode == ThemeMode.system) {
      _themeMode = ThemeMode.light;
    } else if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void setThemeMode(int index) {
    _themeMode = ThemeMode.values[index];
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Rust 库
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
      await Window.setEffect(
        effect: WindowEffect.tabbed,
        dark: true,
      );
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(
    MultiProvider(
      providers: [
        // 2. 将 ServerController 替换为 ServerState
        ChangeNotifierProvider(create: (_) => ServerState()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
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

    if (Platform.isWindows) {
      bool isDark = themeMode == ThemeMode.dark ||
          (themeMode == ThemeMode.system &&
              MediaQuery.platformBrightnessOf(context) == Brightness.dark);

      Window.setEffect(
        effect: WindowEffect.tabbed,
        dark: isDark,
      );
    }

    return MaterialApp(
      title: 'Rustnithm Server',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.cyanAccent, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.cyanAccent, brightness: Brightness.dark),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 208,
                      child: HeaderBrand(),
                    ),
                    SizedBox(width: 48),
                    Expanded(
                      child: HeaderConfig(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha:0.05),
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