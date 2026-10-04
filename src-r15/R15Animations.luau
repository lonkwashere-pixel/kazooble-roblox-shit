-- Experimental visual-only R15 source. The real avatar is read, never animated
-- or moved by this module. A private local rig evaluates locomotion clips.
local Players = game:GetService("Players")
local Retarget = require(script.Parent.R15Retarget)
local Config = require(script.Parent.Config)
local Bridge = {}; Bridge.__index = Bridge

-- Verified Roblox-owned animation assets, used only when the avatar supplies
-- neither an Animate configuration nor an animation-pack ID.
local DEFAULTS = {
    idle="rbxassetid://507766666", walk="rbxassetid://507777826", run="rbxassetid://507767714",
    jump="rbxassetid://507765000", fall="rbxassetid://507767968", climb="rbxassetid://507765644",
    swim="rbxassetid://507784897", swimidle="rbxassetid://507785072", sit="rbxassetid://507768133",
}
local DESCRIPTION = {idle="IdleAnimation",walk="WalkAnimation",run="RunAnimation",
    jump="JumpAnimation",fall="FallAnimation",climb="ClimbAnimation",swim="SwimAnimation"}
local SUPPORTED = {IDLE=true,CREEP=true,WALK_SLOW=true,WALK=true,RUN=true,
    JUMP=true,FALL=true,CLIMB=true,SWIM=true,SWIM_IDLE=true,DIVE_IDLE=true,DIVE_MOVE=true}
local function assetId(value)
    local id=tostring(value or ""):match("(%d+)")
    return id and tonumber(id)>0 and ("rbxassetid://"..id) or nil
end

function Bridge:_attribute(key,value)
    if self.model and self.model.Parent and self.model:GetAttribute(key)~=value then
        self.model:SetAttribute(key,value)
    end
    if self.runtime and self.runtime.Parent and self.runtime:GetAttribute(key)~=value then
        self.runtime:SetAttribute(key,value)
    end
end
function Bridge:_status(status) self:_attribute("R15Status",status) end
function Bridge.new(data,model,runtime)
    local self=setmetatable({model=model,runtime=runtime,retarget=Retarget.new(data),
        player=Players.LocalPlayer,tracks={},loading={},generation=0,retryAt=0,
        nativeCheckAt=0,nativeAction=false,destroyed=false},Bridge)
    if runtime and runtime:GetAttribute("R15Enabled")==nil then runtime:SetAttribute("R15Enabled",true) end
    self:_status("Waiting for R15 character")
    return self
end

local function resolveClips(character,humanoid)
    local clips=table.clone(DEFAULTS)
    local ok,description=pcall(function()return humanoid:GetAppliedDescription()end)
    if ok and description then
        for key,property in pairs(DESCRIPTION) do
            local id=assetId(description[property])
            if id then clips[key]=id end
        end
        -- R15 packs have one swim ID; swimidle may be configured separately.
        if assetId(description.SwimAnimation) then clips.swimidle=clips.swim end
        description:Destroy()
    end
    local animate=character:FindFirstChild("Animate")
    if animate then
        for key in pairs(DEFAULTS) do
            local folder=animate:FindFirstChild(key)
            if folder then
                local best,bestWeight=nil,-math.huge
                local items=folder:IsA("Animation") and {folder} or folder:GetDescendants()
                for _,item in ipairs(items) do
                    if item:IsA("Animation") then
                        local id=assetId(item.AnimationId)
                        local weight=item:FindFirstChild("Weight")
                        local value=weight and weight:IsA("NumberValue") and weight.Value or 1
                        if id and value>bestWeight then best,bestWeight=id,value end
                    end
                end
                if best then clips[key]=best end
            end
        end
    end
    return clips
end

function Bridge:_stop()
    if self.current then pcall(function()self.current:Stop(.12)end) end
    self.current=nil;self.currentId=nil;self.currentKey=nil
end
function Bridge:_clearRig()
    self:_stop()
    if self.rig then self.rig:Destroy() end
    self.rig=nil;self.animator=nil;self.rigJoints=nil;self.nativeJoints=nil
    self.nativeHumanoid=nil;self.nativeAnimator=nil
    self.tracks={};self.loading={}
    self.nativeAction=false;self.nativeCheckAt=0
end

