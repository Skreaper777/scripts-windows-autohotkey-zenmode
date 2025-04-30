#Requires AutoHotkey v2.0
#SingleInstance Force

; ===========================================
; Zen‑Mode v6.2  ―  full‑overlay + multi‑monitor
; ===========================================
;  • Центрирует активное окно внутри своего монитора (marginH / marginV)
;  • Одна полноэкранная полупрозрачная шторка накрывает 100 % виртуального десктопа
;  • Активное окно поднимается поверх шторки → закруглённые углы «чисты»
;  • Возврат maximized/normal при выключении
;  • ЛКМ по шторке или повторный хоткей выключают режим
; -------------------------------------------

; ---------- НАСТРОЙКА ----------
global marginH := 0.25      ; 0‑1 пустота слева/справа
global marginV := 0.10      ; 0‑1 пустота сверху/снизу
global overlayAlpha := 240  ; 0‑255 (240 ≈ 94 %)
global hotkeyList := ["^!z", "^F11", "F8", "!F2"]

; ---------- ВНУТРЕННИЕ ----------
global zen       := false        ; статус режима
global savedWin  := Map()        ; положение/размер/был Max
global overlayGui := ""          ; GUI‑шторка

; ---------- ГОРЯЧИЕ КЛАВИШИ ----------
ToggleZen(*) => toggleZenMode()
for hk in hotkeyList
    Hotkey(hk, ToggleZen)
Hotkey("^!x", (*) => disableZenMode())    ; аварийный выход

; ---------- ЛКМ по шторке ----------
OnMessage(0x201, OnOverlayClick)   ; WM_LBUTTONDOWN
OnOverlayClick(w,l,m,hwnd) {
    global zen, overlayGui
    if zen && IsObject(overlayGui) && (hwnd = overlayGui.Hwnd)
        disableZenMode()
}

; ===================================
;      ВКЛ / ВЫКЛ  ZEN‑режима
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
    wasMax := WinGetMinMax(hwnd) ; 1 = maximized
    savedWin := Map("id", hwnd, "x", ox, "y", oy, "w", ow, "h", oh, "max", wasMax)

    if (wasMax = 1)
        WinRestore("ahk_id " hwnd)
    Sleep 50

    ; --- монитор по центру окна ---
    centerX := ox + ow//2,   centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon, &mL,&mT,&mR,&mB)
    monW := mR - mL,   monH := mB - mT

    newW := Round(monW * (1 - marginH*2))
    newH := Round(monH * (1 - marginV*2))
    newX := mL + Round(monW * marginH)
    newY := mT + Round(monH * marginV)

    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

    ; --- шторка на весь virtual desktop ---
    virtL := SysGet(76),  virtT := SysGet(77)
    virtW := SysGet(78),  virtH := SysGet(79)
    createFullOverlay(virtL, virtT, virtW, virtH)

    ; --- поднимаем окно поверх шторки ---
    WinSetAlwaysOnTop(1, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)

    zen := true
}

; ===================================
;      ВЫКЛ  ZEN‑режима
; ===================================

disableZenMode() {
    global zen, savedWin, overlayGui
    if !zen
        return

    hwnd := savedWin["id"]
    if WinExist("ahk_id " hwnd) {
        if (savedWin["max"] = 1)
            WinMaximize("ahk_id " hwnd)
        else
            WinMove(savedWin["x"], savedWin["y"], savedWin["w"], savedWin["h"], "ahk_id " hwnd)
        WinSetAlwaysOnTop(0, "ahk_id " hwnd)
    }

    if IsObject(overlayGui)
        overlayGui.Destroy()
    overlayGui := ""

    zen := false
}

; ===================================
;      ОДНА  ПОЛНОЭКРАННАЯ  ШТОРКА
; ===================================

createFullOverlay(x,y,w,h) {
    global overlayGui, overlayAlpha

    if IsObject(overlayGui)
        overlayGui.Destroy()

    overlayGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
    overlayGui.BackColor := "Black"
    overlayGui.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(overlayAlpha, overlayGui.Hwnd)
}

; ---------- индекс монитора по точке ----------
GetMonitorIndex(px,py) {
    cnt := MonitorGetCount()
    Loop cnt {
        idx := A_Index
        MonitorGetWorkArea(idx, &l,&t,&r,&b)
        if (px>=l && px<r && py>=t && py<b)
            return idx
    }
    return MonitorGetPrimary()
}
