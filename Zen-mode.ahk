#Requires AutoHotkey v2.0
#SingleInstance Force

global toggle := false
global WinData := Map()

^!z::{
    toggleZenMode()
}

^!x::{
    TrayTip "Zen Mode", "Экстренное отключение Zen Mode", 1
    id := WinData["id"]
    if id {
        try WinSetAlwaysOnTop(false, id)
        PostMessage(0x112, 0xF120,,, "ahk_id " id)  ; WM_SYSCOMMAND, SC_RESTORE
        flags := 0x0040 | 0x0020 | 0x0004 ; SWP_SHOWWINDOW | SWP_FRAMECHANGED | SWP_NOZORDER
            try WinMove(id, WinData["x"], WinData["y"], WinData["w"], WinData["h"])
    }
    for name in ["L", "R", "T", "B"] {
        guiObj := GuiGet("Overlay" . name)
        if IsObject(guiObj)
            guiObj.Destroy()
    }
    toggle := false
}

toggleZenMode() {
    global origWin
    global toggle, WinData
    toggle := !toggle

    if toggle {
        win := WinGetID("A")
        origWin := win
        if !win {
            TrayTip "Zen Mode", "❌ Активное окно не найдено", 1
            toggle := false
            return
        }
        x := 0, y := 0, w := 0, h := 0
        WinGetPos(&x, &y, &w, &h, win)
        WinData := Map("id", win, "x", x, "y", y, "w", w, "h", h)

        screenW := SysGet(78)
        screenH := SysGet(79)

        newW := Round(screenW * 0.5)
        newH := h
        newX := Round((screenW - newW) / 2)
        newY := y

        TrayTip "Zen Mode", "newX:" newX ", newW:" newW ", screenW:" screenW, 1

        try WinSetAlwaysOnTop(false, win)
        PostMessage(0x112, 0xF120,,, "ahk_id " win)  ; WM_SYSCOMMAND, SC_RESTORE
        Sleep 100
                try WinSetAlwaysOnTop(true, origWin)
        try WinActivate(origWin)

        ; Принудительное снятие стиля WS_MAXIMIZE, если он есть
        style := DllCall("GetWindowLongPtr", "ptr", origWin, "int", -16, "ptr")
        style := style & ~0x01000000  ; WS_MAXIMIZE
        DllCall("SetWindowLongPtr", "ptr", origWin, "int", -16, "ptr", style)

        DllCall("SetWindowPos", "ptr", origWin, "ptr", 0, "int", newX, "int", newY, "int", newW, "int", newH, "uint", 0x0040 | 0x0004 | 0x0020)  ; SWP_SHOWWINDOW | SWP_NOZORDER | SWP_FRAMECHANGED

        createOverlay("L", 0, 0, newX, screenH)

        rightX := newX + newW
        rightW := screenW - rightX
        if (rightW > 0)
            createOverlay("R", rightX, 0, rightW, screenH)

        createOverlay("T", newX, 0, newW, newY)

        bottomY := newY + newH
        bottomH := screenH - bottomY
        createOverlay("B", newX, bottomY, newW, bottomH)

    } else {
        id := WinData["id"]
        if id {
            try WinSetAlwaysOnTop(false, id)
            try DllCall("ShowWindow", "ptr", id, "int", 9)
            try DllCall("SetWindowPos", "ptr", id, "ptr", 0, "int", WinData["x"], "int", WinData["y"], "int", WinData["w"], "int", WinData["h"], "uint", 0)
        }
        for name in ["L", "R", "T", "B"] {
            guiObj := GuiGet("Overlay" . name)
            if IsObject(guiObj)
                guiObj.Destroy()
        }
    }
}

createOverlay(name, x, y, w, h) {
    GuiObj := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
    GuiObj.BackColor := "Black"
    GuiObj.Show("x" x " y" y " w" w " h" h " NoActivate")
    WinSetTransparent(150, GuiObj.Hwnd)
    GuiSet("Overlay" . name, GuiObj)
}

WinSetTransparentAnimated(gui, finalAlpha, steps := 15) {
    hwnd := gui.Hwnd
    Loop steps {
        alpha := Round((A_Index / steps) * finalAlpha)
        WinSetTransparent(alpha, hwnd)
        Sleep 10
    }
}

GuiMap := Map()
GuiSet(name, obj) => GuiMap[name] := obj
GuiGet(name) => GuiMap.Has(name) ? GuiMap[name] : ""
