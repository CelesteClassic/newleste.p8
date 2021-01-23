<<<<<<< site.p8
pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--newleste.p8 base cart

--original game by:
--matt thorson + noel berry

--based on taco's evercore,
--meep's smalleste
--and akliant's hex loading
--with help from gonengazit

-- [data structures]

function vector(x,y)
  return {x=x,y=y}
end

function rectangle(x,y,w,h)
  return {x=x,y=y,w=w,h=h}
end

-- [globals]

objects,got_fruit,
freeze,delay_restart,sfx_timer,music_timer,
ui_timer=
{},{},
0,0,0,0,-99

-- [entry point]

function _init()
  max_djump,deaths,frames,seconds,minutes,music_timer,time_ticking=1,0,0,0,0,0,true
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
    off=rnd(1),
    c=6+rnd(2),
  })
end

dead_particles={}

-- [player entity]

player={
  init=function(this) 
    this.grace,this.jbuffer=0,0
    this.djump=max_djump
    this.dash_time,this.dash_effect_time=0,0
    this.dash_target_x,this.dash_target_y=0,0
    this.dash_accel_x,this.dash_accel_y=0,0
    this.hitbox=rectangle(1,3,6,5)
    this.spr_off=0
    this.solids=true
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
    if spikes_at(this.left(),this.top(),this.right(),this.bottom(),this.spd.x,this.spd.y) or 
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
        got_fruit[f.level]=true
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
      1+(this.spd.x~=0 and h_input~=0 and this.spr_off%4 or 0) -- walk or stand
    
   	--move camera to player
   	--this must be before next_level
   	--to avoid loading jank
    move_camera(this)
    
    -- exit level off the top (except summit)
    if this.y<-4 and levels[lvl_id+1] then
      next_level()
    end
    
    -- was on the ground
    this.was_on_ground=on_ground
  end,
  
  draw=function(this)
    -- clamp in screen
  	if this.x<-1 or this.x>lvl_pw-7 then
   		this.x=clamp(this.x,-1,lvl_pw-7)
   		this.spd.x=0
  	end
    -- draw player hair and sprite
    set_hair_color(this.djump)
    draw_hair(this,this.flip.x and -1 or 1)
    draw_obj_sprite(this)
    unset_hair_color()
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

function draw_hair(obj,facing)
  local last=vector(obj.x+4-facing*2,obj.y+(btn(⬇️) and 4 or 3))
  for i,h in pairs(obj.hair) do
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    circfill(h.x,h.y,clamp(4-i,1,2),8)
    last=h
  end
end

function unset_hair_color()
  pal(8,8)
end

-- [other entities]

player_spawn={
  init=function(this)
    sfx(0)
    this.spr=3
    this.target=this.y
    this.y=min(this.y+48,lvl_ph)
		cam_x=clamp(this.x,64,lvl_pw-64)
		cam_y=clamp(this.y,64,lvl_ph-64)
    this.spd.y=-4
    this.state=0
    this.delay=0
    create_hair(this)
    --- <fruitrain> ---
    for i=1,#fruitrain do
      local f=init_object(fruit,this.x,this.y,fruitrain[i].spr)
      f.follow=true
      f.target=i==1 and this or fruitrain[i-1]
      f.r=fruitrain[i].r
      f.level=fruitrain[i].level
      fruitrain[i]=f
    end
    --- </fruitrain> ---
  end,
  update=function(this)
    -- jumping up
    if this.state==0 then
      if this.y<this.target+16 then
        this.state=1
        this.delay=3
      end
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
        --- <fruitrain> ---
        if (fruitrain[1]) fruitrain[1].target=p
        --- </fruitrain> ---
      end
    end
    move_camera(this)
  end,
  draw=function(this)
    set_hair_color(max_djump)
    draw_hair(this,1)
    draw_obj_sprite(this)
    unset_hair_color()
  end
}

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
		local dy=flr(this.dy)
		sspr(72,0,8,8-dy,this.x,this.y+dy)
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
      color(7)
      line(x,y+4,x+3,y+7)
      line(x+4,y+7,x+7,y+4)
      line(x+7,y+3,x+4,y)
      line(x+3,y,x,y+3)
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
      if this.check(player,0,-1) or this.check(player,-1,0) or this.check(player,1,0) then
        psfx(13)
        this.state,this.delay=1,15
        this.init_smoke()
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
    if this.state~=2 then
      spr(this.state==1 and 26-this.delay/5 or 23,this.x,this.y)
    end
  end
}

smoke={
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
  if_not_fruit=true,
  init=function(this)
    this.y_=this.y
    this.off=0
    this.follow=false
    this.tx=this.x
    this.ty=this.y
    this.level=lvl_id
    this.golden=this.spr==11
    if(this.golden and deaths>0) then
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
  if_not_fruit=true,
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
      local f=init_object(fruit, this.x, this.y,10)
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
    this.x-=2
    this.y-=4
    this.flash=0
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
    ?this.spr<=5 and this.spr.."000" or "1UP",this.x-2,this.y,7+this.flash%2
    --<fruitrain>--
  end
}

