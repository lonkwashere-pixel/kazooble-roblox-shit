-- __baphysics_update_normal, src/core2/ba/physics.c.
-- Position and velocity remain in original N64 units; conversion at adapter boundary.
local Physics = {}
function Physics.step(velocity: Vector3, target: Vector3, gravity: number,
    terminal: number, response: number, dt: number): (Vector3, Vector3)
    local vx = velocity.X + (target.X - velocity.X) * response * dt / 0.0333333
    local vz = velocity.Z + (target.Z - velocity.Z) * response * dt / 0.0333333
    if math.abs(vx) < 0.0001 then vx = 0 end
    if math.abs(vz) < 0.0001 then vz = 0 end
    local vy = math.max(velocity.Y + gravity * dt, terminal)
    local nextVelocity = Vector3.new(vx, vy, vz)
    return nextVelocity, nextVelocity * dt
end
return Physics
