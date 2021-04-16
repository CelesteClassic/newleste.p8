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
  init=function(this) 
    this.grace,this.jbuffer=0,0
    this.djump=max_djump
    this.dash_time,this.dash_effect_time=0,0
    this.dash_target_x,this.dash_target_y=0,0
    this.dash_accel_x,this.dash_accel_y=0,0
    this.hitbox=rectangle(1,3,6,5)
    this.spr_off=0
    this.collides=true
    create_hair(this)
    -- <fruitrain> --
    this.berry_timer=0
    this.berry_count=0
    -- <keydoor> --
    this.key_count=0
    -- </keydoor> --
    -- </fruitrain> --
  end,
  update=function(this)
    if pause_player then
      return
    end
    
    -- horizontal input
    local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0
    
    -- spike collision / bottom death
    if this.is_flag(0,0,-1) or 
	    this.y>lvl_ph then
	    kill_player(this)
    end

    -- on ground checks
    local on_ground=this.is_solid(0,1)

        -- <fruitrain> --
    if on_ground then
      this.berry_timer+=1
    else
      this.berry_timer=0
      this.berry_count=0
    end

    for f in all(fruitrain) do
      if f.type==fruit and not f.golden and this.berry_timer>5 and f then
        -- to be implemented:
        -- save berry
        -- save golden
        this.berry_timer=-5
        this.berry_count+=1
        berry_count+=1
        got_fruit[f.fruit_id]=true
        init_object(lifeup, f.x, f.y,this.berry_count)
        del(fruitrain, f)
        destroy_object(f)
        if (fruitrain[1]) fruitrain[1].target=this
      end
    end
    -- </fruitrain> --
    
    -- landing smoke
    if on_ground and not this.was_on_ground then
      this.init_smoke(0,4)
    end

    -- jump and dash input
    local jump,dash=btn(🅾️) and not this.p_jump,btn(❎) and not this.p_dash
    this.p_jump,this.p_dash=btn(🅾️),btn(❎)

    -- jump buffer
    if jump then
      this.jbuffer=4
    elseif this.jbuffer>0 then
      this.jbuffer-=1
    end
    
    -- grace frames and dash restoration
    if on_ground then
      this.grace=6
      if this.djump<max_djump then
        psfx(7)
        this.djump=max_djump
      end
    elseif this.grace>0 then
      this.grace-=1
    end

    -- dash effect timer (for dash-triggered events, e.g., berry blocks)
    this.dash_effect_time-=1

    -- dash startup period, accel toward dash target speed
    if this.dash_time>0 then
      this.init_smoke()
      this.dash_time-=1
      this.spd=vector(
        appr(this.spd.x,this.dash_target_x,this.dash_accel_x),
        appr(this.spd.y,this.dash_target_y,this.dash_accel_y)
      )
    else
      -- x movement
      local maxrun=1
      local accel=on_ground and 0.6 or 0.4
      local deccel=0.15
    
      -- set x speed
      this.spd.x=abs(this.spd.x)<=1 and 
        appr(this.spd.x,h_input*maxrun,accel) or 
        appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
      
      -- facing direction
      if this.spd.x~=0 then
        this.flip.x=this.spd.x<0
      end

      -- y movement
      local maxfall=2
    
      -- wall slide
      if h_input~=0 and this.is_solid(h_input,0) then
        maxfall=0.4
        -- wall slide smoke
        if rnd(10)<2 then
          this.init_smoke(h_input*6)
        end
      end

      -- apply gravity
      if not on_ground then
        this.spd.y=appr(this.spd.y,maxfall,abs(this.spd.y)>0.15 and 0.21 or 0.105)
      end

      -- jump
      if this.jbuffer>0 then
        if this.grace>0 then
          -- normal jump
          psfx(3)
          this.jbuffer=0
          this.grace=0
          this.spd.y=-2
          this.init_smoke(0,4)
        else
          -- wall jump
          local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
          if wall_dir~=0 then
            psfx(4)
            this.jbuffer=0
            this.spd=vector(wall_dir*(-1-maxrun),-2)
            -- wall jump smoke
            this.init_smoke(wall_dir*6)
          end
        end
      end
    
      -- dash
      local d_full=5
      local d_half=3.5355339059 -- 5 * sqrt(2)
      -- <red_bubble> --
      if this.djump>0 and dash or this.do_dash then
        this.do_dash=false
      -- </red_bubble> -- 
        this.init_smoke()
        this.djump-=1   
        this.dash_time=4
        has_dashed=true
        this.dash_effect_time=10
        -- vertical input
        local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
        -- calculate dash speeds
        this.spd=vector(h_input~=0 and 
        h_input*(v_input~=0 and d_half or d_full) or 
        (v_input~=0 and 0 or this.flip.x and -1 or 1)
        ,v_input~=0 and v_input*(h_input~=0 and d_half or d_full) or 0)
        -- effects
        psfx(5)
        freeze=2
        -- dash target speeds and accels
        this.dash_target_x=2*sign(this.spd.x)
        this.dash_target_y=(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y)
        this.dash_accel_x=this.spd.y==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()
        this.dash_accel_y=this.spd.x==0 and 1.5 or 1.06066017177
      elseif this.djump<=0 and dash then
        -- failed dash smoke
        psfx(6)
        this.init_smoke()
      end
    end
    
    -- animation
    this.spr_off+=0.25
    this.spr = not on_ground and (this.is_solid(h_input,0) and 5 or 3) or  -- wall slide or mid air
      btn(⬇️) and 6 or -- crouch
      btn(⬆️) and 7 or -- look up
      this.spd.x~=0 and h_input~=0 and 1+this.spr_off%4 or 1 -- walk or stand
    update_hair(this)
    -- exit level off the top (except summit)
    if this.y<-4 and levels[lvl_id+1] then
      next_level()
    end
    
    -- was on the ground
    this.was_on_ground=on_ground
  end,
  
  draw=function(this)
    -- clamp in screen
    local clamped=mid(this.x,-1,lvl_pw-7)
    if this.x~=clamped then
      this.x=clamped
      this.spd.x=0
    end
    -- draw player hair and sprite
    set_hair_color(this.djump)
    draw_hair(this)
    draw_obj_sprite(this)
    pal()
  end
}

