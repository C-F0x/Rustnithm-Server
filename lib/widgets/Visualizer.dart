import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rustnithm_server/data/state.dart';

class Visualizer extends StatelessWidget {
  const Visualizer({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Consumer<ServerState>(
      builder: (context, state, child) {
        if (!state.isRunning) {
          return _WaitingView(isDark: isDark);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            children: [
              Expanded(
                flex: 35,
                child: _buildAirSection(context, state, isDark),
              ),
              Expanded(
                flex: 65,
                child: _buildSliderSection(
                    context, state, state.sliderData, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAirSection(
      BuildContext context, ServerState state, bool isDark) {
    final sideButtons = [
      {'label': 'COIN', 'key': 'coin', 'val': state.coin},
      {'label': 'SERV', 'key': 'service', 'val': state.service},
      {'label': 'TEST', 'key': 'test', 'val': state.test},
      {'label': 'CODE', 'key': 'code', 'val': state.code.isNotEmpty ? 1 : 0}
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
                  final bool isActive = (btn['val'] is int)
                      ? (btn['val'] as int) > 0
                      : (btn['val'] as String).isNotEmpty;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Listener(
                        onPointerDown: (_) => state.updateButton(key, 0, true),
                        onPointerUp: (_) => state.updateButton(key, 0, false),
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
                                color: isActive ? Colors.black : (isDark ? Colors.white38 : Colors.black45),
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
                    bool isActive = state.airData[logicIndex] > 0;

                    return Expanded(
                      child: Listener(
                        onPointerDown: (_) => state.updateButton('air', logicIndex, true),
                        onPointerUp: (_) => state.updateButton('air', logicIndex, false),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isActive ? (isDark ? Colors.cyanAccent : Colors.cyan.shade400) : baseColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isActive ? (isDark ? Colors.white : Colors.black26) : borderColor,
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
              ),
            ),
            _buildAccessCodeDisplay(state.code, isDark),
          ],
        ),
      );
    });
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
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "ACCESS CODE",
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blueAccent),
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

  Widget _buildSliderSection(BuildContext context, ServerState state,
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
                      state.updateButton('slider', dataIndex, true),
                  onPointerUp: (_) =>
                      state.updateButton('slider', dataIndex, false),
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