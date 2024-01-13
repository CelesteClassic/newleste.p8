pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
--core - celeste classic mod
--made by antibrain
--minimal penguins were harmed in the making of this mod

--~evercore~
--a celeste classic mod base
--v2.1.0

--original game by:
--maddy thorson + noel berry

--major project contributions by
--taco360, meep, gonengazit, and akliant

function vector(x,y)
  return {x=x,y=y}
end
function rectangle(x,y,w,h)
  return {x=x,y=y,w=w,h=h}
end
objects,got_fruit={},{}
freeze,delay_restart,sfx_timer,music_timer,ui_timer=0,0,0,0,-99
draw_x,draw_y,cam_x,cam_y,cam_spdx,cam_spdy,cam_gain=0,0,0,0,0,0,0.25
lava=true
lavaactive=true
ly=0
lvl_h=0
_pal=pal
lt=0
center=false
lavaspd=0.3
function _init()
frames,start_game_flash=0,0
music(40,0,7)
lvl_id=0
end
function begin_game()
max_djump=1
deaths,frames,seconds,minutes,music_timer,time_ticking,fruit_count,bg_col,cloud_col=0,0,0,0,0,true,0,0,1
music(0,0,7)
load_level(1)
end
function is_title()
return lvl_id==0
end
dead_particles={}
player={
  layer=2,
  init=function(this)
    this.outline=true
    this.grace,this.jbuffer=0,0
    this.djump=max_djump
    this.dash_time,this.dash_effect_time=0,0
    this.dash_target_x,this.dash_target_y=0,0
    this.dash_accel_x,this.dash_accel_y=0,0
    this.hitbox=rectangle(1,3,6,5)
    this.spr_off=0
    this.collides=true
    this.canslide=true
    create_hair(this)
  end,
  update=function(this)
    if pause_player then
      return
    end
    local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0
    if spikes_at(this.left(),this.top(),this.right(),this.bottom(),this.spd.x,this.spd.y) or (this.y>lvl_ph and center==false) then
      kill_player(this)
    elseif center then
      if this.y>lvl_ph+16 then
       this.y=-16
      end
    end
    if lavaactive=="true" then
     if this.y>ly-4 or this.y<ly-96 then
      kill_player(this)
     end
    elseif lavaactive=="up" then
     if this.y>ly-4 then
      kill_player(this)
     end 
    end
    local on_ground=this.is_solid(0,1)
    if on_ground and not this.was_on_ground then
      this.init_smoke(0,4)
    end
    local jump,dash=btn(🅾️) and not this.p_jump,btn(❎) and not this.p_dash
    this.p_jump,this.p_dash=btn(🅾️),btn(❎)
    if jump then
      this.jbuffer=4
    elseif this.jbuffer>0 then
      this.jbuffer-=1
    end
    if on_ground then
      this.grace=6
      if this.djump<max_djump and not(this.is_core(0,1)) then
        psfx"54"
        this.djump=max_djump
      end
    elseif this.grace>0 then
      this.grace-=1
    end
    this.dash_effect_time-=1
    if this.dash_time>0 then
      this.init_smoke()
      this.dash_time-=1
      this.spd=vector(appr(this.spd.x,this.dash_target_x,this.dash_accel_x),appr(this.spd.y,this.dash_target_y,this.dash_accel_y))
    else
      local maxrun=1
      local accel=(this.is_ice(0,1)or ((on_ground and lava==false))) and 0.05 or on_ground and 0.6 or 0.4
      local deccel=0.15
      this.spd.x=abs(this.spd.x)<=1 and
      appr(this.spd.x,h_input*maxrun,accel) or
      appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
      if this.spd.x~=0 then
        this.flip.x=this.spd.x<0
      end
      local maxfall=2
      if h_input~=0 and this.is_solid(h_input,0) and not(this.is_ice(h_input,0)) then
       if this.canslide==true then
        maxfall=0.4
        if rnd"20"<1 then
          this.init_smoke(h_input*6)
        end
       end
      end
      this.canslide=true
      if not on_ground then
       if not(center) then
        this.spd.y=appr(this.spd.y,maxfall,abs(this.spd.y)>0.15 and 0.21 or 0.105)
       else
        this.spd.y=appr(this.spd.y,0.5,abs(this.spd.y)>0.15 and 0.21 or 0.105)
       end
      end
      if center then
       this.spd.x=this.spd.x/1.5
      end
      if this.jbuffer>0 then
        if this.grace>0 then
          psfx"1"
          this.jbuffer=0
          this.grace=0
          this.spd.y=-2
          this.init_smoke(0,4)
        else
          local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
          if wall_dir~=0 then
            psfx"2"
            this.jbuffer=0
            this.spd=vector(wall_dir*(-1-maxrun),-2)
          end
        end
      end
      local d_full=5
      local d_half=3.5355339059
      if this.djump>0 and dash then
        this.djump-=1
        this.dash_time=4
        has_dashed=true
        this.dash_effect_time=10
        local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
        this.spd=vector(h_input~=0 and
          h_input*(v_input~=0 and d_half or d_full) or
          (v_input~=0 and 0 or this.flip.x and -1 or 1)
        ,v_input~=0 and v_input*(h_input~=0 and d_half or d_full) or 0)
        psfx"3"
        freeze=2
        this.dash_target_x=2*sign(this.spd.x)
        this.dash_target_y=(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y)
        this.dash_accel_x=this.spd.y==0 and 1.5 or 1.06066017177
        this.dash_accel_y=this.spd.x==0 and 1.5 or 1.06066017177
      elseif this.djump<=0 and dash then
        psfx"9"
      end
    end
    this.spr_off+=0.25
    this.spr = not on_ground and (this.is_solid(h_input,0) and 5 or 3) or
    btn(⬇️) and 6 or
    btn(⬆️) and 7 or
    this.spd.x~=0 and h_input~=0 and 1+this.spr_off%4 or 1
    update_hair(this)
    if this.x>(128*(lvl_w/16))-8 and levels[lvl_id+1] then
      next_level()
    end
    this.was_on_ground=on_ground
  end,
  draw=function(this)
    local clamped=mid(this.x,-1,lvl_pw-7)
    if this.x~=clamped and not(spawning) then
      this.x=clamped
      this.spd.x=0
    end
    set_hair_color(this.djump)
    if this.y>0 and this.y<lvl_ph then
     draw_hair(this)
    end
    draw_obj_sprite(this)
    pal()
  end
}
function create_hair(obj)
  obj.hair={}
  for i=1,5 do
    add(obj.hair,vector(obj.x,obj.y))
  end
end
function set_hair_color(djump)
  pal(2,djump==2 and 8 or 2)
  pal(8,djump==1 and 8 or djump==2 and 14 or 12)
end
function update_hair(obj)
  local last=vector(obj.x+4-(obj.flip.x and-2 or 3),obj.y+(btn(⬇️) and 4 or 2.9))
  for h in all(obj.hair) do
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    last=h
  end
end
function draw_hair(obj)
  for i,h in pairs(obj.hair) do
    circfill(round(h.x),round(h.y),mid(4-i,1,2),8)
  end
end
player_spawn={
  layer=2,
  init=function(this)
    this.outline=true
    sfx"4"
    this.spr=3
    this.targety=this.y
    this.targetx=this.x
    this.x=-16
    this.x=this.x-this.targetx/2
    cam_x,cam_y=mid(this.x,64,lvl_pw-64),mid(this.y,64,lvl_ph-64)
    this.spd.x=0
    this.spd.y=0
    this.state=0
    this.delay=0
    create_hair(this)
    this.djump=max_djump
    spawning=true
    this.fall=false
  end,
  update=function(this)
    update_hair(this)
    
    if this.state==0 and this.x<this.targetx+16 then
      this.state=1
      this.delay=0
    elseif this.state==1 then
      this.spd.x=3.5
      if this.x<this.targetx/2 then
       this.spd.y=-1
      else
       this.spd.y=3
      end
      if this.spd.x>0 then
        if this.delay>0 then
          this.spd.x=0
          this.delay-=1

        elseif this.x>this.targetx then
          this.x=this.targetx
          this.y=this.targety
          this.spd=vector(0,0)
          this.state=2
          this.delay=5
          this.init_smoke(0,4)
          sfx"5"
        end
      end
    elseif this.state==2 then
      this.delay-=1
      this.spr=6
      if this.delay<0 then
        destroy_object(this)
        init_object(player,this.x,this.y)
        spawning=false
      end
    end
  end,
  draw= player.draw
}
spring={
  init=function(this)
    this.outline=true
    this.hide_in=0
    this.hide_for=0
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for<=0 then
        this.spr=18
        this.delay=0
      end
    elseif this.spr==18 then
      local hit=this.player_here()
      if hit and hit.spd.y>=0 then
        this.spr=19
        hit.y=this.y-4
        hit.spd.x*=0.2
        hit.spd.y=-3
        this.delay=10
        this.init_smoke()
        break_fall_floor(this.check(fall_floor,0,1) or {})
        psfx"8"
      end
    elseif this.delay>0 then
      this.delay-=1
      if this.delay<=0 then
        this.spr=18
      end
    end
    if this.hide_in>0 then
      this.hide_in-=1
      if this.hide_in<=0 then
        this.hide_for=60
        this.spr=221
      end
    end
  end
}
balloon={
  init=function(this)
    this.outline=true
    this.offset=0
    this.start=this.y
    this.timer=0
    this.hitbox=rectangle(-1,-1,10,10)
  end,
  update=function(this)
    if this.spr==22 then
      this.offset+=0.01
      this.y=this.start+sin(this.offset)*2
      local hit=this.player_here()
      if hit and hit.djump<max_djump then
        psfx"6"
        this.init_smoke()
        hit.djump=max_djump
        this.spr=14
        this.timer=60
      end
    elseif this.timer>0 then
      this.timer-=1
    else
      psfx"7"
      this.init_smoke()
      this.spr=22
    end
  end,
  draw=function(this)
   draw_obj_sprite(this)
  end
}
fall_floor={
  init=function(this)
    this.solid_obj=true
    this.state=0
  end,
  update=function(this)
    if this.state==0 then
      for i=0,2 do
        if this.check(player,i-1,-(i%2)) then
          break_fall_floor(this)
        end
      end
    elseif this.state==1 then
      this.delay-=1
      if this.delay<=0 then
        this.state=2
        this.delay=60
        this.collideable=false
      end
    elseif this.state==2 then
      this.delay-=1
      if this.delay<=0 and not this.player_here() then
        psfx"7"
        this.state=0
        this.collideable=true
        this.init_smoke()
      end
    end
  end,
  draw=function(this)
    spr(this.state==1 and 26-this.delay/5 or this.state==0 and 23,this.x,this.y)
  end
}
function break_fall_floor(obj)
  if obj.state==0 then
    psfx"15"
    obj.state=1
    obj.delay=15
    obj.init_smoke();
    (obj.check(spring,0,-1) or {}).hide_in=15
  end
end
smoke={
  layer=3,
  init=function(this)
    this.spd=vector(0.3+rnd"0.2",-0.1)
    this.x+=-1+rnd"2"
    this.y+=-1+rnd"2"
    this.flip=vector(rnd()<0.5,rnd()<0.5)
  end,
  update=function(this)
    this.spr+=0.2
    if this.spr>=32 then
      destroy_object(this)
    end
  end
}
fruit={
  check_fruit=true,
  init=function(this)
    if fget(tile_at(0,-1),6)==false then
     this.y-=3.5
    end
    this.outline=true
    this.start=this.y
    this.off=0
  end,
  update=function(this)
    check_fruit(this)
    this.off+=0.025
    this.y=this.start+sin(this.off)*2.5
  end
}
fly_fruit={
  check_fruit=true,
  init=function(this)
    this.outline=true
    this.start=this.y
    this.step=0.5
    this.sfx_delay=8
  end,
  update=function(this)
    if has_dashed then
      if this.sfx_delay>0 then
        this.sfx_delay-=1
        if this.sfx_delay<=0 then
          sfx_timer=20
          sfx"14"
        end
      end
      this.spd.y=appr(this.spd.y,-3.5,0.25)
      if this.y<-16 then
        destroy_object(this)
      end
    else
      this.step+=0.05
      this.spd.y=sin(this.step)*0.5
    end
    check_fruit(this)
  end,
  draw=function(this)
    spr(26,this.x,this.y)
    for ox=-6,6,12 do
      spr((has_dashed or sin(this.step)>=0) and 45 or this.y>this.start and 47 or 46,this.x+ox,this.y-2,1,1,ox==-6)
    end
  end
}
function check_fruit(this)
  local hit=this.player_here()
  if hit then
    hit.djump=max_djump
    sfx_timer=20
    sfx"13"
    got_fruit[this.fruit_id]=true
    init_object(lifeup,this.x,this.y)
    destroy_object(this)
    if time_ticking then
      fruit_count+=1
    end
  end
