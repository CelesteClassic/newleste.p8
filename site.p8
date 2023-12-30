pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
--newleste.p8 base cart

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

-- [interperter stuff]
-- courtesy of meep
-- set global var
function gset(k,v)
 _ENV[k]=_ENV[v] or v
end
True=true

-- split, access _𝘦𝘯𝘷, and unpack
function usplit(str,d,a,env)
 if str then
  local tbl=split(str,d)
  for k,v in pairs(tbl) do
   tbl[k]=not a and env[v] or v
  end
  return unpack(tbl)
 end
end

function args(a)
  return unpack(split(a))
end

-- execute list of fns
function exec(fns,env)
 env=env or _ENV
 foreach(split(fns,"\n"),function(ln)
  local fn,params=usplit(ln," ",true)
  -- print(fn.."\n")
  -- print(fns)
  -- assert(env[fn])
  env[fn](usplit(params,",",fn=="gset" or fn=="lset",env))
 end)
end

-- [globals]

_camera=camera
camera=function(x,y)
  x,y = x or 0,y or 0
  _camera(x+title*15,y+title*28)
end
exec[[gset freeze,0
gset delay_restart,0
gset sfx_timer,0
gset ui_timer,-99
gset cam_x,0
gset cam_y,0
gset cam_spdx,0
gset cam_spdy,0
gset cam_gain,0.1
gset cam_offx,0
gset cam_offy,0
gset _pal,pal
gset shake,0
gset title,1]] --timers, camera values <camtrigger> outlining, screenshake
objects,got_fruit,obj_bins = {},{},{solids={}} --tables

--screenshake=false
local screenshake_toggle=function()
  screenshake=not screenshake
  menuitem(1, "screenshake: ".. (screenshake and "on" or "off"), screenshake_toggle)
  return true
end

menuitem(1, "screenshake: off", screenshake_toggle)

local _g=_ENV --for writing to global vars

-- [entry point]

function _init()
  objects,got_fruit,obj_bins = {},{},{solids={}} --tables
  exec[[gset max_djump,1
gset deaths,0
gset frames,0
gset seconds,0
gset seconds_f,0
gset minutes,0
gset berry_count,0
gset dream_blocks_active
gset stars_falling,True
music 0,0,7
load_level 1]]
end


-- [effects]


dead_particles={}

function bt(idxs, b)
  local ret={}
  for i,v in pairs(b) do
    ret[split(idxs)[i]]=v
  end
  return ret
end
--<stars>--
stars,stars_falling={},true
for i=0,15 do
  add(stars,bt("x,y,off,spdy,size",
  {rnd"128",
    rnd"128",
    rnd(),
    rnd"0.75"+0.5,
    rnd{1,2}
  }))
end
--</stars>--

function create_type(init,update,draw)
  return {init=init,update=update,draw=draw}
end

-- [player entity]

player=create_type(
  function(_ENV) -- init
    hitbox= rectangle(args"1,3,6,5")

    exec[[
lset djump,max_djump
lset collides,True
lset layer,2
lset grace,0
lset jbuffer,0
lset dash_time,0
lset dash_effect_time,0
lset dash_target_x,0
lset dash_target_y,0
lset dash_accel_x,0
lset dash_accel_y,0
lset spr_off,0
lset berry_timer,0
lset berry_count,0]]
    --<fruitrain>--
    -- ^ refers to setting berry_timer and berry_count to 0
    --create_hair(_ENV)
    dream_particles={}

  end,
  function(_ENV) -- update
    -- <dream_block> --
    foreach(dream_particles,function(p)
      p.x+=p.dx
      p.y+=p.dy
      p.t-=1
      if p.t <= 0 then
        del(dream_particles, p)
      end
    end)
    if dreaming then
      dream_time+=1
      if dream_time%5==0 then
        -- afterimage particles
        add(dream_particles,bt("x,y,dx,dy,t,type",{
          x,
          y,
          spd.x/8,
          spd.y/8,
          10,
          2
        }))
      end
      -- trail particles
      add(dream_particles,bt("x,y,dx,dy,t,type",{
        x+4,
        y+4,
        rnd"0.5"-0.25,
        rnd"0.5"-0.25,
        7,
        1
      }))
      if not check(dream_block,0,0) then
        -- back to drawing behing dream block
        layer,init_smoke,spd,dash_time,dash_effect_time,dreaming=2,_init_smoke,vector(mid(dash_target_x,-2,2),mid(dash_target_y,-2,2)),0,0--,false
        sfx(28,-2)
        sfx"27"
        if spd.x~=0 then
          grace=4
        end
      end
    end
    -- </dream_block> --

    -- horizontal input
    -- <cutscene> --
    local h_input=pause_player and (h_input or 0) or split"0,-1,1,1"[btn()%4+1]
    -- </cutscene> --

    -- spike collision / bottom death
    if is_flag(0,0,-1) or
	    y>lvl_ph and not exit_bottom then
	    kill_player(_ENV)
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
      if f.type==fruit and (not f.golden or lvl_id==35 and x>=60) and berry_timer>5 then
        -- to be implemented:
        -- save berry
        -- save golden

        berry_count+=1
        _g.berry_count+=1
        if f.golden then
          _g.collected_golden=true
        end
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
    -- <cutscene> --
    local j_input,d_input = j_input ,d_input
    if not pause_player then
      j_input,d_input = btn(🅾️),btn(❎)
    end
    local jump,dash=j_input and not p_jump,d_input and not p_dash
    p_jump,p_dash=j_input,d_input
    -- </cutscene> --

    -- jump buffer
    if jump then
      jbuffer=5
    end
    jbuffer=max(jbuffer-1)

    -- grace frames and dash restoration
    if on_ground then
      grace=7
      if djump<max_djump then
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
      if is_solid(h_input,0) then
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
      -- <cutscene> --
      not pause_player and btn(⬇️) and 6 or -- crouch
      (not pause_player and btn(⬆️) or u_input) and 7 or -- look up
      -- </cutscene> --
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

  function(_ENV) -- draw
    -- draw player hair and sprite
    -- <dream_block> --
    draw_dreams(_ENV,1,12)
    if not dreaming then
      pal(8,djump==1 and 8 or 12)
      draw_hair(_ENV)
      draw_obj_sprite(_ENV)
      pal()
    end
  end
)

function draw_dreams(_ENV,cdark,clight)
  foreach(dream_particles,function(_ENV)
    if type==1 then
      _g.circfill(x, y, t/2, _g.split"1,13"[t] or clight) --draw trails
    end
  end)

  foreach(dream_particles,function(p)
    if p.type==2 then
      local s = 2.5-p.t/4
      for i=0,15 do
        pal(i,split"1,1,1,13,13,13"[p.t] or clight)
      end
      sspr(8, 0, 8, 8, p.x-s/2, p.y-s/2, 8+s, 8+s) -- draw player afterimage
    end
  end)
  pal()

  if dreaming then
    for i=0,15 do
      pal(i,clight)
    end
    draw_obj_sprite(_ENV)
    local sx = split"8,8,8, 16,16,16, 24, 32,32,32"[dream_time%10+1]
    --sprites used are 97-101 so sy is always 48
    pal(7,({clight,clight,cdark,cdark,clight,cdark})[dream_time%7] or 7)
    local size,w = split"0,5"[dream_time] or rnd()<0.4 and 4 or 0, 2
    if dream_time<3 then
      w,sx=4,0
    end
    sspr(sx, 48, 8, 8, x-w, y-size/2, 8+w*2, 8+size) -- draw flickering sprite
    pal()
  end
end
--</dream_block>--

function create_hair(_ENV)
  hair={}
  for i=1,5 do
    add(hair,vector(x,y))
  end
end


function update_hair(_ENV)
  local last=vector(x+(flip.x and 6 or 1),y+((not pause_player and btn(⬇️) or type==player_spawn and entrance_dir==6) and 4 or 2.9))
  foreach(hair, function(h)
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    last=h
  end)
end

function draw_hair(_ENV,flip)
  for i,h in inext,hair do
    circfill(round(flip and 207-h.x+flip or h.x),round(h.y),split"2,2,1,1,1"[i],8)
  end
end

-- [other entities]

player_spawn=create_type(
  function(_ENV) -- init
    exec[[lset layer,2
lset sprite,3
lset target,y
sfx 15]]

    local offx,offy,c=0,0,check(camera_trigger,0,0)
    if c then
      offx,offy=c.offx,c.offy
      _g.cam_offx,_g.cam_offy=offx,offy
    end
    _g.cam_x,_g.cam_y=mid(x+offx+4,64,lvl_pw-64),mid(y+offy+4,64,lvl_ph-64)
    exec[[lset state,0
lset delay,0]]
    flip.x=entrance_dir%2==1
    --top entrance
    if entrance_dir<=1 then
      y,spd.y=lvl_ph,-4
    elseif entrance_dir<=3 then
      if not is_solid(0,1) then
        player_start_spdy=2
      end
      y,spd.y,state=-8,1,1
    elseif entrance_dir<=5 then
      local dir = entrance_dir==4 and 1 or -1
      spd,x=vector(1.7*dir,-2), x-24*dir
    else
      state,delay=2,20
    end

    create_hair(_ENV)
    update_hair(_ENV)
    exec[[lset djump,max_djump]]
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
  function(_ENV) --update
    -- jumping up
    if state==0 and y<target+16 then
        state,delay=1, 3
    -- falling
    elseif state==1 then
      spd.y=min(spd.y+0.5,3)
      if spd.y>0 then
        if delay>0 then
          -- stall at peak
          spd.y=0
          delay-=1
        elseif y>target then
          -- clamp at target y
          state,spd=2,zerovec()
          if not player_start_spdy then
            y,delay,_g.shake=target,5,4
            init_smoke(0,4)
            sfx"16"
          end
        end
      end
    -- landing and spawning player object
    elseif state==2 then
      if title <= 0 then
        delay-=1
      elseif title < 1 then
        _g.title = appr(title, 0, max(title/10,0.01))
      elseif title == 1 and (btn(4) or btn(5)) then
        _g.title -= 0.01
        sfx"61"
      end

      sprite=6
      if delay<0 then
        destroy_object(_ENV)
        local p=init_object(player,x,y)
        p.flip,p.hair,p.spd.y=flip,hair,player_start_spdy or 0;
        --- <fruitrain> ---
        (fruitrain[1] or {}).target=p
        --- </fruitrain> ---
      end
    end
    update_hair(_ENV)
  end,
  player.draw
  -- function(this) -- draw
  --   set_hair_color(max_djump)
  --   draw_hair(this,1)
  --   draw_obj_sprite(this)
  --   unset_hair_color()
  -- end
)

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


refill=create_type(
  function(_ENV) -- init
    offset,timer,hitbox=rnd(),0,rectangle(args"-1,-1,10,10")
  end,
  function(_ENV) -- update
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
  function(_ENV) -- draw
    if timer==0 then
      spr(15,x,y+sin(offset)+0.5)

    else
      palt"0xfeff"
      draw_obj_sprite(_ENV)
      palt()
    end
  end
)

fall_floor=create_type(
  function(_ENV) -- init
    exec[[lset solid_obj,True
lset state,0
lset unsafe_ground,True
lset delay,0]]
  end,
  function(_ENV) -- update
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
)

smoke=create_type(
  function(_ENV) -- init
    layer,spd,flip=3,vector(0.3+rnd"0.2",-0.1),vector(rnd()<0.5,rnd()<0.5)
    x+=-1+rnd"2"
    y+=-1+rnd"2"
  end,
  function(_ENV) -- update
    sprite+=0.2
    if sprite>=29 then
      destroy_object(_ENV)
    end
  end
)

--- <fruitrain> ---
fruitrain={}
fruit=create_type(
  function(_ENV) -- init
    exec[[lset y_,y
lset off,0
lset tx,x
lset ty,y]]
    golden=sprite==11
    if golden and (deaths>0 or not target and lvl_id!=1) then
      destroy_object(_ENV)
    end
  end,
  function(_ENV) -- update
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
        psfx"62"
      end
    end
    off+=0.025
    y=y_+sin(off)*2.5
  end
)
fruit.check_fruit=true
--- </fruitrain> ---

lifeup=create_type(
  function(_ENV) -- init
    spd.y=-0.25
    exec[[lset duration,30
lset flash,0
gset sfx_timer,20
lset outline,false
sfx 9]]
  end,
  function(_ENV) -- update
    duration-=1
    if duration<=0 then
      destroy_object(_ENV)
    end
    flash+=0.5
  end,
  function(_ENV) -- draw
    --<fruitrain>--
    ?split"1000,2000,3000,4000,5000,1up"[min(sprite,6)],x-4,y-4,7+flash%2
    --<fruitrain>--
  end
)

badeline=create_type(
  function(_ENV) -- init
    for o in all(objects) do
      if (o.type==player_spawn or o.type==badeline) and not o.tracked then
        bade_track(_ENV,o)
        break
      end
    end
    states,timer={},0
    --TODO: rn hitbox is 8x8, need to test if a hitbox matching the player obj is more fitting
  end,
  function(_ENV) -- update
    player_input=player_input or btn()!=0
    if tracking.type==player_spawn then
      --search for player to replace player spawn
      local o=find_player()
      if o.type==player then
        bade_track(_ENV,o)
      end
    elseif tracking.type==badeline and tracking.timer<30 then
      return
    end
    --don't create badeline before the player inputs anything
    if not player_input and (tracking.type==player or timer==29) then
      return
    end
    if timer<50 then
      timer+=1
    end

    local curr_smokes,dream_particles_copy,states=smokes,{},states
    smokes={}

    do
      local _ENV=tracking
      foreach(dream_particles, function(p)
        local q=add(dream_particles_copy,{})
        for k,v in pairs(p) do
          q[k]=v
        end
      end)
      add(states,{x,y,flip.x,sprite or 1,curr_smokes,dreaming,dream_time,dream_particles_copy,layer,tangible or type==player})
    end

    if #states>=30 then
      x,y,flip.x,sprite,curr_smokes,dreaming,dream_time,dream_particles,layer,tangible=unpack(deli(states,1))
      for s in all(curr_smokes) do
        init_smoke(unpack(s))
      end
    end
    if timer==30 then
      create_hair(_ENV)
    end
    if timer>=30 then
      update_hair(_ENV)
    end
    local hit=player_here()
    if hit and tangible then
      kill_player(hit)
    end
  end,
  function(_ENV) -- draw
    if timer>=30 then
      draw_dreams(_ENV,2,8)
      if not dreaming then
        palsplit"8,2,1,4,5,6,5,2,9,10,11,8,13,14,6"
        draw_hair(_ENV)
        draw_obj_sprite(_ENV)
        pal()
      end
    end
  end
)
function bade_track(_ENV,o)
  o.tracked,tracking=true,o
  local f=o.init_smoke
  o.init_smoke=function(...)
    add(smokes,{...})
    f(...)
  end
end

--<fall_plat> <dream_block> <touch_switch>--
--for rectangle objects with variable size, determined by mapdata
function resize_rect_obj(_ENV,tr,td)
  while right()<lvl_pw-1 and tile_at(right()\8+1,y/8)==tr do
    hitbox.w+=8
  end
  while bottom()<lvl_ph-1 and tile_at(x/8,bottom()\8+1)==td do
    hitbox.h+=8
  end
end
--</fall_plat> </dream_block> </touch_switch>

