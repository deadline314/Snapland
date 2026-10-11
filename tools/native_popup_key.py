"""Send one real Windows keyboard message to a Godot PopupMenu HWND.

The native wardrobe review uses this for OptionButton PopupMenu windows. Godot
4.7 handles PopupMenu navigation in Window._input_from_window(), so injecting an
InputEvent into the main Viewport or manually emitting window_input does not
exercise the same native window callback.
"""

from __future__ import annotations

import ctypes
import sys
from ctypes import wintypes


KEYS = {
    "down": 0x28,
    "up": 0x26,
    "enter": 0x0D,
    "escape": 0x1B,
    "space": 0x20,
}
WM_KEYDOWN = 0x0100
WM_KEYUP = 0x0101
MAPVK_VK_TO_VSC = 0


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: native_popup_key.py HWND KEY", file=sys.stderr)
        return 2
    try:
        hwnd = int(sys.argv[1], 0)
    except ValueError:
        print("invalid HWND", file=sys.stderr)
        return 2
    key_name = sys.argv[2].lower()
    vk = KEYS.get(key_name)
    if hwnd == 0 or vk is None:
        print("invalid HWND or unsupported key", file=sys.stderr)
        return 2

    user32 = ctypes.WinDLL("user32", use_last_error=True)
    user32.IsWindow.argtypes = [wintypes.HWND]
    user32.IsWindow.restype = wintypes.BOOL
    user32.MapVirtualKeyW.argtypes = [wintypes.UINT, wintypes.UINT]
    user32.MapVirtualKeyW.restype = wintypes.UINT
    user32.PostMessageW.argtypes = [
        wintypes.HWND,
        wintypes.UINT,
        wintypes.WPARAM,
        wintypes.LPARAM,
    ]
    user32.PostMessageW.restype = wintypes.BOOL

    window = wintypes.HWND(hwnd)
    if not user32.IsWindow(window):
        print(f"not a live HWND: {hwnd}", file=sys.stderr)
        return 1

    scan_code = user32.MapVirtualKeyW(vk, MAPVK_VK_TO_VSC)
    key_down_lparam = 1 | (scan_code << 16)
    key_up_lparam = key_down_lparam | (1 << 30) | (1 << 31)
    if not user32.PostMessageW(window, WM_KEYDOWN, vk, key_down_lparam):
        print(f"PostMessageW(WM_KEYDOWN) failed: {ctypes.get_last_error()}", file=sys.stderr)
        return 1
    if not user32.PostMessageW(window, WM_KEYUP, vk, key_up_lparam):
        print(f"PostMessageW(WM_KEYUP) failed: {ctypes.get_last_error()}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
