import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/screens/dashboard/utils/bound.dart';

/// Covers [Bound], the granular-rebuild primitive the dashboard's whole polling
/// architecture rests on.
///
/// `dashboard_screen.dart` polls every ten seconds and announces changes by
/// bumping a `ValueNotifier` revision counter rather than calling `setState`, so
/// every card on every page is a `Bound` whose builder is the thing that is
/// supposed to re-run. If `Bound` stopped caching, a poll would rebuild the
/// tree it was written to protect. If it stopped comparing, the dashboard shows
/// the wrong page — the specific documented symptom being the AC card sitting
/// under the "PV Status" header, because PV, AC and Battery are three closure
/// lists spliced into one `Column` and their `Bound` widgets reuse each other's
/// `State` at the same tree position.
///
/// That failure was only ever visible on a device, which is why both halves of
/// the contract are pinned here: the caching that makes polling cheap, and the
/// token comparison that makes a sub-view switch honest.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      );

  group('Bound caches its child', () {
    testWidgets('runs the builder exactly once while mounting',
        (tester) async {
      final live = ValueNotifier<int>(0);
      addTearDown(live.dispose);
      final built = <Widget>[];

      // pumpWidget performs a single frame, so the count here is read before
      // any further pump could hide an extra invocation.
      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: live,
            token: Object(),
            builder: () {
              final child = Text('value ${live.value}');
              built.add(child);
              return child;
            },
          ),
        ),
      );

      expect(
        built,
        hasLength(1),
        reason: 'The child is built eagerly in initState. Building it again on '
            'the first build would be a second invocation for one mount, and '
            'the eager build exists precisely so the first frame is not empty.',
      );
    });

    testWidgets('an unrelated ancestor rebuild does not re-invoke the builder',
        (tester) async {
      final live = ValueNotifier<int>(0);
      addTearDown(live.dispose);
      final token = Object();
      final built = <Widget>[];

      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: live,
            token: token,
            builder: () {
              final child = Text('value ${live.value}');
              built.add(child);
              return child;
            },
          ),
        ),
      );
      expect(built, hasLength(1));

      final state = _parent(tester);
      state.bump();
      await tester.pump();
      state.bump();
      await tester.pump();
      // Also change something the parent owns and `Bound` has no business
      // watching, so this is not just "the same widget twice".
      state.reconfigure(unrelated: 1);
      await tester.pump();

      expect(
        built,
        hasLength(1),
        reason: 'Caching is the entire point of the widget. A parent setState '
            'that changes neither the listenable nor the token hands `Bound` a '
            'fresh widget with a fresh builder closure, and the cached child '
            'has to survive it — otherwise every poll would rebuild the tree '
            'this class exists to keep still.',
      );
      expect(find.text('unrelated: 1'), findsOneWidget);

      // Not just "the right text" but the very instance produced on mount.
      final displayed = tester.widget<Text>(
        find.descendant(
          of: find.byType(Bound),
          matching: find.byType(Text),
        ),
      );
      expect(
        identical(built.single, displayed),
        isTrue,
        reason: 'The mounted widget must be the cached instance itself, not an '
            'equal-looking rebuild of it.',
      );
    });
  });

  group('the listenable drives the rebuild', () {
    testWidgets('a notification re-invokes the builder exactly once',
        (tester) async {
      final live = ValueNotifier<int>(0);
      addTearDown(live.dispose);
      final built = <Widget>[];

      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: live,
            token: Object(),
            builder: () {
              final child = Text('value ${live.value}');
              built.add(child);
              return child;
            },
          ),
        ),
      );
      expect(built, hasLength(1));
      expect(find.text('value 0'), findsOneWidget);

      live.value = 1;
      await tester.pump();

      expect(built, hasLength(2));
      expect(find.text('value 1'), findsOneWidget);
      expect(find.text('value 0'), findsNothing);

      // A revision notifier fires once per poll tick, so a second poll has to
      // produce a second builder invocation and not a third.
      live.value = 2;
      await tester.pump();
      expect(built, hasLength(3));
      expect(find.text('value 2'), findsOneWidget);
    });
  });

  group('the token drives the rebuild', () {
    testWidgets('a different token instance rebuilds even though the listenable '
        'never fired', (tester) async {
      final live = ValueNotifier<int>(0);
      addTearDown(live.dispose);
      final built = <Widget>[];
      Widget Function() builderFor(String label) => () {
            final child = Text(label);
            built.add(child);
            return child;
          };

      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: live,
            token: Object(),
            builder: builderFor('first'),
          ),
        ),
      );
      expect(built, hasLength(1));
      expect(find.text('first'), findsOneWidget);

      // Two distinct `Object()` instances: `==` on a plain Object is identity,
      // so this is "equal in meaning, not identical" made literal.
      _parent(tester)
          .reconfigure(token: Object(), builder: builderFor('second'));
      await tester.pump();

      expect(
        built,
        hasLength(2),
        reason: 'A new token must re-run the builder even with the same '
            'listenable instance that has never notified. This is the '
            'theme/threshold/sub-view change path, which arrives as a plain '
            'setState on the dashboard and therefore as no notification at all.',
      );
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('the same token instance does not rebuild', (tester) async {
      final live = ValueNotifier<int>(0);
      addTearDown(live.dispose);
      final token = Object();
      final built = <Widget>[];
      Widget Function() builderFor(String label) => () {
            final child = Text(label);
            built.add(child);
            return child;
          };

      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: live,
            token: token,
            builder: builderFor('first'),
          ),
        ),
      );
      expect(built, hasLength(1));

      // A brand new closure, same token. `didUpdateWidget` runs, and neither
      // of its branches fires.
      _parent(tester).reconfigure(builder: builderFor('second'));
      await tester.pump();

      expect(
        built,
        hasLength(1),
        reason: 'The token is the contract, not the closure. Rebuilding on '
            'closure identity would defeat the cache, because every parent '
            'build allocates a new one.',
      );
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);
    });

    testWidgets('an int token behaves like the dashboard\'s Object.hash one',
        (tester) async {
      final live = ValueNotifier<int>(0);
      addTearDown(live.dispose);
      final built = <Widget>[];
      Widget Function() builderFor(String label) => () {
            final child = Text(label);
            built.add(child);
            return child;
          };

      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: live,
            token: Object.hash(1, false),
            builder: builderFor('pv'),
          ),
        ),
      );
      expect(built, hasLength(1));

      // Same value, recomputed — what a parent rebuild that recomputes
      // `Object.hash(_visualToken, isDark)` actually delivers.
      _parent(tester)
          .reconfigure(token: Object.hash(1, false), builder: builderFor('pv2'));
      await tester.pump();
      expect(built, hasLength(1), reason: 'Equal ints must compare equal.');

      _parent(tester)
          .reconfigure(token: Object.hash(2, false), builder: builderFor('ac'));
      await tester.pump();
      expect(built, hasLength(2));
      expect(find.text('ac'), findsOneWidget);
    });
  });

  group('the listener moves when the listenable changes', () {
    testWidgets('the old listenable is detached and the new one attached',
        (tester) async {
      final old = _TrackingListenable();
      final fresh = _TrackingListenable();
      final built = <Widget>[];

      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: old,
            token: Object(),
            builder: () {
              final child = Text('value ${old.value}');
              built.add(child);
              return child;
            },
          ),
        ),
      );
      expect(built, hasLength(1));
      expect(old.attached, 1);

      _parent(tester).reconfigure(listenable: fresh);
      await tester.pump();

      expect(old.attached, 0);
      expect(fresh.attached, 1);
      // One swap, one rebuild — the token did not change, so the rebuild comes
      // from the listenable branch of `didUpdateWidget` alone.
      expect(built, hasLength(2));
    });

    testWidgets('firing the old listenable no longer rebuilds',
        (tester) async {
      final old = ValueNotifier<int>(0);
      final fresh = ValueNotifier<int>(0);
      addTearDown(old.dispose);
      addTearDown(fresh.dispose);
      var builds = 0;

      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: old,
            token: Object(),
            builder: () {
              builds++;
              return Text('value $builds');
            },
          ),
        ),
      );
      expect(builds, 1);

      _parent(tester).reconfigure(listenable: fresh);
      await tester.pump();
      final afterSwap = builds;

      old.value = 1;
      await tester.pump();

      expect(
        builds,
        afterSwap,
        reason: 'A stale listener left on the old listenable is the mechanism '
            'behind the reused-State bug: the card on screen would keep '
            'rebuilding from a revision counter the sub-view no longer uses, '
            'while the one it should follow stays silent.',
      );
      expect(old.value, 1, reason: 'The old notifier still holds its value.');
    });

    testWidgets('firing the new listenable rebuilds', (tester) async {
      final old = ValueNotifier<int>(0);
      final fresh = ValueNotifier<int>(0);
      addTearDown(old.dispose);
      addTearDown(fresh.dispose);
      final built = <Widget>[];

      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: old,
            token: Object(),
            builder: () {
              final child = Text('fresh ${fresh.value}');
              built.add(child);
              return child;
            },
          ),
        ),
      );

      _parent(tester).reconfigure(listenable: fresh);
      await tester.pump();
      final afterSwap = built.length;

      fresh.value = 7;
      await tester.pump();

      expect(built, hasLength(afterSwap + 1));
      expect(find.text('fresh 7'), findsOneWidget);
    });
  });

  group('dispose', () {
    testWidgets('the listener is removed and a late notification is inert',
        (tester) async {
      final live = _TrackingListenable();
      var builds = 0;

      await tester.pumpWidget(
        wrap(
          _BoundHarness(
            listenable: live,
            token: Object(),
            builder: () {
              builds++;
              return Text('value $builds');
            },
          ),
        ),
      );
      expect(builds, 1);
      expect(live.attached, 1);

      await tester.pumpWidget(wrap(const SizedBox.shrink()));

      expect(
        live.attached,
        0,
        reason: 'A `Bound` that outlives nothing must not leave a closure '
            'holding its defunct State alive through the notifier. The notifier '
            'is owned by the screen, so it outlives every card on the page.',
      );

      expect(() => live.bump(), returnsNormally);
      await tester.pump();

      expect(
        builds,
        1,
        reason: 'The builder is invoked before the `mounted` check in '
            '`_refresh`, so a leaked listener would run it against a disposed '
            'State. No build means no listener, not just no setState.',
      );
    });
  });

  group('a Bound reused at a spliced tree position', () {
    // The scenario the whole class was hardened against, in miniature. PV, AC
    // and Battery are three lists of closures rendered into the same `Column`,
    // so slot 2 of that Column is a `Bound` for the telemetry card on all
    // three, and slot 4 is a `Bound` for the chart on all three. No key
    // distinguishes them, so a sub-view switch reuses their State.

    testWidgets('the State is genuinely reused, without a key',
        (tester) async {
      final live = ValueNotifier<int>(0);
      final selected = ValueNotifier<int>(0);
      addTearDown(live.dispose);
      addTearDown(selected.dispose);

      await tester.pumpWidget(
        wrap(
          _SubViewHost(
            live: live,
            selected: selected,
            builds: {},
            charts: {},
          ),
        ),
      );

      final before = tester.state<State<Bound>>(find.byType(Bound).first);
      expect(tester.state<State<Bound>>(find.byType(Bound).last), isNot(before));

      _select(tester, 1);
      await tester.pump();

      // Identity, not equality: this is the premise of the bug. If a future
      // fix added a key here, this assertion is what would say so.
      final after = tester.state<State<Bound>>(find.byType(Bound).first);
      expect(
        identical(before, after),
        isTrue,
        reason: 'Both slots are the same type with no key, so Flutter reuses '
            'the State. The token comparison is the only thing standing '
            'between that and a wrong page.',
      );
    });

    testWidgets('the card and chart under a header match that sub-view',
        (tester) async {
      final live = ValueNotifier<int>(0);
      final selected = ValueNotifier<int>(0);
      addTearDown(live.dispose);
      addTearDown(selected.dispose);
      final builds = <String, int>{};
      final charts = <String, int>{};

      await tester.pumpWidget(
        wrap(
          _SubViewHost(
            live: live,
            selected: selected,
            builds: builds,
            charts: charts,
          ),
        ),
      );

      expect(find.text('PV Status header'), findsOneWidget);
      expect(find.text('PV Status card'), findsOneWidget);
      expect(find.text('PV Status chart'), findsOneWidget);
      expect(find.text('AC Status card'), findsNothing);

      _select(tester, 1);
      await tester.pump();
      expect(find.text('AC Status header'), findsOneWidget);
      expect(find.text('AC Status card'), findsOneWidget);
      expect(find.text('AC Status chart'), findsOneWidget);
      expect(find.text('PV Status card'), findsNothing);

      _select(tester, 2);
      await tester.pump();
      expect(find.text('Battery Status header'), findsOneWidget);
      expect(find.text('Battery Status card'), findsOneWidget);
      expect(find.text('Battery Status chart'), findsOneWidget);
      expect(find.text('AC Status card'), findsNothing);

      // Back to the first one. A single-direction switch can pass on a
      // comparison that only ever sees increasing values.
      _select(tester, 0);
      await tester.pump();
      expect(find.text('PV Status card'), findsOneWidget);
      expect(find.text('PV Status chart'), findsOneWidget);
      expect(find.text('Battery Status card'), findsNothing);

      for (final title in _SubViewHostState.titles) {
        expect(
          builds[title],
          isNotNull,
          reason: 'The "$title" card never rendered, so this switch did not '
              'actually reach it.',
        );
        expect(charts[title], isNotNull);
      }
    });

    testWidgets('the reused Bound still follows the shared revision counter',
        (tester) async {
      final live = ValueNotifier<int>(0);
      final selected = ValueNotifier<int>(0);
      addTearDown(live.dispose);
      addTearDown(selected.dispose);
      final builds = <String, int>{};
      final charts = <String, int>{};

      await tester.pumpWidget(
        wrap(
          _SubViewHost(
            live: live,
            selected: selected,
            builds: builds,
            charts: charts,
          ),
        ),
      );

      _select(tester, 1);
      await tester.pump();
      final beforePoll = builds['AC Status']!;

      live.value++;
      await tester.pump();

      expect(
        builds['AC Status'],
        beforePoll + 1,
        reason: 'The listenable is the same instance across all three '
            'sub-views, so the listener has to survive the switch intact. This '
            'is the case that breaks when a `Bound` lands on a reused tree '
            'position: the card stops updating while its header keeps moving.',
      );
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// The harness parent, so every test reaches it the same way.
_BoundHarnessState _parent(WidgetTester tester) =>
    tester.state<_BoundHarnessState>(find.byType(_BoundHarness));

void _select(WidgetTester tester, int index) =>
    tester.state<_SubViewHostState>(find.byType(_SubViewHost)).select(index);

// ── Harness ───────────────────────────────────────────────────────────────────

/// A parent that owns the values `Bound` watches, so a test can change any
/// combination of them in a single setState — which is how the dashboard
/// delivers a sub-view switch, a theme change and a threshold change: one
/// rebuild, several changed values, no notification from any listenable.
class _TrackingListenable implements Listenable {
  final List<VoidCallback> _listeners = <VoidCallback>[];

  int value = 0;

  /// How many listeners are attached right now.
  ///
  /// `ChangeNotifier.hasListeners` would say the same thing, but it is a
  /// protected member and a test may not read it. Asserting attachment is not
  /// a detail here: the whole reused-`State` failure is a listener that stayed
  /// on the old notifier, or was never moved to the new one, so the test has to
  /// be able to see the attachment itself and not only its side effects.
  int get attached => _listeners.length;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void bump() {
    value++;
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}

class _BoundHarness extends StatefulWidget {
  const _BoundHarness({
    required this.listenable,
    required this.token,
    required this.builder,
  });

  final Listenable listenable;
  final Object token;
  final Widget Function() builder;

  @override
  State<_BoundHarness> createState() => _BoundHarnessState();
}

class _BoundHarnessState extends State<_BoundHarness> {
  late Listenable _listenable = widget.listenable;
  late Object _token = widget.token;
  late Widget Function() _builder = widget.builder;
  int bumps = 0;
  int _unrelated = 0;

  /// Rebuild without touching what `Bound` watches.
  void bump() => setState(() => bumps++);

  /// Swap what `Bound` watches. A null argument leaves that value alone, which
  /// is what makes "change only the token" expressible.
  void reconfigure({
    Listenable? listenable,
    Object? token,
    Widget Function()? builder,
    int? unrelated,
  }) {
    setState(() {
      if (listenable != null) _listenable = listenable;
      if (token != null) _token = token;
      if (builder != null) _builder = builder;
      if (unrelated != null) _unrelated = unrelated;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('bumps: $bumps'),
          Text('unrelated: $_unrelated'),
          Bound(listenable: _listenable, token: _token, builder: _builder),
        ],
      );
}

/// The dashboard's power page, cut down to the part that matters: three
/// closure lists spliced into one `Column` by a selected index, with a plain
/// header at slot 0 and a `Bound` at slots 2 and 4.
class _SubViewHost extends StatefulWidget {
  const _SubViewHost({
    required this.live,
    required this.selected,
    required this.builds,
    required this.charts,
  });

  final ValueNotifier<int> live;
  final ValueNotifier<int> selected;
  final Map<String, int> builds;
  final Map<String, int> charts;

  @override
  State<_SubViewHost> createState() => _SubViewHostState();
}

class _SubViewHostState extends State<_SubViewHost> {
  static const titles = ['PV Status', 'AC Status', 'Battery Status'];

  void select(int index) {
    if (index == widget.selected.value) return;
    widget.selected.value = index;
    setState(() {});
  }

  List<Widget Function()> _closures(String title) => [
        // The header is a plain widget, so it updates the instant the
        // sub-view changes. That is what made a stale card below it read as
        // the wrong page rather than as a slow refresh.
        () => Text('$title header'),
        () => const SizedBox(height: 10),
        () => Bound(
              listenable: widget.live,
              token: Object.hash(widget.selected.value, title),
              builder: () {
                widget.builds[title] = (widget.builds[title] ?? 0) + 1;
                return Text('$title card');
              },
            ),
        () => const SizedBox(height: 16),
        () => Bound(
              listenable: widget.live,
              token: Object.hash(widget.selected.value, title, 'chart'),
              builder: () {
                widget.charts[title] = (widget.charts[title] ?? 0) + 1;
                return Text('$title chart');
              },
            ),
      ];

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final make in _closures(titles[widget.selected.value])) make(),
        ],
      );
}
