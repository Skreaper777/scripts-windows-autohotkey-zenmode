#Requires AutoHotkey v2.0
#SingleInstance Force

; =====================
; Zen‑Mode v3.3.1 — bug‑fixed
; =====================
;   • Чёткий учёт marginH / marginV и padL/R/T/B
;   • overlayAlpha применяется ровно один раз ко всем зонам
;   • Клик по любой затемнённой GUI (WM_LBUTTONDOWN) = выход
;   • Исправлены скобки/область видимости — скрипт компилируется
; -----------------------------------------------------------

; ---------- настраиваемые параметры ----------
global marginH := 0.25   ; 0‑1 отступ слева/справа
global marginV := 0.15   ; 0‑1 отступ сверху/снизу

global overlayAlpha := 150 ; 0‑255 прозрачность (150 ≈ 60 %)

; Пиксельный «пэд» для точной юстировки затемнения
global padL := 8
global padR := 8
global padT := 6
global padB := 22

; Комбинации, включающие Zen‑режим
global hotkeyList := ["^!z", "^F11", "F8"]

; ---------- внутренние переменные ----------
global zen            := false     ; текущий режим
global savedWin       := Map()     ; координаты для отката
global overlayGuiArr  := []        ; массив гуёв‑шторок

; =====================================
; Горячие клавиши
; =====================================
ToggleZen(*) => toggleZenMode()
for hk in hotkeyList
    Hotkey(hk, ToggleZen)

Hotkey("^!x", (*) => forceOff())   ; аварийный выход

; =====================================
; Глобальный перехват клика по шторке
; =====================================
OnMessage(0x201, ClickOnOverlay)    ; WM_LBUTTONDOWN
ClickOnOverlay(wParam, lParam, msg, hwnd) {
    global zen, overlayGuiArr
    if !zen
        return
    for gui in overlayGuiArr
        if (hwnd = gui.Hwnd) {
            forceOff()
            return
        }
}

; =====================================
; Основной переключатель режима
; =====================================

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

    ; --- сохраняем исходные координаты / размеры
    WinGetPos(&ox, &oy, &ow, &oh, hwnd)
    savedWin := Map("id", hwnd, "x", ox, "y", oy, "w", ow, "h", oh)

    ; --- снимаем развёртывание и ждём отрисовки
    WinRestore("ahk_id " hwnd)
    Sleep 50

    ; --- расчёт новой геометрии
    screenW := SysGet(78), screenH := SysGet(79)
    newW := Round(screenW * (1 - marginH*2))
    newH := Round(screenH * (1 - marginV*2))
    newX := Round(screenW * marginH)
    newY := Round(screenH * marginV)

    ; --- позиционируем окно
    WinSetAlwaysOnTop(1, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)
    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

    ; --- строим затемнение вокруг окна
    buildOverlays(nx, ny, nw, nh, sw, sh) {
    global padL, padR, padT, padB, overlayGuiArr, overlayAlpha

    overlayGuiArr := []   ; очищаем список

    make(x, y, w, h) {
        global overlayGuiArr, overlayAlpha
        if (w <= 0 || h <= 0)
            return
        ovGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
        ovGui.BackColor := "Black"
        ovGui.Show("x" x " y" y " w" w " h" h " NoActivate")
        WinSetTransparent(overlayAlpha, ovGui.Hwnd)
        overlayGuiArr.Push(ovGui)
    }

    ; слева
    make(0, 0, nx + padL, sh)
    ; справа
    make(nx + nw - padR, 0, (sw - nx - nw) + padR, sh)
    ; сверху
    make(nx + padL, 0, nw - padL - padR, ny + padT)
    ; снизу
    make(nx + padL, ny + nh - padT, nw - padL - padR, (sh - ny - nh) + padB)
}
