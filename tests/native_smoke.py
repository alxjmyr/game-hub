"""Linux graphical smoke check. Requires DISPLAY, libXtst and ffmpeg.
Run against the exported executable, with isolated XDG_DATA_HOME.
Produces screenshots for human review; behavioral assertions live in Godot tests.
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
xtst.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
xtst.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
display = x11.XOpenDisplay(os.environ.get('DISPLAY', ':99').encode())
assert display, 'No X display'

def move(x, y):
    xtst.XTestFakeMotionEvent(display, -1, x, y, 0)
    x11.XFlush(display)
    time.sleep(.08)

def button(down):
    xtst.XTestFakeButtonEvent(display, 1, down, 0)
    x11.XFlush(display)
    time.sleep(.08)

def click(x, y):
    move(x, y)
    button(1)
    button(0)
    time.sleep(.2)

def shot(name):
    time.sleep(.2)
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-f', 'x11grab',
                    '-video_size', '1200x800', '-i', os.environ.get('DISPLAY', ':99'),
                    '-frames:v', '1', '-y', str(ROOT / 'artifacts' / ('native-' + name + '.png'))], check=True)

with open(ROOT / 'artifacts/native.log', 'w') as log:
    app = subprocess.Popen([str(ROOT / 'build/linux/game-hub'), '--position', '0,0', '--resolution', '1200x800'], stdout=log, stderr=log)
    try:
        time.sleep(2)
        assert app.poll() is None, 'Packaged game exited at startup'
        shot('shelf')
        # A virtual display without a window manager may consume the first click
        # to focus the app. Focus on a neutral heading before choosing a game.
        click(400, 150)
        click(300, 665)
        # Let hover tooltips become eligible before flipping/navigating.
        # Godot release templates used to emit popup-focus errors here.
        move(165, 270)
        time.sleep(1.5)
        click(165, 270)
        time.sleep(1.5)
        shot('memory-flip')
        move(450, 270)
        time.sleep(1.5)
        click(450, 270)
        time.sleep(1.5)
        click(115, 55)
        click(850, 665)
        shot('physics-start')
        # Regression: release-build dropdown focus errors were missed by the
        # original smoke test. Exercise every replacement control repeatedly.
        for cycle in range(2):
            for index, x in enumerate([729, 903, 1077]):
                click(1030, 485)  # Switch while a simulation is active, too.
                click(x, 60)
                if cycle == 0:
                    shot('difficulty-' + str(index))
        click(729, 60)
        # Move the long ramp from its tray onto the board and rotate via the UI.
        move(220, 590)
        button(1)
        move(390, 360)
        button(0)
        click(1100, 285)
        click(1100, 285)
        shot('physics-arranged')
        click(1030, 485)
        time.sleep(.4)
        shot('physics-running')
        time.sleep(12)
        shot('physics-result')
        click(1040, 540)
        shot('physics-retry')
        click(115, 55)
        shot('returned-shelf')
        click(1115, 65)
        assert app.wait(timeout=5) == 0, 'Quit button failed'
    finally:
        if app.poll() is None:
            app.terminate()
            app.wait(timeout=5)
        x11.XCloseDisplay(display)
text = (ROOT / 'artifacts/native.log').read_text()
assert 'SCRIPT ERROR' not in text and 'ERROR:' not in text, text
print('Native packaged smoke completed; inspect artifacts/native-*.png.')
