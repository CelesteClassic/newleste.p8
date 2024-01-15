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
for i=0,36 do
  add(particles,{
    x=rnd128(),
    y=rnd128(),
    s=flr(rnd(1.25)),
    spd=0.25+rnd(5),
    off=rnd(),
    c=6+rnd(2),
    -- <wind> --
    wspd=0,
    -- </wind> --
  })
end

dead_particles={}

-- [player entity]

player={
  init=function(_ENV)
    djump, hitbox, collides,layer = max_djump, rectangle(1,3,6,5), true,2

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
          -- <cloud> --
          local cloudhit=check(bouncy_cloud,0,1)
          if cloudhit and cloudhit.t>0.5 then
          	spd.y=-3
          else
          	spd.y=-2
          	if cloudhit then
          		cloudhit.t=0.25
							cloudhit.state=1
          	end
          end
          -- </cloud> --
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

      -- <green_bubble> --
      if djump>0 and dash or do_dash then
        do_dash=false
      -- </green_bubble> --
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
  init=function(_ENV)
    layer=2
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
  init=function(_ENV)
    layer=3
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

-- <cloud> --
bouncy_cloud = {
  init=function(_ENV)
    break_timer=0
    t=0.25
    state=0
    start=y
    hitbox=rectangle(0,0,16,0)
    semisolid_obj=true
    particles={}
  end,
  update=function(_ENV)
    --fragile cloud override
    if break_timer==0 then
      collideable=true
    else
      break_timer-=1
      if break_timer==0 then
        init_smoke()
        init_smoke(8)
      end
    end

    local hit=check(player,0,-1)
    --idle position
    if state==0 and break_timer==0 and hit and hit.spd.y>=0 then
      state=1
    end

    if state==1 then
      --in animation
      spd.y=-2*sin(t)
      if hit and t>=0.85 then
        hit.spd.y=min(hit.spd.y,-1.5)
        hit.grace=0
      end


      t+=0.05

      if y-start > 6 and #particles==0 then
        make_cloud_particles(_ENV)
      end

      if t>=1 then
        state=2
      end
    elseif state==2 then
      --returning to idle position
      if sprite==65 and break_timer==0 then
        collideable=false
        break_timer=60
        init_smoke()
        init_smoke(8)
      end

      spd.y=sign(start-y)
      if y==start then
        t=0.25
        state=0
        rem=vector(0,0)
      end

    end
    for p in all(particles) do
      p.t-=0.25
      p.y+=0.3
      if p.t <0 then del(particles, p) end
    end
  end,
  draw=function(_ENV)
    if break_timer==0 then
      if sprite==65 then
        pal(7,14)
        pal(12,2)
      end
      for p in all(particles) do
        pset(p.x,p.y,6)
      end
      local w = (y-start)/2
      sspr(0, 32, 16, 8, x-w/2,y-1,16+w,8)
      pal()
    end
  end
}


function make_cloud_particles(_ENV)
  particles={}
  for i=0,rnd(5)+5 do
    add(particles, {
      x=x+rnd(14)+1,
      y=y+rnd(6)+3,
      t=1+rnd(1)
    })
  end
end
-- </cloud> --

fake_wall={
  init=function(_ENV)
    solid_obj=true
    local match
    for i=y,lvl_ph,8 do
      if tile_at(x/8,i/8)==83 then
        match=i
        break
      end
    end
    ph=match-y+8
    x-=8
    has_fruit=check(fruit,0,0)
    destroy_object(has_fruit)
  end,
  update=function(_ENV)
    hitbox=rectangle(-1,-1,18,ph+2)
    local hit = player_here()
    if hit and hit.dash_effect_time>0 then
      hit.spd=vector(sign(hit.spd.x)*-1.5,-1.5)
      hit.dash_time=-1
      _g.sfx_timer=20
      sfx(16)
      destroy_object(_ENV)
      for ox=0,hitbox.w-8,8 do
        for oy=0,hitbox.h-8,8 do
          init_smoke(ox,oy)
        end
      end
      if has_fruit then
        init_object(fruit,x+4,y+4,10)
      end
    end
    hitbox=rectangle(0,0,16,ph)
  end,
  draw=function(_ENV)
    spr(66,x,y,2,1)
    for i=8,ph-16,8 do
      spr(82,x,y+i,2,1)
    end
    spr(66,x,y+ph-8,2,1,true,true)
  end
}

--- <snowball> ---
snowball = {
  init=function(_ENV)
    spd.x=-3
    sproff=0
  end,
  update=function(_ENV)
    local hit=player_here()
    sproff=(1+sproff)%8
    sprite=68+(sproff\2)%2
    local b=sproff>=4
    flip=vector(b,b)
    if hit then
      if hit.y<y then
        hit.djump=max_djump
        hit.spd.y=-2
        psfx(3) --default jump sfx, maybe replace this?
        hit.dash_time=-1
        init_smoke()
        destroy_object(_ENV)
      else
        kill_player(hit)
      end
    end
    if x<=-8 then
      destroy_object(_ENV)
    end
  end
}
snowball_controller={
  init=function(_ENV)
    t,sprite=0,0
  end,
  update=function(_ENV)
    t=(t+1)%60
    if t==0 then
      for o in all(objects) do
        if o.type==player then
          init_object(snowball,cam_x+128,o.y,68)
        end
      end
    end
  end
}
--- </snowball> ---
-- <green_bubble> --
green_bubble={
  init=function(_ENV)
    t=0
    timer=0
    shake=0
    dead_timer=0
    movetimer=0
    hitbox=rectangle(0,0,12,12)
    outline=false --maybe add an extra black outline, or remove this?
    start=vector(x,y)
  end,
  update=function(_ENV)
    local hit=player_here()
    if hit and movetimer==0 and not invisible then
      hit.invisible=true
      hit.spd=vector(0,0)
      hit.rem=vector(0,0)
      hit.dash_time=0
      if timer==0 then
        timer=1
        shake=5
      end
      hit.x,hit.y=x+1,y+1
      timer+=1
      if timer>10 or btnp(❎) then
        hit.djump=max_djump+1
        hit.do_dash=true
        movetimer=6
        timer=0
      end
    elseif hit and movetimer>0 then
      x=hit.x
      y=hit.y
      movetimer-=1
      if movetimer==0 then
        for i=-4,4,8 do
          for j=-4,4,8 do
            init_smoke(i, -j)
          end
        end

        hit.invisible=false
        invisible=true
        x=start.x
        y=start.y
      end
    elseif movetimer>0 then
      invisible=true
      x=start.x
      y=start.y
    elseif invisible then
      dead_timer+=1
      if dead_timer==60 then
        dead_timer=0
        invisible=false
        init_smoke()
      end
    end
  end,
  draw=function(_ENV)
    t+=0.05
  	local x,y,t=x,y,t
    if shake>0 then
      shake-=1
      x+=rnd(2)-1
      y+=rnd(2)-1
    end
    local sx=sin(t)>=0.5 and 1 or 0
    local sy=sin(t)<-0.5 and 1 or 0
    for f in all({ovalfill,oval}) do
      f(x-2-sx,y-2-sy,x+9+sx,y+9+sy,f==oval and 11 or 3)
    end
    if timer>0 or movetimer>0 then
      pal(8,1)
      pal(15,1)
      spr(1,x,y)
      pal()
    end
    for dx=2,5 do
      local _t=(5*t+3*dx)%8
      local bx=sgn(dx-4)*round(sin(_t/16))
      rectfill(x+dx-bx,y+8-_t,x+dx-bx,y+8-_t,6)
    end
    rectfill(x+5+sx,y+1-sy,x+6+sx,y+2-sy,7)
  end
}
-- </green_bubble> --


-- requires <solids>
arrow_platform={
  init=function(_ENV)
    dir=sprite==71 and -1 or sprite==72 and 1 or 0
    solid_obj=true
    collides=true

    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==73 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==73 do
      hitbox.h+=8
    end
    break_timer,death_timer=0,0
    start_x,start_y=x,y
    outline=false
  end,
  update=function(_ENV)
    if death_timer>0 then
      death_timer-=1
      if death_timer==0 then
        x,y,spd=start_x,start_y,vector(0,0)
        if player_here() then
          death_timer=1
          return
        else
          break_timer=0
          collideable=true
          active=false
        end
      else
        return
      end
    end

    if (dir!=0 and spd.x==0 or dir==0 and spd.y==0) and active then
      break_timer+=1
    else
      break_timer=0
    end
    if break_timer==16 then
      death_timer=90
      collideable=false
      for px=x,right(),6 do
        for py=y,bottom(),6 do
          local o=init_object(rubble,px,py)
          o.tx=px+start_x-x
          o.ty=py+start_y-y
        end
      end
    end

    spd=vector(active and dir or 0,active and dir==0 and -1 or 0)
    local hit=check(player,0,-1)
    if hit then
      spd=vector(dir,dir==0 and -1 or btn(⬇️) and 1 or btn(⬆️) and not hit.is_solid(0,-1) and -1 or 0)
      active=true
    end
  end,
  draw=function(_ENV)
    if (death_timer>4) return
    if death_timer>0 then
      rectfill(start_x-1,start_y-1,start_x+hitbox.w+1,start_y+hitbox.h+1,7)
      return
      else
    local x,y=x,y
    pal(13,active and 11 or 13)
    local shake=break_timer>8
    if shake then
      x+=rnd(2)-1
      y+=rnd(2)-1
      pal(13,8)
    end
    local r,b=x+hitbox.w-1,y+hitbox.h-1
    rectfill(x,y,r,b,1)
    rect(x+1,y+2,r-1,b-1,13)
    line(x+3,y+2,r-3,y+2,1)
    local mx,my=x+hitbox.w/2,y+hitbox.h/2
    spr(shake and 72 or dir==0 and 87 or spd.y~=0 and 73 or 71,mx-4,my+(break_timer<=8 and spd.y<0 and dir!=0 and -3 or -4),1.0,1.0,dir==-1,spd.y>0)
    if hitbox.h==8 and shake then
      rect(mx-3,my-3,mx+2,my+2,1)
    end
    if dir!=0 then
      line(x+1,y,r-1,y,13)
      if not check(player,0,-1) and not is_solid(0,-1) then
        line(x+2,y-1,r-2,y-1,13)
      end
    end
    pal()
  end
  end

}

rubble={
  layer=0,
  init=function(_ENV)
    spd.x=rnd(5)-2.5
    spd.y=-rnd(3)
    hitbox=rectangle(0,0,6,6)
    collides=true
    sprite=102+flr(rnd(3))
    flip=vector(maybe(),maybe())
    outline=false
    timer=90
  end,
  update=function(_ENV)
    timer-=1
    if timer==0 then
      destroy_object(_ENV)
    end
    -- if timer==10 then 
    --   x=tx
    --   y=ty
    -- end
    if timer<=22 then
      collides=false
      spd.x=max(0.15*abs(tx-x),1)*sign(tx-x)
      spd.y=max(0.15*abs(ty-y),1)*sign(ty-y)
    else
      spd.x=appr(spd.x,0,0.1)
      spd.y=appr(spd.y,3,0.3)
    end
  end,
  draw=function(_ENV)
    local ox,oy=0,0
    if timer<=32 and timer>22 then
      ox=rnd(2)
      oy=rnd(2)
    end
    spr(sprite,x+ox,y+oy,0.75,0.75,flip.x,flip.y)
  end
}

bg_flag={
  init=function(_ENV)
    layer=0
    t=0
    wind=prev_wind_spd
    wvel=0
    ph=8
    while not is_solid(0,ph) and y+ph<lvl_ph do
      ph+=8
    end
    h=sprite==78 and 2 or 1
    w=sprite==78 and 1 or 2
    --outline=false
  end,
  update=function(_ENV)
	  wvel+=0.01*(wind_spd+sgn(wind_spd)*0.4-wind)
	  wind+=wvel
	  wvel/=1.1
    t+=1
  end,
  draw=function(_ENV)
	  --line(x, y, x, y+ph-1, 2)
    for nx=w*8-1,0,-1 do
      local off = nx~=0 and sin((nx+t)/(abs(wind_spd)>0.5 and 10 or 16))*wind or 0
      local ang = 1-(wind/4)
      local xoff = sin(ang)*nx+(wind_spd>=0 and 0 or -2)
      local yoff = cos(ang)*nx
      tline(x+xoff,y+off+yoff+1,x+xoff,y+h*8+off+yoff+1,lvl_x+x/8+nx/8,lvl_y+y/8,0,1/8)
    end

  end
}

function appr(val,target,amount)
  return val>target and max(val-amount,target) or min(val+amount,target)
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
64,bouncy_cloud
65,bouncy_cloud
67,fake_wall
68,snowball_controller
70,green_bubble
71,arrow_platform
72,arrow_platform
87,arrow_platform
74,bg_flag
76,bg_flag
78,bg_flag
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
  -- </solids> --
  function player_here()
    return check(player,0,0)
  end

  function move(ox,oy,start)
    for axis in all{"x","y"} do
      -- <wind> --
      rem[axis]+=axis=="x" and ox or oy
      -- </wind> --
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

  prev_wind_spd=wind_spd or 0
  --set level globals
  local tbl=split(levels[lvl_id])
  for i=1,4 do
    _ENV[split"lvl_x,lvl_y,lvl_w,lvl_h"[i]]=tbl[i]*16
  end

  lvl_pw,lvl_ph,wind_spd=lvl_w*8,lvl_h*8,tbl[6] or 0

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
    --<wind>--
    move(spd.x+(type==player and dash_time<=0 and wind_spd or 0),spd.y,type==player and 0 or 1);
    --<wind>--
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
  cls(10)

  -- bg clouds effect
  foreach(clouds,function(_ENV)
    x+=spd-_g.cam_spdx
    _g.rectfill(x+_g.draw_x,y+_g.draw_y,x+w+_g.draw_x,y+16-w*0.1875+_g.draw_y,9)
    if x>128 then
      x,y=-w,_g.rnd(120)
    end
  end)

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
    if layer==0 then
      draw_object(_ENV) --draw below terrain
    else
      add(layers[layer or 1],_ENV) --add object to layer, default draw below player
    end
  end)
  -- draw terrain
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)

  -- draw objects
  foreach(layers,function(l)
    foreach(l,draw_object)
  end)

  -- draw platforms
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,8)
  -- particles
  foreach(particles, function(_ENV)

    y+=_g.sin(off)-_g.cam_spdy
    y%=128
    off+=_g.min(0.05,spd/32)
    -- <wind> --
    wspd=_g.appr(wspd,_g.wind_spd*12,0.5)
    if _g.wind_spd!=0 then
      x += wspd - _g.cam_spdx
      _g.line(x+_g.draw_x,y+_g.draw_y,x+wspd*-1.5+_g.draw_x,y+_g.draw_y,c)
    else
      x+=spd+wspd-_g.cam_spdx
      _g.rectfill(x+_g.draw_x,y+_g.draw_y,x+s+_g.draw_x+wspd*-1.5,y+s+_g.draw_y,c)
    end
    -- </wind> --
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

  -- <transition> --
  if (co_trans and costatus(co_trans) != "dead") coresume(co_trans)
  -- </transition> --
end

function draw_object(_ENV)
  -- <green_bubble> --
  if not invisible then
    srand(draw_seed);
    (type.draw or draw_obj_sprite)(_ENV)
  end
  -- </green_bubble> --
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

function tile_at(x,y)
  return mget(lvl_x+x,lvl_y+y)
end

-- <transition> --
function transition()
  for wi in all{true,false} do
    for x=-96,(wi and 127 or 181),14 do
      camera()
      color(0)
      for yo=-1,128,10 do
        po1tri(x+(wi and 0 or 20),yo,x+(wi and 64 or -44),yo+5,x+(wi and 0 or 20),yo+10)
      end
      rectfill(wi and -1 or x+20,0,wi and x or 128,127)
      yield()
    end
    if (wi) delay_restart=1
  end
end

-- triangle functions
function po1tri(x0,y0,x1,y1,x2,y2)
  local c=x0+(x2-x0)/(y2-y0)*(y1-y0)
  p01traph(x0,x0,x1,c,y0,y1)
  p01traph(x1,c,x2,x2,y1,y2)
end

function p01traph(l,r,lt,rt,y0,y1)
  lt,rt=(lt-l)/(y1-y0),(rt-r)/(y1-y0)
  for y0=y0,y1 do
    rectfill(l,y0,r,y0,0)
    l+=lt
    r+=rt
  end
end
-- </transition> --
-->8
--[map metadata]

--@begin
--level table
--"x,y,w,h,exit_dirs,wind_speed"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
levels={
	"0,0,1,1,?,0",
  "1,0,3,1,?,0.1"
}

--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
}
--</camtrigger>--

