# Home Assistant pieces for the Ioniq 6

Everything the phone app needs on the Home Assistant side lives here.

| Path | What it is |
| --- | --- |
| `automations/27_ioniq6_walkaway_lock.yaml` | Walk-away lock (dry run until you switch it off). |
| `automations/28_ioniq6_locate_on_park.yaml` | Asks the car where it's parked when your phone leaves it. |
| `custom_components/ioniq6_extras/` | The "Ioniq 6 Extras" add-on: parked location, valet mode, battery warming and the 360 camera. |
| `install.sh` | Copies all of it into `/opt/homeassistant`, backing up whatever it replaces. |

## Install or update (on the Pi)

```sh
git clone https://github.com/arshad1416/ioniq6-app ~/ioniq6-app   # first time only
git -C ~/ioniq6-app pull
sudo ~/ioniq6-app/ha/install.sh
```

The first time, after Home Assistant restarts: Settings > Devices & services >
Add integration > "Ioniq 6 Extras". There's nothing to fill in.

## Ioniq 6 Extras

Bluelink Canada supports these, but the Hyundai / Kia Connect integration
doesn't expose them. The add-on borrows that integration's login, so there is
still only one Bluelink sign-in.

| Entity or service | Notes |
| --- | --- |
| `device_tracker.ioniq_6_parked` | Last parked position. The state is the zone (`home`), and `address` has the street (from OpenStreetMap). |
| `ioniq6_extras.locate` | Asks the car where it is (Find My Car). Read only. |
| `switch.ioniq_6_valet_mode` | Valet mode. Switching it is a car command and needs the PIN, which the integration already holds. |
| `image.ioniq_6_360_front`, `_rear`, `_left`, `_right`, `_top` | The latest stored 360 shots. Re-read every 30 minutes and on `ioniq6_extras.refresh`. |
| `switch.ioniq_6_battery_preconditioning` | Warms the battery for fast charging (Bluelink evc/prcndtngon, off). A car command. |
| `ioniq6_extras.take_360_shots` | Asks the car for new shots. Wakes the car and counts against Bluelink's daily and monthly limits. |

Tests for the Bluelink client: `python -m pytest ha/tests` (needs pytest and Pillow).
