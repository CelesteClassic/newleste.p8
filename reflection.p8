pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
--  newleste.p8 - reflection  --
--    by many contributers    --

-- idk if i spelt "contributers" right lmao

_g=_ENV
poke(0x5f2e,1)

-- original game by:
-- maddy thorson + noel berry

-- based on evercore v2.0.2
-- with major project contributions by
-- taco360, meep, gonengazit, and akliant

-- todo: 
--	badeline "sucking player" (who tf picked the name)
--  need tokens to fit mapdata (like mayb 80 ish?)
--	level jam in at least one week, gonna wait until each poll is done.
--  add spinners (oh god, 10 tokens left)

-- [data structures]

function vector(x,y)
  return {x=x,y=y}
end

function v0() return vector(0,0) end

function rectangle(str)
	tbl={}
	tbl.x,tbl.y,tbl.w,tbl.h=unpack(split(str))
	return tbl
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
  max_djump,deaths,frames,seconds,minutes,music_timer,time_ticking,berry_count=1,0,0,0,0,0,true,0
  music(0,0,7)
  load_level(1)
end


-- [effects]

--clouds={}
--for i=0,16 do
--  add(clouds,{
--    x=rnd'128',
--    y=rnd'128',
--    spd=1+rnd'4',
--    w=32+rnd'32'
--  })
--end

--particles={}
--for i=0,24 do
--  add(particles,{
--    x=rnd'128',
--    y=rnd'128',
--    s=flr(rnd'1.25'),
--    spd=0.25+rnd'5',
--    off=rnd(),
--    c=6+rnd'2',
--  })
--end

--wont need clouds, will rely on bg layer maybe
--snow particles not really needed

dead_particles={}

-- [player entity]

