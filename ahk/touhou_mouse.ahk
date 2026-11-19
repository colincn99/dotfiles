#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Prevent Cursor Jump ---
CoordMode("Mouse", "Screen")
SendMode("Event")
SetMouseDelay(0)

; --- Configuration ---
NormalSpeed      := 18   ; Cursor pixels moved per tick (Normal)
SlowSpeed        := 5    ; Cursor pixels moved per tick (When holding L)
TickRate         := 15   ; Update interval in milliseconds

NormalScrollTick := 3    ; Scroll every 3 ticks (~45ms) in Normal mode
SlowScrollTick   := 10   ; Scroll every 10 ticks (~150ms) when holding L

MouseMinMove     := 30   ; Pixels physical mouse/trackpad must move within 300ms to exit
BumpWindowMs     := 300  ; Time window (ms) before small accidental bumps reset

MouseMode    := false
ScrollCount  := 0
LastX        := 0
LastY        := 0
BumpAccumX   := 0
BumpAccumY   := 0
LastBumpTime := 0

; Set initial tray icon
TraySetIcon("shell32.dll", 44) ; Star icon for Normal Mode

; Helper function to cleanly switch modes
SetMouseMode(state) {
    global MouseMode, LastX, LastY, ScrollCount, BumpAccumX, BumpAccumY, LastBumpTime
    if (MouseMode = state)
        return

    MouseMode    := state
    ScrollCount  := 0
    BumpAccumX   := 0
    BumpAccumY   := 0
    LastBumpTime := 0

    if (MouseMode) {
        MouseGetPos(&LastX, &LastY)
        SetTimer(MoveCursor, TickRate)
        TraySetIcon("shell32.dll", 138) ; Pointer/Arrow icon for Mouse Mode
        ToolTip("Mouse Mode: ON")
    } else {
        SetTimer(MoveCursor, 0)
        TraySetIcon("shell32.dll", 44)  ; Star icon for Normal Mode
        ToolTip("Mouse Mode: OFF")
    }
    SetTimer(() => ToolTip(), -1500)
}

; Dedicated ON shortcut: Ctrl + Shift + J
^+j::SetMouseMode(true)

; Dedicated OFF shortcut: Ctrl + Shift + K
^+k::SetMouseMode(false)

MoveCursor() {
    global ScrollCount, LastX, LastY, BumpAccumX, BumpAccumY, LastBumpTime
    if (!MouseMode)
        return

    ; --- Check for Deliberate Physical Mouse/Trackpad Movement ---
    MouseGetPos(&currX, &currY)
    diffX := currX - LastX
    diffY := currY - LastY

    if (diffX != 0 || diffY != 0) {
        now := A_TickCount
        ; Reset bump accumulator if pointer was idle longer than BumpWindowMs
        if (now - LastBumpTime > BumpWindowMs) {
            BumpAccumX := 0
            BumpAccumY := 0
        }
        LastBumpTime := now

        BumpAccumX += diffX
        BumpAccumY += diffY
        LastX := currX
        LastY := currY

        ; Exit only if cumulative movement exceeds MouseMinMove threshold
        if (Sqrt(BumpAccumX**2 + BumpAccumY**2) >= MouseMinMove) {
            SetMouseMode(false)
            return
        }
    }

    isSlow := GetKeyState("l", "P")

    ; --- Cursor Movement ---
    speed := isSlow ? SlowSpeed : NormalSpeed
    dx := 0
    dy := 0

    if GetKeyState("w", "P")
        dy -= 1
    if GetKeyState("s", "P")
        dy += 1
    if GetKeyState("a", "P")
        dx -= 1
    if GetKeyState("d", "P")
        dx += 1

    if (dx != 0 || dy != 0) {
        if (dx != 0 && dy != 0) {
            dx := Round(dx * speed / 1.41421356)
            dy := Round(dy * speed / 1.41421356)
        } else {
            dx *= speed
            dy *= speed
        }
        MouseMove(dx, dy, 0, "R")
        MouseGetPos(&LastX, &LastY) ; Update expected position after synthetic move
    }

    ; --- Scroll Wheel (E = Down, Q = Up) ---
    scrollDown := GetKeyState("e", "P")
    scrollUp   := GetKeyState("q", "P")

    if (scrollDown || scrollUp) {
        scrollInterval := isSlow ? SlowScrollTick : NormalScrollTick
        if (Mod(ScrollCount, scrollInterval) = 0) {
            if (scrollDown)
                Click("WheelDown")
            if (scrollUp)
                Click("WheelUp")
        }
        ScrollCount++
    } else {
        ScrollCount := 0
    }
}

; Hotkeys active ONLY when Mouse Mode is ON
#HotIf MouseMode

*w::return
*a::return
*s::return
*d::return
*q::return
*e::return
*l::return

*j:: {
    Click("Down")
    KeyWait("j")
    Click("Up")
}

*k:: {
    Click("Right Down")
    KeyWait("k")
    Click("Right Up")
}

; Exit Mouse Mode if physical mouse buttons are clicked
~*LButton:: {
    if !GetKeyState("j", "P")
        SetMouseMode(false)
}

~*RButton:: {
    if !GetKeyState("k", "P")
        SetMouseMode(false)
}

~*MButton::SetMouseMode(false)

#HotIf
