#Requires AutoHotkey v2.0
#SingleInstance Force

; ==========================
; Zen‑Mode — мульти‑мониторная **v5.2**
; ==========================
;  • Центрирует активное окно относительно того монитора, где оно находится
;  • Затемняет ВСЮ виртуальную рабочую поверхность (все дисплеи)
;  • marginH / marginV — отступы, padL/R/T/B — юстировка краёв
;  • overlayAlpha применяется ко всем шторкам
;  • ЛКМ по затемнению мгновенно отключает режим
; ----------------------------------------------------------

; ---------- НАСТРОЙКА ----------
global marginH := 0.25      ; 0‑1 пустота слева/справа
global marginV := 0.05      ; 0‑1 пустота сверху/снизу

global overlayAlpha := 240  ; 0‑255 (≈ 94 %)

global padL := 8, padR := 8, padT := 6, padB := 8

global hotkeyList := ["^!z", "^F11", "F8", "!F2"] ; включение Zen

; ---------- ВНУТРЕННИЕ ----------
global zen := false
global savedWin := Map()
global overlayGuiArr := []

; ---------- ГОРЯЧИЕ КЛАВИШИ ----------
ToggleZen(*) => toggleZenMode()
for hk in hotkeyList
    Hotkey(hk, ToggleZen)
Hotkey("^!x", (*) => disableZenMode()) ; аварийный выход

; ---------- Ловим ЛКМ на шторке ----------
OnMessage(0x201, HandleClick) ; WM_LBUTTONDOWN
HandleClick(wParam, lParam, msg, hWnd) {
    global zen, overlayGuiArr
    if !zen
        return
    for g in overlayGuiArr
        if (hWnd = g.Hwnd) {
            disableZenMode()
            return
        }
}

; =========================================
;   ВКЛ / ВЫКЛ  ZEN‑режима
; =========================================

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

    ; --- сохраняем позицию/размер ---
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    savedWin := Map("id", hwnd, "x", ox, "y", oy, "w", ow, "h", oh)

    WinRestore("ahk_id " hwnd)
    Sleep 50

    ; --- выбираем монитор по центру окна ---
    centerX := ox + ow//2
    centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon, &mL,&mT,&mR,&mB)
    monW := mR - mL
    monH := mB - mT

    newW := Round(monW * (1 - marginH*2))
    newH := Round(monH * (1 - marginV*2))
    newX := mL + Round(monW * marginH)
    newY := mT + Round(monH * marginV)

    ; --- позиционируем окно ---
    WinSetAlwaysOnTop(1, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)
    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

        ; --- затемняем всё остальное (учёт смещённого виртуального экрана) ---
    virtL := SysGet(76), virtT := SysGet(77)
    virtW := SysGet(78), virtH := SysGet(79)
    buildOverlays(newX, newY, newW, newH, virtL, virtT, virtW, virtH)

    zen := true
}

; =========================================
;   ОТКЛЮЧЕНИЕ  ZEN‑режима
; =========================================

disableZenMode() {
    global zen, savedWin, overlayGuiArr
    if !zen
        return

    hwnd := savedWin["id"]
    if WinExist("ahk_id " hwnd) {
        WinSetAlwaysOnTop(0, "ahk_id " hwnd)
        WinMove(savedWin["x"], savedWin["y"], savedWin["w"], savedWin["h"], "ahk_id " hwnd)
    }

    for g in overlayGuiArr
        g.Destroy()
    overlayGuiArr := []

    zen := false
}

; =========================================
;   ШТОРКИ
; =========================================

createOverlayRect(x, y, w, h) {
    global overlayGuiArr, overlayAlpha
    if (w<=0 || h<=0)
        return
    o := Gui("-Caption +AlwaysOnTop +ToolWindow")
    o.BackColor := "Black"
    o.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(overlayAlpha, o.Hwnd)
    overlayGuiArr.Push(o)
}

buildOverlays(wx, wy, ww, wh, vL, vT, vW, vH) {
    global overlayGuiArr, padL, padR, padT, padB

    for g in overlayGuiArr
        g.Destroy()
    overlayGuiArr := []

    ; расчёты
    leftX   := vL
    leftW   := (wx - vL) + padL

    rightX  := wx + ww - padR
    rightW  := (vL + vW) - rightX

    topX    := wx - padL
    topY    := vT
    topW    := ww + padL + padR
    topH    := (wy - vT) + padT

    botX    := wx - padL
    botY    := wy + wh - padB
    botW    := ww + padL + padR
    botH    := (vT + vH) - botY

    ; создаём: проверяем положительные размеры
    createOverlayRect(leftX, vT, leftW, vH)        ; слева
    createOverlayRect(rightX, vT, rightW, vH)       ; справа
    createOverlayRect(topX, topY, topW, topH)       ; сверху
    createOverlayRect(botX, botY, botW, botH)       ; снизу
}

; ---------- определить монитор по точке ----------
GetMonitorIndex(x, y) {
    count := MonitorGetCount()
    Loop count {
        idx := A_Index
        MonitorGetWorkArea(idx, &l,&t,&r,&b)
        if (x>=l && x<r && y>=t && y<b)
            return idx
    }
    return MonitorGetPrimary()
}
