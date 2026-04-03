import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rustnithm_server/main.dart';
import 'package:url_launcher/url_launcher.dart';

class HeaderBrand extends StatefulWidget {
  const HeaderBrand({super.key});

  @override
  State<HeaderBrand> createState() => _HeaderBrandState();
}

class _HeaderBrandState extends State<HeaderBrand> {
  final GlobalKey _imageKey = GlobalKey();

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse('https://github.com/C-F0x/Rustnithm-Server');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  bool _resolveIsDark(ThemeController themeController, BuildContext context) {
    switch (themeController.themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return View.of(context).platformDispatcher.platformBrightness == Brightness.dark;
    }
  }

  void _showAboutDialog(bool isDark) {
    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final imagePos = renderBox.localToGlobal(Offset.zero);
    final imageSize = renderBox.size;
    final imageCenter = Offset(
      imagePos.dx + imageSize.width / 2,
      imagePos.dy + imageSize.height / 2,
    );

    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, __) => _AboutDialog(
        isDark: isDark,
        onLaunchUrl: _launchUrl,
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final t = curved.value;
        final dx = (imageCenter.dx - screenCenter.dx) * (1 - t);
        final dy = (imageCenter.dy - screenCenter.dy) * (1 - t);

        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: 0.4 + 0.6 * t,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final isDark = _resolveIsDark(themeController, context);

    return GestureDetector(
      onTap: () => _showAboutDialog(isDark),
      child: ClipRRect(
        key: _imageKey,
        borderRadius: BorderRadius.circular(8.0),
        child: Image.asset(
          'assets/banner.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 48,
            height: 48,
            color: Colors.white10,
            child: const Icon(Icons.image_not_supported, size: 24),
          ),
        ),
      ),
    );
  }
}

class _AboutDialog extends StatelessWidget {
  final bool isDark;
  final VoidCallback onLaunchUrl;

  const _AboutDialog({required this.isDark, required this.onLaunchUrl});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.1);
    final overlayColor = isDark ? Colors.white.withValues(alpha: 2.05) : Colors.white.withValues(alpha: 0.4);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Container(
                color: overlayColor,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rustnithm Server',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'A mixture of dart and rust',
                      style: TextStyle(color: subColor, fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: onLaunchUrl,
                      child: const Text(
                        'https://github.com/C-F0x/Rustnithm-Server',
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('OK', style: TextStyle(color: subColor)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}