import 'dart:io';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:async';
import 'dart:typed_data';
import 'io.dart';
import 'package:rustnithm_server/src/rust/api.dart' show SensorData;

enum ServerProtocol { udp, tcp }

enum LedSource { preset, gameMemory }

class ServerState extends ChangeNotifier {
  final ServerIO _io;

  bool _isRunning = false;
  bool _isActivated = false;
  bool _isTransitioning = false;
  ServerProtocol _protocol = ServerProtocol.udp;
  LedSource _ledSource = LedSource.preset;
  int _gameLedPollFrequency = 50;
  double _gameLedGamma = AppConfig.defaultGameLedGamma;
  int _port = 37564;
  String _statusMessage = "IDLE";

  int _failCount = 0;
  bool _showTipsSignal = false;

  List<String> _allIps = ['127.0.0.1'];
  int _currentIpIndex = 0;

  List<int> airData = List.filled(6, 0);
  List<int> sliderData = List.filled(32, 0);
  int coin = 0;
  int service = 0;
  int test = 0;
  Uint8List code = Uint8List(10);
  List<int> gameSliderRgb = <int>[];
  List<int> gameTowerRgb = <int>[];
  List<int> gameBillboardRgb = <int>[];
  Timer? _gameLedTimer;
  bool _isReadingGameLed = false;

  bool get isRunning => _isRunning;
  bool get isActivated => _isActivated;
  bool get isTransitioning => _isTransitioning;
  ServerProtocol get protocol => _protocol;
  LedSource get ledSource => _ledSource;
  int get gameLedPollFrequency => _gameLedPollFrequency;
  double get gameLedGamma => _gameLedGamma;
  int get port => _port;
  String get statusMessage => _statusMessage;
  String get hostIp =>
      _allIps.isNotEmpty ? _allIps[_currentIpIndex] : '127.0.0.1';
  bool get showTipsSignal => _showTipsSignal;

  ServerState({AppConfig? initialConfig, ServerIO? io})
    : _io = io ?? ServerIO() {
    if (initialConfig != null) {
      _port = initialConfig.port;
      _protocol = initialConfig.connectMode == 'TCP'
          ? ServerProtocol.tcp
          : ServerProtocol.udp;
      _ledSource = initialConfig.ledSource == 'Game'
          ? LedSource.gameMemory
          : LedSource.preset;
      _gameLedPollFrequency = initialConfig.ledPollFrequency;
      _gameLedGamma = initialConfig.gameLedGamma;
    }
    _refreshIps();
  }

  void consumeTipsSignal() {
    _showTipsSignal = false;
  }

  Future<void> _refreshIps() async {
    final info = NetworkInfo();
    List<String> ips = ['127.0.0.1'];

    try {
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp != '127.0.0.1') {
        ips.add(wifiIp);
      }

      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !ips.contains(addr.address) &&
              addr.address != '127.0.0.1') {
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint("IP Refresh Error: $e");
    }

