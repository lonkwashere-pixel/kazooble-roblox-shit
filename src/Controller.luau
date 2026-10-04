-- Selected decomp move parameters and state timing, with Roblox collision.
local Config = require(script.Parent.Config)
local Stick = require(script.Parent.Stick)
local Yaw = require(script.Parent.Yaw)
local Physics = require(script.Parent.Physics)
local Controller = {}
Controller.__index = Controller
function Controller.new(collision)
    local self = setmetatable({collision = collision}, Controller)
    self:reset()
    return self
end
function Controller:reset()
    self.position = self.spawn or Config.Spawn
    self.velocity = Vector3.zero
    self.yaw, self.ideal = 0, 0
    self.grounded, self.trot, self.hasFlapped = false, false, false
    self.state, self.jumpKind = "FALL", nil
    self.gravity, self.terminal = Config.Gravity, Config.Terminal
    self.normal = Vector3.yAxis
    self.ticks, self.landings, self.jumps, self.maxY = 0, 0, 0, self.position.Y
    self.action=nil;self.hasFlapped=false;self.hasPecked=false
    self.attackActive=false;self.impact=false;self.eggFired=false;self.attackSerial=0
    self.swimming=false;self.diving=false;self.air=30;self.drowning=false
    self.climbing=nil;self.climbCooldown=0
    self.flying=false;self.flightTime=0;self.flightFlapCooldown=0;self.feathers=Config.FlightFeathers;self.pitch=0
end
function Controller:startAction(kind,duration)
    self.action={kind=kind,time=0,duration=duration};self.state=kind
    self.attackSerial+=1
end
function Controller:hurt(direction)
    self.flying=false;self.pitch=0
    self.climbing=nil;self.swimming=false;self.diving=false;self.trot=false
    self:startAction("HURT",0.8)
    self.grounded=false;self.jumpKind="HURT"
    self.velocity=direction*250+Vector3.yAxis*350
    self.gravity,self.terminal=Config.Gravity,Config.Terminal
end
function Controller:flightStep(input,dt)
    self.flightTime+=dt;self.flightFlapCooldown=math.max(0,self.flightFlapCooldown-dt)
    if input.busterPressed then
        self.flying=false;self.pitch=0;self:startAction("BUSTER",8)
        self.velocity=Vector3.zero;self.gravity=0;self.jumpKind="BUSTER"
        return false
    end
    if input.move.Magnitude>.03 then self.ideal=Yaw.angle(input.move)end
    self.yaw=Yaw.step(self.yaw,self.ideal,dt)
    local pitch=math.clamp(input.flightPitch or 0,-60,80)
    self.pitch+= (pitch-self.pitch)*math.min(1,dt*4)
    if input.jumpPressed and self.flightFlapCooldown==0 and self.feathers>0 then
        self.feathers-=1;self.flightFlapCooldown=.15
        self.velocity=Vector3.new(self.velocity.X,math.max(0,self.velocity.Y)+Config.FlightFlap,self.velocity.Z)
    end
    local speed,gravity,terminal=Config.FlightSpeed,Config.FlightGravity,Config.FlightTerminal
    if self.pitch>60 then
        local t=(self.pitch-60)/20;speed=600-540*t;gravity=-300-400*t;terminal=-99.9-900.43*t
    elseif self.pitch< -20 then
        local t=(-self.pitch-20)/40;speed=600*(1-t);terminal=-99.9-300.09*t
    end
    local velocity,delta=Physics.step(self.velocity,Yaw.direction(self.yaw)*speed,gravity,terminal,.12,dt)
    self.position,velocity,self.grounded,self.normal=self.collision:move(self.position,delta*Config.Scale,velocity*Config.Scale,false)
    self.velocity=velocity/Config.Scale;self.state="FLY";self.jumpKind="FLY"
    self.maxY=math.max(self.maxY,self.position.Y)
    if self.grounded then
        self.flying=false;self.pitch=0;self.jumpKind=nil;self.state="IDLE";self.trot=false
        self.gravity,self.terminal=Config.Gravity,Config.Terminal;self.hasFlapped=false
    end
    if self.position.Y<(self.spawn or Config.Spawn).Y-150 then self:reset()end
    return true