fall_plat=create_type(
  function(_ENV) -- init
    resize_rect_obj(_ENV,args"67,67")
    exec[[lset collides,True
lset solid_obj,True
lset timer,0]]
  end,
  function(_ENV) -- update
    --states:
    -- nil - before activation
    -- 0 - shaking
    -- 1 - falling
    -- 2 - done
    if not state and check(player,0,-1) then
      -- shake
      state,timer = 0,10
      sfx"13"
    elseif timer>0 then
      timer-=1
      if timer==0 then
        state+=1
        spd.y=0.4
      end
    elseif state==1 then
      if spd.y==0 then
        for i=0,hitbox.w-1,8 do
          init_smoke(i,hitbox.h-2)
          sfx"25"
        end
        timer=6
      end
      spd.y=appr(spd.y,4,0.4)
    end
  end,
  function(_ENV) -- draw
    local x,y=x,y
    if timer>0 then
      x+=rnd"2"-1
      y+=rnd"2"-1
    end
    local r,d=hitbox.w-8,hitbox.h-8

    --can probably be optimized slightly farther
    local sprites=split"37,80,81,?,42,41,43,42,58,57,59,58,?,80,81,?"
    local pals=split"0,0,0,0,0,0x8000,0x8000,0,0,0x8000,0x8000,0,0,0,0,0"
    for i=0,r,8 do
      for j=0,d,8 do
        local typ=(i==0 and 1 or i==r and 2 or (i==8 or i==r-8) and 3 or 0) + (j==0 and 4 or j==d and 8 or (j==8 or j==d-8) and 12 or 0) + 1
        palt(pals[typ])
        spr(tonum(sprites[typ]) or (i+j)%16==0 and 44 or 60,i+x,j+y)
      end
    end
    palt()
  end
)
-- <touch_switch> --
touch_switch=create_type(
  function(_ENV) -- init
    exec[[lset off,2]]
  end,
  function(_ENV) -- update
    if not collected and player_here() then
      collected=true
      controller.missing-=1
      init_smoke()
      sfx"23"
    end
    off+=collected and 0.5 or 0.2
    off%=4
  end,
  function(_ENV) -- draw
    --set color 8 as transparent
    palt"0x80"
    if controller.active then
      sprite=68
      pal(12,2)
    else
      sprite=split"68,69,70,69"[1+flr(off)]
      flip.x=off>=3
      if collected then
        pal(12,7)
      end
    end
    draw_obj_sprite(_ENV)
    --pal() resets transparancy, but when outlining it won't so need to explicitly call palt()
    palt()
    pal()
  end
)
switch_block=create_type(
  function(_ENV) -- init
    exec[[lset delay,0
lset end_delay,0
lset solid_obj,True]]
    resize_rect_obj(_ENV,72,87)
  end,
  function(_ENV) -- update
    if missing==0 and not active then
      active,delay=true,20
      foreach(switches,function(_ENV)
        init_smoke()
        init_smoke()
      end)
      _g.sfx_timer=20
      sfx"24"
    end

    if end_delay>0 then
      end_delay-=1
      if end_delay==0 then
        delay=10
        if dirx~=0 then
          for i=0,hitbox.h-1,8 do
            init_smoke(dirx==-1 and -6 or hitbox.w-2,i)
          end
        end
        if diry~=0 then
          for i=0,hitbox.w-1,8 do
            init_smoke(i,diry==-1 and -6 or hitbox.h-2)
          end
        end
      end
    end
    if delay>0 then
      delay-=1
    elseif active then
      local dx,dy=target.x-x,target.y-y
      --local c=min(max(abs(dx),abs(dy)),16)/8
      local cx,cy=min(abs(dx)+1,distx/4)/8,
                  min(abs(dy)+1,disty/4)/8
      --local c=clamp(abs(dx),abs(dy),16)/8
      --c=c==0.125 and 0.25 or c
      spd=vector(cx*sign(dx),cy*sign(dy))
      if not done then
        if dx==0 and dy==0 then
          end_delay,done=5,true
          sfx"25"
        end
      end
    end
  end,
  function(_ENV) -- draw
    --TODO: put this into a function to save tokens with fall_plat
    local x,y=x,y
    if delay>3 then
      x+=rnd"2"-1
      y+=rnd"2"-1
    end

    local r,d=x+hitbox.w-8,y+hitbox.h-8
    for i in all{x,r} do
      for j in all{y,d} do
        spr(71,i,j,1.0,1.0,i~=x,j~=y)
      end
    end
    for i=x+8,r-8,8 do
      spr(72,i,y)
      spr(72,i,d,1.0,1.0,true,true)
    end
    for i=y+8,d-8,8 do
      spr(87,x,i)
      spr(87,r,i,1.0,1.0,true)
    end
    rectfill(x+8,y+8,r,d,1)

    spr(88,x+hitbox.w/2-4,y+hitbox.h/2-4)
  end
)
switch_block.end_init=function(_ENV)
  switches={}
  foreach(objects, function(o)
    if o.type==touch_switch then
      add(switches,o)
      o.controller=_ENV
    elseif o.sprite==88 then
      target=o
      destroy_object(o)
      local dx,dy=o.x-x,o.y-y
      dirx,diry,distx,disty=sign(dx),sign(dy),abs(dx),abs(dy)
    end
  end)
  missing=#switches
end


switch_target={}
-- <touch_switch> --


--<dream_block>--
function calc_seg(seg)
  local t=dream_blocks_active and time() or 0
  if (seg[2]) return (sin(t/seg[2]+seg[2])+sin(t/seg[3]+seg[3])+2)/2
  return 0
end

