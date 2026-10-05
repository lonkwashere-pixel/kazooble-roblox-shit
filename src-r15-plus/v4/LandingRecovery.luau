-- Banjo R15 build: 2.3.8-r15.4
-- One-time correction after teleport/control handoff. Never runs continuously.
local Config=require(script.Parent.Config)
local Recovery={};Recovery.__index=Recovery
function Recovery.new(world,collision,parent)
    return setmetatable({world=world,collision=collision,parent=parent,blocked=false},Recovery)
end
function Recovery:_clear(position)
    if not self.probe then
        local probe=Instance.new("Part");probe.Name="BK_LandingProbe";probe.Anchored=true
        probe.Transparency=1;probe.CanCollide=false;probe.CanTouch=false;probe.CanQuery=false
        probe:SetAttribute("BKPortOwned",true);probe.Parent=self.parent;self.probe=probe
    end
    self.probe.Size=self.collision.bodySize-Vector3.new(.02,.02,.02)
    self.probe.CFrame=CFrame.new(position)
    local params=OverlapParams.new();params.RespectCanCollide=true
    params.FilterType=self.collision.params.FilterType
    params.FilterDescendantsInstances=self.collision.params.FilterDescendantsInstances
    params.CollisionGroup=self.collision.params.CollisionGroup
    -- Exact part overlap catches ceilings/walls which a sweep already overlaps.
    return #self.world:GetPartsInPart(self.probe,params)==0
end
function Recovery:resolve(position)
    self.blocked=false
    local body=self.collision.bodySize;local halfHeight=body.Y/2
    local slab=.02;local lift=.25
    local origin=position+Vector3.yAxis*lift
    local floor=self.world:Blockcast(CFrame.new(origin),Vector3.new(body.X,slab,body.Z),
        -Vector3.yAxis*(halfHeight+Config.Skin+.3+lift),self.collision.params)
    if not floor or floor.Normal.Y<.6 then return position,false,Vector3.yAxis end
    local topY=origin.Y-floor.Distance-slab/2
    -- Reject an overhead surface. A small allowance recovers a root placed
    -- just inside an extremely thin platform; it never searches high above us.
    if topY>position.Y+.15 then return position,false,Vector3.yAxis end
    local desiredY=topY+halfHeight+Config.Skin
    local raise=desiredY-position.Y
    if raise<=0 then return position,raise>=-.05,floor.Normal end
    local target=Vector3.new(position.X,desiredY,position.Z)
    local ceiling=self.collision:cast(position,Vector3.yAxis*raise)
    if ceiling and ceiling.Distance<raise+Config.Skin then self.blocked=true;return position,false,Vector3.yAxis end
    if not self:_clear(target) then self.blocked=true;return position,false,Vector3.yAxis end
    return target,true,floor.Normal
end
function Recovery:destroy()
    if self.probe then self.probe:Destroy();self.probe=nil end
end
return Recovery
