; vim:ft=autohotkey

; Scripting silliness for Roblox (specifically The Wild West but could possibly 
; be extended to others).
;
; The goal is basically to be able to Toggle Aim/Camera Follows Mouse. Roblox
; games generally require the right mouse button to be held down to aim, and we
; want that to be toggleable, and we also want to be able to indicate when
; messing with that toggle should be temporarily suspended (when typing in a
; text window, for example).
; There are normally ways to toggle "hold down RMB" with other utilities I
; have, BUT when certain keys are pressed, Roblox seemingly throws away the
; current RMB-pressed state. So it has to be reestablished.
; So in the end, we have two states to track - whether or not RMB should be
; held down right now (for doing the Right Thing during refreshes) and whether
; or not we're currently in a mode in-game where messing with that toggle
; should be temporarily suspended.
; This got turned into a class because, frankly, I was rapidly ending up with
; too many globals. And I needed something to track the state of our state (so
; now it's even got a 'GUI'!)
;
; States are:
; * HoldingRMB: We want the RMB (Right Mouse Button) to be held down.
; * ChatMode: Halt *all* processing of RMB holds because we are inputting text.
; I used to also have a SuspendingHold for temporarily suspending Hold whether
; it was on or off and then resume afterwards, but backing out of Suspend Mode
; could be done with multiple different possible inputs and it proved to be too
; difficult to track reliably, so instead those cases Force Hold Off.
;
; Despite best efforts, occasionally use of this script will put the system in
; a state such that left and right mouse clicks do not make it through to *any*
; other window. The only reliable way I've found of clearing this state is to,
; using keyboard shortcuts, *hibernate the computer then bring it back up
; again*. Yeah. It's that kind of hack. :(

class RobloxHoldRMB {
    __new(DestWindow) {
        this.DestWindow := DestWindow
        this.HoldingRMB := False
        this.ChatMode := False
        this.ButtonCount := 0
        this.OSDGui := this._OSDCreateGui()
        ; figure center of screen
        WinGetClientPos(&RBX, &RBY, &RBW, &RBH, this.DestWindow)
        this.xcenter := (RBW) // 2
        this.ycenter := (RBH) // 2
    }
    
    _OSDCreateGui() {
        OSDGui := Gui("-caption +alwaysontop +toolwindow")
        OSDGui.SetFont("s10 w600", "Arial Bold")
        OSDGui.MarginX := 0
        OSDGui.MarginY := 0
        OSDGui.Add("Text", "x0 y0 cWhite backgroundRed vRMBHeld", "Hold")
        OSDGui.Add("Text", "x+10 y0 cWhite backgroundRed vRMBChat", "Chat")
        OSDGui.Add("Text", "x+10 y0 cWhite backgroundBlue vRMBCount",
                this.ButtonCount)
        OSDGui.Show("x500 y80")
        return OSDGui
    }
    
    _CenterMouse() {
        MouseMove(this.xcenter, this.ycenter, 0)
    }
    
    _SendClick(updown) {
        ;ControlClick("x" . this.xcenter . " y" . this.ycenter, this.DestWindow,,"R",,updown . " Pos NA")
        ; Roblox doesn't seem to respond to ControlClick at all (probably for
        ; anticheat reasons; you could implement an idle background bot with
        ; it). So instead we armor Sends with WinActive checks.
        WinActivate(this.DestWindow)
        If (updown = "D") {
            If (WinActive(this.DestWindow)) {
                Send("{RButton down}")
                this.ButtonCount += 1
            }
        } Else {
            If (WinActive(this.DestWindow)) {
                Send("{RButton up}")
                this.ButtonCount -= 1
            }
        }
        this.OSDGui["RMBCount"].Text := this.ButtonCount
        this.OSDGui["RMBCount"].Redraw()
    }
    
    _UpdateGui(textctl, onoroff) {
        If onoroff {
            this.OSDGui[textctl].Opt("backgroundGreen")
        } Else {
            this.OSDGui[textctl].Opt("backgroundRed")
        }
        this.OSDGui[textctl].Redraw()
    }
    
    _Reconcile() {
        While this.ButtonCount > 0 {
            this._SendClick("U")
        }
        While this.ButtonCount < 0 {
            this._SendClick("D")
        }
    }
    
    RMBRefresh() {
        ; Refresh RMB hold state after Roblox throws it away.
        this._Reconcile()
        if (!this.ChatMode and this.HoldingRMB) {
            this._CenterMouse()
            ;Sleep(200)
            ;this._SendClick("D")
            Loop(3) {
                this._SendClick("D")
                Sleep 100
            }
        }
    }
    
    RMBChatSwitch(mode) {
        this.ChatMode := mode
        this._UpdateGui("RMBChat", this.ChatMode)
        this.RMBRefresh()
    }
    
    RMBForceOff() {
        ; only needs to fire if we're already on
        if (!this.ChatMode and this.HoldingRMB) {
            this.HoldingRMB := False
            this._UpdateGui("RMBHeld", this.HoldingRMB)
            this.RMBRefresh()
        }
    }
    
    RMBToggle() {
        if (!this.ChatMode) {
            this.HoldingRMB := !this.HoldingRMB
            this._UpdateGui("RMBHeld", this.HoldingRMB)
            this.RMBRefresh()
        }
    }
    
    __Delete() {
        this._Reconcile()
        this.OSDGui.Destroy()
    }
}

