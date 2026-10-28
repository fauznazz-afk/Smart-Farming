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
  /// the information.
  ///
  /// **Offline takes the measured ink, not a second red.** `statusBad` and
  /// `statusBadFill` both resolve to `AppPalette.statusBad`, so the pill would
  /// be drawing two reds that are the same red — the second would be a duplicate
  /// rather than a distinction.
  ///
  /// The two getters stay separate rather than collapsing into one, because
  /// they describe different jobs — a dot is a shape, a label is text — and the
  /// day a dot needs to differ from its label is the day this split is the thing
  /// that makes it expressible.
  ///
  /// **The page twins, because this is the one place a status hue is drawn
  /// straight onto the page** with no card behind it. The card values are tuned
  /// to a card surface, so drawing them here would put a card-tuned hue on the
  /// page.
  Color get color => switch (this) {
    CctvStatus.live => statusOkOnPage,
    CctvStatus.offline => statusBadOnPage,
    CctvStatus.standby || CctvStatus.connecting => statusWarnOnPage,
  };

  /// The status colour to draw the *label* in.
  ///
  /// This is separate from [color] because the two jobs are different: a dot is
  /// a shape and a label is text, and a fill tuned to be bright is not the same
  /// value as a hue tuned to be read at 10dp.
  ///
  /// So the text takes the **page twins** — `statusOkOnPage` / `statusWarnOnPage`
  /// / `statusBadOnPage` — which are the values the ramp pins for text drawn
  /// straight on the page.
  ///
  /// The dot and the label resolve to the same value today, because the ramp
  /// carries one page twin per severity. The split is kept so the two can move
  /// apart the day a dot needs a different step than its label.
  Color get textColor => switch (this) {
    CctvStatus.live => statusOkOnPage,
    CctvStatus.offline => statusBadOnPage,
    CctvStatus.standby || CctvStatus.connecting => statusWarnOnPage,
  };

  /// Whether the video surface should be mounted behind the overlays.
  bool get showsVideo => this != CctvStatus.standby;
}
