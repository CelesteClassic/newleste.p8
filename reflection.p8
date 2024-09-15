pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
--reflection.p8
--by many contributers

--need token saves bad!!!

--things we cant fit atm:

--	hex level loading
--	background image
--	anxiety tentacles

--can do those after jam ?

_g=_ENV
poke(24366,1)
function vector(n,e)
return{x=n,y=e}
end
function v0()return vector(0,0)end
function rectangle(n)
tbl={}
tbl.x,tbl.y,tbl.w,tbl.h=unpack(split(n))
return tbl
end
objects,got_fruit={},{}
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
for n in all(fruitrain)do
if n.type==fruit and not n.golden and berry_timer>5and n then
berry_timer=-5
_berry_count+=1
_g.got_fruit[n.fruit_id]=true
init_object(lifeup,n.x,n.y,_berry_count)
del(fruitrain,n)
destroy_object(n)
if(fruitrain[1])fruitrain[1].target=_ENV
end
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
if n.big then spr(89,n.x-1,n.y-1,1,1,n.flip.x,n.flip.y)
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
sspr(72,0,8,8-n,x,y+n)
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
spr(15,x,y+sin(offset)+.5)
else
spr(14,x,y)
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
if sprite>=29then
destroy_object(_ENV)
end
end
}
fruitrain={}
fruit={
check_fruit=true,
init=function(_ENV)
y_,off,tx,ty,golden=y,0,x,y,sprite==11
if golden and deaths>0then
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
while(right()<lvl_pw-1and tile_at(right()/8+1,y/8)==65)hitbox.w+=8
while(bottom()<lvl_ph-1and tile_at(x/8,bottom()/8+1)==80)hitbox.h+=8
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
spr(active and 67or 66,n+hitbox.w/2-4,e+hitbox.h/2-4)
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
spr(68,x,y,2,2)
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
bubble=sprite==88
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
spr(70+min(n,6-n),x,y,1,1,n>3)
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
hitbox=rectangle'-16,-16,40,40' --try to suck player in
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
while(right()<lvl_pw-1and tile_at(right()/8+1,y/8)==76)hitbox.w+=8
while(bottom()<lvl_ph-1and tile_at(x/8,bottom()/8+1)==76)hitbox.h+=8
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
spr(31,n.x,n.y)
end)
foreach(spinner_controller.spinners,function(n)
spr(46,n.x,n.y,2,2)
end)
end
}
spinner={
init=function(_ENV)
if sprite%2==1then
x-=8
end
if sprite>=63then
y-=8
end
hitbox=rectangle"2,2,12,12"
add(spinner_controller.spinners,_ENV)
destroy_object(_ENV)
end
}
tiles={}
foreach(split([[1,player_spawn
8,side_spring
9,spring
10,fruit
11,fruit
12,fly_fruit
15,refill
23,fall_floor
64,kevin
68,bumper
70,feather
88,feather
74,badeline
75,fall_plat
77,osc_plat
46,spinner
47,spinner
62,spinner
63,spinner
]],"\n"),function(n)
local n,e=unpack(split(n))
tiles[n]=_ENV[e]
end)
function init_object(n,e,d,f)
local o=e..","..d..","..lvl_id
if n.check_fruit and got_fruit[o]then
return
end
local _ENV=setmetatable({},{__index=_g})
type,collideable,sprite,flip,x,y,hitbox,spd,rem,fruit_id,outline,draw_seed=
n,true,f,vector(),e,d,rectangle"0,0,8,8",vector(0,0),vector(0,0),o,true,rnd()
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
init_object(smoke,x+(n or 0),y+(e or 0),26)
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
--if mapdata[lvl_id] then
--replace_mapdata(lvl_x,lvl_y,lvl_w,lvl_h,mapdata[lvl_id])
--end
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
--sspr(0,80,56,32,0,0,lvl_pw,lvl_ph)
draw_x=round(cam_x)-64
draw_y=round(cam_y)-64
camera(draw_x,draw_y)
if anxiety then
cls'0'
fillp'0b0101101001011010'
--for i=0,127,2 do 
--offset=sin(frames/15+i/150)*3
--for j=-16,256,12 do
--local shrink=(150+(sin(j/4.5+frames/30)*30)-i)/16
--if (shrink<=7.5) line(j+offset+shrink,i,j+offset+16-shrink,i,1)
--line(j+offset+shrink,i,j+offset+15-shrink,i,(i>96 or i>80 and i<90 or i>70 and i<75 or i>64 and i<67 or i>60 and i%2==1) and 1 or 2)
--end end	
fillp()
palt(2,true)
function pa(a)
local t,q,l=unpack(split(a))
for i=1,15 do pal(i,t) end
if l<0 then
camera(draw_x+q,draw_y)
else
map(lvl_x,lvl_y,q,0,lvl_w,lvl_h,l)
end
end
pa'12,-1,4'
pa'8,1,4'
--pal''
end
pal''
palt(2,true)
palt(0,false)
map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)
palt()
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
if anxiety then pa'12,-1,2'
pa'8,1,2' end
pal''
palt(0,false)
palt(2,true)
map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
palt()
foreach(e,function(n)
foreach(n,function(_ENV)
draw_object(_ENV)
if bubble and bubbled then
oval(left()-4,top()-4,right()+4,bottom()+4,7)
end
end)
end)
for n=1,lvl_w do
for e=1,lvl_h do
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
p"9,137"
p"14,131"
p"13,139"
p"15,14"
p"0,129"
p"6,140"
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
-->8
--[map metadata]
--@conf
--[[
autotiles={{33, 35, 34, 32, 33, 35, 34, 32, 49, 51, 50, 48, 32, 48, 40, 41, [0] = 34, [28] = 57, [40] = 56}, {37, 39, 38, 36, 37, 39, 38, 36, 53, 55, 54, 52, 36, 52, 59, 42, [0] = 38, [28] = 58, [40] = 43}, {118, 102, 112, 96, 81, 83, 82, 96, 113, 115, 114, 112, 97, 99, 98, 37, 38, 39, 36, 87, 144, 145, 90, 91, 92, 93, 78, 53, 54, 55, 52, 103, 104, 105, 106, 107, 108, 109, 128, 32, 33, 34, 35, 119, 120, 121, 122, 123, 94, 95, 129, 48, 49, 50, 51, 116, 117, 100, 101, 146, 110, 111, 130, [0] = 98}}
composite_shapes={}
param_names={"phase/phase/phase/..."}
]]
--@begin

