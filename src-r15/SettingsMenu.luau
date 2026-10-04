-- Banjo settings: presentation only; never changes input ownership or physics.
local Menu = {}; Menu.__index = Menu
local ANIMATIONS = {
    {"idle", "Idle", "Standing still"},
    {"walk", "Walking", "Walking, slow walking, and creeping"},
    {"run", "Running", "Ordinary running"},
    {"jump", "Jumping", "The upward part of a jump"},
    {"fall", "Falling", "Falling and the downward part of a jump"},
    {"climb", "Climbing", "Climbing a truss"},
    {"swim", "Swimming", "Moving while swimming or diving"},
    {"swimidle", "Swimming idle", "Staying still in water"},
    {"sit", "Sitting", "Sitting while the game has control"},
    {"game", "Live game poses", "Copy the avatar's active emotes and game poses"},
}
local COLORS = {
    panel=Color3.fromRGB(39,29,24), row=Color3.fromRGB(57,43,32),
    text=Color3.fromRGB(255,232,180), muted=Color3.fromRGB(193,175,150),
    accent=Color3.fromRGB(244,192,77), on=Color3.fromRGB(66,111,74),
    off=Color3.fromRGB(94,76,66), dark=Color3.fromRGB(36,29,24),
}
local function make(class,name,parent,properties)
    local item=Instance.new(class);item.Name=name
    for key,value in pairs(properties or {}) do item[key]=value end
    item.Parent=parent;return item
end
local function rounded(item,radius)
    make("UICorner","Corner",item,{CornerRadius=UDim.new(0,radius or 8)})
end
local function label(name,parent,text,position,size,textSize,color)
    return make("TextLabel",name,parent,{
        BackgroundTransparency=1,Text=text,Position=position,Size=size,
        Font=Enum.Font.Gotham,TextSize=textSize or 14,TextColor3=color or COLORS.text,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
    })
end
local function button(name,parent,text,position,size)
    local item=make("TextButton",name,parent,{
        Text=text,Position=position,Size=size,BackgroundColor3=COLORS.off,
        TextColor3=COLORS.text,Font=Enum.Font.GothamBold,TextSize=13,
        AutoButtonColor=true,BorderSizePixel=0,Modal=false,
    });rounded(item);return item
end
function Menu:_connect(signal,callback)
    local connection=signal:Connect(callback)
    table.insert(self.connections,connection);return connection
end
function Menu:_enabled(key)
    return self.runtime:GetAttribute("R15Use_"..key)~=false
end
function Menu:_row(page,key,title,description,getValue,onClick)
    local row=make("Frame",key,page,{
        Size=UDim2.new(1,-4,0,61),BackgroundColor3=COLORS.row,BorderSizePixel=0,
        LayoutOrder=#self.rowOrder+1,
    });rounded(row)
    label("Title",row,title,UDim2.fromOffset(12,8),UDim2.new(1,-118,0,20),14)
    local caption=label("Description",row,description,UDim2.fromOffset(12,29),UDim2.new(1,-118,0,26),11,COLORS.muted)
    caption.TextWrapped=true
    local toggle=button("Toggle",row,"",UDim2.new(1,-94,.5,-15),UDim2.fromOffset(82,30))
    self.rows[key]={button=toggle,getValue=getValue}
    table.insert(self.rowOrder,key)
    self:_connect(toggle.Activated,function()onClick();self:refresh()end)
end
function Menu:refresh()
    if self.destroyed then return end
    for _,key in ipairs(self.rowOrder) do
        local row=self.rows[key];local value=row.getValue()
        if type(value)=="boolean" then
            row.button.Text=value and "ON" or "OFF"
            row.button.BackgroundColor3=value and COLORS.on or COLORS.off
        else
            row.button.Text=tostring(value)
            row.button.BackgroundColor3=value=="N64" and COLORS.on or COLORS.off
        end
    end
    local enabled=self.runtime:GetAttribute("R15Enabled")~=false
    self.animationNote.Text=enabled and "ON uses R15. OFF uses Banjo's original animation."
        or "R15 is off in General. Your selections are kept."
