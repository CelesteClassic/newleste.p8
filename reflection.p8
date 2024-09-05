pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
--newleste.p8 base cart

_g=_ENV

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
-- [entry point]

function _init()
  _g.max_djump,_g.deaths,_g.frames,_g.seconds,_g.minutes,_g.music_timer,_g.time_ticking,_g.berry_count=1,0,0,0,0,0,true,0
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

-- [player entity]

player={
  layer=2,
  init=function(_ENV)
    grace,jbuffer=0,0
    djump=_g.max_djump
    dash_time,dash_effect_time=0,0
    dash_target_x,dash_target_y=0,0
    dash_accel_x,dash_accel_y=0,0
    hitbox=rectangle(1,3,6,5)
    spr_off=0
    collides=true
    bouncetimer=0
    create_hair(_ENV)
    -- <fruitrain> --
    berry_timer=0
    feather=false
    _g.berry_count=0
    particles={}
    -- </fruitrain> --
  end,
  update=function(_ENV)
    if pause_player then
      return
    end

    -- horizontal input
    local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0

    -- <feather> --
    -- vertical input
    local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0

    -- update feather particles (update remaining ones if not in feather state)
    foreach(particles,function(p)
      p.x+=p.xspd
      p.y+=p.yspd
      p.xspd=appr(p.xspd, 0, 0.03)
      p.yspd=appr(p.yspd, 0, 0.03)
      p.life-=1
      if p.life==0 then
        del(particles, p)
      end
    end)
    -- </feather> --

    -- spike collision / bottom death
    if is_flag(0,0,-1) or
	    y>lvl_ph then
	    kill_player(_ENV)
    end

    if feather then
      local k=1
      if h_input!=0 or v_input!=0 then
        -- calculate direction and velocity
        movedir=appr_circ(movedir,atan2(h_input,v_input),0.04)

        -- speed up if holding button
        k=1.5
      end
      spd = vector(k*cos(movedir), k*sin(movedir))

      -- update tail
      local last=vector(x+4.5,y+4.5)
      foreach(tail,function(h)
				h.x+=(last.x-h.x)/1.4
				h.y+=(last.y-h.y)/1.4
				last=h
			end)


      --bounce off objects
    	if bouncetimer==0 then
      	if is_solid(0, 2) or is_solid(0, -2) then
        	movedir *=-1
        	bouncetimer = 2
        	init_smoke()
				elseif is_solid(2, 0) or is_solid(-2, 0) then
					movedir = round(movedir)+0.5-movedir
					bouncetimer = 2
					init_smoke()
				end
			end
			--make sure we dont bounce too often
    	if bouncetimer>0 then
      	bouncetimer-=1
    	end


      -- feather particles
      local particle = {x=x+rnd(8)-4, y=y+rnd(8)-4, life=10+flr(rnd(5))}
			particle.xspd = -spd.x/2-(x-particle.x)/4
			particle.yspd = -spd.y/2-(y-particle.y)/4
			add(particles, particle)

      lifetime-=1
      if lifetime==0 or btn(❎) then
        -- transform back to player
        p_dash=false
        feather=false
        init_smoke()
        player.init(_ENV)
        spd.x/=2
        spd.y=spd.y<0 and -1.5 or 0
      end
    elseif feather_idle then
      spd.x*=0.8
      spd.y*=0.8
      spawn_timer-=1
      if spawn_timer==0 then
        feather_idle=false
        feather=true
        if h_input==0 and v_input==0 then
          movedir=flip.x and 0.5 or 0
        else
          movedir=atan2(h_input,v_input)
        end
        lifetime=60
        _g.bouncetimer=0
        tail={}
        particles={}
        for i=0,15 do
          add(tail,{x=x+4,y=y+4,size=mid(1,2,9-i)})
        end
      end
    end
    if not feather and not feather_idle then
      -- cursed token save: use else and goto here

      -- on ground checks
      local on_ground=is_solid(0,1)

          -- <fruitrain> --
      if on_ground then
        berry_timer+=1
      else
        berry_timer=0
        _g.berry_count=0
      end

      for f in all(fruitrain) do
        if f.type==fruit and not f.golden and berry_timer>5 and f then
          -- to be implemented:
          -- save berry
          -- save golden
          berry_timer=-5
          _g.berry_count+=1
          _g._g.got_fruit[f.fruit_id]=true
          init_object(lifeup, f.x, f.y,_g.berry_count)
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

      -- grace _g.frames and dash restoration
      if on_ground then
        grace=6
        if djump<_g.max_djump then
          psfx(22)
          djump=_g.max_djump
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
            spd.y=-2
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

        if djump>0 and dash then
          init_smoke()
          djump-=1
          dash_time=4
          has_dashed=true
          dash_effect_time=10
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
      -- exit level off the top (except summit)
      if y<-4 and levels[lvl_id+1] then
        next_level()
      end

      -- was on the ground
      was_on_ground=on_ground
    end
  end,

  draw=function(_ENV)-- clamp in screen

    local clamped=mid(x,-1,lvl_pw-7)
    if x~=clamped then
      x=clamped
      spd.x=0
    end
    --<feather> --

    -- draw feather particles (if not in feather state draw remaining ones)
    foreach(particles, function(p)
			pset(p.x+4, p.y+4,10)
    end)

    if feather and lifetime then
      if lifetime%5==1 then pal(10, 7) end

			if lifetime < 10 then
				pal(10, lifetime%4<2 and 8 or 10)
			end
			circfill(x+4, y+4, 4, 10)
      foreach(tail,function(h)
				circfill(h.x,h.y,h.size,10)
			end)
    elseif feather_idle then
      circfill(x+4, y+4, 4, spawn_timer%4<2 and 7 or 10)
    --</feather> --
    else
      -- draw player hair and sprite
      set_hair_color(djump)
      draw_hair(_ENV)
      draw_obj_sprite(_ENV)
      pal()
    end
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
    djump=_g.max_djump
    --- <fruitrain> ---
    for i=1,#fruitrain do
      local f=init_object(fruit,x,y,fruitrain[i].spr)
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
  -- draw=function(_ENV)
  --   set_hair_color(_g.max_djump)
  --   draw_hair(_ENV,1)
  --   draw_obj_sprite(_ENV)
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
        _g.cam_offx+=_g.cam_gain*(offx-_g.cam_offx)
        _g.cam_offy+=_g.cam_gain*(offy-_g.cam_offy)
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
			hit.y,hit.spd.y,hit.dash_time,hit.dash_effect_time,dy,delay,hit.djump=y-4,-3,0,0,4,10,_g.max_djump
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
			hit.x,hit.spd.x,hit.spd.y,hit.dash_time,hit.dash_effect_time,dx,hit.djump=x+dir*4,dir*3,-1.5,0,0,4,_g.max_djump
			psfx(14)
		end
		dx*=0.75
	end,
	draw=function(_ENV)
		local dx=flr(dx)
		sspr(64,0,8-dx,8,x+dx*(dir-1)/-2,y,8-dx,8,dir==1)
	end
}