end
function Controller:swimStep(input,dt,height)
    local magnitude=math.clamp(input.move.Magnitude,0,1)
    if magnitude>.03 then self.ideal=Yaw.angle(input.move) end
    self.yaw=Yaw.step(self.yaw,self.ideal,dt)
    if input.divePressed then self.diving=not self.diving end
    local horizontal=Yaw.direction(self.ideal)*(magnitude>.03 and (30+270*magnitude) or 0)
    local vertical
    if self.diving then
        vertical=(input.swimVertical or 0)*220
        if self.position.Y>height-.65 then self.position=Vector3.new(self.position.X,height-.65,self.position.Z) end
        self.state=(magnitude>.03 or math.abs(vertical)>1) and "DIVE_MOVE" or "DIVE_IDLE"
        if self.position.Y<height-1.5 then self.air=math.max(0,self.air-dt) else self.air=30 end
    else
        vertical=math.clamp((height-.15-self.position.Y)/Config.Scale*8,-300,300)
        self.state=magnitude>.03 and "SWIM" or "SWIM_IDLE";self.air=30
    end
    self.drowning=self.air<=0
    self.velocity=self.velocity:Lerp(horizontal+Vector3.yAxis*vertical,math.min(1,dt*6))
    self.position,self.velocity,self.grounded,self.normal=self.collision:move(self.position,self.velocity*Config.Scale*dt,self.velocity*Config.Scale,false)
    self.velocity/=Config.Scale;self.grounded=false
    self.maxY=math.max(self.maxY,self.position.Y)
