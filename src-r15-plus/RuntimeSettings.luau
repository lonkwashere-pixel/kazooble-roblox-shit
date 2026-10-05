-- Banjo R15 build: 2.3.8-r15.3
local Runtime={};Runtime.__index=Runtime
Runtime.Defaults={
    VisualSize=.9,ShowBear=true,BlinkEyes=true,ShowShadow=true,BearTint="Original",
    HUDScale=1,ShowHealth=true,ShowEggs=true,ShowPadHints=true,ShowHUDButton=true,
    AnimationBlendTime=.14,EmoteMotionAmount=1,R15PlaybackSpeed=1,
    EnableStairs=true,EnableClimbing=true,EnablePads=true,InputDeadzone=.05,
    CameraFOV=0,HideBearFirstPerson=true,VerticalStabilizerEnabled=true,
    ShowTools=true,AttachToolsToBear=true,ToolArmPoses=true,ToolBothArms=false,
    ToolVisualScale=1,ShowToolsFirstPerson=true,BanjoActionsWithTool=false,
}
local function number(runtime,key,default,minimum,maximum)
    local value=runtime:GetAttribute(key)
    return type(value)=="number" and value==value and math.clamp(value,minimum,maximum) or default
end
function Runtime.new(root,hud,options,collision,visual,player)
    local self=setmetatable({root=root,hud=hud,options=options,collision=collision,visual=visual,
        player=player,cameras={},connections={}},Runtime)
    for key,value in pairs(Runtime.Defaults) do
        if root:GetAttribute(key)==nil then root:SetAttribute(key,value) end
    end
    for _,key in ipairs({"EnableStairs","EnableClimbing","EnablePads"}) do
        local function apply()collision.options[key]=root:GetAttribute(key)~=false end
        apply();table.insert(self.connections,root:GetAttributeChangedSignal(key):Connect(apply))
    end
    return self
end
function Runtime:resetDefaults()
    for key,value in pairs(Runtime.Defaults) do self.root:SetAttribute(key,value) end
end
function Runtime:filterInput(input,character)
    if self.root:GetAttribute("BanjoActionsWithTool")==false and character:FindFirstChildOfClass("Tool") then
        input.attackHeld=false;input.attackPressed=false;input.busterPressed=false;input.eggPressed=false
    end
end
function Runtime:update()
    if self.destroyed then return end
    local root,hud=self.root,self.hud
    local size=number(root,"VisualSize",.9,.5,1.5)
    if size~=self.appliedSize then self.visual:setScale(size);self.appliedSize=size end
    hud.scale.Scale*=number(root,"HUDScale",1,.5,1.25) -- HUD:update computes the base scale first.
    for _,image in ipairs(hud.health) do image.Visible=root:GetAttribute("ShowHealth")~=false end
    for _,image in ipairs(hud.eggs) do image.Visible=root:GetAttribute("ShowEggs")~=false end
    local egg=hud.canvas:FindFirstChild("egg");if egg then egg.Visible=root:GetAttribute("ShowEggs")~=false end
    if root:GetAttribute("ShowPadHints")==false then hud.padHint.Visible=false end
    hud.toggleButton.Visible=root:GetAttribute("ShowHUDButton")~=false
    local camera=workspace.CurrentCamera
    local cameraBlocked=root:GetAttribute("ExternallyPaused")==true or (camera and camera.CameraType==Enum.CameraType.Scriptable)
    if cameraBlocked then self.wasCameraBlocked=true
    elseif camera then
        local requested=number(root,"CameraFOV",0,0,100)
        local entry=self.cameras[camera]
        if self.wasCameraBlocked then
            self.lastCamera=nil
            if entry and entry.written and camera.FieldOfView~=entry.written then entry.original=camera.FieldOfView end
            self.wasCameraBlocked=false
        end
        if requested>0 then
            if not entry or not entry.written then entry={original=camera.FieldOfView};self.cameras[camera]=entry end
            if self.lastCamera~=camera or entry.requested~=requested then
                camera.FieldOfView=requested;entry.written=requested;entry.requested=requested
            end
        elseif entry and entry.written then
            if camera.FieldOfView==entry.written then camera.FieldOfView=entry.original end
            entry.written=nil;entry.requested=nil
        end
        self.lastCamera=camera
    end
end
function Runtime:destroy()
    if self.destroyed then return end
    self.destroyed=true
    for _,connection in ipairs(self.connections) do connection:Disconnect() end
    for camera,entry in pairs(self.cameras) do
        pcall(function()if entry.written and camera.FieldOfView==entry.written then camera.FieldOfView=entry.original end end)
    end
end
return Runtime
