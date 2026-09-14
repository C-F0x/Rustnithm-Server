import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rustnithm_server/src/rust/api.dart' as rust_api;
import 'package:rustnithm_server/src/rust/api.dart' show SensorData;

class AppConfig {
  static const int defaultPort = 37564;
  static const int defaultTargetPort = 37564;
  static const String defaultTargetIp = '';
  static const String defaultLedSource = 'Present';
  static const String defaultThemeMode = 'Auto';
  static const String defaultConnectMode = 'UDP';
  static const int defaultLedPollFrequency = 50;
  static const int defaultLedSendFrequency = 100;
  static const double defaultGameLedGamma = 0.5;

  final int port;
  final String targetIp;
  final int targetPort;
  final String ledSource;
  final String themeMode;
  final String connectMode;
  final int ledPollFrequency;
  final int ledSendFrequency;
  final double gameLedGamma;

  const AppConfig({
    required this.port,
    required this.targetIp,
    required this.targetPort,
    required this.ledSource,
    required this.themeMode,
    required this.connectMode,
    required this.ledPollFrequency,
    required this.ledSendFrequency,
    required this.gameLedGamma,
  });
}

class ServerIO {
  StreamSubscription? _sensorSub;
  Future<void> _configWriteQueue = Future<void>.value();

  Future<Directory> _getConfigDirectory() async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw const FileSystemException('APPDATA is not available');
    }
    final directory = Directory('$appData\\C-F0x');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _getAppConfigFile() async {
    final directory = await _getConfigDirectory();
    return File('${directory.path}\\RustnithmServer.json');
  }

  Future<AppConfig> loadConfig() async {
    Map<String, dynamic> config = <String, dynamic>{};
    try {
      final file = await _getAppConfigFile();
      if (await file.exists()) {
        try {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is Map) {
            config = Map<String, dynamic>.from(decoded);
          }
        } catch (e) {
          debugPrint('IO Parse Config Error: $e');
        }
      }

      final appConfig = AppConfig(
        port: _readInt(config['port'], 1, 65535, AppConfig.defaultPort),
        targetIp: _readIp(config['targetIp'], AppConfig.defaultTargetIp),
        targetPort: _readInt(
          config['targetPort'],
          1,
          65535,
          AppConfig.defaultTargetPort,
        ),
        ledSource: _readString(config['ledSource'], const {
          'Present',
          'Game',
        }, AppConfig.defaultLedSource),
        themeMode: _readString(config['themeMode'], const {
          'Auto',
          'Light',
          'Dark',
        }, AppConfig.defaultThemeMode),
        connectMode: _readString(config['connectMode'], const {
          'UDP',
          'TCP',
        }, AppConfig.defaultConnectMode),
        ledPollFrequency: _readInt(
          config['ledPollFrequency'],
          1,
          1000,
          AppConfig.defaultLedPollFrequency,
        ),
        ledSendFrequency: _readInt(
          config['ledSendFrequency'],
          50,
          1000,
          AppConfig.defaultLedSendFrequency,
        ),
        gameLedGamma: _readDouble(
          config['gameLedGamma'],
          0.0,
          1.0,
          AppConfig.defaultGameLedGamma,
        ),
      );

      config['configVersion'] = 1;
      config['port'] = appConfig.port;
      config['targetIp'] = appConfig.targetIp;
      config['targetPort'] = appConfig.targetPort;
      config['ledSource'] = appConfig.ledSource;
      config['themeMode'] = appConfig.themeMode;
      config['connectMode'] = appConfig.connectMode;
      config['ledPollFrequency'] = appConfig.ledPollFrequency;
      config['ledSendFrequency'] = appConfig.ledSendFrequency;
      config['gameLedGamma'] = appConfig.gameLedGamma;
      config.remove('gameLedInvert');
      await _writeAppConfig(config);
      return appConfig;
    } catch (e) {
      debugPrint('IO Load Config Error: $e');
      return const AppConfig(
        port: AppConfig.defaultPort,
        targetIp: AppConfig.defaultTargetIp,
        targetPort: AppConfig.defaultTargetPort,
        ledSource: AppConfig.defaultLedSource,
        themeMode: AppConfig.defaultThemeMode,
        connectMode: AppConfig.defaultConnectMode,
        ledPollFrequency: AppConfig.defaultLedPollFrequency,
        ledSendFrequency: AppConfig.defaultLedSendFrequency,
        gameLedGamma: AppConfig.defaultGameLedGamma,
      );
    }
  }

  Future<void> saveConfigPatch(Map<String, dynamic> patch) {
    _configWriteQueue = _configWriteQueue.then((_) async {
      try {
        final file = await _getAppConfigFile();
        Map<String, dynamic> config = <String, dynamic>{};
        if (await file.exists()) {
          try {
            final decoded = jsonDecode(await file.readAsString());
            if (decoded is Map) config = Map<String, dynamic>.from(decoded);
          } catch (e) {
            debugPrint('IO Parse Config Error: $e');
          }
        }
        config.addAll(patch);
        config['configVersion'] = 1;
        config.putIfAbsent('port', () => AppConfig.defaultPort);
        config.putIfAbsent('targetIp', () => AppConfig.defaultTargetIp);
        config.putIfAbsent('targetPort', () => AppConfig.defaultTargetPort);
        config.putIfAbsent('ledSource', () => AppConfig.defaultLedSource);
        config.putIfAbsent('themeMode', () => AppConfig.defaultThemeMode);
        config.putIfAbsent('connectMode', () => AppConfig.defaultConnectMode);
        config.putIfAbsent(
          'ledPollFrequency',
          () => AppConfig.defaultLedPollFrequency,
        );
        config.putIfAbsent(
          'ledSendFrequency',
          () => AppConfig.defaultLedSendFrequency,
        );
        config.putIfAbsent('gameLedGamma', () => AppConfig.defaultGameLedGamma);
        config.remove('gameLedInvert');
        await _writeAppConfig(config);
      } catch (e) {
        debugPrint('IO Save Config Error: $e');
      }
    });
    return _configWriteQueue;
  }

  Future<void> _writeAppConfig(Map<String, dynamic> config) async {
    final file = await _getAppConfigFile();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  static int _readInt(Object? value, int min, int max, int fallback) {
    if (value is! int || value < min || value > max) return fallback;
    return value;
  }

  static double _readDouble(
    Object? value,
    double min,
    double max,
    double fallback,
  ) {
    final parsed = value is num ? value.toDouble() : double.nan;
    return parsed.isFinite && parsed >= min && parsed <= max
        ? parsed
        : fallback;
  }

  static String _readString(
    Object? value,
    Set<String> allowed,
    String fallback,
  ) {
    return value is String && allowed.contains(value) ? value : fallback;
  }

  static String _readIp(Object? value, String fallback) {
    if (value == null) return fallback;
    if (value is! String || value.isEmpty) return value == '' ? '' : fallback;
    final parsed = InternetAddress.tryParse(value);
    return parsed?.type == InternetAddressType.IPv4 ? value : fallback;
  }

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

  Future<bool> toggleServer(
    int port,
    bool isUdp, {
    bool gameLed = false,
    int ledFrequency = AppConfig.defaultLedSendFrequency,
    String? targetIp,
    int? targetPort,
  }) async {
    try {
      if (targetIp == null) {
        final lastIp = await loadLastIp();
        if (lastIp != null) {
          await rust_api.initLastIp(ip: lastIp);
        }
      } else if (targetPort != null) {
        await rust_api.initLastIp(
          ip: targetIp.trim().isEmpty
              ? ''
              : '${targetIp.trim()}:$targetPort',
        );
      }
      await rust_api.setLedSource(game: gameLed);
      await rust_api.setLedSendFrequency(frequency: ledFrequency);
      return await rust_api.toggleServer(port: port, isUdp: isUdp);
    } catch (e) {
      debugPrint("IO Toggle Server Error: $e");
      return false;
    }
  }

  Future<bool> toggleSync({String? targetIp, int? targetPort}) async {
    try {
      if (targetIp != null && targetPort != null && targetIp.trim().isNotEmpty) {
        await rust_api.initLastIp(ip: '${targetIp.trim()}:$targetPort');
      }
      return await rust_api.toggleSync();
    } catch (e) {
      debugPrint("IO Toggle Sync Error: $e");
      return false;
    }
  }

  Future<rust_api.GameLedData> readGameLedData() async {
    try {
      return await rust_api.readGameLedData();
    } catch (e) {
      debugPrint("IO Read Game LED Error: $e");
      return rust_api.GameLedData(
        slider: Uint8List(0),
        tower: Uint8List(0),
        billboard: Uint8List(0),
      );
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
}
