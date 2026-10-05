-- Banjo R15 build: 2.3.8-r15.4
local Menu={};Menu.__index=Menu
local INPUT=game:GetService("UserInputService")
local ANIMATIONS={
    {"idle","Idle","Standing still"},{"walk","Walking","Walking, slow walking, and creeping"},
    {"run","Running","Ordinary running"},{"jump","Jumping","The upward part of a jump"},
    {"fall","Falling","Falling and the downward part of a jump"},{"climb","Climbing","Climbing a truss"},
    {"swim","Swimming","Moving while swimming or diving"},{"swimidle","Swimming idle","Staying still in water"},
    {"sit","Sitting","Sitting while the game has control"},
    {"game","Emotes and actions","Independent of the movement switches"},
}
local TABS={"General","Animations","Display","Gear","Movement","Camera","Profiles"}
local NOTES={General="Your everyday controls.",Animations="Movement switches and emotes are independent.",
    Display="Adjust the bear and HUD.",Gear="Equipped Tools use your normal Backpack controls.",
    Movement="Tune Banjo's movement assistance.",Camera="Adjust your view and camera height.",
    Profiles="Keep your setup, or export it as build defaults."}
local C={panel=Color3.fromRGB(24,26,29),raised=Color3.fromRGB(37,40,44),line=Color3.fromRGB(53,56,61),
    text=Color3.fromRGB(238,237,231),muted=Color3.fromRGB(159,163,171),accent=Color3.fromRGB(224,183,99),
    dark=Color3.fromRGB(24,26,29),off=Color3.fromRGB(69,73,80)}
local function make(class,name,parent,props)
    local object=Instance.new(class);object.Name=name
    for key,value in pairs(props or {}) do object[key]=value end
    object.Parent=parent;return object
end
local function round(object,radius)
    local corner=object:FindFirstChild("Corner")
    if corner then corner.CornerRadius=UDim.new(0,radius)
    else make("UICorner","Corner",object,{CornerRadius=UDim.new(0,radius)}) end
