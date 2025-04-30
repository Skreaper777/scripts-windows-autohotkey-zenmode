#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================
; Zen‑Mode — multi‑monitor v6.0
; =============================
; • Центрирует активное окно внутри своего монитора по marginH / marginV.
; • Затемняет ВСЮ область вне окна (без pad).
; • Запоминает wasMaximized и восстанавливает.
; • Работает с любым количеством дисплеев (учёт SysGet 76‑79).
; • ЛКМ по затемнению или повторный хоткей = выход.
; ----------------------------------------------------------

; ---------- НАСТРОЙКА ----------
global marginH := 0.25      ; 0‑1 пустота слева/справа
global marginV := 0.10      ; 0‑1 пустота сверху/снизу

global overlayAlpha := 240  ; 0‑255 степень затемнения

global hotkeyList := ["^!z", "^F11", "F8", "!F2"] ; запуск/выход Zen

; ---------- ВНУТРЕННИЕ ----------
zen             := false              ; статус режима
savedWin        := Map()              ; координаты и state окна
overlayGuiArr   := []                 ; массив GUI‑шторок

; ---------- ГОРЯЧИЕ КЛАВИШИ ----------
ToggleZen(*) => toggleZenMode()
for hk in hotkeyList
    Hotkey(hk, ToggleZen)
Hotkey("^!x", (*) => disableZenMode()) ; аварийный выход

; ---------- ЛКМ по шторке ----------
OnMessage(0x201, HandleClick)   ; WM_LBUTTONDOWN
HandleClick(w,l,m,hwnd) {
    global zen, overlayGuiArr
    if !zen
        return
    for g in overlayGuiArr
        if (hwnd = g.Hwnd) {
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

    ; --- сохраняем состояние окна ---
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd) ; 1 = maximized
    savedWin := Map("id", hwnd, "x", ox, "y", oy, "w", ow, "h", oh, "max", wasMax)

    if (wasMax = 1)
        WinRestore("ahk_id " hwnd)
    Sleep 50

    ; --- выбираем монитор по центру окна ---
    centerX := ox + ow//2, centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon, &mL,&mT,&mR,&mB)
    monW := mR - mL,  monH := mB - mT

    newW := Round(monW * (1 - marginH*2))
    newH := Round(monH * (1 - marginV*2))
    newX := mL + Round(monW * marginH)
    newY := mT + Round(monH * marginV)

    WinSetAlwaysOnTop(1, "ahk_id " hwnd)
    WinActivate("ahk_id " hwnd)
    WinMove(newX, newY, newW, newH, "ahk_id " hwnd)

    ; --- строим затемнение на весь virtual desktop ---
    virtL := SysGet(76), virtT := SysGet(77)
    virtW := SysGet(78), virtH := SysGet(79)
    buildOverlays(newX, newY, newW, newH, virtL, virtT, virtW, virtH)

    zen := true
}

; =========================================
;   ВЫКЛ  ZEN‑режима
; =========================================

disableZenMode() {
    global zen, savedWin, overlayGuiArr
    if !zen
        return

    hwnd := savedWin["id"]
    if WinExist("ahk_id " hwnd) {
        WinSetAlwaysOnTop(0, "ahk_id " hwnd)
        if (savedWin["max"] = 1) {
            WinMaximize("ahk_id " hwnd)
        } else {
            WinMove(savedWin["x"], savedWin["y"], savedWin["w"], savedWin["h"], "ahk_id " hwnd)
        }
    }

    for g in overlayGuiArr
        g.Destroy()
    overlayGuiArr := []

    zen := false
}

; =========================================
;   ШТОРКИ (без pad)
; =========================================

createOverlayRect(x,y,w,h) {
    global overlayGuiArr, overlayAlpha
    if (w<=0 || h<=0)
        return
    g := Gui("-Caption +AlwaysOnTop +ToolWindow")
    g.BackColor := "Black"
    g.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(overlayAlpha, g.Hwnd)
    overlayGuiArr.Push(g)
}

buildOverlays(wx, wy, ww, wh, vL, vT, vW, vH) {
    global overlayGuiArr

    for g in overlayGuiArr
        g.Destroy()
    overlayGuiArr := []

    ; слева
    createOverlayRect(vL, vT, wx - vL, vH)
    ; справа
    createOverlayRect(wx + ww, vT, (vL + vW) - (wx + ww), vH)
    ; сверху
    createOverlayRect(wx, vT, ww, wy - vT)
    ; снизу
    createOverlayRect(wx, wy + wh, ww, (vT + vH) - (wy + wh))
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
