pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
--newleste.p8 core

--original game by:
--maddy thorson + noel berry

-- based on evercore v2.0.2
--with major project contributions by
--taco360, meep, gonengazit, and akliant

-- [data structures]

function vector(x,y)
  return {x=x,y=y}
end

function rectangle(x,y,w,h)
  return {x=x,y=y,w=w,h=h}
end

-- [globals]


objects,got_fruit, --tables
freeze,delay_restart,sfx_timer,ui_timer, --timers
cam_x,cam_y,cam_spdx,cam_spdy,cam_gain,cam_offx,cam_offy, --camera values <camtrigger>
_pal, --for outlining
shake,screenshake
=
{},{},
0,0,0,-99,
0,0,0,0,0.1,0,0,
pal,
0,false

lava=false
lt=0

local _g=_ENV --for writing to global vars

-- [entry point]

function _init()
  max_djump,deaths,frames,seconds,minutes,time_ticking,berry_count=1,0,0,0,0,true,0
  music(0,0,7)
  load_level(1)
end


-- [effects]

clouds={}
for i=0,16 do
  add(clouds,{
    x=rnd"128",
    y=rnd"128",
    spd=1+rnd"4",
    w=32+rnd"32"
  })
end

particles={}
for i=0,24 do
  add(particles,{
    x=rnd"128",
    y=rnd"128",
    s=flr(rnd"1.25"),
    spd=0.25+rnd"5",
    off=rnd(),
    c=6+rnd"2",
  })
end

dead_particles={}

-- [player entity]

player={
  init=function(_ENV)
    djump, hitbox, collides,layer = max_djump, rectangle(1,3,6,5), true,2
    canslide=true
    --<fruitrain>--
    -- ^ refers to setting berry_timer and berry_count to 0
    foreach(split"grace,jbuffer,dash_time,dash_effect_time,dash_target_x,dash_target_y,dash_accel_x,dash_accel_y,spr_off,berry_timer,berry_count", function(var)
      _ENV[var]=0
    end)
    create_hair(_ENV)
  end,
  update=function(_ENV)
    if pause_player then
      return
    end

    -- horizontal input
    local h_input=split"0,-1,1,1"[btn()%4+1]

    -- spike collision / bottom death
    if is_flag(0,0,-1) or
	    y>lvl_ph and not exit_bottom and not center then
	    kill_player(_ENV)
	   elseif center then
      if _ENV.y>lvl_ph+16 then
       _ENV.y=-16
      end
    end
    
    if lavaactive=="true" then
     if _ENV.y>ly-4 or _ENV.y<ly-96 then
      kill_player(_ENV)
     end
    elseif lavaactive=="up" then
     if _ENV.y>ly-4 then
      kill_player(_ENV)
     end 
    end

    -- on ground checks
    local on_ground=is_solid(0,1)

        -- <fruitrain> --
    if is_solid(0,1,true) then
      berry_timer+=1
    else
      berry_timer, berry_count=0, 0
    end

    for i,f in inext,fruitrain do
      if f.type==fruit and not f.golden and berry_timer>5 then
        -- to be implemented:
        -- save berry
        -- save golden
        berry_count+=1
        _g.berry_count+=1
        berry_timer, got_fruit[f.fruit_id]=-5, true
        init_object(lifeup, f.x, f.y,berry_count)
        del(fruitrain, f)
        destroy_object(f);
        (fruitrain[i] or {}).target=f.target
      end
    end
    -- </fruitrain> --

    -- landing smoke
    if on_ground and not was_on_ground then
      init_smoke(0,4)
    end

    -- jump and dash input
    local jump,dash=btn(🅾️) and not p_jump,btn(❎) and not p_dash
    p_jump,p_dash=btn(🅾️),btn(❎)

    -- jump buffer
    if jump then
      jbuffer=5
    end
    jbuffer=max(jbuffer-1)

    -- grace frames and dash restoration
    if on_ground then
      grace=7
      if djump<max_djump and not is_core(0,1) then
        psfx"22"
        djump=max_djump
      end
    end
    grace=max(grace-1)

    -- dash effect timer (for dash-triggered events, e.g., berry blocks)
    dash_effect_time-=1

    -- dash startup period, accel toward dash target speed
    if dash_time>0 then
      init_smoke()
      dash_time-=1
      spd=vector(
        appr(spd.x,dash_target_x,dash_accel_x),
        appr(spd.y,dash_target_y,dash_accel_y)
      )
    else
      -- x movement
      local accel=on_ground and 0.6 or 0.4

      -- set x speed
      spd.x=abs(spd.x)<=1 and
        appr(spd.x,h_input,accel) or
        appr(spd.x,sign(spd.x),0.15)

      -- facing direction
      if spd.x~=0 then
        flip.x=spd.x<0
      end

      -- y movement
      local maxfall=2

      -- wall slide
      if is_solid(h_input,0) and _ENV.canslide then
        maxfall=0.4
        -- wall slide smoke
        if rnd()<0.2 then
          init_smoke(h_input*6)
        end
      end

      -- apply gravity
      if not on_ground then
        spd.y=appr(spd.y,maxfall,abs(spd.y)>0.15 and 0.21 or 0.105)
      end

      -- jump
      if jbuffer>0 then
        if grace>0 then
          -- normal jump
          psfx"18"
          jbuffer,grace,spd.y=0,0,-2
          init_smoke(0,4)
        else
          -- wall jump
          local wall_dir=is_solid(-3,0) and -1 or is_solid(3,0) and 1
          if wall_dir then
            psfx"19"
            jbuffer,spd=0,vector(wall_dir*-2,-2)
            -- wall jump smoke
            init_smoke(wall_dir*6)
          end
        end
      end

      -- dash
      if dash then
        if djump>0 then
          init_smoke()
          djump-=1
          dash_time,_g.has_dashed,dash_effect_time=4, true, 10
          -- vertical input
          local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
          -- calculate dash speeds
          local dspd=h_input&v_input==0 and 5 or 3.5355339059
          spd=vector(h_input~=0 and h_input*dspd or
          v_input~=0 and 0 or flip.x and -1 or 1,
          v_input*dspd)
          -- effects
          psfx"20"
          _g.freeze,_g.shake=2,5
          -- dash target speeds and accels
          dash_target_x,dash_target_y,dash_accel_x,dash_accel_y=
          2*sign(spd.x), split"-1.5,0,2"[v_input+2],
          v_input==0 and 1.5 or 1.06066017177 , spd.x==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()


          -- emulate soft dashes
          if ph_input==-h_input and oob(ph_input,0) then
            spd.x=0
          end

        else
          -- failed dash smoke
          psfx"21"
          init_smoke()
        end
      end
    end

    -- animation
    spr_off+=0.25
    sprite = on_ground and (
      btn(⬇️) and 6 or -- crouch
      btn(⬆️) and 7 or -- look up
      spd.x*h_input~=0 and 1+spr_off%4 or 1) -- walk or stand
      or is_solid(h_input,0) and 5 or 3 -- wall slide or mid air

    update_hair(_ENV)

    -- exit level (except summit)
    if (exit_right and left()>=lvl_pw or
        exit_top and y<-4 or
        exit_left and right()<0 or
        exit_bottom and top()>=lvl_ph) and levels[lvl_id+1] then
      next_level()
    end

    -- was on the ground, previous horizontal input (for soft dashes)
    was_on_ground,ph_input=on_ground, h_input
  end,

  draw=function(_ENV)
    -- draw player hair and sprite
    pal(2,djump==2 and 8 or 2)
    pal(8,djump==1 and 8 or djump==2 and 2 or 12)
    draw_hair(_ENV)
    pal(7,15,1)
    draw_obj_sprite(_ENV)
--    pal()
  end
}

