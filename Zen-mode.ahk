#Requires AutoHotkey v2.0
#SingleInstance Force

; =====================
; Zen-Mode v3.1
; =====================
;   • Раздельные отступы: marginH (лево/право) и marginV (верх/низ)
;   • Несколько хоткеев (см. hotkeyList)
;   • padL/R/T/B — тонкая настройка затемнения
;   • Клик по тёмной области выключает режим (фикс через скрытый Text-контрол)
; -----------------------------------------------------------

; ---------- настраиваемые параметры ----------
global marginH        := 0.25     ; доля (0‒1) слева/справа
global marginV        := 0.15     ; доля (0‒1) сверху/снизу

global overlayAlpha   := 150      ; 0‒255 (≈90 % затемнения)

; «Раздувание»/сжатие затемнения (в пикселях; + расширяет, ‒ сжимает)
global padL := 8
global padR := 8
global padT := 6
global padB := 22

; Горячие клавиши, активирующие Zen-Mode
global hotkeyList := ["^!z", "^F11", "F8"]  ; добавь свои сочетания

; ---------- внутренние ----------
global zen      := false
global savedWin := Map()

overlayIDs := ["L","R","T","B"]

; ---------- установка хоткеев ----------
ToggleZen(*) => toggleZenMode()
for hk in hotkeyList
    Hotkey(hk, ToggleZen)

Hotkey("^!x", (*) => forceOff()) ; аварийный выход

; =====================================
; Основной переключатель режима
; =====================================

toggleZenMode() {
    global zen, savedWin, marginH, marginV

    if !zen {
        ; ============== ВКЛЮЧЕНИЕ ==============
        hwnd := WinGetID("A")
        if !hwnd {
            TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
            return
        }

        ; --- Сохраняем исходное положение
        WinGetPos(&ox,&oy,&ow,&oh, hwnd)
        savedWin := Map("id", hwnd, "x", ox, "y", oy, "w", ow, "h", oh)

        ; --- Снимаем развёртывание
        WinRestore("ahk_id " hwnd)
        Sleep 50

        ; --- Вычисляем целевые координаты
        screenW := SysGet(78)
        screenH := SysGet(79)
        newW := Round(screenW * (1 - marginH*2))
        newH := Round(screenH * (1 - marginV*2))
        newX := Round(screenW * marginH)
        newY := Round(screenH * marginV)

        ; --- Делаем окно поверх и двигаем
        WinSetAlwaysOnTop(1, "ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
        WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

        ; --- Затемняем фон
        buildOverlays(newX, newY, newW, newH, screenW, screenH)
        zen := true
    } else {
        ; ============== ВЫКЛЮЧЕНИЕ ==============
        disableZenMode()
    }
}

; =====================================
; Экстренное выключение
; =====================================

forceOff(*) {
    TrayTip "Zen Mode", "Экстренное отключение", 1
    disableZenMode()
}

; =====================================
; Отключаем Zen-режим
; =====================================

disableZenMode() {
    global zen, savedWin, overlayIDs
    if !zen
        return

    hwnd := savedWin["id"]
    if WinExist("ahk_id " hwnd) {
        WinSetAlwaysOnTop(0, "ahk_id " hwnd)
        WinMove(savedWin["x"], savedWin["y"], savedWin["w"], savedWin["h"], "ahk_id " hwnd)
    }

    ; Уничтожаем оверлеи
    for n in overlayIDs
        if (gui := GuiGet("Overlay" n))
            gui.Destroy()

    zen := false
}

; =====================================
; Построение затемнения
; =====================================

buildOverlays(nx, ny, nw, nh, sw, sh) {
    global padL, padR, padT, padB

    createOverlay("L", 0, 0, nx + padL, sh)                                           ; слева
    createOverlay("R", nx + nw - padR, 0, (sw - (nx + nw)) + padR, sh)                 ; справа
    createOverlay("T", nx - padL, 0, nw + padL + padR, ny + padT)                      ; сверху
    createOverlay("B", nx - padL, ny + nh - padT, nw + padL + padR, (sh - (ny + nh)) + padB) ; снизу
}

createOverlay(name, x, y, w, h) {
    global overlayAlpha
    if (w<=0 || h<=0)
        return

    GuiObj := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    GuiObj.BackColor := "Black"

    ; Полностью прозрачный Text-контрол для захвата клика
    cover := GuiObj.AddText("x0 y0 w" w " h" h " BackgroundTrans")
    cover.OnEvent("Click", forceOff)   ; клик = выход

    GuiObj.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(overlayAlpha, GuiObj.Hwnd)
    GuiSet("Overlay" . name, GuiObj)
}

; ---------- Хелперы ----------

GuiMap := Map()
GuiSet(name, obj) => GuiMap[name] := obj
GuiGet(name)      => GuiMap.Has(name) ? GuiMap[name] : ""