pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
--reflection.p8 jam
--sheebeehs levels
--by many contributers

_g=_ENV
poke(24366,1)
function vector(n,e)
return{x=n,y=e}
end
function v0()return vector(0,0)end
function rectangle(n)
local _g,_ENV=_ENV,{}
x,y,w,h=_g.unpack(_g.split(n))
return _ENV
end
objects={}
freeze,delay_restart,sfx_timer,music_timer,ui_timer=0,0,0,0,-99
cam_x,cam_y,cam_spdx,cam_spdy,cam_gain,cam_offx,cam_offy=0,0,0,0,.25,0,0
_pal=pal
function _init()
max_djump,deaths,frames,seconds,minutes,music_timer,time_ticking,berry_count=1,0,0,0,0,0,true,0
music(0,0,7)
load_level(1)
end
dead_particles={}
player={
layer=2,
init=function(_ENV)
particles,feather,collides,djump,hitbox={},false,true,max_djump,rectangle"1,3,6,5"
create_hair(_ENV)
foreach(split"bouncetimer,grace,jbuffer,dash_time,dash_effect_time,dash_target_x,dash_target_y,dash_accel_x,dash_accel_y,spr_off,berry_timer,_berry_count",function(n)
_ENV[n]=0
end)
end,
update=function(_ENV)
local n,e=btn(➡️)and 1or btn(⬅️)and-1or 0,btn(⬆️)and-1or btn(⬇️)and 1or 0
foreach(particles,function(n)
n.x+=n.xspd
n.y+=n.yspd
n.xspd=appr(n.xspd,0,.03)
n.yspd=appr(n.yspd,0,.03)
n.life-=1
if n.life==0then
del(particles,n)
end
end)
if y>lvl_ph and not exit_bottom then
kill_player(_ENV)
end
if feather then
local d=1
if n~=0or e~=0then
movedir,d=appr_circ(movedir,atan2(n,e),.04),1.5
end
spd=vector(d*cos(movedir),d*sin(movedir))
local e=vector(x+4.5,y+4.5)
foreach(tail,function(n)
n.x+=(e.x-n.x)/1.4
n.y+=(e.y-n.y)/1.4
e=n
end)
if bouncetimer==0then
if is_solid(0,2)or is_solid(0,-2)then
movedir*=-1
bouncetimer=2
init_smoke()
elseif is_solid(2,0)or is_solid(-2,0)then
movedir=round(movedir)+.5-movedir
bouncetimer=2
init_smoke()
end
end
if bouncetimer>0then
bouncetimer-=1
end
local n={x=x+rnd(8)-4,y=y+rnd(8)-4,life=10+flr(rnd(5))}
n.xspd=-spd.x/2-(x-n.x)/4
n.yspd=-spd.y/2-(y-n.y)/4
add(particles,n)
lifetime-=1
if lifetime==0or btn(❎)then
p_dash=false
feather=false
init_smoke()
player.init(_ENV)
spd.x/=2
spd.y=spd.y<0and-1.5or 0
end
elseif feather_idle then
spd.x*=.8
spd.y*=.8
spawn_timer-=1
if spawn_timer==0then
feather_idle=false
feather=true
if n==0and e==0then
movedir=flip.x and.5or 0
else
movedir=atan2(n,e)
end
lifetime=60
_g.bouncetimer=0
tail,particles={},{}
for n=0,15do
add(tail,{x=x+4,y=y+4,size=mid(1,2,9-n)})
end
end
end
if not feather and not feather_idle then
local d=is_solid(0,1)
if d then
berry_timer+=1
else
berry_timer,_berry_count=0,0
end


if d and not was_on_ground then
init_smoke(0,4)
end
local f,o=btn(🅾️)and not p_jump,btn(❎)and not p_dash
p_jump,p_dash=btn(🅾️),btn(❎)
if f then
jbuffer=4
elseif jbuffer>0then
jbuffer-=1
end
if d then
grace=6
if djump<max_djump then
psfx(22)
djump=max_djump
end
elseif grace>0then
grace-=1
end
dash_effect_time-=1
if dash_time>0then
init_smoke()
dash_time-=1
spd=vector(
appr(spd.x,dash_target_x,dash_accel_x),
appr(spd.y,dash_target_y,dash_accel_y)
)
else
local f=d and.6or.4
spd.x=abs(spd.x)<=1and
appr(spd.x,n*1,f)or
appr(spd.x,sign(spd.x)*1,.15)
if spd.x~=0then
flip.x=spd.x<0
end
local f=2
if n~=0and is_solid(n,0)then
f=.4
if rnd(10)<2then
init_smoke(n*6)
end
end
if not d then
spd.y=appr(spd.y,f,abs(spd.y)>.15and.21or.105)
end
if jbuffer>0then
if grace>0then
psfx(18)
jbuffer,grace,spd.y=0,0,-2
init_smoke(0,4)
else
local n=is_solid(-3,0)and-1or is_solid(3,0)and 1or 0
if n~=0then
psfx(19)
jbuffer=0
spd=vector(n*-2,-2)
init_smoke(n*6)
end
end
end
if djump>0and o then
init_smoke()
djump-=1
dash_time=4
has_dashed=true
dash_effect_time=10
spd=vector(n~=0and
n*(e~=0and 3.53553or 5)or
(e~=0and 0or flip.x and-1or 1)
,e~=0and e*(n~=0and 3.53553or 5)or 0)
psfx(20)
dash_target_x=2*sign(spd.x)
dash_target_y=(spd.y>=0and 2or 1.5)*sign(spd.y)
dash_accel_x=spd.y==0and 1.5or 1.06066
dash_accel_y=spd.x==0and 1.5or 1.06066
elseif djump<=0and o then
psfx(21)
init_smoke()
end
end
spr_off+=.25
sprite=not d and(is_solid(n,0)and 5or 3)or
btn(⬇️)and 6or
btn(⬆️)and 7or
spd.x~=0and n~=0and 1+spr_off%4or 1
update_hair(_ENV)
if(exit_right and left()>=lvl_pw or
exit_top and y<-4or
exit_left and right()<0or
exit_bottom and top()>=lvl_ph)and levels[lvl_id+1]then
next_level()
end
was_on_ground=d
end
end,
draw=function(_ENV)
foreach(particles,function(n)
if n.big then spr(15,n.x-1,n.y-1,1,1,n.flip.x,n.flip.y)
else pset(n.x+4,n.y+4,10)end
end)
if feather and lifetime then
if lifetime%5==1then pal(10,7)end
if lifetime<10then
pal(10,lifetime%4<2and 8or 10)
end
circfill(x+4,y+4,4,10)
foreach(tail,function(n)
circfill(n.x,n.y,n.size,10)
end)
elseif feather_idle then
circfill(x+4,y+4,3,spawn_timer%4<2and 7or 10)
else
pal(8,djump==1and 8or 12)
draw_hair(_ENV)
draw_obj_sprite(_ENV)
pal()
end
end
}
function create_hair(_ENV)
hair={}
for n=1,5do
add(hair,vector(x,y))
end
end
function update_hair(_ENV)
local e=vector(x+(flip.x and 6or 1),y+(btn(⬇️)and 4or 2.9))
foreach(hair,function(n)
n.x+=(e.x-n.x)/1.5
n.y+=(e.y+.5-n.y)/1.5
e=n
end)
end
function draw_hair(_ENV)
for e,n in inext,hair do
circfill(round(n.x),round(n.y),split"2,2,1,1,1"[e],8)
end
end
player_spawn={
init=function(_ENV)
layer=2
sfx"15"
sprite=3
target=y
y=min(y+48,lvl_ph)
_g.cam_x,_g.cam_y=mid(x,64,lvl_pw-64),mid(y,64,lvl_ph-64)
spd.y=-4
state=0
delay=0
create_hair(_ENV)
djump=max_djump
foreach(fruitrain,function(n)
fruitrain[1].target=_ENV
add(objects,n)
n.x,n.y=x,y
fruit.init(n)
end)
end,
update=function(_ENV)
if state==0and y<target+16then
state,delay=1,3
elseif state==1then
spd.y+=.5
if spd.y>0then
if delay>0then
spd.y=0
delay-=1
elseif y>target then
y,spd,state,delay,_g.shake=target,vector(0,0),2,5,4
init_smoke(0,4)
sfx"16"
end
end
elseif state==2then
delay-=1
sprite=6
if delay<0then
destroy_object(_ENV)
local n=init_object(player,x,y);
(fruitrain[1]or{}).target=n
end
end
update_hair(_ENV)
end,
draw=player.draw
}
camera_trigger={
update=function(_ENV)
if timer and timer>0then
timer-=1
if timer==0then
_g.cam_offx,_g.cam_offy=offx,offy
else
_g.cam_offx+=cam_gain*(offx-cam_offx)
_g.cam_offy+=cam_gain*(offy-cam_offy)
end
elseif player_here()then
timer=5
end
end
}
spring={
update=function(_ENV)
delta=delta or 0
delta*=.75
local n,e=_ENV,dir
local _ENV=player_here()and player_here()or n
if _ENV~=n then
move(0,n.y-y-4,1)
spd.x*=.2
spd.y=-3
dash_time,dash_effect_time,n.delta,djump=0,0,4,max_djump
end
end,
draw=function(_ENV)
local n=flr(delta)
sspr(64,0,8,8-n,x,y+n)
end
}
refill={
init=function(_ENV)
offset,timer,hitbox=rnd(),0,rectangle"-1,-1,10,10"
end,
update=function(_ENV)
if timer>0then
timer-=1
if timer==0then
psfx"12"
init_smoke()
end
else
offset+=.02
local n=player_here()
if n and n.djump<max_djump then
psfx"11"
init_smoke()
n.djump,timer=max_djump,60
end
end
end,
draw=function(_ENV)
if timer==0then
spr(12,x,y+sin(offset)+.5)
else
spr(11,x,y)
end
end
}
smoke={
init=function(_ENV)
layer,spd,flip=3,vector(.3+rnd"0.2",-.1),vector(rnd()<.5,rnd()<.5)
x+=-1+rnd"2"
y+=-1+rnd"2"
end,
update=function(_ENV)
sprite+=.2
if sprite>=27then
destroy_object(_ENV)
end
end
}
fruitrain={}
fruit={
init=function(_ENV)
golden,y_,off,tx,ty=true,y,0,x,y
if deaths>0then
destroy_object(_ENV)
end
end,
update=function(_ENV)
if target then
tx+=.2*(target.x-tx)
ty+=.2*(target.y-ty)
local n,e=x-tx,y_-ty
local d,o=atan2(n,e),n^2+e^2>r^2and.2or.1
x+=o*(r*cos(d)-n)
y_+=o*(r*sin(d)-e)
else
local n=player_here()
if n then
n.berry_timer,target,r=
0,fruitrain[#fruitrain]or n,fruitrain[1]and 8or 12
add(fruitrain,_ENV)
end
end
off+=.025
y=y_+sin(off)*2.5
end
}
lifeup={
init=function(_ENV)
spd.y,duration,flash,_g.sfx_timer,outline=-.25,30,0,20
sfx"9"
end,
update=function(_ENV)
duration-=1
if duration<=0then
destroy_object(_ENV)
end
flash+=.5
end,
draw=function(_ENV)
?split"1000,2000,3000,4000,5000,1up"[min(sprite,6)],x-4,y-4,7+flash%2
end
}
kevin={
init=function(_ENV)
while(right()<lvl_pw-1and tile_at(right()/8,y/8)!=65)hitbox.w+=8
while(bottom()<lvl_ph-1and tile_at(x/8,bottom()/8)!=80)hitbox.h+=8
solid_obj,collides,retrace_list,hit_timer,retrace_timer,shake=true,true
,{},
0,
0,
0
end,
update=function(_ENV)
shake=max(0,shake-1)
for n=-1,1do
for e=-1,1do
if(n+e)%2==1then
local d=check(player,n,e)
if d and d.dash_effect_time>0and
(n~=0and sign(d.dash_target_x)==-n or e~=0and sign(d.dash_target_y)==-e)and
(not active or n~=dirx and e~=diry)then
d.spd=vector(n*1.5,e==1and.5or-1.5)
d.dash_time=-1
add(retrace_list,vector(x,y))
dirx,diry=n,e
spd=v0()
hit_timer=10
active=true
shake=4
end
end
end
end
if hit_timer>0then
hit_timer-=1
if hit_timer==0then
spd=vector(.2*dirx,.2*diry)
end
elseif active then
if spd.x==0and spd.y==0then
retrace_timer=10
active=false
shake=5
if dirx~=0then
for n=0,hitbox.h-1,8do
init_smoke(dirx==-1and-8or hitbox.w,n)
end
else
for n=0,hitbox.w-1,8do
init_smoke(n,diry==-1and-8or hitbox.h)
end
end
else
spd=vector(appr(spd.x,3*dirx,.2),appr(spd.y,3*diry,.2))
end
elseif retrace_timer>0then
retrace_timer-=1
if retrace_timer==0then
retrace=true
end
elseif retrace then
local n=retrace_list[#retrace_list]
if not n then
retrace=false
elseif n.x==x and n.y==y then
del(retrace_list,n)
retrace_timer=5
shake=4
spd=v0()
rem=v0()
else
spd=vector(appr(spd.x,sign(n.x-x),.2),appr(spd.y,sign(n.y-y),.2))
end
end
end,
draw=function(_ENV)
local n,e=x,y
if shake>0then
n+=rnd"2"-1
e+=rnd"2"-1
end
local o,f,t,d,i,r=n+hitbox.w-8,e+hitbox.h-8,active and diry==-1,active and diry==1,active and dirx==-1,active and dirx==1
for n=n+8,o-8,8do
pal(12,t and 7or 12)
spr(65,n,e)
pal(12,d and 7or 12)
spr(65,n,f,1,1,false,true)
end
for e=e+8,f-8,8do
pal(12,i and 7or 12)
spr(80,n,e)
pal(12,r and 7or 12)
spr(80,o,e,1,1,true)
end
rectfill(n+8,e+8,o,f,4)
local t={d,i,t,r,d}
for d=0,3do
pal(12,(t[d+1]or t[d+2])and 7or 12)
spr(64,d<=1and n or o,(d-1)\2==0and e or f,1,1,d>=2,(d-1)\2~=0)
end
pal()
spr(active and 63or 47,n+hitbox.w/2-4,e+hitbox.h/2-4)
end
}
bumper={
init=function(_ENV)
hitbox=rectangle"1,1,14,14"
hittimer=0
startx,starty=x,y
meep=0
outline=false
inc=rnd"1"<.5and-.02or.02
end,
update=function(_ENV)
x=startx+cos(meep*1.5)*2
y=starty+sin(meep)*1.5
if hittimer>0then
hittimer-=1
if hittimer==0then
init_smoke(4,4)
end
else
meep+=inc
local n=player_here()
if n then
n.init_smoke()
local e,d=x+8-(n.x+4),y+8-(n.y+4)
local o=atan2(e,d)
n.spd=abs(e)>abs(d)and vector(sign(e)*-2.8,-2)or
vector(-3*cos(o),-3*sin(o))
n.dash_time,n.djump=-1,max_djump
hittimer=20
end
end
end,
draw=function(_ENV)
local n,e=x+8,y+8
if hittimer>0then
pal(12,1)
pal(4,2)
if hittimer>17then
circ(n,e,26-hittimer,7)
circfill(n,e,25-hittimer,1)
if hittimer>19then
rectfill(n-4,e-9,n+4,e+9,7)
rectfill(n-9,e-4,n+9,e+4,7)
end
end
end
sspr(112,16,8,16,x,y)
sspr(112,16,8,16,x+8,y,8,16,true)
pal()
if hittimer==1then
circfill(n,e,4,6)
end
end
}
function appr_circ(n,e,d)
return(n+sign(sin(n)*cos(e)-cos(n)*sin(e))*d)%1
end
feather={
init=function(_ENV)
sprtimer=0
offset=0
starty,startx=y,x
timer=0
bubble=sprite==27
bubbled=bubble
end,
update=function(_ENV)
if timer>0then
timer-=1
if timer==0then
init_smoke()
bubbled=bubble
end
else
sprtimer+=.2
offset+=.01
y=appr(y,starty+.5+2*sin(offset),1)
x=appr(x,startx,1)
if(bubbled)hitbox=rectangle"-4,-4,16,16"
local n=player_here()
::n::
if not bubbled and n then
init_smoke()
timer=60
if n.feather_state then
n.lifetime=60
else
n.spawn_timer,n.feather_idle,n.dash_time,n.dash_effect_time=10,true,-10,0
n.spd=vector(mid(n.spd.x,-1.5,1.5),mid(n.spd.y,-1.5,1.5))
end
particles={}
for e=0,10do
local e={x=x+rnd"8"-4,y=y+rnd"8"-4,life=10+flr(rnd(5)),big=true}
e.xspd=-n.spd.x/2-(x-e.x)/4
e.yspd=-n.spd.y/2-(y-e.y)/4
e.flip=vector(rnd"1">.5,rnd"1">.5)
add(n.particles,e)
end
elseif bubbled and n then
if n.dash_time>0then
bubbled=false
goto n
else
local e=atan2(n.y+4-(y+4),n.x+4-(x+4))+.01
local e,d=sin(e)*2,cos(e)*2
n.spd=vector(e,d)
x=startx-e*3
y=starty-d*3
n.djump=max_djump
if(n.movedir)n.movedir+=.5
end
end
hitbox=rectangle"0,0,8,8"
end
end,
draw=function(_ENV)
if timer==0then
local n=flr(sprtimer%6)
spr(66+min(n,6-n),x,y,1,1,n>3)
end
end
}
garbage={
init=function(_ENV)
local n=check(osc_plat,0,-1)
if n then
n.badestate=sprite+1
n.hitbox.h+=8
destroy_object(_ENV)
return
end
n=check(osc_plat,-1,0)
if n then
n.target_id=sprite
foreach(objects,function(e)
if e.type==garbage and e.sprite==sprite and e~=_ENV then
n.targetx,n.targety=e.x,e.y
destroy_object(e)
end
end)
destroy_object(_ENV)
else
foreach(objects,function(n)
if n.type==osc_plat and n.target_id==sprite then
n.targetx,n.targety=x,y
destroy_object(_ENV)
end
end)
end
end,
end_init=function(_ENV)
for n in all(objects)do
if n.type==badeline then
n.nodes[sprite+1]={x,y}
end
end
destroy_object(_ENV)
end
}
badeline={
init=function(_ENV)
nodes,next_node,ffreeze,outline,off,target_x,target_y,rx,ry,attack,attack_timer={},1,
0,
false,
0,
x,y,
x,y,
boss_phases[1],
0
end,
update=function(_ENV)
off+=.005
attack_timer+=1
x,y=round(rx+4*sin(2*off)),round(ry+4*sin(off))
if ffreeze>0then
ffreeze-=1
else
if round(rx)~=target_x or round(ry)~=target_y then
rx+=.2*(target_x-rx)
ry+=.2*(target_y-ry)
else
local n=player_here()
if n then
attack_timer=1
destroy_object(laser or{})
laser=nil
if next_node>#nodes then
target_x=lvl_pw+50
node,ffreeze=-1,10
else
target_x,target_y=unpack(nodes[next_node])
ffreeze=10
end
next_node+=1
attack=boss_phases[next_node]
n.dash_time=4
n.djump=max_djump
n.spd=vector(-2,-1)
n.dash_accel_x,n.dash_accel_y=0,0
off=0
local e=20
foreach(objects,function(n)
if n.type==fall_plat or n.type==osc_plat and next_node-1==n.badestate then
n.timer=e
n.state=0
e+=15
end
end)
elseif node~=-1and find_player()then
hitbox=rectangle'-12,-12,32,32' --try to suck player in
local hit=player_here()
hitbox=rectangle'0,0,8,8'
if hit then
hit.spd=vector(mid(-2,2,hit.spd.x),mid(-2,2,hit.spd.y))
hit.dash_time=0
hit.spd.x+=hit.left()>right() and -.5 or hit.right()<left() and .5 or 0
hit.spd.y+=hit.top()>bottom() and -.25 or hit.bottom()<top() and .25 or 0
end
if attack==1and attack_timer%60==0then
init_object(orb,flip.x and right()or left(),y+4)
elseif attack==2and attack_timer%100==0then
laser=init_object(laser,x,y)
laser.badeline=_ENV
end
end
end
end
foreach(objects,function(n)
if n.type==player and ffreeze==0then
if n.x>x+16then
flip.x=true
elseif n.x<x-16then
flip.x=false
end
end
end)
end,
draw=function(_ENV)
for n=1,2do
pal(n,ffreeze==0and n or _g.frames%2==0and 14or 7)
end
for n in all(split("1,-0.1 1,-0.4 2,0 2,0.5 1,0.125 1,0.375"," "))do
local d,e=unpack(split(n))
for n=0,7do
circfill(x+(flip.x and 2or 6)+1.45*n*cos(e),y+3+1.45*n*sin(e)+(ffreeze>0and 0or sin((_g.frames+3*n+4*e)/14)),split"2,2,1,1,1,1,1"[n],d)
end
end
draw_obj_sprite(_ENV)
pal()
_g.anxiety=true
end
}
orb={
init=function(_ENV)
for n in all(objects)do
if n.type==player then
local n,e=n.x+4-x,n.y+4-y
local d=sqrt(n^2+e^2)*.65
spdx,spdy=n/d,e/d
end
end
init_smoke(-4+2*sign(spdx),-4)
hitbox,t,y_,particles=
rectangle"-2,-2,5,5",0,y,{}
end,
update=function(_ENV)
t+=.05
x+=spdx
y_+=spdy
y=round(y_+1.5*sin(t))
local n=player_here()
if n then
kill_player(n)
end
if maybe()then
add(particles,{
x=x,
y=y,
dx=-rnd()*spdx,
dy=-rnd()*spdy,
c=8,
d=15
})
end
foreach(particles,function(n)
n.x+=n.dx
n.y+=n.dy
if rnd()<.3then
n.c=split"7,8,14"[1+flr(rnd"3")]
end
n.d-=1
if n.d<0then
del(particles,n)
end
end)
end,
draw=function(_ENV)
foreach(particles,function(n)
pset(n.x,n.y,n.c)
end)
local d,o,n=x,y,t
for n=n,n+.08,.01do
pset(round(d+6*cos(n)),round(o-6*sin(n)),8)
end
local f,t,e=cos(2*n)<=-.5and 1or 0,cos(2*n)>.5and 1or 0,1+flr(1.5*n%3)
for n in all{2.001,round(1-cos(1.5*n))}do
if n>0or e==3then
if n~=2.001and e==3then n=2-n end
ovalfill(d-n-f,o-n-t,d+n,o+n,n~=2.001and split"14,7,8"[e]or e==2and 8or 2)
end
pal()
end
end
}
function find_player()
for n in all(objects)do
if n.type==player or n.type==player_spawn then
return n
end
end
end
function line_dist(f,t,n,e,d,o)
local d,o=d-n,o-e
return abs(d*(e-t)-(n-f)*o)/sqrt(d^2+o^2)
end
function rectfillr(d,o,f,t,n,i,r,a)
local function e(e,d)e,d=e-i,d-r return vector(i+cos(n)*e-sin(n)*d,r+sin(n)*e+cos(n)*d)end
local d,n,e=
{e(d,o),e(d,t),e(f,t),e(f,o)},32767.99999,32768
for d in all(d)do
n,e=min(n,d.y),max(e,d.y)
end
for n=ceil(n),e do
local o,f=32767.99999,32768
for t,e in pairs(d)do
local d=d[1+t%4]
if mid(n,e.y,d.y)==n then
local n=e.x+(n-e.y)/(d.y-e.y)*(d.x-e.x)
o,f=min(o,n),max(f,n)
end
end
rectfill(o,n,f,n,a)
end
end
function get_laser_coords(_ENV)
return badeline.x+4,badeline.y-1,playerx+4,playery+6
end
laser={
layer=3,
init=function(_ENV)
outline=false
timer=0
particles={}
end,
update=function(_ENV)
timer+=1
local n=find_player()
if n then
if timer<30then
playerx,playery=appr(playerx or badeline.x,n.x,10),appr(playery or badeline.y,n.y,10)
elseif timer==45then
if line_dist(n.x+4,n.y+6,get_laser_coords(_ENV))<6then
kill_player(n)
end
elseif timer>=48and#particles==0then
destroy_object(_ENV)
badeline.laser=nil
end
foreach(particles,function(n)
n.x+=n.dx
n.y+=n.dy
n.d-=1
if n.d<0then
del(particles,n)
end
end)
else
destroy_object(_ENV)
end
end,
draw=function(_ENV)
local d=timer
if d>42and d<45then return end
if d<48then
local n,e,o,f=get_laser_coords(_ENV)
local o,f=n-o,e-f
local r,a=n-128*o,e-128*f
for d=0,rnd"4"do
local d=rnd()
line(n,e,n+cos(d)*rnd"7",e+sin(d)*rnd"7",7)
end
local t,i,l,c,h=n,e,sqrt(o^2+f^2)*.1,d>45and 2or.5,d>=30and d%4<2and 7or 8
line(n,e,n,e,8)
for n=0,10do
t-=o/l
i-=f/l
line(t+(rnd"10"-5)*c,i+(rnd"10"-5)*c,maybe()and 0or d>45and h or 2)
if d==47then
for n=1,3do
add(particles,{
x=t,
y=i,
dx=rnd()-.5,
dy=rnd()-.5,
d=10
})
end
end
end
if d<45or d==47then
line(n,e,r,a,h)
local o=d>30and d%4<2and 4or 2
for d=1,2do
circfill(n,e,o/d,7+d)
end
else
for d=1,3do
rectfillr(n+2,e+split"-4,-4,3"[d],n+132,e+split"4,-3,4"[d],atan2(r-n,a-e),n,e,split"7,8,8"[d])
end
circfill(n,e,4,7)
end
end
foreach(particles,function(n)
pset(n.x,n.y,n.d>4and 8or 2)
end)
end
}
function plat_draw(_ENV)
local n,e=x,y
if shake>0then
n+=rnd"2"-1
e+=rnd"2"-1
end
local d,o,f=n+hitbox.w-8,e+hitbox.h-8,1.5*timer-4.5
palt(0,false)
palt(5,true)
palt(14,true)
if palswap then
pal(12,2)
pal(7,5)
pal(6,1)
end
if f>0and f<12and state==0then
rect(n-f,e-f,d+f+8,o+f+8,14)
end
for n=n,d,d-n do
for n=e,o,o-e do
end
end
spr(33,n,e)
spr(35,d,e)
spr(49,n,o)
spr(51,d,o)
for n=n+8,d-8,8do
spr(34,n,e)
spr(50,n,o)
end
for e=e+8,o-8,8do
spr(32,n,e)
spr(48,d,e)
end
for d=n+8,d-8,8do
for o=e+8,o-8,8do
spr((d+o-n-e)%16==0and 41or 56,d,o)
end
end
palt()
pal()
end
fall_plat={
init=function(_ENV)
while(right()<lvl_pw-1and tile_at(right()/8+1,y/8)==85)hitbox.w+=8
while(bottom()<lvl_ph-1and tile_at(x/8,bottom()/8+1)==85)hitbox.h+=8
collides,solid_obj,timer,shake,state,new=true,true,0,0,0,false
end,
update=function(_ENV)
if timer>0then
timer-=1
if timer==2then
palswap=true
end
if timer==0then
state+=1
spd.y,shake=.4,0
elseif state==0then
shake=1
end
elseif state>=1then
if spd.y==0then
if(not is_solid(0,1))new=false
if not new then
for n=0,hitbox.w-1,8do
init_smoke(n,hitbox.h-2)
end
new,shake=true,3
end
timer=6
end
spd.y=appr(spd.y,4,.4)
end
end,
draw=plat_draw
}
osc_plat={
init=fall_plat.init,
end_init=function(_ENV)
hitbox.w+=8
if not badestate then
timer=1
end
local n,e=targetx-x,targety-y
local d=sqrt(n^2+e^2)
t,shake,palswap,
startx,starty,
dirx,diry=
0,0,not badestate,
x,y,
n/d,e/d
end,
update=function(_ENV)
if timer>0then
timer-=1
palswap,start=timer<=2,timer==0
elseif start then
if state==0then
state=t==0and 1or t==40and 2or 0
else
local n,e,d=1,targetx,targety
if state==2then
n,e,d=-1,startx,starty
end
spd=vector(mid(appr(spd.x,n*5*dirx,abs(.5*dirx)),e-x,x-e),
mid(appr(spd.y,n*5*diry,abs(.5*diry)),d-y,y-d))
if spd.x|spd.y==0then
shake,state=3,0
if is_solid(sign(n*dirx),0)then
for e=0,hitbox.h-1,8do
init_smoke(sign(dirx)==n and hitbox.w-1or-4,e)
end
end
if is_solid(0,sign(n*diry))then
for e=0,hitbox.w-1,8do
init_smoke(e,sign(diry)==n and hitbox.h-1or-4)
end
end
end
end
t+=1t%=80
end
shake=max(shake-1)
end,
draw=plat_draw
}
psfx=function(n)
if sfx_timer<=0then
sfx(n)
end
end
spinner_controller={
spinners={},
connectors={},
layer=0,
init=function()
spinner_controller.spinners,spinner_controller.connectors={},{}
end,
end_init=function()
for e,n in ipairs(spinner_controller.spinners)do
for e=1,e-1do
local e=spinner_controller.spinners[e]
local d,o=abs(n.x-e.x),abs(n.y-e.y)
if d<=16and o<=16and d+o<32then
add(spinner_controller.connectors,vector((n.x+e.x)/2+4,(n.y+e.y)/2+4))
end
end
end
end,
update=function()
local n=find_player()
if n and n.type==player then
for e in all(spinner_controller.spinners)do
if e.objcollide(n,0,0)then
kill_player(find_player())
break
end
end
end
end,
draw=function()
foreach(spinner_controller.connectors,function(n)
spr(28,n.x,n.y)
end)
foreach(spinner_controller.spinners,function(n)
spr(13,n.x,n.y,2,2)
end)
end
}
spinner={
init=function(_ENV)
if sprite%2==0then
x-=8
end
if sprite>=29then
y-=8
end
hitbox=rectangle"2,2,12,12"
add(spinner_controller.spinners,_ENV)
destroy_object(_ENV)
end
}
tiles={}
foreach(split([[
1,player_spawn
8,spring
10,fruit
12,refill
64,kevin
46,bumper
66,feather
27,feather
31,badeline
84,fall_plat
70,osc_plat
13,spinner
14,spinner
29,spinner
30,spinner
]],"\n"),function(n)
local n,e=unpack(split(n))
tiles[n]=_ENV[e]
end)
function init_object(n,e,d,f)
local _ENV=setmetatable({},{__index=_g})
type,collideable,sprite,flip,x,y,hitbox,spd,rem,outline,draw_seed=
n,true,f,vector(),e,d,rectangle"0,0,8,8",vector(0,0),vector(0,0),true,rnd()
function left()return x+hitbox.x end
function right()return left()+hitbox.w-1end
function top()return y+hitbox.y end
function bottom()return top()+hitbox.h-1end
function is_solid(e,d,o)
for n in all(objects)do
if n~=_ENV and(n.solid_obj or n.semisolid_obj and not objcollide(n,e,0)and d>0)and objcollide(n,e,d)and not(o and n.unsafe_ground)then
return true
end
end
return d>0and not is_flag(e,0,3)and is_flag(e,d,3)or
is_flag(e,d,0)
end
function oob(n,e)
return not exit_left and left()+n<0or not exit_right and right()+n>=lvl_pw or top()+e<=-8
end
function is_flag(e,d,n)
for o=mid(0,lvl_w-1,(left()+e)\8),mid(0,lvl_w-1,(right()+e)/8)do
for e=mid(0,lvl_h-1,(top()+d)\8),mid(0,lvl_h-1,(bottom()+d)/8)do
local d=tile_at(o,e)
if n>=0then
if fget(d,n)and(n~=3or e*8>bottom())then
return true
end
end
end
end
end
function objcollide(n,e,d)
return n.collideable and
n.right()>=left()+e and
n.bottom()>=top()+d and
n.left()<=right()+e and
n.top()<=bottom()+d
end
function check(e,d,o)
for n in all(objects)do
if n.type==e and n~=_ENV and objcollide(n,d,o)then
return n
end
end
end
function player_here()
return check(player,0,0)
end
function move(e,d,t)
for n in all{"x","y"}do
rem[n]+=vector(e,d)[n]
local e=round(rem[n])
rem[n]-=e
local f=n=="y"and e<0
local d,o=not player_here()and check(player,0,f and e or-1)
if collides then
local d,i=sign(e),_ENV[n]
local f=n=="x"and d or 0
for e=t,abs(e)do
if is_solid(f,d-f)or oob(f,d-f)then
spd[n],rem[n]=0,0
break
else
_ENV[n]+=d
end
end
o=_ENV[n]-i
else
o=e
if(solid_obj or semisolid_obj)and f and d then
o+=top()-bottom()-1
local n=round(d.spd.y+d.rem.y)
n+=sign(n)
if o<n then
d.spd.y=max(d.spd.y)
else
o=0
end
end
_ENV[n]+=e
end
if(solid_obj or semisolid_obj)and collideable then
collideable=false
local f=player_here()
if f and solid_obj then
f.move(n~="x"and 0or e>0and right()+1-f.left()or e<0and left()-f.right()-1,
n~="y"and 0or e>0and bottom()+1-f.top()or e<0and top()-f.bottom()-1,
1)
if player_here()then
kill_player(f)
end
elseif d then
d.move(vector(o,0)[n],vector(0,o)[n],1)
end
collideable=true
end
end
end
function init_smoke(n,e)
init_object(smoke,x+(n or 0),y+(e or 0),24)
end
add(objects,_ENV);
(type.init or time)(_ENV)
return _ENV
end
function destroy_object(_ENV)
del(objects,_ENV)
end
function kill_player(_ENV)
_g.sfx_timer=12
sfx(17)
_g.deaths+=1
destroy_object(_ENV)
for n=0,.875,.125do
add(dead_particles,{
x=x+4,
y=y+4,
t=2,
dx=sin(n)*3,
dy=cos(n)*3
})
end
foreach(fruitrain,function(n)
if(n.golden)_g.full_restart=true
end)
_g.fruitrain={}
_g.delay_restart=15
_g.tstate=0
end
function next_level()
local n=lvl_id+1
load_level(n)
end
function load_level(n)
has_dashed=false
foreach(objects,destroy_object)
cam_spdx,cam_spdy=0,0
local e=lvl_id~=n
lvl_id=n
local n=split(levels[lvl_id])
lvl_x,lvl_y,lvl_w,lvl_h=n[1]*16,n[2]*16,n[3]*16,n[4]*16
lvl_pw=lvl_w*8
lvl_ph=lvl_h*8
boss_phases=split(n[6],"/")
local n=tonum(n[5])or 1
for e,d in inext,split"exit_top,exit_right,exit_bottom,exit_left"do
_ENV[d]=n&.5<<e~=0
end
ui_timer=5
if e then
if mapdata[lvl_id] then
for i=0,#mapdata[lvl_id]-1 do
  mset(i%lvl_w,i\lvl_w,ord(mapdata[lvl_id][i+1])-1)
end
end
reload()
end
init_object(spinner_controller,0,0)
for e=0,lvl_w-1do
for d=0,lvl_h-1do
local n=tile_at(e,d)
if tiles[n]then
init_object(tiles[n],e*8,d*8,n)
end
if n>=224then
init_object(garbage,e*8,d*8,n-224)
end
end
end
foreach(objects,function(n)
(n.type.end_init or time)(n)
end)
cam_offx,cam_offy=0,0
for n in all(camera_offsets[lvl_id])do
local n,e,d,o,f,t=unpack(split(n))
local n=init_object(camera_trigger,n*8,e*8)
n.hitbox,n.offx,n.offy=rectangle("0,0,"..d*8 ..","..o*8),f,t
end
end
function _update()
frames+=1
if time_ticking then
seconds+=frames\30
minutes+=seconds\60
seconds%=60
end
frames%=30
if music_timer>0then
music_timer-=1
if music_timer<=0then
music(10,0,7)
end
end
if sfx_timer>0then
sfx_timer-=1
end
if delay_restart>0then
cam_spdx,cam_spdy=0,0
delay_restart-=1
if delay_restart==0then
if full_restart then
full_restart=false
_init()
else
load_level(lvl_id)
end
end
end
foreach(objects,function(_ENV)
move(spd.x,spd.y,type==player and 0or 1);
(type.update or time)(_ENV)
draw_seed=rnd()
end)
foreach(objects,function(_ENV)
if type==player or type==player_spawn then
move_camera(_ENV)
return
end
end)
end
function _draw()
pal()
cls'9'
palt(0,false)
sspr(0,64,32,32,0,0,128,128)
draw_x=round(cam_x)-64
draw_y=round(cam_y)-64
camera(draw_x,draw_y)
if anxiety then
cls'0'
--fillp'0b0101101001011010'
--for i=0,127,2 do 
--offset=sin(frames/15+i/150)*3
--for j=-16,256,12 do
--local shrink=(150+(sin(j/4.5+frames/30)*30)-i)/16
--if (shrink<=7.5) line(j+offset+shrink,i,j+offset+16-shrink,i,1)
--line(j+offset+shrink,i,j+offset+15-shrink,i,(i>96 or i>80 and i<90 or i>70 and i<75 or i>64 and i<67 or i>60 and i%2==1) and 1 or 2)
--end end	
--fillp()
--palt(2,true)


end
pal''
palt(2,true)
palt(0,false)
map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)
palt()
if anxiety then
--pa'12,-1,2'
--pa'8,1,2'
end
for n=0,15do pal(n,0)end
pal=time
foreach(objects,function(n)
if n.outline then
for e=-1,1do for d=-1,1do if e==0or d==0then
camera(draw_x+e,draw_y+d)draw_object(n)
end end end
end
end)
pal=_pal
camera(draw_x,draw_y)
pal()
palt()
anxiety=false
local e={{},{},{}}
foreach(objects,function(n)
if n.type.layer==0then
draw_object(n)
else
add(e[n.type.layer or 1],n)
end
end)
pal''
palt(0,false)
palt(2,true)
map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
palt()
foreach(e,function(n)
foreach(n,function(_ENV)
draw_object(_ENV)
if bubble and bubbled then
--oval(left()-4,top()-4,right()+4,bottom()+4,7)
circ(x+4,y+3,8,7) -- 9 tokens smaller, looks off though.
end
end)
end)
for n=0,lvl_w do
for e=0,lvl_h do
if grass[tile_at(n,e)]and not grass[tile_at(n,e-1)]and not not_grass[tile_at(n,e-1)]then
spr(60,n*8,(e-1)*8)
end
end
end
map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,8)
foreach(dead_particles,function(n)
n.x+=n.dx
n.y+=n.dy
n.t-=.2
if n.t<=0then
del(dead_particles,n)
end
rectfill(n.x-n.t,n.y-n.t,n.x+n.t,n.y+n.t,14+5*n.t%2)
end)
if ui_timer>=-30then
if ui_timer<0then
end
ui_timer-=1
end
camera()
color(0)
if tstate==0then
tlo+=14
thi=tlo-320
po1tri(0,tlo,128,tlo,64,80+tlo)
rectfill(0,thi,128,tlo)
po1tri(0,thi-64,0,thi,64,thi)
po1tri(128,thi-64,128,thi,64,thi)
if(tlo>474)tstate=-1tlo=-64
end
--p"9,137"
p"14,131"
p"13,139"
p"15,14"
p"0,129"
p"6,140"
p"5,15"
end
function p(n)
n=split(n)
pal(n[1],n[2],1)
end
function draw_object(_ENV)
srand(draw_seed);
(type.draw or draw_obj_sprite)(_ENV)
end
function draw_obj_sprite(_ENV)
spr(sprite,x,y,1,1,flip.x,flip.y)
end
function two_digit_str(n)
return n<10and"0"..n or n
end
function round(n)
return flr(n+.5)
end
function appr(n,e,d)
return n>e and max(n-d,e)or min(n+d,e)
end
function sign(n)
return n~=0and sgn(n)or 0
end
function maybe()
return rnd()<.5
end
function tile_at(n,e)
return mget(lvl_x+n,lvl_y+e)
end
tstate,tlo=-1,-64
function po1tri(n,e,f,d,o,t)
local i=n+(o-n)/(t-e)*(d-e)
p01traph(n,n,f,i,e,d)
p01traph(f,i,o,o,d,t)
end
function p01traph(n,e,d,o,f,t)
d,o=(d-n)/(t-f),(o-e)/(t-f)
for f=f,t do
rectfill(n,f,e,f)
n+=d
e+=o
end
end
--function pa(a)
--local t,q,l=unpack(split(a))
--for i=1,15 do pal(i,t) end
--if l<0 then
--camera(draw_x+q,draw_y)
--else
--map(lvl_x,lvl_y,q,0,lvl_w,lvl_h,l)
--end
--end
-->8
--[map metadata]
--@conf
--[[
param_names={"phase/phase/phase/..."}
composite_shapes={}
autotiles={{33, 35, 34, 32, 33, 35, 34, 32, 49, 51, 50, 48, 32, 48, 40, 41, [0] = 34, [28] = 57, [40] = 56}, {37, 39, 38, 36, 37, 39, 38, 36, 53, 55, 54, 52, 36, 52, 59, 42, [0] = 38, [28] = 58, [40] = 43}, {118, 102, 112, 96, 81, 83, 82, 96, 113, 115, 114, 112, 97, 99, 98, 37, 38, 39, 36, 87, 144, 145, 90, 91, 92, 93, 78, 53, 54, 55, 52, 103, 104, 105, 106, 107, 108, 109, 128, 32, 33, 34, 35, 119, 120, 121, 122, 123, 94, 95, 129, 48, 49, 50, 51, 116, 117, 100, 101, 146, 110, 111, 130, [0] = 98}}
]]
--@begin

