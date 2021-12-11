pico-8 cartridge // http://www.pico-8.com
version 34
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

--tables
objects,got_fruit={},{}
--timers
freeze,delay_restart,sfx_timer,music_timer,ui_timer=0,0,0,0,-99
--camera values
--<camtrigger>--
cam_x,cam_y,cam_spdx,cam_spdy,cam_gain,cam_offx,cam_offy=0,0,0,0,0.25,0,0
--</camtrigger>--
_pal=pal --for outlining

local _g=_ENV --for writing to global vars

-- [entry point]

function _init()
  max_djump,deaths,frames,seconds,minutes,music_timer,time_ticking,berry_count=1,0,0,0,0,0,true,0
  music(0,0,7)
  load_level(1)
end


-- [effects]

function rnd128()
  return rnd(128)
end

clouds={}
for i=0,16 do
  add(clouds,{
    x=rnd128(),
    y=rnd128(),
    spd=1+rnd(4),
    w=32+rnd(32)
  })
end

particles={}
for i=0,24 do
  add(particles,{
    x=rnd128(),
    y=rnd128(),
    s=flr(rnd(1.25)),
    spd=0.25+rnd(5),
    off=rnd(),
    c=6+rnd(2),
  })
end

dead_particles={}

--<stars>--
stars={}
for i=0,10 do
  add(stars,{
    x=rnd128(),
    y=rnd128(),
    off=rnd(1)
  })
end
stars_active=true
--</stars>--


-- [player entity]

