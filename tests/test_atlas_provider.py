import importlib.util
from pathlib import Path
from unittest import TestCase
from unittest.mock import patch


SCRIPT = Path(__file__).parents[1] / "scripts" / "transcribe.py"
SPEC = importlib.util.spec_from_file_location("transcribe", SCRIPT)
transcribe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(transcribe)


class FakeResponse:
    def __init__(self, payload, status_code=200, text=""):
        self.payload = payload
        self.status_code = status_code
        self.text = text

    def json(self):
        return self.payload


class AtlasProviderTests(TestCase):
    def test_submits_once_then_polls(self):
        submit_response = FakeResponse(
            {"data": {"id": "prediction-1", "status": "created"}}
        )
        poll_responses = [
            FakeResponse({"data": {"id": "prediction-1", "status": "processing"}}),
            FakeResponse(
                {
                    "data": {
                        "id": "prediction-1",
                        "status": "completed",
                        "stt_result": {
                            "text": "Hello",
                            "utterances": [{"text": "Hello", "start_time": 0, "end_time": 500}],
                        },
                    }
                }
            ),
        ]

        with patch.dict("os.environ", {"ATLASCLOUD_API_KEY": "test-key"}), patch.object(
            transcribe.requests, "post", return_value=submit_response
        ) as post, patch.object(
            transcribe.requests, "get", side_effect=poll_responses
        ) as get, patch.object(
            transcribe.time, "sleep"
        ):
            result = transcribe.transcribe_atlas(
                "https://example.com/sample.wav", "wav", timeout=10
            )

        self.assertEqual(post.call_count, 1)
        self.assertEqual(get.call_count, 2)
        self.assertEqual(result["result"]["text"], "Hello")
        payload = post.call_args.kwargs["json"]
        self.assertEqual(payload["model"], "bytedance/seed-asr-2.0")
        self.assertTrue(payload["enable_speaker_info"])

    def test_failed_prediction_stops(self):
        response = FakeResponse(
            {"data": {"id": "prediction-2", "status": "failed", "error": "bad audio"}}
        )

        with patch.dict("os.environ", {"ATLASCLOUD_API_KEY": "test-key"}), patch.object(
            transcribe.requests, "post", return_value=response
        ):
            with self.assertRaisesRegex(SystemExit, "bad audio"):
                transcribe.transcribe_atlas("https://example.com/sample.mp3", "mp3")