end
lifeup={
  init=function(this)
    this.spd.y=-0.25
    this.duration=30
    this.flash=0
  end,
  update=function(this)
    this.duration-=1
    if this.duration<=0 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    this.flash+=0.5
    ?"1000",this.x-4,this.y-4,7+this.flash%2
  end
}
switchoff={
 init=function(this)
  this.outline=true
  this.solid_obj=false
  this.hitbox=rectangle(0,0,8,8)
  this.active=true
  this.x+=4
 end,
 update=function(this)
  hit=this.player_here()
  if hit and this.active then
   lava=false 
   this.active=false
      psfx"63"

  end
  if lava then
   this.active=true
  else
   this.active=false
  end
 end,
 draw=function(this)
  pal()
  if this.active then
   spr(28,this.x,this.y)
  else
   spr(60,this.x,this.y)
  end
 end
}
switchon={
 init=function(this)
  this.outline=true
  this.solid_obj=false
  this.hitbox=rectangle(0,0,8,8)
  this.active=true
  this.x+=4
 end,
 update=function(this)
  hit=this.player_here()
  if hit and this.active and lava==false then
   lava=true
   this.active=false
   psfx"63"
  end
  if lava==false then
   this.active=true
  else
   this.active=false
  end
 end,
 draw=function(this)
  pal()
  if this.active then
   spr(44,this.x,this.y)
  else
   spr(61,this.x,this.y)
  end
 end
}
launch={
init=function(this)
 this.segments={}
 add(this.segments,{x=this.x,y=this.y,s=85})
 this.checkx=8
 this.checky=0
 this.c=true
 this.cd=true
 this.solid_obj=true
 this.maxcheckx=0
 this.maxchecky=0
 this.q=0
 this.hide=false
 this.hide_for=0
 this.ox=this.x
 this.oy=this.y
 this.h=0
 this.e="0"
 this.shatter=false
end,
update=function(this)
if this.c==true then
 if tile_at(
 (this.x+this.checkx)/8,
 (this.y+this.checky)/8)==101 then
  add(this.segments,
  {x=this.x+this.checkx,
  y=this.y+this.checky,
  s=tile_at(
  (this.x+this.checkx)/8,
  (this.y+this.checky)/8),
  fx=false,
  fy=false})
  this.checkx+=8
 else
  this.maxcheckx=this.checkx
  this.maxchecky=this.segments[#this.segments].y
  this.checky+=8
  this.checkx=0
  if tile_at((this.x+this.checkx)/8,(this.y+this.checky)/8)!=101 then
   this.c=false
   this.hitbox=rectangle(
   0,
   0,
   this.maxcheckx,
   this.checky)
  end
 end
elseif this.cd==true then 
 for i in all(this.segments) do
  if i.x==this.segments[#this.segments].x then
   i.fx=true
   if i.y==this.y then
    i.s=85
   end
  end
  if i.x==this.x and i.y>this.y then
   i.s=36
  end
  if i.y==this.segments[#this.segments].y then
   i.fy=true
   if i.x==this.segments[#this.segments].x or i.x==this.x then
    i.s=85
   end
  end
  i.ox=i.x
  i.oy=i.y
  this.x=this.ox
  this.y=this.oy
 end
 this.cd=false
end
if this.hide==false and lava then 
   this.hitbox=rectangle(
   -1,
   -1,
   this.maxcheckx+2,
   this.checky)
 hit=this.player_here()
if hit and not this.hide then
this.q+=0.0333
if this.q<0.5 then
 for i in all(this.segments) do
  i.y+=this.q
 end
 this.y+=this.q
 hit.y+=this.q
elseif this.q>0 then
 this.q-=2
end
 this.h+=1
if this.h>20 then
 psfx"8"
 hit.spd=vector(hit.spd.x,-3.14)
 this.hide=true
 this.hide_for=80
 this.h=0
 this.q=0
end
end
   this.hitbox=rectangle(
   0,
   0,
   this.maxcheckx,
   this.checky)
elseif not this.hide then
   this.hitbox=rectangle(
   -1,
   -1,
   this.maxcheckx+2,
   this.checky)
   hit=this.player_here()
if hit then
 this.shatter=true
end
if this.shatter then
psfx"15"
this.q+=0.03
if this.q<0.5 then
 for i in all(this.segments) do
  i.y+=this.q
 end
 this.y+=this.q
if hit then
 hit.y+=this.q
end
elseif this.q>0 then
end
 this.h+=1
if this.h>20 then
 this.hide=true
 this.hide_for=80
 this.h=0
 this.q=0
end
end
   this.hitbox=rectangle(
   0,
   0,
   this.maxcheckx,
   this.checky)
end
if this.hide==false then
this.outline=false
end
if this.hide==true then
this.outline=true
this.hitbox=rectangle(0,0,this.maxcheckx,this.checky)
this.solid_obj=false
this.hide_for-=1
hit=this.player_here()
if this.hide_for<=0 then
 this.hide_for=0
 for i in all(this.segments) do
  this.init_smoke(0,0)
 end
 this.hide=false
 this.solid_obj=true
 for i in all(this.segments) do
  i.x=i.ox
  i.y=i.oy
 end
  this.x=this.ox
  this.y=this.oy
  this.shatter=false
end
end
if not hit and this.cd==false then
if this.shatter==false or this.hide==true then
 this.x=this.ox
 this.y=this.oy
 for i in all(this.segments) do
  i.x=i.ox
  i.y=i.oy
 end
 this.q=0
 this.h=0
end
end
if lava==true then
 this.shatter=false
end
end,

draw=function(this)
if this.hide==false then 
 if this.cd==false then
  pal(2,1)
  pal(8,13)
  pal(11,8)
  pal(3,2)
  for i in all(this.segments) do
   if i.y>this.y and i.y<this.segments[#this.segments].y then
    spr(38,this.segments[#this.segments].x,i.y)
   end
   spr(i.s,i.x,i.y,1,1,i.fx,i.fy)
   rectfill(this.x+8,this.y+8,this.segments[#this.segments].x-1,this.segments[#this.segments].y-1,2)
   if lava==false then
    pal(11,12)
    pal(3,1)
   end
   spr(21,(this.x+this.segments[#this.segments].x)/2,(this.y+this.segments[#this.segments].y)/2)
  end
  pal()
 end
elseif this.player_here() then
 rect(this.x-1,this.y-1,this.segments[#this.segments].x+8,this.segments[#this.segments].y+8,6)
end
end
}
bubble={
init=function(this)
 this.outline=true
 this.hitbox=rectangle(2,5,10,12)
 this.hide=false
end,
update=function(this)
 if lava==false then
  this.hitbox=rectangle(2,5,10,12)
 elseif lava==true then
  this.hitbox=rectangle(4,4,12,12)
 end
 hit=this.player_here()
 if hit and lava==true then
  kill_player(hit)
 end
 if this.hide==false and lava==false then
 if hit and hit.y<this.y+3 then
  if btn(🅾️) then
   hit.spd=vector(hit.spd.x,-2)
   psfx"1"
  else
   psfx"2"
   hit.spd=vector(hit.spd.x,-1.3)
  end
  this.hide=true
  for ox=1,8,2 do
   this.init_smoke(ox,2)
  end
 elseif hit then
  kill_player(hit) 
 end
 end
 if this.spr==65 then
  this.y-=0.3
 elseif this.spr==81 then
  this.y+=0.3
 elseif this.spr==97 then
  this.x-=0.3
 elseif this.spr==113 then
  this.x+=0.3
 end
if this.spr==81 or this.spr==65 then
 if this.y<-16 then
  this.y=lvl_h*8
  this.hide=false
 end
 if this.y>lvl_h*8 then
  this.y=-16
  this.hide=false
 end
end
if this.spr==97 or this.spr==113 then
 if this.x<-16 then
  this.x=lvl_w*8
  this.hide=false
 end
 if this.x>lvl_w*8 then
  this.x=-16
  this.hide=false
 end
end
end,
draw=function(this)
  if this.hide==false and lava==false then--draw sprs
    sspr(8,32,8,16,this.x,this.y)
    sspr(8,32,8,16,this.x+8,this.y,8,16,true)
  elseif this.hide==false and lava==true then
    sspr(8,48,8,16,this.x,this.y)
    sspr(8,48,8,16,this.x+8,this.y,8,16,true,true)
  end
end
}
booster={
 init=function(this)
  this.outline=true
  this.solid_obj=false
  this.hitbox=rectangle(5,0,3,9)
  this.s=104
  this.q=0
  this.f=false
  this.off=0
  this.off2=0
 end,
 update=function(this)
  if this.spr==120 then
   this.f=true
   this.hitbox=rectangle(-1,0,3,9)
  end
  hit=this.player_here()
  if hit and lava==true then
   if hit.spd.y>-2 then
    hit.spd=vector(hit.spd.x,-abs(hit.spd.y)-0.4)
   end
  end
  if hit and lava==false then
   hit.canslide=false
  end
  if lava==true then
   this.off+=1.2
   if this.off>8 then this.off=0 end
  end
  this.off2+=0.5
  if this.off2>2 then this.off2=0 end
 end,
 draw=function(this)
  if lava==true then
   sspr(64,48+this.off,8,8,this.x,this.y,8,8,this.f)
   if this.off2==0 then
    pal(2,8)
   end
   if tile_at(this.x/8,(this.y/8)-1)!=this.spr then
    spr(119,this.x,this.y,1,1,this.f)
   end
   if tile_at(this.x/8,(this.y/8)+1)!=this.spr then
    spr(119,this.x,this.y+4,1,1,this.f)
   end
   pal()
  else
   spr(103,this.x,this.y,1,1,this.f)
   if tile_at(this.x/8,(this.y/8)-1)!=this.spr then
    sspr(48,56,8,3,this.x,this.y,8,3,this.f)
   end
   if tile_at(this.x/8,(this.y/8)+1)!=this.spr then
    sspr(48,61,8,3,this.x,this.y+5,8,3,this.f)
   end
  end
 end
}
bumper={
  init=function(this)
    this.outline=true
    this.solid_obj=false
    this.hitbox=rectangle(0,0,16,16)
    this.sy=32
    this.is_active=true
    this.eep=0
    this.j,this.q=0,0
    this.startx=this.x
    this.starty=this.y
    this.off=0
    this.off2=0
    this.offj=0.01
    this.offmul=rnd"1"
    if flr(rnd"2")==0 then
     this.offj=-this.offj
    end
  end,
  update=function(this)
    this.off+=this.offj
    this.off2+=this.offj*3
    this.x=this.startx+sin(this.off2)*1.1+this.offmul
    this.y=this.starty+cos(this.off)*1.2+this.offmul
    this.midx=this.x+8
    this.midy=this.y+8
    this.hitbox=rectangle(-1,-1,18,18)
    local hit=this.player_here()
    if hit and lava==false and this.is_active==true then         
     hit.grace=0 
     if hit.x>this.midx then
      hit.spd=vector(0.6*(hit.x-(this.x+8)),hit.spd.y)
     end
     if hit.x<this.midx then
      hit.spd=vector(0.6*(hit.x-(this.x)),hit.spd.y)
     end
     if hit.y<this.midy then
      hit.spd=vector(hit.spd.x,0.4*(hit.y-(this.y)))
     end
     if hit.y>this.midy then
      hit.spd=vector(hit.spd.x,0.1*(hit.y-(this.y-8)))
     end
     sfx"9"
     this.is_active=false
     this.eep=30
    end
    if lava==true and hit then
     kill_player(hit)
    end
    if lava==true then
     this.sy=72
     this.is_active=true
    elseif this.is_active==true then
     this.sy=64
    end
    if this.is_active==false then
     this.sy=80
     this.eep-=1
    end
    if this.eep<=0 and lava==false then
     this.is_active=true
     this.sy=64
     this.q=0
     this.j=0
    end
    if this.j>2 then this.j=0 end
    this.hitbox=rectangle(3,3,13,13)
  end,
  draw=function(this)
    sspr(this.sy,16,8,16,this.x,this.y)
    sspr(this.sy,16,8,16,this.x+8,this.y,8,16,true)
    if this.is_active==false and this.q<15 then
     circ(this.x+7,this.y+7,10+this.j,12)
     circ(this.x+8,this.y+7,10+this.j,12)
     circ(this.x+7,this.y+8,10+this.j,12)
     circ(this.x+8,this.y+8,10+this.j,12)
     this.q+=5
     this.j+=1
    end
  end
}
lavawall={
init=function(this)
 this.outline=true
end,
update=function(this)
 hit=this.player_here()
 if lava==true and hit then
  kill_player(hit)
 end
end,
draw=function(this)
 if lava==true then
  spr(this.spr,this.x,this.y)
 end
end
}
icewall={
init=function(this)
 this.outline=true
end,
update=function(this)
 hit=this.player_here()
 if lava==false and hit then
  kill_player(hit)
 end
end,
draw=function(this)
 if lava==false then
  spr(this.spr,this.x,this.y)
 end
end
}
function init_fruit(this,ox,oy)
  sfx_timer=20
  sfx"16"
  init_object(fruit,this.x+ox,this.y+oy,26).fruit_id=this.fruit_id
  destroy_object(this)
end
key={
  init=function(this)
   this.outline=true
  end,
  update=function(this)
    this.spr=flr(9.5+sin(frames/30))
    if frames==18 then
      this.flip.x=not this.flip.x
    end
    if this.player_here() then
      sfx"23"
      sfx_timer=10
      destroy_object(this)
      has_key=true
    end
  end
}
chest={
  check_fruit=true,
  init=function(this)
    this.outline=true
    this.x-=4
    this.start=this.x
    this.timer=20
  end,
  update=function(this)
    if has_key then
      this.timer-=1
      this.x=this.start-1+rnd"3"
      if this.timer<=0 then
        init_fruit(this,0,-4)
      end
    end
  end
}
big_chest={
  init=function(this)
    this.outline=true
    this.state=max_djump>1 and 2 or 0
    this.hitbox.w=16
  end,
  update=function(this)
    if this.state==0 then
      local hit=this.check(player,0,8)
      if hit and hit.is_solid(0,1) then
        music(-1,500,7)
        sfx"37"
        pause_player=true
        hit.spd=vector(0,0)
        this.state=1
        this.init_smoke()
        this.init_smoke(8)
        this.timer=60
        this.particles={}
      end
    elseif this.state==1 then
      this.timer-=1
      flash_bg=true
      if this.timer<=45 and #this.particles<50 then
        add(this.particles,{
          x=1+rnd"14",
          y=0,
          h=32+rnd"32",
        spd=8+rnd"8"})
      end
      if this.timer<0 then
        this.state=2
        this.particles={}
        flash_bg,bg_col,cloud_col=false,5,14
        init_object(orb,this.x+4,this.y+4,102)
        pause_player=false
      end
    end
  end,
  draw=function(this)
    if this.state==0 then
      draw_obj_sprite(this)
      spr(96,this.x+8,this.y,1,1,true)
    elseif this.state==1 then
      foreach(this.particles,function(p)
        p.y+=p.spd
        line(this.x+p.x,this.y+8-p.y,this.x+p.x,min(this.y+8-p.y+p.h,this.y+8),7)
      end)
    end
    spr(112,this.x,this.y+8)
    spr(112,this.x+8,this.y+8,1,1,true)
  end
}
orb={
  init=function(this)
    this.outline=true
    this.spd.y=-4
  end,
  update=function(this)
    this.spd.y=appr(this.spd.y,0,0.5)
    local hit=this.player_here()
    if this.spd.y==0 and hit then
      music_timer=45
      sfx"51"
      freeze=10
      destroy_object(this)
      max_djump=2
      hit.djump=2
    end
  end,
  draw=function(this)
    draw_obj_sprite(this)
    for i=0,0.875,0.125 do
      circfill(this.x+4+cos(frames/30+i)*8,this.y+4+sin(frames/30+i)*8,1,7)
    end
  end
}
flag={
  init=function(this)
   this.offset=rnd()
   this.outline=true
   this.start=this.y
   this.e=false
   this.solid_obj=false
   this.hitbox=rectangle(0,0,16,16)
   this.hide=false
  end,
  update=function(this)
    this.midx=this.x+8
    this.midy=this.y+8
    hit=this.player_here()    
    if hit and this.hide==false then
     if hit.x>this.midx then
      hit.spd=vector(0.3*(hit.x-(this.x+8)),hit.spd.y)
     end
     if hit.x<this.midx then
      hit.spd=vector(0.3*(hit.x-(this.x)),hit.spd.y)
     end
     if hit.y<this.midy then
      hit.spd=vector(hit.spd.x,0.2*(hit.y-(this.y)))
     end
     if hit.y>this.midy then
      hit.spd=vector(hit.spd.x,0.05*(hit.y-(this.y-8)))
     end         
    end
    if hit and hit.dash_effect_time>0 then
     this.e=true
     for ox=0,8,8 do
      for oy=0,8,8 do
       this.init_smoke(ox,oy)
      end
     end
     this.hide=true
    end
    if not this.show and this.e then
      sfx"55"
      sfx_timer,this.show,time_ticking=30,true,false
    end
      this.offset+=0.01
      this.y=this.start+sin(this.offset)*2
  end,
  draw=function(this)
   if this.hide==false then
    sspr(64,32,8,16,this.x,this.y)
    sspr(64,32,8,16,this.x+8,this.y,8,16,true)
   end
    if this.show then
      pal()
      camera()
      rectfill(32,2,96,31,0)
      spr(26,55,6)
      ?"x"..fruit_count,64,9,7
      draw_time(49,16)
      ?"deaths:"..deaths,48,24,7
      camera(draw_x,draw_y)
    end
  end
}
function psfx(num)
  if sfx_timer<=0 then
    sfx(num)
  end
end
tiles={}
foreach(split([[
1,player_spawn
8,key
18,spring
20,chest
22,balloon
81,bubble
85,launch
28,switchoff
44,switchon
23,fall_floor
26,fruit
45,fly_fruit
86,message
96,big_chest
40,bumper
104,booster
120,booster
65,bubble
97,bubble
113,bubble
72,flag
13,lavawall
15,icewall
]],"\n"),function(t)
 local tile,obj=unpack(split(t))
 tiles[tile]=_ENV[obj]
end)
function init_object(type,x,y,tile)
  local id=x..","..y..","..lvl_id
  if type.check_fruit and got_fruit[id] then
    return
  end
  local obj={
    type=type,
    collideable=true,
    spr=tile,
    flip=vector(),
    x=x,
    y=y,
    hitbox=rectangle(0,0,8,8),
    spd=vector(0,0),
    rem=vector(0,0),
    fruit_id=id,
  }
  function obj.left() return obj.x+obj.hitbox.x end
  function obj.right() return obj.left()+obj.hitbox.w-1 end
  function obj.top() return obj.y+obj.hitbox.y end
  function obj.bottom() return obj.top()+obj.hitbox.h-1 end
  function obj.is_solid(ox,oy)
    for o in all(objects) do
      if o!=obj and (o.solid_obj or o.semisolid_obj and not obj.objcollide(o,ox,0) and oy>0) and obj.objcollide(o,ox,oy) then
        return true
      end
    end
    return obj.is_flag(ox,oy,0)
  end
  function obj.is_core(ox,oy)
   for o in all(objects) do
     if o!=obj and (o.solid_obj or o.semisolid_obj and not obj.objcollide(o,ox,0) and oy>0) and obj.objcollide(o,ox,oy) then
       return true
     end
   end
   return obj.is_flag(ox,oy,6)
  end
  function obj.is_ice(ox,oy)
    return obj.is_flag(ox,oy,4)
  end
  function obj.is_flag(ox,oy,flag)
    for i=max(0,(obj.left()+ox)\8),min(lvl_w-1,(obj.right()+ox)/8) do
      for j=max(0,(obj.top()+oy)\8),min(lvl_h-1,(obj.bottom()+oy)/8) do
        if fget(tile_at(i,j),flag) then
          return true
        end
      end
    end
  end
  function obj.objcollide(other,ox,oy)
    return other.collideable and
    other.right()>=obj.left()+ox and
    other.bottom()>=obj.top()+oy and
    other.left()<=obj.right()+ox and
    other.top()<=obj.bottom()+oy
  end
  function obj.check(type,ox,oy)
    for other in all(objects) do
      if other and other.type==type and other~=obj and obj.objcollide(other,ox,oy) then
        return other
      end
    end
  end
  function obj.player_here()
    return obj.check(player,0,0)
  end
  function obj.move(ox,oy,start)
    for axis in all{"x","y"} do
      obj.rem[axis]+=axis=="x" and ox or oy
      local amt=round(obj.rem[axis])
      obj.rem[axis]-=amt
      local upmoving=axis=="y" and amt<0
      local riding=not obj.player_here() and obj.check(player,0,upmoving and amt or -1)
      local movamt
      if obj.collides then
        local step=sign(amt)
        local d=axis=="x" and step or 0
        local p=obj[axis]
        for i=start,abs(amt) do
          if not obj.is_solid(d,step-d) then
            obj[axis]+=step
          else
            obj.spd[axis],obj.rem[axis]=0,0
            break
          end
        end
        movamt=obj[axis]-p
      else
        movamt=amt
        if (obj.solid_obj or obj.semisolid_obj) and upmoving and riding then
          movamt+=obj.top()-riding.bottom()-1
          local hamt=round(riding.spd.y+riding.rem.y)
          hamt+=sign(hamt)
          if movamt<hamt then
            riding.spd.y=max(riding.spd.y,0)
          else
            movamt=0
          end
        end
        obj[axis]+=amt
      end
      if (obj.solid_obj or obj.semisolid_obj) and obj.collideable then
        obj.collideable=false
        local hit=obj.player_here()
        if hit and obj.solid_obj then
          hit.move(axis=="x" and (amt>0 and obj.right()+1-hit.left() or amt<0 and obj.left()-hit.right()-1) or 0,
                  axis=="y" and (amt>0 and obj.bottom()+1-hit.top() or amt<0 and obj.top()-hit.bottom()-1) or 0,
                  1)
          if obj.player_here() then
            kill_player(hit)
          end
        elseif riding then
          riding.move(axis=="x" and movamt or 0, axis=="y" and movamt or 0,1)
        end
        obj.collideable=true
      end
    end
  end
  function obj.init_smoke(ox,oy)
    init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),29)
  end
  add(objects,obj);
  (obj.type.init or stat)(obj)
  return obj
end
function destroy_object(obj)
  del(objects,obj)
end
function kill_player(obj)
  sfx_timer=12
  sfx"0"
  deaths+=1
  destroy_object(obj)
  for dir=0,0.875,0.125 do
    add(dead_particles,{
      x=obj.x+4,
      y=obj.y+4,
      t=2,
      dx=sin(dir)*3,
      dy=cos(dir)*3
    })
  end
  delay_restart=15
end
function move_camera(obj)
  cam_spdx=cam_gain*(4+obj.x-cam_x)
  cam_spdy=cam_gain*(4+obj.y-cam_y)
  cam_x+=cam_spdx
  cam_y+=cam_spdy
  local clamped=mid(cam_x,64,lvl_pw-64)
  if cam_x~=clamped then
    cam_spdx=0
    cam_x=clamped
  end
  clamped=mid(cam_y,64,lvl_ph-64)
  if cam_y~=clamped then
    cam_spdy=0
    cam_y=clamped
  end
end
function next_level()
  local next_lvl=lvl_id+1
  if music_switches[next_lvl] then
    music(music_switches[next_lvl],500,7)
  end
  load_level(next_lvl)
end
function load_level(id)
  has_dashed,has_key= false
  foreach(objects,destroy_object)
  cam_spdx,cam_spdy=0,0
  local diff_level=lvl_id~=id
  lvl_id=id
  local tbl=split(levels[lvl_id])
  for i=1,4 do
    _ENV[split"lvl_x,lvl_y,lvl_w,lvl_h"[i]]=tbl[i]*16
  end
  lvl_title=tbl[5]
  lvl_pw,lvl_ph=lvl_w*8,lvl_h*8
  lvl_li=tbl[6]
  bg_col=tbl[8]
  lavaspd=tonum(tbl[9])
  if tbl[10]==nil then
   center=false
  else
   center=tbl[10]
  end
    ui_timer=5
  if diff_level then
    reload()
    if mapdata[lvl_id] then
      replace_mapdata(lvl_x,lvl_y,lvl_w,lvl_h,mapdata[lvl_id])
    end
  end
  lavaactive=lvl_li
  if tbl[7]=="lava" then
   lava=true
  else
   lava=false
  end
  ly=lvl_h*8
  for tx=0,lvl_w-1 do
    for ty=0,lvl_h-1 do
      local tile=tile_at(tx,ty)
      if tiles[tile] then
        init_object(tiles[tile],tx*8,ty*8,tile)
      end
    end
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
  if music_timer>0 then
    music_timer-=1
    if music_timer<=0 then
      music(10,0,7)
    end
  end
  if sfx_timer>0 then
    sfx_timer-=1
  end
  if freeze>0 then
    freeze-=1
    return
  end
  if delay_restart>0 then
    cam_spdx,cam_spdy=0,0
    delay_restart-=1
    if delay_restart==0 then
      load_level(lvl_id)
    end
  end
  foreach(objects,function(obj)
    obj.move(obj.spd.x,obj.spd.y,0);
    (obj.type.update or stat)(obj)
  end)
  foreach(objects,function(obj)
    if obj.type==player or obj.type==player_spawn then
      move_camera(obj)
    end
  end)
  if lavaactive=="true" then
   if lava==true then
    ly-=lavaspd
   else
    ly+=lavaspd
   end
  elseif lavaactive=="up" then
   if lava==true then
    ly-=lavaspd
    if cam_y+64<ly then ly-=lavaspd*4.2 end
   else
    ly-=lavaspd-0.1
    if cam_y+64<ly then ly-=lavaspd*3.9 end
   end
  else
   ly=lvl_h*8
  end
  if is_title() then
    if start_game then
      start_game_flash-=1
      if start_game_flash<=-30 then
        begin_game()
      end
    elseif btn(🅾️) or btn(❎) then
      music"-1"
      start_game_flash,start_game=50,true
      sfx"38"
    end
  end
end
function _draw()
  if freeze>0 then
    return
  end
  if lava==false then
   pal(8,12)
   pal(5,1)
   pal(6,1)
  else
   pal()
  end
  if is_title() then
    if start_game then
    	for i=1,15 do
        pal(i, start_game_flash<=10 and ceil(max(start_game_flash)/5) or frames%10<5 and 7 or i)
    	end
    end
    cls()
    sspr(unpack(split"72,32,56,32,36,32"))
    ?"🅾️/❎",55,80,5
    ?"maddy thorson",40,96,5
    ?"noel berry",46,102,5
    ?"mod made by antibrain",24,108,5
    return
  end
  cls(flash_bg and frames/5 or bg_col)
  draw_x=round(cam_x)-64
  draw_y=round(cam_y)-64
  camera(draw_x,draw_y)
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)
  for i=0,15 do pal(i,1) end
  pal=stat
  foreach(objects,function(o)
    if o.outline then
      for dx=-1,1 do for dy=-1,1 do if dx==0 or dy==0 then
        camera(draw_x+dx,draw_y+dy) draw_object(o)
      end end end
    end
  end)
  pal=_pal
  camera(draw_x,draw_y)
  pal()
  local layers={{},{},{}}
  foreach(objects,function(o)
    if o.type.layer==0 then
      draw_object(o) --draw below terrain
    else
      add(layers[o.type.layer or 1],o) --add object to layer, default draw below player
    end
  end)
  if lava==false then
   pal(8,12)
   pal(2,1)
  end
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
  pal()
    foreach(layers,function(l)
    foreach(l,draw_object)
  end)
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,0x8)
  if lavaactive=="true" then
   lt+=lavaspd
   if lt>=8 then lt=0 end
   for x=-8,136,8 do
     local qz=sin(x/100)*2
     local lyc=ly+qz
    if lava==true then
     spr(63,x+(cam_x-64)-lt,lyc)
     spr(63,x+(cam_x-64)+lt,lyc-97,1,1,true,true)
    else
     spr(62,x+(cam_x-64),ly+qz)
     spr(62,x+(cam_x-64),ly+qz-97,1,1,true,true)
    end
   end
   if lava==true then
    rectfill(cam_x-64,ly+6,cam_x+64,cam_y+64,8)
    rectfill(cam_x-64,ly-96,cam_x+64,cam_y-65,8)
   else
    rectfill(cam_x-64,ly+6,cam_x+64,cam_y+65,12)
    rectfill(cam_x-64,ly-96,cam_x+64,cam_y-65,12)
   end
   for x=0,128,6 do
    if lava==true then
  
    end
   end
  end
  if lavaactive=="up" then
   lt+=lavaspd
   if lt>=8 then lt=0 end
   for x=-8,136,8 do
     local qz=sin(x/100)*2
     local lyc=ly+qz
    if lava==true then
     spr(63,x+(cam_x-64)-lt,lyc)
    else
     spr(62,x+(cam_x-64),ly+qz)
    end
   end
   if lava==true then
    rectfill(cam_x-64,ly+6,cam_x+64,cam_y+65,8)
   else
    rectfill(cam_x-64,ly+6,cam_x+64,cam_y+65,12)
   end
  end
  for x=0,128,6 do
    local cx=cam_x-64
    local cy=cam_y-64
    local qz=sin(x/100)*2
    local lyc=ly+qz
   if lava==true then
    circ(x+rnd"2"+2+cx,lyc+7+rnd"2",1,9)
    circ(x+rnd"2"+5+cx,lyc+5+rnd"2",1,9)
   else
    circ(x+2+cx,(ly+qz)+7,1,1)
    circ(x+5+cx,(ly+qz)+5,1,1)
   end
   if lavaactive=="true" then
    if lava==true then
     circ(x+rnd"2"+2+cx,lyc+rnd"2"-96,1,9)
     circ(x+rnd"2"+5+cx,lyc+rnd"2"-98,1,9)
    else
     circ(x+2+cx,(ly+qz)-96,1,1)
     circ(x+5+cx,(ly+qz)-98,1,1)
    end
   end
  end
  foreach(dead_particles,function(p)
    p.x+=p.dx
    p.y+=p.dy
    p.t-=0.2
    if p.t<=0 then
      del(dead_particles,p)
    end
    rectfill(p.x-p.t,p.y-p.t,p.x+p.t,p.y+p.t,14+5*p.t%2)
  end)
  camera()
  if ui_timer>=-30 then
    if ui_timer<0 then
      draw_ui()
    end
    ui_timer-=1
  end
end
function draw_object(obj)
  (obj.type.draw or draw_obj_sprite)(obj)
end
function draw_obj_sprite(obj)
  spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
end
function draw_time(x,y)
  rectfill(x,y,x+32,y+6,0)
  ?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds),x+1,y+1,7
end
function draw_ui()
  rectfill(24,58,104,70,0)
  local title=lvl_title or lvl_id.."00 m"
  ?title,64-#title*2,62,7
  draw_time(4,4)
end
function two_digit_str(x)
  return x<10 and "0"..x or x
end
function round(x)
  return flr(x+0.5)
end
function appr(val,target,amount)
  return val>target and max(val-amount,target) or min(val+amount,target)
end
function sign(v)
  return v~=0 and sgn(v) or 0
end
function tile_at(x,y)
  return mget(lvl_x+x,lvl_y+y)
end
function spikes_at(x1,y1,x2,y2,xspd,yspd)
  for i=max(0,x1\8),min(lvl_w-1,x2/8) do
    for j=max(0,y1\8),min(lvl_h-1,y2/8) do
      if({[17]=y2%8>=6 and yspd>=0,
          [27]=y1%8<=2 and yspd<=0,
          [43]=x1%8<=2 and xspd<=0,
          [59]=x2%8>=6 and xspd>=0})[tile_at(i,j)] then
            return true
      end
    end
  end
end
-->8
--[map metadata]
--@begin
--level table
--"x,y,w,h,title,lavarising,is_hot,bg_col,lavaspd,is_epicenter"
--lavarising:up/true(room)
--bgcol:0-15
--is_hot:true/false
--lavaspd:int(less then 1 best)
levels={
-- first chapter
 "0,0,2,1,entrance,false,lava,0",
 "0,0,2,1,bounce!,false,lava,5",
 "0,0,3,1,pepper spray,false,lava,5",
 "0,0,1,1,switchback point,false,lava,5",
 "0,0,2,2,high climb,false,ice,5",
 "0,0,2,1,forth and back,false,lava,5",
 "0,0,1,2,top to bottom,false,ice,5",
 "0,0,1,1,hop to it!,false,lava,5",

-- post gem chapter
 "0,0,1,1,point of no return,false,lava,5",
 "0,0,1,3,run,up,lava,5,0.3",
 "0,0,1,2,ascention,up,lava,5,0.5", 
 "0,0,1,2,rupture,up,lava,5,0.4",
 "0,0,1,3,fire riser,up,lava,5,0.56",
 "0,0,1,4,melting point,up,lava,5,1.2",

-- final stretch
 "0,0,1,1,final stretch,false,lava,5,0",
 "0,0,4,1,you should leave,true,lava,5,0.3",
 "4,0,2,1,mad dash,true,lava,5,0.35",
 "6,0,2,1,nyoooom,true,lava,5,0.45",
 "0,1,4,1,crubling,true,lava,5,0.55",
 "4,1,4,1,tight corridor,true,lava,5,0.65",
 "0,2,3,1,bread box,true,lava,5,0.75",
 "3,2,2,1,speedster,true,lava,5,0.85",
 "5,2,3,1,last hurrah,true,lava,5,1",

-- epicenter
 "0,0,8,1,the epicenter,false,lava,0,0,true"
}

--hex levels
mapdata={
--chapter 1

--entrance
 [1]="00000000000000000000000000000000000000000000002425252526242525250000000000000000000000000000000000000000000000242525252624252525000000000000000000000000000000000000000000000031323232332425252500000000000000000000000000000000000000000000001b1bcec4c53132323200000000000000000000000000000000000000000000000000ced4d7d5c7d5f700000000000000000000000000000000001600000000000000ced5f7e6d7d5c700000000000000000000000000000000000000000000000011ced4c7d5f7d7d50000000000000000000000000000000000000000000068212223f7d5212222220000000000000000000000000000682122222223000068242526f7d7313232320000000000000000000000000000682425252526000068242526f7f7f7f7f7f70000000000000000000000000000682425252526000068242526f7c7c5c7f7f70000000000000000000000000000682425252526000068242526d5d4d7c6f7f70000000000000000000000000000683132323233000068242526212222222222000001000000002122222223000000000000000000006824252624252525252521222222230000242525252600000000001a00000000682425262425252525253132323233000031323232330000000017171700000068242526242525252525",
--bounce
 [2]="2525252634353535353535353535353536212222233435353535353536212223252525261b1bef1b1b1b1b1b1b1bcecf1b242525262b00e9ea0000ef3b242526252525267800ef00001608000000cecf00242525262b00f9fa0000ff3b242526323232337800ef00000000000000cecf00242525262b0000110000003b242526000000277800fe00002800cad900cecf00313232332b0068201100003b313233002c0030780000eb0000dbdaca00dedf001b21361b00006821232b00003b21231600003078000000000000dc00000000000037ef0000006824262b00003b242623000030780000000000160000eb0000000000ef00eb006824262b00003b313333000037780000000011110000000000000000fe0000006824262b00003b201b0000000f000000006821231c0000000000002c000000006824260000000000000000000f00cad900682426780000dbcad9000000eb00006824261111001400000001000f00dbca00682426780000caebca0028000000006824262122222222232222222300000000682426780000dbcad90000000000006824262425252525262525252600000000682426780000000000000000fcfd00682426242525252526252525260000dbd968242678000000000000ee00cecf0068242624252525252625252526cacad90068242678000000000000ef00cecf00683133313232323233",
--pepperspray
 [3]="000000ef000000000000000000000000ef000000cecf00000000ef000000000000000000cecf0000000000ef00000000000000ef00000000001a000000000000ef000000cecf00000000ef000028000000000000cecf0000000000ef00000000000000ff0000000000280000eb000000ef000000dedf00000000ff000000000000dacc00cecf0000000000ef00dad90000000000000000000000000000000000ef000000000000eb0000000000000000dbcadad9dedf0000000000ef00dc0000000000cadad900000000000000000000ff00000000000000000000000000000000dcdc0000000000000000ff0000000000000000dacad900001c000000cacc0000000000000000cc00000000001111000000000000e9ea00000000000000000000000000000000000000000000dcdadc000016000000dbdada0000001621231c0000000000f9fa0000000000000000000000000000000000000000000000000000000000000000dcdad9000068242678000000000000000000cc000000000000000000002c0000000028000000000000000000000000000000000000682426780000000000000000dbcadad900000000000000000000000000000000000000000000eb00000000000000000068242678000000000000000000dadc000000000000000100000000000000000000000000000000000000000000000000682426780000eb0000000000000000000000000000212223000055656500000000000000000000cc00ee005565656500682426780000000000000000000000000000000000242526000065000000000000cc0000000000cadaef0065000000006824267800000000fcfd0000005565656565000000313233000065656500fcfddbcad90000000000dcef0065656565006824267800000000cecf0000006500000000000000000000000000000000cecf00dc0000ee00000000ef00002c0000006824267800000000cecf0000006500000000000000000000000000000000cecf00000000ef00000000ef0000000000006824267800000000cecf00000065656565650000",
--switchback
 [4]="21231b1b21222222222222232122222331330000313232323232323324252526000041000f0f1b1b1b1bef1b24252526da0000000f0f00000000ef6824252526dad900000f0f0000cc00ff6824252526dc0041000f0f0000cacc0068242525261c0000000f0f0000dcda006824252526212300002123780000dc006824252526242641002426780000000068242525262426000024260f0f0f0f0f0f242525263133000031330f0f0f0f0f0f31323233000041001b1b0000000000000d00000000000000dadad900000000000d00000001000000dbdc0000000000000d00000021234100556500ee00dbd9db2122222331330000656500efdbdadada31323233",
--highclimb
 [5]="000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e9ea000000000000000000000000000000000000000000000000ccda00000000f9fa000000000000000000000000000000000000000000000000cacaca000000000000000000000000000000000000000000000000000000000000dc000000000000001400000000000000cc00000000000000000000000000000000eb00002123212222222223000000ccdad90000000000000000eb000000000000000000313324252525252600eb00dccadc000000000000000000000000000000000000ef1b24252525252600000000000000000000000000000000cc00000000000000ff00242525252526000000000000001100000000000000dbcad9005565650000001624252525252600000000000068272b000000eb000000dc000065000000000000242525252526000000002c0068302b1c000000000000000000656565002c006824252525252600000000000068302b000000000000000000000000000000006824252525252600000000000068372b000000000000000000000000000000003b313232323233710000710000710000710000710000710000710000710000713b0071dada713b000000000000000000000000000000000000000000000000003bccdacadcda3b000000000000000000000000000000000000000000000000003b2122222222231c0000000000eb0000000000000000000000cc0000eb0000003b3132323232337800000000000000cccc00000000000000dbcad90000000000001b212222222378000000000000dbcadad90000eb00000000dc0000000000000000313232323378002c0000000000dc0000000000000000000000000000000000002122222223780016000000000000000000000000000000000000000000001c0024252525261717170000002800000000280000000028000000002800000000002425252526000000000000000000eb000000cc000000000000000000000000002425252526000000000000000000000000dbdadad900000000000000eb000068242525252600000000000000000000000000dcdc000000000000000000000068242525252600000000eb00cccacc0000000000000000000000000000000000683132323233001c00000000cacaca000000002c00000000000000dacccc0000682122222223000000000000dccadc0000000000000000eb000000dcdada000068242525252600010000000000000000eb000000000000000000ee00dc000000682425252526212223000055650000ee00000055656500000000ef0000fcfd00682425252526313233000065650000ef00000065656500000000ef0000cecf00083132323233",
--forthnback
 [6]="0000000000cc00000000000000000000003b21222222222223343535353535360000eb00dbdad900000000000000cccc003b242525252525262b1bef1bcecf1b0000000000dc00000000000000dbdadad93b242525252525262b00ef00dedf0000000000000000000000eb0000dbdadada3b242525252525262b00ff00eb00000001000000000000000000000000dbdad93b242525252525262b00000000000021222223005565656500000000000000003b242525252525262bdbca6821222324252526006500000000cccc000000eb003b242525252525262bcad968242526242525260065000000dbdadaca000000003b242525252525262bdbca6824252624252526006565656500dcdadc000000003b242525252525262bdad96824252631323233111111111111111111111100003b242525252525262b0000682425262122222223343535353535353535362b003b313232323232332b2c00682425262425252526dadcff00cecf00dcdada00000000ff00ef00dedf000000682425262425252526d9000000dedf0000dc000000dbdad900ff000000eb00006824252624252525261c0011000000110000eb000000dc00000000000000000000242526242525252600682778006827780000002800fcfd005565656565656500242526313232323300683778006837780000000000cecf006565656565656500313233",
--top2bottom
 [7]="00000d00dcdadc00cecf003b2122222300010d0000000000cecf003b242525262122232b00000000cecf003b313232332425262b0000cc00cecf00001b3435363132332b00dbd900cecf0000000f000034361b0000dc0000dedf0000000f0000271b0000000000000000cc00000f000030d900000000e9ea00dbdad9000f000030da00000000f9fa00dadad96821222330d90000000000000000dc00682425263711000000000000000000006831323321231600eb000d0d0d0d0d0d0d0d21232426780000000000000000000000242624267800000000160000cccc00002426242678000000000000dbdacad900242631337800000000000000dc00006824260d0d0d0d0d0d0d0d0d0000eb00682426000000000000000000000000cc68242678000000dbd90016000000dbda682426780000000000000000000000dc00242678000055650000000000556500002426780000656500000000006565000024267800000000dbcad900000000000024260000000000ca00da00000000006824261100000000dbcad900000000006824262011000000000000000000000068242621232b0000000000000000280000242624262b000000ccdadacc0000000024262426556500dbda2c00dad900280024263133656500dbdadacacad90000003133202b0000003b212222232b00ee003b201b00ee003b2031323233202befee001b",
--hoptoit
 [8]="cadccadc0000000000000000000000dbd91adb000000000000000000000000dbdaccdad9410000000000410000ccccca212223d9000055656565000068212223242526d9000065000000000068242526313233d90000656565650000683132333436dad9410000000000410000da343627dad900000000000000000000dbda2730d9000000000000000000000000db3030d90000000000e9ea0000000000db3030000000410000f9fa0041000000db30300000000000000000000000001cdb3037010000000000000000000000ccca37212223000000556565650000682122232425260041006500000041006824252631323300000065656565000068313233",

--chapter 2 (post gem)

--pointofnoreturn
 [9]="0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cccc0000000000000000000000eb00cadadaca00eb0000000000e9ea0000dbda6000dad90000e9ea0000f9fa0000dada7000dada0000f9fa0000000000dbca21222223cad900000000000000ccda203132323320dacc0000000001ccda2122222222222223dacc00002122222324252525252525262122222331323233313232323232323331323233",
--run
 [10]="0000000000000000000000000000000000000000e9ea00000000000000eb0000001a0000f9fa00000000ccda00000000cd00000000000000ccdacaca000000003436000000000000cacadc0000003436212223000000000000000000682122232425262b0000000000000000682425262425262b0000000000000000682425262425262b0000cc000000eb00682425262425262b00cccaca000000003b2425262425262b00cacad9000000003b2425262425262b00dbca00005565653b2425262425262b00000000006565653b2425262425262b00000000000000003b2425262425262b00000000000000003b2425262425262b556565000000eb003b2425262425262b6565650000000000162425262425262b0000000000000000682425263132332b00000000000000006824252621231b0000000000cccacc00682425262426000000eb0000cacaca00002425262426000000000000dccadc00002425262426000000000000000000001624252624267800ccca0000000000000024252624267800cadad90000000000002425262426780000dc000000cad90068242526242678000000000000dbca0068242526242678000000000000cad900682425263133782c000000000000000068242526201b00000000002800000000683132331b0061000000000061000000000d61270000cc000000000000000000000d003000dbdada0000000000000000000d003000dbdadc000000000000cc00000d16301c00000000000000cccacad9000d003778000000eb000000dacadada00343536780000000000000000dccadc001b343678000000000000000000000000001b2700000028000017171700280000006830000000000000000000000000000068300000dbdaca0000000000caccca0068300000cacacad900000000dbcadc0068300000dbdada0000eb00000000000068370000000000000000000000000000343600010000000000000000343535353536212222230000000000212222222222232425252621222222232425252525252631323233313232323331323232323233",
--ascention
 [11]="000000000000000000000000000000001a00000000000000d9000000000000002b000000000000dbdad900000000000078000000e9ea0000db0000000000000078000000f9fa00000000000000000027780000000000000000000000000000377800000000000000000000cc0000212378000000db000000000000dad9002426780000dbdad900000000dbdad9002426780000cada000055650000dc00682426780000dbd900006565000000006824260000000000000000000000000068242600280000000000cccc00000000682426000000000000dbcad900eb000068242600000000eb0000dc0000000000002426280000000000000000000000cc0024260000000000000000000000dbdad92426212378000000556565650000dc002426242678000000656565650000000024262426780000cccc0000000000003b242624267800dbdaca0000000000003b24262426780000dc000000000000003b24262426000000000000dbdacc00006824262426000000eb0000dbcadc0000682426242600000000000000000000006824263133000000000000000000000068242620000000eb00000000000000006824260000000000000000000000eb0068242600010000cccacc000000000000002426212300dbcadaca0000000000000024262426000000dc0000000000000000242631330000000000000000000000003133",
--rupture
 [12]="21232b00ef00ef00ff0000da0000000024262b00ef00ff000000000000ed000024262b00ff000000682122222222222324262b000000eb00683132323232323331330000000000000000ef00ef3b212300000000111111000000ff00ef3b2426001a002021222222232beb00ff3b24262122222331323232332b0000003b2426242525262bef00ef00000012003b2426242525262bef00ff00000017003b2426242525262bff00000011111111113133242525262b0000003b21222222222223313232332b0000003b31323232323233271bcecf00cc0055651b1bef1b1b1b273000cecf00caca65000000ef000000303000dedf00dbd965000000ff000000303000000000000065000000000000003030002c0000eb00650000eb001c00003030000000000000656500000000000030300017170000001717000000171768303000000000000000000000000000683030111111111100111100111111006830302122222223112123112122232b6830372425252526202426202425262b6830003132323233003133003132332b68300000ef00ef000000ef0000ef000068300000ff00ef000000fe0000efeb00683000000000fe00eb00000000ff0000683000000100000000000000000000006830cc212223cc0000001717171700006830da24252627dacc000000000000006830203132333720cadacccc000000006837",
--fireriser
 [13]="2123343535353535353535353535353624261b1b1b1b1b1b1b1b1b1b1b1b1b1b2426000000000000000000000000000024260000cc0000000000000000000000242678dbca0055656565000000002123242678dbcad96565656500caca002426242678dbcad90000000000dbcad92426242678dbcaca0000000000caca00242624267800dc0000e9ea0000000000242624267800000000f9facc0000000024262426780000000000dbdad9eb000024262426780000000000dbdad90000002426242678000000eb00dbdadad900002426242678000000000000dbdada0000242624267800000000000000dc00000024262426000000001717171700000068242624260000000000000000000000682426242600000000000000e9ea0000682426242600000000000000f9fa00006824262426000000000000cccc0000006824262426000000eb00cccacad90000682426242600000000cccacadc0000006824262426000000dbcacadc00000000682426242600000000dcdc0000eb000068242624267800000000000000000000002426242678000000eb00000000000000242624267800000000000000000000002426242678000000000000000000000024262426780000000000000000eb000024262426780000e9ea0000cccccc000024262426780000f9fa00dbcadadacc002426242678000000000000cacadada002426242678000000000000dbcacaca00242624260000000000000000dbcad9002426242600000000eb0000000000000024262426000000000000000000eb000024262426000000000000000000000000242624260000000055656565000000682426242600eb0000656565650000006824262426000000000000000000000068242624260000000000000000e9ea0068242624260000000000000000f9fa0068242631330000e9ea0000000000000068242620000000f9fa00cccad90000006824260000000000cccacacad900000000242600010000dbcacacadc00eb00000024262122230000dcdc00000000000000242631323300000000000000000000003133",
--meltingpoint
 [14]="00000000000000000000000000000000001a0000000000000000e9ea000000002122230000dbca000000f9fa000016003132330000dbcad900000000000000002123000000cacad9000000000000212324260000dbcaca0000000000000024262426000000cad90000000000000024262426000000000000000000000000242624260000e9ea00000000dbca0000242624260000f9fa000000dbcad900002426242600000000000000dbcad900002426242600000000000000caca00000024262426000000000000000000000000242624260000000000000000000000682426242600000000000000e9ea0000682426242600000000000000f9fa0000682426242600000000cc00000000000068242624260000ccdadad9000000000068242624260000dadadadad90000000068242624260000dcdadadada00000000682426242600000000dcdc00000000006824262426000000000000000000000068242624260000e9ea000000dbda000068242624260000f9fa000000dad90000682426313300000000000000dbda0000682426270000000000000000dad90000682426300000000000000000dbda0000002426300000000000000000000000000024263000000000000000000000000000242630000000556565656565650000002426307800006565656565656500000024263078000000000000000000000000242630780000cc0000000000000000002426307800dbdad9000000e9ea0000002426307800dbcadad90000f9fa0000002426300000cadcda00000000000000002426300000000000000000000000000024263000001717001700170017170000242637000000000000000000000000002426000000000000000000cc000000682426000000e9ea000000dbdad90000682426000000f9fa000000dadad900006824260000000000000000dadada00006824260000000000000000dbdad90000682426000000000000000000dc00000068242600000000000000000000e9ea00682426000000cc000000000000f9fa00682426000000caca00000000000000006824260000dbcad900000000000000000024260000caca00000000ed0000000000242600dbcad90000212222232b00000024260000ca000000242525262b0000002426000000000068242525262b00000024260000e9ea0068242525262b00000024260000f9fa0068242525262b0000002426000000000068242525262b0000002426000000000068242525262b0000002426000100000068242525262b00000024262122232b0068242525262bcad90024262425262b0000242525262bcad90024262425262b0000242525262bcaca0024262425262b0000242525262bdbca0024262425262b0000242525262bdbca0024263132332b0000313232332b0000003133",

--chapter 3 (lava rooms)

--finalstretch
 [15]="0000000f0f0000000000000d0d0000000000000f0f0000000000000d0d0000000000000f0f0000000000000d0d00000000eb000f0f0000e9ea00000d0d00eb000000000f0f0000f9fa00000d0d0000000000000f0f0000000000000d0d0000000000000f0fe9ea0000e9ea0d0d00000000eb000f0ff9fa1c00f9fa0d0d00eb000000000f0f0000000000000d0d0000000000000f0f0000e9ea00000d0d0000000000000f0f0000f9fa00000d0d00000000eb000f0f2122222222230d0d00eb000000000f20313232323233200d000000000100212222222222222222230000002122232425252525252525252621222331323331323232323232323233313233",

--epicenter

--theepicenter
 [#levels]="2122222223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000313232323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034353536cf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003436d5d7cf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d6c4d7f7cf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f7d7f7f7cf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f7f7e6f7cf000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f7f7c7f7cf000000000000000000000000000072737475000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000480000000000000000c7c5d5c7cf0100000000000000000000000000424343440000000000000000000000000000000000000000000000000072750000000000000000000000000000000000000000000000000000000000727374457500000000000000000000000000000000000000000000000000000000000000000000000000000000000000002122222222230000000072737475000000000052535354000000000000000000007273747500000000000000000000004244000000000000000072737445750000000000000000000000000000000042434343440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000313232323233000000004243434400000000006263636400000000000000000000424343440000000000000000000000626400000000000000004243434344000000000000000000000000000000005253535354000000000000000000000000000000000000000000000000000000000000000000000000000000000000000034353535360000000000525353540000000000000000000000000000000000000052535354000000000000000000000000000000000000000000520000005400000000000000000000000000000000626363636400000000000000000000000000000000000000000000000000000000000000000000000000000000000000002122222300000000000062636364000000000000000000000000000000000000006263636400000000000000000000000000000000000000000062636363640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000313232330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021222300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003132330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
}
--list of music switch triggers
--assigned levels will start the tracks set here
music_switches={
 [0]=1,
 [1]=4
}
--@end
--replace mapdata with hex
function replace_mapdata(x,y,w,h,data)
  for i=1,#data,2 do
    mset(x+i\2%w,y+i\2\w,"0x"..sub(data,i,i+1))
  end
end
__gfx__
777777770000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000000000000000000088888800007700000ccccc0
700000070888888008888880882888880888888008888800000000000888888000a000a0000a0a000000a000000000000000000008988888007007000c1ccccc
700000078828888888288888822ffff888288888888882800888888022f1ff1800a909a0000a0a000000a00000000000000000008989888807000070c1c1ccc0
70000007822ffff8822ffff888f1ff18822ffff88ffff2208828888882fffff8009aaa900009a9000000a000000000000000000088988888700000070c1ccc00
7000000788f1ff1888f1ff1808fffff088f1ff1881ff1f80822ffff888fffff80000a0000000a0000000a0000000000000000000888889887000000700ccc1c0
7000000708fffff008fffff00022220008fffff00fffff8088fffff8082222800099a0000009a0000000a000000000000000000088889898070000700ccc1c1c
07777770002222000022220007000070072222000022227008f1ff10002222000009a0000000a0000000a00000000000000000008888898000700700ccccc1c0
000000000070070000700070000000000000070000007000077222700070070000aaa0000009a0000000a000000000000000000008888880000770000ccccc00
55555555000000000000000000000000000000000001100000000000d666666dd666666dd666066d0300b0b06665666500000000000000000000000070000000
555555550000000000000000000000000000000000133100000330006dddddd56ddd5dd56dd50dd5003b33006765676500000000007700000770070007000007
550000550000000000000000000000000aaaaaa0013bb310003bb300666ddd55666d6d555650055502888820677067700cc0cc00007770700777000000000000
55000055007000700499994000000000a998888a15bbbb3107bbbb3066ddd5d5656505d5000000550898888007000700ccccccc0077777700770000000000000
55000055007000700050050000000000a988888a15bbbb3107bbbb306ddd5dd56dd50655650000000888898007000700ccccccc0077777700000700000000000
55000055067706770005500000000000aaaaaaaa015bb310007bb3006ddd6d656ddd7d656d50056508898880000000000ccccc00077777700000077000000000
55555555567656760050050000000000a980088a001531000007300005ddd65005d5d65005505650028888200000000000ccc000070777000007077007000070
55555555566656660005500004999940a988888a0001100000000000000000000000000000000000002882000000000000000000000000007000000000000000
0266226006222622226226622662266026d882222222222222288d6202226220000000c100000505000000d15500000000000000000000000000000000000000
626d6d626266666666666266662666266666d822222222222288d66262666626000001c100500558000001556670000000000000000777770000000000000000
26d288666666dd6dd666666d6ddd6662626d822222222222288d6666666d6622000ccc1c005885550001d5d56777700008808800007766700000000000000000
6d2282d6266d88d88d666d68d888d6622266d82222222222228d666222d8dd66001ccc225055882200d555446660000088888880076777000000000000000000
268222d226d8828288ddd8d882288d622666d82222222222228d662226d228d600c1c22455558222001d54445500000088888880077660000777770000000000
6d882d6262d822222888828222228d666666d882222222222228d62626dd2d220cc24442088222220d5244446670000008888800077770000777767007700000
26d6d62666d82222228222222228d662266d882222222222228d66662d822d621122424455221122154244446777700000888000070000000700007707777770
02226220266d82222222222222228d6226d882222222222222288d626d828d62cc421c12052288125d4211146660000000000000000000000000000000077777
26d282d626d82222222222222228d66206266622622666226222666026d828d6cc421c14582211121d4211140000066600000000000000000c000c0008880000
26822862266d82222222282222228d666226d266d6662226dd62262626d228d2112242420522222255424444000777760000000000000000c7c0c7c082228888
2d82286266d822222828888222228d26226d8ddd8d6dd6dd88ddd62222d2dd620cc244415582211101d244210000076600d0d00000606000c71c711c29992222
6d2822d626d882288d8ddd8828288d62666d222828d22d2822d28d226d822d6200c1c2440585518800555421000000550ddddd0006666600c1cc11cc98889999
268222d2266d888d86d666d88d88d66222d82d22822822228222d66666dd8d22001ccc22005881110015dd44000006660ddddd0006666600cccccccc88888888
66d228d22666ddd6d666666dd6dd6666226ddd88d8dd88d8ddd8d6222266d666000ccc1c05558858000d15550007777600ddd00000666000cccccccc88888888
26882862626662666626666666666626626226dd6d26dd6d662d622662666626000001c10000555800000dd500000766000d000000060000cccccccc88888888
2d822d6606622662266226222262226006662226222662262266626002262220000000c1000050550000001d000000550000000000000000cccccccc88888888
00000000000000007777777777777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007000070000700007007070070000000000000000000000000cccc00000000000000000000000000000000000000000000000000000000000
0000000000000000707707000070770700777007777777770000000000000000cc111cc000000000000000000000000000000000000000000000000000000000
0000000000000000707707770070000700007777770077000000000000000000c1cc111c00000000000000000000000000006000000000000000000000000000
0000000000000000700000070070770700000707777777770002eeeeeeee2000c1cc111100000000000000000000000000060600000000000000000000000000
000000000000077777770777007777770000077777007700002eeeeeeeeee200c111111100000000000000000000000000d00060000000000000000000000000
0000000000077ccc7007070000000000000000077700770000eeeeeeeeeeee00c11c11110000000000000000000000000d00000c000000000000000000000000
00000000007ccccc7007770000000000000000077700770000e22222e2e22e00cc111ccc000000000000000000000000d000000c000000000000000000000000
00000000007ccccc7000000000000000000000070622262200eeeeeeeeeeee00cccccccc00000000000000000000000c0000000c000600000000000000000000
00000000007ccccc7000000000000000000077776262662600e22e2222e22e000ccccccc0000000000000000000000d000000000c060d0000000000000000000
000000000007cccc7777700000000000000070076626dd6d00eeeeeeeeeeee000ccccccc000000000000000000000c00000000000d000d000000000000000000
00000000007ccccc7000700000000000000077772666d8d800eee222e22eee0000cccccc000000000000000000000c0000000000000000000000000000000000
000000000cc0c0cc70707000000000000000070722dd828200eeeeeeeeeeee0000077ccc06666600666666006600c00066666600066666006666660066666600
000000000c00c00c70007000000000000000777762d8222200eeeeeeeeeeee00000077cc6666666066666660660c000066666660666666606666666066666660
000000000000cc0c77777000000000000000700766d8222200ee77eee7777e000000077766000660660000006600000066000000660000000066000066000000
0000000000000c00700000000000000000007777266d8222077777777777777000000007dd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000
000000000000000070000000000000000077700722622662007777000000071c000000d5dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000
00aaaaaa00098000700000000000000000707007666622660700007000000ccc00000050ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00
0a99999900a00022700000000000000077707777d666666d7077000700000ccc0000000d0ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd0
a99aaaaa080022227000000000777000700000078d666d687077bb07000001c1000000dd00000000000000000000000000000000000000000000000000000000
a9aaaaaa0a02298870000000007070007770770788ddd8d8700bbb070000071c00000dd50000000000000c000000000000000000000000000000c00000000000
a99999990002999870000000777770000070770728888282700bbb0700000ccc00000d50000000000000c00000000000000000000000000000000c0000000000
a999999900229988700000007000700000700007228222220700007000000ccc0000000d0000000000cc0000000000000000000000000000000000c000000000
a9999999002288887777777777777777777777772222222200777700000001c10000000d000000000c000000000000000000000000000000000000c000000000
aaaaaaaa0022889877777770000000000000000000000000000007710000dddd000000d500000000c0000000000000000000000000000000000000c000000000
a49494a10022899970070077770000000000000077777770000001770000d22d000000500000000100000000000000000000000000000000000000c00c000000
a494a4a1000228997707777007777000000007777007007000000ccc0000d22d0000000d000000c0000000000000000000000000000000000000001010c00000
a49444aa0002228800070077770077770077770077770770000000000000dddd000000dd000001000000000000000000000000000000000000000001000c0000
a49999aa0000222200070070077770077770077770070000000000000000000000000dd500000100000000000000000000000000000000000000000000010000
a4944499000000220007007007007777007777007007000000000ccc0000000000000d5000000100000000000000000000000000000000000000000000001000
a494a444000000000007007007007007777007007007000000000177000000000000000d00000000000000000000000000000000000000000000000000000000
a4949999000000000007007007007007007007007007000000000771000000000000000d00010000000000000000000000000000000000000000000000000010
122222223243535353535353535363122222223212222222321222222222222222223202b200000000000000b3021232122222321222222222321232b1b1b1b1
b1b1b1b1b1b1b1b1122222223212223200000000000000000000000000000000000000000000000000000000000000000000000000b343535353630212321232
4252525262b1b1b1b1b1b1b1b1b1b1425252526213232323331323232323232323233300000000001100000000004262425252624252525252624262009eae00
00be0000be00c1bd4252525262425262000000000000be00000000be00000000000000be0000000000000000000000000000000000000000000000b113334262
1323232333b20000000000000000b313232323331222222222222232122222222222320000be00000211000000004262425252624252525252624262009faf11
11111111111100ac425252526242526200be00cccc000000000000000000acaccc000000000000acaccc00000000000000000000000000c100000000b1721333
1222222232b200000000c1000000b3122222223242525252525252624252525252526200ac9d0011436300c100cc426242525262425252525262426200000012
222222321232bdac42525252624252620000acacacaccccc000000000000cdacaccc0000000000cdacacaccccccc00000000be0000000000001100beb3031232
4252525262b200be000000de0000b3425252526242525252525252624252525252526200ac9d86122232ccccacac4262132323331323232323331333f0f0f042
525252624262bdac13232323331323330000adacacacacac9d00be0000000000cdac9d0000000000cdacacacacacac000000000000be00001102b200b3734262
1323232333b2cccc00b31232b200b3425252526213232323232323334252525252526200bdac86425262acacaccd1333435353535363b14353535363f0f0f013
232323334262acacb14363b102b14363000000adacacaccd00000000000000000000000000be00000000cdcdacac000000000000000000861232b200bdad4262
4363b1b102b2acac9db34262b200b313232323334363b1b1b1b1b1021323232323233300bdac86425262cd000000ac020002b102b1b100b102ac02b1000000f0
f0cdacac4262ac9d00b1b100b100b1b10000be00cdcd0000be00000000c100000000000000000000be00000000000000009eae0000000086426211bdacac4262
02b10000b100bdacacb34262b200b302b1b1b1b102b10000000000b102b143535363b1000000861323330000bebdac9d000000b10000c100acacac00000000f0
f000bdad4262acaccc00000000000000000000000000000000000000000000000000be00000000000000000000000000009faf00be000086426272acad9d4262
b10000be0000bdacacb34262b20000b100000000b100000000000000b100b14363b10000be00861222320000bdacac009d000000000000bdacacac9d00be00f0
f00000ad4262ac1222327171717171710000100000000000000000000000000000000000000000000000000000be00000000000000000086426203acacb31333
000000000000acac9db34262b2000000000000000000acccadcccc00000000b1b10000cccc00864252620000acac9d00adcc10000000bdacacacacac000000f0
f00000bd1333ac425262cc000000000012223212320000007171717100be0000555656565600000082000000000000000000000000000086426203adac9db102
000010000000cdcd00b31333b20000be008200000000acacacacac0000000000000000acac9d864252621111ac9dde001222222232b2acacac12223255565612
32f0f0f01232ac132333accc0000be0013233313330000000000000000000000560000000000000000000000000000000000000000000086133303cdacac9db1
122222223255565656561232b200000000000000000000cdacaccd000000c200000000bdacac864252621222222222324252525262acacac9d42526256000042
62f0f0f04262adb14363acaccc0000001232b1b102000000cc00000000000000560000000000000000000000ccacacccc200111100000086123203b2acadac9d
4252525262560000000042627171717171717171820000000000000071717171717100bdac9d864252624252525252621323232333acacacb342526256565613
33f0f0f042629d00b172acacaccc000013330000b10000acacaccc00000000005656565656000000000000ccacac122232021232ad000086426203ccadacadac
425252526256000000004262b200000000000000000000000000000000000000000000ac9d00864252624252525252621222222232acac9db34252629d0000b1
b10000bd426200a10003acacacaccc0002b10000000000cdacacacac0000000000000000000000000000ccacacac132333b11333adad008642627302acadacad
425252526256000000004262b200000000000000000000000000000000000000000000000000864252624252525252624252525262ac9d00b3425262acacccc2
00ccacac4262dc00de03acacacacac9db100000000000000cdacaccd00000000000000000000000000ccacacacacb102b10002b1adad9d864262123212222232
132323233356565656561333b200000000000000000000000000000000000000000000000000861323331323232323331323232333b20000b313233343535353
53535363133343536373acacacacac9d000000000000000000000000000000000000000000000000ccacacaccd0000b10000b1adadad9d861333133313232333
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc55525555222525552555255555555555000000000052000000002000200025000000000000000000001d555555555100
0000000000000000be00000000be0000552525225552525252525255555555550000000055202022000202020202025500000000101111010001dd5555552000
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc225552555555552555255522555555550000000022000200000000200020002200000000111717110015222d222d5100
be00000000be00000000dc275457de0052555552252555255552552555555555000000000200000220200020000200200000000011119911001555525552d100
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc52525555525555255555552552555552000000000202000002000020000000200200000201177710001d5555d5551000
000000be00000000be00243434344400252522522522525225225252552555250000000020202202202202022022020200200020011777100001ddd222d21000
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc5552552552552555525525555552225500000000000200200200200002002000000222000117771000012d2555251000
000027374757000000002500000045005555255555255555552555555525552500000000000020000020000000200000002000201199599000155255d5555100
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc22255555525552555555255555252552000000002220000002000200000020000020200200000000001d5555dd555100
00002434344400000000263636364600555255555522255555555252525255520000000000020000002220000000020202020002000000000002dd5555551000
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc555555555255525555555525252525520000000000000000020002000000002020202002000000000015222d222d5100
00002500004500be00000000000000be25255555255555255555552555255525000000002020000020000020000000200020002007777770000155525552d100
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc5255555552555255555555255555555500000000020000000200020000000020000000000070070000001d55d5551000
00be26363646000000be0000be000000252255552552525255555252555555550000000020220000000202020000020200000000000770000000011555110000
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc525555552555252555552555555555550000000002000000000020200000200000000000007007000000000151000000
00000000000000000000000000000000552555552552525555555555555555550000000000200000000202000000000000000000000770000000000010000000
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc55555555555555555555555555555555000000000000000000000000000000000000000000000000011101111d555551
000000000000be000000be009eae00be5dddd555555dddd555dd5dd555555555000000000dddd000000dddd000dd0dd0000000001011110101d51d5101dd5510
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdd555dd55dd555dd5d55d55d5555555500000000dd000dd00dd000dd0d55d55d00000000117171111d52555115222d51
dc0000be00000000000000009faf0000d5dd555dd555dd5d5d55555d5555555500000000d0dd000dd000dd0d0d55555d00000000119911111d5d5510155552d1
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd5dd55555555dd5d55d555d55555555500000000d0dd00000000dd0d00d555d00000000001777110155552d11d555510
02000000000000be00dcdcdc0000deded55555555555555d555d5d555555555500000000d00000000000000d000d5d00000000000177711015222d5101ddd210
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd55d55555555d55d5555d5555555555500000000d00d00000000d00d0000d000000000000177711001dd5510012d2510
4363dcde00be00000002122222223202dd555dddddd555dd555555555555555500000000dd000dddddd000dd0000000000000000099599111d55555115525551
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdddddddddddddddd555555555555555500000000dddddddddddddddd5555555500000000100000001d5555511d555551
122222320000000000b11323232333b15dddddddddddddd55555555555555555000000000dddddddddddddd055555555000000015100000001dd551001dd5520
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc5dddddddddddddd55555555555555555000000000dddddddddddddd055555555000001155511000015222d5115222d51
13232333dc00be000000b102b172b10055dddddddddddd5555555555555555550000000000dddddddddddd005555555500001d55d5551000155552d1155552d1
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc555dddddddddd555555555555555555500000000000dddddddddd00055555555000155525552d1001d5d55101d555510
122222223200000000be00b1007300be5555dddddddd55555555555555555555000000000000dddddddd0000555555550015222d222d51001d52555101ddd110
dcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdc55555dddddd5555555555555555555550000000000000dddddd00000555555550002dd555555100001d51d51011d1000
13232323330000be0000000000b100005555555dd55555555555555555555555000000000000000dd000000055555555001d5555dd5551000111011100010000
__label__
0000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000cc0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000cc0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
17700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c10000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000
c1700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000
ccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c100000000000000000000000000000000000000000000000000000000000000000000000000011111111111111111111111111111111111111111111111111
c1700000000000000000000000000000000000000000000000000000000000000000000000000011111111111111111111111111111111111111111111111111
ccc00000000000000000000000000000000000000000000000000000000000000000000000000011111111111111111111111111111111111111111111111111
ccc0000000000000000000000000000000000000000000000000000000000000000000000000001111111111111111111c111111111111111111111111111111
1c100000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111111111111111111111111
c1700000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000
ccc0000000000000000000000000000000000000000000000000011111cc11111111111111111111111111111111111111111111111110000000000000000000
ccc0000000000000000000000000000000000000000000000000011111cc111111111111111111111111111111111cc111111111111110000000000000000000
1c1111111111100000000000000000000000000000000000000001111111111111111111111111111111111111111cc111111111111110000000000000000000
c1711111111110000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000
ccc11111111110000000055055000000000000000000000000000111111111111111111111111111111111111111111111111111111110000000000000000000
ccc111111111100000005885885000000000000000000000000001111111111111111111111111111111111111c1111111111111111110000000000000000000
1c111111111110000000888888850000000000000000000000000111111111111111111111111111111111111111110000000000000000000000000000000000
c1711111111110000000888888850000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc11111111110000000588888500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc11111111110000000058885000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c111111111110000000005550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c1711111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc00000000000000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc00000000000000013310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1c10000000000000013bb31000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c17000000000000017bbbb3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc000000000000017bbbb3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7710000000000000017bb31000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
17700000000000000017310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
055555500555555005555550000000000000000000000000000000c11c000000000000000000000000000000000000c11c000000000000000000000000000000
588888855888888558888885000000000000000000000000000001c11c100000000000000000000000000000000001c11c100000000000000000000000000000
582222855822228558222285000000000000000000000000000ccc1cccccc000000000000000000000000000000ccc1cc1ccc000000000000000000000000000
582222855822228558222285000000000000000000000000001ccc22ccccc100000000000000000000000000001ccc2222ccc100000000000000000000000000
58222285582222855822228511111111111111111111111111c1c224422c1c0000000000000000000000000000c1c224422c1c00000000000000000000000000
5822228558222285582222851111111111111111111111111cc2444224442cc00000000000000000000000000cc2444224442cc0000000000000000000000000
58888885588888855888888511111111111111111111111111224244442422110000000000000000000000001122424444242211000000000000000000000000
155555511555555115555551111111111111111111111111cc421c1221c124cc000000000000000000000000cc421c1221c124cc000000000000000000000000
111111111111111111111111111111111111111111111111cc421c1441c124cc000000000000000000000000cc421c1441c124cc000000000000000000000000
11111111111111111111111111111111111111111111111111224242242422110000000000000000000000001122424224242211000000000000000000000000
0000000000000000000000000000000000000000000000000cc2444114442cc00000000000000000000000000cc2444114442cc0000000000000000000000000
00000000000000000000000000000000000000000000000000c1c244442c1c0000000000000000000000000000c1c244442c1c00000000000000000000000000
000000000000000000000000000000000000000000000000001ccc2222ccc100000000000000000000000000001ccc2222ccc100000000000000000000000000
000000000000000000000000000000000000000000000000000ccc1cc1ccc000000000000000000000000000000ccc1cc1ccc000000000000000000000000000
000000000111111111111111111111111111111111111111111111c11c100000000000000000000000000000000001c11c100000000000000000000000000000
000000000111111111111111111111111111111111111111111111c11c000000000000000000000000000000000000c11c000000000000000000000000000000
00000000011111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111111111111111111111111111111111111111111110000000000000000000000000000000cc0000000000000000000000000000000000000000
00000000011111111111111111111111111111111111111111111110000000000000000000000000000000cc0000000000000000000000000000000000000000
0000000001111111111111111111111111111111111c111111111110000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000
111111111111111111111111111111111111111111c1111110000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc00000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc00000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000c0000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00c00000000000000000000000000000000000000000000000000000000000000000cc0000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000cc0000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005505500000000000000
00000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000058858850000000000000
00000000000001111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088888885000000000000
00000000000001111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088888885000000000000
00000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000058888850000000000000
00000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005888500000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0000008888888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000008888ffff80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111888f1ff180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111188fffff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111183333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111117117111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111555555555555550000000000000000000000000000000000000000000000000055555555555555555555550
11111111111111111111111111111111111111115555555555555555000000000000000000000000000000000000000000000000555555555555555555555555
1111cc1cc111111c1ccc111111111111111111115555dd5dd5dd55550000000000000000000000000000000000000000000000005555dd5dd555555dd5dd5555
1111cccccc111c1ccccc111111111111111111115555dddddddd55550000000000000000000000000000000000000000000000005555dddddd555d5ddddd5555
11ccc2c2ccccccccc22ccc11111111111111111155ddd1d11d1ddd5500000000000000000000000000000000000000000000000055ddd1d1ddd11ddd1d1ddd55
11cc22222cccc2c22222cc11111111111111111155dd11111111dd5500000000000000000000000000000000000000000000000055dd11111d1111d11111dd55
11cc222222c22222222cc111111111111111111155dd111cc111dd5500000000000000000000000000000000000000000000000055dd1111111cc1111111dd55
111cc222222222222222cc110000000000000000555d15cccc11d555000000000000000000000000000000000000000000000000555dd11115cccc11111dd555
11cc222222222222222cc1110000000000000000555d15cccc11d555000000000000000000000000000000000000000000000000555dd11115cccc11111dd555
111cc22222222c222222cc11000000000000000055dd115cc111dd5500000000000000000000000000000000000000000000000055dd1111115cc1111111dd55
11cc22222c2cccc22222cc11000000000000000055dd11151111dd55000000000000000000000000000000000000000000000000c5dd11111d1511d11111dd55
11ccc22ccccccccc2c2ccc11000000000000000055ddd1d11d1ddd5500000000000000000000000000000000000000000000000055ddd1d1ddd11ddd1d1ddd55
111cccccc1c111cccccc111100000000000000005555dddddddd55550000000000000000000000000000000000000000000000005555dddddd555d5ddddd5555
1111ccc1c111111cc1cc111100000000000000005555dd5dd5dd55550000000000000000000000000000000000000000000000005555dd5dd555555dd5dd5555
11111111111111111111111100000000000000005555555555555555000000000000000000000000000000000000000000000000555555555555555555555555
01111111111111111111111000000000000000000555555555555550000000000000000000000000000000000000000000000000055555555555555555555550

__gff__
0000000000000000000000000000000004020000000000404040000200000000434343434343434300000002000000004343434343434343000000020000000000008383830802020000000002020002000083838300020200020202020202020000838383000000000202020202020200000808080800000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040404040004040404040404000000000404040400040404040004040000000004060404000404040004040400000000040404040004040404040404
__map__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002125222222222222222222222222222223212223000000000d00000d0000000f0000000000000000000041000000000000cecf00000000000000000000000000
0000000000000000000000000000000000000000000000000000cccccc0000000000000000000000000000000000000000000000000000000000000000000000242525252525252525252525252525252624252600001c000d00000d00eb000f0000e9ea00000000000000000000000000dedf00000000000000000000000000
00000000000000000000000000dadacccc00000000000000cccacacacad900000000000000dacacc000000000000000000000000cad9000000000000000000002425252525252525252525252525252526242526000000000dcded0d0000000f0000f9fa00000000000000000000000000000000000000000000000000eb0000
00000000000000000000000000dcdadadada0000000000cacacadcdc000000000000000000cadadada0000000000000000000000dbda00000000000000000000313232323232323232323232323232323324252628000016212222235565652700000000000000000000410000eb000000000000000000000000000000000000
00000000eb000000e9ea00000000dcdcdada0000eb0000cadc0000e9ea0000000000eb0000dbdadc00000000eb000000000000dbdada0000000000000000000000ef00ef00ef00ff000f00000d0000000024252600ccca0024252526650000300000000000000000000000000000000000000000000000eb0000000000000000
000000000000cc00f9fa0000000000000000000000000000000000f9fa00000000000000000000000000000000000000000000cacad90000000000000000000000ef00ef00ff00eb000f00000d0000eb0024252600cadc00242525266500003000000000cccc0000000000000000000000000000dad900000000000000000000
0000000000dbcacc00000000eb0000000000000000000000000000000000000000000000000000000000000000000000eb0000dad900e9ea000000eb0000000000ef00ff00000000000f00000d00cacc002425260000eb00242525266565653000000000cacad900000041000000000000000000dadad9000000000000000000
00e9ea000000dccaca00000000000000e9ea00000000000000000000000000000000000000e9ea000000000000000000000000000000f9fa00000000000000cc00ef00eb00000000000f1c000d00dcca0024252600000000242525260000003000000000dbcaca00000000000000000000000000dbdadada000000e9ea000000
00f9fa00000000dcca00000000000000f9fa0000da00002c0000eb00000000001600000000f9fa00001c000000000000000000000000000000000000ccccdbda00ff0000ccdada00000f00000d00000000242526000000002425252600eb00300000000000dbca00000000000000000000eb00000000dbda000000f9fa000000
00000000000000000000000000000000000000dbdad90000000000000000000000000000000000000000000000000000000000000000000000000000dacadada00000000dadc00000021222223556565652425261600280024252526000000300000eb0000000000000041000000000000000000000000000000000000000000
000000000000eb00000000001c000000000000dbdad90011110000000000556565656500000000000017170000280000000028000000002800000000dbdadada000000000000eb0000242525266500000024252600000000242525260000003000000000000000000000000000001c0000000000000000000000000000000000
00000000000000000000000000000000000000dadad96821237800000000650000000000000000eb00000000000000000000000000000000000000000000dcdc000000000000000000242525266500000024252600cacc00242525262c2c0030000100000000000000000000000000000000000000000000000000ee00000000
00010000000000000000120000000055656500dcdc006824267800000000656565656500000000000000000000000000e9ea000000000000000000000000eb00000001000000000000242525266565656531323300dcca002425252600000030212223001717171717004100005565656500001200000000000000ef00000000
21222300171700dad9001700000000650000000000006824267800000000000000000000000000000000000000000000f9fa000000eb000000000000000000002122222223556565652425252600000000eb0000002c00002425252600000030242526000000000000000000006500000000001700000000280000ef00000000
24252600000000dbda00000000000065656500000000682426780000000000000000000000000000000000000000000000000000000000ef00000000ef00000024252525266500000024252526000000000000000000000024252526001a0030242526000000000000000000006565656500000000000000000000ef00000000
31323300000000000000000000000000000000000000683133780000000000000000000000000000000000000000000000000000000000ef00000000ef0000003132323233656565653132323317171717171717171717173132323300000037313233000000000000004100000000000000000000000000000000ef00000000
34353621222321222223212223343535362122222223000000000000000000000000000021222222222223212300000000000000000000ef00000000ff00000021222222222222222223212222222223212222222222222222222321222222232123212222222222232122222222232122222321222321222222222222222223
21222331323324252526242526212222232425252526000000cad90000000000000000003132323232323324260000cacccccccc000000ef000000000000000024252525252525252526242525252526313232323232323232323331323232332426242525252525262425252525262425252624252624252525252525252526
242526212223242525262425262425252624252525260000dbcaca0000000000cc0000002122222321222324260000dbcacacaca000000ff002800000000000024252525252525252526242525252526212223212222222222222222222222232426242525252525262425252525262425252624252624252525252525252526
242526242526242525263132333132323331323232330000cacaca00000000dbcaca0000242525262425262426000000dbcacad900000000000000000000000031323232323232323233242525252526242526242525252525252525252525262426242525252525263132323232333132323324252624252525252525252526
242526242526313232333435361b201b201b3435353600dbcacaca000000dbcacad9000031323233313233313300000000caca0000280000000000000028000021222222232122222223242525252526242526242525252525252525252525262426242525252525262122222222222222222324252624252525252525252526
313233242526201b1b201b201b001b001b00201b1b200000dcdc00000000cacad90000001b34361b1b1b34361b0000000000000000000000000000000000000024252525263132323233313232323233242526313232323232323232323232332426242525252525262425252525252525252624252631323232323232323233
201b1b3132331b00001b001b0000000000001b1c001b0000000000000000dbcaca000000001b1b0000001b1b000000000000000000000000000000000000000024252525263435353535361b34361b1b3132331b34361b1b1b20212334353536242631323232323233313232323232323232333132331b343535361b34361b1b
1b00001b1b1b000000000000000000000000000000000000000000eb000000dc000000000000000016002c0000000000000000000000000000e9ea000000000031323232331b1b201b1b1b001b1b00001b1b1b001b1b0000001b31331b1b201b3133201b34353535353535353535361b3435361b201b001b1b1b1b001b1b0000
000000000000001111000000000000000000000000000000000000000000000000000000000000000000000000000000121200000000000000f9fa00000000001b1b1b1b1b00001b0000001c00000000000000000000000000001b1b00001b001b1b1b001b34361b1b1b34361b201b001b1b1b001b0000000000000000000000
00010000000000343611212223171717171721222327000000280000000000280000000000171700000017170000000017170000000000000000000000000000000000000000000000000000000000000011111100000000110000000000000000000000001b1b0000001b1b001b000000000000000000000000000000000000
2122231717171721222324252600000000002425263000000000000000000000000000000000000000000000000000000000000000280000000000000028000000010000001212000000002123171717172122231717171721230016000012121200000000000000000000000000001100000000000000112122231717171717
242526000000003132332425260000000000242526300000cad9000000000000cccc0000000000cacccccc000000000000000000000000000000000000000000212223271717171721222324262b00003b2425262b00003b24262122231717171717212223000000000000002c00112123171717171721232425262b0000003b
313233000000002122233132330000000000313233370000cacad900000000dbcacaca00000000cacacacacacc0000000000ccccdada000000000000ee000000242526302b00003b24252624262b00003b2425262b00003b24262425262b0000003b2425262122231717172122232724262b0000003b24262425262b0000003b
212223000000002425262122230000000000212222230000dbcacacad90000cacacad900000000dccadcdccacaca000000dadadadcdcee0000280000ef000000313233302b00003b24252624262b00003b2425262b00003b24262425262b0000003b2425262425262b003b2425263024262b0000003b24262425262b0000003b
2425260000000024252624252600000000002425252600000000dbcaca0000dccad900000000000000000000dc00000000dcdc000000ef0000000000ef000000212223302b00003b24252624262b00003b2425262b00003b24262425262b0000003b2425262425262b1a3b2425263024262b0000003b24262425262b0000003b
313233000000003132333132330000000000313232330000000000000000000000000000000000000000000000000000000000000000ef0000000000ef000000313233372b00003b31323331332b00003b3132332b00003b31333132332b0000003b3132333132332b003b3132333731332b0000003b31333132332b0000003b
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200170000600017000170023600017000160000600017000060001700076002360000600017000060001700017000170000600236000170001600006000170000600256000160023600256000170023600
012000001d0001d0001d0001d000180001800018000180001b0001b00022000220001f0001f00016000160001d0001d0001d000130001800018000180001f000240002200016000130001d0001b0001800018000
01100000070000700007000110000700007000030000f0000a0000a0000a0000a0000a0000a0000500031000030000300003000030000c0000c0001100016000160000f000050000a00005000030000a0000a000
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
01030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
001000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
c02000001855218552185521855218552185521f5021d5021c5021d5021f5021f5021f5021e5021e5021e5021f5021f5021f5521f5521f5521d5521d5521d55218552185521b5521b5521b5521b5521b5521b552
c12000001b5021b5021b5021b50222502225021f5021d50217502175021b5021b5021b5021e5021e5021e5021a5521a5521f5521f5521f5521f5521f5521f5521f5021f5021b5021b5021b5021b5021b5021b502
001000201400018000180001d0001d0001d0002100021000210001a000190001a0000e1000e1000e1000d1000d1000d1000d1000d100011000c1000c1000b1000b1000b1000b1000b10000100011000110001100
0108002001700017003f6003b6003c6003b6003f6003160023600236003c600000003f60000000017000170001700017003f6003f6003f600000003f60000000236002360000000000003f600000000000000000
01200020000000a1000a1000a1001110011100111001b1001b10018100181001810013100131001310013100131000f1000f1000f100111001110011100161001610013100131001310013100131001310013100
0001002027700297002a700276002660027600286002d0002d6002d6002d0002d6001d700247001d700247001f700277001f700277001f7002770029700307002970030700297003070029700307002970030700
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
0018002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
00010000266502665027250286502725028250286502865028640296302a6202b6102b6102b6102b6102a6202a610356003660035600006000060000600006000060000600006000060000600000000000000000
__music__
01 114a5644
00 12564c44
00 11564c44
02 124b4c44
01 51135244
00 4a564c44
00 4a564c44
02 4a515244
00 41424344
00 41424344
01 18191a44
00 18191a44
00 1c1b1a44
00 1d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a272944
00 2a272944
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 34312744
02 35322744
00 41424344
01 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 114a5644
02 12564c44
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
03 41424316

