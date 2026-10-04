local PACKED=require(script.Parent.PackedData)
-- ROM render adapter: atlas UVs and original Gouraud vertex colors.
-- Geometry, animation tracks and all atlas pixels are embedded locally.
local AssetService=game:GetService("AssetService")
local Config=require(script.Parent.Config)
local Graphics={}
local cached={}
function Graphics.blob(name)
    if not cached[name] then
        local encoded=assert(PACKED[name],"Missing embedded data: "..name)
        local e=game:GetService("EncodingService")
        cached[name]=e:DecompressBuffer(e:Base64Decode(buffer.fromstring(encoded)),Enum.CompressionAlgorithm.Zstd)
    end
    return cached[name]
end
local metadata
function Graphics.data()
    if not metadata then metadata=game:GetService("HttpService"):JSONDecode(buffer.tostring(Graphics.blob("Descriptor"))) end
    return metadata
end
local images={}
local function textureName(character)
    return type(character)=="string" and character or (character and "Character" or "Map")
end
local atlasKeys={Character="characterAtlas",HUD="hudAtlas",Shadow="shadowAtlas",Wings="wingsAtlas",Pads="padsAtlas"}
function Graphics.editableTexture(character)
    local name=textureName(character)
    if not images[name] then
        local size=Graphics.data()[atlasKeys[name]]
        local image=AssetService:CreateEditableImage({Size=Vector2.new(size[1],size[2])})
        assert(image,"EditableImage budget exhausted")
        image:WritePixelsBuffer(Vector2.zero,Vector2.new(size[1],size[2]),Graphics.blob(name.."Pixels"))
        images[name]=image
    end
    return Content.fromObject(images[name])
end
local surfaces={}
local matte
function Graphics.surface(character)
    local name=textureName(character)
    if not surfaces[name] then
        if not matte then
            matte=AssetService:CreateEditableImage({Size=Vector2.one})
            local pixels=buffer.create(4);buffer.fill(pixels,0,255,4)
            matte:WritePixelsBuffer(Vector2.zero,Vector2.one,pixels)
        end
        local surface=AssetService:CreateSurfaceAppearanceAsync({ColorMap=Graphics.editableTexture(character),RoughnessMap=Content.fromObject(matte)})
        surface.AlphaMode=Enum.AlphaMode.Transparency
        surfaces[name]=surface
    end
    return surfaces[name]:Clone()
end
function Graphics.texture(character)function Graphics.destroy()
    for _,surface in surfaces do surface:Destroy()end;table.clear(surfaces)
    if matte then matte:Destroy();matte=nil end
    for _,image in images do image:Destroy()end;table.clear(images)
    table.clear(cached);metadata=nil
end
return Graphics.editableTexture(character)end
function Graphics.read(desc,skinned)
    local b=Graphics.blob(desc.name);local offset=8
    local vertices,triangles={},{}
    for i=1,buffer.readu32(b,0) do
        local p=Vector3.new(buffer.readf32(b,offset),buffer.readf32(b,offset+4),buffer.readf32(b,offset+8))
        local uv=Vector2.new(buffer.readf32(b,offset+12),buffer.readf32(b,offset+16))
        local color=Color3.fromRGB(buffer.readu8(b,offset+20),buffer.readu8(b,offset+21),buffer.readu8(b,offset+22))
        local alpha=buffer.readu8(b,offset+23)/255
        offset+=24;local skin={}
        if skinned then
            local count=buffer.readu8(b,offset);offset+=1
            for j=1,count do
                skin[j]={bone=buffer.readi16(b,offset),position=Vector3.new(buffer.readf32(b,offset+2),buffer.readf32(b,offset+6),buffer.readf32(b,offset+10)),weight=buffer.readf32(b,offset+14)}
                offset+=18
            end
        end
        vertices[i]={position=p,uv=uv,color=color,alpha=alpha,skin=skin}
    end
    for i=1,buffer.readu32(b,4) do
        triangles[i]={buffer.readu16(b,offset)+1,buffer.readu16(b,offset+2)+1,buffer.readu16(b,offset+4)+1};offset+=6
    end
    assert(offset==buffer.len(b),"Corrupt graphics buffer "..desc.name)
    return vertices,triangles
