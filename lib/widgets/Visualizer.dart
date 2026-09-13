import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rustnithm_server/data/state.dart';
import 'dart:typed_data';

class Visualizer extends StatelessWidget {
  const Visualizer({super.key});

  LedVisualColors _buildLedColors(ServerState state) {
    if (state.ledSource != LedSource.gameMemory ||
        state.gameSliderRgb.length != 93 ||
        state.gameTowerRgb.length != 18) {
      return const LedVisualColors.empty();
    }

    final zoneColors = <Color?>[];
    final dividerColors = <Color?>[];
    for (var i = 0; i < 31; i++) {
      final offset = i * 3;
      final color = _gameColor(
        state.gameSliderRgb[offset + 1],
        state.gameSliderRgb[offset + 2],
        state.gameSliderRgb[offset],
      );
      if (i.isEven) {
        zoneColors.add(color);
      } else {
        dividerColors.add(color);
      }
    }

    List<Color?> towerColors(List<int> bytes) => List.generate(3, (index) {
      final offset = index * 3;
      return _gameColor(bytes[offset], bytes[offset + 1], bytes[offset + 2]);
    });

    return LedVisualColors(
      sliderZones: zoneColors,
      sliderDividers: dividerColors,
      leftTower: towerColors(state.gameTowerRgb.sublist(0, 9)),
      rightTower: towerColors(state.gameTowerRgb.sublist(9, 18)),
    );
  }