badeline={
  init=function(this) 
    for o in all(objects) do 
      if (o.type==player_spawn or o.type==badeline) and not o.tracked then 
        bade_track(this,o)
        break
      end 
    end 
    this.states={}
    this.timer=0
    
  end,
  update=function(this) 
    local tr,states=this.tracking,this.states
    if tr.type==player_spawn and tr.state==2 and tr.delay<0 then 
      for o in all(objects) do 
        if o.type==player then 
          bade_track(this,o)
          tr=o
          break
        end
      end  
    elseif tr.type==badeline and tr.timer<30 then 
      return 
    end 
    if this.timer<70 then 
      this.timer+=1
    end 
    local sm={}
    for s in all(this.smokes) do 
      add(sm,s)
    end 
    this.smokes={}
    add(states,{tr.x,tr.y,tr.flip.x,tr.spr or 1,sm})
    if #states>=30 then 
      this.x,this.y,this.flip.x,this.spr,sm=unpack(states[1])
      del(states,states[1])
      for s in all(sm) do 
        this.init_smoke(unpack(s))
      end
    end 
    if this.timer==30 then 
      create_hair(this)
    end
    local hit=this.check(player,0,0)
    if hit and this.timer>=70 then 
      kill_player(hit)
    end 
  end,
  draw=function(this)
    if this.timer>=30 then 
      pal(8,2)
      pal(15,6)
      pal(3,1)
      pal(1,8)
      pal(7,5)
      draw_hair(this,this.flip.x and -1 or 1)
      draw_obj_sprite(this)
      pal()
    end 
	end
}
function bade_track(this,o)
  o.tracked=true 
  this.tracking=o 
  this.hitbox=o.hitbox
  local f=o.init_smoke
  o.init_smoke=function(...)
    add(this.smokes,{...})
    f(...)
  end 
end 

fall_plat={
  init=function(this)
    while this.right()<lvl_pw-1 and tile_at(this.right()/8+1,this.y/8)==67 do 
      this.hitbox.w+=8
    end 
    while this.bottom()<lvl_ph-1 and tile_at(this.x/8,this.bottom()/8+1)==67 do 
      this.hitbox.h+=8
    end 
    this.solids=true
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
        spr(33,i,j,1.0,1.0,i~=x,j~=y)
      end 
    end 
    for i=x+8,r-8,8 do 
      spr(34,i,y)
      spr(50,i,d)
    end
    for i=y+8,d-8,8 do 
      spr(36,x,i)
      spr(38,r,i)
    end
    for i=x+8,r-8,8 do 
      for j=y+8,d-8,8 do 
        spr((i+j-x-y)%16==0 and 37 or 56,i,j)
      end 
    end 
  end

}
-- <touch_switch> --
touch_switch={
  init=function(this)
    this.off=2
  end,
  update=function(this)
    if this.player_here() and not this.collected then 
      this.collected=true 
      this.controller.missing-=1
      this.init_smoke()
    end 
  end,
  draw=function(this)
    this.off+=this.collected and 0.5 or 0.2
    this.off%=4
    palt(0,false)
    palt(8,true)
    if this.controller.active then 
      this.spr=68
      pal(12,2)
    else 
      this.spr=split"68,69,70,69"[1+flr(this.off)]
      this.flip.x=this.off>=3
      if this.collected then 
        pal(12,7)
      end 
    end 
    draw_obj_sprite(this)
    palt()
    pal()
  end
}
switch_block={
  init=function(this)
    this.solid_obj=true
    while this.right()<lvl_pw-1 and tile_at(this.right()/8+1,this.y/8)==72 do 
      this.hitbox.w+=8
    end 
    while this.bottom()<lvl_ph-1 and tile_at(this.x/8,this.bottom()/8+1)==87 do 
      this.hitbox.h+=8
    end 
    this.delay,this.end_delay=0,0
  end,
  end_init=function(this) 
    this.switches={}
    for o in all(objects) do 
      if o.type==touch_switch then 
        add(this.switches,o)
        o.controller=this 
      elseif o.spr==88 then 
        this.target=vector(o.x,o.y)
        destroy_object(o)
        this.dirx,this.diry=sign(o.x-this.x),sign(o.y-this.y)
        this.distx,this.disty=abs(o.x-this.x),abs(o.y-this.y)
      end 
    end
    this.missing=#this.switches 
  end,
  update=function(this)
    if this.missing==0 and not this.active then 
      this.active=true 
      for s in all(this.switches) do
        for i=1,2 do 
          s.init_smoke()
        end 
      end 
      this.delay=20
    end 

    if this.end_delay>0 then 
      this.end_delay-=1
      if this.end_delay==0 then 
        this.delay=10
        if this.dirx~=0 then 
          for i=0,this.hitbox.h-1,8 do 
            this.init_smoke(this.dirx==-1 and -6 or this.hitbox.w-2,i)
          end 
        end 
        if this.diry~=0 then 
          for i=0,this.hitbox.w-1,8 do 
            this.init_smoke(i,this.diry==-1 and -6 or this.hitbox.h-2)
          end 
        end 
      end 
    end 
    if this.delay>0 then 
      this.delay-=1
    elseif this.active then
      local dx,dy=this.target.x-this.x,this.target.y-this.y
      --local c=min(max(abs(dx),abs(dy)),16)/8
      local cx=min(abs(dx)+1,this.distx/4)/8
      local cy=min(abs(dy)+1,this.disty/4)/8
      --local c=clamp(abs(dx),abs(dy),16)/8
      --c=c==0.125 and 0.25 or c
      this.spd=vector(cx*sign(dx),cy*sign(dy))
      if dx==0 and dy==0 and not this.done then 
        this.end_delay=5
        this.done=true
      end 
      
    end 
  end, 
  draw=function(this)
    --TODO: put this into a function to save tokens with fall_plat
    local x,y=this.x,this.y
    if this.delay>3 then 
      x+=rnd(2)-1
      y+=rnd(2)-1 
    end 
    
    local r,d=x+this.hitbox.w-8,y+this.hitbox.h-8 
    for i=x,r,r-x do 
      for j=y,d,d-y do 
        spr(71,i,j,1.0,1.0,i~=x,j~=y)
      end 
    end 
    for i=x+8,r-8,8 do 
      spr(72,i,y)
      spr(72,i,d,1.0,1.0,false,true)
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

    spr(88,x+this.hitbox.w/2-4,y+this.hitbox.h/2-4)
  end 
}
-- <touch_switch> --
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
  [66]=fall_plat,
  [68]=touch_switch,
  [71]=switch_block,
  -- <touch_switch> --
  [88]={}
  -- <touch_switch> --
}

