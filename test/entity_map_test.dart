import 'package:flutter_test/flutter_test.dart';
import 'package:ioniq6_companion/ha/entities.dart';
import 'package:ioniq6_companion/ha/entity_map.dart';

Map<String, dynamic> entry(String id, {String platform = 'kia_uvo', String device = 'dev-new', String? unique}) => {
  'entity_id': id,
  'unique_id': unique ?? 'u-$id',
  'platform': platform,
  'device_id': device,
};

void main() {
  test('uses the ids as written when Home Assistant has them', () {
    final map = EntityMap.resolve([for (final id in E.all) entry(id, device: E.deviceId)]);
    expect(map.renamed, isEmpty);
    expect(map.deviceId, E.deviceId);
    expect(map.integrationFound, isTrue);
    expect(map.subscribed, E.all);
  });

  test('follows a re-added integration: new device id and numbered entities', () {
    final map = EntityMap.resolve([entry('${E.lock}_2'), entry('${E.soc}_2')]);
    expect(map.actual(E.lock), 'lock.ioniq_6_door_lock_2');
    expect(map.canonical('lock.ioniq_6_door_lock_2'), E.lock);
    expect(map.deviceId, 'dev-new');
    expect(map.translate({'device_id': E.deviceId, 'entity_id': E.lock, 'ac_limit': 80}), {
      'device_id': 'dev-new',
      'entity_id': 'lock.ioniq_6_door_lock_2',
      'ac_limit': 80,
    });
  });

  test('follows a renamed entity by the unique id it remembered', () {
    final first = EntityMap.resolve([entry(E.lock, unique: 'vin-lock')]);
    final later = EntityMap.resolve([entry('lock.my_car', unique: 'vin-lock')], remembered: first.uniqueIds);
    expect(later.actual(E.lock), 'lock.my_car');
  });

  test('says when the Hyundai integration or the add-on is missing', () {
    final none = EntityMap.resolve([entry('sensor.grizzl_e_power', platform: 'mqtt')]);
    expect(none.integrationFound, isFalse);
    expect(none.extrasFound, isFalse);
    expect(none.deviceId, E.deviceId);

    final withExtras = EntityMap.resolve([entry(E.lock), entry(E.valet, platform: 'ioniq6_extras')]);
    expect(withExtras.extrasFound, isTrue);
  });
}
