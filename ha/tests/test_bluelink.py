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

    def post(self, url, headers, json=None, data=None):
        path = url.removeprefix(self.API_URL)
        self.calls.append((path, headers, json if data is None else data))
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
    path, headers, body = api.calls[1]
    assert path == "evc/fme" and headers["pAuth"] == "PAUTH" and headers["vehicleId"] == "REGID"
    assert (headers["from"], headers["brand"], body) == ("SPA", "H", b"")
    assert FakeApi.API_HEADERS.get("pAuth") is None  # shared headers untouched


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
    path, headers, body = api.calls[1]
    assert path == "rfc/fndmcrsvm" and body == b"" and "pAuth" not in headers
    assert (headers["from"], headers["brand"], headers["vehicleId"]) == ("SPA", "H", "REGID")


def test_http_error_without_json_is_readable():
    b, _ = make({"valet/lastvaletstatus": FakeResponse(None, status_code=502)})
    with pytest.raises(bluelink.BluelinkError, match="HTTP 502"):
        b.valet_status()


def test_pin_falls_back_to_config_entry():
    b, api = make({"rfc/fndmcrsvm": OK})
    b._vm.token.pin = None
    b._entry_pin = lambda: "9876"
    b.request_svm()
    assert api.calls[0][2] == {"pin": "9876"}


def test_no_pin_anywhere_is_readable():
    b, api = make({})
    b._vm.token.pin = None
    with pytest.raises(bluelink.BluelinkError, match="No Bluelink PIN"):
        b.request_svm()
    assert api.calls == []


# Charge schedule --------------------------------------------------------------

SCHEDULE = {
    "reservChargeInfo": {
        "reservChargeInfoDetail": {
            "reservInfo": {"day": [1, 2, 3, 4, 5], "time": {"time": "0700", "timeSection": 0}},
            "reservChargeSet": True,
            "reservFatcSet": {"defrost": True, "airTemp": {"value": "10H", "unit": 0, "hvacTempType": 1}, "airCtrl": 1},
        }
    },
    "reserveChargeInfo2": {
        "reservChargeInfoDetail": {
            "reservInfo": {"day": [1, 2, 3, 4, 5], "time": {"time": "0820", "timeSection": 0}},
            "reservChargeSet": True,
            "reservFatcSet": {"defrost": True, "airTemp": {"value": "10H", "unit": 0, "hvacTempType": 1}, "airCtrl": 1},
        }
    },
    "offpeakPowerInfo": {
        "offPeakPowerFlag": 1,
        "offPeakPowerTime1": {
            "starttime": {"time": "1100", "timeSection": 1},
            "endtime": {"time": "0700", "timeSection": 0},
        },
    },
    "reservFlag": 1,
}


def make_with_schedule(answers, generation=None):
    b, api = make({"vhcllst": {**OK, "result": {"vehicles": [{"vehicleId": "REGID", "genHeaderType": generation}]}}, **answers})
    b._vm.get_vehicle = lambda vid: SimpleNamespace(id="REGID", data={"status": {"evStatus": {"reservChargeInfos": SCHEDULE}}})
    return b, api


@pytest.mark.parametrize(
    "hhmm, expected",
    [
        ("23:00", {"time": "1100", "timeSection": 1}),
        ("07:30", {"time": "0730", "timeSection": 0}),
        ("00:00", {"time": "1200", "timeSection": 0}),
        ("12:15", {"time": "1215", "timeSection": 1}),
    ],
)
def test_bluelink_time(hhmm, expected):
    assert bluelink.bluelink_time(hhmm) == expected


def test_set_off_peak_keeps_departures_and_sends_pauth():
    b, api = make_with_schedule({"evc/srcfs": OK}, generation="Gen2")
    b.set_off_peak("only", "22:30", "06:00")
    path, headers, body = api.calls[-1]
    assert path == "evc/srcfs"
    assert headers["pAuth"] == "PAUTH"
    assert body["pin"] == "1234"
    info = body["reservChargeInfos"]
    assert info["offpeakPowerInfo"]["offPeakPowerFlag"] == 2
    window = {"starttime": {"time": "1030", "timeSection": 1}, "endtime": {"time": "0600", "timeSection": 0}}
    assert info["offpeakPowerInfo"]["offPeakPowerTime1"] == window
    assert info["offpeakPowerInfo"]["offPeakPowerTime2"] == window
    assert info["reservFlag"] == 1
    detail = info["reserveChargeInfo2"]["reservChargeInfoDetail"]
    assert detail["reservInfo"]["time"] == {"time": "0820", "timeSection": 0}
    assert detail["reservFatcSet"]["airTemp"]["value"] == "10H"
    assert detail["reservFatcSet"]["heating1"] == 0
    # The car's own copy is left alone.
    assert "heating1" not in SCHEDULE["reservChargeInfo"]["reservChargeInfoDetail"]["reservFatcSet"]


def test_set_off_peak_off_clears_reserv_flag():
    b, api = make_with_schedule({"evc/srcfs": OK})
    b.set_off_peak("off", "23:00", "07:00")
    info = api.calls[-1][2]["reservChargeInfos"]
    assert info["offpeakPowerInfo"]["offPeakPowerFlag"] == 0
    assert info["reservFlag"] == 0


def test_set_off_peak_gen3_uses_window_only_call_without_pauth():
    b, api = make_with_schedule({"v2/rc/ev/reschargeset": OK}, generation="GEN3")
    b.set_off_peak("prefer", "23:00", "07:00")
    assert [c[0] for c in api.calls][-2:] == ["vrfypin", "v2/rc/ev/reschargeset"]
    _, headers, body = api.calls[-1]
    assert "pAuth" not in headers
    assert body == {
        "pin": "1234",
        "reservFlag": 1,
        "offpeakPowerFlag": 1,
        "reservStartTime": {"time": "1100", "timeSection": 1},
        "reservEndTime": {"time": "0700", "timeSection": 0},
    }


def test_set_off_peak_without_a_reported_schedule_refuses():
    b, api = make({"vhcllst": {**OK, "result": {"vehicles": []}}})
    b._vm.get_vehicle = lambda vid: SimpleNamespace(id="REGID", data={})
    with pytest.raises(bluelink.BluelinkError, match="hasn't reported"):
        b.set_off_peak("prefer", "23:00", "07:00")
    assert not any(c[0] == "evc/srcfs" for c in api.calls)
