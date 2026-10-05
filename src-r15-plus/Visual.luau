-- Banjo R15 build: 2.3.8-r15.3
-- Experimental R15 renderer; upstream animation/movement remain available as fallback.
local Graphics=require(script.Parent.Graphics)
local Animation=require(script.Parent.Animation)
local Config=require(script.Parent.Config)
local Shadow=require(script.Parent.Shadow)
local Sizing=require(script.Parent.Sizing)
local Settings=require(script.Parent.Settings)
local R15Animations=require(script.Parent.R15Animations)
local GearSupport=require(script.Parent.GearSupport)
local TINTS={Gold=Color3.fromRGB(255,211,115),Blue=Color3.fromRGB(145,185,255),Green=Color3.fromRGB(165,225,155)}
local Visual={};Visual.__index=Visual
function Visual.new(options,runtime)
    options=Settings.normalize(options)
    local model=Instance.new("Model");model.Name="BK_LocalBear"
    local sizeRatio,footOffset=Sizing.visualRatio(options.CharacterScale)
    local bodyHeight=Settings.bodySize(options).Y
    local self=setmetatable({model=model,pieces={},time=0,phase=0,blend=1,birdHideTime=0,data=Graphics.data(),sizeRatio=sizeRatio,footOffset=footOffset,bodyHeight=bodyHeight},Visual)
    local ok,err=pcall(function()
        for _,desc in ipairs(self.data.character) do table.insert(self.pieces,Graphics.mesh(desc,true,model)) end
    end)
    if not ok then
        for _,piece in self.pieces do piece.mesh:Destroy()end
        model:Destroy();error(err)
    end
    model:SetAttribute("OriginalModel","0x34D")
    model:SetAttribute("BKPortOwned",true)
    model:SetAttribute("Bones",#self.data.bones)
    model:SetAttribute("VertexShading",true)
    model:SetAttribute("OriginalAtlasRenderer",true)
    model.Parent=workspace
    self.shadow=Shadow.new(model)
    self.shadow.scale=self.sizeRatio;self.shadow.bodyHeight=bodyHeight;model:SetAttribute("AvatarHeight",bodyHeight)
    local okBridge,bridge=pcall(R15Animations.new,self.data,model,runtime)
    if okBridge then self.r15=bridge
    else model:SetAttribute("R15Status","Setup fallback: "..tostring(bridge));warn("[Banjo R15] "..tostring(bridge)) end
    self.runtime=runtime
    self.gear=GearSupport.new(model,runtime)
    self.baseColors={}
    for _,piece in ipairs(self.pieces) do self.baseColors[piece.part]=piece.part.Color end
    return self
end
function Visual:setScale(characterScale)
    local normalized=Settings.normalize({CharacterScale=characterScale})
    self.sizeRatio,self.footOffset=Sizing.visualRatio(normalized.CharacterScale)
    self.shadow.scale=self.sizeRatio
    self.model:SetAttribute("VisualScale",normalized.CharacterScale)
    self.blend=1
    for _,piece in ipairs(self.pieces) do for _,v in ipairs(piece.vertices) do v.previous=nil end end
end
local function animationFor(state,speed)
    if state=="FLY_ENTER"then return "flyEnter",1.4,false
    elseif state=="FLY"then return "fly",.62,true
    elseif state=="SPRING_CHARGE"then return "springCharge",2.8,false
    elseif state=="SPRING_JUMP"then return "springJump",.8,false
    elseif state=="CLAW" then return "claw",1.3,false
    elseif state=="ROLL" then return "roll",.9,false
    elseif state=="BARGE" then return "barge",1.15,false
    elseif state=="FLAP" then return "flap",.3,true
    elseif state=="PECK" then return "peck",.2,true
    elseif state=="BUSTER" or state=="BUSTER_LAND" then return "buster",1.02,false
    elseif state=="EGG" then return "egg",1,false
    elseif state=="EGG_REAR" then return "eggRear",1,false
    elseif state=="HURT" then return "hurt",.8,false
    elseif state=="SWIM_IDLE" then return "swimIdle",1.2,true
    elseif state=="SWIM" then return "swimMove",.9,true
    elseif state=="DIVE_IDLE" then return "diveIdle",1.4,true
    elseif state=="DIVE_MOVE" then return "diveMove",1,true
    elseif state=="CLIMB" then return speed>1 and "climb" or "climbIdle",.9,true end
    if state=="TALON_TROT" then return "trot",0.56-0.22*math.clamp((speed-30)/670,0,1),true
    elseif state=="TROT_IDLE" then return "trotIdle",1.2,true
    elseif state=="TROT_JUMP" then return "trotJump",1.4,false
    elseif state=="CROUCH" then return "crouch",0.5,true
    elseif state=="FLIP" then return "flip",0.5,false
    elseif state=="JUMP" or state=="FALL" then return "jump",1.9,false
    elseif state=="CREEP" then return "creep",1.8-0.6*math.clamp(speed/80,0,1),true
    elseif state=="WALK_SLOW" then return "slowWalk",1.3-0.7*math.clamp((speed-80)/70,0,1),true
    elseif state=="WALK" then return "walk",0.92-0.34*math.clamp((speed-150)/75,0,1),true
    elseif state=="RUN" then return "walk",0.54-0.10*math.clamp((speed-225)/275,0,1),true end
    return "idle",5.5,true
end
local flapDurations={.15,.2,.27,.38,.4,.7}
-- bFlap.c changes the loop duration at frame .9, rather than at the wrap.
local function flapProgress(elapsed)
    local remaining=math.max(0,elapsed-.27)
    local phase,cycles=0,0
    while remaining>0 do
        local duration=flapDurations[math.min(cycles+1,#flapDurations)]
        local boundary=phase<.9 and .9 or 1
        local segment=(boundary-phase)*duration
        if remaining<segment then return phase+remaining/duration end
        remaining-=segment
        if boundary==.9 then phase=.9;cycles+=1 else phase=0 end
    end
    return phase
end
function Visual:update(position,yaw,state,speed,dt,world,grounded,actionTime,invulnerable,motion)
    self.time+=dt
    local name,duration,loop=animationFor(state,speed)
    if name~=self.animation then
        self.animation=name;self.phase=0;self.blend=0;self.jumpFallTime=0
        for _,piece in ipairs(self.pieces) do
            for _,v in ipairs(piece.vertices) do v.previous=piece.mesh:GetPosition(v.id) end
        end
    end
    self.phase+=dt/duration;local blendTime=self.runtime and self.runtime:GetAttribute("AnimationBlendTime") or .14
    blendTime=type(blendTime)=="number" and math.clamp(blendTime,0,.4) or .14
    self.blend=blendTime>0 and math.min(1,self.blend+dt/blendTime) or 1
    local progress=loop and self.phase%1 or math.min(0.999,self.phase)
    if state=="FALL" then progress=0.65 end
    if state=="JUMP" then
        if motion and motion.verticalVelocity<=0 then
            self.jumpFallTime+=dt;progress=math.min(.6667,.5042+self.jumpFallTime/4)
        else progress=math.min(.5042,.3+self.phase) end
    elseif state=="TROT_JUMP" then
        if motion and motion.verticalVelocity<=0 then
            self.jumpFallTime+=dt;progress=math.min(.4653,.4002+self.jumpFallTime/10)
        else progress=math.min(.4002,.2+self.phase) end
    end
    if state=="FLIP" then
        local elapsed=actionTime or self.phase*duration
        local windup=Config.FlipWindup
        progress=elapsed<windup and elapsed/2.3 or .1837+(elapsed-windup)/1.9
        if progress>=.7866 then name="flipHold";progress=((elapsed-windup-(.7866-.1837)*1.9)/.13)%1 end
    end
    if state=="FLAP" then
        local elapsed=actionTime or self.phase*duration
        if elapsed<.27 then name="flapEnter";progress=elapsed/.3 else progress=flapProgress(elapsed) end
        -- Original entry-to-loop transition explicitly disables smoothing.
        if self.poseAnimation=="flapEnter" and name=="flap" then self.blend=1 end
    end
    if state=="FLY_ENTER"then
        local t=actionTime or self.phase*duration
        progress=t<Config.FlightWindup and t/1.4 or .2416+(t-Config.FlightWindup)/2.4
        progress=math.min(.999,progress)
    elseif state=="SPRING_CHARGE"then progress=math.min(.3637,(actionTime or self.phase*duration)/2.8)
    elseif state=="SPRING_JUMP"then progress=math.min(.999,.5304+self.phase)end
    self.poseAnimation=name
    if state=="BUSTER" then progress=(actionTime or 0)<.357 and (actionTime or 0)/1.02 or .5 end
    if state=="BUSTER_LAND" then progress=.7+math.min(.29,(actionTime or 0)) end
    local pose=Animation.pose(self.data,name,progress)
    local r15Pose
    if self.r15 then
        local ok,result=pcall(self.r15.pose,self.r15,state,speed,dt,motion)
        if ok then r15Pose=result
        else
            self.model:SetAttribute("R15Status","Runtime fallback: "..tostring(result))
            if self.r15Error~=tostring(result) then warn("[Banjo R15] "..tostring(result));self.r15Error=tostring(result) end
        end
    end
    local poseMode=r15Pose and ("R15:"..tostring(self.model:GetAttribute("R15Source"))..":"..tostring(self.model:GetAttribute("R15Clip"))) or "Banjo"
    if self.poseMode and poseMode~=self.poseMode then
        self.blend=0
        for _,piece in ipairs(self.pieces) do
            for _,v in ipairs(piece.vertices) do v.previous=piece.mesh:GetPosition(v.id) end
        end
    end
    self.poseMode=poseMode
    if r15Pose then pose=r15Pose end
    if blendTime==0 then self.blend=1 end
    if self.r15 then
        local ok,result=pcall(self.r15.toolPose,self.r15,pose)
        if ok then pose=result end
    end
    self.model:SetAttribute("R15Active",r15Pose~=nil)

    local trot=state=="TALON_TROT" or state=="TROT_IDLE" or state=="TROT_JUMP"
    local spring=state=="SPRING_CHARGE"or state=="SPRING_JUMP"
    local flight=state=="FLY_ENTER"or state=="FLY"
    local bird=state=="FLIP" or trot or spring or flight or state=="FLAP" or state=="PECK" or state=="BUSTER" or state=="BUSTER_LAND" or state=="BARGE" or state=="CLAW" or state=="ROLL" or state=="EGG" or state=="EGG_REAR"
    if self.previousState=="FLAP" and state~="FLAP" then self.birdHideTime=self.time+.2 end
    bird=bird or self.time<self.birdHideTime
    self.previousState=state
    local blinkTime=self.time%4.8
    local eye=blinkTime<0.3 and 1+math.floor(math.sin(blinkTime/0.3*math.pi)*7) or 1
    if self.runtime and self.runtime:GetAttribute("BlinkEyes")==false then eye=1 end
    local selector={[9]=bird and 1 or 0,[10]=(trot or spring)and 1 or 0,[11]=state=="EGG_REAR" and 1 or 0,[20]=1,[21]=1,[36]=1,[37]=1}
    -- modelappendages.c blinks Banjo's four left/right eye variants only.
    -- Kazooie's eyes and wing/appendage branches must not use blink selectors.
    for id=26,33 do selector[id]=eye end
    -- The collision footprint can still stand on a ledge while the center shadow
    -- ray sees the floor far below. Never use that ray to move the character.
    local base=position-Vector3.new(0,self.bodyHeight/2,0)
    base+=Vector3.yAxis*self.footOffset
    -- ba/model.c reverses model yaw when Kazooie leads in Talon Trot.
    local root=CFrame.new(base)*CFrame.Angles(0,math.rad(yaw)+(trot and 0 or math.pi),0)
    if state=="FLY"then root*=CFrame.Angles(math.rad(motion and motion.pitch or 0),0,0)end
    local shadowOffset=self.r15 and self.r15.visualTranslation or Vector3.zero
    Shadow.update(self.shadow,position+root:VectorToWorldSpace(shadowOffset*Config.Scale*self.sizeRatio),world)
    if self.shadow.gui and self.runtime and self.runtime:GetAttribute("ShowShadow")==false then self.shadow.gui.Enabled=false end
    local damageBlink=invulnerable and invulnerable>0 and self.time%0.14<.07
    for _,piece in ipairs(self.pieces) do
        local visible=not damageBlink and (not self.runtime or self.runtime:GetAttribute("ShowBear")~=false)
        for _,s in ipairs(piece.selectors) do if (selector[s[1]] or 1)~=s[2] then visible=false;break end end
        piece.part.Transparency=visible and 0 or 1
        piece.part.CFrame=root
        local tint=self.runtime and self.runtime:GetAttribute("BearTint") or "Original"
        piece.part.Color=TINTS[tint] or self.baseColors[piece.part]
        if visible then
            for _,v in ipairs(piece.vertices) do
                local p=Vector3.zero
                for _,w in ipairs(v.skin) do p+=Animation.transform(pose[w.bone],w.position)*w.weight end
                if #v.skin==0 then p=v.position end
                p*=Config.Scale*self.sizeRatio
                if not piece.visible then v.previous=p end
                -- A hidden piece's stored mesh coordinates can be an old folded
                -- pose. Skin its first visible frame directly to the current pose.
                if piece.visible and self.blend<1 and v.previous then p=v.previous:Lerp(p,self.blend) end
                piece.mesh:SetPosition(v.id,p)
            end
        end
        piece.visible=visible
    end
    if self.gear then
        local bridge=self.r15
        local hand=bridge and bridge.retarget:partFrame(pose,"RightHand",bridge.nativeJoints,Config.Scale*self.sizeRatio)
        local ok,err=pcall(self.gear.update,self.gear,dt,hand and root*hand)
        if not ok and self.gearError~=tostring(err) then warn("[Banjo Gear] "..tostring(err));self.gearError=tostring(err) end
    end
    self.model:SetAttribute("State",state)
    self.model:SetAttribute("Animation",name)
    self.model:SetAttribute("AnimationFrame",progress)
end
function Visual:destroy()
    if self.gear then self.gear:destroy();self.gear=nil end
    if self.r15 then self.r15:destroy();self.r15=nil end
    for _,piece in self.pieces do piece.mesh:Destroy()end
    self.model:Destroy()
end
return Visual
