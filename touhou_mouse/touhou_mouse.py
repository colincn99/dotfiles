#!/usr/bin/env python3
import asyncio
import math
import subprocess
import time
import evdev
from evdev import InputDevice, UInput, ecodes as e

# --- Configuration ---
NORMAL_SPEED = 18        # Cursor pixels moved per tick (Normal)
SLOW_SPEED = 5           # Cursor pixels moved per tick (Holding L)
TICK_RATE = 0.015        # 15ms update interval

NORMAL_SCROLL_TICK = 3   # Scroll every 3 ticks (~45ms)
SLOW_SCROLL_TICK = 10    # Scroll every 10 ticks (~150ms)

# Deliberate movement thresholds to ignore accidental bumps/palms
TRACKPAD_MIN_MOVE = 180  # Total trackpad units finger must slide before exiting
MOUSE_MIN_MOVE = 30      # Total mouse pixels cursor must move within 0.3s before exiting

STATE_FILE = "/tmp/touhou_mouse_state"

# --- State ---
mouse_mode = False
held_keys = set()
ctrl_held = False
shift_held = False
scroll_count = 0

def write_state(is_on):
    """Write current mode to state file for the system tray indicator."""
    try:
        with open(STATE_FILE, "w") as f:
            f.write("ON" if is_on else "OFF")
    except Exception:
        pass