-- [object functions]

function init_object(type,x,y,tile)
  if type.if_not_fruit and got_fruit[lvl_id] then
    return
  end

  local obj={
    type=type,
    collideable=true,
    solids=false,
    spr=tile,
    flip=vector(),
    x=x,
    y=y,
    hitbox=rectangle(0,0,8,8),
    spd=vector(0,0),
    rem=vector(0,0),
  }
  function obj.left() return obj.x+obj.hitbox.x end
  function obj.right() return obj.left()+obj.hitbox.w-1 end
  function obj.top() return obj.y+obj.hitbox.y end
  function obj.bottom() return obj.top()+obj.hitbox.h-1 end

    -- <solids> --
  function obj.is_solid(ox,oy)
    for o in all(objects) do 
      if (o!=obj and o.solid_obj or o.semisolid_obj and not obj.objcollide(o,ox,0) and oy>0) and obj.objcollide(o,ox,oy)  then 
        return true 
      end  
    end 
    return (oy>0 and not obj.is_flag(ox,0,3) and obj.is_flag(ox,oy,3)) or  -- one way platform or
            obj.is_flag(ox,oy,0) -- solid terrain
  end
  -- </solids> --
  
  function obj.is_flag(ox,oy,flag)
    for i=max(0,(obj.left()+ox)\8),min(lvl_w-1,(obj.right()+ox)/8) do
      for j=max(0,(obj.top()+oy)\8),min(lvl_h-1,(obj.bottom()+oy)/8) do
        if fget(tile_at(i,j),flag) then
          return true
        end
      end
    end
  end
  -- <solids> --
  function obj.objcollide(other,ox,oy) 
    return other.collideable and
    other.right()>=obj.left()+ox and 
    other.bottom()>=obj.top()+oy and
    other.left()<=obj.right()+ox and 
    other.top()<=obj.bottom()+oy
  end
  -- </solids> --
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
  
  --<solids>--
  function obj.move(ox,oy,start)
    for axis in all({"x","y"}) do
      obj.rem[axis]+=axis=="x" and ox or oy
      local amt=round(obj.rem[axis])
      obj.rem[axis]-=amt
      local upmoving=axis=="y" and amt<0
      local riding=not obj.player_here() and obj.check(player,0,upmoving and amt or -1)
      local movamt
      if obj.solids then
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
        if upmoving and riding then 
          movamt+=obj.top()-riding.bottom()-1
          local hamt=round(riding.spd.y+riding.rem.y)
          hamt+=sign(hamt)
          if movamt<hamt then 
            riding.spd.y=0
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
          if(obj.player_here()) then 
            kill_player(hit)
          end 
        elseif riding then 
          riding.move(axis=="x" and movamt or 0, axis=="y" and movamt or 0,1)
        end
        obj.collideable=true 
      end
    end
  end
  --</solids>--

  function obj.init_smoke(ox,oy) 
    init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),26)
  end

  add(objects,obj)

  if obj.type.init then
    obj.type.init(obj)
  end

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
  dead_particles={}
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

