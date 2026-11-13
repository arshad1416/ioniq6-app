"""Shared entity base: everything sits on one "IONIQ 6 Extras" device."""

from __future__ import annotations

from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from . import Extras
from .const import DOMAIN


class ExtrasEntity(CoordinatorEntity[Extras]):
    _attr_has_entity_name = True

    def __init__(self, extras: Extras, key: str) -> None:
        super().__init__(extras)
        self._attr_unique_id = f"{extras.vin or DOMAIN}_{key}"
        self._attr_device_info = DeviceInfo(
            identifiers={(DOMAIN, extras.vin or DOMAIN)},
            name=extras.vehicle_name,
            manufacturer="Hyundai",
            model="IONIQ 6",
        )