end
function Graphics.mesh(desc,skinned,parent,scale,textureKind)
    local mesh=AssetService:CreateEditableMesh();assert(mesh,"EditableMesh budget exhausted")
    local vertices,triangles=Graphics.read(desc,skinned)
    local ids,colors,uvs={},{},{}
    for i,v in ipairs(vertices) do
        ids[i]=mesh:AddVertex(v.position*(scale or Config.Scale))
        colors[i]=mesh:AddColor(v.color,v.alpha)
        uvs[i]=mesh:AddUV(v.uv)
        v.id=ids[i]
    end
    for _,t in ipairs(triangles) do
        local f=mesh:AddTriangle(ids[t[1]],ids[t[2]],ids[t[3]])
        mesh:SetFaceColors(f,{colors[t[1]],colors[t[2]],colors[t[3]]})
        mesh:SetFaceUVs(f,{uvs[t[1]],uvs[t[2]],uvs[t[3]]})
    end
    if skinned then
        -- Coplanar rest-pose feathers have a .001-stud Y render bound. Keep a
        -- fixed animation envelope so GPU culling cannot discard unfolded wings.
        -- Collinear triangles have no rasterized area and hold these bounds.
        local envelope=Config.AvatarHeight*5
        for _,x in {-envelope,envelope}do for _,y in {-envelope,envelope}do for _,z in {-envelope,envelope}do
            local p=Vector3.new(x,y,z)
            mesh:AddTriangle(mesh:AddVertex(p),mesh:AddVertex(p+Vector3.xAxis*.001),mesh:AddVertex(p-Vector3.xAxis*.001))
        end end end
    end
    -- Mutable meshes reserve far more memory than these small N64 pieces need.
    -- Preserve stable IDs so CPU skinning can update the fixed-size copy.
    local fixed=AssetService:CreateEditableMeshAsync(Content.fromObject(mesh),{FixedSize=true})
    mesh:Destroy()
    assert(fixed,"Fixed-size mesh budget exhausted")
    mesh=fixed
    local part=AssetService:CreateMeshPartAsync(Content.fromObject(mesh),{RenderFidelity=Enum.RenderFidelity.Precise})
    part.Name=desc.name
    part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch=true,false,false,false
    part.DoubleSided=true
    part.Material=Enum.Material.Fabric
    part.Reflectance=0
    part.Color=Color3.new(1,1,1)
    part.CastShadow=false
    part.Transparency=1-(desc.opacity or 1)
    part.TextureContent=Graphics.texture(desc.textureKind or textureKind or skinned)
    if desc.cutout then
        local surface=Graphics.surface(desc.textureKind or textureKind or skinned)
        local tint=desc.tint or {255,255,255}
        surface.Color=Color3.fromRGB(tint[1],tint[2],tint[3])
        part.TextureContent=Content.none
        surface.Parent=part
    end
    part.Parent=parent
    return {mesh=mesh,part=part,vertices=vertices,selectors=desc.selectors,feathers=desc.feathers}
end
function Graphics.lighting()
    local l=game:GetService("Lighting")
    local changes={Ambient=Color3.new(1,1,1),OutdoorAmbient=Color3.new(1,1,1),ColorShift_Top=Color3.new(),ColorShift_Bottom=Color3.new(),Brightness=0,GlobalShadows=false,EnvironmentDiffuseScale=0,EnvironmentSpecularScale=0,ExposureCompensation=0,FogStart=180,FogEnd=650,FogColor=Color3.fromRGB(174,206,242)}
    local saved={}
    for k,v in pairs(changes) do saved[k]=l[k];l[k]=v end
    local effects={}
    local atmosphere={}
    for _,effect in ipairs(l:GetChildren()) do
        if effect:IsA("PostEffect") then effects[effect]=effect.Enabled;effect.Enabled=false end
        if effect:IsA("Atmosphere")then atmosphere[effect]={effect.Density,effect.Haze,effect.Glare};effect.Density=0;effect.Haze=0;effect.Glare=0 end
    end
    return function()
        for k,v in pairs(saved) do l[k]=v end
        for effect,enabled in pairs(effects) do if effect.Parent then effect.Enabled=enabled end end
        for effect,v in atmosphere do if effect.Parent then effect.Density=v[1];effect.Haze=v[2];effect.Glare=v[3]end end
    end
end
function Graphics.destroy()
    for _,surface in surfaces do surface:Destroy()end;table.clear(surfaces)
    if matte then matte:Destroy();matte=nil end
    for _,image in images do image:Destroy()end;table.clear(images)
    table.clear(cached);metadata=nil
end
return Graphics
