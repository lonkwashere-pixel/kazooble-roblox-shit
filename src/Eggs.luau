-- Local visual projectiles, with the same launch/bounce timing as the portable build.
local Graphics=require(script.Parent.Graphics)
local Yaw=require(script.Parent.Yaw)
local Eggs={};Eggs.__index=Eggs
function Eggs.new()
    local folder=Instance.new("Folder");folder.Name="BK_LocalEggs";folder:SetAttribute("BKPortOwned",true);folder.Parent=workspace
    return setmetatable({folder=folder,projectiles={},serial=0,params=RaycastParams.new()},Eggs)
end
function Eggs:shoot(c)
    self.serial+=1
    local dir=Yaw.direction(c.yaw)*(c.eggRear and -1 or 1)
    local part=Instance.new("Part");part.Name="Egg_"..self.serial;part.Shape=Enum.PartType.Ball
    part.Size=Vector3.new(.6,.8,.6);part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
    part.Color=Color3.fromRGB(95,203,232);part.Material=Enum.Material.SmoothPlastic;part.Reflectance=0
    part.Position=c.position+dir*2.1+Vector3.yAxis*.6;part.Parent=self.folder
    local r=Graphics.data().hudRects.egg
    local gui=Instance.new("BillboardGui");gui.Name="BK_EggSprite";gui.Size=UDim2.fromScale(.9,.9)
    gui.Adornee=part;gui.LightInfluence=0;gui.MaxDistance=300;gui.Parent=part
    local image=Instance.new("ImageLabel");image.Size=UDim2.fromScale(1,1);image.BackgroundTransparency=1
    image.ImageContent=Graphics.editableTexture("HUD");image.ImageRectOffset=Vector2.new(r[1],r[2]);image.ImageRectSize=Vector2.new(r[3],r[4]);image.Parent=gui
    part.LocalTransparencyModifier=1
    table.insert(self.projectiles,{part=part,position=part.Position,velocity=dir*30+Vector3.yAxis*(c.eggRear and 7 or 2),life=3.5,bounces=0})
    self.folder:SetAttribute("ShotsFired",self.serial)
end
function Eggs:update(dt,excluded)
    self.params.FilterType=Enum.RaycastFilterType.Exclude;self.params.RespectCanCollide=true
    self.params.FilterDescendantsInstances=excluded
    for i=#self.projectiles,1,-1 do
        local p=self.projectiles[i];p.life-=dt;p.velocity-=Vector3.yAxis*8*dt
        local hit=workspace:Raycast(p.position,p.velocity*dt,self.params)
        if hit then
            p.position=hit.Position+hit.Normal*.3;p.velocity=(p.velocity-2*p.velocity:Dot(hit.Normal)*hit.Normal)*.65;p.bounces+=1
        else p.position+=p.velocity*dt end
        p.part.Position=p.position
        if p.life<=0 or p.bounces>2 then p.part:Destroy();table.remove(self.projectiles,i)end
    end
end
function Eggs:clear()
    for _,p in self.projectiles do p.part:Destroy()end
    table.clear(self.projectiles)
end
function Eggs:destroy()self:clear();self.folder:Destroy()end
return Eggs
