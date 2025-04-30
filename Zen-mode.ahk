#Requires AutoHotkey v2.0
#SingleInstance Force

; ==========================
; Zen‑Mode — стабильная v4.1
; ==========================
;  • Раздельные marginH / marginV
;  • Персональные пэды padL/R/T/B
;  • overlayAlpha применяется ровно один раз ко *всем* шторкам
;  • Любое число hotkey'ев (см. hotkeyList)
;  • ЛКМ по затемнению мгновенно выключает режим
; ----------------------------------------------------------

; ---------- НАСТРОЙКА ----------
global marginH := 0.25      ; 0‑1 пустота слева/справа
global marginV := 0.05      ; 0‑1 пустота сверху/снизу

global overlayAlpha := 240  ; 0‑255 (150 ≈ 60 %)

global padL := 8, padR := 8, padT := 6, padB := 0

global hotkeyList := ["^!z", "^F11", "F8"] ; включение Zen

; ---------- ВНУТРЕННИЕ ----------
global zen            := false
global savedWin       := Map()    ; координаты для отката
global overlayGuiArr  := []       ; список гуёв‑шторок

; =========================================
;  ГОРЯЧИЕ КЛАВИШИ
; =========================================

ToggleZen(*) => toggleZenMode()
for hk in hotkeyList
    Hotkey(hk, ToggleZen)
Hotkey("^!x", (*) => disableZenMode()) ; аварийный выход

; =========================================
;  Ловим ЛКМ на шторке (WM_LBUTTONDOWN = 0x201)
; =========================================
OnMessage(0x201, HandleClick)
HandleClick(wParam, lParam, msg, hWnd) {
    global zen, overlayGuiArr
    if !zen
        return
    for oGui in overlayGuiArr
        if (hWnd = oGui.Hwnd) {
            disableZenMode()
            return
        }
}

; =========================================
;  ВКЛ / ВЫКЛ  ZEN‑режима
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

    ; ----- Сохраняем положение окна -----
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    savedWin := Map("id", hwnd, "x", ox, "y", oy, "w", ow, "h", oh)

    WinRestore("ahk_id " hwnd)
    Sleep 50

    ; ----- Расчёт новой геометрии -----
    screenW := SysGet(78), screenH := SysGet(79)
    newW := Round(screenW * (1 - marginH*2))
    newH := Round(screenH * (1 - marginV*2))
    newX := Round(screenW * marginH)
    newY := Round(screenH * marginV)

    ; ----- Перемещаем окно -----
    WinSetAlwaysOnTop(1, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)
    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

    ; ----- Строим затемнение -----
    buildOverlays(newX, newY, newW, newH, screenW, screenH)
    zen := true
}

; =========================================
;  ОТКЛЮЧЕНИЕ ZEN‑режима
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

    for oGui in overlayGuiArr
        oGui.Destroy()
    overlayGuiArr := []

    zen := false
}

; =========================================
;  СОЗДАНИЕ ШТОРОК  (без перекрытия)
; =========================================

createOverlayRect(x, y, w, h) {
    global overlayGuiArr, overlayAlpha
    if (w <= 0 || h <= 0)
        return
    oGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
    oGui.BackColor := "Black"
    oGui.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(overlayAlpha, oGui.Hwnd)
    overlayGuiArr.Push(oGui)
}

buildOverlays(nx, ny, nw, nh, sw, sh) {
    global padL, padR, padT, padB

    overlayGuiArr := []  ; очищаем

    ; слева
    createOverlayRect(0, 0, nx + padL, sh)
    ; справа
    createOverlayRect(nx + nw - padR, 0, (sw - nx - nw) + padR, sh)
    ; сверху
    createOverlayRect(nx + padL, 0, nw - padL - padR, ny + padT)
    ; снизу
    createOverlayRect(nx + padL, ny + nh - padT, nw - padL - padR, (sh - ny - nh) + padB)
}
