#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
;  Zen‑Mode v9.1 — Blur возвращён, картинка видна, Alt‑Tab чинится
; =============================================================
;  • Blur: AccentFlags убраны, некорректный Integer() заменён.
;    Любое bgBlurStrength > 0 ⇒ включить ACCENT_ENABLE_BLURBEHIND.
;  • Картинка‑фон создаётся *после* цветового слоя, чтобы быть видимой;
;    её альфа = 255 (непрозрачная).
;  • Alt‑Tab: возвращён проверенный алгоритм (v8.6):
;      Alt Down → altPressed := true
;      Tab Up   → выходим из Zen, ждём Alt Up
;      Alt Up   → ставим новое активное окно в центр.
; =============================================================

; ---------- ПАРАМЕТРЫ ОКНА ----------
global marginH       := 0.30
global marginV       := 0.05

global marginH_2     := 0.35
global marginV_2     := 0.15

; ---------- ШТОРКА / BACKDROP ----------
global enableImageBackground := true

global imageBackgroundPath := "E:\\pic.jpg"

global bgColor        := "000000"  ; шестнадцатеричный без «#»
global bgAlpha        := 180       ; 0 (непрозрачный) … 255 (прозрачный)
global bgBlurStrength := 1         ; 0 = blur OFF, >0 = ON

global overlayTopmost := true

; ---------- ПРОЧЕЕ ----------
global enableEscExit := true

global hotkeyList   := ["^!z", "F1"]
global hotkeyList_2 := ["F2"]

; ---------- СЛУЖЕБНЫЕ ----------
global zen := false, savedWin := Map()
global guiBlur := ""            ; слой цвета+blur
global guiImgList := []         ; массив картинок

global altPressed := false, waitNewWin := false

; =============================================================
;                    РЕГИСТРАЦИЯ  HOTKEYS
; =============================================================
registerHotkeys() {
    Toggle1 := (*) => toggleZenMode(marginH,  marginV )
    Toggle2 := (*) => toggleZenMode(marginH_2,marginV_2)

    for hk in hotkeyList
        Hotkey(hk, Toggle1)

    if hotkeyList_2.Length
        for hk in hotkeyList_2
            Hotkey(hk, Toggle2)

    Hotkey("^!x", (*) => disableZenMode())
    if enableEscExit
        Hotkey("*Esc", escExit)
}
registerHotkeys()

; =============================================================
;                           ALT + TAB
; =============================================================
~Alt::  altPressed := true

~Tab Up::{                      ; Tab отпущен при зажатом Alt → выйти из Zen
    global zen, altPressed, waitNewWin
    if zen && altPressed {
        disableZenMode()
        waitNewWin := true      ; ждём новое окно после Alt Up
    }
}

~Alt Up::{                     ; Alt отпустили → если ждали, включаем Zen
    global altPressed, waitNewWin
    altPressed := false
    if waitNewWin {
        waitNewWin := false
        Sleep 100               ; дать окну активироваться
        toggleZenMode()
    }
}

escExit(*){
    if zen
        disableZenMode()
}

; =============================================================
;                    ВКЛ / ВЫКЛ  ZEN
; =============================================================
toggleZenMode(hMargin := marginH, vMargin := marginV) {
    global zen, savedWin

    if zen {
        disableZenMode()
        return
    }

    hwnd := WinGetID("A")
    if !hwnd || !WinExist(hwnd) {
        TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
        return
    }

    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd)
    savedWin := Map("id",hwnd,"x",ox,"y",oy,"w",ow,"h",oh,"max",wasMax)

    if (wasMax = 1) {
        WinRestore(hwnd)
        Sleep 50
    }

    centerX := ox + ow//2, centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon,&mL,&mT,&mR,&mB)
    monW := mR-mL, monH := mB-mT

    newW := Round(monW*(1-hMargin*2))
    newH := Round(monH*(1-vMargin*2))
    newX := mL + Round(monW*hMargin)
    newY := mT + Round(monH*vMargin)
    WinMove(newX,newY,newW,newH, hwnd)

    createBackdropLayers()

    WinSetAlwaysOnTop(1, hwnd)
    WinActivate(hwnd)
    zen := true
}

