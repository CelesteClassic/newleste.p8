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


local _g=_ENV --for writing to global vars

-- [entry point]

function _init()
  max_djump,deaths,frames,seconds,minutes,time_ticking,berry_count=1,0,0,0,0,true,0
  music(0,0,7)
  load_level(1)
end


-- [effects]

--[[clouds={}
for i=0,16 do
  add(clouds,{
    x=rnd"128",
    y=rnd"128",
    spd=1+rnd"4",
    w=32+rnd"32"
  })
end]]

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

--<stars>--
stars={}
for i=0,15 do
  add(stars,{
    x=rnd"128",
    y=rnd"128",
    off=rnd(),
    spdy=rnd"0.75"+0.5,
    size=rnd{1,2}
  })
end
stars_falling=true
--</stars>--


-- [player entity]

player={
  init=function(_ENV)
    djump, hitbox, collides,layer = max_djump, rectangle(1,3,6,5), true,2

    --<fruitrain>--
    -- ^ refers to setting berry_timer and berry_count to 0
    foreach(split"grace,jbuffer,dash_time,dash_effect_time,dash_target_x,dash_target_y,dash_accel_x,dash_accel_y,spr_off,berry_timer,berry_count", function(var)
      _ENV[var]=0
    end)
    create_hair(_ENV)
    dream_particles={}

  end,
  update=function(_ENV)
    if pause_player then
      return
    end

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
        add(dream_particles,{ -- afterimage particles
          x=x,
          y=y,
          dx=spd.x/8,
          dy=spd.y/8,
          t=10,
          type=2
        })
      end
      add(dream_particles,{ -- trail particles
        x=x+4,
        y=y+4,
        dx=rnd"0.5"-0.25,
        dy=rnd"0.5"-0.25,
        t=7,
        type=1
      })
      if not check(dream_block,0,0) then
        -- back to drawing behing dream block
        layer,init_smoke,spd,dash_time,dash_effect_time,dreaming=2,_init_smoke,vector(mid(dash_target_x,-2,2),mid(dash_target_y,-2,2)),0,0--,false
        if spd.x~=0 then
          grace=4
        end
      end
    end
    -- </dream_block> --

    -- horizontal input
    local h_input=split"0,-1,1,1"[btn()%4+1]

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
    -- <dream_block> --
    draw_dreams(_ENV,1,12)
    if not dreaming then
      pal(8,djump==1 and 8 or 12)
      draw_hair(_ENV)
      draw_obj_sprite(_ENV)
      pal()
    end
  end
}

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
    --TODO: optimize more
    for i=0,15 do
      pal(i,clight)
    end
    draw_obj_sprite(_ENV)
    local gfx = split"98,98,98, 99,99,99, 100, 101,101,101"
    local sprite = gfx[dream_time%#gfx+1]
    local sx, sy = sprite % 16 * 8,sprite \ 16 * 8
    local cs = {clight,clight,cdark,cdark,clight,cdark}--[0]=7
    local c = cs[dream_time%#cs] or 7
    local size = split"0,5"[dream_time] or rnd()<0.4 and 4 or 0
    local w = 2
    if dream_time<3 then
      w,sprite=4,97
    end
    pal(7,c)
    sspr(sx, sy, 8, 8, x-w, y-size/2, 8+w*2, 8+size) -- draw flickering sprite
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

badeline={
  init=function(_ENV)
    for o in all(objects) do
      if (o.type==player_spawn or o.type==badeline) and not o.tracked then
        bade_track(_ENV,o)
        break
      end
    end
    states,timer={},0
    --TODO: rn hitbox is 8x8, need to test if a hitbox matching the player obj is more fitting
  end,
  update=function(_ENV)
    if tracking.type==player_spawn then
      --search for player to replace player spawn
      foreach(objects, function(o)
        if o.type==player then
          bade_track(_ENV,o)
        end
      end)
    elseif tracking.type==badeline and tracking.timer<30 then
      return
    end
    if timer<70 then
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
      add(states,{x,y,flip.x,sprite or 1,curr_smokes,dreaming,dream_time,dream_particles_copy,layer})
    end

    if #states>=30 then
      x,y,flip.x,sprite,curr_smokes,dreaming,dream_time,dream_particles,layer=unpack(deli(states,1))
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
    if hit and timer>=70 then
      kill_player(hit)
    end
  end,
  draw=function(_ENV)
    if timer>=30 then
      draw_dreams(_ENV,2,8)
      if not dreaming then
        pal(split"8,2,1,4,5,6,5,2,9,10,11,8,13,14,6")
        draw_hair(_ENV)
        draw_obj_sprite(_ENV)
        pal()
      end
    end
  end
}
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

fall_plat={
  init=function(_ENV)
    resize_rect_obj(_ENV,67,67)
    collides,solid_obj,timer=true,true,0
  end,
  update=function(_ENV)
    --states:
    -- nil - before activation
    -- 0 - shaking
    -- 1 - falling
    -- 2 - done
    if not state and check(player,0,-1) then
      -- shake
      state,timer = 0,10
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
        end
        timer=6
      end
      spd.y=appr(spd.y,4,0.4)
    end
  end,
  draw=function(_ENV)
    local x,y=x,y
    if timer>0 then
      x+=rnd(2)-1
      y+=rnd(2)-1
    end
    local r,d=hitbox.w-8,hitbox.h-8
    --[[for i in all{x,r} do
      for j in all{y,d} do
        spr(41+(i==x and 0 or 2) + (j==y and 0 or 16),i,j)
      end
    end
    for i=x+8,r-8,8 do
      spr(42,i,y)
      spr(58,i,d)
    end
    for i=y+8,d-8,8 do
      spr(80,x,i)
      spr(81,r,i)
    end
    palt(0,false)
    for i=x+8,r-8,8 do
      for j=y+8,d-8,8 do
        if i==x+8 or i==r-8 or j==y+8 or j==d-8 then
          spr((i+j-x-y)%16==0 and 44 or 60,i,j)
        else
          spr(46,i,j)
        end
      end
    end
    palt(0,true)]]

    --can probably be optimized slightly farther
    local sprites=split"37,80,81,?,42,41,43,42,58,57,59,58,?,80,81,?"
    for i=0,r,8 do
      for j=0,d,8 do
        local typ=(i==0 and 1 or i==r and 2 or (i==8 or i==r-8) and 3 or 0) + (j==0 and 4 or j==d and 8 or (j==8 or j==d-8) and 12 or 0) + 1
        palt(0,(i==0 or i==r) and (j==0 or j==d))
        spr(tonum(sprites[typ]) or (i+j)%16==0 and 44 or 60,i+x,j+y)
      end
    end
    palt()
  end

}
-- <touch_switch> --
touch_switch={
  init=function(_ENV)
    off=2
  end,
  update=function(_ENV)
    if not collected and player_here() then
      collected=true
      controller.missing-=1
      init_smoke()
    end
    off+=collected and 0.5 or 0.2
    off%=4
  end,
  draw=function(_ENV)
    --set color 8 as transparent
    palt(0x0a0)
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
}
switch_block={
  init=function(_ENV)
    solid_obj=true
    resize_rect_obj(_ENV,72,87)
    delay,end_delay=0,0
  end,
  end_init=function(_ENV)
    switches={}
    for o in all(objects) do
      if o.type==touch_switch then
        add(switches,o)
        o.controller=_ENV
      elseif o.sprite==88 then
        target=vector(o.x,o.y)
        destroy_object(o)
        dirx,diry=sign(o.x-x),sign(o.y-y)
        distx,disty=abs(o.x-x),abs(o.y-y)
      end
    end
    missing=#switches
  end,
  update=function(_ENV)
    if missing==0 and not active then
      active=true
      for s in all(switches) do
        s.init_smoke()
        s.init_smoke()
      end
      delay=20
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
      local cx=min(abs(dx)+1,distx/4)/8
      local cy=min(abs(dy)+1,disty/4)/8
      --local c=clamp(abs(dx),abs(dy),16)/8
      --c=c==0.125 and 0.25 or c
      spd=vector(cx*sign(dx),cy*sign(dy))
      if dx==0 and dy==0 and not done then
        end_delay=5
        done=true
      end

    end
  end,
  draw=function(_ENV)
    --TODO: put this into a function to save tokens with fall_plat
    local x,y=x,y
    if delay>3 then
      x+=rnd(2)-1
      y+=rnd(2)-1
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
}

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
    local x_=x+10+flr(rnd"6")
    while x_<right-4 do
      add(seg,{x_,rnd"3"+2,rnd"3"+2})
      x_+=flr(rnd"6")+6
    end

    seg[ seg[#seg][1]>right-8 and #seg or #seg+1 ] = {right - 4}
    add(seg,{right})
    add(segs,seg)
  end
  return segs
end

function draw_outline(_ENV, x,right,draw_y,ysegs,transpose,outline_color)
  for t,i in ipairs{x,right} do
    -- line(x+1, i, right()-1,i)


    local segs=ysegs[t]
    local dir= split"-1,1"[t]
    for idx=1,#segs-1 do
      ly,ry=segs[idx][1],segs[idx+1][1]
      if ry<draw_y or ly>=draw_y+129 then goto continue end
      local lx,rx=i+dir*calc_seg(segs[idx]), i+dir*calc_seg(segs[idx+1])
      local m=(rx-lx)/(ry-ly)
      local px_=lx
      for j=ly,ry do
        px_+=m
        local px=round(px_)
        if transpose then
          rectfill(j,px,j,i,0)
          px,j=j,px
        else
          rectfill(px,j,i,j,0)
        end
        if #disp_shapes==0 then
          pset(px,j,outline_color)
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

dream_blocks_active=true
dream_block={
  init=function(_ENV)
    layer=3
    resize_rect_obj(_ENV,65,65)
    kill_timer=0
    particles={}
    for i=1,hitbox.w*hitbox.h/32 do
      add(particles,
      {x=rnd(hitbox.w-1)+x,
      y=rnd(hitbox.h-1)+y,
      z=rnd(),
      c=split"3, 8, 9, 10, 12, 14"[flr(rnd(6))+1],
      s=rnd(),
      t=flr(rnd(10))})
    end
    dtimer=1
    disp_shapes={min_x=10000,max_x=-10000, min_y=10000, max_y=-10000}
    outline=false
    xsegs=build_segs(x,right())
    ysegs=build_segs(y,bottom())
  end,
  update=function(_ENV)
    --[[hitbox.w+=2
    hitbox.h+=2]]
    local hit=player_here()
    if hit then
      -- set the player as _ENV temporarily, to save a lot of tokens
      local _ENV,this=hit,_ENV
      dash_effect_time=10
      dash_time=2

      local magnitude=(dash_target_y==0 or dash_target_x==0) and 2.5 or 2
      dash_target_x,dash_target_y=sign(dash_target_x)*magnitude,sign(dash_target_y)*magnitude
      if not dreaming then
        spd=vector(dash_target_x*(dash_target_y==0 and 2.5  or 1.7678),dash_target_y*(dash_target_x==0 and 2.5 or 1.7678))
        dream_time=0
        dreaming=true
        _init_smoke, init_smoke=init_smoke, function() end
      end

      --corner correction
      if abs(spd.x)<abs(dash_target_x) or abs(spd.y)<abs(dash_target_y) then
        move(dash_target_x,dash_target_y,0)
        if is_solid(dash_target_x,dash_target_y) then
          kill_player(hit)
        end
      end

      djump=max_djump
      layer=3 -- draw player in front of dream blocks while inside
      if this.dtimer>0 then
        this.dtimer-=1
        if this.dtimer==0 then
          this.dtimer=4
          create_disp_shape(this.disp_shapes, x+4, y+4)
        end
      end
    else
      dtimer=1
    end
    --[[hitbox.w-=2
    hitbox.h-=2]]--
    update_disp_shapes(disp_shapes)

    foreach(particles, function(p)
      if dream_blocks_active then
        p.t=(p.t+1)%16
      end
    end)
  end,
  draw=function(_ENV)
    rectfill(x+1,y+1,right()-1,bottom()-1,0)

    if not dream_blocks_active then
      pal(split"1,2,5,4,5,6,7,5,6,6,11,13,13,13,15")
    end
    local big_particles={}
    foreach(particles, function(p)
      local px,py = (p.x+cam_x*p.z-65)%(hitbox.w-2)+1+x, (p.y+cam_y*p.z-65)%(hitbox.h-2)+1+y
      local d,dx,dy,ds=displace(disp_shapes, px,py)
      d=max((6-d), 0)
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
      -- line(px-1,py,px+1,py,pc)
      -- line(px,py-1,px,py+1,pc)
      -- draw a + in the right location using some trickery
      palt(0b1111111011111111)
      pal(7,pc)
      spr(74,px-3,py-3)
    end)
    pal()

    -- draw outline pixel by pixel
    -- divide into segments of 8 pixels
    -- at the boundaries of each segment, set the position to be a sum of sines
    -- lerp between the boundaries
    -- fill the dream block in
    --
    --

    -- local minx,maxx,miny,maxy
    -- if #disp_shapes!=0 then
    --   local first,last=disp_shapes[1],disp_shapes[#disp_shapes]
    --   minx=min(first.pos.x-first.r-4,last.pos.x-last.r-4)
    --   maxx=max(first.pos.x+first.r+4,last.pos.x+last.r+4)
    --   miny=min(first.pos.y-first.r-4,last.pos.y-last.r-4)
    --   maxy=max(first.pos.y+first.r+4,last.pos.y+last.r+4)
    -- end

    local outline_color = dream_blocks_active and 7 or 5
    draw_outline(_ENV,x,right(),draw_y,ysegs,false,outline_color)
    draw_outline(_ENV,y,bottom(),draw_x,xsegs,true,outline_color)


    for i in all{x+1,right()-1} do
      for j in all{y+1,bottom()-1} do
        pset(i,j,outline_color)
      end
    end
  end
}

phone_booth={
  init=function(_ENV)
    hitbox.h=16
  end,
  update=function(_ENV)
    if not done and player_here() then
      _g.co_trans=cocreate(circ_transition)
      done=true
    end
  end,
  draw=function(_ENV)
    rectfill(x,y,x+7,y+15,2)
  end
}


function create_disp_shape(tbl,x,y)
  add(tbl, {x,y,0}) --x,y,r
end

function update_disp_shapes(tbl)
  tbl.min_x,tbl.max_x,tbl.min_y,tbl.max_y=10000,-10000,10000,-10000
  for i in all(tbl) do
    x,y=unpack(i)
    i[3]+=2
    if i[3] >= 15 then
      del(tbl, i)
    end
    tbl.min_x,tbl.max_x,tbl.min_y,tbl.max_y=min(tbl.min_x,x), max(tbl.max_x, x), min(tbl.min_y, y), max(tbl.max_y,y)
  end
end

function displace(tbl, px,py)
  local d,ds,pox,poy,s = 10000,0,0,0,0
  if px>=tbl.min_x-20 and px<=tbl.max_x+20 and  py>=tbl.min_y-20 and py<=tbl.max_y+20 then
    for i in all(tbl) do
      local ox,oy,r=unpack(i)
      if abs(px-ox)+abs(py-oy)<=20 then
        --cpu optimization - if the manhatten distance is far enough, we don't care anyway
        local td,ts,tpox,tpoy = sdf_circ(px,py, ox,oy,r)
        if td<d then
          d,ds,pox,poy,s=td,ts,tpox,tpoy,r
        end
      end
    end
  end
  if d>10 then
    return d,0,0,0
  end
  local gx, gy = sdg_circ(pox,poy, ds, s)
  return d,gx,gy,(15-s)/15
end

function sdg_circ(pox,poy, d, r)
  local s=sign(d-r)/d
  return s*pox, s*poy
end

function sdf_circ(px,py, ox, oy, r)
  local pox,poy = px-ox,py-oy
  local d = vec_len(pox,poy)
  return abs(d-r), d, pox,poy
end
--</dream_block>--

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
66,fall_plat
68,touch_switch
71,switch_block
88,switch_target
64,dream_block
6,phone_booth
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
  --delay_restart=15
  -- <transition> --
  co_trans=cocreate(transition)
  -- </transition> --
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
  --<badeline>--
  bad_num=tbl[6] or 0
  --</badeline>--

  local exits=tonum(tbl[5]) or 0b0001

  -- exit_top,exit_right,exit_bottom,exit_left=exits&1!=0,exits&2!=0,exits&4!=0, exits&8!=0
  for i,v in inext,split"exit_top,exit_right,exit_bottom,exit_left" do
    _ENV[v]=exits&(0.5<<i)~=0
  end


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
  --<badeline>--
  for i=1,bad_num do
    init_object(badeline,0,0)
  end
  --</badeline>--
  foreach(objects,function(_ENV)
    (type.end_init or time)(_ENV)

  end)

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
  camera(draw_x,draw_y)

  -- draw bg color
  cls()

  --<stars>--
  -- bg stars effect
  for dy=stars_falling and -4 or 0,0 do
    foreach(stars, function(c)
      local x=c.x+draw_x
      local y=c.y+draw_y
      local s=flr(sin(c.off)*2)
      local _y = y+dy
      local _s = _y<y and s-1 or s
      if _y~=y then
        pal(split"1,2,3,4,5,1,1,8,9,10,11,12,1")
      elseif stars_falling then
        pal(split"1,2,3,4,5,12,6,8,9,10,11,12,12")
      end
      if c.size==2 then
        if _s<=-2 then
          pset(x,_y,stars_falling and (_y==y and 12 or 1) or 7)
        elseif _s==-1 then
          spr(73,x-3,_y-3)
        elseif _s==0 then
          line(x-5,_y,x+5,_y,13)
          line(x,_y-5,x,_y+5,13)
          spr(74,x-3,_y-3)
        else
          sspr(72,40,16,16,x-7,_y-7)
        end
      else
        if _s<=-2 then
          pset(x,_y,stars_falling and (_y==y and 12 or 1) or 7)
        elseif _s==-1 then
          line(x-1,_y-1,x+1,_y+1,13)
          line(x-1,_y+1,x+1,_y-1,13)
        else
          line(x-2,_y-2,x+2,_y+2,13)
          line(x-2,_y+2,x+2,_y-2,13)
        end
      end
      if dy==0 then
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
          pal()
        end
      end
    end)
  end
  --</stars>--

  -- bg clouds effect
  --[[foreach(clouds,function(c)
    x+=spd-_g.cam_spdx
    _g.rectfill(x+_g.draw_x,y+_g.draw_y,x+w+_g.draw_x,y+16-w*0.1875+_g.draw_y,1)
    if x>128 then
      x,y=-w,_g.rnd"120"
    end
  end)]]

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
  palt(0,false)
  palt(8,true)
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
  palt()

  -- draw objects
  foreach(layers,function(l)
    foreach(l,draw_object)
  end)

  -- draw platforms
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,8)
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

--<dream_block>

function vec_len(x,y)
  local ang=atan2(x,y)
  return x*cos(ang)+y*sin(ang)
end

--</dream_block>

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
  local n=0
  for x=0,7 do
    for y=0,7 do
      c={}
      c.pos = vector((x - 0.8 + rnd(0.6)) * 20, (y - 0.8 + rnd(0.6)) * 20)
      c.delay = rnd(1.5) + (wipein and (6 - x) or x)
      c.radius = (wipein and (2 * (15 - c.delay)) or 0)
      circles[n]=c
      n+=1
    end
  end

  for t=1,15 do
    camera()
    for i=0,#circles do
      if not wipein then
        circles[i].delay -= 1
        if circles[i].delay <= 0 then
          circles[i].radius += 2
        end
      elseif circles[i].radius > 0 then
        circles[i].radius -= 2
      else
        circles[i].radius = 0
      end
    end

    for i=0,#circles do
      if (circles[i].radius>0) circfill(circles[i].pos.x, circles[i].pos.y, circles[i].radius, 0)
    end
    yield()
  end

  if not wipein then
    delay_restart=1
    for t=1,3 do
      cls(0)
      yield()
    end

    co_trans=cocreate(transition)
    coresume(co_trans, true)
  end
end
-- </transition> --
-- <circ_transition>--

function circ_transition()
  local p
  for o in all(objects) do
    if o.type==player then
      p=o
    end
  end
  p.spd=vector(0,0)
  pause_player=true

  radii=split"128,120,112,104,96,88,80,72,64,56,48,40,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,28,24,20,16,12,8,4,0,0,0,0,0,0,4,8,12,16,20,24,28,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,40,48,56,64,72,80,88,96,104,112,120,128"
  s=""
  for i,r in ipairs(radii) do
    if i==42 then
      stars_falling=false
      next_level()
      pause_player=false
      for o in all(objects) do
        if o.type==player_spawn then
          p=vector(o.x,o.target)
        end
      end
    end
    inv_circle(p.x+4,p.y+4,r)
    yield()
  end
end

function inv_circle(circle_x, circle_y, circle_r)

  color(0)
  rectfill(-1, -1, 128, circle_y - circle_r)
  rectfill(-1, circle_y + circle_r, 128, 128)
  rectfill(-1, -1, circle_x - circle_r, 128)
  rectfill(circle_x + circle_r, -1, 128, 128)

  local circle_r_max = circle_r*sqrt(2)+1

  for i=circle_r,circle_r_max do
    circ(circle_x, circle_y, i)
    circ(circle_x+1, circle_y, i)
    circ(circle_x, circle_y+1, i)
    circ(circle_x+1, circle_y+1, i)
  end
end
-- </circ_transition>--
-->8
--[map metadata]

--@conf
--[[
composite_shapes={}
autotiles={{52, 54, 53, 39, 33, 35, 34, 55, 49, 51, 50, 48, 36, 38, 37, 32, 29, 30, 31, 41, 42, 43, nil, nil, nil, nil, nil, 56, 45, 46, 47, 80, 44, 81, [41] = 61, [42] = 62, [43] = 63, [0] = 48, [44] = 57, [45] = 58, [46] = 59, [56] = 40, [57] = 60}, {122, 124, 123, 121, 29, 31, 30, 119, 61, 63, 62, 120, 45, 47, 46, 48, 52, 53, 54, 32, 41, 42, 43, nil, nil, nil, nil, 39, 33, 34, 35, 56, 80, 44, 81, nil, nil, nil, nil, 48, 36, 37, 38, [45] = 57, [46] = 58, [47] = 59, [52] = 55, [53] = 49, [0] = 29, [54] = 50, [55] = 51, [57] = 40, [58] = 60}, {41, 43, 42, 41, 41, 43, 42, 57, 57, 59, 58, 80, 80, 81, 44, 44, 48, 52, 53, 54, 32, 56, nil, nil, nil, nil, nil, 60, 39, 33, 34, 35, 29, 30, 31, nil, nil, nil, nil, 40, 48, 36, 37, 38, 45, 46, 47, [53] = 49, [54] = 49, [55] = 50, [0] = 41, [56] = 51, [57] = 61, [58] = 62, [59] = 63}}
param_names={"badeline num", "comment"}
]]
--@begin
--level table
--"x,y,w,h,exit_dirs,badeline num"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
levels={
  "-3.5,2.9375,3,1,0b0100,0,spikes on ground need fixed or sparky's going to have a meltdown (g: maybe fixed?) ; need to figure out what's gonna happen to the berry if doing level duplication stuff",
  "0.3125,-2.0625,1.1875,2,0b0010,0,built for branching paths, reworked!",
  "-1.25,1,1.25,1,0b0010,0,0",
  "0,1,1,1,0b0010,0,perhaps shorten middle right wall by 1px to make it slightly easier",
  "1,1,2,1,0b0010,0,my old notes said needs tweaking (terrain/spacing), but it seems fine",
  "1.75,-1.875,1.3125,1.5,0b1000,0,mirror room- needs mirror; terrain should be made more \"cavernous\",need to fix player spawn in cam trigger",
  "1.5625,4.3125,1.4375,1.3125,0b1000,0,0",
  "0,3,2,1,0b1001,0,the first half could maybe be slightly tweaked",
  "3.375,4.375,1.1875,2,0b1000,0,built for branching paths, reworked!",
  "5,2,1,1,0b0001,0,should you be able to land on the left dreamblock?; diag (instead of wj updash) is currently an option, but it might be fine",
  "-3.5,4,3,1,0b0001,0,spikes on ground need fixed or sparky's going to have a meltdown (g: maybe fixed?) ; need to figure out what's gonna happen to the berry if doing level duplication stuff",
  "7,0,1,1,0b0001,0,works with or without badeline",
  "5,0,1,1,0b0001,1,0",
  "2,3,1,1,0b0001,1,0",
  "5.9375,-4.1875,1,1.4375,0b0001,2,terrain is a bit weird?; especially given where it is in the progression",
  "1,0,1,1,0b0010,1,0",
  "2,0,1,1,0b0001,2,0",
  "3,0,1,1,0b0010,1,0",
  "4,0,1,1,0b0001,2,0",
  "7,1,1,1,0b0001,3,difficult balance between awkward dream block placements and relative cheese freeness. not sure it's quite there yet",
  "7,2,1,1,0b0001,1,0",
  "9.5,-2.5,1,2,0b0010,2,where this fits in the progression should be considered",
  "10.5,-2.5,2,1,0b0010,1,0",
  "12.5,-2.5,3,1,0b0010,2,0",
  "15.5,-2.5,1,2,0b0010,1,more badelines could be added to make it feel more intense. could perhaps be tweaked a bit?",
  "10.1875,0.375,1,2.0625,0b0101,2,0",
  "6,0,1,4,0b0100,4,2nd berry is too hard, while being too easy to collect and tank (add a roundabout?); badeline num seems maybe excessive; probably need to nerf length/ending; move block should go somewhere less in the the way/ending is a bit wacky and tight. also the spikes on the right wall in the middle suck",
  "5.0625,4.0625,2,1.5,0b0010,0,exiting the tower portion, after the final badeline room",
  "3,1,3,1,0b0010,0,walk to phone booth",
  "7,3,1,1,0b0010,0,phone booth (no sprite for it yet)",
  "0,0,1,1,0b0010,0,memorial room (missing sprite)",
  "1,2,3,1,0b0010,0,awake ver - main corridor",
  "3,3,3,1,0b0010,0,awake ver - walk to phone booth",
  "0,2,1,1,0b0001,0,0",
  "4,2,1,1,0b0001,0,0"
}

--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
  {
    "25,4,2,5,-18,0",
    "29,3,2,8,0,0"
  },
  {},
  {},
  {},
  {
    "16,2,1,5,16,0",
    "15,2,1,5,0,0"
  },
  {
    "6,11,1,7,56,0",
    "4,15,1,3,0,0",
    "10,8,7,1,24,0",
    "10,12,7,1,56,0"
  },
  {
    "12,6,2,8,-20,56",
    "20,15,1,1,0,56",
    "14,6,5,1,0,0",
    "14,8,7,1,0,56"
  },
  {},
  {},
  {},
  {
    "25,4,2,5,-18,0",
    "29,3,2,8,0,0"
  },
  {},
  {},
  {},
  {
    "1,16,15,1,0,0",
    "1,14,3,1,0,-32"
  },
  {},
  {},
  {},
  {},
  {},
  {},
  {
    "11,17,4,3,0,0",
    "4,7,4,3,0,20"
  },
  {},
  {
    "13,2,2,14,32,0"
  },
  {
    "0,1,6,1,0,24"
  },
  {
    "9,12,5,1,0,16"
  },
  {
    "1,19,3,5,0,24",
    "1,17,3,2,0,0"
  },
  {},
  {
    "0,7,5,5,20,0"
  },
  {},
  {},
  {},
  {},
  {},
  {}
}
--</camtrigger>--

--mapdata string table
--assigned levels will load from here instead of the map
mapdata={
  "!&&&9'&`¹233339&!&&&&3333&&9&'■■■■■%9&'¹¹¹¹¹¹¹¹¹333!&4V&`¹¹^&V%&&&9&4o&&V%9&&!######&&',¹¹L¹¹¹¹¹&○o%'om&&__o&&%9&&&'&○○&&%!3333&&&!&&&&-,¹\\¹¹¹¹¹p¹n%'mmVWo&&V\"9&339'█t¹~V24█¹¹⁘%!33333&&=$\\¹¹¹¹¹█¹n%9##$g&ABB%!4○&%'¹t¹¹nop¹¹¹⁘24¹¹¹~o2333,`¹^`¹¹¹~%&33!#$B¹¹%'p¹n24¹u¹¹n&&`¹¹¹□□¹¹¹¹n&○○oQ,¹np¹¹¹¹24V&2&'B¹¹24p¹~█¹¹¹¹¹~o&p¹¹¹¹¹¹¹■■~█¹ᵇnQR^op¹¹¹¹¹¹~p¹%'B¹¹&█¹¹¹t¹¹¹¹¹¹nVp¹¹¹¹¹w¹゛$¹¹¹¹~Q),&V`¹¹¹¹¹¹l¹2'B¹¹p¹¹¹¹t¹¹¹q¹¹no█¹¹¹¹¹◀▶%'ma¹¹*-=Ro&p¹¹¹¹¹¹¹¹~8B¹¹p¹¹¹¹m¹¹NMNN゛$¹¹¹¹¹¹¹^24‖◀◀▶Q&&=,o&¹¹¹¹¹¹¹¹¹¹~&op¹^`¹¹¹¹¹O¹^%0■■¹¹¹¹^Vp¹¹¹¹¹Q=&&-+,¹¹¹¹¹¹¹¹¹¹¹nV&_op¹¹¹¹゛ ¹n%&#$¹¹¹¹n&o`¹¹¹*))&&&&-¹²¹¹¹¹¹¹¹¹¹n&&h&paL¹¹.'^&%&90¹¹S_*++$■■*-=&;-&&&++,¹¹¹¹¹¹¹^o&Vi*++,■■%'&o.&&0¹¹¹~Q-)=$‖▶%)RV:=9&=)-++,¹¹¹¹\"###+)-)&##90V&.!&0■■■■:&&&'¹^%&R&o%!&&&&)=-+###9!&!)-&&-&&&0o&.&&9##゜゜=&&=R^N%9'o&%&!",
  "&&&&&&&0¹¹¹.&&&&&&&&&&&&&/@¹¹¹>/&&&&&&&&&&/?@¹¹²¹¹>?/&&&/&&&/0¹¹¹¹¹¹¹¹¹.&/&&????@¹¹¹¹¹¹¹¹¹>??//¹ABBB¹¹¹¹¹¹¹¹¹vtt./¹B¹¹¹¹¹¹¹¹¹¹¹¹¹tv./¹B¹¹¹¹¹¹¹¹¹¹¹¹¹u¹./゜゜゜ ¹¹¹¹¹¹¹¹¹¹¹¹¹./&&/0¹¹¹¹¹¹¹¹¹¹¹¹¹./&&&0‖◀◀¹¹¹¹¹¹¹¹¹¹./&/?@¹¹¹¹¹¹¹¹゛ ‖◀▶>/&0¹¹¹¹¹¹¹¹¹¹.0¹¹¹¹>&0¹¹¹゛ ABBB゛/0¹¹¹¹¹&0¹¹¹>0B¹¹¹>/0¹¹u¹¹&0¹¹¹¹x¹¹¹¹¹>/ au¹a&/,¹¹¹¹¹¹¹¹¹¹>/゜゜゜゜&/-+,¹¹¹¹¹¹¹¹¹:--/&&//-R¹¹¹¹¹¹¹¹¹¹Q-.&&&///゜ ‖◀¹¹¹¹¹¹:;.&&/????@■■■■■■¹¹¹¹.&&0¹¹¹ABBBBBBB¹¹¹¹.&/0¹ᵇ¹B¹¹¹¹¹¹¹¹¹¹¹.&/@¹¹¹B¹¹¹¹¹¹¹¹¹¹¹.&0⁙¹¹¹゛゜゜゜゜}¹¹¹¹¹¹./0⁙¹¹¹>???@¹¹¹¹¹¹¹>?0⁙¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹0⁙¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹0⁙¹¹¹¹¹¹¹¹¹¹wrsa¹¹¹0⁙¹¹¹¹¹¹¹¹¹゛゜゜゜゜゜゜゜0⁙¹¹¹¹¹¹¹¹¹.///////0⁙¹¹¹¹¹¹¹¹¹.///////",
  "???/&&&/?????/&&&&&&&o○>?&/@t¹t¹n>?/&/??V█¹¹n.@¹t¹u¹~&V.?@o&p¹¹¹~y⁙¹t¹¹¹¹n&yV&&Vp²¹¹¹y⁙¹u¹■■¹~ox○○&&゜゜}¹¹y⁙¹¹¹゛ ¹¹~█¹¹~o/@¹¹¹x⁙¹¹¹.0¹¹¹¹¹¹¹n0¹a¹¹¹¹¹▮¹.0¹▮¹¹¹¹¹n0NMNP¹¹¹¹¹.0¹¹¹¹¹◀▶゛0NNP¹¹¹¹¹^.0__`¹¹¹¹.0¹¹¹¹¹¹¹^o.0&o○U¹¹■.0■¹¹¹¹¹¹~○.0○█¹¹¹¹゛// ¹¹¹¹¹■■■.0■¹¹¹¹■.&&0■■■■■゛゜゜// ■■■■゛/&&/゜゜゜゜゜/&&&&/゜゜゜゜/&&&&&&//&&&&&&&&&//&&&",
  [6] = "&&/&&&&&/??//?//?/&&&&/???//?@&○.@¹>@v>?/&?@&&o>@█○█¹x¹¹¹t¹~&.&&V&&V█¹¹¹¹¹t¹¹¹v¹¹n>/o&V&p¹¹¹¹¹¹u¹¹¹¹¹¹~&.゜゜゜゜゜゜ ¹¹¹¹¹¹¹¹¹¹¹¹n.&&&&&/0u¹¹¹¹¹¹¹¹¹aq゛/&&&&&&/゜ ¹¹¹¹¹¹¹¹゛゜//&&&&&&&&/ ABBBBBB./&&&&&&&&&/&0B¹¹¹¹¹¹.&&&&&&&&/??/0B¹¹¹¹¹¹./&&&&&&&0&&?0B¹¹¹¹¹¹.?&&&&&&&0&○○xB¹¹¹¹¹¹x&.&&&&//@█¹¹¹B¹¹¹¹¹¹¹n.&/???@█¹¹¹¹¹¹¹¹¹¹¹¹~.&0○○█¹¹¹¹¹¹¹¹¹¹¹¹¹¹O>/0ma¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹O¹.0mm¹¹¹²¹¹¹¹¹¹¹¹¹¹]NM.0mm゛゜゜}¹¹¹¹¹¹¹¹¹¹¹¹O.@‖▶./0¹¹¹¹゛゜゜゜゜゜ ¹m゛/p¹¹./0ma¹゛//&/&/0wm.&p¹¹.&/゜゜゜/&&&&&&/゜゜/&&`u./&&//&&&&&&&&&&&&゜゜゜/&&&&&&&&&&&&&&&&&",
  [7] = "&&&&&&&&&&&&&/?????/&&&&&&&&&&&&&&&/@o&█¹¹>/&&&&&&&&&&&&&/0V&pᵇ¹¹¹.&&&&&&&&&&&&&/0&W&_`¹¹./&&&&&//&&&&&&/ gV&o`゛&&&&/????/&&//&&0ABBBB./&&/@tt¹v>????/&0B¹¹¹¹>?/&@¹vt¹¹¹¹¹¹¹>?0B¹¹¹¹¹¹.&¹¹¹u¹¹¹¹¹¹¹¹OxB¹¹¹¹NN./¹¹¹¹■■■■■¹¹¹O¹B¹¹¹¹P¹./¹¹¹¹ABBBB¹amOqB¹¹¹¹¹^>/゜ ‖¹B¹¹¹¹NNMNNB¹¹¹¹¹no./0¹¹B¹¹¹¹¹¹O¹¹B¹¹¹^^&&>&@¹¹B¹¹¹¹¹¹O¹¹B¹¹¹n&V○o0¹¹¹¹¹¹¹¹¹¹O゛ B¹¹¹nV█¹n0■¹¹¹¹¹¹¹¹*+/0B¹¹¹np²¹n&,¹¹¹¹¹¹¹*-=&/゜゜゜゜゜゜゜゜゜-R■■■■■■■Q&&&&&//&/&&//&)+゜++゜゜+)&&&&&&&&&&&&&&&&-=&-/=&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&",
  [9] = "&&&&&&&0¹¹¹.&&&&&&&&&&&&&/@¹¹¹>/&&&&&&&&&&/?@¹¹¹¹¹>?/&&&/&&&/0¹¹¹¹¹¹¹¹¹.&/&&????@¹¹¹¹¹¹¹¹¹>??//¹ABBB¹¹¹¹¹¹¹¹¹vtt./¹B¹¹¹¹¹¹¹¹¹¹¹¹¹tv./¹B¹¹¹¹¹¹¹¹¹¹¹¹¹u¹./゜゜゜ ¹¹¹¹¹¹¹¹¹¹¹¹¹./&&/0¹¹¹¹¹¹¹¹¹¹¹¹¹./&&&0‖◀◀¹¹¹¹¹¹¹¹¹¹./&/?@¹¹¹¹¹¹¹¹゛ ‖◀▶>/&0¹¹¹¹¹¹¹¹¹¹.0¹¹¹¹>&0¹¹¹゛ ABBB゛/0¹¹¹¹¹&0¹¹¹>0B¹¹¹>/0¹¹u¹¹&0¹¹¹¹x¹¹¹¹¹>/ au²a&/,¹¹¹¹¹¹¹¹¹¹>/゜゜゜゜&/-+,¹¹¹¹¹¹¹¹¹:--/&&//-R¹¹¹¹¹¹¹¹¹¹Q-.&&&///゜ ‖◀¹¹¹¹¹¹:;.&&/????@■■■■■■¹¹¹¹.&&0¹¹¹ABBBBBBB¹¹¹¹.&/0¹ᵇ¹B¹¹¹¹¹¹¹¹¹¹¹.&/@¹¹¹B¹¹¹¹¹¹¹¹¹¹¹.&0⁙¹¹¹゛゜゜゜゜}¹¹¹¹¹¹./0⁙¹¹¹>???@¹¹¹¹¹¹*>?0⁙¹¹¹¹¹¹¹¹¹¹¹¹¹¹Q=-0⁙¹¹¹¹¹¹¹¹¹¹¹¹¹¹Q-=0⁙¹¹¹¹¹¹¹¹¹¹wrs*-=-0⁙¹¹¹¹¹¹¹¹¹゛゜゜゜゜゜゜゜0⁙¹¹¹¹¹¹¹¹¹.///////0⁙¹¹¹¹¹¹¹¹¹.///////",
  [11] = "!&&&9'&`¹233339&!&&&&3333&&9&'■■■■■%9&'¹¹¹¹¹¹¹¹¹333!&4V&`¹¹^&V%&&&9&4o&&V%9&&!######&&',¹¹L¹¹¹¹¹&○o%'om&&__o&&%9&&&'&○○&&%!3333&&&!&&&&-,¹\\¹¹¹¹¹p¹n%'mmVWo&&V\"9&339'█t¹~V24█¹¹⁘%!33333&&=$\\¹¹¹¹¹█¹n%9##$g&ABB%!4○&%'¹t¹¹nop¹¹¹⁘24¹¹¹~o2333,`¹^`¹¹¹~%&33!#$B¹¹%'p¹n24¹u¹¹n&&`¹¹¹□□¹¹¹¹n&○○oQ,¹np¹¹¹¹24V&2&'B¹¹24p¹~█¹¹¹¹¹~o&p¹¹¹¹¹¹¹■■~█¹ᵇnQR^op¹¹¹¹¹¹~p¹%'B¹¹&█¹¹¹t¹¹¹¹¹¹nVp¹¹¹¹¹w¹゛$¹¹¹¹~Q),&V`¹¹¹¹¹¹l¹2'B¹¹p¹¹¹¹t¹¹¹q¹¹no█¹¹¹¹¹◀▶%'ma¹¹*-=Ro&p¹¹¹¹¹¹¹¹~8B¹¹p¹¹¹¹m¹¹NMNN゛$¹¹¹¹¹¹¹^24‖◀◀▶Q&&=,o&¹¹¹¹¹¹¹¹¹¹~&op¹^`¹¹¹¹²O¹^%0■■¹¹¹¹^Vp¹¹¹¹¹Q=&&-+,¹¹¹¹¹¹¹¹¹¹¹nV&_op¹¹¹¹゛ ¹n%&#$¹¹¹¹n&o`¹¹¹*))&&&&-¹¹¹¹¹¹¹¹¹¹¹n&&h&paL¹¹.'^&%&90¹¹S_*++$■■*-=&;-&&&++,¹¹¹¹¹¹¹^o&Vi*++,■■%'&o.&&0¹¹¹~Q-)=$‖▶%)RV:=9&=)-++,¹¹¹¹\"###+)-)&##90V&.!&0■■■■:&&&'¹^%&R&o%!&&&&)=-+###9!&!)-&&-&&&0o&.&&9##゜゜=&&=R^N%9'o&%&!",
  [15] = "¹¹¹¹¹¹¹¹¹¹¹%'&&%¹¹¹¹¹¹¹¹■■■%'AB%¹¹¹■■■■■*++%'B¹%¹¹¹5#6663;;;4B¹%¹¹¹¹1□□□¹¹~○&&&%■¹¹¹1⁙¹¹¹¹¹¹~○○%,■■■1⁙ᵇ¹■■¹¹¹■■%-+++'⁙¹¹\"$■■■\"#9&);9'⁙¹¹%'ABB%!&=<o24⁙¹¹2'B¹¹29&RV&p¹¹¹¹¹8B¹¹¹%&R&o&`¹¹¹¹t¹vt¹29'&&Vp¹¹¹¹t¹▮t¹⁘%'&WV█¹¹¹¹t¹¹u¹⁘%'og█v¹¹¹¹u¹¹¹¹⁘2'‖▶(¹¹¹¹q¹¹¹¹¹¹¹'`¹1¹¹¹¹O¹¹¹¹¹¹¹'o`1¹¹¹¹O¹¹¹¹¹¹¹'&V8■■■¹O¹a¹¹¹¹¹'V○ABBBqO]MPm¹¹■'█OB¹¹¹NMNOmm²¹\"'¹O□□□□¹O¹O(‖◀▶%'¹O¹¹¹¹¹O¹O1¹¹¹%",
  [22] = "¹¹¹¹¹¹^_&*-=!&9&¹¹¹■*#666;;33333¹■■*-4v¹Y¹~○&pHI⁘5+-R¹¹¹¹¹¹¹~█X¹¹t2)4¹¹¹¹wrs¹aX^¹v¹1¹¹¹¹\"#$‖◀▶\"#■■■1`¹¹¹%&'ABB%9+++Ro__`29'B¹¹%&33!R&WV&_%'B¹¹%!¹t24Vg&&o%'B¹¹%9¹u¹ABBBB&2'B¹¹%&¹¹¹B¹¹¹¹█¹1B¹¹%&aE¹B¹¹¹¹¹¹1B¹¹%&##7B¹¹¹¹`¹1B¹¹%&&4¹B¹¹¹¹pE1B¹¹%!'¹¹B¹¹¹¹&`1B¹¹%&4¹¹B¹¹¹¹5#'B¹¹%9¹¹¹B¹¹¹¹o2'B¹¹%!¹¹¹B¹¹¹¹█t1B¹¹%&¹¹¹¹¹(t¹¹t1B¹¹%&¹¹¹E¹1t¹¹v1B¹¹%9¹¹「「「1t¹¹¹1B¹¹%&¹¹¹¹¹1CDDD1B¹¹%&■■■■■1D¹¹¹1B¹¹%&###664¹¹^_1B¹¹%&&34Vp¹¹¹nV1B¹¹%9'&o&█¹¹¹~&8B¹¹%9'V○█¹¹¹¹¹~○o&&%&'█²¹ma¹¹¹¹¹n&V%&'‖◀▶\"$¹¹¹¹^&V&%&'_`¹%'■■■■\"###9&'&&_%9####&&!&&&",
  [23] = "&&&&&&&9&&&!&&&&&&!&&&&&333!&&&&&&9&!&&333!333!&&&339&!'a¹~29&&!&3333!'ABB1¹¹¹%&&'□□2334NP¹n2!33'¹t¹t24B¹¹1¹E¹%!9'⁙¹¹~&p¹¹¹~█1Yn4¹t¹v¹¹B¹¹8¹¹¹233'⁙¹¹E~█¹¹¹¹¹8¹~¹¹t¹¹¹¹B¹¹¹¹▮¹ABB1⁙¹¹■■■■■¹¹¹¹HI¹¹v¹¹¹¹B¹¹¹¹¹¹B¹¹1⁙¹¹ABBBB¹¹¹¹X¹¹¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹8⁙¹¹B¹¹¹¹¹¹q▶5#a¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹¹¹¹qO¹¹%m¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹¹¹¹¹B¹¹¹¹NNMNN%m²m¹¹¹¹B¹¹¹L¹¹B¹¹¹¹L¹¹t¹t¹¹¹Oa¹%##$¹¹¹¹¹tv¹n`¹B¹¹¹^p¹¹t¹u¹¹]NNN%!&'■■■¹¹t¹¹np¹B¹¹¹np¹¹t¹¹¹¹¹¹¹¹Q&&9##$⁙¹v¹^op¹¹*,■n&`¹u¹L¹¹¹¹¹■Q&&&&9'■¹¹¹n&&`■Q=,&&V_U¹\\¹¹¹¹■*-&&&&&!$¹¹¹n&Vp*=)RV&&p¹¹n`¹¹¹*=&",
  [24] = "33;;;-'¹¹%&&9!&&'&`¹%&&!9&&-R¹¹¹¹%9&3339&&!=&&&&¹¹¹~V:)##!33333&9###9&3333!&)+,¹a%&4ot○%&33;;-&&¹¹¹¹~&Q=&'V█¹¹~23&&&&4&&○t239&=+#&'p█u¹24¹~○&:=&¹²¹¹¹nQ&!4█¹¹¹¹~o%&94&○█¹t~U23&&-&'█¹¹¹AB¹¹t~oQ=#$¹¹¹~%)'v¹¹¹¹¹¹~%&'oV█¹¹u¹¹~&%&&9'¹¹¹¹B¹¹¹t¹~%)!4¹¹¹¹%!'¹¹¹¹w¹¹¹%!4○¹¹¹¹¹¹¹¹~%&&34¹▮¹¹B¹¹¹v¹¹2&'¹¹¹¹¹%9'¹¹¹\"$¹¹¹24█¹¹¹¹▮¹¹¹¹¹%!4AB¹¹¹¹B¹¹¹¹¹¹v2'¹am¹¹%&']MN2'¹¹¹AB¹¹¹¹¹¹¹¹¹¹¹%'¹B¹¹¹¹⁘\"$¹¹¹¹¹¹¹'NMNP¹234NP¹⁘1¹¹¹B¹¹¹¹¹¹■■■¹m¹%4¹B¹¹¹¹⁘%'¹¹¹¹¹¹¹'NNP¹¹ABB¹¹¹⁘1¹¹¹B¹¹¹¹■■\"#$]MN8v¹B¹¹¹¹⁘%'¹¹¹¹rs¹'¹¹¹¹¹B¹¹¹¹¹⁘8¹¹¹B¹¹¹¹\"#9!4NP¹¹¹¹B¹¹¹¹⁘%'¹¹¹¹\"##'¹¹¹¹¹B¹¹¹¹¹¹t¹¹¹B¹¹¹¹2!&'v¹¹¹¹¹¹B¹¹¹¹⁘%'¹¹¹¹29&'¹¹¹¹¹B¹¹¹¹¹¹u¹¹¹B¹¹¹¹t%&'■■¹¹¹¹¹B¹¹¹¹■%'¹¹¹¹n%&'■■¹¹¹B¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹v%&=+,¹¹¹¹¹¹¹¹¹⁘\"&'■¹¹^o%9)+,`¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹^_%&&-R`¹¹¹¹¹¹¹¹⁘%!&$`¹^&%!&-R&`¹¹¹¹¹¹¹¹¹¹¹¹¹¹^_&V%9&&R&_`¹¹¹¹¹¹⁘%&&'&_&&%&",
  [25] = "m¹¹¹¹¹ABBB%&&&&&mm²¹a¹B¹¹¹59&&&&###++,B¹¹¹V5&&!&9&)&-RB¹¹¹&&%!39&&&&=RB¹¹¹&o54o%&&&&!RB¹¹¹V○█¹n%&&&&='B¹¹¹█¹t¹n%&&&39'B¹¹¹¹¹v¹~%&!4V%'B¹¹¹¹¹E¹¹%&'o&2'B¹¹¹¹¹¹¹¹Q&'&○V1B¹¹¹¹¹¹¹¹Q9'pv~1B¹¹¹¹¹¹¹¹Q&'█E¹8B¹¹¹¹¹■■■Q&'¹▮¹¹B¹¹¹■■*++)!4¹¹¹¹B¹¹¹*+=&-&R¹¹¹¹¹B¹¹¹Q)&&&&R¹¹¹¹¹\"#++-&&&&&R¹¹■■■%!&=&&&&&&R¹¹5##33339&&&&&R¹¹□24ABBB2!&&&&R¹¹¹□□B¹¹¹V2&&&&'m¹¹¹¹B¹¹¹&&%&&!'NME¹¹B¹¹¹&V%933'NNMP¹B¹¹¹&&2'Y_'¹¹O¹¹B¹¹¹o&&1^&'¹¹O¹¹B¹¹¹&o█1&o'¹¹¹¹¹B¹¹¹○○v8~█'■¹¹¹¹B¹¹¹¹t¹¹HI9,■■■¹B¹¹¹¹v¹¹X¹&-++$■B¹¹¹¹¹¹¹X¹&&&-!$B¹¹¹arswX¹&&&&&'B¹¹¹\"#####",
  [26] = "&&'&&%&&333&9&&&&9'&○%94¹v¹%333!&&'█¹24¹¹¹¹8¹¹¹%!34¹¹⁘ABBBBB¹¹¹%'HI¹¹⁘B¹¹¹¹¹¹E¹%'X¹¹¹¹¹¹(_`¹¹¹¹%'X¹¹²¹¹¹%$&`¹rs%'¹¹\"####9!#####9'__23333333&!&&&'&&○█¹t¹¹~○23&9&'○█¹¹¹u¹¹¹¹O¹%&&'Y¹¹¹¹¹¹■¹¹O]2!&'¹¹¹¹¹¹](¹MPm¹%&'w¹¹¹¹¹¹1NNNNN2!!#$¹¹¹¹¹1¹¹¹¹¹n%&&'¹¹「「¹1¹¹¹¹¹n%&&'■■¹¹¹1¹¹¹¹¹~%&&=+,■■■1¹「「¹¹¹%&&&&-+++'■■■■¹¹%&&&&&&=)!+++,AB%&&&&&&&&&)&-RB¹%&!339&&&!&&!'□□%94○&%&!333334¹¹%'v¹~%!'&○█t¹¹CD%'¹¹¹23'█¹¹t¹¹D¹%'ABB¹¹8CD¹u¹¹D¹%'B¹¹¹¹¹D¹¹¹¹¹¹¹%'B¹¹¹¹¹D¹¹¹¹¹¹¹%'B¹¹¹¹¹D¹¹¹¹¹¹a%'B¹¹■■¹¹¹¹¹¹¹]NQ'B¹¹\",■■■■¹¹¹¹¹%'¹¹¹%-+++,■■■■■Q'¹¹¹%&)=&=+++++)",
  [28] = "&&'¹¹¹¹%&&&&&&&&&&&&&&&&4&&&&&&&&&'¹²¹¹%&&3&&&&&&&&&3334&&V&&&&&&&'¹¹¹¹%&4□%&&&33334&&&&&&&&&○○○&&'¹¹¹¹%'□¹%&&4&&&&&&V&&&&&&█tt¹&&'¹¹¹¹%'¹¹%&'&&&&&&&&&&&&&█¹tt¹&&'¹¹¹¹24¹¹%&'V&&&&&&&&&&&p¹¹tt¹&&'¹¹¹¹tt¹¹2&'&&&&&&&&&&&Vp¹¹tt¹&&'¹¹¹¹ut¹¹¹%'&&&&V○○&&&&&p¹¹tt¹9&'¹¹¹¹¹t¹¹¹%4○○○&p¹tn&&&&█¹¹¹t¹&&',¹¹¹¹u¹¹¹8□¹¹tnp¹un&&&paa¹¹v¹&&&$,¹¹¹¹¹¹¹□¹¹¹t~█¹¹n&V&pNMP¹¹¹33&&#$¹¹¹¹¹¹¹¹¹¹t¹¹¹¹n&&○█NP¹¹¹¹¹¹2333,¹¹¹¹¹¹¹¹¹t¹¹¹¹n&p¹t¹¹¹¹¹¹¹¹¹¹¹¹Q,¹¹¹¹¹¹¹¹u¹¹¹¹n&p¹t¹¹¹¹¹¹■¹¹¹¹¹QR¹¹¹¹¹¹¹¹¹¹¹¹¹n&█¹t¹¹¹¹¹¹$¹¹¹¹¹Q),¹¹¹¹¹¹¹¹¹¹¹¹~█¹¹t¹¹¹¹¹¹'¹¹¹¹*-=R¹¹¹¹¹¹¹¹¹¹¹¹¹U¹¹t¹¹¹¹¹¹4‖◀◀▶Q-&=,¹¹¹¹¹¹¹¹¹¹¹¹^¹¹t¹¹¹¹¹¹¹¹¹¹¹Q=&=-+,¹¹¹¹¹¹¹¹¹¹¹¹¹u¹¹¹¹¹¹¹¹¹¹*)=&&=)-,¹¹¹¹*+,¹¹¹¹¹¹¹¹¹¹¹¹$■■*-=&&&&&&-++++-=Rqa¹uq¹¹¹*+++=$‖▶%&&&&&&&&=)=-=&)++++++++--=))'¹¹%&9&&&&!&&&&&-&&=)=---))&&&&=R¹¹%&&&&&9&&&&&&&&&&&&&&&&&&&&&"
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
--[=[function get_mapdata(x,y,w,h)
  local reserve=""
  for i=0,w*h-1 do
    reserve..=num2base256(mget(i%w,i\w)+1)
  end
  printh(reserve,"@clip")
end

--convert mapdata to memory data
function num2base256(number)
  return number%256==0 and "\\000" or number==10 and "\\n" or number==13 and "\\r" or number==34 and [[\"]] or number==92 and [[\\]] or chr(number)
end]=]
__gfx__
000000000000000000000000088888800000000000000000000000000000000000000000000000000300b0b00a0aa0a000000000000000000000000000077000
00000000088888800888888088888888088888800888880000000000088888800004000000000000003b33000aa88aa0000777770000000000000000007bb700
000000008888888888888888888ffff888888888888888800888888088f1ff180009505000000000028888200299992000776670000000000000000007bbb370
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff800090505049999400898888009a999900767770000000000000000007bbb3bb7
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff800090505005005000888898009999a9007766000077777000000000073b33bb7
0000000008fffff008fffff00033330008fffff00fffff8088fffff808333380000950500005500008898880099a999007777000077776700770000007333370
00000000003333000033330007000070073333000033337008f1ff10003333000004000000500500028888200299992007000000070000770777777000733700
00000000007007000070007000000000000007000000700007733370007007000000000000055000002882000029920000000000000000000007777700077000
888888886665666555888888888886664fff4fff4fff4fff4fff4fffd666666dd666666dd666066d0000000000000000700000000d6666660d666d6d066666d0
888888886765676566788888888777764444444444444444444444446dddddd56ddd5dd56dd50dd5007700000770070007000007dddd66661ddddddd1dd6666d
88888888677867786777788888888766000450000000000000054000666ddd55666d6d5556500555007770700777000000000000ddd6dddd1ddddddd11ddd66d
8878887887888788666888888888885500450000000000000000540066ddd5d5656505d5000000550777777007700000000000001dddddd1111ddd11111ddddd
887888788788878855888888888886660450000000000000000005406ddd5dd56dd506556500000007777770000070000000000001ddddd11111111111111ddd
867786778888888866788888888777764500000000000000000000546ddd6d656ddd7d656d500565077777700000077000000000d11111111111101111111110
5676567688888888677778888888876650000000000000000000000505ddd65005d5d65005505650070777000007077007000070dd1111110011011011111ddd
56665666888888886668888888888855000000000000000000000000000000000000000000000000000000007000000000000000dd111110000000000111ddd6
00000000ddd8ddd8ddddd5888ddd8ddddd555100000000000015555d8d5585d80cccccc0077777777777777777777770cc000000011111000000000000111d66
00000000d5515551555555111555155d55555100000000000000111155555155cccccccc7777777777677767777777771c00cc00dd111100000001000011d166
00555550d55155511111111111111118111100000000000001555dd8811111181ccccccc7677667777766677777777770000ccc06ddd1110011011100001ddd6
005ddd50555155505dddd1551555555d8dd55d100000000001555dd8dd55111d1cc1ccc17766677777776d676777677700001ccc66ddd110011011100001dddd
000ddd0055505d505ddd515515d55ddd8dd5551000000000015555d8dd5551dd1cc11c1077d67777dd77dcd7666677700cc01ccc66ddd110000001100001ddd6
000005558110011155555055110001188d5555100000000000001111d555515d111111007dcd667dccddcccd6d6777661ccc11c1dd6dd1100011000000111ddd
55500555d55555101111101100055ddd1111000000000000001555dd55555155011010007cccd66cccccccccccc66d661ccc0111dddd111001111100011111dd
55500000d5555510000000000015555ddd55510000000000001555dddd55515d000000007ccccccc0ccc00cccccd6dd611c00000ddd111000011100001111110
dd55515dd5555100000000000015555dddd15ddddddddd51ddd51ddd555551550000000077cccccc00cccccccccccc770ccc1000011111000000000000111d66
55555155d55551001100000000155ddddd51555555555551555515dd555551185500000077cccccccccccccccccccc771cc11000ddd11110000000001111dd66
81111118810001115500111011111118555111111111111111111555811111185505555067c7cccccccccccccccc7c671111000066dd1111111100111111ddd6
dd5111dd55505d51dd00555015d55ddd811111155111111151111118d551555d000555506ccccccccccccc6cccccccc60011cc1066dd11111111101111111ddd
dd5111dd55515551dd1155511555555d555551155155555151155555d5515555000000006ccccccccc6cccccccccccc6001cccc0dddd11111ddd111166611dd6
55511155d55155511111555111111118555551111155555111155555811155550555550066ccccc6cccccccc6ccccc660111cc106dddd11d666dd11ddd6611dd
81111118d5515551555155511555155ddd555155515d5551551555ddd55155dd055555006ccc66c6666ccc666c66ccc61c111100ddddd1d666ddd1dddddd11dd
5555515d8dd8ddd8dd58dd588ddd8dd8dddd585dd8dddd58d585dddd8d585dd800000000066666660666666666666660cc1000000dddd0ddddddd0ddddddd110
0000000000000000577777777777777788cccc8888cccc8888cccc881dddd15ddddd51dd000d0000100600101111011115555555555555551500000055505500
00008000000b000077777777777777778c0000c88c0000c88c0000c8d555515555d551550d0d0d000d060d001111011115111111111111111500000011111000
00b00000000000007777ccccccccccccc00cc00cc00c100cc00cc00cd55551555555515500d6d000006760001111011115000000000000001500000000000000
0000000000000000777cc7ccccccccccc0c00c0cc010c10cc00cc00cd555111111111111dd676dd0667776600000011115000000000000001500000000000000
0000b000080000b077ccc7ccccccccccc0cccc0cc01cc10cc00cc00c555111111111111100d6d000006760001110011115000000000000001500000000000000
0b0000000000000077c77777ccccccccc00cc00cc00c100cc00cc00c55511111111111110d0d0d000d060d001110000015000000000000001500000000000000
00000080000b000077cc777ccccccccc8c0000c88c0000c88c0000c81111111111111111000d0000100600101110111115000000000000001500000000000000
000000000000000077ccc7cccccccccc88cccc8888cccc8888cccc88d55111111111111100000000000000000000000015000000000000001500000000000000
7cccccccccccccc71111101100111010111101110000000015555551d5511111111cc11100000001000000001111111100555505111011101110110001101110
77ccccc0cccccc771111101101111010111101110001111050500505d551111111cccc1100000001000000001111111100001111111011101110110001101111
76ccccc0cccc77771111001101111010111101110001111051511515d55111111cc11cc10000010d010000000001111000000000111011101110110001101111
667cccc000ccccc70000000100001010000000110000000051511515555111111cc11cc10001000d000100000000000000000000000011100000000000001111
6ccccccc0ccccc771100000001100000100000000111010051511515111111111cccccc100001006001000001100011100000000111011100000000000000000
7cccccccccccc6771110111101101110110111110111010051511515d55111111cccccc100100d060d0010001110111100000000111011101110110000111111
7cccccccccccc6671110111101101110110111110000000051511515d551111111cccc1100000067600000000000111000000000111000001110110000111111
77cccccccccccc671110111101101110110111110000000051515515d5511111111cc11111dd6677766dd1100000000000000000111000000000000000111111
00000000000770000007700000077000000000000007700051515515155555515000000500000067600000001111011111155555000000001110000000000000
00000050000770000077770000700700707777070077770051510515500000055000000500100d060d0010001111011110151115100001001110000000011110
00000050007777007777777707000070777777770777777051511515500000055000000500001006001000000000011110151155111101101110111100011111
0050050500777700077777707777777777777777777777775151151550000005500000050001000d000100001110011110151555111100100000111100111111
0505051d07777770077007707777777707777770777777775151151550000005500000050000010d010000001110000010155515000000000000111100100111
051d0515077777707777777707777770077777700777777051511515500000055000000500000001000000001110111110155115110011000000000000011011
0515051d777777770077770000777700077777700077770051511515500000055000000500000001000000001110111110151115111011110000000000111111
051d051d777777770007700000000000777777700007700055555555500000055000000500000000000000001110111111155555011001100000000000011111
000000000000000000000000000115000111111500011500000000000dd11dd1011111100d666660066d0d66666d0d660d6666d0011100000000000000000000
00000000000000000000000000010500001010100001050000011100111111d1dd1111ddd6d6666d66dd1ddddddd1ddd1dd6666d111100000001111000001111
000000000000000000000000000151000050505000015100001505101611111066d111d6ddddd66666dd11dddd1111dd1ddd666d111100000000111000001111
00000000000000000000000000005000005050500000500000150510d661116666d11dd60111ddddd6dd1111111111111ddddd6d111100000000000000001111
10000000055555555555555000011500005050500001100000150510dd6611d66dd11dd0d1111110ddd1111000000100011ddddd111101110000001111101111
100000000111111111111150000105000050505000050000001111111dd11ddd6dd111166ddd11d6dd11d6d0ddd0dd10111111dd111101110110100111101111
100000000001100000011000000151000010101000000000001010511ddd66d1ddd111dddddd1ddd0111ddd1ddd1ddd11dd11110111101110110111111101111
15000000000150000001500000005000011111150000000000101051011ddd100dd111dd0dd111d000111dd111111dd1ddd11100111101110110111111101111
00000000000000000000000000000000025252528352525252525252525252520252525252232323235252835252525252525252835252525252525252330000
00000000000000000000000000000000f2e652d3e3e25252e2e3e3e3e3e3e3e25252620101000000000003000000428352627484841302232323022323520252
000000000000000000000000000000002323525252525252525223235252525252528352333737d7524283525202525252525252525252525252232352620000
00000000000000000000000000000000f255525552d3e3e3f255525252e652d3525282a2b20000000101030000014252836275d5f50003215731033737132323
00000000000000000000000000000000000013025252525252625252135252835252526200374737d61323232323232352520252525252525262003713330000
00000000000000000000000000000000f3e75252e7e7e7e68752e6e7e7e7e655525252521501010192a262d700432302526200d6f60073214431733737000057
0000000000000000000000000000000000000042525252525233e7e7524252522323233300370057d6525252f6000042022323232323525252620037d6f60000
000000000000000000000000000000000037d7f7005700d78752f7010100d75252525252c2a2a2a252826252e5f737425262d5e652f500000000003747004400
00000000000000000000000000000000000000428352525262d4c4f4d64202330006000000470000d652e6e7f7000013330000d75252132323230037d6f60000
00000000000000000000000000000000004700370000000087f700a7c700f0d65252825283a3a3c3528362e7f700474283625252e6e745000000005700671727
00000000000000000000000000000000000000425223232333d4f400d742620600c66700000000d55252f6373700000000000000d652f60037000057d6f60000
00000000000000000000000000000000000000370004141487000004140000d75202a3c362111105c32333000000004202625552f73700000000000000432222
00000000000000000000000000000000000000133337370037000000001333d4c4d4c4f4000000d65252f6003700000000000000d652f70037000000d6f60000
0000000000000000000000000000000001010047001400008700001400000000836211133300001333370000000000425262e7f7003700000000000000004283
00000000000000000000000000000000000000d6f65737003700000000d6f600e400e400000000d65252f6005700000000000000d6f6000057000000d6f60000
00000000000000000000000000000000b2b2010000000000770000d1f10101015262e5e7f7000000573700000000004252628537004700010101000000001352
00000000000000000000000000000000000000d6f60037005700000000d6f600e400e400000000d65552f6000000000000000000d6f6000000000000d6f60000
00000000000000000000000000000000c382b20000000000000000d2e2e1e1e10233f60000000000005700000000014283620047000000041414f5000000d613
00000000000000000000000000000000000000d6f60057000000000000d6f600e400e4000000d5525276f6000000000000000000d6f6000000004700d6f60000
0000000000000000000000000000000052c2150000000000000000d2525252526252f7000000000000000000000092c3023300000000d5140000f6000000d655
00000000000000000000000000000000000000d6f60000000000000000d6f600e400e4000000d567528652f547000000000000d55212320000004747d6f60000
00000000000000000000000000000000c252150000000000000000d3e3e2525262f60000000000243400000000000552620000000000d6555252e6f54400d7e6
00000000000000000000000000000000001000d6f60000000000000000d6f600e400e40000d1e1e1e1222222320000000000d5e65242620000474747d692a2a2
0000000000000000000000000000000052521500000000000000000000d2525262f70000000000340000000000004282620000000000d6e6525252f6000000d6
00000000000000000000000000000000a2a2b2d6f60000000047060000d6f600e400e4000042525252525283f24151516192a2b27213330092a2a2a2a2c2c382
0000000000000000000000000000000052521501010000000000000000d25252620000000101000000000001010142526200000000d55252555255f7000006d6
00000000000000000000000000000000c382c2a2a2a2b2004747c61727d6f692a2a2b2416142835252525252f20000000005c282a2a2a2a2c2c382c3c2c35252
00000000000000000000000000000000525282a2b20100000000000000d252526200000092b2010000000092a2a202526210000012a2a2a2a2a2b20101011222
0000000000000000000000000000000052525282c3c28222222222222222a282c2821547c542525252520252f20101010105c352c38382525252525252c25252
00000000000000000000000000000000525252c252b2172700100000d1e25252152434340552b2000001010552c352526241611202c3c28252c2c32222220283
00000000000000000000000000000000525252525252525202525252528383c252c315d4d442525252525252832222222283c252525252525252525252525252
0000000000000000000000000000000052525252c282a2b241515161d25252521534000005c362000192a2822323230262000042525252525252525202525252
e3e3e3e3e3e3e3e2e25252e2e3e3e3e3e25252e2e3e3525252525252e2e3e3e3525252525252525252023337d6e6135200000000000000000142625252525252
52425262000000000000000000000000000000000000000000000000000000001500000005c26200432323330000004200000000000000000000000000000000
e752e652f700d7d3e3e2e2f3f737d7e7d3e2e2f352e6d2e252e2e3e3f3e7e7e7525252525252525283331137d7e7e742000000000000000012526252525252e6
524252330000000000000000000000000000000000000000000000000000000015000000138362000000670000a0004200000000000000000000000000000000
00d752f6000000d752d2f2f600470057d7d3f2e6e752d2e3e3f30414f7000000528352525252525262110057001727420000000000000000425262e7e6525252
52426200000000000000000000000000000000000000000000000000000000006200000037132322222232000000004200000000000000000000000000000000
1727d6f700000000d6d2f2f70000000000d787f6a0d78700573114000000000002232302525252526200000000122202000000000000000042526201d65252e7
e7426200000000000000000000000000000000000000000000000000000000006200440047d75213232333717171714200000000000000000000000000000000
e1f1f60000000000d7d2f20000006700000077f7000087c6003114000000001062111113835252026241515161428352000000000000000013525232d7e6f600
0013330000000000000000000000000000000000000000000000000000000000620000000000d7e7f700570000d5e54200000000000000000000000000000000
e2f2f7000000000000d2f20414d1f10000310414141487d4f43114000000d1e16200001113232323330000000013235200000000000000000042526200d7f700
001111000000000000000000000000000000000000000000000000000000000062000000000000000000000000d6524200000000000000000000000000000000
52f300000101010000d3f31400d2f20000311400000077000031140000c4d2e262c60000041400370000f0000057314200000000000000000042523300000000
000000000000000000000000000000000000000000000000000000000092a2a215010100000000000101000044d7524200000000000000000000000000000000
f23700310414142100d6f61111d2f24100311400000037000000d1f1d4f4d25262d4f40014000047000000000000314200000000000000000013330000000000
0000000000000000000000000000000000000000d5b5b5b5f50000000005c382c2a2b20101000000041400000000d742000000000000000000000000d5e5f500
f23700311400002100d652f500d2f20000311400000037000000d2f20101d2e262f4000014000000000001010000314200000000000000000000000000000000
00000000000000000000000000000000000000d5d652e65252f500000005c25252c32353630000001400000000000042000000000000000000000000d652f600
f25700311400002100d75552e5d2f20000311400000057000000d2e2e1e1e252620000c51400000000311232f500014200000000000000000000000000000000
00000000000000000000000000000000d5b5e5525252525252f600123205c3525262c600000000001400000000000042000000000000000000000000d652f600
f2000000370037000000d65252d2f20000311400000000000000d2e252525252620000001400010101014262f700128300000000000000000000000000000000
00000000000000000000000000000000d6765252525252e60652f5133393c2520233d4f400000000140000000000014200000000000000000000d5e55252f600
f200000037f047000000d7e755d2f200d5e555e7e7f700000000d25252525252620000001222320414144262d5d5425200001000000000000000000000000000
00000000000092a2b2070000000000d5068667172706062222222222223205c36257000000000000000000000000128300000000001232000000d652605252f5
f20000005700000000000000d7d2f2e5e6e7f700000000000000d2e252525252620000004283621400001333d5e64252a2a2a2b2000000000000222232000000
00010100009282c382223200470000d6122222222222321323232323233305c26200000000000000000000000000425200100000004283320000d652525252f6
f2010000000000000000010101d2f2e7f7000000000000010101d2e252525252620610004252620000000414e5554202c2c2c215000000000043425262000000
001232000005c25252525232474706d64283525252026292a2a2a2a2a2c3c25262004400000101018500748484844252a2b2000012025282a2a2a2a2a2a2a2a2
e2f1010101010101010192a2a2e2f20101010101010101d1e1e1e252525252526241516142026200a0d5140052e64252525252c2a2b200650012835282b200c6
00133392a2c2525252525262474792a2c252525283526205c3c2c282c252525262000017271222320101750000004202c2c2a2a2c2525252c2c3c2c282c2c382
52e2e1e1e1e1e1e1e1a2c3c25252e2e1e1a2a2a2a2a2e1e2e25252525252525262000000425262e5e5e614005552428352525252c2c2a2a2a242525252c2a2a2
a2a2a2c3c2c3525252525252a2a282c252525252525262055252525252525252522222222202528322222232000042525252c282525252525252c35252525252
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
00000000000000000000000000000000260000000031335d6f00000000000031267f4d4d4c4d4f0000000040416d5525336e7f0000005d5e410000555f305800337e7e6e3725254100000024202525252023141500306e537e7e24202b10102426000000101000001324252526410024252526404141414141242025267f0000
0000000000000000000000005d5f0000267601000000586d255f000000004748260000004e00000000000041006d25257e5f0000005d6e25410000256e3700000000007d6e256e4100000024382525252526000000377f00000031383c2a2a3c26101010292b1200132420323300002425252641000000000031322526000000
000000000000292a2a2b005d256f00003823141621235d256e6f006000005700330000004e00000000000041006d6e2500000000007d7e5541000025255f4748000100006d5625555f0000503c2525252526000000000000000073312c282525264041415051120013313375000000243238264100000000006e253133000000
2b0000010000502c2c2c2a2b25255f002526005d24266d6e256f6c6c000057000000005d5b5e5f00000000006d555525000176717200007d4100006e256f575d222223006d666e256f6000502525252538265f00000000000000755f502c252526410000243b0000000000000000002400313341000000000055566f00000000
2c2a2b1416292c2525252c2c2222222a20265b6e2438222a2a2a2a2a2a22222200005225256e255e5200000f6d6e2525231416292b0000002122222a2a2a2a2a202538222a2a2a2a2a2a2a2c252525252526255f700000000000006e503c25252641000037730000000000000000002400007d6e252122222325666f76717200
2528510000502c252525252538252528382655252425382c3c252c28383825200060016d2525557f0000005d25252525265f0050515f0000243825252c252c3c252525252c253c25282c3c252525252525202222237000000100600050252525260000000073000000000010101010240001006d552425252522222222222222
2525510000502c252525252525202525252625552420252525252525252525252222231415256f000000006d6e25552526255e50516e5f00242025252525252525252525252525252525252525252525252525203822231415162122282525252600000000740000005d56292a2a2a3c22222222222525202525252525252525
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