--level table
--"x,y,w,h,exit_dirs,phase/phase/phase/..."
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
--phase 1 (ball) or 2 (laser)

levels={
  "0,0,2,1,0b0010,0",
  "2,0,2,1,0b0010,0/1/2"
}
--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
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
foreach(split'40,41,42,43,56,57,58,59',function(t)
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
000000000000000000000000088888800000000000000000000000000000000000000000000000000300b0b00a0aa0a000000000000000000007700000077000
00000000088888800888888088888888088888800888880000000000088888800000000000000000003b33000aa88aa0000000000000000000700700007bb700
00000000888888888888888888877778888888888888888008888880887177180000000000000000028888200299992000000000000000000700007007bbb370
000000008887777888877778887177188887777887777880888888888877777800000000024444200898888009a999900000000000000000700000077bbb3bb7
000000008871771888717718087777708871771881771780888777788877777800000000005005000888898009999a9000000000000000007000000773b33bb7
0000000008777770087777700033330008777770077777808877777808333380000000000005500008898880099a999000000000000000000700007007333370
00000000003333000033330005000050053333000033335008717710003333000000000000500500028888200299992000000000000000000070070000733700
00000000005005000050005000000000000005000000500005533350005005000000000000055000002882000029920000000000000000000007700000077000
22222222eeeeee1300000000110000004999499949994999499949990000000000000000000000000000000000000000700000000000000000000000022f22f0
22222222ee1ee13e00000000111000004444444444444444444444440000000000000000000000000077000007700700070000070000000000000000fff22f2f
22222222e13ee3ee000000000110110022245222222222222225422200000000000000000000000000777070077700000000000000000000000000002fff2ff2
2222222213eeeeee00000000000011102245222222222222222254220000000000000000000000000777777007700000000000000000000000000000f2f22222
222261223eee61ee000000000110011024522222222222222222254200000000000000000000000007777770000070000000000000000000000000002222222f
22cc6612eecc661e00000000011100004522222222222222222222540000000000000000000000000777777000000770000000000000000000000000f22222ff
2cc66662ecc6666e00000000001100005222222222222222222222250000000000000000000000000707770000070770070000700000000000000000f2222f2f
cc666661cc666661000000000000000022222222222222222222222200000000000000000000000000000000700000000000000000000000000000000ff2fff0
7cc1c1005771777777cc1777777717753d333dddd3333b3333b33b33333b333d1100000000000660dd3dd33333ddd33322222222dddddddd0000000700700000
77cc1c10777c177cc771cc77c771c7773bb33dbb3bbb33dddbbdbbbddbbb33d31110000000660066dd3dd3333ddd3dd322222222dddddddd00000000ff000070
777cc1c177ccc1cccccc1ccccc11cc77bbb3dbb33ddbb3ddd3bb3bbdddbbb3d301100110006cc00633333dd3ddd3ddd322222232ddddddbd7000f0027f200700
177ccc1c77cccc1ccccc1ccccccc1cc73b3ddb3d3bdd33bdbb3bb33dbdd33bd300000110000ccc003dd33ddddd33dd33222222b2ddddddbd070007ff2ff2ff00
7c1cccc11cccccc11cccc11c1cccc1c733ddd3bb3bbdd33bbd33bddbbbdd33b3001100000000ccc03ddd33dd3333333d22222b32dddddbbd0fff2ff2f22ff000
77c1ccc071ccccc111ccc11111cccc173dbbdbbb3ddddbbd3dd3dbdbddddbbd300111000cc000c6633dd333dddd3dd3d23222b22dbdddbdd002222ff22f2f700
777c11007711ccc101111000011cccc13bbbdbb33333ddbbd33b3bbd333ddbb300011100cc600066d333ddd33ddddd3322b2b322ddbdbbdd0002222ff2ff2000
177c1000ccc11111001100000011ccccbbb3dd3d3b33bddbd3dbb3ddb33bddb30000110006600000dd333dd3333dd33322323322ddbdbbdd00ff2ff22222f220
0ccc17711111cccc0ccccccc1cccccc1ddd333d3bb3bbdbddbbdbbddddd333d300066000000c0000dd333ddddd33333300000000dddddddd77f2f22f22f227f0
01ccc1717ccc1cccccccccccc1cccc71bbd33bb33bb3bdbbbdbb3bbdbbd33bb300066c0000cc6000dd333dd33d333ee300000000dddddddd020f22f2ff2ffff7
111c77107cccc1ccccc1cccccc1ccc713bbd3bbb3bbd3d3bbbdbb33d3bbd3bbb66006cc000066c0033dd3333333ddeee00000000dddddddd0000f272f2722000
1cc1777117cccc1ccccc1cccccc1ccc7d3bdd3b3b33bdbd3bbbdbddbd3bdd3b36cc006c66600cc60ddddd3333333ddee000000b0ddddddbd000ff72f2f277000
cccc1771717ccc1c1cccc1ccccc71c77bb3ddd3bdd333bbddbbdd3dbbb3ddd3b0ccc00666cc00660dd3ddd3333333d33b00b00b0bddbddbd002ff02ff22ff200
ccccc1117717cc11c1c7c711ccc77171bbbdbbd3d3dd33bbd3db333dbbbdbbd300cc60000ccc00003333dd3333333ee3b0b003b0bdbdd3bd0072000f0000f700
1cccc71017c1cc1c771777cc1ccc77113bbdbbb3d3bd3333d33bb3333bbdbbb366066000c0cc60003dd333dd33d33eeeb3b03b30b3bd3b3d0700000070000070
01cc7771e111111171117cc10111111ed3dd3bbb333d333d3d3333ddd3333333066000000c0660003ddd333d33dd33eeb3bb3b3bb3bb3b3b0000000020000000
0992cc5445cccc541110011111000011000000000000000000aaa0000099aa0000999aa0000aaa0000000000577777777777777747777777eeeeeeee00000000
9245cc2442cccc240000000001100110000001111110000009aaa900099aaaa0099aaaaa00aaaaa0022222207882787772287777722e7277eee1111e00000000
942ecc22221ee122011001100c0000c0000015ecce51000001aaa1009911aaaa995aaa11009a5a90222222227872c8ccc2c8cccc727e222cee111d1e00000000
25e5ee111111111100e99e000cc99cc00001ceecceec10000111110091110aa095aa0001009a5a90255552227222c8ccc888cccc7eeec2c2e11ddd1e00000000
cccec12222222222099ee99009eeee90001ccc1111ccc100011111009110000095a00000009959902855852277ccc8cccccccccc77ccc2cc1ddbd31e00000000
ccce1124444444440e1111e00e4114e0015ec144441ce510011111001100000095a00000009959900555552077c8c8c8cccccccc77c2c2c21bd3331e00000000
522122444444444400e99e000e1111e001ee14c44c41ee10001110001000000009500000000959000011111077cc888ccccccccc77cc222c1333111e00000000
44212444444444440009900000eeee0001cc14c22c41cc10000010001000000000500000000500000005000577ccc8cccccccccc77ccc2cc11111eee00000000
44212444222ddd23ddd33dd3dd22ddd201cc14444441cc102223d222eee1eeee007777000aa00000eeeeeeee1eeeeeeeeeeeeeeeeeeeeeeeeeeeeee1eeeeeeee
5221244422ddddd1dd11ddddddd11ddd01ee124cc421ee102233ddd2ee13eeee0700aa70aa000000eee1eee13eee11eeeee1111111eeee1eeeeeee13eeee1eee
cc11244421dd31131dd11dd1dddd31d3015ec124421ce5102ddeddd2e13eee1e700aaa0700000000ee13ee13111111eeee111ddd11eee13eeeeee13eee111eee
cce124443313113331313311d1113313001ccc1111ccc100dddee333e3eee13e7095900700000000e13ee11113dd11e1e131dddd11ee13eeeeee13eeee111eee
cce124441dd331eee3133e33e3131dd30001ceecceec1000dd33ee33eeee133e705900070000000013ee113dddd311131311dddd11ee3e1eee1e3eeee0001ee1
cc112444ddd31eeeee3eee3eeee1ddd3000015ecce510000233eeeddeee133ee70500007000000003ee11dddddb3113e311ddddd111ee13eee11eee1e0001e13
52212444dddd1eeeeeeeeeeeeee11dd20000011111100000ddeee3ddeee13eee070e007000000000eee13ddddb3111eee1ddddb1b11e1d3ee111ee131100013e
442124443ddd3eeeeeeeeeeeeeee1d320000000000000000ddde3dddeeeeeeee0077770000000000eee1dddd333111eee1dddb1331111eeee1100e31100113e0
bbbe3bbb2133e3eeeeeeeeeeee31ddd2eeeeee1eeeeeee1e22dd3322ee1ee13eee1ee111111eee1eee11ddb3333111eee1ddd1333d3d1eeeee10031000011000
bbe333bb1dd113eeeeeeeeeeee3e1dd3ee1ee13eeee1e13eddde3dd3e13e13eee1e111dd331111eee111db33333111eee11d1b33d3d11eeeee00880880010001
bb333ee2ddd333eeeeeeeeeeeee31ddde13e13eeee1313eeddd33ddd13e13ee11111d3bdd33111ee131d3333331111eeee11b333d11d1eeeee0082a280000111
ee33eebbdd13e3eeeeeeeeeeeee131dd13ee3eeee13e3ee33eeeedd23ee3ee1311dddd3bd333111e3e1b333311311ee1ee11333d13d11ee1e0082a900000011e
eee33bbb211d3eeeeeeeeeeeeee331dd3ee1eeee33eeee1eede3e332ee1ee13e1dddddd3b3111111ee1111111dd11e13ee1133d1d111ee13e10880280000111e
2bbb3bb22ddd1eeeeeeeeeeeeee1e312ee13e3d1d33ee13edddedd33e13e13ee1ddddddd31111111ee1133311111113ee1e11d1111eee13ee1000088000111ee
2bbbee22dddd1eeeeeeeeeeeeee31dd2e13ee3dd1dde13eedd3dddd3e3ee3eee11ddddb311111111e1311d33111113ee1dee111eeeee13eeee10000000111eee
222be2223dd13eeeeeeeeeeeee31ddd2e3ee3d111d1e3eee3322d322eeeeeeeee1ddb13d11110001e3ee11d331111eeedeeeeeeeeeee3eeeee1100001111eeee
eeeeeeee23d1eeeeeeeeeeeeeee3ddd3ee1edd1333dd1eee223d2233eeeeeeeee11d131d3110001eeeeee1d313111ee100000000000000000000000000000000
eeeeeeee2dd11eeeeeeeeeeeeee1dddde13e1d13111d3eee3dddd3ddee133eeeee113ddd111111eeeeee11113d111e1d00000000000000000000000000000000
eeeeeeee3ddd1eeeee1eee13eee13ddde3eedd1dddd3ee1e33ddeddde1333ee1eee1bddd110001eeeee13e13d111113300000000000000000000000000000000
eeeeeeee3dd1313ee3313133ee133dd1ee1e33dddd13e13e233e3ede1333ee13eee11ddd11001eeeee13ee11d11113ee00000000000000000000000000000000
eeeeeeee3133111d3113313e33113133e13eee31e13e13ee2ddeeee3133ee13eee1e1bdd1101eeeee13eee11111113ee00000000000000000000000000000000
eeeeeeee3d13dddd3ddd13d13113dd1213eee13313e13e1eddd33dddeeee13eee13e11bd1111ee1e13eee13e11113eee00000000000000000000000000000000
eeeeeeeeddd11ddd1dddd1dd1ddddd223eee13ee3ee3e13e3dd3edddeeee3eee13eee11b1111e13e3eee13eee113eeee00000000000000000000000000000000
eeeeeeee2ddd22dddddd2ddd32ddd222eeeeeeeeeeee13ee2233dd22eeeeeeee3eeeee11111e13eeeeee3eeeee3eeeee00000000000000000000000000000000
eee13eeeeeeeee1eeeeeeee1eeeee13eeeeeeeeeeeeeeee13eee13ee22222222222222222200001122222222eeee0000eeee13ee000000000000000000000000
ee13eeee0000013eee118813eeee13eeeeeee1eeeeeeee13eee13eee22222222222222211000000112222222eee000000ee13eee000000000000000000000000
e13eeee0000000888118888eee1100eeeeee13eeeeeee13eeee3eee122222222222221100000000011122222ee000ee11e13eeee000000000000000000000000
13eee1e00ee000e88822881ee111100eeee13eee888803eeeeeeee1322222222222111000002222001122222ee0001eeee3eee1e000000000000000000000000
3eee13e0ee1e000029992111eee0000eee13e888888000eeeeeee13e22222222221110000222222220112222ee18011110eee13e000000000000000000000000
eee13eeee13e1100889888eeeeeee00ee13e000888808888eeee13ee22222222211100002222222222011222eee80011001ee3ee000000000000000000000000
eee0008813ee11088882888eee111011e3ee880088a908888ee13eeedd222222211000022221110222011222ee08800000111eee000000000000000000000000
e0ee088880ee1100880eeee111110011eeee8880a99a90888e13eeeeddd11222110000222211100222001222ee8888ee000111ee000000000000000000000000
008829920001110000e01113111000011ee8888099440000883eeeeed1dd3330000002222211002200011222ee8888e08ee0111e000000000000000000000000
088889988001100000011111000000011ee888800000088000eeeee1d1113d00000022222210000000012222e10080e888e8001e000000000000000000000000
0882998888000000001111ee0000000000eee800088808880eeeee131e3e1e1100022222222000000012222213e001e080e8800e000000000000000000000000
00088828800000000011eee1000ee0000011001088880088eeeee13e31e1e1110002222222220000002222223ee001ee0ee8011e000000000000000000000000
10088800010000000111ee130eeee13e0000000008888e13eeee13eee1111110002222222222202202222222ee0010110e00011e000000000000000000000000
1100800111110000111ee13e0eee13eeeee00e0eeeeee13eeee13eee11111100002222222222202202222222e0010111110001e1000000000000000000000000
1110000011100011111e13eeeee13eeeeee13e00000e13eeee13eeee111110010222222222220012022222220110010110011e13000000000000000000000000
e11110000000011111ee3eeeeee3eeeeeee3eee000ee3eeeee3eeeee1110000112222222222211d102222222100000000011ee3e000000000000000000000000
9999999999999999999999999999999900000000000000000000000011000002222222222200dddd122222220000000022222222110000222222222222222222
99992999999999999999999999999999000000000000000000000000000000222222222220111dd3312222220000000022222221100000011222222222222222
999922299999999999999999999922990000000000000000000000000000d3222222222220011133312222220000000022222111000000000112222222222222
9992222999999999999999999222229900000000000000000000000000ddd2222222222220000113311222220000000022222110022220000011122222222222
9992222999999999999999992222f999000000000000000000000000311ed2222222222221dd0000001222220000000022221102222222200001112222222222
99992222999992299999992222ff29990000000000000000000000003e1dd32222222222221d3300000022220000000022211022222222220000111222222222
999992229200222099999222ff229999000000000000000000000000e31ddd2222222222222133300002222200000000222110222011122220000112222222dd
99999922222022002220022f22999999000000000000000000000000e131dd222222222222221313100222220000000022210022200111222200001122211ddd
a9200222222020022222022299999999000000000000000000000000e331dd22222222222222213110222222000000002221100022001122222000000333dd1d
2222002222202022222200222aaaaaaa000000000000000000000000e1e313222222222222222212222222220000000022221000000001222222000000d3111d
2222200222f0000222222002222aaaaa000000000000000000000000e31dd2222222222222222222222222220000000022222100000002222222200011e1e3e1
2222220222f00200222222022f200aaa00000000000000000000000031ddd22222222222222222222222222200000000222222000000222222222000111e1e13
22222f000f20222002222f0ff000222a0000000000000000000000003d222222222222222222222222222222000000002222222022022222222222000111111e
2222f0020f0022220022f20000222222000000000000000000000000ddd222222222222222222222222222220000000022222220220222222222220000111111
22ff002202022fff200f000022222222000000000000000000000000d22222222222222222222222222222220000000022222220210022222222222010011111
2f2002220002222a220002202222ffff0000000000000000000000002222222222222222222222222222222200000000222222201d1122222222222110000111
aaaa2222202aaaaaaa0222202fff00002222222222222222d1d13eeee31eeeee0000000000000000000000000000000022222221dddd00222222222220000011
aaaa2222f0222aaaaaa2222200000222222222222222222d1ddd11eeee31eeee00000000000000000000000000000000222222133dd111022222222222000000
aaa222ff202f22aaaaaaa222022222222222222222222222d1dd1eeeee0011ee00000000000000000000000000000000222222133311100222222222223d0000
aa222f22af22f2aaaaaaaa22022222222222222222208888dd1d1eeee001111e00000000000000000000000000000000222221133110000222222222222ddd00
aa22222faaf2f22aaaaaaaa2022222222222222222000888888e31eee0000eee00000000000000000000000000000000222221000000dd1222222222222de113
aaa222f2aaafff2aaaaaaaaa0222ffff22222222888808888000e31ee00eeeee00000000000000000000000000000000222200000033d12222222222223dd1e3
999222faaaaa2f2aaaaaaaa22fff22222222222888809a880088ee3e110111ee0000000000000000000000000000000022222000033312222222222222ddd13e
99992f999999999aaaaaa22222aaaaa2222222288809a99a0888eeee110011110000000000000000000000000000000022222001313122222222222222dd131e
99992999999999999999222222aaaaaa222222880000449908888ee1100001110000000000000000000000000000000022222201131222222222222222dd133e
99999999999999999999222ff999aaaa222222000880000008888ee1100000000000000000000000000000000000000022222222212222222222222222313e1e
999999999999999999992ff2299999992222222088808880008eee000000000000000000000000000000000000000000222222222222222222222222222dd13e
99999999999999999999222999999999222222228800888801001100000ee00000000000000000000000000000000000222222222222222222222222222ddd13
99999999999999999999999999999999222222222228888000000000e31eeee000000000000000000000000000000000222222222222222222222222222222d3
99999999999999999999999999999999222222222222222dd0d00eeeee31eee00000000000000000000000000000000022222222222222222222222222222ddd
99999999999999999999999999999999222222222222200000d3333eeee31eee000000000000000000000000000000002222222222222222222222222222222d
9999999999999999999999999999999922222222222222000d1dd3eeeeee3eee0000000000000000000000000000000022222222222222222222222222222222
00888800000008000088880000888800008008000088880000888800008888000088880000888800008888000088880000888800008880000088880000888800
00800800000008000000080000000800008008000080000000800000000008000080080000800800008008000080080000800000008008000080000000800000
00800800000008000000080000000800008008000080000000800000000008000080080000800800008008000080080000800000008008000080000000800000
00800800000008000088880000888800008888000088880000888800000008000088880000888800008888000088800000800000008008000088880000888800
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00888800000008000088880000888800000008000088880000888800000008000088880000000800008008000088880000888800008880000088880000800000
00cccc0000000c0000cccc0000cccc0000c00c0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000ccc00000cccc0000cccc00
00c00c0000000c0000000c0000000c0000c00c0000c0000000c0000000000c0000c00c0000c00c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000000c0000000c0000c00c0000c0000000c0000000000c0000c00c0000c00c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000cccc0000cccc0000cccc0000cccc0000cccc0000000c0000cccc0000cccc0000cccc0000ccc00000c0000000c00c0000cccc0000cccc00
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00cccc0000000c0000cccc0000cccc0000000c0000cccc0000cccc0000000c0000cccc0000000c0000c00c0000cccc0000cccc0000ccc00000cccc0000c00000
__label__
cccccccccccccccccccccccccccccccccccccc775500000000000000000000000000000000070000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccc776670000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccc77ccc776777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccc77ccc776660000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccc7cccccc6ccccccccc7775500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccc77776670000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccc777777776777700000000000000000000000000000000000000000000011111111111111111111111111111111111111
cccccccccccccccccccccccccccccccc777777756661111111111111111111111111111111111100000000000011111111111111111111111111111111111111
cccccccccccccccccccccccccccccc77011111111111111111111111111111111111111111111100000000000011111111111111111111111111111111111111
ccccccccccccccccccccccccccccc777011111111111111111111111111111111111111111111100000000000011111111111111111111111111111111111111
ccccccccccccccccccccccccccccc777011111111111111111111111111111111111111111111100000000000011111111111111111111111111111111111111
cccccccccccccccccccccccccccc7777011111111111111111111111111111111111111111111100000000000011111111111111111111111111111111111111
cccccccccccccccccccccccccccc7777011111111111111111111111111111111111111111111100000000000011111111111111111111111111111111111111
ccccccccccccccccccccccccccccc777011111111111111111111111111111111111111111111100000000000011111111111111111111111111111111111111
ccccccccccccccccccccccccccccc777011111111311b1b111111111111111111111111111111100000000000011111111111111111111111111111111111111
cccccccccccccccccccccccccccccc7700000000003b330000000000000000000000000000000000000000000011111111111111111111111111111111111111
cccccccccccccccccccccccccccccc77000000000288882000000000000000000000000000000000000070000000000000000000000000000000000000000000
cccccccc66cccccccccccccccccccc77000000000898888000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc66ccccccccccccccc77ccc77000000000888898000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccc77ccc77000000000889888000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccc77cccccccc777000000000288882000000000000000000000000000000000000000000000000000000000000000000000006600000000
ccccccccccccccccc777777ccccc7777000000000028820000000000000000000000000000000000000000000000000000000000000000000000006600000000
cccccccccccccccc7777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6ccccccccccccccc7777777777777775111111111111111111111000000000000000000000000000000000000000000000000001111111111111111111111111
cccccccccccccc776665666566656665111111111111111111111000000000000000000000000000000000000000000000000001111111111111111111111111
ccccccccccccc7776765676567656765111111111111111111111000000000000000000000000000000000000000000000000001111111111111111111111111
ccccccccccccc7776771677167716771111111111111111111111111111111111111111111111111111111110000000000000001111111111111111111111111
cccccccccccc77771711171117111711111111111111111111111111111111111111111111111111111111110000000000000001111111111111111111111111
cccccccccccc77771711171117111711111111111111111111111111111111111111111111111111111111110000000000000001111111111111111111111111
ccccccccccccc7770000000000000011111111111111111111111111111111171111111111111111111111110000000000000001161111111111111111111111
ccccccccccccc7770000000000000011111111111111111111111111111111111111111111111111111111110000000000000001111111111111111111111111
cccccccccccccc770000000000000011111111111111111111111111111111111111111111111111111111110000000000000000000000000000000000000000
cccccccccccccc770000000000000011111111111111111111111111111111111111111111111111111111110000000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccc77770000000000000000000000000111111111111111111111111111111111111111111111100000000000000000000000000000000000000000
cccccccccccc77770000000000000000000000000111111111111111111111111111111111111111111111100000000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000111111111111111111111111111111111111111111111100000000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000111111111111111111111111111111111111111111111100060000000000000000000000000000000000000
cccccccccccccc770000000000000000000000000111111111111111111111111111111111111111111111100000000000000000000000000000000000000000
cccccccccccccc770000000000000000000000000111111111111111111111111111111111111111111111100000000000000000000000000000000000000000
cccccccccccccc770000000000000000000000000111111111111111111111111111111111111111111111100000000000000000000000000000000000000000
ccccccccc77ccc770000000000000000000000000111111111111111111111111111111111111111111111100000000000000000000000000000000000000000
ccccccccc77ccc770000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccc77770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc777777750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccc77550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccc77667000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c77ccc77677770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011
c77ccc77666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000011
ccccc777550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000011
cccc7777667000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011
77777777677770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011
77777775666000000000000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000011
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000077777700000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000777777770000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000777777770000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000777733770000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000777733770000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000737733370000001111111111
555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007333bb370000001111111111
555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000333bb300000001111111111
55555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033333300000001111111111
50555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ee0ee003b333300000001111111111
55550055555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000eeeee0033333300000001111111111
555500555555000000000000000000000000000000000000000000000000000000111111111111111111111111111111111e8e111333b3300000001111111111
55555555555550000000000000000000000000000000000000000000000000000011111111111111111111111111b11111eeeee1113333000000001111111111
5505555555555500000000000000000000000000000000000000000000000000001111111111111111111111111b111111ee3ee1110440000000001111111111
5555555555555550000000000000000000000000000000000000000000000000001111111117111111111111131b11311111b111110440000000000000000111
5555555555555555000000000000000000000000000000000000000000000000001111111111111111111111131331311111b111119999000000000000000111
55555555555555550000000000000000077777700000000000000000000000000011111111111111511111115777777777777777777777755000000000000005
55555555555555500000000000000000777777770000000000000000000000000011111111111111551111117777777777777777777777775500000000000055
55555555555555000000000000000000777777770000000000000000000000000011111111111111555111117777ccccc777777ccccc77775550000000000555
5555555555555000000000000000000077773377111111111111111111111111111111111111111155551111777cccccccc77cccccccc7775555000000005555
555555555555000000000000000000007777337711111111111111111111111111111111111111115555511177cccccccccccccccccccc775555500000055555
555555555550000000000000000000007377333711111111111111111111111111111111111110005555550077cc77ccccccccccccc7cc775555550000555555
555555555500000000000000000000007333bb3711111111111111111111111111111111111110005555555077cc77cccccccccccccccc775555555005555555
555555555000000000000000000000000333bb3111111111111111111111111111111111111110005555555577cccccccccccccccccc66775555555555555555
555555555555555555555555000000000333333111111111111111111111111111111111111110055555555577ccccccccccccccc6cc66775555555555555555
5555555555555555555555500000000003b3333111111111111111111111111111111111111110555055555577cccccccccccccccccccc775555555550555555
555555555555555555555500000000300333333111111111111111111111111111111111111115555555005577cc7cccccccccccc77ccc775555555555550055
555555555555555555555000000000b00333b33111111111111111111111111111111111111155555555005577ccccccccccccccc77ccc775555555555550055
55555555555555555555000000000b3000333311111111111111111111111111111111111115555555555555777cccccccc77cccccccc7775555555555555555
55555555555555555550000003000b00000440000000000000000000000000000000000000555555550555557777ccccc777777ccccc77775555555555055555
55555555555555555500000000b0b300000440000000000000000000000000000000000005555555555555557777777777777777777777775555555555555555
55555555555555555000000000303300009999000000000000000000000000000000000055555555555555555777777777777777777777755555555555555555
55555555555555555777777777777777777777750000000000000000000000000000000555555555555555555555555500000000555555555555555555555555
55555555505555557777777777777777777777770000000088888880000000000000005550555555555555555555555000000000055555550555555555555555
55555555555500557777ccccc777777ccccc77770000000888888888000000300000055555550055555555555555550000000000005555550055555555555555
5555555555550055777cccccccc77cccccccc77700000008888ffff8000000b00000555555550055555555555555500000000000000555550005555555555555
555555555555555577cccccccccccccccccccc770000b00888f1ff1800000b300005555555555555555555555555000000000000000055550000555555555555
555555555505555577cc77ccccccccccccc7cc77000b000088fffff003000b000055555555055555555555555550000000000000000005550000055555555555
555555555555555577cc77cccccccccccccccc77131b11311833331000b0b3000555555555555555555555555500000000888800000000550000005555555555
555555555555575577cccccccccccccccccccc771313313111711710703033005555555555555555555555555000000008888880000000050000000555555555
7777777777777777cccccccccccccccccccccccc7777777777777777777777755555555555555555555555550000000008788880000000000000000055555555
7777777777777777cccccccccccccccccccccccc7777777777777777777777775555555555555555555555550000000008888880000000000000000055555550
c777777cc777777cccccccccccccccccccccccccc777777cc777777ccccc77775555555555555555555555550000000008888880000000000000000055555500
ccc77cccccc77cccccccccccccccccccccccccccccc77cccccc77cccccccc7775555555555555555555555550000000008888880000000000000000055555000
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc775555555555555555555555550000000000888800000000000000000055550000
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7cc775555555555555555555555550000000000006000000000000000000055500000
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc775555555555555555555555550000000000060000000000000000000055000000
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc775555555555555555555555550000000000060001111111111111111151111111
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc775555555555555555555555550000000000060001111111111111111111111111
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc775555555555555550555555500000000000060001111111111111111111111111
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc77ccc775500005555555500555555600000000000006001111111111111111111111111
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc77ccc775500005555555000555550000000000000006001111111111111111111111111
ccccccccccccccccccccccccccccccccccccccccccccccccccc77cccccccc7775500005555550000555500000000000000000001111111111111111111111111
cccccccccccccc7cccccccccccccccccccccccccccccccccc777777ccccc77775500005555500000555000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccccccccccccc77777777777777775555555555000000550000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccccccccccccc77777777777777755555555550000000500000000000000000000000007700000000000000000000
ccccccccccccccccccccccccccccccccccccccccc77ccc7700000000555555555555555500000000000000000000000000000000007700000000000000000000
ccccccccccccccccccccccccccccccccccccccccc77cc77700000000055555555555555000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccccccccccccccc77700000000005555555555550000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccccccccc777770000000000555555555500000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccccccccc777700000000000055555555000000000000000000000000000000000000000000000111111111111111
ccccccccccccccccccccccccccccccccccccccccccccc77700000000000005555550000000000000000000000000000000000000000000000111111111111111
ccccccccccccccccccccccccccccccccccccccccccccc77700000000000000555500000000000000000000000000000000000000000000000111111111111111
cccccccccccccccccccccccccccccccccccccccccccccc7700000000000000055000000000000000000000000000000000000000000000000111111111111111
cccccccccccccccccccccccccccccccccccccccccccccc7700000000000000000000000000000000000000000000000000000000000000000111111111111111
ccccccccccccccccccccccccccccccccccccccccccccc77700000000000000000000000000000000000000000000000000000000000000000111111111111111
ccccccccccccccccccccccccccccccccccccccccccccc77700000000000000000000000000000000000000000000000000006000000000000111111111111111
cccccccccccccccccccccccccccccccccccccccccccc777700000000000000000000000000000000000000000000000000000000000007000111111111111111
cccccccccccccccccccccccccccccccccccccccccccc777700000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccccccccccccccc77700000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccccccccccccccc77700000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccccccccccc7700000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000004040003080808000000000000000000030303030303030303030303040400000303030303030303030303030404000000000000000000000000000000000400000404040000040400000404040404040404040404040404040404040404040404040404040404040404040400000000
0404040404040404040404040400000004040404040404040404040404000000000000000000000404040400040404040000000000000004040404000404040400000000040404040000000004040404000000000404040400000000040404040000000000000000000000000000000000000000000000000000000000000000
__map__
3b3b2b3a26363772655777202938281328382933243a2a3a2a3a34575c5d675728282829393232242b3a2a2b34202928282933242a3a3b3b3b2b3a2a3420382900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b3a2b3536370000716557313229393829393325352a3a3a3a3537776c6d776728293839332526352a3636363731392939332536353a2a2b3a2a35363720293800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
36363636370000000071657762313239383325353a2a363636377265576267572939322526352a3a2b344d4c4cf03132330035363636362a353637212239383900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
372122238788898a00007172655767313325363635363764730000717265574e393025352b2a3a3636374c000000000000004d4cf1353536372122382938323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222939309798999a0000000071656457627735363762576300000000007165623233242a3a3636374b4ce0000000000000004c0000f200716567313232335c5d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
39382933a7a8a9aa00000000007165625c5d62776264727300000000000061572626353636374e634c000000000000000000e100000000007172655762676c6d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
29393372b7b8b9ba00000000000071656c6d62577763000000000000c4c5c6c72a2b36376277647300000000000000e00000000000000000000071657780818200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
393300000000000000000000000000716562676264732e00002f0000d4d5d6d73636375a5b5763000000000000000000000000000000000000e100616290919200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3363000000000000002f0000000000006157624e632e000000004400000061676762776a6b6263004a000000002f00000000000000000000000051756725262600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
576300000000002e000000000f0000006177676263002f002e000000005175627265577a7b676300000000002e003e002f00f100004d4c4cf251755725362b2a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67745358000009002f002e0000000000618081827453002e212223525275776700717265577774530000f02e00212300002f000000e1000000252626362a3a2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6257630000002527003e4041414141416190919257742122393829222383848500000071658b8c745225270000203822232e002e0025262626363a2a2b2b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5e5f630000253635272e502f002f003e252626274e772029291339293093949500000100619b9c1167243626273132293922232526362b2a2b3a3a2b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6e6f745301243a2b352750002f002e00242b2a35271120392813133930676262002122222222222325362a2b3626272029293024363a2a3b3b3b3b3b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2122222325363a3b2a36272222222222242a3a2a2427203813282838212362772229383929382933243a2b2a3a3634203938303536363a2b3b3b3b3b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20292526352a3b2a3739293839293938243a2a2b2b34203913281339293067622928282828383025362a3b3b2b2a3420293929222324363a2b3b3b3b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