end
function Menu:selectTab(name)
    if self.destroyed then return end
    self.selectedTab=name
    for key,page in pairs(self.pages) do
        page.Visible=key==name
        self.tabs[key].BackgroundColor3=key==name and COLORS.accent or COLORS.row
        self.tabs[key].TextColor3=key==name and COLORS.dark or COLORS.text
    end
    self.resetButton.Visible=name=="General"
    self.enableAllButton.Visible=name=="Animations"
    self.disableAllButton.Visible=name=="Animations"
    self:refresh()
end
function Menu:setVisible(visible)
    if self.destroyed then return end
    self.overlay.Visible=visible==true
    self.openButton.Text=self.overlay.Visible and "Close settings [F5]" or "Settings [F5]"
    self:refresh()
end
function Menu:toggle()self:setVisible(not self.overlay.Visible)end
function Menu:setAllAnimations(enabled)
    for _,entry in ipairs(ANIMATIONS) do
        self.runtime:SetAttribute("R15Use_"..entry[1],enabled==true)
    end
    self:refresh()
end
function Menu:resetDefaults()
    self:setAllAnimations(true);self.runtime:SetAttribute("R15Enabled",true)
    self.hud:setVisible(true);self.hud.help.Visible=false
    if self.runtime:GetAttribute("LightingMode")=="N64" then self.toggleLighting() end
    self:refresh()
end
function Menu:_watchCamera()
    if self.cameraConnection then self.cameraConnection:Disconnect();self.cameraConnection=nil end
    local camera=workspace.CurrentCamera
    local function resize()
        if self.destroyed or not camera then return end
        local size=camera.ViewportSize
        self.scale.Scale=math.max(.1,math.min(1,(size.X-24)/420,(size.Y-40)/506))
    end
    resize()
    if camera then self.cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
