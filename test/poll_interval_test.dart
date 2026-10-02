import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/utils/poll_interval.dart';

/// The decision, tested apart from the timer it drives.
///
/// The version this replaces was `Timer.periodic(Duration(seconds:
/// _refreshSeconds))` -- an expression that never mentioned the WebSocket, so
/// there was nothing here to assert on and nothing to fail when it was wrong.
/// The dashboard held a live WebSocket subscription that pushed every value into
/// the displayed slots, and still re-read all three devices over REST every ten
/// seconds for as long as the app was open: about 25 900 requests a day, against
/// the same single-board ThingsBoard instance the repo budgets the background
/// alarm check at roughly 4 300 a day.
void main() {
  group('effectivePollIntervalSeconds', () {
    // Without a live feed the user's setting is the whole truth. Nothing about
    // this change may touch that case, because it is the one where polling is
    // the data path rather than a safety net.
    test('with no WebSocket the user setting is used unchanged', () {
      for (final requested in [5, 10, 30, 60, 120, 300]) {
        expect(
          effectivePollIntervalSeconds(
            requestedSeconds: requested,
            realtimeConnected: false,
          ),
          requested,
          reason: 'requested $requested s with the socket down',
        );
      }
    });

    // The default 10 s is the case that mattered: six times less load while the
    // socket is healthy.
    test('a live WebSocket backs the default up to the floor', () {
      expect(
        effectivePollIntervalSeconds(
          requestedSeconds: 10,
          realtimeConnected: true,
        ),
        kRealtimePollFloorSeconds,
      );
      expect(kRealtimePollFloorSeconds, 60);
    });

    // The floor is a floor. A user who asked for 5 s wanted it live, and backing
    // off is only ever allowed to make polling less frequent than they asked
    // for -- never to quietly override them in the other direction.
    test('backing off never makes polling more frequent than requested', () {
      for (final requested in [1, 5, 10, 30, 59]) {
        final actual = effectivePollIntervalSeconds(
          requestedSeconds: requested,
          realtimeConnected: true,
        );
        expect(
          actual,
          greaterThanOrEqualTo(requested),
          reason: 'requested $requested s, got $actual s',
        );
      }
    });

    // A slow setting must not be sped up by the socket being healthy.
    test('a setting slower than the floor is left alone', () {
      for (final requested in [60, 120, 300, 3600]) {
        expect(
          effectivePollIntervalSeconds(
            requestedSeconds: requested,
            realtimeConnected: true,
          ),
          requested,
        );
      }
    });

    // The socket sends no ping, so a dead-but-open connection is only noticed by
    // a re-read. That is why the floor is a slow poll and not no poll, and it is
    // the single most important thing this function must keep doing.
    test('polling continues at a live connection rather than stopping', () {
      expect(
        effectivePollIntervalSeconds(
          requestedSeconds: 10,
          realtimeConnected: true,
        ),
        greaterThan(0),
      );
    });

    // Both directions, because the second is the one that bites. If the caller
    // only re-armed on connect, a socket that dropped would leave the dashboard
    // on the 60 s safety net for the rest of the session -- the exact case the
    // short interval exists for.
    test('the interval returns to the setting as soon as the socket drops', () {
      const requested = 10;
      expect(
        effectivePollIntervalSeconds(
          requestedSeconds: requested,
          realtimeConnected: true,
        ),
        greaterThan(requested),
      );
      expect(
        effectivePollIntervalSeconds(
          requestedSeconds: requested,
          realtimeConnected: false,
        ),
        requested,
      );
    });
  });
}
