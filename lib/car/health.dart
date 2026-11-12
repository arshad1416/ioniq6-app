/// Which link between the phone and the car is broken, if any.
enum Link {
  ok,
  demo,
  connecting,

  /// The phone has no usable network (or can't look up the address).
  noNetwork,

  /// The network works but Home Assistant doesn't answer.
  haUnreachable,

  /// Home Assistant answered and refused the token.
  tokenRejected,

  /// Home Assistant is fine but has no Hyundai integration for the car.
  integrationMissing,

  /// The Hyundai integration is there but its entities are unavailable:
  /// usually it can't sign in to Bluelink.
  carUnavailable,

  /// Everything answers, but the car hasn't reported for a long time.
  stale,
}

/// The state of the path to the car, in words the screens can show.
class Health {
  const Health(this.link, {this.detail, this.extrasMissing = false});

  final Link link;

  /// The underlying error text, when there is one.
  final String? detail;

  /// The Ioniq 6 Extras add-on isn't loaded (parked location, valet, battery
  /// warming and the 360 camera need it).
  final bool extrasMissing;

  bool get ok => link == Link.ok || link == Link.demo;

  /// Whether a command has any chance of reaching the car.
  bool get canCommand => ok || link == Link.stale;

  /// Whether what's on screen comes straight from Home Assistant right now.
  bool get live => ok || link == Link.stale || link == Link.carUnavailable || link == Link.integrationMissing;

  String? get title => switch (link) {
    Link.ok || Link.demo || Link.connecting => null,
    Link.noNetwork => 'No internet connection',
    Link.haUnreachable => 'Can\'t reach Home Assistant',
    Link.tokenRejected => 'Home Assistant rejected the token',
    Link.integrationMissing => 'The Hyundai integration isn\'t set up in Home Assistant',
    Link.carUnavailable => 'The Hyundai integration isn\'t getting data from Bluelink',
    Link.stale => 'The car hasn\'t reported for a while',
  };

  String? get advice => switch (link) {
    Link.ok || Link.demo || Link.connecting => null,
    Link.noNetwork => 'Retrying when the phone is back online.',
    Link.haUnreachable => 'Retrying. Check that Home Assistant and its remote address are up.',
    Link.tokenRejected => 'Create a new long-lived token in Home Assistant and paste it in Settings.',
    Link.integrationMissing => 'Add Hyundai / Kia Connect in Home Assistant; the app finds the car by itself.',
    Link.carUnavailable => 'In Home Assistant, reload Hyundai / Kia Connect or sign it in again.',
    Link.stale => 'Pull down to ask Home Assistant again.',
  };
}