function Bridge:_attach(character)
    self.generation+=1
    local generation=self.generation
    self.sourceCharacter=character;self.retryAt=os.clock()+2
    self:_clearRig();self.attaching=true
    self:_status("Preparing private R15 rig")
    task.spawn(function()
        local rig
        local r6=false
        local ok,err=pcall(function()
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            assert(humanoid,"Waiting for Humanoid")
            r6=humanoid.RigType==Enum.HumanoidRigType.R6
            assert(not r6,"R6 avatar: using Banjo animations")
            assert(character:FindFirstChild("HumanoidRootPart"),"Waiting for root")
            local nativeJoints=Retarget.joints(character)
            local clips=resolveClips(character,humanoid)
            -- Restore the only temporarily changed source property, even if Clone fails.
            local archivable=character.Archivable
            character.Archivable=true
            local cloned,result=pcall(function()return character:Clone()end)
            character.Archivable=archivable
            assert(cloned and result,"Could not clone R15 animation reference")
            rig=result;rig.Name="BK_R15AnimationReference";rig:SetAttribute("BKPortOwned",true)
            -- Remove scripts BEFORE parenting the clone anywhere in the DataModel.
            for _,item in ipairs(rig:GetDescendants()) do
                if item:IsA("LuaSourceContainer") or item:IsA("Accessory") or item:IsA("Tool")
                    or item:IsA("Animator") or item:IsA("Sound") or item:IsA("BillboardGui")
                    or item:IsA("SurfaceGui") then
                    item:Destroy()
                elseif item:IsA("BasePart") then
                    item.Transparency=1;item.LocalTransparencyModifier=1;item.CastShadow=false
                    item.CanCollide=false;item.CanTouch=false;item.CanQuery=false;item.Massless=true
                    item.Anchored=item.Name=="HumanoidRootPart"
                elseif item:IsA("Decal") or item:IsA("Texture") then item.Transparency=1
                elseif item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam") then item.Enabled=false
                elseif item:IsA("AnimationConstraint") then
                    item.IsKinematic=true;item.Transform=CFrame.identity
                elseif item:IsA("Motor6D") then item.Transform=CFrame.identity
                elseif item:IsA("Constraint") or item:IsA("JointInstance") then item:Destroy() end
            end
            local rigRoot=assert(rig:FindFirstChild("HumanoidRootPart"),"Clone root missing")
            local rigHumanoid=assert(rig:FindFirstChildOfClass("Humanoid"),"Clone Humanoid missing")
            rig.PrimaryPart=rigRoot;rigHumanoid.AutoRotate=false
            rigHumanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
            rigHumanoid.EvaluateStateMachine=false
            rigHumanoid.Health=rigHumanoid.MaxHealth
            local animator=Instance.new("Animator");animator.Parent=rigHumanoid
            rig.Parent=self.model -- Already excluded from Banjo's collision queries.
            rig:PivotTo(character.HumanoidRootPart.CFrame)
            local rigJoints=Retarget.joints(rig)
            if self.destroyed or self.generation~=generation then rig:Destroy();rig=nil;return end
            self.rig=rig;self.animator=animator;self.rigJoints=rigJoints;self.nativeJoints=nativeJoints
            self.nativeHumanoid=humanoid;self.nativeAnimator=humanoid:FindFirstChildOfClass("Animator")
            self.clips=clips
            self:_attribute("R15JointCount",15)
            self:_status("Ready")
        end)
        if not ok then
            if rig then rig:Destroy() end
            if not self.destroyed and self.generation==generation then
                self:_status("Fallback: "..tostring(err));self.retryAt=r6 and math.huge or os.clock()+5
                if self.lastError~=tostring(err) then
                    warn("[Banjo R15] "..tostring(err));self.lastError=tostring(err)
                end
            end
        end
        if self.generation==generation then self.attaching=false end
    end)
end

function Bridge:_track(id,key)
    if self.tracks[id]~=nil then return self.tracks[id] or nil end
    if self.loading[id] then return nil end
    self.loading[id]=true
    local animator,generation=self.animator,self.generation
    task.spawn(function()
        local animation=Instance.new("Animation");animation.AnimationId=id
        local ok,track=pcall(function()return animator:LoadAnimation(animation)end)
        if self.destroyed or self.generation~=generation then
            if ok then track:Destroy() end
            animation:Destroy();return
        end
        self.loading[id]=nil
        if ok then
            animation.Parent=self.rig
            track.Priority=Enum.AnimationPriority.Action
            self.tracks[id]=track
        else
            animation:Destroy();self.tracks[id]=false
            self:_status("Animation unavailable: "..id)
            warn("[Banjo R15] Could not load "..key.." ("..id.."): "..tostring(track))
        end
    end)
    return nil
