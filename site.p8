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
--[[param_names = {"badeline num", "comment"}
autotiles = {{52, 54, 53, 39, 33, 35, 34, 55, 49, 51, 50, 48, 36, 38, 37, 32, 29, 30, 31, 41, 42, 43, nil, nil, nil, nil, nil, 56, 45, 46, 47, 80, 44, 81, [41] = 61, [42] = 62, [43] = 63, [0] = 48, [44] = 57, [45] = 58, [46] = 59, [56] = 40, [57] = 60}, {29, 31, 30, 29, 29, 31, 30, 61, 61, 63, 62, 45, 45, 47, 46, 48, 52, 53, 54, 32, 41, 42, 43, nil, nil, nil, nil, 39, 33, 34, 35, 56, 80, 44, 81, nil, nil, nil, nil, 48, 36, 37, 38, [45] = 57, [46] = 58, [47] = 59, [52] = 55, [53] = 49, [0] = 29, [54] = 50, [55] = 51, [57] = 40, [58] = 60}, {41, 43, 42, 41, 41, 43, 42, 57, 57, 59, 58, 80, 80, 81, 46, 44, 48, 52, 53, 54, 32, 56, nil, nil, nil, nil, nil, 60, 39, 33, 34, 35, 29, 30, 31, nil, nil, nil, nil, 40, 48, 36, 37, 38, 45, 46, 47, [53] = 49, [54] = 49, [55] = 50, [0] = 41, [56] = 51, [57] = 61, [58] = 62, [59] = 63}}
]]
--@begin
--level table
--"x,y,w,h,exit_dirs,badeline num"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
levels={
  "0,0,1.4375,1,0b0001,1,bg tilling at end could be tweaked",
  "1.4375,0,2,1,0b0010,1,needs a bit of polish/slightly more interesting terrain (maybe good bg tiling is enough); last dream block should be wider",
  "3.4375,0,1.5625,1,0b0010,0,",
  "5,0,1,1,0b0010,1,maybe slightly modify block target",
  "6,0,1,1,0b1000,1,0",
  "0,1,2.1875,1,0b1000,0,needs to be retiled; a bit big/empty rn could be compactified; not sure about cam trigger",
  "2,3,1,1,0b0001,2,i wonder if there is a way to telegraph the block movement. on the other hand kinda funny moment.",
  "0,2,1,2,0b0001,3,left side needs polish; lags but might not w/ new dreamblocks",
  "5,1,1,1,0b0001,0,left dreamblock looks a bit smol",
  "1,3,1,1,0b0010,0,left side needs slight retiling; block should go all the way left",
  "3,1,1,1,0b0001,2,needs some bg tilling to look less weird; berry is maybe a tad too tight",
  "6,1,1,1,0b0001,3,feels like it's missing something, but maybe it's fine.",
  "4,1,1,1,0b0001,3,can remove dash crystal and/or add one at the end.",
  "7,0,1,4,0b0010,5,should use a cam trigger so falls are less blind; 2nd berry is too hard (add a roundabout?); badeline num seems maybe excessive; probably need to nerf length/ending",
  "1,2,1,1,0b0010,0,0",
  "3,2,1,1,0b0001,1,lacks substance",
  "2,2,1,1,0b0001,1,might be better as a non badline level",
  "4,2,3,1,0b0010,2,berry exit needs a nerf; also can cheese berry by just tanking a death; ending dream block layout can maybe be more interesting",
  "3.875,5.375,1,3,0b0100,4,like this less than the 1st vertical chase level. maybe should split into 2+ levels (send back to designer?); ending of long dreamblock should be more lenient",
  "1.125,5.375,2.375,1.25,0b0001,1,wayyyy to open. needs significat rework",
  "0,6.8125,2.4375,1.25,0b0001,3,too gimmicky. start is kinda neat, but i don't like the rest",
  "0.125,8.25,1,1,0b0001,1,feels like a concept level but works surprisingly well. just need to make it a little bit more interesting. big berry potential",
  "1.1875,8.25,1,1.0625,0b0010,1,gimmick level, don't think there's anything to do with ti.",
  "0.125,9.375,2,1,0b0010,0,needs tweaks ofr both tiling and terrain. overall good tho",
  "3.5625,9.375,1,1,0b0001,0,mirror room- needs mirror (also don't love terrain - might just rework this once we have mirror)",
  "4.6875,9.3125,2,1,0b1000,0,don't love berry route; don't like camtriggers; decent concept but lacking polish",
  "6.8125,9.3125,1,1,0b0001,0,non berry route kinda lacking(replace berry with token?);  pretty good concept -  but missing some polish",
  "0.0625,10.5625,1,2,0b0010,1,not sure about token block phasing through wall",
  "1.3125,10.5,1,1,0b0001,1,0",
  "2.5625,10.5,1,2,0b1000,1,exit needs to be better telegraphed; not sure about cam trigger (maybe put it after the dream block so it's less zoomy?)",
  "3.6875,10.4375,1,1,0b0010,3,a lot of potential, but not interesting enough rn",
  "0.0625,12.6875,2,1,0b1001,0,tiling around berry feels a tad weird",
  "0.125,13.8125,3,1,0b0100,0,not sure about tiling of first blue block; need to figure out what's gonna happen to the berry if doing level duplication stuff",
  "3.25,12.8125,1,2,0b0010,0,seems like it's built for branching paths, but we aren't doing those?"
}

