#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
;  Zen‑Mode v10.0  — рабочий Blur + картинки + корректный Alt‑Tab
; =============================================================

; ---------- НАСТРОЙКА ----------
global marginH        := 0.30
global marginV        := 0.05

; альтернативный режим
global marginH_2      := 0.35
global marginV_2      := 0.15

; хоткеи
global hotkeyList     := ["^!z", "F1"]
global hotkeyList_2   := ["F2"]

; выход по Esc
global enableEscExit  := true

; фон‑картинка
global enableImageBackground := true
global imageBackgroundPath   := "E:\\pic.jpg"

; слой‑цвет + blur
global bgColor        := "000000"   ; шестнадцатеричный без '#'
global bgAlpha        := 180        ; 0 (непрозр.) … 255 (прозр.)
global bgBlurStrength := 1          ; 0 = blur off, >0 = blur on

; слой AlwaysOnTop?
global overlayTopmost := true

; ---------- СЛУЖЕБНЫЕ ----------
global zen := false, savedWin := Map()

global guiBlur   := ""       ; верхний слой
global guiImgArr := []       ; массив картинок

global altPressed  := false
global needNewZen  := false
global prevHwnd    := 0

; =============================================================
;               РЕГИСТРАЦИЯ  HOTKEY'ев
; =============================================================
registerHotkeys() {
    Toggle1 := (*) => toggleZenMode(marginH,  marginV )
    Toggle2 := (*) => toggleZenMode(marginH_2, marginV_2)

    for k in hotkeyList
        Hotkey(k, Toggle1)
    for k in hotkeyList_2
        Hotkey(k, Toggle2)

    Hotkey("^!x", (*) => disableZenMode())
    if enableEscExit
        Hotkey("Esc", escExit)
}
registerHotkeys()

; =============================================================
;                          ALT + TAB
; =============================================================
~Alt:: altPressed := true

~Tab::{
    global zen, altPressed, needNewZen, prevHwnd
    if zen && altPressed {
        prevHwnd := WinGetID("A")
        disableZenMode()
        needNewZen := true
    }
}

~Alt Up::{
    global altPressed, needNewZen, prevHwnd
    altPressed := false
    if needNewZen {
        needNewZen := false
        Loop 30 {
            Sleep 50
            newHwnd := WinGetID("A")
            if (newHwnd != prevHwnd && newHwnd) {
                toggleZenMode()
                break
            }
        }
    }
}

escExit(*) {
    if zen
        disableZenMode()
}

; =============================================================
;                     ВКЛ / ВЫКЛ ZEN
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

    ; сохраняем состояние
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd)
    savedWin := Map("id",hwnd,"x",ox,"y",oy,"w",ow,"h",oh,"max",wasMax)
    if (wasMax = 1) {
        WinRestore(hwnd)
        Sleep 50
    }

    ; центрируем
    centerX := ox + ow//2, centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon, &mL, &mT, &mR, &mB)
    monW := mR - mL, monH := mB - mT

    newW := Round(monW * (1 - hMargin*2))
    newH := Round(monH * (1 - vMargin*2))
    newX := mL + Round(monW * hMargin)
    newY := mT + Round(monH * vMargin)
    WinMove(newX, newY, newW, newH, hwnd)

    ; создаём слои
    createBackdropLayers()

    WinSetAlwaysOnTop(1, hwnd)
    WinActivate(hwnd)
    zen := true
}

disableZenMode() {
    global zen, savedWin, guiBlur, guiImgArr
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
    for g in guiImgArr
        if IsObject(g)
            g.Destroy()
    guiImgArr := []

    zen := false
}

; =============================================================
;                   ШТОРКА  (per-monitor)
; =============================================================
createBackdropLayers() {
    global enableImageBackground, imageBackgroundPath

    ; 1) верхний слой — цвет + blur
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    createBlurOverlay(vx, vy, vw, vh)

    ; 2) картинки под ним
    if enableImageBackground && FileExist(imageBackgroundPath) {
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            createImageOverlay(l, t, r - l, b - t)
        }
    }
}

; слой цвета + blur через DWM
createBlurOverlay(x, y, w, h) {
    global guiBlur, bgColor, bgAlpha, bgBlurStrength, overlayTopmost
    if IsObject(guiBlur)
        guiBlur.Destroy()
    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    guiBlur := Gui(flags)
    guiBlur.BackColor := bgColor
    guiBlur.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))
    hwnd := guiBlur.Hwnd
    if (bgBlurStrength > 0) {
        p := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32"), "AStr", "SetWindowCompositionAttribute", "Ptr")
        if p {
            acc := Buffer(16), NumPut(4, acc, 0, "UInt")
            wcaSize := A_PtrSize=8?24:16, wca := Buffer(wcaSize)
            NumPut(19, wca, 0, "UInt"), NumPut(acc.Ptr, wca, A_PtrSize=8?8:4, "Ptr"), NumPut(acc.Size, wca, A_PtrSize=8?16:8, "UPtr")
            DllCall(p, "Ptr", hwnd, "Ptr", wca.Ptr)
        }
    }
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)
}

; картинка‑cover с сохранением пропорций
createImageOverlay(x, y, wMon, hMon) {
    global guiImgArr, imageBackgroundPath, overlayTopmost
    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    g := Gui(flags)
    if !ImageSize(imageBackgroundPath, &imgW, &imgH) { g.Destroy(); return }
    monRatio := wMon/hMon, imgRatio := imgW/imgH
    if (monRatio >= imgRatio) {
        newW := wMon
        newH := Floor(imgH * (wMon/imgW))
        offsetX := 0
        offsetY := (hMon - newH)//2
    } else {
        newH := hMon
        newW := Floor(imgW * (hMon/imgH))
        offsetX := (wMon - newW)//2
        offsetY := 0
    }
    g.AddPicture(Format("x{} y{} w{} h{} +Center", offsetX, offsetY, newW, newH), imageBackgroundPath)
    g.Show(Format("x{} y{} w{} h{} NoActivate", x, y, wMon, hMon))
    guiImgArr.Push(g)
}

; монитор по координате
GetMonitorIndex(px, py) {
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        if (px>=l && px<r && py>=t && py<b)
            return A_Index
    }
    return MonitorGetPrimary()
}