end

local function clipFor(state,speed,motion,seated)
    if seated then return "sit",1 end
    if state=="JUMP" then return motion and motion.verticalVelocity<=0 and "fall" or "jump",1 end
    if state=="FALL" then return "fall",1 end
    if state=="CLIMB" then return "climb",math.clamp(speed*Config.Scale/5,0,2) end
    if state=="SWIM_IDLE" or state=="DIVE_IDLE" then return "swimidle",1 end
    if state=="SWIM" or state=="DIVE_MOVE" then return "swim",1 end
    if state=="RUN" then return "run",math.clamp(speed*Config.Scale/16,.25,2.5) end
    if state=="CREEP" or state=="WALK_SLOW" or state=="WALK" then
        return "walk",math.clamp(speed*Config.Scale/8,.15,2.5)
    end
    return "idle",1
end

function Bridge:_useNative(paused)
    local animator=self.nativeHumanoid and self.nativeHumanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end
    local now=os.clock()
    if now>=self.nativeCheckAt then
        self.nativeCheckAt=now+.1
        local ok,tracks=pcall(function()return animator:GetPlayingAnimationTracks()end)
        self.nativeAction=false;self.nativePlaying=false
        if ok then
            for _,track in ipairs(tracks) do
                if track.WeightCurrent>.01 then
                    self.nativePlaying=true
                    if track.Priority.Value>=Enum.AnimationPriority.Action.Value then self.nativeAction=true end
                end
            end
        end
    end
    return self.nativePlaying and (paused or self.nativeAction)
end

function Bridge:pose(state,speed,dt,motion)
    if self.destroyed then return nil end
    if self.runtime and self.runtime:GetAttribute("R15Enabled")==false then
        self:_stop();self:_attribute("R15Source","Banjo");self:_status("Disabled (F7)");return nil
    end
    local character=self.player and self.player.Character
    if not character then self:_status("Waiting for character");return nil end
    if self.sourceCharacter~=character or (not self.rig and not self.attaching and os.clock()>=self.retryAt) then
        self:_attach(character)
    end
    if not self.rig or self.sourceCharacter~=character then return nil end
    local paused=self.runtime and self.runtime:GetAttribute("ExternallyPaused")==true
    if not SUPPORTED[state] and not paused then
        self:_stop();self:_attribute("R15Source","Banjo special move");return nil
    end
    local joints
    if self:_useNative(paused) then
        self:_stop();joints=self.nativeJoints
        self:_attribute("R15Source","Native avatar pose");self:_attribute("R15Clip","Live")
    else
        local seated=paused and self.nativeHumanoid and (self.nativeHumanoid.SeatPart~=nil
            or self.nativeHumanoid:GetState()==Enum.HumanoidStateType.Seated)
        local key,rate=clipFor(state,speed or 0,motion,seated)
        local id=self.clips[key]
        local track=id and self:_track(id,key)
        if not track then
            self:_stop()
            self:_status((self.tracks[id]==false and "Unavailable " or "Loading ")..key.." "..tostring(id))
            return nil
        end
        if track~=self.current or key~=self.currentKey then
            self:_stop();track.Looped=key~="jump";track:Play(.15,1,rate)
            self.current=track;self.currentId=id;self.currentKey=key
            self.trackStartedAt=os.clock()
        else
            if key=="jump" and track.Length>0 and track.TimePosition>=track.Length-.05 then rate=0 end
            track:AdjustSpeed(rate)
        end
        if track.Length<=0 then
            if os.clock()-self.trackStartedAt>5 then
                self:_status("Animation did not load: "..id)
            else self:_status("Waiting for animation data") end
            return nil
        end
        local nativeRoot=character:FindFirstChild("HumanoidRootPart")
        if nativeRoot then self.rig:PivotTo(nativeRoot.CFrame) end -- private rig only
        joints=self.rigJoints
        self:_attribute("R15Source","Private R15 evaluator");self:_attribute("R15Clip",key.." "..id)
    end
    local ok,pose=pcall(function()return self.retarget:pose(joints)end)
    if not ok then self:_status("Pose fallback: "..tostring(pose));return nil end
    self:_status("Active")
    return pose
end

function Bridge:destroy()
    if self.destroyed then return end
    self.destroyed=true;self.generation+=1;self:_clearRig()
end

return Bridge