function create_hair(obj)
  obj.hair={}
  for i=1,5 do
    add(obj.hair,vector(obj.x,obj.y))
  end
end

function set_hair_color(djump)
  pal(8,djump==1 and 8 or 12)
end

function update_hair(obj)
  local last=vector(obj.x+4-(obj.flip.x and-2 or 3),obj.y+(btn(⬇️) and 4 or 2.9))
  for h in all(obj.hair) do
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    last=h
  end
end

function draw_hair(obj)
  for i,h in pairs(obj.hair) do
    circfill(round(h.x),round(h.y),mid(4-i,1,2),8)
  end
end

-- [other entities]

player_spawn={
  layer=2,
  init=function(this)
    sfx(0)
    this.spr=3
    this.target=this.y
    this.y=min(this.y+48,lvl_ph)
		cam_x,cam_y=mid(this.x,64,lvl_pw-64),mid(this.y,64,lvl_ph-64)
    this.spd.y=-4
    this.state=0
    this.delay=0
    create_hair(this)
    this.djump=max_djump
    --- <keydoor> ---
    this.key_count=0
    --- <fruitrain> ---
    for i=1,#fruitrain do
      local f=init_object(fruitrain[i].type,this.x,this.y,fruitrain[i].spr)
      if fruitrain[i].type==key then 
        this.key_count+=1
      end 
      f.follow=true
      f.target=i==1 and this or fruitrain[i-1]
      f.r=fruitrain[i].r
      f.fruit_id=fruitrain[i].fruit_id
      fruitrain[i]=f
    end
    --- </fruitrain> </keydoor> ---
  end,
  update=function(this)
    -- jumping up
    if this.state==0 and this.y<this.target+16 then
        this.state=1
        this.delay=3
    -- falling
    elseif this.state==1 then
      this.spd.y+=0.5
      if this.spd.y>0 then
        if this.delay>0 then
          -- stall at peak
          this.spd.y=0
          this.delay-=1
        elseif this.y>this.target then
          -- clamp at target y
          this.y=this.target
          this.spd=vector(0,0)
          this.state=2
          this.delay=5
          this.init_smoke(0,4)
          sfx(1)
        end
      end
    -- landing and spawning player object
    elseif this.state==2 then
      this.delay-=1
      this.spr=6
      if this.delay<0 then
        destroy_object(this)
        local p=init_object(player,this.x,this.y)
        -- <keydoor> --
        p.key_count=this.key_count 
        -- </keydoor> --
        --- <fruitrain> ---
        if (fruitrain[1]) fruitrain[1].target=p
        --- </fruitrain> ---
      end
    end
    update_hair(this)
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
  update=function(this)
    if this.timer and this.timer>0 then 
      this.timer-=1
      if this.timer==0 then 
        cam_offx=this.offx
        cam_offy=this.offy
      else 
        cam_offx+=cam_gain*(this.offx-cam_offx)
        cam_offy+=cam_gain*(this.offy-cam_offy)
      end 
    elseif this.player_here() then
      this.timer=5
    end
  end
}
--</camtrigger>--

