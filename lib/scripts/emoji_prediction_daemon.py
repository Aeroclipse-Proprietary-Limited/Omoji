#!/usr/bin/env python3
import asyncio
import json
import re
import os
import sys
import time
import select
import socket
from pathlib import Path

log_dir = Path.home() / '.config' / 'omoji'
try:
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = open(log_dir / 'daemon.log', 'a', encoding='utf-8')
    sys.stdout = log_file
    sys.stderr = log_file
except Exception:
    pass

try:
    import evdev
    from evdev import UInput, ecodes as e
    HAS_EVDEV = True
except ImportError:
    HAS_EVDEV = False

PORT = 18942
HOST = '127.0.0.1'

# Load emoji dictionary from emoji_map.dart
def load_emoji_dictionary():
    emoji_map_path = Path(__file__).parent.parent / 'data' / 'emoji_map.dart'
    emoji_list = []
    if emoji_map_path.exists():
        try:
            content = emoji_map_path.read_text(encoding='utf-8')
            # Find char and name entries
            pattern = re.compile(r"\{'char':\s*'([^']+)',\s*'name':\s*'([^']+)'\}")
            for match in pattern.finditer(content):
                char, name = match.groups()
                emoji_list.append({'char': char, 'name': name})
        except Exception as err:
            print(f"[Daemon] Error parsing emoji_map.dart: {err}")

    if not emoji_list:
        # Hardcoded fallback popular emojis
        emoji_list = [
            {'char': '😍', 'name': 'smiling face with heart eyes love adore'},
            {'char': '❤️', 'name': 'red heart love like'},
            {'char': '🥰', 'name': 'smiling face with hearts affectionate'},
            {'char': '😘', 'name': 'face blowing a kiss love romantic'},
            {'char': '😂', 'name': 'face with tears of joy laughing crying lol'},
            {'char': '🤣', 'name': 'rofl rolling on the floor laughing lol'},
            {'char': '🔥', 'name': 'fire flame hot lit'},
            {'char': '☕', 'name': 'hot beverage coffee tea'},
            {'char': '👍', 'name': 'thumbs up like agree ok'},
            {'char': '🥳', 'name': 'partying face celebrate party'},
            {'char': '😎', 'name': 'smiling face with sunglasses cool'},
            {'char': '🐱', 'name': 'cat face pet meow'},
            {'char': '🐶', 'name': 'dog face pet woof'},
            {'char': '⭐', 'name': 'star favorite yellow'},
            {'char': '🙏', 'name': 'folded hands pray thanks please'},
        ]
    return emoji_list

EMOJI_DATA = load_emoji_dictionary()

def get_predictions(query, dismissed_word=None):
    if not query:
        return []
    # Extract the last word currently being typed from the buffer
    parts = re.split(r'[\s\W]+', query.lower())
    words = [w for w in parts if w]
    if not words:
        return []
    clean = re.sub(r'[^a-z0-9]', '', words[-1])
    if len(clean) < 2:
        return []
    if dismissed_word and clean == dismissed_word:
        return []

    exact_matches = []
    prefix_matches = []
    added = set()

    for item in EMOJI_DATA:
        char = item['char']
        name = item['name'].lower()
        if char in added:
            continue

        tokens = name.split()
        if clean in tokens:
            exact_matches.append(item)
            added.add(char)
        elif len(clean) >= 3 and any(t.startswith(clean) for t in tokens):
            prefix_matches.append(item)
            added.add(char)

    return (exact_matches + prefix_matches)[:4]

def get_key_char(code):
    if not HAS_EVDEV:
        return None
    if code in e.KEY:
        name = e.KEY[code]
        if isinstance(name, list):
            name = name[0]
        if name.startswith('KEY_'):
            part = name[4:].lower()
            if len(part) == 1 and part.isalnum():
                return part
    return None

def get_mouse_position():
    try:
        import subprocess
        res = subprocess.run(['xdotool', 'getmouselocation'], capture_output=True, text=True, timeout=0.3)
        if res.returncode == 0:
            m = re.search(r'x:(\d+)\s+y:(\d+)', res.stdout)
            if m:
                return int(m.group(1)), int(m.group(2))
    except Exception:
        pass
    return None, None

