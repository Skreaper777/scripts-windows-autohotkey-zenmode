#Requires AutoHotkey v2.0
#SingleInstance Force

; =========================================
;  Zen-Mode v7.0 — Alt‑Tab «handoff» + optional image overlay
; =========================================
;  • Первая группа хоткеев (hotkeyList) — классический режим.
;  • Вторая группа (hotkeyList_2) — альтернативный режим с иными отступами.
;  • Alt + Tab заменяет окно в Zen‑режиме, одиночный Alt больше не влияет.
;  • Esc (если включено) всегда выводит из Zen‑режима.
;  • Фоновая «шторка» может быть либо «DWM‑blur» чёрного цвета, либо картинка.

; ---------- ПАРАМЕТРЫ ----------
;   Базовые отступы (доли от ширины/высоты монитора)
global marginH       := 0.30
global marginV       := 0.05
;   Отступы для альтернативного режима
global marginH_2     := 0.35
global marginV_2     := 0.15

;   Прозрачность (alpha) для всех видов шторки (0 = прозр., 255 = непрозр.)
global overlayAlpha  := 140

;   ===========   Выбор фона шторки  ===========
;   true  — использовать картинку   (imageBackgroundPath)
;   false — классический DWM‑blur чёрного цвета
global enableImageBackground := true
global imageBackgroundPath   := "E:\\pic.png"

;   ===========   Управление ESC   ===========
;   true  — Esc выводит из Zen‑режима и НЕ передаётся активному приложению
;   false — Esc никак не связан с Zen‑режимом
global enableEscExit      := true

;   ===========   Группы хоткеев   ===========
global hotkeyList   := ["^!z", "^F11", "F8", "F1"]
global hotkeyList_2 := ["F2"]               ; пустой массив = вторая группа не нужна

; ---------- СЛУЖЕБНЫЕ ----------
global zen                := false          ; «в zen или нет»
global savedWin           := Map()          ; координаты/состояние окна до Zen
global overlayGui         := ""             ; ссылка на шторку‑GUI
global altPressed         := false          ; держим ли Alt
global wasZenDuringAltTab := false          ; выходили из Zen по Alt+Tab

; ---------- РЕГИСТРАЦИЯ ГОТОВЫХ КЛАВИШ ----------
registerHotkeys() {
    ToggleZen1 := (*) => toggleZenMode(marginH,  marginV)
    for hk in hotkeyList
        Hotkey(hk, ToggleZen1)

    if (hotkeyList_2.Length) {
        ToggleZen2 := (*) => toggleZenMode(marginH_2, marginV_2)
        for hk in hotkeyList_2
            Hotkey(hk, ToggleZen2)
    }

    Hotkey("^!x", (*) => disableZenMode()) ; аварийный выход

    if enableEscExit
        Hotkey("*Esc", escExit)
}
registerHotkeys()

; ---------- ALT‑TAB ----------
~Alt::  altPressed := true         ; просто зажали Alt — ничего не делаем
~Alt Up:: {
    global altPressed, wasZenDuringAltTab
    altPressed := false
    if wasZenDuringAltTab {
        wasZenDuringAltTab := false
        Sleep 75
        toggleZenMode()            ; используем активное окно
    }
}

~Tab Up:: {                         ; Tab отжат при зажатом Alt
    global zen, altPressed, wasZenDuringAltTab
    if zen && altPressed {
        wasZenDuringAltTab := true
        disableZenMode()
    }
}

escExit(*) {
    global zen
    if zen
        disableZenMode()
}

