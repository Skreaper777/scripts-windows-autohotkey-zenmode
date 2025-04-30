#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================
;  Zen‑Mode v7.2 — авто‑переключение через WinEventHook (Alt+Tab)
; =========================================
;  • Хоткеи включения: ^!z, ^F11, F8, !F2, F1 (блокирующий)
;  • Автоматически переносит затемнение на вновь активированное окно
;  • Одна полноэкранная шторка (GUI) под окном, окно всегда сверху
;  • Сохраняет/возвращает maximized‑состояние
;  • Работает на любом мониторе (учёт SysGet 76‑79)
; -----------------------------------------

; ---------- ПАРАМЕТРЫ ----------
global marginH := 0.25           ; доля пустоты слева/справа (0‑1)
global marginV := 0.10           ; доля пустоты сверху/снизу (0‑1)
global overlayAlpha := 240       ; 0‑255 прозрачность (≈94 %)

; ---------- ГЛОБАЛЫ ----------
global zen       := false         ; Zen‑режим активен?
global savedWin  := Map()         ; положение/размер + был ли Max
global overlayGui := ""          ; GUI‑шторка
global zenHwnd   := 0             ; текущее окно в Zen
global hCallHook := 0             ; дескриптор WinEventHook

; ---------- ГОРЯЧИЕ КЛАВИШИ ----------
^!z::toggleZenMode()
^F11::toggleZenMode()
F8::toggleZenMode()
!F2::toggleZenMode()
F1::toggleZenMode()      ; блокирующий F1
^!x::disableZenMode()    ; аварийный выход

; ---------- УСТАНОВКА WinEventHook ----------
callbackWinEvent := CallbackCreate(WinEventProc, "Fast")
hCallHook := DllCall("SetWinEventHook"
    , "UInt", 0x0003, "UInt", 0x0003        ; EVENT_SYSTEM_FOREGROUND
    , "Ptr", 0, "Ptr", callbackWinEvent
    , "UInt", 0, "UInt", 0, "UInt", 0x0002)

; =========================================
;  ВКЛ / ВЫКЛ ZEN‑режима
; =========================================

toggleZenMode() {
    global zen, savedWin, marginH, marginV, overlayGui, zenHwnd

    if zen {         ; если уже включён — выключаем
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
    wasMax := WinGetMinMax(hwnd)          ; 1 = maximized
    savedWin := Map("id",hwnd,"x",ox,"y",oy,"w",ow,"h",oh,"max",wasMax)

    if (wasMax = 1)
        WinRestore("ahk_id " hwnd)
    Sleep 50

    ; --- расчёт позиции внутри монитора ---
    centerX := ox + ow//2,  centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon, &mL,&mT,&mR,&mB)
    monW := mR - mL,  monH := mB - mT

    newW := Round(monW * (1 - marginH*2))
    newH := Round(monH * (1 - marginV*2))
    newX := mL + Round(monW * marginH)
    newY := mT + Round(monH * marginV)

    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

    ; --- создаём шторку ---
    virtL := SysGet(76), virtT := SysGet(77)
    virtW := SysGet(78), virtH := SysGet(79)
    createFullOverlay(virtL, virtT, virtW, virtH)

    ; --- поднимаем окно сверху ---
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
    overlayGui := ""

    zen := false
    zenHwnd := 0
}

; =========================================
;  ШТОРКА (GUI overlay)
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

; индекс монитора по точке
GetMonitorIndex(px,py) {
    cnt := MonitorGetCount()
    Loop cnt {
        MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
        if (px>=l && px<r && py>=t && py<b)
            return A_Index
    }
    return MonitorGetPrimary()
}

; -----------------------------------
; WinEvent callback: EVENT_SYSTEM_FOREGROUND
; -----------------------------------
WinEventProc(hook,event,hwndNew,idObj,idChild,thread,time) {
    global zen, zenHwnd
    if !zen || idObj || idChild
        return
    if (hwndNew && hwndNew != zenHwnd) {
        disableZenMode()
        Sleep 50
        toggleZenMode()
    }
}

; OnExit (регистрируем после объявления функции)
OnExit(Func("CleanupHooks"))

CleanupHooks(*) {
    global hCallHook, callbackWinEvent
    if hCallHook
        DllCall("UnhookWinEvent", "Ptr", hCallHook)
    if callbackWinEvent
        CallbackFree(callbackWinEvent)
}
