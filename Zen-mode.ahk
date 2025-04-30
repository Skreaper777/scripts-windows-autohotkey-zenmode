#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================
; Zen‑Mode  v7.0  (auto‑switch via timer)
; =========================================
; • F1 (и другие хоткеи) включает «фокус» на активное окно.
; • Если во время Zen пользователь Alt‑Tab’ом активирует другое окно,
;   скрипт автоматически снимет тьму со старого и наложит на новое.
;   (реализовано лёгким SetTimer, без сложных WinEventHook).
; • Одна полноэкранная шторка, окно сверху, поддержка maximized.
; • Multi‑monitor: учитываем SysGet 76‑79.
; -----------------------------------------

; ---------- ПАРАМЕТРЫ ----------
global marginH := 0.25           ; доля пустоты слева/справа
global marginV := 0.10           ; доля пустоты сверху/снизу
global overlayAlpha := 240       ; 0‑255 прозрачность

; гор. клавиши (последняя — блокирующий F1)
global hotkeyList := ["^!z", "^F11", "F8", "!F2", "F1"]

; ---------- ВНУТРЕННИЕ ----------
global zen := false
global savedWin := Map()         ; координаты + был Max
global overlayGui := ""          ; GUI‑шторка
global zenHwnd := 0              ; окно, на которое сейчас наложен Zen

; ---------- ГОРЯЧИЕ КЛАВИШИ ----------
for hk in hotkeyList
    Hotkey(hk, Func("toggleZenMode"))   ; корректный callback
Hotkey("^!x", Func("disableZenMode"))   ; аварийный выход

; ---------- ЛКМ по шторке ----------
OnMessage(0x201, Func("OnOverlayClick"))
OnOverlayClick(w,l,m,hwnd) {
    global zen, overlayGui
    if zen && IsObject(overlayGui) && (hwnd = overlayGui.Hwnd)
        disableZenMode()
}

; ---------- TIMER для автопереключения ----------
WatchActive() {
    global zen, zenHwnd
    if !zen
        return
    current := WinGetID("A")
    if (current != zenHwnd && current != 0) {
        disableZenMode()
        Sleep 50
        toggleZenMode()           ; включаем Zen на новом окне
    }
}

; ===================================
;    ВКЛ / ВЫКЛ   ZEN‑режима
; ===================================

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

    ; --- сохраняем состояние окна ---
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd) ; 1 = maximized
    savedWin := Map("id", hwnd, "x", ox, "y", oy, "w", ow, "h", oh, "max", wasMax)

    if (wasMax = 1)
        WinRestore("ahk_id " hwnd)
    Sleep 50

    ; --- монитор по центру окна ---
    centerX := ox + ow//2,  centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon, &mL,&mT,&mR,&mB)
    monW := mR - mL,  monH := mB - mT

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
    zenHwnd := hwnd
    SetTimer(Func("WatchActive"), 100)   ; каждые 100 мс проверяем Alt‑Tab
}

; ===================================
;        ВЫКЛ  ZEN‑режима
; ===================================

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
    SetTimer(Func("WatchActive"), 0)      ; останавливаем таймер
}

; ===================================
;          ШТОРКА‑OVERLAY
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