end
function Controller:step(input, dt: number)
    self.ticks += 1
    self.attackActive,self.impact,self.eggFired=false,false,false
    self.climbCooldown=math.max(0,self.climbCooldown-dt)
    if input.reset then local feathers=self.feathers;self:reset();self.feathers=feathers;return end
    if self.flying and self:flightStep(input,dt)then return end
    local jumpConsumed=false
    if input.climbTarget and not self.climbing and self.climbCooldown==0 then
        self.climbing=input.climbTarget;self.action=nil;self.trot=false;self.jumpKind=nil
        if self.climbing.normal then self.yaw=Yaw.angle(-self.climbing.normal);self.ideal=self.yaw end
    end
    if self.climbing then
        local tree=self.climbing
        self.state="CLIMB";self.grounded=false;self.velocity=Vector3.zero
        local axis=input.climbAxis or 0
        local vertical=math.abs(axis)>.03 and math.sign(axis)*(100+200*math.abs(axis)) or 0
        local y=math.clamp(self.position.Y+vertical*Config.Scale*dt,tree.bottom,tree.top)
        if tree.normal then
            local delta=Vector3.yAxis*(y-self.position.Y)
            local hit=self.collision:cast(self.position,delta)
            if hit then y=self.position.Y+math.sign(delta.Y)*math.max(0,hit.Distance-Config.Skin)end
        end
        local direction=Yaw.direction(self.yaw)
        self.position=tree.normal and Vector3.new(tree.position.X,y,tree.position.Z) or Vector3.new(tree.position.X-direction.X*1.3,y,tree.position.Z-direction.Z*1.3)
        self.climbSpeed=math.abs(vertical)
        if axis>0 and y>=tree.top and tree.exitPosition then
            self.position=tree.exitPosition;self.climbing=nil;self.climbCooldown=.6
            self.state="FALL";self.jumpKind=nil
        elseif input.jumpPressed or input.cancelClimb or (axis<0 and y<=tree.bottom) then
            self.climbing=nil;self.climbCooldown=.6;self.jumpKind="JUMP";self.state="JUMP"
            self.velocity=-direction*200+Vector3.yAxis*Config.JumpVelocity
            self.gravity=Config.JumpGravity;self.jumps+=1
            jumpConsumed=true
        else self.maxY=math.max(self.maxY,y);return end
    end
    local water=input.waterHeight
    if water and self.position.Y<water+.4 and self.velocity.Y<50 and not self.climbing then
        if not self.swimming then self.swimming=true;self.diving=false;self.action=nil;self.jumpKind=nil;self.trot=false;self.hasFlapped=false end
    elseif self.swimming and not water then self.swimming=false;self.diving=false;self.jumpKind=nil end
    if self.swimming then
        if input.jumpPressed and not self.diving then
            self.swimming=false;self.position=Vector3.new(self.position.X,water+.65,self.position.Z)
            self.velocity=Yaw.direction(self.yaw)*200+Vector3.yAxis*Config.JumpVelocity
            self.jumpKind="JUMP";self.state="JUMP";self.gravity=Config.JumpGravity;self.grounded=false;self.jumps+=1
            jumpConsumed=true
        else self:swimStep(input,dt,water);return end
    else self.air=30;self.drowning=false end
    if self.action then
        self.action.time+=dt
        if self.action.time>=self.action.duration then
            self.action=nil;self.gravity,self.terminal=Config.Gravity,Config.Terminal
            if not self.grounded then self.jumpKind=nil end
        end
    end
    if input.jumpPressed and not jumpConsumed and self.grounded and not self.action and not input.crouch and input.padKind then
        self.trot=false;self.pitch=0;self.velocity=Vector3.zero
        if input.padKind=="Flight"then self:startAction("FLY_ENTER",8);self.jumpKind="FLY_ENTER"
        elseif input.padKind=="ShockSpring"then self:startAction("SPRING_CHARGE",Config.SpringCharge+1);self.jumpKind="SPRING_JUMP"end
        jumpConsumed=true
    end
    if input.toggleTrot and self.grounded then self.trot = not self.trot end
    local magnitude = math.clamp(input.move.Magnitude, 0, 1)
    if not self.action and magnitude > (self.trot and 0.03 or 0.12) then
        self.ideal = Yaw.angle(input.move)
    end
    self.yaw = Yaw.step(self.yaw, self.ideal, dt)
    local speed = Stick.speed(magnitude, self.trot)
    if input.crouch and self.grounded and not self.trot then speed = 0 end
    local direction = Yaw.direction(self.ideal)
    if input.attackPressed and not self.action and not self.trot then
        if self.grounded then
            if input.crouch then self:startAction("BARGE",1.15)
            elseif magnitude>.12 then self:startAction("ROLL",.9)
            else self:startAction("CLAW",1.3) end
        elseif not self.hasPecked then
            self.hasPecked=true;self:startAction("PECK",.95)
            self.velocity=Vector3.new(self.velocity.X,120,self.velocity.Z);self.gravity=-1400
        end
    end
    if input.eggPressed and self.grounded and not self.action and (input.eggsAvailable or 0)>0 then
        self:startAction(input.eggRear and "EGG_REAR" or "EGG",1)
    end
    if input.busterPressed and not self.grounded and (not self.action or self.action.kind=="FLIP" and self.action.launched) then
        self:startAction("BUSTER",8);self.velocity=Vector3.zero;self.gravity=0;self.jumpKind="BUSTER"
    end
    if input.jumpPressed and not jumpConsumed and self.grounded and (not self.action or self.action.kind=="CLAW" or self.action.kind=="ROLL") then
        self.action=nil
        self.jumps += 1
        self.grounded = false
        if input.crouch and not self.trot then
            self.jumpKind, self.state = "FLIP", "FLIP"
            self:startAction("FLIP",8)
            self.grounded=true;self.velocity=Vector3.zero;speed=0
            self.gravity,self.terminal=0,Config.FlipTerminal
        elseif self.trot then
            self.jumpKind, self.state = "TROT_JUMP", "TROT_JUMP"
            self.gravity = Config.TrotGravity
            self.velocity = direction * speed + Vector3.yAxis * Config.TrotJump
        else
            self.jumpKind, self.state = "JUMP", "JUMP"
            self.gravity = Config.JumpGravity
            self.velocity = direction * speed + Vector3.yAxis * Config.JumpVelocity
        end
    elseif input.jumpPressed and not jumpConsumed and not self.grounded and not self.hasFlapped and not self.action and self.jumpKind~="FLIP" and self.jumpKind~="TROT_JUMP" then
        self.hasFlapped=true;self:startAction("FLAP",2.5);self.jumpKind="FLAP"
        self.velocity=Vector3.new(self.velocity.X,0,self.velocity.Z);self.gravity=-1100;self.terminal=-399.9
    end
    if self.action then
        local a=self.action;local t=a.time
        if a.kind=="FLIP" then
            if not a.launched and t<Config.FlipWindup then
                self.state="FLIP";self.velocity=Vector3.zero
                return
            end
            if not a.launched then
                a.launched=true;self.grounded=false;self.jumpKind="FLIP"
                speed=magnitude>.03 and 200 or 0
                self.velocity=direction*speed+Vector3.yAxis*Config.FlipVelocity
                self.gravity,self.terminal=Config.FlipGravity,Config.FlipTerminal
            end
        elseif a.kind=="CLAW" then
            speed=t<1.3*.5788 and 160 or 0
            local p=t/1.3
            self.attackActive=(p>.0488 and p<.2488) or (p>.2288 and p<.4288) or (p>.4788 and p<.6788)
        elseif a.kind=="ROLL" then speed=t<.72 and 600 or 0;self.attackActive=t<.72
        elseif a.kind=="BARGE" then
            speed=t<.375 and 0 or math.max(0,(input.attackHeld and 850 or 500)-math.max(0,t-.565)*2400)
            if t>=.375 and not a.launched then a.launched=true;self.velocity=direction*speed+Vector3.yAxis*self.velocity.Y end
            self.attackActive=t>=.375 and speed>200
        elseif a.kind=="PECK" then self.attackActive=t>.1 and t<.75;speed=200
        elseif a.kind=="BUSTER" then
            speed=0
            if t>=.357 and not a.launched then a.launched=true;self.velocity=Vector3.yAxis*2300;self.gravity=-20000;self.terminal=-5000 end
            self.attackActive=a.launched and self.velocity.Y<0 or false
        elseif a.kind=="FLAP" then
            if t>=.27 and not a.launched then a.launched=true;self.velocity=Vector3.new(self.velocity.X,280,self.velocity.Z) end
            if (t>.67 and input.jumpReleased) or t>2.5 then self.action=nil;self.jumpKind=nil;self.gravity,self.terminal=Config.Gravity,Config.Terminal end
            if t>1.6 then speed*=.35 end
        elseif a.kind=="EGG" or a.kind=="EGG_REAR" then
            speed=0
            if t>=.4704 and not a.fired then self.eggFired=true;a.fired=true;self.eggRear=a.kind=="EGG_REAR" end
        elseif a.kind=="FLY_ENTER"then
            speed=0
            if not a.launched then
                if t<Config.FlightWindup then self.velocity=Vector3.zero;self.state="FLY_ENTER";return end
                a.launched=true;self.grounded=false;self.jumps+=1
                self.velocity=Vector3.yAxis*Config.FlightLaunch;self.gravity=-1200;self.terminal=Config.Terminal
            elseif self.velocity.Y<=0 then
                self.action=nil;self.flying=true;self.flightTime=0;self.state="FLY";self.jumpKind="FLY"
                self:flightStep(input,dt);return
            end
        elseif a.kind=="SPRING_CHARGE"then
            speed=0
            if input.jumpReleased then self.action=nil;self.jumpKind=nil;self.state="IDLE";return end
            if t<Config.SpringCharge then self.velocity=Vector3.zero;self.state="SPRING_CHARGE";return end
            self.action=nil;self.jumpKind="SPRING_JUMP";self.grounded=false;self.jumps+=1
            self.velocity=Vector3.yAxis*Config.SpringVelocity;self.gravity=Config.SpringGravity;self.terminal=Config.Terminal
        elseif a.kind=="HURT" or a.kind=="BUSTER_LAND" then speed=0 end
    end
    if not self.grounded then
        if self.jumpKind == "FLIP" then
            speed = magnitude > 0.03 and (80 + 120 * math.clamp((magnitude - 0.03) / 0.97, 0, 1)) or 0
            if input.jumpReleased then self.terminal = Config.Terminal end
        elseif not self.action and input.jumpReleased and self.velocity.Y > 0 then
            self.gravity = Config.Gravity -- bsjump_update / bsbtrot_jump_update
        end
    end
    local target = direction * speed
    -- code_C4B0.c selects type 2 on a normal floor; type 1 while airborne.
    -- commonParticle.c gives their blending coefficients 0.29 and 0.07.
    local response = self.grounded and (self.trot and Config.TrotResponse or Config.GroundResponse) or Config.AirResponse
    local velocity, delta = Physics.step(self.velocity, target, self.gravity, self.terminal, response, dt)
    local wasGrounded = self.grounded
    self.position, velocity, self.grounded, self.normal = self.collision:move(
        self.position, delta * Config.Scale, velocity * Config.Scale, wasGrounded)
    self.velocity = velocity / Config.Scale
    self.maxY = math.max(self.maxY, self.position.Y)
    if self.jumpKind=="SPRING_JUMP"and self.velocity.Y<=0 then self.jumpKind=nil end
    if self.grounded then
        if not wasGrounded then self.landings += 1 end
        self.gravity, self.terminal = Config.Gravity, Config.Terminal
        self.jumpKind = nil
        self.hasFlapped,self.hasPecked=false,false
        if self.action and self.action.kind=="FLIP" and self.action.launched then
            self.action=nil
        elseif self.action and self.action.kind=="BUSTER" then
            self.impact=true;self.attackActive=true;self:startAction("BUSTER_LAND",.3)
        elseif self.action and (self.action.kind=="FLAP" or self.action.kind=="PECK") then self.action=nil end
        if self.trot then self.state = magnitude > 0.03 and "TALON_TROT" or "TROT_IDLE"
        elseif input.crouch then self.state = "CROUCH"
        else
            local zone = Stick.zone(magnitude)
            self.state = ({"IDLE", "CREEP", "WALK_SLOW", "WALK", "RUN"})[zone + 1]
        end
    elseif not self.jumpKind then self.state = "FALL"
    else self.state = self.jumpKind end
    if self.action then self.state=self.action.kind end
    if self.position.Y < (self.spawn or Config.Spawn).Y-150 then self:reset() end
end
return Controller