--level table
--"x,y,w,h,exit_dirs,phase/phase/phase/..."
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
--phase 1 (ball) or 2 (laser)

levels={
  "0,0,2,1,0b0001,0",
  "2,0,1,1,0b0001,0",
  "3,0,1,2,0b1000,0",
  "4,0,2,1,0b0011,0",
  "6,0,1,1,0b0001,0"
}
--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
  {},
  {},
  {},
  {},
  {}
}
--</camtrigger>--

--mapdata string table
--assigned levels will load from here instead of the map
mapdata={}

--@end

function move_camera(obj)
  --<camtrigger>--
  cam_spdx,cam_spdy=cam_gain*(4+obj.x-cam_x+cam_offx),cam_gain*(4+obj.y-cam_y+cam_offy)
  --</camtrigger>--

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  --clamp camera to level boundaries
  local clamped=mid(cam_x,64,lvl_pw-64)
  if cam_x~=clamped then
    cam_spdx,cam_x=0,clamped
  end
  clamped=mid(cam_y,64,lvl_ph-64)
  if cam_y~=clamped then
    cam_spdy,cam_y=0,clamped
  end
end

--tiles to draw grass on
grass={}
foreach(split'36,37,38,39,52,53,54,55',function(t)
grass[t]=true
end)

not_grass={}
foreach(split'21,22,23,42,43,58,59',function(t)
not_grass[t]=true
end)

