#Requires AutoHotkey v2.0

; Suppress the menu bar from focusing when Alt is released
A_MenuMaskKey := "vkE8"

; Track whether we are currently simulating holding down the Win key
WinHeld := false

; Map Alt+1 through Alt+9 dynamically
Loop 9 {
    Hotkey "!" A_Index, SwitchTaskbarApp.Bind(A_Index)
}

SwitchTaskbarApp(num, *) {
    global WinHeld
    if !WinHeld {
        Send "{Blind}{Alt up}{LWin down}"
        WinHeld := true
    }
    ; Send the number key while LWin remains held down
    Send "{Blind}{" num "}"
}

; Release LWin when either Alt key is physically released
~*LAlt up::
~*RAlt up:: {
    global WinHeld
    if WinHeld {
        Send "{LWin up}"
        WinHeld := false
    }
}