RBHRMB() {
    global RBHRMBInstance
    if (!IsSet(RBHRMBInstance)) {
        try {
            RBHRMBInstance := RobloxHoldRMB(
                    WinExist("ahk_exe RobloxPlayerBeta.exe"))
                    ;WinExist("ahk_exe KeyTest.exe"))
        }
    }
    return RBHRMBInstance
}
RBHRMB_Exit() {
    global RBHRMBInstance
    if (IsSet(RBHRMBInstance)) {
        RBHRMBInstance := unset   ; destroy (AHK will GC the object)
    }
}

#HotIf WinActive("ahk_exe RobloxPlayerBeta.exe")
;#HotIf WinActive("ahk_exe KeyTest.exe")
; Currently set up for controls for The Wild West.
~1::RBHRMB().RMBRefresh()   ; hotbar weapons and tools
~2::RBHRMB().RMBRefresh()
~3::RBHRMB().RMBRefresh()
~4::RBHRMB().RMBRefresh()
~5::RBHRMB().RMBRefresh()
~6::RBHRMB().RMBRefresh()
~7::RBHRMB().RMBForceOff()  ; for sheriff baton
~8::RBHRMB().RMBForceOff()  ; for sheriff cuffs
~v::RBHRMB().RMBRefresh()   ; first/third person switch
~b::RBHRMB().RMBForceOff()  ; backpack window
~m::RBHRMB().RMBForceOff()  ; map window
~Tab::RBHRMB().RMBForceOff()  ; all-around window
~t::RBHRMB().RMBForceOff()  ; character customization window
~h::RBHRMB().RMBForceOff()  ; Pick A Horse window
~k::RBHRMB().RMBForceOff()  ; Skills window
~l::RBHRMB().RMBForceOff()  ; Quests window
~p::RBHRMB().RMBRefresh()   ; Friendly/Hostile toggle
~e Up::RBHRMB().RMBRefresh()   ; primary use/action
~f Up::RBHRMB().RMBRefresh()   ; secondary use/action
        ; The above two are complicated because they don't always pop up a UX
        ; dialog. When they *do* (talking to shopkeepers, opening a chest, et
        ; cetera) we'd prefer ForceOff, and when they *don't* (picking up a
        ; drop, sitting down, et cetera) we'd prefer Refresh. And we have no
        ; reliable way of detecting which because Roblox doesn't expose hooks
        ; for detecting such states for anticheat reasons.
        ; So I'm opting to just leave them alone and do any switching manually.
        ; CORRECTION: I'm having it refresh, and turning things off manually.
        ; CORRECTION 2: Having them only refresh on keyup (not down) because
        ; otherwise some robbery-related actions Don't Work.
~/::RBHRMB().RMBChatSwitch(True)    ; send a message
~Esc::{ ; EITHER Roblox menu OR cancel chat
    ; forceoff first as it'll work outside of chat mode
    ; otherwise, just end chat mode
    RBHRMB().RMBForceOff()
    RBHRMB().RMBChatSwitch(False)
}
~Enter::RBHRMB().RMBChatSwitch(False)   ; Chat Send
F13::RBHRMB().RMBToggle()     ; primary toggle key
`::{    ; "master reset and rehold" key
    RBHRMB_Exit()
    RBHRMB().RMBToggle()
}
Del::RBHRMB_Exit()  ; "bail out" key
#HotIf
F14::Reload ; in case the "can't click on anything else" bug recurs
