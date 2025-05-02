#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================
;  Zen-Mode v6.6-blur  — Alt-Tab «handoff» + DWM blur
; =========================================
;  • F1 / ^!z / ^F11 / F8 / !F2  → вкл/выкл Zen.
;  • Alt↓ + Tab снимает Zen, Alt↑ включает его на новом окне.
;  • Шторка: полноэкранная, размытая, полупрозрачная.
;  • Поддержка maximized и нескольких мониторов.
; -----------------------------------------

; ---------- НАСТРОЙКА ----------
global marginH := 0.30
global marginV := 0.05
global overlayAlpha := 240            ; 0-255 (≈94 %)

global hotkeyList := ["F1"]

; ---------- СЛУЖЕБНЫЕ ----------
global zen             := false
global savedWin        := Map()
global overlayGui      := ""
global wasZenDuringAlt := false

; ---------- ГОРЯЧИЕ КЛАВИШИ ----------
ToggleZen(*) => toggleZenMode()
for hk in hotkeyList
    Hotkey(hk, ToggleZen)
Hotkey("^!x", (*) => disableZenMode())      ; аварийный выход

; --- Alt-Tab hand-off ---
~Alt:: {
    global zen, wasZenDuringAlt
    if zen {
        wasZenDuringAlt := true
    } else {
        wasZenDuringAlt := false
    }
}

~*Tab:: {
    global zen, wasZenDuringAlt
    if GetKeyState("Alt", "P") && zen {
        wasZenDuringAlt := true
        disableZenMode()
        Sleep 50
    }
}

~Alt Up:: {
    global wasZenDuringAlt
    if wasZenDuringAlt {
        wasZenDuringAlt := false
        Sleep 75
        toggleZenMode()
    }
}

; --- клик по шторке ---
OnMessage(0x201, OnOverlayClick)            ; WM_LBUTTONDOWN
OnOverlayClick(w,l,m,hwnd) {
    global zen, overlayGui
    if zen && IsObject(overlayGui) && (hwnd = overlayGui.Hwnd)
        disableZenMode()
}

; ===================================
;              ВКЛ  ZEN
; ===================================

toggleZenMode() {
    global zen, savedWin, marginH, marginV

    if zen {
        disableZenMode()
        return
    }

    hwnd := WinGetID("A")
    if !hwnd {
        TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
        return
    }

    ; --- сохраняем состояние ---
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd)            ; 1 = maximized
    savedWin := Map("id",hwnd, "x",ox,"y",oy,"w",ow,"h",oh,"max",wasMax)

    if (wasMax = 1)
        WinRestore(hwnd)
    Sleep 50

    ; --- центрируем ---
    centerX := ox + ow//2,  centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon,&mL,&mT,&mR,&mB)
    monW := mR-mL,  monH := mB-mT

    newW := Round(monW*(1-marginH*2))
    newH := Round(monH*(1-marginV*2))
    newX := mL + Round(monW*marginH)
    newY := mT + Round(monH*marginV)
    WinMove(newX,newY,newW,newH, hwnd)

    ; --- шторка на весь виртуальный стол ---
    createBlurOverlay(SysGet(76), SysGet(77), SysGet(78), SysGet(79))

    WinSetAlwaysOnTop(1, hwnd)              ; окно поверх шторки
    WinActivate(hwnd)
    zen := true
}

; ===================================
;              ВЫКЛ  ZEN
; ===================================

disableZenMode() {
    global zen, savedWin, overlayGui
    if !zen || !savedWin.Count
        return

    hwnd := savedWin["id"]

    if WinExist(hwnd) {
        try {
            if (savedWin["max"] = 1)
                WinMaximize(hwnd)
            else
                WinMove(savedWin["x"], savedWin["y"]
                       ,savedWin["w"], savedWin["h"], hwnd)
            WinSetAlwaysOnTop(0, hwnd)
        }
    }
    if IsObject(overlayGui)
        overlayGui.Destroy()
    overlayGui := ""
    zen := false
}

; ===================================
;         РАЗМЫТАЯ ШТОРКА (DWM)
; ===================================

createBlurOverlay(x,y,w,h) {
    global overlayGui, overlayAlpha

    if IsObject(overlayGui)
        overlayGui.Destroy()

    overlayGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    overlayGui.BackColor := "000000"
    overlayGui.Show("x" x " y" y " w" w " h" h " NoActivate")
    hwnd := overlayGui.Hwnd

    ; --- ACCENT_POLICY ---
    acc := Buffer(16, 0)
    NumPut("UInt", 4, acc, 0)               ; ACCENT_ENABLE_BLURBEHIND

    ; --- WCA_DATA ---
    wca := Buffer(A_PtrSize=8?24:16, 0)
    NumPut("UInt", 19,        wca, 0)       ; WCA_ACCENT_POLICY
    NumPut("Ptr",  acc.Ptr,   wca, A_PtrSize=8?8:4)
    NumPut("UPtr", acc.Size,  wca, A_PtrSize=8?16:8)

    DllCall("user32\SetWindowCompositionAttribute"
        , "Ptr", hwnd, "Ptr", wca.Ptr)

    DllCall("SetLayeredWindowAttributes"
        , "Ptr", hwnd, "UInt", 0
        , "UChar", overlayAlpha, "UInt", 0x02) ; LWA_ALPHA
}

; ---------- монитор по точке ----------
GetMonitorIndex(px,py) {
    max := MonitorGetCount()
    Loop max {
        MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
        if (px>=l && px<r && py>=t && py<b)
            return A_Index
    }
    return MonitorGetPrimary()
}
