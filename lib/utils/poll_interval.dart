/// How often the dashboard should re-read the same telemetry over REST.
///
/// The dashboard has two ways to get telemetry and for most of a session both
/// are running at once. `ThingsBoardRealtimeService` holds a WebSocket
/// subscription and pushes every value into the displayed slots as it arrives;
/// `_fetchAll` re-reads the same devices over REST on a timer. The WebSocket
/// answers the question "what is the reading now" in real time, which makes the
/// REST poll a *safety net* rather than the data path -- but the timer was armed
/// at the user's interval either way and never consulted the connection state.
///
/// **The cost of not consulting it is the dominant request load in the app.** At
/// the 10 s default and three devices, a session that stays open for a day
/// issues about 25 900 REST requests, against a ThingsBoard instance running on
/// a single-board computer that the repo already budgets carefully: the
/// background alarm check was deliberately given a 60 s interval precisely
/// because it costs roughly 4 300 requests a day, and the dashboard was issuing
/// six times that without anyone having counted.
///
/// The floor is 60 s and not "stop polling", and the reason is specific. The
/// WebSocket sends no ping -- `FEATURE.md` §18.3 records that an idle
/// connection is only noticed through `onDone` -- so a socket that has died
/// without closing can leave the app looking connected while nothing arrives.
/// A poll that never stops is what notices. At 60 s the worst case before the
/// dashboard notices a silently dead socket is one minute of stale numbers,
/// which is a far better failure than a frozen screen, and it costs one sixth
/// of what it did.
///
/// It is a floor, not a replacement: a user who asks for 120 s still gets 120 s,
/// because backing off is only ever allowed to make polling *less* frequent than
/// they asked for. Someone who chose 5 s because they want it live has said so
/// and is not overruled.
library;

/// Seconds between REST re-reads once the WebSocket is connected.
const int kRealtimePollFloorSeconds = 60;

/// The interval the dashboard should actually poll at.
///
/// [requestedSeconds] is the user's setting, in seconds. [realtimeConnected]
/// says whether the WebSocket is currently carrying telemetry.
///
/// Kept free of Flutter imports so the decision can be tested directly, which
/// matters more than usual here: the version this replaces was a
/// `Timer.periodic(Duration(seconds: _refreshSeconds))` line that simply did not
/// mention the WebSocket, and there was no expression to assert on at all.
int effectivePollIntervalSeconds({
  required int requestedSeconds,
  required bool realtimeConnected,
}) {
  if (!realtimeConnected) return requestedSeconds;
  return requestedSeconds < kRealtimePollFloorSeconds
      ? kRealtimePollFloorSeconds
      : requestedSeconds;
}