--mapdata string table
--assigned levels will load from here instead of the map
mapdata={
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
000000000000000000000000088888800000000000000000000000000000000000000000000000000300b0b00a0aa0a000000000000000000000000000000000
00000000088888800888888088888888088888800888880000000000088888800004000000000000003b33000aa88aa00007777700000000000000000007f000
000000008888888888888888888ffff888888888888888800888888088f1ff18000950500000000002888820029999200077667000000000000000000077bb00
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff800090505049999400898888009a99990076777000000000000000000077bbbb0
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff800090505005005000888898009999a900776600007777700000000000fbb3330
0000000008fffff008fffff00033330008fffff00fffff8088fffff808333380000950500005500008898880099a999007777000077776700770000000b33300
00000000003333000033330007000070073333000033337008f1ff10003333000004000000500500028888200299992007000000070000770777777000033000
00000000007007000070007000000000000007000000700007733370007007000000000000055000002882000029920000000000000000000007777700000000
0000000071cd7c177111000000011117444499994444999944449999d666666dd666666dd666066d000000000000000070000000000000000000111000001002
000100001c1cd1c11ccc1000001cccc12222222222222222222222226dddddd56ddd5dd56dd50dd5007700000770070007000007000000000001222900000102
001c10101c1dc1c1c11111000001111c000220000000000000022000666ddd55666d6d5556500555007770700777000000000000000000000001212900000122
011c11c11c11c1c17dcccc1000111dcd00420000000000000000240066ddd5d5656505d500000055077777700770000000000000000000000001221000000120
1c1c11c11c11c110dcd1110001ccccd70420000000000000000002406ddd5dd56dd5065565000000077777700000700000000000000000000199222900000112
1c1cd1c10101c100c11110000011111c4200000000000000000000246ddd6d656ddd7d656d500565077777700000077000000000011100001122122900000122
1c1dc1c1000010001cccc1000001ccc120000000000000000000000205ddd65005d5d65005505650070777000007077007000070122290001222122900000122
71c7dc17000000007111100000001117000000000000000000000000000000000000000000000000000000007000000000000000122291201121112900000122
111111110eeeeeee5eeeeee12eeeeee011ee211111111111152222e10eeeeee04442244444244444444424440000000044444000442444244442202400000122
11112211eee5222515eeeee25eeeeeee1e2222511111111111222251ee552eee4442444444244494494222440099400044444200422244424442009400000222
11121121ee52222215522222522222ee152225511111111111552e105222225e4944444422224990042444240499429944422440222224424420099400000122
11211112e5522222112222221222255e152225511111111115222ee1e22222259444444944442200024444424449429944424449222222224200094400000122
12111121e222222221122221122225551121121111111111122222e1e22222212444449244444400009944442444424444244494222222922000994200000122
11211211e222225155211111511125510115ee251111111112222511152222514444444244449900009994444244424422244444922229942299942200000122
11122111152255111115511522551111115e222511111111115511101115ee214444444444499900000994404422242444244440492299444444444400000112
1111111121111112111122221122111211522221111111111522ee11215222e14442444444449000000000004444244444244400449944444442244400000122
12eee25151eee21112551111115555110eeeeee2ee011eee1eeeeee011ee21111111111100449000000992990022444444424444422422244442244400000000
1ee222511ee222212222511212222251eee222212e11eee22222eeee1ee222511122111104499900009992990044244442224444200220022444444b00008220
1e222251152222212222212121222221ee52222522112222222222ee1e222251122221114444990009994244499942442444242420000009224444b200000888
1e222e11152225511122222122222251e5522225225522222222225e1e2222511222211144444420099442449994442444444244200000024b2442b202800300
152522e1152252222552125522122211e522222122222222522222511222221111222111444422440444244444444422444442442000000943b24b3288b00300
115222e11121522222251222521221121522225122122225152225511522155111111122222249940222444444444424444942992200009923b21b1200b03000
1152225111112221222211225111222111555512551225512255551111511111111111224424449444424444444442440499429942200994b13b3b1bb03b30b0
1115221101211112122111111111111001111111155551111121111001112110111111114424444444244444044424440099400044499944331b3b3b0b3b30b3
00777000000777700eee12ee2e515ee0007777000077770000bbbb00111111111111111111111111cccccccc00000000eeeeeeeeeeeeeee00000000000000000
077777c0777c7777ee551525522152ee07767770077767700b3333b0111111111d1111d1111dddd10ccc11cccccc00002222222222220000bbbbbbbb00000000
c77777ccc777c777e55252225225222e7777777767777777b333773b1111d11111d11d111111ddd10c111cc111cccccc00eeee0eeeeeeee03333333300000000
c7777c777c77777c155252221225222e7677777767767767b333773b1111dd11111dd1111111ddd10c1cc111cccccc0000eeee00eeeeee00bbbbbbb000000000
cc7777777c7777cc12222222122222257776777667777777b333333b1dddddd1111dd111111d11d10c1c1cc00000000000222200222222220b3333bb00000000
0cc77cc7ccc77cc0e2222121212511117777776666777777b333333b1111dd1111d11d1111d111110c111ccc0000000000eeee0eeeee000003bbbb3b00000000
00ccccc000cccc00152211111222551107777660066777700b3333b01111d1111d1111d1111111110ccc111cccc00000eeeeeeeeeeeeee000bb33bb000000000
00000000000000002111211111122212006666000066770000bbbb00111111111111111100000000ccccccccc000000022222222222222200b3333bb00000000
000000000000012251eee21111555511121200000000000012120122111111110000012200000000000000210000011100000122000000000b3333bb00000000
00000000000001121ee2222112222251012220000000000001212122111dd1110000011200000000000002100002444100000122000000000b3333b000000000
0000000000000122152222212122222100121200000000000012212211dddd110000011200000000000021000012211244400111000000000bbbbbbb00000000
000000000000012215222551222222510001212000000000000122441dddddd10000012200000000000210000012222112224441000000000bb33bbb00000000
00000000000001221522522222122211000012120000000000001214111dd111000001220000000000210000001111122222221244400000bbbbbbb000000000
22222222222212441121522252122112000001222000000000000224111dd1112000012222222220021000000000011111112221124000003333333300000000
21222211221112141111222151112221000000121200000000000122111dd111120001122211120021000000000001210011111222400000bbbbbbbb00000000
11111111111112240121111211111110000000012120000000000122111111112120012211111111100000000000012200000111110000000000000000000000
00000000000000000000000000000000000000000000000001111000001110000011110000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111000111111000111110000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111100111111001111110000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111100111111001111100000000000000000000000000000000000000000000000000000000000
00b000b0000000000000000000000000000000000000000011111100011111001111100000000000000000000000000000000000000000000000000000000000
00b000b0000000000000000000000000000000000000000001111000001110000111100000000000000000000000000000000000000000000000000000000000
b0b30b30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa22444444422444422422244442244444422444442444244424
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa442444444244442aa22aa24442444444424444422244424424
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa49994244494444442aaaaaa94944444449444444222224422222
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99944424944444492aaaaaa29444444994444449222222224444
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa44444422244444922aaaaaa92444449224444492222222924444
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa444444244444444222aaaa994444444244444442922229944444
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4444424444444444422aa9944444444444444444492299444449
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa444244444424444444999444442444444424444449944444444
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4444244444244424444224444442244444422444444449999999
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4942224442224442444244444442444444424444444442999999
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa424442422222442494444444944444449444444444224499999
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777aaaaaaaa244444222222222944444499444444994444449444244499999
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99444422222292244444922444449224444492442444949999
aaaaaaaaaa777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99944492222994444444424444444244444442222444449999
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777aaaaaaaaaa9944a49229944444444444444444444444444442444499999
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa44994444444244444442444444424444442444999999
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa224444444224444442292444422444444449999999
aaaaaaaaaa666666666666aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa44244444424444444299942444444b444442999999
aaaaaaaaaa666666666666aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4999424449444444442aa994224444b24442244aaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777779444444942aaa9444b2442b244424449aaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa44444422244444922aaa994243b24b3244244494aaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa44444424444444422299942223b21b1222244444aaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa444442444444444444444444b13b3b1b4424444aaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa44424444442444444422444331b3b3b442444aaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111aaaaaaaaaaaaaaaa2244444442244444422444aeeeeeee2eeeeeeaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa822aaaaaaaaaaaa18888881aaaaaaaaa822aaa4424442444444b44424444eee522255eeeeeeeaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa888aaaaa777777777777881aaaaaaaaa88849994244224444b249444444ee522222522222eeaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa28aa3aaaaaaa666666666666f81aaaaa28aa3aa999444244b2442b294444449e55222221222255eaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88baa3aaaaaaaaaaaa188f1ff181aaaa88baa3aa4444442243b24b3224444492e222222212222555aaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaba3aaaaaaaaaaaaa188fffff1aaaaaaaba3aaa4444442423b21b1244444442e2222251511125512222
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaba3b3abaaaaaaaaaaaa1833331aaaaaaba3b3aba44444244b13b3b1b4444444415225511225511112122
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab3b3ab3aaaaaaaaaaaa171171aaaaaaab3b3ab3a4442444331b3b3b4442444421111112112211121111
99999999999999aaaaaaaeeeeee21eeeeee51eeeeee51eeeeee51eeeeee51eeeeee51eeeeee51eeeeee51eeeeee51eeeeee51eeeeee512551111115555111212
99999999999999aaaaaaeee222212eeeee512eeeee512eeeee512eeeee512eeeee512eeeee512eeeee512eeeee512eeeee512eeeee512222511212222251a122
99999999999999aaaaaaee522225222225512222255122222551222225512222255122222551222225512222255122222551222225512222212121222221aa12
99999999999999aaaaaae5522225222222112222221122222211222222112222221122222211222222112222221122222211222222111122222122222251aaa1
99999999999999aaaaaae5222221122221121222211212222112122221121222211212222112122266666666666612222112122221122552125522122211aaaa
99999999999999aaaaaa15222251111112551111125511111255111112551111125511111255111112551111125511111255111112552225122252122112aaaa
99999999999999aaaaaa11555512511551115115511151155111511551115115511151155111511551115115511151155111511551112222112251112221aaaa
99999999999999aaaaaaa111111122221111222211112222111122221111222211112222111122221111222211112222111122221111122111111111111aaaaa
99999999999999aaaaaa1212aaaaaaaaaaaaaaaaa122aaaaaa21aaaaaaa999999122999991229999992144442444444224444442244444444aaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaa1222aaaaaaaaaaaaaaaa222aaaaa21aaaaaaaa9999992229999922299999219494222444442444444424444444442aaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaa1212aaaaaaaaaaaaaaa122aaaa21aaaaaaaaa99999912299999122999921999424442449444444494444444442244aaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaa1212aaaaaaaaaaaaaa122aaa21aaaaaaaaaa999999122999991229992199992444442944444499444444944424449aaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaa1212aaaaaaaaaaaaa122aa21aaaaaaaaaaaaaaaaa122aaaaa122aa21aaaaaa994444244444922444449244244494aaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaa1666666666666aaa122a21aaaaaaaaaaaaaaaaaa122aaaaa122a21aaaaaaa999444444444424444444222244444aaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaa1212aaaaaaaaaaa11221aaaaaaaaaaaaaaaaaaa112aaaaa11221aaaaaaaaa9944a44444444444444444424444aaaaaaaaaaaaa
a99999999999999999999999999121299999999991221aaaaaaaaaaaaaaaaaaaa122aaaaa1221aaaaaaaaaaaaaaa4442444444424444442444aaaaaaaaaaaaaa
a99999999999999999999999999912129999999991229aaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaa444424444442444444244444aaaaaaaaaaaa
a99999999999999999999999999991222999999991129aaaaaaaaaaaaaaaaaaaa222aaaaa222aaaaaaaaaaaaaaaa494222444222444444244494aaaaaaaaaaaa
a99999999999999999999999999999121299999991129aaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaa4244424244424242222499aaaaaaaaaaaaa
a99999999999999999999999999999912129999991229aaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaa244444244444244444422aaaaaaaaaaaaaa
a99999999999999999999999999999991212999991229aaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaaa99444444444244444444aaaaaaaaaaaaaa
a99999999999999999999999999999999122299991222aaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaaa99944444494299444499aaaaaaaaaaaaaa
a999999999999999999999999999999999121299911212aaaaaaaaaaaaaaaaaaa112aaaaa112aaaaaaaaaaaaaaaaaaa9944aa4994299444999aaaaaaaaaaaaaa
a9999999999999999999999999999999999121299122212aaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaaaaaaaaaaa994aaa44449aaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1212a1221212aaaaaaaaaaaaaaaaa111aaaaa122aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1212122a1222aaaaaaaaaaaaaa24441aaaaa122aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa122122aa1212aaaaaaaaaaaa122112444aa111aaaaaaaaaaaaaaaaaaaa666666666666aaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa12244aaa1212aaaaaaaaaaa12222112224441aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1214aaaa1212aaaaaaaaaa11111222222212444aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa224aaaaa1222aaaaaaaaaaaa11111112221124aaaaaaaaaaaaaaaaa777777777777aaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa122aaaaaa1212aaa666666666666a111112224aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaa777777777777aaa122aaaaaaa1212aaaaaaaaaa122aaaaa11111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaaaaaa1111111111111111aaaaa122aaaaaaaa1212aaaaaaaaa122aaaaaaaaaaaa999999999999999999999999999999999999999999999999
aaaaaaaaaaaaaaaaaaaa1111111dd1111111aaaaa222aaaaaaaaa1222666666666666aaaaaaaaaaa999999999999999999999999999999999999999999999999
aaaaaaaaaaaaaaaaaaaa1dd111dddd111dd1aaaaa122aaaaaaaaaa1212aaaaaaa112aaaaaaaaaaaa999999999999999999999999999999999999999999999999
aaaaaaaaaaaaaaaaaaaa1d111dddddd111d1aaaaa122aaaaaaaaaaa1212aaaaaa122aaaaaaaaaaaa999999999999999999999999999999999999999999999999
aaaaaaaaaaaaaaaaaaaa1d11111dd11111d1aaaaa122aaaaaaaaaaaa1212aaaaa122aaaaaaaaaaaa999999999999999999999999999999999999999999999999
a99999999999999999991d111177777777777799912229999aaaaaaaa1222aaaa122aaaaaaaaaaaa999999999999999999999999999999999999999999999999
a99999999999999999991ddd111dd111ddd19999911212999aaaaaaaaa1212aaa112aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
a999999999999999999911111111111111119999912221299aaaaaaaaaa1212aa122aaddddddddddddddddddddaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
a999999999999999999999999999999999999999912212129aaaaaaaaaaa1212a1221dddddddddddddddddddddd1aaaaaaaaaaaaaaaaaaa99299aa449aaaaaaa
a999999999999999999999999977777777777799922291222aaaaaaaa66666666666611111111111111111111111aaaaaaaaaaaaaaaaaa999299a44999aaaaaa
a9999999999999999999999999999999999999999122991212aaaaaaaaaaaa1221221dd111111111111111111dd1aaaaaaaaaaaaaaaaa9994244444499aaaaaa
a99999999977777777777799999999999999999991229991212aaaaaaaaaaaa122441d11111111111111111111d19999999999999999999442444444442aaaaa
a999999999999999999999999999999999999999912299991212aaaaaaaaaaaa12141d11111111111111111111d199999999999999999444244444442244aaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa122aaaaa1222aaaaaaaaaaaa2241d11111111111111111111d199999999999999999222444422224994aaaa
aaaaaaaaaaaaaaaaaaaaa1aa1a1aaaaaaaaaaaaaa112aaaaaa1212aaaaaaaaaaa1221d111111111d1111111111d199999999999999994442444444244494aaaa
aaaaaaaaaa77777777777711b1b1aaaaaaaaaaaaa122aaaa999121299666666666666d11111111dd1111111111d199999999999999994424444444244444aaaa
aaaaaaaaaaaaaaaaaaaaa13b331aaaaaaaaaaaaaa122aaaa992112129999999991221d1111111dddddd1111111d199999999999999999922444444444aaaaaaa
aaaaaaaaaaaaaaaaaaaa12888821aaaaaaaaaaaaa222aaaa921991222666666666666d11111111dd1111111111d1999999999999999999442444444442aaaaaa
aaaaaaaaaaaaaaaaaaaa18988881aaaaaaaaaaaaa122aaaa219999121777777777777d111111111d1111111111d19999999999999999499942444442244aaaaa
aaaaaaaaaaaaaaaaaaaa18888981aaaaaaaaaaaaa122aaa2199999912129999991221d11111111111111111111d199999999999999999994442444424449aaaa
aaaaaaaaaaaaaaaaaaaa18898881aaaaaaaaaaaaa122aa21999999991212999991221d11111111111111111111d199999999999999994444442244244494aaaa
aaaaaaaaaaaaaaaaaaaa12888821aaaaaaaaaaaaa122a21aaaaaaaaaa1222aaaa1221d111111111166666666666699999999999999994444442422244444aaaa
aaaaaaaaaaaaaaaaaaaaa128821aaaaaaaaaaaaaa11221aaaaaaaaaaaa1212aaa1121dddddddddddddddddddddd1aaaaaaaaaaaaaaaa444442444424444aaaaa
aaaaaaaaaaaaaaaaaaaaaa1111aaaaaaaaaaaaaaa1221aaaaaaaaaaaaaa1212aa122111111111111111111111111aaaaaaaaaaaaaaaaa4442444442444aaaaaa
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaa1212a122aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa992994442244444244424aa44
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa222aaaaaaaaaaaaaaaaa1212122aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9992994442444442224442a449
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaaaa122122aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999424449444444222224424444
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaaaaa12244aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa994424494444449222222224444
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaaaaaa1214aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa444244424444492222222924444
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaaaaaaa224aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa222444444444442922229942222
aaaaaaaaaaaaaaaaaaaaaaaaaa666666666666aaa112aaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4442444444444444492299444424
ddddddddddddddddddaaaaaaaaaaaaaaaaa11aaaa122aaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4424444444424444449944444424
ddddddddddddddddddd1aaaaaaaaaaaaa11cc1111112aaaaaaaaaaaaaaaaaaaaa122aaaa1aa2aaaaaaaaaaaaaaaaaaaaaaaaaa22444444422444444229244444
77777771111111111111aaaaaaaaaaa11cccccccccc1aaaaaaaaaaaaa666666666666aaaa1a2aaaaaaaaaaaaaaaaaaaaaaaaaa44244444424444444299944444
11111111d11111111dd1aaaaaaa1111cc111c11ccc12aaaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaaaaaaaaa4999424449444444442999944442
11111111dd11111111d19999991cccccccc11c111c1299999999999999999999912299999129999aaaaaaaaaaaaaaaaaaaaa9994442494444449429999444442
11111dddddd1111111d1999999911cccc111c1cc1c1299999999999999999999912299999112999aaaaaaaaaaaaaaaaaaaaa4444442224444492299999424424
11111111dd11111111d1999999999111111ccc1c1c1299999999999999999999912299999122999aaaaaaaaaaaaaaaaaaaaa4444442444444442229994222224
dddd1111d111ddddddd19999999999991ccc1c111c1299999999999999999999911299999122999aaaaaaaaaaaaaaaaaaaaa4444424444444444444444444424
11111111111111111111999999999991c1ccc11ccc1299999999999999999999912299999122999aaaaaaaaaaaaaaaaaaaaaa444244444424444444224444424
aaaaaaaaaaaa9999999999999999999919111cccccc199999999999997777777777779999122999aaaaaaaaaaaaaaaaaaaaaaa22444444422444444224444224
aaaaaaaaaaaa9999999999999999999999999111111299999999999999999999922299999222999aaaaaaaaaaaaaaaaaaaaaaa44244444424444444244442992
99999999999999999aaaaaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaaaaa66666666666649444444494444442aaa
99999999999999999aaaaaaaaa777777777777aaa122aaaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaaaaaaaaa9994442494444449944444492aaa
99999999999999999aaaaaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaaaaaaaaa4444442224444492244444922aaa
99999999999999999aaaaaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaaaaaaaaaa122aaaaa122aaaaaaaaaaaaaaaaaaaaaaaa44444424444444424444444222aa
99999999999999999aaaaaaaaaaaaaaaaaaaaaaaa112aaaaa999999999999999911299999112999999999999999aaaaaaaaa444442444444444444444444422a
99999999999999999999999999999999999999999122aaaaa999999999999999912299999122999999999999999aaaaaaaaaa444244444424444444244444449
99999999999999999999999999999999999999999122aaaaa99999999999999991229eeeeeee2eeeeee99999999aaaa992994442244444422a24444224444442
99999999999999999999999999999999999999999222aaaaa9999999999999999222eee522255eeeeeee9999999aaa999299444244444442aa94444244444442
99999999999999999999999999999999999999999122aaaaa9999999999999999122ee522222522222ee9999999aa999424449444444442aa994494444444944
999999999999999999999999999999999977777777777aaaa9999999999999999122e55222221222255e9999999aa99442449444444942aaa944944444499444
99999999999999999999999999999999999999999122aaaaa9999999999999999122e2222222122225559999999aa4442444244444922aaa9942244444922444
99999999999999999999999999777777777777999122aaaaa9999999999999999122e2222251511125519999999aa22244444444444222999422444444424444
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa112aaaaa999999999999999911215225511225511119999999a444244444444444444444444444444444444
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa122aaaaaaaaaaaaa777777777777111111211221112aaaaaaaa442444444442444444422444444244444442
eeee5eeeeee15eeeeee15eeeeee15eeeeee15eeeeee15eeeeee15eeeeee15eeeeee111111111152222e1aaaaaaaaaa2244444442244444422444444224444442
222515eeeee215eeeee215eeeee215eeeee215eeeee215eeeee215eeeee215eeeee2111122111122666666666666aa4424444442444444424444444244444442
222215522222155222221552222215522222155222221552222215522222155222221112112111552e1aaaaaaaaa499942444944444449444444494444444944
222211222222112222221122222211222222112222221122222211222222112222221121111215222ee1aaaaaaaa999444249444444994444449944444499444
2222211222212112222121122221211222212112222121122221211222212112222112111121122222e1aaaaaaaa444444222444449224444492244444922444
225155211111552111115521111155211111552111115521111155211111552111111121121112222511aaaaaaaa444444244444444244444442444444424444
55111115517777777777771551151115511511155115111551151115511511155115111221111155111aaaaaaaaa444442444444444444444444444444444444
11121111222211112222111122221111222211112222111122221111222211112222111111111522ee11aaaaaaaaa44424444442444444424444444244444442

__gff__
0000000000000000000000000000000002020202080808000000000000040404030303030303030304040404040404040303030303030303030404040404040400000000000000000000000000000000040400000404040004040404040400000400000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
282d29000000000000000000002a282800000000000000000000003b283d28282d2900002f005a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28290000000000000000000000002a2e00000000000000000000002a2d2828282c0000002f5a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
29000000000000013f0000000000002a0000000000000000000000003b282e3e2c0000002f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000001321352223120000000000000000000000003f0000003f3b3e2821235050505150590000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000001324202526120000000000000000003422352235222235223522323354585a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000132425382612000f0000100000000054552f5a002f2f5a2a28282c000056000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
270800000013313232331200000008270000000000545855002f2f00002a3c2900002f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
300800000000111111110041000008300000000000005654555b5c5d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
300000004300000000000000000000300000000057492f555458000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
370000005300342235360040000000370000000000002f54555647494900003a390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
392b3900000000000000000000000000000000000a002f5a545849000000003b2c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
282d291415160b2f4e00002f4c4d00000000000000002f000056000000003a282d3900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2d28282b3900002f5e00002f00000a430048494900002f4a4b2f1f0000003b282e2c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28283e2d2910102f0010102f00603f530100000000002f00002f2f0000003b28283d39000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
223522352317172123171721223522352300000000002f00002f2123003a282e28282c003a39000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
38252525260000242600002425252538262122353522352222352026003b282828282c003b28390000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