spring={
	init=function(this)
		this.dy,this.delay=0,0
	end,
	update=function(this)
		local hit=this.player_here()
		if this.delay>0 then
			this.delay-=1
		elseif hit then
			hit.y,hit.spd.y,hit.dash_time,hit.dash_effect_time,this.dy,this.delay,hit.djump=this.y-4,-3,0,0,4,10,max_djump
			hit.spd.x*=0.2
			psfx(14)
		end
	this.dy*=0.75
	end,
	draw=function(this)
		sspr(72,0,8,8-flr(this.dy),this.x,this.y+this.dy)
	end
}

side_spring={
	init=function(this)
		this.dx,this.dir=0,this.is_solid(-1,0) and 1 or -1
	end,
	update=function(this)
		local hit=this.player_here()
		if hit then
			hit.x,hit.spd.x,hit.spd.y,hit.dash_time,hit.dash_effect_time,this.dx,hit.djump=this.x+this.dir*4,this.dir*3,-1.5,0,0,4,max_djump
			psfx(14)
		end
		this.dx*=0.75
	end,
	draw=function(this)
		local dx=flr(this.dx)
		sspr(64,0,8-dx,8,this.x+dx*(this.dir-1)/-2,this.y,8-dx,8,this.dir==1)
	end
}


refill={
  init=function(this) 
    this.offset=rnd(1)
    this.timer=0
    this.hitbox=rectangle(-1,-1,10,10)
    this.active=true
  end,
  update=function(this) 
    if this.active then
      this.offset+=0.02
      local hit=this.player_here()
      if hit and hit.djump<max_djump then
        psfx(11)
        this.init_smoke()
        hit.djump=max_djump
        this.active=false
        this.timer=60
      end
    elseif this.timer>0 then
      this.timer-=1
    else 
      psfx(12)
      this.init_smoke()
      this.active=true 
    end
  end,
  draw=function(this)
    local x,y=this.x,this.y
    if this.active then
      spr(15,x,y+sin(this.offset)+0.5)
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
  init=function(this)
    this.solid_obj=true
    this.state=0
  end,
  update=function(this)
    -- idling
    if this.state==0 then
      for i=0,2 do
        if this.check(player,i-1,-(i%2)) then 
          psfx(13)
          this.state,this.delay=1,15
          this.init_smoke()
          break
        end
      end
    -- shaking
    elseif this.state==1 then
      this.delay-=1
      if this.delay<=0 then
        this.state=2
        this.delay=60--how long it hides for
        this.collideable=false
      end
    -- invisible, waiting to reset
    elseif this.state==2 then
      this.delay-=1
      if this.delay<=0 and not this.player_here() then
        psfx(12)
        this.state=0
        this.collideable=true
        this.init_smoke()
      end
    end
  end,
  draw=function(this)
    spr(this.state==1 and 26-this.delay/5 or this.state==0 and 23,this.x,this.y) --add an if statement if you use sprite 0 
  end
}

smoke={
  layer=3,
  init=function(this)
    this.spd=vector(0.3+rnd(0.2),-0.1)
    this.x+=-1+rnd(2)
    this.y+=-1+rnd(2)
    this.flip=vector(maybe(),maybe())
  end,
  update=function(this)
    this.spr+=0.2
    if this.spr>=29 then
      destroy_object(this)
    end
  end
}

