-- Banjo: one LocalScript with supporting modules stored as its children.
-- Copy this entire Banjo item into StarterPlayer > StarterPlayerScripts.
-- No uploads, HTTP downloads, loadstring or server script required.
-- Requires Allow Mesh & Image APIs in the experience. Appearance/eggs are client-only.
-- Size: 1.0 = 5.5 studs, .90 = 4.95 studs. Change these options before Play.
local OPTIONS={
    CharacterScale=.90,
    EnableStairs=true,
    EnableClimbing=true,
    EnablePads=true,
}
-- WASD move; Space jump/flutter; T trot; Ctrl+Space flip; X attack;
-- Ctrl+X barge; Z buster; V eggs (Ctrl+V backwards); L lighting; H help; F8 exit.
-- Pad marker Parts: BKPad attribute "Flight" / "ShockSpring". TrussParts climb.
-- Original model, pixels and animation tracks live in Modules > PackedData.
local moduleRoot=script:WaitForChild("Modules")
local function loadModule(name)return require(moduleRoot:WaitForChild(name))end
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local root=script
root:SetAttribute("BKPortOwned",true);script:SetAttribute("BKPortOwned",true)
local Config=loadModule("Config")
local Settings=loadModule("Settings")
OPTIONS=Settings.normalize(OPTIONS)
local bodySize=Settings.bodySize(OPTIONS)
local Traversal=loadModule("Traversal")
local Pads=loadModule("Pads")
local Controller=loadModule("Controller")
local Collision=loadModule("Collision")
local Graphics=loadModule("Graphics")
local Visual=loadModule("Visual")
local Yaw=loadModule("Yaw")
local Clock=loadModule("Clock")
local HUD=loadModule("HUD")
local Eggs=loadModule("Eggs")
local player=Players.LocalPlayer
local savedAvatar={}
local appearanceConnections={}
local hiddenParts={}
local function hidePart(p)
    if p:IsA("BasePart") and not hiddenParts[p] then
        hiddenParts[p]=true;table.insert(savedAvatar,{p,p.LocalTransparencyModifier,p.Anchored});p.LocalTransparencyModifier=1
        if p.Name=="HumanoidRootPart" then p.Anchored=true end
    end
end
local function hide(character)
    table.insert(appearanceConnections,character.DescendantAdded:Connect(hidePart))
    for _,p in ipairs(character:GetDescendants())do hidePart(p)end
end
local character=player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart")
local characterConnection
local controls
local playerModule=player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule",2)
if playerModule then
    local ok,module=pcall(require,playerModule)
    if ok then controls=module:GetControls()end
end
local rayParams=RaycastParams.new();rayParams.RespectCanCollide=true
rayParams.FilterType=Enum.RaycastFilterType.Exclude;rayParams.FilterDescendantsInstances={character}
local center=character.HumanoidRootPart.Position
local hit=workspace:Raycast(center+Vector3.yAxis*20,-Vector3.yAxis*1000,rayParams)
local createdFloor
if not hit then
    local floor=Instance.new("Part");floor.Name="BK_CharacterFloor";floor.Anchored=true;floor.Size=Vector3.new(200,2,200);floor.Position=Vector3.new(0,-1,0);floor.Color=Color3.fromRGB(125,135,145);floor:SetAttribute("BKPortOwned",true);floor.Parent=workspace
    center=Vector3.zero
    createdFloor=floor
else center=hit.Position end
local okVisual,visual
for attempt=1,3 do
    okVisual,visual=pcall(Visual.new,OPTIONS)
    if okVisual then break end
    if attempt<3 then task.wait(1)end
end
if not okVisual then
    if createdFloor then createdFloor:Destroy()end
    Graphics.destroy();root:SetAttribute("StartupError",tostring(visual));warn("[BK] Rework renderer unavailable: "..tostring(visual));return
