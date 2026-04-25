#Requires AutoHotkey v2.0
#SingleInstance Force

/*
    SnapFrame - MVP
    ---------------
    Ctrl + Alt + S: Enter capture mode.
    Esc: Cancel capture mode.
    Left click: Capture the current framed region.

    How to change the capture size:
    - Edit CAPTURE_WIDTH and CAPTURE_HEIGHT below.

    Output:
    - PNG files are saved to .\screenshots\
*/

global CAPTURE_WIDTH := 1200
global CAPTURE_HEIGHT := 800
global OUTPUT_DIR := A_ScriptDir "\screenshots"
global OVERLAY_BORDER_THICKNESS := 3
global OVERLAY_COLOR := "00D7FF"
global OVERLAY_BG_COLOR := "010203"
global OVERLAY_REFRESH_MS := 16
global OVERLAY_HIDE_DELAY_MS := 50
global g_IsCaptureMode := false
global g_GdipToken := 0
global g_OverlayGui := 0
global g_OverlayVisualsApplied := false
global g_LastRegion := 0

main()

^!s::startCaptureMode()
Esc::stopCaptureMode()

#HotIf IsCaptureModeActive()
LButton::handleCaptureClick()
#HotIf

main() {
    InitDpiAwareness()
    CoordMode("Mouse", "Screen")
    EnsureOutputDir()
    InitGdip()
    EnsureOverlayGui()
}

startCaptureMode() {
    global CAPTURE_WIDTH, CAPTURE_HEIGHT, OVERLAY_REFRESH_MS, g_IsCaptureMode, g_LastRegion

    if g_IsCaptureMode {
        return
    }

    g_IsCaptureMode := true
    g_LastRegion := GetDefaultCaptureRegion(CAPTURE_WIDTH, CAPTURE_HEIGHT)

    updateOverlayPosition()
    SetTimer(updateOverlayPosition, OVERLAY_REFRESH_MS)
    TrayTip("截图模式已启动`n移动鼠标并左键截图，Esc 取消", "SnapFrame", 1)
}

stopCaptureMode() {
    global g_IsCaptureMode, g_LastRegion

    if !g_IsCaptureMode {
        return
    }

    g_IsCaptureMode := false
    g_LastRegion := 0
    SetTimer(updateOverlayPosition, 0)
    HideOverlay()
}

handleCaptureClick() {
    global OVERLAY_HIDE_DELAY_MS, g_IsCaptureMode, g_LastRegion

    if !g_IsCaptureMode || !IsObject(g_LastRegion) {
        return
    }

    HideOverlay()
    Sleep(OVERLAY_HIDE_DELAY_MS)

    savedFile := captureRegion(g_LastRegion.x, g_LastRegion.y, g_LastRegion.w, g_LastRegion.h)
    stopCaptureMode()

    if savedFile {
        TrayTip("截图已保存:`n" savedFile, "SnapFrame", 1)
    }

    KeyWait("LButton")
}

IsCaptureModeActive() {
    global g_IsCaptureMode
    return g_IsCaptureMode
}

updateOverlayPosition() {
    global CAPTURE_WIDTH, CAPTURE_HEIGHT, g_IsCaptureMode, g_LastRegion

    if !g_IsCaptureMode {
        return
    }

    MouseGetPos(&mouseX, &mouseY)
    region := GetRegionCenteredOnPoint(mouseX, mouseY, CAPTURE_WIDTH, CAPTURE_HEIGHT)
    g_LastRegion := region
    ShowOverlay(region)
}

GetDefaultCaptureRegion(width, height) {
    primaryMonitor := MonitorGetPrimary()
    MonitorGet(primaryMonitor, &left, &top, &right, &bottom)

    monitorWidth := right - left
    monitorHeight := bottom - top

    x := left + Floor((monitorWidth - width) / 2)
    y := top + Floor((monitorHeight - height) / 2)

    return clampToScreen(x, y, width, height, left, top, right, bottom)
}

GetRegionCenteredOnPoint(centerX, centerY, width, height) {
    primaryMonitor := MonitorGetPrimary()
    MonitorGet(primaryMonitor, &left, &top, &right, &bottom)

    x := centerX - Floor(width / 2)
    y := centerY - Floor(height / 2)

    return clampToScreen(x, y, width, height, left, top, right, bottom)
}

