pico-8 cartridge // http://www.pico-8.com
version 32
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
          -- <zip_mover>
            local hit=check(zip_mover,0,1)
            if hit and hit.state==1 then 
              if hit.delay>=12 then 
                spd.x=hit.dir.x*4
                spd.y=min(hit.dir.y*3,-2)
              else 
                spd.x=(hit.spd.x-sign(hit.spd.x))*0.75
                spd.y=mid(hit.spd.y-sign(hit.spd.y),-2,-3)
              end 
              
              -- local d=sqrt(((hit.x-hit.target.x)^2+(hit.y-hit.target.y)^2)/36) -- frames till reaching target (i think)
              -- if hit.delay>=12 or d<=3 and d!=0 then 
              --   spd=vector(hit.dir.x*4,min(3*hit.dir.y,-2))
              -- elseif hit.delay==0 and d<=7 then 
              --   spd=vector(hit.spd.x-1,min(3*hit.dir.y,-2))
              -- else
              --   spd.y=-2
              --   spd.x=hit.spd.x-1
              -- end 

            else 
              spd.y=-2
            end 
          -- </zip_mover>
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
--<zip_mover> --
function spr_r(s,x,y,a)
  x+=1
  y+=1 --idk why this is 
  local sx,sy=s%16*8,s\16*8 --bad tokens but lazy
  local ca,sa=cos(a),sin(a)
  local dx,dy=ca,sa
  local x0,y0=3.5*(sa-ca)+4,-3.5*(ca+sa)+4
  x0*=2
  y0*=2
  for _x=0,15 do
    local srcx,srcy=x0,y0
    for _y=0,15 do
      if band(bor(srcx,srcy),-16)==0 then
        local c=sget(sx+srcx,sy+srcy)
        if c!=0 then
          pset(x+_x,y+_y,c)
        end
      end
      srcx,srcy=srcx-dy,srcy+dx
    end
    x0,y0=x0+dx,y0+dy
  end
end