player={
  layer=2,
  init=function(_ENV)
    particles,feather,collides,djump,hitbox={},false,true,max_djump,rectangle'1,3,6,5'
    create_hair(_ENV)
    -- <fruitrain> --
    
    --zero vars
    foreach(split"bouncetimer,grace,jbuffer,dash_time,dash_effect_time,dash_target_x,dash_target_y,dash_accel_x,dash_accel_y,spr_off,berry_timer,_berry_count", function(var)
      _ENV[var]=0
    end)
    -- </fruitrain> --
  end,
  update=function(_ENV)

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

    -- bottom death
    if y>lvl_ph and not exit_bottom then
	    kill_player(_ENV)
    end
    
    -- removed spike collision - use spinners instead

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
        tail,particles={},{}
        for i=0,15 do
          add(tail,{x=x+4,y=y+4,size=mid(1,2,9-i)})
        end          
      end
    end
    if not feather and not feather_idle then
      -- cursed token save: use else and goto here
			-- would have used this but couldnt figure it out lol - anti
			
      -- on ground checks
      local on_ground=is_solid(0,1)

          -- <fruitrain> --
      if on_ground then
        berry_timer+=1
      else
        berry_timer,_berry_count=0,0
      end

      for f in all(fruitrain) do
        if f.type==fruit and not f.golden and berry_timer>5 and f then
          -- to be implemented:
          -- save berry
          -- save golden
          
          berry_timer=-5
          _berry_count+=1
          _g.got_fruit[f.fruit_id]=true
          init_object(lifeup, f.x, f.y,_berry_count)
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
            jbuffer,grace,spd.y=0,0,-2
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
    if (exit_right and left()>=lvl_pw or
        exit_top and y<-4 or
        exit_left and right()<0 or
        exit_bottom and top()>=lvl_ph) and levels[lvl_id+1] then
      next_level()
    end

      -- was on the ground
      was_on_ground=on_ground
    end
  end,

  draw=function(_ENV)

    --<feather> --

    -- draw feather particles (if not in feather state draw remaining ones)
    foreach(particles, function(p)
			if p.big then spr(89,p.x-1,p.y-1,1,1,p.flip.x,p.flip.y)
      else pset(p.x+4, p.y+4,10) end

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
      circfill(x+4, y+4, 3, spawn_timer%4<2 and 7 or 10)
    --</feather> --
    else
      -- draw player hair and sprite
    	pal(8,djump==1 and 8 or 12)
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
  update=function(_ENV)
  	delta=delta or 0
    delta*=0.75
    --can save tokens by setting hit as _ENV
    --but i'm not desperate enough yet
    
    --jokes on you <insert_name> i am.
    local j,dir=_ENV,dir
    local _ENV=player_here() and player_here() or j
    if _ENV!=j then
      move(0,j.y-y-4,1)
      spd.x*=0.2
      spd.y=-3
      dash_time,dash_effect_time,j.delta,djump=0,0,4,max_djump
    end
  end,
  draw=function(_ENV)
    local delta=flr(delta)
    sspr(72,0,8,8-delta,x,y+delta)
  end
}


refill={
  init=function(_ENV)
    offset,timer,hitbox=rnd(),0,rectangle'-1,-1,10,10'
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

kevin={
  init=function(_ENV)
    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==65 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==80 do
      hitbox.h+=8
    end
    solid_obj,collides,retrace_list,hit_timer,retrace_timer,shake=true,true
    ,{},
   0,
    0,
    0
  end,
  update=function(_ENV)
    shake=max(0,shake-1)
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
            spd=v0()
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
        spd=v0()
        rem=v0()
      else
        spd=vector(appr(spd.x,sign(last.x-x),0.2),appr(spd.y,sign(last.y-y),0.2))
      end
    end
  end,
  draw=function(_ENV)
    local x,y=x,y
    if shake>0 then
      x+=rnd'2'-1
      y+=rnd'2'-1
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

}


bumper={
  init=function(_ENV)
    hitbox=rectangle'1,1,14,14'
    hittimer=0
    startx,starty=x,y --not tables to save tokens
    meep=0
    outline=false
  	inc=rnd'1'<.5 and -0.02 or 0.02
  end,
  update=function(_ENV)
  	x=startx+cos(meep*1.5)*2
  	y=starty+sin(meep)*1.5
    if hittimer>0 then
			hittimer-=1
      if hittimer==0 then
        init_smoke(4,4)
      end
    else
      meep+=inc
      local hit=player_here()
      if hit then
        hit.init_smoke()
        local dx,dy=x+8-(hit.x+4),y+8-(hit.y+4)
        local angle=atan2(dx,dy)
        hit.spd = abs(dx) > abs(dy) and vector(sign(dx)*-2.8,-2) or --  -3.5*(cos(0.9),sin(0.9))
                 vector(-3*cos(angle),-3*sin(angle))
        hit.dash_time,hit.djump=-1,max_djump
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
    starty,startx=y,x
    timer=0
    bubble=sprite==88
    bubbled=bubble
  end,
  update=function(_ENV)
    if timer>0 then
      timer-=1
      if timer==0 then
        init_smoke()
        bubbled=bubble
      end
    else
      sprtimer+=0.2
      offset+=0.01
      y=appr(y,starty+0.5+2*sin(offset),1)
      x=appr(x,startx,1)

      if(bubbled) hitbox=rectangle'-4,-4,16,16'

      local hit=player_here()

      -- no bubble
      ::rcollect::
      if not bubbled and hit then
        init_smoke()
        timer=60
        if hit.feather_state then
          hit.lifetime=60
        else
          hit.spawn_timer,hit.feather_idle,hit.dash_time,hit.dash_effect_time=10,true,-10,0
          hit.spd=vector(mid(hit.spd.x,-1.5,1.5),mid(hit.spd.y,-1.5,1.5))
        end
          
        particles={}
        for i=0,10 do
          local particle = {x=x+rnd'8'-4, y=y+rnd'8'-4, life=10+flr(rnd(5)), big=true}
          particle.xspd = -hit.spd.x/2-(x-particle.x)/4
          particle.yspd = -hit.spd.y/2-(y-particle.y)/4
          particle.flip = vector(rnd'1'>0.5,rnd'1'>0.5)
          add(hit.particles, particle)
        end
      elseif bubbled and hit then
        if hit.dash_time>0 then
          bubbled=false
--          sfx(0,3,5,4)
          goto rcollect
        else
          local dir=atan2((hit.y+4)-(y+4),(hit.x+4)-(x+4))+0.01
          local ox,oy=sin(dir)*2,cos(dir)*2
          hit.spd=vector(ox,oy)
          x=startx-ox*3
          y=starty-oy*3
          hit.djump=max_djump
          if (hit.movedir) hit.movedir+=0.5
        end
      end

      hitbox=rectangle'0,0,8,8'

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
--      stop(sprite)
      hit.hitbox.h+=8
      destroy_object(_ENV)
      return
    end

    --handle both garbage loading orders
    hit=check(osc_plat,-1,0)
    if hit then
      hit.target_id=sprite
      foreach(objects,function(o)
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
    nodes,next_node,ffreeze,outline,off,target_x,target_y,rx,ry,attack,attack_timer={},1,
    0,
    false,
    0,
    x,y,
    x,y,
    boss_phases[1],
    0
  end,
  update=function(_ENV)
    off+=0.005
    attack_timer+=1
    x,y=round(rx+4*sin(2*off)),round(ry+4*sin(off))
    if ffreeze>0 then
      ffreeze-=1
    else
      if round(rx)!=target_x or round(ry)!=target_y then
        rx+=0.2*(target_x-rx)
        ry+=0.2*(target_y-ry)
      else
        local hit=player_here()
        if hit then
          attack_timer=1
          destroy_object(laser or {})
          laser=nil
          if next_node>#nodes then
            target_x=lvl_pw+50
            node=-1
            ffreeze=10
          else
            target_x,target_y=unpack(nodes[next_node])
            ffreeze=10
          end
          next_node+=1
          attack=boss_phases[next_node]

          hit.dash_time=4
          hit.djump=max_djump
          hit.spd=vector(-2,-1)
          hit.dash_accel_x,hit.dash_accel_y=0,0 --stuff dash without stuffing dash_time
          off=0


          --activate falling blocks:
          local off=20
          foreach(objects, function(o)
            if o.type==fall_plat or (o.type==osc_plat and next_node-1==o.badestate) then
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
      if o.type == player and ffreeze==0 then
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
      pal(i,ffreeze==0 and i or _g.frames%2==0 and 14 or 7)
    end
    --draw_x,draw_y=x+4*sin(2*off)+0.5,y+4*sin(off)+0.5
    -- badehair(_ENV,1,-0.1)
    -- badehair(_ENV,1,-0.4)
    -- badehair(_ENV,2,0)
    -- badehair(_ENV,2,0.5)
    -- badehair(_ENV,1,0.125)
    -- badehair(_ENV,1,0.375)
    for p in all(split("1,-0.1 1,-0.4 2,0 2,0.5 1,0.125 1,0.375"," ")) do
--	    badehair(_ENV,unpack(split(p)))
			local c,a=unpack(split(p))
 			for h=0,4 do
  			circfill(x+(flip.x and 2 or 6)+1.6*h*cos(a),y+3+1.6*h*sin(a)+(ffreeze>0 and 0 or sin((_g.frames+3*h+4*a)/15)),mid(1,2,3-h),c)
 			end    
    end
    draw_obj_sprite(_ENV)
    pal()
--    ?attack_timer,x,y,8
--    ?next_node,x,y+6
--    ?boss_phases[next_node],x,y+13

  end
}

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
    rectangle'-2,-2,5,5',0,     y,  {}
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
        p.c=split"7,8,14"[1+flr(rnd'3')]
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
    outline=false
    timer=0
    particles={}
  end,
  update=function(_ENV)
    timer+=1
    local p=find_player()
    if p then
    if timer<30 then
      playerx,playery=appr(playerx or badeline.x,p.x,10),appr(playery or badeline.y,p.y,10)
    elseif timer==45 then
      if line_dist(p.x+4,p.y+6,get_laser_coords(_ENV))<6 then
        kill_player(p)
      end
    elseif timer>=48 and #particles==0 then
      destroy_object(_ENV)
      badeline.laser=nil
    end
    
    foreach(particles, function(p)
      p.x+=p.dx
      p.y+=p.dy
      p.d-=1
      if p.d<0 then
        del(particles,p)
      end
    end)
    else
    	destroy_object(_ENV)
    end
  end,
  draw=function(_ENV)
    local timer=timer
    if timer>42 and timer<45 then return end
    if timer<48 then
      local x1,y1,x2,y2=get_laser_coords(_ENV)
      local dx12,dy12=x1-x2,y1-y2
      local x3,y3=x1-128*dx12,y1-128*dy12

      --draw ball electricity lines
      for i=0,rnd'4' do
        local a = rnd()
        line(x1,y1,x1+cos(a)*rnd'7',y1+sin(a)*rnd'7',7)
      end

      --x,y,magnitude to player,scale with laser,color flashing white
      local _x,_y,d,s,c=x1,y1,sqrt(dx12^2+dy12^2)*0.1,timer>45 and 2 or 0.5,timer>=30 and timer%4<2 and 7 or 8

      --draw laser electricity lines
      line(x1,y1,x1,y1,8) --set line cursor pos
      for i=0,10 do
        _x-=dx12/d
        _y-=dy12/d
        line(_x+(rnd'10'-5)*s,_y+(rnd'10'-5)*s,maybe() and 0 or timer>45 and c or 2)
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
    x+=rnd'2'-1
    y+=rnd'2'-1
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
  palt(0,false)
  for i=x+8,r-8,8 do
    for j=y+8,d-8,8 do
      spr((i+j-x-y)%16==0 and 41 or 56,i,j)
    end
  end
  palt()
  pal()
end


fall_plat={
  init=function(_ENV)
    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==76 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==76 do
      hitbox.h+=8
    end
    collides,solid_obj,timer,shake,state,new=true,true,0,0,0,false
  end,
  update=function(_ENV)
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
    elseif state>=1 then
      if spd.y==0 then
      	if (not is_solid(0,1)) new=false
      	if not new then
        	for i=0,hitbox.w-1,8 do
          	init_smoke(i,hitbox.h-2)
        	end
          new,shake=true,3
        end
        timer=6
      end
      spd.y=appr(spd.y,4,0.4)
    end  
  end,
  draw=plat_draw
}

osc_plat={
  init=fall_plat.init, -- fineish now cause everything uses _ENV
  end_init=function(_ENV)
    hitbox.w+=8
    if not badestate then
      timer=1
    end


    local dx,dy=targetx-x,targety-y
    local d=sqrt(dx^2+dy^2)

    t,shake,palswap,
    startx,starty,
    dirx,diry=
    0, 0, not badestate,
    x,y,
    dx/d,dy/d

--    start=true
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

--<spinners>--
spinner_controller={
  spinners={},
  connectors={},
  layer=0,
  init=function()
    spinner_controller.spinners,spinner_controller.connectors={},{}
  end,
  end_init=function()
    for i,s1 in ipairs(spinner_controller.spinners) do
      for j=1,i-1 do
        local s2=spinner_controller.spinners[j]
        local dx,dy=abs(s1.x-s2.x),abs(s1.y-s2.y)
        if dx<=16 and dy<=16 and dx+dy<32 then
          add(spinner_controller.connectors,vector((s1.x+s2.x)/2+4,(s1.y+s2.y)/2+4))
        end
      end
    end
  end,
  update=function()
  	local p=find_player()
  	if p and p.type==player then
  	for s in all(spinner_controller.spinners) do
      if s.objcollide(p,0,0) then
        kill_player(find_player())
        break
      end
		end
		end
  end,
  draw=function()
    foreach(spinner_controller.connectors,function(c)
      spr(31,c.x,c.y)
    end)
    foreach(spinner_controller.spinners,function(s)
      spr(46,s.x,s.y,2,2)
    end)
    -- for s in all(spinner_controller.spinners) do
      -- rect(s.left(),s.top(),s.right(),s.bottom(),10)
    -- end
  end
}
spinner={
  init=function(_ENV)
    if sprite%2==1 then
      x-=8
    end
    if sprite>=63 then
      y-=8
    end
    hitbox=rectangle'2,2,12,12'
    add(spinner_controller.spinners,_ENV)
    destroy_object(_ENV)
  end
}

--</spinners>--

-- [tile dict]
tiles={}
foreach(split([[
1,player_spawn
8,side_spring
9,spring
10,fruit
11,fruit
12,fly_fruit
15,refill
23,fall_floor
64,kevin
68,bumper
70,feather
88,feather
74,badeline
75,fall_plat
77,osc_plat
46,spinner
47,spinner
62,spinner
63,spinner
]],'\n'),function(t)
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
  _type, true, tile, vector(), sx, sy, rectangle'0,0,8,8', vector(0,0), vector(0,0), id, true, rnd()

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
  foreach(fruitrain,function(f)
    if (f.golden) _g.full_restart=true
  end)
  _g.fruitrain={}
  --- </fruitrain> ---
  _g.delay_restart=15
  -- <transition>
  _g.tstate=0
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

  --set level globals
  local tbl=split(levels[lvl_id])
  lvl_x,lvl_y,lvl_w,lvl_h=tbl[1]*16,tbl[2]*16,tbl[3]*16,tbl[4]*16
  lvl_pw=lvl_w*8
  lvl_ph=lvl_h*8
  boss_phases=split(tbl[6],"/")

  local exits=tonum(tbl[5]) or 0b0001

  -- exit_top,exit_right,exit_bottom,exit_left=exits&1!=0,exits&2!=0,exits&4!=0, exits&8!=0
  for i,v in inext,split"exit_top,exit_right,exit_bottom,exit_left" do
    _ENV[v]=exits&(0.5<<i)~=0
  end
  
  --drawing timer setup
  ui_timer=5

  --reload map
  if diff_level then
    reload()
    --chcek for mapdata strings
--    if mapdata[lvl_id] then
--      replace_mapdata(lvl_x,lvl_y,lvl_w,lvl_h,mapdata[lvl_id])
--    end
  end
  --<spinners>--
  init_object(spinner_controller,0,0)
  --</spinners>--
  -- entities
  for tx=0,lvl_w-1 do
    for ty=0,lvl_h-1 do
      local tile=tile_at(tx,ty)
      if tiles[tile] then
        init_object(tiles[tile],tx*8,ty*8,tile)
      end
      if tile>=224 then
        init_object(garbage,tx*8,ty*8,tile-224)
      end
    end
  end
  
  foreach(objects,function(o)
    (o.type.end_init or time)(o)
  end)

  --<camtrigger>--
  --generate camera triggers
  cam_offx,cam_offy=0,0
  for s in all(camera_offsets[lvl_id]) do
    local tx,ty,tw,th,offx,offy=unpack(split(s))
    local t=init_object(camera_trigger,tx*8,ty*8)
    t.hitbox,t.offx,t.offy=rectangle('0,0,'..tw*8 ..','..th*8),offx,offy
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
  
  -- draw bg color
  cls(9)
  
  
	--set cam draw position
  draw_x=round(cam_x)-64
  draw_y=round(cam_y)-64
  camera(draw_x,draw_y)


  
  
  -- bg sky

  -- bg clouds effect
  -- foreach(clouds,function(c)
  --   c.x+=c.spd-.cam_spdx
  --   rectfill(c.x+draw_x,c.y+draw_y,c.x+c.w+draw_x,c.y+16-c.w*0.1875+draw_y,1)
  --   if c.x>128 then
  --     c.x=-c.w
  --     c.y=rnd(120)
  --   end
  -- end)

	palt(0,false)
	palt(2,true)

	-- draw bg terrain
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)



	palt()
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
	palt(0,false)
	palt(2,true)
  -- draw terrain
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
	palt()
  -- draw objects
  foreach(layers,function(l)
    foreach(l,function(_ENV)
      draw_object(_ENV)
      if bubble and bubbled then
        oval(left()-4,top()-4,right()+4,bottom()+4,7)
      end
    end)
  end)
  
	---[[ draw grass

	for i=1,lvl_w do
		for j=1,lvl_h do
			if grass[tile_at(i,j)] and not grass[tile_at(i,j-1)] and not not_grass[tile_at(i,j-1)] then
				spr(60,i*8,(j-1)*8)
			end
		end
	end
	
	--]]
	
  -- draw platforms
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,8)
  -- particles
--  foreach(particles,function(p)
--    p.x+=p.spd-cam_spdx
--    p.y+=sin(p.off)-cam_spdy
--    p.y%=128
--    p.off+=min(0.05,p.spd/32)
--    rectfill(p.x+draw_x,p.y+draw_y,p.x+p.s+draw_x,p.y+p.s+draw_y,p.c)
--    if p.x>132 then
--      p.x=-4
--      p.y=rnd'128'
--   	elseif p.x<-4 then
--     	p.x=128
--     	p.y=rnd'128'
--    end
--  end)

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
  if ui_timer>=-30 then
  	if ui_timer<0 then
--  		draw_time(draw_x+4,draw_y+4)
  	end
  	ui_timer-=1
  end

  -- <transition>
  camera()
  color(0)
  if tstate==0 then
  	tlo+=14
    thi=tlo-320
    po1tri(0,tlo,128,tlo,64,80+tlo)
    rectfill(0,thi,128,tlo)
    po1tri(0,thi-64,0,thi,64,thi)
    po1tri(128,thi-64,128,thi,64,thi)
    if (tlo>474) tstate=-1 tlo=-64
  end
  -- </transition>
  
  -- <pallete>
  
  	p'9,137'
  	p'14,131'
  	p'13,139'
  
  -- </pallete>
end

function p(s)
s=split(s)
pal(s[1],s[2],1)
end

function draw_object(_ENV)
  srand(draw_seed);
  (type.draw or draw_obj_sprite)(_ENV)
end

function draw_obj_sprite(_ENV)
  spr(sprite,x,y,1,1,flip.x,flip.y)
end

--function draw_time(x,y)
--  rectfill(x,y,x+32,y+6,0)
--  ?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds),x+1,y+1,7
--end


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
tstate,tlo=-1,-64

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
--@conf
--[[
autotiles={{33, 35, 34, 32, 33, 35, 34, 32, 49, 51, 50, 48, 32, 48, 40, 41, [0] = 34, [28] = 57, [40] = 56}, {37, 39, 38, 36, 37, 39, 38, 36, 53, 55, 54, 52, 36, 52, 59, 42, [0] = 38, [28] = 58, [40] = 43}, {118, 102, 112, 96, 81, 83, 82, 96, 113, 115, 114, 112, 97, 99, 98, 37, 38, 39, 36, 87, 144, 145, 90, 91, 92, 93, 78, 53, 54, 55, 52, 103, 104, 105, 106, 107, 108, 109, 128, 32, 33, 34, 35, 119, 120, 121, 122, 123, 94, 95, 129, 48, 49, 50, 51, 116, 117, 100, 101, 146, 110, 111, 130, [0] = 98}}
composite_shapes={}
param_names={"phase/phase/phase/..."}
]]
--@begin

--level table
--"x,y,w,h,exit_dirs,phase/phase/phase/..."
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
--phase 1 (ball) or 2 (laser)

levels={
  "0,0,2,1,0b0010,0",
  "2,0,2,1,0b0010,0/1/2"
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

--tiles to draw grass on
grass={}
foreach(split'36,37,38,39,52,53,54,55',function(t)
grass[t]=true
end)

not_grass={}
foreach(split'32,33,34,35,49,49,50,51,40,41,42,43,56,57,58,59',function(t)
not_grass[t]=true
end)


--replace mapdata with hex
--function replace_mapdata(x,y,w,h,data)
--  for y_=0,h*2-1,2 do
--    local offset=y*2+y_<64 and 8192 or 0
--    for x_=1,w*2,2 do
--      local i=x_+y_*w
--      poke(offset+x+y*128+y_*64+x_/2,"0x"..sub(data,i,i+1))
--    end
--  end
--end

-- ill figure something out once i actually have all the levels
-- thinking ill just convert them somewhere else. could use that lua script i wrote like a million years ago
--  -anti

--copy mapdata string to clipboard
--function get_mapdata(x,y,w,h)
--  local reserve=""
--  for y_=0,h*2-1,2 do
--    local offset=y*2+y_<64 and 8192 or 0
--    for x_=1,w*2,2 do
--      reserve=reserve..num2hex(peek(offset+x+y*128+y_*64+x_/2))
--    end
--  end
--  printh(reserve,"@clip")
--end
--
----convert mapdata to memory data
--function num2hex(v)
--  return sub(tostr(v,true),5,6)
--end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000000000000000000300b0b00a0aa0a000000000000000000000000000066000
00000000088888800888888088888888088888800888880000000000088888800000000000000000003b33000aa88aa0000000000000000000000000006bb600
000000008888888888888888888ffff888888888888888800888888088f1ff180000000000000000028888200299992000000000000000000000000006bbb360
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff8000000000d9999d00898888009a999900000000000000000000000006bbb3bb6
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff800000000005005000888898009999a9000000000000000000000000063b33bb6
0000000008fffff008fffff00033330008fffff00fffff8088fffff808333380000000000005500008898880099a999000000000000000000000000006333360
00000000003333000033330006000060063333000033336008f1ff10003333000000000000500500028888200299992000000000000000000000000000633600
00000000006006000060006000000000000006000000600006633360006006000000000000055000002882000029920000000000000000000000000000066000
000000000000000000000000000000004fff4fff4fff4fff4fff4fffd666666dd666666dd666066d0000000000000000700000000000000000000000022f22f0
000000000000000000000000000000004444444444444444444444446dddddd56ddd5dd56dd50dd50077000007700700070000070000000000000000f882282f
00000000000000000000000000000000222452222222222222254222666ddd55666d6d5556500555007770700777000000000000000000000000000028882f82
0000000000000000000000000000000022452222222222222222542266ddd5d5656505d5000000550777777007700000000000000000000000000000f2822222
000000000000000000000000000000002452222222222222222225426ddd5dd56dd506556500000007777770000070000000000000000000000000002222222f
000000000000000000000000000000004522222222222222222222546ddd6d656ddd7d656d5005650777777000000770000000000000000000000000f2222288
0000000000000000000000000000000052222222222222222222222505ddd65005d5d65005505650070777000007077007000070000000000000000082222828
00000000000000000000000000000000222222222222222222222222000000000000000000000000000000007000000000000000000000000000000008f2f880
7cc1c1002771777777cc177777771772f31113333ffffbffffbffbfffffbfff30000000000000110331331111133311122222222dddddddd0000000700700000
77cc1c10777c177cc771cc77c771c777fbb113bbfbbbff333bb3bbb33bbbff3f0000000000110011331331111333133122222222dddddddd0000000002000070
777cc1c177ccc1cccccc1ccccc11cc77bbb13bb1f33bbf3331bb1bb333bbbf3f00000000001cc001111113313331333122222232ddddddbd7000200870200700
177ccc1c77cccc1ccccc1ccccccc1cc7fb133b13fb3311b3bb1bb113b3311b3f00000000000ccc001331133333113311222222b2ddddddbd0700072222080200
7c1cccc11cccccc11cccc11c1cccc1c7113331bbfbb3311bb311b33bbb3311bf000000000000ccc0133311331111111322222b32dddddbbd0220800202802000
77c1ccc071ccccc111ccc11111cccc17f3bb3bbbf3333bb313313b3b3333bb3f00000000cc000c11113311133331331323222b22dbdddbdd0082220088020700
777c11007711ccc101111000011cccc1fbbb3bb1f11133bb311b1bb311133bbf00000000cc100011311133311333331122b2b322ddbdbbdd0008888008008000
177c1000ccc11111001100000011ccccbbb13313fb11b33b313bb133b11b33bf0000000001100000331113311113311122323322ddbdbbdd0022200888820220
0ccc17711111cccc0ccccccc1cccccc13331113fbb1bb3b33bb3bb333331113f00011000000c0000331113331111111100000000dddddddd7708228088088770
01ccc1717ccc1cccccccccccc1cccc71bb311bbffbb1b3bbb3bb1bb3bb311bbf00011c0000cc1000331113311111111100000000dddddddd0200280200200027
111c77107cccc1ccccc1cccccc1ccc711bb31bbbfbb3131bbb3bb1131bb31bbb11001cc000011c00113311111111111100000000dddddddd0000027808728000
1cc1777117cccc1ccccc1cccccc1ccc731b331bfb11b3b31bbb3b33b31b331bf1cc001c11100cc103333311111111111000000b0ddddddbd0000278020877000
cccc1771717ccc1c1cccc1ccccc71c77bb13331b33111bb33bb3313bbb13331b0ccc00111cc001103313331111111111b00b00b0bddbddbd0020002028220200
ccccc1117717cc11c1c7c711ccc77171bbb3bb3f313311bb313b1113bbb3bb3f00cc10000ccc00001111331111111111b0b003b0bdbdd3bd0072000200002700
1cccc71017c1cc1c771777cc1ccc77111bb3bbbf31b31111311bb1111bb3bbbf11011000c0cc10001331113311111111b3b03b30b3bd3b3d0700000070000070
01cc77712111111171117cc10111111231331bbb1ff3f113f3111f3331ff1fff011000000c0110001333111311111111b3bb3b3bb3bb3b3b0000000020000000
0992cc5445cccc541110011111000011000000000000000000aaa0000099aa0000999aa0000aaa00000000005777777777777777477777773333333300000000
9245cc2442cccc240000000001100110000001111110000009aaa900099aaaa0099aaaaa00aaaaa0022222207882787772287777722e7277333eeee300000000
9426cc2222166122011001100c0000c0000015dccd51000001aaa1009911aaaa995aaa11009a5a90222222227872c8ccc2c8cccc727e222c33eeede300000000
256566111111111100e99e000cc99cc00001cddccddc10000111110091110aa095aa0001009a5a902dddd2227222c8ccc888cccc7eeec2c23eeddde300000000
ccc6c12222222222099ee99009eeee90001ccc1111ccc100011111009110000095a00000009959902855852277ccc8cccccccccc77ccc2cceddbd3e300000000
ccc61124444444440e1111e00e4114e0015dc144441cd510011111001100000095a00000009959900666662077c8c8c8cccccccc77c2c2c2ebd333e300000000
522122444444444400e99e000e1111e001dd14c44c41dd10001110001000000009500000000959000011111077cc888ccccccccc77cc222ce333eee300000000
44212444444444440009900000eeee0001cc14c22c41cc10000010001000000000500000000500000005000577ccc8cccccccccc77ccc2cceeeee33300000000
44212444222bbb2dbbbddbbdbb22bbb20ecce444444ecce0222db222333e3333007777000aa0000033333333e333333333333333333333333333333e33333333
5221244422bbbbbebbeebbbbbbbeebbb0e33e24cc42e33e022ddbbb233ed33330700aa70aa000000333e333ed333ee33333eeeeeee3333e3333333ed3333b333
cc1124442ebbdeedebbeebbebbbbdebd0e53ce2442ec35e02bb3bbb23ed333e3700aaa070000000033ed33edeeeeee3333eeedddee333ed333333ed333bbb333
cc612444ddedeedddededdeebeeedded00eccceeeeccce00bbb33ddd3d333ed370959007000000003ed33eeee3ddee3e3ededdddee33ed333333ed3333beb333
cc612444ebbdde333dedd3dd3dedebbd000ec33cc33ce000bbdd33dd3333edd37059000700000000ed33ee3dddd3eeededeeddddee33d3e333b3d3333bbeb33e
cc112444bbbde33333d333d3333ebbbd0000e53cc35e00002dd333bb333edd337050000700000000d33eedddddb3eed3deedddddeee33ed333bb333e3bbeb3ed
52212444bbbbe33333333333333eebb200000eeeeee00000bb333dbb333ed333070e007000000000333e3ddddb3eee333eddddbebee3ed333beb33edbbebbed3
44212444dbbbd333333333333333ebd20000000000000000bbb3dbbb333333330077770000000000333edddd333eee333edddbe33eeee3333bbeb3dbbbeb3d3b
bbbe3bbb2edd3d333333333333debbb2333333e3333333e322bbdd2233e33ed333e33eeeeee333e333eeddb3333eee333eddde333d3de33333beb3ebbeeb3bbb
bbe333bbebbeed333333333333d3ebbd33e33ed3333e3ed3bbb3dbbd3ed3ed333edeeedd33eeeed33eeedb33333eee333eedeb33d3dee33333bb88e88eebbbeb
bb333ee2bbbddd3333333333333debbb3ed3ed3333eded33bbbddbbbed3ed33eeeeed3bdd333ee33eded333333eeee3333eeb333deede33333eb82a28eebbebb
ee33eebbbbed3d3333333333333edebbed33d3333ed3d33dd3333bb2d33d33edeedddd3bd3333ee3d3eb3333ee3ee33e33ee333de3dee33e3ed82a9bbebbebb3
eee33bbb2eebd33333333333333ddebbd33e3333dd3333e33b3d3dd233e33ed3edddddd3d33ed3ee33eeeeeeeddee3ed33ee33dedeee33edbb388b28bebbebb3
2bbb3bb22bbbe33333333333333e3de233ed3dbebdd33ed3bbb3bbdd3ed3ed33eddddddd33e333de33ee333eeeeeeed33e3eedeeee333ed33bebbb88bebebb33
2bbbee22bbbbe33333333333333debb23ed33dbbebb3ed33bbdbbbbd3d33d333eeddddd333e3d3de3edeed33eeeeed33ed33eee33333ed3333beebeeebebb333
222be222dbbed3333333333333debbb23d33dbeeebe3d333dd22bd22333333333eddde3d3e33eeee3d33eed33eeee333d33333333333d3333333beeeeebb3333
333333332dbe333333333333333dbbbd33e3bbedddbbe33322db22dd333333333eede3ed3e3eeee333333ed3e3eee33e00000000000000000000000000000000
333333332bbee33333333333333ebbbb3ed3ebedeeebd333dbbbbdbb33edd33333ee3ddde333de333333eeee3deee3ed00000000000000000000000000000000
33333333dbbbe33333e333ed333edbbb3d33bbebbbbd33e3ddbb3bbb3eddd33e333ebddde3eeee33333ed3e3deeeeed300000000000000000000000000000000
33333333dbbeded33ddededd33eddbbe33e3ddbbbbed3ed32dd3d3b3eddd33ed333eeddde3eee33333ed33eedeeeed3300000000000000000000000000000000
33333333deddeeebdeedded3ddeededd3ed333de3ed3ed332bb3333dedd33ed333e3ebdde3ee33333ed333eeeeeeed3300000000000000000000000000000000
33333333dbedbbbbdbbbedbedeedbbe2ed333edded3ed3e3bbbddbbb3333ed333ed3eebde33e33e3ed333ed3eeeed33300000000000000000000000000000000
33333333bbbeebbbebbbbebbebbbbb22d333ed33d33d3ed3dbbd3bbb3333d333ed333eebe3ee3ed3d333ed333eed333300000000000000000000000000000000
333333332bbb22bbbbbb2bbbd2bbb222333333333333ed3322ddbb2233333333d33333eeeee3ed333333d33333d3333300000000000000000000000000000000
333ed333333333e33333333e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33ed333311111ed333ee88ed00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3ed33331111111888ee8888300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ed333e3113311138882288e300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d333ed3133e3111129992eee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
333ed3333ed3ee118898883300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33311188ed33ee188882888300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
313318888133ee118813333e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11882992111eee1111311eed00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
18888998811ee1eee111eeee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
18829988881111eeee1eee3300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
111888288111111eeeee333e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e11888111e111111eeee33ed00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ee11811eeeee1111eee33ed300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
eee11111eee111eeeee3ed3300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3eeee11111111eeeee33d33300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00888800000008000088880000888800008008000088880000888800008888000088880000888800008888000088880000888800008880000088880000888800
00800800000008000000080000000800008008000080000000800000000008000080080000800800008008000080080000800000008008000080000000800000
00800800000008000000080000000800008008000080000000800000000008000080080000800800008008000080080000800000008008000080000000800000
00800800000008000088880000888800008888000088880000888800000008000088880000888800008888000088800000800000008008000088880000888800
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00888800000008000088880000888800000008000088880000888800000008000088880000000800008008000088880000888800008880000088880000800000
00cccc0000000c0000cccc0000cccc0000c00c0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000ccc00000cccc0000cccc00
00c00c0000000c0000000c0000000c0000c00c0000c0000000c0000000000c0000c00c0000c00c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000000c0000000c0000c00c0000c0000000c0000000000c0000c00c0000c00c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000cccc0000cccc0000cccc0000cccc0000cccc0000000c0000cccc0000cccc0000cccc0000ccc00000c0000000c00c0000cccc0000cccc00
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00cccc0000000c0000cccc0000cccc0000000c0000cccc0000cccc0000000c0000cccc0000000c0000c00c0000cccc0000cccc0000ccc00000cccc0000c00000
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
0000000000000000000000000000000000000000080808000000000000000000030303030303030303030303040400000303030303030303030303030404000000000000000000000000000000000400000404040000040400000404040404040404040404040404040404040404040404040404040404040404040400000000
0404040000000000000000000000000004040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2a2b2a3a2b3637775a5b77202938282828382933243a2a3a2a3a34626762576228282829393232242b3a2a2b34202928282933242a3a3b3b3b2b3a2a3420382900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b3a2b3a353767676a6b57313229393829393325352a3a3a3a3537575c5d626728293839332526352a3636363731392939332536353a2a2b3a2a35363720293800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
36363636375762627a7b677762313239383325353a2a3636363772656c6d62572939322526352a3a2b344d4c4cf03132330035363636362a353637212239383900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
372122236869625764727272655767313325363635363764730000717265624e393025352b2a3a3636374c000000000000004d4cf1353536372122382938323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22293930787964727300000071656457627735363762576300000000007172653233242a3a3636374b4ce0000000000000004c0000f200716567313232335c5d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
393829336472730000000000007165625c5d62776264727300000000000000712626353636374e634c000000000000000000e100000000007172655762676c6d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
293933727300000000000000000071656c6d62577763000000000000000000002a2b36376277647300000000000000e00000000000000000000071657780818200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
393300000000000000000000000000716562676264732e00002f0000000000003636375a5b5763000000000000000000000000000000000000e100616290919200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3363000000000000002f0000000000006157624e632e000000004400000000516762776a6b6263004a000000002f00000000000000000000000051756725262600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
576300000000002e00000000000000006177676263002f002e000000005152757265577a7b676300000000002e003e002f00f100004d4c4cf251755725362b2a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
67745358000009002f002e0000000000618081827453002e212223525275776700717265577774530000f02e00212300002f000000e1000000252626362a3a2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
62576300002c25273c3e4041414141416190919257742122393829222367626200000071655e5f745225270000203822232e002e0025262626363a2a2b2b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5e5f630000253635272e502f002f003e252626274e772029292839293077626700000100616e6f7767243626273132293922232526362b2a2b3a3a2b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6e6f745301243a2b352750002f002e00242b2a35276720392828283930676262002122222222222325362a2b3626272029293024363a2a3b3b3b3b3b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2122222325363a2a2a36272222222222242a3a2a2427203828282838212362772229383929382933243a2b2a3a3634203938303536363a2b3b3b3b3b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20292526352a2b2a3739293839293938243a2a2b2b34203928282839293067622928282828383025362a3b3b2b2a3420293929222324363a2b3b3b3b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
01020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
01030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
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
010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

