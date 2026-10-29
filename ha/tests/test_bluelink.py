"""Tests for the add-on's Bluelink client, with a fake kia_uvo VehicleManager.

Run from ha/: python -m pytest tests
"""

import base64
import io
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).parents[1] / "custom_components" / "ioniq6_extras"))
import bluelink  # noqa: E402

OK = {"responseHeader": {"responseCode": 0}}


class FakeResponse:
    def __init__(self, body, headers=None, status_code=200):
        self._body, self.headers, self.status_code = body, headers or {}, status_code

    def json(self):
        if self._body is None:
            raise ValueError("no JSON")
        return self._body


class FakeApi:
    API_URL = "https://mybluelink.ca/tods/api/"
    API_HEADERS = {"from": "CWP", "language": "0", "offset": "-5"}

    def __init__(self, answers):
        self.answers, self.calls = answers, []
        self.sessions = SimpleNamespace(post=self.post)

    def post(self, url, headers, json):
        path = url.removeprefix(self.API_URL)
        self.calls.append((path, headers, json))
        answer = self.answers[path]
        return answer if isinstance(answer, FakeResponse) else FakeResponse(answer)


def make(answers):
    api = FakeApi({"vrfypin": {**OK, "result": {"pAuth": "PAUTH"}}, **answers})
    vm = SimpleNamespace(
        api=api,
        token=SimpleNamespace(access_token="AT", pin="1234"),
        check_and_refresh_token=lambda: True,
        get_vehicle=lambda vid: SimpleNamespace(id="REGID"),
        check_action_status=lambda vid, tid: SimpleNamespace(name="SUCCESS"),
    )
    return bluelink.Bluelink(vm, "v1"), api


def test_locate_uses_ev_call_with_pin_header():
    b, api = make({"evc/fme": {**OK, "result": {"coord": {"lat": 43.7, "lon": -79.4}, "head": 90}}})
    loc = b.locate()
    assert (loc.lat, loc.lon, loc.heading) == (43.7, -79.4, 90)
    path, headers, _ = api.calls[1]
    assert path == "evc/fme" and headers["pAuth"] == "PAUTH" and headers["vehicleId"] == "REGID"
    assert FakeApi.API_HEADERS.get("pAuth") is None  # shared headers untouched


def test_locate_falls_back_to_fndmcr():
    err = {"responseHeader": {"responseCode": 1}, "error": {"errorCode": "7445"}}
    b, _ = make({"evc/fme": err, "fndmcr": {**OK, "result": {"coord": {"lat": 1.0, "lon": 2.0}}}})
    assert b.locate().lat == 1.0


@pytest.mark.parametrize(("mode", "on"), [(0, True), (3, True), (1, False), (None, False)])
def test_valet_status(mode, on):
    b, _ = make({"valet/lastvaletstatus": {**OK, "result": {"valetMode": mode, "maxSpeed": 80}}})
    assert b.valet_status().on is on


def test_valet_activate_waits_for_the_car():
    b, api = make({"valet/activate": FakeResponse(OK, {"transactionId": "T1"})})
    b.set_valet(True)
    assert api.calls[1][0] == "valet/activate" and api.calls[1][1]["pAuth"] == "PAUTH"


def test_svm_limit_error_is_readable():
    err = {"responseHeader": {"responseCode": 1}, "error": {"errorCode": "7662"}}
    b, _ = make({"rfc/fndmcrsvm": err})
    with pytest.raises(bluelink.BluelinkError, match="Today's 360"):
        b.request_svm()


def test_last_svm_splits_strip():
    w, h, tw, th = 40, 30, 50, 60
    strip = Image.new("RGB", (4 * w + tw, th))
    for i, color in enumerate([(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0)]):
        strip.paste(color, (i * w, 0, (i + 1) * w, h))
    strip.paste((255, 255, 255), (4 * w, 0, 4 * w + tw, th))
    buf = io.BytesIO()
    strip.save(buf, format="PNG")
    loc = {"svmImage": base64.b64encode(buf.getvalue()).decode(), "imageSize": [0, 0, w, h, tw, th], "utcTime": "20261029061500"}
    b, _ = make({"rfc/lastmcrsvm": {**OK, "result": {"svmLocations": [loc]}}})
    shots = b.last_svm()
    assert set(shots.images) == {"front", "rear", "left", "right", "top"}
    front = Image.open(io.BytesIO(shots.images["front"]))
    top = Image.open(io.BytesIO(shots.images["top"]))
    assert front.size == (w, h) and top.size == (tw, th)
    assert front.getpixel((5, 5))[0] > 200 and top.getpixel((5, 5)) > (200, 200, 200)
    assert shots.taken.isoformat() == "2026-10-29T06:15:00+00:00"
    assert "svmImage" not in shots.raw


def test_preconditioning_on_uses_pin():
    b, api = make({"evc/prcndtngon": FakeResponse(OK, {"transactionId": "T2"})})
    b.set_preconditioning(True)
    path, headers, body = api.calls[1]
    assert path == "evc/prcndtngon" and headers["pAuth"] == "PAUTH" and body == {"pin": "1234"}


def test_pin_error_is_readable():
    err = {"responseHeader": {"responseCode": 1}, "error": {"errorCode": "7404", "errorDesc": "Invalid PIN"}}
    b, api = make({"vrfypin": err, "rfc/fndmcrsvm": OK})
    with pytest.raises(bluelink.BluelinkError, match="Invalid PIN"):
        b.request_svm()
    assert [c[0] for c in api.calls] == ["vrfypin"]


def test_request_svm_accepts_empty_reply():
    b, api = make({"rfc/fndmcrsvm": FakeResponse(None)})
    b.request_svm()
    path, headers, body = api.calls[0]
    assert (path, body) == ("vrfypin", {"pin": "1234"}) and headers["accessToken"] == "AT"
    assert api.calls[1][0] == "rfc/fndmcrsvm" and "pAuth" not in api.calls[1][1]


def test_http_error_without_json_is_readable():
    b, _ = make({"valet/lastvaletstatus": FakeResponse(None, status_code=502)})
    with pytest.raises(bluelink.BluelinkError, match="HTTP 502"):
        b.valet_status()
