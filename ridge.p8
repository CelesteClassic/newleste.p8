pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
--newleste.p8 base cart

--original game by:
--maddy thorson + noel berry

-- based on evercore v2.0.2
--with major project contributions by
--taco360, meep, gonengazit, and akliant

poke(0x5f2e,1)

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
    berry_timer=0
    berry_count=0
    -- </fruitrain> --
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
      local maxrun=1
      local accel=on_ground and 0.6 or 0.4
      local deccel=0.15

      -- set x speed
      spd.x=abs(spd.x)<=1 and
        appr(spd.x,h_input*maxrun,accel) or
        appr(spd.x,sign(spd.x)*maxrun,deccel)

      -- facing direction
      if spd.x~=0 then
        flip.x=spd.x<0
      end

      -- y movement
      local maxfall=2

      -- wall slide
      if h_input~=0 and is_solid(h_input,0) then
        maxfall=0.4
        -- wall slide smoke
        if rnd(10)<2 then
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
          jbuffer=0
          grace=0
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
            jbuffer=0
            spd=vector(wall_dir*(-1-maxrun),-2)
            -- wall jump smoke
            init_smoke(wall_dir*6)
          end
        end
      end

      -- dash
      local d_full=5
      local d_half=3.5355339059 -- 5 * sqrt(2)

      -- <green_bubble> --
      if djump>0 and dash or do_dash then
        do_dash=false
      -- </green_bubble> --
        init_smoke()
        djump-=1
        dash_time=4
        _g.has_dashed=true
        dash_effect_time=10

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
        dash_target_x=2*sign(spd.x)
        dash_target_y=(spd.y>=0 and 2 or 1.5)*sign(spd.y)
        dash_accel_x=spd.y==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()
        dash_accel_y=spd.x==0 and 1.5 or 1.06066017177

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
    sprite = not on_ground and (is_solid(h_input,0) and 5 or 3) or  -- wall slide or mid air
      btn(⬇️) and 6 or -- crouch
      btn(⬆️) and 7 or -- look up
      spd.x~=0 and h_input~=0 and 1+spr_off%4 or 1 -- walk or stand
    update_hair(_ENV)
    -- exit level (except summit)
    if (exit_right and left()>=lvl_pw or exit_top and y<-4 or exit_left and right()<0 or exit_bottom and top()>=lvl_ph) and levels[lvl_id+1] then
      next_level()
    end

    -- was on the ground
    was_on_ground=on_ground
    --previous horizontal input (for soft dashes)
    ph_input=h_input
  end,

  draw=function(_ENV)
    -- draw player hair and sprite
    set_hair_color(djump)
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

function set_hair_color(djump)
  pal(8,djump==1 and 8 or 12)
end

function update_hair(_ENV)
  local last=vector(x+4-(flip.x and-2 or 3),y+(btn(⬇️) and 4 or 2.9))
  for h in all(hair) do
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    last=h
  end
end

function draw_hair(_ENV)
  for i,h in pairs(hair) do
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
      f.follow=true
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
        state=1
        delay=3
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
          y=target
          spd=vector(0,0)
          state=2
          delay=5
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
        _g.cam_offx=offx
        _g.cam_offy=offy
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
		dy,delay=0,0
	end,
	update=function(_ENV)
		local hit=player_here()
		if delay>0 then
			delay-=1
		elseif hit then
			hit.y,hit.spd.y,hit.dash_time,hit.dash_effect_time,dy,delay,hit.djump=y-4,-3,0,0,4,10,max_djump
			hit.spd.x*=0.2
			psfx(14)
		end
	  dy*=0.75
	end,
	draw=function(_ENV)
		sspr(72,0,8,8-flr(dy),x,y+dy)
	end
}

side_spring={
	init=function(_ENV)
		dx,dir=0,is_solid(-1,0) and 1 or -1
	end,
	update=function(_ENV)
		local hit=player_here()
		if hit then
			hit.x,hit.spd.x,hit.spd.y,hit.dash_time,hit.dash_effect_time,dx,hit.djump=x+dir*4,dir*3,-1.5,0,0,4,max_djump
			psfx(14)
		end
		dx*=0.75
	end,
	draw=function(_ENV)
    -- _g.printh(_g._spr==_g.spr)
    -- _g.printh(_ENV)
		local dx=flr(dx)
		sspr(64,0,8-dx,8,x+dx*(dir-1)/-2,y,8-dx,8,dir==1)
	end
}


