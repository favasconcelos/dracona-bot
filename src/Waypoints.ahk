#Include ..\libs\JSON.ahk
; #Warn
; #NoEnv

#SingleInstance force
CoordMode, ToolTip Mouse, Screen
SendMode Input
SetWorkingDir %A_ScriptDir%

;; Global variables
; focusedRow := -1
configName := ""
latestPosition := 1
lastEditedRow := 0

;; Gui :: Main
Gui, Main:+Owner
Gui, Main:New, -MaximizeBox, Waypoints

Gui, Main:Add, Button, w45 Default gOnButtonAdd, Add
Gui, Main:Add, Button, w45 ys gOnButtonLoad, Load
Gui, Main:Add, Button, w45 ys gOnButtonSave, Save
Gui, Main:Add, Button, w45 ys gOnButtonClear, Clear

Gui, Main:Add, ListView, xm r10 w210 NoSortHdr NoSort vOnWayListView gOnWayListView, X|Y|Delay
LV_ModifyCol(1, 50)
LV_ModifyCol(2, 50)
LV_ModifyCol(3, 95)

Gui, Main:Add, Button, w100 section gOnButtonStart, Start
Gui, Main:Add, Button, w100 ys gOnButtonStop, Stop

Menu, WayContextMenu, Add, Go, ContextGoToWay
Menu, WayContextMenu, Add, Remove, ContextRemoveWay
Menu, WayContextMenu, Default, Go

;; Gui :: Edit
Gui, Edit:+OwnerMain
Gui, Edit:New, -MaximizeBox -MinimizeBox, Edit Waypoint

Gui, Edit:Add, Text, x12 y9 w50 h20, X:
Gui, Edit:Add, Edit, x72 y9 w100 h20 vEditX

Gui, Edit:Add, Text, x12 y39 w50 h20, Y:
Gui, Edit:Add, Edit, x72 y39 w100 h20 vEditY

Gui, Edit:Add, Text, x12 y69 w50 h20, Delay:
Gui, Edit:Add, Edit, x72 y69 w100 h20 vEditDelay

Gui, Edit:Add, Button, x12 y99 w70 h30 gEditButtonSave default, Save
Gui, Edit:Add, Button, x92 y99 w80 h30 gEditButtonCancel, Cancel

;; Display the main window

Gui, Main:Show
return

;; --------------------------------------
;; List of hotkeys
;; Win + Alt + A
#!a:: AddNewWaypoint()
;; Win + Alt + C
#!c:: ClearWaypoints()
;; Win + Alt + M
#!m:: MouseTest()

;; --------------------------------------
;; Listeners
AddNewWaypoint() {
  Gui, Main:Default
  CoordMode, Mouse, Screen
  MouseGetPos, MouseX, MouseY
  LV_Add(Focus Vis, MouseX, MouseY)
}

ClearWaypoints() {
  Gui, Main:Default
  OnButtonClear()
}

MouseTest() {
  MouseGetPos, MouseX, MouseY
  SetControlDelay -1
  ControlClick,, Dracona,, Left, 1,% NA Pos "x"MouseX "y"MouseY
}

OnButtonAdd(CtrlHwnd, GuiEvent, EventInfo, ErrLevel:="") {
  ShowToolTip("TODO")

  ; SetControlDelay -1
  ; ControlClick, X500 Y300, Dracona,,,, Pos NA
}

OnButtonLoad(CtrlHwnd, GuiEvent, EventInfo, ErrLevel:="") {
  global configName
  FileSelectFile, filePath, 3, %A_WorkingDir%, Open a config file, Config file (*.json)
  if (filePath != "") {
    FileRead, rawData, %filePath%
    if not ErrorLevel {
      parsed := JSON.Load(rawData)
      configName := Format("{}", parsed.name)
      LV_Delete()
      for index, element in parsed.waypoints {
        x := element.x
        y := element.y
        delay := element.delay
        LV_Add(, x, y, delay)
      }
      Gui +OwnDialogs
      MsgBox, 64, Message, %configName% configuration loaded.
    }
  }
}

OnButtonSave(CtrlHwnd, GuiEvent, EventInfo, ErrLevel:="") {
  global configName
  InputBox, name, Config, Please enter the config name, , 290, 125, ,,,, %configName%
  if (not ErrorLevel) {
    waypoints := Array()
    Loop % LV_GetCount()
    {
        LV_GetText(x, A_Index, 1)
        LV_GetText(y, A_Index, 2)
        LV_GetText(delay, A_Index, 3)
        waypoint := { "x": x, "y": y, "delay": delay }
        waypoints.push(waypoint)
    }
    rawData := { "name": name, "waypoints": waypoints }
    content := JSON.dump(rawData,,2)
    fileName := Format("{}.json", name)
    file := FileOpen(fileName, "w")
    file.Write(content)
    file.Close()
    MsgBox, 64, Message, %name% configuration saved.
  }
}