function create_hair(_ENV)
  hair={}
  for i=1,5 do
    add(hair,vector(x,y))
  end
end


function update_hair(_ENV)
  local last=vector(x+(flip.x and 6 or 1),y+(btn(⬇️) and 4 or 2.9))
  foreach(hair, function(h)
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    last=h
  end)
end

function draw_hair(_ENV)
  for i,h in inext,hair do
    circfill(round(h.x),round(h.y),split"2,2,1,1,1"[i],8)
  end
end

-- [other entities]

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
    --- <fruitrain> ---
    foreach(fruitrain, function(f)
      --this gets called many times but saves tokens for checking if fruitrain is empty
      fruitrain[1].target=_ENV

      add(objects,f)
      f.x,f.y=x,y
      fruit.init(f)
    end)
    --- </fruitrain> ---
  end,
  update=function(_ENV)
    -- jumping up
    if state==0 and y<target+16 then
        state,delay=1, 3
    -- falling
    elseif state==1 then
      spd.y+=0.5
      if spd.y>0 then
        if delay>0 then
          -- stall at peak
          spd.y=0
          delay-=1
        elseif y>target then
          -- clamp at target y
          y,spd,state,delay,_g.shake=target,vector(0,0),2,5,4
          init_smoke(0,4)
          sfx"16"
        end
      end
    -- landing and spawning player object
    elseif state==2 then
      delay-=1
      sprite=6
      if delay<0 then
        destroy_object(_ENV)
        local p=init_object(player,x,y);
        --- <fruitrain> ---
        (fruitrain[1] or {}).target=p
        --- </fruitrain> ---
      end
    end
    update_hair(_ENV)
  end,
  draw=player.draw
  -- draw=function(this)
  --   set_hair_color(max_djump)
  --   draw_hair(this,1)
  --   draw_obj_sprite(this)
  --   unset_hair_color()
  -- end
}

--<camtrigger>--
camera_trigger={
  update=function(_ENV)
    if timer and timer>0 then
      timer-=1
      if timer==0 then
        _g.cam_offx,_g.cam_offy=offx,offy
      else
        _g.cam_offx+=cam_gain*(offx-cam_offx)
        _g.cam_offy+=cam_gain*(offy-cam_offy)
      end
    elseif player_here() then
      timer=5
    end
  end
}
--</camtrigger>--


spring={
  init=function(_ENV)
    delta,dir=0,sprite==9 and 0 or is_solid(-1,0) and 1 or -1
  end,
  update=function(_ENV)
    delta*=0.75
    --can save tokens by setting hit as _ENV
    --but i'm not desperate enough yet
    local hit=player_here()
    if hit then
      if dir==0 then
        hit.move(0,y-hit.y-4,1)
        hit.spd.x*=0.2
        hit.spd.y=-3
      else
        hit.move(x+dir*4-hit.x,0,1)
        hit.spd=vector(dir*3,-1.5)
      end
      hit.dash_time,hit.dash_effect_time,delta,hit.djump=0,0,4,max_djump
    end
  end,
  draw=function(_ENV)
    local delta=flr(delta)
    if dir==0 then
      sspr(72,0,8,8-delta,x,y+delta)
    else
      spr(8,dir==-1 and x+delta or x,y,1-delta/8,1,dir==1)
    end
  end
}

refill={
  init=function(_ENV)
    offset,timer,hitbox=rnd(),0,rectangle(-1,-1,10,10)
  end,
  update=function(_ENV)
    if timer>0 then
      timer-=1
      if timer==0 then
        psfx"12"
        init_smoke()
      end
    else
      offset+=0.02
      local hit=player_here()
      if hit and hit.djump<max_djump then
        psfx"11"
        init_smoke()
        hit.djump,timer=max_djump,60
      end
    end
  end,
  draw=function(_ENV)
    if timer==0 then
      spr(15,x,y+sin(offset)+0.5)
    else
      -- color"7"
      -- line(x,y+4,x+3,y+7)
      -- line(x+4,y+7,x+7,y+4)
      -- line(x+7,y+3,x+4,y)
      -- line(x+3,y,x,y+3)
      foreach(split(
      [[0,4,3,7
      4,7,7,4
      7,3,4,0
      3,0,0,3]],"\n"),function(t)
        local o1,o2,o3,o4=unpack(split(t))
        line(x+o1,y+o2,x+o3,y+o4,7)
      end
      )
    end
  end
}

fall_floor={
  init=function(_ENV)
    solid_obj,state,unsafe_ground,delay=true,0,true,0
  end,
  update=function(_ENV)
    --it looks like weird stuff goes on here with the decimal constants (mostly to ensure rounding correctly), but it should be equivalent to vanilla
    --(and if i made an error, probably no one cares)
    -- idling
    if delay>0 then
      delay-=0.2
    elseif state==0 then
      for i=-1,1 do
        if check(player,i,abs(i)-1) then
          psfx"13"
          state,delay=1,2.79
          init_smoke()
          break
        end
      end
    -- shaking
    elseif state==1 then
      state,delay,collideable=2,11.79--,false
    -- invisible, waiting to reset
    else
      if not player_here() then
        psfx"12"
        state,collideable=0,true
        init_smoke()
      end
    end
    --if sprite 0 is not empty, need to fixup this
    sprite=state==1 and 25.8-delay or state==0 and 23
  end
}

