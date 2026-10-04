-- One continuous alpha footprint, projected onto the ground surface.
local Shadow={}
function Shadow.new(parent)
    local p=Instance.new("Part");p.Name="BK_SoftShadow";p.Anchored=true
    p.Size=Vector3.new(2.7,.01,2.7);p.Transparency=1
    p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=parent
    local gui=Instance.new("SurfaceGui");gui.Face=Enum.NormalId.Top
    gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.CanvasSize=Vector2.new(64,64)
    gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.Parent=p
    local image=Instance.new("ImageLabel");image.BackgroundTransparency=1
    image.Size=UDim2.fromScale(1,1);image.ImageContent=require(script.Parent.Graphics).editableTexture("Shadow");image.Parent=gui
    return {part=p,image=image,gui=gui,pieces={}}
end
function Shadow.update(self,position,world)
    local params=self.params or RaycastParams.new()
    if not self.params then params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={self.part.Parent}end
    params.RespectCanCollide=true
    local hit=workspace:Raycast(position+Vector3.yAxis*.3,Vector3.new(0,-60,0),params)
    self.gui.Enabled=hit~=nil
    if hit then
        local normal=hit.Normal
        local right=Vector3.xAxis-normal*normal.X
        if right.Magnitude<.01 then right=Vector3.zAxis-normal*normal.Z end
        right=right.Unit
        self.part.CFrame=CFrame.fromMatrix(hit.Position+normal*.03,right,normal,right:Cross(normal))
        local height=math.max(0,position.Y-hit.Position.Y-(self.bodyHeight or require(script.Parent.Config).BodySize.Y)/2)
        local size=2.7*(self.scale or 1)*math.clamp(1-height*.025,.55,1)
        self.part.Size=Vector3.new(size,.01,size)
        self.image.ImageTransparency=math.clamp(height/24,0,.65)
    end
    return hit
end
return Shadow
