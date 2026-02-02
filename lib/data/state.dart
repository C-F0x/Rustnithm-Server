import 'dart:io';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'io.dart';

enum ServerProtocol { udp, tcp }

class ServerState extends ChangeNotifier {
  final ServerIO _io = ServerIO();

  bool _isRunning = false;
  bool _isTransitioning = false;
  ServerProtocol _protocol = ServerProtocol.udp;
  int _port = 37564;
  String _statusMessage = "IDLE";

  List<String> _allIps = ['127.0.0.1'];
  int _currentIpIndex = 0;

  List<int> airData = List.filled(6, 0);
  List<int> sliderData = List.filled(32, 0);
  int coin = 0;
  int service = 0;
  int test = 0;
  String code = "";

  bool get isRunning => _isRunning;
  bool get isTransitioning => _isTransitioning;
  ServerProtocol get protocol => _protocol;
  int get port => _port;
  String get statusMessage => _statusMessage;
  String get hostIp => _allIps.isNotEmpty ? _allIps[_currentIpIndex] : '127.0.0.1';

  ServerState() {
    refreshIp();
  }

  Future<void> refreshIp() async {
    try {
      final info = NetworkInfo();
      String? wifiIp = await info.getWifiIP();
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );
      _allIps = interfaces.expand((i) => i.addresses.map((a) => a.address)).toList();
      if (wifiIp != null && _allIps.contains(wifiIp)) {
        _allIps.remove(wifiIp);
        _allIps.insert(0, wifiIp);
      }
      _currentIpIndex = 0;
      notifyListeners();
    } catch (e) {
      debugPrint("Refresh IP Error: $e");
    }
  }

  Future<void> toggleServer() async {
    if (_isTransitioning) return;
    _isTransitioning = true;
    notifyListeners();

    if (_isRunning) {
      _statusMessage = "SUSPENDING...";
      notifyListeners();
      await _io.suspend();
      _isRunning = false;
      _statusMessage = "SUSPENDED";
      _io.stopListening();
    } else {
      _statusMessage = "ACTIVATING...";
      notifyListeners();
      final result = await _io.activate(_port, _protocol == ServerProtocol.udp);
      if (result.toUpperCase().contains("SUCCESS")) {
        _isRunning = true;
        _statusMessage = "ACTIVE";
        _io.listenSensors((data) {
          airData = data.air;
          sliderData = data.slider;
          coin = data.coin;
          service = data.service;
          test = data.test;

          bool hasValidCard = data.code.any((digit) => digit != 0);
          if (hasValidCard) {
            code = data.code.map((b) => b.toString()).join('');
          } else {
            code = "";
          }

          if (_isRunning) {
            _io.sync(airData, sliderData, coin, service, test, code);
          }
          notifyListeners();
        });
      } else {
        _statusMessage = "FAILED: $result";
      }
    }
    _isTransitioning = false;
    notifyListeners();
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
    } else if (type == 'code') {
      code = isActive ? "12345678901234567890" : "";
    }

    if (_isRunning) {
      _io.sync(airData, sliderData, coin, service, test, code);
    }
    notifyListeners();
  }

  void nextIp() {
    if (_allIps.length > 1) {
      _currentIpIndex = (_currentIpIndex + 1) % _allIps.length;
      notifyListeners();
    }
  }

  void configServer(ServerProtocol p, int port) {
    _protocol = p;
    _port = port;
    notifyListeners();
  }

  @override
  void dispose() {
    _io.suspend();
    super.dispose();
  }
}