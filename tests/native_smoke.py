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
x11.XStringToKeysym.argtypes = [ctypes.c_char_p]
x11.XStringToKeysym.restype = ctypes.c_ulong
x11.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x11.XKeysymToKeycode.restype = ctypes.c_uint
xtst.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
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

def key(name):
    code = x11.XKeysymToKeycode(display, x11.XStringToKeysym(name.encode()))
    assert code, name
    xtst.XTestFakeKeyEvent(display, code, 1, 0)
    xtst.XTestFakeKeyEvent(display, code, 0, 0)
    x11.XFlush(display)
    time.sleep(.08)

def shot(name):
    time.sleep(.2)
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-f', 'x11grab',
                    '-video_size', '1200x800', '-i', os.environ.get('DISPLAY', ':99'),
                    '-frames:v', '1', '-y', str(ROOT / 'artifacts' / ('native-' + name + '.png'))], check=True)

with open(ROOT / 'artifacts/native.log', 'w') as log:
    app = subprocess.Popen([str(ROOT / 'build/linux/game-hub'), '--display-driver', 'x11', '--position', '0,0', '--resolution', '1200x800'], stdout=log, stderr=log)
    try:
        time.sleep(2)
        assert app.poll() is None, 'Packaged game exited at startup'
        shot('shelf')
        # A virtual display without a window manager may consume the first click
        # to focus the app. Focus on a neutral heading before choosing a game.
        click(400, 150)
        click(220, 415)
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
        click(600, 415)
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
        click(980, 415)
        shot('jigsaw-start')
        # Select a piece, choose a target and exercise hint/rotation/restart.
        key('n')
        key('Right')
        key('Return')
        click(1090, 50)
        key('e')
        move(740, 220)
        button(1)
        move(300, 280)
        button(0)
        click(590, 677)
        shot('jigsaw-hard')
        key('Escape')
        click(220, 680)
        shot('maze-start')
        for x in [220, 365, 80]:
            click(x, 150)
            for direction in ['Right', 'Down', 'Left', 'Up', 'd', 's']:
                key(direction)
            click(355, 750)
        shot('maze-hint')
        click(950, 50)
        click(1100, 50)
        key('Escape')
        click(600, 680)
        shot('letter-start')
        for x in [80, 250, 425]:
            click(x, 155)
            # Every alphabet character ensures both accepted keys and forgiving
            # mistakes occur regardless of the random prompt.
            for letter in 'abcdefghijklmnopqrstuvwxyz0123456789':
                key(letter)
            key('BackSpace')
        click(1080, 155)
        shot('letter-words')
        click(1100, 50)
        key('Escape')
        shot('all-games-returned-shelf')
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
