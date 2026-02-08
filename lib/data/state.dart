import 'dart:io';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:async';
import 'dart:typed_data';
import 'io.dart';
import 'package:rustnithm_server/src/rust/api.dart' show SensorData;

enum ServerProtocol { udp, tcp }

class ServerState extends ChangeNotifier {
  final ServerIO _io = ServerIO();

  bool _isRunning = false;
  bool _isActivated = false;
  bool _isTransitioning = false;
  ServerProtocol _protocol = ServerProtocol.udp;
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

  bool get isRunning => _isRunning;
  bool get isActivated => _isActivated;
  bool get isTransitioning => _isTransitioning;
  ServerProtocol get protocol => _protocol;
  int get port => _port;
  String get statusMessage => _statusMessage;
  String get hostIp => _allIps.isNotEmpty ? _allIps[_currentIpIndex] : '127.0.0.1';
  bool get showTipsSignal => _showTipsSignal;

  ServerState() {
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
    notifyListeners();
  }

  void setProtocol(ServerProtocol p) {
    _protocol = p;
    notifyListeners();
  }

  Future<void> toggleServer() async {
    if (_isTransitioning) return;
    _isTransitioning = true;
    notifyListeners();

    final success = await _io.toggleServer(_port, _protocol == ServerProtocol.udp);

    if (success) {
      _isRunning = !_isRunning;
      if (_isRunning) {
        _statusMessage = "RUNNING";
        _io.saveLastIp(_allIps[_currentIpIndex]);
        _io.listenSensors(_onSensorUpdate);
      } else {
        _statusMessage = "IDLE";
        _isActivated = false;
        _io.stopListening();
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

  void updateButton(String type, int index, bool isActive) {
    if (type == 'air') {
      airData[index] = isActive ? 1 : 0;
    } else if (type == 'slider') {
      sliderData[index] = isActive ? 1 : 0;
    } else if (type == 'coin') {
      coin = isActive ? 1 : 0;
    } else if (type == 'service') {
      service = isActive ? 1 : 0;
    } else if (type == 'test') {
      test = isActive ? 1 : 0;
    }
    notifyListeners();
  }
}