-- __yaw_update_limited from src/core2/yaw.c; same 700 / 7.5 defaults.
local Yaw = {}
function Yaw.step(current: number, ideal: number, dt: number): number
    local delta = (ideal - current + 180) % 360 - 180
    local limit = 700 * dt
    local amount = delta * 7.5 * dt
    if amount < 0 then amount = math.clamp(amount, -limit, -0.1)
    else amount = math.clamp(amount, 0.1, limit) end
    if math.abs(amount) > math.abs(delta) then return ideal % 360 end
    return (current + amount) % 360
end
function Yaw.direction(degrees: number): Vector3
    -- Coordinate adapter: yaw zero faces Roblox -Z.
    local radians = math.rad(degrees)
    return Vector3.new(-math.sin(radians), 0, -math.cos(radians))
end
function Yaw.angle(direction: Vector3): number
    return math.deg(math.atan2(-direction.X, -direction.Z)) % 360
end
return Yaw