; ===================================
;           В К Л  Z E N
; ===================================
toggleZenMode(hMargin := marginH, vMargin := marginV) {
    global zen, savedWin, overlayGui
    if zen {                         ; Zen уже активен → выключаем
        disableZenMode()
        return
    }

    hwnd := WinGetID("A")
    if !hwnd {
        TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
        return
    }

    ; --- сохраняем исходное состояние ---
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd)            ; 1 = maximized
    savedWin := Map("id",hwnd, "x",ox,"y",oy,"w",ow,"h",oh,"max",wasMax)

    if (wasMax = 1)
        WinRestore(hwnd)
    Sleep 50

    ; --- центрируем окно ---
    centerX := ox + ow//2,  centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon,&mL,&mT,&mR,&mB)
    monW := mR-mL,  monH := mB-mT

    newW := Round(monW*(1-hMargin*2))
    newH := Round(monH*(1-vMargin*2))
    newX := mL + Round(monW*hMargin)
    newY := mT + Round(monH*vMargin)
    WinMove(newX,newY,newW,newH, hwnd)

    ; --- полная шторка ---
    createOverlay(SysGet(76), SysGet(77), SysGet(78), SysGet(79))

    WinSetAlwaysOnTop(1, hwnd)              ; окно поверх шторки
    WinActivate(hwnd)
    zen := true
}

; ===================================
;           В Ы К Л  Z E N
; ===================================
disableZenMode() {
    global zen, savedWin, overlayGui
    if !zen || !savedWin.Count
        return

    hwnd := savedWin["id"]
    if WinExist(hwnd) {
        try {
            if (savedWin["max"] = 1)
                WinMaximize(hwnd)
            else
                WinMove(savedWin["x"], savedWin["y"]
                       ,savedWin["w"], savedWin["h"], hwnd)
            WinSetAlwaysOnTop(0, hwnd)
        }
    }
    if IsObject(overlayGui)
        overlayGui.Destroy(), overlayGui := ""
    zen := false
}

; ===================================
;         Ш Т О Р К А  (выбор)
; ===================================
createOverlay(x,y,w,h) {
    if enableImageBackground && FileExist(imageBackgroundPath)
        createImageOverlay(x,y,w,h)
    else
        createBlurOverlay(x,y,w,h)
}

; --- DWM‑blur чёрного цвета ---
createBlurOverlay(x,y,w,h) {
    global overlayGui, overlayAlpha

    if IsObject(overlayGui)
        overlayGui.Destroy()

    overlayGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    overlayGui.BackColor := "000000"
    overlayGui.Show("x" x " y" y " w" w " h" h " NoActivate")
    hwnd := overlayGui.Hwnd

    ; ACCENT_POLICY для blur‑behind
    acc := Buffer(16, 0)
    NumPut("UInt", 4, acc, 0)               ; ACCENT_ENABLE_BLURBEHIND

    wca := Buffer(A_PtrSize=8?24:16, 0)
    NumPut("UInt", 19,        wca, 0)       ; WCA_ACCENT_POLICY
    NumPut("Ptr",  acc.Ptr,   wca, A_PtrSize=8?8:4)
    NumPut("UPtr", acc.Size,  wca, A_PtrSize=8?16:8)

    DllCall("user32\\SetWindowCompositionAttribute"
           , "Ptr", hwnd, "Ptr", wca.Ptr)

    DllCall("SetLayeredWindowAttributes"
           , "Ptr", hwnd, "UInt", 0
           , "UChar", overlayAlpha, "UInt", 0x02) ; LWA_ALPHA
}

; --- Пиктограмма поверх всех окон ---
createImageOverlay(x,y,w,h) {
    global overlayGui, overlayAlpha, imageBackgroundPath

    if IsObject(overlayGui)
        overlayGui.Destroy()

    overlayGui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    overlayGui.BackColor := "000000"
    overlayGui.AddPicture("x0 y0 w" w " h" h " +Center", imageBackgroundPath)
    overlayGui.Show("x" x " y" y " w" w " h" h " NoActivate")
    hwnd := overlayGui.Hwnd
    DllCall("SetLayeredWindowAttributes"
           , "Ptr", hwnd, "UInt", 0
           , "UChar", overlayAlpha, "UInt", 0x02)
}

; ---------- монитор по точке ----------
GetMonitorIndex(px,py) {
    max := MonitorGetCount()
    Loop max {
        MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
        if (px>=l && px<r && py>=t && py<b)
            return A_Index
    }
    return MonitorGetPrimary()
}