disableZenMode() {
    global zen, savedWin, guiBlur, guiImgList
    if !zen || !savedWin.Count
        return

    hwnd := savedWin["id"]
    if WinExist(hwnd) {
        try {
            if (savedWin["max"] = 1)
                WinMaximize(hwnd)
            else
                WinMove(savedWin["x"],savedWin["y"],savedWin["w"],savedWin["h"], hwnd)
            WinSetAlwaysOnTop(0, hwnd)
        }
    }

    if IsObject(guiBlur)
        guiBlur.Destroy(), guiBlur := ""
    for g in guiImgList
        if IsObject(g)
            g.Destroy()
    guiImgList := []

    zen := false
}

; =============================================================
;                    ШТОРКА (по мониторам)
; =============================================================
createBackdropLayers() {
    global enableImageBackground, imageBackgroundPath

    ; 1) Цвет + blur (верхний слой)
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    createBlurOverlay(vx, vy, vw, vh)

    ; 2) Картинка под цветным слоем
    if enableImageBackground && FileExist(imageBackgroundPath) {
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
            createImageOverlay(l, t, r-l, b-t)
        }
    }
}

; ---------- цвет + (опц.) blur ----------
createBlurOverlay(x,y,w,h) {
    global guiBlur, bgColor, bgAlpha, bgBlurStrength, overlayTopmost

    if IsObject(guiBlur)
        guiBlur.Destroy()

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    guiBlur := Gui(flags)
    guiBlur.BackColor := bgColor
    guiBlur.AddText(Format("x0 y0 w{} h{}", w, h), "").OnEvent("Click", (*)=>disableZenMode())
    guiBlur.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))

    hwnd := guiBlur.Hwnd
    ex := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "Ptr") | 0x80000
    DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "Ptr", ex)
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)

    ; ------------ Blur -------------
    if (bgBlurStrength > 0) {
        pSetWCA := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32"), "AStr", "SetWindowCompositionAttribute", "Ptr")
        if pSetWCA {
            acc := Buffer(16,0)
            NumPut("UInt", 3, acc, 0)          ; ACCENT_ENABLE_BLURBEHIND
            NumPut("UInt", 0, acc, 4)          ; AccentFlags = 0
            gradColor := ( (255-bgAlpha) << 24 ) | ( "0x" bgColor + 0 )
            NumPut("UInt", gradColor, acc, 8)
            wca := Buffer(A_PtrSize=8?24:16,0)
            NumPut("UInt",19,wca,0), NumPut("Ptr",acc.Ptr,wca,A_PtrSize=8?8:4), NumPut("UPtr",acc.Size,wca,A_PtrSize=8?16:8)
            DllCall(pSetWCA, "Ptr", hwnd, "Ptr", wca.Ptr)
        }
    }
}

; ---------- картинка (cover) ----------
createImageOverlay(x,y,wMon,hMon) {
    global guiImgList, imageBackgroundPath, overlayTopmost

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    picGui := Gui(flags)

    imgW := 0, imgH := 0
    if !ImageSize(imageBackgroundPath, &imgW, &imgH) {
        picGui.Destroy()
        return
    }

    monRatio := wMon / hMon
    imgRatio := imgW / imgH

    if (monRatio >= imgRatio) {
        newW := wMon, newH := Floor(imgH * (wMon / imgW))
        offsetX := 0, offsetY := (hMon - newH)//2
    } else {
        newH := hMon, newW := Floor(imgW * (hMon / imgH))
        offsetY := 0, offsetX := (wMon - newW)//2
    }

    picGui.AddPicture(Format("x{} y{} w{} h{} +Center", offsetX, offsetY, newW, newH), imageBackgroundPath)
    picGui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, wMon, hMon))

    ; картинка непрозрачна
    DllCall("SetLayeredWindowAttributes", "Ptr", picGui.Hwnd, "UInt", 0, "UChar", 0, "UInt", 0x02)

    guiImgList.Push(picGui)
}

; --- размеры изображения (без GDI+) ---
ImageSize(path, &w, &h) {
    w := h := 0
    hBitmap := LoadPicture(path, "G") ; гарантируем Bitmap
    if (hBitmap) {
        bm := Buffer(24, 0)
        if (DllCall("GetObject", "Ptr", hBitmap, "Int", 24, "Ptr", bm.Ptr)) {
            w := NumGet(bm, 4, "Int")
            h := NumGet(bm, 8, "Int")
        }
        DllCall("DeleteObject", "Ptr", hBitmap)
        return (w > 0 && h > 0)
    }
    return false
}

; ---------- монитор по точке ----------
GetMonitorIndex(px,py) {
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
        if (px>=l && px<r && py>=t && py<b)
            return A_Index
    }
    return MonitorGetPrimary()
}
