import 'package:flutter/material.dart';

/// Lifecycle of the CCTV stream, derived from the player flags.
enum CctvStatus {
  /// Nothing is loading; the user must press play.
  standby,

  /// A request is in flight.
  connecting,

  /// Frames are being displayed.
  live,

  /// The last attempt failed.
  offline,
}

/// Derives the stream status from the player flags.
///
/// [failed] wins over everything else, because a failed reload keeps the
/// player mounted behind the error overlay.
CctvStatus cctvStatusOf({
  required bool playing,
  required bool loading,
  required bool failed,
}) {
  if (failed) return CctvStatus.offline;
  if (!playing) return CctvStatus.standby;
  return loading ? CctvStatus.connecting : CctvStatus.live;
}

extension CctvStatusDisplay on CctvStatus {
  /// Short uppercase badge text.
  String get label => switch (this) {
    CctvStatus.standby => 'STANDBY',
    CctvStatus.connecting => 'CONNECTING',
    CctvStatus.live => 'LIVE',
    CctvStatus.offline => 'OFFLINE',
  };

  /// Badge and dot tint.
  Color get color => switch (this) {
    CctvStatus.live => const Color(0xFF58D68D),
    CctvStatus.offline => const Color(0xFFFF765E),
    CctvStatus.standby || CctvStatus.connecting => const Color(0xFFFFC857),
  };

  /// Whether the video surface should be mounted behind the overlays.
  bool get showsVideo => this != CctvStatus.standby;
}