refill={
  init=function(_ENV)
    offset=rnd()
    timer=0
    hitbox=rectangle(-1,-1,10,10)
    active=true
  end,
  update=function(_ENV)
    if active then
      offset+=0.02
      local hit=player_here()
      if hit and hit.djump<max_djump then
        psfx(11)
        init_smoke()
        hit.djump=max_djump
        active=false
        timer=60
      end
    elseif timer>0 then
      timer-=1
    else
      psfx(12)
      init_smoke()
      active=true
    end
  end,
  draw=function(_ENV)
    if active then
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
    solid_obj=true
    state=0
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
        state=2
        delay=60--how long it hides for
        collideable=false
      end
    -- invisible, waiting to reset
    elseif state==2 then
      delay-=1
      if delay<=0 and not player_here() then
        psfx(12)
        state=0
        collideable=true
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
    spd=vector(0.3+rnd(0.2),-0.1)
    x+=-1+rnd(2)
    y+=-1+rnd(2)
    flip=vector(maybe(),maybe())
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
    y_=y
    off=0
    follow=false
    tx=x
    ty=y
    golden=sprite==11
    if golden and deaths>0 then
      destroy_object(_ENV)
    end
  end,
  update=function(_ENV)
    if not follow then
      local hit=player_here()
      if hit then
        hit.berry_timer=0
        follow=true
        target=#fruitrain==0 and hit or fruitrain[#fruitrain]
        r=#fruitrain==0 and 12 or 8
        add(fruitrain,_ENV)
      end
    else
      if target then
        tx+=0.2*(target.x-tx)
        ty+=0.2*(target.y-ty)
        local a=atan2(x-tx,y_-ty)
        local k=(x-tx)^2+(y_-ty)^2 > r^2 and 0.2 or 0.1
        x+=k*(tx+r*cos(a)-x)
        y_+=k*(ty+r*sin(a)-y_)
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
    start=y
    step=0.5
    sfx_delay=8
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
    spd.y=-0.25
    duration=30
    flash=0
    outline=false
    _g.sfx_timer=20
    sfx(9)
  end,
  update=function(_ENV)
    duration-=1
    if duration<=0 then
      destroy_object(_ENV)
    end
  end,
  draw=function(_ENV)
    flash+=0.5
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
	end,
	draw=function(_ENV)
		if break_timer==0 then
			if sprite==65 then
				pal(7,14)
				pal(6,2)
			end
      spr(64,x,y-1,2.0,1.0)
			pal()
		end
	end
}
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
      init_smoke_hitbox()
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
    hitbox=rectangle(0,0,12,12)
    outline=false --maybe add an extra black outline, or remove this?
  end,
  update=function(_ENV)
    local hit=player_here()
    if hit and not invisible then
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
        hit.invisible=false
        hit.djump=max_djump+1
        hit.do_dash=true
        invisible=true
        timer=0
      end
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
    dir=sprite==71 and -1 or 1
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
          init_smoke_hitbox()
          break_timer=0
          collideable=true
          active=false
        end
      else
        return
      end
    end

    if spd.x==0 and active then
      break_timer+=1
    else
      break_timer=0
    end
    if break_timer==16 then
      init_smoke_hitbox()
      death_timer=60
      collideable=false
    end

    spd=vector(active and dir or 0,0)
    local hit=check(player,0,-1)
    if hit then
      spd=vector(dir,btn(⬇️) and 1 or btn(⬆️) and not hit.is_solid(0,-1) and -1 or 0)
      active=true
    end
  end,
  draw=function(_ENV)
    if (death_timer>0) return

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
    spr(shake and 72 or spd.y~=0 and 73 or 71,mx-4,my+(break_timer<=8 and spd.y<0 and -3 or -4),1.0,1.0,dir==-1,spd.y>0)
    if hitbox.h==8 and shake then
      rect(mx-3,my-3,mx+2,my+2,1)
    end
    line(x+1,y,r-1,y,13)
    if not check(player,0,-1) and not is_solid(0,-1) then
      line(x+2,y-1,r-2,y-1,13)
    end
    pal()
  end

}

