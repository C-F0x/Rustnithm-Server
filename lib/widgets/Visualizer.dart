import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data.dart';

class Visualizer extends StatelessWidget {
  const Visualizer({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Consumer<ServerController>(
      builder: (context, controller, child) {
        if (!controller.isRunning) {
          return _WaitingView(isDark: isDark);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            children: [
              Expanded(
                flex: 35,
                child: _buildAirSection(context, controller, isDark),
              ),
              Expanded(
                flex: 65,
                child: _buildSliderSection(
                    context, controller, controller.sliderData, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAirSection(
      BuildContext context, ServerController controller, bool isDark) {
    final sideButtons = [
      {'label': 'COIN', 'key': 'coin', 'val': controller.coin},
      {'label': 'SERV', 'key': 'service', 'val': controller.service},
      {'label': 'TEST', 'key': 'test', 'val': controller.test},
    ];

    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
    final borderColor =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1);
    final inactiveText = isDark ? Colors.white12 : Colors.black26;

    return LayoutBuilder(builder: (context, constraints) {
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
                  final String key = btn['key'] as String;
                  final bool isActive = (btn['val'] as int) > 0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Listener(
                        onPointerDown: (_) =>
                            controller.triggerButton(key, 0, true),
                        onPointerUp: (_) =>
                            controller.triggerButton(key, 0, false),
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
                    bool isActive = controller.airData[logicIndex] > 0;

                    return Expanded(
                      child: Listener(
                        onPointerDown: (_) =>
                            controller.triggerButton('air', logicIndex, true),
                        onPointerUp: (_) =>
                            controller.triggerButton('air', logicIndex, false),
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
                                    color:
                                        isActive ? Colors.black : inactiveText,
                                  ),
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
            const SizedBox(width: 70),
          ],
        ),
      );
    });
  }

  Widget _buildSliderSection(BuildContext context, ServerController controller,
      List<int> sliderData, bool isDark) {
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.06);
    final borderColor =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1);
    final inactiveText = isDark ? Colors.white12 : Colors.black26;

    return Column(
      children: List.generate(2, (row) {
        return Expanded(
          child: Row(
            children: List.generate(16, (col) {
              int logicIndex = (15 - col) * 2 + (row + 1);
              int dataIndex = logicIndex - 1;
              bool isActive = sliderData[dataIndex] > 0;

              return Expanded(
                child: Listener(
                  onPointerDown: (_) =>
                      controller.triggerButton('slider', dataIndex, true),
                  onPointerUp: (_) =>
                      controller.triggerButton('slider', dataIndex, false),
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.amberAccent : baseColor,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: isActive
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
                              color: isActive ? Colors.black : inactiveText,
                            ),
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
  }
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
            Icon(Icons.grid_on_rounded,
                size: 100, color: isDark ? Colors.white : Colors.black),
            const SizedBox(height: 16),
            Text("WAITING FOR CONNECTION",
                style: TextStyle(
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black,
                )),
          ],
        ),
      ),
    );
  }
}
