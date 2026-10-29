"""One-step setup: confirm, as long as the Hyundai integration is there."""

from __future__ import annotations

from homeassistant import config_entries

from .const import DOMAIN, KIA_DOMAIN


class Ioniq6ExtrasFlow(config_entries.ConfigFlow, domain=DOMAIN):
    VERSION = 1

    async def async_step_user(self, user_input=None):
        await self.async_set_unique_id(DOMAIN)
        self._abort_if_unique_id_configured()
        if not self.hass.config_entries.async_entries(KIA_DOMAIN):
            return self.async_abort(reason="no_kia_uvo")
        if user_input is not None:
            return self.async_create_entry(title="Ioniq 6 Extras", data={})
        return self.async_show_form(step_id="user")
