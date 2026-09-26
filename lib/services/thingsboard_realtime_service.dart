import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/telemetry_model.dart';
import 'thingsboard_api.dart';

typedef RealtimeTelemetryCallback = void Function(
  String deviceId,
  Map<String, TelemetryPoint> values,
);

class ThingsBoardRealtimeService {
  ThingsBoardRealtimeService({
    required this.api,
    required this.onTelemetry,
    this.onConnectionChanged,
  });

  final ThingsBoardApi api;
  final RealtimeTelemetryCallback onTelemetry;
  final ValueChanged<bool>? onConnectionChanged;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _running = false;
  bool _connected = false;
  int _reconnectAttempt = 0;
  int _nextCommandId = 1;
  final Map<int, String> _subscriptionDevices = {};

  bool get isConnected => _connected;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    await _connect();
  }

  Future<void> stop() async {
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _setConnected(false);
  }

  Future<void> _connect() async {
    final token = api.accessToken;
    if (!_running || token == null || token.isEmpty) return;
    try {
      final channel = WebSocketChannel.connect(api.telemetryWebSocketUri);
      _channel = channel;
      await channel.ready;
      if (!_running || !identical(_channel, channel)) {
        await channel.sink.close();
        return;
      }
      _reconnectAttempt = 0;
      _setConnected(true);
      _sendSubscriptions(channel);
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (_, _) => _handleDisconnect(channel),
        onDone: () => _handleDisconnect(channel),
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect(_channel);
    }
  }

  void _sendSubscriptions(WebSocketChannel channel) {
    _subscriptionDevices.clear();
    final commands = <Map<String, dynamic>>[
      // Key list diambil dari ThingsBoardApi, bukan ditulis ulang di sini, supaya
      // polling REST dan langganan WebSocket tidak mungkin asks for different
      // sets. Lihat komentar di ThingsBoardApi.batteryKeys.
      _subscriptionCommand(ThingsBoardApi.deviceBattery, ThingsBoardApi.batteryKeys),
      _subscriptionCommand(ThingsBoardApi.devicePzem, ThingsBoardApi.pzemKeys),
      _subscriptionCommand(ThingsBoardApi.deviceSensor, ThingsBoardApi.sensorKeys),
    ];
    channel.sink.add(
      jsonEncode({
        'tsSubCmds': commands,
        'historyCmds': const [],
        'attrSubCmds': const [],
      }),
    );
  }

  Map<String, dynamic> _subscriptionCommand(
    String deviceId,
    List<String> keys,
  ) {
    final commandId = _nextCommandId++;
    _subscriptionDevices[commandId] = deviceId;
    return {
      'entityType': 'DEVICE',
      'entityId': deviceId,
      'scope': 'LATEST_TELEMETRY',
      'cmdId': commandId,
      'keys': keys.join(','),
    };
  }

  void _handleMessage(dynamic rawMessage) {
    if (rawMessage is! String) return;
    try {
      final message = jsonDecode(rawMessage);
      if (message is! Map<String, dynamic>) return;
      final data = message['data'];
      if (data is! Map) return;
      final subscriptionId = message['subscriptionId'];
      final deviceId = _deviceForSubscription(subscriptionId);
      if (deviceId == null) return;
      final values = <String, TelemetryPoint>{};
      data.forEach((key, rawPoints) {
        if (rawPoints is! List || rawPoints.isEmpty) return;
        final point = rawPoints.first;
        dynamic ts;
        dynamic rawValue;
        if (point is Map) {
          ts = point['ts'];
          rawValue = point['value'];
        } else if (point is List && point.length >= 2) {
          ts = point[0];
          rawValue = point[1];
        } else {
          return;
        }
        final value = double.tryParse(rawValue.toString());
        if (ts is num && value != null) {
          values[key.toString()] = TelemetryPoint(
            timestamp: DateTime.fromMillisecondsSinceEpoch(ts.toInt()),
            value: value,
          );
        }
      });
      if (values.isNotEmpty) onTelemetry(deviceId, values);
    } catch (_) {
      // Ignore malformed frames and keep the live stream alive.
    }
  }

  String? _deviceForSubscription(Object? subscriptionId) {
    final id = subscriptionId is num ? subscriptionId.toInt() : null;
    return id == null ? null : _subscriptionDevices[id];
  }

  void _handleDisconnect(WebSocketChannel? channel) {
    if (channel != null && !identical(_channel, channel)) return;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _setConnected(false);
    if (!_running || _reconnectTimer != null) return;
    final seconds = 1 << (_reconnectAttempt.clamp(0, 3));
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  void _setConnected(bool value) {
    if (_connected == value) return;
    _connected = value;
    onConnectionChanged?.call(value);
  }
}
