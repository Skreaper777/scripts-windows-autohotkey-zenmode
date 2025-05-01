#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
;  Zen‑Mode v8.6 — Alt‑Tab fix + идеальное растягивание фона
; =============================================================
;  • Alt‑Tab: ждём смены активного окна → новое окно в Zen.
;  • Порядок слоёв: [раб. стол] → картинка → цвет/blur → окно Zen.
;  • Картинка заполняет монитор без искажений (cover‑алгоритм).
; =============================================================

; ---------- ПАРАМЕТРЫ ОКНА ----------
global marginH       := 0.30
global marginV       := 0.05

global marginH_2     := 0.35
global marginV_2     := 0.15

; ---------- ШТОРКА / BACKDROP ----------
global enableImageBackground := true

global imageBackgroundPath := "E:\\pic.jpg"

global bgColor        := "000000"
; 0 .. 255  (0 непрозрачный)
global bgAlpha        := 180
; 0 .. 19   (0 blur off)
global bgBlurStrength := 8

global overlayTopmost := true

; ---------- ПРОЧЕЕ ----------
global enableEscExit := true

global hotkeyList   := ["^!z", "F1"]
global hotkeyList_2 := ["F2"]

; ---------- СЛУЖЕБНЫЕ ----------
global zen := false, savedWin := Map()
global guiBlur := ""            ; слой цвета/blur
global guiImgList := []         ; картинки‑по‑мониторам

global altPressed := false, wasZenDuringAltTab := false, altPrevHwnd := 0

; =============================================================
;              Р Е Г И С Т Р А Ц И Я  H O T K E Y S
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
;                           ALT + TAB
; =============================================================
~Alt::{
    altPressed := true
    altPrevHwnd := WinGetID("A")       ; запоминаем исходное окно
}

~Tab::{                      ; Tab вниз — выходим из Zen
    global zen, altPressed, wasZenDuringAltTab
    if zen && altPressed {
        wasZenDuringAltTab := true
        disableZenMode()
    }
}

~Alt Up::{                   ; Alt отпущен → ждём новое окно
    global altPressed, wasZenDuringAltTab, altPrevHwnd
    altPressed := false
    if wasZenDuringAltTab {
        wasZenDuringAltTab := false
        ; ждём, пока активное окно сменится с предыдущего
        Loop 40 {                             ; макс 2 сек
            Sleep 50
            hwnd := WinGetID("A")
            if (hwnd != altPrevHwnd && hwnd) {
                toggleZenMode()              ; новое окно в Zen
                break
            }
        }
    }
}

escExit(*){
    if zen
        disableZenMode()
}

; =============================================================
;                ВКЛ / ВЫКЛ ZEN
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

    createBackdropLayers()           ; ← порядок слоёв исправлен

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
                WinMove(savedWin["x"], savedWin["y"], savedWin["w"], savedWin["h"], hwnd)
            WinSetAlwaysOnTop(0, hwnd)
        }
    }

    if IsObject(guiBlur)
        guiBlur.Destroy(), guiBlur := ""
    for gui in guiImgList
        if IsObject(gui)
            gui.Destroy()
    guiImgList := []

    zen := false
}

; =============================================================
;                  Ш Т О Р К А  (per‑monitor)
; =============================================================
createBackdropLayers() {
    global enableImageBackground, imageBackgroundPath

    ; 1) Картинка‑задник на каждом мониторе (нижний слой)
    if enableImageBackground && FileExist(imageBackgroundPath) {
        loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
            createImageOverlay(l, t, r - l, b - t)
        }
    }

    ; 2) Цвет + (опц.) blur — единый слой поверх
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    createBlurOverlay(vx, vy, vw, vh)
}

; ---------- слой цвета + (опц.) blur ----------
createBlurOverlay(x,y,w,h) {
    global guiBlur, bgColor, bgAlpha, bgBlurStrength, overlayTopmost

    if IsObject(guiBlur)
        guiBlur.Destroy()

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    guiBlur := Gui(flags)
    guiBlur.BackColor := bgColor

    guiBlur.AddText(Format("x0 y0 w{} h{}", w, h), "").OnEvent("Click", (*)=>disableZenMode())
    guiBlur.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))

    hwnd := guiBlur.Hwnd
    ex := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "Ptr") | 0x80000
    DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "Ptr", ex)
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)

    if (bgBlurStrength > 0) {
        pSetWCA := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32", "Ptr"), "AStr", "SetWindowCompositionAttribute", "Ptr")
        if pSetWCA {
            try {
                acc := Buffer(16,0)
                NumPut("UInt",4,acc,0), NumPut("UInt",bgBlurStrength,acc,4)
                alpha := 255 - bgAlpha, rgb := "0x" SubStr(bgColor,5,2) SubStr(bgColor,3,2) SubStr(bgColor,1,2)
                NumPut("UInt",(alpha<<24)|(Integer(rgb)&0xFFFFFF), acc, 8)
                wca := Buffer(A_PtrSize=8?24:16,0)
                NumPut("UInt",19,wca,0), NumPut("Ptr",acc.Ptr,wca,A_PtrSize=8?8:4), NumPut("UPtr",acc.Size,wca,A_PtrSize=8?16:8)
                DllCall(pSetWCA, "Ptr", hwnd, "Ptr", wca.Ptr)
            }
        }
    }
}

; ---------- картинка (cover‑алгоритм) ----------
createImageOverlay(x,y,wMon,hMon) {
    global guiImgList, imageBackgroundPath, bgAlpha, overlayTopmost

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    gui := Gui(flags)

    ; Получаем размеры JPG через GDI+
    if !ImageSize(path:=imageBackgroundPath, &imgW, &imgH) {
        gui.Destroy()
        return
    }

    monRatio := wMon / hMon
    imgRatio := imgW / imgH

    if (monRatio >= imgRatio) {
        ; масштабируем по ширине экрана
        newW := wMon
        scale := imgW / newW
        newH := Floor(imgH / scale)
        offsetY := (hMon - newH)//2
        offsetX := 0
    } else {
        ; масштабируем по высоте экрана
        newH := hMon
        scale := imgH / newH
        newW := Floor(imgW / scale)
        offsetX := (wMon - newW)//2
        offsetY := 0
    }

    gui.AddPicture(Format("x{} y{} w{} h{} +Center", offsetX, offsetY, newW, newH), imageBackgroundPath)
    gui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, wMon, hMon))

    DllCall("SetLayeredWindowAttributes", "Ptr", gui.Hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)
    guiImgList.Push(gui)
}

; --- получить размеры изображения (GDI+) ---
ImageSize(path, &w, &h) {
    static token := 0
    if (!token) {
        si := Buffer(16,0)
        DllCall("gdiplus\\GdiplusStartup","PtrP",&token,"Ptr",si,"Ptr",0)
    }
    pBitmap := 0
    if (DllCall("gdiplus\\GdipLoadImageFromFile","WStr",path,"PtrP",&pBitmap)=0 && pBitmap) {
        VarSetCapacity(w,8), VarSetCapacity(h,8)
        DllCall("gdiplus\\GdipGetImageWidth","Ptr",pBitmap,"UIntP",&w)
        DllCall("gdiplus\\GdipGetImageHeight","Ptr",pBitmap,"UIntP",&h)
        DllCall("gdiplus\\GdipDisposeImage","Ptr",pBitmap)
        return true
    }
    return false
}

; ---------- монитор по точке ----------
GetMonitorIndex(px,py) {
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
        if (px>=l && px<r && py>=t && py<b)
            return A_Index
    }
    return MonitorGetPrimary()
}