--- <fruitrain> ---
fruitrain={}
fruit={
  check_fruit=true,
  init=function(this)
    this.y_=this.y
    this.off=0
    this.follow=false
    this.tx=this.x
    this.ty=this.y
    this.golden=this.spr==11
    if this.golden and deaths>0 then
      destroy_object(this)
    end
  end,
  update=function(this)
    if not this.follow then
      local hit=this.player_here()
      if hit then
        hit.berry_timer=0
        this.follow=true
        this.target=#fruitrain==0 and hit or fruitrain[#fruitrain]
        this.r=#fruitrain==0 and 12 or 8
        add(fruitrain,this)
      end
    else
      if this.target then
        this.tx+=0.2*(this.target.x-this.tx)
        this.ty+=0.2*(this.target.y-this.ty)
        local a=atan2(this.x-this.tx,this.y_-this.ty)
        local k=(this.x-this.tx)^2+(this.y_-this.ty)^2 > this.r^2 and 0.2 or 0.1
        this.x+=k*(this.tx+this.r*cos(a)-this.x)
        this.y_+=k*(this.ty+this.r*sin(a)-this.y_)
      end
    end
    this.off+=0.025
    this.y=this.y_+sin(this.off)*2.5
  end
}
--- </fruitrain> ---

fly_fruit={
  check_fruit=true,
  init=function(this) 
    this.start=this.y
    this.step=0.5
    this.sfx_delay=8
  end,
  update=function(this)
    --fly away
    if has_dashed then
     if this.sfx_delay>0 then
      this.sfx_delay-=1
      if this.sfx_delay<=0 then
       sfx_timer=20
       sfx(10)
      end
     end
      this.spd.y=appr(this.spd.y,-3.5,0.25)
      if this.y<-16 then
        destroy_object(this)
      end
    -- wait
    else
      this.step+=0.05
      this.spd.y=sin(this.step)*0.5
    end
    -- collect
    if this.player_here() then
      --- <fruitrain> ---
      this.init_smoke(-6)
      this.init_smoke(6)

      local f=init_object(fruit,this.x,this.y,10) --if this happens to be in the exact location of a different fruit that has already been collected, this'll cause a crash
      --TODO: fix this if needed 
      f.fruit_id=this.fruit_id
      fruit.update(f)
      --- </fruitrain> ---
      destroy_object(this)
    end
  end,
  draw=function(this)
    spr(10,this.x,this.y)
    for ox=-6,6,12 do
      spr((has_dashed or sin(this.step)>=0) and 12 or this.y>this.start and 14 or 13,this.x+ox,this.y-2,1,1,ox==-6)
    end
  end
}

lifeup={
  init=function(this)
    this.spd.y=-0.25
    this.duration=30
    this.flash=0
    this.outline=false
    sfx_timer=20
    sfx(9)
  end,
  update=function(this)
    this.duration-=1
    if this.duration<=0 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    this.flash+=0.5
    --<fruitrain>--
    ?this.spr<=5 and this.spr.."000" or "1UP",this.x-4,this.y-4,7+this.flash%2
    --<fruitrain>--
  end
}
key_door_used={}
key={
  init=function(this)
    if key_door_used[this.fruit_id] then
      destroy_object(this) 
    end 
    this.y_=this.y
    this.off=0
    this.tx=this.x
    this.ty=this.y
    this.timer=0
  end,
  update=function(this)
    if this.timer>0 then 
      this.timer-=1
      if this.timer==0 then 
        this.target.timer=1
        this.init_smoke()
        destroy_object(this)
      end 
    elseif not this.target then
      local hit=this.player_here()
      if hit then
        hit.key_count+=1
        --this.follow=true
        this.target=#fruitrain==0 and hit or fruitrain[#fruitrain]
        this.r=#fruitrain==0 and 12 or 8
        add(fruitrain,this)
        key_door_used[this.fruit_id]=true 
      end
    else
      this.tx+=0.2*(this.target.x+this.target.hitbox.w/2-this.hitbox.w/2-this.tx)
      this.ty+=0.2*(this.target.y+this.target.hitbox.h/2-this.hitbox.h/2-this.ty) --target center, which matters (more) for doors
      local a=atan2(this.x-this.tx,this.y_-this.ty)
      local k=(this.x-this.tx)^2+(this.y_-this.ty)^2 > this.r^2 and 0.2 or 0.1
      this.x+=k*(this.tx+this.r*cos(a)-this.x)
      this.y_+=k*(this.ty+this.r*sin(a)-this.y_)
      if this.target.type==keydoor and (this.x-this.target.x-4)^2+(this.y-this.target.y-4)^2<5 then
        this.x,this.y_,this.timer=this.target.x+4,this.target.y+4,20
      end

    end
    this.off+=0.025
    this.y=this.y_+sin(this.off)*2.5

    this.spr=65.5+sin(frames/30)
    if frames==18 then
      this.flip.x=not this.flip.x
    end
  end,
  draw=function(this)
    if this.timer>10 then
      rectfill(this.x+3,this.y_+2,this.x+4,this.y_+5,10)
    elseif this.timer>0 then 
      rectfill(this.x+2,this.y_+4,this.x+5,this.y_+5,10)
    else 
      spr(this.spr,this.x,this.y,0.875,1,this.flip.x,this.flip.y)
      if flr(this.spr)==66 and this.flip.x then
        line(this.x+3,this.y+5,this.x+3,this.y+7,9)
      end 
    end 
  end
}
keydoor={
  layer=0, --might cause visual problems? idk lol
  init=function(this)
    if key_door_used[this.fruit_id] then 
      destroy_object(this)
    end 
    this.hitbox=rectangle(0,0,16,16)
    this.solid_obj=true
    this.timer=0
  end,
  update=function(this)
    if this.timer>0 then 
      this.collideable=false
      this.timer+=1
      if this.timer==12 then 
        this.init_smoke(-8,0)
        this.init_smoke(-8,8)
        this.init_smoke(16,0)
        this.init_smoke(16,8)
        destroy_object(this)
      end 
    elseif not this.has_key then
      this.hitbox=rectangle(-16,-16,48,48)
      local hit=this.player_here()
      if hit and hit.key_count>0 then 
        hit.key_count-=1
        for i,f in ipairs(fruitrain) do 
          if f.type==key then 
            local p=fruitrain[i+1] or {}
            p.target,p.r=f.target,f.r 
            del(fruitrain,f)
            key_door_used[this.fruit_id]=true
            f.target,f.r=this,0 
            this.has_key=true
            break
          end 
        end 
      end 
      this.hitbox=rectangle(0,0,16,16)
    end
  end,
  draw=function(this) 
    spr(80,this.x-this.timer\3,this.y,1,2)
    spr(81,this.x+8+this.timer\3,this.y,1,2)
  end 
}


