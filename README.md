# SnapFrame

SnapFrame is a lightweight Windows screenshot helper built with AutoHotkey v2. It is designed for fixed-size captures, especially for Chrome Web Store promotional images.

## Features

- Fixed capture size with a visible overlay frame
- Overlay follows the mouse cursor
- Left click captures the framed region
- `Esc` exits capture mode
- PNG output saved to a local `screenshots` folder

## Requirements

- Windows
- AutoHotkey v2

## Usage

1. Install AutoHotkey v2.
2. Run [`snapframe.ahk`](./snapframe.ahk).
3. Press `Ctrl + Alt + S` to enter capture mode.
4. Move the mouse to position the frame.
5. Left click to save the screenshot, or press `Esc` to cancel.

## Configuration

You can adjust the default capture size in [`snapframe.ahk`](./snapframe.ahk):

```ahk
global CAPTURE_WIDTH := 1200
global CAPTURE_HEIGHT := 800
```

Other overlay settings such as border thickness, color, and refresh rate are also defined near the top of the script.

## Repository Notes

- Local notes in `docs/` are intentionally ignored by git.
- Generated screenshots and compiled `.exe` files are also ignored.

## License

[MIT](./LICENSE)
