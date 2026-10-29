"""Valet mode: switch.ioniq_6_valet_mode.

Turning it on or off is a car command (Bluelink valet/activate, deactivate,
with the PIN). The phone app only calls it from a press-and-hold with car
commands turned on.
"""

from __future__ import annotations

from homeassistant.components.switch import SwitchEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import Extras
from .const import DOMAIN
from .entity import ExtrasEntity


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, add: AddEntitiesCallback) -> None:
    add([ValetSwitch(hass.data[DOMAIN][entry.entry_id])])


class ValetSwitch(ExtrasEntity, SwitchEntity):
    _attr_name = "Valet mode"
    _attr_icon = "mdi:account-tie-hat"

    def __init__(self, extras: Extras) -> None:
        super().__init__(extras, "valet_mode")

    @property
    def available(self) -> bool:
        return super().available and self.coordinator.data is not None and self.coordinator.data.valet is not None

    @property
    def is_on(self) -> bool | None:
        valet = self.coordinator.data.valet if self.coordinator.data else None
        return valet.on if valet else None

    @property
    def extra_state_attributes(self) -> dict:
        valet = self.coordinator.data.valet if self.coordinator.data else None
        return dict(valet.raw) if valet else {}

    async def async_turn_on(self, **kwargs) -> None:
        await self.coordinator.async_set_valet(True)

    async def async_turn_off(self, **kwargs) -> None:
        await self.coordinator.async_set_valet(False)