--replace mapdata with hex
--function replace_mapdata(x,y,w,h,data)
--  for y_=0,h*2-1,2 do
--    local offset=y*2+y_<64 and 8192 or 0
--    for x_=1,w*2,2 do
--      local i=x_+y_*w
--      poke(offset+x+y*128+y_*64+x_/2,"0x"..sub(data,i,i+1))
--    end
--  end
--end

-- ill figure something out once i actually have all the levels
-- thinking ill just convert them somewhere else. could use that lua script i wrote like a million years ago
--  -anti

--copy mapdata string to clipboard
--function get_mapdata(x,y,w,h)
--  local reserve=""
--  for y_=0,h*2-1,2 do
--    local offset=y*2+y_<64 and 8192 or 0
--    for x_=1,w*2,2 do
--      reserve=reserve..num2hex(peek(offset+x+y*128+y_*64+x_/2))
--    end
--  end
--  printh(reserve,"@clip")
--end
--
----convert mapdata to memory data
--function num2hex(v)
--  return sub(tostr(v,true),5,6)
--end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000000000ee15513e0a0aa0a0000770000007700000000007007000000aa00000
000000000888888008888880888888880888888008888800000000000888888000000000e15005ee0aa88aa000700700007bb70000000000ff000070aa000000
00000000888888888888888888855558888888888888888008888880885155180000000013500511029999200700007007bbb3707000f0027f20070000000000
0000000088855558888555588851551888855558855558808888888888555558024444203155555309a99990700000077bbb3bb7070007ff2ff2ff0000000000
000000008851551888515518085555508851551881551580888555588855555800e00e005005551509999a907000000773b33bb70fff2ff2f22ff00000000000
0000000008555550085555500033330008555550055555808855555808333380000ee000e0055005099a99900700007007333370002222ff22f2f70000000000
000000000033330000333300070000700733330000333370085155100033330000e00e00e555500e0299992000700700007337000002222ff2ff200000000000
0000000000700700007000700000000000000700000070000773337000700700000ee000e115111100299200000770000007700000ff2ff22222f22000000000
00000000eeeeee1349994999499949994999499911311311111bbb111331331100000000000000007000000000777700022f22f077f2f22f22f227f000000000
00000000ee1ee13e44444444444444444444444413313331331bb3313133b3310077000007700700070000070700aa70fff22f2f020f22f2ff2ffff702222220
00000000e13ee3ee0004e00000000000000e40001b33b331b331b33333133bb1007770700777000000000000700aaa072fff2ff20000f272f272200022222222
0000000013eeeeee004e0000000000000000e40033b33bb11b311b333331311307777770077000000000000070959007f2f22222000ff72f2f27700025555222
000061003eee61ee04e000000000000000000e4031bb313333b111b313311b13077777700000700000000000705900072222222f002ff02ff22ff20028558522
00cc6610eecc661e4e00000000000000000000e4b11b1333333133111b133bb107777770000007700000000070500007f22222ff0072000f0000f70005555520
0cc66660ecc6666ee0000000000000000000000e1bb3b33bb33133311bb333bb070777000007077007000070070e0070f2222f2f070000007000007000111110
cc666661cc6666610000000000000000000000001b133bb11b11b33311bb3331000000007000000000000000007777000ff2fff0000000002000000000050005
7cc1c1005771777777cc1777777717755133311115555b5555b55b55555b555111000000000006603313311111333111ee11eeeee33d111e0000000011100111
77cc1c10777c177cc771cc77c771c7775bb331bb5bbb33111bb1bbb11bbb331511100000006600663313311113331331e1e311ee1ed3dd110000011100000000
777cc1c177ccc1cccccc1ccccc11cc77bbb31bb3511bb31113bb3bb111bbb31501100110006cc00611111331333133311e3d3e11e1ee3de1000016ec01100110
177ccc1c77cccc1ccccc1ccccccc1cc75b311b315b1133b1bb3bb331b1133b1500000110000ccc00133113333311331113d33ebeee11ebe10001ceec00e99e00
7c1cccc11cccccc11cccc11c1cccc1c7531113bb5bb1133bb133b11bbb1133b5001100000000ccc013331133111111131edd3ed1e3e11e1e001ccc11099ee990
77c1ccc071ccccc111ccc11111cccc1751bb1bbb51111bb131131b1b1111bb1500111000cc000c661133111333313313113eebd1ee3e11ed016ec1440e1111e0
777c11007711ccc101111000011cccc15bbb1bb3533311bb133b3bb133311bb500011100cc6000663111333113333311e111ddb1eee1eedb01ee14c400e99e00
177c1000ccc11111001100000011ccccbbb311315b33b11b131bb311b33b11b50000110006600000331113311113311113311bd1ee1edbbe01cc14c200099000
0ccc17711111cccc0ccccccc1cccccc111133315bb3bb1b11bb1bb111113331500066000000c0000331113333311111100000000e11eeeee01cc144411000011
01ccc1717ccc1cccccccccccc1cccc71bb133bb55bb3b1bbb1bb3bb1bb133bb500066c0000cc60003311133113111ee100000000e1edddbe01ee124c01100110
111c77107cccc1ccccc1cccccc1ccc713bb13bbb5bb1313bbb1bb3313bb13bbb66006cc000066c001133111111133eee000000001eebdbe1016ec1240c0000c0
1cc1777117cccc1ccccc1cccccc1ccc713b113b5b33b1b13bbb1b11b13b113b56cc006c66600cc6033333111111133ee000000b0111eebe1001ccc110cc99cc0
cccc1771717ccc1c1cccc1ccccc71c77bb31113b51333bb11bb1131bbb31113b0ccc00666cc006603313331111111311b00b00b0ee111e1e0001ceec09eeee90
ccccc1117717cc11c1c7c711ccc77171bbb1bb15531133bb131b3331bbb1bb1500cc60000ccc00001111331111111ee1b0b003b0e3ee111e000016ec0e4114e0
1cccc71017c1cc1c771777cc1ccc77113bb1bbb553b13333133bb3333bb1bbb566066000c0cc60001331113311311eeeb3b03b30eed3e11e000001110e1111e0
01cc7771e111111171117cc10111111e13113bbb555155515155551115555555066000000c06600013331113113311eeb3bb3b3be13d1ee10000000000eeee00
0992cc6446cccc6400aaa0000099aa0000999aa0000aaa0057777777eeeeeeeeee1ee111111eee1eeeeeeeee1eeeeeeeeeeeeee1eeeeeeeeeeee0000eeee13ee
9246cc2442cccc2409aaa900099aaaa0099aaaaa00aaaaa078807277eee1111ee1e111dd331111eeeee1eee13eee11eeeeeeee13eeee1eeeeee000000ee13eee
942ecc22221ee12201aaa1009911aaaa99eaaa11009aea907870222cee111d1e1111d3bdd33111eeee13ee13111111eeeeeee13eee111eeeee000ee11e13eeee
26e6ee11111111110111110091110aa09eaa0001009aea907000c2c2e11ddd1e11dddd3bd333111ee13ee11113dd11e1eeee13eeee111eeeee0001eeee3eee1e
cccec1222222222201111100911000009ea000000099e99077ccc2cc1ddbd31e1dddddd3b311111113ee113dddd31113ee1e3eeee0001ee1ee18011110eee13e
ccce11244444444401111100110000009ea000000099e99077c2c2c21bd3331e1ddddddd311111113ee11dddddb3113eee11eee1e0001e13eee80011001ee3ee
6221224444444444001110001000000009e000000009e90077cc222c1333111e11ddddb311111111eee13ddddb3111eee111ee131100013eee08800000111eee
4421244444444444000010001000000000e00000000e000077ccc2cc11111eeee1ddb13d11110001eee1dddd333111eee1100e31100113e0ee8888ee000111ee
44212444222ddd23ddd33dd3dd22ddd257777777777777772223d222eee1eeeee11d131d3110001eee11ddb3333111eeee10031000011000ee8888e08ee0111e
6221244422ddddd1dd11ddddddd11ddd78807877700877772233ddd2ee13eeeeee113ddd111111eee111db33333111eeee00880880010001e10080e888e8001e
cc11244421dd31131dd11dd1dddd31d37870c8ccc0c8cccc2ddeddd2e13eee1eeee1bddd110001ee131d3333331111eeee0084a48000011113e001e080e8800e
cce124443313113331313311d11133137000c8ccc888ccccdddee333e3eee13eeee11ddd11001eee3e1b333311311ee1e0084a900000011e3ee001ee0ee8011e
cce124441dd331eee3133e33e3131dd377ccc8ccccccccccdd33ee33eeee133eee1e1bdd1101eeeeee1111111dd11e13e10880480000111eee0010110e00011e
cc112444ddd31eeeee3eee3eeee1ddd377c8c8c8cccccccc233eeeddeee133eee13e11bd1111ee1eee1133311111113ee1000088000111eee0010111110001e1
62212444dddd1eeeeeeeeeeeeee11dd277cc888cccccccccddeee3ddeee13eee13eee11b1111e13ee1311d33111113eeee10000000111eee0110010110011e13
442124443ddd3eeeeeeeeeeeeeee1d3277ccc8ccccccccccddde3dddeeeeeeee3eeeee11111e13eee3ee11d331111eeeee1100001111eeee100000000011ee3e
ddd3eddd2133e3eeeeeeeeeeee31ddd2eeeeee1eeeeeee1e22dd3322ee1ee13eeeeeeeeeeeeeeeeeeeeee1d313111ee1eeeee13eeeeeeeeeeeeeeee13eee13ee
dd3eeedd1dd113eeeeeeeeeeee3e1dd3ee1ee13eeee1e13eddde3dd3e13e13eeeee1111111eeee1eeeee11113d111e13eeee13eeeeeee1eeeeeeee13eee13eee
ddeee332ddd333eeeeeeeeeeeee31ddde13e13eeee1313eeddd33ddd13e13ee1ee111ddd11eee13eeee13e13d111113eee1100eeeeee13eeeeeee13eeee3eee1
33ee33dddd13e3eeeeeeeeeeeee131dd13ee3eeee13e3ee33eeeedd23ee3ee13e131dddd11ee13eeee13ee11d11113eee111100eeee13eee888803eeeeeeee13
333eeddd211d3eeeeeeeeeeeeee331dd3ee1eeee33eeee1eede3e332ee1ee13e1311dddd11ee3e1ee13eee11111113eeeee0000eee13e888888000eeeeeee13e
2dddedd22ddd1eeeeeeeeeeeeee1e312ee13e3d1d33ee13edddedd33e13e13ee311ddddd111ee13e13eee13e11113eeeeeeee00ee13e000888808888eeee13ee
2ddd3322dddd1eeeeeeeeeeeeee31dd2e13ee3dd1dde13eedd3dddd3e3ee3eeee1ddddb1b11e13ee3eee13eee113eeeeee111011e3ee880088a908888ee13eee
222d32223dd13eeeeeeeeeeeee31ddd2e3ee3d111d1e3eee3322d322eeeeeeeee1dddb1331111eeeeeee3eeeee3eeeee11110011eeee8880a99a90888e13eeee
eeeeeeee23d1eeeeeeeeeeeeeee3ddd3ee1edd1333dd1eee223d2233eeeeeeeee1ddd1333d3d1eee2222288213eee88e111000011ee8888099440000883eeeee
eeeeeeee2dd11eeeeeeeeeeeeee1dddde13e1d13111d3eee3dddd3ddee133eeee11d1b33d3d11eee2881888838818888000000011ee888800000088000eeeee1
eeeeeeee3ddd1eeeee1eee13eee13ddde3eedd1dddd3ee1e33ddeddde1333ee1ee11b333d11d1eee888991128889911e0000000000eee800088808880eeeee13
eeeeeeee3dd1313ee3313133ee133dd1ee1e33dddd13e13e233e3ede1333ee13ee11333d13d11ee1889aa882889aa883000ee0000011001088880088eeeee13e
eeeeeeee3133111d3113313e33113133e13eee31e13e13ee2ddeeee3133ee13eee1133d1d111ee1321aa9888e1aa98880eeee13e0000000008888e13eeee13ee
eeeeeeee3d13dddd3ddd13d13113dd1213eee13313e13e1eddd33dddeeee13eee1e11d1111eee13e28881880188818800eee13eeeee00e0eeeeee13eeee13eee
eeeeeeeeddd11ddd1dddd1dd1ddddd223eee13ee3ee3e13e3dd3edddeeee3eee13ee111eeeee13ee288810023888100eeee13eeeeee13e00000e13eeee13eeee
eeeeeeee2ddd22dddddd2ddd32ddd222eeeeeeeeeeee13ee2233dd22eeeeeeee3eeeeeeeeeee3eee22810022ee8100eeeee3eeeeeee3eee000ee3eeeee3eeeee
9999999999999999999999999999999921122222e1013e13222e2222222222222222222222222222220000112222222222222222110000222222222222222222
99999999999999999999999999999999210222221013e13e22ede222221222222222222222222221100000011222222222222221100000011222222222222222
9999999999999999999999999999999921882222318813ee22ede12221e122222222222222222110000000001112222222222111000000000112222222222222
9999999999999999999999999999999921888008e18880082ed3ee121ede12222222222222211100000222200112222222222110022220000011122222222222
999999999999999999999999999999992108aa88e018aa882e3e3ee11ebbe2222222222222111000022222222011222222221102222222200001112222222222
999999999999999999999999999999992100aa001100aa002e33ede1eddd3e222222222221110000222222222201122222211022222222220000111222222222
9999999999999999999999999999999920880888308808882e3e3ddeeedbbbe2dd222222211000022221110222011222222110222011122220000112222222dd
9999999999999999999999999999999928880882e888088e2ede3eee11ee3de2ddd1122211000022221110022200122222210022200111222200001122211ddd
9999999999999999999999999999999922802222ee8103ee2ed3ee111e11ee12d1dd33300000022222110022000112222221100022001122222000000333dd1d
9999999999999999999999999999999922102822e11038ee2eee111ee3e11e22d1113d0000002222221000000001222222221000000001222222000000d3111d
999999999999999999999999999999992221888213e1888e2e111eedd33e11221e3e1e1100022222222000000012222222222100000002222222200011e1e3e1
99999999999999999999999999999999288088823880888e211eeed3bdbbe12231e1e111000222222222000000222222222222000000222222222000111e1e13
999999999999999999999999999999998889a0028889a00e1eedd33dddbdde12e11111100022222222222022022222222222222022022222222222000111111e
99999999999999999999999999999999288a9882e88a988111ed3333ddd3bbe21111110000222222222220220222222222222220220222222222220000111111
9999999999999999999999999999999920998882e09988832111e3333d3deee21111100102222222222200120222222222222220210022222222222010011111
99999999999999999999999999999999888088228880883e11eeee3ee11111221110000112222222222211d102222222222222201d1122222222222110000111
9999999999999999999999999999999921002222e100eee111eeee3ee111112211000002100e01102200dddd1222222222222221dddd0022e33d111e20000011
9999999999999999999999999999999922110022ee1000132111e3333d3deee20000002210e0110020111dd331222222222222133dd111021ed3dd1122000000
9999999999999999999999999999999922221022e13e103e11ed3333ddd3bbe20000d32211e11e1e20011133312222222222221333111002e1ee3de1223d0000
999999999999999999999999999999992222210213e1e00e1eedd33dddbdde1200ddd22211e1e2e020000113311222222222211331100002ee11ebe1222ddd00
99999999999999999999999999999999222220023e13e101211eeed3bdbbe122311ed2221e1112e221dd000000122222222221000000dd12e3e11e1e222de113
9999999999999999999999999999999922211012e13110032e111eedd33e11223e1dd322e22112e2221d330000002222222200000033d1222e3e11ed223dd1e3
9999999999999999999999999999999922110022e311003e2eee111ee3e11e22e31ddd22e22212e2222133300002222222222000033312222ee1eedb22ddd13e
9999999999999999999999999999999920112222e00003ee2ed3ee111e11ee12e131dd2202221202222213131002222222222001313122222e1edbbe22dd131e
99999999999999999999999999999999e0010eeeee13eee12ede3eee11ee3de2e331dd222222022222222131102222222222220113122222211eeeee22dd133e
99999999999999999999999999999999ee0010eee13eee132e3e3ddeeedbbbe2e1e313222222122222222212222222222222222221222222e1edddbe22313e1e
99999999999999999999999999999999eeee100ee311113e2e33ede1eddd3e22e31dd22222221222222222222222222222222222222222220eebdbe1222dd13e
999999999999999999999999999999991eee000ee171711e2e3e3ee11ebbe22231ddd2222222122222222222222222222222222222222222111eebe1222ddd13
999999999999999999999999999999993e1000eee199111e2ed3ee121ede12223d2222222222122222222222222222222222222222222222ee111e12222222d3
999999999999999999999999999999991d013dd31177711122ede12221e12222ddd222222222222222222222222222222222222222222222e3ee111222222ddd
99999999999999999999999999999999d013d1d11977911122ede22222122222d222222222222222222222222222222222222222222222222ed3e11e2222222d
99999999999999999999999999999999d0033d1de966911e222e222222222222222222222222222222222222222222222222222222222222e13d1ee122222222
22111111111111e22e11111111111222ee111111111111eeee11111111111eee111eeb112222222222222222d1d13eeee31eeeeeeee13eeeeeeeee1eeeeeeee1
22eee1111dbbe112e33e33eeeeeee222eeeee1111dbbe11ee33e33eeeeeeeeeeee111db1222222222222222d1ddd11eeee31eeeeee13eeee0000013eee118813
2e33e3ddeddbbde22e333333dddde222ee33e3ddeddbbdeeee333333ddddeeeeed3eedde2222222222222222d1dd1eeeee0011eee13eeee0000000888118888e
e3e333de1ddddde22ee3e3ddddbde222e3e333de1dddddeeeee3e3ddddbdeeeee3ed3ede2222222222208888dd1d1eeee001111e13eee1e00ee000e88844881e
ee33d33e3ddbdde222111eeeebbdde22ee33d33e3ddbddeeee111eeeebbddeee1e3deebe2222222222000888888e31eee0000eee3eee13e0ee1e00004a994111
e33dd3e1ebbddde222ee11111eeebe22e33dd3e1ebbdddeeeeee11111eeebeee0edeeee122222222888808888000e31ee00eeeeeeee13eeee13e110088a888ee
e3bdee111ebdddde22edeeee1111ee22e3bdee111ebddddeeeedeeee1111eeee01ee11e02222222888809a880088ee3e110111eeeee0008813ee11088884888e
edee11ee11edbdde22edde33eeee1122edee11ee11edbddeeeedde33eeee11ee00e100e0222222288809a99a0888eeee11001111e0ee088880ee1100880eeee1
ee11ee3ee11ebbbe2e333333dbddeee2ee11ee3ee11ebbbeee333333dbddeeee00e100e0222222880000449908888ee110000111008849940001110000e01113
11ee333dbde1ebbe2e33d33dbeeee11211ee333dbde1ebbeee33d33dbeeee11e01ee11e0222222000880000008888ee110000000088889a88001100000011111
e333d111edbe1eee2eeddd3ee1111122e333d111edbe1eeeeeeddd3ee11111ee0edeeee12222222088808880008eee00000000000884aa8888000000001111ee
1111ee1111bbe11e2eeddee11e11ee221111ee1111bbe11eeeeddee11e11eeee1e3deebe222222228800888801001100000ee00000088848800000000011eee1
22ee33eee11edde22e3de11eede11ee2eeee33eee11eddeeee3de11eede11eee13dd3ede222222222228888000000000e31eeee010088800010000000111ee13
e13e333dbee11beee33e11e3ddbe11e2e13e333dbee11beee33e11e3ddbe11ee113eebde222222222222222dd0d00eeeee31eee01100800111110000111ee13e
133dd3dbbddeee112ee113e3beeee112133dd3dbbddeee11eee113e3beeee11ee111ddbe222222222222200000d3333eeee31eee1110000011100011111e13ee
1eeee1111eee1112222eeeeee11111121eeee1111eee111eeeeeeeeee111111eeee11bde22222222222222000d1dd3eeeeee3eeee11110000000011111ee3eee
00888800000008000088880000888800008008000088880000800000008888000088880000888800008888000088880000888800008880000088880000888800
00800800000008000000080000000800008008000080000000800000000008000080080000800800008008000080080000800000008008000080000000800000
00800800000008000000080000000800008008000080000000800000000008000080080000800800008008000080080000800000008008000080000000800000
00800800000008000088880000888800008888000088880000888800000008000088880000888800008888000088800000800000008008000088880000888800
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00888800000008000088880000888800000008000088880000888800000008000088880000000800008008000088880000888800008880000088880000800000
00cccc0000000c0000cccc0000cccc0000c00c0000cccc0000c0000000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000ccc00000cccc0000cccc00
00c00c0000000c0000000c0000000c0000c00c0000c0000000c0000000000c0000c00c0000c00c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000000c0000000c0000c00c0000c0000000c0000000000c0000c00c0000c00c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000cccc0000cccc0000cccc0000cccc0000cccc0000000c0000cccc0000cccc0000cccc0000ccc00000c0000000c00c0000cccc0000cccc00
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00cccc0000000c0000cccc0000cccc0000000c0000cccc0000cccc0000000c0000cccc0000000c0000c00c0000cccc0000cccc0000ccc00000cccc0000c00000
__label__
11hhhhhhbb3bb1b133111111331111111113331fjjjjjj1jjjjjjj1jjjjjjjjj1111cccchhhhhssh11hhhhhh11hhhhhh11hhhhhhf13331113311111133111111
111hhhhhfbb3b1bb13111jj113111jj1bb133bbfjjj1j13jjj1jj13jjjjjjjjj7ccc1ccchhsshhss111hhhhh111hhhhh111hhhhhfbb331bb13111jj113111jj1
h11hh11hfbb1313b11133jjj11133jjj3bb13bbbjj1313jjj13j13jjjj1jjj1h7cccc1cchhscchhsh11hh11hh11hh11hh11hh11hbbb31bb311133jjj11133jjj
hhhhh11hb33b1b13111133jj111133jj13b113bfj13j3jj313jj3jjjj331313317cccc1chhhccchhhhhhh11hhhhhh11hhhhhh1bhfb311b31111133jj111133jj
hh11hhhhf1333bb11111131111111311bb31113b33jjjj1j3jj1jjjj3113313j717ccc1chhhhccchhh11hhhhhh11hhhhbh1bhhbhf31113bb1111131111111311
hh111hhhf31133bb11111jj111111jj1bbb1bb1fr33jj13jjj13j3r13rrr13r17717cc11cchhhcsshh111hhhhh111hhhbhb113bhf1bb1bbb11111jj111111jj1
hhh111hhf3b1333311311jjj11311jjj3bb1bbbf1rrj13jjj13jj3rr1rrrr1rr17c1cc1cccshhhsshhh111hhhhh111hhb3b13b3hfbbb1bb311311jjj11311jjj
hhhh11hhfff1fff1113311jj113311jj1fffffff1r1j3jjjj3jj3r11rrrr9rrrj1111111hsshhhhhhhhh11hhhhhh11hhb3bb3b3bbbb31131113311jj113311jj
11hhhhhh11hhhhhhbb3bb1b11113331f22e227eh93r1jjjjjj31rrr99999999h77e2e22e7cc1c1hh11hhhhhhhhhsshhh1ffffbff331111111bb1bb111bb1bb11
111hhhhh111hhhhhfbb3b1bbbb133bbfee2eeee7hrr11jjjjj3j1rr399999999h2he22e277cc1c1h111hhhhhhhhsschhfbbb331113111jj1b1bb3bb1b1bb3bb1
h11hh11hh11hh11hfbb1313b3bb13bbbe2722hhh3rrr1jjjjjj31rrr999999999h9he272777cc1c1h11hh11hsshhscchf11bb31111133jjjbb1bb331bb1bb331
hhhhh11hhhhhh11hb33b1b1313b113bf2e277h993rr1313jjjj131rr9999999999hee72e177ccc1chhhhh11hscchhscsfb1133b1111133jjbbb1b11bbbb1b11b
hh11hhhhhh11hhhhf1333bb1bb31113be22ee2h93133111rjjj331rr999999999h2ee22e7c1cccc1hh11hhhhhccchhssfbb1133b111113111bb1131b1bb1131b
hh111hhhhh111hhhf31133bbbbb1bb1f2e2ee7h93r13rrrrjjj1j319999999999h72eeee77c1ccchhh111hhhhhccshhhf1111bb111111jj1131b3331131b3331
hhh111hhhhh111hhf3b133333bb1bbbf7ee2hh7hrrr11rrrjjj31rr999999999h7hh2eee777c11hhhhh111hhsshsshhhf33311bb11311jjj133bb333133bb333
hhhh11hhhhhh11hhfff1fff11fffffff2222h9h99rrr99rrjj31rrr9999999999h9he2e2177c1hhhhhhh11hhhsshhhhhfb33b11b113311jjf1ffff11f1ffff11
11hhhhhh11hhhhhhhhhhhsshhccc1771227eh9h999999999rrr3jrrr99999999999h22277cc1c1hhhhhhhsshhcccccccbb3bb1b11113331fjjjjjjjjjj1jj13j
111hhhhh111hhhhhhhsshhssh1ccc171eeeehh7h99999999rr3jjjrr99999999h99he22277cc1c1hhhsshhssccccccccfbb3b1bbbb133bbfjj133jjjj13j13jj
h11hh11hh11hh11hhhscchhs111c771h7e2eh7h999999999rrjjj3399999999h7h9he222777cc1c1hhscchhsccc1ccccfbb1313b3bb13bbbj1333jj113j13jj1
hhhhh11hhhhhh11hhhhccchh1cc177712ee2eeh99999999933jj33rr99999999h7hhh7ee177ccc1chhhccchhcccc1cccb33b1b1313b113bf1333jj133jj3jj13
hh11hhhhhh11hhhhhhhhccchcccc1771e22eeh9999999999333jjrrr99999999heee2ee27c1cccc1hhhhccch1cccc1ccf1333bb1bb31113b133jj13jjj1jj13j
hh111hhhhh111hhhcchhhcssccccc11122e2e7h9999999999rrrjrr9999999999h2222ee77c1ccchcchhhcssc1c7c711f31133bbbbb1bb1fjjjj13jjj13j13jj
hhh111hhhhh111hhccshhhss1cccc71he2ee2hh9999999999rrr33999999999999h2222e777c11hhccshhhss771777ccf3b133333bb1bbbfjjjj3jjjj3jj3jjj
hhhh11hhhhhh11hhhsshhhhhh1cc77712222e22h99999999999r399999999999hhee2ee2177c1hhhhsshhhhh71117cc1fff1fff11fffffffjjjjjjjjjjjjjjjj
11hhhhhh11hhhhhhhhhsshhhhccc1771227227eh99999999999999999999999h77e2e22e1111cccc1cccccc1jj11jj3jj11jbbbj93r1jjjjjjjjjjjjjjjjjj1j
111hhhhh111hhhhhhhhsschhh1ccc171ee2eee77h99999999999999999999999h2he22e27ccc1cccc1cccc7111jj333rbrj1jbbj9rr11jjjjjjjjjjjjjj1j13j
h11hh11hh11hh11hsshhscch111c771h7e2227hh9999999999999999999999999h9he2727cccc1cccc1ccc71j333r111jrbj1jjj3rrr1jjjjj1jjj13jj1313jj
hhhhh1bhhhhhh1bhscchhsbs1cc177712ee2eeh999999999999999999999999999hee72e17cccc1cccc1ccc71111jj1111bbj11j3rr1313jj3313133j13j3jj3
bh1bhhbhbh1bhhbhbccbhhbscccc1771e22ee2h99999999999999999999999999h2eeh2e717ccc1cccc71c77jjjj33jjj11jrrjj3133111r3113313j33jjjj1j
bhb113bhbhb113bhbhbcs3bhccccc11122e2e7h99999999999999999999999999h72h9he7717cc11ccc77171j13j333rbjj11bjj3r13rrrr3rrr13r1r33jj13j
b3b13b3hb3b13b3hb3bs3b3h1cccc71he2ee2h7h999999999999999999999999h7hh999h17c1cc1c1ccc7711133rr3rbbrrjjj11rrr11rrr1rrrr1rr1rrj13jj
b3bb3b3bb3bb3b3bb3bb3b3bh1cc77712222e22h9999999999999999999999999h99999hj1111111h111111j1jjjj1111jjj111j9rrr99rrrrrr9rrr1r1j3jjj
ffbffbffffbffbfffffbfff11cccccc122e227eh99999999999999999999999999999999h9999999999999999j1111111111199999999999999999999133j3jj
1bb1bbb11bb1bbb11bbb331fc1cccc71ee2eeee7h99999999999999999999999999999999999999999999999j33j33jjjjjjj99999999999999999991rr113jj
13bb3bb113bb3bb111bbb31fcc1ccc71e2722hhh9999999999999999999999999999999999999999999999999j333333rrrrj9999999999999999999rrr333jj
bb3bb331bb3bb331b1133b1fccc1ccc72e277h999999999999999999999999999999999999999999999999999jj3j3rrrrbrj9999999999999999999rr13j3jj
b133b11bb133b11bbb1133bfccc71c77e22ee2h999999999999999999999999999999999999999999999999999111jjjjbbrrj999999999999999999911r3jjj
31131b1b31131b1b1111bb1fccc77171hhhhe7h999999999999999999999999999999999999999999999999999jj11111jjjbj9999999999999999999rrr1jjj
133b3bb1133b3bb133311bbf1ccc77117h99hh7h99999999999999999999999999999999999999999999999999jrjjjj1111jj999999999999999999rrrr1jjj
131bb311131bb311b33b11bfh111111j2h9999h999999999999999999999999999999999999999999999999999jrrj33jjjj119999999999999999993rr13jjj
1bb1bb11331111111113331fjj31rrr9h9999999999999999999999999999999999999999993r999999999999j333333rbrrjjj999999999999999999133j3jj
b1bb3bb113111jj1bb133bbfjj3j1rr399999999999999999999999999999999999999999933rrr9999999999j33r33rbjjjj11999999999999999991rr113jj
bb1bb33111133jjj3bb13bbbjjj31rrr99999999999999999999999999999999999999999rrjrrr9999999999jjrrr3jj11111999999999999999999rrr333jj
bbb1b11b111133jj13b113bfjjj131rr9999999999999999999999999999999999999999rrrjj333999999999jjrrjj11j11jj999999999999999999rr13j3jj
1bb1131b11111311bb31113bjjj331rr9999999999999999999999999999999999999999rr33jj33999999999j3rj11jjrj11jj99999999999999999911r3jjj
131b333111111jj1bbb1bb1fjjj1j3199999999999999999999999999999999999999999933jjjrr99999999j33j11j3rrbj11j999999999999999999rrr1jjj
133bb33311311jjj3bb1bbbfjjj31rr99999999999999999999999999999999999999999rrjjj3rr999999999jj113j3bjjjj1199999999999999999rrrr1jjj
f1ffff11113311jj13113bbbjj31rrr99999999999999999999999999999999999999999rrrj3rrr99999999999jjjjjj111111999999999999999993rr13jjj
11hhhhhhf13331111113331fjj1jrr13rrr33rr3rr99rrr99999999999999999999rrr93jj31rrr9999999999jrj3jjj11jj3rj9999999999999999993r1jjjj
111hhhhhfbb331bbbb133bbfj13j1r13rr11rrrrrrr11rrr999999999999999999rrrrr1jj3j1rr3999999999j3j3rrjjjrbbbj999999999999999999rr11jjj
h11hh11hbbb31bb33bb13bbbj3jjrr1r1rr11rr1rrrr31r3999999999999999991rr3113jjj31rrr999999999j33jrj1jrrr3j9999999999999999993rrr1jjj
hhhhh11hfb311b3113b113bfjj1j33rr31313311r1113313999999999999999933131133jjj131rr999999999j3j3jj11jbbj99999999999999999993rr1313j
hh11hhhhf31113bbbb31113bj13jjj31j3133j33j3131rr399999999999999991rr331jjjjj331rr999999999jr3jj191jrj199999999999999999993133111r
hh111hhhf1bb1bbbbbb1bb1f13jjj133jj3jjj3jjjj1rrr39999999999999999rrr31jjjjjj1j3199999999999jrj19991j1999999999999999999993r13rrrr
hhh111hhfbbb1bb33bb1bbbf3jjj13jjjjjjjjjjjjj11rr99999999999999999rrrr1jjjjjj31rr99999999999jrj999991999999999999999999999rrr11rrr
hhhh11hhbbb3113113113bbbjjjjjjjjjjjjjjjjjjjj1r3999999999999999993rrr3jjjjj31rrr999999999999j99999999999999999999999999999rrr99rr
11hhhhhhbb3bb1b11113331fjjj1jjjjjj1jj13jjj1jrr13rrr33rr3rrr33rr333rr1jjjjj1jrr13rr99rrr99999999999999999999999999999999999999999
111hhhhhfbb3b1bbbb133bbfjj13jjjjj13j13jjj13j1r13rr11rrrrrr11rrrr111r3jjjj13j1r13rrr11rrr9999999999999999999999999999999999999999
h11hh11hfbb1313b3bb13bbbj13jjj1j13j13jj1j3jjrr1r1rr11rr11rr11rr1rrr3jj1jj3jjrr1rrrrr31r39999999999999999999999999999999999999999
hhhhh11hb33b1b1313b113bfj3jjj13j3jj3jj13jj1j33rr3131331131313311rr13j13jjj1j33rrr11133139999999999999999999999999999999999999999
hh11hhhhf1333bb1bb31113bjjjj133jjj1jj13jj13jjj31j3133j33j3133j33j13j13jjj13jjj31j3131rr39999999999999999999999999999999999999999
hh111hhhf31133bbbbb1bb1fjjj133jjj13j13jj13jjj133jj3jjj3jjj3jjj3j13j13j1j13jjj133jjj1rrr39999999999999999999999999999999999999999
hhh111hhf3b133333bb1bbbfjjj13jjjj3jj3jjj3jjj13jjjjjjjjjjjjjjjjjj3jj3j13j3jjj13jjjjj11rr99999999999999999999999999999999999999999
hhhh11hhfff1fff11fffffffjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj13jjjjjjjjjjjjjj1r399999999999999999999999999999999999999999
hhhhhsshhccc1771jjjjj13jjjjjjjjjjjjjjjj13jjj13jjjjj1jjjjjjjjjjjj1jjjjjjjjjj1jjjjjj1jrr13f77177777777177frr99rrr99999999999999999
hhsshhssh1ccc171jjjj13jjjjjjj1jjjjjjjj13jjj13jjjjj13jjjjjjj1jjj13jjj11jjjj13jjjjj13j1r13777c177cc771c777rrr11rrr9999999999999999
hhscchhs111c771hjj11hhjjjjjj13jjjjjjj13jjjj3jjj1j13jjj1jjj13jj13111111jjj13jjj1jj3jjrr1r77ccc1cccc11cc77rrrr31r39999999999999999
hhhccchh1cc17771j1111hhjjjj13jjj8888h3jjjjjjjj13j3jjj13jj13jj11113rr11j1j3jjj13jjj1j33rr77cccc1ccccc1cc7r11133139999999999999999
hhhhccchcccc1771jjjhhhhjjj13j888888hhhjjjjjjj13jjjjj133j13jj113rrrr31113jjjj133jj13jjj311cccccc11cccc1c7j3131rr39999999999999999
cchhhcssccccc111jjjjjhhjj13jhhh8888h8888jjjj13jjjjj133jj3jj11rrrrrb3113jjjj133jj13jjj13371ccccc111cccc17jjj1rrr39999999999999999
ccshhhss1cccc71hjj111h11j3jj88hh88a9h8888jj13jjjjjj13jjjjjj13rrrrb3111jjjjj13jjj3jjj13jj7711ccc1h11cccc1jjj11rr99999999999999999
hsshhhhhh1cc77711111hh11jjjj888ha99a9h888j13jjjjjjjjjjjjjjj1rrrr333111jjjjjjjjjjjjjjjjjjccc11111hh11ccccjjjj1r399999999999999999
hhhsshhhhccc1771111hhhh11jj8888h9944hhhh883jjjjjjjj1jjjjjj11rrb3333111jjjjjjjjjj13jjj88j7cc1c1hh11hhhhhh77cc17777777177frrr33rr3
hhhsschhh1ccc171hhhhhhh11jj8888hhhhhh88hhhjjjjj1jj13jjjjj111rb33333111jjjj133jjj3881888877cc1c1h111hhhhhc771cc77c771c777rr11rrrr
sshhscch111c771hhhhhhhhhhhjjj8hhh888h888hjjjjj13j13jjj1j131r3333331111jjj1333jj18889911j777cc1c1h11hh11hcccc1ccccc11cc771rr11rr1
scchhscs1cc17771hhhjjhhhhh11hh1h8888hh88jjjjj13jj3jjj13j3j1b333311311jj11333jj13889aa883177ccc1chhhhh11hcccc1ccccccc1cc731313311
hccchhsscccc1771hjjjj13jhhhhhhhhh8888j13jjjj13jjjjjj133jjj1111111rr11j13133jj13jj1aa98887c1cccc1hh11hhhh1cccc11c1cccc1c7j3133j33
hhccshhhccccc111hjjj13jjjjjhhjhjjjjjj13jjjj13jjjjjj133jjjj1133311111113jjjjj13jj1888188h77c1ccchhh111hhh11ccc11111cccc17jj3jjj3j
sshsshhh1cccc71hjjj13jjjjjj13jhhhhhj13jjjj13jjjjjjj13jjjj1311r33111113jjjjjj3jjj38881hhj777c11hhhhh111hhh1111hhhh11cccc1jjjjjjjj
hsshhhhhh1cc7771jjj3jjjjjjj3jjjhhhjj3jjjjj3jjjjjjjjjjjjjj3jj11r331111jjjjjjjjjjjjj81hhjj177c1hhhhhhh11hhhh11hhhhhh11ccccjjjjjjjj
hhhchhhhhccc1771jjjjjj13jjjjjjjjjjj1jjjjjjj1jjjjjj1jj13jjjjjj1r313111jj1jjj1jjjjj1hhjjj17cc1c1hhhhhhhsshhhhsshhhhccc1771jjjjjj13
hhccshhhh1ccc171jj1jj13jjj133jjjjj13jjjjjj13jjjjj13j13jjjjjj11113r111j1rjj13jjjjjj1hhh1377cc1c1hhhsshhsshhhsschhh1ccc171jj1jj13j
hhhsschh111c771hj13jj3jjj1333jj1j13jjj1jj13jjj1j13j13jj1jjj13j13r1111133j13jjj1jj13j1h3j777cc1c1hhscchhssshhscch111c771hj13jj3jj
sshhccsh1cc1777113jjjjjj1333jj13j3jjj1bjj3jjj1bj3jj3jj13jj13jj11r11113jjj3jjj13j13j1jhhj177ccc1chhhccchhscchhscs1cc1777113jjjjjj
scchhsshcccc17713jjjs1jj133jj13jbjjb13bjbjjb13bjjj1jj13jj13jjj11111113jjjjjj133j3j13j1h17c1cccc1hhhhccchhccchhsscccc17713jjjs1jj
hccchhhhccccc111jjccss1jjjjj13jjbjb133bjbjb133bjj13j13jj13jjj13j11113jjjjjj133jjj1311hh377c1ccchcchhhcsshhccshhhccccc111jjccss1j
chccshhh1cccc71hjccssssjjjjj3jjjb3b13b3jb3b13b3jj3jj3jjj3jjj13jjj113jjjjjjj13jjjj311hh3j777c11hhccshhhsssshsshhh1cccc71hjccssssj
hchsshhhh1cc7771ccsssss1jjjjjjjjb3bb3b3bb3bb3b3bjjjjjjjjjjjj3jjjjj3jjjjjjjjjjjjjjhhhh3jj177c1hhhhsshhhhhhsshhhhhh1cc7771ccsssss1
11hhhhhh11hhhhhh7777177fjjj1jjjj1ffffbfffffbfff1j11jjjjjjjjjjj1jjjjjjjjjjjjjjj1jf771777711hhhhhh11hhhhhh11hhhhhhhhhhhssh77cc1777
111hhhhh111hhhhhc771c777jj13jjjjfbbb33111bbb331fj1jrrrbjjj1jj13jjjjjjjjjjjj1j13j777c177c111hhhhh111hhhhh111hhhhhhhsshhssc771cc77
h11hh11hh11hh11hcc11cc77j13jjj1jf11bb31111bbb31f1jjbrbj1j13j13jjjj1jjj13jj1313jj77ccc1cch11hh11hh11hh11hh11hh11hhhscchhscccc1ccc
hhhhh11hhhhhh11hcccc1cc7j3jjj1bjfb1133b1b1133b1f111jjbj113jj3jjjj3313133j13j3jj377cccc1chhhhh11hhhhhh11hhhhhh11hhhhccchhcccc1cbc
hh11hhhhhh11hhhh1cccc1c7bjjb13bjfbb1133bbb1133bfjj111j1j3jj1jjjj3113313j33jjjj1j1cccccc1hh11hhhhhh11hhhhhh11hhhhhhhhccchbccbc1bc
hh111hhhhh111hhh11cccc17bjb133bjf1111bb11111bb1fj3jj111jjj13j3r13rrr13r1r33jj13j71ccccc1hh111hhhhh111hhhhh111hhhcchhhcssb1bcc3b1
hhh111hhhhh111hhh11cccc1b3b13b3jf33311bb33311bbfjjr3j11jj13jj3rr1rrrr1rr1rrj13jj7711ccc1hhh111hhhhh111hhhhh111hhccshhhssb3b13b3h
hhhh11hhhhhh11hhhh11ccccb3bb3b3bfb33b11bb33b11bfj13r1jj1j3jj3r11rrrr9rrr1r1j3jjjccc11111hhhh11hhhhhh11hhhhhh11hhhsshhhhhb3bb3b3b
11hhhhhh11hhhhhhhhhsshhh1ffffbff331111111113331fjjjjjj1jjjj3rrr3999999999133j3jj7cc1c1hhhhhsshhh11hhhhhh11hhhhhh11hhhhhh1ffffbff
111hhhhh111hhhhhhhhsschhfbbb331113111jj1bb133bbfjj1jj13jjjj1rrrr999999991rr113jj77cc1c1hhhhsschh111hhhhh111hhhhh111hhhhhfbbb3311
h11hh11hh11hh11hsshhscchf11bb31111133jjj3bb13bbbj13j13jjjjj13rrr99999999rrr333jj777cc1c1sshhscchh11hh11hh11hh11hh11hh11hf11bb311
hhhhh11hhhhhh11hscchhscsfb1133b1111133jj13b113bf13jj3jjjjj133rr199999999rr13j3jj177ccc1cscchhscshhhhh11hhhhhh11hhhhhh11hfb1133b1
hh11hhhhhh11hhhhhccchhssfbb1133b11111311bb31113b3jj1jjjj3311313399999999911r3jjj7c1cccc1hccchhsshh11hhhhhh11hhhhhh11hhhhfbb1133b
hh111hhhhh111hhhhhccshhhf1111bb111111jj1bbb1bb1fjj13j3r13113rr19999999999rrr1jjj77c1ccchhhccshhhhh111hhhhh111hhhhh111hhhf1111bb1
hhh111hhhhh111hhsshsshhhf33311bb11311jjj3bb1bbbfj13jj3rr1rrrrr9999999999rrrr1jjj777c11hhsshsshhhhhh111hhhhh111hhhhh111hhf33311bb
hhhh11hhhhhh11hhhsshhhhhfb33b11b113311jj13113bbbj3jj3r1139rrr999999999993rr13jjj177c1hhhhsshhhhhhhhh11hhhhhh11hhhhhh11hhfb33b11b
11hhhhhh11hhhhhh11hhhhhhf1333111331111111113331fjjj3rrr3hhhhhhh99999999993r1jjjj7cc1c1hhhhhhhssh11hhhhhh11hhhhhh11hhhhhhbb3bb1b1
111hhhhh111hhhhh111hhhhhfbb331bb13111jj1bb133bbfjjj1rrrh8888888h999999999rr11jjj77cc1c1hhhsshhss111hhhhh111hhhhh111hhhhhfbb3b1bb
h11hh11hh11hh11hh11hh11hbbb31bb311133jjj3bb13bbbjjj13rh888888888h99999993rrr1jjj777cc1c1hhscchhsh11hh11hh11hh11hh11hh11hfbb1313b
hhhhh11hhhhhh11hhhhhh11hfb311b31111133jj13b113bfjj133rh8888ffff8h99999993rr1313j177ccc1chhhccchhhhhhh11hhhhhh11hhhhhh11hb33b1b13
hh11hhhhhh11hhhhhh11hhhhf31113bb11111311bb31113b331131h888f1ff18h99999993133111r7c1cccc1hhhhccchhh11hhhhhh11hhhhhh11hhhhf1333bb1
hh111hhhhh111hhhhh111hhhf1bb1bbb11111jj1bbb1bb1f3113rrh888fffffh999999993r13rrrr77c1ccchcchhhcsshh111hhhhh111hhhhh111hhhf31133bb
hhh111hhhhh111hhhhh111hhfbbb1bb311311jjj3bb1bbbf1rrrrr9h883333h999999999rrr11rrr777c11hhccshhhsshhh111hhhhh111hhhhh111hhf3b13333
hhhh11hhhhhh11hhhhhh11hhbbb31131113311jj1fffffff39rrr999hhjhhjh9999999999rrr99rr177c1hhhhsshhhhhhhhh11hhhhhh11hhhhhh11hhfff1fff1
11hhhhhh11hhhhhh11hhhhhhbb3bb1b11113331f77cc177777cc17777777177f99999999f771777711hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh
111hhhhh111hhhhh111hhhhhfbb3b1bbbb133bbfc771cc77c771cc77c771c77799999999777c177c111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh
h11hh11hh11hh11hh11hh11hfbb1313b3bb13bbbcccc1ccccccc1ccccc11cc779999999977ccc1cch11hh11hh11hh11hh11hh11hh11hh11hh11hh11hh11hh11h
hhhhh11hhhhhh11hhhhhh11hb33b1b1313b113bfcccc1ccccccc1ccccccc1cc79999999977cccc1chhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11h
hh11hhhhhh11hhhhhh11hhhhf1333bb1bb31113b1cccc11c1cccc11c1cccc1c7999999991cccccc1hh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhh
hh111hhhhh111hhhhh111hhhf31133bbbbb1bb1f11ccc11111ccc11111cccc179999999971ccccc1hh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh111hhh
hhh111hhhhh111hhhhh111hhf3b133333bb1bbbfh1111hhhh1111hhhh11cccc1999999997711ccc1hhh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh111hh
hhhh11hhhhhh11hhhhhh11hhfff1fff11fffffffhh11hhhhhh11hhhhhh11cccc99999999ccc11111hhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hh
11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhhhhhsshhh11hhhhhh77cc1777hhhhhssh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh
111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhhhhhsschh111hhhhhc771cc77hhsshhss111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh
h11hh11hh11hh11hh11hh11hh11hh11hh11hh11hh11hh11hsshhscchh11hh11hcccc1ccchhscchhsh11hh11hh11hh11hh11hh11hh11hh11hh11hh11hh11hh11h
hhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hscchhscshhhhh11hcccc1ccchhhccchhhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11h
hh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhccchhsshh11hhhh1cccc11chhhhccchhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhh
hh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhhccshhhhh111hhh11ccc111cchhhcsshh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh111hhh
hhh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh111hhsshsshhhhhh111hhh1111hhhccshhhsshhh111hhhhh111hhhhh111hhhhh111hhhhh111hhhhh111hh
hhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhsshhhhhhhhh11hhhh11hhhhhsshhhhhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hhhhhh11hh