clampToScreen(x, y, width, height, left, top, right, bottom) {
    maxX := Max(left, right - width)
    maxY := Max(top, bottom - height)

    if (x < left) {
        x := left
    } else if (x > maxX) {
        x := maxX
    }

    if (y < top) {
        y := top
    } else if (y > maxY) {
        y := maxY
    }

    return {x: x, y: y, w: width, h: height}
}

EnsureOverlayGui() {
    global CAPTURE_WIDTH, CAPTURE_HEIGHT, OVERLAY_BG_COLOR, g_OverlayGui

    if IsObject(g_OverlayGui) {
        return g_OverlayGui
    }

    guiObj := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner +E0x20", "SnapFrameOverlay")
    guiObj.BackColor := OVERLAY_BG_COLOR
    guiObj.MarginX := 0
    guiObj.MarginY := 0

    DrawOverlayBorder(guiObj, CAPTURE_WIDTH, CAPTURE_HEIGHT)
    guiObj.Show("Hide w" CAPTURE_WIDTH " h" CAPTURE_HEIGHT)

    g_OverlayGui := guiObj
    return g_OverlayGui
}

DrawOverlayBorder(guiObj, width, height) {
    global OVERLAY_BORDER_THICKNESS, OVERLAY_COLOR

    border := OVERLAY_BORDER_THICKNESS
    color := "c" OVERLAY_COLOR " Background" OVERLAY_COLOR
    bottomY := height - border
    rightX := width - border

    guiObj.Add("Progress", "x0 y0 w" width " h" border " Disabled " color, 100)
    guiObj.Add("Progress", "x0 y" bottomY " w" width " h" border " Disabled " color, 100)
    guiObj.Add("Progress", "x0 y0 w" border " h" height " Disabled " color, 100)
    guiObj.Add("Progress", "x" rightX " y0 w" border " h" height " Disabled " color, 100)
}

ShowOverlay(region) {
    global OVERLAY_BG_COLOR, g_OverlayVisualsApplied

    guiObj := EnsureOverlayGui()
    guiObj.Show("NA x" region.x " y" region.y " w" region.w " h" region.h)

    if !g_OverlayVisualsApplied {
        WinSetTransparent(180, guiObj)
        WinSetTransColor(OVERLAY_BG_COLOR, guiObj)
        g_OverlayVisualsApplied := true
    }
}

HideOverlay() {
    global g_OverlayGui

    if IsObject(g_OverlayGui) {
        g_OverlayGui.Hide()
    }
}

captureRegion(x, y, width, height) {
    if !InitGdip() {
        MsgBox("GDI+ 初始化失败，无法执行截图。", "SnapFrame")
        return ""
    }

    hBitmap := CaptureScreenBitmap(x, y, width, height)
    if !hBitmap {
        MsgBox("屏幕截图失败。", "SnapFrame")
        return ""
    }

    pBitmap := Gdip_CreateBitmapFromHBITMAP(hBitmap)
    DeleteObject(hBitmap)

    if !pBitmap {
        MsgBox("位图转换失败。", "SnapFrame")
        return ""
    }

    outputFile := saveImage(pBitmap)
    Gdip_DisposeImage(pBitmap)

    return outputFile
}

saveImage(pBitmap) {
    global OUTPUT_DIR

    EnsureOutputDir()
    timestamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    outputFile := OUTPUT_DIR "\dom2prompt_" timestamp ".png"

    if !Gdip_SaveBitmapToFile(pBitmap, outputFile) {
        MsgBox("PNG 保存失败。", "SnapFrame")
        return ""
    }

    return outputFile
}

EnsureOutputDir() {
    global OUTPUT_DIR

    if !DirExist(OUTPUT_DIR) {
        DirCreate(OUTPUT_DIR)
    }
}

InitDpiAwareness() {
    dpiContextPerMonitorV2 := -4

    if DllCall("User32\SetProcessDpiAwarenessContext", "ptr", dpiContextPerMonitorV2, "int") {
        return
    }

    try {
        DllCall("Shcore\SetProcessDpiAwareness", "int", 2, "int")
    } catch {
        DllCall("User32\SetProcessDPIAware")
    }
}

