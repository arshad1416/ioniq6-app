"""Valet mode (switch.ioniq_6_valet_mode) and battery preconditioning
(switch.ioniq_6_battery_preconditioning).

Turning it on or off is a car command (Bluelink valet/activate, deactivate,
with the PIN). The phone app only calls it from a press-and-hold with car
commands turned on.
"""

from __future__ import annotations

from homeassistant.components.switch import SwitchEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import Extras
from .const import DOMAIN, SIGNAL_UPDATE
from .entity import ExtrasEntity


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, add: AddEntitiesCallback) -> None:
    extras = hass.data[DOMAIN][entry.entry_id]
    add([ValetSwitch(extras), PreconditioningSwitch(extras)])


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


class PreconditioningSwitch(ExtrasEntity, SwitchEntity):
    """Warms the battery for fast charging (Bluelink evc/prcndtngon, off).
    A car command; the state comes from kia_uvo's status."""

    _attr_name = "Battery preconditioning"
    _attr_icon = "mdi:battery-heart-variant"

    def __init__(self, extras: Extras) -> None:
        super().__init__(extras, "battery_preconditioning")

    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        self.async_on_remove(async_dispatcher_connect(self.hass, SIGNAL_UPDATE, self._changed))

    @callback
    def _changed(self) -> None:
        self.async_write_ha_state()

    @property
    def is_on(self) -> bool | None:
        override = self.coordinator.preconditioning_override
        return override if override is not None else self.coordinator.bluelink.preconditioning()

    async def async_turn_on(self, **kwargs) -> None:
        await self.coordinator.async_set_preconditioning(True)

    async def async_turn_off(self, **kwargs) -> None:
        await self.coordinator.async_set_preconditioning(False)
