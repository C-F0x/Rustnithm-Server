import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rustnithm_server/src/rust/api.dart';

class ServerIO {
  StreamSubscription? _sensorSub;

  Future<String> start(int port, bool isUdp) async {
    try {
      return await startServer(port: port, isUdp: isUdp)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      return "ERROR: $e";
    }
  }

  Future<void> stop(int port, bool isUdp) async {
    try {
      await _sensorSub?.cancel();
      _sensorSub = null;

      await stopServer().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint("IO Stop Error: $e");
    }
  }

  void listenSensors(Function(SensorData) onData) {
    _sensorSub?.cancel();
    _sensorSub = createSensorStream().listen(onData);
  }

  void sync(List<int> air, List<int> slider, int coin, int service, int test, String code) {
    try {
      syncToShmem(
        air: Uint8List.fromList(air),
        slider: Uint8List.fromList(slider),
        coin: coin,
        service: service,
        test: test,
        code: code,
      );
    } catch (e) {
      debugPrint("IO Sync Error: $e");
    }
  }
}