sawblade={
  layer=0,
  init=function(this)
    this.hitbox=rectangle(2,2,12,12)
    local axis=this.spr==112 and "x" or "y"
    this.axis=axis
    local r=this[axis]
    while axis=="x" and r<lvl_pw and not fget(tile_at(r\8,this.y\8),0) or
          axis=="y" and r<lvl_ph and not fget(tile_at(this.x\8,r\8),0) do 
      r+=8
    end 
    this[axis]-=4
    this.l=this[axis] 
    this.r=r-12
  end,
  update=function(this)
    local axis=this.axis
    if this[axis]>=this.r then
      this.dir=-1
    elseif this[axis]<=this.l then
      this.dir=1
    end 
    this.spd[axis]=appr(this.spd[axis],2*this.dir,0.4)
    local hit=this.player_here()
    if hit then 
      kill_player(hit)
    end 
  end,
  draw=function(this)
    for i=0,3 do
      spr(abs(2*this[this.axis]-this.l-this.r)<10 and 113 or 112,this.x+(i%2)*8,this.y+i\2*8,1,1,i%2!=0,i>1)
    end
  end 
}
--<red_bubble>--
red_bubble_particle={
  layer=0,
  init=function(this)
    this.outline=false
    this.spd=vector(0.3-rnd(0.3),0.1)
    this.x+=-1+rnd(2)
    this.y+=-1+rnd(2)
    this.flip=vector(maybe(),maybe())
  end,
  update=function(this)
    this.spr+=rnd(0.2)
    if this.spr>=29 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    pal(7,14)
    draw_obj_sprite(this)
    pal()
  end 
}

