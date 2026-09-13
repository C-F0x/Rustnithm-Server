import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rustnithm_server/main.dart';
import 'package:rustnithm_server/data/state.dart';
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
        return View.of(context).platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  void _showAboutDialog(bool isDark) {
    final renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
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
      pageBuilder: (context, _, _) => _AboutDialog(
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

        final scaleX =
            (imageWidth + (targetWidth - imageWidth) * t) / targetWidth;
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
        ? const Color(0xCC1C1C1E)
        : const Color(0xD9F4F4F4);
    final surfaceBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);

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
                  border: Border.all(color: surfaceBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.28 : 0.12,
                      ),
                      blurRadius: 28,
                      spreadRadius: 1,
                      offset: const Offset(0, 12),
                    ),
                  ],
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
                    const SizedBox(height: 18),
                    _PollFrequencyControl(
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    const SizedBox(height: 16),
                    _BillboardControl(
                      textColor: textColor,
                      subColor: subColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: onLaunchUrl,
                      child: Text(
                        'GitHub@C-F0x/Rustnithm-Server',
                        style: TextStyle(
                          color: isDark
                              ? Colors.lightBlueAccent
                              : Colors.blueAccent,
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

class _PollFrequencyControl extends StatelessWidget {
  final Color textColor;
  final Color subColor;

  const _PollFrequencyControl({
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerState>();
    final frequency = state.gameLedPollFrequency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Game LED poll frequency',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              '$frequency Hz',
              style: TextStyle(color: subColor, fontSize: 13),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: isDark
                ? Colors.cyanAccent.withValues(alpha: 0.88)
                : Colors.blueAccent.withValues(alpha: 0.82),
            inactiveTrackColor: isDark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.14),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7,
              elevation: 2,
            ),
            overlayColor: (isDark ? Colors.cyanAccent : Colors.blueAccent)
                .withValues(alpha: 0.14),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: frequency.toDouble(),
            min: 1,
            max: 1000,
            divisions: 999,
            label: '$frequency Hz',
            onChanged: (value) => state.setGameLedPollFrequency(value.round()),
          ),
        ),
      ],
    );
  }
}

class _BillboardControl extends StatelessWidget {
  final Color textColor;
  final Color subColor;
  final bool isDark;

  const _BillboardControl({
    required this.textColor,
    required this.subColor,
    required this.isDark,
  });

  void _showBillboard(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close billboard',
      barrierColor: Colors.black.withValues(alpha: 0.22),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => _BillboardDialog(isDark: isDark),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerState>();
    final enabled = state.isRunning && state.ledSource == LedSource.gameMemory;
    final accent = isDark ? Colors.cyanAccent : Colors.blueAccent;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Billboard',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text('11 x 30', style: TextStyle(color: subColor, fontSize: 12)),
            ],
          ),
        ),
        Tooltip(
          message: 'Open billboard',
          child: Semantics(
            button: true,
            enabled: enabled,
            label: 'Open billboard',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? () => _showBillboard(context) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled
                        ? accent.withValues(alpha: isDark ? 0.16 : 0.12)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04)),
                    border: Border.all(
                      color: enabled
                          ? accent.withValues(alpha: 0.55)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.09)),
                    ),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 18,
                    color: enabled ? accent : subColor.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BillboardDialog extends StatelessWidget {
  static const int _columnCount = 11;
  static const int _rowCount = 30;

  final bool isDark;

  const _BillboardDialog({required this.isDark});

  Color? _colorAt(List<int> rgb, int column, int row) {
    if (rgb.length != 360) return null;

    final isLeftBoard = column < 5;
    final boardColumn = isLeftBoard ? column : column - 5;
    final rowGroup = row ~/ 3;
    final logicalRow = isLeftBoard
        ? (boardColumn.isEven ? rowGroup : 9 - rowGroup)
        : (boardColumn.isEven ? 9 - rowGroup : rowGroup);
    final pixelIndex = (isLeftBoard ? 0 : 60) + boardColumn * 10 + logicalRow;
    final offset = pixelIndex * 3;
    final red = rgb[offset];
    final green = rgb[offset + 1];
    final blue = rgb[offset + 2];

    if (red == 0 && green == 0 && blue == 0) return null;
    return Color.fromARGB(255, red, green, blue);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerState>();
    final screenSize = MediaQuery.sizeOf(context);
    final maxDialogWidth = math.max(
      180.0,
      math.min(screenSize.width - 40, 560.0),
    );
    final maxDialogHeight = math.max(
      300.0,
      math.min(screenSize.height - 40, 840.0),
    );
    final boardWidth = math.max(
      1.0,
      math.min(maxDialogWidth - 50, (maxDialogHeight - 88) * 11 / 30),
    );
    final boardHeight = boardWidth * 30 / 11;
    final panelColor = isDark
        ? const Color(0xE61C1C1E)
        : const Color(0xEDF4F4F4);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
            child: Container(
              // Add the two-pixel border to the fixed content dimensions so
              // the header and the 11x30 grid do not compete for height.
              width: boardWidth + 50,
              height: boardHeight + 86,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'BILLBOARD 11 x 30',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Tooltip(
                          message: 'Close',
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: textColor.withValues(alpha: 0.72),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: boardWidth,
                    height: boardHeight,
                    child: Column(
                      children: List.generate(_rowCount, (row) {
                        return Expanded(
                          child: Row(
                            children: List.generate(_columnCount, (column) {
                              final color = _colorAt(
                                state.gameBillboardRgb,
                                column,
                                row,
                              );
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(0.8),
                                  child: SizedBox.expand(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            color ??
                                            (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.065,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.075,
                                                  )),
                                        boxShadow: color == null
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: color.withValues(
                                                    alpha: 0.35,
                                                  ),
                                                  blurRadius: 3,
                                                ),
                                              ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