    _allIps = ips;
    if (_currentIpIndex >= _allIps.length) {
      _currentIpIndex = 0;
    }
    notifyListeners();
  }

  void switchIp() {
    _refreshIps();
    if (_allIps.length <= 1) return;
    _currentIpIndex = (_currentIpIndex + 1) % _allIps.length;
    _io.saveLastIp(_allIps[_currentIpIndex]);
    notifyListeners();
  }

  void setPort(int p) {
    _port = p;
    _io.saveConfigPatch({'port': p});
    notifyListeners();
  }

  void setProtocol(ServerProtocol p) {
    _protocol = p;
    _io.saveConfigPatch({
      'connectMode': p == ServerProtocol.tcp ? 'TCP' : 'UDP',
    });
    notifyListeners();
  }

  void setLedSource(LedSource source) {
    if (_isRunning || _isTransitioning || _ledSource == source) return;
    _ledSource = source;
    _io.saveConfigPatch({
      'ledSource': source == LedSource.gameMemory ? 'Game' : 'Present',
    });
    notifyListeners();
  }

  void setGameLedPollFrequency(int frequency) {
    final nextFrequency = frequency.clamp(1, 1000).toInt();
    if (_gameLedPollFrequency == nextFrequency) return;
    _gameLedPollFrequency = nextFrequency;
    _io.saveConfigPatch({'ledPollFrequency': nextFrequency});
    if (_isRunning && _ledSource == LedSource.gameMemory) {
      _startGameLedPolling();
    }
    notifyListeners();
  }

  void setGameLedGamma(double gamma) {
    final clamped = gamma.clamp(0.0, 1.0).toDouble();
    final nextGamma = (clamped * 100).round() / 100.0;
    if (_gameLedGamma == nextGamma) return;
    _gameLedGamma = nextGamma;
    _io.saveConfigPatch({'gameLedGamma': nextGamma});
    notifyListeners();
  }

  void _startGameLedPolling() {
    _gameLedTimer?.cancel();
    final intervalMicros =
        (Duration.microsecondsPerSecond / _gameLedPollFrequency)
            .round()
            .clamp(1, Duration.microsecondsPerSecond)
            .toInt();
    _gameLedTimer = Timer.periodic(Duration(microseconds: intervalMicros), (
      _,
    ) async {
      if (!_isRunning || _ledSource != LedSource.gameMemory) {
        return;
      }
      if (_isReadingGameLed) return;
      _isReadingGameLed = true;
      try {
        final data = await _io.readGameLedData();
        if (!_isRunning || _ledSource != LedSource.gameMemory) return;
        final slider = data.slider.length == 93
            ? data.slider.toList()
            : <int>[];
        final tower = data.tower.length == 18 ? data.tower.toList() : <int>[];
        final billboard = data.billboard.length == 360
            ? data.billboard.toList()
            : <int>[];
        if (_sameList(gameSliderRgb, slider) &&
            _sameList(gameTowerRgb, tower) &&
            _sameList(gameBillboardRgb, billboard)) {
          return;
        }
        gameSliderRgb = slider;
        gameTowerRgb = tower;
        gameBillboardRgb = billboard;
        notifyListeners();
      } finally {
        _isReadingGameLed = false;
      }
    });
  }

  void _stopGameLedPolling() {
    _gameLedTimer?.cancel();
    _gameLedTimer = null;
    gameSliderRgb = <int>[];
    gameTowerRgb = <int>[];
    gameBillboardRgb = <int>[];
  }

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> toggleServer() async {
    if (_isTransitioning) return;
    _isTransitioning = true;
    notifyListeners();

    final success = await _io.toggleServer(
      _port,
      _protocol == ServerProtocol.udp,
    );

    if (success) {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _statusMessage = "RUNNING";
        _io.saveLastIp(_allIps[_currentIpIndex]);
        _io.listenSensors(_onSensorUpdate);
        if (_ledSource == LedSource.gameMemory) _startGameLedPolling();
      } else {
        _statusMessage = "IDLE";
        _isActivated = false;
        _io.stopListening();
        _stopGameLedPolling();
        _resetData();
      }
    }

    _isTransitioning = false;
    notifyListeners();
  }

  void _onSensorUpdate(SensorData data) {
    bool changed = false;

    if (data.coin != coin || data.service != service || data.test != test) {
      coin = data.coin;
      service = data.service;
      test = data.test;
      changed = true;
      if (coin > 0 || service > 0 || test > 0) _isActivated = true;
    }

    for (int i = 0; i < 6; i++) {
      if (data.air[i] != airData[i]) {
        airData[i] = data.air[i];
        changed = true;
        if (airData[i] > 0) _isActivated = true;
      }
    }

    for (int i = 0; i < 32; i++) {
      if (data.slider[i] != sliderData[i]) {
        sliderData[i] = data.slider[i];
        changed = true;
        if (sliderData[i] > 0) _isActivated = true;
      }
    }

    final incomingCode = data.code;
    bool hasValue = false;
    for (var b in incomingCode) {
      if (b != 0) {
        hasValue = true;
        break;
      }
    }

    if (hasValue) {
      bool codeChanged = false;
      for (int i = 0; i < 10; i++) {
        if (code[i] != incomingCode[i]) {
          codeChanged = true;
          break;
        }
      }

      if (codeChanged) {
        code = Uint8List.fromList(incomingCode.take(10).toList());
        _isActivated = true;
        changed = true;
        _checkAndPersistIp();
      }
    } else if (code.any((e) => e != 0)) {
      code = Uint8List(10);
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  void _resetData() {
    airData = List.filled(6, 0);
    sliderData = List.filled(32, 0);
    coin = 0;
    service = 0;
    test = 0;
    code = Uint8List(10);
  }

  Future<void> _checkAndPersistIp() async {
    try {
      final lastIp = await _io.loadLastIp();
      if (lastIp == null) {
        debugPrint("Persisting connection IP");
      }
    } catch (e) {
      debugPrint("Persistence Check Error: $e");
    }
  }

  Future<bool> toggleSync() async {
    if (_isTransitioning || !_isRunning) return true;
    _isTransitioning = true;
    notifyListeners();

    final sent = await _io.toggleSync();
    if (!sent) {
      _isTransitioning = false;
      _showTipsSignal = true;
      notifyListeners();
      return false;
    }

    Timer(const Duration(milliseconds: 500), () {
      _isTransitioning = false;
      if (!_isActivated) {
        _failCount++;
        if (_failCount >= 5) {
          _failCount = 0;
          _showTipsSignal = true;
        }
      } else {
        _failCount = 0;
      }
      notifyListeners();
    });
    return true;
  }
}
