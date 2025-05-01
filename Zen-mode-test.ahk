#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
;  Zen‑Mode v8.0  —  двойная шторка + гибкие настройки + баг‑фиксы
; =============================================================
;  • Шторка теперь состоит из *двух* слоёв, если enableImageBackground = true:
;       1) картинка‑задник (самый нижний слой);
;       2) полупрозрачный цвет + DWM‑blur (между картинкой и окном Zen).
;    При enableImageBackground = false создаётся только слой №2.
;  • Клик по шторке **всегда** выводит из Zen‑режима.
;  • Alt‑Tab снова «передаёт» окно: отключаем Zen при Tab, восстанавливаем при Alt Up.
;  • Переменные цвета, прозрачности и силы размытия добавлены.
;  • overlayAlpha удалён как неиспользуемый.
; =============================================================

; ---------- ПАРАМЕТРЫ ОКНА ----------
global marginH       := 0.30  ; левые/правые отступы (доля)
global marginV       := 0.05  ; верх/низ

; Альтернативный режим (вторая группа хоткеев)
global marginH_2     := 0.35
global marginV_2     := 0.15

; ---------- ШТОРКА / BACKDROP ----------
; true  — добавляем картинку под цвет + blur
; false — только цвет + blur
global enableImageBackground := true

; Путь к картинке (используется, только если enableImageBackground = true)
global imageBackgroundPath := "E:\\pic.png"

; Настройки верхнего (цветного) слоя шторки
global bgColor        := "000000"  ; шестнадцатеричный RGB без «#»
global bgAlpha        := 180       ; 0 = непрозрачный, 255 = полностью прозр.
global bgBlurStrength := 8         ; 0 = blur off, >0 — сила размытия (0‑19)

; ---------- ПРОЧЕЕ ----------
; true  — Esc выводит из Zen (и не передаётся приложению)
; false — Esc не трогаем
global enableEscExit := true

; Основная / альтернативная группа хоткеев
global hotkeyList   := ["^!z", "F1"]
global hotkeyList_2 := ["F2"]          ; пустой массив = режим не нужен

; ---------- СЛУЖЕБНЫЕ ПЕРЕМЕННЫЕ ----------
global zen                 := false
global savedWin            := Map()
global guiBlur             := ""       ; GUI‑слой цвет+blur
global guiImg              := ""       ; GUI‑слой картинка
global altPressed          := false
global wasZenDuringAltTab  := false

; =============================================================
;                  Р Е Г И С Т Р А Ц И Я  H O T K E Y S
; =============================================================
registerHotkeys() {
    ToggleZen1 := (*) => toggleZenMode(marginH, marginV)
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

; =============================================================
;                        ALT  +  TAB
; =============================================================
~Alt::  altPressed := true

~Alt Up:: {
    global altPressed, wasZenDuringAltTab
    altPressed := false
    if wasZenDuringAltTab {
        wasZenDuringAltTab := false
        ; ждём, пока активируется выбранное окно
        Sleep 120
        toggleZenMode() ; запускаем Zen для нового активного окна
    }
}

~Tab:: {
    global zen, altPressed
    ; Срабатывает при нажатии Tab (а не при отпускании) — быстрее реакция
    if zen && altPressed
        wasZenDuringAltTab := true,
        disableZenMode()
}

escExit(*) {
    global zen
    if zen
        disableZenMode()
}

; =============================================================
;                   В К Л Ю Ч И Т Ь / О Т К Л Ю Ч И Т Ь
; =============================================================
toggleZenMode(hMargin := marginH, vMargin := marginV) {
    global zen, savedWin

    if zen {
        disableZenMode()
        return
    }

    hwnd := WinGetID("A")
    if !hwnd || !WinExist(hwnd) {
        TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
        return
    }

    ; --- сохраняем исходное состояние ---
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd)
    savedWin := Map("id",hwnd, "x",ox, "y",oy, "w",ow, "h",oh, "max",wasMax)

    if (wasMax = 1)
        WinRestore(hwnd), Sleep 50

    ; --- центрируем окно ---
    centerX := ox + ow//2, centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon,&mL,&mT,&mR,&mB)
    monW := mR-mL, monH := mB-mT

    newW := Round(monW*(1-hMargin*2))
    newH := Round(monH*(1-vMargin*2))
    newX := mL + Round(monW*hMargin)
    newY := mT + Round(monH*vMargin)
    WinMove(newX,newY,newW,newH, hwnd)

    ; --- создаём слои шторки ---
    createBackdropLayers(SysGet(76), SysGet(77), SysGet(78), SysGet(79))

    WinSetAlwaysOnTop(1, hwnd)
    WinActivate(hwnd)
    zen := true
}