__gff__
0000000000000000000400000000000004040808080303030000000000000000030303030303030303030303040400000303030303030303030303030404000000000000000000040404040404040404000404040000040404040404040404040404040404040404040404040404040404040404040404040404040404040404
0000000004040404040404040404040400000000040404040404040404040404000000000404040404040404040404040000000004040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000
__map__
28353b3b376564723129282828243b3b34282928282828293932323229282828282932323830677731293932323828283232353b3b341e001e1d3536363637283b3b3b3636363732323938392829243b3b3b34292828293232322939292839380000000000000000000000000000000000000000000000000000000000000000
282835371e7163001d202838253b36363b262732382829323365675720382828262767473133656869313372773129287b64723536371e0051527568694720393b3b3447630000a90031323232323536363637323239301e1e1d3232323232320000000000000000000000000000000000000000000000000000000000000000
282829300e00600000202932353777673536375731323373a9716547202839283b3b276473a971787963c9cacbcc3139a57300c2c3715252647265787972312936363767745300b9007157631e1d00000000a6a76120301d000000c9cacbcccd0000000000000000000000000000000000000000000000000000000000000000
28283830000000001d3133d4d57172654764727272656300b9006164313225263b36376300b900716563d9dadbdc2028270e00a6a70061647300716563001d2029306c6d6e6f530000006163420000000000b6b76131331e005153d9dadbdcdd0000000000000000000000000000000000000000000000000000000000000000
262627331e000000000000c2c30000616473000000616300005164730000243b373064730000131421230d5164722029370000c2c30071730d0000616300003138307c7d7e7f630e00006174530000000d0000517585630000617452527577670000000000000000000000000000000000000000000000000000000000000000
363b346300000000005600d2d30000616300000000617453006163004041243b293063000d0000003129237573001d20300e0dd2d30e00000025277273001d25393072655777740000516747630e005152530d615795745252756472655725260000000000000000000000000000000000000000000000000000000000000000
2824347452530000516300b6b70000716553000051751174527563005000243b2829230d000000001d203063001d0d20300e2122230000000035378c8d8e8f2428300e616869671d527577676767526767484975677767476764730025263b360000000000000000000000000000000000000000000000000000000000000000
2835375767745252757453000000000061630051252627222367745225263b3b2838331e000d00001d3133630000002029223929331e00000000009c9d9e9f24383052757879671e6767671e6767671d0d5859671e6767677763000d353b34280000000000000000000000000000000000000000000000000000000000000000
29306c6d6e6f574a4b577421235300006174522135363729334a4b57353b3b3b28300e00000e0000000d717253000d20282828304041005153007aacad00af3526277272726564661e610e0d1d1d00716767670e00001e716574520e673537280000000000000000000000000000000000000000000000000000000000000000
38307c7d7e7f575a5b777b20282223527548493132292833575a5b5747353b28293025270d0000000d00000d6153002028282930500000617453a4bcbd00bf203b341e0000717300006157676300001d717265c31d00001d61570e670d2029280000000000000000000000000000000000000000000000000000000000000000
393011775757676a6b57a520293830115758597757313372656a6b576757243626263637530d0000000d515272630d202828252626275275472526270e0d0d203b3488898a8b000000716577745300000000d2d3000000006167670e673128280000000000000000000000000000000000000000000000000000000000000000
2828235725274764726521282828292225274c4d6473c9cacbcccdcecf2534283b3457476300000000006163006121382828243b36376d6e67353637222222293b3498999a9b00000000614a4b7452530000c2c30000000061677767647220390000000000000000000000000000000000000000000000000000000000000000
282838253b34647300612038282828253b345c5d630ad9dadbdcdddedf2437283637674c4d5300000051647342712028283935371d717d7e72722029282939283637a800aaab0000000d615a5b5767634200d2d3000000514c4d6472730031290000000000000000000000000000000000000000000000000000000000000000
282828243b3773010071202928282835363b2627745252527521222225342828307b575c5d6300017675630000002029293365631e006163001d2029282828283830b800babb0051520e756a6b6747745300c2c3000000615c5d6300010000200000000000000000000000000000000000000000000000000000000000000000
2828283537222223002128282828282828353b3b27222222222928383537282829222225262712131421230e0d0d2029301d716552527574530e20282828282828300e1e0d000d7567670d67776767577452d2d3530e0d2526262712131425260000000000000000000000000000000000000000000000000000000000000000
282828282828382822292828282828282828243b3428293829282828282828282828253b3b3452530020392222223828301e0061776764727221392828282828283922222222222222230e0d1d0d1d0d1d0d1d21222222243b3b34000000243b0000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000300e51756472630e1e3129282828282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030527547631e61530d1d20292828282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003072727265526763000020282828282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000301e000071657763000d20382828282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000380e0e0d00716574530020382828282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000282222230d006147630d20392828282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002838283923527577742138282828282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002828282526276472722526272828282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000028283835363773000035363b2728282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002839323364730042000000353739282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003833776763000000008687716531382800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003048496473000000009697006167252600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000305859630000000000c2c3006167243b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000274c4d745300000000d2d3517b253b3600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000345c5d252753000100252775a535372800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003b26263b34231214212434222238282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010100000f0001e000120002200017000260001b0002c000210003100027000360002b0003a000300003e00035000000000000000000000000000000000000000000000000000000000000000000000000000000
010100000970009700097000970008700077000670005700357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
0101000036300234002f3001d4002a30017400273001340023300114001e3000e4001a3000c40016300084001230005400196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
010100000c0633c6003c6603c6603c6603c6603065030650306403064030660306403063030630306503063030630306303062030620306202462024610246101861018610186100c6100c615006000060000600
01020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
01030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
0102000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 41425253
00 41425253
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 41425253
00 41425253
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 41425253
00 40404040
00 40404040
00 40404040
00 40404040
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 40404040
00 40404040
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253
00 41425253

