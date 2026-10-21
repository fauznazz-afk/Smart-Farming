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
  /// **Offline now takes the measured ink, not a second red.** It used to take
  /// [statusBadFill], whose own doc names "a dot" as one of its purposes, so
  /// this looks like a step backwards. It is not, and the reason is stronger
  /// now than it was: the ramp carries **one** red. `statusBad` and
  /// `statusBadFill` both resolve to `AppPalette.statusBad` (`#D01E1E`), so the
  /// pill would be drawing two reds that are the same red — the second would be
  /// a duplicate rather than a distinction, and on a 7dp dot beside a word it
  /// reads as a rendering fault. Dropping it costs nothing: [statusBad]
  /// measures **5.40:1** on `#FFFFFF` and **4.98:1** on the light ramp's
  /// `#F1F6FD` card.
  ///
  /// The two getters stay separate rather than collapsing into one, because
  /// they describe different jobs — a dot is a shape, a label is text — and the
  /// day a dot needs to differ from its label, a live-only dot that must not be
  /// read aloud, say, is the day this split is the thing that makes it
  /// expressible.
  ///
  /// **The page twins, because this is the one place a status hue is drawn
  /// straight onto the page gradient** with no card behind it. The card values
  /// are dark — cards are near-white in both ramps — so drawing them here put a
  /// dark green dot on a dark blue page. Measured on the dark page `#1B3260`:
  /// 6.53 / 7.52 / 6.62:1.
  Color get color => switch (this) {
    CctvStatus.live => statusOkOnPage,
    CctvStatus.offline => statusBadOnPage,
    CctvStatus.standby || CctvStatus.connecting => statusWarnOnPage,
  };

  /// The status colour to draw the *label* in.
  ///
  /// This is separate from [color] because the pill used [color] for both, and
  /// as 9dp text the then-current values measured 1.66:1 (live) and 1.39:1
  /// (standby) on the light page — far below AA and, at that size, close to
  /// invisible. They were fills tuned to be bright, not colours tuned to be
  /// read.
  ///
  /// So the text takes the **page twins** — `statusOkOnPage` / `statusWarnOnPage`
  /// / `statusBadOnPage` — which are the values the ramp pins for text drawn
  /// straight on the page. On the light page they measure 6.25 / 5.21 / 5.27:1
  /// and on the dark page 6.53 / 7.52 / 6.62:1, and on the badge's own 12% wash
  /// they read 4.55 / 5.24 / 4.63:1 at the dark ramp's worst stop — AA
  /// everywhere, which is what 10dp label text needs.
  ///
  /// The dot and the label resolve to the same value today, because the ramp
  /// carries one page twin per severity. The split is kept because the two jobs
  /// are different: a dot is a shape, a label is text.
  Color get textColor => switch (this) {
    CctvStatus.live => statusOkOnPage,
    CctvStatus.offline => statusBadOnPage,
    CctvStatus.standby || CctvStatus.connecting => statusWarnOnPage,
  };

  /// Whether the video surface should be mounted behind the overlays.
  bool get showsVideo => this != CctvStatus.standby;
}
