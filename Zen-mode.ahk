#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================
;  Zen-Mode v6.5-blur  — Alt-Tab «handoff» + DWM blur
; =========================================
;  • F1 / ^!z / ^F11 / F8 / !F2  → вкл/выкл Zen-режим.
;  • Пока Zen активен: Alt↓ снимает Zen, Alt↑ включает на новом окне.
;  • Шторка: полноэкранная, полупрозрачная, с размытой подложкой DWM.
;  • Поддержка maximized, multi-monitor (SysGet 76-79).
; -----------------------------------------

; ---------- НАСТРОЙКА ----------
global marginH := 0.25        ; пустота слева/справа (0-1)
global marginV := 0.10        ; пустота сверху/снизу (0-1)
global overlayAlpha := 240    ; 0-255 (≈94 %)

global hotkeyList := ["^!z", "^F11", "F8", "!F2", "F1"]

; ---------- ВНУТРЕННИЕ ----------
global zen             := false   ; статус Zen
global savedWin        := Map()   ; координаты + был Max
global overlayGui      := ""      ; GUI-шторка
global wasZenDuringAlt := false   ; флаг Alt-Tab handoff

; ---------- ГОРЯЧИЕ КЛАВИШИ ----------
ToggleZen(*) => toggleZenMode()
for hk in hotkeyList
    Hotkey(hk, ToggleZen)
Hotkey("^!x", (*) => disableZenMode())    ; аварийный выход

; --- Alt-Tab handoff ---
~Alt:: {
    global zen, wasZenDuringAlt
    if zen {
        wasZenDuringAlt := true
        disableZenMode()
    } else
        wasZenDuringAlt := false
}

~Alt Up:: {
    global wasZenDuringAlt
    if wasZenDuringAlt {
        wasZenDuringAlt := false
        Sleep 75
        toggleZenMode()
    }
}

; --- ЛКМ по шторке ---
OnMessage(0x201, OnOverlayClick)          ; WM_LBUTTONDOWN
OnOverlayClick(w,l,m,hwnd) {
    global zen, overlayGui
    if zen && IsObject(overlayGui) && (hwnd = overlayGui.Hwnd)
        disableZenMode()
}

; ===================================
;          ВКЛ / ВЫКЛ  ZEN
; ===================================

toggleZenMode() {
    global zen, savedWin, marginH, marginV, overlayGui

    if zen {
        disableZenMode()
        return
    }

    hwnd := WinGetID("A")
    if !hwnd {
        TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
        return
    }

    ; --- сохраняем состояние окна ---
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd)          ; 1 = maximized
    savedWin := Map("id",hwnd,"x",ox,"y",oy,"w",ow,"h",oh,"max",wasMax)

    if (wasMax = 1)
        WinRestore(hwnd)
    Sleep 50

    ; --- центрируем внутри монитора ---
    centerX := ox + ow//2,  centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon, &mL,&mT,&mR,&mB)
    monW := mR - mL,  monH := mB - mT

    newW := Round(monW * (1 - marginH*2))
    newH := Round(monH * (1 - marginV*2))
    newX := mL + Round(monW * marginH)
    newY := mT + Round(monH * marginV)

    WinMove(newX, newY, newW, newH, hwnd)

    ; --- размытaя шторка ---
    createBlurOverlay(SysGet(76), SysGet(77), SysGet(78), SysGet(79))

    WinSetAlwaysOnTop(1, hwnd)            ; ← правильный порядок аргументов
    WinActivate(hwnd)
    zen := true
}

; ===================================
;              ВЫКЛ  ZEN
; ===================================

disableZenMode() {
    global zen, savedWin, overlayGui
    if !zen
        return

    hwnd := savedWin.id
    if WinExist(hwnd) {
        Try {
            if (savedWin.max = 1)
                WinMaximize(hwnd)
            else
                WinMove(savedWin.x, savedWin.y, savedWin.w, savedWin.h, hwnd)
            WinSetAlwaysOnTop(0, hwnd)
        }
    }

    if IsObject(overlayGui)
        overlayGui.Destroy()
    overlayGui := ""
    zen := false
}

; ===================================
;        РАЗМЫТАЯ ШТОРКА (DWM)
; ===================================

createBlurOverlay(x, y, w, h) {
    global overlayGui, overlayAlpha

    if IsObject(overlayGui)
        overlayGui.Destroy()

    overlayGui := Gui("-Caption +ToolWindow +LastFound")
    overlayGui.BackColor := "000000"
    overlayGui.Show("x" x " y" y " w" w " h" h " NoActivate")
    hwnd := overlayGui.Hwnd

    ; ---------- ACCENT_POLICY ----------
    acc := Buffer(16, 0)
    NumPut("UInt", 4, acc, 0)                 ; ACCENT_ENABLE_BLURBEHIND = 4

    ; ---------- WINDOWCOMPOSITIONATTRIBDATA ----------
    wca := Buffer(A_PtrSize=8?24:16, 0)
    NumPut("UInt", 19,         wca, 0)        ; WCA_ACCENT_POLICY
    NumPut("Ptr",  acc.Ptr,    wca, A_PtrSize=8?8:4)
    NumPut("UPtr", acc.Size,   wca, A_PtrSize=8?16:8)

    ; ---------- применяем размытие ----------
    DllCall("user32\SetWindowCompositionAttribute"
        , "Ptr", hwnd
        , "Ptr", wca.Ptr)

    ; ---------- полупрозрачность ----------
    DllCall("SetLayeredWindowAttributes"
        , "Ptr", hwnd, "UInt", 0
        , "UChar", overlayAlpha, "UInt", 0x02) ; LWA_ALPHA
}

; ---------- индекс монитора по точке ----------
GetMonitorIndex(px,py) {
    cnt := MonitorGetCount()
    Loop cnt {
        MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
        if (px>=l && px<r && py>=t && py<b)
            return A_Index
    }
    return MonitorGetPrimary()
}