CaptureScreenBitmap(x, y, width, height) {
    screenDC := DllCall("User32\GetDC", "ptr", 0, "ptr")
    memoryDC := DllCall("Gdi32\CreateCompatibleDC", "ptr", screenDC, "ptr")
    hBitmap := DllCall("Gdi32\CreateCompatibleBitmap", "ptr", screenDC, "int", width, "int", height, "ptr")
    oldBitmap := DllCall("Gdi32\SelectObject", "ptr", memoryDC, "ptr", hBitmap, "ptr")

    SRCCOPY := 0x00CC0020
    CAPTUREBLT := 0x40000000
    success := DllCall(
        "Gdi32\BitBlt",
        "ptr", memoryDC,
        "int", 0,
        "int", 0,
        "int", width,
        "int", height,
        "ptr", screenDC,
        "int", x,
        "int", y,
        "uint", SRCCOPY | CAPTUREBLT,
        "int"
    )

    DllCall("Gdi32\SelectObject", "ptr", memoryDC, "ptr", oldBitmap, "ptr")
    DllCall("Gdi32\DeleteDC", "ptr", memoryDC)
    DllCall("User32\ReleaseDC", "ptr", 0, "ptr", screenDC)

    if !success {
        DeleteObject(hBitmap)
        return 0
    }

    return hBitmap
}

DeleteObject(handle) {
    return DllCall("Gdi32\DeleteObject", "ptr", handle)
}

InitGdip() {
    global g_GdipToken

    if g_GdipToken {
        return g_GdipToken
    }

    if !DllCall("Kernel32\GetModuleHandle", "Str", "gdiplus.dll", "Ptr") {
        if !DllCall("Kernel32\LoadLibrary", "Str", "gdiplus.dll", "Ptr") {
            return 0
        }
    }

    startupInput := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, startupInput, 0)

    token := 0
    status := DllCall(
        "gdiplus\GdiplusStartup",
        "Ptr*", &token,
        "Ptr", startupInput.Ptr,
        "Ptr", 0,
        "UInt"
    )

    if (status != 0 || !token) {
        return 0
    }

    g_GdipToken := token
    OnExit(ShutdownGdip)
    return g_GdipToken
}

ShutdownGdip(*) {
    global g_GdipToken

    if g_GdipToken {
        DllCall("gdiplus\GdiplusShutdown", "Ptr", g_GdipToken)
        g_GdipToken := 0
    }
}

Gdip_CreateBitmapFromHBITMAP(hBitmap) {
    pBitmap := 0
    status := DllCall("Gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBitmap, "Ptr", 0, "Ptr*", &pBitmap, "UInt")
    return (status = 0) ? pBitmap : 0
}

Gdip_DisposeImage(pBitmap) {
    return DllCall("Gdiplus\GdipDisposeImage", "Ptr", pBitmap)
}

Gdip_SaveBitmapToFile(pBitmap, outputFile) {
    pngClsid := GetEncoderClsid("image/png")
    if !pngClsid {
        return false
    }

    status := DllCall(
        "Gdiplus\GdipSaveImageToFile",
        "Ptr", pBitmap,
        "WStr", outputFile,
        "Ptr", pngClsid.Ptr,
        "Ptr", 0,
        "UInt"
    )

    return status = 0
}

GetEncoderClsid(mimeType) {
    size := 0
    count := 0
    status := DllCall("Gdiplus\GdipGetImageEncodersSize", "UInt*", &count, "UInt*", &size, "UInt")
    if (status != 0 || size = 0) {
        return 0
    }

    encoders := Buffer(size, 0)
    status := DllCall("Gdiplus\GdipGetImageEncoders", "UInt", count, "UInt", size, "Ptr", encoders.Ptr, "UInt")
    if (status != 0) {
        return 0
    }

    ; ImageCodecInfo structure layout:
    ; CLSID(16) + FormatID(16) + 5 string pointers + 4 UInt fields + 2 pointers
    ; Total size = 48 + 7 * pointer-size.
    ; MimeType is the 5th string pointer, after 32 + 4 * pointer-size bytes.
    encoderSize := 48 + (7 * A_PtrSize)
    mimeOffset := 32 + (4 * A_PtrSize)

    loop count {
        offset := (A_Index - 1) * encoderSize
        mimePtr := NumGet(encoders, offset + mimeOffset, "Ptr")

        if !mimePtr {
            continue
        }

        currentMime := StrGet(mimePtr, "UTF-16")

        if (currentMime = mimeType) {
            clsid := Buffer(16, 0)
            DllCall("Kernel32\RtlMoveMemory", "Ptr", clsid.Ptr, "Ptr", encoders.Ptr + offset, "UPtr", 16)
            return clsid
        }
    }

    return 0
}