refill={
  init=function(_ENV)
    offset=rnd(1)
    timer=0
    hitbox=rectangle(-1,-1,10,10)
    active=true
  end,
  update=function(_ENV)
    if active then
      offset+=0.02
      local hit=player_here()
      if hit and hit.djump<_g.max_djump then
        psfx(11)
        init_smoke()
        hit.djump=_g.max_djump
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
    local x,y=x,y
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
--[[fruit={
  check_fruit=true,
  init=function(_ENV)
    y_=y
    off=0
    follow=false
    tx=x
    ty=y
    golden=sprite==11
    if golden and _g.deaths>0 then
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

      local f=init_object(fruit,x,y,10) --if _ENV happens to be in the exact location of a different fruit that has already been collected, _ENV'll cause a crash
      --TODO: fix _ENV if needed
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
}]]
--commented out berries- fix golden berry later
---[[
kevin={
  init=function(_ENV)
    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==65 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==80 do
      hitbox.h+=8
    end
    solid_obj=true
    collides=true
    retrace_list={}
    hit_timer=0
    retrace_timer=0
    shake=0
  end,
  update=function(_ENV)
    if shake>0 then
      shake-=1
    end
    for xdir=-1,1 do
      for ydir=-1,1 do
        if (xdir+ydir)%2==1 then
          local hit=check(player,xdir,ydir)
          if hit and hit.dash_effect_time>0 and
            (xdir!=0 and sign(hit.dash_target_x)==-xdir or ydir!=0 and sign(hit.dash_target_y)==-ydir) and
            (not active or xdir!=dirx and ydir!=diry) then
            hit.spd=vector(xdir*1.5,ydir==1 and 0.5 or -1.5)
            hit.dash_time=-1
            --hit.dash_effect_time=0

            add(retrace_list,vector(x,y))
            dirx,diry=xdir,ydir
            spd=vector(0,0)
            hit_timer=10
            active=true
            shake=4
          end
        end
      end
    end

    if hit_timer>0 then
      hit_timer-=1
      if hit_timer==0 then
        spd=vector(0.2*dirx,0.2*diry)
      end
    elseif active  then
      if spd.x==0 and spd.y==0 then
        retrace_timer=10
        active=false
        shake=5
        if dirx!=0 then
          for oy=0,hitbox.h-1,8 do
            init_smoke(dirx==-1 and -8 or hitbox.w,oy)
          end
        else
          for ox=0,hitbox.w-1,8 do
            init_smoke(ox,diry==-1 and -8 or hitbox.h)
          end
        end
      else
        spd=vector(appr(spd.x,3*dirx,0.2),appr(spd.y,3*diry,0.2))
      end
    elseif retrace_timer>0 then
      retrace_timer-=1
      if retrace_timer==0 then
        retrace=true
      end
    elseif retrace then
      local last=retrace_list[#retrace_list]
      if not last then
        retrace=false
      elseif last.x==x and last.y==y then
        del(retrace_list,last)
        retrace_timer=5
        shake=4
        spd=vector(0,0)
        rem=vector(0,0)
      else
        spd=vector(appr(spd.x,sign(last.x-x),0.2),appr(spd.y,sign(last.y-y),0.2))
      end
    end
  end,
  draw=function(_ENV)
    local x,y=x,y
    if shake>0 then
      x+=rnd(2)-1
      y+=rnd(2)-1
    end
    local r,b=x+hitbox.w-8,y+hitbox.h-8
    local up,down,left,right=active and diry==-1,active and diry==1,active and dirx==-1,active and dirx==1
    for sx=x+8, r-8,8 do
      pal(12, up and 7 or 12)
      spr(65,sx,y)
      pal(12, down and 7 or 12)
      spr(65,sx,b,1,1,false,true)
    end
    for sy=y+8, b-8,8 do
      pal(12, left and 7 or 12)
      spr(80,x,sy)
      pal(12, right and 7 or 12)
      spr(80,r,sy,1,1,true)
    end
    rectfill(x+8,y+8,r,b,4)

    -- spr(64,x,y)
    -- spr(64,r-8,y,1,1,true)
    -- spr(64,x,b-8,1,1,false,true)
    -- spr(64,r-8,b-8,1,1,true,true)
    local lookup={down,left,up,right,down}
    for i=0,3 do
      pal(12,(lookup[i+1] or lookup[i+2]) and 7 or 12)
      spr(64,i<=1 and x or r, (i-1)\2==0 and y or b,1,1,i>=2,(i-1)\2!=0)
    end
    pal()
    -- face
    spr(active and 67 or 66,x+hitbox.w/2-4,y+hitbox.h/2-4)
  end

}--]]


bumper={
  init=function(_ENV)
    hitbox=rectangle(1,1,14,14)
    hittimer=0
    outline=false
  end,
  update=function(_ENV)
    if hittimer>0 then
      hittimer-=1
      if hittimer==0 then
        init_smoke(4,4)
      end
    else
      local hit=player_here()
      if hit then
        hit.init_smoke()
        local dx,dy=x+8-(hit.x+4),y+8-(hit.y+4)
        local angle=atan2(dx,dy)
        hit.spd = abs(dx) > abs(dy) and vector(sign(dx)*-2.8,-2) or --  -3.5*(cos(0.9),sin(0.9))
                 vector(-3*cos(angle),-3*sin(angle))
        hit.dash_time,hit.djump=-1,_g.max_djump
        hittimer=20
      end
    end
  end,
  draw=function(_ENV)
    local sx,sy=x+8,y+8
		if hittimer>0 then
			pal(12, 1)
			pal(4, 2)
			if hittimer > 17 then
				circ(sx, sy, 26-hittimer, 7)
				circfill(sx, sy, 25-hittimer, 1)
				if hittimer > 19 then
					rectfill(sx-4, sy-9, sx+4, sy+9, 7)
					rectfill(sx-9, sy-4, sx+9, sy+4, 7)
				end
			end
		end
		spr(68, x, y, 2, 2)
		pal()
		if hittimer == 1 then
			circfill(sx, sy, 4, 6)
		end
  end
}
 
--<feather> --
function appr_circ(value,target,amount)
	return (value +sign(sin(value)*cos(target)-cos(value)*sin(target))*amount)%1
end

feather={
  init=function(_ENV)
    sprtimer=0
    offset=0
    starty=y
    timer=0
  end,
  update=function(_ENV)
    if timer>0 then
      timer-=1
      if timer==0 then
        init_smoke()
      end
    else
      sprtimer+=0.2
      offset+=0.01
      y=starty+0.5+2*sin(offset)
      local hit=player_here()
      if hit then
        init_smoke()
        timer=60
        if hit.feather then
          hit.lifetime=60
        else
          hit.spawn_timer,hit.feather_idle,hit.dash_time,hit.dash_effect_time=10,true,0,0
          hit.spd=vector(mid(hit.spd.x,-1.5,1.5),mid(hit.spd.y,-1.5,1.5))
        end
      end
    end
  end,
  draw=function(_ENV)
    if timer==0 then
      local d=flr(sprtimer%6)
      spr(70+min(d,6-d),x,y, 1, 1,d>3)
    end
  end
}

-- </feather>

garbage={
  init=function(_ENV)
    local hit = check(osc_plat,0,-1)
    if hit then
      hit.badestate=sprite+1
      hit.hitbox.h+=8
      destroy_object(_ENV)
      return
    end

    --handle both garbage loading orders
    hit=check(osc_plat,-1,0)
    if hit then
      hit.target_id=sprite
      foreach(objects, function(o)
        if o.type==garbage and o.sprite==sprite and o!=_ENV then
          hit.targetx,hit.targety=o.x,o.y
          destroy_object(o)
        end
      end)
      destroy_object(_ENV)
    else
      foreach(objects, function(o)
        if o.type==osc_plat and o.target_id==sprite then
          o.targetx,o.targety=x,y
          destroy_object(_ENV)
        end
      end)
    end

  end,
  end_init=function(_ENV)
    for o in all(objects) do
      if o.type==badeline then
        o.nodes[sprite+1]={x,y}
      end
    end
    destroy_object(_ENV)
  end
}
badeline={
  init=function(_ENV)
    nodes={}
    next_node=1
    freeze=0
    outline=false
    off=0
    target_x,target_y=x,y
    rx,ry=x,y
    --hitbox=rectangle(-4,-2,16,12)
    attack=0 --hardcoded for now, will eventually be loaded from level table
    --b=_ENV
    attack_timer=0
  end,
  update=function(_ENV)
    off+=0.005
    attack_timer+=1
    x,y=round(rx+4*sin(2*off)),round(ry+4*sin(off))
    if freeze>0 then
      freeze-=1
    else
      if round(rx)!=target_x or round(ry)!=target_y then
        rx+=0.2*(target_x-rx)
        ry+=0.2*(target_y-ry)
      else
        local hit=player_here()
        if hit then
          attack_timer=1
          destroy_object(laser or {})
          if next_node>#nodes then
            target_x=lvl_pw+50
            node=-1
            freeze=10
          else
            target_x,target_y=unpack(nodes[next_node])
            freeze=10
          end
          next_node+=1

          hit.dash_time=4
          hit.djump=_g.max_djump
          hit.spd=vector(-2,-1)
          hit.dash_accel_x,hit.dash_accel_y=0,0 --stuff dash without stuffing dash_time
          off=0


          --activate falling blocks:
          local off=20
          foreach(objects, function(o)
            if o.type==fall_plat and o.x<=x  or o.type==osc_plat and next_node-1==o.badestate then
              o.timer=off
              o.state=0
              off+=15
            end
          end)
        -- else
        --   hitbox=rectangle(-4,-2,16,12) --try to suck player in
        --   local hit=player_here()
        --   hitbox=rectangle(0,0,8,8)
        --   if hit then
        --     hit.dash_time=0
        --     if hit.left()>right() then
        --       hit.spd.x=min(hit.spd.x,-1)
        --     elseif hit.right()<left() then
        --       hit.spd.x=max(hit.spd.x,1)
        --     end
        --     if hit.top()>bottom() then
        --       hit.spd.y=min(hit.spd.y,-1)
        --     elseif hit.bottom()<top() then
        --       hit.spd.y=max(hit.spd.y,1)
        --     end
        --   end
          -- sucking in needs more work


        --attacks
        elseif node!=-1 and find_player() then
          if attack==1 and attack_timer%60==0 then --single orb
            --assert(false)

            init_object(orb,flip.x and right() or left() ,y+4)
          elseif attack==2 and attack_timer%100==0 then --laser
            laser=init_object(laser,x,y)
            laser.badeline=_ENV
          end
        end
      end

    end

    -- facing direction
    foreach(objects,function(o)
      if o.type == player and _g.freeze==0 then
        if o.x>x+16 then
          flip.x=true
        elseif o.x<x-16 then
          flip.x=false
        end
      end
    end)
  end,
  draw=function(_ENV)
    for i=1,2 do
      pal(i,_g.freeze==0 and i or _g.frames%2==0 and 14 or 7)
    end
    --draw_x,draw_y=x+4*sin(2*off)+0.5,y+4*sin(off)+0.5
    -- badehair(_ENV,1,-0.1)
    -- badehair(_ENV,1,-0.4)
    -- badehair(_ENV,2,0)
    -- badehair(_ENV,2,0.5)
    -- badehair(_ENV,1,0.125)
    -- badehair(_ENV,1,0.375)
    for p in all(split("1,-0.1 1,-0.4 2,0 2,0.5 1,0.125 1,0.375"," ")) do
	    badehair(_ENV,unpack(split(p)))
    end
    draw_obj_sprite(_ENV)
    pal()

  end
}

function badehair(_ENV,c,a)
 for h=0,4 do
  circfill(x+(flip.x and 2 or 6)+1.6*h*cos(a),y+3+1.6*h*sin(a)+(_g.freeze>0 and 0 or sin((_g.frames+3*h+4*a)/15)),mid(1,2,3-h),c)
 end
end

orb={
  init=function(_ENV)


    for o in all(objects) do
      if o.type==player then
        local dx,dy=o.x+4-x,o.y+4-y
        local k=sqrt(dx^2+dy^2)*0.65
        spdx,spdy=dx/k,dy/k
        --spdx,spdy=-1/0.65,0
      end
    end

    init_smoke(-4+2*sign(spdx),-4)

    hitbox,         t,y_,particles=
    rectangle(-2,-2,5,5),0,     y,  {}
  end,
  update=function(_ENV)
    t+=0.05
    x+=spdx
    y_+=spdy
    y=round(y_+1.5*sin(t))
    local hit=player_here()
    if hit then
      kill_player(hit)
    end
    if maybe() then
      add(particles,{
        x=x,
        y=y,
        dx=-rnd()*spdx,
        dy=-rnd()*spdy,
        c=8,
        d=15
      })
    end
    foreach(particles,function(p)
      p.x+=p.dx
      p.y+=p.dy
      if rnd()<0.3 then
        p.c=split"7,8,14"[1+flr(rnd(3))]
      end
      p.d-=1
      if p.d<0 then
        del(particles,p)
      end
    end)
  end,
  draw=function(_ENV)
    -- particles
    foreach(particles,function(p)
      pset(p.x,p.y,p.c)
    end)
    -- spinny thing
    local x,y,t=x,y,t
    for a=t,t+0.08,0.01 do
      pset(round(x+6*cos(a)),round(y-6*sin(a)),8)
    end

    --inner animation
    local sx,sy,i=cos(2*t)<=-0.5 and 1 or 0, cos(2*t)>0.5 and 1 or 0, 1+flr((1.5*t)%3)

    --unoptimized, clearer code
    --[[
      local r=2
      ovalfill(x-r-sx,y-r-sy,x+r,y+r,i==2 and 8 or 2)
      r=round(1-cos(1.5*t))
      if r>0 or i==3 then
        if i==3 then r=2-r end
        ovalfill(x-r-sx,y-r-sy,x+r,y+r,split"14,7,8"[i])
      end
    ]]
    for r in all{2.001,round(1-cos(1.5*t))} do
      if r>0 or i==3 then
        if r!=2.001 and i==3 then r=2-r end
        ovalfill(x-r-sx,y-r-sy,x+r,y+r,r!=2.001 and split"14,7,8"[i] or i==2 and 8 or 2)
      end
      pal()
    end
  end
}

function find_player()
  for o in all(objects) do
    if o.type==player or o.type==player_spawn then
      return o
    end
  end
end

function line_dist(x0,y0,x1,y1,x2,y2)
  local dx,dy=x2-x1,y2-y1
  return abs(dx*(y1-y0)-(x1-x0)*dy)/sqrt(dx^2+dy^2)
end

function rectfillr(x1,y1,x2,y2,a,xc,yc,c)
    -- rotation about xc,yc
  local function rc(x,y) x,y=x-xc,y-yc return vector(xc+cos(a)*x-sin(a)*y,yc+sin(a)*x+cos(a)*y) end
  -- rect points + max/min
  local pts,top,bot=
    {rc(x1,y1),rc(x1,y2),rc(x2,y2),rc(x2,y1)},0x7fff.ffff,0x8000.0000
  for pt in all(pts) do
    top,bot=min(top,pt.y),max(bot,pt.y)
  end
  -- draw that shit
  for _y=ceil(top),bot do
    local x1,x2=0x7fff.ffff,0x8000.0000
    for i,p1 in pairs(pts) do
      local p2=pts[1+i%4]
      if mid(_y,p1.y,p2.y)==_y then
        local _x=p1.x+(_y-p1.y)/(p2.y-p1.y)*(p2.x-p1.x)
        x1,x2=min(x1,_x),max(x2,_x)
      end
    end
    rectfill(x1,_y,x2,_y,c)
  end
end

function get_laser_coords(_ENV)
  return badeline.x+4,badeline.y-1,playerx+4,playery+6
end
laser={
  layer=3,
  init=function(_ENV)
    local _ENV=_ENV
    outline=false
    timer=0
    particles={}
  end,
  update=function(_ENV)
    timer+=1
    local p=find_player()
    if timer<30 then
      playerx,playery=appr(playerx or badeline.x,p.x,10),appr(playery or badeline.y,p.y,10)
    elseif timer==45 then
      if line_dist(p.x+4,p.y+6,get_laser_coords(_ENV))<6 then
        kill_player(p)
      end
    elseif timer>=48 and #particles==0 then
      destroy_object(_ENV)
    end
    foreach(particles, function(p)
      p.x+=p.dx
      p.y+=p.dy
      p.d-=1
      if p.d<0 then
        del(particles,p)
      end
    end)
  end,
  draw=function(_ENV)
    local timer=timer
    if timer>42 and timer<45 then return end
    if timer<48 then
      local x1,y1,x2,y2=get_laser_coords(_ENV)
      local dx12,dy12=x1-x2,y1-y2
      local x3,y3=x1-128*dx12,y1-128*dy12

      --draw ball electricity lines
      for i=0,rnd(4) do
        local a = rnd()
        line(x1,y1,x1+cos(a)*rnd(7),y1+sin(a)*rnd(7),7)
      end

      --x,y,magnitude to player,scale with big laser,color flashing white
      local _x,_y,d,s,c=x1,y1,sqrt(dx12^2+dy12^2)*0.1,timer>45 and 2 or 0.5,timer>=30 and timer%4<2 and 7 or 8

      --draw laser electricity lines
      line(x1,y1,x1,y1,8) --set line cursor pos
      for i=0,10 do
        _x-=dx12/d
        _y-=dy12/d
        line(_x+(rnd(10)-5)*s,_y+(rnd(10)-5)*s,maybe() and 0 or timer>45 and c or 2)
        if timer==47 then
          for j=1,3 do
            add(particles,{
              x=_x,
              y=_y,
              dx=rnd()-0.5,
              dy=rnd()-0.5,
              d=10
            })
          end
        end
      end

      if timer<45 or timer==47 then
        line(x1,y1,x3,y3,c)
        local bscale = timer>30 and timer%4<2 and 4 or 2
        for i=1,2 do
          circfill(x1,y1,bscale/i,7+i)
        end
      else
        -- rectfillr(x1+2,y1-4,x1+132,y1+4,atan2(x3-x1,y3-y1),x1,y1,7)
        -- rectfillr(x1+2,y1-4,x1+132,y1-3,atan2(x3-x1,y3-y1),x1,y1,8)
        -- rectfillr(x1+2,y1+3,x1+132,y1+4,atan2(x3-x1,y3-y1),x1,y1,8)
        for i=1,3 do
          rectfillr(x1+2,y1+split"-4,-4,3"[i],x1+132,y1+split"4,-3,4"[i],atan2(x3-x1,y3-y1),x1,y1,split"7,8,8"[i])
        end
        circfill(x1,y1,4,7)
      end
    end
    foreach(particles,function(p)
      pset(p.x,p.y,p.d>4 and 8 or 2)
    end)
  end
}

function plat_draw(_ENV)
  local x,y=x,y
  if shake>0 then
    x+=rnd(2)-1
    y+=rnd(2)-1
  end

  local r,d,t=x+hitbox.w-8,y+hitbox.h-8,1.5*timer-4.5

  if palswap then
    pal(12,2)
    pal(7,14)
  end

  if t>0 and t<12 and state==0 then
    rect(x-t,y-t,r+t+8,d+t+8,14)
  end


  for i=x,r,r-x do
    for j=y,d,d-y do
--      spr(34,i,j,1.0,1.0,i~=x,j~=y)
    end
  end
  spr(33,x,y)
  spr(35,r,y)
  spr(49,x,d)
  spr(51,r,d)
  for i=x+8,r-8,8 do
    spr(34,i,y)
    spr(50,i,d)
  end
  for i=y+8,d-8,8 do
    spr(32,x,i)
    spr(48,r,i)
  end
  for i=x+8,r-8,8 do
    for j=y+8,d-8,8 do
      spr((i+j-x-y)%16==0 and 40 or 41,i,j)
    end
  end
  pal()
end


fall_plat={
  init=function(_ENV)
    -- beware if changing implementation, osc_plat calls _ENV func
    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==76 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==76 do
      hitbox.h+=8
    end
    collides,solid_obj,timer,shake,state=true,true,0,0,0
  end,
  update=function(_ENV)
    local _ENV,appr=_ENV,appr
    if timer>0 then
      timer-=1
      if timer==2 then
        palswap=true
      end
      if timer==0 then
        state+=1
        spd.y,shake=0.4,0
      elseif state==0 then
        shake=1
      end
    elseif state==1 then
      if spd.y==0 then
        for i=0,hitbox.w-1,8 do
          init_smoke(i,hitbox.h-2)
        end
        timer,shake=6,3
      end
      spd.y=appr(spd.y,4,0.4)
    end
  end,
  draw=plat_draw
}

osc_plat={
  init=fall_plat.init, -- kinda terrible because depends on fall_plat implementation, but tokens
  end_init=function(_ENV)
    hitbox.w+=8
    if not badestate then
      timer=1
    end
		local targetx,targety=0,0

    local dx,dy=targetx-x,targety-y
    local d=sqrt(dx^2+dy^2)

    t,shake,palswap,
    startx,starty,
    dirx,diry=
    0, 0, not badestate,
    x,y,
    dx/d,dy/d

    --start=true
  end,
  update=function(_ENV)
    if timer>0 then
      timer-=1
      palswap,start=timer<=2,timer==0
    elseif start then
      if state==0 then
        state=t==0 and 1 or t==40 and 2 or 0
      else
        local s,tx,ty=1,targetx,targety
        if state==2 then
          s,tx,ty=-1,startx,starty
        end

        spd=vector(mid(appr(spd.x,s*5*dirx,abs(0.5*dirx)),tx-x,x-tx),
                   mid(appr(spd.y,s*5*diry,abs(0.5*diry)),ty-y,y-ty))
        if spd.x|spd.y==0 then
          shake,state=3,0
          if is_solid(sign(s*dirx),0) then
            for oy=0,hitbox.h-1,8 do
              init_smoke(sign(dirx)==s and hitbox.w-1 or -4,oy)
            end
          end
          if is_solid(0,sign(s*diry)) then
            for ox=0,hitbox.w-1,8 do
              init_smoke(ox,sign(diry)==s and hitbox.h-1 or -4)
            end
          end

        end
      end

      --end


      t=(t+1)%80
    end
    shake=max(shake-1) --,0
  end,
  draw=plat_draw
}

psfx=function(num)
  if _g.sfx_timer<=0 then
   sfx(num)
  end
end

-- [tile dict]
tiles={
  [1]=player_spawn,
  [8]=side_spring,
  [9]=spring,
  --[10]=fruit,
  --[11]=fruit,
  --[12]=fly_fruit,
  [15]=refill,
  [23]=fall_floor,
  [64]=kevin,
  [68]=bumper,
  [70]=feather,
  [74]=badeline,
  [75]=fall_plat,
  [77]=osc_plat
}


-- [object functions]

function init_object(_type,sx,sy,tile)
  --generate and check berry id
  local id=sx..","..sy..","..lvl_id
  if _type.check_fruit and _g.got_fruit[id] then
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


function destroy_object(_ENV)
  del(objects,_ENV)
end

function kill_player(_ENV)
  _g.sfx_timer=12
  sfx(17)
  _g.deaths+=1
  destroy_object(_ENV)
  --dead_particles={}
  for dir=0,0.875,0.125 do
    add(dead_particles,{
      x=x+4,
      y=y+4,
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
  _g.delay_restart=15
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
  _g.cam_spdx,_g.cam_spdy=0,0

  local diff_level=lvl_id~=id

		--set level index
  lvl_id=id

  --set level globals
  local tbl=split(levels[lvl_id])
  lvl_x,lvl_y,lvl_w,lvl_h=tbl[1]*16,tbl[2]*16,tbl[3]*16,tbl[4]*16
  lvl_pw=lvl_w*8
  lvl_ph=lvl_h*8


  --drawing timer setup
  _g.ui_timer=5

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
      elseif tile>=128 then
        init_object(garbage,tx*8,ty*8,tile-128)
      end

    end
  end
  foreach(objects,function(o)
    (o.type.end_init or time)(o)
  end)

  --<camtrigger>--
  --generate camera triggers
  _g.cam_offx,_g.cam_offy=0,0
  for s in all(camera_offsets[lvl_id]) do
    local tx,ty,tw,th,offx,offy=unpack(split(s))
    local t=init_object(camera_trigger,tx*8,ty*8)
    t.hitbox,t.offx,t.offy=rectangle(0,0,tw*8,th*8),offx,offy
  end
  --</camtrigger>--
end

-- [main update loop]

function _update()
  _g.frames+=1
  if _g.time_ticking then
    _g.seconds+=_g.frames\30
    _g.minutes+=_g.seconds\60
    _g.seconds%=60
  end
  _g.frames%=30

  if _g.music_timer>0 then
    _g.music_timer-=1
    if _g.music_timer<=0 then
      music(10,0,7)
    end
  end

  if _g.sfx_timer>0 then
    _g.sfx_timer-=1
  end

  -- cancel if _g.freeze
  if _g.freeze>0 then
    _g.freeze-=1
    return
  end

  -- restart (soon)
  if _g.delay_restart>0 then
  	_g.cam_spdx,_g.cam_spdy=0,0
    _g.delay_restart-=1
    if _g.delay_restart==0 then
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
  if _g.freeze>0 then
    return
  end

  -- reset all palette values
  pal()

	--set cam draw position
  draw_x=round(_g.cam_x)-64
  draw_y=round(_g.cam_y)-64
  camera(draw_x,draw_y)

  -- draw bg color
  cls()

  -- bg clouds effect
  -- foreach(clouds,function(c)
  --   c.x+=c.spd-_g.cam_spdx
  --   rectfill(c.x+draw_x,c.y+draw_y,c.x+c.w+draw_x,c.y+16-c.w*0.1875+draw_y,1)
  --   if c.x>128 then
  --     c.x=-c.w
  --     c.y=rnd(120)
  --   end
  -- end)

		-- draw bg terrain
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)

  -- draw outlines
  for i=0,15 do pal(i,1) end
  pal=time
  foreach(objects,function(o)
    if o.outline then
      for dx=-1,1 do for dy=-1,1 do if dx==0 or dy==0 then
        camera(draw_x+dx,draw_y+dy) draw_object(o)
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
  foreach(objects,function(o)
    if o.type.layer==0 then
      draw_object(o) --draw below terrain
    else
      add(layers[o.type.layer or 1],o) --add object to layer, default draw below player
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
  foreach(particles,function(p)
    p.x+=p.spd-_g.cam_spdx
    p.y+=sin(p.off)-_g.cam_spdy
    p.y%=128
    p.off+=min(0.05,p.spd/32)
    rectfill(p.x+draw_x,p.y+draw_y,p.x+p.s+draw_x,p.y+p.s+draw_y,p.c)
    if p.x>132 then
      p.x=-4
      p.y=rnd128()
   	elseif p.x<-4 then
     	p.x=128
     	p.y=rnd128()
    end
  end)

  -- dead particles
  foreach(dead_particles,function(p)
    p.x+=p.dx
    p.y+=p.dy
    p.t-=0.2
    if p.t<=0 then
      del(dead_particles,p)
    end
    rectfill(p.x-p.t,p.y-p.t,p.x+p.t,p.y+p.t,14+5*p.t%2)
  end)

  -- draw time
  if _g.ui_timer>=-30 then
  	if _g.ui_timer<0 then
  		draw_time(draw_x+4,draw_y+4)
  	end
  	_g.ui_timer-=1
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
  srand(draw_seed);
  (type.draw or draw_obj_sprite)(_ENV)
end

function draw_obj_sprite(_ENV)
  spr(sprite,x,y,1,1,flip.x,flip.y)
end

function draw_time(x,y)
  rectfill(x,y,x+32,y+6,0)
  ?two_digit_str(_g.minutes\60)..":"..two_digit_str(_g.minutes%60)..":"..two_digit_str(_g.seconds),x+1,y+1,7
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
    rectfill(l,y0,r,y0)
    l+=lt
    r+=rt
  end
end
-- </transition> --
-->8
--[map metadata]

--level table
--"x,y,w,h"
levels={
	"0,0,1,1",
  "1,0,3,1"
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
00000020dddddd20022000000220002d4fff4fff4fff4fff4fff4fffd666666dd666666dd666066d000000000000000070000000000000000005500011111111
002002d22d2d2dd22dd222002dd222dd4444444444444444444444446dddddd56ddd5dd56dd50dd5007700000770070007000007000000000051155015110011
02d202d202dd2dd2dddddd20022ddd2d000450000000000000054000666ddd55666d6d5556500555007770700777000000000000000000000551111011100001
02d22d2002d22d20d222220000022ddd00450000000000000000540066ddd5d5656505d500000055077777700770000000000000000000005511111511100001
02d22d2002d22d20ddd220000022222d0450000000000000000005406ddd5dd56dd5065565000000077777700000700000000000000000005515511111150001
2dd2dd202d202d20d2ddd22002dddddd4500000000000000000000546ddd6d656ddd7d656d500565077777700000077000000000000000000115515015515551
2dd2d2d22d200200dd222dd200222dd250000000000000000000000505ddd65005d5d65005505650070777000007077007000070000000000511115015511111
02dddddd02000000d200022000000220000000000000000000000000000000000000000000000000000000007000000000000000000000000511115511111111
7cc1c1000771777777cc177777771770f31113333ffffbffffbffbfffffbfff30000000000000110331331111133311100000000111111110055550011111111
77cc1c10777c177cc771cc77c771c777fbb113bbfbbbff333bb3bbb33bbbff3f0000000000110011331331111333133100000000111111115511555511111111
777cc1c177ccc1cccccc1ccccc11cc77bbb13bb1f33bbf3331bb1bb333bbbf3f00000000001cc001111113313331333100000030111111311111551511511111
177ccc1c77cccc1ccccc1ccccccc1cc7fb133b13fb3311b3bb1bb113b3311b3f00000000000ccc001331133333113311000000b0111111b11111115011111111
7c1cccc11cccccc11cccc11c1cccc1c7113331bbfbb3311bb311b33bbb3311bf000000000000ccc0133311331111111300000b3011111b311115115011115511
77c1ccc071ccccc111ccc11111cccc17f3bb3bbbf3333bb313313b3b3333bb3f00000000cc000c11113311133331331303000b0013111b111111115511115511
777c11007711ccc101111000011cccc1fbbb3bb1f11133bb311b1bb311133bbf00000000cc100011311133311333331100b0b30011b1b3111555115515111111
177c1000ccc11111001100000011ccccbbb13313fb11b33b313bb133b11b33bf0000000001100000331113311113311100303300113133115500550011111111
0ccc17711111cccc0ccccccc1cccccc13331113fbb1bb3b33bb3bb333331113f00011000000c0000331113330000000000000000111111110055055511551111
01ccc1717ccc1cccccccccccc1cccc71bb311bbffbb1b3bbb3bb1bb3bb311bbf00011c0000cc1000331113310000000000000000111111115511511115550051
111c77107cccc1ccccc1cccccc1ccc711bb31bbbfbb3131bbb3bb1131bb31bbb11001cc000011c00113311110000000000000000111111115511551150000005
1cc1777117cccc1ccccc1cccccc1ccc731b331bfb11b3b31bbb3b33b31b331bf1cc001c11100cc10333331110000000000000000111111115111111110000005
cccc1771717ccc1c1cccc1ccccc71c77bb13331b33111bb33bb3313bbb13331b0ccc00111cc0011033133311000000000000b0001111b1115111111110000005
ccccc1117717cc11c1c7c711ccc77171bbb3bb3f313311bb313b1113bbb3bb3f00cc10000ccc00001111331100000000000b0000111b11115111155110000051
1cccc71017c1cc1c771777cc1ccc77111bb3bbbf31b31111311bb1111bb3bbbf11011000c0cc10001331113300000000030b0030131b11310551151115000551
01cc77710111111171117cc10111111031331bbb1ff3f113f3111f3331ff1fff011000000c011000133311130000000003033030131331310005505511555111
0220cc5555cccc55ddd00dddddd00ddd000000000000000000aaa0000099aa0000999aa0000aaa00000000005777777777777777577777770000000000000000
2125ccc55cccccc50000000000000000000001111110000009aaa900099aaaa0099aaaaa00aaaaa0022222207777777777777777777777770000000000000000
222c5cc55cc11cc5011001100cc00cc0000015dccd51000001aaa1009911aaaa995aaa11009a5a90222222227777cccccccccccc7777cc7c0000000000000000
05cc1cc111111111000000000cc00cc00001cddccddc10000111110091110aa095aa0001009a5a9025555222777ccc7ccccccccc777cc7770000000000000000
cc511522222222220011110000111100001ccc1111ccc100011111009110000095a000000099599028dd8d2277cccccccccccccc77cccc7c0000000000000000
cccc5524444444440111111001d11d10015dc144441cd510011111001100000095a00000009959900666662077c7cccccccccccc77cccc7c0000000000000000
5ccc224444444444001dd10001d11d1001dd14c44c41dd10001110001000000009500000000959000011111077cccc7ccccccccc77ccc7770000000000000000
5551244444444444000dd0000011110001cc14c44c41cc10000010001000000000500000000500000005000577cccccccccccccc77cccc7c0000000000000000
5551244400055505555555555500555001cc14444441cc1000000000000000000000000000000000000000000000000000000000000000000000000000000000
5cc1244400555551551155115155155501dd144cc441dd1000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc12444051551551551155111111115015dc144441cd51000000000000000000000000000000000000000000000000000000000000000000000000000000000
cc112444551111551551155111511115001ccc1111ccc10000000000000000000000000000000000000000000000000000000000000000000000000000000000
cc1124445511111111151115111155550001cddccddc100000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccc12444111111151155111115115555000015dccd51000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5cc12444510001111111151111111550000001111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55512444510001111111111111111150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055505051111111111111151111150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555551555111111111111111155155000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05155155551111111111111111155115000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55111155551111111111111111111115000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55111111051111511111111111111555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111115051111111111111111511550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
51000111011111111111111111111550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
51000111111111111111111111111550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555551111111111111111111150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555515511111111111111111150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555115515115111111511111155000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555511111111111111511111115000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555111111111111155111111155000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555055115511111155111111550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555055515511115111111150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555000555555500055515000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888000008888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000008888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888880008888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbb99999999aaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbb99999999aaaaaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbb999999990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000002020202080808000000000000000404030303030303030303030303040404040303030303030303030303030404040400000000000000000000000000000000000404040000000000000000000000000404040400000000000000000000000004040404000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2f1f7300000000000000000000711f6200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3f73000000000000000000000000712f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
730000000000002c000000000000007100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4d90000090002526272312000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4c00000000003537313012000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000004d91004b4c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000008000004c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000440000810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000080000000912c00000000004a0000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000002c25273c0040414100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000253635273c50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000001243a2b352750000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2122222325363a2a2a3627222222222323000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20292526352a2b2a373929383929393026000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

