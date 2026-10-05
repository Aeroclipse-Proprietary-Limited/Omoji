#!/usr/bin/env python3
import sys
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
        ui.syn()
        time.sleep(0.02)
        ui.write(e.EV_KEY, e.KEY_V, 1)
        ui.syn()
        time.sleep(0.03)
        ui.write(e.EV_KEY, e.KEY_V, 0)
        ui.syn()
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

def try_ydotool_paste():
    try:
        res = subprocess.run(['ydotool', 'key', '29:1', '47:1', '47:0', '29:0'], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False

def main():
    if try_uinput_paste():
        sys.exit(0)
    if try_xdotool_paste():
        sys.exit(0)
    if try_wtype_paste():
        sys.exit(0)
    if try_ydotool_paste():
        sys.exit(0)
    sys.exit(1)

if __name__ == '__main__':
    main()