--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
  {
    "3,8,4,5,32,0"
  },
  {},
  {},
  {},
  {},
  {
    "19,2,3,5,-32,0"
  },
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {
    "16,2,1,5,15,0",
    "15,2,1,5,0,0"
  },
  {},
  {
    "27,9,5,5,-45,0",
    "13,9,3,4,-30,0"
  },
  {},
  {},
  {},
  {
    "11,18,3,3,0,-40"
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
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  "2e2e2e3e3e3e3e3e3e3e2e2e2e2e3e3e2e3e3f000000000000002d2e3e3f00002f000000000f000000102d2f000000002f1000000000000000213d3f000000002e1f00000010000000312600000000002e2f00000027000000003000000034222e3f000000301000000030000f0013243f000000003123000000300000001324000000000013300000003700000013240000000000133000000000000000132400000000001330000000000000001324000100000013370000000000000013241e1f00000000000000000000001010242e2f10101010000000000010101d1f312e2e1e1e1e1f10101010101d1e2e2e1e2e2e2e2e2e2e1e1e1e1e1e2e2e2e2e2e",
  "25252525252025252526404141412425253232252525253232264100000024252611112425323300003741000000312526000031330000000000000000000024260000000000000000000000000000242600000000000000000000000000002426000000000000000000000000000024260000000000212300000000000000242600000000003126000000000000002426000000000000300000002123101024260000000000003700000024252222252600000000000000000000242525252526000000000000000000002425202525252223000100000000000024252525252025252222222222222222252525202525252525252525252525252525252525",
  "25260000242525252532322525252025252600003132323233000031322525252526404141414141410000000024252525264100000000000000000000313232252641000000000000000000404141412526410000000000000000004100000025260000000000212222222341000000252522222235353232252526410000002025253233000000002425252300000025252640414141414124252526000000252526410000000000313225260000003225264100000000000000313300000000313341000000000000000000000000000000000021222223000000000000000001000000242525252222222222222222222222222525202525252525252525",
  "323232323225252025252525252525252525253232323232323232323232252525252525252525252525323232252525000000000031252525253232323232252520260000000040414141000000242525252532323232252526000000312525000000000000242525260000000000313225260000000041000000000a00242025253300000000242533000000002425000100000000242525330000000000000024260000000021222223000000242525260000000000242600000000002425222300000000242526000000000000000031330000000024252525222222252525260000000000313300000000002425253300000000242526000000000000000040410000000031323232322525252532330000000000404100000000003125260000000000242526000000212300000041000000000000000000003132323340410000000000410000000000000031260000000000242526000000312600000041000000000000000000000000000041000000000000410000000000000000260000000000313233000000133000000041000000000000000000000000000041000000000000410000000000000000260000000000404141000000133000000041000000000000000000000000000041000000000000410000000000000000260000000000410000000000133700000041000000000000000000000000000041000000000000410000000000212222260000000000410000000000000000000041000000000f00001010100000000041000000000000212300000000312525260000000000410000000000000000000041000000000000002122230000000000000000000010242600000000002425261010000000410000000000000000000000000000000000002425330000000000000000000021252600000000002425252223000000000000000000000000000000000000000000002426000000000000000000000024202523000000002425252526000000000000000000000000000000000000000000002426000000000000000000000024252526000000002425",
  "2532323232323232323232323300002426000000404141414141410000000024260000004100000000000000000100242600000021222235353535352222222526000000243233000000000024202525260000003012000000000000242525322600000030120000440000002425260026000000301200001000000024252600260000003012000027120000242533002600000037120000301200002426000026000000000000003012000024260000260000000000000037120000242523002600000000000000000000002425252226000010100000000f0000003132252526101021230000000000000047482425252222252600000000000000570024252525252526000000101010105700242525202525261010102122222300002420252525253235353532323233000024252525323300000000000000000000242525260000000000000000000000002425253300000000100000000000580024252600000000002700000000000000242533000000000030000000000000002425000000000000300000000000212225250000000000003000171700002425253200000000000030000000101024252600000000171700301010102122252533000000101010102422222225252526000040412122222225252520252525252300410024252525252525252525252525224100242532323225252532323225252500003133000000313233000000313225000040414141414141414141414141240000410000000000000000000000002400004100000000000000000000000024000000212222230000002122230000242222222525252535353532323300002425252525202526000000000000424324253232322525260000000000004300242600000031323342430000000043002426404141000000430000000000000024264100000000004300000000000000242641000000000043000000000000002426410000000000000000000000000024264100001010101010100000000000242600000021222222222310101010102426000000242525252525222222222225",
  "47484831323232323232323232323232323232323232323232322525252525252525252525255700000000000000000000000000000000000000000000000000312525252525252525252525570000000000000000000000000000000000000000000000000000242525252525252525252500000000000000000000000010101000000000000000000000000031252525252525252525250000000000001010100000001d1e1f00000010101000000000000000242525252525252525250000000000004041410000002d2e2f00000040414100000000000000312525252525252525255800000000004100000000002d2e2f00000041000000000000000000002425252525252525250000000000004100000000002d2e2f00000041000000000000000000003125252525252525250001000000004100000000002d2e2f000f0041000000000000440000000031323225252525252222230000004100000000002d2e2f00000041000000000000000000000000000031252525252525260000004100000000002d2e2f00000041000000000000000000000000000000312525252525260000004100000000003d3e3f000000410000000000000000000000000000000024252525252600000011111100000011111100000011111100000000000000000000000000002425252525260000000000000000000000000000000000000000000000000000000000000000242525252526000000000000000000000a000000000000000000000000000000000000000f0024252525252609000000000000000000000000000000000000000000000000000000000000002425252525261400001010100000001010100000001010100000001010101010101010000000242525252526000013404141000013404141000013404141000013404141414141414100000024252525252600001341000000001341000000001341000000001341000000000000000000002425252525260000134100000000134100000000134100000000134100000000000000000000242525",
  "252525252525252525252525253232323232323232322525252525252525264748482425252525252525252525252532323232334400004041410000003132323225252525265700002425252525252525323232323300000040414141410021230000000000000031323232335700003132252525252526000000000040414121230000000024260000000000000000000000000000000000242525252526000000000041000024260000000024252300000000000000000000000000000000242525252526000001000041000024261010101024252522222222222300000000000000001010242525252525222222222222222225252222222225252525252525252600000000005810004041242525252525252525252525252525252525252525252525252525252600000000001337124100242525252525323232323232323232323232323232252525252525252600000000000011004100242525252526000000000000000000000000000000242525252525252600440000000000004100242525252526000000000000000000000000000a0831252525252525260000000000000000410024252525252600004400000000000000001010000000313225252525261010100000000000000024252525252600000000000000000000083436120000000031323232323535360000000000000024252525252600000000000000000000000000000000000000000000404141410000000f00000024252525252600000000000000000000000000000f0000000f0000004100000000000000000000242525252526000000000000001717170000000000000000000000004100000000000000000000242525252526000017171700000000000000000000000000000000000000000000000000000000242525252526000000000000000000000000000000000000000000000000000000000000000000242525252526000000000000000000000000000000000000000000000000000000000000000000242525252526000000000000000000000000000000000000000000000000000000000000000000242525",
  "25323232323347484848313232323225260000000000570000000000000000242600000000005800000000000000002426000000000010101010000000000024260000440000404141410000440000242600000000004100000000000000002426424343434341000000424343434324264300000000410000004300000000242643000000004100000043000000002426000000000041000000000000000024260000440000410000000000440000242600000000004100000000000000002426000000000011111111000000000024260000000000000000000000000000242600010000002122222300000000002425222222222225252525222222222225",
  "2e2e3e3e3e3e3e3e3e3e2e2e2e2e2e2e2e2f00000000000000003d3e2e2e2e2e2e2f000000000000424300003d3e2e2e2e2f0000000000004300424300002d2e2e2f0000000000004300430042432d2e2e2f0000000042430000430043003d3e2e2f00000000430042430000430000002e2f0001000043004300424300001d1e2e2f1415424300004300430042432d2e2e2f0000430042430000430043002d2e2e2f0000430043004243000043002d2e2e2f0900000043004300424300002d2e2e2e1e1e1e1f00004300430042432d2e2e2e2e2e2e2e1e1f0000430043002d2e2e2e2e2e2e2e2e2e1e1f000043002d2e2e2e2e2e2e2e2e2e2e2e1e1f00002d2e2e2e2e2e2e2e2e2e2e2e2e2e1e1e2e2e",
  "2e2e2e2e2e2e3e2e2e3e3e3e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e3e3f003d3f0000003d3e3e2e2e3e3e2e2e2e3e3e3e2e2e2e2e2e2e2e2e2e3e3f00000000000000000000003d3f00002d2e3f0000003d2e2e2e2e2e2e2e3f00000000000000000000000000000000002d2f00000000002d2e2e2e2e2e2f1200000000000000000000000000000000002d2f00000f00002d2e2e2e2e2e2f1200000000000000000000000000001000002d2f00000000002d2e2e2e2e2e2f12000f0000101010000000000000001d00002d2f00000000002d2e2e2e2e2e2f12000000001d1e1f000000000000002d00003d3f00000000002d2e2e2e2e2e3f12000000002d2e2f000000000000002d000000000000100000002d2e3e2e2e0000000000003d2e2f000042434300102d0000000000001d0000002d2f003d3e000000000000132d3f0000430000001d2f0000000000102d0000003d3f000000000000000000132d000000430000002d2f14000000001d2f0000001111000000000000000000133d000000000000002d2f00000010102d2f10000000000000000001000000000000000010000000102d2f1010101d1e2e2e1f000000000000001e1e1e1f1010101010101d0000001d2e2e1e1e1e2e2e2e2e2f101010101d1e1e2e2e2e2e1e1e1e1e1e1e2f0000002d2e2e2e2e2e2e2e2e2e2e1e1e1e1e2e2e2e",
  "2e2e2e2e2e2e2f000000002d2e2e2e2e2e2e2e2e2e2e2f000000002d2e2e2e2e2e2e2e2e2e2e2f404141412d2e2e2e2e2e2e2e2e2e2e2f410000002d2e2e2e2e3e3e3e3e2e2e3f410000003d2e3e2e2e000000003d3f0041000000003d002d2e00000000000000000000000000002d2e00000000000000000000000000003d2e0001000000000000000000000000002d1e1e1e1f00000000000000000000002d2e2e2e3f0000000000000000001d1e2e2e2e2f00001d1e1e1e1e1e1f002d2e2e2e2e2e1e1e2e2e2e2e2e2e2e1e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e",
  "2e2e2e2e2e2e2e2e2e2e2e2e2e2e3e2e2e3e3e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e3e3f113d3e11112d2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e3f111100111100002d2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e3f11000000000000002d2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2f1200000a00000000002d2e3e2e2e2e3e2e2e2e2e2e2e3e3e2e2e3e2e2e2e2e2f1200000000101010102d3f003d3e3f002d2e2e2e2e2e00003d3f003d2e2e2e2f12000000131d1f40413f0000000000003d3e3e2e2e2e0000000000002d2e2e2f12000000133d3f4100000000000000000000003d2e2e0000000000002d2e2e2f12000000000000000000000000000000000000002d2e0000000000003d3e3e3f12100000000000000000000040414100000000003d2e1e1e1e1f4041414141414141000000000000000000004100000000000000002d2e2e2e2f4100000000000000000000000000000000004100000000000000002d2e2e2e2f4100000000000000000000000000000000000000000000000001002d2e2e2e2f41000000000000001d1e1e1f00000000000000000000001d1415162d2e2e2e2f00000000000000002d2e2e2f00000000000000000000002d0000002d2e2e2e2e1e1e1e1e1e1e1e1e2e2e2e2f00000000000000000000002d0000002d",
  "2e2e2e2e2e2e3e3e3e3f0000002d2e2e2e2e2e2e2e3f000040410000002d2e2e2e2e2e2e2f00000041000000002d2e2e2e2e2e2e2f00000041000000002d2e2e2e2e2e2e2f00000041000000002d2e2e2e2e2e2e2f0000001d1f1010102d2e2e2e2e2e2e2f0000002d2e1e1e1e2e2e2e3e3e3e2e2f0000003d3e3e3e3e2e2e2e0000002d2f00000040410000003d2e2e000f002d2f0000004100000000003d3e0000002d2f0000004100000000000000000a003d3f000000410000000000000000000040410000001d1f00000000000000000041000000002d2f00000000010000000000000000002d2f10101e1e1e1e00000000000000002d2e1e1e2e2e2e2e",
  "00000000000040414141242525252525000001000000410000003125252525252a2a2a2a222341000000003125252525252525252526410000000000242532252525252525264100000000003133002425252525252641000000000000000024252525252526410000000000000000242525253225304100000000000000002425253300243041000000000044000050252600003130410000000000000000502526000000304100000000000000005025260000003041000000000000000050252600440037410000000000101010502526000f0000410000001010292a2a2525330000000041000000292a252525255100000000004100000050252525252551000000000021222a2a2525252525255100001010102425252525252525252551000034222232323232252525252525510000113133404141413125252525253b00000011114100000000312525252526000000000041000000000024252525260000440000410000000000312532322600000000004100000000000030580026000000000041000000000000300000260000000000410000000000003000002600000000004100000000000031222226100000000041000000000000003132252b101010004100000000000000474825252a2a2310410000000000000057002525252525234100000000000000570025252525252641000000212222222222",
  "2526474848312532323225323225252525265700000030120013300000313232252600000000301244133000000000002526000000000000000000000000440025260000000000000000000000000000252600000000000000000000003422222526000000000000000000000000242525265800000000101010000000003125252600000000004041410000000000312533000000000041000000000000000026000000000000000000000044000000260000000000000000000000000000002600000000000000000000000000000026010000212a2a2a2a2a2b10101021222614162125252525252525222222252526000024252525252525252525252525",
  "2525252525264041414100000024252525252525252641000000000a002425252525252525264100000000000024252525252525252600000000212222252525323225252526000f00002425252525250000313232330000001024252525252540414141414100000021252525252525410000000000000f003132252525252541000000000000000000003132252525000000002123000000000000002425252600001024260000000000001024252526100021252612000000000834252525252310242526120000000000002425252525222525261200000000000031252525252525252612000000000000002425252525252526120000000000000024252525252525261200000000000000242525252525252522222222231415162425252525252525252525252640414129252525323232252525252526410000502532330000003132252525264100005025000000000000003132323341000050250000000000000040414100000000242500000000000000410000000000002425000000000000004100000000000031250000000000000021222300000000002400000000000000242526101000000024000000000000002425252a2b101010240000000009000024252525252a2a2a25010000002700002425252525252525252223000030000024252525252525252525260000300000242525252525252525",
  "25252525252525252525252525265800252532323232323232323232323347482526000000000044000000000000570025260021222317171721222315212222252600242526000000242526002425252526003125330000003125330024252525260000370000000000370000242525252600000000004400000000002425252526002122231717172122222225252525260024252600000024252525252525252600242526000000242525252532252526002425260000002425253233002425260031323300000031323300000024252600000000004400404141000001242525222222222222222222222222222525252525252525252525252525252525",
  "3e3e3e3e3e3e3e2e2e2e2e2e3e3e3e3e3e252025252525252525252525202525000000000000003d3e2e2e3f00000000003d25253232202532323232323232320000000000000000002d2f000000000000003d260000312600134041000000000000000000000000002d2f0000000000000000300000003000134100000000002223000000000000002d2f000000000000000030000a003000134100000000012526000000000000002d2f40411d1f0000000030000000300013410000001d1e2533000010101000003d3f41002d2f0000000037000000370013410000002d2e260000134041411200000011112d2f14150000404141414100001d1f00002d2e260000134100001200000000002d2f00000000410000000000002d2f10102d2e260000134100001200000000002d2f00000000410000000000002d2e1e1e2e2e260000000000000000000000002d2f00000000410000000000002d2e2e2e2e2e26000000000f000000000000002d2f00000000000000000000002d2e2e2e2e2e260000000000000000000000002d2f00000000000000000000002d2e2e2e2e2e261000000000000000001010102d2f00000000000000001010102d2e2e2e2e2e251f10101010101010101d1e1e2e2f10101010101010101d1e1e2e2e2e2e2e2e25201e1e1e1e1e1e1e1e2e2e2e2e2e1e1e1e1e1e1e1e1e2e2e2e2e2e2e2e2e2e",
  "2025252538260000003131323232382520252525253232323225253825261010101010243825260000000000000000003232322025330000000000000000242525253825330000000024382525202222222222222525262b0000000000000000000000242600000000000000000024382525252600000000003132323232323225252025252525232b000000000000000000002426000000000000000021252532323233000000000000000000001324203232323238252522230000000000000000002438222223000040414124203300000000000000000000000000001331330000000031323232332b0000000000000000242532322022234100002426000000000000000000000000000000001111000000000000000000502b00000000000000313300003138264100003133000000000000000000000000000000000000000000000000000a0050510000000000000000000000002426410000000000000000000000000000000000000000000000001010000000000050282b0000000000000000000000312641000000000000000000000000000000000000000000001516212300000000292c3c51000000000000000000000000374100000000000000000000000000001d230000000000000000313314151516502c2e3c2b000000000000000000000000000000000000000000000000000000242f1010000000000000000000000000503c2e3c2c2a2b0000000000000000000000000000000000000000001d1f000024252223000000000000000000000029283c2e2e3c282c000100000000000000000000000000000000000000242f00002425382f00000000292a2a231010292c3c2e2e2e2e2e2e2a2a2b000000000000000000000000292a2a2b1010242600003e25252f00000000502c283c23141621231415162122223c282c2a2a2a2b0000002122222223502c28511d22382600002420252f10101010393c2e282600002426000000242520000000283c2c51212222222025252650283c512425252f00003e252538222222222350283c512e2e2426000000243825",
  "2e2e2e2e2e2e2f00002d2e2e2e2e2e2e2e2e2e2e3e3e3f00003d3e3e2e2e2e2e3e3e3e3f00000000000000003d2e2e2e000000000000000000000000002d2e2e000000000000000000000000002d2e2e000000000000000100004041412d2e2e1e1f1200131d1e1e1e1f4100002d2e2e2e2f1200132d2e2e2e2f4100002d2e2e2e2f1200133d3e3e2e2f4100003d3e3e2e3f1200000000003d3f4100000000002f0000000000000000004100000000002f0000000000000000004100000000002f00000000000000000000001d1e1e1e2f10000000000000000000002d2e2e2e2e1f101010101000000000002d2e2e2e2e2e1e1e1e1e1f00000000002d2e2e2e2e2e2e2e2e2e2e1e1f0000002d2e2e2e2e2e3e3e3e2e2e2e2f0000003d3e2e2e2e3f1111113d3e3e3f00000000002d2e2f110000004041410000000000002d2e2f00000a004100000000000000002d2e2f100000004100000000000000002d2e2e1f1010101d1e1f0000000000002d2e2e2e1e1e1e2e2e2e1e1e1f0000002d2e2e2e2e2e2e2e2e3e3e3e3f0000002d2e2e2e3e3e3e3e3f000000000000002d2e3e3f0000000000000000000000003d3e00000000000000000000000000000000000000000000000000000000000000001e1e1e1e1f00000000000000000000002e2e2e2e2f101010101d1e1e1e1e1e1e2e2e2e2e2e1e1e1e1e2e2e2e2e2e2e2e"
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
0000000000000000577777777777777788cccc8888cccc8888cccc881dddd15ddddd51dd000d0000d00600d01111011115555555555555551500000055505500
00008000000b000077777777777777778c0000c88c0000c88c0000c8d555515555d551550d0d0d000d060d001111011115111111111111111500000011111000
00b00000000000007777ccccccccccccc00cc00cc00c100cc00cc00cd55551555555515500d6d000006760001111011115000000000000001500000000000000
0000000000000000777cc7ccccccccccc0c00c0cc010c10cc00cc00cd555111111111111dd676dd0667776600000011115000000000000001500000000000000
0000b000080000b077ccc7ccccccccccc0cccc0cc01cc10cc00cc00c555111111111111100d6d000006760001110011115000000000000001500000000000000
0b0000000000000077c77777ccccccccc00cc00cc00c100cc00cc00c55511111111111110d0d0d000d060d001110000015000000000000001500000000000000
00000080000b000077cc777ccccccccc8c0000c88c0000c88c0000c81111111111111111000d0000d00600d01110111115000000000000001500000000000000
000000000000000077ccc7cccccccccc88cccc8888cccc8888cccc88d55111111111111100000000000000000000000015000000000000001500000000000000
7cccccccccccccc71111101100111010111101110000000015555551d5511111111cc11100000001000000001111111100555505111011101110110001101110
77ccccc0cccccc771111101101111010111101110001111050500505d551111111cccc1100000001000000001111111100001111111011101110110001101111
76ccccc0cccc77771111001101111010111101110001111051511515d55111111cc11cc10000010d010000000001111000000000111011101110110001101111
667cccc000ccccc70000000100001010000000110000000051511515555111111cc11cc10001000d000100000000000000000000000011100000000000001111
6ccccccc0ccccc771100000001100000100000000111010051511515111111111cccccc100001006001000001100011100000000111011100000000000000000
7cccccccccccc6771110111101101110110111110111010051511515d55111111cccccc100100d060d0010001110111100000000111011101110110000111111
7cccccccccccc6671110111101101110110111110000000051511515d551111111cccc1100000067600000000000111000000000111000001110110000111111
77cccccccccccc671110111101101110110111110000000051515515d5511111111cc11111dd6677766dd1100000000000000000111000000000000000111111
00000000880008888800088888000888880008888800088851515515155555515000000500000067600000001111011111155555000000001110000000000000
00000050888000808880008088800080888000808880008051510515500000055000000500100d060d0010001111011110151115100001001110000000011110
00000050088808000888080008880800088808000888080051511515500000055000000500001006001000000000011110151155111101101110111100011111
0050050500888000008880000088800000888000008880005151151550000005500000050001000d000100001110011110151555111100100000111100111111
0505051d00088800000888000008880000088800000888005151151550000005500000050000010d010000001110000010155515000000000000111100100111
051d0515008088800080888000808880008088800080888051511515500000055000000500000001000000001110111110155115110011000000000000011011
0515051d080008880800088808000888080008880800088851511515500000055000000500000001000000001110111110151115111011110000000000111111
051d051d888000888880008888800088888000888880008855555555500000055000000500000000000000001110111111155555011001100000000000011111
000000000000000000000000000115000111111500011500000000000dd11dd1011111100d666660066d0d66666d0d660d6666d0011100000000000000000000
00000000000000000000000000010500001010100001050000011100111111d1dd1111ddd6d6666d66dd1ddddddd1ddd1dd6666d111100000001111000001111
000000000000000000000000000151000050505000015100001505101611111066d111d6ddddd66666dd11dddd1111dd1ddd666d111100000000111000001111
00000000000000000000000000005000005050500000500000150510d661116666d11dd60111ddddd6dd1111111111111ddddd6d111100000000000000001111
10000000055555555555555000011500005050500001100000150510dd6611d66dd11dd0d1111110ddd1111000000100011ddddd111101110000001111101111
100000000111111111111150000105000050505000050000001111111dd11ddd6dd111166ddd11d6dd11d6d0ddd0dd10111111dd111101110110100111101111
100000000001100000011000000151000010101000000000001010511ddd66d1ddd111dddddd1ddd0111ddd1ddd1ddd11dd11110111101110110111111101111
15000000000150000001500000005000011111150000000000101051011ddd100dd111dd0dd111d000111dd111111dd1ddd11100111101110110111111101111
62850000748484132323232323232323000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052525262010100000000000300000042
62000000750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052525252223200000001010300000142
23535363000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052525252526201010112226200004352
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052525252525222222252526200000042
00001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052525252522323235252526200000042
53535353415100001222324151516112000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052522352621111114252233300000042
00000000000000001352620000000013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052621113330000001333000000000042
00000000000000000042620414141400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052620000000000000000000000000042
000000000000000000426214000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052330000000000000000000000000042
00000000000000000042621400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000000000000000000042
00000043535353535323621400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000002434000000003142
00000000000000000000031400000042000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000003400000000003142
00000000000000000000031400000042000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000010101000000000001010142
22320101010101010000031400000042000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000122232010000000012222252
23235353535353630000031400000042000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000425252320000010142525252
00000000000000000000031400000042000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000425252620001125323232352
000000000000f0000000031400000042000000000000000000001323232323236200000013232323232323232323238300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000132323330013330000000042
00000000000000000000031400000042008500000000440000000074840000006274848400000000000000008500374200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000310414000000000000a00042
000001010101010101010314000000420000000000000000000000750000000062750000004400c6000000000000374200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000311400000000000000000042
00004353532253535353621400000042000000000001010100000000435322226275d5e5f50000c6c60000000000374200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000001222222222222222222252
000000000003000044000314000000420000000000041414210000000000135262e5525212222222534151617200374200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000001323232323232323232323
00000000000000000000031400000042010000000014000021000000000000426255525242232333000044007300374200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062850000000000111111000000007484
00f000000000f0000000031400000042b20100000000000000010100000000426252525203000057000000003700374200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000000000000000007500
0000000000000000000003140000004282b201010000000031041400000000426252525503f50000000000003747374200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052320000000000010101010101222222
01010101010000000000031400000042c3e2a2b2000000003114000000000042625252520352e504141414122222228300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052522232041414141414141414425252
53535353630000000000031400000042e2c2821500000000000000000000004262e7e7e673525214000000425252525200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052525233140000000000000000135252
00000000000000000000731400000042e2e2e215000000000000000000010142620000d7d6525214000000425252525200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052526200000000000000000000004252
00436300000000000000000000000042e2e2c31501000000000000000012225262000000d6655255f50000425252525200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052523300004400000000000000001352
00440000000000000000000000000042e2e2e282b2000000000000000042525262001000d666e652f60000425252525200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000052330000000000000000000000000042
00000000007200000000000000000042e2e2e2e21501000000000000004252526241516112222222222222835252525200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000717171000000000000000042
22222222226201010101122222222252e2e2e2c2e2b2000000100000004252526200000042525252525252525252525200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000000000000000000042
52525252525222222222525252525252e2e2e2c2e282a2b241515161125252526200000042525252525252525252525200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000062000000000000000000000000000042
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
25252525252525252525267f73007d256e25242525252525252525253232323232253232323225252532323232323232323232252525253e3e3e3e3e3e2e2e2e2e2e3e3e3e3e3e3e3e2e2e2e3e3e2e2e252532323232323232323232323225253832323232323232323232323825252526000000242525252525252525323225
3232323238252525252526007300007d7e7e242525252525323232330000404141300000000024252612000040410000000000312532320000000000003d2e2e2e3f000000000000002d2e2f00003d3e3233000000000000404141000000242526255525257e7e7e2525256f3132323826000000313232323232323232111124
257e7e7e313825252538260073000000000024252525252600000000000041000030004400002425261244004100000000000000305800000000000000002d2e3f00000000000000003d2e2f0000000000000000000000004100000000002425266e7e7e7f0000007d25556f0073003126000000004041414141414100000024
7f000000002425252532330073007172760024252525253300000000000041000030000000003132261200004100000000000000370000000000000000002d2f120000000000000000002d2f0000000000004400000000004100000044002425266f004400000000006d6f7f0073007326000100004100000000000000000024
00000001002425252612000075002122222238252525250000000000000041000037000f00004041301200004100000000000000004748000001000000002d2f120000001010000000003d3f00000000000000000000000041000000000024253822353535360000006d6f000073007325222222222222222222222223000024
0000212222252525261200000000313238252525252525000000000000004100000000000000410030120f0041000000000000000057001e1e1e1f0000002d2f120000001d1f00000f00000000000000222222223600000041000000000024253833000073000000006d6f000075007325252525252525252525252526000024
000031382525252526120000000000132425252525252500000000000000410000000000000041003712000041000000000015151634222e2e3f000000003d3f120000002d2f00000000000000000000252532330000000041000000000024252600000073000000002123141500007325323232323232323225252526404124
000000313232323233120000000000133132323232323800000000000000410000000000000041000000000041000000000000000000242e2f0000000000000000000f002d2f00000000000000000000253300000000000041000000000024252600000075000000002426000000007326000000001111111124252526410024
00000000404141000000000000000000404100006d2524000100000000004100000000000000410000000f0041000000000000000000242e2f00000000000000000000002d2f0000000000000015161d330000000000000041000000000024252600000000000000002426000000000026000a00000000001324252526410024
000000004100000000000000000000004100000a6d252422222300000000410000000000000041000000000041000000000000000000242e2f00000000000000000000002d2f0000000000000000002d0000000000000000410000000000313233000000000000000031335f0000000026000000101000001324252526410024
00000000410000000000000f00000000410076006d252425252600000000000000000000000000000000000000000000000000000000242e3f00000000000000000000002d2f0000000000000000102d000000000000000041000000000047484748000000000000586d256f0001717226101010212312001324253233000024
000000004100000000000000001000004100343536252425252610101000000000000000000000000000000000000000000000000000242f0000000000000000000000002d2f00000000000000001d2e000000000000000041000000000057005700000000605d5e5b2521231415162126404141242612001331330000000024
000000004100000000000000132712004100006d25252425252522222300000000000000000000000000000000000000000000000010242f0000000000000000001010102d2f10100000000000102d2e00010000000000004100000000005700570000006c6c6d252555242600005d2426410000243300000000000000000024
101010102122231200000000133012004100006d25252425252525252600000000000000000000000000000000000000000000000021252f0010101010101010101d1e1e2e2e1e1f10101010101d2e2e222222222300000021222358002122222222222a2a2a2a2a2a2a38265d5b6e2426410000370000000000000000000024
222222223825261200000000133012132122222222223825252525252610101010101010101010101010101010101010101010101024252f101d1e1e1e1e1e1e1e2e2e2e2e2e2e2e1e1e1e1e1e2e2e2e252525252600000024252600002425252525252525252525252525266e55252426000000000000000000001010101024
252525252525261200000000133012132425252525252525252525252522222222222222222222222222222222222222222222222225252e1e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e252525252600000024252600002425252525252525252525252525262525552426000000000000000000002122222225
3e3e3e3e3e2e2e2e2e2e2e2e2e2e2e3e3e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e000000000000000000000000000000000000000000000000242600002425260000242538323238252525252525266e25313238252538323232323232382e2e2e2e2e2e2c51120000132425252526000000000000000000002425252525
00000000003e3e3e3e3e3e3e3e3e3f00003d3e3e3e3e3e3e3e3e3e3e3e3e3e3e2e2e2e000000000000000000000000000000000000000000101010242640412425260000243233111124253832382525265525552531323226552525256e25312e2e3c282e3c3a3b120000133125252526000000101021222222222525252525
00000000000000000000000000000000000000000000404141410000000000003d3e2e000000000000000000000000000000001010101010292a2a242641002432260000370000000031323311242525337e7e7e7e7e7e6e30257e7e7e7e6e552e2c3a3a3a3b0000000000000024252526000000212225252525252525252525
000000000000000000000000000000000000000000004100000000000000000000002d000000000000000000000000000000003435353535353535323341002400370000730000000073007300242525000073007375007d307f001010007d7e2e51000000000000101010100031322525353600242525252525252525252525
1e1e1f141500001010101010100000000000000000004100000000000000000000002d00000000000000000000000000000000003011111100000000000000240075000073101010007300730031382500007400730000003000003436000f003c51000000000000404141410000002426000000242525252525252525322525
2e2e2f000000004041414141410000000000000000004100000000000000000000003d000000000000000000000000001000000030120000000000000000002400000000734041410074007300002425100000007300404130000040410000002e51100000000000410000000000002426003435323225252525252533112425
2e2e3f0000000041000000000000000000000000000041000000000000000000000000000000000000000000000000002b10101030120a001010000000101024101000007341000000000073000024252b100000740041003000004100000000283c2b0000000000000000000000002426000000000031253232323300003125
2e3f00000f00004100000000000000000000001d1e1e1e1e1e1e1e1e1f000000000000000000000000000000000000002c2a2a2a2612000021231010102122252a2b101073111111000000730f002425282b10100000000037000021231010102c3a3b0000000000000000000000002426000000000000300000000000000024
2f0000000000004100000000000000000000002d2e2e2e2e2e2e2e2e2f00000000000000000000000000000000000000253532252612000024264041412425253c2e2a2b5b5b5b5f00101073005d24253c2e2a2b0000000000000024382222223b00001010000000000000000000002425222223000000300000000000000024
2f0000000000004100000000000000000000002d2e2e2e2e2e2e2e2e2f00000000000000000000000000000000000000260000313300000031264100003125252e2c28517e7e25255b40415b5b2524252e2c28510000000000000024252525250000004041000000000000000000003125252526000000300000001000001324
2f0000000000000000000000000000000000002d2e2e2e2e2e2e2e2e2f00000001000000000000000000000000000000260000000000000000374100000024252e2e2e5110007d7e7e41007e6e2524252e2e2e510000000000000031323825250000004100000000000000000000000025252526000000300000002100000024
5100000000000000000000000000292a2a1e1e2e2e2e2e2e2e2e2e2e2e1e1f1415161d00000000000000000000000000260000000000000000000000000031252e2e3c2c2b007373001111007d7e24252e2e3c511000000000000000002425250000004100000000000000000000000025252526000000370000003012000024
5110101010101010101010101010502c2c2e2e2e2e2e2e2e2e2e2e2e2e2e2f0000002d0000000000000000000000000026000000000000000000000f000000242e2e2e285100737400000000101024252e2e2e282b00000000000000002425250000000000000000000000000000001025252526000000000000003000000024
282a2a2a2a2a2a2a2a2a2a2a2a2a283c2c2e2e2e2e2e2e2e2e2e2e2e2e2e2f0000002d00000000000000000000000000260000000000000000000000000000242e2e2e2e5110747400000000212238252e2e2e2e511000000000000000242525000000000f000000000000000000002125252526000000000000003000000024
2c2c2c3c2c2c3c3c2c282c3c3c2c3c3c2e2e2e2e2e2e2e2e2e2e2e2e2e2e2f0000002d00000000000000000000000000260001000000000000000000000000312e2e2e2c2e2b747400000100242525252e2e2e2c2e2b717200010000213825250000000000000000000000000001002425252526000000000000001100000024
2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2e2f0000002d00000000000000000000000000261416270000000000000000000000002e2e2e2c2e282a2b14151516242525252e2e2e2c2e2e2a2b14151516242525250000000000000000000000212314162425252526000000000000002100000024
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
