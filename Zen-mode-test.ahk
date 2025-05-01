#Requires AutoHotkey v2.0
#SingleInstance Force

; ---------- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ----------
global marginH := 0.30

global marginV := 0.05

global marginH_2 := 0.35

global marginV_2 := 0.15

global hotkeyList := ["^!z","F1"]

global hotkeyList_2 := ["F2"]

global enableEscExit := true

global enableImageBackground := true

global imageBackgroundPath := "E:\pic.jpg"

global overlayTopmost := false

global bgColor := "000000"

global bgAlpha := 250

global bgBlurStrength := 8

global zen := false

global savedWin := Map()

global guiBlur := ""

global guiImgList := []

global altPressed := false

global wasZenDuringAltTab := false


; =============================================================
;  Zen-Mode v8.6 — обновлённая версия с исправлением фоновой картинки и синтаксисом ActionHotkey v2
; =============================================================

; =============================================================
;                 РЕГИСТРАЦИЯ HOTKEY'ев
; =============================================================
registerHotkeys() {
    Toggle1 := (*) => toggleZenMode(marginH, marginV)
    Toggle2 := (*) => toggleZenMode(marginH_2, marginV_2)

    for hkKey in hotkeyList
        Hotkey(hkKey, Toggle1)
    for hkKey in hotkeyList_2
        Hotkey(hkKey, Toggle2)

    Hotkey("^!x", (*) => disableZenMode())
    if enableEscExit
        Hotkey("*Esc", escExit)
}
registerHotkeys()

; =============================================================
;                         ALT + TAB
; =============================================================
~Alt:: altPressed := true
~Alt Up::{
    global altPressed, wasZenDuringAltTab
    altPressed := false
    if wasZenDuringAltTab {
        wasZenDuringAltTab := false
        Sleep 120
        toggleZenMode()
    }
}
~Tab::{
    global zen, altPressed
    if zen && altPressed {
        wasZenDuringAltTab := true
        disableZenMode()
    }
}

escExit(*){
    global zen
    if zen
        disableZenMode()
}

; =============================================================
;                ВКЛ / ВЫКЛ ZEN
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
    if (wasMax = 1)
{
    WinRestore(hwnd)
    Sleep 50
}
    centerX := ox + ow//2, centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon,&mL,&mT,&mR,&mB)
    monW := mR - mL, monH := mB - mT
    newW := Round(monW * (1 - hMargin * 2))
    newH := Round(monH * (1 - vMargin * 2))
    newX := mL + Round(monW * hMargin)
    newY := mT + Round(monH * vMargin)
    WinMove(newX, newY, newW, newH, hwnd)
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
    for ref in guiImgList
        if IsObject(ref)
            ref.Destroy()
    guiImgList := []
    zen := false
}

; =============================================================
;                  ШТОРКА (по мониторам)
; =============================================================
createBackdropLayers() {
    global enableImageBackground, imageBackgroundPath
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    createBlurOverlay(vx, vy, vw, vh)
    if enableImageBackground && FileExist(imageBackgroundPath) {
        loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
            createImageOverlay(l, t, r - l, b - t)
        }
    }
}

createBlurOverlay(x,y,w,h) {
    global guiBlur, bgColor, bgAlpha, bgBlurStrength, overlayTopmost
    if IsObject(guiBlur)
        guiBlur.Destroy()
    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    guiBlur := Gui(flags)
    guiBlur.BackColor := bgColor
    ; Показываем окно без дополнительных контролов
    guiBlur.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))
    ; Клик по окну отключает Zen Mode
    guiBlur.OnEvent("Click", Func("disableZenMode"))
    hwnd := guiBlur.Hwnd
    ex := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "Ptr") | 0x80000
    DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "Ptr", ex)
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)
    if bgBlurStrength > 0 {
        p := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32"), "AStr", "SetWindowCompositionAttribute", "Ptr")
        if p {
            acc := Buffer(16)
            NumPut(4, acc, 0, "UInt"), NumPut(bgBlurStrength, acc, 4, "UInt")
            alpha := 255 - bgAlpha
            rgb := "0x" SubStr(bgColor,5,2) SubStr(bgColor,3,2) SubStr(bgColor,1,2)
            NumPut((alpha<<24)|(NumGet(DllCall("StrPtr", "Str", rgb), "UInt")&0xFFFFFF), acc, 8, "UInt")
            wca := Buffer(A_PtrSize=8?24:16)
            NumPut(19, wca, 0, "UInt"), NumPut(acc.Ptr, wca, A_PtrSize=8?8:4, "Ptr"), NumPut(acc.Size, wca, A_PtrSize=8?16:8, "UPtr")
            DllCall(p, "Ptr", hwnd, "Ptr", wca.Ptr)
        }
    }
}

createImageOverlay(x,y,w,h) {
    global guiImgList, imageBackgroundPath, bgAlpha, overlayTopmost
    if !FileExist(imageBackgroundPath)
        return
    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    imgGui := Gui(flags)
    imgGui.AddPicture(Format("x0 y0 w{} h{} +Center", w, h), imageBackgroundPath)
    imgGui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))
    DllCall("SetLayeredWindowAttributes", "Ptr", imgGui.Hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)
    guiImgList.Push(imgGui)
}

GetMonitorIndex(px,py) {
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
        if px>=l && px<r && py>=t && py<b
            return A_Index
    }
    return MonitorGetPrimary()
}

Shutdown(*) {
    global GdipShutdown, IsFunc
    if IsFunc("GdipShutdown")
        GdipShutdown()
    ExitApp
}
