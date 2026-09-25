import 'package:flutter/foundation.dart';

/// The transport whose health is being tracked.
enum ConnectionTransport { rest, webSocket, polling }

/// Current state of a connection transport.
enum ConnectionTransportStatus {
  idle,
  connecting,
  connected,
  disconnected,
  degraded,
  error,
}

/// Health information for one connection transport.
@immutable
class ConnectionTransportHealth {
  const ConnectionTransportHealth({
    required this.transport,
    this.status = ConnectionTransportStatus.idle,
    this.latency,
    this.lastSuccessfulUpdate,
    this.reconnectCount = 0,
  });

  final ConnectionTransport transport;
  final ConnectionTransportStatus status;
  final Duration? latency;
  final DateTime? lastSuccessfulUpdate;
  final int reconnectCount;

  bool get isAvailable =>
      status == ConnectionTransportStatus.connected ||
      status == ConnectionTransportStatus.degraded;

  String get statusMessage {
    final transportLabel = switch (transport) {
      ConnectionTransport.rest => 'REST',
      ConnectionTransport.webSocket => 'WebSocket',
      ConnectionTransport.polling => 'Polling',
    };
    return switch (status) {
      ConnectionTransportStatus.idle => '$transportLabel idle',
      ConnectionTransportStatus.connecting => 'Connecting to $transportLabel',
      ConnectionTransportStatus.connected => '$transportLabel connected',
      ConnectionTransportStatus.disconnected => '$transportLabel disconnected',
      ConnectionTransportStatus.degraded => '$transportLabel degraded',
      ConnectionTransportStatus.error => '$transportLabel error',
    };
  }

  ConnectionTransportHealth copyWith({
    ConnectionTransportStatus? status,
    Duration? latency,
    DateTime? lastSuccessfulUpdate,
    int? reconnectCount,
  }) {
    return ConnectionTransportHealth(
      transport: transport,
      status: status ?? this.status,
      latency: latency ?? this.latency,
      lastSuccessfulUpdate: lastSuccessfulUpdate ?? this.lastSuccessfulUpdate,
      reconnectCount: reconnectCount ?? this.reconnectCount,
    );
  }
}

/// A point-in-time view of REST, WebSocket, and polling health.
@immutable
class ConnectionHealth {
  const ConnectionHealth({
    required this.rest,
    required this.webSocket,
    required this.polling,
    required this.updatedAt,
  });

  final ConnectionTransportHealth rest;
  final ConnectionTransportHealth webSocket;
  final ConnectionTransportHealth polling;
  final DateTime updatedAt;

  List<ConnectionTransportHealth> get transports => [rest, webSocket, polling];

  /// The most recent successful update from any transport.
  DateTime? get lastSuccessfulUpdate {
    DateTime? latest;
    for (final health in transports) {
      final timestamp = health.lastSuccessfulUpdate;
      if (timestamp != null && (latest == null || timestamp.isAfter(latest))) {
        latest = timestamp;
      }
    }
    return latest;
  }

  int get reconnectCount =>
      transports.fold(0, (total, health) => total + health.reconnectCount);

  bool get isHealthy => transports.any((health) => health.isAvailable);

  /// A concise status suitable for a banner, card, or accessibility label.
  String get statusMessage {
    if (webSocket.status == ConnectionTransportStatus.connected) {
      return 'Live WebSocket connected';
    }
    if (polling.status == ConnectionTransportStatus.connected) {
      return 'Polling active';
    }
    if (rest.status == ConnectionTransportStatus.connected) {
      return 'REST connected';
    }
    if (transports.any(
      (health) => health.status == ConnectionTransportStatus.connecting,
    )) {
      return 'Connecting…';
    }
    if (isHealthy) return 'Connection degraded';
    if (transports.any(
      (health) => health.status == ConnectionTransportStatus.error,
    )) {
      return 'Connection error';
    }
    if (transports.every(
      (health) => health.status == ConnectionTransportStatus.idle,
    )) {
      return 'Not connected';
    }
    return 'Disconnected';
  }
}

/// Tracks connection health without owning any REST or WebSocket client.
///
/// Call the transport-specific methods from the existing API, WebSocket, and
/// polling integrations. Listeners are notified after every state change.
class ConnectionHealthService extends ChangeNotifier {
  ConnectionHealthService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _rest = const ConnectionTransportHealth(
        transport: ConnectionTransport.rest,
      ),
      _webSocket = const ConnectionTransportHealth(
        transport: ConnectionTransport.webSocket,
      ),
      _polling = const ConnectionTransportHealth(
        transport: ConnectionTransport.polling,
      );

  final DateTime Function() _clock;
  ConnectionTransportHealth _rest;
  ConnectionTransportHealth _webSocket;
  ConnectionTransportHealth _polling;

  ConnectionHealth get health => ConnectionHealth(
    rest: _rest,
    webSocket: _webSocket,
    polling: _polling,
    updatedAt: _clock(),
  );

  ConnectionTransportHealth operator [](ConnectionTransport transport) =>
      switch (transport) {
        ConnectionTransport.rest => _rest,
        ConnectionTransport.webSocket => _webSocket,
        ConnectionTransport.polling => _polling,
      };

  void markConnecting(ConnectionTransport transport) {
    _update(transport, status: ConnectionTransportStatus.connecting);
  }

  void markConnected(
    ConnectionTransport transport, {
    Duration? latency,
    DateTime? successfulUpdate,
  }) {
    _update(
      transport,
      status: ConnectionTransportStatus.connected,
      latency: latency,
      lastSuccessfulUpdate: successfulUpdate ?? _clock(),
    );
  }

  void markSuccess(
    ConnectionTransport transport, {
    required Duration latency,
    DateTime? updatedAt,
  }) {
    markConnected(transport, latency: latency, successfulUpdate: updatedAt);
  }

  void markDisconnected(ConnectionTransport transport) {
    _update(transport, status: ConnectionTransportStatus.disconnected);
  }

  void markError(
    ConnectionTransport transport, {
    Duration? latency,
    bool degraded = false,
  }) {
    _update(
      transport,
      status: degraded
          ? ConnectionTransportStatus.degraded
          : ConnectionTransportStatus.error,
      latency: latency,
    );
  }

  void recordReconnect(ConnectionTransport transport) {
    final current = this[transport];
    _update(
      transport,
      status: ConnectionTransportStatus.connecting,
      reconnectCount: current.reconnectCount + 1,
    );
  }

  void reset() {
    _rest = const ConnectionTransportHealth(
      transport: ConnectionTransport.rest,
    );
    _webSocket = const ConnectionTransportHealth(
      transport: ConnectionTransport.webSocket,
    );
    _polling = const ConnectionTransportHealth(
      transport: ConnectionTransport.polling,
    );
    notifyListeners();
  }

  void _update(
    ConnectionTransport transport, {
    ConnectionTransportStatus? status,
    Duration? latency,
    DateTime? lastSuccessfulUpdate,
    int? reconnectCount,
  }) {
    final current = this[transport];
    final next = current.copyWith(
      status: status,
      latency: latency,
      lastSuccessfulUpdate: lastSuccessfulUpdate,
      reconnectCount: reconnectCount,
    );
    switch (transport) {
      case ConnectionTransport.rest:
        _rest = next;
      case ConnectionTransport.webSocket:
        _webSocket = next;
      case ConnectionTransport.polling:
        _polling = next;
    }
    notifyListeners();
  }
}