function build_segs(x,right)
  local segs={}
  for i=1,2 do
    local seg={{x},{x+4}}
    local x_,lastx_=x+10+flr(rnd"6"),x+4
    while x_<right-4 do
      add(seg,{x_,rnd"3"+2,rnd"3"+2})
      lastx_=x_
      x_+=flr(rnd"6")+6
    end

    seg[ lastx_>right-8 and #seg or #seg+1 ] = {right - 4}
    add(seg,{right})
    add(segs,seg)
  end
  return segs
end

function draw_outline(_ENV, x,right,draw_y,ysegs,transpose,outline_color)
  for t,i in ipairs{x,right} do
    -- line(x+1, i, right()-1,i)


    local segs,dir=ysegs[t], split"-1,1"[t]
    for idx=1,#segs-1 do
      ly,ry=segs[idx][1],segs[idx+1][1]
      if ry<draw_y or ly>=draw_y+129 then goto continue end
      local lx,rx=i+dir*calc_seg(segs[idx]), i+dir*calc_seg(segs[idx+1])
      local m=(rx-lx)/(ry-ly)
      local px_=lx
      for j=ly,ry do
        px_+=m
        -- <cutscene> --
        local px,ox,oy=round(px_),outline_size,0
        if transpose then
          rectfill(j,px,j,i,0)
          px,j,ox,oy=j,px,oy,ox
        else
          rectfill(px,j,i,j,0)
        end
        if #disp_shapes==0 then
          rectfill(px-ox,j-oy,px+ox,j+oy,outline_color)
        -- </cutscene> --
        else
          local d,dx,dy,ds=displace(disp_shapes,px,j)
          d=max((4-d), 0)
          pset(px+dx*d*ds,j+dy*d*ds,outline_color)
        end
      end
      ::continue::
    end

  end
end

--dream_blocks_active=false
dream_block=create_type(
  function(_ENV) -- init
    layer,kill_timer,particles=3,0,{}
    resize_rect_obj(_ENV,65,65)
    for i=1,hitbox.w*hitbox.h/32 do
      add(particles,bt("x,y,z,c,s,t",
      {rnd(hitbox.w-1)+x,
      rnd(hitbox.h-1)+y,
      rnd(),
      split"3, 8, 9, 10, 12, 14"[flr(rnd"6")+1],
      rnd(),
      flr(rnd"10")}))
    end
    dtimer,disp_shapes,xsegs,ysegs,pitch,outline=1, bt("min_x,min_y,max_x,max_y",split"10000,-10000,10000,-10000"), build_segs(x,right()), build_segs(y,bottom()), 0--,false
    -- <cutscene> --
    outline_size=0
    -- </cutscene> --
  end,
  function(_ENV) -- update
    --[[hitbox.w+=2
    hitbox.h+=2]]
    local hit=player_here()
    if hit then
      -- set the player as _ENV temporarily, to save a lot of tokens
      local _ENV,this=hit,_ENV
      dash_effect_time,dash_time=10,2

      local magnitude=(dash_target_y==0 or dash_target_x==0) and 2.5 or 2
      dash_target_x,dash_target_y=sign(dash_target_x)*magnitude,sign(dash_target_y)*magnitude
      if not dreaming then
        spd=vector(dash_target_x*(dash_target_y==0 and 2.5  or 1.7678),dash_target_y*(dash_target_x==0 and 2.5 or 1.7678))
        dream_time,dreaming=0,true
        _init_smoke, init_smoke=init_smoke, function() end
        sfx"28"
        this.pitch=5
      end

      --corner correction
      if abs(spd.x)<abs(dash_target_x) or abs(spd.y)<abs(dash_target_y) then
        move(dash_target_x,dash_target_y,0)
        if is_solid(dash_target_x,dash_target_y) or oob(dash_target_x,dash_target_y) then
          sfx(28,-2)
          kill_player(hit)
        end
      end

      djump,layer=max_djump,3 -- draw player in front of dream blocks while inside

      local _ENV=this -- set _ENV back to this to save more tokens
      if dtimer>0 then
        dtimer-=1
        if dtimer==0 then
          dtimer=4
          add(disp_shapes, {hit.x+4, hit.y+4,0}) -- x,y,r
        end
      end

      --local sfxaddr = 0x3200 + 28*68
      poke(0x3970, 204+pitch)
      poke(0x3972, 211+pitch)
      pitch=min(pitch+1.5,27)+(pitch >= 27 and rnd"8" or 0)
    else
      dtimer=1
    end
    --[[hitbox.w-=2
    hitbox.h-=2]]--
    --update disp_shapes
    disp_shapes.min_x,disp_shapes.max_x,disp_shapes.min_y,disp_shapes.max_y=args"10000,-10000,10000,-10000"
    for i in all(disp_shapes) do
      local x,y=unpack(i)
      i[3]+=2
      if i[3] >= 15 then
        del(disp_shapes, i)
      end
      disp_shapes.min_x,disp_shapes.max_x,disp_shapes.min_y,disp_shapes.max_y=min(disp_shapes.min_x,x), max(disp_shapes.max_x, x), min(disp_shapes.min_y, y), max(disp_shapes.max_y,y)
    end

    foreach(particles, function(p)
      if dream_blocks_active then
        p.t+=1
        p.t%=16
      end
    end)
  end,
  function(_ENV) -- draw
    rectfill(x+1,y+1,right()-1,bottom()-1,0)

    if not dream_blocks_active then
      palsplit"1,2,5,4,5,6,7,5,6,6,11,13,13,13,15"
    end
    local big_particles={}
    foreach(particles, function(p)
      local px,py = (p.x+cam_x*p.z-65)%(hitbox.w-2)+1+x, (p.y+cam_y*p.z-65)%(hitbox.h-2)+1+y
      local d,dx,dy,ds=displace(disp_shapes, px,py)
      d=max(6-d, 0)
      px+=dx*ds*d
      py+=dy*ds*d

      if p.s<0.2 and p.t<=8 then
        add(big_particles,{px,py,p.c})
      else
        pset(px,py,p.c)
      end
    end)
    foreach(big_particles,function(p)
      local px,py,pc=unpack(p)
      line(px-1,py,px+1,py,pc)
      line(px,py-1,px,py+1,pc)
    end)
    pal()

    -- draw outline pixel by pixel
    -- divide into segments of 8 pixels
    -- at the boundaries of each segment, set the position to be a sum of sines
    -- lerp between the boundaries
    -- fill the dream block in
    --
    --

    local outline_color = dream_blocks_active and 7 or 5
    draw_outline(_ENV,x,right(),draw_y,ysegs,false,outline_color)
    draw_outline(_ENV,y,bottom(),draw_x,xsegs,true,outline_color)


    for i in all{x+1,right()-1} do
      for j in all{y+1,bottom()-1} do
        pset(i,j,outline_color)
      end
    end
  end
)


function displace(tbl, px,py)
  local d,ds,pox,poy,s = 10000,0,0,0,0
  if px>=tbl.min_x-20 and px<=tbl.max_x+20 and  py>=tbl.min_y-20 and py<=tbl.max_y+20 then
    for i in all(tbl) do
      local ox,oy,r=unpack(i)
      if abs(px-ox)+abs(py-oy)<=20 then
        --cpu optimization - if the manhatten distance is far enough, we don't care anyway
        local tpox,tpoy = px-ox,py-oy
        local ang=atan2(tpox,tpoy)
        local ts= tpox*cos(ang)+tpoy*sin(ang)
        local td =abs(ts-r)
        if td<d then
          d,ds,pox,poy,s=td,ts,tpox,tpoy,r
        end
      end
    end
  end
  if d>10 then
    return d,0,0,0
  end
  local s_=sign(ds-s)/ds
  local gx, gy= s_*pox, s_*poy
  return d,gx,gy,(15-s)/15
end

--</dream_block>--
phone_booth=create_type(
  function(_ENV) -- init
    hitbox.h=24
  end,
  function(_ENV) -- update
    if not done and player_here() then
      _g.co_trans,done=cocreate(circ_transition),true
    end
  end,
  function(_ENV) -- draw
    palt"0"
    spr(148,x,y,1,3)
    palt()
  end
)

-- <cutscene> --
mirror=create_type(
  function(_ENV) -- init
    hitbox=rectangle(args"-5,-20,42,60")
    exec[[lset reflect_off,0
lset mirror_col,12
lset outline,false]]
  end,
  function(_ENV) -- update
    if p and not player_here() and not cutscene and not _g.mirror_broken then
      p.spd.x,p.dash_time=0,0
      _g.cutscene,_g.cutscene_env,_g.pause_player=cocreate(mirror_cutscene),_ENV,true
    else
      p=p or player_here()
    end
  end,
  function(_ENV) -- draw
    rectfill(x+3,y+7,x+28,y+23,mirror_col)
    if p then
      palsplit"8,2,1,4,5,6,5,2,9,10,11,8,13,14,15"
      clip(x+3-cam_x+64,y+7-cam_y+64,26,17)
      draw_hair(p,reflect_off)
      spr(p.sprite,2*x-p.x+24+reflect_off,p.y,1,1,not p.flip.x)
      pal()
      clip()
    end
    palt"0x80"
    camera(draw_x-x,draw_y-y)
    if broken then
      spr(args"128,0,4,4,2.5")
    else
      sspr(args"0,84,32,12,0,4")
      spr(args"132,0,16,4,1")
    end
    camera(draw_x,draw_y)
    palt()
    -- rect(x+3,y+7,x+20,y+15,7)
  end
)

-- a="\z
-- [=["
function mirror_cutscene(_ENV)
  exec[[
music -1,500
wait 30
music 16,500]]
  p.flip.x=not p.flip.x
  wait"20"
  p.h_input=sgn(x+6-p.x)
  while abs(x+6-p.x)>1 do
    yield()
  end
  p.h_input,p.spd.x=0,0
  yield()
  p.flip.x=false
  wait"30"
  _g.co_trans=cocreate(cutscene_transition)
  exec[[sfx 10
wait 50]]
  for i=0,-3,-1 do reflect_off=i yield() end
  exec[[wait 30
sfx 8]]
  for i=1,6 do
    mirror_col=split"12,7"[i%2+1]
    wait"2"
  end
  exec[[wait 15
lset reflect_off,-128
lset broken,True
gset shake,2]]
  baddy=init_object(cutscene_badeline, 197-p.x, p.y)
  baddy.flip.x=true
  exec[[init_smoke 4,8
init_smoke 24,8]]
  wait(3,rectfill, x, y+5, x+32, y+23, 7)
  baddy.exec[[
wait 20
lset h_input,-1
wait 10
lset j_input,True
wait 10
lset d_input,True
wait 50]]
  destroy_object(baddy)
  p.u_input=true
  while _g.cam_offy>-60 do _g.cam_offy+=-12-0.2*_g.cam_offy yield() end
  exec[[gset dream_blocks_active,True]]
  block = check(dream_block,0,-16)
  block.outline_size=2

  exec[[gset shake,100
sfx 28
lset pitch,-6]]
  for _y=block.bottom()-1,block.y+8,-0.50 do
    rectfill(block.x+1,block.y+1,block.right()-1,_y,7)
    if _y%2<0.5 then
      for _x=1,block.hitbox.w,8 do block.init_smoke(_x-3,_y-block.y-8) end
    end

    --sfxaddr = 0x3200 + 28*68
    poke(0x3970, 204+pitch)
    poke(0x3972, 211+pitch)
    pitch+=0.5
    yield()
  end
  block.exec[[sfx 28,-2
sfx 27
gset shake,0
wait 3
lset outline_size,1
wait 3
lset outline_size,0
music 17,0,7
wait 20]]
  while _g.cam_offy<-1 do _g.cam_offy+=-0.2*_g.cam_offy yield() end
  p.exec[[gset cam_offy,0
gset mirror_broken,True
lset u_input]]
end
--]=]
function wait(frames,func, ...) for i=1,frames do (func or stat)(...); yield() end end
cutscene_badeline=create_type(
  function(_ENV) -- init
    player.init(_ENV)
    create_hair(_ENV)
  end,
  player.update, -- update
  function(_ENV) -- draw
    palsplit"8,2,1,4,5,6,5,2,9,10,11,8,13,14,15"
    draw_hair(_ENV)
    draw_obj_sprite(_ENV)
    pal()
  end
)
function cutscene_transition()
  for _t=1,305 do
    local t=_t<=15 and _t or _t<=245 and 15 or 306-_t
    local c=_t<=245 and 15 or 60
    local fac=15-15*(1-t/c)^3
    camera()
    rectfill(0, 0, 128, fac, 0)
    rectfill(0, 128-fac, args"128, 128, 0")
    yield()
  end
end
-- </cutscene> --

campfire=create_type(
  function(_ENV) -- init
    exec[[lset off,0
lset layer,0
lset outline,false]]
  end,
  function(_ENV) -- update
    off+=0.2
  end,
  function(_ENV) -- draw
    camera(draw_x-x,draw_y-y)
    exec[[rectfill -8,0,16,8,0
spr 8,0,0,2,1]]
    if stars_falling then
      palsplit"1,2,3,4,5,6,7,11,7"
    end
    spr(split"12,13,14"[flr(off)%3+1],4,-2)
    pal()
    camera(draw_x,draw_y)
  end
)

memorial=create_type(
  function(_ENV) -- init
    index,text,hitbox.w,outline=6,"-- celeste mountain --\nthis memorial to those\n perished on the climb",16--,false
  end,
  nil, -- update
  function(_ENV) -- draw
    camera(draw_x-x,draw_y-y)
    exec[[spr 149,0,-16,2,3
spr 183,4,-24
camera draw_x,draw_y]]
    if player_here() then
      if stars_falling then
        for i = 1,8 do
          pos = rnd(#text)+1
          c = i<=3 and rnd(split(text,"")) or text[pos]
          if ptext[pos] ~= "\n" and c~="\n" then
            ptext = sub(ptext,1,pos-1)..c..sub(ptext,pos+1)
          end
        end
      end

      index+=0.5
      ?"\^x5\^y8"..sub(ptext, 1, index),args"8,16,7"
      if index%1==0 and index < #text then
        ?"\as4i6<<<x5d#4"
      end
    else
      exec[[lset ptext,text
lset index,0]]
    end
  end
)
end_screen=create_type(
  function(_ENV) -- init
    foreach(fruitrain, function(f)
      _g.berry_count+=1
      if f.golden then
        exec[[gset collected_golden,True]]
      end
    end)
  end,
  nil,
  function (_ENV) --draw
    exec[[rectfill 17,16,110,91,7
rectfill 16,17,111,91,7
rectfill 15,18,112,91,7
rectfill 15,92,112,110,6
rectfill 16,92,111,111,6
rectfill 17,92,110,112,6
rectfill 15,22,113,42,1
rectfill 16,23,113,41,3
rectfill 15,43,112,43,6
fillp 0b1100000000000000.1000
rectfill 15,92,112,92,13
fillp]]

    for _x=7,16 do
      line(_x,16+_x, 18, 16+_x, 3)
      line(_x,16+_x, _x+3, 16+_x, 10)

      line(_x,48-_x, 18, 48-_x, 3)
      line(_x,48-_x, _x+3, 48-_x, 10)
    end

    -- ?args"CHAPTER 2,52,26,11"
    -- ?args"old site,56,34,7"
    -- ?args"chapter complete!,31,100,0"
    --
    -- ?"⁙ "..berry_count.."/18",args"55,51,0"
    -- ?"⁙ "..deaths,args"55,64,0"
    -- ?args"⁙ ,55,77,0"

    ?"\^jd6\|i\fbCHAPTER 2\^je8\|i\f7old site\^j7p\-j\f0chapter complete!\^jdc\+jj\f0⁙ "..berry_count.."/8\^jdj\+jh\f0⁙ \^jdg\-j\f0⁙ "..deaths
    draw_time(args"63,77,0")

    --manually draw outlines
    palsplit"0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"
    berry_sprite=collected_golden and 11 or 10
    exec[[spr berry_sprite,43,49
spr berry_sprite,41,49
spr berry_sprite,42,50
spr berry_sprite,42,48
spr 151,43,63
spr 151,41,63
spr 151,42,64
spr 151,42,62
spr 167,43,76
spr 167,41,76
spr 167,42,77
spr 167,42,75
spr 212,94,25,2,2
spr 212,92,25,2,2
spr 212,93,26,2,2
spr 212,93,24,2,2
pal
spr berry_sprite,42,49
spr 151,42,63
spr 167,42,76
spr 212,93,25,2,2]]
  end
)

psfx=function(num)
  if sfx_timer<=0 then
   sfx(num)
  end
end

-- [tile dict]
tiles={}
foreach(split([[
1,player_spawn
8,campfire
10,fruit
11,fruit
15,refill
23,fall_floor
66,fall_plat
68,touch_switch
71,switch_block
88,switch_target
64,dream_block
6,phone_booth
7,end_screen
181,memorial
128,mirror
]],"\n"),function(t)
 local tile,obj=args(t)
 tiles[tile]=_ENV[obj]
end)


-- [object functions]

function init_object(_type,sx,sy,tile)
  --generate and check berry id
  --hardcoded level 29 berry to match level 2 berry
  local id=lvl_id==29 and "320,48,2" or sx..","..sy..","..(linked_levels[lvl_id] or lvl_id)
  if _type.check_fruit then
    if got_fruit[id] then
      return
    end
    for f in all(fruitrain) do
      if f.fruit_id==id then
        return
      end
    end
  end
  --local _g=_g
  local _ENV=setmetatable({},{__index=_g})
  type, collideable, sprite, flip, x, y, hitbox, spd, rem, fruit_id, outline, draw_seed=
  _type, true, tile, vector(), sx, sy, rectangle(args"0,0,8,8"), zerovec(), zerovec(), id, true, rnd()

  function left() return x+hitbox.x end
  function right() return left()+hitbox.w-1 end
  function top() return y+hitbox.y end
  function bottom() return top()+hitbox.h-1 end

  function is_solid(ox,oy,require_safe_ground)
    for o in all(obj_bins.solids) do
      if o!=_ENV and (o.solid_obj or o.semisolid_obj and not objcollide(o,ox,0) and oy>0) and objcollide(o,ox,oy) and not (require_safe_ground and o.unsafe_ground) then
        return true
      end
    end
    return oy>0 and not is_flag(ox,0,3) and is_flag(ox,oy,3) or  -- one way platform or
            is_flag(ox,oy,0) -- solid terrain
            -- <dream_block> --
           or check(dream_block,ox,oy) and (not dream_blocks_active
           or dash_effect_time<=2
           or not check(dream_block,sign(dash_target_x),sign(dash_target_y)) and not dreaming)
           -- </dream_block> --
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
    for other in all(obj_bins[type]) do
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

  function lset(k,v)
   _ENV[k]=_ENV[v] or v
  end

  function exec(fns)
    _g.exec(fns,_ENV)
  end





  add(objects,_ENV);
  obj_bins[type]=obj_bins[type] or {}
  add(obj_bins[type],_ENV);
  (type.init or time)(_ENV)

  if solid_obj or semisolid_obj then
    add(obj_bins.solids,_ENV)
  end

  return _ENV
end

function destroy_object(obj)
  del(objects,obj)
  del(obj_bins[obj.type],obj)
  del(obj_bins.solids,obj)
end

function kill_player(obj)
  sfx_timer,shake=12,9
  sfx"17"
  sfx(28,-2)
  deaths+=1
  destroy_object(obj)
  --dead_particles={}
  for dir=0,0.875,0.125 do
    add(dead_particles,bt("x,y,t,dx,dy",{
      obj.x+4,
      obj.y+4,
      2,
      sin(dir)*3,
      cos(dir)*3
    }))
  end
    -- <fruitrain> ---
  foreach(fruitrain,function(f)
    full_restart = full_restart or f.golden
  end)
  fruitrain={}
  --- </fruitrain> ---
  --delay_restart=15
  -- <transition> --
  co_trans=cocreate(transition)
  -- </transition> --
end

-- [room functions]


function next_level()
  local mu=music_triggers[lvl_id]
  if lvl_id==31 then
    for a=14772,15520,68 do
      poke(a+65, 20)
    end
  end
  if mu then
    music(args(mu))
  end
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
  --<badeline>--
  bad_num=tbl[7] or 0
  --</badeline>--

  local exits=tonum(tbl[5]) or 0b0001

  -- exit_top,exit_right,exit_bottom,exit_left=exits&1!=0,exits&2!=0,exits&4!=0, exits&8!=0
  for i,v in inext,split"exit_top,exit_right,exit_bottom,exit_left" do
    _ENV[v]=exits&(0.5<<i)~=0
  end

  entrance_dir=tonum(tbl[6]) or 0

  --reload map
  if diff_level then
    reload(0x1000,0x1000,0x2000)
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

  --<camtrigger>--
  --generate camera triggers
  cam_offx,cam_offy=0,0
  local c=camera_offsets[lvl_id]
  if c!='{}' then
    for s in all(split(c,"|")) do
      local tx,ty,tw,th,offx_,offy_=args(s)
      local _ENV=init_object(camera_trigger,tx*8,ty*8)
      hitbox.w,hitbox.h,offx,offy=tw*8,th*8,offx_,offy_
    end
  end
  --</camtrigger>--

  -- entities
  for tx=0,lvl_w-1 do
    for ty=0,lvl_h-1 do
      local tile=tile_at(tx,ty)
      if tiles[tile] then
        init_object(tiles[tile],tx*8,ty*8,tile)
      end
    end
  end
  --<badeline>--
  for i=1,bad_num do
    init_object(badeline,0,0)
  end
  --</badeline>--
  foreach(objects,function(_ENV)
    (type.end_init or time)(_ENV)

  end)

end

-- [main update loop]

function _update()
  frames+=1
  if lvl_id<=35 and title==0 then
    seconds+=frames\30
    minutes+=seconds\60
    seconds%=60
    seconds_f=frames%30
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
    -- <cutscene> --
    move(spd.x,spd.y,(type==player or type==cutscene_badeline) and 0 or 1);
    -- </cutscene> --
    (type.update or time)(_ENV)
    draw_seed=rnd()
  end)

  --move camera to player
  local p=find_player()
  if p then
    --move camera to p
    --<camtrigger>--
    cam_spdx,cam_spdy=cam_gain*(4+p.x-cam_x+cam_offx),cam_gain*(4+p.y-cam_y+cam_offy)
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
end

-- [drawing functions]

function _draw()
  if freeze>0 then
    return
  end

  -- reset all palette values
  pal()

  --set cam draw position
  draw_x,draw_y=round(cam_x)-64,round(cam_y)-64

  if shake>0 then
    shake-=1
    if screenshake then
      draw_x+=-2+rnd"5"
      draw_y+=-2+rnd"5"
    end
  end

  -- draw bg color
  cls()

  if title > 0 then
    local xe,yt,yb = flr(15*(1-title)),ceil(28*(1-title)),flr(30*(1-title))

    exec[[_camera
rectfill 0,60,128,128,1
fillp 0b1111000011110000
rectfill 0,50,128,60,1
fillp
spr 192,23,2,8,1
spr 208,87,2,3,1
spr 224,34,12,4,1
spr 240,66,12,4,1]]
    ?args"•-                       -•, 10, 8, 7"
    ?args"based on celeste by exok games, 5, 120, 13"

    tmp_a,tmp_b,tmp_c,tmp_d,tmp_e,tmp_f,tmp_g,tmp_h=9-xe,22-yt,118+xe,116+yb,15-xe, 28-yt, 112+xe, 97+yb
    exec[[rectfill tmp_a,tmp_b,tmp_c,tmp_d,7
rectfill tmp_e,tmp_f,tmp_g,tmp_h,0
color 1
pset tmp_a,tmp_b
pset tmp_a,tmp_d
pset tmp_c,tmp_b
pset tmp_c,tmp_d]]

    ?"press 🅾️/❎", 42, 101+yb, 13
    ?"by the n.p8 team", 32, 109+yb, 1

    clip(15-xe, 28-yt, 98+xe*2, 70+yt+yb)
  end

  --<stars>--
  -- bg stars effect
  if stars_falling then
    exec[[pal 7,6
pal 6,12
pal 13,12
pal 5,1
pal 10,12]]
  else
    exec[[palt 5,True
pal 10,7]]
  end
  foreach(stars, function(c)
    local x=c.x
    local y=c.y
    --avoid the edge case where sin(c.off) is exactly 1
    local s=flr(min(1,sin(c.off)*2))
    camera(-x,-y)
    if c.size==2 then
      if s==-2 then
        exec[[sspr 32,122,1,5,0,-4]]
      elseif s==-1 then
        exec[[spr 73,-3,-4]]
      elseif s==0 then
        exec[[spr 89,-7,-8,2,2]]
      else
        exec[[sspr 48,111,15,17,-7,-9]]
      end
    else
      if s==-2 then
        exec[[sspr 32,122,1,5,0,-4]]
      elseif s==-1 then
        exec[[sspr 33,122,3,6,-1,-4]]
      elseif s==0 then
        exec[[sspr 36,120,5,8,-2,-5]]
      else
        exec[[sspr 24,104,5,9,-2,-6]]
      end
    end

    c.x+=(-cam_spdx/4)*(2-c.size)
    c.y+=(-cam_spdy/4)*(2-c.size)
    c.off+=0.01
    if c.x>128 then
      c.x=-8
      c.y=rnd"120"
    elseif c.x<-8 then
      c.x=128
      c.y=rnd"120"
    end
    if stars_falling then
      c.y+=c.spdy
      if c.y>128 then
        c.y=-8
        c.x=rnd"120"
        c.spdy=rnd"0.75"+0.5
      end
    end
  end)
  pal()

  camera(draw_x,draw_y)
  --</stars>--

		-- draw bg terrain
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)

  -- draw outlines
  palsplit"1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1"
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
  palt"0x80"
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
  palt()

  -- draw objects
  foreach(layers,function(l)
    foreach(l,draw_object)
  end)

  -- draw platforms
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,8)

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

  -- <cutscene> --
  if cutscene then
    coresume(cutscene, cutscene_env)
    if costatus(cutscene) == "dead" then
      pause_player,cutscene,cutscene_env=false--,nil,nil
    end
  end
  -- </cutscene> --
  -- draw time
  if ui_timer>=-30 then
    if ui_timer<0 then
      rectfill(draw_x+4,draw_y+4,draw_x+48,draw_y+10,0)
      draw_time(draw_x+5,draw_y+5,7)
    end
    ui_timer-=1
  end

  -- <transition> --
  if (co_trans and costatus(co_trans) != "dead") coresume(co_trans)
  color"0"

