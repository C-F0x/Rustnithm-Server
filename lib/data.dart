import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:rustnithm_server/src/rust/api.dart';

enum ServerProtocol { udp, tcp }

class ServerController extends ChangeNotifier {
  bool _isRunning = false;
  ServerProtocol _protocol = ServerProtocol.udp;
  int _port = 37564;
  String _statusMessage = "IDLE";

  List<String> _allIps = ['127.0.0.1'];
  int _currentIpIndex = 0;

  StreamSubscription? _sensorSub;
  StreamSubscription? _logSub;
  final List<LogEntry> _logs = [];

  OverlayEntry? _debugOverlayEntry;
  Offset _debugPos = const Offset(100, 100);
  bool _isLogMinimized = false;

  List<int> _airData = List.filled(6, 0);
  List<int> _sliderData = List.filled(32, 0);
  int _coin = 0;
  int _service = 0;
  int _test = 0;

  bool get isRunning => _isRunning;
  ServerProtocol get protocol => _protocol;
  int get port => _port;
  String get statusMessage => _statusMessage;
  String get hostIp =>
      _allIps.isNotEmpty ? _allIps[_currentIpIndex] : '127.0.0.1';
  List<String> get allIps => _allIps;
  List<LogEntry> get logs => _logs;

  List<int> get airData => _airData;
  List<int> get sliderData => _sliderData;
  int get coin => _coin;
  int get service => _service;
  int get test => _test;

  ServerController() {
    refreshIp();
  }

