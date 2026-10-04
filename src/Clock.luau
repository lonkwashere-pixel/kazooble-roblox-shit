-- Keep the original 30Hz physics stable across render rates and short hitches.
local Config=require(script.Parent.Config)
local Clock={};Clock.__index=Clock
function Clock.new()return setmetatable({accumulator=0,clampedTime=0,renderTime=0,ticks=0},Clock)end
function Clock:advance(dt,step)
    local accepted=math.clamp(dt,0,1)
    self.clampedTime+=math.max(0,dt-accepted)
    self.accumulator+=accepted
    local count=0
    while self.accumulator+1e-9>=Config.Step and count<30 do
        step(Config.Step)
        self.accumulator=math.max(0,self.accumulator-Config.Step)
        self.ticks+=1;count+=1
    end
    local alpha=math.clamp(self.accumulator/Config.Step,0,1)
    local time=self.ticks*Config.Step+alpha*Config.Step
    local renderDelta=math.max(0,time-self.renderTime)
    self.renderTime=time
    return alpha,renderDelta,count
end
return Clock
