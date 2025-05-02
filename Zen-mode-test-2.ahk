#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
;  Zen‑Mode v10.0  — рабочий Blur + картинки + корректный Alt‑Tab
; =============================================================
;  • Два набора хоткеев (hotkeyList / hotkeyList_2) — разные отступы.
;  • Цветовой слой с DWM‑размытием (Win10+).  Параметр bgAlpha управляет
;    прозрачностью, любое bgBlurStrength > 0 включает blur (силу нельзя
;    регулировать API‑ами, это просто Факт Windows).
;  • Картинка‑задник (cover) растягивается по каждому монитору с
;    сохранением пропорций.  Создаётся ПОД цветным слоем.
;  • Alt + Tab:  Tab (при Alt)  →  выходим из Zen,
;                Alt Up         →  помещаем новое активное окно в Zen.
; =============================================================

; ---------- НАСТРОЙКА ----------
global marginH        := 0.30
global marginV        := 0.05

; альтернативный режим
global marginH_2      := 0.35
global marginV_2      := 0.15

; хоткеи
global hotkeyList     := ["^!z", "F1"]
global hotkeyList_2   := ["F2"]

; выход по Esc
global enableEscExit  := true

; фон‑картинка
global enableImageBackground := false
global imageBackgroundPath   := "E:\\pic.jpg"

; слой‑цвет + blur
global bgColor        := "000000"   ; шестнадцатеричный без '#'
global bgAlpha        := 180        ; 0 (непрозр.) … 255 (прозр.)
global bgBlurStrength := 1          ; 0 = blur off, >0 = blur on

; слой AlwaysOnTop?
global overlayTopmost := true

; ---------- СЛУЖЕБНЫЕ ----------
global zen := false, savedWin := Map()

global guiBlur   := ""       ; верхний слой
global guiImgArr := []       ; массив картинок

global altPressed  := false
global needNewZen  := false
global prevHwnd    := 0

; =============================================================
;               Р Е Г И С Т Р А Ц И Я  H O T K E Y S
; =============================================================
registerHotkeys() {
    Toggle1 := (*) => toggleZenMode(marginH,  marginV )
    Toggle2 := (*) => toggleZenMode(marginH_2,marginV_2)

    for k in hotkeyList
        Hotkey(k, Toggle1)
    for k in hotkeyList_2
        Hotkey(k, Toggle2)

    Hotkey("^!x", (*) => disableZenMode())
    if enableEscExit
        Hotkey("*Esc", escExit)
}
registerHotkeys()

; =============================================================
;                          ALT  +  TAB
; =============================================================
~Alt:: altPressed := true

~Tab::{                              ; Tab вниз/вверх считаем после отпускания
    global zen, altPressed, needNewZen, prevHwnd
    if zen && altPressed {
        prevHwnd := WinGetID("A")    ; запоминаем, какое окно было в Zen
        disableZenMode()
        needNewZen := true            ; ждём Alt Up
    }
}

~Alt Up::{
    global altPressed, needNewZen, prevHwnd
    altPressed := false
    if needNewZen {
        needNewZen := false
        ; ждём, пока активное окно сменится (до 1,5 c)
        Loop 30 {
            Sleep 50
            newHwnd := WinGetID("A")
            if (newHwnd != prevHwnd && newHwnd) {
                toggleZenMode()       ; входим в Zen с новым окном
                break
            }
        }
    }
}

escExit(*) {
    if zen
        disableZenMode()
}

; =============================================================
;                     В К Л  /  В Ы К Л  Z E N
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

    ; --- сохраняем состояние ---
    WinGetPos(&ox,&oy,&ow,&oh, hwnd)
    wasMax := WinGetMinMax(hwnd)
    savedWin := Map("id",hwnd,"x",ox,"y",oy,"w",ow,"h",oh,"max",wasMax)

    if (wasMax = 1) {
        WinRestore(hwnd)
        Sleep 50
    }

    ; --- центрируем ---
    centerX := ox + ow//2, centerY := oy + oh//2
    mon := GetMonitorIndex(centerX, centerY)
    MonitorGetWorkArea(mon,&mL,&mT,&mR,&mB)
    monW := mR - mL, monH := mB - mT

    newW := Round(monW * (1 - hMargin*2))
    newH := Round(monH * (1 - vMargin*2))
    newX := mL + Round(monW * hMargin)
    newY := mT + Round(monH * vMargin)
    WinMove(newX, newY, newW, newH, hwnd)

    ; --- создаём слои шторки ---
    createBackdropLayers()

    WinSetAlwaysOnTop(1, hwnd)
    WinActivate(hwnd)
    zen := true
}