red_bubble={
  init=function(this)
    this.t=0
    this.st=0
    this.timer=0
    this.shake=0
    this.dead_timer=0
    this.hitbox=rectangle(0,0,12,12)
    this.outline=false --maybe add an extra black outline, or remove this?
    this.startx,this.starty=this.x,this.y
  end,
  hide=function(this)
    this.invisible=true
    this.timer=0
    this.x,this.y=this.startx,this.starty
    this.spd=vector(0,0)
    this.rem=vector(0,0)
    this.active=false
    this.init_smoke()
  end,
  update=function(this)
    local maxspd=3.5
    local hit=this.player_here()
    if hit and not this.invisible then
      hit.move(-hit.x+this.x+1,-hit.y+this.y+1,1) 
      if hit.x!=this.x+1 or hit.y!=this.y+1 then 
        hit.invisible=false 
        hit.init_smoke()
        hit.spd.x=sign(this.spd.x)
        hit.spd.y=sign(this.spd.y)
        hit.djump=max_djump
        red_bubble.hide(this)
      else 
        this.active=true
        hit.invisible=true
        hit.spd=vector(0,0)
        hit.rem=vector(0,0)
        hit.dash_time=0
        hit.djump=0
        if this.timer==0 then
          this.timer=1
          this.shake=5
        elseif this.timer<15 then 
          this.timer+=1
          if this.timer==15 then 
            this.init_smoke()
            local diry=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
            local dirx=btn(➡️) and 1 or btn(⬅️) and -1 or diry==0 and (hit.flip.x and -1 or 1) or 0
            local k=maxspd/sqrt(dirx^2+diry^2)
            this.spd=vector(dirx*k,diry*k)
          end
        else 
          init_object(red_bubble_particle,this.x,this.y,26)
        end 
        if btnp(❎) then
          if this.timer<15 then 
            this.timer=14 
          else 
            hit.invisible=false
            hit.djump=max_djump+1
            hit.do_dash=true
            red_bubble.hide(this)
          end
        end 
      end 
    elseif this.invisible then
      this.dead_timer+=1
      if this.dead_timer==60 then
        this.dead_timer=0
        this.invisible=false
        this.init_smoke()
      end
    elseif this.active then
      red_bubble.hide(this)
    end 
  end, 
  draw=function(this)
    this.t+=0.05
  	local x,y,t=this.x,this.y,this.t
    if this.shake>0 then
      this.shake-=1
      x+=rnd(2)-1
      y+=rnd(2)-1
    end
    local sx=sin(t)>=0.5 and 1 or 0
    local sy=sin(t)<-0.5 and 1 or 0
    for f in all({ovalfill,oval}) do
      f(x-2-sx,y-2-sy,x+9+sx,y+9+sy,f==oval and 7 or 8)
    end
    if this.active then
      this.st+=1
      this.st%=8
      pal(8,2)
      pal(15,2)
      pal(1,2)
      pal(3,2)
      pal(7,8)
      local c=flr(this.st)
      if abs(this.spd.x)+abs(this.spd.y)==0 then  
        spr(1,x-1,y-1)
        this.st=-1
      else 
        spr(1,x+(split"-1,0,1,1,1,0,-1,-1")[this.st+1],y+(split"-1,-1,-1,0,1,1,1,0")[this.st+1]) --spinny stuff
      end 
      pal()
    end
  	for dx=2,5 do
      local _t=(5*t+3*dx)%8
      local bx=sgn(dx-4)*round(sin(_t/16))
      rectfill(x+dx-bx,y+8-_t,x+dx-bx,y+8-_t,9)
  	end
  	rectfill(x+5+sx,y+1-sy,x+6+sx,y+2-sy,7)
  end 
}
--</red_bubble>--
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
  [64]=key,
  [80]=keydoor,
  [112]=sawblade,
  [113]=sawblade,
  [67]=red_bubble
  
}

-- [object functions]

