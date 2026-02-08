import 'dart:async';
import 'package:flutter/material.dart';
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
    _portController.dispose();
    _rollbackTimer?.cancel();
    super.dispose();
  }

  Color _getIndicatorColor(ServerState state) {
    if (_isManualWaiting || state.isTransitioning) return Colors.amberAccent;
    if (state.isRunning) return Colors.greenAccent;
    return Colors.redAccent;
  }

  void _handleTap(ServerState state) {
    if (state.isTransitioning) return;
    state.toggleServer();
  }

  void _handleLongPress(ServerState state) async {
    if (state.isTransitioning || !state.isRunning) return;

    setState(() {
      _isManualWaiting = true;
    });

    final bool sent = await state.toggleSync();

    if (!sent) {
      setState(() {
        _isManualWaiting = false;
      });
      return;
    }

    _rollbackTimer?.cancel();
    _rollbackTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isManualWaiting = false;
        });
      }
    });
  }

  void _showConnectionTips(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.tips_and_updates_rounded, color: Colors.amberAccent),
            SizedBox(width: 10),
            Text("Connection Tips", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("1. Connect Manual on both sides while first using"),
            SizedBox(height: 12),
            Text("2. Connect Manual on both sides when IP changed"),
            SizedBox(height: 12),
            Text("3. Nop."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("GOT IT", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ServerState>();
    final themeController = context.watch<ThemeController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.showTipsSignal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showConnectionTips(context);
        state.consumeTipsSignal();
      });
    }

    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isDark ? Colors.white24 : Colors.black38;
    final Color containerBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.05);
    final Color itemBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final Color borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.12);

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
            child: GestureDetector(
              onTap: () => _handleTap(state),
              onLongPress: () => _handleLongPress(state),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getIndicatorColor(state),
                    boxShadow: [
                      BoxShadow(
                        color: _getIndicatorColor(state).withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.black12,
                      width: 2.5,
                    ),
                  ),
                  child: Center(
                    child: (_isManualWaiting || state.isTransitioning)
                        ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Icon(
                      state.isRunning ? Icons.link : Icons.power_settings_new,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildDivider(isDark),
          _buildConfigItem(
            child: Material(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: state.isRunning
                    ? null
                    : () {
                  state.setProtocol(
                    state.protocol == ServerProtocol.udp
                        ? ServerProtocol.tcp
                        : ServerProtocol.udp,
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 32,
                  width: 60,
                  alignment: Alignment.center,
                  child: Text(
                    state.protocol == ServerProtocol.udp ? 'UDP' : 'TCP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                child: InkWell(
                  onTap: () => state.switchIp(),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.lan, size: 14, color: Colors.blueAccent),
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
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: _buildConfigItem(
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
                      color: state.isRunning ? textColor.withValues(alpha: 0.8) : textColor
                  ),
                  decoration: InputDecoration(
                    hintText: "Port",
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
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}