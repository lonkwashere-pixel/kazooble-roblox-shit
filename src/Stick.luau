-- Translated from src/core2/bastick.c and bs/walk.c.
local Stick = {}
local markers = {0.12, 0.2, 0.5, 0.75, 1}
local speeds = {30, 80, 150, 225, 500}
function Stick.zone(distance: number, trot: boolean?): (number, number)
    distance = math.clamp(distance, 0, 1)
    if trot then
        if distance <= 0.03 then return 0, 0 end
        return 1, (distance - 0.03) / 0.97
    end
    if distance <= markers[1] then return 0, 0 end
    for i = 2, #markers do
        if distance <= markers[i] then
            return i - 1, (distance - markers[i - 1]) / (markers[i] - markers[i - 1])
        end
    end
    return 4, 1
end
function Stick.speed(distance: number, trot: boolean?): number
    local zone, fraction = Stick.zone(distance, trot)
    if zone == 0 then return 0 end
    if trot then return 30 + (700 - 30) * fraction end
    return speeds[zone] + (speeds[zone + 1] - speeds[zone]) * fraction
end
return Stick
