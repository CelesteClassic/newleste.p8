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
stars_active=true
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

fall_plat={
  init=function(_ENV)
    while right()<lvl_pw-1 and tile_at(right()\8+1,y/8)==67 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()\8+1)==67 do
      hitbox.h+=8
    end
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
    local r,d=x+hitbox.w-8,y+hitbox.h-8
    for i in all{x,r} do
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
    palt(0,true)
  end

}
-- <touch_switch> --
touch_switch={
  init=function(_ENV)
    off=2
  end,
  update=function(_ENV)
    if player_here() and not collected then
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
    while right()<lvl_pw-1 and tile_at(right()\8+1,y/8)==72 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()\8+1)==87 do
      hitbox.h+=8
    end
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
    for i=x+8,r-8,8 do
      for j=y+8,d-8,8 do
        rectfill(i,j,i+8,j+8,1)
      end
    end

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

dream_blocks_active=true
dream_block={
  init=function(_ENV)
    layer=3
    while right()<lvl_pw-1 and tile_at(right()\8+1,y/8)==65 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()\8+1)==65 do
      hitbox.h+=8
    end
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
    disp_shapes={}
    outline=false
    xsegs={}
    ysegs={}
    for i=1,2 do
      local seg={{x},{x+4}}
      local x_=x+10+flr(rnd(6))
      while x_<right()-4 do
        add(seg,{x_,rnd(3)+2,rnd(3)+2})
        x_+=flr(rnd(6))+6
      end
      if seg[#seg][1]>right()-8 then
        seg[#seg][1]=right()-4
        seg[#seg][2]=nil
      else
        add(seg,{right()-4})
      end
      add(seg,{right()})
      add(xsegs,seg)
    end
    for i=1,2 do
      local seg={{y},{y+4}}
      local y_=y+10+flr(rnd(6))
      while y_<bottom()-4 do
        add(seg,{y_,rnd(3)+2,rnd(3)+2})
        y_+=flr(rnd(6))+6
      end
      if seg[#seg][1]>bottom()-8 then
        seg[#seg][1]=bottom()-4
        seg[#seg][2]=nil
      else
        add(seg,{bottom()-4})
      end
      add(seg,{bottom()})
      add(ysegs,seg)
    end
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
      if dash_target_y==-1.5 then
        dash_target_y=-2
      end
      if dash_target_x==0 then
        dash_target_y=sign(dash_target_y)*2.5
      end
      if dash_target_y==0 then
        dash_target_x=sign(dash_target_x)*2.5
      end
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
      if #disp_shapes!=0 then
        local d,dx,dy,ds=displace(disp_shapes, px,py)
        d=max((6-d), 0)
        px+=dx*ds*d
        py+=dy*ds*d
      end

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

    color(7)
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

    for i=y,bottom(),hitbox.h-1 do
      -- line(x+1, i, right()-1,i)

      local segs=xsegs[i==y and 1 or 2]
      for idx,seg in ipairs(segs) do
        if idx==#segs then
          break
        end
        lx,rx=seg[1],segs[idx+1][1]
        local ly,ry=i+(i==y and -1 or 1)*calc_seg(seg), i+(i==y and -1 or 1)*calc_seg(segs[idx+1])
        local m=(ry-ly)/(rx-lx)
        for j=lx,rx do
          local py=round(m*(j-lx)+ly)
          if #disp_shapes==0 then
            pset(j,py,outline_color)
          else
            local d,dx,dy,ds=displace(disp_shapes,j,py)
            d=max((4-d), 0)
            pset(j+dx*d*ds,py+dy*d*ds,outline_color)
          end
          if py!=i then
            line(j,py+sign(i-py),j,i,0)
          end
        end
      end
    end

    for i=x,right(),hitbox.w-1 do
      -- line(x+1, i, right()-1,i)

      local segs=ysegs[i==x and 1 or 2]
      for idx,seg in ipairs(segs) do
        if idx==#segs then
          break
        end
        ly,ry=seg[1],segs[idx+1][1]
        local lx,rx=i+(i==x and -1 or 1)*calc_seg(seg), i+(i==x and -1 or 1)*calc_seg(segs[idx+1])
        local m=(rx-lx)/(ry-ly)
        for j=ly,ry do
          local px=round(m*(j-ly)+lx)
          if #disp_shapes==0 then
            pset(px,j,outline_color)
          else
            local d,dx,dy,ds=displace(disp_shapes,px,j)
            d=max((4-d), 0)
            pset(px+dx*d*ds,j+dy*d*ds,outline_color)
          end
          if px!=i then
            line(px+sign(i-px),j,i,j,0)
          end
        end
      end
    end

      for i in all{x+1,right()-1} do
        for j in all{y+1,bottom()-1} do
          pset(i,j,outline_color)
        end
      end
  end
}


function create_disp_shape(tbl,x,y)
  add(tbl, {x,y,0}) --x,y,r
end

function update_disp_shapes(tbl)
  for i in all(tbl) do
    i[3]+=2
    if i[3] >= 15 then
      del(tbl, i)
    end
  end
end

function displace(tbl, px,py)
  local d,ds,pox,poy,s = 10000,0,0,0,0
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
      --replace mapdata with hex
      for i=1,#mapdata[lvl_id],2 do
        mset(i\2%lvl_w,i\2\lvl_w,"0x"..sub(mapdata[lvl_id],i,i+1))
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
  if stars_active then --stars_active is star condition, should probably set it somewhere
  	for dy=stars_falling and -4 or 0,0 do
	    foreach(stars, function(c)
	      if stars_falling then
	        pal(7,6)
	        pal(6,12)
	        pal(13,12)
	      end
	      local x=c.x+draw_x
	      local y=c.y+draw_y
	      local s=flr(sin(c.off)*2)
	      local _y = y+dy
      	local _s = _y<y and s-1 or s
      	if _y~=y then
      		pal(7,1)
       		pal(6,1)
        	pal(13,1)
      	else
      		pal(7,6)
       		pal(6,12)
        	pal(13,12)
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
		        c.y=rnd(120)
		      elseif c.x<-8 then
		        c.x=128
		        c.y=rnd(120)
		      end
		      if stars_falling then
		        c.y+=c.spdy
		        if c.y>128 then
		          c.y=-8
		          c.x=rnd(120)
          c.spdy=rnd(0.75)+0.5
		        end
		        pal()
		      end
		    end
	    end)
	  end
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
-->8
--[map metadata]

--@conf
--[[
autotiles={{52, 54, 53, 39, 33, 35, 34, 55, 49, 51, 50, 48, 36, 38, 37, 32, 29, 30, 31, 41, 42, 43, nil, nil, nil, nil, nil, 56, 45, 46, 47, 80, 44, 81, [41] = 61, [42] = 62, [43] = 63, [0] = 48, [44] = 57, [45] = 58, [46] = 59, [56] = 40, [57] = 60}, {122, 124, 123, 121, 29, 31, 30, 119, 61, 63, 62, 120, 45, 47, 46, 48, 52, 53, 54, 32, 41, 42, 43, nil, nil, nil, nil, 39, 33, 34, 35, 56, 80, 44, 81, nil, nil, nil, nil, 48, 36, 37, 38, [45] = 57, [46] = 58, [47] = 59, [52] = 55, [53] = 49, [0] = 29, [54] = 50, [55] = 51, [57] = 40, [58] = 60}, {41, 43, 42, 41, 41, 43, 42, 57, 57, 59, 58, 80, 80, 81, 44, 44, 48, 52, 53, 54, 32, 56, nil, nil, nil, nil, nil, 60, 39, 33, 34, 35, 29, 30, 31, nil, nil, nil, nil, 40, 48, 36, 37, 38, 45, 46, 47, [53] = 49, [54] = 49, [55] = 50, [0] = 41, [56] = 51, [57] = 61, [58] = 62, [59] = 63}}
param_names={"badeline num", "comment"}
composite_shapes={}
]]
--@begin
--level table
--"x,y,w,h,exit_dirs,badeline num"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
levels={
  "0,0,3,1,0b0100,0,spikes on ground need fixed or sparky's going to have a meltdown (g: maybe fixed?) ; need to figure out what's gonna happen to the berry if doing level duplication stuff",
  "0.3125,-2.0625,1.1875,2,0b0010,0,built for branching paths, reworked!",
  "0,1,1.25,1,0b0010,0,0",
  "1.5625,1,1,1,0b0010,0,perhaps shorten middle right wall by 1px to make it slightly easier",
  "2.5625,1,2,1,0b0010,0,my old notes said needs tweaking (terrain/spacing), but it seems fine",
  "4.6875,0.5,1.3125,1.5,0b1000,0,mirror room- needs mirror; terrain should be made more \"cavernous\",need to fix player spawn in cam trigger",
  "1.5625,4.25,1.4375,1.3125,0b1000,0,0",
  "1,2,2,1,0b1001,0,the first half could maybe be slightly tweaked",
  "3.375,4.375,1.1875,2,0b1000,0,built for branching paths, reworked!",
  "0,2,1,1,0b0001,0,should you be able to land on the left dreamblock?; diag (instead of wj updash) is currently an option, but it might be fine",
  "0,3,3,1,0b0001,0,spikes on ground need fixed or sparky's going to have a meltdown (g: maybe fixed?) ; need to figure out what's gonna happen to the berry if doing level duplication stuff",
  "7,0,1,1,0b0001,0,works with or without badeline",
  "8.1875,2.1875,1,1,0b0001,1,0",
  "4.875,-5.0625,1,1,0b0001,1,0",
  "5.9375,-4.1875,1,1.4375,0b0001,2,terrain is a bit weird?; especially given where it is in the progression",
  "3.5,-2.5,1,1,0b0010,1,0",
  "4.5,-2.5,1,1,0b0001,2,0",
  "5.5,-2.5,1,1,0b0010,1",
  "6.5,-2.5,1,1,0b0001,2,0",
  "7.5,-2.5,1,1,0b0001,3,difficult balance between awkward dream block placements and relative cheese freeness. not sure it's quite there yet",
  "8.5,-2.5,1,1,0b0001,1,0",
  "9.5,-2.5,1,2,0b0010,2,where this fits in the progression should be considered",
  "10.5,-2.5,2,1,0b0010,1,0",
  "12.5,-2.5,3,1,0b0010,2,0",
  "15.5,-2.5,1,2,0b0010,1,more badelines could be added to make it feel more intense. could perhaps be tweaked a bit?",
  "7,1,1,2.0625,0b0101,2,0",
  "6,0,1,4,0b0100,4,2nd berry is too hard, while being too easy to collect and tank (add a roundabout?); badeline num seems maybe excessive; probably need to nerf length/ending; move block should go somewhere less in the the way/ending is a bit wacky and tight. also the spikes on the right wall in the middle suck",
  "5.0625,4.0625,2,1.5,0b0010,0,exiting the tower portion, after the final badeline room",
  "8.5,4.75,3,1,0b0010,0,walk to phone booth",
  "11.5,4.3125,1,1,0b0010,0,phone booth (no sprite for it yet)",
  "3,0,1,1,0b0010,0,memorial room (missing sprite)",
  "3,2,3,1,0b0010,0,awake ver - main corridor",
  "3,3,3,1,0b0010,0,awake ver - walk to phone booth"
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
  {}
}
--</camtrigger>--

--mapdata string table
--assigned levels will load from here instead of the map
mapdata={
  nil,
  "252525252525252f0000002d252525252525252525252525252e3f0000003d2e252525252525252525252e3e3f00000100003d3e2e2525252e2525252e2f0000000000000000002d252e25253e3e3e3e3f0000000000000000003d3e3e2e2e00404141410000000000000000007573732d2e00410000000000000000000000000073752d2e00410000000000000000000000000074002d2e1e1e1e1f000000000000000000000000002d2e25252e2f000000000000000000000000002d2e2525252f141515000000000000000000002d2e252e3e3f00000000000000001d1f1415163d2e252f000000000000000000002d2f000000003d252f0000001d1f404141411d2e2f0000000000252f0000003d2f410000003d2e2f0000740000252f000000007700000000003d2e1f60740060252e2b000000000000000000003d2e1e1e1e1e252e2c2a2b000000000000000000392c2c2e25252e2e2c5100000000000000000000502c2d2525252e2e2e1e1f1415000000000000393a2d25252e3e3e3e3e3f101010101010000000002d25252f0000004041414141414141000000002d252e2f000a004100000000000000000000002d252e3f0000004100000000000000000000002d252f120000001d1e1e1e1e7c0000000000002d2e2f120000003d3e3e3e3f000000000000003d3e2f1200000000000000000000000000000000002f1200000000000000000000000000000000002f1200000000000000000000767172600000002f120000000000000000001d1e1e1e1e1e1e1e2f120000000000000000002d2e2e2e2e2e2e2e2f120000000000000000002d2e2e2e2e2e2e2e",
  nil,
  nil,
  nil,
  nil,
  "252525252525252525252525252e3e3e3e3e3e2e2525252525252525252525252525252e3f6e257f00003d2e252525252525252525252525252e2f55256f0a0000002d252525252525252525252525252e2f2556255e5f00002d2e25252525252e2e2525252525252e1f6655256e5f1d252525252e3e3e3e3e2e25252e2e25252f40414141412d2e25252e3f737300753d3e3e3e3e2e252f41000000003d3e2e253f007573000000000000003d3e2f410000000000002d250000007400000000000000004e7741000000004d4d2d2e0000000010101010100000004e0041000000004f002d2e00000000404141414100606c4e704100000000005d3d2e1e1f140041000000004d4d4c4d4d4100000000006d6e2d2e2f0000410000000000004e0000410000005d5d25253d253f0000410000000000004e0000410000006d25557e6e2f000000000000000000004e1d1f410000006d557f006d2f100000000000000000292a2e2f410000006d6f01006d252b00000000000000292c3c252e1e1e1e1e1e1e1e1e1e2c51101010101010105025252525252e2e252e25252e2e25282a1e2a2a1e1e2a28252525252525252525252525252525252c3c252c2e3c25252525252525252525252525252525252525252525252525252525252525252525252525",
  nil,
  "252525252525252f0000002d252525252525252525252525252e3f0000003d2e252525252525252525252e3e3f00000000003d3e2e2525252e2525252e2f0000000000000000002d252e25253e3e3e3e3f0000000000000000003d3e3e2e2e00404141410000000000000000007573732d2e00410000000000000000000000000073752d2e00410000000000000000000000000074002d2e1e1e1e1f000000000000000000000000002d2e25252e2f000000000000000000000000002d2e2525252f141515000000000000000000002d2e252e3e3f00000000000000001d1f1415163d2e252f000000000000000000002d2f000000003d252f0000001d1f404141411d2e2f0000000000252f0000003d2f410000003d2e2f0000740000252f000000007700000000003d2e1f60740160252e2b000000000000000000003d2e1e1e1e1e252e2c2a2b000000000000000000392c2c2e25252e2e2c5100000000000000000000502c2d2525252e2e2e1e1f1415000000000000393a2d25252e3e3e3e3e3f101010101010000000002d25252f0000004041414141414141000000002d252e2f000a004100000000000000000000002d252e3f0000004100000000000000000000002d252f120000001d1e1e1e1e7c0000000000002d2e2f120000003d3e3e3e3f000000000000293d3e2f120000000000000000000000000000503c2c2f120000000000000000000000000000502c3c2f1200000000000000000000767172292c3c2c2f120000000000000000001d1e1e1e1e1e1e1e2f120000000000000000002d2e2e2e2e2e2e2e2f120000000000000000002d2e2e2e2e2e2e2e",
  nil,
  nil,
  nil,
  "252538323220252525252026556d7f24203233256e313220253832337e00002426252525557e7e31323340410000002426256e7e7f000073000041000000602426557f00000000740000410000151624266f0000000000000000410000000024266f0000000076000000410000000024267f00000021234f0000410000006c24260000000024334d5d5e2123105c4d242023141500306e537e7e24202b1010242526000000377f00000031383c2a2a3c2526000000000000000073312c28252538265f00000000000000755f502c25252526255f700000000000006e503c25252520222223700000010060005025252525252520382223141516212228252525",
  "2525252525252525252033736d6e31252525252525252525383311737d7e7e2425382525252525252611007500717224203232202525252526000000002122202611113138252520261415151624382526000011313232323300000000313225266c00004041007300000f0000751324264d4f00410000740000000000001324264f00004100000000001010000013242600005c41000000001321235f0010242600000041001010101024267f0021382600000021222340414124265d5d24252600000024382641000031335d6e24252660010024252600000040415e55242026141516242026000a5d4100256e2425260000002425265e5e6e410055252438",
  "00000000000000000000002426252524000000000000000010101024264041240000001010101010292a2a24264100240000003422353535323a3a3a33410024000000003011111100007d7e252525241000000030120000000000007d7e7e242b10101030120a0010100000001010242c2a2a2a26120000212310101021223825283a382612000024264041412420253c3b6e313312000031264100003138255155256f00000000003741000000242551256e255f0000000073007573003138262525556f0000000073000f73001324262556557f0000000073000074001324266e667f75000000007400000000133126141627000000007000000000000000265f0030000000004e00000000000000266e5f30000000004e0000000000000026255537101010004e0060000000000026557e40414141704e5c4c4f6c000010267f4e410000004d4c4d4e6c6c01002126004e11111111004e004e271415162426004e00000000004e004e3000000024",
  "001010503a3a32323232323232323238102935336d256e257e7e7e25556e2524223b73006d25257f0000007d7e7e6e24260073007d556f000000000044006d2426007300006d6f00000034353535222026007500007d7f00000000730073313826000015162123000000007300740024260000000024265d0000007400000024260000000024266d5f00000000000024260000000031335d6f00000000000031267601000000586d255f0000000047483823141621235d256e6f0060000057002526005d24266d6e256f6c6c0000570020265b6e2438222a2a2a2a2a2a222222382655252425382c3c252c283838252025262555242025252525252525252525",
  "252520261200001350282c25252525252525253312000013393a3c2c282525252538267f000000000073393a3a32382520323300101010100075007300002425266f7300404141410000007300002420265b7300410000000000007500102425265b7400000000000000000000213825266f0070000000000000000000313238266f4d4c4f6c000000000010102e2537267f4d4d4c4d4f0000000040416d5525260000004e00000000000041006d2525330000004e00000000000041006d6e250000005d5b5e5f00000000006d55552500005225256e255e5200000f6d6e25250060016d2525557f0000005d252525252222231415256f000000006d6e255525",
  "3825323232323232323232323220252532337e7f00737500404141256e312525256f0000007400004100007d7e252425556f44000000000041000000447d2438256e5f0000000000410000000000242522222222360070004100000000102420252032334d4d4c4d4100005f0021382525335f7300004e004100006f0024252526256f745c4d4e004100006f00243232336e7f0000005d5e410000555f3058007e5f0000005d6e25410000256e37000000000000007d7e5541000025255f4748000176717200007d4100006e256f575d231416292b0000002122222a2a2a2a2a265f0050515f0000243825252c252c3c26255e50516e5f002420252525252525",
  "2600000031323232323232323232323826474848000000000000000058007324265700000044006c000000000000732426575d5e5f00006c6c00600000007324265e256e212222223514151627007324265525252425323300004400370073242625252524330075000000007300732426252555305f000000000000737473242625252530255e404141412122222238337e7e6e3725254100000024202525250000007d6e256e410000002438252525000100006d5625555f0000503c252525222223006d666e256f60005025252525202538222a2a2a2a2a2a2a2c25252525252525252c253c25282c3c252525252525252525252525252525252525252525",
  "2526000024382532322025252525252538260000243233111124382532382525322600003700000000313233112420250037000073000000007300730024252500750000731010100073007300312525000000007340414100730074000024381010000073410000007400000f0024202a2b1010731111110000000000002425282c2a2b105b5b5f00101010005d24252525252c2b7e25255b4041415b2524252525252551007d7e7e41007e6e2524202525252851007373001111117d7e24252525252c260073740000000010102425252525252610747400000000212238252525252520237474000001002420252525252525253822231415151624252525",
  "252647484831203232322032322520253826575d5f00301275133073733132322526006d6f003712441337737300007525265d6e255f00000000007374004400382625256e7e54000000007500767172202655257f730000000000000034222225267e7f00730000000000000000243825265873007400101010000000003125382600740000004041415f0000006d312033000000005d4100006f0000006d552600000000006d5525256e5f44007d6e2600000000006d6e2525256f0000006d26000000005d25255525557f0000606d26010000212a2a2a2a2a2b101010212226141621203c2c28252c3c222222203826000024252525252525252520252525",
  "0000000000005d5e25292c3c202538250000001029223535353a3a3232323232001010292c33750058007d7e256f474813342a2c51000000000000007d7f57000073312833000000007671720060575d00750030000000002122231415162122101010305f00000024252640414124382a2a2a516e5e5e5f313826410000242532322051255655255e2426410000242000733133556625256e242641000024380074004041414141253126410000242500000041000000007f003041000024256044004100000000000030410000242522223641000000005f0030410000242525330041000000006f443041000024202600004100000000255f3041000024253300004100000000342226410000243800000041000000006e3126410000242000000041000000007f73304100002425000000000027730000733041000024250000004400307300007530410000243800001717173073000000304100002425000000000030424343433041000024251010101010304300000030410000242522222235353300005d5e304100002425253233556f0000006d5530410000243826256e257f0000007d2537410000243826557e7f00000000007d7e6e25252425267f01006c6000000000006d25552425261415162123000000005d2555252425265e5f002426101010102122222238252625255e243822222222252520252525",
  "252525252525253825252520252525252525202525252525323232202525252525253825202525323232203232322025252532323825202660007d31382525202532323232202640414130000000242525261111313232334d4f006d312032322600730073313341000030004400242038261200007d256f0000007d7f30586d330073007500004100003700000031323226120000447d7f000000000037007d0000730000000041000000000f0040414130120000101010101000000000474800007500000000410000000000004100003012000040414141410000000057000000000000000041000000000000410000371200004100000000000070163422600000000000004100000000000041000000000000410000000000704e0000246c000000000000410000000000004100000000000041000000004d4d4c4d4d246c016c00000000410000004b000041000000004b00007300730000004e60002422222300000000007375006d5f00410000005d6f000073007400005c4d4d4d2420252610101000007300006d6f00410000006d6f000073000000000000000050252538222223120075005d6e6f0000292b106d255f0074004b00000000001050252525253826100000006d25255f10503c2b2525555e54005b0000000010292c252525252520230000006d25556f293c28515525256f00006d5f000000293c25",
  "32323a3a3a2c2600002425253820252526255f00242525203825252c5100000000243825323232382525203c252525250000007d553928222220323232323225382222223825323232322025282a2b00602425336e737e242532323a3a2c2525000000007d25503c2526557f00007d3132252525253325257e73313238253c2a2225266f7f74003133007d7e25393c2500010000006d502520337f000000007d6e24253833257e7f00737d54313225252c25267f00000040410000737d6e503c22230000007d242826750000000000007d2425266e557f00007400007d252425253826000000004100000073007d242820330000000024202600000000760000002420337e00000000000000007d2425253233000f0000410000007500003125260000000000243826000000212300000031337f000000000f00000000002420334041000000004100000000000075312600606c00002425265c4c4d312600000040410000000000000000000000242600410000000013212300000000000000264d4c4d4f003132334d4f00133000000041000000000000101010006c00243300410000000013242600000000000000264d4d4f00004041410000001330000000410000000010102122235c4c4d3775004100000000132426000000007172002600000000004100000000001337000000410000000021223820334d4f000000004100000000132426000000002122222600000000004100000000000073000000410000000031202526750000000000004100000000132426000000003138252600000000004100000000000074000000410000000073242526101000000000004100000000102426000000006d2425261010000000410000000000000000000000000000007524253c2a2b000000000000000000132125261000005d6e2438282a2b5f00000000000000000000000000000000005d5e2425252c515f000000000000000013242025235f005d252420252c51255f00000000000000000000000000005d5e25552438252551255e5f0000000000001324252526255e25252425",
  "6c0000000000404141412425252525256c6c01006000410000003438252525252222222a2a2b41000000553425252025382528252c5141000000252524203238252525253c5141000000256e34336e2425252525205141000000557e7f006d24252525253c26410000007f0073006d2425252532382641000000000075007d242520335524264100000000004400002425266e253126410000000000000000502526257e55304100000000000000005038266f757d304100000000000000005025267f440037410000000000101010502526000f0000410000001010292a2a2820330000000041000000292a3c252c255100000000004100000050282525252551000000000021222a2a2c25252525255100001010102420253c252525252525510000342222323232323825252525255100001131334041414131202525252551000000111141000000553125252525266c0000000041000000252524252520264d4c44000041000000255524383232264d4d4c4f004100000025253126585e2600004e0000410000006e2525305d252600004e000041000000256e7f30256e260000000000410000007e7e75377d7f26100000000041000000007300004748382b1010100041000000007500005700252c2a2a2310410000000000000057002525252c20234100000060717276570025252525252641000000212222222222",
  nil,
  nil,
  "2525260000000024252525252525252525252525252525253325252525252525252526000100002425253225252525252525252532323233252555252525252525252600000000242533112425252532323232332525252525252525257e7e7e252526000000002426110024252533252525252525552525252525257f7373002525260000000024260000242526252525252525252525252525257f0073730025252600000000313300002425265525252525252525252525256f000073730025252600000000737300003125262525252525252525252525556f0000737300252526000000007473000000242625252525557e7e25252525256f000073730038252600000000007300000024337e7e7e256f00736d252525257f00000073002525262b000000007400000037110000736d6f00746d2525256f606000007500252525232b0000000000000011000000737d7f00006d2555256f4d4c4f0000003232252522230000000000000000000073000000006d25257e7f4d4f000000000000313232322b00000000000000000073000000006d256f0073000000000000000000000000502b000000000000000074000000006d256f00730000000000001000000000005051000000000000000000000000006d257f007300000000000023000000000050282b0000000000000000000000007d7f0000730000000000002600000000292c3c5100000000000000000000000000540000730000000000003314151516502c253c2b0000000000000000000000005d0000730000000000000000000000503c253c2c2a2b00000000000000000000000000740000000000000000000029283c25253c282c2b00000000292a2b000000000000000000000000231010292c3c2525252525252c2a2a2a2a2c3c517060007470000000292a2a2a3c2314162425252525252525253c283c2c3c25282a2a2a2a2a2a2a2a2c2c3c2828260000242538252525252025252525252c25253c283c2c2c2c2828252525253c51000024252525252538252525252525252525252525252525252525252525",
  "000000000000000010242625252525252524252600000000000000000000000000006d6e25252525257f0000000000000000000000000000212526252525256e2524253300000000000000000000000000007d7e7e6e25256f7300000000000000000000000000002425267e6e2525252524260000000000000000000000000000000073006d25256f740000000000000000000000000000242526106d25257e7e24260000000000000000000000000000000074006d256c6f000000000000000000000000000000312525237d6e6f000031330000000000000000000000000000000000006d6c6c6f00000000000000000000000000000000242526007d7f000011110000004041414141410000000000000013222222222223000000000000000000000000000000242526000000000000000000004100000000000000000000000013313232323226404141292a2a0000000000000000003132330000000000101000000041000000000000000000000000006d2525256e37410000503c2800000000000000404141414141410000002123000000002122222300000000000000005d6d252525256f410000502c2500000000000000410000000000000000003133000000003132323300000000005d5b5e2525252525256f410000503c2500000000000000410000000000000000006d6f00000000292a2b00000000005d6e5625252525256e256f000000392c2500000100000000000034222223000000006d6f00000000502c5100000000006d60667671726c762525255f000000503c2a2a2a2b000000000000242526000000006d6f0000292a282c3b00000000007d21222222222223252525255e5e5e502c2c2c2c51000000000010242526000000006d6f0000502c3c510000000000000024382525252025232525252525292c252525252c2a2b005600213825282b006c006d6f292a2c25252c2b00000000292a2c252525382525282a2a2a2a2a3c2525252525252c2c2a2a2a242525252c2a2a2a2a2a3c2c3c2525252c2a2a2a2a282c25252525252525253c2c2c282c252525",
  "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d5e5f000000000000000000000000006d256f000000000000000000000000006d256f00000000000000000000005d5e25256f00000000000021230000006d252525255f000100000024382300006d252525256f2a2b0000212025282a2a2a2a2a2a2a2a2c2c2a2a2c2525252c3c2c2c282c3c2825252c282525252525253c2525252525"
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
    reserve..=num2hex(mget(i%w,i\w))
  end
  printh(reserve,"@clip")
end

--convert mapdata to memory data
function num2hex(v)
  return sub(tostr(v,true),5,6)
end
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
f2e652d3e3e25252e2e3e3e3e3e3e3e2e3e3e3e3e3e3e3e2e25252e2e3e3e3e3e25252e2e3e3525252525252e2e3e3e302525252835252525252525252525252
0252525252232323235252835252525252525252835252525252525252330000525262010100000000000300000042835252620101000000030000000000d742
f255525552d3e3e3f255525252e652d3e752e652f700d7d3e3e2e2f3f737d7e7d3e2e2f352e6d2e252e2e3e3f3e7e7e723235252525252525252232352525252
52528352333737d7524283525202525252525252525252525252232352620000525282a2b200000001010300000142525252c3a2b20101010300717100000042
f3e75252e7e7e7e68752e6e7e7e7e65500d752f6000000d752d2f2f600470057d7d3f2e6e752d2e3e3f30414f700000000001302525252525262525213525283
5252526200374737d61323232323232352520252525252525262003713330000525252521501010192a262d70043230252525252c2a2a2a26201010101000042
0037d7f7005700d78752f7010100d7521727d6f700000000d6d2f2f70000000000d787f6a0d78700573114000000000000000042525252525233e7e752425252
2323233300370057d6525252f6000042022323232323525252620037d6f6000052525252c2a2a2a252826252e5f73742525252525252c38202a2a2a2b2041442
004700370000000087f700a7c700f0d6e1f1f60000000000d7d2f20000006700000077f7000087c60031140000000010000000428352525262d4c4f4d6420233
0006000000470000d652e6e7f7000013330000d75252132323230037d6f600005252825283a3a3c3528362e7f70047425252525252525252528252c215140042
000000370004141487000004140000d7e2f2f7000000000000d2f20414d1f10000310414141487d4f43114000000d1e1000000425223232333d4f400d7426206
00c66700000000d55252f6373700000000000000d652f60037000057d6f600005202a3c362111105c32333000000004252022323835252520252520262111142
0101004700140000870000140000000052f300000101010000d3f31400d2f20000311400000077000031140000c4d2e2000000133337370037000000001333d4
c4d4c4f4000000d65252f6003700000000000000d652f70037000000d6f60000836211133300001333370000000000428333e752425202232323232333000042
b2b2010000000000770000d1f1010101f23700310414142100d6f61111d2f24100311400000037000000d1f1d4f4d252000000d6f65737003700000000d6f600
e400e400000000d65252f6005700000000000000d6f6000057000000d6f600005262e5e7f70000005737000000000042625700d742026252e7f7370000243442
c382b20000000000000000d2e2e1e1e1f23700311400002100d652f500d2f20000311400000037000000d2f20101d2e2000000d6f60037005700000000d6f600
e400e400000000d65552f6000000000000000000d6f6000000000000d6f600000233f60000000000005700000000014262000000132362f70000370000340042
52c2150000000000000000d252525252f25700311400002100d75552e5d2f20000311400000057000000d2e2e1e1e252000000d6f60057000000000000d6f600
e400e4000000d5525276f6000000000000000000d6f6000000004700d6f600006252f7000000000000000000000092c362041414000073243400470000340042
c252150000000000000000d3e3e25252f2000000370037000000d65252d2f20000311400000000000000d2e252525252000000d6f60000000000000000d6f600
e400e4000000d567528652f547000000000000d55212320000004747d6f6000062f6000000000024340000000000055262140000000000340000000000000042
52521500000000000000000000d25252f200000037f047000000d7e755d2f200d5e555e7e7f700000000d25252525252001000d6f60000000000000000d6f600
e400e40000d1e1e1e1222222320000000000d5e65242620000474747d692a2a262f7000000000034000000000000428262140000000000340000000000000042
52521501010000000000000000d25252f20000005700000000000000d7d2f2e5e6e7f700000000000000d2e252525252a2a2b2d6f60000000047060000d6f600
e400e4000042525252525283f24151516192a2b27213330092a2a2a2a2c2c3826200000001010000000000010101425262140000000000340000000000000642
525282a2b20100000000000000d25252f2010000000000000000010101d2f2e7f7000000000000010101d2e252525252c382c2a2a2a2b2004747c61727d6f692
a2a2b2416142835252525252f20000000005c282a2a2a2a2c2c382c3c2c352526200000092b2010000000092a2a2025262140000010100000000000000c5d405
525252c252b2172700100000d1e25252e2f1010101010101010192a2a2e2f20101010101010101d1e1e1e2525252525252525282c3c28222222222222222a282
c2821547c542525252520252f20101010105c352c38382525252525252c25252152434340552b2000001010552c352526214000012b201010101000000000042
52525252c282a2b241515161d252525252e2e1e1e1e1e1e1e1a2c3c25252e2e1e1a2a2a2a2a2e1e2e252525252525252525252525252525202525252528383c2
52c315d4d442525252525252832222222283c2525252525252525252525252521534000005c362000192a282232323026200000042c2a2a2a2b2010101010105
02525252836252f50013232323238352025252525223232323525283526201010101014283526200000000000000000000000000000000000142625252525252
52425262000000000000000000000000000000000000000000000000000000001500000005c26200432323330000004262000000425282c352c3a2a2a2a2a282
2323230252335552f50000d5525542525252835233e65252554283525202222222222222525262b20000b40000000000000000000000000012526252525252e6
524252330000000000000000000000000000000000000000000000000000000015000000138362000000670000a0004200000000000000000000000000000000
52e7e64262e6c65252e5e5e6525242835252526252e7e752524202232323235252520252525252c2b200b500000000000000000000000000425262e7e6525252
52426200000000000000000000000000000000000000000000000000000000006200000037132322222232000000004200000000000000000000000000000000
f600d64262c6c65565e652525512835223238362f73700d7551333f7000031420223232323235252c332b50000000000000000000000000042526201d65252e7
e7426200000000000000000000000000000000000000000000000000000000006200440047d75213232333717171714200000000000000000000000000000000
f700d642832222326652041414420233e752426200370000d6e6f6000000311333000000d7e613232323b2f500d5f500000000000000000013525232d7e6f600
0013330000000000000000000000000000000000000000000000000000000000620000000000d7e7f700570000d5e54200000000000000000000000000000000
0000d7425223230222321400004262f600d6133300470000d65252f5000000111100000000d652e7e7e605b200d6f60000000000000000000042526200d7f700
001111000000000000000000000000000000000000000000000000000000000062000000000000000000000000d6524200000000000000000000000000000000
000000133355521352621400001333f600d7f70000000000d7e652f6000000000000000101d7f700a0d60515d5e6f60000000000000000000042523300000000
000000000000000000000000000000000000000000000000000000000092a2a215010100000000000101000044d7524200000000000000000000000000000000
0000000000d7f600426214000052f700000037000000000000d655f600000000006700d13200000000d70582b25255f500000000000000000013330000000000
0000000000000000000000000000000000000000d5b5b5b5f50000000005c382c2a2b20101000000041400000000d74200000000000000000000000000000000
000000000000b6001362140000f60000000037000000070000d6e6f7000000000051614262c606000092c2c315e652f600000000000000000000000000000000
00000000000000000000000000000000000000d5d652e65252f500000005c25252c3235363000000140000000000004200000000000000000000000000000000
0000000000000000d773140000f600000000c60000d4c4d4d4d13200000000000000d5133341515161055252c3b2e65200000000000000000000000000000000
00000000000000000000000000000000d5b5e5525252525252f600123205c3525262c60000000000140000000000004200000000000000000000000000000000
00000000000000000000d752e6f600d5f50000000010e400d542f2010100000000d555f6000000000005c35252c2a2b200000000000000000000000000000000
00000000000000000000000000000000d6765252525252e60652f5133393c2520233d4f400000000140000000000014200000000000000000000000000000000
0000000000000000000000d65552e5e6f600000000d1f100d64252223200000000d652e6f500000092828252525252c200001000000000000000000000000000
00000000000092a2b2070000000000d5068667172706062222222222223205c36257000000000000000000000000128300000000000000000000000000000000
0000000000000000000000d652527652f606b40000d262d552425283f2000025e592a2a232010192c2c352a3c2525252a2a2a2b2000000000000222232000000
00010100009282c382223200470000d6122222222222321323232323233305c26200000000000000000000000000425200000000000000000000000000000000
a2a2b200000000000000d5e652558692a2a2b20101426252e6d25252f2000000d705c282c33241614282155593c38352c2c2c215000000000043425262000000
001232000005c25252525232474706d64283525252026292a2a2a2a2a2c3c2526200440000010101850074848484425200000000000000000000000000000000
c382c2a2a2b20000000012222222a282c28252222283f25552d20252f201010101935252526200d542521552e6420252525252c2a2b200650012835282b200c6
00133392a2c2525252525262474792a2c252525283526205c3c2c282c25252526200001727122232010175000000420200000000000000000000000000000000
52525282c3c2a22222228302520282c25252c2525252f2e652d25252832222e1e1c35252c315d5d4428362e65242520252525252c2c2a2a2a242525252c2a2a2
a2a2a2c3c2c3525252525252a2a282c2525252525252620552525252525252525222222222025283222222320000425200000000000000000000000000000000
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
202525253826255f003132323232382520252525253232323225253825261010101010243825260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002625257e24202525252025252532323825265f00242525202532322538252525
32323220253355255f00005d2555242525253825336e25255524382525202222222222222525262b00004b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000267e7f003132323232323232331111242026255f3132323233004e3132202525
257e6e24266e6c25255e5e6e2525243825252526257e7e252524203232323225252520252525252c2b005b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000260000000040414141414141000000242526404141414141414d4f007d242525
6f006d24266c6c55566e252555213825323238267f73007d5531337f0000132420323232323225253c235b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000267601000041000000000000000000242526410000000000005f600000313232
7f006d243822222366254041412420337e252426007300006d6e6f0000001331330000007d6e313232322b5f005d5f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000382222222222222222222222234f0024202641000000000000255e5f40414141
00007d2425323220222341000024266f006d3133007400006d25255f0000001111000000006d257e7e6e502b006d6f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002525252025253825202525382600002425264100000000000055256e41000000
0000003133552531252641000031336f007d7f00000000007d6e256f0000000000000010107d7f000a6d50515d6e6f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002032323232323232322525252640412425265525256e25212222222341000000
00000000007d6f002426410000257f000000730000000000006d556f000000000076001d23000000007d50282b25555f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000026257e7f00111111112425252641002425252222223535323238252641000000
0000000000006b0031264100006f00000000730000007000006d6e7f0000000000151624266c600000292c3c516e256f00000000000000000000000000000000000000000000000000000025252e25252525252e3e3e2e2e3e2e2e3e2e252525267f0a00000000001324382526410024252520323325256f0024253823257f00
00000000000000007d374100006f000000006c00004d4c4d4d1d23000000000000005d3133141515165025253c2b6e25000000000000000000000000000000000000000000000000000000252e3e3e3e2e2e3e3f257e2d3f003d3f753d3e2e2526000000101000001324252526410024252526404141414141242025267f0000
000000000000000000007d256e6f005d5f00000000004e005d242f1010000000005d556f0000000000503c25252c2a2b0000000000000000000000005d5f000000000000000000000000003e3f25256e3d3f7f7e7f007700000073007d252d2526101010292b1200132420323300002425252641000000000031322526000000
00000000000000000000006d55255e6e6f000000001d1f006d24252223000000006d256e5f000000292828252525252c000000000000292a2a2b005d256f0000000000000000000000000025552525557f0000000000730000007500006d3d2e264041415051120013313375000000243238264100000000006e253133000000
00010000000000000000006d252567256f604b00002d265d252425382f0000525e292a2a231010292c3c253a2c2525252b0000010000502c2c2c2a2b25255f0000000000000000000000006e2555256f000000000000740000000000007d252d26410000243b0000000000000000002400313341000000000055566f00000000
2a2a2b000000000000005d6e255568292a2a2b10102426256e2d25252f0000007d502c283c23141624285155393c38252c2a2b1416292c2525252c2c2222222a00000000000000000000001e1e1e1e1e1e1f0000000000000000000000006d2d2641000037730000000000000000002400007d6e252122222325666f76717200
3c282c2a2a2b00000000212222222a282c28252222382f55252d20252f101010103925252526005d242551256e2420252528510000502c252525252538252528000000000000000000000025252525252e2f7400000000000000000060701d2e260000000073000000000010101010240001006d552425252522222222222222
252525283c2c2a22222238202520282c25252c2525252f6e252d25253822221e1e3c25253c515d4d2438266e252425202525510000502c25252525252520252500000000000000000000002525252525252e1e1f00000000000000001d1e2e2e2600000000740000005d56292a2a2a3c22222222222525202525252525252525
3e3e3e2e2525252e3e3e3e3e3e2e252525252525000000000025252e3e3e3e3e3e3e3e2e2525253e3e2525252525252e2e2e3e3e3e2e2e2525252e252525252e3e3e2e252525252525000025252525252525252e1f404141414141412d2e2525265f00000000005d5e2566502c25282525252625252425253232322538252525
256e7e3d3e252e3f730073006d3d3e2e252e3e3e0000000000253e3f7f00000073007d2d2e3e3f000025252e2e3e3e3e3e3f5525253d3e3e2e2e3e3e2e252e3f6e252d2525252525250000252525252525252e252f410000000000002d252525266f0000101021222222222025252525253826257e2438330075002432323220
557f00006d2d3f00730074007d25552d3e3f6e2500000000002f7e7f00000f007400102d2f00000000252e3e3f6e252525557e256e7e7f733d3f55252d2e3f257e7e3d2e2525252525000025252525252e3e3e2e2f410000000000002d2e252526255e5e2122382025382525252525252525267f003133000000003700000024
6f0000007d78120073000000006d25785525255500000000002f10000000000000001d2e3f4f0000002e3f007d5525256e7f006d5f00007300006d6e2d2f556f00007d2d2525252525000025252525252f25253e2f410000000000002d3e25253835365524252525252525252525252520323300001340414141414100000024
6f0100000078120074001010007d6e777e7e25250000000000251f6c0000100000003d2f75000076002f1200007d55256f00006d5f60007300007d252d2f257f0f00002d2e25252525000025252525252f257e7e774100000000000077252d2526756d2524252525252525203225252526474800001341000000000000440024
1e1e7c000078120000001d1f00007d7f00007d6e0000000000252f4d4d4c794f000073780000007a1e2f120000006d7e7f00006d555f00740010006d2d2f7f000000002d2e2525252500002525252e2e3f7f00000041000000000000006d2d25260034353225252520252533112425252657000000000000275e5f0000000024
2e3f00000077120000002d2f000000000000006d00000000002e3f005c4d781000007578000f00132d2f12000f005b1010105d25256f00000079007d2d2f00000000002d252525252500002e3e3e3e3f7f0000000000000000000000007d2d252600000000342032323233000031382526570000010000002423255f00717224
2f006000000000000f002d2f000f00000000006d00000000003f000000003d1f005d5e77000000132d2f1200005d25292a2b6d55256f0000007800003d3f00000000003d2e2525252500002f7e7e7f00000000000000000000000000004e3d2e26607000000030257e7f00000013242526000021222222223820222222222238
2f4d4c4d4f00000000002d2f000000000015161d0000000000000000000013784f6d6f114b0000132d3f1200007d6e502c51256e7e7f000000785f000000000010006c002d2e3e2e2500002f6c600000000000000000000000000000004e002d252223000000307f0000000000132425265e5e31323232323232322520252525
2f4d4d4f00000000005d2d2f5e5e5f000000002d000000000000000000001378006d7e537f0000132d00000000007d392e2f7d6f4243430010786e5e5f000000794d4c4d2d2f253d3e00002f6c6c00000001000000000000000000005c4d4c2d25202600005d300000001000001324252625257e7f007300007d7e3132253825
2f000000000000005d6e2d2f256e7e540000102d0000000000010000000013785d7f0000000000132d000000000000132d3f006b43000000292f7e7e7f000010784d4d4d3d3f7e7f0000002f6c6c1d1e1e7c0000000000000000000000004e2d2525265e5e25304d4c4f271200002425267e7f00000074000000004e00242525
2f100000000000007d7e2d2f7e7f000000001d2e00000000001e1f00000013776f000000000000132d00000000000013780000004300005d502f14150000001d2f000000111100730000003f14162d2e2f000000001d1e1e1e1e1e1f006c1d2e252526252525375c4d4d30120000242526580000000000001000004e5c312025
2e1f00000000001010102d2f1000000000102d2500000000002e2f4f0000007d7e000000000010102d0000000000001377000000005d5e7f2d2f00000010102d2f100000000000740000006f00002d2e2f6c60001d2e2e252e252e2f766c2d2525382625257e7f0000003012005d2425260000000000005c27004c4f6c002425
252f10101010101d1e1e2e2e1f101010101d2e250000000000252f10101000000000000010101d1e2e0001000000000000000010006d7f10502f1010101d1e2e2e1f0000000076717200006f00002d252e1e1e1e2e2525252525252e1e1e2e25252526257f0000000000375d5e2524252676000000000000304d4d4d4d4d3120
252e1e1e1e1e1e2e252525252e1e1e1e1e2e2525000000000025251e1e1f1010101010101d1e2525251e1e1e1f10101010101079006b00292c251e1e1e2e2525252f101010101d1e1e0000255f742d2e25252e2e2525252525252525252525252538267f000000000000116d2525242020222300000000003000000000006d24
252525252e2e2525252525252525252e2e25252500000000002525252e2e1e1e1e1e1e1e252525252525252e2e1e2a2a1e2a2a5100000050252e252525252525252e1e1e1e1e25252500001e1e1e2e25252525252525252525252525252525252525260000000000005c277e7e7e242525252600001717003000000000006d24