end
local function label(name,parent,text,position,size,textSize,color)
    return make("TextLabel",name,parent,{Text=text,Position=position,Size=size,BackgroundTransparency=1,
        Font=Enum.Font.Gotham,TextSize=textSize or 14,TextColor3=color or C.text,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
end
local function button(name,parent,text,position,size)
    local object=make("TextButton",name,parent,{Text=text,Position=position,Size=size,
        BackgroundColor3=C.raised,BorderSizePixel=0,TextColor3=C.text,Font=Enum.Font.Gotham,
        TextSize=12,AutoButtonColor=true,Modal=false})
    round(object,5);return object
end
function Menu:_connect(signal,callback)
    local connection=signal:Connect(callback);table.insert(self.connections,connection);return connection
end
function Menu:_enabled(key)return self.runtime:GetAttribute("R15Use_"..key)~=false end
function Menu:_row(page,key,title,description,getValue,onClick)
    local row=make("Frame",key,page,{Size=UDim2.new(1,-8,0,62),BackgroundTransparency=1,
        BorderSizePixel=0,LayoutOrder=#self.rowOrder+1})
    label("Title",row,title,UDim2.fromOffset(0,7),UDim2.new(1,-118,0,20),14)
    local caption=label("Description",row,description,UDim2.fromOffset(0,29),UDim2.new(1,-118,0,26),11,C.muted)
    caption.TextWrapped=true;caption.TextYAlignment=Enum.TextYAlignment.Top
    make("Frame","Divider",row,{Position=UDim2.new(0,0,1,-1),Size=UDim2.new(1,0,0,1),
        BackgroundColor3=C.line,BackgroundTransparency=.55,BorderSizePixel=0})
    local isSwitch=type(getValue())=="boolean"
    local control=button("Toggle",row,"",UDim2.new(1,isSwitch and -42 or -104,.5,isSwitch and -11 or -15),
        UDim2.fromOffset(isSwitch and 40 or 102,isSwitch and 22 or 30))
    local thumb
    if isSwitch then
        round(control,11)
        thumb=make("Frame","Thumb",control,{Size=UDim2.fromOffset(16,16),Position=UDim2.fromOffset(3,3),
            BackgroundColor3=C.text,BorderSizePixel=0});round(thumb,8)
    end
    self.rows[key]={button=control,thumb=thumb,getValue=getValue}
    table.insert(self.rowOrder,key)
    self:_connect(control.Activated,function()onClick();self:refresh()end)
end
function Menu:_option(list,key,title,description,choices)
    local default=self.runtimeSettings.Defaults[key]
    if default==nil then default=choices[1][1] end
    local function value()local current=self.runtime:GetAttribute(key);if current==nil then return default end;return current end
    local function caption()
        local current=value();if type(current)=="boolean" then return current end
        for _,choice in ipairs(choices) do if choice[1]==current then return choice[2] end end
        return tostring(current)
    end
    self:_row(list,key,title,description,caption,function()
        local current=value();local nextIndex=1
        for index,choice in ipairs(choices) do if choice[1]==current then nextIndex=index%#choices+1;break end end
        self.runtime:SetAttribute(key,choices[nextIndex][1])
    end)
    self:_connect(self.runtime:GetAttributeChangedSignal(key),function()self:refresh()end)
end
function Menu:refresh()
    if self.destroyed then return end
    for _,key in ipairs(self.rowOrder) do
        local row=self.rows[key];local value=row.getValue()
        if row.thumb then
            row.button.BackgroundColor3=value and C.accent or C.off
            row.thumb.BackgroundColor3=value and C.dark or C.text
            row.thumb.Position=UDim2.fromOffset(value and 21 or 3,3)
            row.button:SetAttribute("Enabled",value==true)
        else row.button.Text=tostring(value) end
    end
    local enabled=self.runtime:GetAttribute("R15Enabled")~=false
    self.animationNote.Text=enabled and NOTES.Animations or "R15 is off in General. Your selections are kept."
    self.r15Status.Text=enabled and "R15  /  ACTIVE" or "R15  /  OFF"
end
function Menu:selectTab(name)
    if self.destroyed or not self.pages[name] then return end
    self.selectedTab=name;self.pageTitle.Text=name
    for key,page in pairs(self.pages) do
        page.Visible=key==name
        self.tabs[key].BackgroundTransparency=key==name and 0 or 1
        self.tabs[key].Caption.TextColor3=key==name and C.text or C.muted
        self.tabs[key].Accent.Visible=key==name
    end
    self.resetButton.Visible=name~="Animations"
    self.centerButton.Visible=name=="Profiles"
    self.enableAllButton.Visible=name=="Animations";self.disableAllButton.Visible=name=="Animations"
    self.emotesOnlyButton.Visible=name=="Animations"
    self:refresh()
end
function Menu:setVisible(visible)
    if self.destroyed then return end
    self.overlay.Visible=visible==true
    if not visible then self:_endDrag() end
    self.openButton.Text=visible and "Close settings  [F5]" or "Settings  [F5]"
    self:refresh()
end
function Menu:toggle()self:setVisible(not self.overlay.Visible)end
function Menu:setAllAnimations(enabled)
    for _,entry in ipairs(ANIMATIONS) do self.runtime:SetAttribute("R15Use_"..entry[1],enabled==true) end
    self:refresh()
end
function Menu:emotesOnly()
    self:setAllAnimations(false);self.runtime:SetAttribute("R15Use_game",true)
    self.runtime:SetAttribute("R15Enabled",true);self.runtime:SetAttribute("ToolArmPoses",false);self:refresh()
end
function Menu:resetDefaults()self.runtimeSettings:resetDefaults();self:_layout();self:refresh()end
function Menu:centerWindow()
    self.offsetX=0;self.offsetY=0
    self.runtime:SetAttribute("MenuOffsetX",0);self.runtime:SetAttribute("MenuOffsetY",0);self:_position()
end
function Menu:_position()
    local size=self.viewport;if not size then return end
    local maxX=math.max(0,(size.X-self.width*self.scale.Scale)/2-12)
    local maxY=math.max(0,(size.Y-self.height*self.scale.Scale)/2-12)
    self.offsetX=math.clamp(self.offsetX or 0,-maxX,maxX);self.offsetY=math.clamp(self.offsetY or 0,-maxY,maxY)
    self.panel.Position=UDim2.new(.5,self.offsetX,.5,self.offsetY)
end
function Menu:_layout()
    if self.destroyed then return end
    local camera=workspace.CurrentCamera;if not camera then return end
    self.viewport=camera.ViewportSize
    local compact=self.viewport.X<740
    self.width=compact and 440 or 680;self.height=compact and 570 or 500
    self.panel.Size=UDim2.fromOffset(self.width,self.height)
    self.scale.Scale=math.max(.1,math.min(1,(self.viewport.X-24)/self.width,(self.viewport.Y-24)/self.height))
    local x=compact and 20 or 168;local contentWidth=self.width-x-24
    self.navigation.Position=UDim2.fromOffset(compact and 16 or 16,compact and 80 or 88)
    self.navigation.Size=UDim2.fromOffset(compact and 408 or 128,compact and 36 or 288)
    self.navigation.ScrollingDirection=compact and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y
    self.navigation.CanvasSize=UDim2.fromOffset(compact and #TABS*102 or 0,compact and 0 or #TABS*40)
    self.sidebarLine.Visible=not compact
    for index,name in ipairs(TABS) do
        local tab=self.tabs[name]
        tab.Position=UDim2.fromOffset(compact and (index-1)*102 or 0,compact and 0 or (index-1)*40)
        tab.Size=UDim2.fromOffset(compact and 96 or 126,34)
        tab.Accent.Position=compact and UDim2.new(0,10,1,-2) or UDim2.fromOffset(0,8)
        tab.Accent.Size=compact and UDim2.new(1,-20,0,2) or UDim2.fromOffset(2,18)
        tab.Caption.TextXAlignment=compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
    end
    self.pageTitle.Position=UDim2.fromOffset(x,compact and 130 or 90)
    self.pageTitle.Size=UDim2.fromOffset(contentWidth,28)
    for _,page in pairs(self.pages) do
        page.Position=UDim2.fromOffset(x,compact and 164 or 124)
        page.Size=UDim2.fromOffset(contentWidth,compact and 346 or 310)
        page.Note.Size=UDim2.new(1,-8,0,22)
        page.Options.Position=UDim2.fromOffset(0,30)
        page.Options.Size=UDim2.new(1,0,1,-30)
    end
    self.footerLine.Position=UDim2.fromOffset(x,compact and 518 or 446)
    self.footerLine.Size=UDim2.fromOffset(contentWidth,1)
    local y=compact and 530 or 460;local third=(contentWidth-16)/3
    self.resetButton.Position=UDim2.fromOffset(x,y);self.resetButton.Size=UDim2.fromOffset(122,28)
    self.centerButton.Position=UDim2.fromOffset(x+130,y);self.centerButton.Size=UDim2.fromOffset(124,28)
    for index,object in ipairs({self.enableAllButton,self.disableAllButton,self.emotesOnlyButton}) do
        object.Position=UDim2.fromOffset(x+(index-1)*(third+8),y);object.Size=UDim2.fromOffset(third,28)
    end
    self.r15Status.Visible=not compact
    if not self.drag then
        self.offsetX=(self.runtime:GetAttribute("MenuOffsetX") or 0)*self.viewport.X
        self.offsetY=(self.runtime:GetAttribute("MenuOffsetY") or 0)*self.viewport.Y
    end
    self:_position()
end
function Menu:_watchCamera()
    if self.cameraConnection then self.cameraConnection:Disconnect();self.cameraConnection=nil end
    self:_layout()
    if workspace.CurrentCamera then
        self.cameraConnection=workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()self:_layout()end)
    end
end
function Menu:_startDrag(input)
    if not self.overlay.Visible or self.drag then return end
    local kind=input.UserInputType
    if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
    self.drag={input=input,x=input.Position.X,y=input.Position.Y,
        offsetX=self.offsetX or 0,offsetY=self.offsetY or 0,touch=kind==Enum.UserInputType.Touch}
end
function Menu:_moveDrag(input)
    local drag=self.drag;if not drag then return end
    if drag.touch then if input~=drag.input then return end
    elseif input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    self.offsetX=drag.offsetX+input.Position.X-drag.x;self.offsetY=drag.offsetY+input.Position.Y-drag.y
    self:_position()
end
function Menu:_endDrag()
    if not self.drag then return end
    self.drag=nil
    if self.viewport then
        local x=self.offsetX/math.max(1,self.viewport.X);local y=self.offsetY/math.max(1,self.viewport.Y)
        self.runtime:SetAttribute("MenuOffsetX",x);self.runtime:SetAttribute("MenuOffsetY",y)
    end
end
function Menu:_profilePage()
    local list=self.lists.Profiles
    local actions=make("Frame","Actions",list,{Size=UDim2.new(1,-8,0,82),BackgroundTransparency=1,LayoutOrder=1})
    local save=button("SaveProfile",actions,"Save profile",UDim2.fromOffset(0,0),UDim2.new(.5,-4,0,32))
    local load=button("LoadProfile",actions,"Load saved",UDim2.new(.5,4,0,0),UDim2.new(.5,-4,0,32))
    local generate=button("GenerateList",actions,"Generate settings list",UDim2.fromOffset(0,42),UDim2.new(1,-104,0,32))
    local copy=button("CopyList",actions,"Copy list",UDim2.new(1,-96,0,42),UDim2.fromOffset(96,32))
    generate.Visible=self.runtimeSettings.ExportEnabled~=false;copy.Visible=generate.Visible
    self.profileStatus=label("Status",list,self.runtimeSettings.profileLoaded and "Saved profile loaded." or "Save a profile, or generate a list to send back.",
        UDim2.fromOffset(0,0),UDim2.new(1,-8,0,40),12,C.muted)
    self.profileStatus.LayoutOrder=2;self.profileStatus.TextWrapped=true
    self.exportBox=make("TextBox","SettingsList",list,{Size=UDim2.new(1,-8,0,210),BackgroundColor3=C.raised,
        BorderSizePixel=0,Text="",TextColor3=C.text,Font=Enum.Font.Code,TextSize=11,TextWrapped=false,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
        MultiLine=true,ClearTextOnFocus=false,TextEditable=false,Visible=false,LayoutOrder=3})
    self.exportBox.Size=UDim2.new(1,-8,0,210);round(self.exportBox,5)
    make("UIPadding","Padding",self.exportBox,{PaddingLeft=UDim.new(0,10),PaddingTop=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
    self:_connect(save.Activated,function()local _,message=self.runtimeSettings:saveProfile();self.profileStatus.Text=message end)
    self:_connect(load.Activated,function()
        local _,message=self.runtimeSettings:loadProfile();self.profileStatus.Text=message;self:_layout();self:refresh()
    end)
    local function export()
        self.exportBox.Text=self.runtimeSettings:exportList();self.exportBox.Visible=true
        -- Full-height text stays reachable in the page's scroller.
        local _,lines=self.exportBox.Text:gsub("\n","");self.exportBox.Size=UDim2.new(1,-8,0,(lines+1)*14+20)
    end
    self:_connect(generate.Activated,function()export();self.profileStatus.Text="Copy this list and send it back to make these your defaults." end)
    self:_connect(copy.Activated,function()
        export()
        if type(setclipboard)=="function" and pcall(setclipboard,self.exportBox.Text) then
            self.profileStatus.Text="Copied. Send the list back when you're ready."
        else
            self.exportBox:CaptureFocus();self.exportBox.CursorPosition=#self.exportBox.Text+1;self.exportBox.SelectionStart=1
            self.profileStatus.Text="List selected. Press Ctrl+C to copy it."
        end
    end)
end
function Menu.new(player,runtime,hud,toggleLighting,runtimeSettings)
    local self=setmetatable({runtime=runtime,hud=hud,toggleLighting=toggleLighting,runtimeSettings=runtimeSettings,
        connections={},rows={},rowOrder={},pages={},tabs={},lists={}},Menu)
    self.gui=make("ScreenGui","BK_SettingsMenu",player.PlayerGui,{ResetOnSpawn=false,IgnoreGuiInset=true,
        DisplayOrder=50,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    self.openButton=button("OpenSettings",self.gui,"Settings  [F5]",UDim2.new(1,-12,0,94),UDim2.fromOffset(150,30))
    self.openButton.AnchorPoint=Vector2.new(1,0)
    self.overlay=make("Frame","Overlay",self.gui,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false})
    local dismiss=make("TextButton","Dismiss",self.overlay,{Size=UDim2.fromScale(1,1),Text="",
        BackgroundColor3=C.dark,BackgroundTransparency=.36,BorderSizePixel=0,AutoButtonColor=false,Modal=false,ZIndex=1})
    self.panel=make("Frame","Panel",self.overlay,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(680,500),BackgroundColor3=C.panel,BorderSizePixel=0,Active=true,ZIndex=2});round(self.panel,10)
    make("UIStroke","Border",self.panel,{Color=C.line,Thickness=1,Transparency=.2})
    self.scale=make("UIScale","FitToScreen",self.panel,{Scale=1})
    local header=make("Frame","DragHeader",self.panel,{Size=UDim2.new(1,-64,0,70),BackgroundTransparency=1,Active=true})
    label("Brand",header,"BANJO",UDim2.fromOffset(20,12),UDim2.fromOffset(200,16),10,C.accent)
    label("Title",header,"Settings",UDim2.fromOffset(20,31),UDim2.fromOffset(260,26),22)
    label("DragHint",header,"drag to move",UDim2.new(1,-125,0,28),UDim2.fromOffset(105,20),11,C.muted)
    local close=button("Close",self.panel,"×",UDim2.new(1,-50,0,23),UDim2.fromOffset(30,30))
    make("Frame","HeaderLine",self.panel,{Position=UDim2.fromOffset(20,70),Size=UDim2.new(1,-40,0,1),BackgroundColor3=C.line,BorderSizePixel=0})
    self.navigation=make("ScrollingFrame","Navigation",self.panel,{BackgroundTransparency=1,BorderSizePixel=0,
        ScrollBarThickness=0,CanvasSize=UDim2.fromOffset(0,280),Size=UDim2.fromOffset(128,288)})
    self.sidebarLine=make("Frame","SidebarLine",self.panel,{Position=UDim2.fromOffset(148,88),Size=UDim2.fromOffset(1,344),
        BackgroundColor3=C.line,BorderSizePixel=0,BackgroundTransparency=.5})
    self.r15Status=label("R15Status",self.panel,"",UDim2.fromOffset(26,420),UDim2.fromOffset(120,18),10,C.muted)
    self.pageTitle=label("PageTitle",self.panel,"General",UDim2.fromOffset(168,90),UDim2.fromOffset(480,28),22)
    for _,name in ipairs(TABS) do
        local tab=button(name.."Tab",self.navigation,"",UDim2.fromOffset(0,0),UDim2.fromOffset(126,34));self.tabs[name]=tab
        label("Caption",tab,name,UDim2.fromOffset(12,0),UDim2.new(1,-24,1,0),12)
        make("Frame","Accent",tab,{BackgroundColor3=C.accent,BorderSizePixel=0})
        self:_connect(tab.Activated,function()self:selectTab(name)end)
        local page=make("Frame",name.."Page",self.panel,{BackgroundTransparency=1,Size=UDim2.fromOffset(488,310)});self.pages[name]=page
        local note=label("Note",page,NOTES[name],UDim2.fromOffset(0,0),UDim2.new(1,-8,0,22),12,C.muted)
        note.TextWrapped=true;if name=="Animations" then self.animationNote=note end
        local list=make("ScrollingFrame","Options",page,{BackgroundTransparency=1,BorderSizePixel=0,
            CanvasSize=UDim2.fromOffset(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
            ScrollingDirection=Enum.ScrollingDirection.Y,ScrollBarThickness=3,ScrollBarImageColor3=C.off})
        make("UIListLayout","Rows",list,{Padding=UDim.new(0,0),SortOrder=Enum.SortOrder.LayoutOrder});self.lists[name]=list
    end
    self.generalList=self.lists.General;self.animationList=self.lists.Animations
    self:_row(self.generalList,"r15","R15 animations","Enable the animation system  ·  F7",
        function()return runtime:GetAttribute("R15Enabled")~=false end,function()runtime:SetAttribute("R15Enabled",runtime:GetAttribute("R15Enabled")==false)end)
    self:_row(self.generalList,"hud","Show HUD","Health, eggs, and hints  ·  F6",function()return hud.canvas.Visible end,function()hud:toggleVisible()end)
    self:_row(self.generalList,"help","Show controls","Banjo's controls on the HUD  ·  H",function()return hud.help.Visible end,function()hud.help.Visible=not hud.help.Visible end)
    self:_row(self.generalList,"lighting","Lighting","Choose Roblox or classic N64 lighting  ·  L",function()return runtime:GetAttribute("LightingMode") or "Roblox" end,toggleLighting)
    for _,entry in ipairs(ANIMATIONS) do
        local key=entry[1]
        self:_row(self.animationList,key,entry[2],entry[3],function()return self:_enabled(key)end,
            function()runtime:SetAttribute("R15Use_"..key,not self:_enabled(key))end)
        self:_connect(runtime:GetAttributeChangedSignal("R15Use_"..key),function()self:refresh()end)
    end
    local toggle={{true,"ON"},{false,"OFF"}}
    self:_option(self.lists.Display,"VisualSize","Bear size","Visible size; your collision body stays the same",
        {{.5,"50%"},{.75,"75%"},{.9,"90%"},{1,"100%"},{1.25,"125%"},{1.5,"150%"}})
    self:_option(self.lists.Display,"ShowBear","Show Banjo","Keep gear visible when the bear is hidden",toggle)
    self:_option(self.lists.Display,"BearTint","Bear tint","Color the visible model",{{"Original","Original"},{"Gold","Gold"},{"Blue","Blue"},{"Green","Green"}})
    self:_option(self.lists.Display,"BlinkEyes","Eye blinking","Use Banjo's original eye blinking",toggle)
    self:_option(self.lists.Display,"ShowShadow","Ground shadow","Show Banjo's soft footprint shadow",toggle)
    self:_option(self.lists.Display,"HUDScale","HUD size","Scale the HUD independently of the bear",{{.5,"50%"},{.75,"75%"},{1,"100%"},{1.25,"125%"}})
    self:_option(self.lists.Display,"ShowHealth","Health display","Show the health icons",toggle)
    self:_option(self.lists.Display,"ShowEggs","Egg display","Show egg count and icon",toggle)
    self:_option(self.lists.Display,"ShowPadHints","Movement hints","Show pad, climbing, and flight hints",toggle)
    self:_option(self.lists.Display,"ShowHUDButton","HUD button","Settings and F6 remain available",toggle)
    self:_option(self.animationList,"AnimationBlendTime","Blend time","Smooth transitions between poses",
        {{0,"None"},{.07,"Fast"},{.14,"Normal"},{.25,"Soft"},{.4,"Slow"}})
    self:_option(self.animationList,"EmoteMotionAmount","Emote movement","Allow emote hops and side-to-side movement",
        {{0,"OFF"},{.5,"50%"},{1,"100%"},{1.5,"150%"}})
    self:_option(self.animationList,"R15PlaybackSpeed","Movement anim speed","Change clips' speed without changing movement",
        {{.5,"0.5x"},{.75,"0.75x"},{1,"1x"},{1.25,"1.25x"},{1.5,"1.5x"}})
    self:_option(self.lists.Movement,"EnableStairs","Step over ledges","Use Banjo's existing stair assistance",toggle)
    self:_option(self.lists.Movement,"EnableClimbing","Climbing","Allow climbing trusses and marked surfaces",toggle)
    self:_option(self.lists.Movement,"EnablePads","Special pads","Allow flight and shock spring pads",toggle)
    self:_option(self.lists.Movement,"InputDeadzone","Gamepad deadzone","Ignore small stick movements",{{.05,"5%"},{.1,"10%"},{.15,"15%"},{.2,"20%"}})
    self:_option(self.lists.Camera,"CameraFOV","Field of view","Default leaves the game's FOV alone",{{0,"Default"},{60,"60"},{70,"70"},{80,"80"},{90,"90"},{100,"100"}})
    self:_option(self.lists.Camera,"HideBearFirstPerson","Hide in first person","Hide the bear when the camera is close",toggle)
    self:_option(self.lists.Camera,"VerticalStabilizerEnabled","Steady camera height","Filter small vertical movement on the ground",toggle)
    self:_option(self.lists.Gear,"ShowTools","Show equipped Tools","Use your normal Backpack and Tool controls",toggle)
    self:_option(self.lists.Gear,"AttachToolsToBear","Follow Banjo's hand","OFF displays the real Tool at its native grip",toggle)
    self:_option(self.lists.Gear,"ToolArmPoses","Tool arm poses","Copy the equipped Tool's right-arm pose",toggle)
    self:_option(self.lists.Gear,"ToolBothArms","Use both arms","For Tools with two-handed poses",toggle)
    self:_option(self.lists.Gear,"ToolVisualScale","Gear size","Change only the visible gear size",{{.5,"50%"},{.75,"75%"},{1,"100%"},{1.25,"125%"},{1.5,"150%"}})
    self:_option(self.lists.Gear,"ShowToolsFirstPerson","Show in first person","Keep equipped gear visible when zoomed in",toggle)
    self:_option(self.lists.Gear,"BanjoActionsWithTool","Banjo attacks with gear","Allow attacks and eggs while a Tool is equipped",toggle)

    self.footerLine=make("Frame","FooterLine",self.panel,{BackgroundColor3=C.line,BorderSizePixel=0})
    self.resetButton=button("ResetDefaults",self.panel,"Reset defaults",UDim2.fromOffset(0,0),UDim2.fromOffset(122,28))
    self.centerButton=button("CenterWindow",self.panel,"Center window",UDim2.fromOffset(0,0),UDim2.fromOffset(124,28))
    self.enableAllButton=button("EnableAll",self.panel,"Enable all",UDim2.fromOffset(0,0),UDim2.fromOffset(120,28))
    self.disableAllButton=button("DisableAll",self.panel,"Disable all",UDim2.fromOffset(0,0),UDim2.fromOffset(120,28))
    self.emotesOnlyButton=button("EmotesOnly",self.panel,"Emotes only",UDim2.fromOffset(0,0),UDim2.fromOffset(120,28))
    self:_profilePage()
    self:_connect(self.openButton.Activated,function()self:toggle()end)
    self:_connect(close.Activated,function()self:setVisible(false)end)
    self:_connect(dismiss.Activated,function()self:setVisible(false)end)
    self:_connect(self.resetButton.Activated,function()self:resetDefaults()end)
    self:_connect(self.centerButton.Activated,function()self:centerWindow()end)
    self:_connect(self.enableAllButton.Activated,function()self:setAllAnimations(true)end)
    self:_connect(self.disableAllButton.Activated,function()self:setAllAnimations(false)end)
    self:_connect(self.emotesOnlyButton.Activated,function()self:emotesOnly()end)
    for _,key in ipairs({"R15Enabled","LightingMode"}) do self:_connect(runtime:GetAttributeChangedSignal(key),function()self:refresh()end) end
    for _,key in ipairs({"MenuOffsetX","MenuOffsetY"}) do self:_connect(runtime:GetAttributeChangedSignal(key),function()self:_layout()end) end
    self:_connect(hud.canvas:GetPropertyChangedSignal("Visible"),function()self:refresh()end)
    self:_connect(hud.help:GetPropertyChangedSignal("Visible"),function()self:refresh()end)
    self:_connect(header.InputBegan,function(input)self:_startDrag(input)end)
    self:_connect(INPUT.InputChanged,function(input)self:_moveDrag(input)end)
    self:_connect(INPUT.InputEnded,function(input)
        if self.drag and (input==self.drag.input or (not self.drag.touch and input.UserInputType==Enum.UserInputType.MouseButton1)) then self:_endDrag() end
    end)
    self:_connect(INPUT.WindowFocusReleased,function()self:_endDrag()end)
    self:_connect(workspace:GetPropertyChangedSignal("CurrentCamera"),function()self:_watchCamera()end)
    self:_watchCamera();self:selectTab("General");return self
end
function Menu:destroy()
    if self.destroyed then return end
    self:_endDrag();self.destroyed=true
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections={}
    if self.cameraConnection then self.cameraConnection:Disconnect();self.cameraConnection=nil end
    if self.gui then self.gui:Destroy() end
end
return Menu
