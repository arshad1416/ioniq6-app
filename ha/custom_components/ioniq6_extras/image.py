"""The latest 360 camera shots: image.ioniq_6_360_front, _rear, _left,
_right and _top. These read what Bluelink already stores; taking new shots
is the separate take_360_shots service.
"""

from __future__ import annotations

from homeassistant.components.image import ImageEntity
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import Extras
from .bluelink import SVM_TOP, SVM_VIEWS
from .const import DOMAIN
from .entity import ExtrasEntity


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, add: AddEntitiesCallback) -> None:
    extras = hass.data[DOMAIN][entry.entry_id]
    add([SvmImage(hass, extras, view) for view in (*SVM_VIEWS, SVM_TOP)])


class SvmImage(ExtrasEntity, ImageEntity):
    _attr_content_type = "image/jpeg"

    def __init__(self, hass: HomeAssistant, extras: Extras, view: str) -> None:
        ExtrasEntity.__init__(self, extras, f"360_{view}")
        ImageEntity.__init__(self, hass)
        self._view = view
        self._attr_name = f"360 {view}"
        self._sync()

    def _sync(self) -> None:
        data = self.coordinator.data
        self._attr_image_last_updated = (data.svm.taken or data.svm_fetched) if data and data.svm else None

    @callback
    def _handle_coordinator_update(self) -> None:
        self._sync()
        super()._handle_coordinator_update()

    @property
    def extra_state_attributes(self) -> dict:
        data = self.coordinator.data
        return {"details": data.svm.raw} if data and data.svm and self._view == "front" else {}

    async def async_image(self) -> bytes | None:
        data = self.coordinator.data
        return data.svm.images.get(self._view) if data and data.svm else None