function load_level(lvl)
  has_dashed=false
  
  --remove existing objects
  foreach(objects,destroy_object)
  
  --reset camera speed
  cam_spdx=0
	cam_spdy=0
		
  local diff_room=lvl_id~=lvl
  
		--set level index
  lvl_id=lvl
  
  --set level globals
  local tbl=get_lvl()
  --<badeline>--
  lvl_x,lvl_y,lvl_w,lvl_h,bad_num=tbl[1],tbl[2],tbl[3]*16,tbl[4]*16,tbl[5] or 0
  --</badeline>--
  lvl_pw=lvl_w*8
  lvl_ph=lvl_h*8
  
  
  --reload map
  --time drawing setup
  if diff_room then reload() end 
  ui_timer=5
  
  --chcek for hex mapdata
  if diff_room and get_data() then
  	--replace old rooms with data
  	for i=0,tbl[3]-1 do
      for j=0,tbl[4]-1 do
        replace_room(lvl_x+i,lvl_y+j,get_data()[i*tbl[4]+j+1])
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
  foreach(objects,function(o)
    (o.type.end_init or stat)(o)
  end)
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
    obj.move(obj.spd.x,obj.spd.y,obj.type==player and 0 or 1)
    if obj.type.update then
      obj.type.update(obj)
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
  local camx=round(cam_x)-64
  local camy=round(cam_y)-64
  camera(camx,camy)

  --local token saving
  local xtiles=lvl_x*16
  local ytiles=lvl_y*16
  
  -- draw bg color
  cls()

  -- bg clouds effect
  foreach(clouds, function(c)
    c.x+=c.spd-cam_spdx
    rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+16-c.w*0.1875+camy,1)
    if c.x>128 then
      c.x=-c.w
      c.y=rnd(120)
    end
  end)

		-- draw bg terrain
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,4)
		
  -- draw terrain
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,2)
  
  -- draw objects
  foreach(objects, draw_object)

  -- draw platforms
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,8)
  
  -- particles
  foreach(particles, function(p)
    p.x+=p.spd-cam_spdx
    p.y+=sin(p.off)-cam_spdy
    p.y%=128
    p.off+=min(0.05,p.spd/32)
    rectfill(p.x+camx,p.y+camy,p.x+p.s+camx,p.y+p.s+camy,p.c)
    if p.x>132 then 
      p.x=-4
      p.y=rnd128()
   	elseif p.x<-4 then
     	p.x=128
     	p.y=rnd128()
    end
  end)
  
  -- dead particles
  foreach(dead_particles, function(p)
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
  		draw_time(camx+4,camy+4)
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

function clamp(val,a,b)
  return max(a,min(b,val))
end

function appr(val,target,amount)
  return val>target and max(val-amount,target) or min(val+amount,target)
end

function sign(v)
  return v~=0 and sgn(v) or 0
end

function maybe()
  return rnd(1)<0.5
end


function tile_at(x,y)
  return mget(lvl_x*16+x,lvl_y*16+y)
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

-->8
--scrolling level stuff

--level table
--strings follow this format:
--"x,y,w,h,badeline num"
levels={
	"0,0,1,1",
  "1,0,3,1"
}

--mapdata table
--rooms separated by commas
mapdata={
}

function get_lvl()
	return split(levels[lvl_id])
end

function get_data()
	return split(mapdata[lvl_id],",",false)
end

--not using tables to conserve tokens
cam_x=0
cam_y=0
cam_spdx=0
cam_spdy=0
cam_gain=0.25

function move_camera(obj)
  --set camera speed
  cam_spdx=cam_gain*(4+obj.x+0*obj.spd.x-cam_x)
  cam_spdy=cam_gain*(4+obj.y+0*obj.spd.y-cam_y)

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  if cam_x<64 or cam_x>lvl_pw-64 then
    cam_spdx=0
    cam_x=clamp(cam_x,64,lvl_pw-64)
  end
  if cam_y<64 or cam_y>lvl_ph-64 then
    cam_spdy=0
    cam_y=clamp(cam_y,64,lvl_ph-64)
  end
end

--replace mapdata with hex
function replace_room(x,y,room)
 for y_=0,511,32 do
  for x_=1,32,2 do
   local idx=x_+y_
   local hex=sub(room,idx,idx+1)
   poke((y<2 and 8192 or 0)+x*16+y*2048+y_*4+x_/2, "0x"..hex)
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

--returns mapdata string of level
--printh(get_room(),"@clip")
function get_room(x,y)
  local reserve=""
  local offset=4096+(y<2 and 4096 or 0)
  y=y%2
  for y_=1,32,2 do
    for x_=1,32,2 do
      reserve=reserve..num2hex(peek(offset+x*16+y*2048+(y_-1)*64+x_/2))
    end
  end
  return reserve
end

--convert mapdata to memory data
function num2hex(number)
 local resultstr=""
 while number>0 do
  local remainder=1+number%16
  number\=16
  resultstr=sub("0123456789abcdef",remainder,remainder)..resultstr
 end
 return #resultstr==0 and "00" or #resultstr==1 and "0"..resultstr or resultstr
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
0000000000000000577777777777777788cccc8888cccc8888cccc88522222222222222200000000000000000000000000000000000000000000000000000000
000000000000000077777777777777778c0000c88c0000c88c0000c8222111111111111100000000000000000000000000000000000000000000000000000000
00000000000000007777ccccccccccccc00cc00cc00c100cc00cc00c221111111111111100000000000000000000000000000000000000000000000000000000
0000000000000000777ccc7cccccccccc0c00c0cc010c10cc00cc00c211111111111111100000000000000000000000000000000000000000000000000000000
000000000000000077ccccccccccccccc0cccc0cc01cc10cc00cc00c211111111111111100000000000000000000000000000000000000000000000000000000
000000000000000077c7ccccccccccccc00cc00cc00c100cc00cc00c211111111111111100000000000000000000000000000000000000000000000000000000
000000000000000077cccc7ccccccccc8c0000c88c0000c88c0000c8211111111111111100000000000000000000000000000000000000000000000000000000
000000000000000077cccccccccccccc88cccc8888cccc8888cccc88211111111111111100000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000021111111111cc11100000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000002111111111cccc1100000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000211111111cc11cc100000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000211111111cc11cc100000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000211111111cccccc100000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000211111111cccccc100000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000002111111111cccc1100000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000021111111111cc11100000000000000000000000000000000000000000000000000000000
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
29000044000000013d0000000044002a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000132122222312000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000133132323312000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000001111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0047484800000000000000004243430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0057000000000000000000004300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0057000000000000000000004300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0058000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222222222222317172122222222222223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3825252525252600002425252525253826000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

=======
pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--newleste.p8 base cart

--original game by:
--matt thorson + noel berry

--based on taco's evercore,
--meep's smalleste
--and akliant's hex loading
--with help from gonengazit

-- [data structures]

function vector(x,y)
  return {x=x,y=y}
end

function rectangle(x,y,w,h)
  return {x=x,y=y,w=w,h=h}
end

-- [globals]

objects,got_fruit,
freeze,delay_restart,sfx_timer,music_timer,
ui_timer=
{},{},
0,0,0,0,-99

-- [entry point]

function _init()
  max_djump,deaths,frames,seconds,minutes,music_timer,time_ticking=1,0,0,0,0,0,true
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
    off=rnd(1),
    c=6+rnd(2),
    -- <wind> --
    wspd=0,
    -- </wind> --
  })
end

dead_particles={}

-- [player entity]

