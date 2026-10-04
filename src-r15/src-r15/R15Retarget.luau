-- R15 -> Banjo vertex-skinning adapter. All matrices use N64 model units.
-- No native character movement, camera writes, or physics state changes.
local Animation = require(script.Parent.Animation)
local Retarget = {}; Retarget.__index = Retarget

-- Skeleton indices (zero based), verified from PackedData.Descriptor.
-- Banjo faces +Z locally, so its anatomical left is +X. R15 faces -Z.
local MAP = {
    [0] = {"LowerTorso", 43}, [16] = {"UpperTorso", 1}, [30] = {"Head", 18},
    [18] = {"LeftUpperArm", 14}, [20] = {"LeftLowerArm", 8}, [22] = {"LeftHand", 16},
    [24] = {"RightUpperArm", 28}, [26] = {"RightLowerArm", 22}, [28] = {"RightHand", 30},
    [4] = {"LeftUpperLeg", 10}, [6] = {"LeftLowerLeg", 12}, [8] = {"LeftFoot", 6},
    [10] = {"RightUpperLeg", 24}, [12] = {"RightLowerLeg", 26}, [14] = {"RightFoot", 20},
}
local IDENTITY = {x=Vector3.xAxis, y=Vector3.yAxis, z=Vector3.zAxis, p=Vector3.zero}
local RIG_TO_BANJO = CFrame.Angles(0, math.pi, 0)
local function vector(m, v) return m.x*v.X + m.y*v.Y + m.z*v.Z end
local function point(m, v) return vector(m,v) + m.p end
local function multiply(a,b)
    return {x=vector(a,b.x),y=vector(a,b.y),z=vector(a,b.z),p=point(a,b.p)}
end
local function inverse(m)
    local det = m.x:Dot(m.y:Cross(m.z))
    assert(math.abs(det)>1e-8, "Singular Banjo reference matrix")
    local a,b,c = m.y:Cross(m.z)/det, m.z:Cross(m.x)/det, m.x:Cross(m.y)/det
    local result = {
        x=Vector3.new(a.X,b.X,c.X), y=Vector3.new(a.Y,b.Y,c.Y), z=Vector3.new(a.Z,b.Z,c.Z),
        p=Vector3.zero,
    }
    result.p = -vector(result,m.p)
    return result
end
local function rotation(m)
    local x = m.x.Unit
    local y = (m.y-x*m.y:Dot(x)).Unit
    return CFrame.fromMatrix(Vector3.zero,x,y,x:Cross(y))
end
local function rotationAt(cf,pivot)
    return {x=cf.XVector,y=cf.YVector,z=cf.ZVector,p=pivot-cf:VectorToWorldSpace(pivot)}
end

function Retarget.new(data)
    local bind = Animation.pose(data,"idle",0)
    local self = setmetatable({data=data,locals={},bases={},pivots={}},Retarget)
    for i=0,#data.bones-1 do
        local bone = data.bones[i+1]
        local parent = bone[5]>=0 and bind[bone[5]] or IDENTITY
        self.locals[i] = multiply(inverse(parent),bind[i])
        self.bases[i] = rotation(parent)
        self.pivots[i] = point(self.locals[i],Vector3.new(bone[1],bone[2],bone[3]))
        local mapped = MAP[i]
        if mapped then
            assert(bone[4]==mapped[2],"Banjo skeleton changed at index "..i)
        end
    end
    return self
end

-- joints[childPartName] = {joint=Motor6D/AnimationConstraint, basis=rest model rotation}.
-- Joint translation/root motion is deliberately ignored: rendering must not
-- rebase movement or move the camera. Unmapped Kazooie bones keep the idle bind.
function Retarget:pose(joints)
    local matrices = {}
    local visiting = {}
    local function solve(i)
        if matrices[i] then return matrices[i] end
        assert(not visiting[i],"Circular Banjo bone hierarchy")
        visiting[i]=true
        local bone = self.data.bones[i+1]
        local localMatrix = self.locals[i]
        local mapped = MAP[i]
        local source = mapped and joints[mapped[1]]
        if source and source.joint.Parent then
            local basis = RIG_TO_BANJO * source.basis
            local offset = basis * source.joint.Transform.Rotation * basis:Inverse()
            local parentBasis = self.bases[i]
            local localOffset = parentBasis:Inverse() * offset * parentBasis
            localMatrix = multiply(rotationAt(localOffset,self.pivots[i]),localMatrix)
        end
        local parent = bone[5]>=0 and solve(bone[5]) or IDENTITY
        matrices[i] = multiply(parent,localMatrix)
        visiting[i]=nil
        return matrices[i]
    end
    for i=0,#self.data.bones-1 do solve(i) end
    return matrices
end

-- Build source rest rotations through C0/C1, ignoring animated part CFrames.
-- AnimationConstraint exposes compatible read-only C0/C1/Part0/Part1 aliases.
function Retarget.joints(character)
    local byPart, candidates = {}, {}
    for _,item in ipairs(character:GetDescendants()) do
        if item:IsA("Motor6D") or item:IsA("AnimationConstraint") then
            if item.Part0 and item.Part1 then
                local prior = byPart[item.Part1]
                if not prior or item:IsA("AnimationConstraint") then byPart[item.Part1]=item end
            end
        end
    end
    local rest, visiting = {}, {}
    local root = character:FindFirstChild("HumanoidRootPart")
    local function restFor(part)
        if rest[part] then return rest[part] end
        assert(not visiting[part],"Circular R15 rig joints")
        visiting[part]=true
        local joint = byPart[part]
        local cf
        if part==root or not joint then cf=CFrame.identity
        else cf=restFor(joint.Part0)*joint.C0*joint.C1:Inverse() end
        rest[part]=cf;visiting[part]=nil
        return cf
    end
    for part,joint in pairs(byPart) do
        candidates[part.Name] = {joint=joint,basis=(restFor(joint.Part0)*joint.C0).Rotation}
    end
    for _,mapped in pairs(MAP) do
        assert(candidates[mapped[1]],"Missing R15 joint for "..mapped[1])
    end
    return candidates
end

return Retarget
