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
for i=0,36 do
  add(particles,{
    x=rnd"128",
    y=rnd"128",
    s=flr(rnd"1.25"),
    spd=0.25+rnd"5",
    off=rnd(),
    c=6+rnd"2",
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
      -- <green_bubble> --
      if dash or do_dash then
        if djump>0 then
          do_dash=false
          -- </green_bubble> --
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
        pal(6,2)
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
  for i=0,rnd"5"+5 do
    add(particles, {
      x=x+rnd"14"+1,
      y=y+rnd"6"+3,
      t=1+rnd()
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
      sfx"16"
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
        psfx"3" --default jump sfx, maybe replace this?
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
      x+=rnd"2"-1
      y+=rnd"2"-1
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
      x+=rnd"2"-1
      y+=rnd"2"-1
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
    spd.x=rnd"5"-2.5
    spd.y=-rnd"3"
    hitbox=rectangle(0,0,6,6)
    collides=true
    sprite=102+flr(rnd"3")
    flip=vector(rnd()<0.5,rnd()<0.5)
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
      ox=rnd"2"
      oy=rnd"2"
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

  prev_wind_spd=wind_spd or 0
  --set level globals
  local tbl=split(levels[lvl_id])
  for i=1,4 do
    _ENV[split"lvl_x,lvl_y,lvl_w,lvl_h"[i]]=tbl[i]*16
  end

  lvl_pw,lvl_ph,wind_spd=lvl_w*8,lvl_h*8,tbl[6] or 0

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
  cls"10"

  -- bg clouds effect
  foreach(clouds,function(_ENV)
    x+=spd-_g.cam_spdx
    _g.rectfill(x+_g.draw_x,y+_g.draw_y,x+w+_g.draw_x,y+16-w*0.1875+_g.draw_y,9)
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

-- <transition> --
function transition()
  for wi in all{true,false} do
    for x=-96,(wi and 127 or 181),14 do
      camera()
      color"0"
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

--@conf
--[[
autotiles={{52, 54, 53, 39, 33, 35, 34, 55, 49, 51, 50, 48, 36, 38, 37, [0] = 33}, {59, 44, 40, 43, 58, 57, 43, 60, 42, 41, 60, 40, 59, 44, 40, [0] = 40}}
param_names={"wind_speed"}
composite_shapes={}
]]
--@begin
--level table
--"x,y,w,h,exit_dirs,wind_speed"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
levels={
  "0,0,1,1,0b0010,0",
  "1,0,1,1,0b0011,0",
  "2,0,1,1,0b0001,0",
  "3,0,1,1,0b0001,0",
  "4,0,1,1,0b0010,0",
  "5,0,1,1,0b0001,-0.3",
  "6,0,1,1,0b0010,-0.4",
  "0,1,1.75,1,0b0010,0",
  "1.75,1,1.5625,1,0b0001,0",
  "3.3125,1,2,1.125,0b0001,0",
  "5.3125,1,2,1,0b0010,-0.5",
  "0,2,2,1,0b0010,-0.6",
  "2,2.125,2,1,0b0010,0.4",
  "6,2,2,1,0b0010,-0.6",
  "0,3,2,1,0b0010,-0.7",
  "4,3,2,1,0b0010,-0.4",
  "6,3,1.1875,1,0b0000,0"
}

--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
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
00000000088888800888888088888888088888800888880000000000088888800004000000000000003b33000aa88aa0000777770000000000000000007bb700
000000008888888888888888888ffff888888888888888800888888088f1ff180009505000000000028888200299992000776670000000000000000007bbb370
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff800090505049999400898888009a999900767770000000000000000007bbb3bb7
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff800090505005005000888898009999a9007766000077777000000000073b33bb7
0000000008fffff008fffff00033330008fffff00fffff8088fffff808333380000950500005500008898880099a999007777000077776700770000007333370
00000000003333000033330007000070073333000033337008f1ff10003333000004000000500500028888200299992007000000070000770777777000733700
00000000007007000070007000000000000007000000700007733370007007000000000000055000002882000029920000000000000000000007777700077000
00000010077c7c1001100000011000004fff4fff4fff4fff4fff4fffd666666dd666666dd666066d000000000000000070000000000000000000111000001002
001001c1071c1cc11cc111001cc111774444444444444444444444446dddddd56ddd5dd56dd50dd5007700000770070007000007000000000001222900000102
01c101c101cc1cc1cccccc10011ccc17000450000000000000054000666ddd55666d6d5556500555007770700777000000000000000000000001212900000122
01c11c1001c11c107111110000011ccc00450000000000000000540066ddd5d5656505d500000055077777700770000000000000000000000001221000000120
01c11c1001c11c10ccc11000001111170450000000000000000005406ddd5dd56dd5065565000000077777700000700000000000000000000199222900000112
1cc1cc101c101c1071ccc11001cccccc4500000000000000000000546ddd6d656ddd7d656d500565077777700000077000000000011100001122122900000122
1cc1c1701c10010077111cc100111cc750000000000000000000000505ddd65005d5d65005505650070777000007077007000070122290001222122900000122
01c7c770010000000000011000000110000000000000000000000000000000000000000000000000000000007000000000000000122291201121112900000122
111111110eeeeeeeeeee01eeeeeeeeee11e221111111111112222ee10eeeeee04442244444244444444424440000000044444000442444244442202400000122
11112211eee22222222112ee22222eee1ee221111111111111222ee1ee222eee4442444444244494494222440099400044444200422244424442009400000222
11121121ee222222211221222222222e1ee22211111111111122ee10e222222e4944444422224990042444240499429944422440222224424420099400000122
11211112e2222222222221222222222211ee2221111111111222e111e22222229444444944442200024444424449429944424449222222224200094400000122
12111121e22222e22e222212e2e2222e11e112221111111122221ee11e2e2e222444449244444400009944442444424444244494222222922000994200000122
1121121122e22e1221e22e1e1e1222e1011e222211111111222222e111e221ee4444444244449900009994444244424422244444922229942299942200000122
11122111221ee122221ee1112122ee1111e222221111111112222e10111221e14444444444499900000994404422242444244440492299444444444400000112
11111111221112222221122111222ee111e222221111111112222211112222114442444444449000000000004444244444244400449944444442244400000122
122222111122222222222222222222210eeeeeeeeeeeeee2eeeeeeee112222211111111100449000000992990022444444424444422422244442244400000e00
122e2e21122222222222222222222221e2ee2222eeeee2e1e22ee221112222211122111104499900009992990044244442224444200220022444444b00002880
1221e1211e22222222222122222222e122e2222222ee222122e22221122222e1122221114444990009994244499942442444242420000009224444b20000088e
122112211e22e222222221122e22221122222e221222ee12ee1222211e222ee1122221114444442009944244999444244444424420000002432442b200000b00
122212211eeee222112e2e1121e22e1122222e22111ee1111122222111e22e1111222111444422440444244444444422444442442000000944324bb200300b00
1122221111ee1ee2221eee22211ee1111e22e122e2111122122222e1111e222111111122222249940222444444444424444942992200009924322b220030b000
1122222111e111e22101e1112111e11111ee12221ee2122222222e11111e2111111111224424449444424444444442440499429942200994b223bb2b0003b030
112222210111011e1100111111111110011111111111111111211110011111101111111144244444442444440444244400994000444999443323333b03033033
077770000077767000eeeeeeeeeeeee0007777000077770000bbbb00111111111111111111111111cccccccc00000000eeeeeeeeeeeeeee00000000000000000
07777677667777670ee112221e221ee007767770077767700b3333b0111111111d1111d1111dddd10ccc11cccccc00002222222222220000bbbbbbbb00000000
67776777776777770e1e212221ee211e7777777767777777b333773b1111d11111d11d111111ddd10c111cc111cccccc00eeee0eeeeeeee03333333300000000
6677777766777776e12e21212211e12e7677777767767767b333773b1111dd11111dd1111111ddd10c1cc111cccccc0000eeee00eeeeee00bbbbbbb000000000
0666776666677666e22122e2e2e2122e7776777667777777b333333b1dddddd1111dd111111d11d10c1c1cc00000000000222200222222220b3333bb00000000
0066666666666660e2e21e121e1212ee7777776666777777b333333b1111dd1111d11d1111d111110c111ccc0000000000eeee0eeeee000003bbbb3b00000000
0006666000666600221ee121212122ee07777660066777700b3333b01111d1111d1111d1111111110ccc111cccc00000eeeeeeeeeeeeee000bb33bb000000000
0000000000000000e21112121112122e006666000066770000bbbb00111111111111111100000000ccccccccc000000022222222222222200b3333bb00000000
0000000000000122ee21e1111221e22e121200000000000012120122111111110000012200000000000000210000011100000122000000000b3333bb00000000
0000000000000112e222111111e1222e012220000000000001212122111dd1110000011200000000000002100002444100000122000000000b3333b000000000
0000000000000122e2222e11111222ee00121200000000000012212211dddd110000011200000000000021000012211244400111000000000bbbbbbb00000000
0000000000000122ee22e1e111212eee0001212000000000000122441dddddd10000012200000000000210000012222112224441000000000bb33bbb00000000
0000000000000122ee21122212ee122e000012120000000000001214111dd111000001220000000000210000001111122222221244400000bbbbbbb000000000
22222222222212440ee221222e11212e000001222000000000000224111dd1112000012222222220021000000000011111112221124000003333333300000000
2122221122111214ee212e12112212e0000000121200000000000122111dd111120001122211120021000000000001210011111222400000bbbbbbbb00000000
1111111111111224ee22112112122eee000000012120000000000122111111112120012211111111100000000000012200000111110000000000000000000000
00000000000000000000000000000000000000000000000001111000001110000011110000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111000111111000111110000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111100111111001111110000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111100111111001111100000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000011111100011111001111100000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001111000001110000111100000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042526200004252
52525252525252525252525252525252525252525200000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042526200004252
52525252525252525252525252525252525252525200000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000051611222220000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005161122222
00000000000000000000000000000000000000000000000000000000001352520000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000640000000001010000000000006400000000000000000000000000000000000064000000000101000000000000000000425252
00000000000000000000000000000000000000010100000000f00044000042520000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000043630000000000000000000000000000000000000000000000000000000000004363000000000000000000132352
00000000000000000000000000011232000031123200005400000000000013520000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000720000000000000000000000000000000000000000000000000000000000000072000000000000000013
00000000000000000000640031125262000031423300000000010100000000130000100000000000000100000064000000000000000001010101000000000000
00000000000000000072000000000000000000000000034100000000001222220000000000000000007200000000000000000000000003415100000000000000
00000000000000000000000031135262000000730000000031123221000000002222324151000000317200004400000000000000003112222232210000000000
00000000000000000003415100000000720000000000030000000000004252520000000000000000000341510000000072000000000003000000000000000000
00000000000000000000000000004233000000000000000031133321000000005252330000000000310300000000000101010000003113235262210000000000
00000000006400000003000000000000034151000000730000000000001352520000000000640000000300000000000003415100000073000000000000000000
00000000000000010101000000000300000000000000000000111100000000005262000000000000310300000000311222322100000000001362210000000000
00000000000000000003000000000000030000000000000000000000000042520000000000000000000300000000000003000000000000000000000000000000
00000000640031122232000000007300440000009090000000000000000000005262000000000000310300000000314252622100640000440003210000000000
00000000000000000073000000000000730000000101010000000000000013230000000000000000007300000000000073000000010101000000000000000000
00000000000031132323536300000000000000007171000000000000000000005262000000000000317300000000311323332100000000000003210000000000
00000000000000000000000101010000000000004353630000000000000000000000000000000000000000010101000000000000435363000000000000000000
00100000000000000000000000000101010000000000000000000000000000005233000000000000000000000000001111110000000000000073210000000000
00100000000000000000004353630000000000000000000000000000000000000010000000000000000000435363000000000000000000000000000000000000
22320000000000000000000000001222320000000000000000000000000000003300000000000000000000000000000000000000000000000000000000000000
22324151000000000000000000000000000000000000000000000000000000002232415100000000000000000000000000000000000000000000000000000000
52620000000000000000000000001323330000000000000000000000000000000000000000000000000000000000000000000000000000000000004451611222
52620000000000000000000000000000000000000000000000000000000000005262000000000000000000000000000000000000000000000000000000000000
526200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000001352
52620000000000000000000000000000000000000000000000000000000000005262000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001323
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000031122232210000000001010100000000000000000000000000f1a4b40000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000123200000000000000000000000000000000f1a4b400000000000000000000f1a4b400000000000000
0000000000000000010100000000000031425262210000003112223221000000000000000000000000f100000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000133300000000000000000000000000000000f1000000000000000000000000f1000000000000000000
0000000000000031123221000000000031425262210000003142526221000000000000000000000000f200000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000f2000000000000000000000000f2000000000000000000
0000000000000031426221000000000031132333210000003113233321000000000000000000000000f200000000000000000000000000000000000000000000
0000000000000000000000000000000000000101000000000000000000000000000000000000000000f2000000000000000000000000f2000000000000000000
00000000000000311333210000000000001111110000000000111111000000000000000000000000001232000000000000000000000000000000000000000000
00000000000000000000000000000000000012320000000000000000000000000000000000000000001232000000000000000000000012320000000000000000
00000000000000001111000000000000000000000000000000000000000012220000000000000012225252222232000000000000440000000000000051611222
00000000000000000000000101000000000013330000000000000000516112220000000000000012225252222232000000000000122252522222320000000000
00001000000000000000000000000000000000000000004400010112222252520000000000001252525252525252320000000021000000000000540000004252
00000010000000000000001232000000000000000000000001010000000042520000000000001252525252525252320000000012525252525252523200000000
22222222320101000000440000000000000000000101011222222252525252520000000012225252525252525252620000000021005400000000000000001352
22222222222263000000001333000000000000000000000012320000000013520000000012225252525252525252620000000052525252525252526200000000
52525252522222222222320100004401011222222222225252525252525252520000001252525252525252525252523200000000007171710000000000440013
52525252526200000000000000000000000000000000000013330000000000130000001252525252525252525252523200000052525252525252525232000000
52525252525252525252522222222222225252525252525252525252525252521000125252525252525252525252525222320000000000000071717100000000
52525252523300000000000000000000000000000000000000000000000000001000125252525252525252525252525222320052525252525252525252223200
52525252525252525252525252525252525252525252525252525252525252522222525252525252525252525252525252522200000000000000000000000000
52525252620000000000000000000000000000000000000000000000000000002222525252525252525252525252525252522252525252525252525252525222
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
0000000000000000000000000000000002020202080808000000000000040404030303030303030304040404040404040303030303030303030404040404040400000000000000000000000000000000040400000404040004040404040400000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000025252525252525252525252525252525252525252525252525252526000024252532323232322525252526000024252525252525323232323232323232322525260000002432323232323232252525252526000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000025252532323232323232323232323232252532323232323232323233000024253300000000003132322526000024252525323233000000000000000000003132260000003000000000000000312525252526000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000025323300000000000000000000000000253300000000000000000000000024250000000000000000003133000024252533000000004600000046000000000000260000003700000000000000003125252526000000000000100000000015162100000000000000000000000000000000
0000000000000000000000000000000033000000000000000000000000000000330000000000000000000000000031250000000000000000000000000031322500000000000000000010101000000000260000000000000000000000000024252526000000000013270000000000003100000000000000000000000000000000
00000000000000000000000000000000000000000000000000000021230000000000000000000010100000000000002400000000000000000000000000001324000000000000000013343536120000002600000000001000000000000000242525330000000000133000000f0000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000003125222222000000000000002123000000000000240000000000000000000000101000132400000000000000000011111100000000260000000013270000001000000031252600000000000013370000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000024252525000000000000002426000000000000310000000000000000460013212312132400000000000000000010100000000000222222360013300000002700000000242600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000004000000000242525250000000000000024260000000000000000000000001000000000133133121324000000000000000013212312000000002525330000133700000037000000002426000000001000000f0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000024252525000000000000002426000000410000000000000013271200000000111100132400000000004100001324261200000000253300000000000000000000000000242600000013270000000010100000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000024252525000000004100002433001010101000000000000013371200000000000000132400000000000000001324261200000000330000000000000000000000002122252600000013300000001021230000000000000000000000000000000000000000
000000000000000000000000000000000001212300000000000000002425252501000000000000370000212222230000000000000000000000000000000021250001000000000000132426120000000000000000000f0000000f0000003125252600000013370000002125260000000000000000000000000000000000000000
0000000000212222222222222222222222222526000000000000000024252525222300000000000000003132323300000000000000000000000000151621252522222223000000001324261200212222000000000000000000000000000024252600000000000000002425331000000000000000000000000000000000000000
0000002122382525253825252525252525252526000000000000000024252525252600000000000000000000000000000001000000000000090000000031322525252533000000001331331200312525000000000000101010000000000024252600000000000000003126382700000000000000000000000000000000000000
0100213825252525252525253825252525252526000000000000000024252525252600000000000000000000000000002223141500000000170000000000002425252600000000000011110000002425000100000013343536120000000031252600000001000000001324353300000000000000000000000000000000000000
2222252525252525252525252525252525252526000000000000000024252525252600000000000000000000000000002533000000000000000000000000002425253300000000000000000000003125222223000000111111000000000000312614162122230000001330000000000000000000000000000000000000000000
3825252525252525252525252525252525252526000000000000000024252525252600000000000000000000000000002600000000000000000000000000002425260000000000000000000000000024252526000000000000000000000000002600002425260000001330000000000000000000000000000000000000000000
2525252525252525252525252525252525252525252525252525252525323232252525252525252525252532323225260000000024252525252525252525252525252525252525252525252525252526000000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2525323232323225252525323232323232252525252525252525252533000000313232323232323232323300000042430000000024252525252525323232323232252525253232323232323232323226000000002400000000000000000000000000000000000000000000000000000000151621220000000000000000000000
323300000000003132322600000000000024323232323232323232320000000000000000000000000000000000000000000000002425252525323300000000000031323233000000000000000000003000000000240000000000000000000f0000000000000000000f0000000000000000000031250000000000000000000000
0000000000000000000030000000000000300000000000000000000000010000000000000000000010101010000000002700002125252525330000000000000000000000000000000000000f00000030000015162400000000000000000000000000000000000000000000000000000000000000310000000000000000000000
0000000000000000000037000000000000300000000000000000000000212223000000000000000034353536000052532422222525252533000000000000000000000000000000000000000000000030000000002400010000000000000010101000000000000010101000000000000000000000000000000000000000000000
0000000000000000000000000000000000370000001000000000000022252525223600000000000000000000000000003132252525252600000000000000001010100000001010000000101010000037000000132422230000000000001021222310000000101021222310100000005757000000000000000000000000000000
0000000048494900000000001010100000000000132712000000000025252525330000001010100000000000000000000000312525252600000010101000002122231200002123120013212223120000000000132425252300000000002125252523000000212225252522230000132123120000000000000000000000000000
0000000000000000000000003435360000000000133012000000000025252526000000003435360000000000000000000000002425252600000021222300002425261200002426120013242526120000000000132425253235360000003132323233000000313232323232330000132426120000000000000000000000000000
0001000000000000000000000000000000000000133012002122222225252526000000000000000000000000000000000000002425252600000031323300003132331200003133120013313233120000000000132425264849494900000000000000000044000000000000000000132426120000000000000000000000000000
2222230000000000000000101010101000000000133012003125252525252526100048494900000000000000000000000000002425252600004849494900000000000000000000000000000000000000000010102425264900000000000010100000000000000010101000000000132426120000000000000000000000000000
2525260000000000000013212222222312000000133012000031252525252525231010100000000010101010000000101010102425252600004910101000001010100000001010000000101010000000000021222525252223000000001321231200000000001321222312000000132426120000000000000000000000000000
2525260000000000000013242525252612000000133012000000242525252525252222230000000021222223000000212222222525252600000034353600002122230000002123000000212223000000000024252525252525230000001324261200000000001324252612000000133133120000000000000000000000000000
2525260000000000000013313232323312000000133712000000242525252525252525260000000024252526000000242525252525252600000000000000002425330000102426000000242526000000101024252525252525252300001331331200004400001331323312000000001111000000000000000000000000000000
2525330000000000000000111111111100000000001100000000312525252525252525260000000024252526000000242525252525253300000001000000102426001010212526101010242526101010212225252525252525253300000011110000000000000011111100000000000000000000000000000000000000000000
2533000000000000000000000000000000000000000000000000002425252525252525260000000024252526000000242525252525330000000021230000212526102122252525222222252525222222252525252525252525260000000000000000000000000000000000000000000000000000000000000000000000000000
2600000000000000000000000000000000000000000000000000002425252525252525260000000024252526000000242525252525000000002125260000242525222525252525252525252525252525252525252525252525260000000000000000000000000000000000000000000000000000000000000000000000000000
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