player={
  init=function(this) 
    this.grace,this.jbuffer=0,0
    this.djump=max_djump
    this.dash_time,this.dash_effect_time=0,0
    this.dash_target_x,this.dash_target_y=0,0
    this.dash_accel_x,this.dash_accel_y=0,0
    this.hitbox=rectangle(1,3,6,5)
    this.spr_off=0
    this.solids=true
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
    if spikes_at(this.left(),this.top(),this.right(),this.bottom(),this.spd.x,this.spd.y) or 
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
        got_fruit[f.level]=true
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
          -- <cloud> --
          local cloudhit=this.check(bouncy_cloud,0,1)
          if cloudhit and cloudhit.time>0.5 then
          	this.spd.y=-3
          else
          	this.spd.y=-2
          	if cloudhit then 
          		cloudhit.time=0.25
							cloudhit.state=1
          	end
          end
          -- </cloud> --
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

      -- <green_bubble> --
      if this.djump>0 and dash or this.do_dash then
        this.do_dash=false
      -- </green_bubble> -- 
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
      1+(this.spd.x~=0 and h_input~=0 and this.spr_off%4 or 0) -- walk or stand
    
   	--move camera to player
   	--this must be before next_level
   	--to avoid loading jank
    move_camera(this)
    
    -- exit level off the top (except summit)
    if this.y<-4 and levels[lvl_id+1] then
      next_level()
    end
    
    -- was on the ground
    this.was_on_ground=on_ground
  end,
  
  draw=function(this)
    -- clamp in screen
  	if this.x<-1 or this.x>lvl_pw-7 then
   		this.x=clamp(this.x,-1,lvl_pw-7)
   		this.spd.x=0
  	end
    -- draw player hair and sprite
    set_hair_color(this.djump)
    draw_hair(this,this.flip.x and -1 or 1)
    draw_obj_sprite(this)
    unset_hair_color()
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

function draw_hair(obj,facing)
  local last=vector(obj.x+4-facing*2,obj.y+(btn(⬇️) and 4 or 3))
  for i,h in pairs(obj.hair) do
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    circfill(h.x,h.y,clamp(4-i,1,2),8)
    last=h
  end
end

function unset_hair_color()
  pal(8,8)
end

-- [other entities]

player_spawn={
  init=function(this)
    sfx(0)
    this.spr=3
    this.target=this.y
    this.y=min(this.y+48,lvl_ph)
		cam_x=clamp(this.x,64,lvl_pw-64)
		cam_y=clamp(this.y,64,lvl_ph-64)
    this.spd.y=-4
    this.state=0
    this.delay=0
    create_hair(this)
    --- <fruitrain> ---
    for i=1,#fruitrain do
      local f=init_object(fruit,this.x,this.y,fruitrain[i].spr)
      f.follow=true
      f.target=i==1 and this or fruitrain[i-1]
      f.r=fruitrain[i].r
      f.level=fruitrain[i].level
      fruitrain[i]=f
    end
    --- </fruitrain> ---
  end,
  update=function(this)
    -- jumping up
    if this.state==0 then
      if this.y<this.target+16 then
        this.state=1
        this.delay=3
      end
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
        --- <fruitrain> ---
        if (fruitrain[1]) fruitrain[1].target=p
        --- </fruitrain> ---
      end
    end
    move_camera(this)
  end,
  draw=function(this)
    set_hair_color(max_djump)
    draw_hair(this,1)
    draw_obj_sprite(this)
    unset_hair_color()
  end
}

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
		local dy=flr(this.dy)
		sspr(72,0,8,8-dy,this.x,this.y+dy)
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
      color(7)
      line(x,y+4,x+3,y+7)
      line(x+4,y+7,x+7,y+4)
      line(x+7,y+3,x+4,y)
      line(x+3,y,x,y+3)
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
      if this.check(player,0,-1) or this.check(player,-1,0) or this.check(player,1,0) then
        psfx(13)
        this.state,this.delay=1,15
        this.init_smoke()
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
    if this.state~=2 then
      spr(this.state==1 and 26-this.delay/5 or 23,this.x,this.y)
    end
  end
}

smoke={
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
  if_not_fruit=true,
  init=function(this)
    this.y_=this.y
    this.off=0
    this.follow=false
    this.tx=this.x
    this.ty=this.y
    this.level=lvl_id
    this.golden=this.spr==11
    if(this.golden and deaths>0) then
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
  if_not_fruit=true,
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
      local f=init_object(fruit, this.x, this.y,10)
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
    this.x-=2
    this.y-=4
    this.flash=0
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
    ?this.spr<=5 and this.spr.."000" or "1UP",this.x-2,this.y,7+this.flash%2
    --<fruitrain>--
  end
}

-- <cloud> --
bouncy_cloud = {
	init=function(this)
		this.break_timer=0
		this.time=0.25
		this.state=0
		this.start=this.y
    this.hitbox=rectangle(0,0,16,0)
		this.semisolid_obj=true
	end,
	update=function(this)
		--fragile cloud override
		if this.break_timer==0 then
			this.collideable=true
		else
			this.break_timer-=1
			if this.break_timer==0 then
				this.init_smoke()
				this.init_smoke(8)
			end
		end
		
    local hit=this.check(player,0,-1)
    --idle position
		if this.state==0 and this.break_timer==0 and hit and hit.spd.y>=0 then
			this.state=1
		end
		
		if this.state==1 then
			--in animation
			this.spd.y=-2*sin(this.time)
			if hit and this.time>=0.85 then 
        hit.spd.y=min(hit.spd.y,-1.5)
        hit.grace=0
			end
      
			
			this.time+=0.05
			
      
			if this.time>=1 then
				this.state=2
			end
		elseif this.state==2 then
			--returning to idle position
      if this.spr==65 and this.break_timer==0 then
				this.collideable=false
				this.break_timer=60
				this.init_smoke()
				this.init_smoke(8)
			end
			
      this.spd.y=sign(this.start-this.y)
			if this.y==this.start then
				this.time=0.25
				this.state=0
        this.rem=vector(0,0)
      end
        
		end
	end,
	draw=function(this)
		if this.break_timer==0 then
			if this.spr==65 then
				pal(7,14)
				pal(6,2)
			end
      spr(64,this.x,this.y-1,2.0,1.0)
			pal()
		end
	end
}
-- </cloud> --