zip_mover={
  init=function(_ENV)
    solid_obj=true
    delay=0
    state=0
    shake=0
    id=tile_at(x/8,y/8-1)
    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==68 do 
      hitbox.w+=8
    end 
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==68 do 
      hitbox.h+=8
    end 
    break_timer,death_timer=0,0
    start=vector(x,y)
    ang=0
    particles={}
  end,
  end_init=function(_ENV)
    for o in all(objects) do 
      if o.sprite==id then 
        if o.x!=x or o.y!=y-8 then 
          target=vector(o.x,o.y)
        end 
        destroy_object(o)
      end
    end 
    local dx=target.x-x 
    local dy=target.y-y 
    local d=sqrt(dx^2+dy^2)
    dir=vector(dx/d,dy/d)
  end,
  update=function(_ENV)
    -- states:
    -- 0 - idle
    -- 1 - active moving towards target
    -- 2 - returning back to original pos
    if delay>0 then 
      delay-=1
      if delay==0 then 
        state=(state+1)%3
      end 
      --ang=appr(ang,state==1 and flr(ang) or ceil(ang),0.2)
    elseif state==0 then 
      local hit=check(player,0,-1)
      if hit then 
        delay=4
        shake=4
      end
    else
      local accel,maxspeed,shake,target
      if state==1 then 
        accel,maxspeed,shake,target=0.5,6,6,_ENV.target

        --create particles
        -- this is really bad token wise, and can be optimized, but idc for now
        local c1x=start.x+hitbox.w/2-0.5
        local c1y=start.y+7.5
        local c2x=target.x+hitbox.w/2-0.5
        local c2y=target.y+7.5
        cang=atan2(c1x-c2x,c1y-c2y)

        local r=6
        ox,oy=r*cos(0.25+cang),r*sin(0.25+cang)
        --line(c1x,c1y,c2x,c2y,8)
        if rnd()<0.8 then 
          local cx,cy
          if rnd()<0.5 then
            cx,cy=c1x,c1y              
          else 
            cx,cy=c2x,c2y 
          end 
          if rnd()<0.5 then 
            ox*=-1
            oy*=-1
          end 
          add(particles,{
            x=cx+ox+rnd(3)-1,
            y=cy+oy+rnd(3)-1,
            dx=ox*rnd(0.05),
            dy=oy*rnd(0.05),
            d=10
          })
        end 
      else 
        accel,maxspeed,shake,target=0.2,-1,4,start
      end 
      for axis in all{"x","y"} do 
        spd[axis]=mid(appr(spd[axis],maxspeed*dir[axis],abs(accel*dir[axis])),_ENV[axis]-target[axis],target[axis]-_ENV[axis])
      end
      ang+=sqrt(spd.x^2+spd.y^2)/100*(state==1 and 1 or -1)
      if x==target.x and y==target.y then 
        delay=15
        shake=shake
        ang=0
      end 
    end
    if shake>0 then 
      shake-=1
    end 

    --update particles 
    for p in all(particles) do 
      p.x+=p.dx 
      p.y+=p.dy 
      p.d-=1
      if p.d<0 then 
        del(particles,p)
      end 
    end 
  end,
  draw=function(_ENV)

    if pal==_pal then --don't outline
      --tracks
      local c1x=start.x+hitbox.w/2-0.5
      local c1y=start.y+7.5
      local c2x=target.x+hitbox.w/2-0.5
      local c2y=target.y+7.5
      
      cang=atan2(c1x-c2x,c1y-c2y)

      local r=4.5
      ox,oy=r*cos(0.25+cang),r*sin(0.25+cang)
      --line(c1x,c1y,c2x,c2y,8)
      --pset(c1x+ox/r*(r+6),c1y+oy/r*(r+6),9)

      c1x+=1*sin(0.25+cang)
      c1y-=1*cos(0.25+cang)
      c2x-=1*sin(0.25+cang)
      c2y+=1*cos(0.25+cang)
      line(round(c1x+ox),round(c1y+oy),round(c2x+ox),round(c2y+oy),2)
      line(round(c1x-ox),round(c1y-oy),round(c2x-ox),round(c2y-oy),2)
      

      --ox,oy=(r+1.5)*cos(0.25+cang),(r+1.5)*sin(0.25+cang)
      if abs(c1x-c2x)>abs(c1y-c2y) then 
        oy+=1
      else 
        ox+=1
      end
      poke(0x5f38,1)
      poke(0x5f3a,start.x/8+lvl_x+1)
      pal(7,4)
      tline(round(c1x+ox),round(c1y+oy),round(c2x+ox),round(c2y+oy),0,start.y/8+0.875-flr(ang*40%4)/8,0.125,0)
      tline(round(c1x-ox),round(c1y-oy),round(c2x-ox),round(c2y-oy),0,start.y/8+0.5+flr(ang*40%4)/8,0.125,0)
      pal()
      --tline(0,0,128,0,0,start.y/8+0.5--[[+ang*10%4/8]],0.125,0)
    end
    -- gears  
    spr_r(101,start.x+hitbox.w/2-8,start.y,ang)
    spr_r(101,target.x+hitbox.w/2-8,target.y,ang)

    if pal==_pal then 
      --particles
      for p in all(particles) do 
        pset(p.x,p.y,10)
      end 
    end 

    local x,y=x,y
    if shake>0 then 
      x+=rnd(2)-1
      y+=rnd(2)-1
    end
    local r,b=x+hitbox.w-1,y+hitbox.h-1
    
    if state==1 then
    	pal(2,3)
    	pal(8,11)
    elseif state==2 and delay==0 then 
      pal(2,9)
      pal(8,10)
    end 
    
    --chasis
    line(x,y,r,y,7)
    rectfill(x,y+1,r,b,1)
    rect(x+1,y+2,r-1,b-1,5)
    spr(67,x+hitbox.w/2-4,y)
    rect(x,y+1,r,b,6)
    
    --top corner sprites
    if hitbox.w>8 then
    	spr(70,x,y)
    	spr(70,r-7,y,1,1,true)
    end
    
    --bottom corner sprites
    spr(70,x,b-7,1,1,false,true)
    spr(70,r-7,b-7,1,1,true,true)
    
    pal()
    --pset(start.x+8,start.y+4,11)
    --pset(c1x+ox,c1y+oy,11)
    --pset(c2x+ox,c2y+oy,11)
  end
}
--</zip_mover>--
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
  [67]=zip_mover
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

  function player_here()
    return check(player,0,0)
  end
  
  function move(ox,oy,start)
    for axis in all{"x","y"} do
      rem[axis]+=axis=="x" and ox or oy
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
        --<zip_mover> --
        if (solid_obj or semisolid_obj) and upmoving and riding and riding.spd.y>-1 then 
        --</zip_mover> --
          movamt+=top()-riding.bottom()-1
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
  
  --set level globals
  local tbl=split(levels[lvl_id])
  lvl_x,lvl_y,lvl_w,lvl_h=tbl[1]*16,tbl[2]*16,tbl[3]*16,tbl[4]*16
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
      -- <zip_mover> --
      if tiles[tile] or tile>=128 then
        init_object(tiles[tile] or tile>=128 and {},tx*8,ty*8,tile)
      end
      -- <zip_mover> --
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
  cls()

  -- bg clouds effect
  foreach(clouds,function(c)
    c.x+=c.spd-cam_spdx
    rectfill(c.x+draw_x,c.y+draw_y,c.x+c.w+draw_x,c.y+16-c.w*0.1875+draw_y,1)
    if c.x>128 then
      c.x=-c.w
      c.y=rnd(120)
    end
  end)

		-- draw bg terrain
		pal(11,0)
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)
		pal()
		
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
--"x,y,w,h,exit_dirs"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
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
888888886661666111188888888116664fff4fff4fff4fff4fff4fffd666666dd666666dd666066d000000000000000070000000666666666666666661111116
888888886761676166711888881777764444444444444444444444446dddddd56ddd5dd56dd50dd500770000077007000700000761111116dd111dd16d1111d6
88188818677167716777718888811766000450000000000000054000666ddd55666d6d55565005550077707007770000000000006dd11dd61dd1dd116dd11dd6
8171817117181718666118888888811100450000000000000000540066ddd5d5656505d50000005507777770077000000000000061dddd1611ddd11161dddd16
817181711718171811188888888116660450000000000000000005406ddd5dd56dd5065565000000077777700000700000000000611dd11611ddd111611dd116
167716778188818866711888881777764500000000000000000000546ddd6d656ddd7d656d50056507777770000007700000000061dddd161dd1dd1161dddd16
1676167688888888677771888881176650000000000000000000000505ddd65005d5d650055056500707770000070770070000706dd11dd6dd111dd16dd11dd6
1666166688888888666118888888811100000000000000000000000000000000000000000000000000000000700000000000000066666666666666666d1111d6
1111001106666666066666666666666066d1ddd11ddd1666077777777777777777777770cc000000000000000ff40ff4fff04ff04ff04ff00ff4000000004ff0
11110011666166d616dddddddd6616666dd111111ddd1d667777777777677767777777771c00cc00000000004fff4ff44ff4fff44ffffff4ffff40000004ffff
1111000066d1dddd1ddddddddddd1d666dd1ddd01ddd11107677667777766677777777770000ccc0000000004ff44f444f44ff444fff4ffffff4440000444fff
1555500001111111110011001111111066d1ddd00ddd00067766677777776d676777677700001ccc00000000444444404444f4400fff4ff44444000000044ff4
0555511166d16661ddd0dddd16661d660110ddd101100dd677d67777dd77dcd7666677700cc01ccc0000000004400440440444400444044004ff4000004f4440
055551116dd1d661ddd1dddd166d1dd666d0ddd11ddd0dd67dcd667dccddcccd6d6777661ccc11c100000000fff400000000440000444ff4fff44400004444ff
0000111166d1dd61ddd1dddd16dd1d666dd111111ddd1d667cccd66cccccccccccc66d661ccc011100000000ff4404000000000004404fffff44400000044fff
000011110111111111111111111111106dd1ddd11ddd1d667ccccccc0ccc00cccccd6dd611c00000000000004440000000000000000004ff04400000000044ff
11110000011111001111110000111d667cccccccccccccc777cccccc00cccccccccccc770ccc10000cccccc04440000000000000000004441000000100001000
1100000066d1dd60ddddddd106dd1dd677ccccc0cccccc7777cccccccccccccccccccc771cc11000ccccccccff44040000000440004044ff0155551000055500
110555006dd1d661ddddddd1166d1dd676ccccc0cccc777767c7cccccccccccccccc7c67111100001cccccccfff400000440444000004fff055511500051d150
110555006dd16661ddddddd016660dd6667cccc000ccccc76ccccccccccccc6cccccccc60011cc101cc1ccc10440044044444f40044004400555115000d555d0
000000016dd001111111110011100dd66ccccccc0ccccc776ccccccccc6cccccccccccc6001cccc01cc11c10444444404ff4440004444444051555500051d150
000011116dd0dddd1ddd1dddddddddd67cccccccccccc67766ccccc6cccccccc6ccccc660111cc10111111004ff44f444fff4f4444f44ff40555555000d555d0
00001111666166d616dd1ddd6d6666667cccccccccccc6676ccc66c6666ccc666c66ccc61c111100011010004fff4ff4ffff4ff44ff4fff4015555100051d150
0000111106666666666666666666666077cccccccccccc67066666660666666666666666cc100000000000000ff40ff444ff0ff44ff04ff01000000100055500
0000044404444000440004406666666600000b000007700077750000155555555555555555555551155555555555555555555555555555510011111151111110
044044444444400004444440666666660000a00000577500656500005111111111111111111111155511111111111111111111111111115500555555d1111110
444444444444000044444440566226650008000005666650666000005151155155155511115151555155515551555111111111111111111500555555d1111110
44440440004444404444444456288265000000007760067755000000515115115511511111515155515111515115111aa11111111111111500555555d1111110
4444000000444440444444405688886577007700776006770000000051551551511151111515151551511151511511aaaa1aaa1aa1aaaa1500588588d2212210
0444000004444440444444405668866507700770056666500000000051111111111111111555555551515151511511aaaa1aaaaaaaaaa1150088588582122120
00440044044444004444440056666665007700770057750000000000515511115111111115511515515551555115111aa11a1aaa1aa1aa1500555555d1111110
00400044044000000440400055555555700770070007700000000000515115115155111115115115511111111111111111111111111111150000111151111110
000555055555555555005550000000000000000000055500000555005115151551511111155555555155515111555151115155515551551500005555d1111000
005555515511551151551555000000000000555000286820001888105155151551551151151151155151515111515151115151515111151500005555d1111000
0515515515511551111111155000000000005bb505688865056878655111111111111515155151155155515111555151515155515511551500005555d1111000
551111551551155111511115b55000000000555b05678765056888655155155515551115155551155151115111515155555151115111111500005555d1111000
551111111115111511115555dbb500000000555505688865056877655151151515151151151151155151115551515115151151115551511500005555d1111000
111111151155111115115555dd1b50000000555500286820001866105115155515551111155151155111111111111111111111111111111500005555d1111000
510001111111151111111550d11110000000555500055500000555005151111111111151155551155511111111111111111111111111115500005555d111b000
510001111111111111111150d11110000000555500001000000010001555555555555555555555511555555555555555555555555555555100005555d1111000
051111111111111151111150000055550005550000000000000000000000000000000000000000000000000015555511000000000000000000005555d1111000
555111111111111111155155000055550018861000000000000000000000000000000000000000000000000051111151000000000000000000005555d1111000
5511111111111111111551150000055505678865000000000000000000000000000000000000000000000000551d1551000000009449400000005555d1111000
55111111111111111111111500000555058888850000000dd000000000000000000000000000000000000000515d515100000000420420000000555bb1111000
05111151111111111111155500000055056788650000dd0dd0dd00000000000000000000000000000000000051111151000000004204200000005555bb111000
05111111111111111151155000000055001886100000dd0550dd00000000000000000000000000000000770051555151000000094494220000005555dd111000
01111111111111111111155000000005000555000000005555000000000000000000000000000000077766705111115100000004424422000000b555d1111000
1111111111111111111115500000000500001000000dd550055dd0000000000000000000000000007667767715555511000000040040020000005555d1111000
551111111111111111111150d111100000001000000dd550055dd000000000000000000000000000000055555555555000677794494222200000111151111000
515511111111111111111150d11110000000500000000055550000000000000000000000000000000005ddddddddddd500d676440442022000555555d1111110
115515115111111511111155d1111000000010000000dd0550dd00000000000000000000000000000005ddddddddddd500d665400402002000588588d2212210
511111111111111511111115d1111000000010000000dd0dd0dd000000000000000000000000000000055ddddddddd5500d56944940222220088588582122120
111111111111155111111155d1111000000010000000000dd00000000000000000000000000000000555555555555555d66d14414402202200555555d1111110
055115511111155111111550d1110000000010000000000000000000000000000000000000000000ddddddddddddd555ddd514114000200200555555d1111110
055515511115111111150000d10000000000500000000000000000000000000000000000000000000111110000111110d55594494000222200555555d1111110
000555555500055515000000d0000000000010000000000000000000000000000000000000000000000000000000000000000000400020020011111151111110
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bb0000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b000b00008808800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0b0bbb00008880800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bbbb000008808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000008880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000002020202080808000000000000030303030303030303030303030303030303030303030303030303030303030303030403030300000000040404040404070707070404040404040404040404040404040404040404000000000004040404040404040404040000000000040404040404
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2b3b29000000000000000000002a3b2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3b290000000000000000000000002a3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2900000000000001000000000000002a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000132122222312000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000133132323312000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000008000001111111100000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2708000000000000000000000000082700000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3708000000000000000000008100083700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000810000000000004344000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000008000000000000000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000004344000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000009090000000000000001008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222222223171720201717212222222223004344000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3825252526000000000000242525253826004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

__change_mask__
fbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbfffffffbffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