function init_object(type,x,y,tile)
  --generate and check berry id
  local id=x..","..y..","..lvl_id
  if type.check_fruit and got_fruit[id] then 
    return 
  end

  local obj={
    type=type,
    collideable=true,
    spr=tile,
    flip=vector(),
    x=x,
    y=y,
    hitbox=rectangle(0,0,8,8),
    spd=vector(0,0),
    rem=vector(0,0),
    fruit_id=id,
    outline=true,
    draw_seed=rnd()
  }
  function obj.left() return obj.x+obj.hitbox.x end
  function obj.right() return obj.left()+obj.hitbox.w-1 end
  function obj.top() return obj.y+obj.hitbox.y end
  function obj.bottom() return obj.top()+obj.hitbox.h-1 end

  function obj.is_solid(ox,oy)
    for o in all(objects) do 
      if o!=obj and (o.solid_obj or o.semisolid_obj and not obj.objcollide(o,ox,0) and oy>0) and obj.objcollide(o,ox,oy)  then 
        return true 
      end 
    end 
    return (oy>0 and not obj.is_flag(ox,0,3) and obj.is_flag(ox,oy,3)) or  -- one way platform or
            obj.is_flag(ox,oy,0) -- solid terrain
  end
  
  function obj.is_flag(ox,oy,flag)
    local x1,x2,y1,y2=obj.left(),obj.right(),obj.top(),obj.bottom()
    for i=mid(0,lvl_w-1,(x1+ox)\8),mid(0,lvl_w-1,(x2+ox)/8) do
      for j=mid(0,lvl_h-1,(y1+oy)\8),mid(0,lvl_h-1,(y2+oy)/8) do
        local tile=tile_at(i,j)
        if flag>=0 then
          if fget(tile,flag) and (flag~=3 or j*8>y2) then
            return true
          end
        else
          if ({obj.spd.y>=0 and y2%8>=6,
            obj.spd.y<=0 and y1%8<=2,
            obj.spd.x<=0 and x1%8<=2,
            obj.spd.x>=0 and x2%8>=6})[tile-15] then
            return true
          end
        end
      end
    end
  end

  function obj.objcollide(other,ox,oy) 
    return other.collideable and
    other.right()>=obj.left()+ox and 
    other.bottom()>=obj.top()+oy and
    other.left()<=obj.right()+ox and 
    other.top()<=obj.bottom()+oy
  end
  function obj.check(type,ox,oy)
    for other in all(objects) do
      if other and other.type==type and other~=obj and obj.objcollide(other,ox,oy) then
        return other
      end
    end
  end

  function obj.player_here()
    return obj.check(player,0,0)
  end
  
  function obj.move(ox,oy,start)
    for axis in all{"x","y"} do
      obj.rem[axis]+=axis=="x" and ox or oy
      local amt=round(obj.rem[axis])
      obj.rem[axis]-=amt
      local upmoving=axis=="y" and amt<0
      local riding=not obj.player_here() and obj.check(player,0,upmoving and amt or -1)
      local movamt
      if obj.collides then
        local step=sign(amt)
        local d=axis=="x" and step or 0
        local p=obj[axis]
        for i=start,abs(amt) do
          if not obj.is_solid(d,step-d) then
            obj[axis]+=step
          else
            obj.spd[axis],obj.rem[axis]=0,0
            break
          end
        end
        movamt=obj[axis]-p --save how many px moved to use later for solids
      else
        movamt=amt 
        if (obj.solid_obj or obj.semisolid_obj) and upmoving and riding then 
          movamt+=obj.top()-riding.bottom()-1
          local hamt=round(riding.spd.y+riding.rem.y)
          hamt+=sign(hamt)
          if movamt<hamt then 
            riding.spd.y=max(riding.spd.y,0)
          else 
            movamt=0
          end
        end
        obj[axis]+=amt
      end
      if (obj.solid_obj or obj.semisolid_obj) and obj.collideable then
        obj.collideable=false 
        local hit=obj.player_here()
        if hit and obj.solid_obj then 
          hit.move(axis=="x" and (amt>0 and obj.right()+1-hit.left() or amt<0 and obj.left()-hit.right()-1) or 0, 
                  axis=="y" and (amt>0 and obj.bottom()+1-hit.top() or amt<0 and obj.top()-hit.bottom()-1) or 0,
                  1)
          if obj.player_here() then 
            kill_player(hit)
          end 
        elseif riding then 
          riding.move(axis=="x" and movamt or 0, axis=="y" and movamt or 0,1)
        end
        obj.collideable=true 
      end
    end
  end

  function obj.init_smoke(ox,oy) 
    init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),26)
  end

  add(objects,obj);

  (obj.type.init or time)(obj)

  return obj
end

function destroy_object(obj)
  del(objects,obj)
end