fake_wall={
  init=function(this)
    this.solid_obj=true
    local match 
    for i=this.y,lvl_ph,8 do 
      if tile_at(this.x/8,i/8)==83 then 
        match=i 
        break 
      end 
    end 
    this.ph=match-this.y+8
    this.x-=8
    this.has_fruit=this.check(fruit,0,0)
    destroy_object(this.has_fruit)
  end,
  update=function(this)
    this.hitbox=rectangle(-1,-1,18,this.ph+2)
    local hit = this.player_here()
    if hit and hit.dash_effect_time>0 then
      hit.spd=vector(sign(hit.spd.x)*-1.5,-1.5)
      hit.dash_time=-1
      sfx_timer=20
      sfx(16)
      destroy_object(this)
      this.init_smoke_hitbox()
      if this.has_fruit then
        init_object(fruit,this.x+4,this.y+4,10)
      end
    end
    this.hitbox=rectangle(0,0,16,this.ph)
  end,
  draw=function(this)
    spr(66,this.x,this.y,2,1)
    for i=8,this.ph-16,8 do
      spr(82,this.x,this.y+i,2,1)
    end
    spr(66,this.x,this.y+this.ph-8,2,1,true,true)
  end
}

--- <snowball> ---
snowball = {
  init=function(this) 
    this.spd.x=-3
    this.sproff=0
  end,
  update=function(this)
    local hit=this.player_here()
    this.sproff=(1+this.sproff)%8
    this.spr=68+(this.sproff\2)%2
    local b=this.sproff>=4
    this.flip=vector(b,b)
    if hit then
      if hit.y<this.y then
        hit.djump=max_djump
        hit.spd.y=-2
        psfx(3) --default jump sfx, maybe replace this?
        hit.dash_time=-1
        this.init_smoke()
        destroy_object(this)
      else
        kill_player(hit)
      end
    end
    if this.x<=-8 then
      destroy_object(this)
    end
  end
}
snowball_controller={
  init=function(this)
    this.t,this.spr=0,0
  end,
  update=function(this)
    this.t=(this.t+1)%60
    if this.t==0 then 
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
  init=function(this)
    this.t=0
    this.timer=0
    this.shake=0
    this.dead_timer=0
    this.hitbox=rectangle(0,0,12,12)
  end,
  update=function(this)
    local hit=this.player_here()
    if hit and not this.invisible then
      hit.invisible=true
      hit.spd=vector(0,0)
      hit.rem=vector(0,0)
      hit.dash_time=0
      if this.timer==0 then
        this.timer=1
        this.shake=5
      end
      hit.x,hit.y=this.x+1,this.y+1
      this.timer+=1
      if this.timer>10 or btnp(❎) then
        hit.invisible=false
        hit.djump=max_djump+1
        hit.do_dash=true        
        this.invisible=true
        this.timer=0
      end
    elseif this.invisible then
      this.dead_timer+=1
      if this.dead_timer==60 then
        this.dead_timer=0
        this.invisible=false
        this.init_smoke()
      end
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
  init=function(this)
    this.dir=this.spr==71 and -1 or 1
    this.solid_obj=true
    this.solids=true

    while this.right()<lvl_pw-1 and tile_at(this.right()/8+1,this.y/8)==73 do 
      this.hitbox.w+=8
    end 
    while this.bottom()<lvl_ph-1 and tile_at(this.x/8,this.bottom()/8+1)==73 do 
      this.hitbox.h+=8
    end 
    this.break_timer,this.death_timer=0,0
    this.start_x,this.start_y=this.x,this.y
  end,
  update=function(this)
    if this.death_timer>0 then 
      this.death_timer-=1
      if this.death_timer==0 then 
        this.x,this.y,this.spd=this.start_x,this.start_y,vector(0,0)
        if this.player_here() then 
          this.death_timer=1
          return
        else 
          this.init_smoke_hitbox()
          this.break_timer=0
          this.collideable=true
          this.active=false
        end
      else
        return 
      end 
    end 

    if this.spd.x==0 and this.active then 
      this.break_timer+=1
    else 
      this.break_timer=0
    end 
    if this.break_timer==16 then 
      this.init_smoke_hitbox()
      this.death_timer=60
      this.collideable=false
    end

    this.spd=vector(this.active and this.dir or 0,0)
    local hit=this.check(player,0,-1)
    if hit then 
      this.spd=vector(this.dir,btn(⬇️) and 1 or btn(⬆️) and not hit.is_solid(0,-1) and -1 or 0)
      this.active=true
    end
  end,
  draw=function(this)
    if (this.death_timer>0) return 

    local x,y=this.x,this.y
    pal(13,this.active and 11 or 13)
    local shake=this.break_timer>8
    if shake then 
      x+=rnd(2)-1
      y+=rnd(2)-1
      pal(13,8)
    end
    local r,b=x+this.hitbox.w-1,y+this.hitbox.h-1
    rectfill(x,y,r,b,1)
    rect(x+1,y+2,r-1,b-1,13)
    line(x+3,y+2,r-3,y+2,1)
    local mx,my=x+this.hitbox.w/2,y+this.hitbox.h/2
    spr(shake and 72 or this.spd.y~=0 and 73 or 71,mx-4,my+(this.break_timer<=8 and this.spd.y<0 and -3 or -4),1.0,1.0,this.dir==-1,this.spd.y>0)
    if this.hitbox.h==8 and shake then 
      rect(mx-3,my-3,mx+2,my+2,1)
    end
    line(x+1,y,r-1,y,13)
    if not this.check(player,0,-1) and not this.is_solid(0,-1) then
      line(x+2,y-1,r-2,y-1,13)
    end
    pal()
  end

}