smoke={
  init=function(_ENV)
    layer,spd,flip=3,vector(0.3+rnd"0.2",-0.1),vector(rnd()<0.5,rnd()<0.5)
    x+=-1+rnd"2"
    y+=-1+rnd"2"
  end,
  update=function(_ENV)
    sprite+=0.2
    if sprite>=29 then
      destroy_object(_ENV)
    end
  end
}
launch={
init=function(_ENV)
 segments={}
 add(segments,{x=x,y=y,s=65})
 checkx=8
 checky=0
 c=true
 cd=true
 solid_obj=true
 maxcheckx=0
 maxchecky=0
 q=0
 hide=false
 hide_for=0
 ox=x
 oy=y
 h=0
 e="0"
 shatter=false
end,
update=function(_ENV)
if c then
 if tile_at(
 (x+checkx)/8,
 (y+checky)/8)==81 then
  add(segments,
  {x=x+checkx,
  y=y+checky,
  s=tile_at(
  (x+checkx)/8,
  (y+checky)/8),
  fx=false,
  fy=false})
  checkx+=8
 else
  maxcheckx=checkx
  maxchecky=segments[#segments].y
  checky+=8
  checkx=0
  if tile_at((x+checkx)/8,(y+checky)/8)!=81 then
   c=false
   hitbox=rectangle(
   0,
   0,
   maxcheckx,
   checky)
  end
 end
elseif cd then 
 for i in all(segments) do
  if i.x==segments[#segments].x then
   i.fx=true
   if i.y==y then
    i.s=65
   end
  end
  if i.x==x and i.y>y then
   i.s=36
  end
  if i.y==segments[#segments].y then
   i.fy=true
   if i.x==segments[#segments].x or i.x==x then
    i.s=65
   end
  end
  i.ox=i.x
  i.oy=i.y
  x=ox
  y=oy
 end
 cd=false
end
if hide==false and lava then 
   hitbox=rectangle(
   -1,
   -1,
   maxcheckx+2,
   checky)
 hit=player_here()
if hit and not hide then
q+=0.0333
if q<0.5 then
 for i in all(segments) do
  i.y+=q
 end
 y+=q
 hit.y+=q
elseif q>0 then
 q-=2
end
 h+=1
if h>20 then
 psfx"8"
 hit.spd=vector(hit.spd.x,-3.14)
 hide=true
 hide_for=80
 h=0
 q=0
end
end
   hitbox=rectangle(
   0,
   0,
   maxcheckx,
   checky)
elseif not hide then
   hitbox=rectangle(
   -1,
   -1,
   maxcheckx+2,
   checky)
   hit=player_here()
if hit then
 shatter=true
end
if shatter then
psfx"15"
q+=0.03
if q<0.5 then
 for i in all(segments) do
  i.y+=q
 end
 y+=q
if hit then
 hit.y+=q
end
elseif q>0 then
end
 h+=1
if h>20 then
 hide=true
 hide_for=80
 h=0
 q=0
end
end
   hitbox=rectangle(
   0,
   0,
   maxcheckx,
   checky)
end
if hide==false then
outline=false
end
if hide then
outline=true
hitbox=rectangle(0,0,maxcheckx,checky)
solid_obj=false
hide_for-=1
hit=player_here()
if hide_for<=0 and not hit then
 hide_for=0
 for i in all(segments) do
  init_smoke(0,0)
 end
 hide=false
 solid_obj=true
 for i in all(segments) do
  i.x=i.ox
  i.y=i.oy
 end
  x=ox
  y=oy
  shatter=false
end
end
if not hit and cd==false then
if shatter==false or hide then
 x=ox
 y=oy
 for i in all(segments) do
  i.x=i.ox
  i.y=i.oy
 end
 q=0
 h=0
end
end
if lava then
 shatter=false
end
end,

draw=function(_ENV)
if hide==false then 
 if cd==false then
  pal(2,1)
  pal(8,13)
  pal(11,8)
  pal(3,2)
  for i in all(segments) do
   if i.y>y and i.y<segments[#segments].y then
    spr(38,segments[#segments].x,i.y)
   end
   spr(i.s,i.x,i.y,1,1,i.fx,i.fy)
   rectfill(x+8,y+8,segments[#segments].x-1,segments[#segments].y-1,2)
   if lava==false then
    pal(11,12)
    pal(3,1)
   end
   spr(66,(x+segments[#segments].x)/2,(y+segments[#segments].y)/2)
  end
  pal()
 end
elseif player_here() then
 rect(x-1,y-1,segments[#segments].x+8,segments[#segments].y+8,6)
end
end
}
heart={
  init=function(_ENV)
   offset=rnd()
   outline=true
   start=y
   e=false
   solid_obj=false
   hitbox=rectangle(0,0,16,16)
   hide=false
  end,
  update=function(_ENV)
    midx=x+8
    midy=y+8
    hit=player_here()    
    if hit and hide==false then
     if hit.x>midx then
      hit.spd=vector(0.3*(hit.x-(x+8)),hit.spd.y)
     end
     if hit.x<midx then
      hit.spd=vector(0.3*(hit.x-(x)),hit.spd.y)
     end
     if hit.y<midy then
      hit.spd=vector(hit.spd.x,0.2*(hit.y-(y)))
     end
     if hit.y>midy then
      hit.spd=vector(hit.spd.x,0.05*(hit.y-(y-8)))
     end         
    end
    if hit and hit.dash_effect_time>0 then
     e=true
     for ox=0,8,8 do
      for oy=0,8,8 do
       init_smoke(ox,oy)
      end
     end
     hide=true
    end
    if not show and e then
      sfx"55"
      sfx_timer,show,time_ticking=30,true,false
    end
      offset+=0.01
      y=start+sin(offset)*2
  end,
  draw=function(_ENV)
   if hide==false then
    sspr(112,16,8,16,x,y)
    sspr(112,16,8,16,x+8,y,8,16,true)
   end
    if show then
      pal()
      camera()
      rectfill(32,2,96,31,0)
      spr(10,55,6)
      ?"x"..berry_count,64,9,7
      draw_time(49,16)
      ?"deaths:"..deaths,48,24,7
      camera(draw_x,draw_y)
    end
  end
}
bubble={
init=function(_ENV)
 outline=true
 hitbox=rectangle(2,5,10,12)
 hide=false
end,
update=function(_ENV)
 if lava==false then
  hitbox=rectangle(2,5,10,12)
 elseif lava then
  hitbox=rectangle(4,4,12,12)
 end
 hit=player_here()
 if hit and lava then
  kill_player(hit)
 end
 if hide==false and lava==false then
 if hit and hity<y+3 then
  if btn(🅾️) then
   hitspd=vector(hitspdx,-2)
   psfx"1"
  else
   psfx"2"
   hitspd=vector(hitspdx,-13)
  end
  hide=true
  for ox=1,8,2 do
   init_smoke(ox,2)
  end
 elseif hit then
  kill_player(hit) 
 end
 end
 if sprite==64 then
  y-=03
 elseif sprite==80 then
  y+=03
 elseif sprite==96 then
  x-=03
 elseif sprite==112 then
  x+=03
 end
 
 --placeholder screenwrapping
x=x%((lvl_w*8))
y=y%((lvl_h*8))
end,
draw=function(_ENV)
  if hide==false and lava==false then--draw sprs
    sspr(0,32,8,16,x,y)
    sspr(0,32,8,16,x+8,y,8,16,true)
  elseif hide==false and lava then
    sspr(0,48,8,16,x,y)
    sspr(0,48,8,16,x+8,y,8,16,true,true)
  end
end
}
booster={
 init=function(_ENV)
  outline=true
  solid_obj=false
  hitbox=rectangle(5,0,3,9)
  s=104
  q=0
  f=false
  off=0
  off2=0
 end,
 update=function(_ENV)
  if sprite==47 then
   f=true
   hitbox=rectangle(-1,0,3,9)
  end
  hit=player_here()
  if hit and lava==true then
   if hit.spd.y>-2 then
    hit.spd=vector(hit.spd.x,-abs(hit.spd.y)-0.4)
   end
  end
  if hit and lava==false then
   hit.canslide=false
  end
  if lava==true then
   off+=1.2
   if off>8 then off=0 end
  end
  off2+=0.5
  if off2>2 then off2=0 end
 end,
 draw=function(_ENV)
  if lava==true then
   sspr(120,8+off,8,8,x,y,8,8,f)
   if off2==0 then
    pal(2,8)
   end
   if tile_at(x/8,(y/8)-1)!=sprite then
    spr(97,x,y,1,1,f)
   end
   if tile_at(x/8,(y/8)+1)!=sprite then
    spr(97,x,y+4,1,1,f)
   end
   pal()
  else
   spr(63,x,y,1,1,f)
   if tile_at(x/8,(y/8)-1)!=sprite then
    sspr(8,56,8,3,x,y,8,3,f)
   end
   if tile_at(x/8,(y/8)+1)!=sprite then
    sspr(8,61,8,3,x,y+5,8,3,f)
   end
  end
 end
}
wall={
 init=function(_ENV)
  id=sprite==45 and true or false
 end,
 
 update=function(_ENV)
  hit=player_here()
  if id and hit and lava then
   kill_player(hit)
  elseif hit and not lava and not id then
   kill_player(hit)
  end
 end,
 
 draw=function(_ENV)
  if id and lava then
   spr(45,x,y) 
  elseif not lava and not id then
   spr(61,x,y)
  else
   
  end
 end
}
bumper={
  init=function(_ENV)
    outline=true
    solid_obj=false
    hitbox=rectangle(0,0,16,16)
    sy=32
    is_active=true
    eep=0
    j,q=0,0
    startx=x
    starty=y
    off=0
    off2=0
    offj=0.01
    offmul=rnd"1"
    if flr(rnd"2")==0 then
     offj=-offj
    end
  end,
  update=function(_ENV)
    off+=offj
    off2+=offj*3
    x=startx+sin(off2)*1.1+offmul
    y=starty+cos(off)*1.2+offmul
    midx=x+8
    midy=y+8
    hitbox=rectangle(-1,-1,18,18)
    local hit=player_here()
    if hit and not lava and is_active then
     hit.grace=0 
     if hit.x>midx then
      hit.spd=vector(0.6*(hit.x-(x+8)),hit.spd.y)
     end
     if hit.x<midx then
      hit.spd=vector(0.6*(hit.x-(x)),hit.spd.y)
     end
     if hit.y<midy then
      hit.spd=vector(hit.spd.x,0.4*(hit.y-(y)))
     end
     if hit.y>midy then
      hit.spd=vector(hit.spd.x,0.1*(hit.y-(y-8)))
     end
     sfx"9"
     is_active=false
     eep=20
    end
    if lava and hit then
     kill_player(hit)
    end
    if lava then
     sy=72
     is_active=true
    elseif is_active then
     sy=64
    end
    if not is_active then
     sy=80
     eep-=1
    end
    if eep<=0 and not lava then
     is_active=true
     sy=64
     q=0
     j=0
    end
    if j>2 then j=0 end
    hitbox=rectangle(3,3,13,13)
  end,
  draw=function(_ENV)
    sspr(sy,16,8,16,x,y)
    sspr(sy,16,8,16,x+8,y,8,16,true)
    if not is_active and q<15 then
     circ(x+7,y+7,10+j,12)
     circ(x+8,y+7,10+j,12)
     circ(x+7,y+8,10+j,12)
     circ(x+8,y+8,10+j,12)
     q+=5
     j+=1
    end
  end
}

switch={

init=function(_ENV) 
 outline=true
 tp=sprite==59 and true or false
 active=true
 x+=4
 hitbox=rectangle(0,0,8,8)
end,

update=function(_ENV)
 
 local hit=player_here()
 
 if not lava and not tp then
  active=false
 elseif not tp then
  active=true
 elseif not lava then
  active=true
 end
 
 if hit and active and tp then
  _g.lava=true
  active=false
 elseif hit and active then
  _g.lava=false
  active=false
 end

end,

draw=function(_ENV)

if active then
  spr(sprite,x,y)
else
  spr(sprite+1,x,y)
end

end

}

--- <fruitrain> ---
fruitrain={}
fruit={
  check_fruit=true,
  init=function(_ENV)
    y_,off,tx,ty,golden=y,0,x,y,sprite==11
    if golden and deaths>0 then
      destroy_object(_ENV)
    end
  end,
  update=function(_ENV)
    if target then
      tx+=0.2*(target.x-tx)
      ty+=0.2*(target.y-ty)
      local dtx,dty=x-tx,y_-ty
      local a,k=atan2(dtx,dty),dtx^2+dty^2 > r^2 and 0.2 or 0.1
      x+=k*(r*cos(a)-dtx)
      y_+=k*(r*sin(a)-dty)
    else
      local hit=player_here()
      if hit then
        hit.berry_timer,target,r=
        0,fruitrain[#fruitrain] or hit,fruitrain[1] and 8 or 12
        add(fruitrain,_ENV)
      end
    end
    off+=0.025
    y=y_+sin(off)*2.5
  end
}
--- </fruitrain> ---

fly_fruit={
  check_fruit=true,
  init=function(_ENV)
    start,step,sfx_delay=y,0.5,8
  end,
  update=function(_ENV)
    --fly away
    if has_dashed then
      sfx_delay-=1
      if sfx_delay==0 then
       _g.sfx_timer=20
       sfx"10"
      end
      spd.y=appr(spd.y,-3.5,0.25)
      if y<-16 then
        destroy_object(_ENV)
      end
    -- wait
    else
      step+=0.05
      spd.y=sin(step)*0.5
    end
    -- collect
    if player_here() then
      --- <fruitrain> ---
      init_smoke(-6)
      init_smoke(6)

      local f=init_object(fruit,x,y,10) --if this happens to be in the exact location of a different fruit that has already been collected, this'll cause a crash
      --TODO: fix this if needed
      f.fruit_id=fruit_id
      fruit.update(f)
      --- </fruitrain> ---
      destroy_object(_ENV)
    end
  end,
  draw=function(_ENV)
    spr(10,x,y)
    for ox=-6,6,12 do
      spr((has_dashed or sin(step)>=0) and 12 or y>start and 14 or 13,x+ox,y-2,1,1,ox==-6)
    end
  end
}

lifeup={
  init=function(_ENV)
    spd.y,duration,flash,_g.sfx_timer,outline=-0.25,30,0,20--,false
    sfx"9"
  end,
  update=function(_ENV)
    duration-=1
    if duration<=0 then
      destroy_object(_ENV)
    end
    flash+=0.5
  end,
  draw=function(_ENV)
    --<fruitrain>--
    ?split"1000,2000,3000,4000,5000,1up"[min(sprite,6)],x-4,y-4,7+flash%2
    --<fruitrain>--
  end
}


psfx=function(num)
  if sfx_timer<=0 then
   sfx(num)
  end
end

-- [tile dict]
tiles={}
foreach(split([[
1,player_spawn
8,spring
9,spring
10,fruit
11,fruit
12,fly_fruit
15,refill
23,fall_floor
40,bumper
43,switch
59,switch
31,booster
47,booster
65,launch
46,heart
64,bubble
80,bubble
96,bubble
112,bubble
45,wall
61,wall
]],"\n"),function(t)
 local tile,obj=unpack(split(t))
 tiles[tile]=_ENV[obj]
end)

-- [object functions]

function init_object(_type,sx,sy,tile)
  --generate and check berry id
  local id=sx..","..sy..","..lvl_id
  if _type.check_fruit and got_fruit[id] then
    return
  end
  --local _g=_g
  local _ENV=setmetatable({},{__index=_g})
  type, collideable, sprite, flip, x, y, hitbox, spd, rem, fruit_id, outline, draw_seed=
  _type, true, tile, vector(), sx, sy, rectangle(0,0,8,8), vector(0,0), vector(0,0), id, true, rnd()

  function left() return x+hitbox.x end
  function right() return left()+hitbox.w-1 end
  function top() return y+hitbox.y end
  function bottom() return top()+hitbox.h-1 end

  function is_solid(ox,oy,require_safe_ground)
    for o in all(objects) do
      if o!=_ENV and (o.solid_obj or o.semisolid_obj and not objcollide(o,ox,0) and oy>0) and objcollide(o,ox,oy) and not (require_safe_ground and o.unsafe_ground) then
        return true
      end
    end
    return oy>0 and not is_flag(ox,0,3) and is_flag(ox,oy,3) or  -- one way platform or
            is_flag(ox,oy,0) -- solid terrain
  end
  function is_core(ox,oy)
   for o in all(objects) do
     if o!=ENV and (o.solid_obj or o.semisolid_obj and not obj.objcollide(o,ox,0) and oy>0) and objcollide(o,ox,oy) then
       return true
     end
   end
   return _ENV.is_flag(ox,oy,6)
  end
  function oob(ox,oy)
    return not exit_left and left()+ox<0 or not exit_right and right()+ox>=lvl_pw or top()+oy<=-8
  end

  
  function is_flag(ox,oy,flag)
    for i=mid(0,lvl_w-1,(left()+ox)\8),mid(0,lvl_w-1,(right()+ox)/8) do
      for j=mid(0,lvl_h-1,(top()+oy)\8),mid(0,lvl_h-1,(bottom()+oy)/8) do
        local tile=tile_at(i,j)
        if flag>=0 then
          if fget(tile,flag) and (flag~=3 or j*8>bottom()) then
            return true
          end
        elseif ({spd.y>=0 and bottom()%8>=6,
          spd.y<=0 and top()%8<=2,
          spd.x<=0 and left()%8<=2,
          spd.x>=0 and right()%8>=6})[tile-15] then
            return true
        end
      end
    end
  end
  function objcollide(other,ox,oy)
    return other.collideable and
    other.right()>=left()+ox and
    other.bottom()>=top()+oy and
    other.left()<=right()+ox and
    other.top()<=bottom()+oy
  end
  function check(type,ox,oy)
    for other in all(objects) do
      if other.type==type and other~=_ENV and objcollide(other,ox,oy) then
        return other
      end
    end
  end

  function player_here()
    return check(player,0,0)
  end

  function move(ox,oy,start)
    for axis in all{"x","y"} do
      rem[axis]+=vector(ox,oy)[axis]
      local amt=round(rem[axis])
      rem[axis]-=amt

      local upmoving=axis=="y" and amt<0
      local riding,movamt=not player_here() and check(player,0,upmoving and amt or -1)--,nil
      if collides then
        local step,p=sign(amt),_ENV[axis]
        local d=axis=="x" and step or 0
        for i=start,abs(amt) do
          if is_solid(d,step-d) or oob(d,step-d) then
            spd[axis],rem[axis]=0,0
            break
          else
            _ENV[axis]+=step
          end
        end
        movamt=_ENV[axis]-p --save how many px moved to use later for solids
      else
        movamt=amt
        if (solid_obj or semisolid_obj) and upmoving and riding then
          movamt+=top()-bottom()-1
          local hamt=round(riding.spd.y+riding.rem.y)
          hamt+=sign(hamt)
          if movamt<hamt then
            riding.spd.y=max(riding.spd.y)--,0)
          else
            movamt=0
          end
        end
        _ENV[axis]+=amt
      end
      if (solid_obj or semisolid_obj) and collideable then
        collideable=false
        local hit=player_here()
        if hit and solid_obj then
          hit.move(axis~="x" and 0 or amt>0 and right()+1-hit.left() or amt<0 and left()-hit.right()-1,
                  axis~="y" and 0 or amt>0 and bottom()+1-hit.top() or amt<0 and top()-hit.bottom()-1,
                  1)
          if player_here() then
            kill_player(hit)
          end
        elseif riding then
          riding.move(vector(movamt,0)[axis],vector(0,movamt)[axis],1)
        end
        collideable=true
      end
    end
  end

  function init_smoke(ox,oy)
    init_object(smoke,x+(ox or 0),y+(oy or 0),26)
  end



  add(objects,_ENV);

  (type.init or time)(_ENV)

  return _ENV
end

function destroy_object(obj)
  del(objects,obj)
end

function kill_player(obj)
  sfx_timer,shake=12,9
  sfx"17"
  deaths+=1
  destroy_object(obj)
  --dead_particles={}
  for dir=0,0.875,0.125 do
    add(dead_particles,{
      x=obj.x+4,
      y=obj.y+4,
      t=2,
      dx=sin(dir)*3,
      dy=cos(dir)*3
    })
  end
    -- <fruitrain> ---
  foreach(fruitrain,function(f)
    full_restart = full_restart or f.golden
  end)
  fruitrain={}
  --- </fruitrain> ---
  delay_restart=15
  -- <transition>
  tstate=0
  -- </transition>
end

-- [room functions]


function next_level()
  load_level(lvl_id+1)
end

function load_level(id)
  --remove existing objects
  foreach(objects,destroy_object)

  --reset camera speed, drawing timer setup
  ui_timer,cam_spdx,cam_spdy,has_dashed=5,0,0--,false

  local diff_level=lvl_id~=id

  --set level index
  lvl_id=id

  --set level globals
  local tbl=split(levels[lvl_id])
  for i=1,4 do
    _ENV[split"lvl_x,lvl_y,lvl_w,lvl_h"[i]]=tbl[i]*16
  end

  lvl_pw,lvl_ph=lvl_w*8,lvl_h*8

  local exits=tonum(tbl[5]) or 0b0001

  -- exit_top,exit_right,exit_bottom,exit_left=exits&1!=0,exits&2!=0,exits&4!=0, exits&8!=0
  for i,v in inext,split"exit_top,exit_right,exit_bottom,exit_left" do
    _ENV[v]=exits&(0.5<<i)~=0
  end
  lvl_li=tbl[6]
  lavaspd=tonum(tbl[8])
  if tbl[9]==true then
   center=true
  else
   center=false
  end
  lavaactive=lvl_li
  if tbl[7]=="lava" then
   lava=true
  else
   lava=false
  end
  ly=lvl_h*8
  --reload map
  if diff_level then
    reload()
  end
    --chcek for mapdata strings
  if mapdata[lvl_id] then
    --hex loaded levels go at (0,0), despite what the levels table says (to make everhorn nicer)
    lvl_x,lvl_y=0,0
    if diff_level then
      --replace mapdata with base256
      --encoding is offset by 1, to avoid shenanigans with null chars
      for i=0,#mapdata[lvl_id]-1 do
        mset(i%lvl_w,i\lvl_w,ord(mapdata[lvl_id][i+1])-1)
      end
    end
  end

  -- entities
  for tx=0,lvl_w-1 do
    for ty=0,lvl_h-1 do
      local tile=tile_at(tx,ty)
      if tiles[tile] then
        init_object(tiles[tile],tx*8,ty*8,tile)
      end
    end
  end

  foreach(objects,function(_ENV)
    (type.end_init or time)(_ENV)
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

  --<camtrigger>--
  --generate camera triggers
  cam_offx,cam_offy=0,0
  for s in all(camera_offsets[lvl_id]) do
    local tx,ty,tw,th,offx_,offy_=unpack(split(s))
    local _ENV=init_object(camera_trigger,tx*8,ty*8)
    hitbox.w,hitbox.h,offx,offy=tw*8,th*8,offx_,offy_
  end
  --</camtrigger>--
end

-- [main update loop]

function _update()
  frames+=1
  if time_ticking then
    seconds+=frames\30
    minutes+=seconds\60
    seconds%=60
  end
  frames%=30

  sfx_timer=max(sfx_timer-1)

  -- cancel if freeze
  if freeze>0 then
    freeze-=1
    return
  end

  -- screenshake toggle
  if btnp(⬆️,1) then
    screenshake=not screenshake
  end

  -- restart (soon)
  if delay_restart>0 then
    cam_spdx,cam_spdy=0,0
    delay_restart-=1
    if delay_restart==0 then
      -- <fruitrain> --
      if full_restart then
        full_restart=false
        _init()
      -- </fruitrain> --
      else
        load_level(lvl_id)
      end
    end
  end

  -- update each object
  foreach(objects,function(_ENV)
    move(spd.x,spd.y,type==player and 0 or 1);
    (type.update or time)(_ENV)
    draw_seed=rnd()
  end)

  --move camera to player
  foreach(objects,function(_ENV)
    if type==player or type==player_spawn then
      move_camera(_ENV)
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

end

-- [drawing functions]

function _draw()
  if freeze>0 then
    return
  end
  
  --set cam draw position
  draw_x,draw_y=round(cam_x)-64,round(cam_y)-64

  if shake>0 then
    shake-=1
    if screenshake then
      draw_x+=-2+rnd"5"
      draw_y+=-2+rnd"5"
    end
  end
  camera(draw_x,draw_y)

  -- draw bg color
  cls()

  -- bg clouds effect
  foreach(clouds,function(_ENV)
    x+=spd-_g.cam_spdx
    _g.rectfill(x+_g.draw_x,y+_g.draw_y,x+w+_g.draw_x,y+16-w*0.1875+_g.draw_y,1)
    if x>128 then
      x,y=-w,_g.rnd"120"
    end
  end)
 
		-- draw bg terrain
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)

  -- draw outlines
  pal(split"1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1")
  pal=time
  foreach(objects,function(_ENV)
    if outline then
      for i=1,4 do
        camera(draw_x+split"-1,0,0,1"[i],draw_y+split"0,-1,1,0"[i]) draw_object(_ENV)
      end
    end
  end)
  pal=_pal
  camera(draw_x,draw_y)
  pal()
  


  --set draw layering
  --0: background layer
  --1: default layer
  --2: player layer
  --3: foreground layer
  local layers={{},{},{}}
  foreach(objects,function(_ENV)
    if layer==0 then
      draw_object(_ENV) --draw below terrain
    else
      add(layers[layer or 1],_ENV) --add object to layer, default draw below player
    end
  end)
  
  -- draw terrain
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
--pal()
  -- draw objects
  foreach(layers,function(l)
    foreach(l,draw_object)
  end)

  -- draw platforms
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,8)
  -- draw fg tiles
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,0x10)
--  pal()
  -- particles
  foreach(particles,function(_ENV)
    x+=spd-_g.cam_spdx
    y+=_g.sin(off)-_g.cam_spdy
    y%=128
    off+=_g.min(0.05,spd/32)
    _g.rectfill(x+_g.draw_x,y+_g.draw_y,x+s+_g.draw_x,y+s+_g.draw_y,c)
    if x>132 then
      x,y=-4,_g.rnd"128"
    elseif x<-4 then
      x,y=128,_g.rnd"128"
    end
  end)

  -- dead particles
  foreach(dead_particles,function(_ENV)
    x+=dx
    y+=dy
    t-=0.2
    if t<=0 then
      _g.del(_g.dead_particles,_ENV)
    end
    rectfill(x-t,y-t,x+t,y+t,14+5*t%2)
  end)
  -- draw time
  if ui_timer>=-30 then
    if ui_timer<0 then
      draw_time(draw_x+4,draw_y+4)
    end
    ui_timer-=1
  end

  if lavaactive=="true" then
   lt+=lavaspd
   if lt>=8 then lt=0 end
   for x=-8,136,8 do
     local qz=sin(x/100)*2
     local lyc=ly+qz
    if lava==true then
     spr(30,x+(cam_x-64)-lt,lyc)
     spr(30,x+(cam_x-64)+lt,lyc-97,1,1,true,true)
    else
     spr(29,x+(cam_x-64),ly+qz)
     spr(29,x+(cam_x-64),ly+qz-97,1,1,true,true)
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
     spr(30,x+(cam_x-64)-lt,lyc)
    else
     spr(29,x+(cam_x-64),ly+qz)
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
  -- <transition>
  camera()
  color"0"
  if tstate>=0 then
    local t20=tpos+20
    if tstate==0 then
      po1tri(tpos,0,t20,0,tpos,127)
      if(tpos>0) rectfill(0,0,tpos,127)
      if(tpos>148) then
        tstate=1
        tpos=-20
      end
    else
      po1tri(t20,0,t20,127,tpos,127)
      if(tpos<108) rectfill(t20,0,127,127)
      if(tpos>148) then
        tstate=-1
        tpos=-20
      end
    end
    tpos+=14
  end
  
  if lava then
   pal(14,141,1)
   pal(1,130,1)
   pal(15,13,1)
  else
   pal(14,140,1)
   pal(6,12,1)
   pal(13,7,1)
   pal(7,15,1)
   pal(15,12,1)
   pal(5,15,1)
  end
  -- </transition>
end

function draw_object(_ENV)
  srand(draw_seed);
  (type.draw or draw_obj_sprite)(_ENV)
end

function draw_obj_sprite(_ENV)
  spr(sprite,x,y,1,1,flip.x,flip.y)
end

function draw_time(x,y)
  rectfill(x,y,x+32,y+6,0)
  ?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds),x+1,y+1,7
end


function two_digit_str(x)
  return sub("0"..x,-2)
end

-- [helper functions]

function round(x)
  return flr(x+0.5)
end

function appr(val,target,amount)
  return mid(val-amount,val+amount,target)
end

function sign(v)
  return v~=0 and sgn(v) or 0
end

function tile_at(x,y)
  return mget(lvl_x+x,lvl_y+y)
end

--<transition>--

-- transition globals
tstate=-1
tpos=-20

-- triangle functions
function po1tri(x0,y0,x1,y1,x2,y2)
  local c=x0+(x2-x0)/(y2-y0)*(y1-y0)
  p01traph(x0,x0,x1,c,y0,y1)
  p01traph(x1,c,x2,x2,y1,y2)
end

function p01traph(l,r,lt,rt,y0,y1)
  lt,rt=(lt-l)/(y1-y0),(rt-r)/(y1-y0)
  for y0=y0,y1 do
    rectfill(l,y0,r,y0)
    l+=lt
    r+=rt
  end
end
-- </transition> --
-->8
--[map metadata]

--@conf
--[[
autotiles={{52, 54, 53, 39, 33, 35, 34, 55, 49, 51, 50, 48, 36, 38, 37, [0] = 32}, {111, 110, 106, 94, 105, 107, 106, 126, 121, 123, 122, 127, 108, 109, 104, 106, 33, 35, 106, [21] = 50, [23] = 106, [28] = 104, [29] = 36, [30] = 38, [31] = 104, [33] = 104, [0] = 104, [35] = 104, [40] = 122, [41] = 49, [42] = 51, [43] = 122, [45] = 122, [47] = 34}}
composite_shapes={}
param_names={"lava direction up/true (room)", "lava/ice active", "lava speed (0-1 preferred)", "isepicenter"}
]]
--@begin
--[[level table
"x,y,w,h,exit,lavarising,is_hot,lavaspd,is_epicenter"
lavarising:up/true(room)
is_hot:true/false
lavaspd:int(less then 1 best)
exit directions 
"0b"+"exit_left"+
"exit_bottom"+
"exit_right"+
"exit_top" 
(default top- 0b0001)
]]
levels={
  "0,0,3,1,0b0010,false,lava,0,false"
}

--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
  {
    "0,0,25,16,0,0",
    "26,0,22,16,50,0"
  }
}
--</camtrigger>--

--mapdata string table
--assigned levels will load from here instead of the map
mapdata={
  "¹¹¹¹¹¹¹¹miii{iin¹¹¹¹ziin¹¹¹¹¹¹¹¹¹¹%&&&&&&&&&&&&&¹¹¹¹¹¹¹¹mii|¹zin¹¹¹¹¹miil¹¹¹¹¹¹¹¹¹233&&&&&&&&&&&¹¹¹¹¹¹¹jiin¹¹¹mn¹¹¹¹¹ziin¹¹¹¹¹¹¹¹¹¹¹¹2333&&&&&&&¹¹¹¹¹¹¹mii|¹¹¹mn¹¹¹¹¹¹min¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹%&&&&&&¹¹¹¹¹¹¹min¹¹¹¹mil¹¹¹¹¹miil¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹2333333¹¹¹¹¹¹¹mi|¹¹¹¹min¹¹¹¹¹miin¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹jin¹¹¹¹¹zin¹¹¹¹¹ziiikl¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹jii|¹¹¹¹¹¹mn¹¹¹¹¹¹miiiil¹¹¹¹BRR¹¹¹)¹¹¹¹¹¹¹¹¹¹¹¹¹min¹¹¹¹¹,jin<¹¹¹¹jiiiiiil¹¹¹R¹¹¹¹¹¹¹¹¹¹¹/¹¹¹¹¹¹jiin¹¹¹¹¹jiiikl¹¹¹\"#####$n¹¹¹RRR¹¹¹¹¹¹¹¹¹¹¹¹¹²¹¹miin¹¹¹j\"#####$¹¹¹%&&&&&'il¹¹¹¹¹ \"##################$¹ji%yy&&i'l¹¹%&&&&&'in¹¹¹¹¹ %&&&&&&&&&&&&&&&&&&'kii%&x&&&'n¹¹2333334in¹¹¹¹¹ %&&&&&&&&&&&&&&&&&&'ii{%x&&xx'il¹¹¹¹¹¹¹min¹¹¹¹¹ %&&&&&&&&&&&&&&&&&&'i|¹2333334iil¹¹¹¹¹¹zin¹¹¹¹¹ %&&&&&&&&&&&&&&&&&&'n¹¹¹¹¹miiiiiil¹¹¹¹¹¹mil¹¹¹¹ %&&&&&&&&&&"
}
--@end


function move_camera(obj)
  --<camtrigger>--
  cam_spdx,cam_spdy=cam_gain*(4+obj.x-cam_x+cam_offx),cam_gain*(4+obj.y-cam_y+cam_offy)
  --</camtrigger>--

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  --clamp camera to level boundaries
  local clampx,clampy=mid(cam_x,64,lvl_pw-64),mid(cam_y,64,lvl_ph-64)
  if cam_x~=clampx then
    cam_spdx,cam_x=0,clampx
  end
  if cam_y~=clampy then
    cam_spdy,cam_y=0,clampy
  end
end



--[[

short on tokens?
everything below this comment
is just for grabbing data
rather than loading it
and can be safely removed!

--]]

--copy mapdata string to clipboard
function get_mapdata(x,y,w,h)
  local reserve=""
  for i=0,w*h-1 do
    reserve..=num2base256(mget(i%w,i\w)+1)
  end
  printh(reserve,"@clip")
end

--convert mapdata to memory data
function num2base256(number)
  return number%256==0 and "\\000" or number==10 and "\\n" or number==13 and "\\r" or number==34 and [[\"]] or number==92 and [[\\]] or chr(number)
end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000000000000000000300b0b00a0aa0a000000000000000000000000000077000
00000000088888800888888088288888088888800888880000000000088888800004000000000000003b33000aa88aa0000777770000000000000000007bb700
00000000882888888828888882277778882888888888828008888880227177180009505000000000028888200299992000776670000000000000000007bbb370
000000008227777882277778887177188227777887777220882888888277777800090505049999400898888009a999900767770000000000000000007bbb3bb7
000000008871771888717718087777708871771881771780822777788877777800090505005005000888898009999a9007766000077777000000000073b33bb7
0000000008777770087777700022220008777770077777808877777808222280000950500005500008898880099a999007777000077776700770000007333370
0000000000222200002222000d0000d00d222200002222d008717710002222000004000000500500028888200299992007000000070000770777777000733700
0000000000d00d0000d000d00000000000000d000000d0000dd222d000d00d000000000000055000002882000029920000000000000000000007777700077000
000000006665666555000000000006664fff4fff4fff4fff4fff4fffd666666dd666666dd666066d0000000000000000700000000c000c0008880000000000d5
000000006765676566700000000777764444444444444444444444446dddddd56ddd5dd56dd50dd5007700000770070007000007c7c0c7c08222888800000050
00000000677067706777700000000766000450000000000000054000666ddd55666d6d5556500555007770700777000000000000c71c711c299922220000000d
0070007007000700666000000000005500450000000000000000540066ddd5d5656505d500000055077777700770000000000000c1cc11cc98889999000000dd
007000700700070055000000000006660450000000000000000005406ddd5dd56dd5065565000000077777700000700000000000cccccccc8888888800000dd5
067706770000000066700000000777764500000000000000000000546ddd6d656ddd7d656d500565077777700000077000000000cccccccc8888888800000d50
5676567600000000677770000000076650000000000000000000000505ddd65005d5d65005505650070777000007077007000070cccccccc888888880000000d
56665666000000006660000000000055000000000000000000000000000000000000000000000000000000007000000000000000cccccccc888888880000000d
15555551155555555555555555555550e66ddd11111111111dddd6ee16565551000000c100000505000000d100000000000000000888888000000000000000d5
6ddddd65556ee666ddddd66d666ee655e66ddde111111111dd6dd66e6d666dd6000001c100500558000001550000000000000000089888880cccc00000000050
eddddddee6e11e6e66dd6eeee6e11e6ee666ddee11111111dd66d66e6dd6dddd000ccc1c005885550001d5d50cc0cc0000d0d00089898888cc111cc00000000d
edddddeee6e11e66e666e6dd66e11e6e1e666ede11111111ddd666e1dde6d6ed001ccc225055882200d55544ccccccc00ddddd0088988888c1cc111c000000dd
e6d6de6e665ee56edeee666de65ee566eee6e1dd11111111ddee6ee16dee6eed00c1c22455558222001d5444ccccccc00ddddd0088888988c1cc111100000dd5
e666e66ee66556e16e66e6661e65566eee1e1d1d111111116d6eee6ee66eee660cc24442088222220d5244440ccccc0000ddd00088889898c111111100000d50
ee6ed6eeeee66e11ee66e1ee11e66eeee661dd11111111111ed6e66eeeeeddee11224244552211221542444400ccc000000d000088888980c11c11110000000d
1eeeeee1ee6ee11111ee11ee111ee6eee6ddddd11111111111ed66eeeeeddddecc421c12052288125d421114000000000000000008888880cc111ccc0000000d
edddddeeed1d11111111d1d11111d1de155555551e66666665555551edddddddcc421c14582211121d421114000000000000000000ccccc0cccccccc0000071c
edd6d6deed16111d11ddd1ddd11161de6dd666d6666666d66dd66ddeed6ddd6e11224242052222225542444400000000000000000c1ccccc0ccccccc00000ccc
edde6edee6d6d1dd16ddd6eddd1d6d6e6d6e6e6dedd66ddddd6ddddeede6d6ee0cc244415582211101d244210880880000606000c1c1ccc00ccccccc00000ccc
eddeedde5e66d6edde666eddde6d66e5d6eeeee6deddd66e66dddddeedde6eee00c1c244058551880055542188888880066666000c1ccc0000cccccc000001c1
e6dde6eee5e66ed66deee6d66de66e5ed6eeeee6eeee66eedddddddeeed6e6ee001ccc22005881110015dd44888888800666660000ccc1c000077ccc0000071c
ee6d6eeeee566666666ee666666665eee66eee66e6deeeeddddddd6eee66e666000ccc1c05558858000d155508888800006660000ccc1c1c000077cc00000ccc
eee6edde1ee55e6ee6e11e6ee6e55ee1ee66e66eee66ded6ddddd6ee1eee1e6e000001c10000555800000dd50088800000060000ccccc1c00000077700000ccc
eededdde111ee1e11e1111e11e1ee111111161111111111111d1111111e111e1000000c1000050550000001d00000000000000000ccccc0000000007000001c1
0000000006222622000dd00077777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
000000006262662600dbbd0070000700007000070070700700000000000000000000000000000000000000000000000000000000000000000000000000000000
000000006626dd6d0dbbb3d070770700007077070077700700000000000000000000000000000000000000000000000000000000000000000000000000000000
000000002666d8d8dbbb3bbd70770777007000070000777700000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000022dd8282d3b33bbd70000007007077070000070700000000000000000000000000000000000000000000000000000000000000000000000000000000
0000077762d822220d3333d077770777007777770000077700000000000000000000000000000000000000000000000000000000000000000000000000000000
00077ccc66d8222200d33d0070070700000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000
007ccccc266d8222000dd00070077700000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000
007ccccc22622662000000007000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000ff00000000e1e
007ccccc6666226600000000700000000000000000007777000000000000000000000000000000000000000000000000000000000000000000efff00000fefe1
0007ccccd666666d0000000077777000000000000000700700000000000000000000000000000000000000000000000000000000000000000f1ffff000ffeff1
007ccccc8d666d680000000070007000000000000000777700000000000000000000000000000000000000000000000000000000000000000ff1ffff0fff1ff1
0cc0c0cc88ddd8d8000000007070700000000000000007070000000000000000000000000000000000000000000000000000000000000000ffffeffffff1fff1
0c00c00c28888282000000007000700000000000000077770000000000000000000000000000000000000000000000000000000000000000ffff1ffffff1fff1
0000cc0c22822222000000007777700000000000000070070000000000000000000000000000000000000000000000000000000000000000ffff1fff0ffefffe
00000c0022222222000000007000000000000000000077770000000000000000000000000000000000000000000000000000000000000000eee111ee0000ffee
000000000000dddd000000007000000000000000007770070000000000000000fe1eee1100000000000fff000000000000fffffeee1eef0000ffff0000000000
000980000000d22d000000007000000000000000007070070000000000000000ffeffe11000000ff00fffff0ff0000000fefffffe1fffff00efffff00ffff000
00a000220000d22d777777777000000000000000777077770000000000000000fffff11e00fe1fff0efffffffff1ef00fffe1fffe1fffffffeffffffffffffef
080022220000dddd7700770070000000007770007000000700000000000000001fff111e0fffefffffeffffefffefff0ffff1fff11fffffffeffffffffffff1f
0a0229880000000077777777700000000070700077707707000000000000000011f11fff0fff1fffff11fffefff1fff0fffff1ffff1fffffffefffffffffff1f
000299980000000077007700700000007777700000707707000000000000000011111fff0fff1fffffff1111fff1fff00ffff111fff11ee0ff1fffffffffe1ff
0022998800000000770077007000000070007000007000070000000000000000111ff1110111fffefffff1eeefff111000fff1eeffeffff00ff11e000eeeffff
0022888800000000770077007777777777777777777777770000000000000000111ff111ff1ffeeeeffff1eeeeeff1ff00fff1eeeefffff00fffff0000ffff00
00228898000007717777777000000000000000000000000000000000111f111111111111eee1fffeeee1eeeeeeeff1ffeeeeee1eeeee111eff111e111feffff0
0022899900000177700700777700000000000000777777700000000011ff1f111ee11e110111fffeee111eeeefff1110eeeeee1eee11fe1efff1ffff1ffeffff
0002289900000ccc770777700777700000000777700700700000000011f1fff1eeee1ee10eee1fefe1eee1e1fff1fff0eeeee1eee11fff11ffff1fffefffeee0
000222880000000000070077770077770077770077770770000000001f11fff1eee1eeee0ffee1ff1eeffe1efff1fff0eeeee111e1effe1effffefff1ffffff0
00002222000000000007007007777007777007777007000000000000fff1fff11e11ee110fffe1ffffeffffffffefff01eee111111eeee1e0ffffeff11ffffff
0000002200000ccc0007007007007777007777007007000000000000fff11f1111e1e1e100fff1fffffffffffff1ef00e1111111ee1ee1ee0ffffef01f1efff0
000000000000017700070070070070077770070070070000000000001f111111111e1eee000ffeff0fffff0fff000000ee11ee11eee111ee00ffff00fff1ef00
0000000000000771000700700700700700700700700700000000000011111111111111e1000000000efff00000000000ee1eee1eeeeeee1e000ff000ffff0000
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
0000000000000000000000000000000002020202484848000000000000000000434343434343434300000000000000004343434343434343000000000000000000000083838300000000000000000000000000838383000404040404040404040000108383830004040404040404040400001010101000040404040404040404
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
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