--   if seconds>0 then
--   max_cpu = max(max_cpu,stat(1))
--   camera()
--   print(max_cpu,0,0,7)
-- end
end

function draw_object(_ENV)
  srand(draw_seed);
  (type.draw or draw_obj_sprite)(_ENV)
end

function draw_obj_sprite(_ENV)
  spr(sprite,x,y,1,1,flip.x,flip.y)
end

function draw_time(x,y,c)
  ?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds)..'.'..two_digit_str(round(seconds_f/30*100)),x,y,c
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

function palsplit(x)
  pal(split(x))
end

function zerovec()
  return vector(0,0)
end

function tile_at(x,y)
  return mget(lvl_x+x,lvl_y+y)
end

function spikes_at(x1,y1,x2,y2,xspd,yspd)
  for i=max(0,x1\8),min(lvl_w-1,x2/8) do
    for j=max(0,y1\8),min(lvl_h-1,y2/8) do
      if({y2%8>=6 and yspd>=0,
          y1%8<=2 and yspd<=0,
          x1%8<=2 and xspd<=0,
          x2%8>=6 and xspd>=0})[tile_at(i,j)-15] then
            return true
      end
    end
  end
end

-- <transition> --
function transition(wipein)
  local circles = {}
  for x=0,7 do
    for y=0,7 do
      local delay=rnd"1.5" + (wipein and 6 - x or x)
      add(circles,bt("x,y,delay,radius",{
         (x - 0.8 + rnd"0.6") * 20,
         (y - 0.8 + rnd"0.6") * 20,
         delay,
         wipein and 30 - 2*delay or 0
      }))
    end
  end

  for t=1,15 do
    camera()
    local circfill=circfill
    foreach(circles, function(_ENV)
      if not wipein then
        delay -= 1
        if delay <= 0 then
          radius += 2
        end
      elseif radius > 0 then
        radius -= 2
      else
        radius = 0
      end
      if (radius>0) circfill(x, y, radius, 0)
    end)

    yield()
  end

  if not wipein then
    delay_restart=1
    for t=1,3 do
      cls()
      yield()
    end

    co_trans=cocreate(transition)
    coresume(co_trans, true)
  end
end
-- </transition> --

-- <circ_transition>--

function circ_transition()
  --find_player()
  local p=find_player()
  p.spd,pause_player=zerovec(),true

  sfx"26"

  radii=split"128,120,112,104,96,88,80,72,64,56,48,40,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,28,24,20,16,12,8,4,0,0,0,0,0,0,0,0,0,0,0,0,4,8,12,16,20,24,28,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,40,48,56,64,72,80,88,96,104,112,120,128"
  s=""
  for i,r in ipairs(radii) do
    if i==48 then
      --set p in order to center circle for end screen
      p,stars_falling,pause_player=vector(64,64),--false,false
      next_level()
      local o=find_player()
      if o then
        p=vector(o.x,o.target)
      end
    end
    inv_circle(p.x+4,p.y+4,r)
    yield()
  end
end

function inv_circle(circle_x, circle_y, circle_r)

  color"0"
  rectfill(-1, -1, 128, circle_y - circle_r)
  rectfill(-1, circle_y + circle_r, 128, 128)
  rectfill(-1, -1, circle_x - circle_r, 128)
  rectfill(circle_x + circle_r, -1, 128, 128)


  for i=circle_r,circle_r*sqrt"2"+1 do
    for t=0,3 do
      circ(circle_x+t\2, circle_y+t%2, i)
    end
  end
end

function find_player()
  for _ENV in all(objects) do
    if type==player or type==player_spawn then
      return _ENV
    end
  end
end
-- </circ_transition>--
-->8
--[map metadata]

--@conf
--@begin
--level table
--"x,y,w,h,exit_dirs,entrance_dir,badeline num"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
--entrace direction 012345->bfr (bottom facing right) bfl tfr tfl left right
--entrace direction 012345->bfr (bottom facing right) bfl tfr tfl left right static
levels=split([[0,0,1,1,0b0010,6,0,
  -3.5,2.9375,3,1,0b0100,4,0,
  0.3125,-2.0625,1.1875,2,0b0010,2,0,
  -1.25,1,1.25,1,0b0010,4,0,
  0,1,1,1,0b0010,4,0,0,
  1,1,2,1,0b0010,4,0,
  1.75,-1.875,1.3125,1.5,0b1000,4,0,
  1.5625,4.3125,1.4375,1.3125,0b1000,5,0,
  2,2,2,1,0b1001,5,0,
  -1.25,-2.0625,1.1875,2,0b1000,5,0,
  3,3,1,1,0b0001,5,0,0,
  -3.5,4,3,1,0b0001,0,0,
  7,0,1,1,0b0001,0,0,
  5,0,1,1,0b0001,0,1,
  2,3,1,1,0b0001,0,1,0,
  5.9375,-4.1875,1,1.4375,0b0001,1,2,
  1,0,1,1,0b0010,0,1,
  2,0,1,1,0b0001,4,2,
  3,0,1,1,0b0010,0,1,
  4,0,1,1,0b0001,4,2,
  7,1,1,1,0b0001,0,3,
  7,2,1,1,0b0001,0,1,
  9.5,-2.5,1,2,0b0010,0,2,
  10.5,-2.5,2,1,0b0010,4,1,
  12.5,-2.5,3,1,0b0010,4,2,
  15.5,-2.5,1,2,0b0010,4,1,
  10.1875,0.375,1,2.0625,0b0100,2,2,
  6,0,1,4,0b0100,2,4,
  -0.1875,5.6875,2,1.5,0b0010,2,0,0,
  3,1,3,1,0b0010,4,0,
  7,3,1,1,0b0000,4,0,
  0,0,1,1,0b0010,6,0,
  0,3,3,1,0b0010,4,0,0,
  3,3,3,1,0b0010,4,0,
  7,3,1,1,0b0000,4,0,
  8.125,3.875,0.0625,0.0625,0b0001,4,0,0]],"\n")

--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets=split(
[[{}
25,4,2,5,-18,0|29,3,2,8,0,0
{}
{}
{}
16,2,1,5,16,0|15,2,1,5,0,0
6,11,1,7,74,0|4,15,1,3,0,0|10,8,7,1,24,0|10,12,7,1,56,0
12,6,2,8,-20,56|20,15,1,1,0,56|14,6,5,1,0,0|14,8,7,1,0,56
{}
{}
{}
25,4,2,5,-18,0|29,3,2,8,0,0
{}
{}
{}
1,16,15,1,0,0|1,14,3,1,0,-32
{}
{}
{}
{}
{}
{}
11,17,4,3,0,0|4,7,4,3,0,20
{}
13,2,2,14,32,0
0,1,6,1,0,24
9,12,5,1,0,16
1,19,3,5,0,24|1,17,3,2,0,0
{}
0,7,5,5,20,0
{}
{}
{}
{}
{}
{}]],"\n")
--</camtrigger>--