bg_flag={
  init=function(this) 
    this.t=0
    this.wind=prev_wind_spd
    this.wvel=0
    this.ph=8
    while not this.is_solid(0,this.ph) and this.y+this.ph<lvl_ph do 
      this.ph+=8 
    end 
    this.h=1
    this.w=2
  end, 
  update=function(this)
	  this.wvel+=0.01*(wind_spd+sgn(wind_spd)*0.4-this.wind)
	  this.wind+=this.wvel
	  this.wvel/=1.1
  end,
  draw=function(this)
	  line(this.x, this.y, this.x, this.y+this.ph-1, 4)
    for x=this.w*8-1,0,-1 do
      local off = x~=0 and sin((x+this.t)/(abs(wind_spd)>0.5 and 10 or 16))*this.wind or 0
      local ang = 1-(this.wind/4)
      local xoff = sin(ang)*x
      local yoff = cos(ang)*x
      tline(this.x+xoff,this.y+off+yoff,this.x+xoff,this.y+this.h*8+off+yoff,lvl_x*16+this.x/8+x/8,lvl_y*16+this.y/8,0,1/8)
    end
    this.t+=1
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

function init_object(type,x,y,tile)
  if type.if_not_fruit and got_fruit[lvl_id] then
    return
  end

  local obj={
    type=type,
    collideable=true,
    solids=false,
    spr=tile,
    flip=vector(),
    x=x,
    y=y,
    hitbox=rectangle(0,0,8,8),
    spd=vector(0,0),
    rem=vector(0,0),
  }
  function obj.left() return obj.x+obj.hitbox.x end
  function obj.right() return obj.left()+obj.hitbox.w-1 end
  function obj.top() return obj.y+obj.hitbox.y end
  function obj.bottom() return obj.top()+obj.hitbox.h-1 end

    -- <solids> --
  function obj.is_solid(ox,oy)
    for o in all(objects) do 
      if o!=obj and (o.solid_obj or o.semisolid_obj and not obj.objcollide(o,ox,0) and oy>0) and obj.objcollide(o,ox,oy)  then 
        return true 
      end 
    end 
    return (oy>0 and not obj.is_flag(ox,0,3) and obj.is_flag(ox,oy,3)) or  -- one way platform or
            obj.is_flag(ox,oy,0) -- solid terrain
  end
  -- </solids> --
  
  function obj.is_flag(ox,oy,flag)
    for i=max(0,(obj.left()+ox)\8),min(lvl_w-1,(obj.right()+ox)/8) do
      for j=max(0,(obj.top()+oy)\8),min(lvl_h-1,(obj.bottom()+oy)/8) do
        if fget(tile_at(i,j),flag) then
          return true
        end
      end
    end
  end
  -- <solids> --
  function obj.objcollide(other,ox,oy) 
    return other.collideable and
    other.right()>=obj.left()+ox and 
    other.bottom()>=obj.top()+oy and
    other.left()<=obj.right()+ox and 
    other.top()<=obj.bottom()+oy
  end
  -- </solids> --
  function obj.check(type,ox,oy)
    for other in all(objects) do
      if other and other.type==type and other~=obj and obj.objcollide(other,ox,oy) then
        return other
      end
    end
  end
  -- </solids> --
  function obj.player_here()
    return obj.check(player,0,0)
  end
  
  --<solids>--
  function obj.move(ox,oy,start)
    for axis in all({"x","y"}) do
      -- <wind> --
      obj.rem[axis]+=axis=="x" and ox+(obj.type==player and obj.dash_time<=0 and wind_spd or 0) or oy
      -- </wind> --
      local amt=round(obj.rem[axis])
      obj.rem[axis]-=amt
      local upmoving=axis=="y" and amt<0
      local riding=not obj.player_here() and obj.check(player,0,upmoving and amt or -1)
      local movamt
      if obj.solids then
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
          if(obj.player_here()) then 
            kill_player(hit)
          end 
        elseif riding then 
          riding.move(axis=="x" and movamt or 0, axis=="y" and movamt or 0,1)
        end
        obj.collideable=true 
      end
    end
  end
  --</solids>--

  function obj.init_smoke(ox,oy) 
    init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),26)
  end

  -- <fake_wall> <arrow_platform>

  -- made into function because of repeated usage
  -- can be removed if doesn't save tokens
  function obj.init_smoke_hitbox()
    for ox=0,obj.hitbox.w-8,8 do 
      for oy=0,obj.hitbox.h-8,8 do 
        obj.init_smoke(ox,oy) 
      end 
    end 
  end 
  -- </fake_wall> </arrow_platform>
  add(objects,obj)

  if obj.type.init then
    obj.type.init(obj)
  end

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
  dead_particles={}
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

