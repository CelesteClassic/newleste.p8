pico-8 cartridge // http://www.pico-8.com
version 35
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
freeze,delay_restart,sfx_timer,music_timer,ui_timer, --timers
cam_x,cam_y,cam_spdx,cam_spdy,cam_gain,cam_offx,cam_offy, --camera values <camtrigger>
_pal --for outlining
=
{},{},
0,0,0,0,-99,
0,0,0,0,0.1,0,0,
pal


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
    off=rnd(1),
    spdy=rnd(0.5)+0.5
  })
end
stars_active=true
--</stars>--


-- [player entity]

player={
  layer=2,
  init=function(_ENV)
    djump, hitbox, collides = max_djump, rectangle(1,3,6,5), true

    --<fruitrain>--
    -- ^ refers to setting berry_timer and berry_count to 0
    for var in all(split"grace,jbuffer,dash_time,dash_effect_time,\z
                         dash_target_x,dash_target_y,dash_accel_x,dash_accel_y,\z
                         spr_off,berry_timer,berry_count") do
      _ENV[var]=0
    end
    create_hair(_ENV)
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
      berry_timer, berry_count=0, 0
    end

    for f in all(fruitrain) do
      if f.type==fruit and not f.golden and berry_timer>5 and f then
        -- to be implemented:
        -- save berry
        -- save golden

        berry_count+=1
        _g.berry_count+=1
        berry_timer, got_fruit[f.fruit_id]=-5, true
        init_object(lifeup, f.x, f.y,berry_count)
        del(fruitrain, f)
        destroy_object(f);
        (fruitrain[1] or {}).target=_ENV
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
      local d_full, d_half = 5, 3.5355339059 -- 5 * sqrt(2)

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
      sspr(72,0,8,8-delta,x,y+delta)
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
    else
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
        0,#fruitrain==0 and hit or fruitrain[#fruitrain],#fruitrain==0 and 12 or 8
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
       sfx(10)
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
      local first,last=disp_shapes[1],disp_shapes[#disp_shapes]

      minx=min(first.pos.x-first.r-4,last.pos.x-last.r-4)
      maxx=max(first.pos.x+first.r+4,last.pos.x+last.r+4)
      miny=min(first.pos.y-first.r-4,last.pos.y-last.r-4)
      maxy=max(first.pos.y+first.r+4,last.pos.y+last.r+4)

      if minx>x then
        line(x,y,minx-1,y)
        line(x,bottom(),minx-1,bottom())
      end
      if maxx<right() then
        line(maxx+1,y,right(),y)
        line(maxx+1,bottom(),right(),bottom())
      end

      if miny>y then
        line(x,y,x,miny-1)
        line(right(),y,right(),miny-1)
      end
      if maxy<bottom() then
        line(x,maxy,x,bottom())
        line(right(),maxy,right(),bottom())
      end

      for x_=max(minx,x),min(maxx,right()) do
        for y_=y,bottom(),bottom()-y do
          local d,dx,dy,ds=displace(disp_shapes,vector(x_,y_))
          d=max((4-d), 0)
          rectfill(x_+dx*d*ds,y_+dy*d*ds,x_+dx*d*ds,y_+dy*d*ds)
        end
      end
      for x_=x,right(),right()-x do
        for y_=max(miny,y),min(maxy,bottom()) do
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

function init_object(_type,sx,sy,tile)
  --generate and check berry id
  local id=sx..","..sy..","..lvl_id
  if _type.check_fruit and got_fruit[id] then
    return
  end
  --local _g=_g
  local _ENV={}
  type, collideable, sprite, flip, x, y, hitbox, spd, rem, fruit_id, outline, draw_seed=
  _type, true, tile, _g.vector(), sx, sy, _g.rectangle(0,0,8,8), _g.vector(0,0), _g.vector(0,0), id, true, _g.rnd()

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
    return oy>0 and not is_flag(ox,0,3) and is_flag(ox,oy,3) or  -- one way platform or
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
      rem[axis]+=axis=="x" and ox or oy
      local amt=round(rem[axis])
      rem[axis]-=amt

      local upmoving=axis=="y" and amt<0
      local riding,movamt=not player_here() and check(player,0,upmoving and amt or -1)--,nil
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
  for i,v in ipairs(split"exit_top,exit_right,exit_bottom,exit_left") do
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
      if stars_falling then
        pal(7,6)
        pal(6,12)
        pal(13,12)
      end
      local x=c.x+draw_x
      local y=c.y+draw_y
      local s=flr(sin(c.off)*2)
      if s==-2 then
        pset(x,y,stars_falling and 12 or 7)
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
      c.y+=-cam_spdy/4
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
          c.spdy=rnd(0.5)+0.5
        end
        pal()
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

-- function vec_len(a)
--   return sqrt(vec_len_sqr(a))
-- end

function vec_len(a)
 local maskx,masky=a.x>>31,a.y>>31
 local a0,b0=(a.x+maskx)^^maskx,(a.y+masky)^^masky
 if a0>b0 then
  return a0*0.9609+b0*0.3984
 end
 return b0*0.9609+a0*0.3984
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
  "3,0,3,1,0b0010"
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
888888886665666555888888888886664fff4fff4fff4fff4fff4fffd666666dd666666dd666066d000000000000000070000000111011101110110001101110
888888886765676566788888888777764444444444444444444444446dddddd56ddd5dd56dd50dd5007700000770070007000007111011101110110001101111
88888888677867786777788888888766000450000000000000054000666ddd55666d6d5556500555007770700777000000000000111011101110110001101111
8878887887888788666888888888885500450000000000000000540066ddd5d5656505d500000055077777700770000000000000000011100000000000001111
887888788788878855888888888886660450000000000000000005406ddd5dd56dd5065565000000077777700000700000000000111011100000000000000000
867786778888888866788888888777764500000000000000000000546ddd6d656ddd7d656d500565077777700000077000000000111011101110110000111111
5676567688888888677778888888876650000000000000000000000505ddd65005d5d65005505650070777000007077007000070111000001110110000111111
56665666888888886668888888888855000000000000000000000000000000000000000000000000000000007000000000000000111000000000000000111111
00000000ddd8ddd8ddddd5888ddd8ddddd555100000000000015555d8d5585d80cccccc0077777777777777777777770cc000000000000001110000000000000
00000000d5515551555555111555155d55555100000000000000111155555155cccccccc7777777777677767777777771c00cc00100001001110000000011110
00555550d55155511111111111111118111100000000000001555dd8811111181ccccccc7677667777766677777777770000ccc0111101101110111100011111
005ddd50555155505dddd1551555555d8dd55d100000000001555dd8dd55111d1cc1ccc17766677777776d676777677700001ccc111100100000111100111111
000ddd0055505d505ddd515515d55ddd8dd5551000000000015555d8dd5551dd1cc11c1077d67777dd77dcd7666677700cc01ccc000000000000111100100111
000005558110011155555055110001188d5555100000000000001111d555515d111111007dcd667dccddcccd6d6777661ccc11c1110011000000000000011011
55500555d55555101111101100055ddd1111000000000000001555dd55555155011010007cccd66cccccccccccc66d661ccc0111111011110000000000111111
55500000d5555510000000000015555ddd55510000000000001555dddd55515d000000007ccccccc0ccc00cccccd6dd611c00000011001100000000000011111
dd55515dd5555100000000000015555dddd15ddddddddd51ddd51ddd555551550000000077cccccc00cccccccccccc770ccc1000011100000000000000000000
55555155d55551001100000000155ddddd51555555555551555515dd555551185500000077cccccccccccccccccccc771cc11000111100000001111000001111
81111118810001115500111011111118555111111111111111111555811111185505555067c7cccccccccccccccc7c6711110000111100000000111000001111
dd5111dd55505d51dd00555015d55ddd811111155111111151111118d551555d000555506ccccccccccccc6cccccccc60011cc10111100000000000000001111
dd5111dd55515551dd1155511555555d555551155155555151155555d5515555000000006ccccccccc6cccccccccccc6001cccc0111101110000001111101111
55511155d55155511111555111111118555551111155555111155555811155550555550066ccccc6cccccccc6ccccc660111cc10111101110110100111101111
81111118d5515551555155511555155ddd555155515d5551551555ddd55155dd055555006ccc66c6666ccc666c66ccc61c111100111101110110111111101111
5555515d8dd8ddd8dd58dd588ddd8dd8dddd585dd8dddd58d585dddd8d585dd800000000066666660666666666666660cc100000111101110110111111101111
0000000000000000577777777777777788cccc8888cccc8888cccc881dddd15ddddd51dd000d0000d00600d01111011115555555555555551500000055505500
00008000000b000077777777777777778c0000c88c0000c88c0000c8d555515555d551550d0d0d000d060d001111011115111111111111111500000011111000
00b00000000000007777ccccccccccccc00cc00cc00c100cc00cc00cd55551555555515500d6d000006760001111011115000000000000001500000000000000
0000000000000000777cc7ccccccccccc0c00c0cc010c10cc00cc00cd555111111111111dd676dd0667776600000011115000000000000001500000000000000
0000b000080000b077ccc7ccccccccccc0cccc0cc01cc10cc00cc00c555111111111111100d6d000006760001110011115000000000000001500000000000000
0b0000000000000077c77777ccccccccc00cc00cc00c100cc00cc00c55511111111111110d0d0d000d060d001110000015000000000000001500000000000000
00000080000b000077cc777ccccccccc8c0000c88c0000c88c0000c81111111111111111000d0000d00600d01110111115000000000000001500000000000000
000000000000000077ccc7cccccccccc88cccc8888cccc8888cccc88d55111111111111100000000000000000000000015000000000000001500000000000000
7cccccccccccccc71111101100111010111101110000000015555551d5511111111cc111000000010000000011111111005555050d6666660d666d6d066666d0
77ccccc0cccccc771111101101111010111101110001111050500505d551111111cccc1100000001000000001111111100001111dddd66661ddddddd1dd6666d
76ccccc0cccc77771111001101111010111101110001111051511515d55111111cc11cc10000010d010000000001111000000000ddd6dddd1ddddddd11ddd66d
667cccc000ccccc70000000100001010000000110000000051511515555111111cc11cc10001000d0001000000000000000000001dddddd1111ddd11111ddddd
6ccccccc0ccccc771100000001100000100000000111010051511515111111111cccccc10000100600100000110001110000000001ddddd11111111111111ddd
7cccccccccccc6771110111101101110110111110111010051511515d55111111cccccc100100d060d0010001110111100000000d11111111111101111111110
7cccccccccccc6671110111101101110110111110000000051511515d551111111cccc1100000067600000000000111000000000dd1111110011011011111ddd
77cccccccccccc671110111101101110110111110000000051515515d5511111111cc11111dd6677766dd1100000000000000000dd111110000000000111ddd6
00000000880008888800088888000888880008888800088851515515155555515000000500000067600000001111011111155555011111000000000000111d66
00000050888000808880008088800080888000808880008051510515500000055000000500100d060d0010001111011110151115dd111100000001000011d166
000000500888080008880800088808000888080008880800515115155000000550000005000010060010000000000111101511556ddd1110011011100001ddd6
0050050500888000008880000088800000888000008880005151151550000005500000050001000d00010000111001111015155566ddd110011011100001dddd
0505051d00088800000888000008880000088800000888005151151550000005500000050000010d01000000111000001015551566ddd110000001100001ddd6
051d0515008088800080888000808880008088800080888051511515500000055000000500000001000000001110111110155115dd6dd1100011000000111ddd
0515051d080008880800088808000888080008880800088851511515500000055000000500000001000000001110111110151115dddd111001111100011111dd
051d051d888000888880008888800088888000888880008855555555500000055000000500000000000000001110111111155555ddd111000011100001111110
000000000000000000000000000115000111111500011500000000000dd11dd1011111100d666660066d0d66666d0d660d6666d0011111000000000000111d66
00000000000000000000000000010500001010100001050000011100111111d1dd1111ddd6d6666d66dd1ddddddd1ddd1dd6666dddd11110000000001111dd66
000000000000000000000000000151000050505000015100001505101611111066d111d6ddddd66666dd11dddd1111dd1ddd666d66dd1111111100111111ddd6
00000000000000000000000000005000005050500000500000150510d661116666d11dd60111ddddd6dd1111111111111ddddd6d66dd11111111101111111ddd
10000000055555555555555000011500005050500001100000150510dd6611d66dd11dd0d1111110ddd1111000000100011ddddddddd11111ddd111166611dd6
100000000111111111111150000105000050505000050000001111111dd11ddd6dd111166ddd11d6dd11d6d0ddd0dd10111111dd6dddd11d666dd11ddd6611dd
100000000001100000011000000151000010101000000000001010511ddd66d1ddd111dddddd1ddd0111ddd1ddd1ddd11dd11110ddddd1d666ddd1dddddd11dd
15000000000150000001500000005000011111150000000000101051011ddd100dd111dd0dd111d000111dd111111dd1ddd111000dddd0ddddddd0ddddddd110
__label__
00000000000000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000055500000000000011111
00000055550000000000005555001115555000000000000000000000000000700000000000000000000000000000000000000000000555511100000000015000
00000055550000000001110555111115555000000000000000000000000000000000000000000000000000000000000000000000000555511110000000050000
00000011110000000001111000111115555000000000000000000000000000000000000000000000000000000000000000000000000555511000000000050000
00005550500000000001111115555515555000000000000000000000000000000000000000000000000000000000000000000000000555515550000000050000
00005550500000000001551510555515555000000000000000000000000000000000000000000000000000000000000000000000000555515550000000050000
00001110100000000001551555555515555000000000000000000000000000000000000000000000000000000000000000000000000555515550000000050000
00000000000000000000550555555505555000000000000000000000000000000000000000000000000000000000000000000000000555505550000000050000
00000000000001111000000000000000000007700000000000000000000000000000000000000000000000000000000000000000000000000000111110050000
00000000000001555500000000000000000007700000000000000000000000000000000000000000000000000000000000000000000000000005111150050000
55500000000001555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555155050000
55500000000005555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555105050000
55500000000005005550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000110050000
11100000000000550550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005511550050000
00000000000005555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005551555515000
00000000000000555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000551055011555
00000000000001111000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000111110000000
00000000000001555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005111150000000
00000000000001555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555155000000
00000000000005555550000000000000000000000000000000000000000000000000000000000000000007000700070007000700070000000005555105000000
00000000000005005550000000000000000000000000000000000000000000000000000000000000000007000700070007000700070000000000000110000000
00000000000000550550000000000000000000000000000000000000000000000000000000000000000067706770677067706770677000000005511550000000
00000000000005555550000000000000000000000000000000000000000000000000000000000000000567656765676567656765676000000005551555500000
00000000000000555550000000000000000000000000000000000000000000000000000000000000000566656665666566656665666000000000551055000000
00055500000000000000550555000000000000000000000000000000000000000000000000000000000077777777777777777777770000000000555000000000
000555000000000000015515555000000000000000000000000000000000000100000000000000000007c0000000000000000000007000000005555111000000
00055505555000000001551555500000000000000000000000000000000000181000000000000000000700000000000000000000007000000005555111100000
00011105555000000001001555500000000000000000000000000000000001888100000000000000000700000080000000000000007000600005555110000000
00000005555006000001111000000000000000000000000000000000001111888100000000000000000700000000000900000000007000000005555155500000
00000001111000000001155555500000000000000000000000000000018888888810000000000000000700000000000000000000007000000005555155500000
00000000000000000000155555500000000000000000000000000000188888888810000000000000000700000000000000000000007000000005555155500000
0000000000000000000005555550000000000000000000000000000018ffff888810000000000000000077777777777777777777770000000005555055500000
00000000000000000000000000000111100000000000000000000000181ff1f88810000000000000000000000000000000000000000006600000000000001111
5500000000000000000000000000015555000000000000000000000001fffff88100000000000000000000000000000000000000000006600000000000051111
55100000000000000000000000000155555000000000000000000000001333311000000000000000000000001111110000000000000000000000000000055551
00100000000000000000000000000555555000000000000000000000017111171000000000000000000000012222221000000000000000000000000000055551
15500000000000000000000000000500555000000000000000000000001000010000000000000000000000122222222100000000000000000000000000000001
10500000000000000000000000000055055000000000000000000000000000000000000000000000000000122266662100000000000000000060000000055115
55500000000000000000000000000555555000000000000000000000000000000000000000000000000000122686682100000000000000000000000000055515
55500000000000000000000000000055555000000000000000000000000000000000000000000000000001222666661000000000000000000000000000005510
00001111100000000001555555100111100000000000000000000000000000000000006000000000000001222111110000000000000000000000000000001111
00051111500000555505000000500155550000000000000000000000000000000000000000000000000001225221151000000000000000000000000000051111
00055551550000555505000000500755555000000000000000000000000000000000000000000000000001222221010000000000000000000000000000055551
00055551050000111105000000500555555000000000000000000000000000000000000000000000000007222221070007000700070000000000000000055551
00000001100055505005000000500500555000000000000000000000000000000000000000000000000007222221170007000700070000000000000070000001
000551155000555050050d0000500055055000000000000000000000000000000000000000000000000067722277777067706770677000000000000000055115
00055515555011101005d00000500555555000000000000000000000000000000000000000000000006667627277776567656765676000000000000000055515
000055105500000000056dd000500055555000000000000000000000000000000000000000000000006666657777776566656665666000000000000000005510
00001111100000000005d00000500000000055055507000000000000000000000000000000000000000077777777777777777777770000000000000000055551
000511115000000000050d0000500000000155155550000000000000000000000000000000000000000700027777770000030000007000000000000000055551
0005555155000000000500000050000000015515555000000000000000000000000000000000000000070000277707a000000000007000000000000000000001
00055551050000000005000000500000000100155550000000000000000000000000000000000000000700002000770000000000007000000000000000055511
00000001100000000005000000500000000111100000000000000000000000000000000000000000000700022707770000000000007000000000000000055511
00055115500000000066000000500000000115555550000000000000000000000000000000000000000700002777777000000000007000000000000000055515
00055515555000000066000000500000000015555550000000000000000000000000000000000000000700000777777000000000007000000000000000055515
00005510550000000005000000500000000005555550000000000000000000000000000000000000000077777777777777777777770000000000000000055505
d6d0d666d6d0d666d6d0d666d6d0d666d6d0d666d6d0d666d6d066666d0000000000000000000000000000000177777717100000000000000000000000000000
ddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1dd6666d000000000000000000000000000000177777711000000000000000000000000000000
ddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd1ddddddd11ddd66d000000000000000000000000000000177777710000000000000000000000000000000
d11111ddd11111ddd11111ddd11166ddd11111ddd11111ddd11111ddddd000000000000000000000000000000177777710000000000000000000000000000000
11111111111111111111111111116611111111111111117111111111ddd000000000000000000000000000000171777771000000000000000000000000000000
01111111011111110111111101111111011111110111111101111111110000000000000000000000000000000177177771000000000000000000000000000000
11000110110001101100011011000110110001101100011011011111ddd000000000000000000000000000000177711771000000000000000000000000000000
0000000000000000000000000000000000000000000000000000111ddd6000000000000000000000000000000011711110000000000000000000000000000000
00000000000000000000000000000000000000000000000000000111d66000000000000000000000000000000000117710000000000000000000000000000000
1000000010000000000000000000000010000000000000000001111dd6600000000000000000000000000000000117771100000000000000000d000000000000
1100110111000000000000000000110111011110011111100111111ddd6000000000000000000000000000000017117717100000000000000d0d0d0000000000
11001101110000000000000000001101110111110111111101111111ddd0000000000000000000000000000000177171010000000000000000d6d00000000000
110000001100000000000000000000001101ddd11111ddd111166611dd600000000000000000000000000000001771100000000000000000dd676dd000000000
00000170000000000000000000000110000666dd11d666dd11ddd6611dd0000000000000000000000000000000011711100000000000000000d6d00000000000
1000111110000000000000000000111110066ddd1dd66ddd1dddddd11dd000000000000000000000000000000000011771000000000000000d0d0d0000000000
00000111000000000000000000000111000ddddd0ddddddd0ddddddd11000000000000000000000000000000000011777100000000000000000d000000000000
00000000000000000000000000000111d66077777777777777777777770000000007000000000000000000000001711771000000000000000000000000000000
0000000000000000000000000000011d166700000000000000000000007000000000000000000000000000000000100110000000000000000000000000000000
0000000000000000000000000000001ddd6700000000000000000000007700000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000001dddd700000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000001ddd6700003000000000000000007000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000111ddd700a90800000000000009007100000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000011111dd700000000030000000000007000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000001111110700000000000000000000007d11000000000000000700000000000000000000000000000000000000000000000000
00000000000000000000000000000111d66700000000000000000000037000000000000000000000000000000070000000000000000000000000000000000010
0000000000000000000000000000011d1667000000e000000000000a007100000000000000000000000000000000000000000000000000000000000000000010
0000000000000000000000000000001ddd67000000000000000900000070000000000000000000000000000000000000000000000000000000000000000010d0
0000000000000000060000000000001dddd7000000000000000000000070000000000000000000000000000000000000000000000000000000000000001000d0
0000000000000000000000000000001ddd6700000000000000000000007000000000000000000000000000000000000000000000000000000000000000010060
00000000000000000000000000000111ddd70000000000000000000000700000000000000000000000000000000000000000000000000000000000000100d060
000000000000000000000000000011111dd70000000000000000000e007000000000000000000000000000000000000000000000000000000000000000000676
0000000000000000000000000000111111070000000000000000000000700000000000000000006000000000000000000000000000000000000000011dd66777
00000000000000000000000000000111d66700000000000000000000007000000000000000000000000000000000000000000000000000000000000000000676
0000000000000000000550000000011d16670000000000000000000000700000000000000000000000000000000000000000000000000000000000000100d060
0000000000000000000550555500001ddd6700000000000000000000007000000000000000000000000000000000000000000000000000000000000000010060
0000000000000000000110555500001dddd700000000000009000000007007000700070007d007000700070007000700070000000000000000000000001000d0
0000000000000000000000111100001ddd67000000000000000000000070070007000700d7d0d7000700070007000700070000000000000000000000000010d0
00000000000000000000555550000111ddd7000000000000000000000070677067706770677d6770677067706770677067700000000000000000000000000010
000000000000000000005555500011111dd700000000000000008000007567656765676567656765676567656765676567600000000000000000000000000010
000000000000000000001111100011111107000000000c0000000000007566656665666566656665666566656665666566600000000000000000000000000000
00000000000111111111111111100111d6670c000000008000000000007ddd0ddd0dddddd51dddddd51dddddd51ddd51ddd00000000000000000000000000000
0005500000011111111111111111111dd667000008000000000e0000007d5515551555555515555555155555551555515dd00000000000000000000000000000
0005505555055111111551111111111ddd6700000000000000000000007d55155511111111111111111111111111111155500000000000000000000000000000
00011055550dd115551dd11555111111ddd700000000000000000000007555155515111111151111111511111115711111000000000000000000000000000000
00000011110dd115551dd11555166611dd67000000000e000000000000755515d515155555151555551565555515115555500000000000000000000000000000
000055555001111555111115551dd6611dd700000000000000000000007011111111155555111555551115555511115555500000000000000000000000000000
000055555005551555155515551dddd11dd700000000000000000000007d5555511515d5551515d5551515d5551551555dd00000000000000000000000000000
00001111100dd50dd50dd50dd50ddddd110700000000000000000000007d5555511d0dddd50d0dddd50d0dddd50d505dddd00000000000000000000000000000
0001115555d000000000000000000000000700000000000000000000007dd55515d0000000000000000001111000000000000000000000000000000000000000
00011111111000000000000000000000000700000000000000000000007555551550000000000000000011155550000000000000000000000000000000000000
00011555dd0000000000000000000000000700000000000000000000007011111100000000000000000111155550000000000000000000000000000000000000
00011555dd000000000000000000000000070000000090000000e000007dd5111dd0000000000000000111155550000000000000000007000700000000000000
000115555d0000000000000000000000000700000000000000000000307dd5111dd0000000000000000555155550000000000000000007000700000000000000
00011111111000000000000000000000000700900000000000000000a07555111550000000000000000555155550000000000000000067706770000000000000
000111555dd000000000000000000000000700000000008908000000007011111100000000000000000555155550000000000000000567656760000000000000
000111555dd0000000000000000000000007000000000000000000000075555515d0000000000000000555055550000000000000000566656660000000000000
0001115555d000000000000000000000000700000000000000000000007dd55515d0000000000111100000000000000000000000666077777700000000000000
00011111111000000000000000000000000700000000000000000000007555551550000000000155550000000000000000000077776700000070000000000000
00011555dd0000000000000000000000000700000000000000000030807011111100000000000155555000000000000000000000766700000070000000000000
00011555dd0000000000000000000000000700000900000000000000007dd5111dd0000000000555555000000000000000000000055700000070000000000000
000115555d0000000000000000000000000700000000000000000000007dd5111dd0000000000500555000000000000000000000666700000070000000000000
00011111111000000000000000000000000700000000000000000000007555111550000000000055055000000000000000000077776700000070000000000000
000111555dd000000000000000000000000700000000000000000000007011111100000000000555555000000000000000000000766700000070000000000000
000111555dd0000000000000000000000007000000000000000000000075555515d0000000000055555000000000000000000000055700000070000000000000
0001115555d000000000000000000000000700000000000000000000007dd55515d0000000000111100000000000000000000000666700000070000000000000
00011111111000111000000000000000000700000000000000000000007555551550005555001115555000000000000000000077776700000070000000000000
00011555dd00015051000000000000000007000000000000000000000070111111011105551111155550000000000000000000007667000c0070000000000000
00011555dd0001505100000000000000000700000000083000000800007dd5111dd1111000111115555000000000000000000000055700000070000000000000
000115555d0001505100555555555555550700000000000000000080007dd5111dd11111155555155550000000000000000000006667c0000070000000000000
000111111110011111101111111111111507000000000000000000000e7555111551551510555515555000000000000000000077776700000070000000000000
000111555dd001010510001100000011000700000000000000000000007011111101551555555515555000000000000000000000766700000070000000000000
000111555dd0010105100015000000150007000000000000000000000075555515d0550555555505555000000000000000000000055077777700000000000000

__gff__
0000000000000000000000000000000002020202080808000000000000060606030303030306030303030303030606060303030303030303030303030306060600000000000000000000000604040404030306060606060000000006040303030404040404040604040000040603030304040404040404030303030303030303
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
25252e552f00704e0000000000000000252555253e3f0000000000000000003d25252525252f00000000000000000000252600000000004e00006d6e252525256f000000000000000000006d2526000000000013243825253233005b003132250000000000000000000000000000000000000000000000000000000000000000
552525253f4d4c4f6000000000000000252e252f0000000000000000000000002d252525253f00000000000000000000253300000000004e600031252525256e6f00000000000000000000242526000000000013242525260000005b000000310000000000000000000000000000000000000000000000000000000000000000
2525252f00004e016c6c0000004400002525252f0000000000000000101010002d25253e2f000000000000000000000026000000004d4d4c4d4d4d6d252525257f000000000000001010107d7e33101010000013312525265353533e535353530000000000000000000000000000000000000000000000000000000000000000
2e2e3e3f00132122222312000000000025252e251f00000000000000404141003d252f005b00000000000000000000002600000000000000000000246e25256f00000000000000004041414141414141410000001324382600750073007300000000000000000000000000000000000000000000000000000000000000000000
253f0000001331323233120000000000253e2525252f00000000000000000000002d2f006b00000000000000000000002600000000000000000000243825256f00000000000000004100000000000000000000001324252660000074007500600000000000000000000000000000000000000000000000000000000000000000
3f0000000000111111110000000000003f002d55672f00000000000010101000002d3f00730000000000000000000000261010101010100000001031327e7e7f000000000000000041000000000000000000000013242525230000000000006c0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000002d2568251f000000000040414100006b00007300000000000000000000002022264041412700760040414141414100000000000000000000005d5e2222231200000013242525266c7671727600210000000000000000000000000000000000000000000000000000000000000000
004748480000000000000042434300005e5e5e5e5e5e5e5e5f0000000000000000000000740000000000000000000000252526410000304d4d4d4100000000000000001010000000000f006d6e253826120000001331252525222222222222250000000000000000000000000000000000000000000000000000000000000000
00570000000000000000004300000000256e6e25256e7e7e7f0000000000000000000000000000000000000000000000253833410000370000004100000000000000005d5f0000000000002438252526100000000013242525382525252525250000000000000000000000000000000000000000000000000000000000000000
0057000000000000000000431d1e1f0025252525256f40414100000000000000000000000000000000000000000000002526004100000000001d5d5e5e5e5e5f1010106d6f0000006000007d25252525231200000013242525252525252538250000000000000000000000000000000000000000000000000000000000000000
0000000000000040414100002d2e251f25252525256f41000000000000000000000000000a0000000000000000000000203300004e00001d1e2e6d25252525255e5e5e256f0000006c60000024252538261200000013313232323232323232320000000000000000000000000000000000000000000000000000000000000000
0058000000000041000000002d55252e25252525386f4100001010101010000000000000000000000000000000000000264d4d4d4c4f002d25257d2525256e25252525256f4d4d4c4d4d4d4d2438252526100000000040414141412e2f00002d0000000000000000000000000000000000000000000000000000000000000000
00000000000000000000001d2e25562525253832327f4100002135353536000000000000000000000000000000000000260000004e001d2e25252e6d25257e7e256e25257f00004e000000006d38252525231200001d410000000025561f002d0000000000000000000000000000000000000000000000000000000000000000
000000000000000000001d2e252566252525260000004100003025253f00001000000010000000000000000000000000260001004e1d25252525556d257f2f007d7e256f4d4d4d4d4d4c4f002425252525261200002d410000000025662e1e250000000000000000000000000000000000000000000000000000000000000000
5e5e5e5e5e5e5f17172122222222222225252600000041000030252f00001340000013400000000000000000000000002614151621222325252e256d6f2e2f0000007d6f00000000004e00006d382525382612001d25212222222222222222220000000000000000000000000000000000000000000000000000000000000000
2525252525256f000024252025383825252526767172410000303e3f000013410000134100000000000000000000000026000000243826552525256d6f25251e1f00007800000000004e00006d252525252612002d2e243825252538383825250000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000025252022225f41000037000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000025252525202641000000000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000007e7e7e7e7e7f41000000000000000000000000000000001340410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000730073000000000000000000000000000000000000001341000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000730074000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000730000000000000000000000000000000000000000000000000010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000740000000000000000000000000000000000000000000000000040414141000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000041000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000010000000101010101010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000010101079000000404141414141410000001000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000040414178000000410000000000000000007900000040411200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000781f0000000000000000000000007700000041001200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000078551e1e1f0000000000000000005b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000600100782555252e1f00000000000000005b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000005d5e5f78252525252f00000000000000002d1f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000006d256f7825255525251f000000000000002d2f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

