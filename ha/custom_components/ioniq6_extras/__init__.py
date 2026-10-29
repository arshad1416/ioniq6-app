"""Ioniq 6 Extras: parked location, valet mode and the 360 camera.

Bluelink Canada supports these, but the Hyundai / Kia Connect (kia_uvo)
integration doesn't expose them. This borrows that integration's
VehicleManager, so Home Assistant keeps a single Bluelink login.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant, ServiceCall
from homeassistant.exceptions import ConfigEntryNotReady, HomeAssistantError
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.helpers.dispatcher import async_dispatcher_send
from homeassistant.helpers.event import async_call_later
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator
from homeassistant.util import dt as dt_util

from .bluelink import Bluelink, BluelinkError, Location, SvmShots, ValetStatus
from .const import DOMAIN, KIA_DOMAIN, POLL_MINUTES, SIGNAL_UPDATE

_LOGGER = logging.getLogger(__name__)
PLATFORMS = [Platform.DEVICE_TRACKER, Platform.SWITCH, Platform.IMAGE]


@dataclass
class Snapshot:
    valet: ValetStatus | None = None
    svm: SvmShots | None = None
    svm_fetched: datetime | None = None
    errors: dict[str, str] = field(default_factory=dict)


class Extras(DataUpdateCoordinator[Snapshot]):
    """Holds the add-on's state; polls the stored valet state and 360 shots."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry, bluelink: Bluelink, vehicle: Any) -> None:
        super().__init__(hass, _LOGGER, name=DOMAIN, update_interval=timedelta(minutes=POLL_MINUTES))
        self.entry = entry
        self.bluelink = bluelink
        self.vehicle_name: str = getattr(vehicle, "name", None) or "IONIQ 6"
        self.vin: str | None = getattr(vehicle, "VIN", None)
        self.location: Location | None = None
        self.address: str | None = None
        self.located_at: datetime | None = None
        # What we last asked for, until kia_uvo's next status says otherwise.
        self.preconditioning_override: bool | None = None

    async def _async_update_data(self) -> Snapshot:
        # kia_uvo has polled since the last command, so trust its status again.
        self.preconditioning_override = None
        snap = Snapshot(svm=self.data.svm if self.data else None, svm_fetched=self.data.svm_fetched if self.data else None)
        try:
            snap.valet = await self.hass.async_add_executor_job(self.bluelink.valet_status)
        except Exception as err:  # noqa: BLE001 - one failing read shouldn't hide the other
            snap.errors["valet"] = str(err)
        try:
            shots = await self.hass.async_add_executor_job(self.bluelink.last_svm)
            if shots:
                snap.svm, snap.svm_fetched = shots, dt_util.utcnow()
        except Exception as err:  # noqa: BLE001
            snap.errors["svm"] = str(err)
        if len(snap.errors) == 2:
            _LOGGER.warning("Bluelink reads failed: %s", snap.errors)
        return snap

    async def async_locate(self) -> None:
        try:
            loc = await self.hass.async_add_executor_job(self.bluelink.locate)
        except BluelinkError as err:
            raise HomeAssistantError(f"Couldn't locate the car: {err}") from err
        if loc is None:
            raise HomeAssistantError("The car didn't share its location")
        moved = self.location is None or (round(self.location.lat, 4), round(self.location.lon, 4)) != (
            round(loc.lat, 4),
            round(loc.lon, 4),
        )
        self.location, self.located_at = loc, dt_util.utcnow()
        if moved or not self.address:
            self.address = await self._street(loc)
        async_dispatcher_send(self.hass, SIGNAL_UPDATE)

    async def _street(self, loc: Location) -> str | None:
        """House number and street from OpenStreetMap's Nominatim."""
        try:
            session = async_get_clientsession(self.hass)
            async with session.get(
                "https://nominatim.openstreetmap.org/reverse",
                params={"format": "jsonv2", "lat": loc.lat, "lon": loc.lon, "zoom": 18, "addressdetails": 1},
                headers={"User-Agent": "ioniq6-extras (Home Assistant)"},
                timeout=15,
            ) as resp:
                data = await resp.json()
        except Exception as err:  # noqa: BLE001 - the address is a nicety
            _LOGGER.debug("Reverse geocoding failed: %s", err)
            return None
        a = data.get("address") or {}
        street = " ".join(p for p in (a.get("house_number"), a.get("road")) if p)
        place = a.get("city") or a.get("town") or a.get("village") or a.get("suburb")
        return ", ".join(p for p in (street or data.get("name"), place) if p) or data.get("display_name")

    async def async_set_valet(self, on: bool) -> None:
        try:
            await self.hass.async_add_executor_job(self.bluelink.set_valet, on)
        except BluelinkError as err:
            raise HomeAssistantError(f"Valet mode: {err}") from err
        await self.async_request_refresh()

    async def async_take_shots(self) -> None:
        try:
            await self.hass.async_add_executor_job(self.bluelink.request_svm)
        except BluelinkError as err:
            raise HomeAssistantError(str(err)) from err
        except Exception as err:
            _LOGGER.exception("Taking 360 shots failed")
            raise HomeAssistantError(f"Taking 360 shots failed: {err!r}") from err
        # Nothing tells us when the car has uploaded them; look again shortly.
        for delay in (60, 150, 300):
            async_call_later(self.hass, delay, self._refresh_later)

    async def _refresh_later(self, _now) -> None:
        await self.async_request_refresh()

    async def async_set_preconditioning(self, on: bool) -> None:
        try:
            await self.hass.async_add_executor_job(self.bluelink.set_preconditioning, on)
        except BluelinkError as err:
            raise HomeAssistantError(f"Battery preconditioning: {err}") from err
        self.preconditioning_override = on
        async_dispatcher_send(self.hass, SIGNAL_UPDATE)