end
function Menu.new(player,runtime,hud,toggleLighting)
    local self=setmetatable({runtime=runtime,hud=hud,toggleLighting=toggleLighting,
        connections={},rows={},rowOrder={},pages={},tabs={},destroyed=false},Menu)
    self.gui=make("ScreenGui","BK_SettingsMenu",player.PlayerGui,{
        ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=50,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    })
    self.openButton=button("OpenSettings",self.gui,"Settings [F5]",UDim2.new(1,-12,0,94),UDim2.fromOffset(150,30))
    self.openButton.AnchorPoint=Vector2.new(1,0)
    self.overlay=make("Frame","Overlay",self.gui,{
        Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false,
    })
    local dismiss=make("TextButton","Dismiss",self.overlay,{
        Size=UDim2.fromScale(1,1),Text="",BackgroundColor3=Color3.new(0,0,0),
        BackgroundTransparency=.45,BorderSizePixel=0,AutoButtonColor=false,Modal=false,ZIndex=1,
    })
    self.panel=make("Frame","Panel",self.overlay,{
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(420,506),BackgroundColor3=COLORS.panel,BorderSizePixel=0,Active=true,ZIndex=2,
    });rounded(self.panel,12)
    make("UIStroke","Border",self.panel,{Color=COLORS.accent,Thickness=1,Transparency=.55})
    self.scale=make("UIScale","FitToScreen",self.panel,{Scale=1})
    label("Title",self.panel,"Banjo settings",UDim2.fromOffset(20,16),UDim2.fromOffset(320,28),22)
    label("Subtitle",self.panel,"Make it feel right for you.",UDim2.fromOffset(20,45),UDim2.fromOffset(350,18),12,COLORS.muted)
    local close=button("Close",self.panel,"X",UDim2.new(1,-48,0,16),UDim2.fromOffset(30,30))
    for index,name in ipairs({"General","Animations"}) do
        local tab=button(name.."Tab",self.panel,name,UDim2.fromOffset(20+(index-1)*194,78),UDim2.fromOffset(186,34))
        self.tabs[name]=tab
        self:_connect(tab.Activated,function()self:selectTab(name)end)
        local page=make("Frame",name.."Page",self.panel,{
            BackgroundTransparency=1,Position=UDim2.fromOffset(20,124),Size=UDim2.fromOffset(380,284),
        });self.pages[name]=page
        local note=label("Note",page,name=="General" and "Changes apply immediately." or "",UDim2.fromOffset(0,0),UDim2.fromOffset(380,30),12,COLORS.muted)
        note.TextWrapped=true
        if name=="Animations" then self.animationNote=note end
        local scroll=make("ScrollingFrame","Options",page,{
            BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(0,36),
            Size=UDim2.fromOffset(380,248),CanvasSize=UDim2.fromOffset(0,0),
            AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
            ScrollBarThickness=4,ScrollBarImageColor3=COLORS.accent,
        })
        make("UIListLayout","Rows",scroll,{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
        if name=="General" then self.generalList=scroll else self.animationList=scroll end
    end
    self:_row(self.generalList,"r15","R15 animations","Enable the R15 animation system [F7]",
        function()return runtime:GetAttribute("R15Enabled")~=false end,
        function()runtime:SetAttribute("R15Enabled",runtime:GetAttribute("R15Enabled")==false)end)
    self:_row(self.generalList,"hud","Show HUD","Health, eggs, and hints [F6]",
        function()return hud.canvas.Visible end,function()hud:toggleVisible()end)
    self:_row(self.generalList,"help","Show controls","Show the Banjo controls on the HUD [H]",
        function()return hud.help.Visible end,function()hud.help.Visible=not hud.help.Visible end)
    self:_row(self.generalList,"lighting","Lighting","Choose Roblox or classic N64 lighting [L]",
        function()return runtime:GetAttribute("LightingMode") or "Roblox" end,toggleLighting)
    for _,entry in ipairs(ANIMATIONS) do
        local key=entry[1]
        self:_row(self.animationList,key,entry[2],entry[3],
            function()return self:_enabled(key)end,
            function()runtime:SetAttribute("R15Use_"..key,not self:_enabled(key))end)
        self:_connect(runtime:GetAttributeChangedSignal("R15Use_"..key),function()self:refresh()end)
    end
    make("Frame","Divider",self.panel,{
        Position=UDim2.fromOffset(20,420),Size=UDim2.fromOffset(380,1),
        BackgroundColor3=COLORS.off,BorderSizePixel=0,
    })
    self.resetButton=button("ResetDefaults",self.panel,"Reset defaults",UDim2.fromOffset(20,434),UDim2.fromOffset(380,32))
    self.enableAllButton=button("EnableAll",self.panel,"Enable all",UDim2.fromOffset(20,434),UDim2.fromOffset(186,32))
    self.disableAllButton=button("DisableAll",self.panel,"Disable all",UDim2.fromOffset(214,434),UDim2.fromOffset(186,32))
    label("Keys",self.panel,"F5 settings  /  F6 HUD  /  F7 R15",UDim2.fromOffset(20,478),UDim2.fromOffset(380,16),11,COLORS.muted)
    self:_connect(self.openButton.Activated,function()self:toggle()end)
    self:_connect(close.Activated,function()self:setVisible(false)end)
    self:_connect(dismiss.Activated,function()self:setVisible(false)end)
    self:_connect(self.resetButton.Activated,function()self:resetDefaults()end)
    self:_connect(self.enableAllButton.Activated,function()self:setAllAnimations(true)end)
    self:_connect(self.disableAllButton.Activated,function()self:setAllAnimations(false)end)
    self:_connect(runtime:GetAttributeChangedSignal("R15Enabled"),function()self:refresh()end)
    self:_connect(runtime:GetAttributeChangedSignal("LightingMode"),function()self:refresh()end)
    self:_connect(hud.canvas:GetPropertyChangedSignal("Visible"),function()self:refresh()end)
    self:_connect(hud.help:GetPropertyChangedSignal("Visible"),function()self:refresh()end)
    self:_connect(workspace:GetPropertyChangedSignal("CurrentCamera"),function()self:_watchCamera()end)
    self:_watchCamera();self:selectTab("General")
    return self
end
function Menu:destroy()
    if self.destroyed then return end
    self.destroyed=true
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    self.connections={}
    if self.cameraConnection then self.cameraConnection:Disconnect();self.cameraConnection=nil end
    if self.gui then self.gui:Destroy() end
end
return Menu
