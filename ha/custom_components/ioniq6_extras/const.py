"""Constants for Ioniq 6 Extras."""

DOMAIN = "ioniq6_extras"
KIA_DOMAIN = "kia_uvo"

# How often to re-read the stored 360 shots and valet state. Both are reads of
# what Bluelink already holds, so neither wakes the car.
POLL_MINUTES = 30

SIGNAL_UPDATE = f"{DOMAIN}_update"
