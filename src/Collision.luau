-- Roblox platform adapter. This is not the original N64 collision engine.
local Config = require(script.Parent.Config)
local Settings = require(script.Parent.Settings)
local Collision = {}
Collision.__index = Collision
function Collision.new(world: Instance,excluded: {Instance}?,options)
    local params = RaycastParams.new()
    params.FilterType = excluded and Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = excluded or {world}
    params.RespectCanCollide = true
    options=Settings.normalize(options)
    return setmetatable({params=params,world=world,options=options,bodySize=Settings.bodySize(options)}, Collision)
end
function Collision:cast(position: Vector3, delta: Vector3)
    if delta.Magnitude < 0.000001 then return nil end
    local hidden={};local result
    -- N64 triangle collision is sided. A Roblox wedge also has a back face;
    -- accepting it as a floor prevents diving beneath the mountain overhang.
    -- This query never yields; temporarily hidden faces are restored below.
    for _=1,24 do
        local hit=self.world:Blockcast(CFrame.new(position),self.bodySize,delta,self.params)
        if not hit then break end
        local normal=hit.Instance:GetAttribute("OriginalNormal")
        if normal and normal:Dot(delta)>=-0.000001 then
            table.insert(hidden,hit.Instance);hit.Instance.CanQuery=false
        else
            result={Distance=hit.Distance,Position=hit.Position,Normal=normal or hit.Normal,Instance=hit.Instance}
            break
        end
    end
    for _,part in ipairs(hidden) do part.CanQuery=true end
    return result
end
function Collision:move(position: Vector3, delta: Vector3, velocity: Vector3, wasGrounded: boolean)
    local grounded, normal = false, Vector3.yAxis
    local start = position
    local horizontal = Vector3.new(delta.X, 0, delta.Z)
    if self.options.EnableStairs and wasGrounded and horizontal.Magnitude > 0.00001 then
        local wall = self:cast(position, horizontal)
        if wall and wall.Normal.Y < 0.6 then
            local raise = Vector3.yAxis * (Config.StepHeight*self.options.CharacterScale + Config.Skin)
            if not self:cast(position, raise) and not self:cast(position + raise, horizontal) then
                local raised = position + raise + horizontal
                local floor = self:cast(raised, -raise * 1.1)
                if floor and floor.Normal.Y >= 0.6 then
                    position = raised - Vector3.yAxis * math.max(0, floor.Distance - Config.Skin)
                    horizontal = Vector3.zero
                end
            end
        end
    end
    -- Slide horizontal movement along walls and slopes, up to three contacts.
    for _ = 1, 3 do
        if horizontal.Magnitude < 0.000001 then break end
        local hit = self:cast(position, horizontal)
        if not hit then position += horizontal; break end
        local travelled = horizontal.Unit * math.max(0, hit.Distance - Config.Skin)
        position += travelled
        local remaining = horizontal - travelled
        horizontal = remaining - hit.Normal * math.min(0, remaining:Dot(hit.Normal))
        local into = velocity:Dot(hit.Normal)
        if into < 0 then velocity -= hit.Normal * into end
    end
    local vertical = Vector3.yAxis * delta.Y
    local hit = self:cast(position, vertical)
    if hit then
        position += vertical.Unit * math.max(0, hit.Distance - Config.Skin)
        if delta.Y <= 0 and hit.Normal.Y >= 0.6 then grounded = true; normal = hit.Normal end
        velocity = Vector3.new(velocity.X, 0, velocity.Z)
    else position += vertical end
    -- Ground snap keeps descending ramp contacts stable; never snaps an ascending jump.
    if velocity.Y <= 0 then
        local snapDistance=wasGrounded and self.options.EnableStairs and Config.StepDownHeight*self.options.CharacterScale or .08
        local snap = self:cast(position, -Vector3.yAxis * snapDistance)
        if snap and snap.Normal.Y >= 0.6 then
            position -= Vector3.yAxis * math.max(0, snap.Distance - Config.Skin)
            grounded, normal = true, snap.Normal
            velocity = Vector3.new(velocity.X, 0, velocity.Z)
        end
    end
    return position, velocity, grounded, normal, position - start
end
return Collision
