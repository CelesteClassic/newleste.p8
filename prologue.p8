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
  max_djump,deaths,frames,seconds,minutes,music_timer,time_ticking,berry_count=stat(6) == "epilogue" and 2 or 0,0,0,0,0,0,true,0
  music(0,0,7)
  load_level(stat(6) == "epilogue" and 2 or 1)
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
        psfx(22)
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
          psfx(18)
          this.jbuffer=0
          this.grace=0
          this.spd.y=-2
          this.init_smoke(0,4)
        else
          -- wall jump
          local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
          if wall_dir~=0 then
            psfx(19)
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
    
      if this.djump>0 and dash then
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
        psfx(20)
        freeze=2
        -- dash target speeds and accels
        this.dash_target_x=2*sign(this.spd.x)
        this.dash_target_y=(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y)
        this.dash_accel_x=this.spd.y==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()
        this.dash_accel_y=this.spd.x==0 and 1.5 or 1.06066017177
      elseif this.djump<=0 and dash then
        -- failed dash smoke
        psfx(21)
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
  pal(8,djump==1 and 8 or djump==2 and 14 or 12)
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
    sfx(15)
    this.spr=3
    this.target=this.y
    this.y=min(this.y+48,lvl_ph)
		cam_x,cam_y=mid(this.x,64,lvl_pw-64),mid(this.y,64,lvl_ph-64)
    this.spd.y=-4
    this.state=0
    this.delay=0
    create_hair(this)
    this.djump=max_djump
    --- <fruitrain> ---
    for i=1,#fruitrain do
      local f=init_object(fruit,this.x,this.y,fruitrain[i].spr)
      f.follow=true
      f.target=i==1 and this or fruitrain[i-1]
      f.r=fruitrain[i].r
      f.fruit_id=fruitrain[i].fruit_id
      fruitrain[i]=f
    end
    --- </fruitrain> ---
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
          sfx(16)
        end
      end
    -- landing and spawning player object
    elseif this.state==2 then
      this.delay-=1
      this.spr=6
      if this.delay<0 then
        destroy_object(this)
        local p=init_object(player,this.x,this.y)
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

