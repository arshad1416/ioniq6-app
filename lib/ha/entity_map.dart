import 'entities.dart';

/// Where the app's entities and the car's device actually are in this Home
/// Assistant. The ids in [E] are what they were when the app was written;
/// removing and re-adding the Hyundai integration gives the device a new id
/// and can rename entities (`…_2`), so they are looked up at each connect.
class EntityMap {
  const EntityMap({
    this.deviceId = E.deviceId,
    this.renamed = const {},
    this.uniqueIds = const {},
    this.integrationFound = true,
    this.extrasFound = true,
  });

  /// The Hyundai integration's device for the car, for `kia_uvo.*` services.
  final String deviceId;

  /// Entities that now go by another id: the id in [E] to the current one.
  final Map<String, String> renamed;

  /// Each found entity's permanent id, remembered so a rename can be followed.
  final Map<String, String> uniqueIds;

  /// Whether Home Assistant has the Hyundai integration's car at all.
  final bool integrationFound;

  /// Whether the Ioniq 6 Extras add-on has entities.
  final bool extrasFound;

  static const kiaPlatform = 'kia_uvo';
  static const extrasPlatform = 'ioniq6_extras';

  String actual(String id) => renamed[id] ?? id;

  List<String> get subscribed => [for (final id in E.all) actual(id)];

  /// The id in [E] for an entity as Home Assistant names it now.
  String canonical(String actualId) {
    for (final MapEntry(:key, :value) in renamed.entries) {
      if (value == actualId) return key;
    }
    return actualId;
  }

  /// Service data with the device and entity ids swapped for the current ones.
  Map<String, dynamic> translate(Map<String, dynamic> data) => {
    for (final MapEntry(:key, :value) in data.entries)
      key: switch (key) {
        'device_id' => deviceId,
        'entity_id' when value is String => actual(value),
        _ => value,
      },
  };

  /// Builds the map from Home Assistant's entity registry. [remembered] is
  /// [uniqueIds] from an earlier connect.
  factory EntityMap.resolve(List<Map<String, dynamic>> registry, {Map<String, String> remembered = const {}}) {
    final byId = {for (final e in registry) e['entity_id'] as String: e};
    final kia = [
      for (final e in registry)
        if (e['platform'] == kiaPlatform && e['device_id'] != null) e,
    ];

    final renamed = <String, String>{};
    final uniqueIds = <String, String>{};
    for (final id in E.all) {
      var entry = byId[id];
      if (entry == null) {
        final domain = id.split('.').first;
        final unique = remembered[id];
        final numbered = RegExp('^${RegExp.escape(id)}_\\d+\$');
        bool sameEntity(Map<String, dynamic> e) {
          final other = e['entity_id'] as String;
          if (!other.startsWith('$domain.')) return false;
          return unique != null ? e['unique_id'] == unique : numbered.hasMatch(other);
        }

        entry = registry.where(sameEntity).firstOrNull;
        if (entry == null) continue;
        renamed[id] = entry['entity_id'] as String;
      }
      if (entry['unique_id'] is String) uniqueIds[id] = entry['unique_id'] as String;
    }

    // The car's device: the one the lock belongs to, else the Hyundai device
    // with the most entities.
    String? device = byId[renamed[E.lock] ?? E.lock]?['device_id'] as String?;
    if (device == null && kia.isNotEmpty) {
      final counts = <String, int>{};
      for (final e in kia) {
        counts.update(e['device_id'] as String, (n) => n + 1, ifAbsent: () => 1);
      }
      device = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    }

    return EntityMap(
      deviceId: device ?? E.deviceId,
      renamed: renamed,
      uniqueIds: {...remembered, ...uniqueIds},
      integrationFound: device != null,
      extrasFound: registry.any((e) => e['platform'] == extrasPlatform),
    );
  }
}