OnButtonClear() {
  Gui +OwnDialogs
  MsgBox, 4, Clear Waypoints, You are about to clear the waypoints, continue?
  IfMsgBox Yes
    LV_Delete()
}

OnButtonStart(){
  global latestPosition
  if (A_GuiControl = "Start") {
    ControlSetText, %A_GuiControl%, Pause
    MoveToWaypoint(latestPosition, true)
  } else {
    ControlSetText, %A_GuiControl%, Start
    SetTimer, MoveToNextWaypoint, Off
  }
}

OnButtonStop(){
  StopAutoMove()
}

ContextGoToWay(){
  Gui, Main:Default
  focusedRow := LV_GetNext(0, "F")
  if (not focusedRow){
    return
  }
  StopAutoMove()
  MoveToWaypoint(focusedRow)
}

ContextRemoveWay(){
  Gui, Main:Default
  focusedRow := LV_GetNext(0, "F")
  if (not focusedRow){
    return
  }
  StopAutoMove()
  LV_Delete(focusedRow)
}

OnWayListView(CtrlHwnd, GuiEvent, EventInfo, ErrLevel:=""){
  if (GuiEvent = "DoubleClick") {
    focusedRow := LV_GetNext(0, "F")
    if (focusedRow > 0) {
      waypoint := GetWaypointAtIndex(focusedRow)
      global lastEditedRow := focusedRow 
      ShowEditRow(waypoint.x, waypoint.y, waypoint.delay)
    }
  }
}

MainGuiContextMenu(GuiHwnd, CtrlHwnd, EventInfo, IsRightClick, X, Y){
  if (A_GuiControl != "OnWayListView") {
    return
  } 
  Menu, WayContextMenu, Show, %A_GuiX%, %A_GuiY%
}

;; EDIT GUI
;; ------------------------------------------------------
ShowEditRow(x, y, delay){
  GuiControl, Edit:Text, EditX, %x%
  GuiControl, Edit:Text, EditY, %y%
  GuiControl, Edit:Text, EditDelay, %delay%

  Gui, Edit:Show, h145 w187
  Gui Main:+Disabled
}

EditButtonSave(){
  global lastEditedRow
  GuiControlGet, newX,, EditX
  GuiControlGet, newY,, EditY
  GuiControlGet, newDelay,, EditDelay
  Gui, Main:Default
  LV_Modify(lastEditedRow,, newX, newY, newDelay)
  LV_Modify(lastEditedRow, "Vis")
  EditButtonCancel()
}

EditButtonCancel(){
  Gui, Edit:Hide
  Gui, Main:-Disabled
  Gui, Main:Show
}

EditGuiClose:
EditGuiEscape:
  EditButtonCancel()
return

;; HELPER FUNCTIONS
;; ------------------------------------------------------

;; GetWaypointAtIndex
GetWaypointAtIndex(index){
  LV_GetText(x, index, 1)
  LV_GetText(y, index, 2)
  LV_GetText(delay, index, 3)

  return { "x": x, "y": y, "delay": delay }
}

;; Tooltip
ShowToolTip(message, timeout:=-1000){
  HideToolTip()
  ToolTip, %message%
  SetTimer, HideToolTip, %timeout%
}

HideToolTip(){
  ToolTip
}

;; MoveToWaypoint
MoveToWaypoint(index, moveToNext := false) {
  global latestPosition
  latestPosition := index

  waypoint := GetWaypointAtIndex(latestPosition)
  x := Format("{:d}", waypoint.x)
  y := Format("{:d}", waypoint.y)
  
  CoordMode, Mouse, Screen
  ; grab the mouse
  MouseGetPos, mouseX, mouseY
  ; debug
  message := Format("{:d},{:d}", x, y)
  ShowToolTip(message)
  ; Left Click
  Send, {Click, %x%, %y%}
  ; move back the mouse
  MouseMove, % mouseX, % mouseY
  
  if (moveToNext) {
    ; Sleep % waypoint.delay * 1000
    SetTimer MoveToNextWaypoint, % waypoint.delay * 1000
  }
}

MoveToNextWaypoint(){
  global latestPosition
  if (latestPosition <= LV_GetCount()) {
    MoveToWaypoint(latestPosition + 1, true)
  } else {
    latestPosition := 1
  }
}

StopAutoMove(){
  global latestPosition
  ; reset the latestPosition
  latestPosition = 0
  ; clear the timer
  SetTimer, MoveToNextWaypoint, Off
  ; reset the toggle btn
  ControlSetText, Pause, Start
}

#!x::
MainGuiClose:
MainGuiEscape:
  ExitApp
return