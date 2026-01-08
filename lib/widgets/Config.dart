import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data.dart';
import '../main.dart';

class HeaderConfig extends StatefulWidget {
  const HeaderConfig({super.key});

  @override
  State<HeaderConfig> createState() => _HeaderConfigState();
}

class _HeaderConfigState extends State<HeaderConfig> {
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _portController.text = "";
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServerController>();
    final themeController = context.watch<ThemeController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isDark ? Colors.white24 : Colors.black38;
    final Color containerBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.05);
    final Color itemBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildThemeToggle(themeController, isDark),
          const SizedBox(width: 8),
          _buildDivider(isDark),
          _buildConfigItem(
            child: Row(
              children: [
                SizedBox(
                  height: 32,
                  child: Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: controller.isRunning,
                      onChanged: (_) => controller.toggleServer(),
                      activeThumbColor: Colors.blueAccent,
                      activeTrackColor:
                          Colors.blueAccent.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  controller.isRunning ? "RUNNING" : "STOPPED",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: controller.isRunning
                        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                        : secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(isDark),
          _buildConfigItem(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: itemBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ToggleButtons(
                isSelected: [
                  controller.protocol == ServerProtocol.udp,
                  controller.protocol == ServerProtocol.tcp
                ],
                onPressed: controller.isRunning
                    ? (index) {}
                    : (index) {
                        controller.setProtocol(index == 0
                            ? ServerProtocol.udp
                            : ServerProtocol.tcp);
                      },
                borderRadius: BorderRadius.circular(6),
                constraints: const BoxConstraints(minHeight: 32, minWidth: 50),
                fillColor: controller.isRunning
                    ? Colors.blueAccent.withValues(alpha: 0.4)
                    : Colors.blueAccent,
                selectedColor: Colors.white,
                color: isDark ? Colors.white38 : Colors.black45,
                borderColor: Colors.transparent,
                selectedBorderColor: Colors.transparent,
                children: const [
                  Text('UDP',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text('TCP',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          _buildDivider(isDark),
          Expanded(
            flex: 3,
            child: _buildConfigItem(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: itemBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => controller.nextIp(),
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(6)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.lan,
                                  size: 14, color: Colors.blueAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  controller.hostIp,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    color: isDark
                                        ? Colors.greenAccent
                                        : Colors.green.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(
                        width: 1, color: borderColor, indent: 6, endIndent: 6),
                    IconButton(
                      onPressed: () => controller.refreshIp(),
                      icon: Icon(Icons.refresh,
                          size: 14,
                          color: isDark ? Colors.white54 : Colors.black45),
                      tooltip: 'Refresh',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _buildConfigItem(
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _portController,
                        enabled: !controller.isRunning,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 13, color: textColor),
                        decoration: InputDecoration(
                          hintText: "Port",
                          hintStyle: TextStyle(
                              color: secondaryTextColor, fontSize: 13),
                          filled: true,
                          fillColor: itemBg,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(
                                color: Colors.blueAccent, width: 1.5),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide:
                                const BorderSide(color: Colors.transparent),
                          ),
                        ),
                        onChanged: (val) {
                          final p = int.tryParse(val);
                          if (p != null) controller.setPort(p);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(ThemeController themeController, bool isDark) {
    IconData icon;
    Color iconColor;

    switch (themeController.themeMode) {
      case ThemeMode.system:
        icon = Icons.brightness_auto_rounded;
        iconColor = isDark ? Colors.white54 : Colors.black45;
        break;
      case ThemeMode.light:
        icon = Icons.light_mode_rounded;
        iconColor = Colors.orangeAccent;
        break;
      case ThemeMode.dark:
        icon = Icons.dark_mode_rounded;
        iconColor = Colors.cyanAccent;
        break;
    }

    return IconButton(
      onPressed: () => themeController.toggleTheme(),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(icon, key: ValueKey(icon), color: iconColor, size: 20),
      ),
    );
  }

  Widget _buildConfigItem({required Widget child}) => child;

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
          height: 24,
          child: VerticalDivider(
              width: 1,
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.1))),
    );
  }
}