class EmojiPredictionDaemon:
    def __init__(self):
        self.clients = set()
        self.typed_buffer = ""
        self.active_predictions = []
        self.dismissed_word = None
        self.uinput = None
        if HAS_EVDEV:
            try:
                self.uinput = UInput()
            except Exception as err:
                print(f"[Daemon] UInput init notice: {err}")

    def send_to_clients(self, data):
        msg = (json.dumps(data) + "\n").encode('utf-8')
        to_remove = set()
        for writer in self.clients:
            try:
                writer.write(msg)
            except Exception:
                to_remove.add(writer)
        for w in to_remove:
            self.clients.discard(w)

    def synthesize_backspaces(self, count):
        if not self.uinput:
            return
        try:
            for _ in range(count):
                self.uinput.write(e.EV_KEY, e.KEY_BACKSPACE, 1)
                self.uinput.syn()
                time.sleep(0.01)
                self.uinput.write(e.EV_KEY, e.KEY_BACKSPACE, 0)
                self.uinput.syn()
                time.sleep(0.01)
        except Exception as err:
            print(f"[Daemon] Backspace synthesis error: {err}")

    def handle_key(self, code, val):
        # Process key press (val == 1) and key repeat (val == 2)
        if val not in (1, 2):
            return

        if not HAS_EVDEV:
            return

        # Ignore modifier keys (Shift, Ctrl, Alt, CapsLock, Super/Meta)
        if code in (
            e.KEY_LEFTSHIFT, e.KEY_RIGHTSHIFT,
            e.KEY_LEFTCTRL, e.KEY_RIGHTCTRL,
            e.KEY_LEFTALT, e.KEY_RIGHTALT,
            e.KEY_CAPSLOCK, e.KEY_LEFTMETA, e.KEY_RIGHTMETA
        ):
            return

        char = get_key_char(code)
        if char is not None and char.isalpha():
            self.typed_buffer += char
            if len(self.typed_buffer) > 20:
                self.typed_buffer = self.typed_buffer[-15:]
            self.update_predictions()
            return

        if code == e.KEY_BACKSPACE:
            if self.typed_buffer:
                self.typed_buffer = self.typed_buffer[:-1]
                self.update_predictions()
            return

        if code in (e.KEY_ENTER, e.KEY_KPENTER, e.KEY_TAB):
            if self.active_predictions:
                top_emoji = self.active_predictions[0]['char']
                active_word = self.typed_buffer
                self.synthesize_backspaces(len(active_word))

                # Broadcast autofill event to Flutter
                self.send_to_clients({
                    'type': 'autofill',
                    'emoji': top_emoji,
                    'word': active_word
                })
                self.clear_predictions()
                return

        if code == e.KEY_ESC:
            if self.active_predictions:
                clean = re.sub(r'[^a-z0-9]', '', self.typed_buffer.lower())
                self.dismissed_word = clean
                self.clear_predictions()
            else:
                self.typed_buffer = ""
                self.clear_predictions()
            return

        # Any space, punctuation, number, or non-alpha delimiter resets word buffer
        self.typed_buffer = ""
        self.dismissed_word = None
        self.clear_predictions()

    def update_predictions(self):
        clean_buf = re.sub(r'[^a-z0-9]', '', self.typed_buffer.lower())
        if self.dismissed_word and clean_buf != self.dismissed_word:
            self.dismissed_word = None

        preds = get_predictions(self.typed_buffer, self.dismissed_word)
        if preds != self.active_predictions:
            self.active_predictions = preds
            if preds:
                mx, my = get_mouse_position()
                payload = {
                    'type': 'prediction',
                    'word': self.typed_buffer,
                    'predictions': preds
                }
                if mx is not None and my is not None:
                    payload['x'] = mx
                    payload['y'] = my
                self.send_to_clients(payload)
            else:
                self.send_to_clients({'type': 'clear'})

    def clear_predictions(self):
        self.typed_buffer = ""
        self.active_predictions = []
        self.send_to_clients({'type': 'clear'})

    async def handle_client(self, reader, writer):
        self.clients.add(writer)
        # Send current state if active
        if self.active_predictions:
            msg = (json.dumps({
                'type': 'prediction',
                'word': self.typed_buffer,
                'predictions': self.active_predictions
            }) + "\n").encode('utf-8')
            writer.write(msg)
        try:
            while True:
                data = await reader.readline()
                if not data:
                    break
                try:
                    cmd = json.loads(data.decode('utf-8'))
                    if cmd.get('type') == 'backspace':
                        count = int(cmd.get('count', 0))
                        if count > 0:
                            self.synthesize_backspaces(count)
                            self.clear_predictions()
                except Exception:
                    pass
        except Exception:
            pass
        finally:
            self.clients.discard(writer)

    async def _listen_device(self, dev):
        try:
            async for event in dev.async_read_loop():
                if event.type == e.EV_KEY:
                    self.handle_key(event.code, event.value)
        except Exception as err:
            print(f"[Daemon] Error reading device {dev.name}: {err}", flush=True)

    async def listen_keyboards(self):
        if not HAS_EVDEV:
            print("[Daemon] evdev not available, global keyboard listener disabled", flush=True)
            return

        active_tasks = {}
        while True:
            try:
                devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
                keyboards = []
                for dev in devices:
                    try:
                        caps = dev.capabilities()
                        if e.EV_KEY in caps and e.KEY_A in caps[e.EV_KEY]:
                            keyboards.append(dev)
                    except Exception:
                        pass

                current_paths = {dev.path for dev in keyboards}
                for path in list(active_tasks.keys()):
                    if path not in current_paths:
                        active_tasks[path].cancel()
                        del active_tasks[path]

                for dev in keyboards:
                    if dev.path not in active_tasks or active_tasks[dev.path].done():
                        active_tasks[dev.path] = asyncio.create_task(self._listen_device(dev))

            except Exception as err:
                print(f"[Daemon] Keyboard loop error: {err}", flush=True)
            await asyncio.sleep(3)

    async def start(self):
        server = await asyncio.start_server(self.handle_client, HOST, PORT)
        print(f"[Daemon] Emoji prediction daemon listening on {HOST}:{PORT}")
        asyncio.create_task(self.listen_keyboards())
        async with server:
            await server.serve_forever()

if __name__ == '__main__':
    daemon = EmojiPredictionDaemon()
    try:
        asyncio.run(daemon.start())
    except KeyboardInterrupt:
        pass