player={
  layer=2,
  init=function(_ENV)
    grace,jbuffer=0,0
    djump=max_djump
    dash_time,dash_effect_time=0,0
    dash_target_x,dash_target_y=0,0
    dash_accel_x,dash_accel_y=0,0
    hitbox=rectangle(1,3,6,5)
    spr_off=0
    collides=true
    create_hair(_ENV)
    -- <fruitrain> --
    berry_timer,berry_count=0,0
    -- </fruitrain> --
  end,
  update=function(_ENV)
    if pause_player then
      return
    end

    -- <dream_block> --
    if dreaming and not check(dream_block,0,0) then
      dreaming=false
      spd=vector(mid(dash_target_x,-2,2),
                      mid(dash_target_y,-2,2))
      dash_time,dash_effect_time=0,0
      if spd.x~=0 then
        grace=4
      end
    end
    -- </dream_block> --

    -- horizontal input
    local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0

    -- spike collision / bottom death
    if is_flag(0,0,-1) or
	    y>lvl_ph and not exit_bottom then
	    kill_player(_ENV)
    end

    -- on ground checks
    local on_ground=is_solid(0,1)

        -- <fruitrain> --
    if on_ground then
      berry_timer+=1
    else
      berry_timer=0
      berry_count=0
    end

    for f in all(fruitrain) do
      if f.type==fruit and not f.golden and berry_timer>5 and f then
        -- to be implemented:
        -- save berry
        -- save golden
        berry_timer=-5

        berry_count+=1
        _g.berry_count+=1
        got_fruit[f.fruit_id]=true
        init_object(lifeup, f.x, f.y,berry_count)
        del(fruitrain, f)
        destroy_object(f)
        if (fruitrain[1]) fruitrain[1].target=_ENV
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
      jbuffer=4
    elseif jbuffer>0 then
      jbuffer-=1
    end

    -- grace frames and dash restoration
    if on_ground then
      grace=6
      if djump<max_djump then
        psfx(22)
        djump=max_djump
      end
    elseif grace>0 then
      grace-=1
    end

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
          psfx(18)
          jbuffer,grace,spd.y=0,0,-2
          init_smoke(0,4)
        else
          -- wall jump
          local wall_dir=(is_solid(-3,0) and -1 or is_solid(3,0) and 1 or 0)
          if wall_dir~=0 then
            psfx(19)
            jbuffer,spd=0,vector(wall_dir*-2,-2)
            -- wall jump smoke
            init_smoke(wall_dir*6)
          end
        end
      end

      -- dash
      local d_full=5
      local d_half=3.5355339059 -- 5 * sqrt(2)

      if djump>0 and dash then
        init_smoke()
        djump-=1
        dash_time,_g.has_dashed,dash_effect_time=4, true, 10
        -- vertical input
        local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
        -- calculate dash speeds
        spd=vector(h_input~=0 and
        h_input*(v_input~=0 and d_half or d_full) or
        (v_input~=0 and 0 or flip.x and -1 or 1)
        ,v_input~=0 and v_input*(h_input~=0 and d_half or d_full) or 0)
        -- effects
        psfx(20)
        _g.freeze=2
        -- dash target speeds and accels
        dash_target_x,dash_target_y,dash_accel_x,dash_accel_y=
        2*sign(spd.x), (spd.y>=0 and 2 or 1.5)*sign(spd.y),
        spd.y==0 and 1.5 or 1.06066017177 , spd.x==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()

        -- emulate soft dashes
        if h_input~=0 and ph_input==-h_input and oob(ph_input,0) then
          spd.x=0
        end

      elseif djump<=0 and dash then
        -- failed dash smoke
        psfx(21)
        init_smoke()
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
    pal(8,djump==1 and 8 or 12)
    draw_hair(_ENV)
    draw_obj_sprite(_ENV)
    pal()
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
  for h in all(hair) do
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    last=h
  end
end

function draw_hair(_ENV)
  for i,h in ipairs(hair) do
    circfill(round(h.x),round(h.y),mid(4-i,1,2),8)
  end
end

-- [other entities]

player_spawn={
  layer=2,
  init=function(_ENV)
    sfx(15)
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
    for i=1,#fruitrain do
      local f=init_object(fruit,x,y,fruitrain[i].sprite)
      f.target=i==1 and _ENV or fruitrain[i-1]
      f.r=fruitrain[i].r
      f.fruit_id=fruitrain[i].fruit_id
      fruitrain[i]=f
    end
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
          y,spd,state,delay=target,vector(0,0),2,5
          init_smoke(0,4)
          sfx(16)
        end
      end
    -- landing and spawning player object
    elseif state==2 then
      delay-=1
      sprite=6
      if delay<0 then
        destroy_object(_ENV)
        local p=init_object(player,x,y)
        --- <fruitrain> ---
        if (fruitrain[1]) fruitrain[1].target=p
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
    local hit=player_here()
    if hit then
      hit.move(dir==0 and 0 or x+dir*4-hit.x,dir==0 and y-hit.y-4 or 0,1)
      hit.spd=vector(
      dir==0 and hit.spd.x*0.2 or dir*3,
      dir==0 and -3 or -1.5
      )
      hit.dash_time,hit.dash_effect_time,delta,hit.djump=0,0,4,max_djump
    end
  end,
  draw=function(_ENV)
    local delta=flr(delta)
    if dir==0 then
      sspr(72,0,8,8-flr(delta),x,y+delta)
    else
      sspr(64,0,8-delta,8,dir==-1 and x+delta or x,y,8-delta,8,dir==1)
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
        psfx(12)
        init_smoke()
      end
    else
      offset+=0.02
      local hit=player_here()
      if hit and hit.djump<max_djump then
        psfx(11)
        init_smoke()
        hit.djump,timer=max_djump,60
      end
    end
  end,
  draw=function(_ENV)
    if timer==0 then
      spr(15,x,y+sin(offset)+0.5)

    else
      -- color(7)
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
    solid_obj,state=true,0
  end,
  update=function(_ENV)
    -- idling
    if state==0 then
      for i=0,2 do
        if check(player,i-1,-(i%2)) then
          psfx(13)
          state,delay=1,15
          init_smoke()
          break
        end
      end
    -- shaking
    elseif state==1 then
      delay-=1
      if delay<=0 then
        state,delay,collideable=2,60--,false
      end
    -- invisible, waiting to reset
    elseif state==2 then
      delay-=1
      if delay<=0 and not player_here() then
        psfx(12)
        state,collideable=0,true
        init_smoke()
      end
    end
  end,
  draw=function(_ENV)
    spr(state==1 and 26-delay/5 or state==0 and 23,x,y) --add an if statement if you use sprite 0
  end
}

smoke={
  layer=3,
  init=function(_ENV)
    spd,flip=vector(0.3+rnd(0.2),-0.1),vector(maybe(),maybe())
    x+=-1+rnd(2)
    y+=-1+rnd(2)
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
    if not target then
      local hit=player_here()
      if hit then
        hit.berry_timer,target,r=
        0,#fruitrain==0 and hit or fruitrain[#fruitrain],#fruitrain==0 and 12 or 8
        add(fruitrain,_ENV)
      end
    elseif target then
      tx+=0.2*(target.x-tx)
      ty+=0.2*(target.y-ty)
      local dtx,dty=x-tx,y_-ty
      local a,k=atan2(dtx,dty),dtx^2+dty^2 > r^2 and 0.2 or 0.1
      x+=k*(r*cos(a)-dtx)
      y_+=k*(r*sin(a)-dty)
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
     if sfx_delay>0 then
      sfx_delay-=1
      if sfx_delay<=0 then
       _g.sfx_timer=20
       sfx(10)
      end
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
    sfx(9)
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
    ?sprite<=5 and sprite.."000" or "1UP",x-4,y-4,7+flash%2
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
    states={}
    timer=0

  end,
  update=function(_ENV)
    local tr,states=tracking,states
    if tr.type==player_spawn and tr.state==2 and tr.delay<0 then
      for o in all(objects) do
        if o.type==player then
          bade_track(_ENV,o)
          tr=o
          break
        end
      end
    elseif tr.type==badeline and tr.timer<30 then
      return
    end
    if timer<70 then
      timer+=1
    end
    local sm={}
    for s in all(smokes) do
      add(sm,s)
    end
    smokes={}
    add(states,{tr.x,tr.y,tr.flip.x,tr.sprite or 1,sm})
    if #states>=30 then
      x,y,flip.x,sprite,sm=unpack(states[1])
      del(states,states[1])
      for s in all(sm) do
        init_smoke(unpack(s))
      end
    end
    if timer==30 then
      create_hair(_ENV)
    end
    if timer>=30 then
      update_hair(_ENV)
    end
    local hit=check(player,0,0)
    if hit and timer>=70 then
      kill_player(hit)
    end
  end,
  draw=function(_ENV)
    if timer>=30 then
      pal(8,2)
      pal(15,6)
      pal(3,1)
      pal(1,8)
      pal(7,5)
      draw_hair(_ENV)
      draw_obj_sprite(_ENV)
      pal()
    end
	end
}
function bade_track(_ENV,o)
  o.tracked=true
  tracking=o
  hitbox=o.hitbox
  local f=o.init_smoke
  o.init_smoke=function(...)
    add(smokes,{...})
    f(...)
  end
end

fall_plat={
  init=function(_ENV)
    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==67 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==67 do
      hitbox.h+=8
    end
    collides=true
    solid_obj=true
    timer=0
  end,
  update=function(_ENV)
    if not state and check(player,0,-1) then
      state = 0  -- shake
      timer = 10
    elseif timer>0 then
      timer-=1
      if timer==0 then
        state=finished and 2 or 1
        spd.y=0.4
      end
    elseif state==1 then
      if spd.y==0 then
        state=0
        for i=0,hitbox.w-1,8 do
          init_smoke(i,hitbox.h-2)
        end
        timer=6
        finished=true
      end
      spd.y=appr(spd.y,4,0.4)
    end
  end,
  draw=function(_ENV)
    local x,y=x,y
    if state==0 then
      x+=rnd(2)-1
      y+=rnd(2)-1
    end
    local r,d=x+hitbox.w-8,y+hitbox.h-8
    for i=x,r,r-x do
      for j=y,d,d-y do
        spr(41+(i==x and 0 or 2) + (j==y and 0 or 16),i,j,1.0,1.0)
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
    palt(0,false)
    palt(8,true)
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
    palt()
    pal()
  end
}
switch_block={
  init=function(_ENV)
    solid_obj=true
    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==72 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==87 do
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
        for i=1,2 do
          s.init_smoke()
        end
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
    for i=x,r,r-x do
      for j=y,d,d-y do
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
dream_block={
  init=function(_ENV)
    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==65 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==65 do
      hitbox.h+=8
    end
    kill_timer=0
    particles={}
    for i=1,hitbox.w*hitbox.h/32 do
      add(particles,
      {x=rnd(hitbox.w-1)+x,
      y=rnd(hitbox.h-1)+y,
      z=rnd(1),
      c=split"3, 8, 9, 10, 12, 14"[flr(rnd(7))]})
    end
    dtimer=1
    disp_shapes={}
    outline=false
  end,
  update=function(_ENV)
    --[[hitbox.w+=2
    hitbox.h+=2]]
    local hit=player_here()
    if hit then --could save a bunch of tokens by doing local this,_ENV=_ENV,hit, not gonna do it for now cause it's more confusing
      hit.dash_effect_time=10
      hit.dash_time=2
      if hit.dash_target_y==-1.5 then
        hit.dash_target_y=-2
      end
      if hit.dash_target_x==0 then
        hit.dash_target_y=sign(hit.dash_target_y)*2.5
      end
      if hit.dash_target_y==0 then
        hit.dash_target_x=sign(hit.dash_target_x)*2.5
      end
      if not hit.dreaming then
        hit.spd=vector(hit.dash_target_x*(hit.dash_target_y==0 and 2.5  or 1.7678),hit.dash_target_y*(hit.dash_target_x==0 and 2.5 or 1.7678))
      end
      if abs(hit.spd.x)<abs(hit.dash_target_x) or abs(hit.spd.y)<abs(hit.dash_target_y) then
        hit.move(hit.dash_target_x,hit.dash_target_y,0)
        if hit.is_solid(hit.dash_target_x,hit.dash_target_y) then
          kill_player(hit)
        end
      end
      hit.dreaming=true
      hit.djump=max_djump
      if dtimer>0 then
        dtimer-=1
        if dtimer==0 then
          dtimer=4
          create_disp_shape(disp_shapes, hit.x, hit.y)
        end
      end
    else
      dtimer=1
    end
    --[[hitbox.w-=2
    hitbox.h-=2]]--
    update_disp_shapes(disp_shapes)
  end,
  draw=function(_ENV)
    rectfill(x+1,y+1,right()-1,bottom()-1,0)
    foreach(particles, function(p)
      local px,py = (p.x+cam_x*p.z-65)%(hitbox.w-2)+1+x, (p.y+cam_y*p.z-65)%(hitbox.h-2)+1+y
      if #disp_shapes==0 then
        rectfill(px,py,px,py,p.c)
      else
        local d,dx,dy,ds=displace(disp_shapes, vector(px,py))
        d=max((6-d), 0)
        rectfill(px+dx*d*ds,py+dy*d*ds,px+dx*d*ds,py+dy*d*ds,p.c)
      end
    end)
    color(7)
    if #disp_shapes==0 then
      --rect(x,y,right(),bottom(),7)
      for i=y,bottom(),hitbox.h-1 do
        line(x+1, i, right()-1,i)
      end
      for i=x,right(),hitbox.w-1 do
        line(i, y+1, i,bottom()-1)
      end
    else
      for x_=x,right() do
        for y_=y,bottom(),(x_==x or x_==right()) and 1 or bottom()-y do
          local d,dx,dy,ds=displace(disp_shapes,vector(x_,y_))
          d=max((4-d), 0)
          rectfill(x_+dx*d*ds,y_+dy*d*ds,x_+dx*d*ds,y_+dy*d*ds)
        end
      end
    end
    --[[pset(x, y, 0)
    pset(x, bottom(), 0)
    pset(right(), y, 0)
    pset(right(), bottom(), 0)]]--
  end
}


function create_disp_shape(tbl,x,y)
  add(tbl, {pos=vector(x,y),r=0})
end

function update_disp_shapes(tbl)
  for i in all(tbl) do
    i.r+=2
    if i.r >= 15 then
      del(tbl, i)
    end
  end
end

function displace(tbl, p)
  local d,ds,po,s = 10000,0,vector(0,0),0
  for i in all(tbl) do
    local td,ts,tpo = sdf_circ(p, i.pos, i.r)
    if td<d then
      d,ds,po,s=td,ts,tpo,i.r
    end
  end
  local gx, gy = sdg_circ(po, ds, s)
  return d,gx,gy,(15-s)/15
end

function sdg_circ(po, d, r)
  return sign(d-r)*(po.x/d), sign(d-r)*(po.y/d)
end

function sdf_circ(p, origin, r)
  local po = vec_sub(p,origin)
  local d = vec_len(po)
  return abs(d-r), d, po
end

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

function init_object(type,sx,sy,tile)
  --generate and check berry id
  local id=sx..","..sy..","..lvl_id
  if type.check_fruit and got_fruit[id] then
    return
  end
  --local _g=_g
  local _ENV={
    type=type,
    collideable=true,
    sprite=tile,
    flip=vector(),
    x=sx,
    y=sy,
    hitbox=rectangle(0,0,8,8),
    spd=vector(0,0),
    rem=vector(0,0),
    fruit_id=id,
    outline=true,
    draw_seed=rnd()
  }
  _g.setmetatable(_ENV,{__index=_g})
  function left() return x+hitbox.x end
  function right() return left()+hitbox.w-1 end
  function top() return y+hitbox.y end
  function bottom() return top()+hitbox.h-1 end

  function is_solid(ox,oy)
    for o in all(objects) do
      if o!=_ENV and (o.solid_obj or o.semisolid_obj and not objcollide(o,ox,0) and oy>0) and objcollide(o,ox,oy)  then
        return true
      end
    end
    return (oy>0 and not is_flag(ox,0,3) and is_flag(ox,oy,3)) or  -- one way platform or
            is_flag(ox,oy,0) -- solid terrain
            -- <dream_block> --
           or check(dream_block,ox,oy) and (dash_effect_time<=2 or
           not check(dream_block,sign(dash_target_x),sign(dash_target_y))
           and not dreaming)
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
        else
          if ({spd.y>=0 and bottom()%8>=6,
            spd.y<=0 and top()%8<=2,
            spd.x<=0 and left()%8<=2,
            spd.x>=0 and right()%8>=6})[tile-15] then
            return true
          end
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
      rem[axis]+=axis=="x" and ox or oy
      local amt=round(rem[axis])
      rem[axis]-=amt
      local upmoving,riding,movamt=
      axis=="y" and amt<0,not player_here() and check(player,0,upmoving and amt or -1)
      if collides then
        local step,p=sign(amt),_ENV[axis]
        local d=axis=="x" and step or 0
        for i=start,abs(amt) do
          if not (is_solid(d,step-d) or oob(d,step-d)) then
            _ENV[axis]+=step
          else
            spd[axis],rem[axis]=0,0
            break
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
          riding.move(axis=="x" and movamt or 0, axis=="y" and movamt or 0,1)
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
  sfx_timer=12
  sfx(17)
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
  for f in all(fruitrain) do
    if (f.golden) full_restart=true
    del(fruitrain,f)
  end
  --- </fruitrain> ---
  delay_restart=15
  transition:play()
end

-- [room functions]


function next_level()
  load_level(lvl_id+1)
end

function load_level(id)
  --remove existing objects
  foreach(objects,destroy_object)

  has_dashed=false


  --reset camera speed
  cam_spdx,cam_spdy=0,0

  local diff_level=lvl_id~=id

  --set level index
  lvl_id=id

  --set level globals
  local tbl=split(levels[lvl_id])
  --<badeline>--
  lvl_x,lvl_y,lvl_w,lvl_h,bad_num=tbl[1]*16,tbl[2]*16,tbl[3]*16,tbl[4]*16,tbl[6] or 0
  --</badeline>--
  lvl_pw,lvl_ph=lvl_w*8,lvl_h*8


  local exits=tonum(tbl[5]) or 0b0001
  exit_top,exit_right,exit_bottom,exit_left=exits&1!=0,exits&2!=0,exits&4!=0, exits&8!=0

  --drawing timer setup
  ui_timer=5

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
      for y_=0,lvl_h*2-1,2 do
        local offset=y_<64 and 8192 or 0
        for x_=1,lvl_w*2,2 do
          local i=x_+y_*lvl_w
          poke(offset+y_*64+x_/2,"0x"..sub(mapdata[lvl_id],i,i+1))
        end
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

  if music_timer>0 then
    music_timer-=1
    if music_timer<=0 then
      music(10,0,7)
    end
  end

  if sfx_timer>0 then
    sfx_timer-=1
  end

  -- cancel if freeze
  if freeze>0 then
    freeze-=1
    return
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
      return
    end
  end)

  -- <transition>
  transition:update()
  -- </transition>

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
  camera(draw_x,draw_y)

  -- draw bg color
  cls()

  --<stars>--
  -- bg stars effect
  if stars_active then --stars_active is star condition, should probably set it somewhere
    foreach(stars, function(c)
      local x=c.x+draw_x
      local y=c.y+draw_y
      local s=flr(sin(c.off)*2)
      if s==-2 then
        pset(x,y,7)
      elseif s==-1 then
        spr(73,x-3,y-3)
      elseif s==0 then
        line(x-5,y,x+5,y,13)
        line(x,y-5,x,y+5,13)
        spr(74,x-3,y-3)
      else
        sspr(72,40,16,16,x-7,y-7)
      end
      c.x+=-cam_spdx/4
      c.off+=0.01
      if c.x>128 then
        c.x=-8
        c.y=rnd(120)
      elseif c.x<-8 then
        c.x=128
        c.y=rnd(120)
      end
    end)
  end
  --</stars>--

  -- bg clouds effect
  --[[foreach(clouds,function(c)
    x+=spd-_g.cam_spdx
    _g.rectfill(x+_g.draw_x,y+_g.draw_y,x+w+_g.draw_x,y+16-w*0.1875+_g.draw_y,1)
    if x>128 then
      x,y=-w,_g.rnd(120)
    end
  end)]]

		-- draw bg terrain
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)

  -- draw outlines
  for i=0,15 do pal(i,1) end
  pal=time
  foreach(objects,function(_ENV)
    if outline then
      for dx=-1,1 do for dy=-1,1 do if dx&dy==0 then
        camera(draw_x+dx,draw_y+dy) draw_object(_ENV)
      end end end
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
    if type.layer==0 then
      draw_object(_ENV) --draw below terrain
    else
      add(layers[type.layer or 1],_ENV) --add object to layer, default draw below player
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
      x,y=-4,_g.rnd128()
    elseif x<-4 then
      x,y=128,_g.rnd128()
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

  -- <transition>
  transition:draw()
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
  return x<10 and "0"..x or x
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

function maybe()
  return rnd()<0.5
end

--<dream_block>

function vec_len_sqr(a)
  return a.x^2 + a.y^2
end

function vec_len(a)
  return sqrt(vec_len_sqr(a))
end

function vec_sub(a,b)
  return vector(a.x-b.x, a.y-b.y)
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
transition = {
  -- state:
  --  1 | wiping in
  -- -1 | wiping out
  --  0 | idle
  state=0,
  tw = 6,
  play=function(_ENV)
    state = state==0 and 1 or state
    pixelw = 128/(tw-1)
    circles = {}
    local ctotal = tw*tw
    for i=0,ctotal-1 do
      local c = {
        x=i%tw * pixelw + _g.rnd(6)-3,
        y=i\tw * pixelw + _g.rnd(6)-3,
        delay=i%tw * 2 + _g.rnd(4)-2,
        radius=state==1 and 0 or pixelw
      }
      add(circles, c)
    end
  end,
  update=function(_ENV)
    if (state==0) return
    for i=1,#circles do
      local c = circles[i]
      if c.delay > 0 then
        c.delay -= 1
      else
        c.radius += state*3
      end
    end
    local lastr = circles[#circles].radius
    if state==1 and lastr > pixelw*0.7 then
      state=-1
      play(_ENV)
    elseif lastr < 0 then
      state=0
    end
  end,
  draw=function(this)
    if (this.state==0) return
    camera()
    for i=1,#this.circles do
      local c = this.circles[i]
      if c.radius > 0 then
        circfill(c.x, c.y, c.radius, 0)
      end
    end
  end
}
-- </transition> --
-->8
--[map metadata]

--@conf
--[[param_names = {"badeline num"}
autotiles = {{52, 54, 53, 39, 33, 35, 34, 55, 49, 51, 50, 48, 36, 38, 37, 32, 29, 30, 31, 41, 42, 43, nil, nil, nil, nil, nil, 56, 45, 46, 47, 80, 44, 81, [41] = 61, [42] = 62, [43] = 63, [0] = 48, [44] = 57, [45] = 58, [46] = 59, [56] = 40, [57] = 60}, {29, 31, 30, 29, 29, 31, 30, 61, 61, 63, 62, 45, 45, 47, 46, 48, 52, 53, 54, 32, 41, 42, 43, nil, nil, nil, nil, 39, 33, 34, 35, 56, 80, 44, 81, nil, nil, nil, nil, 48, 36, 37, 38, [45] = 57, [46] = 58, [47] = 59, [52] = 55, [53] = 49, [0] = 29, [54] = 50, [55] = 51, [57] = 40, [58] = 60}, {41, 43, 42, 41, 41, 43, 42, 57, 57, 59, 58, 80, 80, 81, 46, 44, 48, 52, 53, 54, 32, 56, nil, nil, nil, nil, nil, 60, 39, 33, 34, 35, 29, 30, 31, nil, nil, nil, nil, 40, 48, 36, 37, 38, 45, 46, 47, [53] = 49, [54] = 49, [55] = 50, [0] = 41, [56] = 51, [57] = 61, [58] = 62, [59] = 63}}
]]
--@begin
--level table
--"x,y,w,h,exit_dirs,badeline num"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
levels={
  "0,0,1,1,0b0001",
  "1,0,2,2,0b0001,1",
  "4,0,1,4,0b0010,1",
  "5,3,1,1,0b0001"
}

--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
  {},
  {},
  {},
  {}
}
--</camtrigger>--

--mapdata string table
--assigned levels will load from here instead of the map
mapdata={
  [3] = "260000002425252525252525252525252600000031323232323232323232323226000000004041414141414100000000260001000041000000000000000000002522222222222222222222222300002125252525252525252525252526000024253232323232323232252525264041242600000000111111112425252641002426000a0000000000132425252641002426000000101000001324252526410024261010102123120013242532330000242640414124261200133133000000002426410000243300000000000000000024264100003700000000000000000000242600000000000000000000101010102426000000000000000000002123404124260000000000000000000031334100242600000010102122222300000000002426000000212225252526000000000024253536002425252525252222222222252600000024252525252525252532252526003435323225252525252533112425260000000000312532323233000031252600000000000030000000000000002425222223000000300000000000000024252525260000003000000010000013242525252600000030000000210000002425252526000000370000003012000024252525260000000000000030000000242525252600000000000000300000002425252526000000000000001100000024252525260000000000000021000000242525252610100000000000300000002425252525222300000010103000001024252525252526101010212226000034252525252525252222222525260000002425252525253232322525252600000024252532252611111124253233000000242526113133000000313300000000002425260000000000000000000000000024253300000000000000000000000000242600000000000000000000000000002426000000000000004243000000001324260000000000000043000000000013242600000010101000000000001010102426000000212223100000000021222225260000002425252300001010242525252600000024252526001021353232322526000000313232330031330000000024260000001340410000000000000a00242600000013410000000000000000002426000000002122222222222222222225260000000031323232323232323232322658000000000011111100000000474826000000000000000000000000005700252300000000001010101010102222222525222340414141414141414124252525252533410000000000000000312525252526000000000000000000000024252525330000440000000000000000312525330000000000000000000000000024260000001717170000000000000000242600000000000000000000000000002426000000000000000000000000000024",
  [4] = "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000021222222230000000000"
}
local __init = _init function _init() __init() load_level(3) music(-1) end
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
  for y_=0,h*2-1,2 do
    local offset=y*2+y_<64 and 8192 or 0
    for x_=1,w*2,2 do
      reserve=reserve..num2hex(peek(offset+x+y*128+y_*64+x_/2))
    end
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
888888886665666555888888888886664fff4fff4fff4fff4fff4fffd666666dd666666dd666066d0000000000000000700000000666666d16666d6d1d666660
888888886765676566788888888777764444444444444444444444446dddddd56ddd5dd56dd50dd50077000007700700070000076666666d16666ddd16666666
88888888677867786777788888888766000450000000000000054000666ddd55666d6d5556500555007770700777000000000000d666666d1ddddddd1666666d
8878887887888788666888888888885500450000000000000000540066ddd5d5656505d500000055077777700770000000000000dd6666dd1dddd6dd1d6666dd
887888788788878855888888888886660450000000000000000005406ddd5dd56dd5065565000000077777700000700000000000dddddddd11ddddd11ddddddd
867786778888888866788888888777764500000000000000000000546ddd6d656ddd7d656d500565077777700000077000000000d66ddddd111111111dddd66d
5676567688888888677778888888876650000000000000000000000505ddd65005d5d65005505650070777000007077007000070ddddddd1110001111ddddddd
56665666888888886668888888888855000000000000000000000000000000000000000000000000000000007000000000000000111111111000000111dddddd
11111111ddd1ddd1ddddd5111ddd1ddddd555111111111111115555ddd5515dd0cccccc0077777777777777777777770cc000000dddd11110000000011111111
11111111d5515551555555111555155d55555111111111111111111155555155cccccccc7777777777677767777777771c00cc006dddd1100000000011d66ddd
11555551d55155511111111111111111111111111111111111555dd1111111111ccccccc7677667777766677777777770000ccc0ddd6d110000000001dd66d66
115ddd51555155515dddd1551555555d1dd55d111111111111555dd1dd55111d1cc1ccc17766677777776d676777677700001ccc66ddd110000000001ddddd66
111ddd1155515d515ddd515515d55ddd1dd5551111111111115555d1dd5551dd1cc11c1077d67777dd77dcd7666677700cc01ccc66ddd110000000001ddddd66
111115551111111155555155111111111d5555111111111111111111d555515d111111007dcd667dccddcccd6d6777661ccc11c166ddd110000000001d6ddd66
55511555d55555111111111111155ddd1111111111111111111555dd55555155011010007cccd66cccccccccccc66d661ccc011166dd1110000000001dddd666
55511111d5555511111111111115555ddd55511111111111111555dddd55515d000000007ccccccc0ccc00cccccd6dd611c00000111111110000000011dddddd
dd55515dd5555111111111111115555dddd15ddddddddd51ddd51ddd555551551111111177cccccc00cccccccccccc770ccc1000ddddd1111111111111111111
55555155d55551111111111111155ddddd51555555555551555515dd555551115511111177cccccccccccccccccccc771cc110006ddddd111ddddd11111ddddd
11111111111111115511111111111111555111111111111111111555111111115515555167c7cccccccccccccccc7c671111000066d66dd1dddd6dd1111dd6dd
dd5111dd55515d51dd11555115d55ddd111111155111111151111111d551555d111555516ccccccccccccc6cccccccc60011cc1066dd6dd166ddddd11ddddddd
dd5111dd55515551dd1155511555555d555551155155555151155555d5515555111111116ccccccccc6cccccccccccc6001cccc0666dddd166ddddd1ddd6666d
55511155d55155511111555111111111555551111155555111155555111155551555551166ccccc6cccccccc6ccccc660111cc1066666dd1ddddd6d1d6666666
11111111d5515551555155511555155ddd555155515d5551551555ddd55155dd155555116ccc66c6666ccc666c66ccc61c111100666666d1d66666d1d6666666
5555515d1dd1ddd1dd51dd511ddd1dd1dddd515dd1dddd51d515dddd1d515dd111111111066666660666666666666660cc100000066666d1d66666d1d6666666
0000000000000000577777777777777788cccc8888cccc8888cccc881dddd15ddddd51dd000d0000d00600d00000000000000000000000000000000000000000
00008000000b000077777777777777778c0000c88c0000c88c0000c8d555515555d551550d0d0d000d060d000000000000000000000000000000000000000000
00b00000000000007777ccccccccccccc00cc00cc00c100cc00cc00cd55551555555515500d6d000006760000000000000000000000000000000000000000000
0000000000000000777cc7ccccccccccc0c00c0cc010c10cc00cc00cd555111111111111dd676dd0667776600000000000000000000000000000000000000000
0000b000080000b077ccc7ccccccccccc0cccc0cc01cc10cc00cc00c555111111111111100d6d000006760000000000000000000000000000000000000000000
0b0000000000000077c77777ccccccccc00cc00cc00c100cc00cc00c55511111111111110d0d0d000d060d000000000000000000000000000000000000000000
00000080000b000077cc777ccccccccc8c0000c88c0000c88c0000c81111111111111111000d0000d00600d00000000000000000000000000000000000000000
000000000000000077ccc7cccccccccc88cccc8888cccc8888cccc88d55111111111111100000000000000000000000000000000000000000000000000000000
7cccccccccccccc70000000000000000000000000000000000000000d5511111111cc11100000001000000000000000000000000000000000000000000000000
77ccccc0cccccc770000000000000000000000000000000000000000d551111111cccc1100000001000000000000000000000000000000000000000000000000
76ccccc0cccc77770000000000000000000000000000000000000000d55111111cc11cc10000010d010000000000000000000000000000000000000000000000
667cccc000ccccc70000000000000000000000000000000000000000555111111cc11cc10001000d000100000000000000000000000000000000000000000000
6ccccccc0ccccc770000000000000000000000000000000000000000111111111cccccc100001006001000000000000000000000000000000000000000000000
7cccccccccccc6770000000000000000000000000000000000000000d55111111cccccc100100d060d0010000000000000000000000000000000000000000000
7cccccccccccc6670000000000000000000000000000000000000000d551111111cccc1100000067600000000000000000000000000000000000000000000000
77cccccccccccc670000000000000000000000000000000000000000d5511111111cc11111dd6677766dd1100000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000067600000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000100d060d0010000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000001006001000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000001000d000100000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000010d010000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
56555665000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55655655000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000002020202080808000000000000030303030303030303030303030303030303030303030303030303030303030303030300000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000000000002b3b29000000000000000000002a3b2b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000003b290000000000000000000000002a3b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000440000000100000000004400002900000000000000000000001010102a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000132122222312000000000000000000000000000000000040414100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000133132323312000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000001111111100000000000000000000000000000000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000040414100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0047484800000000000000424343430022222222222222222300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0057000000000000000000430000000025252525252532323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0057000000000000000000430000000025252525252640414100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000040414100430000000025252525252641000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0058000000000041000000430000000025252525252641000010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000025252532323341000034353535360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000025252600000041000025000000000010000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222222222222317172122222222222225252600000041000025000000001340000013400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2525252525252600002425252525252525252600000041000025000000001341000013410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000025252522222341000025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000025252525252641000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000032323232323341000000000000000000000000000000001340410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000001341000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000040414141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000041000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000010000000101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000010101027000000404141414141410000001000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000040414130000000410000000000000000002700000040411200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000030000000000000000000000000003700000041001200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000010030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000021222330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000024252630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