fall_plat={
  init=function(this)
    while this.right()<lvl_pw-1 and tile_at(this.right()/8+1,this.y/8)==67 do 
      this.hitbox.w+=8
    end 
    while this.bottom()<lvl_ph-1 and tile_at(this.x/8,this.bottom()/8+1)==67 do 
      this.hitbox.h+=8
    end 
    this.collides=true
    this.solid_obj=true
    this.timer=0
  end,
  update=function(this) 
    if not this.state and this.check(player,0,-1) then
      this.state = 0  -- shake
      this.timer = 10
    elseif this.timer>0 then 
      this.timer-=1
      if this.timer==0 then 
        this.state=this.finished and 2 or 1
        this.spd.y=0.4
      end 
    elseif this.state==1 then 
      if this.spd.y==0 then 
        this.state=0
        for i=0,this.hitbox.w-1,8 do 
          this.init_smoke(i,this.hitbox.h-2)
        end
        this.timer=6
        this.finished=true
      end
      this.spd.y=appr(this.spd.y,4,0.4)
    end 
  end,
  draw=function(this)
    local x,y=this.x,this.y
    if this.state==0 then 
      x+=rnd(2)-1
      y+=rnd(2)-1
    end
    local r,d=x+this.hitbox.w-8,y+this.hitbox.h-8 
    for i=x,r,r-x do 
      for j=y,d,d-y do 
        spr(80,i,j,1.0,1.0,i~=x,j~=y)
      end 
    end 
    for i=x+8,r-8,8 do 
      spr(81,i,y)
      spr(81,i,d,1,1,false,true)
    end
    for i=y+8,d-8,8 do 
      spr(83,x,i)
      spr(83,r,i,1,1,true)
    end
    for i=x+8,r-8,8 do 
      for j=y+8,d-8,8 do 
        spr((i+j-x-y)%16==0 and 84 or 85,i,j)
      end 
    end 
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
      --todo: fix this if needed
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
    ?this.spr<=5 and this.spr.."000" or "1up",this.x-4,this.y-4,7+this.flash%2
    --<fruitrain>--
  end
}


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
  [66]=fall_plat
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
  palt(0,false)
  palt(8,true)
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
  srand(obj.draw_seed);
  (obj.type.draw or draw_obj_sprite)(obj)
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
	"0,0,8,1",
	"5,3,3,1"
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
888888886665666555888888888886664fff4fff4fff4fff4fff4fffd666666dd666666dd666066d000000000000000070000000d666666d0ff40ff077777770
888888886765676566788888888777764444444444444444444444446dddddd56ddd5dd56dd50dd50077000007700700070000076dddddd54ff44ff477777777
88888888677867786777788888888766000450000000000000054000666ddd55666d6d5556500555007770700777000000000000666ddd554fff444477777777
8878887887888788666888888888885500450000000000000000540066ddd5d5656505d50000005507777770077000000000000066ddd5d50440044467776777
887888788788878855888888888886660450000000000000000005406ddd5dd56dd50655650000000777777000007000000000006ddd5dd54444444066667770
867786778888888866788888888777764500000000000000000000546ddd6d656ddd7d656d5005650777777000000770000000006ddd6d654ff44f446dccc766
5676567688888888677778888888876650000000000000000000000505ddd65005d5d6500550565007077700000707700700007085ddd6584fff4ff4ccccccc6
56665666888888886668888888888855000000000000000000000000000000000000000000000000000000007000000000000000888888880ff40ff4c6111660
7ccccccc0777777777777777777777700ff45ff4fff04ff04ff04ff00ff40000cc00000000000000000004448888888888888888077777770777777700000000
77ccccc07777777777677767777777774fff4ff44ff4fff44ffffff4ffff40001c00cc0000000000044044448888888888888888777777777777777700000000
76ccccc07677667777766677777777774ff44f444f44ff444fff4ffffff444000000ccc000000000444444448888888888888838777777777777777700000000
667cccc07766677777776d6767776777444444404444f4400fff4ff44444000000001ccc000000004444044088888888888888b8777677767776777600000000
6ccccccc77d67777dd77dcd76666777004400440440444400444044004ff40000cc01ccc00000000444400008888b88888888b38077766667777666600000000
7ccccccc7dcd667dccddcccd6d677766fff400000000440000444ff4fff444001ccc11c10000000004440000888b888883888b88667cccd6667cccd600000000
7ccccccc7cccd66cccccccccccc66d66ff4404000000000004404fffff4440001ccc01110000000000440044838b883888b8b3886ccccccc6ccccccc00000000
77cccccc7ccccccc0ccc00cccccd6dd64440000000000000000004ff0440000011c00000000000000040004483833838883833880661116c1661116c00000000
ccccccc777cccccc00cccccccccccc7744400000000000000000044400004ff00ccc10000cccccc0044440004400044000000005000000000000000000000000
cccccc7777cccccccccccccccccccc77ff44040000000440004044ff0004ffff1cc11000cccccccc444440000444444000000055000000000000000000000000
cccc777767c7cccccccccccccccc7c67fff400000440444000004fff00444fff111100001ccccccc444400004444444000000555000000000000000000000000
00ccccc76ccccccccccccc6cccccccc60440044044444f400440044000044ff40011cc101cc1ccc1004444404444444400005555000000000000000000000000
0ccccc776ccccccccc6cccccccccccc6444444404ff4440004444444004f4440001cccc01cc11c10004444404444444055555555000000000000000000000000
ccccc67766ccccc6cccccccc6ccccc664ff44f444fff4f4444f44ff4004444ff0111cc1011111100044444404444444055555555000000000000000000000000
ccccc6676ccc66c6666ccc666c66ccc64fff4ff4ffff4ff44ff4fff400044fff1c11110001101000044444004444440055555555000000000000000000000000
cccccc670666666606666666666666660ff40ff444ff0ff44ff04ff0000044ffcc10000000000000044000000440400055555555000000000000000000000000
00000000000000000777777777777777888888880000000000000000888558888885b38888888888888888888888888811111111111111111155111151111115
00000000000000007777777777677767888888880000000000000000885dd588885dd38888888888888888888888888815118811111111111555885151111155
0000000000000000767766777776667788888888000000000000000085d66d5885d66b3888888888888888888888888811188881115111115888888585111158
00000000000000007766677777776d678888888800000000000000005d6666d53d66663588888888888888888888888811188881111111111888888555111155
000000000000000077d67777dd77dcd7888888880000000000000000165555613655553188888888888888888888888811158881111155111888888551151115
00000000000000007dcd667dccddcccd888877880000000000000000165aa561b653856188885555555555558888888815515551111155111888885185111158
00000000000000007cccd66ccccccccc877766780000000000000000816aa618316b861888855151cc5c551c5888888815511111151111111588855185515588
00000000000000007ccccccc0ccc00cc766776770000000000000000816aa618816388888855c1511c51c551c588888811111111111111111155511188855588
0777777777777777777777707ccccccccc0000000cccccc088144188816aa618816888888551115111511c551158888888855585555555555588555888855888
77777777776777677777777777ccccc01c00cc00cccccccc88114188816556188165588855555555555555555555555588555551551155115155155588511558
76776677777666777777777776ccccc00000ccc01ccccccc8814118881d66d1881d66d889ddddddddd5dddddd577dd7585155155155115511111111585511118
7766677777776d6767776777667cccc000001ccc1cc1ccc18813413881555518815555189d000dd55d555dd00077557555111155155115511151111555111115
77d67777dd77dcd7666677706ccccccc0cc01ccc1cc11c1088b4438888144188881441886000006666566600000dddd555111111111511151111555555155111
7dcd667dccddcccd6d6777667ccccccc1ccc11c11111110088343b888814418888114188d00600dddd5ddd00600dddd511111115115511111511555581155158
7cccd66cccccccccccc66d667ccccccc1ccc01110110100088134188881411888814118850000055555555000005555851888111111115111111155885111158
7ccccccc0ccc00cccccd6dd677cccccc11c00000000000003814b138881441888814418888000888000888800080008851888111111111111111115885111155
d666666dd666666dd666666dd666666d881441144114418883133138881441880000000088888814418888880000000085111111111111115111115888555588
6dddddd56dddddd56dddddd56ddddd55888144144144188888b4b388881441880000000088888814418888880000000055511111111111111115515555115555
666ddd55666ddd5d6ddddd556dddd5d5888814441441888888144338881141880000000088888811418888880000000055111111111111111115511511115515
66ddd5d566ddd5ddddddd5d56ddd5dd5888881444418888888134b38881411880000000088888814118888880000000055111111111111111111111511111158
6ddd5dd56ddd5ddddddd5dd56ddddd65888888144188888888344388881441880000000088888811418888880000000085111151111111111111155511151158
6ddd6d65dd5ddddd5ddddd65666dd65588888814118888888813b388881441880000000088888814418888880000000085111111111111111151155811111155
85ddd658d5ddddd5ddddd65566dddd658888881141888888881b3188881441880000000088888814418888880000000081111111111111111111155815551155
88888888dddddd5dddddddd56ddddd55888888144188888888334188881441880000000088888811418888880000000011111111111111111111155855885588
00000000d66ddddddddddd656dddd5d588888814418888888b314188881441888814418888888814418888880000000055111111111111111111115888558555
000000006dddddddddddddd56ddd5dd5888888114188888883141188881441888811418888888814418888880000000051551111111111111111115855115111
00000000666ddd5ddddddd556dddddd5888888144188888883143188881141888814418888888814418888880000000011551511511111151111115555115511
0000000066ddd5ddddddd5d56ddd6d6d8888881441888888881b4138881441888814418888888814118888880000000051111111111111151111111551111111
000000006ddd5ddddddd5dd585ddd658888888144188888888344138881441888814418888888811418888880000000011111111111115511111115551111111
000000006ddd6d6d6ddd6d65888888888888881141888888881313b8881441888811118888888814418888880000000085511551111115511111155851111551
000000006d6dd66dd66dd6d588888888888888141188888881663618881411888166661888888814418888880000000085551551111511111115888885511511
0000000085dddddddddddd5888888888888888144188888816636661881141881666666188888814418888880000000088855555558885551588888888855855
88888888888888888888888888888888888888888888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
88888888888888888888888888888888888888888788877888888888888888881200000000000000000000000000000000000000000000000000000000000000
88888888888888888888888888888888888888887777777788888888888888880000000000000000000000000000000000000000000000000000000000000000
88888888888888888888888888888888888888887ffff77788888888888888881200000000000000000000000000000000000000000000000000000000000000
888888888888888888888888877888888888888881ff1f7888888888888888880000000000000000000000000000000000000000000000000000000000000000
88888888888888888888888877678888888888888fffff8888888888888888881200000000000000000000000000000000000000000000000000000000000000
8888888888888888888888886776778888888888f833338888888888888888880000000000000000000000000000000000000000000000000000000000000000
88888888888888888888888877777678888888884868868888888888888888881200000000000000000000000000000000000000000000000000000000000000
88888888888888888977999992992777866688882191142988888888888888880000000000000000000000000000000000000000000000000000000000000000
88888888888888877767292222992267755588882791177988888888888888881200000000000000000000000000000000000000000000000000000000000000
888888888888877777769221129921777ddd88887777777788888888888888880000000000000000000000000000000000000000000000000000000000000000
88888888888876776229221112222177975588887ffff77788888888888888881200000000000000000000000000000000000000000000000000000000000000
888888888888776222922114444444474292888821ff1f7988888888888888880000000000000000000000000000000000000000000000000000000000000000
88888888888722222922144444444447441928881fffff2988888888888888881200000000000000000000000000000000000000000000000000000000000000
8888888888727222922144477774444744412288f433332988888888888888880000000000000000000000000000000000000000000000000000000000000000
88888888822262292214447777677444444411284767462988888888888888881200000000000000000000000000000000000000000000000000000000000000
88888888999999991111111171111111111111198888888821911129888888880000000000000000000000000000000000000000000000000000000000000000
88888888899142921444444444444444444444198888888821111119888888881200000000000000000000000000000000000000000000000000000000000000
88888888829112921111111111111111111111198888888821171719888888880000000000000000000000000000000000000000000000000000000000000000
88888888829142921144444414444444111444298888888811119911888888881200000000000000000000000000000000000000000000000000000000000000
88888888829142921444444444444444444444298888888811177711888888880000000000000000000000000000000000000000000000000000000000000000
88888888829142921449999444444444499994298888888811177719888888881200000000000000000000000000000000000000000000000000000000000000
88888888829142921121911111111111219111298888888841177719888888880000000000000000000000000000000000000000000000000000000000000000
8888888882914292142191144999944421911429888888881199d999888888881200000000000000000000000000000000000000000000000000000000000000
88888899999999921421911441111944219114298888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
88889922222992221421911441444944219114298888888888888888888888881200000000000000000000000000000000000000000000000000000000000000
88992222299221121121911111444244219114298888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
99999999922914421421911441444944219114298888888888888888888888881200000000000000000000000000000000000000000000000000000000000000
82911111192914421429999441444944299994298888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
82914444192914421411111441444944111114298888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
82914114192914421444777741444944444444298888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
82914444192914421447677677744944477744298888888888888888888888880000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000000000000000000000008400
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000192939490000000000000000000000000000000000000000000000000000000000000000000000000000008500
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000001a2a3a4a0000000000000000000000000000000000000000000000000000000000000000000000000000006500
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000044000b1b2b3b59c200000000000000000000000000000000000000000000000000000000000000000000000000006642
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000122222222222225262e50000000000000000000000000000000000000000000000000000000000000000000000006772
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000283828382a2a3b373d6d5e5440000b20000004400000000440000000000000044000000000000000000001044c542a2
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000008392929292929292a252522222225252222222f11626360606063616263600000636162600000000000000422252a392
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000929292929292929292a3a282839382928293030017273700000037172737000000371727000000000000007293a29292
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000929292929292929292929292929292929283330046560000000000465600000000004656000000000000004353929292
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000929292929292929292929292929292928203e600475700000000004757000000000047570000000000000000c643a292
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000092929292929292929292929292929292b363e60096a6000000000096a6000000000096a60000000000000000c7d672a3
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000929292929292929292929292929292a373d6e60097a7000000000097a7000000000097a7000000000000000000c643a3
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000929292929292929292929292929292a273d6e70096a6000000000096a60000e5000096a6000000000000000000c7d672
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000009292929292929292929292929292929273e6000097a7000000000097a700c5e6000097a700000000000000000000c772
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000929292929292929292929292929292a373e7000096a60000c5000096a600c6d6e50096a6000000000000000000000072
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000929292929292929292929292929292a27300000097a700c5e6000097a7c5d6d6e60097a7000000000000000000000072
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
0000000000000000000000000000000002020202080808000000000000030303030303030303030303030302020303000303030303030303030303030400000000000000040404040404040404040404000000000303040404040404040404040303030304040404010404040404040403030303040404040404040404040404
0404040404040404000000000000000004040404040404040000000000000000040404040404040400000000000000000404040404040404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
00000000000000000000000000272a2929292929292a37000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000083000000000000000000000000000000000000000000000000000000000000000000000000000000004800
00000000000000000000000000273b352a292929292936000000000000000000000000000000000000000000000000000000000000000000000000000000000000002122230000000000000000000000000000919293940000000000000000000000000000000000000000000000000000000000000000000000000000005800
0000000000000000000000000034366d202829293a3700000000000000000000000000000000000000000000000000000000000000000000000000000000000000002028370000000000000000470000000000a1a2a3a40000000000000000000000000000000000000000000000000000000000000000000000000000005600
00000000000000000000000000007c6d3139382928370000000000000000000000000000000000000000000000000000000000000000000000000000000000000000203b3600000000000000005700004400b0b1b2b3952c00000000000000000000000000000000000000000000000000000000000000000000000000006624
000000000000000000005f2b0000007c7d3132323233000000000000000000000000000000000000000000000000000000000000000000162123000047000000000020370000000000000000006700002122222222222225265e0000000000000000000000000000000000000000000000000000000000000000000000007627
0000000000000000002425265e0000000042434343430000000000000000000000000000000000000000000000000000000000000000000020300000570000000000203700000000000000000077005c20382838282a3a3b376d5d5e4400002b00000044000000004400000000000000440000000000000000000000445c242a
00000000000000005c3435366e000000004300000000000000000000004800000000000000000000000000000044000000000000000000002028230067000000000020370000000000002c002b785c2138292929292929292a252522222225252222221f61626360606063616263000060636162000000000000002422253a29
0000000047005c5d6d7d7e006c5d5e00004300000000000000000000005800000000000000000000000000000021222300000000000015162038300077000000000031330000000000002425252222282929292929292929293a2a283839282928393000717273000000737172730000007371720000000000000027392a2929
0000000057006c6d7e0000007c6d6e0000000000000000000000000000560000000000480000000000000000002039300000000000000000203930447800000000000000000000000000273b2a283829292929292929292929292929292929292938330064650000000000646500000000006465000000000000003435292929
00000000675c6d7e00000000006c6d5e00000000000000000000000000660000000000580000000000000015162028330000000044000000002028222223000000000000000000001516273a292929292929292929292929292929292929292928306e007475000000000074750000000000747500000000000000006c342a29
494a4b00776c6e44000000002b6c6d7e0000000000000000000000002b76000000000056000000000000000000203000000021222223005c5d203838393000000000000021221f5d5e2b272a29292929292929292929292929292929292929293b366e00696a0000000000696a0000000000696a00000000000000007c6d273a
595a5b01782422230000000024267e0000002b2c002b0000000000002426000000000066000000000000002b0020305e000031383930006c6d20382928305e000000004420306d7d6d242a29292929292929292929292929292929292929293a376d6e00797a0000000000797a0000000000797a0000000000000000006c343a
25252525222228330000000027372b00001e25252526000000002c0027375e002b2c2b760044000000001e252238306d5d5e00202833006c6d20392938306d5d5e00212239376e0a6c342a2a292929292929292929292929292929292929292a376d7e00696a0000000000696a00005e0000696a0000000000000000007c6d27
2a3a3b2a2839300000002c00273a26000000273b2a365e00001624223a376e001e25252222221f00005c6d273828336d6d6d5d273000007c6d342a2929306d6d2d22393838377c5d6d342a3a2929292929292929292929292929292929292929376e0000797a0000000000797a005c6e0000797a000000000000000000007c27
2929292929383000000024252a3b3700005c272a376d6d5e0000342a3a366d5d6d272a3a283000005c6d6d273a376d6d7d6d7d27370000007c7d273a38307d6d6d2028292a36007c6d6d272a292929292929292929292929292929292929293a377e0000696a00005c0000696a006c6d5e00696a000000000000000000000027
29292929292830000000273a292a37005c6d273a376d6d6e00000027376d6d6d6d273a29383000006c6d6d272a376d6e007c7e27370000000000272a2830006c6d272a3b370000006c6d273b292929292929292929292929292929292929292a37000000797a005c6e0000797a5c6d6d6e00797a000000000000000000000027
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002100000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002100000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002100000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002100000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002100000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002100000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002100000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002100000000000000000000000000000000000000000000000000000000000000
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

