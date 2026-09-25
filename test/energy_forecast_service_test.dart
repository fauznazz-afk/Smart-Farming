import 'package:flutter_test/flutter_test.dart';
import 'package:plts_monitoring/models/telemetry_model.dart';
import 'package:plts_monitoring/services/energy_forecast_service.dart';

void main() {
  test(
    'forecast keeps the full sample range without a combined history sort',
    () {
      final start = DateTime(2026, 1, 1, 8);
      final result = const EnergyForecastService().calculate(
        history: {
          'power_dc': [
            TelemetryPoint(timestamp: DateTime(2026, 1, 1, 9), value: 1000),
            TelemetryPoint(timestamp: DateTime(2026, 1, 1, 8), value: 1000),
          ],
          'power_ac': [
            TelemetryPoint(timestamp: DateTime(2026, 1, 1, 10), value: 200),
          ],
        },
      );

      expect(result.sampleStart, start);
      expect(result.sampleEnd, DateTime(2026, 1, 1, 10));
      expect(result.peakUsageWatts, 200);
      expect(result.peakUsageAt, DateTime(2026, 1, 1, 10));
    },
  );
}