  void showDebugPanel(BuildContext context) {
    if (_debugOverlayEntry != null) {
      hideDebugPanel();
      return;
    }

    _debugOverlayEntry = OverlayEntry(
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setOverlayState) {
            return Positioned(
              left: _debugPos.dx,
              top: _debugPos.dy,
              child: Material(
                elevation: 16,
                color: Colors.transparent,
                child: Container(
                  width: 500,
                  height: _isLogMinimized ? 45 : 400,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        GestureDetector(
                          onPanUpdate: (details) {
                            setOverlayState(() {
                              _debugPos += details.delta;
                            });
                          },
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            color: Colors.white.withValues(alpha: 0.05),
                            child: Row(
                              children: [
                                const Icon(Icons.bug_report_rounded,
                                    size: 18, color: Colors.cyanAccent),
                                const SizedBox(width: 10),
                                const Text(
                                  "DEBUG CONSOLE",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                      _isLogMinimized
                                          ? Icons.unfold_more
                                          : Icons.unfold_less,
                                      size: 18,
                                      color: Colors.white38),
                                  onPressed: () => setOverlayState(
                                      () => _isLogMinimized = !_isLogMinimized),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep_outlined,
                                      size: 18, color: Colors.white38),
                                  onPressed: () {
                                    notifyListeners();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18, color: Colors.white70),
                                  onPressed: hideDebugPanel,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!_isLogMinimized)
                          Expanded(
                            child: ListenableBuilder(
                              listenable: this,
                              builder: (context, _) {
                                return SelectionArea(
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _logs.length,
                                    itemBuilder: (context, index) {
                                      final log = _logs[index];
                                      Color levelColor = Colors.white24;
                                      if (log.level == "ERROR") {
                                        levelColor = Colors.redAccent;
                                      }
                                      if (log.level == "SUCCESS") {
                                        levelColor = Colors.greenAccent;
                                      }
                                      if (log.level == "INFO") {
                                        levelColor = Colors.blueAccent;
                                      }

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: "[${log.level}] ",
                                                style: TextStyle(
                                                  color: levelColor,
                                                  fontFamily: 'monospace',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(
                                                text: log.message,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'monospace',
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_debugOverlayEntry!);
  }

  void hideDebugPanel() {
    _debugOverlayEntry?.remove();
    _debugOverlayEntry = null;
  }

  void triggerButton(String type, int index, bool isActive) {
    int val = isActive ? 1 : 0;
    if (type == 'air') _airData[index] = val;
    if (type == 'slider') _sliderData[index] = val;
    if (type == 'coin') _coin = val;
    if (type == 'service') _service = val;
    if (type == 'test') _test = val;
    updateSensors(_airData, _sliderData, _coin, _service, _test);
  }

  Future<void> refreshIp() async {
    try {
      final info = NetworkInfo();
      String? wifiIp = await info.getWifiIP();

      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );

      _allIps =
          interfaces.expand((i) => i.addresses.map((a) => a.address)).toList();

      if (wifiIp != null && _allIps.contains(wifiIp)) {
        _allIps.remove(wifiIp);
        _allIps.insert(0, wifiIp);
      }

      _currentIpIndex = 0;
      notifyListeners();
      _logs.insert(
          0,
          const LogEntry(
              time: "", level: "INFO", message: "IP list refreshed."));
    } catch (e) {
      debugPrint("Refresh IP Error: $e");
    }
  }

  void nextIp() {
    if (_allIps.length <= 1) return;
    _currentIpIndex = (_currentIpIndex + 1) % _allIps.length;
    notifyListeners();
  }

  void setProtocol(ServerProtocol p) {
    if (_isRunning) return;
    _protocol = p;
    notifyListeners();
  }

  void setPort(int p) {
    if (_port == p) return;
    _port = p;
    notifyListeners();
  }

  Future<void> toggleServer() async {
    if (_isTransitioning) return;

    _isTransitioning = true;
    notifyListeners();

    try {
      if (_isRunning) {
        await _stopRustServer();
      } else {
        await _startRustServer();
      }
    } catch (e) {
      debugPrint("Toggle Error: $e");
    } finally {
      _isTransitioning = false;
      notifyListeners();
    }
  }

  Future<void> _startRustServer() async {
    try {
      _statusMessage = "STARTING...";
      notifyListeners();

      await _logSub?.cancel();
      _logSub = createLogStream().listen((log) {
        _logs.insert(0, log);
        if (_logs.length > 100) _logs.removeLast();
        notifyListeners();
      }, onError: (e) => debugPrint("Log Stream Error: $e"));

      final result = await
          startServer(
            port: _port,
            isUdp: _protocol == ServerProtocol.udp,
          )
          .timeout(const Duration(seconds: 5),
              onTimeout: () => "ERROR: TIMEOUT");

      if (result.toUpperCase().contains("SUCCESS")) {
        _isRunning = true;
        _statusMessage = "RUNNING";

        await _sensorSub?.cancel();
        _sensorSub = createSensorStream().listen((data) {
          updateSensors(
              data.air, data.slider, data.coin, data.service, data.test);
        });
      } else {
        _isRunning = false;
        _statusMessage = "FAILED: $result";
        _logs.insert(
            0,
            LogEntry(
                time: "",
                level: "ERROR",
                message: "Server Start Failed: $result"));
      }
    } catch (e) {
      _statusMessage = "CRASH: $e";
      _isRunning = false;
      _logs.insert(0, LogEntry(time: "", level: "ERROR", message: "Crash: $e"));
    } finally {
      notifyListeners();
    }
  }

  bool _isTransitioning = false;

  Future<void> _stopRustServer() async {
    try {
      _statusMessage = "STOPPING...";
      notifyListeners();

      await _sensorSub?.cancel();
      _sensorSub = null;

      await stopServer().timeout(const Duration(seconds: 2));
      if (_protocol == ServerProtocol.udp) {
        final String psCommand =
            '\$client = New-Object System.Net.Sockets.UdpClient; '
            '\$content = New-Object Byte[] 48; '
            '\$client.Send(\$content, 48, "127.0.0.1", $_port); '
            '\$client.Close();';

        await Process.run('powershell', ['-Command', psCommand]);
        _logs.insert(
            0,
            const LogEntry(
                time: "",
                level: "INFO",
                message:
                    "External Process: Sent UDP tombstone via PowerShell."));
      } else {
        final String psCommand =
            '\$client = New-Object System.Net.Sockets.TcpClient; '
            '\$client.Connect("127.0.0.1", $_port); '
            '\$client.Close();';

        await Process.run('powershell', ['-Command', psCommand]);
      }
    } catch (e) {
      debugPrint("Stop Server Error: $e");
    } finally {
      _isRunning = false;
      _statusMessage = "STOPPED";

      Future.delayed(const Duration(seconds: 1), () {
        _logSub?.cancel();
        _logSub = null;
        notifyListeners();
      });

      notifyListeners();
    }
  }

  void updateSensors(
      List<int> newAir, List<int> newSlider, int coin, int service, int test) {
    _airData = newAir;
    _sliderData = newSlider;
    _coin = coin;
    _service = service;
    _test = test;

    if (_isRunning) {
      try {
        syncToShmem(
          air: Uint8List.fromList(newAir),
          slider: Uint8List.fromList(newSlider),
          coin: coin,
          service: service,
          test: test,
        );
      } catch (e) {
        debugPrint("Sync Shmem Error: $e");
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _logSub?.cancel();
    _debugOverlayEntry?.remove();
    super.dispose();
  }
}
