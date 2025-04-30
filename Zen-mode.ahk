#Requires AutoHotkey v2.0
#SingleInstance Force

global toggle := false
global WinData := Map()
global margin := 0.25          ; 25 % рамка
global overlayAlpha := 230     ; 0-255 (≈ 90 % затемнение)
/*
   Ctrl+Alt+Z — включить / выключить
   Ctrl+Alt+X — аварийное выключение
*/

^!z:: toggleZenMode()
^!x::{
    TrayTip "Zen Mode", "Экстренное отключение", 1
    disableZenMode()
}

toggleZenMode() {
    global toggle, WinData, margin, overlayAlpha
    toggle := !toggle

    if toggle {
        win := WinGetID("A")
        if !win {
            TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
            toggle := false
            return
        }
        ; сохраняем исходные координаты/размер
        WinGetPos(&ox,&oy,&ow,&oh, win)
        WinData := Map("id", win, "x", ox, "y", oy, "w", ow, "h", oh)

        screenW := SysGet(78)
        screenH := SysGet(79)

        newW := Round(screenW * (1 - margin * 2))
        newH := Round(screenH * (1 - margin * 2))
        newX := Round(screenW * margin)
        newY := Round(screenH * margin)

        ; снимаем всегда-поверх и разворачиваем
        try WinSetAlwaysOnTop(false, win)
        PostMessage(0x112, 0xF120,,, "ahk_id " win)  ; SC_RESTORE
        Sleep 100

        ; делаем окно поверх всех
        try WinSetAlwaysOnTop(true, win)
        WinActivate("ahk_id " win)

        ; убираем стиль WS_MAXIMIZE
        style := DllCall("GetWindowLongPtr", "ptr", win, "int", -16, "ptr")
        style &= ~0x01000000
        DllCall("SetWindowLongPtr", "ptr", win, "int", -16, "ptr", style)

        ; окончательное позиционирование
        DllCall("SetWindowPos", "ptr", win, "ptr", 0
            , "int", newX, "int", newY, "int", newW, "int", newH
            , "uint", 0x0040|0x0004|0x0020)          ; SWP_SHOWWINDOW|NOZORDER|FRAMECHANGED

        ; --- строим затемнение ---
        buildOverlays(newX,newY,newW,newH,screenW,screenH)
    } else
        disableZenMode()
}

disableZenMode() {
    global WinData
    id := WinData["id"]
    if id {
        try WinSetAlwaysOnTop(false, id)
        try DllCall("ShowWindow","ptr",id,"int",9) ; SW_RESTORE
        try DllCall("SetWindowPos","ptr",id,"ptr",0
            ,"int",WinData["x"],"int",WinData["y"],"int",WinData["w"],"int",WinData["h"],"uint",0)
    }
    for n in ["L","R","T","B"]
        if (gui := GuiGet("Overlay" n))
            gui.Destroy()
}

buildOverlays(nx,ny,nw,nh,sw,sh) {
    createOverlay("L", 0, 0, nx, sh)               ; слева
    createOverlay("R", nx+nw, 0, sw-(nx+nw), sh)   ; справа
    createOverlay("T", nx, 0, nw, ny)              ; сверху
    createOverlay("B", nx, ny+nh, nw, sh-(ny+nh))  ; снизу
}

createOverlay(name,x,y,w,h) {
    GuiObj := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    GuiObj.BackColor := "Black"
    GuiObj.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(overlayAlpha, GuiObj.Hwnd)
    GuiSet("Overlay" . name, GuiObj)
}

; --- утилиты ---
GuiMap := Map()
GuiSet(name,obj) => GuiMap[name] := obj
GuiGet(name)     => GuiMap.Has(name) ? GuiMap[name] : ""