  Color? _gameColor(int red, int green, int blue) {
    if (red == 0 && green == 0 && blue == 0) return null;
    return Color.fromARGB(255, red, green, blue);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Consumer<ServerState>(
      builder: (context, state, child) {
        if (!state.isRunning) {
          return _WaitingView(isDark: isDark);
        }

        final ledColors = _buildLedColors(state);
        final content = Column(
          children: [
            Expanded(flex: 35, child: _buildAirSection(context, state, isDark)),
            Expanded(
              flex: 65,
              child: _buildSliderSection(
                context,
                state,
                state.sliderData,
                isDark,
                ledColors: ledColors,
              ),
            ),
          ],
        );

        final hasTowerColor =
            ledColors.leftTower != null &&
            ledColors.rightTower != null &&
            (ledColors.leftTower!.any((color) => color != null) ||
                ledColors.rightTower!.any((color) => color != null));
        final contentWithDividers = !hasTowerColor
            ? content
            : Stack(
                fit: StackFit.expand,
                children: [
                  content,
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _VisualizerSideDividerPainter(
                        leftColors: ledColors.leftTower!,
                        rightColors: ledColors.rightTower!,
                      ),
                    ),
                  ),
                ],
              );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: contentWithDividers,
        );
      },
    );
  }

  String _decodeBcd(Uint8List bcdBytes) {
    bool hasData = false;
    for (int i = 0; i < bcdBytes.length; i++) {
      if (bcdBytes[i] != 0) {
        hasData = true;
        break;
      }
    }
    if (!hasData) return "";
    final List<int> chars = List<int>.filled(20, 0);

    for (int i = 0; i < 10 && i < bcdBytes.length; i++) {
      int byte = bcdBytes[i];

      int high = (byte >> 4) & 0x0F;
      int low = byte & 0x0F;

      chars[i * 2] = high + 48;
      chars[i * 2 + 1] = low + 48;
    }
    return String.fromCharCodes(chars);
  }

  Widget _buildAirSection(
    BuildContext context,
    ServerState state,
    bool isDark,
  ) {
    final String decodedCode = _decodeBcd(state.code);

    final sideButtons = [
      {'label': 'COIN', 'val': state.coin},
      {'label': 'SERV', 'val': state.service},
      {'label': 'TEST', 'val': state.test},
      {'label': 'CODE', 'val': decodedCode.isNotEmpty ? 1 : 0},
    ];

    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
    final borderColor = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.1);
    final inactiveText = isDark ? Colors.white12 : Colors.black26;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Column(
                  children: List.generate(sideButtons.length, (index) {
                    final btn = sideButtons[index];
                    final String label = btn['label'] as String;
                    final bool isActive = (btn['val'] as int) > 0;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 50),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.amberAccent : baseColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isActive
                                  ? (isDark ? Colors.white : Colors.black38)
                                  : borderColor,
                              width: 0.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isActive
                                    ? Colors.black
                                    : (isDark
                                          ? Colors.white38
                                          : Colors.black45),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    children: List.generate(6, (index) {
                      int logicNum = 6 - index;
                      int logicIndex = logicNum - 1;
                      bool isActive = state.airData[logicIndex] > 0;

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark
                                      ? Colors.cyanAccent
                                      : Colors.cyan.shade400)
                                : baseColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isActive
                                  ? (isDark ? Colors.white : Colors.black26)
                                  : borderColor,
                              width: 0.5,
                            ),
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Text(
                                  "AIR $logicNum",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.black
                                        : inactiveText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              _buildAccessCodeDisplay(decodedCode, isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccessCodeDisplay(String code, bool isDark) {
    String displayCode = code.padRight(20, ' ').substring(0, 20);
    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < displayCode.length; i++) {
      formatted.write(displayCode[i]);
      if ((i + 1) % 5 == 0 && i != displayCode.length - 1) {
        formatted.write('\n');
      }
    }

    return Container(
      width: 80,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "ACCESS CODE",
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatted.toString(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: code.isEmpty
                  ? (isDark ? Colors.white10 : Colors.black12)
                  : (isDark ? Colors.greenAccent : Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSection(
    BuildContext context,
    ServerState state,
    List<int> sliderData,
    bool isDark, {
    required LedVisualColors ledColors,
  }) {
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
    final borderColor = isDark
        ? Colors.white10
        : Colors.black.withValues(alpha: 0.1);
    final inactiveText = isDark ? Colors.white12 : Colors.black26;

    final sliderGrid = Column(
      children: List.generate(2, (row) {
        return Expanded(
          child: Row(
            children: List.generate(16, (col) {
              int logicIndex = (15 - col) * 2 + (row + 1);
              int dataIndex = logicIndex - 1;
              bool isActive = sliderData[dataIndex] > 0;
              final isGameLed = ledColors.sliderZones != null;
              final Color? gameZoneColor = ledColors.sliderZones == null
                  ? null
                  : ledColors.sliderZones![15 - col];

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: isGameLed
                        ? (gameZoneColor ?? baseColor)
                        : (isActive ? Colors.amberAccent : baseColor),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                      color: !isGameLed && isActive
                          ? (isDark ? Colors.white : Colors.black26)
                          : borderColor,
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          "$logicIndex",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isGameLed && gameZoneColor == null
                                ? inactiveText
                                : gameZoneColor == null
                                ? (isActive ? Colors.black : inactiveText)
                                : (gameZoneColor.computeLuminance() > 0.35
                                      ? Colors.black
                                      : Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );

    if (ledColors.sliderDividers == null ||
        ledColors.sliderDividers!.every((color) => color == null)) {
      return sliderGrid;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        sliderGrid,
        IgnorePointer(
          child: CustomPaint(
            painter: _SliderGridDividerPainter(
              colors: ledColors.sliderDividers!,
            ),
          ),
        ),
      ],
    );
  }
}

class _SliderGridDividerPainter extends CustomPainter {
  static const int _columnCount = 16;
  static const double _cellMargin = 1.5;

  final List<Color?> colors;

  const _SliderGridDividerPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.length < 15) return;
    final paint = Paint()
      // Each divider fills the existing 1.5px margin on both adjacent cells.
      ..strokeWidth = _cellMargin * 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final columnWidth = size.width / _columnCount;
    for (int column = 1; column < _columnCount; column++) {
      final x = columnWidth * column;
      final color = colors[_columnCount - column - 1];
      if (color == null) continue;
      paint.color = color;
      canvas.drawLine(
        Offset(x, _cellMargin),
        Offset(x, size.height - _cellMargin),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SliderGridDividerPainter oldDelegate) =>
      oldDelegate.colors.length != colors.length ||
      oldDelegate.colors.asMap().entries.any(
        (entry) => entry.value != colors[entry.key],
      );
}

class _VisualizerSideDividerPainter extends CustomPainter {
  static const double _lineWidth = 3.0;

  final List<Color?> leftColors;
  final List<Color?> rightColors;

  const _VisualizerSideDividerPainter({
    required this.leftColors,
    required this.rightColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || leftColors.length < 3 || rightColors.length < 3) return;
    final leftGradientColors = leftColors
        .map((color) => color ?? Colors.transparent)
        .toList();
    final rightGradientColors = rightColors
        .map((color) => color ?? Colors.transparent)
        .toList();

    final leftGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.5, 1.0],
      colors: leftGradientColors,
    ).createShader(Offset.zero & size);
    final rightGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.5, 1.0],
      colors: rightGradientColors,
    ).createShader(Offset.zero & size);
    final paint = Paint();

    // Align with the outer 1.5px cell margin used by the slider grid. The
    // bars therefore fill that existing edge margin without changing layout.
    final radius = Radius.circular(_lineWidth / 2);
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _lineWidth, size.height),
      radius,
    );
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - _lineWidth, 0, _lineWidth, size.height),
      radius,
    );
    paint.shader = leftGradient;
    canvas.drawRRect(leftRect, paint);
    paint.shader = rightGradient;
    canvas.drawRRect(rightRect, paint);
  }

  @override
  bool shouldRepaint(covariant _VisualizerSideDividerPainter oldDelegate) =>
      !_sameColors(oldDelegate.leftColors, leftColors) ||
      !_sameColors(oldDelegate.rightColors, rightColors);

  static bool _sameColors(List<Color?> a, List<Color?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class LedVisualColors {
  final List<Color?>? sliderZones;
  final List<Color?>? sliderDividers;
  final List<Color?>? leftTower;
  final List<Color?>? rightTower;

  const LedVisualColors({
    this.sliderZones,
    this.sliderDividers,
    this.leftTower,
    this.rightTower,
  });

  const LedVisualColors.empty()
    : sliderZones = null,
      sliderDividers = null,
      leftTower = null,
      rightTower = null;
}

class _WaitingView extends StatelessWidget {
  final bool isDark;
  const _WaitingView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: isDark ? 0.15 : 0.3,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_on_rounded,
              size: 100,
              color: isDark ? Colors.white : Colors.black,
            ),
            const SizedBox(height: 16),
            Text(
              "WAITING FOR ACTIVATION",
              style: TextStyle(
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