end
local restoreLighting
local lightingMode="Roblox";root:SetAttribute("LightingMode",lightingMode)
local okHUD,errHUD=pcall(Graphics.editableTexture,"HUD")
if not okHUD then
    visual:destroy();Graphics.destroy();if createdFloor then createdFloor:Destroy()end
    root:SetAttribute("StartupError",tostring(errHUD));warn("[BK] HUD renderer unavailable: "..tostring(errHUD));return
end
hide(character);if controls then controls:Disable()end
local eggs=Eggs.new();local eggsFolder=eggs.folder
local pads=Pads.new()
local excluded={character,visual.model,eggsFolder,pads.folder}
for _,other in Players:GetPlayers()do if other~=player and other.Character then table.insert(excluded,other.Character)end end
rayParams.FilterDescendantsInstances=excluded
local collision=Collision.new(workspace,excluded,OPTIONS)
visual.shadow.params=rayParams
local controller=Controller.new(collision);controller.spawn=center+Vector3.yAxis*(bodySize.Y/2+Config.Skin);controller:reset()
local camera=workspace.CurrentCamera;local oldType,oldSubject=camera.CameraType,camera.CameraSubject
camera.CameraType=Enum.CameraType.Custom;camera.CameraSubject=character:FindFirstChildOfClass("Humanoid")
local hud=HUD.new(player);local gui,help=hud.gui,hud.help
local ownerHealth,ownerEggs=100,100
local keys,pending={},{};local stick=Vector2.zero;local previous=controller.position;local previousYaw=controller.yaw;local clock=Clock.new();local alive=true
local connections={};local render
local function toggleLighting()
    if restoreLighting then restoreLighting();restoreLighting=nil;lightingMode="Roblox"
    else restoreLighting=Graphics.lighting();lightingMode="N64"end
    root:SetAttribute("LightingMode",lightingMode);hud.lighting.Text="Lighting: "..lightingMode
end
table.insert(connections,hud.lighting.Activated:Connect(toggleLighting))
local function clear()keys,pending,stick={},{},Vector2.zero end
local function held(... )for _,k in ipairs({...})do if keys[k]then return true end end return false end
local function cleanup()
    if not alive then return end;alive=false;if render then render:Disconnect()end;for _,c in ipairs(connections)do c:Disconnect()end;if characterConnection then characterConnection:Disconnect()end
    for _,c in ipairs(appearanceConnections)do c:Disconnect()end
    eggs:destroy();pads:destroy();visual:destroy();gui:Destroy();Graphics.destroy();if restoreLighting then restoreLighting();restoreLighting=nil end
    if createdFloor and createdFloor.Parent then createdFloor:Destroy()end
    for _,entry in ipairs(savedAvatar)do if entry[1].Parent then entry[1].LocalTransparencyModifier=entry[2];entry[1].Anchored=entry[3]end end
    camera.CameraType=oldType;camera.CameraSubject=oldSubject and oldSubject.Parent and oldSubject or player.Character:FindFirstChildOfClass("Humanoid");if controls then controls:Enable()end
    root:SetAttribute("RuntimeReady",false)
end
table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
    if processed or UIS:GetFocusedTextBox()then return end;local k=input.KeyCode;keys[k]=true
    if k==Enum.KeyCode.Space or k==Enum.KeyCode.ButtonA then pending.jumpPressed=true end
    if k==Enum.KeyCode.X or k==Enum.KeyCode.ButtonB then pending.attackPressed=true end
    if k==Enum.KeyCode.LeftControl or k==Enum.KeyCode.RightControl or k==Enum.KeyCode.ButtonL2 or k==Enum.KeyCode.Z then pending.busterPressed=true end
    if k==Enum.KeyCode.V or k==Enum.KeyCode.ButtonR1 then pending.eggPressed=true end
    if k==Enum.KeyCode.T or k==Enum.KeyCode.ButtonY then pending.toggleTrot=true end
    if k==Enum.KeyCode.R then pending.reset=true end
    if k==Enum.KeyCode.H then help.Visible=not help.Visible end
    if k==Enum.KeyCode.L then toggleLighting()end
    if k==Enum.KeyCode.F8 then cleanup()end
