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
  /// the information. It keeps its status hue for exactly that reason.
  ///
  /// **Offline now takes the measured ink, not the fill.** It used to take
  /// [statusBadFill], whose own doc names "a dot" as one of its purposes, so
  /// this looks like a step backwards. It is not, for one measured reason:
  /// `statusBad` (`#FF5C5C`) and `statusBadFill` (`#FF6B6B`) are **0.4° apart**
  /// — `color_helpers.dart` records the number — so the pill was drawing two
  /// reds that are the same red. On a 7dp dot beside a word, the second red
  /// reads as a rendering fault rather than as a distinction, and dropping it
  /// costs nothing: [statusBad] clears AA on every caption surface, which the
  /// fill variant does not.
  ///
  /// The two getters stay separate rather than collapsing into one, because
  /// they describe different jobs and the day a dot needs to differ from its
  /// label — a live-only dot that must not be read aloud, say — is the day this
  /// split is the thing that makes it expressible.
  Color get color => switch (this) {
    CctvStatus.live => statusOk,
    CctvStatus.offline => statusBad,
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