--mapdata string table
--assigned levels will load from here instead of the map
mapdata={
  nil,
  "!&&&9'&`¹233339&!&&&&3333&&9&'■■■■■%9&'¹¹¹¹¹¹¹¹¹333!&4V&`¹¹^&V%&&&9&4;-)&%9&&!######&&',¹¹L¹¹¹¹¹&○o%'om&&__o&&%9&&&'&¹Q-&%!3333&&&!&&&&-,¹\\¹¹¹¹¹p¹n%'mmVWo&&V\"9&339'█t:=-24█¹¹⁘%!33333&&=$\\¹¹¹¹¹█¹n%9##$g&ABB%!4○&%'¹t¹QRop¹¹¹⁘24¹¹¹~o2333,`¹^`¹¹¹~%&33!#$B¹¹%'p¹n24¹u¹:<&&`¹¹¹□□¹¹¹¹n&○○oQ,¹np¹¹¹¹24V&2&'B¹¹24p¹~█¹¹¹¹¹¹o&p¹¹¹¹¹¹¹■■~█¹ᵇnQR^op¹¹¹¹¹¹~p¹%'B¹¹&█¹¹¹t¹¹¹¹¹¹nVp¹¹¹¹¹w¹゛$¹¹¹¹~Q),&V`¹¹¹¹¹¹l¹2'B¹¹p¹¹¹¹t¹¹¹q¹¹no█¹¹¹¹¹◀▶%'ma¹¹*-=Ro&p¹¹¹¹¹¹¹¹~8B¹¹p¹¹¹¹m¹¹NMNN゛$¹¹¹¹¹¹¹^24‖◀◀▶Q&&=,o&¹¹¹¹¹¹¹¹¹¹~&op¹^`¹¹¹¹¹O¹^%0■■¹¹¹¹^Vp¹¹¹¹¹Q=&&-+,¹¹¹¹¹¹¹¹¹¹¹nV&_op¹¹¹¹゛ ¹n%&#$¹¹¹¹n&o`¹¹¹*))&&&&-¹²¹¹¹¹¹¹¹¹¹n&&h&paL¹¹.'^&%&90¹¹S_*++$■■*-=&;-&&&++,¹¹¹¹¹¹¹^o&Vi*++,■■%'&o.&&0¹¹¹~Q-)=$‖▶%)RV:=9&=)-++,‖◀▶\"####+)-)&##90V&.!&0■■■■:&&&'¹^%&R&o%!&&&&)=R¹¹¹%!&&!)-&&-&&&0o&.&&9##゜゜=&&=R^N%9'o&%&!",
  "&&&&&&&0&○○.&&&&&&&&&&&&&/@█²¹>/&&&&&&&&&&/?@█¹¹¹~>?/&&&/&&&/0v¹¹¹¹¹¹~○.&/&&????@¹¹¹¹¹¹¹¹¹>??/&¹ABBB¹¹¹¹¹¹¹¹¹vtt.&¹B¹¹¹¹¹¹¹¹¹¹¹¹¹tv./¹B¹¹¹¹¹¹¹¹¹¹¹¹¹u¹.&゜゜゜ P¹¹¹¹¹¹¹¹¹¹¹¹.&&&/0¹¹¹¹¹¹¹¹¹¹¹¹¹./&&&0‖◀◀¹¹¹¹¹¹¹¹¹¹./&/?@`¹¹¹¹¹¹¹゛ ‖◀▶>/&0○&&`¹¹¹¹¹¹.0¹¹¹¹>&0¹~○゛ ABBB゛/0¹¹¹¹¹&0¹¹¹>0B¹¹¹>/0¹¹u¹¹&0¹¹¹¹x¹¹~○&>/ au¹a&/,¹¹¹¹¹¹¹¹~&>/゜゜゜゜&/-+,¹¹¹¹¹¹¹~○:--/&&&/-R¹¹¹¹¹¹¹¹¹¹Q-.&&&&//゜ ‖◀¹¹¹¹¹¹Q-.&&/????@■■■■■■¹¹:;.&&0¹¹¹ABBBBBBB¹¹]N.&/0¹ᵇ¹B¹¹¹¹¹¹¹¹¹¹].&/@¹¹¹B¹¹¹¹¹¹¹¹¹¹¹.&0⁙¹¹¹゛゜゜゜゜}¹¹¹¹¹¹./0⁙¹¹^>???@v¹¹¹¹¹¹>?0⁙¹¹~V&&&█¹¹¹¹¹¹¹~&0⁙¹¹¹~T&p¹¹¹¹¹¹¹¹¹n0⁙¹¹¹¹n&p¹¹¹wrsa¹¹n0■¹¹¹¹n&`¹¹゛゜゜゜゜゜゜゜/ ⁙¹^_&&&\\_.//&&/&/&0⁙^&&&&o&&./&&&&&&",
  "???/&&&/?????/&&&&&&&o○>?&/@t¹t¹n>?/&/??V█¹¹n.@¹t¹u¹~&V.?@o&p¹¹¹~y⁙¹t¹¹¹¹n&yV&&Vp²¹¹¹y⁙¹u¹■■¹~ox○○&&゜゜}¹¹y⁙¹¹¹゛ ¹¹~█¹¹~o/@¹¹¹x⁙¹¹¹.0¹¹¹¹¹¹¹n0¹a¹¹¹¹¹▮¹.0¹▮¹¹¹¹¹n0NMNP¹¹¹¹¹.0¹¹¹¹¹◀▶゛0NNP¹¹¹¹¹^.0__`¹¹¹¹.0¹¹¹¹¹¹¹^o.0&o○U¹¹■.0■¹¹¹¹¹¹~○.0○█¹¹¹¹゛// ¹¹¹¹¹■■■.0■¹¹¹¹■.&&0■■■■■゛゜゜// ■■■■゛/&&/゜゜゜゜゜/&&&&/゜゜゜゜/&&&&&&//&&&&&&&&&//&&&",
  nil,
  nil,
  "&&/&&&&&/??//?//?/&&&&/???//?@&○.@¹>@v>?/&?@&&o>@█○█¹x¹¹¹t¹~&.&&V&&V█¹¹¹¹¹t¹¹¹v¹¹n>/o&V&p¹¹¹¹¹¹u¹¹¹¹¹¹~&.゜゜゜゜゜゜ ¹¹¹¹¹¹¹¹¹¹¹¹n.&&&&&/0u¹¹¹¹¹¹¹¹¹aq゛/&&&&&&/゜ ¹¹¹¹¹¹¹゛゜゜//&&&&&&&&/ ABBBBB.//&&&&&&&&&/&0B¹¹¹¹¹.&&&&&&&&&/??/0B¹¹¹¹¹./&&&&&&&&0&&>0B¹¹¹¹¹.??/&&&&&&0&○○xB¹¹¹¹¹x~&.&&&&//@█¹¹¹B¹¹¹¹¹¹¹n.&/???@█¹¹¹¹¹¹¹¹¹¹¹¹~.&0○○█¹¹¹¹¹¹¹¹¹¹¹¹¹¹O>/0ma¹¹¹¹¹¹¹¹▒¹¹¹¹¹¹O¹.0mm¹¹¹²¹¹¹¹¹¹¹¹¹¹]NM.0mm゛゜゜}¹¹¹¹¹¹¹¹¹¹¹¹O.@‖▶./0¹¹¹゛゜゜゜゜゜゜ ¹m゛/p¹¹./0ma¹.//&/&/0wm.&p¹¹.&/゜゜゜/&&&&&&/゜゜/&&`u./&&//&&&&&&&&&&&&゜゜゜/&&&&&&&&&&&&&&&&&",
  "&&&&&&&&&&&&&/?????/&&&&&&&&&&&&&&&/@o&█¹¹>/&&&&&&&&&&&&&/0V&pᵇ¹¹¹.&&&&&&&&&&&&&/0&W&_`¹¹./&&&&&//&&&&&&/ gV&o`゛&&&&/????/&&//&&0ABBBB./&&/@tt¹v>????/&0B¹¹¹¹>?/&@¹vt¹¹¹¹¹¹¹>?0B¹¹¹¹¹¹.&¹¹¹u¹¹¹¹¹¹¹¹OxB¹¹¹¹NN./¹¹¹¹■■■■■¹¹¹O¹B¹¹¹¹P¹./¹¹¹¹ABBBB¹amOqB¹¹¹¹¹^>/゜ ‖¹B¹¹¹¹NNMNNB¹¹¹¹¹no./0¹¹B¹¹¹¹¹¹O¹¹B¹¹¹^^&&>&@¹¹B¹¹¹¹¹¹O¹¹B¹¹¹n&V○o0¹¹¹¹¹¹¹¹¹¹O゛ B¹¹¹nV█¹n0■¹¹¹¹¹¹¹¹*+/0B¹¹¹np²¹n&,¹¹¹¹¹¹¹*-=&/゜゜゜゜゜゜゜゜゜-R■■■■■■■Q&&&&&//&/&&//&)+゜++゜゜+)&&&&&&&&&&&&&&&&-=&-/=&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&",
  nil,
  "&&&&&&&0;-=.&&&&&&&&&&&&&/@○:;>/&&&&&&&&&&/?@█¹¹¹~>?/&&&/&&&/0v¹¹¹¹¹¹~○.&/&&????@¹¹¹¹¹¹¹¹¹>??/&¹ABBB¹¹¹¹¹¹¹¹¹vtt.&¹B¹¹¹¹¹¹¹¹¹¹¹¹¹tv./¹B¹¹¹¹¹¹¹¹¹¹¹¹¹u¹.&゜゜゜ P¹¹¹¹¹¹¹¹¹¹¹¹.&&&/0¹¹¹¹¹¹¹¹¹¹¹¹¹./&&&0‖◀◀¹¹¹¹¹¹¹¹¹¹./&/?@`¹¹¹¹¹¹¹゛ ‖◀▶>/&0○&&`¹¹¹¹¹¹.0¹¹¹¹>&0¹~○゛ ABBB゛/0¹¹¹¹¹&0¹¹¹>0B¹¹¹>/0¹¹u¹¹&0¹¹¹¹x¹¹~○&>/ au²a&/,¹¹¹¹¹¹¹¹~&>/゜゜゜゜&/-+,¹¹¹¹¹¹¹~○:;;/&&&/-R¹¹¹¹¹¹¹¹¹¹n&.&&&&//゜ ‖◀¹¹¹¹¹¹n&.&&/????@■■■■■■¹¹~o.&&0¹¹¹ABBBBBBB¹¹¹~.&/0¹ᵇ¹B¹¹¹¹¹¹¹¹¹¹¹.&/@¹¹¹B¹¹¹¹¹¹¹¹¹¹¹.&0⁙¹¹¹゛゜゜゜゜}¹¹¹¹¹¹./0⁙¹¹^>???@v¹¹¹¹¹*>?0⁙¹¹~V&&&█¹¹¹¹¹¹Q=-0⁙¹¹¹~T&p¹¹¹¹¹¹¹Q-=0⁙¹¹¹¹n&p¹¹¹wrs*-=-0■¹¹¹¹n&`¹¹゛゜゜゜゜゜゜゜/ ⁙¹^_&&&\\_.//&&/&//0⁙^&&&&o&&./&&&&&&",
  nil,
  "!&&&9'&`¹233339&!&&&&3333&&9&'■■■■■%9&'¹¹¹¹¹¹¹¹¹333!&4V&`¹¹^&V%&&&9&4o&&V%9&&!######&&',¹¹L¹¹¹¹¹&○o%'om&&__o&&%9&&&'&○○&&%!3333&&&!&&&&-,¹\\¹¹¹¹¹p¹n%'mmVWo&&V\"9&339'█t¹~V24█¹¹⁘%!33333&&=$\\¹¹¹¹¹█¹n%9##$g&ABB%!4○&%'¹t¹¹nop¹¹¹⁘24¹¹¹~o2333,`¹^`¹¹¹~%&33!#$B¹¹%'p¹n24¹u¹¹n&&`¹¹¹□□¹¹¹¹n&○○oQ,¹np¹¹¹¹24V&2&'B¹¹24p¹~█¹¹¹¹¹~o&p¹¹¹¹¹¹¹■■~█¹ᵇnQR^op¹¹¹¹¹¹~p¹%'B¹¹&█¹¹¹t¹¹¹¹¹¹nVp¹¹¹¹¹w¹゛$¹¹¹¹~Q),&V`¹¹¹¹¹¹l¹2'B¹¹p¹¹¹¹t¹¹¹q¹¹no█¹¹¹¹¹◀▶%'ma¹¹*-=Ro&p¹¹¹¹¹¹¹¹~8B¹¹p¹¹¹¹m¹¹NMNN゛$¹¹¹¹¹¹¹^24‖◀◀▶Q&&=,o&¹¹¹¹¹¹¹¹¹¹~&op¹^`¹¹¹¹¹O¹^%0■■¹¹¹¹^Vp¹¹¹¹¹Q=&&-+,¹¹¹¹¹¹¹¹¹¹¹nV&_op¹¹¹¹゛ ¹n%&#$¹¹¹¹n&o`¹¹¹*))&&&&-¹¹¹¹¹¹¹¹¹¹¹n&&h&paL¹¹.',&%&90¹¹S_*++$■■*-=&;-&&&++,¹¹¹¹²¹¹^o&Vi*++,■■%'=,.&&0¹¹¹~Q-)=$‖▶%)RV:=9&=)-++,‖◀▶\"####+)-)&##90)-.!&0■■■■:&&&'¹^%&R&o%!&&&&)=R¹¹¹%!&&!)-&&-&&&0-).&&9##゜゜=&&=R^N%9'o&%&!",
  nil,
  nil,
  nil,
  "¹¹¹¹¹¹¹¹¹¹¹%'&&%¹¹¹¹¹¹¹¹■■■%'AB%¹¹¹■■■■■*++%'B¹%¹¹¹5#6663;;;4B¹%¹¹¹¹1□□□¹¹~○&&&%■¹¹¹1⁙¹¹¹¹¹¹~○○%,■■■1⁙ᵇ¹■■¹¹¹■■%-+++'⁙¹¹\"$■■■\"#9&);9'⁙¹¹%'ABB%!&=<o24⁙¹¹2'B¹¹29&RV&p¹¹¹¹¹8B¹¹¹%&R&o&`¹¹¹¹t¹vt¹29'&&Vp¹¹¹¹t¹▮t¹⁘%'&WV█¹¹¹¹t¹¹u¹⁘%'og█v¹¹¹¹u¹¹¹¹⁘2'‖▶(¹¹¹¹q¹¹¹¹¹¹¹'`¹1¹¹¹¹O¹¹¹¹¹¹¹'o`1¹¹¹¹O¹¹¹¹¹¹¹'&V8■■■¹O¹a¹¹¹¹¹'V○ABBBqO]MPm¹¹■'█OB¹¹¹NMNOmm²¹\"'¹O□□□□¹O¹O(‖◀▶%'¹O¹¹¹¹¹O¹O1¹¹¹%",
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  "¹¹¹¹¹¹^_&*-=!&9&¹¹¹■*#666;;33333¹■■*-4v¹Y¹~○&pHI⁘5+-R¹¹¹¹¹¹¹~█X¹¹t2)4¹¹¹¹wrs¹aX^¹v¹1¹¹¹¹\"#$‖◀▶\"#■■■1`¹¹¹%&'ABB%9+++Ro__`29'B¹¹%&33!R&WV&_%'B¹¹%!¹t24Vg&&o%'B¹¹%9¹u¹ABBBB&2'B¹¹%&¹¹¹B¹¹¹¹█¹1B¹¹%&aE¹B¹¹¹¹¹¹1B¹¹%&##7B¹¹¹¹`¹1B¹¹%&&4¹B¹¹¹¹pE1B¹¹%!'¹¹B¹¹¹¹&`1B¹¹%&4¹¹B¹¹¹¹5#'B¹¹%9¹¹¹B¹¹¹¹o2'B¹¹%!¹¹¹B¹¹¹¹█t1B¹¹%&¹¹¹¹¹(t¹¹t1B¹¹%&¹¹¹E¹1t¹¹v1B¹¹%9¹¹「「「1t¹¹¹1B¹¹%&¹¹¹¹¹1CDDD1B¹¹%&■■■■■1D¹¹¹1B¹¹%&###664¹¹^_1B¹¹%&&34Vp¹¹¹nV1B¹¹%9'&o&█¹¹¹~&8B¹¹%9'V○█¹¹¹¹¹~○o&&%&'█²¹ma¹¹¹¹¹n&V%&'‖◀▶\"$¹¹¹¹^&V&%&'_`¹%'■■■■\"###9&'&&_%9####&&!&&&",
  "&&&&&&&9&&&!&&&&&&!&&&&&333!&&&&&&9&!&&333!333!&&&339&!'a¹~29&&!&3333!'ABB1¹¹¹%&&'□□2334NP¹n2!33'¹t¹t24B¹¹1¹E¹%!9'⁙¹¹~&p¹¹¹~█1Yn4¹t¹v¹¹B¹¹8¹¹¹233'⁙¹¹E~█¹¹¹¹¹8¹~¹¹t¹¹¹¹B¹¹¹¹▮¹ABB1⁙¹¹■■■■■¹¹¹¹HI¹¹v¹¹¹¹B¹¹¹¹¹¹B¹¹1⁙¹¹ABBBB¹¹¹¹X¹¹¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹8⁙¹¹B¹¹¹¹¹¹q▶5#a¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹¹¹¹qO¹¹%m¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹¹¹NNMNN%m²m¹¹¹¹B¹¹¹L¹¹B¹¹¹¹L¹¹t¹t¹¹¹Oa¹%##$¹¹¹¹¹tv¹n`¹B¹¹¹^p¹¹t¹u¹¹]NNN%!&'■■■¹¹t¹¹np¹B¹¹¹np¹¹t¹¹¹¹¹¹¹¹Q&&9##$⁙¹v¹^op¹¹*,■n&`¹u¹L¹¹¹¹¹■Q&&&&9'■¹¹¹n&&`■Q=,&&V_U¹\\¹¹¹¹■*-&&&&&!$¹¹¹n&Vp*=)RV&&p¹¹n`¹¹¹*=&",
  "33;;;-'¹¹%&&9!&&'&`¹%&&!9&&-R¹¹¹¹%9&3339&&!=&&&&¹¹¹~V:)##!33333&9###9&3333!&)+,¹a%&4ot○%&33;;-&&¹¹¹¹~&Q=&'V█¹¹~23&&&&4&&○t239&=+#&'p█u¹24¹~○&:=&¹²¹¹¹nQ&!4█¹¹¹¹~o%&94&○█¹t~U23&&-&'█¹¹¹AB¹¹t~oQ=#$¹¹¹~%)'v¹¹¹¹¹¹~%&'oV█¹¹u¹¹~&%&&9'¹¹¹¹B¹¹¹t¹~%)!4¹¹¹¹%!'¹¹¹¹w¹¹¹%!4○¹¹¹¹¹¹¹¹~%&&34¹▮¹¹B¹¹¹v¹¹2&'¹¹¹¹¹%9'¹¹¹\"$¹¹¹24█¹¹¹¹▮¹¹¹¹¹%!4AB¹¹¹¹B¹¹¹¹¹¹v2'¹am¹¹%&']MN2'¹¹¹AB¹¹¹¹¹¹¹¹¹¹¹%'¹B¹¹¹¹⁘\"$¹¹¹¹¹¹¹'NMNP¹234NP¹⁘1¹¹¹B¹¹¹¹¹¹■■■¹m¹%4¹B¹¹¹¹⁘%'¹¹¹¹¹¹¹'NNP¹¹ABB¹¹¹⁘1¹¹¹B¹¹¹¹■■\"#$]MN8v¹B¹¹¹¹⁘%'¹¹¹¹rs¹'¹¹¹¹¹B¹¹¹¹¹⁘8¹¹¹B¹¹¹¹\"#9!4NP¹¹¹¹B¹¹¹¹⁘%'¹¹¹¹\"##'¹¹¹¹¹B¹¹¹¹¹¹t¹¹¹B¹¹¹¹2!&'v¹¹¹¹¹¹B¹¹¹¹⁘%'¹¹¹¹29&'¹¹¹¹¹B¹¹¹¹¹¹u¹¹¹B¹¹¹¹t%&'■■¹¹¹¹¹B¹¹¹¹■%'¹¹¹¹n%&'■■¹¹¹B¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹v%&=+,¹¹¹¹¹¹¹¹¹⁘\"&'■¹¹^o%9)+,`¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹^_%&&-R`¹¹¹¹¹¹¹¹⁘%!&$`¹^&%!&-R&`¹¹¹¹¹¹¹¹¹¹¹¹¹¹^_&V%9&&R&_`¹¹¹¹¹¹⁘%&&'&_&&%&",
  "m¹¹¹¹¹ABBB%&&&&&mm²¹a¹B¹¹¹59&&&&###++,B¹¹¹V5&&!&9&)&-RB¹¹¹&&%!39&&&&=RB¹¹¹&o54o%&&&&!RB¹¹¹V○█¹n%&&&&='B¹¹¹█¹t¹n%&&&39'B¹¹¹¹¹v¹~%&!4V%'B¹¹¹¹¹E¹¹%&'o&2'B¹¹¹¹¹¹¹¹Q&'&○V1B¹¹¹¹¹¹¹¹Q9'pv~1B¹¹¹¹¹¹¹¹Q&'█E¹8B¹¹¹¹¹■■■Q&'¹▮¹¹B¹¹¹■■*++)!4¹¹¹¹B¹¹¹*+=&-&R¹¹¹¹¹B¹¹¹Q)&&&&R¹¹¹¹¹\"#++-&&&&&R¹¹■■■%!&=&&&&&&R¹¹5##33339&&&&&R¹¹□24ABBB2!&&&&R¹¹¹□□B¹¹¹V2&&&&'m¹¹¹¹B¹¹¹&&%&&!'NME¹¹B¹¹¹&V%933'NNMP¹B¹¹¹&&2'Y_'¹¹O¹¹B¹¹¹o&&1^&'¹¹O¹¹B¹¹¹&o█1&o'¹¹¹¹¹B¹¹¹○○v8~█'■¹¹¹¹B¹¹¹¹t¹¹HI9,■■■¹B¹¹¹¹v¹¹X¹&-++$■B¹¹¹¹¹¹¹X¹&&&-!$B¹¹¹arswX¹&&&&&'B¹¹¹\"#####",
  "&&'&&%&&333&9&&&&9'&○%94¹v¹%333!&&'█¹24¹¹¹¹8¹¹¹%!34¹¹⁘ABBBBB¹¹¹%'HI¹¹⁘B¹¹¹¹¹¹E¹%'X¹¹¹¹¹¹(_`¹¹¹¹%'X¹¹²¹¹¹%$&`¹rs%'¹¹\"####9!#####9'__23333333&!&&&'&&○█¹t¹¹~○23&9&'○█¹¹¹u¹¹¹¹O¹%&&'Y¹¹¹¹¹¹■¹¹O]2!&'¹¹¹¹¹¹](¹MPm¹%&'w¹¹¹¹¹¹1NNNNN2!!#$¹¹¹¹¹1¹¹¹¹¹n%&&'¹¹「「¹1¹¹¹¹¹n%&&'■■¹¹¹1¹¹¹¹¹~%&&=+,■■■1¹「「¹¹¹%&&&&-+++'■■■■¹¹%&&&&&&=)!+++,AB%&&&&&&&&&)&-RB¹%&!339&&&!&&!'□□%94○&%&!333334¹¹%'v¹~%!'&○█t¹¹CD%'¹¹¹23'█¹¹t¹¹D¹%'ABB¹¹8CD¹u¹¹D¹%'B¹¹¹¹¹D¹¹¹¹¹¹¹%'B¹¹¹¹¹D¹¹¹¹¹¹¹%'B¹¹¹¹¹D¹¹¹¹¹¹a%'B¹¹■■¹¹¹¹¹¹¹]NQ'B¹¹\",■■■■¹¹¹¹¹%'¹¹¹%-+++,■■■■■Q'¹¹¹%&)=&=+++++)",
  [29] = "&&'¹¹¹¹%&&&&&&&&&&&&&&&&4&&&&&&&&&'¹²¹¹%&&3&&&&&&&&&3334&&V&&&&&&&'¹¹¹¹%&4□%&&&33334&&&&&&&&&○○○&&'¹¹¹¹%'□¹%&&4&&&&&&V&&&&&&█tt¹&&'¹¹¹¹%'¹¹%&'&&&&&&&&&&&&&█¹tt¹&&'¹¹¹¹24¹¹%&'V&&&&&&&&&&&p¹¹tt¹&&'¹¹¹¹tt¹¹2&'&&&&&&&&&&&Vp¹¹tt¹&&'¹¹¹¹ut¹¹¹%'&&&&V○○&&&&&p¹¹tt¹9&'¹¹¹¹¹t¹¹¹%4○○○&p¹tn&&&&█¹¹¹t¹&&',¹¹L¹u¹¹¹8□¹¹tnp¹un&&&paa¹¹v¹&&&-,¹\\¹¹¹¹¹□¹¹¹t~█¹¹n&V&pNMP¹¹¹33&&=$\\¹¹¹¹¹¹¹¹¹t¹¹¹¹n&&○█NP¹¹¹¹~o2333,`¹^`¹¹¹¹¹t¹¹¹¹n&p¹t¹¹¹¹¹¹¹n&○○oQ,¹np¹¹¹¹¹u¹¹¹¹n&p¹t¹¹¹¹¹¹■~█¹ᵇnQR^op¹¹¹¹¹¹¹¹¹¹n&█¹t¹¹¹¹¹¹$¹¹¹¹~Q),&V`¹¹¹¹¹¹¹¹¹~█¹¹t¹¹¹¹¹¹'ma¹¹*-=Ro&p¹¹¹¹¹¹¹¹¹¹U¹¹t¹¹¹¹¹¹4‖◀◀▶Q&&=,o&`¹¹¹¹¹¹¹¹¹^¹¹t¹¹¹¹¹¹¹¹¹¹¹Q=&&-+,p¹¹¹¹¹¹¹¹¹¹¹¹u¹¹¹¹¹¹`¹¹¹*))&&&&-,¹¹¹¹*+,¹¹¹¹¹¹¹¹¹¹¹¹$■■*-=&;-&&&-++++-=Rqa¹uq¹¹¹*+++=$‖▶%)RV:=9&&=)=-=&)++++++++--=)&'¹^%&R&o%!&&&&&&-&&=)=---))&&&&=R^N%9'o&%&!&&&&&&&&&&&&&&&&&&&&",
  [33] = "!&&&9&&&&&&&&&&&!&&&&3333&&9&&&&&&&&9&&&&&&&&4¹¹33&&&&&&&&33&&&&&&9&4tt~&%9&&!&&&&&&&&&&&&33&'¹¹¹¹2!&&&&&'&&2&&9&&&'¹tutn2333333&&!&&&&&&'¹t24¹¹¹¹¹%&&&&&4○○&%&&3334¹t¹vn&&&p¹¹%!33333&&&'¹tnp¹¹¹¹¹%9&&&'NMPn%!4¹a¹¹¹u¹¹n&o○█¹¹24¹¹~&&2333¹tnp¹¹¹¹¹%&3334NP¹~%'a¹mw¹¹¹¹^&&ptt¹¹¹¹¹¹¹n&p¹t¹¹vnp¹¹¹¹¹24tt¹t¹¹¹¹24NMNMP¹¹¹n&&p¹t¹¹¹¹¹¹¹n&█¹t¹¹¹np¹¹¹¹¹npvt¹t¹¹¹¹np¹O¹O¹¹¹¹n&&p¹v¹¹¹¹¹¹¹np¹¹v¹¹¹np¹¹¹¹¹np¹t¹v¹¹¹¹np¹O¹O¹¹¹¹nV&p¹¹¹¹¹¹¹¹¹np¹¹¹¹¹¹np¹¹¹¹¹np¹v¹¹¹¹¹¹np¹O¹O¹¹¹^&&hp¹¹¹¹¹¹¹¹¹np¹¹¹¹u¹np¹¹¹¹¹np¹¹¹¹¹¹¹¹np¹O¹O¹¹¹^w&i&`u¹¹¹¹¹¹^&\"$¹¹¹uunp¹¹¹²¹np¹¹¹¹¹¹¹¹np¹O¹O¹¹゛゜゜゜###$¹¹¹¹¹^o&%'¹¹uuun*++++,np¹¹¹¹ua¹¹np¹O¹O¹¹%&&&&&90‖◀◀▶*+,(24¹*++++-=)=)-+++,¹uumrsnp*++,‖▶%9&&&&&0¹¹¹¹Q-)++++-=)=-=&&&&&)=-R‖◀▶\"###+)-)Ru]%&&&&!&0■■■■Q=&=9)&&&&&&-&&&&&&&&R¹¹¹%&&99-&=RNN%&&&&&&9####9-&&&&&&&&&&&&&",
  [34] = "¹¹¹¹¹¹¹¹■%'&&&&&&%&'¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹\"&'&&&&o&%&4¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹%&'○o&&&&%'¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹%&'■n&&○○%'¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹2&&$~op¹¹24¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹%&'¹~█¹¹□□¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹%&4¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹*++¹¹¹¹¹¹¹¹¹24¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹^\\\\\\`¹¹¹¹Q=)¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹^n&o&&`¹¹¹Q-&¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹^\\_&&&&&&p¹\"$Q=&¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹nh&&&&&oa&`24:-&¹¹²¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹*+,q¹¹¹¹¹^aiwrsaa######$Q=+++,¹¹¹¹¹¹##$¹¹¹¹■■¹¹*)=)#$¹u¹¹n\"#####$2333334Q----R¹¹¹¹¹5%&'¹¹¹¹\"$¹¹Q-&&&&$uuan%9&&&!'*+++++=-&&&&-+,¹W¹\"9&),¹m¹24*+-&&&&&'uu*+-&&&9&'Q=--)-&&&&&&&--+++%&&&-+++++=-=&&&&&&++)-&&&&&&'Q&&&&&&&&",
  [36] = "⁸"
}

