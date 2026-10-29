"""Where the car was last parked: device_tracker.ioniq_6_parked.

Updated by the locate service (when the phone leaves the car, or on request).
Home Assistant turns the position into a zone ("home") itself; the street is
in the address attribute. The last fix survives restarts.
"""

from __future__ import annotations

from homeassistant.components.device_tracker import SourceType, TrackerEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.restore_state import RestoreEntity
from homeassistant.util import dt as dt_util

from . import Extras
from .bluelink import Location
from .const import DOMAIN, SIGNAL_UPDATE
from .entity import ExtrasEntity


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, add: AddEntitiesCallback) -> None:
    add([ParkedTracker(hass.data[DOMAIN][entry.entry_id])])


class ParkedTracker(ExtrasEntity, TrackerEntity, RestoreEntity):
    _attr_name = "Parked"
    _attr_icon = "mdi:car-electric"

    def __init__(self, extras: Extras) -> None:
        super().__init__(extras, "parked")

    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        if self.coordinator.location is None and (last := await self.async_get_last_state()):
            a = last.attributes
            if a.get("latitude") is not None and a.get("longitude") is not None:
                self.coordinator.location = Location(a["latitude"], a["longitude"], a.get("heading"), None)
                self.coordinator.address = a.get("address")
                self.coordinator.located_at = dt_util.parse_datetime(str(a.get("located_at")))
        self.async_on_remove(async_dispatcher_connect(self.hass, SIGNAL_UPDATE, self._changed))

    @callback
    def _changed(self) -> None:
        self.async_write_ha_state()

    @property
    def source_type(self) -> SourceType:
        return SourceType.GPS

    @property
    def latitude(self) -> float | None:
        loc = self.coordinator.location
        return loc.lat if loc else None

    @property
    def longitude(self) -> float | None:
        loc = self.coordinator.location
        return loc.lon if loc else None

    @property
    def location_accuracy(self) -> int:
        return 10

    @property
    def extra_state_attributes(self) -> dict:
        c = self.coordinator
        return {
            "address": c.address,
            "located_at": c.located_at.isoformat() if c.located_at else None,
            "heading": c.location.heading if c.location else None,
        }