function load_level(lvl)
  has_dashed=false
  
  --remove existing objects
  foreach(objects,destroy_object)
  
  --reset camera speed
  cam_spdx=0
	cam_spdy=0
		
  local diff_room=lvl_id~=lvl
  
		--set level index
  lvl_id=lvl
  
  prev_wind_spd=wind_spd or 0
  --set level globals
  local tbl=get_lvl()
  lvl_x,lvl_y,lvl_w,lvl_h,wind_spd=tbl[1],tbl[2],tbl[3]*16,tbl[4]*16,tbl[5] or 0
  lvl_pw=lvl_w*8
  lvl_ph=lvl_h*8
  
  
  --reload map
  --timer setup
  if diff_room then reload() end 
  ui_timer=5
  
  --chcek for hex mapdata
  if diff_room and get_data() then
  	--replace old rooms with data
  	for i=0,tbl[3]-1 do
      for j=0,tbl[4]-1 do
        replace_room(lvl_x+i,lvl_y+j,get_data()[i*tbl[4]+j+1])
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
  foreach(objects,function(o)
    (o.type.end_init or stat)(o)
  end)
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
    obj.move(obj.spd.x,obj.spd.y,obj.type==player and 0 or 1)
    if obj.type.update then
      obj.type.update(obj)
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
  local camx=round(cam_x)-64
  local camy=round(cam_y)-64
  camera(camx,camy)

  --local token saving
  local xtiles=lvl_x*16
  local ytiles=lvl_y*16
  
  -- draw bg color
  cls()

  -- bg clouds effect
  foreach(clouds, function(c)
    c.x+=c.spd-cam_spdx
    rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+16-c.w*0.1875+camy,1)
    if c.x>128 then
      c.x=-c.w
      c.y=rnd(120)
    end
  end)

		-- draw bg terrain
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,4)
		
  -- draw terrain
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,2)
  
  -- draw flags
  foreach(objects,function(o)
    if o.type==bg_flag then
      draw_object(o)
    end
  end)
  -- draw objects
  foreach(objects,function(o)
    if o.type~=bg_flag then
      draw_object(o)
    end
  end)

  -- draw platforms
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,8)
  
  -- particles
  foreach(particles, function(p)
    p.y+=sin(p.off)-cam_spdy
    p.y%=128
    p.off+=min(0.05,p.spd/32)
    -- <wind> --
      p.wspd=appr(p.wspd,wind_spd*12,0.5)
      if wind_spd!=0 then 
        p.x += p.wspd - cam_spdx 
        line(p.x+camx,p.y+camy,p.x+p.wspd*-1.5+camx,p.y+camy,p.c)  
      else 
        p.x+=p.spd+p.wspd-cam_spdx
        rectfill(p.x+camx,p.y+camy,p.x+p.s+camx+p.wspd*-1.5,p.y+p.s+camy,p.c)
      end
    -- </wind> --
    if p.x>132 then 
      p.x=-4
      p.y=rnd128()
   	elseif p.x<-4 then
     	p.x=128
     	p.y=rnd128()
    end
  end)
  
  -- dead particles
  foreach(dead_particles, function(p)
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
  		draw_time(camx+4,camy+4)
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
  -- <green_bubble> --
  if not obj.invisible then 
    (obj.type.draw or draw_obj_sprite)(obj)
  end 
  -- </green_bubble> --
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

function clamp(val,a,b)
  return max(a,min(b,val))
end

function appr(val,target,amount)
  return val>target and max(val-amount,target) or min(val+amount,target)
end

function sign(v)
  return v~=0 and sgn(v) or 0
end

function maybe()
  return rnd(1)<0.5
end


function tile_at(x,y)
  return mget(lvl_x*16+x,lvl_y*16+y)
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

-->8
--scrolling level stuff

--level table
--strings follow this format:
--"x,y,w,h,wind speed"
levels={
	"0,0,1,1,0",
  "1,0,3,1,-0.6"
}

--mapdata table
--rooms separated by commas
mapdata={
}

function get_lvl()
	return split(levels[lvl_id])
end

function get_data()
	return split(mapdata[lvl_id],",",false)
end

--not using tables to conserve tokens
cam_x=0
cam_y=0
cam_spdx=0
cam_spdy=0
cam_gain=0.25

function move_camera(obj)
  --set camera speed
  cam_spdx=cam_gain*(4+obj.x+0*obj.spd.x-cam_x)
  cam_spdy=cam_gain*(4+obj.y+0*obj.spd.y-cam_y)

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  if cam_x<64 or cam_x>lvl_pw-64 then
    cam_spdx=0
    cam_x=clamp(cam_x,64,lvl_pw-64)
  end
  if cam_y<64 or cam_y>lvl_ph-64 then
    cam_spdy=0
    cam_y=clamp(cam_y,64,lvl_ph-64)
  end
end

--replace mapdata with hex
function replace_room(x,y,room)
 for y_=0,511,32 do
  for x_=1,32,2 do
   local idx=x_+y_
   local hex=sub(room,idx,idx+1)
   poke((y<2 and 8192 or 0)+x*16+y*2048+y_*4+x_/2, "0x"..hex)
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

--returns mapdata string of level
--printh(get_room(),"@clip")
function get_room(x,y)
  local reserve=""
  local offset=4096+(y<2 and 4096 or 0)
  y=y%2
  for y_=1,32,2 do
    for x_=1,32,2 do
      reserve=reserve..num2hex(peek(offset+x*16+y*2048+(y_-1)*64+x_/2))
    end
  end
  return reserve
end

--convert mapdata to memory data
function num2hex(number)
 local resultstr=""
 while number>0 do
  local remainder=1+number%16
  number\=16
  resultstr=sub("0123456789abcdef",remainder,remainder)..resultstr
 end
 return #resultstr==0 and "00" or #resultstr==1 and "0"..resultstr or resultstr
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
00077077700777005777755777577775007777000077770000bbbb00111111111111111111111111cccccccc0000000000000000000000000000000000000000
0777777677777770777777777777777707767770077767700b3333b0111111111d1111d1111dddd14ccc11cccccc000000000000000000000000000000000000
77666666677677777777cc7777cc77777777777767777777b333773b1111d11111d11d111111ddd14c111cc111cccccc00000000000000000000000000000000
7677766676666677777cccccccccc7777677777767767767b333773b1111dd11111dd1111111ddd14c1cc111cccccc0000000000000000000000000000000000
066666666666666077cccccccccccc777776777667777777b333333b1dddddd1111dd111111d11d14c1c1cc00000000000000000000000000000000000000000
000000000000000057cc77ccccc7cc757777776666777777b333333b1111dd1111d11d1111d111114c111ccc0000000000000000000000000000000000000000
0000000000000000577c77ccccccc77507777660066777700b3333b01111d1111d1111d1111111114ccc111cccc0000000000000000000000000000000000000
0000000000000000777cccccccccc777006666000066770000bbbb00111111111111111100000000ccccccccc000000000000000000000000000000000000000
0000000000000000777cccccccccc777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000077cccccccccccc77000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000077cccc7ccccccc77000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000577cccccccccc775000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000577cccccc77cc775000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000077ccccccc77ccc77000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000077cc7ccccccccc77000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000777cccccccccc777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
0000000000133132323312000000000000000000202020202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000001111111100000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2708000000000000000000000000082700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3708000000004300000000460000083700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000474949000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000a0000000000490000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000004000005300004100004a4b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f0000000000000000000000000a43004849490000004a4b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000009090000000000005301000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222222223171720201717212222222223000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3825252526000000000000242525253826202020202020202020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

>>>>>>> ridge.p8
