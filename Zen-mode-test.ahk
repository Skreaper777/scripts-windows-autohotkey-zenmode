#Requires AutoHotkey v2.0
#SingleInstance Force

; =============================================================
;  Zen-Mode v8.6 — обновлённая версия с исправлением фоновой картинки
; =============================================================

; ------------ Очистка GDI+ при выходе ------------
OnExit("Shutdown")

; ---------------------- ИНИЦИАЛИЗАЦИЯ GDI+ ----------------------
if !DllCall("GetModuleHandle", "Str", "gdiplus.dll")
    GdipStartup(0)

; ---------- ПАРАМЕТРЫ ОКНА ----------
global marginH       := 0.30
... (остальной код без изменений) ...

; ---------- картинка на монитор ----------
createImageOverlay(x,y,w,h) {
    global guiImgList, imageBackgroundPath, bgAlpha, overlayTopmost

    if !FileExist(imageBackgroundPath)
        return

    flags := "-Caption +ToolWindow +LastFound" . (overlayTopmost ? " +AlwaysOnTop" : "")
    imgGui := Gui(flags)
    imgGui.AddPicture(Format("x0 y0 w{} h{} +Center", w, h), imageBackgroundPath)
    imgGui.Show(Format("x{} y{} w{} h{} NoActivate", x, y, w, h))

    DllCall("SetLayeredWindowAttributes", "Ptr", imgGui.Hwnd, "UInt", 0, "UChar", bgAlpha, "UInt", 0x02)
    guiImgList.Push(imgGui)
}

; ---------- монитор по координате ----------
GetMonitorIndex(px,py) {
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index,&l,&t,&r,&b)
        if (px>=l && px<r && py>=t && py<b)
            return A_Index
    }
    return MonitorGetPrimary()
}

; ------------ Функция для корректного завершения GDI+ ------------
Shutdown(*) {
    if IsFunc("GdipShutdown")
        GdipShutdown()
}
