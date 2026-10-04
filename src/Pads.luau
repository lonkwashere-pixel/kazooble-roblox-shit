-- Local pad markers provide activation; render their original ROM meshes.
local Graphics=require(script.Parent.Graphics)
local Pads={};Pads.__index=Pads
function Pads.new()
    local folder=Instance.new("Folder");folder.Name="BK_PadVisuals";folder.Parent=workspace
    local self=setmetatable({folder=folder,entries={},alive=true},Pads)
    local function remove(part)
        local e=self.entries[part];if not e then return end;self.entries[part]=nil
        for _,c in e.connections do c:Disconnect()end
        for _,piece in e.pieces do piece.mesh:Destroy()end
        e.model:Destroy();if part.Parent then part.LocalTransparencyModifier=e.transparency end
    end
    self.remove=remove
    local function added(part)
        if not self.alive or not part:IsA("BasePart")or self.entries[part]then return end
        local kind=part:GetAttribute("BKPad")or ({BK_FlightPad="Flight",BK_ShockSpringPad="ShockSpring"})[part.Name]
        local desc=Graphics.data().padModels[kind]
        if not desc then return end
        local model=Instance.new("Model");model.Name=kind.."Pad";model:SetAttribute("BKPortOwned",true);model.Parent=folder
        local e={model=model,pieces={},connections={},transparency=part.LocalTransparencyModifier}
        self.entries[part]=e
        local span=Vector3.new(desc.high[1]-desc.low[1],desc.high[2]-desc.low[2],desc.high[3]-desc.low[3])
        local scale=part.Size/span
        local ok,err=pcall(function()
            for _,d in desc.pieces do
                local piece=Graphics.mesh(d,false,model,scale,"Pads");piece.baseSize=piece.part.Size
                table.insert(e.pieces,piece)
            end
        end)
        if not ok then remove(part);warn("[BK] Pad renderer: "..tostring(err));return end
        local initialSize=part.Size
        local function update()
            if not part.Parent then remove(part);return end
            local ratio=part.Size/initialSize;local unit=scale*ratio
            local centerX=(desc.low[1]+desc.high[1])/2;local centerZ=(desc.low[3]+desc.high[3])/2
            local cf=part.CFrame*CFrame.new(-centerX*unit.X,-part.Size.Y/2-desc.low[2]*unit.Y,-centerZ*unit.Z)
            for _,piece in e.pieces do piece.part.Size=piece.baseSize*ratio;piece.part.CFrame=cf end
        end
        part.LocalTransparencyModifier=1;update()
        table.insert(e.connections,part:GetPropertyChangedSignal("CFrame"):Connect(update))
        table.insert(e.connections,part:GetPropertyChangedSignal("Size"):Connect(update))
        table.insert(e.connections,part.AncestryChanged:Connect(function()if not part:IsDescendantOf(workspace)then remove(part)end end))
    end
    self.added=workspace.DescendantAdded:Connect(added)
    for _,part in workspace:GetDescendants()do added(part)end
    return self
end
function Pads:destroy()
    if not self.alive then return end;self.alive=false;self.added:Disconnect()
    local parts={};for part in self.entries do table.insert(parts,part)end
    for _,part in parts do self.remove(part)end;self.folder:Destroy()
end
return Pads
