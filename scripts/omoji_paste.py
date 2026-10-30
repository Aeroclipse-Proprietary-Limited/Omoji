#!/usr/bin/env python3
import sys
import os
import time
import subprocess

def release_all_modifiers(ui, ec):
    for key in [ec.KEY_LEFTMETA, ec.KEY_RIGHTMETA, ec.KEY_LEFTALT, ec.KEY_RIGHTALT, ec.KEY_LEFTSHIFT, ec.KEY_RIGHTSHIFT, ec.KEY_LEFTCTRL, ec.KEY_RIGHTCTRL]:
        ui.write(ec.EV_KEY, key, 0)
    ui.syn()

def try_uinput_paste():
    try:
        import evdev
        from evdev import UInput, ecodes as e
        
        ui = UInput()
        time.sleep(0.05)
        release_all_modifiers(ui, e)
        time.sleep(0.02)
        
        # Press Ctrl+V
        ui.write(e.EV_KEY, e.KEY_LEFTCTRL, 1)
        ui.write(e.EV_KEY, e.KEY_V, 1)
        ui.syn()
        time.sleep(0.03)
        ui.write(e.EV_KEY, e.KEY_V, 0)
        ui.write(e.EV_KEY, e.KEY_LEFTCTRL, 0)
        ui.syn()
        ui.close()
        return True
    except Exception:
        return False

def try_xdotool_paste():
    try:
        res = subprocess.run(['xdotool', 'key', '--clearmodifiers', 'ctrl+v'], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False

def try_wtype_paste():
    try:
        res = subprocess.run(['wtype', '-M', 'ctrl', '-k', 'v', '-m', 'ctrl'], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False

def try_wtype_text(text):
    try:
        res = subprocess.run(['wtype', '--', text], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False

def try_ydotool_paste():
    try:
        # Use the named-key format supported by ydotool 0.1.x+.
        # The raw linux-keycode:value format (e.g. '29:1 47:1 47:0 29:0') is NOT
        # recognised by ydotool 0.1.8: it misinterprets the leading digit of each
        # argument as a key name and types the literal string "2442" instead of
        # sending Ctrl+V.
        res = subprocess.run(
            ['ydotool', 'key', 'ctrl+v'],
            capture_output=True,
        )
        return res.returncode == 0
    except Exception:
        return False

def try_dotool_paste():
    try:
        res = subprocess.run(['dotool'], input='key ctrl+v\n', text=True, capture_output=True)
        return res.returncode == 0
    except Exception:
        return False

def try_xdotool_text(text):
    try:
        res = subprocess.run(['xdotool', 'type', '--clearmodifiers', text], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False

def main():
    text = sys.argv[1] if len(sys.argv) > 1 else ''
    is_wayland = bool(
        os.environ.get('WAYLAND_DISPLAY')
        or os.environ.get('XDG_SESSION_TYPE') == 'wayland'
    )

    if is_wayland:
        # xdotool can exit 0 on Wayland without delivering keys to native apps.
        # Try the uinput-backed daemon first, and never treat xdotool as success.
        if try_ydotool_paste():
            sys.exit(0)
        if try_uinput_paste():
            sys.exit(0)
        if try_wtype_paste():
            sys.exit(0)
        if text and try_wtype_text(text):
            sys.exit(0)
    else:
        if try_uinput_paste():
            sys.exit(0)
        if try_xdotool_paste():
            sys.exit(0)
        if try_wtype_paste():
            sys.exit(0)
        if text and try_wtype_text(text):
            sys.exit(0)
        if try_ydotool_paste():
            sys.exit(0)
        if try_dotool_paste():
            sys.exit(0)
        if text and try_xdotool_text(text):
            sys.exit(0)
    sys.exit(1)

if __name__ == '__main__':
    main()