end))
table.insert(connections,UIS.InputEnded:Connect(function(input)keys[input.KeyCode]=nil;if input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.ButtonA then pending.jumpReleased=true end end))
table.insert(connections,UIS.WindowFocusReleased:Connect(clear));table.insert(connections,UIS.TextBoxFocused:Connect(clear))
table.insert(connections,UIS.InputChanged:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.Thumbstick1 then stick=Vector2.new(input.Position.X,input.Position.Y)end

end))
script.Destroying:Connect(cleanup)
local renderName="BKRework_"..player.UserId
render={Disconnect=function()RunService:UnbindFromRenderStep(renderName)end}
RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value-1,function(dt)
    if workspace.CurrentCamera~=camera and workspace.CurrentCamera then
        camera=workspace.CurrentCamera;camera.CameraType=Enum.CameraType.Custom;camera.CameraSubject=character:FindFirstChildOfClass("Humanoid")
    end
    excluded={visual.model,eggsFolder,pads.folder}
    for _,other in Players:GetPlayers()do if other.Character then table.insert(excluded,other.Character)end end
    rayParams.FilterDescendantsInstances=excluded;collision.params.FilterDescendantsInstances=excluded
    for _,entry in ipairs(savedAvatar)do if entry[1].Parent then entry[1].LocalTransparencyModifier=1 end end
    if UIS:GetFocusedTextBox()then clear()end
    local axis=Vector2.new((keys[Enum.KeyCode.D]and 1 or 0)-(keys[Enum.KeyCode.A]and 1 or 0),(keys[Enum.KeyCode.W]and 1 or 0)-(keys[Enum.KeyCode.S]and 1 or 0));if axis.Magnitude>1 then axis=axis.Unit end;if stick.Magnitude>.05 then axis=stick end
    local look=camera.CFrame.LookVector;local right=camera.CFrame.RightVector
    local forward=Vector3.new(look.X,0,look.Z);local sideways=Vector3.new(right.X,0,right.Z)
    forward=forward.Magnitude>.001 and forward.Unit or Vector3.new(0,0,-1)
    sideways=sideways.Magnitude>.001 and sideways.Unit or Vector3.xAxis
    local move=sideways*axis.X+forward*axis.Y
    local alpha,renderDt=clock:advance(dt,function(step)
        previous=controller.position;previousYaw=controller.yaw;local crouch=held(Enum.KeyCode.LeftControl,Enum.KeyCode.RightControl,Enum.KeyCode.ButtonL2)
        local input={move=move,climbAxis=axis.Y,flightPitch=math.deg(math.asin(math.clamp(-look.Y,-1,1))),jumpHeld=held(Enum.KeyCode.Space,Enum.KeyCode.ButtonA),crouch=crouch,attackHeld=held(Enum.KeyCode.X,Enum.KeyCode.ButtonB),eggRear=crouch,eggsAvailable=ownerEggs}
        for k,v in pairs(pending)do input[k]=v end;pending={}
        Traversal.sense(controller,input);controller:step(input,step)
        if controller.eggFired and ownerEggs>0 then eggs:shoot(controller);ownerEggs-=1 end
        eggs:update(step,excluded)
        if input.reset then previous=controller.position end
        
        root:SetAttribute("Seen_"..controller.state,true)
    end)
    local hum=character:FindFirstChildOfClass("Humanoid")
    ownerHealth=hum and hum.MaxHealth>0 and hum.Health/hum.MaxHealth*100 or 0
    hud:update(dt,ownerHealth,ownerEggs,controller.feathers,controller.state,controller.currentPad)
    local pos=previous:Lerp(controller.position,alpha)
    local yaw=previousYaw+((controller.yaw-previousYaw+180)%360-180)*alpha
    visual:update(pos,yaw,controller.state,controller.climbing and controller.climbSpeed or Vector3.new(controller.velocity.X,0,controller.velocity.Z).Magnitude,renderDt,workspace,controller.grounded,controller.action and controller.action.time,nil,{verticalVelocity=controller.velocity.Y,pitch=controller.pitch})
    -- Local prediction feeds the native CameraModule before its camera update.
    -- The Banjo model/projectiles are local; this script has no server counterpart.
    local avatarRoot=character:FindFirstChild("HumanoidRootPart")
    if avatarRoot then avatarRoot.CFrame=CFrame.new(pos)*CFrame.Angles(0,math.rad(yaw),0)end
    local firstPerson=(camera.CFrame.Position-camera.Focus.Position).Magnitude<1
    for _,piece in visual.pieces do piece.part.LocalTransparencyModifier=firstPerson and 1 or 0 end
    root:SetAttribute("PlayerPosition",controller.position);root:SetAttribute("PlayerState",controller.state);root:SetAttribute("Grounded",controller.grounded);root:SetAttribute("Ticks",controller.ticks);root:SetAttribute("DroppedSeconds",clock.clampedTime)
