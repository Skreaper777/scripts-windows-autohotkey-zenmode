#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
;  Zen‑Mode v8.4 — per‑monitor JPG фон, AlwaysOnTop по умолчанию
; =============================================================
;  • overlayTopmost снова true — шторка поверх всех окон.
;  • imageBackgroundPath → "E:\\pic.jpg" (JPG).
;  • Картинка‑задник растягивается *отдельно* на каждый монитор:
;    берётся *высота* монитора, пропорции сохраняются (ширина автоподстройка).
;  • guiImg заменён на массив guiImgList, чтобы хранить несколько GUI.
; =============================================================

; ---------- ПАРАМЕТРЫ ОКНА ----------
global marginH       := 0.30
global marginV       := 0.05

global marginH_2     := 0.35
global marginV_2     := 0.15

; ---------- ШТОРКА / BACKDROP ----------
global enableImageBackground := true

; Путь к картинке (JPG)
global imageBackgroundPath := "E:\\pic.jpg"

; Верхний цветной слой
global bgColor        := "000000"
global bgAlpha        := 180        ; 0‑255  (0 = полностью непрозрачный, 255 = полностью прозрачный)
global bgBlurStrength := 8          ; 0‑19   (0 = blur off; ~19 = максимум)

; Делать ли слои шторки AlwaysOnTop?
global overlayTopmost := false

; ---------- ПРОЧЕЕ ----------
global enableEscExit := true

global hotkeyList   := ["^!z", "F1"]
global hotkeyList_2 := ["F2"]

; ---------- СЛУЖЕБНЫЕ ----------
global zen := false, savedWin := Map()
; массивы для многослойных GUI
global guiBlur := ""
global guiImgList := []

global altPressed := false, wasZenDuringAltTab := false

; =============================================================
;    Р Е Г И С Т Р А Ц И Я   H O T K E Y S
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

    createBackdropLayers()

    WinSetAlwaysOnTop(1, hwnd)
    WinActivate(hwnd)
    zen := true
}

disableZenMode() {
    global zen, savedWin, guiBlur, guiImgList
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
    for ref in guiImgList
        if IsObject(ref)
            ref.Destroy()
    guiImgList := []

    zen := false
}

; =============================================================
;                     Ш Т О Р К А (per‑monitor)
; =============================================================
createBackdropLayers() {
    global enableImageBackground

    ; 1) Цвет + (опц.) blur по всей виртуальной области
        ; Получаем виртуальные координаты экрана
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    createBlurOverlay(vx,vy,vw,vh)

    ; 2) Картинка на каждом мониторе
    if enableImageBackground && FileExist(imageBackgroundPath)
        loop MonitorGetCount()
        {
            MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
            createImageOverlay(l,t,r-l,b-t)
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

    ; === прозрачность ===
    DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "Ptr", DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "Ptr") | 0x80000)
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)

    ; === blur ===
    if (bgBlurStrength > 0) {
        pSetWCA := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32", "Ptr")
                                        , "AStr", "SetWindowCompositionAttribute", "Ptr")
        if pSetWCA {
            try {
                acc := Buffer(16,0)
                NumPut("UInt", 4, acc, 0)              ; ACCENT_ENABLE_BLURBEHIND
                NumPut("UInt", bgBlurStrength, acc, 4) ; AccentFlags

                alpha := 255 - bgAlpha
                rgb := "0x" SubStr(bgColor,5,2) SubStr(bgColor,3,2) SubStr(bgColor,1,2)
                color := (alpha << 24) | (Integer(rgb) & 0xFFFFFF)
                NumPut("UInt", color, acc, 8)

                wca := Buffer(A_PtrSize=8?24:16,0)
                NumPut("UInt", 19, wca, 0)
                NumPut("Ptr",  acc.Ptr, wca, A_PtrSize=8?8:4)
                NumPut("UPtr", acc.Size, wca, A_PtrSize=8?16:8)

                DllCall(pSetWCA, "Ptr", hwnd, "Ptr", wca.Ptr)
            } catch {
                ; если API не доступен — остаёмся с прозрачным цветом
            }
        }
    }
}

; ---------- слой №1: картинка (на каждый монитор) ----------
createImageOverlay(x,y,w,h) {
    global guiImgList, imageBackgroundPath, bgAlpha, overlayTopmost

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost? " +AlwaysOnTop" : "")
    gui := Gui(flags)
    ; тянем по высоте, сохраняя пропорции
    gui.AddPicture(Format("x0 y0 h{} +Center", h), imageBackgroundPath)
    gui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))

    hwnd := gui.Hwnd
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)

    guiImgList.Push(gui)   ; сохраняем для последующего Destroy
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
