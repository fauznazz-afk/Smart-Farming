import 'package:flutter/material.dart';

import '../../dashboard/utils/color_helpers.dart';

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

  /// The status hue. Used for the 7dp dot.
  ///
  /// The dot does not need text contrast — it sits beside a word that does, and
  /// WCAG 1.4.11 exempts it as part of a graphic that is not the sole carrier of
  /// the information. It keeps its distinct hue for exactly that reason.
  Color get color => switch (this) {
    CctvStatus.live => statusOk,
    CctvStatus.offline => statusBadFill,
    CctvStatus.standby || CctvStatus.connecting => statusWarn,
  };

  /// The status colour to draw the *label* in.
  ///
  /// This is separate from [color] because the pill used [color] for both, and
  /// as 9dp text those values measured 1.66:1 (live) and 1.39:1 (standby) on
  /// the light page — far below AA and, at that size, close to invisible. They
  /// are fills tuned to be bright, not colours tuned to be read.
  ///
  /// So the text moves to the measured family the rest of the app asserts
  /// against (`statusOk` / `statusWarn` / `statusBad`, pinned by
  /// `test/color_helpers_test.dart`) and the dot keeps its own hue, which is the
  /// cheapest possible fix and the one that preserves the dot/text pairing.
  ///
  /// Note the `0xFFFFC857` above is byte-identical to the energy report's PV
  /// series amber. A CCTV standby dot and a PV bar are already the same colour
  /// on screen. That is reported rather than fixed here: inventing a fourth hue
  /// to separate them would be the automatic hue variation AGENTS.md forbids,
  /// and a deliberate alternative has to be a choice the lead makes.
  Color get textColor => switch (this) {
    CctvStatus.live => statusOk,
    CctvStatus.offline => statusBad,
    CctvStatus.standby || CctvStatus.connecting => statusWarn,
  };

  /// Whether the video surface should be mounted behind the overlays.
  bool get showsVideo => this != CctvStatus.standby;
}
