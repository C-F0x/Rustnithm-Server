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
    final imageWidth = imageSize.width;
    final imageCenter = Offset(
      imagePos.dx + imageSize.width / 2,
      imagePos.dy + imageSize.height / 2,
    );

    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    final targetWidth = screenSize.width * 0.42;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, _, __) => _AboutDialog(
        isDark: isDark,
        onLaunchUrl: _launchUrl,
        imageWidth: imageWidth,
        targetWidth: targetWidth,
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final t = curved.value;

        final dx = (imageCenter.dx - screenCenter.dx) * (1 - t);
        final dy = (imageCenter.dy - screenCenter.dy) * (1 - t);

        final scaleX = (imageWidth + (targetWidth - imageWidth) * t) / targetWidth;
        final scaleY = 0.3 + 0.7 * t;

        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
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
  final double imageWidth;
  final double targetWidth;

  const _AboutDialog({
    required this.isDark,
    required this.onLaunchUrl,
    required this.imageWidth,
    required this.targetWidth,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    final tintColor = isDark
        ? Colors.black.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.78);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: targetWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                decoration: BoxDecoration(
                  color: tintColor,
                  borderRadius: BorderRadius.circular(16),
                ),
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
                    const SizedBox(height: 8),
                    Text(
                      'A mixture of dart and rust',
                      style: TextStyle(color: subColor, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: onLaunchUrl,
                      child: Text(
                        'GitHub@C-F0x/Rustnithm-Server',
                        style: TextStyle(
                          color: isDark ? Colors.lightBlueAccent : Colors.blueAccent,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: isDark
                              ? Colors.lightBlueAccent
                              : Colors.blueAccent,
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