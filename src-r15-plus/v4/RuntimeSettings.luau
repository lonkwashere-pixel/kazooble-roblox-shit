-- Banjo R15 build: 2.3.8-r15.4
local Runtime={};Runtime.__index=Runtime
Runtime.ProfileFile="BanjoLoader_Settings_v1.json"
Runtime.ExportEnabled=true
Runtime.Defaults={
    VisualSize=.9,ShowBear=true,BlinkEyes=true,ShowShadow=true,BearTint="Original",
    HUDScale=1,ShowHealth=true,ShowEggs=true,ShowPadHints=true,ShowHUDButton=true,
    AnimationBlendTime=.14,EmoteMotionAmount=1,R15PlaybackSpeed=1,
    EnableStairs=true,EnableClimbing=true,EnablePads=true,InputDeadzone=.05,
    CameraFOV=0,HideBearFirstPerson=true,VerticalStabilizerEnabled=true,
    ShowTools=true,AttachToolsToBear=true,ToolArmPoses=true,ToolBothArms=false,
    ToolVisualScale=1,ShowToolsFirstPerson=true,BanjoActionsWithTool=false,
    R15Enabled=true,HUDVisible=true,ControlsVisible=false,LightingMode="Roblox",
    MenuOffsetX=0,MenuOffsetY=0,
}
local CLIPS={"idle","walk","run","jump","fall","climb","swim","swimidle","sit","game"}
for _,key in ipairs(CLIPS) do Runtime.Defaults["R15Use_"..key]=true end
local RANGES={VisualSize={.5,1.5},HUDScale={.5,1.25},AnimationBlendTime={0,.4},
    EmoteMotionAmount={0,1.5},R15PlaybackSpeed={.5,1.5},InputDeadzone={.05,.2},
    CameraFOV={0,100},ToolVisualScale={.5,1.5},MenuOffsetX={-.5,.5},MenuOffsetY={-.5,.5}}
local VALUES={BearTint={Original=true,Gold=true,Blue=true,Green=true},LightingMode={Roblox=true,N64=true}}
function Runtime:applySettings(settings)
    if type(settings)~="table" then return false,"Invalid settings list." end
    local accepted={}
    for key,default in pairs(Runtime.Defaults) do
        local value=settings[key]
        if type(value)==type(default) then
            if type(value)=="number" then
                if value==value and math.abs(value)<math.huge then
                    accepted[key]=math.clamp(value,RANGES[key][1],RANGES[key][2])
                end
            elseif type(value)=="string" then
                if VALUES[key] and VALUES[key][value] then accepted[key]=value end
            else accepted[key]=value end
        end
    end
    for key,value in pairs(accepted) do if key~="LightingMode" then self.root:SetAttribute(key,value) end end
    if accepted.HUDVisible~=nil then self.hud:setVisible(accepted.HUDVisible) end
    if accepted.ControlsVisible~=nil then self.hud.help.Visible=accepted.ControlsVisible end
    -- Lighting belongs to Main; use its callback to update the real lighting too.
    if accepted.LightingMode then
        if self.toggleLighting and self.root:GetAttribute("LightingMode")~=accepted.LightingMode then self.toggleLighting() end
        self.root:SetAttribute("LightingMode",accepted.LightingMode)
        self.lightingMode=accepted.LightingMode
    end
    return true
end
function Runtime:snapshot()
    local settings={}
    for key,default in pairs(Runtime.Defaults) do
        local value=self.root:GetAttribute(key)
        if value==nil then value=default end
        settings[key]=value
    end
    settings.HUDVisible=self.hud.canvas.Visible
    settings.ControlsVisible=self.hud.help.Visible
    return settings
end
function Runtime:saveProfile()
    if type(writefile)~="function" then return false,"File saving is unavailable here. Generate a settings list instead." end
    local ok=pcall(function()
        local encoded=game:GetService("HttpService"):JSONEncode({schema=1,settings=self:snapshot()})
        writefile(Runtime.ProfileFile,encoded)
    end)
    return ok,ok and "Saved. This profile loads the next time you run Banjo." or "Could not write the profile. You can still export a list."
end
function Runtime:loadProfile(quiet)
    if type(readfile)~="function" then
        if quiet then return false end
        return false,"File loading is unavailable here. Use a settings list."
    end
    if type(isfile)=="function" then
        local exists,fileExists=pcall(isfile,Runtime.ProfileFile)
        if exists and not fileExists then
            if quiet then return false end
            return false,"No saved profile yet."
        end
    end
    local ok=pcall(function()
        local text=readfile(Runtime.ProfileFile)
        if type(text)~="string" or #text>65536 then error("Invalid profile") end
        local data=game:GetService("HttpService"):JSONDecode(text)
        if type(data)~="table" or data.schema~=1 or type(data.settings)~="table" then error("Invalid profile") end
        self:applySettings(data.settings)
    end)
    if not ok and quiet then return false end
    return ok,ok and "Loaded your saved profile." or "Could not read this profile. Current settings were kept."
end
function Runtime:exportList()
    local settings=self:snapshot();local keys={}
    for key in pairs(settings) do table.insert(keys,key) end
    table.sort(keys)
    local lines={"-- Banjo settings · 2.3.8-r15.4","-- Send this list back to make these the build defaults.","return {"}
    for _,key in ipairs(keys) do
        local value=settings[key]
        table.insert(lines,"    "..key.." = "..(type(value)=="string" and string.format("%q",value) or tostring(value))..",")
    end
    table.insert(lines,"}");return table.concat(lines,"\n")
end
local function number(runtime,key,default,minimum,maximum)
    local value=runtime:GetAttribute(key)
    return type(value)=="number" and value==value and math.clamp(value,minimum,maximum) or default
end
function Runtime.new(root,hud,options,collision,visual,player,toggleLighting)
    local self=setmetatable({root=root,hud=hud,options=options,collision=collision,visual=visual,
        player=player,toggleLighting=toggleLighting,lightingMode=root:GetAttribute("LightingMode") or "Roblox",
        cameras={},connections={}},Runtime)
    for key,value in pairs(Runtime.Defaults) do
        if root:GetAttribute(key)==nil then root:SetAttribute(key,value) end
    end
    for _,key in ipairs({"EnableStairs","EnableClimbing","EnablePads"}) do
        local function apply()collision.options[key]=root:GetAttribute(key)~=false end
        apply();table.insert(self.connections,root:GetAttributeChangedSignal(key):Connect(apply))
    end
    table.insert(self.connections,root:GetAttributeChangedSignal("LightingMode"):Connect(function()
        self.lightingMode=root:GetAttribute("LightingMode") or "Roblox"
    end))
    self.profileLoaded,self.profileMessage=self:loadProfile(true)
    return self
end
function Runtime:resetDefaults()
    self:applySettings(Runtime.Defaults)
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
