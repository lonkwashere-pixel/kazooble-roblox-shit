-- Sense pads and climbing from the current world geometry.
local Config=require(script.Parent.Config)
local Yaw=require(script.Parent.Yaw)
local CollectionService=game:GetService("CollectionService")
local Traversal={}
local function padKind(part)
    local p=part
    while p and p~=workspace do
        local kind=p:GetAttribute("BKPad")or ({BK_FlightPad="Flight",BK_ShockSpringPad="ShockSpring"})[p.Name]
        if kind=="Flight"or kind=="ShockSpring"then return kind end
        p=p.Parent
    end
end
function Traversal.sense(c,input)
    local collision=c.collision;local options=collision.options
    input.padKind=nil;input.climbTarget=nil
    if not options then return end
    local world=collision.world;local body=collision.bodySize
    if options.EnablePads and c.grounded then
        local hit=world:Raycast(c.position,-Vector3.yAxis*(body.Y/2+.35),collision.params)
        if hit and hit.Normal.Y>.6 then input.padKind=padKind(hit.Instance)end
    end
    c.currentPad=input.padKind
    if c.climbing and (not c.climbing.part.Parent or not options.EnableClimbing)then input.cancelClimb=true end
    if not options.EnableClimbing or c.climbing or c.flying or c.action or c.climbCooldown>0 or input.move.Magnitude<.12 then return end
    local overlap=OverlapParams.new();overlap.FilterType=collision.params.FilterType
    overlap.FilterDescendantsInstances=collision.params.FilterDescendantsInstances
    local near=world:GetPartBoundsInBox(CFrame.new(c.position),body+Vector3.new(3,1,3),overlap)
    local best,bestDistance
    for _,p in near do
        if (p:IsA("TrussPart")or p:GetAttribute("BKClimbable")==true or CollectionService:HasTag(p,"BKClimbable"))and math.abs(p.CFrame.UpVector.Y)>.9 then
            local localPos=p.CFrame:PointToObjectSpace(c.position);local half=p.Size/2
            local normal,face
            if math.abs(localPos.X)/math.max(.1,half.X)>math.abs(localPos.Z)/math.max(.1,half.Z)then
                normal=p.CFrame.RightVector*(localPos.X>=0 and 1 or -1)
                face=Vector3.new(half.X*(localPos.X>=0 and 1 or -1),0,math.clamp(localPos.Z,-half.Z,half.Z))
            else
                normal=p.CFrame.LookVector*(localPos.Z>=0 and -1 or 1)
                face=Vector3.new(math.clamp(localPos.X,-half.X,half.X),0,half.Z*(localPos.Z>=0 and 1 or -1))
            end
            normal=Vector3.new(normal.X,0,normal.Z).Unit
            local surface=p.CFrame:PointToWorldSpace(face)
            local delta=Vector3.new(c.position.X-surface.X,0,c.position.Z-surface.Z)
            local distance=delta.Magnitude
            local bottom=p.Position.Y-half.Y+body.Y/2
            local top=p.Position.Y+half.Y+body.Y/2+Config.Skin
            if distance<body.X/2+.8 and c.position.Y>=bottom-.8 and c.position.Y<top and input.move:Dot(-normal)>.15 and (not bestDistance or distance<bestDistance)then
                local anchor=surface+normal*(body.X/2+Config.Skin+.05)
                best={part=p,position=anchor,normal=normal,bottom=bottom,top=top,exitPosition=Vector3.new(p.Position.X,top,p.Position.Z)}
                bestDistance=distance
            end
        end
    end
    input.climbTarget=best
end
return Traversal
