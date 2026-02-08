import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rustnithm_server/src/rust/api.dart' as rust_api;
import 'package:rustnithm_server/src/rust/api.dart' show SensorData;

class ServerIO {
  StreamSubscription? _sensorSub;

  Future<File> _getConfigFile() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final f0xDir = Directory("${appSupportDir.path}\\F0xHub");
    if (!await f0xDir.exists()) {
      await f0xDir.create(recursive: true);
    }
    return File("${f0xDir.path}\\Server.json");
  }

  Future<void> saveLastIp(String ip) async {
    try {
      final file = await _getConfigFile();
      Map<String, dynamic> config = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        config = jsonDecode(content);
      }
      config['last_connect_ip'] = ip;
      await file.writeAsString(jsonEncode(config));
    } catch (e) {
      debugPrint("IO Save Config Error: $e");
    }
  }

  Future<String?> loadLastIp() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final config = jsonDecode(content);
        return config['last_connect_ip'] as String?;
      }
    } catch (e) {
      debugPrint("IO Load Config Error: $e");
    }
    return null;
  }

  Future<bool> toggleServer(int port, bool isUdp) async {
    try {
      final lastIp = await loadLastIp();
      if (lastIp != null) {
        await rust_api.initLastIp(ip: lastIp);
      }
      return await rust_api.toggleServer(port: port, isUdp: isUdp);
    } catch (e) {
      debugPrint("IO Toggle Server Error: $e");
      return false;
    }
  }

  Future<bool> toggleSync() async {
    try {
      return await rust_api.toggleSync();
    } catch (e) {
      debugPrint("IO Toggle Sync Error: $e");
      return false;
    }
  }

  void listenSensors(Function(SensorData) onData) {
    _sensorSub?.cancel();
    _sensorSub = rust_api.createSensorStream().listen((data) {
      onData(data);
    });
  }

  void stopListening() {
    _sensorSub?.cancel();
    _sensorSub = null;
  }

  void sync(List<int> air, List<int> slider, int coin, int service, int test) {
    try {
      rust_api.syncToShmem(
        air: Uint8List.fromList(air),
        slider: Uint8List.fromList(slider),
        coin: coin,
        service: service,
        test: test,
      );
    } catch (e) {
      debugPrint("IO Sync Error: $e");
    }
  }
}