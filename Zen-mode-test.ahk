#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
;  Zen-Mode v8.3 — «чёрный экран» пофиксен + fallback, ошибки видны
; =============================================================
;  • SetWindowCompositionAttribute вызывает ошибку на старых Windows —
;    теперь проверяем наличие функции и оборачиваем в Try/Catch.
;    Если API недоступно или bgBlurStrength = 0  → просто полупрозрачный
;    цвет без blur (через SetLayeredWindowAttributes).
;  • overlayTopmost = **false** по умолчанию, чтобы системные ошибки
;    и всплывающие окна были поверх шторки.
;  • Если картинка не найдена  → шторка не рушится, просто не создаём
;    слой с изображением.
; =============================================================

; ---------- ПАРАМЕТРЫ ОКНА ----------
global marginH       := 0.30
global marginV       := 0.05

global marginH_2     := 0.35
global marginV_2     := 0.15

; ---------- ШТОРКА / BACKDROP ----------
global enableImageBackground := true

; Путь к картинке
global imageBackgroundPath := "E:\\pic.jpg"

; Верхний цветной слой
global bgColor        := "000000"   ; RGB без #
global bgAlpha        := 240        ; 0 = непрозр., 255 = полно прозрачн.
global bgBlurStrength := 1          ; 0 = blur off

; Делать ли шторку AlwaysOnTop?  false = ошибки будут поверх
global overlayTopmost := true

; ---------- ПРОЧЕЕ ----------
global enableEscExit := true

global hotkeyList   := ["^!z", "F1"]
global hotkeyList_2 := ["F2"]

; ---------- СЛУЖЕБНЫЕ ----------
global zen := false, savedWin := Map()
global guiBlur := "", guiImg := ""
global altPressed := false, wasZenDuringAltTab := false

; =============================================================
;                 Р Е Г И С Т Р А Ц И Я   H O T K E Y S
; =============================================================
registerHotkeys() {
    Toggle1 := (*) => toggleZenMode(marginH,  marginV )
    Toggle2 := (*) => toggleZenMode(marginH_2,marginV_2)

    for hk in hotkeyList
        Hotkey(hk, Toggle1)

    if hotkeyList_2.Length
        for hk in hotkeyList_2
            Hotkey(hk, Toggle2)

    Hotkey("^!x", (*) => disableZenMode())
    if enableEscExit
        Hotkey("*Esc", escExit)
}
registerHotkeys()

; =============================================================
;                         ALT + TAB
; =============================================================
~Alt:: altPressed := true

~Alt Up::{
    global altPressed, wasZenDuringAltTab
    altPressed := false
    if wasZenDuringAltTab {
        wasZenDuringAltTab := false
        Sleep 120
        toggleZenMode()
    }
}

~Tab::{
    global zen, altPressed
    if zen && altPressed
        wasZenDuringAltTab := true,
        disableZenMode()
}

escExit(*){
    global zen
    if zen
        disableZenMode()
}

; =============================================================
;                 В К Л / В Ы К Л  Z E N
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

    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd)
    savedWin := Map("id",hwnd,"x",ox,"y",oy,"w",ow,"h",oh,"max",wasMax)

    if (wasMax = 1) {
        WinRestore(hwnd)
        Sleep 50
    }

    centerX := ox + ow//2, centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon,&mL,&mT,&mR,&mB)
    monW := mR - mL,  monH := mB - mT

    newW := Round(monW * (1 - hMargin * 2))
    newH := Round(monH * (1 - vMargin * 2))
    newX := mL + Round(monW * hMargin)
    newY := mT + Round(monH * vMargin)
    WinMove(newX, newY, newW, newH, hwnd)

    createBackdropLayers(SysGet(76),SysGet(77),SysGet(78),SysGet(79))

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
                WinMove(savedWin["x"],savedWin["y"],savedWin["w"],savedWin["h"], hwnd)
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
        createImageOverlay(x,y,w,h)   ; нижний слой (картинка)
        createBlurOverlay(x,y,w,h)    ; верхний слой (цвет/blur)
    } else {
        createBlurOverlay(x,y,w,h)
    }
}

; ---------- слой №2: цвет + (опц.) blur ----------
createBlurOverlay(x,y,w,h) {
    global guiBlur, bgColor, bgAlpha, bgBlurStrength, overlayTopmost

    if IsObject(guiBlur)
        guiBlur.Destroy()

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost? " +AlwaysOnTop" : "")
    guiBlur := Gui(flags)
    guiBlur.BackColor := bgColor

    filler := guiBlur.AddText(Format("x0 y0 w{} h{}", w, h), "")
    filler.OnEvent("Click", (*) => disableZenMode())

    guiBlur.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))

    hwnd := guiBlur.Hwnd

    ; === Прозрачность всегда ===
    DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20 ; GWL_EXSTYLE
           , "Ptr", DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "Ptr") | 0x80000) ; WS_EX_LAYERED
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)

    ; === Blur, если доступен API и blurStrength > 0 ===
    if (bgBlurStrength > 0) {
        pSetWCA := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32", "Ptr")
                                        , "AStr", "SetWindowCompositionAttribute", "Ptr")
        if pSetWCA {
            try {
                acc := Buffer(16,0)
                NumPut("UInt", 4, acc, 0)              ; ACCENT_ENABLE_BLURBEHIND
                NumPut("UInt", bgBlurStrength, acc, 4)

                alpha := 255 - bgAlpha
                rgb := "0x" SubStr(bgColor,5,2) SubStr(bgColor,3,2) SubStr(bgColor,1,2)
                color := (alpha << 24) | (Integer(rgb) & 0xFFFFFF)
                NumPut("UInt", color, acc, 8)

                wca := Buffer(A_PtrSize=8?24:16,0)
                NumPut("UInt", 19, wca, 0)
                NumPut("Ptr", acc.Ptr, wca, A_PtrSize=8?8:4)
                NumPut("UPtr", acc.Size, wca, A_PtrSize=8?16:8)

                DllCall(pSetWCA, "Ptr", hwnd, "Ptr", wca.Ptr)
            } catch {
                ; тихо игнорируем, оставляя прозрачный цвет без blur
            }
        }
    }
}

; ---------- слой №1: картинка ----------
createImageOverlay(x,y,w,h) {
    global guiImg, imageBackgroundPath, bgAlpha, overlayTopmost

    if !FileExist(imageBackgroundPath)
        return

    if IsObject(guiImg)
        guiImg.Destroy()

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost? " +AlwaysOnTop" : "")
    guiImg := Gui(flags)
    guiImg.AddPicture(Format("x0 y0 w{} h{} +Center", w, h), imageBackgroundPath)
    guiImg.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))

    DllCall("SetLayeredWindowAttributes", "Ptr", guiImg.Hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)
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