disableZenMode() {
    global zen, savedWin, guiBlur, guiImgArr
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
    for g in guiImgArr
        if IsObject(g)
            g.Destroy()
    guiImgArr := []

    zen := false
}

; =============================================================
;                   Ш Т О Р К А  (per‑monitor)
; =============================================================
createBackdropLayers() {
    global enableImageBackground, imageBackgroundPath

    ; 1) Верхний слой — цвет + blur
    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    createBlurOverlay(vx, vy, vw, vh)

    ; 2) Картинка под цветным слоем
    if enableImageBackground && FileExist(imageBackgroundPath) {
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
            createImageOverlay(l, t, r - l, b - t)
        }
    }
}

; ---------- слой цвета + (опц.) blur ----------
createBlurOverlay(x, y, w, h) {
    global guiBlur, bgColor, bgAlpha, bgBlurStrength, overlayTopmost

    if IsObject(guiBlur)
        guiBlur.Destroy()

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    guiBlur := Gui(flags)
    guiBlur.BackColor := bgColor
    guiBlur.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))

    hwnd := guiBlur.Hwnd

    ; --- DWM blur ---
    if (bgBlurStrength > 0) {
        pSetWCA := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32"), "AStr", "SetWindowCompositionAttribute", "Ptr")
        if pSetWCA {
            acc := Buffer(16,0)
            NumPut("UInt", 4, acc, 0)              ; ACCENT_ENABLE_BLURBEHIND
            wca := Buffer(A_PtrSize=8?24:16,0)
            NumPut("UInt", 19, wca, 0)
            NumPut("Ptr",  acc.Ptr, wca, A_PtrSize=8?8:4)
            NumPut("UPtr", acc.Size, wca, A_PtrSize=8?16:8)
            DllCall(pSetWCA,"Ptr", hwnd,"Ptr", wca.Ptr)
        }
    }

    ; --- прозрачность ---
    DllCall("SetLayeredWindowAttributes", "Ptr", hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)
}

; ---------- картинка (cover) ----------
createImageOverlay(x, y, wMon, hMon) {
    global guiImgArr, imageBackgroundPath, overlayTopmost

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    g := Gui(flags)

    if !ImageSize(imageBackgroundPath, &imgW, &imgH) {
        g.Destroy()
        return
    }

    monRatio := wMon / hMon
    imgRatio := imgW / imgH

    if (monRatio >= imgRatio) {
        newW := wMon
        newH := Floor(imgH * (wMon / imgW))
        offsetX := 0
        offsetY := (hMon - newH)//2
    } else {
        newH := hMon
        newW := Floor(imgW * (hMon / imgH))
        offsetY := 0
        offsetX := (wMon - newW)//2
    }

    g.AddPicture(Format("x{} y{} w{} h{} +Center", offsetX, offsetY, newW, newH), imageBackgroundPath)
    g.Show(Format("x{} y{} w{} h{} NoActivate", x, y, wMon, hMon))
    guiImgArr.Push(g)
}

; --- размеры изображения (Bitmap via LoadPicture) ---
ImageSize(path, &w, &h) {
    w := h := 0
    hBmp := LoadPicture(path, "G")  ; G = force Bitmap (AHK v2)
    if !hBmp
        return false

    bm := Buffer(24, 0)               ; BITMAP struct
    if DllCall("GetObject", "Ptr", hBmp, "Int", bm.Size, "Ptr", bm.Ptr) {
        w := NumGet(bm, 4, "Int")    ; bm.bmWidth
        h := NumGet(bm, 8, "Int")    ; bm.bmHeight
    }
    DllCall("DeleteObject", "Ptr", hBmp)
    return (w > 0 && h > 0)
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