--@end
linked_levels=bt("10,12",split"3,2")
music_triggers=bt("12,13,28,31",
split([[-1,5000,0
38,0,7
-1,32000,7
0,0,7]],"\n"))
__gfx__
000000000000000000000000088888800000000000000000000000000000000000000000000000000300b0b00a0aa0a000000000000000000008000000077000
00000000088888800888888088888888088888800888880000000000088888800000000000000000003b33000aa88aa0000080000008008000000008007bb700
000000008888888888888888888ffff888888888888888800888888088f1ff180000000000000000028888200299992000080080080880080000000007bbb370
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff800000000000000000898888009a999900800008800098000080000807bbb3bb7
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff800000122021000000888898009999a9089088098000898008908808873b33bb7
0000000008fffff008fffff00033330008fffff00fffff8088fffff808333380000014442442100008898880099a999089899889088999880889989807333370
00000000003333000033330007000070073333000033337008f1ff10003333000012442211224210028888200299992080008008800880080000800000733700
00000000007007000070007000000000000007000000700007733370007007001244424442442421002882000029920000080000008900000088000000077000
888888886665666555888888888886664fff4fff4fff4fff4fff4fffd666666dd666666dd666066d0000000000000000700000000d6666660d666d6d066666d0
888888886765676566788888888777764444444444444444444444446dddddd56ddd5dd56dd50dd5007700000770070007000007dddd66661ddddddd1dd6666d
88888888677867786777788888888766000450000000000000054000666ddd55666d6d5556500555007770700777000000000000ddd6dddd1ddddddd11ddd66d
8878887887888788666888888888885500450000000000000000540066ddd5d5656505d5000000550777777007700000000000001dddddd1111ddd11111ddddd
887888788788878855888888888886660450000000000000000005406ddd5dd56dd506556500000007777770000070000000000001ddddd11111111111111ddd
867786778888888866788888888777764500000000000000000000546ddd6d656ddd7d656d500565077777700000077000000000d11111111111101111111110
5676567688888888677778888888876650000000000000000000000505ddd65005d5d65005505650070777000007077007000070dd1111110011011011111ddd
56665666888888886668888888888855000000000000000000000000000000000000000000000000000000007000000000000000dd111110000000000111ddd6
00000000ddd0ddd0ddddd5000ddd0ddddd555100000000000015555d0d5505d00cccccc0077777777777777777777770cc000000011111000000000000111d66
00000000d5515551555555111555155d55555100000000000000111155555155cccccccc7777777777677767777777771c00cc00dd111100000001000011d166
00555550d55155511111111111111110111100000000000001555dd0011111101ccccccc7677667777766677777777770000ccc06ddd1110011011100001ddd6
005ddd50555155505dddd1551555555d0dd55d100000000001555dd0dd55111d1cc1ccc17766677777776d676777677700001ccc66ddd110011011100001dddd
000ddd0055505d505ddd515515d55ddd0dd5551000000000015555d0dd5551dd1cc11c1077d67777dd77dcd7666677700cc01ccc66ddd110000001100001ddd6
000005550110011155555055110001100d5555100000000000001111d555515d111111007dcd667dccddcccd6d6777661ccc11c1dd6dd1100011000000111ddd
55500555d55555101111101100055ddd1111000000000000001555dd55555155011010007cccd66cccccccccccc66d661ccc0111dddd111001111100011111dd
55500000d5555510000000000015555ddd55510000000000001555dddd55515d000000007ccccccc0ccc00cccccd6dd611c00000ddd111000011100001111110
dd55515dd5555100000000000015555dddd15ddddddddd51ddd51ddd555551550000000077cccccc00cccccccccccc770ccc1000011111000000000000111d66
55555155d55551001100000000155ddddd51555555555551555515dd555551105500000077cccccccccccccccccccc771cc11000ddd11110000000001111dd66
01111110010001115500111011111110555111111111111111111555011111105505555067c7cccccccccccccccc7c671111000066dd1111111100111111ddd6
dd5111dd55505d51dd00555015d55ddd011111155111111151111110d551555d000555506ccccccccccccc6cccccccc60011cc1066dd11111111101111111ddd
dd5111dd55515551dd1155511555555d555551155155555151155555d5515555000000006ccccccccc6cccccccccccc6001cccc0dddd11111ddd111166611dd6
55511155d55155511111555111111110555551111155555111155555011155550555550066ccccc6cccccccc6ccccc660111cc106dddd11d666dd11ddd6611dd
01111110d5515551555155511555155ddd555155515d5551551555ddd55155dd055555006ccc66c6666ccc666c66ccc61c111100ddddd1d666ddd1dddddd11dd
5555515d0dd0ddd0dd50dd500ddd0dd0dddd505dd0dddd50d505dddd0d505dd000000000066666660666666666666660cc1000000dddd0ddddddd0ddddddd110
0000000000000000577777777777777788cccc8888cccc8888cccc881dddd15ddddd51dd00050000100600101111011115555555555555551500000055505500
00008000000b000077777777777777778c0000c88c0000c88c0000c8d555515555d55155000d00000d060d001111011115111111111111111500000011111000
00b00000000000007777ccccccccccccc00cc00cc00c100cc00cc00cd5555155555551550d0d0d00006760001111011115000000000000001500000000000000
0000000000000000777cc7ccccccccccc0c00c0cc010c10cc00cc00cd55511111111111100d6d000667776600000011115000000000000001500000000000000
0000b000080000b077ccc7ccccccccccc0cccc0cc01cc10cc00cc00c5551111111111111dd676dd0006760001110011115000000000000001500000000000000
0b0000000000000077c77777ccccccccc00cc00cc00c100cc00cc00c555111111111111100d6d0000d060d001110000015000000000000001500000000000000
00000080000b000077cc777ccccccccc8c0000c88c0000c88c0000c811111111111111110d0d0d00100600101110111115000000000000001500000000000000
000000000000000077ccc7cccccccccc88cccc8888cccc8888cccc88d551111111111111000d0000000000000000000015000000000000001500000000000000
7cccccccccccccc71111101100111010111101110000000015555551d5511111111cc11100000000000000001111111100555505111011101110110001101110
77ccccc0cccccc771111101101111010111101110001111050500505d551111111cccc1100000005000000001111111100001111111011101110110001101111
76ccccc0cccc77771111001101111010111101110001111051511515d55111111cc11cc100000505050000000001111000000000111011101110110001101111
667cccc000ccccc70000000100001010000000110000000051511515555111111cc11cc10000055d550000000000000000000000000011100000000000001111
6ccccccc0ccccc771100000001100000100000000111010051511515111111111cccccc10000555d555000001100011100000000111011100000000000000000
7cccccccccccc6771110111101101110110111110111010051511515d55111111cccccc100005556555000001110111100000000111011101110110000111111
7cccccccccccc6671110111101101110110111110000000051511515d551111111cccc1100005d565d5000000000111000000000111000001110110000111111
77cccccccccccc671110111101101110110111110000000051515515d5511111111cc11100005567655000000000000000000000111000000000000000111111
00000000000770000007700000077000000000000007700051515515155555515000000500dd6677766dd0001111011111155555000000001110000000000000
00000050000770000077770000700700707777070077770051510515500000055000000500000567650000001111011110151115100001001110000000011110
00000050007777007777777707000070777777770777777051511515500000055000000500000d060d0000000000011110151155111101101110111100011111
00500505007777000777777077777777777777777777777751511515500000055000000500000006000000001110011110151555111100100000111100111111
0505051d07777770077007707777777707777770777777775151151550000005500000050000000d000000001110000010155515000000000000111100100111
051d051507777770777777770777777007777770077777705151151550000005500000050000000d000000001110111110155115110011000000000000011011
0515051d777777770077770000777700077777700077770051511515500000055000000500000000000000001110111110151115111011110000000000111111
051d051d777777770007700000000000777777700007700055555555500000055000000500000000000000001110111111155555011001100000000000011111
000000000000000000000000000115000111111500011500000000000dd11dd1011111100d666660066d0d66666d0d660d6666d0011100000000000000000000
00000000000000000000000000010500001010100001050000011100111111d1dd1111ddd6d6666d66dd1ddddddd1ddd1dd6666d111100000001111000001111
000000000000000000000000000151000050505000015100001505101611111066d111d6ddddd66666dd11dddd1111dd1ddd666d111100000000111000001111
00000000000000000000000000005000005050500000500000150510d661116666d11dd60111ddddd6dd1111111111111ddddd6d111100000000000000001111
10000000055555555555555000011500005050500001100000150510dd6611d66dd11dd0d1111110ddd1111000000100011ddddd111101110000001111101111
100000000111111111111150000105000050505000050000001111111dd11ddd6dd111166ddd11d6dd11d6d0ddd0dd10111111dd111101110110100111101111
100000000001100000011000000151000010101000000000001010511ddd66d1ddd111dddddd1ddd0111ddd1ddd1ddd11dd11110111101110110111111101111
15000000000150000001500000005000011111150000000000101051011ddd100dd111dd0dd111d000111dd111111dd1ddd11100111101110110111111101111
dd5888888888881551888888888885dd85077777787888888887778888888058e3e3e3e3e3e3e3e2e25252e2e3e3e3e3e25252e2e3e3525252525252e2e3e3e3
d155d5d5ddddd556d55ddddd5d5d551d810777778788888888777888888870185252620101000000000003000000428352627484841302232323022323520252
5501111111115151151511111111105585077778788888888777888888878058e752e652f700d7d3e3e2e2f3f737d7e7d3e2e2f352e6d2e252e2e3e3f3e7e7e7
8510000000001505505100000000015881077787888888887778888888788018525282a2b20000000101030000014252836275d5f50003215731033737132323
8510ccc7777700c00700711ccccc01588507787888888887778888888788805800d752f6000000d752d2f2f600470057d7d3f2e6e752d2e3e3f30414f7000000
85071077777cc11c1c17cc711cccc05851078788888888777888888878888015525252521501010192a262d700432302526200d6f60073214431733737000057
850cc71077cc1cc17c71c777c100c058151078888888877788888887888801511727d6f700000000d6d2f2f70000000000d787f6a0d787005731140000000000
850cccc71011ccc1cc71777ccc7000585100888888887778888888788888001552525252c2a2a2a252826252e5f737425262d5e652f500000000003747004400
850ccc1cc710cc17ccc717ccc00770580000044000000d0550d0000006666600e1f1f60000000000d7d2f20000006700000077f7000087c60031140000001000
85011c1cccc7107ccccc71c0077cc058000564460000050110500000667776605252825283a3a3c3528362e7f700474283625252e6e745000000005700671727
850c711cccc111000ccc00077cc770580060024000666d666d6d660066666660e2f2f7000000000000d2f20414d1f10000310414141487d4f43114000000d1e1
850cc71cc11ccc10000071cccc7770580550024006dddddddddddd60611611605202a3c362111105c32333000000004202625552f73700000000000000432222
850cc77117ccc0000177cc1cc77770585aa50240dddddd5555dddddd6116116052f300000101010000d3f31400d2f20000311400000077000031140000c4d2e2
810c7c717cc11711171cc7c17777c01800000420dddd5d5dd5d5dddd16666610836211133300001333370000000000425262e7f7003700000000000000004283
8507c771cc017cc1cc717c7c1771105800000440dddddd5555dddddd06060600f23700310414142100d6f61111d2f24100311400000037000000d1f1d4f4d252
810c77c1017cccc1c11717ccc11cc01800000440dddddddddddddddd000000005262e5e7f7000000573700000000004252628537004700010101000000001352
85077c017ccccc111cc771c11c1cc05800000440dd555555555555dd00666000f23700311400002100d652f500d2f20000311400000037000000d2f20101d2e2
5107017ccccc11cc1c77771ccc1cc01500000440dddddddddddddddd061816000233f60000000000005700000000014283620047000000041414f5000000d613
15107ccccc11cccc11777c71ccc10151666666205dd5555d555d5ddd61181160f25700311400002100d75552e5d2f20000311400000057000000d2e2e1e1e252
5100cccc11cccccc1c17ccc71cc10015dddd6620dddddddddddddddd611888606252f7000000000000000000000092c3023300000000d5140000f6000000d655
dd5888888888881551888888888885dddd1166205ddd55d5d55dddd561111160f2000000370037000000d65252d2f20000311400000000000000d2e252525252
d155d5d5ddddd556d55ddddd5d5d551dd1115540dddddddddddddddd0611160062f60000000000243400000000000552620000000000d6555252e6f54400d7e6
55011111111151511515111111111055d11d6640ddd55555d5555ddd00666000f200000037f047000000d7e755d2f200d5e555e7e7f700000000d25252525252
85100000000015055051000000000158d11d6640dddddddddddddddd0000000062f70000000000340000000000004282620000000000d6e6525252f6000000d6
85108888888700700800888888870158d11d6640dd555555555555dd00000000f20000005700000000000000d7d2f2e5e6e7f700000000000000d2e252525252
85088888887777778788888888777058d11166405ddddddddddddddd00000000620000000101000000000001010142526200000000d55252555255f7000006d6
85088888877777787888888887778058dd11554055dddd5555ddddd500000000f2010000000000000000010101d2f2e7f7000000000000010101d2e252525252
85088888777777878888888877788058dd5d6620d55ddd5dd5dddd5d000000006200000092b2010000000092a2a202526210000012a2a2a2a2a2b20101011222
85088887777778788888888777888058005066205ddddd5555dddddd00000000e2f1010101010101010192a2a2e2f20101010101010101d1e1e1e25252525252
85088877777787888888887778888058005002205ddddddddddddddd000d5000152434340552b2000001010552c352526241611202c3c28252c2c32222220283
850887777778788888888777888880580005022055dd5dd55dddddd50005500052e2e1e1e1e1e1e1e1a2c3c25252e2e1e1a2a2a2a2a2e1e2e252525252525252
8508777777878888888877788888805800005240555dd5dddddd5d55000550001534000005c362000192a2822323230262000042525252525252525202525252
7700077077777700770007707700000077777700077777007777770077777700525252525252525252023337d6e61352f2e652d3e3e25252e2e3e3e3e3e3e3e2
77700770777777707700077077000000777777707777777077777770777777701500000005c26200432323330000004200000000000000000000000000000000
7777077077000000770707707700000077000000770000000077000077000000525252525252525283331137d7e7e742f255525552d3e3e3f255525252e652d3
ccccccc0cccc0000ccccccc0cc000000cccc0000ccccccc000cc0000cccc000015000000138362000000670000a0004200000000000000000000000000000000
cc0cccc0cc000000ccccccc0cc0000c0cc000000000000c000cc0000cc00000052835252525252526211005700172742f3e75252e7e7e7e68752e6e7e7e7e655
cc00ccc0cccccc00ccc0ccc0ccccccc0cccccc00ccccccc000cc0000cccccc006200000037132322222232000000004200000000000000000000000000000000
cc000cc0ccccccc0cc000cc0ccccccc0ccccccc00ccccc0000cc0000ccccccc0022323025252525262000000001222020037d7f7005700d78752f7010100d752
00000000000000000000000000000000000000000000000000000000000000006200440047d75213232333717171714200000000000000000000000000000000
000777777000777770000000500050005544402444444455000000000000000062111113835252026241515161428352004700370000000087f700a7c700f0d6
0007777777077000770000005505500011444244444444110000000000000000620000000000d7e7f700570000d5e54200000000000000000000000000000000
000770007707700077000000555550000044444444444400000000000000000062000011132323233300000000132352000000370004141487000004140000d7
000ccccccc00ccccc0000000555550000044242424244400000000000000000062000000000000000000000000d6524200000000000000000000000000000000
000cccccc00cc000cc000000655560000044222222244400000000000000000062c60000041400370000f0000057314201010047001400008700001400000000
cc0cc000000cc000cc000000565650000044222222244400000000000000000015010100000000000101000044d7524200000000000000000000000000000000
cc0cc0000000ccccc0000000556550000044422222444400000000000000000062d4f400140000470000000000003142b2b2010000000000770000d1f1010101
0000000000000000000000005606500000444422424444000000000500000000c2a2b20101000000041400000000d742000000000000000000000000d5e5f500
077777007700000077777700600060000044424222444400000000050000000062f40000140000000000010100003142c382b20000000000000000d2e2e1e1e1
777777707700000077777770000000000044422222444400000050010050000052c32353630000001400000000000042000000000000000000000000d652f600
7700077077000000770007700000000000442222242444000000550105500000620000c51400000000311232f500014252c2150000000000000000d252525252
dd000dd0dd000000dd000dd00000000000444444444444000000515d515000005262c600000000001400000000000042000000000000000000000000d652f600
dd000dd0dd0000d0dd000dd00000000000444204444442000051555d55515000620000001400010101014262f7001283c252150000000000000000d3e3e25252
ddddddd0ddddddd0ddddddd000000000004042004444420000551556551550000233d4f400000000140000000000014200000000000000000000d5e56052f600
0ddddd00ddddddd0dddddd0000000000002020002004200000155d565d551000620000001222320414144262d5d5425252521500000000000000000000d25252
00000000000000000000000000000000000000000000000000555567655550006257000000000000000000000000128300000000001232000000d652525252f5
07777700777007777770077777700000000005050000000011dd6677766dd110620000004283621400001333d5e6425252521501010000000000000000d3e3e3
77777770777707777777077777770000000005550000000000005567655000006200000000000000000000000000425200100000004283320000d652525252f6
77000000077000077000077000000000505005550000000000105d060d501000620610004252620000000414e5554202525282a2b2010000000000000000d6e6
ddddddd00dd0000dd0000dddd00000005050655560000000000010060010000062004400000101018500748484844252a2b2000012025282a2a2a2a2a2a2a2a2
000000d00dd0000dd0000dd00000000050500656000000000001000d000100006241516142026200a0d5140052e64252525252c252b21727000000000010d6e6
ddddddd0ddd0000dd0000dddddd0000056560565000000000000010d0100000062000017271222320101750000004202c2c2a2a2c2525252c2c3c2c282c2c382
0ddddd00dddd000dd0000ddddddd0000a060060600000000000000010000000062000000425262e5e5e614005552428352525252c282a2b241515161d1e1e1e1
0000000000000000000000000000000006066000600000000000000100000000522222222202528322222232000042525252c282525252525252c35252525252
__label__
000000000000000000100d060d001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000006760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000011dd6677766dd110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000006760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000100d060d001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000100600100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000001000d00010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000010d01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000d0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000d0d0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000d6d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000dd676dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000d6d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000d0d0d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100000000000000000
00000000000000001777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777710000000000000000
00000000000000017777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777771000000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110000000000000
0000001aaaa333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333310000000000000
00000001aaaa33333333333333333333333333333333333333333333333333333333333333333333333333333333300000300000000003333310000000000000
000000001aaaa3333333333333333333333333333333333333333333333333333333333333333333333333333333055444024444444550333310000000000000
0000000001aaaa3333333333333333333333333333333333333333333333333333333333333333333333bbb33333011444244444444110333310000000000000
00000000001aaaa33333333333333333333333333333333333333bb3b3b33bb33bb3bbb3bbb3bb33333333b33333300444444444444003333310000000000000
000000000001aaaa333333333333333333333333333333333333b333b3b3b3b3b3b33b33bb33b3b33333bbb33333330442424242444033333310000000000000
0000000000001aaaa33333333333333333333333333333333333b333bbb3bbb3bbb33b33b333bb333333b3333333330442222222444033333310000000000000
00000000000001aaaa33333333333333333333333333333333333bb3b3b3b3b3b3333b333bb3b3b33333bbb33333330442222222444033333310000000000000
000000000000001aaaa3333333333333333333333333333333333333333333333333333333333333333333333333330444222224444033333310000000000000
0000000000000011aaaa333333333333333333333333333333333333333333333333333333333333333333333333330444422424444033333310000000000000
000000000000001aaaa3333333333333333333333333333333333333333333333333333333333333333333333333330444242224444033333310000000000000
00000000000001aaaa33333333333333333333333333333333333333377373337733333337737773777377733333330444222224444033333310000000000000
0000000000001aaaa333333333333333333333333333333333333333737373337373333373333733373373333333330442222242444033333310000000000000
000000000001aaaa3333333333333333333333333333333333333333737373337373333377733733373377333333330444444444444033333310000000000000
00000000001aaaa33333333333333333333333333333333333333333737373337373333333733733373373333333330444204444442033333310000000000000
0000000001aaaa333333333333333333333333333333333333333333773377737773333377337773373377733333330404200444442033333310000000000000
000000001aaaa3333333333333333333333333333333333333333333333333333333333333333333333333333333330202030200420333333310000000000000
00000001aaaa33333333333333333333333333333333333333333333333333333333333333333333333333333333333030333033003333333310000000000000
0000001aaaa333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333310000000000000
00000001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777770770707777777777777777777777777777777777777777777777777777777777777777100000000000000
0000000000000017777777777777777777777777770300b0b0777777777777777777777777777777777777777777777777777777777777777100000000000000
000000000000001777777777777777777777777777703b3307777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777702888820777777777777700077707007700077777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777708988880777770707777707077077707707077777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777708888980777777077777707077077707700077777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777708898880777770707777707077077707707077777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777702888820777777777777700070777000700077777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777770288207777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777000077777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777770000077777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777706666607777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777066777660777777777777700077777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777066666660777770707777707077777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777061161160777777077777707077777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777061161160777770707777707077777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777016666610777777777777700077777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777706060607777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777770707077777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777000777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777770666077777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777706181607777777777777700070007777700070007777700070707777700070007777777100000000000000
00000000000000177777777777777777777777777061181160777770707777707070707707707070707707707070707777707077707777777100000000000000
00000000000000177777777777777777777777777061188860777777077777707070707777707070707777707070007777700077707777777100000000000000
00000000000000177777777777777777777777777061111160777770707777707070707707707070707707707077707777707077707777777100000000000000
00000000000000177777777777777777777777777706111607777777777777700070007777700070007777700077707707700077707777777100000000000000
00000000000000177777777777777777777777777770666077777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777000777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000010177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000001000177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000100177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
000000000100d0177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
00000000000006177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
000000011dd667177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777100000000000000
000000000000061d66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd66dd6100000000000000
000000000100d0166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000100166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000001000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000010166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000166666666666666666006060600060006000600060006666660066006000600060666000600060006606666666666666666100000000000000
00000000000000166666666666666660666060606060606606606660606666606660606000606060666066660660666606666666666666666100000000000000
00000000000000166666666666666660666000600060006606600660066666606660606060600060666006660660066606666666666666666100000000000000
00000000000011166666666666666660666060606060666606606660606666606660606060606660666066660660666666666666666666666100000000000000
00000000000000166666666666666666006060606060666606600060606666660060066060606660006000660660006606666666666666666100000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000166666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666100000000000000
00000000000000016666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666661000000000000000
00000000000000001666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666610000000000000000
00000000000070000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000002020202080808000000000000030303030303030306030303030303030303030303030303030303030303030303030300000000000000000000000604040404030306060606060000000006040606060404040404040604040000040606060604040404040404030303030303060606
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
00000000000000000000000000000000001010503a3a32323232323232323238252520261200001350282c25252525253825323232323232323232323220252526000000313232323232323232323238252538323220252525252026556d7f242625257e24202525252025252532323825265f00242525202532322538252525
00000000000000000000000000000000102935336d256e257e7e7e25556e25242525253312000013393a3c2c2825252532337e7f00737500404141256e31252526474848000000000000000058007324203233256e313220253832337e000024267e7f003132323232323232331111242026255f3132323233004e3132202525
00000000000000000000000000000000223b73006d25257f0000007d7e7e6e242538267f000000000073393a3a323825256f0000007400004100007d7e252425265700000044006c000000000000732426252525557e7e313233404100000024260000000040414141414141000000242526404141414141414d4f007d242525
00000000000000000000000000000000260073007d556f000000000044006d2420323300101010100075007300002425556f44000000000041000000447d243826575d5e5f00006c6c0060000000732426256e7e7f0000730000410000006024267601000041000000000000000000242526410000000000005f600000313232
0000000000000000000000000000000026007300006d6f000000343535352220266f7300404141410000007300002420256e5f00000000004100000000002425265e256e21222222351415162700732426557f00000000740000410000151624382222222222222222222222234f0024202641000000000000255e5f40414141
0000000000000000000000000000000026007500007d7f000000007300733138265b73004100000000000075001024252222222236007000410000000010242026552525242532330000440037007324266f00000000000000004100000000242525252025253825202525382600002425264100000000000055256e41000000
0000000000000000000000000000000026000015162123000000007300740024265b7400000000000000000000213825252032334d4d4c4d4100005f0021382526252525243300750000000073007324266f00000000760000004100000000242032323232323232322525252640412425265525256e25212222222341000000
00000000000000000000000000000000260000000024265d0000007400000024266f007000000000000000000031323825335f7300004e004100006f0024252526252555305f00000000000073747324267f00000021234f0000410000006c2426257e7f00111111112425252641002425252222223535323238252641000000
00000000000000000000000000000000260000000024266d5f00000000000024266f4d4c4f6c000000000010106d253726256f745c4d4e004100006f002432322625252530255e404141412122222238260000000024334d5d5e2123105c4d24267f0a00000000001324382526410024252520323325256f0024253823257f00
0000000000000000000000000b000000260000000031335d6f00000000000031267f4d4d4c4d4f0000000040416d5525336e7f0000005d5e410000555f305800337e7e6e3725254100000024202525252023141500306e537e7e24202b10102426000000101000001324252526410024252526404141414141242025267f0000
00000000000000b5000000005e5b5b00267601000000586d255f000000004748260000004e00000000000041006d25557e5f0000005d6e25410000256e3700000000007d6e256e4100000024382525252526000000377f00000031383c2a2a3c26101010292b1200132420323300002425252641000000000031322526000000
000000000000292a2a2b005d6e25255f3823141621235d256e6f006000005700330000004e00000000000041006d6e2500000000007d7e5541000025255f4748000100006d5625555f0000503c2525252526000000000000000073312c282525264041415051120013313375000000242538264100000000006e253133000000
2b0000000000502c2c2c2a2b0108006f2526005d24266d6e256f6c6c000057000000005d5b5e5f00000000006d555525000176717200007d4100006e256f575d222223006d666e256f6000502525252538265f00000000000000755f502c252526410000243b0000000000000000002425323341000000000055566f00000000
2c2a2b1416292c2525252c2c2222222a20265b6e2438222a2a2a2a2a2a22222200005225256e255e5200000f6d6e2525231416292b0000002122222a2a2a2a2a202538222a2a2a2a2a2a2a2c252525252526255f700000000000006e503c25252641000037730000000000000000002426007d6e252122222325666f76717200
2528510000502c252525252538252528382655252425382c3c252c28383825200060016d2525557f0000005d2525256e265f0050515f0000243825252c252c3c252525252c253c25282c3c252525252525202222237000000100600050252525260000000073000000000010101010242601006d552425252522222222222222
2525510000502c252525252525202525252625552420252525252525252525252222231415256f000000006d6e25552526255e50516e5f00242025252525252525252525252525252525252525252525252525203822231415162122282525252600000000740000005d56292a2a2a3c26141621222525202525252525252525
25252e3e3e3e3e3e3e3e2e2525253e3e2525252525252e2e2e3e3e3e2e2e2525252e252525252e3e3e2e252525252525000000000000000010242625252525252524252600000000000000000000000000006d6e25252525257f000000000000265f00000000005d5e2566502c25282525260000243825323220252525252525
253e3f7f00000073007d2d2e3e3f000025252e2e3e3e3e3e3f5525253d3e3e2e2e3e3e2e252e3f6e252d2525252525250000000000000000212526252525256e2524253300000000000000000000000000007d7e7e6e25256f73000000000000266f000010102122222222202525252538260000243233111124382532382525
2f7e7f00000f007400102d2f00000000252e3e3f6e252525557e256e7e7f733d3f55252d2e3f257e7e3d2e252525252500000000000000002425267e6e2525252524260000000000000000000000000000000073006d25256f7400000000000026255e5e21223820253825252525252532260000370000000031323311242025
2f10000000000000001d2e3f4f0000002e3f007d5525256e7f006d5f00007300006d6e2d2f556f00007d2d25252525250000000000000000242526106d25257e7e24260000000000000000000000000000000074006d256c6f000000000000003835365524252525252525252525252500370000730000000073007300242525
251f6c0000100000003d2f75000076002f1200007d55256f00006d5f60007300007d252d2f257f0f00002d2e252525250000000000000000312525237d6e6f000031330000000000000000000000000000000000006d6c6c6f0000000000000026756d2524252525252525203225252500750000731010100073007300312525
252f4d4d4c794f000073780000007a1e2f120000006d7e7f00006d555f00740010006d2d2f7f000000002d2e25252525000000000000000000242526007d7f0000111100000040414141414100000000000000132222222222230000000000002600343532252525202525331124252500000000734041410073007400002438
2e3f005c4d781000007578000f00132d2f12000f005b1010105d25256f00000079007d2d2f00000000002d2525252525000000000000000000242526000000000000000000004100000000000000000000000013313232323226404141292a2a260000000034203232323300003138251010000073410000007400000f002420
3f000000003d1f005d5e77000000132d2f1200005d25292a2b6d55256f0000007800003d3f00000000003d2e252525250000000000000000003132330000000000101000000041000000000000000000000000006d2525256e37410000503c2826607000000030257e7f0000001324252a2b1010731111110000000000002425
000000000013784f6d6f114b0000132d3f1200007d6e502c51256e7e7f000000785f000000000010006c002d2e3e2e2500000000000000404141414141410000002123000000002122222300000000000000005d6d252525256f410000502c25252223000000307f0000000000132425282c2a2b105b5b5f00101010005d2425
00000000001378006d7e537f0000132d00000000007d392e2f7d6f4243430010786e5e5f000000794d4c4d2d2f253d3e00000000000000410000000000000000003133000000003132323300000000005d5b5e2525252525256f410000503c2525202600005d300000001000001324252525252c2b7e25255b4041415b252425
010000000013785d7f0000000000132d000000000000132d3f006b43000000292f7e7e7f000010784d4d4d3d3f7e7f0000000000000000410000000000000000006d6f00000000292a2b00000000005d6e5625252525256e256f000000392c252525265e5e25304d4c4f2712000024252525252551007d7e7e41007e6e252420
1e1f00000013776f000000000000132d00000000000013780000004300005d502f14150000001d2f000000111100730000000100000000000034222223000000006d6f00000000502c5100000000006d60667671726c762525255f000000503c252526252525375c4d4d3012000024252525252851007373001111117d7e2425
2e2f4f0000007d7e000000000010102d0000000000001377000000005d5e7f2d2f00000010102d2f10000000000074002a2a2a2b000000000000242526000000006d6f0000292a282c3b00000000007d21222222222223252525255e5e5e502c25382625257e7f0000003012005d24252525252c260073740000000010102425
252f10101000000000000010101d1e2e0001000000000000000010006d7f10502f1010101d1e2e2e1f000000007671722c2c2c51000000000010242526000000006d6f0000502c3c510000000000000024382525252025232525252525292c25252526257f0000000000375d5e25242525252525261074740000000021223825
25251e1e1f1010101010101d1e2525251e1e1e1f10101010101079006b00292c251e1e1e2e2525252f101010101d1e1e2525252c2a2b005600213825282b006c006d6f292a2c25252c2b00000000292a2c252525382525282a2a2a2a2a3c25252538267f000000000000116d2525242025252525202374740000010024202525
2525252e2e1e1e1e1e1e1e252525252525252e2e1e2a2a1e2a2a5100000050252e252525252525252e1e1e1e1e252525252525252c2c2a2a2a242525252c2a2a2a2a2a3c2c3c2525252c2a2a2a2a282c25252525252525253c2c2c282c2525252525260000000000005c277e7e7e242525252525253822231415151624252525
__sfx__
110600080c5500c5500c5500c5520c5500c5500c5500c552000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010518201813018070180701807018050180501805018050180401804018040180401803018030180301803018020180201802018020180101801018010180101801018010180101801018010180101801018010
03040000180433d6703d6503d6403d6203d6103d6203d635000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400001807300150001500015000150001500015000150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040000180730c1500c1500c1500c1500c1500c1500c150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800080015000150001500015000150001500015000150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8919001015d1015d1215d1015d1115d2115d2015d2015d2215d2015d2015d2215d2115d1115d1015d1215d1000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d00
0134000015900189001c9002090024900289002d9003090015900189001c9002090024900289002d9003090000000000000000000000000000000000000000000000000000000000000000000000000000000000
03040000366352a6542b60027300376352a6541d30026300376352a654193000030000300003000030000300003000030000300003000c0000030000300003000c073306603e474306702f6502d6402b62029615
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
4d1800002d9302d92028920289102f9202f91030920309103091030910309103091500900009000090000900009000c1000090000900009000090000900009002c9202d9202f9302f9202f910289202891028915
030400000c073306603e4741867021670246442b6252d6002b6002960030600306003060030600306003060030600306003060030600306002460024600246001860018600186000c6000c600006000060000600
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
01100000070000a0000e0001000016000220002f0002f0002c0002c0002f0002f0002c0002c0002f0002f0002c000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
0102000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
0103000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
030200003d6133f65530654346413464134641356413564135611346213763137641376103761037620376203763037630396103962039630396103961039610396143b6143b6143b6143d6143d6003d6143b600
71050000371752b1502b1502b1402b1302b1202b1102b110331752715027150271402713027120271102711027110271102711027110271102711027110271102711027110271102711027110271102711027115
4b0300000c0733265432651326413164131631316313062130621306112f6112f6112f611236112361117611176110b6110b61500000000000000000000000000000000000000000000000000000000000000000
950c0000210021f0511d0611c0711a0711c00017000210002100009000150001005109071040710007100000000000405109061100711507100000000000000000000000000000015000180511a0711d07121071
4b0300003e62438625206263b62438625206262f62420626146162060023614146152060023614146152360014600206002060000000236001460017600086000000000000000000000000000000000000000000
0f02000414032180541f7713b6243862500100001000010000100001000010000100001000010000100001000010000100001000c0001f0000010000100001000010000100001000010000100001000010000000
190d002009760097400c7500c7301075010730147501473018850188301c8501c8302085020830248502483028850288301c8301c8202083020820248302482028830288201c8201c81020820208102482024810
190d002007760077400c7500c7301075010730137501373018850188301c8501c8301f8501f830248502483028850288301c8301c8201f8301f820248302482028830288201c8201c8101f8201f8102482024810
190d0020057600574009750097300c7500c7301075010730158501583018850188301c8501c8302185021830248502483018830188201c8301c8202183021820248302482018820188101c8201c8102182021810
190d0020047600474008750087300b7500b7301075010730148501483017850178301c8501c8302085020830238502383017830178201c8301c8202083020820238302382017820178101c8201c8102082020810
011a00001c9501c9501c9501c9501c9401c9301c9201c9101c9101c9101c9101c9101c9101c9101c9101a94018950189501895018950189401893018920189101891018910189101891018910189101891017940
011a0000159501595015950159501594015930159201591015910159101591015910159101591015910159101591015910159101591015910159101591015910159101591015910159151593017940189501a950
011a00001c9701c9701c9701c9701c9601c9601c9501c9401c9301c9201c9101c9151a6001a600186001896717970179701797017970179601795017940179301792017910159501594017970179601795018960
011a0000149501495014950149501494014930149201491014910149101491014910149101491014910149101491014910149101491014910149101491014910149101491014912149151490014900149001a900
011a00001095010950109501095010940109301092010910109101091010910109101091010910109101091010910109101091010910109101091010910109101091010910109121091514900149001596015950
010d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001593015920179301792018940189301a9401a930
011a00000900009000209302092020910149002093020930209202091521940219302191015900219402194021920219152395023940239201790023940239302392023915249402493024910189002493024920
011a000009000090001f9301f9201f910139001f9301f9301f9201f91521940219302191015900219402194021910219152395023940239201790023940239302392023915249402493024910189002493024920
030d00201505315d003d62415d001505321d003d62421d0018a7018a703d62415d003c62521d003d63421d003d620000003c6250000015053000003d6240000018a7018a7015053000003c625000003d62400000
030d002015b5015d5015d5015d5015c5021d5021d5021d5018a7018a7015d5015d5021d6021d6021d6021d6015d7015d7015d7015d7015c6021d6021d6021d6018a7018a7015b6015d6021d5021d5021d5021d50
030d002000000000003d6240000000000000003d6240000000000000003d624000003c62521d003d634000003d620000003c6250000000000000003d62400000000000000000000000003c625000003d62400000
030d002013b5013d5013d5013d5013c501fd501fd501fd5018a7018a7013d5013d501fd601fd601fd601fd6013d7013d7013d7013d7013c601fd601fd601fd6018a7018a7013b6013d601fd501fd501fd501fd50
030d002011b5011d5011d5011d5011c501dd501dd501dd5018a7018a7011d5011d501dd601dd601dd601dd6011d7011d7011d7011d7011c601dd601dd601dd6018a7018a7011b6011d601dd501dd501dd501dd50
030d002010b5010d5010d5010d5010c501cd501cd501cd5018a7018a7010d5010d501cd601cd601cd601cd6010d7010d7010d7010d7010c601cd601cd601cd6018a7018a7010b6010d601cd501cd501cd501cd50
03080020150731c9003f61515d003f62518a003f63015d003d6753d6053f6151a9003f625189003f63515b003f63514d003f61514d001505318a003f63015d003d67518a001507314d003f62518a003f6263f636
0920000015d7015d5015d7015d5015d7015d5415d7415d5414d7014d5014d7014d5014d7014d5414d7414d5413d7013d5013d7013d5013d7013d5413d7413d5412d7012d5012d7012d5012d7012b5013d6514d75
010800201c9601c9550000000000159301592518940189351a9401a9351893018925179301792515930159251c9501c9451800018000159301592518940189351a9401a935189301892517940179351595015945
0510000015d7021d7023d7024d7015d7021d7023d7024d7015d6021d6023d6024d6015d6021d6023d6024d6015d5021d5023d5024d5015d5021d5023d5024d5015d4021d4023d4024d4015d5021d5023d6024d60
011000002d8702d8502d8402d8352d860288502f840308502d830288202f810308202d820288102f810308102d815288152c8502d8502f8602f8552d8502c8402c8302c8252d8102c8102f8102f8152d8152c815
011000002b8702b8502b8402b8352b860268502d8402f8502b830268202d8102f8202b820268102d8102f8102b815268152a8502b8502d8602d8552b8502a8402a8302a8252b8102a81028870288502884228835
011000002d8702d8502d8402d8352d860288502f840308502d830288202f810308202d820288102f810308102d815288152f850308503286032855308502f8402f8302f8252f810308103281032815308152f815
031000002d8702d8502d8402d8352d860288502f840308502d830288202f810308202d820288102f810308102d81528815308503285034860348553285030840308303082530810308153f6143f6113f6213f631
0120000009560095410954109551095510954109541095310b5600b5410b5410b5510b5510b5410b5410b5310c5600c5410c5410c5510c5510c541095500c5400e5600e5410e5410e5510e5510e5410e5410e531
012000002d8702d8502d8522d8452d860288502f84030860308503085030840308403084030835308603285534861348503284030850308503084230840308303082030810000000000030800308002f8502f857
112000002d8702d8502d8522d8452d860288502f84030860308503085030840308403084030835308603285533861338503284030850308503084532815308572f8702f8502f8402f8402f8322f8202f8152d745
11200000347423472534712347152d860288502f8403086032757307152f7202f715308402d745307453275534861348503284030850308503084230840308303082030810000000000030800308002f8502d745
11200000347423472534712347152d860288502f8403086032757308302f7352f715308402d745307453275533861338503284030850308503084532815308572f8702f8502f8402f8402f8302f8302f8202f810
03080020150731c9003f60015d003f6143f6203f6203f6003d6753d6053f6001a9003f600189003f60015b001501314d003f60014d001505318a003f60015d003d67518a001507314d003f636246263f6003f600
070500001507339655150701c0502106021040210202101015d1415d1015d1015d1015d1015d1015d1015d1015d2015d2015d2015d2015d3015d3015d3015d3015d2015d2015d2015d2015d1015d1015d1015d15
07020000180532d0522d0353f6103e6253c6153c6003c6003c6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 1d424344
00 1d424344
00 1e424344
00 1e424344
00 1f424344
00 1f424344
00 20424344
00 20264344
00 1d214344
00 1e224344
00 1f214344
00 20244344
00 1d274344
00 1e284344
00 1f274344
02 20274344
03 06424344
01 1d232944
00 1e252944
00 1f232944
00 20252944
00 1d232a2b
00 1e252c2b
00 1f232d2b
00 20252e2b
00 1d272a2b
00 1e282c2b
00 1f272d2b
00 20272e2b
00 1d272a2b
00 1e282c2b
00 1f272d2b
00 20272e2b
00 1d272944
00 1e282944
00 1f272944
02 20272944
00 41424344
01 3c303144
00 2f303144
00 2f323331
00 2f323431
00 2f323331
00 2f323431
00 2f323331
00 2f323431
00 2f323531
00 2f323631
00 3c373144
00 2f373144
00 2f303831
00 2f303931
00 2f303a31
00 2f303b31
00 2f323331
00 2f323431
00 2f323331
00 2f323431
00 2f323331
00 2f323431
00 2f323531
00 2f323631
00 3c373144
02 2f373144

