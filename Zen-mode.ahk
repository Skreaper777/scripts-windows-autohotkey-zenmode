#Requires AutoHotkey v2.0
#SingleInstance Force

; =====================
; Zen‑Mode v2.2 (param‑fix)
; =====================
;   • Поля по 25 % от границ текущего монитора
;   • Окно строго по центру (корректный порядок параметров WinMove)
;   • 90 % затемнение вне рабочей области
;
;   Ctrl + Alt + Z  — включить / выключить
;   Ctrl + Alt + X  — аварийное выключение
; -----------------------------------------------------------

global zen            := false            ; текущий режим
global savedWin       := Map()            ; координаты для отката
global margin         := 0.25             ; 25 % рамка
global overlayAlpha   := 230              ; 0‑255 ≈ 90 % затемнение

overlayIDs := ["L","R","T","B"]         ; имена оверлеев

; -----------------------
; Горячие клавиши
; -----------------------

^!z:: toggleZenMode()
^!x:: forceOff()

; -----------------------
; Переключатель режима
; -----------------------

toggleZenMode() {
    global zen, savedWin, margin

    if !zen {
        ; ================= ВКЛЮЧЕНИЕ =================
        hwnd := WinGetID("A")
        if !hwnd {
            TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
            return
        }

        ; --- Сохраняем исходное положение
        WinGetPos(&ox,&oy,&ow,&oh, hwnd)
        savedWin := Map("id", hwnd, "x", ox, "y", oy, "w", ow, "h", oh)

        ; --- Снимаем развёртывание, если было
        WinRestore("ahk_id " hwnd)
        Sleep 50

        ; --- Вычисляем целевые координаты
        screenW := SysGet(78)      ; ширина виртуального экрана
        screenH := SysGet(79)      ; высота
        newW    := Round(screenW * (1 - margin*2)) ; 50 %
        newH    := Round(screenH * (1 - margin*2)) ; 50 %
        newX    := Round(screenW * margin)         ; 25 %
        newY    := Round(screenH * margin)         ; 25 %

        ; --- Делаем окно поверх и двигаем
        WinSetAlwaysOnTop(1, "ahk_id " hwnd)
        WinActivate("ahk_id " hwnd)
        WinMove(newX, newY, newW, newH, "ahk_id " hwnd)   ; ← порядок: X,Y,W,H,WinTitle

        ; --- Затемняем фон
        buildOverlays(newX, newY, newW, newH, screenW, screenH)
        zen := true
    } else {
        ; ================= ВЫКЛЮЧЕНИЕ =================
        disableZenMode()
    }
}

; -----------------------
; Экстренное выключение
; -----------------------

forceOff() {
    TrayTip "Zen Mode", "Экстренное отключение", 1
    disableZenMode()
}

; -----------------------
; Отключаем Zen‑режим
; -----------------------

disableZenMode() {
    global zen, savedWin

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

; -----------------------
; Затемнение рабочей зоны
; -----------------------

buildOverlays(nx, ny, nw, nh, sw, sh) {
    createOverlay("L", 0,        0,  nx,       sh)            ; слева
    createOverlay("R", nx+nw,    0,  sw-(nx+nw), sh)          ; справа
    createOverlay("T", nx,       0,  nw,       ny)            ; сверху
    createOverlay("B", nx,  ny+nh,  nw,  sh-(ny+nh))          ; снизу
}

createOverlay(name, x, y, w, h) {
    if (w<=0 || h<=0)
        return

    GuiObj := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    GuiObj.BackColor := "Black"
    GuiObj.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(overlayAlpha, GuiObj.Hwnd)
    GuiSet("Overlay" . name, GuiObj)
}

; -----------------------
; Хелперы для хранения GUI
; -----------------------

GuiMap := Map()
GuiSet(name, obj) => GuiMap[name] := obj
GuiGet(name)      => GuiMap.Has(name) ? GuiMap[name] : ""
