-- Banjo R15 build: 2.3.8-r15.3
-- Local presentation for equipped Tools. The real Tool keeps its scripts,
-- grip, activation events, physical parts, and normal Backpack lifecycle.
local Players=game:GetService("Players")
local Gear={};Gear.__index=Gear
local function removeUnsafeChildren(copy)
    for _,item in ipairs(copy:GetDescendants()) do
        if item:IsA("LuaSourceContainer") or item:IsA("BasePart") or item:IsA("JointInstance") or item:IsA("Constraint")
            or item:IsA("Sound") or item:IsA("TouchTransmitter") or item:IsA("ProximityPrompt")
            or item:IsA("ClickDetector") or item:IsA("BillboardGui") or item:IsA("SurfaceGui")
            or item:IsA("Beam") or item:IsA("Trail") or item:IsA("ParticleEmitter")
            or item:IsA("Animator") or item:IsA("Humanoid") or item:IsA("AnimationController") then item:Destroy() end
    end
end
function Gear.new(model,runtime)
    local folder=Instance.new("Folder");folder.Name="BK_EquippedGear";folder.Parent=model
    return setmetatable({folder=folder,runtime=runtime,player=Players.LocalPlayer,parts={},time=0,scanAt=0},Gear)
end
function Gear:_remove(source,entry)
    if source.Parent then source.LocalTransparencyModifier=entry.transparency end
    if entry.copy then entry.copy:Destroy() end
    self.parts[source]=nil
end
function Gear:_scan(character)
    local wanted={}
    if character then
        for _,tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") then
                for _,source in ipairs(tool:GetDescendants()) do
                    if source:IsA("BasePart") then
                        wanted[source]=true
                        if not self.parts[source] then
                            local entry={tool=tool,transparency=source.LocalTransparencyModifier,meshes={}}
                            local ok,copy=pcall(function()return source:Clone()end)
                            if ok and copy then
                                removeUnsafeChildren(copy) -- BEFORE parenting anything in Workspace.
                                copy.Name=source.Name;copy.Anchored=true;copy.CanCollide=false
                                copy.CanTouch=false;copy.CanQuery=false;copy.Massless=true
                                copy.LocalTransparencyModifier=0;copy.CastShadow=source.CastShadow
                                for _,mesh in ipairs(source:GetDescendants()) do
                                    if mesh:IsA("SpecialMesh") then
                                        local cloned=copy:FindFirstChild(mesh.Name,true)
                                        if cloned and cloned:IsA("SpecialMesh") then table.insert(entry.meshes,{source=mesh,copy=cloned}) end
                                    end
                                end
                                copy.Parent=self.folder;entry.copy=copy
                            end
                            self.parts[source]=entry
                        end
                    end
                end
            end
        end
    end
    for source,entry in pairs(self.parts) do if not wanted[source] then self:_remove(source,entry) end end
end
function Gear:update(dt,handFrame)
    if self.destroyed then return end
    self.time+=dt or 0
    local character=self.player.Character
    if character~=self.character or self.time>=self.scanAt then
        self.character=character;self.scanAt=self.time+.1;self:_scan(character)
    end
    local visible=not self.runtime or self.runtime:GetAttribute("ShowTools")~=false
    local attached=not self.runtime or self.runtime:GetAttribute("AttachToolsToBear")~=false
    local size=self.runtime and self.runtime:GetAttribute("ToolVisualScale") or 1
    size=type(size)=="number" and math.clamp(size,.5,1.5) or 1
    local hand=character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
    local camera=workspace.CurrentCamera
    local firstPerson=camera and (camera.CFrame.Position-camera.Focus.Position).Magnitude<1
    if firstPerson and self.runtime and self.runtime:GetAttribute("ShowToolsFirstPerson")==false then visible=false end
    local count,mirrors=0,0
    for source,entry in pairs(self.parts) do
        if not source.Parent or entry.tool.Parent~=character then self:_remove(source,entry)
        else
            count+=1
            local mirrored=visible and attached and entry.copy and hand and handFrame
            source.LocalTransparencyModifier=(not visible or mirrored) and 1 or entry.transparency
            if entry.copy then
                entry.copy.Transparency=mirrored and source.Transparency or 1
                if mirrored then
                    mirrors+=1
                    local relative=hand.CFrame:ToObjectSpace(source.CFrame)
                    relative=CFrame.new(relative.Position*size)*relative.Rotation
                    entry.copy.CFrame=handFrame*relative
                    entry.copy.Size=source.Size*size;entry.copy.Color=source.Color;entry.copy.Material=source.Material
                    for _,mesh in ipairs(entry.meshes) do
                        if mesh.source.Parent and mesh.copy.Parent then mesh.copy.Scale=mesh.source.Scale*size;mesh.copy.Offset=mesh.source.Offset*size end
                    end
                end
            end
        end
    end
    if self.runtime and self.runtime.Parent then
        local status=count>0 and (visible and (attached and (mirrors==count and "Following Banjo hand" or "Native grip (visual fallback)") or "Native grip") or "Hidden") or "No equipped Tool"
        if self.runtime:GetAttribute("GearStatus")~=status then self.runtime:SetAttribute("GearStatus",status) end
    end
end
function Gear:destroy()
    if self.destroyed then return end
    self.destroyed=true
    for source,entry in pairs(self.parts) do self:_remove(source,entry) end
    self.folder:Destroy()
end
return Gear
