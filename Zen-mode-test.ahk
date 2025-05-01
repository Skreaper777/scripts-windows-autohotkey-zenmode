#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
;  Zen‑Mode v9.0 — финальный фикс дубликата GetMonitorIndex
; =============================================================
;  • Удалён лишний хвост «(px,py) { … }», оставлена ровно одна
;    корректная функция GetMonitorIndex — больше никаких «Return's
;    parameter should be blank…».
; =============================================================

; ---------- ПАРАМЕТРЫ ОКНА ----------
global marginH       := 0.30
global marginV       := 0.05

global marginH_2     := 0.35
global marginV_2     := 0.15

; ---------- ШТОРКА / BACKDROP ----------
global enableImageBackground := false

global imageBackgroundPath := "E:\\pic.jpg"

global bgColor        := "000000"
global bgAlpha        := 235     ; 0‑255 (0 непрозр.)
global bgBlurStrength := 0       ; 0‑19 (0 blur off)

global overlayTopmost := true

; ---------- ПРОЧЕЕ ----------
global enableEscExit := true

global hotkeyList   := ["^!z", "F1"]
global hotkeyList_2 := ["F2"]

; ---------- СЛУЖЕБНЫЕ ----------
global zen := false, savedWin := Map()
global guiBlur := ""            ; цвет/blur слой
global guiImgList := []         ; массив картинок

global altPressed := false, wasZenDuringAltTab := false, altPrevHwnd := 0

; =============================================================
;              Р Е Г И С Т Р А Ц И Я  H O T K E Y S
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
    altPrevHwnd := WinGetID("A")
}

~Tab::{
    global zen, altPressed, wasZenDuringAltTab
    if zen && altPressed {
        wasZenDuringAltTab := true
        disableZenMode()
    }
}

~Alt Up::{
    global altPressed, wasZenDuringAltTab, altPrevHwnd
    altPressed := false
    if wasZenDuringAltTab {
        wasZenDuringAltTab := false
        Loop 40 {
            Sleep 50
            hwnd := WinGetID("A")
            if (hwnd != altPrevHwnd && hwnd) {
                toggleZenMode()
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
;                    В К Л / В Ы К Л  Z E N
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
    monW := mR-mL, monH := mB-mT

    newW := Round(monW*(1-hMargin*2))
    newH := Round(monH*(1-vMargin*2))
    newX := mL + Round(monW*hMargin)
    newY := mT + Round(monH*vMargin)
    WinMove(newX,newY,newW,newH, hwnd)

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
    for g in guiImgList
        if IsObject(g)
            g.Destroy()
    guiImgList := []

    zen := false
}

; =============================================================
;                   Ш Т О Р К А (per‑monitor)
; =============================================================
createBackdropLayers() {
    global enableImageBackground, imageBackgroundPath

    if enableImageBackground && FileExist(imageBackgroundPath) {
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            createImageOverlay(l, t, r-l, b-t)
        }
    }

    vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
    createBlurOverlay(vx, vy, vw, vh)
}

; ---------- цвет + (опц.) blur ----------
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
        pSetWCA := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32"), "AStr", "SetWindowCompositionAttribute", "Ptr")
        if pSetWCA {
            acc := Buffer(16,0)
            NumPut("UInt",4,acc,0), NumPut("UInt",bgBlurStrength,acc,4)
            alpha := 255-bgAlpha, rgb := "0x" SubStr(bgColor,5,2) SubStr(bgColor,3,2) SubStr(bgColor,1,2)
            NumPut("UInt",(alpha<<24)|(Integer(rgb)&0xFFFFFF),acc,8)
            wca := Buffer(A_PtrSize=8?24:16,0)
            NumPut("UInt",19,wca,0), NumPut("Ptr",acc.Ptr,wca,A_PtrSize=8?8:4), NumPut("UPtr",acc.Size,wca,A_PtrSize=8?16:8)
            DllCall(pSetWCA, "Ptr", hwnd, "Ptr", wca.Ptr)
        }
    }
}

; ---------- картинка (cover) ----------
createImageOverlay(x,y,wMon,hMon) {
    global guiImgList, imageBackgroundPath, bgAlpha, overlayTopmost

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    picGui := Gui(flags)

    imgW := 0, imgH := 0
    if !ImageSize(imageBackgroundPath, &imgW, &imgH) {
        picGui.Destroy()
        return
    }

    monRatio := wMon / hMon
    imgRatio := imgW / imgH

    if (monRatio >= imgRatio) {
        newW := wMon
        scale := imgW / newW
        newH := Floor(imgH / scale)
        offsetX := 0
        offsetY := (hMon - newH)//2
    } else {
        newH := hMon
        scale := imgH / newH
        newW := Floor(imgW / scale)
        offsetY := 0
        offsetX := (wMon - newW)//2
    }

    picGui.AddPicture(Format("x{} y{} w{} h{} +Center", offsetX, offsetY, newW, newH), imageBackgroundPath)
    picGui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, wMon, hMon))

    DllCall("SetLayeredWindowAttributes", "Ptr", picGui.Hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)
    guiImgList.Push(picGui)
}

; --- размеры изображения (без GDI+) ---
ImageSize(path, &w, &h) {
    w := h := 0
    hBitmap := LoadPicture(path) ; HBITMAP (NULL on failure)
    if (hBitmap) {
        bm := Buffer(24, 0)
        if (DllCall("GetObject", "Ptr", hBitmap, "Int", 24, "Ptr", bm.Ptr)) {
            w := NumGet(bm, 4, "Int")
            h := NumGet(bm, 8, "Int")
        }
        DllCall("DeleteObject", "Ptr", hBitmap)
        return (w > 0 && h > 0)
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
