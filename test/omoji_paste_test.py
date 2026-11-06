import importlib.util
import pathlib
import unittest
from unittest.mock import patch


SCRIPT_PATH = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "omoji_paste.py"
SPEC = importlib.util.spec_from_file_location("omoji_paste", SCRIPT_PATH)
omoji_paste = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(omoji_paste)


class OmojiPasteTest(unittest.TestCase):
    def test_wayland_tries_wtype_before_ydotool(self):
        with (
            patch.dict("os.environ", {"WAYLAND_DISPLAY": "wayland-0"}),
            patch.object(omoji_paste, "try_uinput_paste", return_value=False),
            patch.object(omoji_paste, "try_wtype_paste", return_value=True) as wtype,
            patch.object(omoji_paste, "try_ydotool_paste", return_value=True) as ydotool,
            patch.object(omoji_paste.sys, "argv", ["omoji_paste.py", "🙂"]),
        ):
            with self.assertRaises(SystemExit) as exit_result:
                omoji_paste.main()

        self.assertEqual(exit_result.exception.code, 0)
        wtype.assert_called_once()
        ydotool.assert_not_called()


if __name__ == "__main__":
    unittest.main()
