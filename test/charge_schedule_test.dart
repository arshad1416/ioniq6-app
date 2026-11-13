import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/bluelink/bluelink_states.dart';
import 'package:ioniq6_companion/car/car_state.dart';
import 'package:ioniq6_companion/car/charge_schedule.dart';
import 'package:ioniq6_companion/ha/entities.dart';
import 'package:ioniq6_companion/ha/ha_client.dart';

Map<String, dynamic> departure(String time, int section) => {
  'reservChargeInfoDetail': {
    'reservInfo': {
      'day': [1, 2, 3, 4, 5],
      'time': {'time': time, 'timeSection': section},
    },
    'reservChargeSet': true,
    'reservFatcSet': {
      'defrost': true,
      'airTemp': {'value': '10H', 'unit': 0, 'hvacTempType': 1},
      'airCtrl': 1,
    },
  },
};

/// As the car reported it on 2026-11-12.
Map<String, dynamic> sample({int flag = 1, String start = '1100', int startSection = 1}) => {
  'reservChargeInfo': departure('0700', 0),
  'reserveChargeInfo2': departure('0820', 0),
  'offpeakPowerInfo': {
    'offPeakPowerFlag': flag,
    'offPeakPowerTime1': {
      'starttime': {'time': start, 'timeSection': startSection},
      'endtime': {'time': '0700', 'timeSection': 0},
    },
  },
  'reservFlag': 1,
};

void main() {
  test('reads the car\'s schedule', () {
    final s = ChargeSchedule.tryParse(sample())!;
    expect(s.mode, OffPeakMode.prefer);
    expect(s.window, '23:00–07:00');
    expect(s.scheduledCharging, isTrue);
    expect(s.departures, hasLength(2));
    expect(clock(s.departures[0].minutes), '07:00');
    expect(clock(s.departures[1].minutes), '08:20');
    expect(daySummary(s.departures[0].days), 'Weekdays');
    expect(s.departures[0].climateOn, isTrue);
    expect(s.departures[0].tempC, 22);
  });

  test('off-peak modes', () {
    expect(ChargeSchedule.tryParse(sample(flag: 0))!.mode, OffPeakMode.off);
    expect(ChargeSchedule.tryParse(sample(flag: 2))!.mode, OffPeakMode.only);
    expect(ChargeSchedule.tryParse(sample(flag: 7)), isNull);
  });

  test('twelve o\'clock', () {
    expect(ChargeSchedule.tryParse(sample(start: '1200', startSection: 0))!.start, 0);
    expect(ChargeSchedule.tryParse(sample(start: '1200', startSection: 1))!.start, 12 * 60);
    expect(ChargeSchedule.tryParse(sample(start: '1230', startSection: 1))!.window, '12:30–07:00');
  });

  test('missing or odd data is unknown, not an error', () {
    expect(ChargeSchedule.tryParse(null), isNull);
    expect(ChargeSchedule.tryParse('x'), isNull);
    expect(ChargeSchedule.tryParse(const {}), isNull);
    expect(ChargeSchedule.tryParse(sample(start: '9x00')), isNull);
    expect(ChargeSchedule.tryParse({...sample(), 'reservChargeInfo': 'x'})!.departures, hasLength(1));
  });

  test('day summaries', () {
    expect(daySummary([0, 1, 2, 3, 4, 5, 6]), 'Every day');
    expect(daySummary([6, 0]), 'Weekends');
    expect(daySummary([3, 1]), 'Mon, Wed');
    expect(daySummary([]), 'No days');
  });

  test('read from Home Assistant\'s raw status sensor', () {
    final car = const CarState({}).withEntity(
      EntityState(E.carData, 'on', {
        'vehicle_data': {
          'status': {
            'evStatus': {'reservChargeInfos': sample()},
          },
        },
      }, DateTime(2026)),
    );
    expect(car.chargeSchedule?.window, '23:00–07:00');
    expect(const CarState({}).chargeSchedule, isNull);
  });

  test('Bluelink times', () {
    expect(bluelinkTime(23 * 60), {'time': '1100', 'timeSection': 1});
    expect(bluelinkTime(0), {'time': '1200', 'timeSection': 0});
    expect(bluelinkTime(12 * 60 + 5), {'time': '1205', 'timeSection': 1});
    expect(bluelinkTime(7 * 60 + 30), {'time': '0730', 'timeSection': 0});
  });

  test('turning off-peak off clears the scheduled-charging flag, as the app does', () {
    final body = srcfsSchedule(sample(), OffPeakMode.off, 23 * 60, 7 * 60);
    expect((body['offpeakPowerInfo'] as Map)['offPeakPowerFlag'], 0);
    expect(body['reservFlag'], 0);
  });

  test('a saved change shows before the car reports it', () {
    final updated = ChargeSchedule.tryParse(withOffPeak(sample(), OffPeakMode.only, 22 * 60, 6 * 60))!;
    expect(updated.mode, OffPeakMode.only);
    expect(updated.window, '22:00–06:00');
    expect(updated.departures, hasLength(2));
    expect(ChargeSchedule.tryParse(withOffPeak(sample(), OffPeakMode.off, 0, 0))!.scheduledCharging, isFalse);
  });

  test('read from a direct Bluelink status', () {
    final states = statesFromBluelink({
      'evStatus': {'reservChargeInfos': sample(flag: 2)},
    });
    final car = const CarState({}).withEntities(states);
    expect(car.chargeSchedule?.mode, OffPeakMode.only);
    expect(statesFromBluelink({'evStatus': <String, dynamic>{}}).any((e) => e.entityId == E.carData), isFalse);
  });
  test('all daily minute values round-trip through every off-peak mode', () {
    for (final mode in OffPeakMode.values) {
      for (var minute = 0; minute < 1440; minute++) {
        final end = (minute + 61) % 1440;
        final encoded = withOffPeak(sample(), mode, minute, end);
        final decoded = ChargeSchedule.tryParse(encoded)!;
        expect((decoded.start, decoded.end, decoded.mode), (minute, end, mode), reason: '$mode $minute');
      }
    }
  });

  test('malformed signed or whitespace times are unknown', () {
    for (final time in ['12-1', '01-1', '+100', ' 100', '01+1', '01 1', '1260', '1300']) {
      expect(ChargeSchedule.tryParse(sample(start: time)), isNull, reason: time);
    }
  });

  test('schedule encoding refuses minutes outside a single day', () {
    for (final minute in [-1440, -1, 1440, 1500, 999999]) {
      expect(() => bluelinkTime(minute), throwsRangeError, reason: '$minute');
    }
  });

  test('schedule update deep copies departures without mutating current data', () {
    for (var minute = 0; minute < 1440; minute += 15) {
      final current = sample();
      final body = srcfsSchedule(current, OffPeakMode.only, minute, (minute + 60) % 1440);
      final original = (current['reservChargeInfo'] as Map)['reservChargeInfoDetail'] as Map;
      final copied = (body['reservChargeInfo'] as Map)['reservChargeInfoDetail'] as Map;
      expect((original['reservFatcSet'] as Map).containsKey('heating1'), isFalse);
      ((copied['reservInfo'] as Map)['day'] as List).clear();
      expect((original['reservInfo'] as Map)['day'], [1, 2, 3, 4, 5]);
    }
  });
}
