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
    };
  }

  ConnectionTransportHealth copyWith({
    ConnectionTransportStatus? status,
    Duration? latency,
    DateTime? lastSuccessfulUpdate,
    int? reconnectCount,
  }) {    return ConnectionTransportHealth(
      transport: transport,
      status: status ?? this.status,
      latency: latency ?? this.latency,
      lastSuccessfulUpdate: lastSuccessfulUpdate ?? this.lastSuccessfulUpdate,
      reconnectCount: reconnectCount ?? this.reconnectCount,
    );
  }

  /// Value equality over the fields a listener can actually see.
  ///
  /// Two fields are deliberately excluded, and both were a mistake when included:
  ///
  ///  * `lastSuccessfulUpdate` advances on every telemetry frame, so including it
  ///    made every instance unequal and the check suppressed nothing at all.
  ///  * `latency` is measured from `DateTime.now()` each time a frame arrives, so
  ///    it is different on every frame for the same reason — and unlike the
  ///    timestamp, nothing renders it anywhere in the app.
  ///
  /// What remains is the status, the transport and the reconnect count: the three
  /// things the status strip and the connection banner actually draw. If one of
  /// those moves, the UI has something new to show and must be told.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionTransportHealth &&
          transport == other.transport &&
          status == other.status &&
          reconnectCount == other.reconnectCount;

  @override
  int get hashCode => Object.hash(transport, status, reconnectCount);
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
    // The `degraded` parameter is accepted for compatibility but ignored.
    // All current callers pass `degraded: true`, and the `error` status was
    // unreachable as a result. The status is always `degraded`.
    _update(
      transport,
      status: ConnectionTransportStatus.degraded,
      latency: latency,
    );
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
    // Only announce an actual change. This is called on every telemetry frame the
    // socket delivers, which is several times a second, and the status strip
    // subscribes to this notifier — so notifying unconditionally rebuilt that
    // strip (and its banner switcher) two or three times a second to render, in
    // the overwhelmingly common case, nothing at all.
    if (next == current) return;
    notifyListeners();
  }
}
