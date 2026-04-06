import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rustnithm_server/data/state.dart';
import 'package:rustnithm_server/main.dart';

class HeaderConfig extends StatefulWidget {
  const HeaderConfig({super.key});

  @override
  State<HeaderConfig> createState() => _HeaderConfigState();
}

class _HeaderConfigState extends State<HeaderConfig> {
  final TextEditingController _portController = TextEditingController();
  final FocusNode _portFocusNode = FocusNode();
  final FocusNode _indicatorFocusNode = FocusNode();
  bool _isPortError = false;
  bool _isManualWaiting = false;
  Timer? _rollbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<ServerState>();
      _portController.text = state.port.toString();
    });
    _portFocusNode.addListener(() {
      if (!_portFocusNode.hasFocus) {
        _validateAndSavePort();
      }
    });
  }

  void _validateAndSavePort() {
    final state = context.read<ServerState>();
    final int? newPort = int.tryParse(_portController.text);

    if (newPort == null || newPort < 1 || newPort > 65535) {
      setState(() => _isPortError = true);
      return;
    }

    try {
      state.setPort(newPort);
      setState(() => _isPortError = false);
    } catch (e) {
      setState(() => _isPortError = true);
    }
  }

  @override
  void dispose() {
    _portFocusNode.dispose();
    _indicatorFocusNode.dispose();
    _portController.dispose();
    _rollbackTimer?.cancel();
    super.dispose();
  }

  Color _getIndicatorColor(ServerState state, bool isDark) {
    if (_isManualWaiting || state.isTransitioning) {
      return Colors.amberAccent;
    }
    if (state.isRunning) {
      return isDark ? Colors.greenAccent : Colors.green.shade600;
    }
    return isDark ? Colors.redAccent : Colors.red.shade600;
  }

  void _handleTap(ServerState state) {
    if (state.isTransitioning) return;
    state.toggleServer();
  }

  void _handleLongPress(ServerState state) async {
    if (state.isTransitioning || !state.isRunning) return;

    setState(() => _isManualWaiting = true);

    final bool sent = await state.toggleSync();

    if (!sent) {
      setState(() => _isManualWaiting = false);
      return;
    }

    _rollbackTimer?.cancel();
    _rollbackTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isManualWaiting = false);
    });
  }

  void _showConnectionTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded, color: Colors.amberAccent),
              const SizedBox(width: 10),
              Text(
                "Connection Tips",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "1. Connect Manual on both sides while first using",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 12),
              Text(
                "2. Connect Manual on both sides when IP changed",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 12),
              Text(
                "3. Nop.",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "GOT IT",
                style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerState>();
    final themeController = context.watch<ThemeController>();

    final Brightness platformBrightness = View.of(context).platformDispatcher.platformBrightness;
    final bool isDark = themeController.themeMode == ThemeMode.system
        ? platformBrightness == Brightness.dark
        : themeController.themeMode == ThemeMode.dark;

    if (state.showTipsSignal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showConnectionTips(context);
        state.consumeTipsSignal();
      });
    }

    final Color textColor = isDark ? Colors.white : Colors.black87;
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
          _buildIndicator(state, isDark),
          _buildDivider(isDark),
          _buildProtocolToggle(state, isDark),
          _buildDivider(isDark),
          _buildIpSelector(state, isDark, itemBg, borderColor),
          const SizedBox(width: 16),
          _buildPortField(state, textColor, itemBg, borderColor, isDark),
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
        child: Icon(icon, key: ValueKey(icon), color: iconColor, size: 20),
      ),
    );
  }

  Widget _buildIndicator(ServerState state, bool isDark) {
    final color = _getIndicatorColor(state, isDark);

    IconData icon;
    if (_isManualWaiting || state.isTransitioning) {
      icon = Icons.sync_rounded;
    } else if (state.isRunning) {
      icon = Icons.link_outlined;
    } else {
      icon = Icons.power_settings_new_outlined;
    }

    return Focus(
      focusNode: _indicatorFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          _handleTap(state);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          _indicatorFocusNode.requestFocus();
          _handleTap(state);
        },
        onLongPress: () => _handleLongPress(state),
        child: MouseRegion(
          cursor: SystemMouseCursors.basic,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              _indicatorFocusNode.requestFocus();
              _handleTap(state);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.12),
                ),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
              ),
              child: Center(
                child: (_isManualWaiting || state.isTransitioning)
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
                    : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    size: 18,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolToggle(ServerState state, bool isDark) {
    final isUdp = state.protocol == ServerProtocol.udp;
    final labelColor = isDark ? Colors.lightBlueAccent : Colors.blueAccent;
    final disabledColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.2);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.12);
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);

    return Container(
      height: 32,
      width: 52,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        onTap: state.isRunning
            ? null
            : () {
          state.setProtocol(
            isUdp ? ServerProtocol.tcp : ServerProtocol.udp,
          );
        },
        borderRadius: BorderRadius.circular(6),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              isUdp ? 'UDP' : 'TCP',
              key: ValueKey(isUdp),
              style: TextStyle(
                color: state.isRunning ? disabledColor : labelColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIpSelector(ServerState state, bool isDark, Color itemBg, Color borderColor) {
    return Expanded(
      flex: 3,
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: itemBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        child: InkWell(
          onTap: () => state.switchIp(),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  Icons.lan_outlined,
                  size: 14,
                  color: isDark ? Colors.lightBlueAccent : Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.hostIp,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.greenAccent : Colors.green.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortField(
      ServerState state,
      Color textColor,
      Color itemBg,
      Color borderColor,
      bool isDark,
      ) {
    final portColor = isDark
        ? const Color(0xFFFFE082)
        : const Color(0xFF8B6914);

    return Expanded(
      flex: 2,
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: _portController,
          focusNode: _portFocusNode,
          readOnly: state.isRunning,
          enabled: !state.isRunning,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: 13,
            color: state.isRunning
                ? portColor.withValues(alpha: 0.5)
                : portColor,
          ),
          decoration: InputDecoration(
            hintText: "Port",
            hintStyle: TextStyle(
              color: portColor.withValues(alpha: 0.4),
              fontSize: 13,
            ),
            filled: true,
            fillColor: itemBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: _isPortError ? Colors.redAccent : borderColor,
                width: _isPortError ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: _isPortError ? Colors.redAccent : Colors.blueAccent,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (val) {
            if (_isPortError) setState(() => _isPortError = false);
          },
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 24,
        child: VerticalDivider(
          width: 1,
          color: isDark
              ? Colors.white10
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}