def _is_vehicle_manager(obj: Any) -> bool:
    return all(hasattr(obj, a) for a in ("api", "token", "vehicles", "get_vehicle"))


def _vehicle_manager(hass: HomeAssistant) -> Any | None:
    """kia_uvo's VehicleManager, wherever this version of it keeps it: on the
    config entry's runtime_data or in hass.data, directly or on a coordinator,
    keyed by entry id or unique id."""
    holders: list[Any] = []
    for entry in hass.config_entries.async_entries(KIA_DOMAIN):
        holders.append(getattr(entry, "runtime_data", None))
    data = hass.data.get(KIA_DOMAIN)
    if isinstance(data, dict):
        for value in data.values():
            holders.append(value)
            if isinstance(value, dict):
                holders.extend(value.values())
    else:
        holders.append(data)
    for holder in holders:
        if holder is None:
            continue
        for candidate in (holder, getattr(holder, "vehicle_manager", None), getattr(holder, "_vehicle_manager", None)):
            if isinstance(holder, dict) and candidate is holder:
                candidate = holder.get("vehicle_manager")
            if candidate is not None and _is_vehicle_manager(candidate) and candidate.vehicles:
                return candidate
    _LOGGER.debug(
        "No kia_uvo VehicleManager yet; hass.data[%s] is %s with %s",
        KIA_DOMAIN,
        type(data).__name__,
        {k: type(v).__name__ for k, v in data.items()} if isinstance(data, dict) else None,
    )
    return None


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    vm = _vehicle_manager(hass)
    if vm is None:
        data = hass.data.get(KIA_DOMAIN)
        found = {k: type(v).__name__ for k, v in data.items()} if isinstance(data, dict) else type(data).__name__
        raise ConfigEntryNotReady(f"Waiting for the Hyundai / Kia Connect integration (found {found})")
    vehicle_id, vehicle = next(iter(vm.vehicles.items()))
    pin = next((e.data.get("pin") for e in hass.config_entries.async_entries(KIA_DOMAIN) if e.data.get("pin")), None)
    extras = Extras(hass, entry, Bluelink(vm, vehicle_id, pin), vehicle)
    await extras.async_config_entry_first_refresh()
    hass.data.setdefault(DOMAIN, {})[entry.entry_id] = extras

    async def locate(_: ServiceCall) -> None:
        await extras.async_locate()

    async def refresh(_: ServiceCall) -> None:
        await extras.async_refresh()

    async def take_360_shots(_: ServiceCall) -> None:
        await extras.async_take_shots()

    hass.services.async_register(DOMAIN, "locate", locate)
    hass.services.async_register(DOMAIN, "refresh", refresh)
    hass.services.async_register(DOMAIN, "take_360_shots", take_360_shots)
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    ok = await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
    if ok:
        hass.data[DOMAIN].pop(entry.entry_id, None)
        for service in ("locate", "refresh", "take_360_shots"):
            hass.services.async_remove(DOMAIN, service)
    return ok