function kill_player(obj)
  sfx_timer=12
  sfx(2)
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
    -- <keydoor> --
    if f.type==fruit then 
      del(fruitrain,f)
    end 
    -- </keydoor> --
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
  foreach(objects,function(o)
    (o.type.end_init or time)(o)
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
  foreach(objects,function(obj)
    obj.move(obj.spd.x,obj.spd.y,obj.type==player and 0 or 1);
    (obj.type.update or time)(obj)
    obj.draw_seed=rnd()
  end)

  --move camera to player
  foreach(objects,function(obj)
    if obj.type==player or obj.type==player_spawn then
      move_camera(obj)
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
    p.x+=p.spd-cam_spdx
    p.y+=sin(p.off)-cam_spdy
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

function draw_object(obj)
  -- <red_bubble> --
  if not obj.invisible then 
    srand(obj.draw_seed);
    (obj.type.draw or draw_obj_sprite)(obj)
  end 
  -- </red_bubble> --
end

function draw_obj_sprite(obj)
  spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
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
    local offset=y+y_\32<2 and 8192 or 0
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
    local offset=y+y_\32<2 and 8192 or 0
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
000000006665666555000000000006664fff4fff4fff4fff4fff4fffd666666dd666666dd666066d000000000000000070000000000000000000000000000000
000000006765676566700000000777764444444444444444444444446dddddd56ddd5dd56dd50dd5007700000770070007000007000000000000000000000000
00000000677067706777700000000766000450000000000000054000666ddd55666d6d5556500555007770700777000000000000000000000000000000000000
0070007007000700666000000000005500450000000000000000540066ddd5d5656505d500000055077777700770000000000000000000000000000000000000
007000700700070055000000000006660450000000000000000005406ddd5dd56dd5065565000000077777700000700000000000000000000000000000000000
067706770000000066700000000777764500000000000000000000546ddd6d656ddd7d656d500565077777700000077000000000000000000000000000000000
5676567600000000677770000000076650000000000000000000000505ddd65005d5d65005505650070777000007077007000070000000000000000000000000
56665666000000006660000000000055000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000
5777777557777777777777777777777577cccccccccccccccccccc77577777755555555555555555555555555555555500000000000000000000000000000000
77777777777777777777777777777777777cccccccccccccccccc777777777775555555555555550055555555555555500000000000000000000000000000000
777c77777777ccccc777777ccccc7777777cccccccccccccccccc777777777775555555555555500005555555500005500000000000000000000000000000000
77cccc77777cccccccc77cccccccc7777777cccccccccccccccc7777777cc7775555555555555000000555555500005500000000000000000000000000000000
77cccc7777cccccccccccccccccccc777777cccccccccccccccc777777cccc775555555555550000000055555500005555555555000000000000000000000000
777cc77777cc77ccccccccccccc7cc77777cccccccccccccccccc77777cccc775555555555500000000005555500005555555555000000000000000000000000
7777777777cc77cccccccccccccccc77777cccccccccccccccccc77777c7cc775555555555000000000000555555555555555555000000000000000000000000
5777777577cccccccccccccccccccc7777cccccccccccccccccccc7777cccc775555555550000000000000055555555555555555000000000000000000000000
77cccc7777cccccccccccccccccccc77577777777777777777777775777ccc77cccccccc50000000000000055555555500000005000000000000000000000000
777ccc7777cccccccccccccccccccc77777777777777777777777777777cc777c77ccccc55000000000000555055555500000055000000000000000000000000
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc777c77cc7cc55500000000005555555005500000555000000000000000000000000
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777cccccccc55550000000055555555005500005555000000000000000000000000
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc77cccccccc55555000000555555555555555555555000000000000000000000000
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc77cc7ccccc55555500005555555505555555555555000000000000000000000000
777cc777777777777777777777777777777777777777777777777777777cc777ccccc7cc55555550055555555555555555555555000000000000000000000000
77cccc7757777777777777777777777557777777777777777777777557777775cccccccc55555555555555555555555555555555000000000000000000000000
0aaaaa0000aaa000000a000000666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a000a0000a0a000000a000006888860000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a909a0000a0a000000a000068887786000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09aaa900009a9000000a000068887786000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000a0000000a0000000a000068888886000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
099a0000009a0000000a000068888886000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
009a0000000a0000000a000006888860000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaa0000009a0000000a000000666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06d6667006666d600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6d666d6006d766d60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d66dd8d00d8dd66d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
676d6d6006d6d6660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
666d66655666d6760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6ddd6d5005d6ddd60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6d6ddd5555ddd6d60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
676d65500556d7660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
676d65500556d6760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66dd65000056dd660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6d8dd555555dd8d60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76dd6d6006d6dd660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
666d76d00d66d6660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66d8ddd00ddd8d670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
566d66d00d66d6650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05676d6006d676500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000700000076000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000760000067600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006760000006760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00065766076000670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777556067600560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00666565006765650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006658000676580000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000000000000000000000000002020202080808000000000000000000030303030303030304040404040000000303030303030303030404040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2b3b29000000000000000000002a3b2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3b290000000000000000000000002a3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2900000000000001000000000000002a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000132122222312000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000133132323312000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000001111111100000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2708000000000000000000202000082700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3708000000002000000000710000083700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000043000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222222223171720201717212222222223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3825252526000000000000242525253826000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000700003a672366522a642236220561201615376003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000029305000000a0051c00000000050051330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00 41424344
00 41424344
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 41424344
00 41424344
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 40404040
00 41424344
00 40404040
00 40404040
00 40404040
00 40404040
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 40404040
00 40404040

