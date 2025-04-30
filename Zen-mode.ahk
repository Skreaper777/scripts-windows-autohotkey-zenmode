#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================
; Zen-Mode v7.1 — авто-переключение через WinEventHook
; =========================================
; • Горячие клавиши включения/выключения: ^!z, ^F11, F8, !F2, F1 (блокирующий)
; • Автоматический переход Zen при смене активного окна (Alt+Tab и другие способы)
; • Полноэкранная шторка на весь виртуальный рабочий стол, окно всегда поверх
; • Поддержка maximized для возврата в исходное состояние
; • Multi-monitor: учёт SysGet 76-79, собственная функция GetMonitorIndex
; -----------------------------------------

; ---------- ПАРАМЕТРЫ ----------
global marginH := 0.25           ; доля пустоты слева/справа
global marginV := 0.10           ; доля пустоты сверху/снизу
global overlayAlpha := 240       ; 0–255 прозрачность

; ---------- ГЛОБАЛЫ ----------
global zen := false              ; статус Zen-режима
global savedWin := Map()         ; координаты + был Max
global overlayGui := ""         ; GUI-шторка
global zenHwnd := 0              ; HWND активной Zen-цели
global hCallHook := 0            ; хук WinEvent

; ---------- ГОРЯЧИЕ КЛАВИШИ ----------
^!z::toggleZenMode()
^F11::toggleZenMode()
F8::toggleZenMode()
!F2::toggleZenMode()
F1::toggleZenMode()
^!x::disableZenMode()  ; аварийный выход

; ---------- ИНИЦИАЛИЗАЦИЯ WINEVENTHOOK ----------
; создаём callback-объект для обработки системного события смены фокуса
callbackWinEvent := RegisterCallback("WinEventProc", "Fast")

hCallHook := DllCall("SetWinEventHook"
    , "UInt", 0x0003, "UInt", 0x0003            ; EVENT_SYSTEM_FOREGROUND
    , "Ptr", 0                    ; hmodWinEventProc
    , "Ptr", callbackWinEvent     ; lpfnWinEventProc
    , "UInt", 0, "UInt", 0      ; все процессы, все потоки
    , "UInt", 0x0002             ; WINEVENT_OUTOFCONTEXT
)

; -----------------------------------
; регистрируем OnExit колбэк для снятия хука
cleanupHook := Func("CleanupHooks")
OnExit(cleanupHook)

; =========================================
;   Функции Zen
; =========================================

toggleZenMode() {
    global zen, savedWin, marginH, marginV, overlayGui, zenHwnd

    if zen {
        disableZenMode()
        return
    }

    hwnd := WinGetID("A")
    if !hwnd {
        TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
        return
    }

    ; сохраняем положение и размер
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd)  ; 1 = maximized
    savedWin := Map("id",hwnd,"x",ox,"y",oy,"w",ow,"h",oh,"max",wasMax)

    if (wasMax = 1)
        WinRestore("ahk_id " hwnd)
    Sleep 50

    ; определяем монитор по центру окна
    centerX := ox + ow//2
    centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon, &mL,&mT,&mR,&mB)
    monW := mR - mL
    monH := mB - mT

    ; рассчитываем центрируемые координаты
    newW := Round(monW * (1 - marginH*2))
    newH := Round(monH * (1 - marginV*2))
    newX := mL + Round(monW * marginH)
    newY := mT + Round(monH * marginV)

    ; перемещаем окно
    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

    ; создаём полноэкранное затемнение на весь virtual desktop
    virtL := SysGet(76), virtT := SysGet(77)
    virtW := SysGet(78), virtH := SysGet(79)
    createFullOverlay(virtL, virtT, virtW, virtH)

    ; поднимаем окно над шторкой
    WinSetAlwaysOnTop(1, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)

    zen := true
    zenHwnd := hwnd
}

; -----------------------------------
disableZenMode() {
    global zen, savedWin, overlayGui, zenHwnd
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
    overlayGui := ""  ; reset

    zen := false
    zenHwnd := 0
}

; =========================================
;   ОДНА ПОЛНОЭКРАННАЯ ШТОРКА
; =========================================

createFullOverlay(x,y,w,h) {
    global overlayGui, overlayAlpha
    if IsObject(overlayGui)
        overlayGui.Destroy()
    overlayGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
    overlayGui.BackColor := "Black"
    overlayGui.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(overlayAlpha, overlayGui.Hwnd)
}

; -----------------------------------
; индекс монитора по точке
; -----------------------------------
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

; -----------------------------------
; WinEvent callback для смены окна
; -----------------------------------

WinEventProc(hWinEventHook, event, hwndNew, idObject, idChild, dwThread, dwTime) {
    global zen, zenHwnd
    if !zen || idObject || idChild
        return
    if (hwndNew && hwndNew != zenHwnd) {
        disableZenMode()
        Sleep 50
        toggleZenMode()
    }
}

; -----------------------------------
; Удаляем хук при выходе
; -----------------------------------
CleanupHooks(*) {
    global hCallHook
    if (hCallHook)
        DllCall("UnhookWinEvent", "Ptr", hCallHook)
}