def notify(msg):
    """Send an optional desktop notification."""
    try:
        subprocess.Popen(
            ["notify-send", "-t", "1200", "Touhou Mouse Mode", msg],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass

def set_mouse_mode(state, v_kbd=None, v_mouse=None):
    global mouse_mode, scroll_count
    if mouse_mode == state:
        return
    mouse_mode = state
    scroll_count = 0
    write_state(mouse_mode)

    if mouse_mode:
        if v_kbd:
            for mod in (e.KEY_LEFTCTRL, e.KEY_RIGHTCTRL, e.KEY_LEFTSHIFT, e.KEY_RIGHTSHIFT):
                v_kbd.write(e.EV_KEY, mod, 0)
            v_kbd.syn()
        print("[ON] Mouse Mode Active")
        notify("Mouse Mode: ON")
    else:
        if v_mouse:
            v_mouse.write(e.EV_KEY, e.BTN_LEFT, 0)
            v_mouse.write(e.EV_KEY, e.BTN_RIGHT, 0)
            v_mouse.syn()
        print("[OFF] Normal Keyboard Mode")
        notify("Mouse Mode: OFF")

def find_devices():
    """Detect physical keyboards, external mice, and laptop trackpads."""
    keyboards = []
    pointers = []
    for path in evdev.list_devices():
        dev = InputDevice(path)
        if "touhou-virtual" in dev.name.lower():
            continue
        caps = dev.capabilities()
        keys = caps.get(e.EV_KEY, [])

        if e.KEY_A in keys and e.KEY_D in keys and e.KEY_W in keys:
            keyboards.append(dev)
        elif e.BTN_LEFT in keys and e.EV_REL in caps:
            pointers.append(dev)
        elif e.EV_ABS in caps and (e.BTN_TOOL_FINGER in keys or e.BTN_TOUCH in keys):
            pointers.append(dev)

    return keyboards, pointers

async def cursor_loop(v_mouse):
    global scroll_count
    while True:
        await asyncio.sleep(TICK_RATE)
        if not mouse_mode:
            continue

        is_slow = e.KEY_L in held_keys
        speed = SLOW_SPEED if is_slow else NORMAL_SPEED

        dx = 0
        dy = 0
        if e.KEY_W in held_keys:
            dy -= 1
        if e.KEY_S in held_keys:
            dy += 1
        if e.KEY_A in held_keys:
            dx -= 1
        if e.KEY_D in held_keys:
            dx += 1

        if dx != 0 or dy != 0:
            if dx != 0 and dy != 0:
                dx = round(dx * speed / math.sqrt(2))
                dy = round(dy * speed / math.sqrt(2))
            else:
                dx *= speed
                dy *= speed
            v_mouse.write(e.EV_REL, e.REL_X, dx)
            v_mouse.write(e.EV_REL, e.REL_Y, dy)
            v_mouse.syn()

        scroll_down = e.KEY_E in held_keys
        scroll_up = e.KEY_Q in held_keys

        if scroll_down or scroll_up:
            interval = SLOW_SCROLL_TICK if is_slow else NORMAL_SCROLL_TICK
            if scroll_count % interval == 0:
                if scroll_down:
                    v_mouse.write(e.EV_REL, e.REL_WHEEL, -1)
                if scroll_up:
                    v_mouse.write(e.EV_REL, e.REL_WHEEL, 1)
                v_mouse.syn()
            scroll_count += 1
        else:
            scroll_count = 0

async def handle_keyboard(dev, v_kbd, v_mouse):
    global ctrl_held, shift_held
    dev.grab()
    try:
        async for event in dev.async_read_loop():
            if event.type != e.EV_KEY:
                v_kbd.write_event(event)
                v_kbd.syn()
                continue

            code = event.code
            val = event.value

            if code in (e.KEY_LEFTCTRL, e.KEY_RIGHTCTRL):
                ctrl_held = (val != 0)
            elif code in (e.KEY_LEFTSHIFT, e.KEY_RIGHTSHIFT):
                shift_held = (val != 0)

            if val == 1:
                held_keys.add(code)
            elif val == 0:
                held_keys.discard(code)

            # Dedicated ON shortcut: Ctrl + Shift + J
            if code == e.KEY_J and val == 1 and ctrl_held and shift_held:
                set_mouse_mode(True, v_kbd, v_mouse)
                continue

            # Dedicated OFF shortcut: Ctrl + Shift + K
            if code == e.KEY_K and val == 1 and ctrl_held and shift_held:
                set_mouse_mode(False, v_kbd, v_mouse)
                continue

            if mouse_mode:
                if code in (e.KEY_W, e.KEY_A, e.KEY_S, e.KEY_D, e.KEY_Q, e.KEY_E, e.KEY_L):
                    continue
                if code == e.KEY_J:
                    if val in (0, 1):
                        v_mouse.write(e.EV_KEY, e.BTN_LEFT, val)
                        v_mouse.syn()
                    continue
                if code == e.KEY_K:
                    if val in (0, 1):
                        v_mouse.write(e.EV_KEY, e.BTN_RIGHT, val)
                        v_mouse.syn()
                    continue

            v_kbd.write_event(event)
            v_kbd.syn()
    finally:
        dev.ungrab()

async def handle_pointer(dev, v_kbd, v_mouse):
    """Require deliberate movement distance on trackpad or mouse before exiting."""
    touch_start = {}       # Starting (X, Y) of the current finger touch
    touch_active = False   # True only while a single finger is actively down
    rel_accum_x = 0        # Accumulated relative mouse X distance
    rel_accum_y = 0        # Accumulated relative mouse Y distance
    last_rel_time = 0.0

    async for event in dev.async_read_loop():
        if not mouse_mode:
            touch_start.clear()
            touch_active = False
            rel_accum_x = 0
            rel_accum_y = 0
            continue

        # --- Trackpad Finger Down / Lift Tracking ---
        if event.type == e.EV_KEY and event.code == e.BTN_TOUCH:
            if event.value == 1:
                touch_active = True
                touch_start.clear()
            elif event.value == 0:
                touch_active = False
                touch_start.clear()
            continue

        # Ignore multi-finger palm rests (2+ fingers) on trackpad
        if event.type == e.EV_KEY and event.code in (e.BTN_TOOL_DOUBLETAP, e.BTN_TOOL_TRIPLETAP, e.BTN_TOOL_QUADTAP):
            if event.value == 1:
                touch_active = False
                touch_start.clear()
            continue

        # --- 1. Physical Mouse Relative Movement (Accumulated Window) ---
        if event.type == e.EV_REL and event.code in (e.REL_X, e.REL_Y):
            now = time.monotonic()
            # Reset accumulated bump distance if mouse was idle for > 0.3 seconds
            if now - last_rel_time > 0.3:
                rel_accum_x = 0
                rel_accum_y = 0
            last_rel_time = now

            if event.code == e.REL_X:
                rel_accum_x += event.value
            else:
                rel_accum_y += event.value

            if math.hypot(rel_accum_x, rel_accum_y) >= MOUSE_MIN_MOVE:
                set_mouse_mode(False, v_kbd, v_mouse)

        # --- 2. Trackpad Absolute Finger Slide (Total Distance from Touchdown) ---
        elif event.type == e.EV_ABS and touch_active:
            if event.code in (e.ABS_X, e.ABS_Y):
                if event.code not in touch_start:
                    touch_start[event.code] = event.value
                elif e.ABS_X in touch_start and e.ABS_Y in touch_start:
                    dx = (event.value - touch_start[e.ABS_X]) if event.code == e.ABS_X else 0
                    dy = (event.value - touch_start[e.ABS_Y]) if event.code == e.ABS_Y else 0
                    if math.hypot(dx, dy) >= TRACKPAD_MIN_MOVE:
                        set_mouse_mode(False, v_kbd, v_mouse)

        # --- 3. Physical Clicks Only ---
        elif event.type == e.EV_KEY and event.value == 1:
            if event.code in (e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE):
                set_mouse_mode(False, v_kbd, v_mouse)

async def main():
    keyboards, pointers = find_devices()
    if not keyboards:
        print("No physical keyboards found. Make sure you run with sudo.")
        return

    write_state(False)
    print(f"Monitoring {len(keyboards)} keyboard(s) and {len(pointers)} mouse/trackpad(s):")
    for p in pointers:
        print(f"  - Pointer detected: {p.name} ({p.path})")

    mouse_caps = {
        e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL],
        e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE],
    }
    v_mouse = UInput(mouse_caps, name="touhou-virtual-mouse")
    v_kbd = UInput.from_device(*keyboards, name="touhou-virtual-keyboard")

    tasks = [asyncio.create_task(cursor_loop(v_mouse))]
    for kbd in keyboards:
        tasks.append(asyncio.create_task(handle_keyboard(kbd, v_kbd, v_mouse)))
    for ptr in pointers:
        tasks.append(asyncio.create_task(handle_pointer(ptr, v_kbd, v_mouse)))

    await asyncio.gather(*tasks)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        write_state(False)

