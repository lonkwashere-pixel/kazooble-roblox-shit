-- Original skeletal tracks. Interpolation follows animationfile.c (Catmull-Rom).
local Animation={}
local function catmull(a,b,c,d,t)
    return 0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
end
local function sample(keys,frame,default,start)
    local n=#keys
    if frame<keys[1][1] then
        local first=keys[1]
        return catmull(default,default,first[2],bit32.band(first[3],2)~=0 and n>1 and keys[2][2] or first[2],(frame-start)/math.max(1,first[1]-start))
    end
    if frame>=keys[n][1] then
        local last=keys[n];local prev=bit32.band(last[3],1)~=0 and n>1 and keys[n-1][2] or last[2]
        return catmull(prev,last[2],last[2],last[2],math.clamp(frame-last[1],0,1))
    end
    local i=1
    while i<n-1 and frame>=keys[i+1][1] do i+=1 end
    local a,b=keys[i],keys[i+1];local t=(frame-a[1])/(b[1]-a[1])
    local before,after=bit32.band(a[3],1)~=0,bit32.band(b[3],2)~=0
    if not before and not after then return a[2]+(b[2]-a[2])*t end
    return catmull(before and i>1 and keys[i-1][2] or a[2],a[2],b[2],after and i+2<=n and keys[i+2][2] or b[2],t)
end
function Animation.pose(data,name,progress)
    local anim=assert(data.animations[name],"Missing animation "..name)
    local frame=anim.start+progress*(anim["end"]-anim.start)
    local values={}
    for _,track in ipairs(anim.tracks) do
        local bone=track[1];local t=values[bone]
        if not t then t={0,0,0,1,1,1,0,0,0};values[bone]=t end
        local kind=track[2]+1
        t[kind]=sample(track[3],frame,kind>=4 and kind<=6 and 1 or 0,anim.start)
    end
    local matrices={}
    local function boneMatrix(i)
        if matrices[i] then return matrices[i] end
        local bone=data.bones[i+1];local v=values[bone[4]] or {0,0,0,1,1,1,0,0,0}
        local pivot=Vector3.new(bone[1],bone[2],bone[3])
        local rotation=CFrame.Angles(0,0,math.rad(v[3]))*CFrame.Angles(0,math.rad(v[2]),0)*CFrame.Angles(math.rad(v[1]),0,0)
        local x=rotation.XVector*v[4];local y=rotation.YVector*v[5];local z=rotation.ZVector*v[6]
        local p=pivot+Vector3.new(v[7],v[8],v[9])*data.boneScale-x*pivot.X-y*pivot.Y-z*pivot.Z
        local m={x=x,y=y,z=z,p=p}
        if bone[5]>=0 then
            local parent=boneMatrix(bone[5])
            local function vector(a)return parent.x*a.X+parent.y*a.Y+parent.z*a.Z end
            m={x=vector(x),y=vector(y),z=vector(z),p=vector(p)+parent.p}
        end
        matrices[i]=m;return m
    end
    for i=0,#data.bones-1 do boneMatrix(i) end
    return matrices
end
function Animation.transform(m,p)
    if not m then return p end
    return m.x*p.X+m.y*p.Y+m.z*p.Z+m.p
end
return Animation