disableZenMode() {
    global zen, savedWin, guiBlur, guiImg

    if !zen || !savedWin.Count
        return

    hwnd := savedWin["id"]
    if WinExist(hwnd) {
        try {
            if (savedWin["max"] = 1)
                WinMaximize(hwnd)
            else
                WinMove(savedWin["x"], savedWin["y"], savedWin["w"], savedWin["h"], hwnd)
            WinSetAlwaysOnTop(0, hwnd)
        }
    }
    if IsObject(guiBlur)
        guiBlur.Destroy(), guiBlur := ""
    if IsObject(guiImg)
        guiImg.Destroy(), guiImg := ""

    zen := false
}

; =============================================================
;                     Ш Т О Р К А  (2 слоя)
; =============================================================
createBackdropLayers(x,y,w,h) {
    global enableImageBackground

    if enableImageBackground && FileExist(imageBackgroundPath) {
        createImageOverlay(x,y,w,h)   ; самый нижний слой
        createBlurOverlay(x,y,w,h)    ; второй слой — цвет + blur
    } else {
        createBlurOverlay(x,y,w,h)
    }
}

; ---------- слой №2: цвет + (опц.) blur ----------
createBlurOverlay(x,y,w,h) {
    global guiBlur, bgColor, bgAlpha, bgBlurStrength
    if IsObject(guiBlur)
        guiBlur.Destroy()

    guiBlur := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    guiBlur.BackColor := bgColor
    guiBlur.OnEvent("Click", (*) => disableZenMode())
    guiBlur.Show("x" x " y" y " w" w " h" h " NoActivate")
    hwnd := guiBlur.Hwnd

    ; ACCENT_POLICY
    acc := Buffer(16, 0)
    NumPut("UInt", 4, acc, 0)                 ; ACCENT_ENABLE_BLURBEHIND (4)
    NumPut("UInt", bgBlurStrength, acc, 4)     ; AccentFlags – сила размытия

    ; Цвет + альфа → DWORD ABGR
    alpha := 255 - bgAlpha                      ; инвертируем: 0 = непрозр.
    rgb := "0x" SubStr(bgColor,5,2) + SubStr(bgColor,3,2) + SubStr(bgColor,1,2)
    color := (alpha<<24) | (Integer(rgb) & 0xFFFFFF)
    NumPut("UInt", color, acc, 8)

    wca := Buffer(A_PtrSize=8?24:16, 0)
    NumPut("UInt", 19, wca, 0)                ; WCA_ACCENT_POLICY
    NumPut("Ptr",  acc.Ptr, wca, A_PtrSize=8?8:4)
    NumPut("UPtr", acc.Size, wca, A_PtrSize=8?16:8)
    DllCall("user32\\SetWindowCompositionAttribute", "Ptr", hwnd, "Ptr", wca.Ptr)
}

; ---------- слой №1: картинка ----------
createImageOverlay(x,y,w,h) {
    global guiImg, imageBackgroundPath, bgAlpha
    if IsObject(guiImg)
        guiImg.Destroy()

    guiImg := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
    guiImg.AddPicture("x0 y0 w" w " h" h " +Center", imageBackgroundPath)
    guiImg.Show("x" x " y" y " w" w " h" h " NoActivate")
    hwnd := guiImg.Hwnd
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)
    ; Круговой ESC – клика нет (закроет верхний слой)
}

; ---------- монитор по координате ----------
GetMonitorIndex(px,py) {
    max := MonitorGetCount()
    Loop max {
        MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
        if (px>=l && px<r && py>=t && py<b)
            return A_Index
    }
    return MonitorGetPrimary()
}
