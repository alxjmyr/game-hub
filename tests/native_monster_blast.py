"""Exercise the packaged FPS with real X11 keyboard/mouse input.
Run under xvfb-run with a 1200x800 display; captures go to artifacts/.
"""
import ctypes
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
x11 = ctypes.CDLL('libX11.so.6')
xtst = ctypes.CDLL('libXtst.so.6')
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XFlush.argtypes = [ctypes.c_void_p]
x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
x11.XStringToKeysym.restype = ctypes.c_ulong
x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x11.XKeysymToKeycode.restype = ctypes.c_uint
xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeRelativeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
display = x11.XOpenDisplay(os.environ['DISPLAY'].encode())
assert display

def key(name, duration=.08):
    code = x11.XKeysymToKeycode(display, x11.XStringToKeysym(name.encode()))
    xtst.XTestFakeKeyEvent(display, code, 1, 0)
    x11.XFlush(display)
    time.sleep(duration)
    xtst.XTestFakeKeyEvent(display, code, 0, 0)
    x11.XFlush(display)
    time.sleep(.15)

def click(x=None, y=None, duration=.08, button=1):
    if x is not None:
        xtst.XTestFakeMotionEvent(display, -1, x, y, 0)
        x11.XFlush(display)
        time.sleep(.1)
    xtst.XTestFakeButtonEvent(display, button, 1, 0)
    x11.XFlush(display)
    time.sleep(duration)
    xtst.XTestFakeButtonEvent(display, button, 0, 0)
    x11.XFlush(display)
    time.sleep(.2)

def shot(name):
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-f', 'x11grab',
                    '-video_size', '1200x800', '-i', os.environ['DISPLAY'], '-frames:v', '1',
                    '-y', str(ROOT / 'artifacts' / ('monster-native-' + name + '.png'))], check=True)

log_path = ROOT / 'artifacts/monster-native.log'
with log_path.open('w') as log:
    app = subprocess.Popen([str(ROOT / 'build/linux/game-hub'), '--display-driver', 'x11',
                            '--position', '0,0', '--resolution', '1200x800', '--', '--monster-blast'],
                           stdout=log, stderr=log)
    try:
        time.sleep(2)
        assert app.poll() is None
        click(100, 100)  # Focus window on virtual display.
        shot('intro')
        click(600, 396)
        shot('normal-selected')
        click(790, 396)
        shot('hard-selected')
        click(410, 396)
        shot('easy-selected')
        click(600, 495)
        time.sleep(.3)
        shot('cell')
        key('w', 1.6)
        shot('pistol')
        click(duration=.8)
        shot('combat')
        xtst.XTestFakeRelativeMotionEvent(display, 220, -25, 0)
        x11.XFlush(display)
        time.sleep(.2)
        shot('mouse-look')
        key('Tab')
        shot('map')
        key('Tab')
        key('Escape')
        shot('pause')
        key('Return')
        key('f')
        key('Escape')
        # Keyboard navigation covers restart and returning to the shelf.
        key('Tab')
        key('Return')
        shot('restart')
        key('Escape')
        key('Tab')
        key('Tab')
        key('Return')
        shot('shelf')
        click(1110, 65)
        assert app.wait(timeout=5) == 0
    finally:
        if app.poll() is None:
            app.terminate()
            app.wait(timeout=5)
        x11.XCloseDisplay(display)
text = log_path.read_text()
assert 'SCRIPT ERROR' not in text and 'ERROR:' not in text and 'leaked' not in text, text
print('Packaged Monster Blast native input smoke passed; inspect artifacts/monster-native-*.png.')