end)
characterConnection=player.CharacterAdded:Connect(function(c)
    local r=c:WaitForChild("HumanoidRootPart",10)
    if not alive or not r then return end
    character=c;hide(c);table.insert(excluded,c)
    camera.CameraType=Enum.CameraType.Custom;camera.CameraSubject=c:FindFirstChildOfClass("Humanoid")
    rayParams.FilterDescendantsInstances=excluded;collision.params.FilterDescendantsInstances=excluded
    local floor=workspace:Raycast(r.Position+Vector3.yAxis*20,-Vector3.yAxis*1000,rayParams)
    controller.spawn=(floor and floor.Position or r.Position)+Vector3.yAxis*(bodySize.Y/2+Config.Skin)
    controller:reset();previous=controller.position;previousYaw=controller.yaw;clear()
    if controls then controls:Disable()end
    eggs:clear();ownerEggs=100
end)
root:SetAttribute("RuntimeReady",true)
if RunService:IsStudio()then
    local snapshot=Instance.new("BindableFunction");snapshot.Name="BK_ReworkSnapshot";snapshot.Parent=script
    snapshot.OnInvoke=function()return {position=controller.position,velocity=controller.velocity,state=controller.state,grounded=controller.grounded,trot=controller.trot,lighting=lightingMode,cameraType=tostring(camera.CameraType),avatarHeight=bodySize.Y,options=OPTIONS,pad=controller.currentPad,feathers=controller.feathers,flying=controller.flying,climbing=controller.climbing~=nil,actionTime=controller.action and controller.action.time,ticks=clock.ticks,droppedSeconds=clock.clampedTime,maxY=controller.maxY,spawn=controller.spawn}end
    local test=Instance.new("BindableFunction");test.Name="BK_SingleTest";test.Parent=script
    test.OnInvoke=function(command,args)
        if command=="modules"then return {Controller=Controller,Collision=Collision,Clock=Clock,Graphics=Graphics,Visual=Visual,Traversal=Traversal,Config=Config,Settings=Settings,Animation=loadModule("Animation"),Yaw=Yaw}end
        if command=="pose"then
            visual:update(controller.position,controller.yaw,args.state,args.speed or 0,args.dt or 0,workspace,args.grounded or false,args.time,nil,{verticalVelocity=args.velocityY or 0,pitch=args.pitch or 0})
            return visual.model:GetAttributes()
        end
        return nil
    end
    local hook=Instance.new("BindableEvent");hook.Name="BK_ReworkValidation";hook.Parent=script
    hook.Event:Connect(function(command)
        if command=="reset"then clear();controller:reset();previous=controller.position
        elseif command=="exit"then cleanup()end
    end)
end
print("[BK] Banjo client package ready: local Banjo, moves, eggs, HUD and pads. L lighting; H controls; F8 exits.")