bg_flag={
  layer=0,
  init=function(_ENV)
    t=0
    wind=prev_wind_spd
    wvel=0
    ph=8
    while not is_solid(0,ph) and y+ph<lvl_ph do
      ph+=8
    end
    h=1
    w=2
    --outline=false
  end,
  update=function(_ENV)
	  wvel+=0.01*(wind_spd+sgn(wind_spd)*0.4-wind)
	  wind+=wvel
	  wvel/=1.1
    t+=1
  end,
  draw=function(_ENV)
	  line(x, y, x, y+ph-1, 4)
    for nx=w*8-1,0,-1 do
      local off = nx~=0 and sin((nx+t)/(abs(wind_spd)>0.5 and 10 or 16))*wind or 0
      local ang = 1-(wind/4)
      local xoff = sin(ang)*nx
      local yoff = cos(ang)*nx
      tline(x+xoff,y+off+yoff,x+xoff,y+h*8+off+yoff,lvl_x+x/8+nx/8,lvl_y+y/8,0,1/8)
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
tiles={
  [1]=player_spawn,
  [8]=side_spring,
  [9]=spring,
  [10]=fruit,
  [11]=fruit,
  [12]=fly_fruit,
  [15]=refill,
  [23]=fall_floor,
  [64] =bouncy_cloud,
  [65] =bouncy_cloud,
  [67] = fake_wall,
  [68] = snowball_controller,
  [70] = green_bubble,
  [71] = arrow_platform,
  [72] = arrow_platform,
  [74] = bg_flag
}

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
  end
  function oob(ox,oy)
    return not exit_left and left()+ox<0 or not exit_right and right()+ox>=lvl_pw or top()+oy<=-8
  end
  function place_free(ox,oy)
    return not (is_solid(ox,oy) or oob(ox,oy))
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
      if other and other.type==type and other~=_ENV and objcollide(other,ox,oy) then
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
      rem[axis]+=axis=="x" and ox+(type==player and dash_time<=0 and wind_spd or 0) or oy
      -- </wind> --
      local amt=round(rem[axis])
      rem[axis]-=amt

      local upmoving=axis=="y" and amt<0
      local riding=not player_here() and check(player,0,upmoving and amt or -1)
      local movamt
      if collides then
        local step=sign(amt)
        local d=axis=="x" and step or 0
        local p=_ENV[axis]
        for i=start,abs(amt) do
          if place_free(d,step-d) then
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
          hit.move(axis=="x" and (amt>0 and right()+1-hit.left() or amt<0 and left()-hit.right()-1) or 0,
                  axis=="y" and (amt>0 and bottom()+1-hit.top() or amt<0 and top()-hit.bottom()-1) or 0,
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

  -- <fake_wall> <arrow_platform>

  -- made into function because of repeated usage
  -- can be removed if doesn't save tokens
  function init_smoke_hitbox()
    for ox=0,hitbox.w-8,8 do
      for oy=0,hitbox.h-8,8 do
        init_smoke(ox,oy)
      end
    end
  end
  -- </fake_wall> </arrow_platform>




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
  -- <transition>
  tstate=0
  -- </transition>
end

-- [room functions]


function next_level()
  local next_lvl=lvl_id+1
  load_level(next_lvl)
end

function load_level(id)
  has_dashed=false

  --remove existing objects
  foreach(objects,destroy_object)

  --reset camera speed
  cam_spdx,cam_spdy=0,0

  local diff_level=lvl_id~=id

		--set level index
  lvl_id=id

  prev_wind_spd=wind_spd or 0
  --set level globals
  local tbl=split(levels[lvl_id])
  lvl_x,lvl_y,lvl_w,lvl_h,wind_spd=tbl[1]*16,tbl[2]*16,tbl[3]*16,tbl[4]*16,tbl[6] or 0

  lvl_pw=lvl_w*8
  lvl_ph=lvl_h*8

  local exits=tonum(tbl[5]) or 0b0001
  exit_top,exit_right,exit_bottom,exit_left=exits&1!=0,exits&2!=0,exits&4!=0, exits&8!=0

  --drawing timer setup
  ui_timer=5

  --reload map
  if diff_level then
    reload()
    --chcek for mapdata strings
    if mapdata[lvl_id] then
      replace_mapdata(lvl_x,lvl_y,lvl_w,lvl_h,mapdata[lvl_id])
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
    local tx,ty,tw,th,offx,offy=unpack(split(s))
    local t=init_object(camera_trigger,tx*8,ty*8)
    t.hitbox,t.offx,t.offy=rectangle(0,0,tw*8,th*8),offx,offy
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

end

-- [drawing functions]

function _draw()
  if freeze>0 then
    return
  end

  -- reset all palette values
  pal()

	--set cam draw position
  draw_x=round(cam_x)-64
  draw_y=round(cam_y)-64
  camera(draw_x,draw_y)

  -- draw bg color
  cls(9)

  -- bg clouds effect
  foreach(clouds,function(c)
    c.x+=c.spd-cam_spdx
    ovalfill(c.x+draw_x,c.y+draw_y,c.x+c.w+draw_x,c.y+16-c.w*0.18+draw_y,10)
    if c.x>128 then
      c.x=-c.w
      c.y=rnd(128)
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
    if type.layer==0 then
      draw_object(_ENV) --draw below terrain
    else
      add(layers[type.layer or 1],_ENV) --add object to layer, default draw below player
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
      x=-4
      y=_g.rnd128()
   	elseif x<-4 then
     	x=128
     	y=_g.rnd128()
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
  camera()
  color(0)
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
  -- </transition>
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
  return val>target and max(val-amount,target) or min(val+amount,target)
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
    rectfill(l,y0,r,y0,0)
    l+=lt
    r+=rt
  end
end
-- </transition> --
-->8
--[map metadata]

--level table
--"x,y,w,h,exit_dirs,wind_speed"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
levels={
	"0,0,2,1,0b0010,0",
	"2,0,2,1,?,0",
	"0,1,2,1,0b0010,0",
	"2,1,3,1,?,0",
	"4,0,3,1,?,0",
	"2,2,3,1,0b0010,-0.3",
	"0,2,2,1,?,-0.3",
	"7,0,1,1,?,0",
	"5,2,1,2,?,0",
	"5,1,3,1,0b0010,-0.3",
	"6,2,2,2,?,0",
	"0,3,5,1,0b0010,-0.6",
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


function move_camera(obj)
  --<camtrigger>--
  cam_spdx=cam_gain*(4+obj.x-cam_x+cam_offx)
  cam_spdy=cam_gain*(4+obj.y-cam_y+cam_offy)
  --</camtrigger>--

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  --clamp camera to level boundaries
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


--replace mapdata with hex
function replace_mapdata(x,y,w,h,data)
  for y_=0,h*2-1,2 do
    local offset=y*2+y_<64 and 8192 or 0
    for x_=1,w*2,2 do
      local i=x_+y_*w
      poke(offset+x+y*128+y_*64+x_/2,"0x"..sub(data,i,i+1))
    end
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
000000001ccc1cc111100000000011114fff4fff4fff4fff4fff4fffd666666dd666666dd666066d000000000000000070000000000000000000000000000000
000001001cc111c1ccc110000011c1cc4444444444444444444444446dddddd56ddd5dd56dd50dd5007700000770070007000007000000000000000000000000
00101c1011c101c1c11cc10001cc1ccc000450000000000000054000666ddd55666d6d5556500555007770700777000000000000000000000000000000000000
01c11c101c101c10110110000011011c00450000000000000000540066ddd5d5656505d500000055077777700770000000000000000000000000000000000000
01c101c101c11c10c1101100000110110450000000000000000005406ddd5dd56dd5065565000000077777700000700000000000000000000000000000000000
1c101c1101c10100ccc1cc10001cc11c4500000000000000000000546ddd6d656ddd7d656d500565077777700000077000000000000000000000000000000000
1c111cc100100000cc1c110000011ccc50000000000000000000000505ddd65005d5d65005505650070777000007077007000070000000000000000000000000
1cc1ccc1000000001111000000000111000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000
9ee0eee99eeeeeeeeee01eeeeeeeeeee11e221111111111112222ee19eeeeee94424442444244444444424440000000044444000494444440000000000000000
ee1e1e2eeee1222222112ee222222eee1ee221111111111111222ee1ee222eee4222444444244494494222440099400044444200449444440000000000000000
e122212eee122222112212222222222e1ee22211111111111122ee10e222222e2222244222224990042444240499429944422440424924420000000000000000
122e212ee2222221222212222222222211ee2221111111111222e111e22222222222222244442200024444424449429944424449222922290000000000000000
1e21e212e22222e2e2222122e2e2222e11e112221111111122222ee11e2e2e222222229244444400009944442444424444244494229222940000000000000000
21e2222122e22e121e22e1e21e1222e1011e222211111111222222e111e221ee9222299444449900009994444244424422244444924929440000000000000000
121ee111221ee12221ee11122122ee1111e222221111111112222e10111221e14922994444499900000994404422242444244440442499440000000000000000
91111119121112222211221211222ee111e222211111111112222211112222114499444444449000000000004444244444244400449944440000000000000000
12222211112222222222222222222221eeeeeeeeeeeeeeeeeeeeeeee112222211111111144449000000992990022444444424444444244440000000000000000
122e2e21122222222222222222222221e2ee2222eeeee2e2e22ee221112222211122111149499900009992990044244442224444442444440000000000000000
1221e1211e22222222222122222222e122e2222222ee222122e22221122222e11222211199449900099942444999424424442424424444440000000000000000
122112211e22e222222221122e22221122222e221222ee12ee1222211e222ee11222211144444420099442449994442444444244224444990000000000000000
122212211eeee222112e2e1121e22e1122222e22111ee1111122222111e22e111122211144442244044424444444442244444244424449990000000000000000
1122221111ee1ee2221eee22211ee1111e22e122e2111122122222e1111e22211111112222224994022244444444442444494299442449940000000000000000
1122222111e111e22101e1112111e11111ee12222ee2122222222e11111e21111111112244244494444244444444424404994299444244040000000000000000
112222219111011e1100111111111119911111111111111111211119911111191111111144244444442444444444244400994000444422000000000000000000
000770777007770000eeeeeeeeeeeee0007777000077770000bbbb00111111111111111111111111cccccccc0000000000000000000000000000000000000000
07777776777777700ee112221e221ee007767770077767700b3333b0111111111d1111d1111dddd14ccc11cccccc000000000000000000000000000000000000
77666666677677770e1e212221ee211e7777777767777777b333773b1111d11111d11d111111ddd14c111cc111cccccc00000000000000000000000000000000
7677766676666677e12e21212211e1217677777767767767b333773b1111dd11111dd1111111ddd14c1cc111cccccc0000000000000000000000000000000000
0666666666666660e22122e2e2e2122e7776777667777777b333333b1dddddd1111dd111111d11d14c1c1cc00000000000000000000000000000000000000000
000000000000000012e21e121e1212e17777776666777777b333333b1111dd1111d11d1111d111114c111ccc0000000000000000000000000000000000000000
0000000000000000221ee1212121ee1107777660066777700b3333b01111d1111d1111d1111111114ccc111cccc0000000000000000000000000000000000000
00000000000000001211121211121ee1006666000066770000bbbb00111111111111111100000000ccccccccc000000000000000000000000000000000000000
000000000000000011e1e11112212ee1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001ee2111111e12ee1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001ee22e111112ee10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000011ee21e11121e111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000011e1122212ee1ee1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000011e21222e1121e1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000011e1221211221e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000011e2112112122111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000a213525252525252525252525252525252525262920000a29352528352525262d2920000000000000000000000000000000000000000000000
0000000000000000000013235252525252525252525252835252526221a293005252528323232323232323232383525252522323232352525262210000314252
0000000000000000a242525252525252525252835252525283233300000000a25252525252526292000000000000000000000000000000000000000000000000
000000000000000000000000132323235283525252525252525252622100a293232323339200a292a3d29200a213525283331111111113525262210000314252
00000000000000000013835252525252525252525252525262829300000000005252525252836200000000000000000000000000000000000000000000000000
00000000000000000000000000000000525252525252525252525262210000a29200a29200000000a29200000011135233110000000011428362210000314252
000000000000000000a2425252525283525252525252525262a29264000000005252525252233300000000000000000000007201010200000000000000000112
634100000000000000000000000000005252525252525252525283622100000001a393000000f00000f000006400117311000000000000132333210000311352
00000000000000000000132383525252525252525252528362930000000000005252525262829200000000000000000000001322639200000000000000004333
000000000000000000000000000000002323232383525223232323332100000032a2920000000000010101010000001100000001000000111111000000001113
0000000000000000000000a21323232323235252522323236292000000000000528352526292000000000000000000000000a273920000000000000000000000
0000000000000000000000000012222293a292a21323331111111111001400a3629300000000010112535332010000000000017200a393000000000000000011
000000000000000000000000111111111111138362d29200730000000000000052525283330000000000000000000000000000000000000000a393000000a4b4
0000000000000000000000122283525282930000a2343500000000000000a3823392000000004353331111133201006400011262a382d2930101000000000000
00000000000000000000006400000064000011423392000000000000000000a35252526292000000000000000000000000000000000000a393a2829300000000
000000000000640000000042525252528292000000000000006400000000a29211000000a3931111110000a2133201000112526292a282821232000400000000
000000000000000000000000000100000000000392006400000000000000a392832323330000000000000000000000a4b40000000000a38292a38292a3930000
00000000000000000000014252525252920000000000000000000000000000a300000000a292000000000000a2133201122352620000a2824262000000000000
0000000000000000000000000072010000000073000000000000000000a392003392000000000000000000000000000000000000000043223241516112226300
000000000000000000001283525252529300f0000035000000010101000400a2000000000000010100000000a382135333c31362010000a24262010101000000
93000000000000000000000000132201000000110000000000000000a382930092000000000000000000000000001222329300000000a213330000a342339200
0000000000000000000042525252525292a393000001010101122232000000000000040000a31232000000a3d3c392000000a242320101014283222232010101
32930000000000000000000000a2422201000000000000000000a393a2d28293930000000000000000000000000042528332930000000000000000a273920000
0000000000000000000042525252528300a292a30112222222525262010101010000000000a2426201a3b2c39200000000008042832222225252525252222222
832232000000000000000000000042522200000000000000a393a292a382828292a39300000000000000000000014252526292a3930000640000a00000000000
00000001122222320000425252525252000000a21252525223232323222222220000000101014252328292000000000000a39342525252528352525252525283
525262100000000000011232000042524200000000000000a28293a38292a28222223241516172100000000000128352526293a2829300000000000000000000
0000a312525283620100428352525252000000a313522333920000a213525252010101122222525262921400000100a3b292a213525252525223232352525252
5252624151000000a31252620100425242930000000000a3828282828293a3825252629300a342226300000000425252526282d2829200000000000000000000
a393a2425252528332b24252525252520000a3829273829300000000111352232222225252525252620000000072a3c3926400a213835223339200a213232323
528362930000a393a242525232b242524282930000a393a282d292a28282d28252526282b2824262000000000042528352628282828293000000000000a393a3
8292a3428352525262824252525283520000a292a311a29200000000001173c32323238352525283620101010103920000000000a24233d29200000000a28282
440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a2132352525252
83525252525283628292000000a292a3000000a39200a393a3930100000011009200a2135252525252222222226201000000000000038292000000000000a282
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a29213835252
525252525252523392000000000000a2000000a293018292a282720100000000000000a2425252525252525252523200000000000073920000000000000000a2
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a382425252
5252525283233392000000000000000000040000a272920000a2423201006400000000a34252525252528352525262000000000000c300000000000000000001
0000000000000000000000000000000000000000000000000000000000000000000000000000a4b4000000000000000000000000000000a4b40000a282135252
525252233392000000000000000000a30101010101030101010142833200000000a3122252525252525252525252330000000000000000000000000000000112
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004332930000000000000000a2924252
528333d292000000000000000000a3d2222222222283222222225252620000002222835252525252525252525262920000000000000000000000000000a31283
0000000000000000000000000000000000000000a312226300000000436393000000000000000000000000000000000000a27341614322226300000000a34283
526282920000000000000000004322225283525223232352525252523300000052525252528352525252528352629300000000000000000000000000a3d24252
01000000000000000000000000000000000000614323339200000000a282920000000000a312222222329300000000000000000000a242339200000000a21323
2333920000000000a312329300a2132323232333a282821323238362920000005252525252525252525252522323324151611253222222222232415161128352
3200000000000000000201017200000000000000a29200000000000000a2829300a312222252232323832232000000900000000000a373920000000000000000
3435000000004353228352630000a2828293a28293a292a292a213620000000052832323238352525252523392a27300000073c342525252526221a000425252
620100000000000000a24322236341000000000000000000000000000000a28212225252233392a3821352629300a3020000000000a292000000000000000000
000000f0000000a213233392000000a2a2d293a2920000000000a2730000000023338292a2132352528333920000000064000000138352525262930000425252
52320000000000000000a27392000000000000000000000000a372930000004352835233a29200a292a342523293a29200000000000000000000000000640000
000000000000000000000000000000a393a2829300000000000000000000000093a292000000a213233392000000000000000000a24252528362a29331425252
133393000000000000000000000000000000a393000000000061136300000000132333920000000000a242836292000000000000000000000000000000000000
000000000000000000000000000000a28293a292000000000000000000000000829300000000001111110000000000000000000000132323233300a293425252
82829200000000000000000000000000a393122222329300000000000000000000343500000000000000425262000000000000a3122232930000000000000000
3500000000000000000000000000a39382829300000000000000000000000000829200000000006400000000000000000000000000003400350000a392425283
d2829300000000000000000000000000614383525252223200000000000064000000000000000000a00042526200000000004322835252225363000000000000
000000000000a3122222329300a3d28282829200000000000000000000900000920000000000000001010100000000a393000000000000000000a39200425252
222232100000000000a312223200000000a24252525252620100000000000000000000000000000000014252620100000000a213522323339200000000000000
00000000432222525252832232828282d28293a3930010a39300000000020000931000000000000012323280000000a2829300000000350000a3920031425252
52525263410000a31222528362010000000042525252528332000000000000000000f000f00000f0a312525283329300000000a2738292000000000000000000
00000000a21383525252525252222222222232415161432232930000a3930000222232930000000142526200000000a382920000004322222232010101425252
525262920000a38242525252523200000000425283525252620000000000000000350000000000a3824252525262d293000000a3828293000000000000000000
0000000000a242525252525283525252525262930000a242523293a3d292a3935252833293000012525262930000a38292a3930000a242525252222222835252
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
0000000000000000000000000000000002020202080808000000000000000000030303030303030304040404040400000303030303030303030404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000000000002a293a282828242525252525252525252525252525252525252525252525253825252525253825252525252525332d2828282400000000002a313232322525252525252532323225252525252525252525252525252525252538252525252526283d3c382525252629002a2425252525252525
0000000000000000000000000000002a3c3c28242525252525252525252525252525252538252525383232323232323232322525252538252526283d3c292a310000000000000000002a3132323238253311002a31323225253825252525253232323825252525252525252526282900252525252610003a3138252525252525
0000000000000000000000000000000000002a24382525253232322525252525382525252525253233292a2828393a282d2831252525252525263d290000003a000000000000000000000000001124331100000000002a313225252525383328293a24252525252525252538332900003232323238233a291131252525253825
000000000000000000000000000000000000003125252533292a2d313232322525253832323233290000002a2d28283c3c292a313825252538262c000000002a00000000000000000000000000003711000000000000002a2924252525262d28392a31323232252525323233110000002828292a312629000011313832323232
000000000000000000000000000000000000002a2425332900002a28282828313232332829000000000000002a2a28390000002a2425252532332900000000000000000000000000000000000000110000000000000000003a2425252526282d290011111111313833111111000000003d2900002a3010000000113711111111
0000000000000000000000000000000000000000313329000000002a282828282d283d290000000000000000003a2d2900000000312525262d290000000000000000000000000000000000000000000000100000000000002a242525253328294600000046001137110000000000000039010000002423100000001100000000
0000000000000000000000000000000000000000111100000000003a28282828282d2c000000000000000000002a2900000000002a243826290000000000000000000000000000000000000000000000102700000000000000312525262a290000001010000000110000001000000000222314003a2438231000460000460000
0000000000000000000000000000000000000000000000000000002a3c2d282828282900000000000000000000000000000000000024252600000000000000000000000000000000000000004600001021263a3900000000002a24382639000000002123000000000000102700400000253300002a242525231010100000003a
000000000000000000000000000000000000000000000000000000003a28282828290000000000000000212300000000000000000024253300000000000000000000000000000000000000000000002125262829000000000000313233290000000024261000004600102126000000002611000000242525323522230000002a
000000000000000000000000000000000000000010100000000000002a3c282d3c29000000000000000024260000000000000000003126290000000000000000000000000000000000000000000000242526290000000000000011111100000000003138233a3900002125260000000033000000102425260f2a242639003a39
0000000000000000003a21230000000000000000212300000000001000002a282b39000000000000000024260000000000000000002a37004600000000000000000000000000000000000000000000313826100000000000000000000000000000002a2426282900002425261000000029000010212525260000242628392a29
00000b0000000000002a24260000000000000000242600000000002700003a2122230001000000000010242600003a390000000000003c00000000002b00000000000000000000000000000000000011242523000000000000001010100000000000002426290000003138252339000039000021253825260a43242628290000
00000000000000003a392426100000004100000024260000000000300021222525382222360000000021382600002a2d39000000000000000000003a28390000000000000000000000000040000000002425260000000000003a212223004100003a392426100000002a24252629000029003a31323232330053313329400000
00010000000040002a282438233900000000001024263900400010300024382525252533290000003a24252610003a28290000000000000000003a282d2839000000000001000000000000000000003a242526390000003a2b2d2425263900003a2828242523390000002425263a390000002a2900002a2839003a2900000000
222223390000003a392a24252628390000003a2338262839003a21262b242525382526290000003a28242538232b2d282c3900000000000000002a3c3c282839222223141516342223393a3900003a282425262c3a393a28282824252628393a282d2824252628390000242526282839003a39000046002a293a290000460000
252538233900002a293a2425262a28393a2b2d24252628293a2824262824252525252639003a2b3b2924252526282828282c2b3900000000000000003a2828282525262b2b2b282425232828393a282d242526392a28282d2828242526282d2828282824252628293a392425262d28283a292a390000003a392a390000000000
000000000000000000002a282d2425252525252525323232322525252525252500000000002a2824252525252525252525252525252525252525252525252525252525252525252628282d2438252525000000000000000000000000003a28243825252525252525252525252525252525382525252525252525252525252525
00000000000000000000002a283125252538323233282d2828313825252525250000000000002a242525252525252525252525252525252525252525252525252525252525252526283c282425252525000000000000000000000000002a29242525252525252525253825252525252525252525253825252525252525252525
0000000000000000000000002a2a2425253328392a2828292a282425252525250000000000000031382525252538252525252538252525252525252525252538252525252525252629002a242525253800000000000000000000000000003a242525252525252525252525252525252525252525252525252525382525252525
000000000000000000000000003a2425302d2829002a3c393a28242525382525000000000000002a2425252525252525252525252525253825252525252525252525252525253826000000243832322500000000000000000000000000002a312525253825252525252525253832323225252525252525252525252525252525
000000000000000000001000002a2438332829004600002a2828242525252525000000000000003a312525252525252525323232323232323232252525252525252525253232322639003a2433292a310000000000000000000000000000003a2425252525252525252525253329002a31323825252525252525252525253825
00000000000000000010270000003126282900000010103a3c29312525252525000000000000002a2824382525252525263d3c29004353002a293125252525252525253329002a37141516372900002a0000000000000000000000000000002a24252525323232323225252629000000002a3125252525252525252525252525
00000000000000001021261000002a30290000001021232900002a242525253800000000000000002a313225252525383329000000000000003a28313825252525383329000000000000000000000000000000000000000000000000000000003125252611111111113138330000000000002a24252525252538252525252525
00000000000000002138252300000037390000102138260000000024382532320000000000000000002a2831323232332900460000000046002a292a3132323232332900460000000046000000000000000000000000000000000000000000002a24383300000000002830290046000000000031323825252532323232323825
0000000000000000312525260000002a29000021252526100000003132331111000000000000000000002a29004353000000000000000000000000002a2943530000000000000000000000000000000000000000000000003a39004a4b0000000031262900000000002a300000001010000000002a31323233282900002a3132
00000000000000002a242526000000000000002425252523000000111111000000000000000000000000000000000000000000000053000000000000000000000000000000000000000000000000003a000000000000003a2828390000000000002a300000101000003a37000000212300000000002a3c2d2829000000003a28
000000000000000000242526100000000000002425252526000000000000003a390000000000000000004600000000460000000000000000000000460000000046000000000000000000000000003a29000000000000002a293a2122233900000000370000212300002a290000002426100000000000002a2900000000002a2d
0000000000000000002425382339000000001024252525260000000000003a282d39000000000000000000000000000000000000002b3900000000000000000000000000000000000000000000002a390000000000000000002a31382523000000000000003126103a390000000024382300000000000000000000003a393a28
23000100000040003a242525262900410000213825252526000000003a2122222223010000000000000000000053000000000000002a290000000000000053000000000000000000000000003a393a2839000000000000000000112425260000000000463a282423282900000010242526080000000000000000003a21222222
252222360000003a28313825263a3900003a24252525382639000000213825253825222339000000000000000000000000000000003a393a393a390000000000000000000000000000003a3928282828233901000000000900003a24252600000000003a2d282426290000003a212525263900000000003a2122222238252525
253833290000002a2d282425262828393a3c2425252525262839003a2425252525252538233900000000000000000000000000003a282828282d29000000000000000000000000003a2d2828282828282522233900000020003a282425261000003a392a28282426394000002a2425252628390000003a213825252525252525
25262900000000002a282425262a282d290024252525252628283a2924252525252525252628390000000000000000000000003a28282d282828283900000000000000000000003a282828292a282828252538233900003a392a2824253823393a28293a282824262839003a39242538262a28393a392a242525252525253825
__sfx__
61100012310002504500000000002704500000000002a04500000000002e04500000000002a04500000000002c045000000000000000000000000000000000000000000000000000000000000000000000000000
911b000008614086100861500000000000861408610086100a6110a610086110c6210c6200c6200a6110a6100a615000000000006614066100661003621066110661008611086100861008615000000000000000
010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
911b0000007000661006610086100861008610066100a6100a6210a6200c6110c6100a6100c6210e6200e6200e6200c6110a6100e6210e62010620106200e6201163111630116301363010621156311563015630
c506001f2471500000000002871500000000002671500000000002671500000000002871500000000002471500000000002871500000000002971500000000002871500000000002b71500000000000000000000
911b0000156301362115631156301162111620116200e63110631106300e6210e6200c6110c6100e6210e6200c6110c6100c6100862108620086200a6210a620066210a6200a6200662106620036210362500000
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
01 00014240
00 00030440
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

