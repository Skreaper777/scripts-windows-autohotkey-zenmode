#Requires AutoHotkey v2.0
#SingleInstance Force

; ======================================
; Zen‑Mode — multi‑monitor v6.1 (full‑overlay)
; ======================================
; • Центрирует активное окно внутри СВОЕГО монитора (marginH / marginV)
; • Одна полноэкранная полупрозрачная шторка закрывает ВСЮ виртуальную область;
;   активное окно поднимается поверх, так что скруглённые углы не видят фон.
; • Запоминает, было ли окно развёрнуто; возвращает исходное состояние.
; • Любое число дисплеев, поддержка отрицательных координат.
; • Горячие клавиши перечислены в hotkeyList; ЛКМ по шторке или повторный хоткей выключают.
; ======================================

; ---------- НАСТРОЙКА ----------
global marginH := 0.25      ; 0‑1 пустота слева/справа
global marginV := 0.10      ; 0‑1 пустота сверху/снизу

global overlayAlpha := 240  ; 0‑255 степень затемнения (240 ≈ 94 %)

global hotkeyList := ["^!z", "^F11", "F8", "!F2"]

; ---------- ВНУТРЕННИЕ ----------
global zen := false               ; статус Zen‑режима
global savedWin := Map()          ; исходные координаты + был ли Max
global overlayGui := ""           ; единственная GUI‑шторка

; ---------- ГОРЯЧИЕ КЛАВИШИ ----------
ToggleZen(*) => toggleZenMode()
for hk in hotkeyList
    Hotkey(hk, ToggleZen)
Hotkey("^!x", (*) => disableZenMode()) ; аварийный выход

; ---------- ЛКМ по шторке ----------
OnMessage(0x201, LButtonOnOverlay) ; WM_LBUTTONDOWN
LButtonOnOverlay(w,l,m,hwnd) {
    global zen, overlayGui
    if zen && (hwnd = overlayGui.Hwnd)
        disableZenMode()
}

; =========================================
;   ВКЛ / ВЫКЛ  ZEN‑режима
; =========================================

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

    ; --- вычисляем геометрию относительно текущего монитора ---
    centerX := ox + ow//2, centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon, &mL,&mT,&mR,&mB)
    monW := mR - mL,  monH := mB - mT

    newW := Round(monW * (1 - marginH*2))
    newH := Round(monH * (1 - marginV*2))
    newX := mL + Round(monW * marginH)
    newY := mT + Round(monH * marginV)

    WinActivate("ahk_id " hwnd)("ahk_id " hwnd)
    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

    ; --- создаём одну полноэкранную шторку ---
    virtL := SysGet(76), virtT := SysGet(77)
    virtW := SysGet(78), virtH := SysGet(79)
    createFullOverlay(virtL, virtT, virtW, virtH)

    ; поднимаем окно над шторкой
    WinSetAlwaysOnTop(1, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)

    ; поднимаем окно снова поверх шторки
    WinActivate("ahk_id " hwnd)
    zen := true
}

; =========================================
;   ВЫКЛ  ZEN‑режима
; =========================================

disableZenMode() {
    global zen, savedWin, overlayGui
    if !zen
        return

    hwnd := savedWin["id"]
    if WinExist("ahk_id " hwnd) {
        WinSetAlwaysOnTop(0, "ahk_id " hwnd)
        if (savedWin["max"] = 1)
            WinMaximize("ahk_id " hwnd)
        else
            WinMove(savedWin["x"], savedWin["y"], savedWin["w"], savedWin["h"], "ahk_id " hwnd)
    }

    if IsObject(overlayGui)
        overlayGui.Destroy()
    overlayGui := ""

    zen := false
}

; =========================================
;   ОДНА ПОЛНОЭКРАННАЯ ШТОРКА
; =========================================

createFullOverlay(vL,vT,vW,vH) {
    global overlayGui, overlayAlpha

    if IsObject(overlayGui)
        overlayGui.Destroy()

    overlayGui := Gui("-Caption +ToolWindow")
    overlayGui.BackColor := "Black"
    overlayGui.Show("x" vL " y" vT " w" vW " h" vH " NoActivate")
    WinSetTransparent(overlayAlpha, overlayGui.Hwnd)
}

; ---------- индекс монитора по точке ----------
GetMonitorIndex(x,y) {
    cnt := MonitorGetCount()
    Loop cnt {
        idx := A_Index
        MonitorGetWorkArea(idx, &l,&t,&r,&b)
        if (x>=l && x<r && y>=t && y<b)
            return idx
    }
    return MonitorGetPrimary()
}
