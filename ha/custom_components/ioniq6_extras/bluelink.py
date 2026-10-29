"""Bluelink Canada calls that the kia_uvo integration doesn't make.

Every call goes through kia_uvo's own VehicleManager (its session, token and
PIN), so Home Assistant still holds a single Bluelink login. Request shapes
come from the MyHyundai Bluelink Android app 2.0.47 (com.hyundaicanada.bluelink):
all POSTs to https://mybluelink.ca/tods/api/ with JSON bodies whose keys are
the app's field names.

These functions block; call them from an executor.
"""

from __future__ import annotations

import base64
import io
import logging
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

_LOGGER = logging.getLogger(__name__)

# The 360 camera's views, in the order they sit in the image strip, then the
# larger top-down view that follows them.
SVM_VIEWS = ("front", "rear", "left", "right")
SVM_TOP = "top"

# Server-side limits on new 360 shots.
SVM_LIMIT_ERRORS = {
    "7659": "Bluelink refused the 360 request",
    "7661": "This month's 360 camera requests are used up",
    "7662": "Today's 360 camera requests are used up",
}


class BluelinkError(Exception):
    """Bluelink answered with an error."""


@dataclass
class Location:
    lat: float
    lon: float
    heading: int | None
    time: str | None


@dataclass
class ValetStatus:
    on: bool
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass
class SvmShots:
    """The latest 360 shots: PNG/JPEG bytes per view, and when they were taken."""

    images: dict[str, bytes]
    taken: datetime | None
    raw: dict[str, Any] = field(default_factory=dict)


class Bluelink:
    """Extra calls for one vehicle, made with kia_uvo's VehicleManager."""

    def __init__(self, vehicle_manager: Any, vehicle_id: str) -> None:
        self._vm = vehicle_manager
        self._vehicle_id = vehicle_id

    @property
    def _api(self) -> Any:
        return self._vm.api

    @property
    def _vehicle(self) -> Any:
        return self._vm.get_vehicle(self._vehicle_id)

    def _headers(self, pin: bool) -> dict[str, str]:
        self._vm.check_and_refresh_token()
        token = self._vm.token
        headers = dict(self._api.API_HEADERS)  # never mutate the shared dict
        headers["offset"] = str(int(datetime.now().astimezone().utcoffset().total_seconds() // 3600))
        headers["accessToken"] = token.access_token
        headers["vehicleId"] = self._vehicle.id
        if pin:
            headers["pAuth"] = self._api._get_pin_token(token, self._vehicle)
        return headers

    def _post(self, path: str, *, pin: bool = False, body: dict[str, Any] | None = None):
        response = self._api.sessions.post(self._api.API_URL + path, headers=self._headers(pin), json=body or {})
        data = response.json()
        header = data.get("responseHeader") or {}
        if header.get("responseCode") == 1:
            error = data.get("error") or {}
            code = str(error.get("errorCode", ""))
            raise BluelinkError(SVM_LIMIT_ERRORS.get(code) or error.get("errorDesc") or f"Bluelink error {code}")
        return data, response.headers

    # Location ---------------------------------------------------------------

    def locate(self) -> Location | None:
        """Find My Car (read only). evc/fme is the EV call; fndmcr the general one."""
        last: Exception | None = None
        for path in ("evc/fme", "fndmcr"):
            try:
                data, _ = self._post(path, pin=True)
            except Exception as err:  # noqa: BLE001 - try the other call
                last = err
                continue
            result = data.get("result") or {}
            coord = result.get("coord") or (result.get("gpsDetail") or {}).get("coord") or {}
            if coord.get("lat") is not None and coord.get("lon") is not None:
                return Location(
                    lat=float(coord["lat"]),
                    lon=float(coord["lon"]),
                    heading=result.get("head"),
                    time=result.get("time"),
                )
        if last:
            raise last
        return None

    # Valet ------------------------------------------------------------------

    def valet_status(self) -> ValetStatus:
        data, _ = self._post("valet/lastvaletstatus")
        result = data.get("result") or {}
        # The app treats 0 and 3 as active; anything else, including null, is off.
        return ValetStatus(on=result.get("valetMode") in (0, 3), raw=result)

    def set_valet(self, on: bool) -> None:
        """A car command: only ever called from the valet switch."""
        _, headers = self._post(
            "valet/activate" if on else "valet/deactivate", pin=True, body={"pin": self._vm.token.pin}
        )
        transaction = headers.get("transactionId")
        if transaction:
            self._wait(transaction)

    def _wait(self, transaction: str, timeout: int = 90) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            status = self._vm.check_action_status(self._vehicle_id, transaction)
            name = getattr(status, "name", str(status))
            if name == "SUCCESS":
                return
            if name in ("FAILED", "TIMEOUT"):
                raise BluelinkError("The car didn't confirm the change")
            time.sleep(5)
        raise BluelinkError("The car didn't answer in time")

    # 360 camera ---------------------------------------------------------------

    def request_svm(self) -> None:
        """Asks the car to take new 360 shots. A car command with daily and
        monthly limits; only ever called from the take_360_shots service."""
        self._api._get_pin_token(self._vm.token, self._vehicle)  # the app checks the PIN first
        self._post("rfc/fndmcrsvm")

    def last_svm(self) -> SvmShots | None:
        """The latest stored 360 shots (read only)."""
        data, _ = self._post("rfc/lastmcrsvm")
        result = data.get("result") or {}
        locations = result.get("svmLocations") or []
        if not locations:
            return None
        latest = locations[0]
        image = latest.get("svmImage")
        size = latest.get("imageSize") or []
        if not image or len(size) < 6:
            return None
        return SvmShots(images=split_svm(image, size), taken=_parse_time(latest), raw=_without_image(latest))


def split_svm(image_b64: str, size: list[Any]) -> dict[str, bytes]:
    """Cuts the strip into the four camera views and the top-down view.

    imageSize[2] × [3] is each camera view, laid side by side from x = 0;
    [4] × [5] is the top-down view, which starts at x = 4 × [2].
    """
    from PIL import Image  # Home Assistant ships Pillow

    strip = Image.open(io.BytesIO(base64.b64decode(image_b64)))
    w, h = int(size[2]), int(size[3])
    tw, th = int(size[4]), int(size[5])
    boxes = {view: (i * w, 0, (i + 1) * w, h) for i, view in enumerate(SVM_VIEWS)}
    boxes[SVM_TOP] = (4 * w, 0, 4 * w + tw, th)
    out: dict[str, bytes] = {}
    for view, box in boxes.items():
        buf = io.BytesIO()
        strip.crop(box).convert("RGB").save(buf, format="JPEG", quality=88)
        out[view] = buf.getvalue()
    return out


def _parse_time(location: dict[str, Any]) -> datetime | None:
    """utcTime is yyyyMMddHHmmss in UTC."""
    try:
        return datetime.strptime(str(location.get("utcTime")), "%Y%m%d%H%M%S").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _without_image(location: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in location.items() if k != "svmImage"}
