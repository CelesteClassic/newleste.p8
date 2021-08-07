pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- newleste.p8 base cart

-- original game by
-- matt thorson and noel berry

-- globals --
-------------

-- <fruitrain> --
full_restart=false
-- </fruitrain> --
room = { x=0, y=0 }
objects = {}
freeze=0
shake=0
will_restart=false
delay_restart=0
got_fruit={}
has_dashed=false
sfx_timer=0
pause_player=false

time_ticking=true

node = 1
nodes = {}

target_x = 0
target_y = 0

bg_col=0
cloud_col=1

bg_music=0
current_music=0

scrlevel_1={
--insert mapdata here in strings
}

reserve_levels={}

--not using tables to conserve tokens
cam_x=0
cam_y=0
cam_spdx=0
cam_spdy=0
cam_gain=0.25

function bounce(this,obj,spd,set_target)
 local angle=atan2(obj.x-this.x,obj.y-this.y)
 local ca=-cos(angle)
 local sa=-sin(angle)
 this.spd.x=spd*ca
 this.spd.y=spd*sa
 if set_target then
  this.dash_accel.x=abs(1.5*ca)
  this.dash_accel.y=abs(1.5*sa)
  this.dash_target.x=2*ca
  this.dash_target.y=2*sa
 end
end

function glide_to(obj,x,y,gain)
  obj.spd.x=gain*(x-obj.x)
  obj.spd.y=gain*(y-obj.y)
end

function get_length(x,y)
  --input coords of long levels
  if x==1 and y==0 then
    return 2
  else
    return 1
  end
end

function get_height(x,y)
  --input coords of tall levels
  if x==1 and y==0 then
    return 2
  else
    return 1
  end
end

function get_data(x,y)
  --input tables of scrolling levels
  if x==1 and y==0 then
  --return scrlevel_1
  end
end

function level_length()
  return get_length(room.x,room.y)
end

function level_height()
  return get_height(room.x,room.y)
end

function level_data()
  return get_data(room.x,room.y)
end

function level_tlength()
  return level_length()*16
end

function level_theight()
  return level_height()*16
end

function level_plength()
  return level_length()*128
end

function level_pheight()
  return level_height()*128
end

function setuparea(level)
  if level==0 then
    bg_col=0
    cloud_col=1

    bg_music=30
  else
    bg_col=0
    cloud_col=1

    bg_music=0
  end
end

k_left=0
k_right=1
k_up=2
k_down=3
k_jump=4
k_dash=5

-- entry point --
-----------------

function _init()
  begin_game()
end

function begin_game()
  got_fruit = {}
  for i=0,29 do
    add(got_fruit,false) end
  frames=0
  deaths=0
  max_djump=1
  frames=0
  centiseconds=0
  seconds=0
  minutes=0
  load_room(0,0)
end

function level_index()
  return room.x%8+room.y*8
end

function is_summit()
  return level_index()==30
end

-- effects --
-------------

clouds = {}
for i=0,16 do
  add(clouds,{
      x=rnd(128),
      y=rnd(128),
      spd=1+rnd(4),
      w=32+rnd(32)
    })
end

particles = {}
for i=0,24 do
  add(particles,{
      x=rnd(128),
      y=rnd(128),
      s=0+flr(rnd(5)/4),
      spd=0.25+rnd(5),
      off=rnd(1),
      c=6+flr(0.5+rnd(1))
    })
end

dead_particles = {}

-- player entity --
-------------------

player={
  init=function(this)
    this.p_jump=false
    this.p_dash=false
    this.grace=0
    this.jbuffer=0
    this.djump=max_djump
    this.dash_time=0
    this.dash_effect_time=0
    this.dash_target={x=0,y=0}
    this.dash_accel={x=0,y=0}
    this.hitbox={x=1,y=3,w=6,h=5}
    this.spr_off=0
    this.was_on_ground=false
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
    local input=btn(k_right) and 1 or (btn(k_left) and -1 or 0)

    -- spike collision
    if spikes_at(this.x+this.hitbox.x,this.y+this.hitbox.y,this.hitbox.w,this.hitbox.h,this.spd.x,this.spd.y) then
      kill_player(this) end

    -- bottom death
    if this.y>level_pheight() then
      kill_player(this)
    end

    --ground and terrain checks
    local on_ground=this.is_solid(0,1)

    -- <fruitrain> --
    if on_ground then
      this.berry_timer+=1
    else
      this.berry_timer=0
      this.berry_count=0
    end

    local fr
    local fr1=fruitrain[1]
    local fr2=fruitrain[2]
    if fr1 then
      if fr1.golden and fr2 then
        fr=fr2
      elseif fr1.golden==nil or level_index()==30 then
        fr=fr1
      end
    end

    if this.berry_timer>5 and fr then
      -- to be implemented:
      -- save berry
      -- save golden
      got_fruit[fr.level+1]=true
      init_object(lifeup, fr.x, fr.y)
      del(fruitrain, fr)
      destroy_object(fr)
      this.berry_timer=-5
      this.berry_count+=1
      if (fruitrain[1]) fruitrain[1].target=get_player()
    end
    -- </fruitrain> --

    -- landing particles
    if on_ground and not this.was_on_ground then
      init_object(smoke,this.x,this.y+4)
    end

    --jump input
    local jump=btn(k_jump) and not this.p_jump
    this.p_jump=btn(k_jump)

    --jump buffer
    if jump then
      this.jbuffer=4
    elseif this.jbuffer>0 then
      this.jbuffer-=1
    end

    --dash input
    local dash = btn(k_dash) and not this.p_dash
    this.p_dash = btn(k_dash)

    --grace frames + dash restore
    if on_ground then
      this.grace=6
      if this.djump<max_djump then
        psfx(7)
        this.djump=max_djump
      end
    elseif this.grace > 0 then
      this.grace-=1
    end

    --dash effect timer
    --for dash-triggered events,
    --such as berry blocks
    this.dash_effect_time-=1

    --dash startup period
    --accel to dash target speed
    if this.dash_time>0 then
      init_object(smoke,this.x,this.y)
      this.dash_time-=1
      this.spd.x=appr(this.spd.x,this.dash_target.x,this.dash_accel.x)
      this.spd.y=appr(this.spd.y,this.dash_target.y,this.dash_accel.y)
    else
      --horizontal movement
      local maxrun=1
      local accel=on_ground and 0.6 or 0.4
      local deccel=0.15

      -- set x speed
      this.spd.x=abs(this.spd.x)<=maxrun and
      appr(this.spd.x,input*maxrun,accel) or
      appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)

      --facing direction
      if this.spd.x!=0 then
        this.flip.x=(this.spd.x<0)
      end

      --vertical movement
      local maxfall=2
      local gravity=abs(this.spd.y)>0.15 and 0.21 or 0.105

      -- wall slide
      if input!=0 and this.is_solid(input,0) then
        maxfall=0.4
        --wallslide particles
        if rnd(10)<2 then
          init_object(smoke,this.x+input*6,this.y)
        end
      end

      --apply gravity
      if not on_ground then
        this.spd.y=appr(this.spd.y,maxfall,gravity)
      end

      -- jump
      if this.jbuffer>0 then
        if this.grace>0 then
          -- normal jump
          psfx(3)
          this.jbuffer=0
          this.grace=0
          this.spd.y=-2
          init_object(smoke,this.x,this.y+4)
        else
          -- wall jump
          local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
          if wall_dir!=0 then
            psfx(4)
            this.jbuffer=0
            this.spd.y=-2
            this.spd.x=-wall_dir*(maxrun+1)
            --walljump particles
            init_object(smoke,this.x+wall_dir*6,this.y)
          end
        end
      end

      -- dash
      local d_full=5
      local d_half=3.5355339059

      if this.djump>0 and dash then
        init_object(smoke,this.x,this.y)
        this.djump-=1
        this.dash_time=4
        has_dashed=true
        this.dash_effect_time=10

        --vertical input
        local v_input=(btn(k_up) and -1 or (btn(k_down) and 1 or 0))

        -- calculate dash speeds
        this.spd.x=input!=0 and
        input*(v_input!=0 and d_half or d_full) or
        (v_input!=0 and 0 or (this.flip.x and -1 or 1))
        this.spd.y=v_input!=0 and v_input*(input!=0 and d_half or d_full) or 0

        --effects
        psfx(5)
        freeze=2
        shake=6

        -- dash target speeds and accels
        this.dash_target.x=2*sign(this.spd.x)
        this.dash_target.y=(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y)
        this.dash_accel.x=this.spd.y==0 and 1.5 or 1.06066017177
        this.dash_accel.y=this.spd.x==0 and 1.5 or 1.06066017177
      elseif this.djump<=0 and dash then
        -- failed dash smoke
        psfx(6)
        init_object(smoke,this.x,this.y)
      end
    end

    -- animation
    this.spr_off+=0.25
    if not on_ground then
      -- wallslide or midair
      this.spr=this.is_solid(input,0) and 5 or 3
    elseif btn(k_down) then
      -- crouch
      this.spr=6
    elseif btn(k_up) then
      --look up
      this.spr=7
    else
      -- walk or stand
      this.spr=1+(this.spd.x~=0 and (btn(k_left) or btn(k_right)) and this.spr_off%4 or 0)
    end

    -- exit level from top
    if this.y<-4 and not is_summit() then
      next_room()
    end

    -- was on the ground
    this.was_on_ground=on_ground
    move_camera(this)
  end,
  draw=function(this)
    -- clamp in screen
    if this.x<-1 or this.x>(level_plength())-7 then
      this.x=clamp(this.x,-1,(level_plength())-7)
      this.spd.x=0
    end

    -- draw player hair + sprite
    
    if not anxiety_check then
     set_hair_color(this.djump)
    end
    
    draw_hair(this,this.flip.x and -1 or 1)
    spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
    unset_hair_color()
  end
}

psfx=function(num)
  if sfx_timer<=0 then
    sfx(num)
  end
end

create_hair=function(obj)
  obj.hair={}
  for i=0,4 do
    add(obj.hair,{x=obj.x,y=obj.y,size=max(1,min(2,3-i))})
  end
end

set_hair_color=function(djump)
  pal(8,(djump==1 and 8 or djump==2 and (7+flr((frames/3)%2)*4) or 12))
end

draw_hair=function(obj,facing)
  local last={x=obj.x+4-facing*2,y=obj.y+(btn(k_down) and 4 or 3)}
  foreach(obj.hair,function(h)
      h.x+=(last.x-h.x)/1.5
      h.y+=(last.y+0.5-h.y)/1.5
      circfill(h.x,h.y,h.size,8)
      last=h
    end)
end

unset_hair_color=function()
  pal(8,8)
end

player_spawn = {
  init=function(this)
    sfx(0)
    this.spr=3
    this.target= {x=this.x,y=this.y}
    this.y=min(this.y+48,(level_pheight()))
    cam_x=this.x
    cam_y=this.y
    this.spd.y=-4
    this.state=0
    this.delay=0
    this.solids=false
    create_hair(this)
    --- <fruitrain> ---
    for i=1,#fruitrain do
      local f=init_object(fruit,this.x,this.y,fruitrain[i].golden and 14 or 12)
      f.follow=true
      f.target=i==1 and get_player() or fruitrain[i-1]
      f.r=i==1 and 12 or 8
      f.level=fruitrain[i].level
      fruitrain[i]=f
    end
  --- </fruitrain> ---
  end,
  update=function(this)
    -- jumping up
    if this.state==0 then
      if this.y < this.target.y+16 then
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
        elseif this.y>this.target.y then
          -- clamp at target y
          this.y=this.target.y
          this.spd={x=0,y=0}
          this.state=2
          this.delay=5
          shake=5
          init_object(smoke,this.x,this.y+4)
          sfx(1)
        end
      end
    -- landing
    elseif this.state==2 then
      this.delay-=1
      this.spr=6
      if this.delay<0 then
        destroy_object(this)
        local p=init_object(player,this.x,this.y)
        --- <fruitrain> ---
        local f=fruitrain[1]
        if (f) f.target=p
      --- </fruitrain> ---
      end
    end

    move_camera(this)
  end,
  draw=function(this)
				set_hair_color(max_djump)
    draw_hair(this,1)
    
    spr(this.spr,this.x,this.y)
    unset_hair_color()
  end
}

spring = {
  init=function(this)
    this.hide_in=0
    this.hide_for=0
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for<=0 then
        this.spr=18
        this.delay=0
      end
    elseif this.spr==10 then
      local hit = this.collide(player,0,0)
      if hit and hit.spd.y>=0 then
        this.spr=11
        hit.y=this.y-4
        hit.spd.x*=0.2
        hit.spd.y=-3
        hit.djump=max_djump
        this.delay=10
        init_object(smoke,this.x,this.y)

        -- breakable below us
        local below=this.collide(fall_floor,0,1)
        if below then
          break_fall_floor(below)
        end

        psfx(14)
      end
    elseif this.delay>0 then
      this.delay-=1
      if this.delay<=0 then
        this.spr=10
      end
    end
    -- begin hiding
    if this.hide_in>0 then
      this.hide_in-=1
      if this.hide_in<=0 then
        this.hide_for=60
        this.spr=0
      end
    end
  end
}

side_spring = {
  init=function(this)
    this.hide_in=0
    this.hide_for=0
    this.delay=0
    this.dir=0
    this.dir=this.spr==8 and 1 or -1
    this.spr=8
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for<=0 then
        this.spr=8
        this.delay=0
      end
    elseif this.spr==8 then
      local hit = this.collide(player,0,0)
      if hit and this.dir*hit.spd.x<=0 then
        this.spr=9
        hit.x=this.x+this.dir*4
        hit.spd.x=this.dir*3
        hit.spd.y=-1.5
        hit.djump=max_djump
        hit.dash_time=0
        hit.dash_effect_time=0
        this.delay=10
        init_object(smoke,this.x,this.y)
        local left=this.collide(fall_floor,-this.dir,0)
        if left then
          break_fall_floor(left)
        end
        psfx(14)
      end
    elseif this.delay>0 then
      this.delay-=1
      if this.delay<=0 then
        this.spr=8
      end
    end
    -- begin hiding
    if this.hide_in>0 then
      this.hide_in-=1
      if this.hide_in<=0 then
        this.hide_for=60
        this.spr=0
      end
    end
  end,
  draw=function(this)
    spr(this.spr,this.x,this.y,1.0,1.0,this.dir==-1,false)
  end
}

function break_spring(obj)
  obj.hide_in=15
end

-- </springelie> --

function break_spring(obj)
  obj.hide_in=15
end

refill = {
  init=function(this)
    this.offset=rnd(1)
    this.timer=0
    this.hitbox={x=-1,y=-1,w=10,h=10}
    this.active=true
  end,
  update=function(this)
    if this.active then
      this.offset+=0.02
      local hit = this.collide(player,0,0)
      if hit and hit.djump<max_djump then
        psfx(11)
        init_object(smoke,this.x,this.y)
        hit.djump=max_djump
        this.active=false
        this.timer=60
      end
    elseif this.timer>0 then
      this.timer-=1
    else
      psfx(12)
      init_object(smoke,this.x,this.y)
      this.active=true
    end
  end,
  draw=function(this)
    if this.active then
      spr(this.spr,this.x,this.y+sin(this.offset)*1+0.5)
    else
      local off=sin(this.offset)*1+0.5
      color(7)
      line(this.x,this.y+4+off,this.x+3,this.y+7+off)
      line(this.x+4,this.y+7+off,this.x+7,this.y+4+off)
      line(this.x+7,this.y+3+off,this.x+4,this.y+off)
      line(this.x+3,this.y+off,this.x,this.y+3+off)
    end
  end
}

fall_floor = {
  init=function(this)
    this.state=0
    this.solid=true
    this.hitbox.h=7
  end,
  update=function(this)
    -- idling
    if this.state == 0 then
      if this.check(player,0,-1) or this.check(player,-1,0) or this.check(player,1,0) then
        break_fall_floor(this)
      end
    -- shaking
    elseif this.state==1 then
      this.delay-=1
      if this.delay<=0 then
        this.state=2
        this.delay=60  --how long it hides for
        this.collideable=false
      end
    -- invisible, waiting to reset
    elseif this.state==2 then
      this.delay-=1
      if this.delay<=0 and not this.check(player,0,0) then
        psfx(12)
        this.state=0
        this.collideable=true
        init_object(smoke,this.x,this.y)
      end
    end
  end,
  draw=function(this)
    if this.state!=2 then
      if this.state!=1 then
        spr(23,this.x,this.y)
      else
        spr(23+(15-this.delay)/5,this.x,this.y)
      end
    else
      color(7)
      line(this.x,this.y,this.x,this.y+5)
      line(this.x+1,this.y+6,this.x+6,this.y+6)
      line(this.x+7,this.y+5,this.x+7,this.y)
      line(this.x+1,this.y,this.x+6,this.y)
    end
  end
}

function break_fall_floor(obj)
  if obj.state==0 then
    psfx(13)
    obj.state=1
    obj.delay=15  --how long until it falls
    init_object(smoke,obj.x,obj.y)
    local hit=obj.collide(spring,0,-1)
    if hit then
      break_spring(hit)
    end
    hit=obj.collide(side_spring,1,0)
    if hit then
      break_spring(hit)
    end
    hit=obj.collide(side_spring,-1,0)
    if hit then
      break_spring(hit)
    end
  end
end

smoke={
  init=function(this)
    this.spr=29
    this.spd.y=-0.1
    this.spd.x=0.3+rnd(0.2)
    this.x+=-1+rnd(2)
    this.y+=-1+rnd(2)
    this.flip.x=maybe()
    this.flip.y=maybe()
    this.solids=false
  end,
  update=function(this)
    this.spr+=0.2
    if this.spr>=32 then
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
    this.level=level_index()
  if this.spr==14 then
   this.golden=true
  end
  end,
  update=function(this)
    if not this.follow then
      if this.collide(player,0,0) then
        get_player().berry_timer=0
        this.follow=true
        this.target=#fruitrain==0 and get_player() or fruitrain[#fruitrain]
        this.r=#fruitrain==0 and 12 or 8
        add(fruitrain,this)
      end
    else
      local p=get_player()
      if p then
        this.tx+=0.2*(this.target.x-this.tx)
        this.ty+=0.2*(this.target.y-this.ty)
        local a=atan2(this.x-this.tx,this.y_-this.ty)
        local k=((this.x-this.tx)^2+(this.y_-this.ty)^2) > this.r^2 and 0.2 or 0.1
        this.x+=k*(this.tx+this.r*cos(a)-this.x)
        this.y_+=k*(this.ty+this.r*sin(a)-this.y_)
      end
    end
    this.off+=1
    this.y=this.y_+sin(this.off/40)*2.5
  end
}
--- </fruitrain> ---

fly_fruit={
  if_not_fruit=true,
  init=function(this)
    this.start=this.y
    this.fly=false
    this.step=0.5
    this.solids=false
    this.sfx_delay=8
  end,
  update=function(this)
    --fly away
    if this.fly then
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
      if has_dashed then
        this.fly=true
      end
      this.step+=0.05
      this.spd.y=sin(this.step)*0.5
    end
    -- collect
    local hit=this.collide(player,0,0)
    if hit then
      --- <fruitrain> ---
      init_object(smoke, this.x-6, this.y)
      init_object(smoke, this.x+6, this.y)
      local f=init_object(fruit, this.x, this.y,12)
      f.follow=true
      f.target=#fruitrain==0 and get_player() or fruitrain[#fruitrain]
      f.r=#fruitrain==0 and 12 or 8
      add(fruitrain, f)
      --- </fruitrain> ---
      destroy_object(this)
    end
  end,
  draw=function(this)
    local off=0
    if not this.fly then
      local dir=sin(this.step)
      if dir<0 then
        off=1+max(0,sign(this.y-this.start))
      end
    else
      off=(off+0.25)%3
    end
    spr(16+off,this.x-6,this.y-2,1,1,true,false)
    spr(this.spr,this.x,this.y)
    spr(16+off,this.x+6,this.y-2)
  end
}

lifeup = {
  init=function(this)
    this.spd.y=-0.25
    this.duration=30
    this.x-=2
    this.y-=4
    this.flash=0
    this.solids=false
    --- <fruitrain> ---
    this.num=get_player().berry_count+1
    sfx_timer=20
    sfx(9)
  --- </fruitrain> ---
  end,
  update=function(this)
    this.duration-=1
    if this.duration<= 0 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    this.flash+=0.5
  str = this.num<=5 and this.num.."000" or "1up" 
    print(str,this.x-2,this.y,7+this.flash%2)
  end
}

badeline = {
 init=function(this)
  this.node=1
  this.target_x=this.x
  this.target_y=this.y
  this.badefreeze=0
 end,
 update=function(this)
  if this.badefreeze==0 then
   glide_to(this,this.target_x,this.target_y,0.2)
   local hit=this.collide(player,0,0)
   if hit then
    if this.node>#nodes then
     this.spd.y=0.1
     this.spd.x=-0.8
     this.hitbox.w=0
     this.hitbox.h=0
     this.target_x+=100
     this.node=-1
     this.badefreeze=30
     hit.dash_time=4
     hit.djump=max_djump
    else
     this.target_x=nodes[this.node][1]
     this.target_y=nodes[this.node][2]
     this.node+=1
     this.badefreeze=10
     hit.dash_time=4
     hit.djump=max_djump
    end
    bounce(hit,this,3.5,true)
   end
  else
   this.badefreeze -= 1
  end
 end,
 draw=function(this)
  if not anxiety_check then
   pal(1,this.badefreeze==0 and 1 or frames%2==0 and 14 or 7)
   pal(2,this.badefreeze==0 and 2 or frames%2==0 and 14 or 7)
  end
  
  badehair(this,1,-0.1)
  badehair(this,1,-0.4)
  badehair(this,2,0)
  badehair(this,2,0.5)
  badehair(this,1,0.125)
  badehair(this,1,0.375)
  
  this.flip=false
  
  foreach(objects,function(o)
   if o.type == player then
    this.flip=o.x>this.x
   end
  end)
  
  spr(45,this.x,this.y,1,1,this.flip)
  pal()
 end
}

function badehair(obj,c,a)
 for h=0,4 do
  circfill(obj.x+6+1.6*h*cos(a),obj.y+3+1.6*h*sin(a)+(obj.badefreeze>0 and 0 or sin((frames+3*h+4*a)/15)),max(1,min(2,3-h)),c)
 end
end

fake_wall = {
  if_not_fruit=true,
  update=function(this)
    this.hitbox={x=-1,y=-1,w=18,h=18}
    local hit = this.collide(player,0,0)
    if hit and hit.dash_effect_time>0 then
      hit.spd.x=-sign(hit.spd.x)*1.5
      hit.spd.y=-1.5
      hit.dash_time=-1
      sfx_timer=20
      sfx(8)
      destroy_object(this)
      init_object(smoke,this.x,this.y)
      init_object(smoke,this.x+8,this.y)
      init_object(smoke,this.x,this.y+8)
      init_object(smoke,this.x+8,this.y+8)
      init_object(fruit,this.x+4,this.y+4,12)
    end
    this.hitbox={x=0,y=0,w=16,h=16}
  end,
  draw=function(this)
    sspr(96,16,8,16,this.x,this.y)
    sspr(96,16,8,16,this.x+8,this.y,8,16,true,true)
  end
}

flag = {
  init=function(this)
    this.x+=5
    this.score=0
    this.show=false
    for i=1,count(got_fruit) do
      if got_fruit[i] then
        this.score+=1
      end
    end
  end,
  draw=function(this)
    this.spr=61+(frames/5)%3
    spr(this.spr,this.x,this.y)
    if this.show then
      rectfill(32,2,96,31,0)
      spr(12,55,6)
      print("x"..this.score,64,9,7)
      draw_time(41,16)
      print("deaths:"..deaths,48,24,7)
    elseif this.check(player,0,0) then
      time_ticking=false
      sfx(15)
      sfx_timer=30
      this.show=true
    end
  end
}

room_title = {
  init=function(this)
    this.delay=5
  end,
  draw=function(this)
    local camx=flr(clamp(cam_x,64,level_plength()-64)+0.5)-64
    local camy=flr(clamp(cam_y,64,level_pheight()-64)+0.5)-64
    this.delay-=1
    if this.delay<-30 then
      destroy_object(this)
    elseif this.delay<0 then
      rectfill(24+camx,58+camy,104+camx,70+camy,0)
      if level_index()==11 then
        print("old site",48+camx,62+camy,7)
      elseif is_summit() then
        print("summit",52+camx,62+camy,7)
      else
        local level=(1+level_index())*100
        print(level.." m",52+(level<1000 and 2 or 0)+camx,62+camy,7)
      end

      draw_time(4+camx,4+camy)
    end
  end
}

-- object functions --
-----------------------

-- complete object list
-- used instead of add()
-- to save tokens
tiles={}
tiles[1]  =player_spawn
tiles[8]  =side_spring
tiles[9]  =side_spring
tiles[10] =spring
tiles[12] =fruit
tiles[13] =fly_fruit
tiles[14] =fruit
tiles[15] =refill
tiles[23] =fall_floor
tiles[44] =fake_wall
tiles[61] =flag
tiles[45] =badeline

function init_object(type,x,y,tile)
  if type.if_not_fruit and got_fruit[1+level_index()] then
    return
  end

  local obj = {}
  obj.type = type
  obj.collideable=true
  -- <tilesystem> --
  obj.spr = tile
  -- </tilesystem> --
  obj.flip = {x=false,y=false}

  obj.x = x
  obj.y = y
  obj.hitbox = { x=0,y=0,w=8,h=8 }

  obj.spd = {x=0,y=0}
  obj.rem = {x=0,y=0}

  obj.is_solid=function(ox,oy)
    return (oy>0 and not obj.is_platform(ox,0) and obj.is_platform(ox,oy))  -- one way platform
    or solid_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
    or obj.check(fall_floor,ox,oy)
    or obj.check(fake_wall,ox,oy)
    or obj.check(fall_plat,ox,oy)  --falling block
  end

  obj.is_platform=function(ox,oy)
    return tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,3)
  end

  obj.collide=function(type,ox,oy)
    local other
    for i=1,count(objects) do
      other=objects[i]
      if other  and other.type == type and other != obj and other.collideable and
      other.x+other.hitbox.x+other.hitbox.w > obj.x+obj.hitbox.x+ox and
      other.y+other.hitbox.y+other.hitbox.h > obj.y+obj.hitbox.y+oy and
      other.x+other.hitbox.x < obj.x+obj.hitbox.x+obj.hitbox.w+ox and
      other.y+other.hitbox.y < obj.y+obj.hitbox.y+obj.hitbox.h+oy then
        return other
      end
    end
    return nil
  end

  obj.check=function(type,ox,oy)
    return obj.collide(type,ox,oy) 
  end

  obj.move=function(ox,oy)
    local amount
    -- [x] get move amount
    obj.rem.x += ox
    amount = flr(obj.rem.x + 0.5)
    obj.rem.x -= amount
    obj.move_x(amount,0)

    -- [y] get move amount
    obj.rem.y += oy
    amount = flr(obj.rem.y + 0.5)
    obj.rem.y -= amount
    obj.move_y(amount)
  end

  obj.move_x=function(amount,start)
    if obj.solids then
      local step = sign(amount)
      for i=start,abs(amount) do
        if not obj.is_solid(step,0) then
          obj.x += step
        else
          obj.spd.x = 0
          obj.rem.x = 0
          break
        end
      end
    else
      obj.x += amount
    end
  end

  obj.move_y=function(amount)
    if obj.solids then
      local step = sign(amount)
      for i=0,abs(amount) do
        if not obj.is_solid(0,step) then
          obj.y += step
        else
          obj.spd.y = 0
          obj.rem.y = 0
          break
        end
      end
    else
      obj.y += amount
    end
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
  shake=10
  destroy_object(obj)
  dead_particles={}
  for dir=0,7 do
    add(dead_particles,{
        x=obj.x+4,
        y=obj.y+4,
        t=10,
        spd={
          x=sin(dir/8)*3,
          y=cos(dir/8)*3
        }
      })
  end
  -- <fruitrain> ---
  for f in all(fruitrain) do
   if (f.golden) full_restart=true
    del(fruitrain,f)
    
  end
  --- </fruitrain> ---
  restart_room()
end

-- room functions --
--------------------

function restart_room()
  will_restart=true
  delay_restart=15
end

function next_room()
  --set balloon rng
  srand(level_index())

  if room.x==7 then
    load_room(0,room.y+1)
  else
    load_room(room.x+1,room.y)
  end
end

function load_room(x,y)
  has_dashed=false

  --remove existing objects
  foreach(objects,destroy_object)

  --previous room
  local x_prev=room.x
  local y_prev=room.y

  --current room
  room.x=x
  room.y=y

  --lock camera
  if level_index()==10 then
    cam_lock=true
  else
    cam_lock=false
  end

  --load/unload scrolling levels
  local same_room=(x==x_prev) and (y==y_prev)
  local number=0
  local mapdata=level_data()

  --return old levels to reserve
  if not same_room and get_data(x_prev,y_prev) then
    for i=0,get_length(x_prev,y_prev)-1 do
      for j=0,get_height(x_prev,y_prev)-1 do
        if i~=0 or j~=0 then
          number=i*get_height(x_prev,y_prev)+j
          replace_level(x_prev+i,y_prev+j,reserve_levels[number],false)
        end
      end
    end
    reserve_levels={}
  end

  --replace new rooms with data
  if not same_room and level_data() then
    for i=0,level_length()-1 do
      for j=0,level_height()-1 do
        if i~=0 or j~=0 then
          number=i*level_height()+j
          replace_level(x+i,y+j,level_data()[number],true)
        end
      end
    end
  end

  -- entities
  for tx=0,level_tlength()-1 do
    for ty=0,level_theight()-1 do
      local tile = mget(x*16+tx,y*16+ty);
      if tiles[tile] then
        init_object(tiles[tile],tx*8,ty*8,tile)
      end
      if tile >= 128 then
       nodes[tile-127] = {tx*8,ty*8}
      end
    end
  end

  init_object(room_title,0,0)
  setuparea(level_index())
end

function move_camera(obj)
  --set camera speed
  if cam_lock then
    if obj.type==player_spawn then
      cam_x=64
      cam_y=64
    elseif obj.y>128 then
      cam_lock=false
    end
  else
    cam_spdx=cam_gain*(4+obj.x+0*obj.spd.x-cam_x)
    cam_spdy=cam_gain*(4+obj.y+0*obj.spd.y-cam_y)
  end

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  if cam_x<64 or cam_x>level_plength()-64 then
    cam_spdx=0
    cam_x=min(max(cam_x,64),level_plength()-64)
  end
  if cam_y<64 or cam_y>level_pheight()-64 then
    cam_spdy=0
    cam_y=min(max(cam_y,64),level_pheight()-64)
  end
end

-- update function --
-----------------------

function _update()
  frames=((frames+1)%30)
  if time_ticking then
    centiseconds=flr(100*frames/30)
    if frames==0 then
      seconds=((seconds+1)%60)
      if seconds==0 then
        minutes+=1
      end
    end
  end

  if sfx_timer>0 then
    sfx_timer-=1
  end

  -- music system
  if current_music~=bg_music then
    music(bg_music,0,7)
    current_music=bg_music
  end

  -- cancel if freeze
  if freeze>0 then freeze-=1 return end

  -- restart (soon)
  if will_restart and delay_restart>0 then
    delay_restart-=1
    if delay_restart<=0 then
      will_restart=false
      -- <fruitrain> --
      if full_restart then
        full_restart=false
        _init()
      -- </fruitrain> --
      else
        load_room(room.x,room.y)
      end
    end
  end

  -- update each object
  foreach(objects,function(obj)
      obj.move(obj.spd.x,obj.spd.y)
      if obj.type.update then
        obj.type.update(obj)
      end
    end)
end

-- drawing functions --
-----------------------
function _draw()
  if freeze>0 then return end
  
  -- is badeline present?
  -- if so, do anxiety shader
  
  anxiety=0
  
  foreach(objects,function(o)
   if o.type == badeline then
    anxiety=1
   end
  end)

  -- reset all palette values
  pal()

  --set cam draw position
  local camx=flr(clamp(cam_x,64,level_plength()-64)+0.5)-64
  local camy=flr(clamp(cam_y,64,level_pheight()-64)+0.5)-64
  camera(camx,camy)

  --local token saving
  local xtiles=room.x*16
  local ytiles=room.y*16

  -- clear screen
  rectfill(camx,camy,camx+128,camy+128,bg_col)

  -- clouds
  foreach(clouds, function(c)
      c.x += c.spd-cam_spdx
      rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+4+(1-c.w/64)*12+camy,cloud_col)
      if c.x > 128 then
        c.x = -c.w
        c.y=rnd(128-8)
      end
    end)

  -- badeline background
  
  -- foreach(objects,function(o)
  --  if o.type == badeline then
  --   rectfill(0,0,128,128,0)
    
  --   fillp(0b0101101001011010)
    
  --   for i=0,127 do    
  --    offset=sin((frames/15)+(i/150))*3
     
  --    for j=-16,256,12 do
  --     shrink = (150+(sin((j/4.5)+(frames/30))*30)-i) / 16
      
  --     if shrink <= 7.5 then
  --      line(j+offset+shrink+1,i+1,j+offset+16-shrink,i+1,1)
       
  --      if i > 96 then
  --       c=1
  --      elseif i > 80 and i < 90 then
  --       c=1
  --      elseif i > 70 and i < 75 then
  --       c=1
  --      elseif i > 64 and i < 67 then
  --       c=1
  --      elseif i > 60 then
  --       if i % 2 == 0 then
  --        c=2
  --       else
  --        c=1
  --       end
  --      else
  --       c=2
  --      end
       
  --      line(j+offset+shrink,i,j+offset+15-shrink,i,c)     
  --     end
  --    end
  --   end
  --  end
  -- end)

  fillp()

  -- if anxiety then
  --  for i=0,15 do
  --   pal(i,12)
  --  end
  --  map(xtiles,ytiles,-anxiety,0,level_tlength(),level_theight(),4)
  --  for i=0,15 do
  --   pal(i,8)
  --  end
  --  map(xtiles,ytiles,anxiety,0,level_tlength(),level_theight(),4)
  -- end
   
  pal()

  -- draw bg terrain
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),4)

  -- if anxiety then
  --  for i=0,15 do
  --   pal(i,12)
  --  end
  --  map(xtiles,ytiles,-anxiety,0,level_tlength(),level_theight(),2)
  --  for i=0,15 do
  --   pal(i,8)
  --  end
  --  map(xtiles,ytiles,anxiety,0,level_tlength(),level_theight(),2)
  -- end
   
  pal()

  -- draw terrain
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),2)

  -- anxiety check is true
  -- if chromatic abberation
  -- is currently being done.
  -- objects should not change
  -- their palettes while
  -- this variable is true.

  -- draw objects
  foreach(objects,function(o)
      -- anxiety_check=true
      -- for i=0,15 do
      --  pal(i,12)
      -- end
      -- camera(2,0)
      -- draw_object(o)
      -- for i=0,15 do
      --  pal(i,8)
      -- end
      -- camera(-2,0)
      -- draw_object(o)
      -- anxiety_check=false
      -- pal()
      -- camera(0,0)
      draw_object(o)
    end)

  -- draw platforms
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),8)

  -- particles
  foreach(particles, function(p)
      p.x += p.spd-cam_spdx
      p.y += sin(p.off)-cam_spdy
      p.off+= min(0.05,p.spd/32)
      rectfill(p.x+camx,p.y%128+camy,p.x+p.s+camx,p.y%128+p.s+camy,p.c)
      if p.x>128+4 then
        p.x=-4
        p.y=rnd(128)
      elseif p.x<-4 then
        p.x=128
        p.y=rnd(128)
      end
    end)

  -- dead particles
  foreach(dead_particles, function(p)
      p.x += p.spd.x
      p.y += p.spd.y
      p.t -=1
      if p.t <= 0 then del(dead_particles,p) end
      rectfill(p.x-p.t/5,p.y-p.t/5,p.x+p.t/5,p.y+p.t/5,14+p.t%2)
    end)

  if is_summit() then
    local p
    for i=1,count(objects) do
      if objects[i].type==player then
        p = objects[i]
        break
      end
    end
    if p then
      local diff=min(24,40-abs(p.x+4-64))
      rectfill(0,0,diff,128,0)
      rectfill(128-diff,0,128,128,0)
    end
  end
end

function draw_object(obj)
  if obj.type.draw  then
    obj.type.draw(obj)
  elseif obj.spr and obj.spr>0 then
    spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
  end
end

function draw_time(x,y)
  rectfill(x,y,x+44,y+6,0)
  print(two_digit_str(flr(minutes/60))..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds).."."..two_digit_str(centiseconds),x+1,y+1,7)
end

-- helper functions --
----------------------
function get_player()
  for i=1,count(objects) do
    if objects[i].type==player or objects[i].type==player_spawn then
      return objects[i]
    end
  end
end

function two_digit_str(x)
  return x<10 and "0"..x or x
end

function clamp(val,a,b)
  return max(a, min(b, val))
end

function appr(val,target,amount)
  return val > target
  and max(val - amount, target)
  or min(val + amount, target)
end

function sign(v)
  return v>0 and 1 or
  v<0 and -1 or 0
end

function maybe()
  return rnd(1)<0.5
end

function solid_at(x,y,w,h)
  return tile_flag_at(x,y,w,h,0)
end

function tile_flag_at(x,y,w,h,flag)
  for i=max(0,flr(x/8)),min(level_tlength()-1,(x+w-1)/8) do
    for j=max(0,flr(y/8)),min(level_theight()-1,(y+h-1)/8) do
      if fget(tile_at(i,j),flag) then
        return true
      end
    end
  end
end

function tile_at(x,y)
  return mget(room.x * 16 + x, room.y * 16 + y)
end

function spikes_at(x,y,w,h,xspd,yspd)
  for i=max(0,flr(x/8)),min(level_tlength()-1,(x+w-1)/8) do
    for j=max(0,flr(y/8)),min(level_theight()-1,(y+h-1)/8) do
      local tile=tile_at(i,j)
      if tile==22 and ((y+h-1)%8>=6 or y+h==j*8+8) and yspd>=0 then
        return true
      elseif tile==20 and y%8<=2 and yspd<=0 then
        return true
      elseif tile==19 and x%8<=2 and xspd<=0 then
        return true
      elseif tile==21 and ((x+w-1)%8>=6 or x+w==i*8+8) and xspd>=0 then
        return true
      end
    end
  end
end

--returns mapdata string of level
--use with printh() in console
function get_level(x,y)
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

function replace_level(x,y,level,reserve)
  reserve=reserve or false
  if reserve then
    reservelvl=""
  end
  for y_=1,32,2 do
    for x_=1,32,2 do
      local offset=4096+(y<2 and 4096 or -4096)
      local hex=sub(level, x_+(y_-1)/2*32, x_+(y_-1)/2*32+1)
      if reserve then
        reservelvl=reservelvl..num2hex(peek(offset+x*16+y*2048+(y_-1)*64+x_/2))
      end
      poke(offset+x*16+y*2048+(y_-1)*64+x_/2, "0x"..hex)
    end
  end
  if reserve then
    add(reserve_levels,reservelvl)
  end
end

--convert mapdata to memory data
function num2hex(number)
  local base = 16
  local result = {}
  local resultstr = ""

  local digits = "0123456789abcdef"
  local quotient = flr(number / base)
  local remainder = number % base

  add(result, sub(digits, remainder + 1, remainder + 1))

  while (quotient > 0) do
    local old = quotient
    quotient /= base
    quotient = flr(quotient)
    remainder = old % base

    add(result, sub(digits, remainder + 1, remainder + 1))
  end

  for i = #result, 1, -1 do
    resultstr = resultstr..result[i]
  end
  if #resultstr==1 then

    resultstr="0"..resultstr
  end

  return resultstr
end

function int(b)
  return b==true and 1 or 0
end
__gfx__
0000000000000000000000000888888000000000000000000000000000000000000000000000000000000000000000000300b0b00300b0b00a0aa0a000077000
000000000888888008888880888888880888888008888880000000000888888000004000400000000000000000000000003b3300003b33000aa88aa0007bb700
00000000888888888888888888111111888888888888888808888880881111110505900090000000000000000000000002888820028888200299992007bbb370
00000000881111118811111188f11f1188111111811111188888888888f11f1150509000900000000499994000000000089888807898888709a999907bbb3bb7
0000000088f11f1188f11f1108fffff088f11f11811f118888fffff888fffff850509000900000000050050000000000088889807888898709999a9073b33bb7
0000000008fffff008fffff00033330008fffff00fffff808811111108333380050590009000000000055000000000000889888008898880099a999007333370
00000000003333000033330007000070073333000033337008f11f11003333000000400040000000005005000000000002888820028888200299992000733700
00000000007007000070007000000000000007000000700007733370007007000000000000000000000550000499994000288200002882000029920000077000
00000000000000000000000055000000666566650000066600000000d666666dd666666dd666066d4fff4fff4fff4fff4fff4fff000000000000000070000000
000777770000000000000000667000006765676500077776000000006dddddd56ddd5dd56dd50dd5444444444444444444444444007700000770070007000007
00776670000000000000000067777000677067700000076600000000666ddd55666d6d5556500555000450000000000000054000007770700777000000000000
0767770000000000000000006660000007000700000000550070007066ddd5d5656505d500000055004500000000000000005400077777700770000000000000
077660000777770000000000550000000700070000000666007000706ddd5dd56dd5065565000000045000000000000000000540077777700000700000000000
077770000777767007700000667000000000000000077776067706776ddd6d656ddd7d656d500565450000000000000000000054077777700000077000000000
0000000000000077007777706777700000000000000007665676567605ddd65005d5d65005505650500000000000000000000005070777000007077007000070
00000000000000000007777766600000000000000000005556665666000000000000000000000000000000000000000000000000000000007000000000000000
5777777557777777777777777777777577cccccccccccccccccccc77577777755555555555555555555555555555555557777557000000000000000000000000
77777777777777777777777777777777777cccccccccccccccccc777777777775555555555555550055555555555555577777777022222200000000000000000
777c77777777ccccc777777ccccc7777777cccccccccccccccccc77777777777555555555555550000555555550000557777cc77222222220000000000000000
77cccc77777cccccccc77cccccccc7777777cccccccccccccccc7777777cc77755555555555550000005555555000055777ccccc255552220000000000000000
77cccc7777cccccccccccccccccccc777777cccccccccccccccc777777cccc775555555555550000000055555500005577cccccc28dd8d220000000000000000
777cc77777cc77ccccccccccccc7cc77777cccccccccccccccccc77777cccc775555555555500000000005555500005557cc77cc066666200000000000000000
7777777777cc77cccccccccccccccc77777cccccccccccccccccc77777c7cc7755555555550000000000005555555555577c77cc001111100000000000000000
5777777577cccccccccccccccccccc7777cccccccccccccccccccc7777cccc7755555555500000000000000555555555777ccccc000500050000000000000000
77cccc7777cccccccccccccccccccc77577777777777777777777775777ccc77cccccccc500000000000000555555555777ccccc004bbb00004b000000400bbb
777ccc7777cccccccccccccccccccc77777777777777777777777777777cc777c77ccccc550000000000005550555555577ccccc004bbbbb004bb000004bbbbb
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc777c77cc7cc55500000000005555555005557cc7ccc04200bbb042bbbbb042bbb00
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777cccccccc55550000000055555555005577cccccc040000000400bbb004000000
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc77cccccccc555550000005555555555555777ccccc040000000400000004000000
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc77cc7ccccc5555550000555555550555557777cc77420000004200000042000000
777cc777777777777777777777777777777777777777777777777777777cc777ccccc7cc55555550055555555555555577777777400000004000000040000000
77cccc7757777777777777777777777557777777777777777777777557777775cccccccc55555555555555555555555557777577400000004000000040000000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccc77cccccc77cccccc77cccccc77cccccc77cccccccccccccc77cccccc77cccccc77cccccc77cccccc77cccccc77cccccc77cccccccccccccccccccccccc
77cc777777cc777777cc777777cc777777cc777777cccccccccc777777cc777777cc777777cc777777cc777777cc777777cc777777cccccccccccccccccccccc
7777777777777777777777777777777777777777777cccccccc77777777777777777777777777777777777777777777777777777777ccccccccccccccccccccc
7777777777777777777777777777777777777777777cccccccc77777777777777777777777777777777777777777777777777777777ccccccccccccccccccccc
000555555555555555500000000000000000000000077cccc775777755777577775555555555555555555555555555555555555555577ccccccccccccccccccc
0005555555555555550000000000000000000000000777ccc7777777777777777775555555555555555555555555555555555555555777cccccccccccccccccc
0005555555555565500000000000000000000000000777ccc777777cc7777cc77775555555555555555555555555555555555555555777cccccccccccccccccc
000555555555555500000000000000000000000000077ccc777777cccccccccc77755555555555555555555555555555555555555557777ccccccccccccccccc
111555555555555000000000000000000000000000077ccc77777cccccccccccc7755555555555555555555555555555555555555557777ccccccccccccccccc
1115555555555500000000000000000000000000000777cc77757cc77ccccc7cc755555555555555555555555555555555555555555777cccccccccccccccccc
1115555555555000000000000000000000000000000777cc777577c77ccccccc7755555555555555555555555555555555555555555777cccccccccccccccccc
111555555555000000000000000000000000000000077cccc77777cccccccccc777555555555555555555555555555555555555555577ccccccccccccccccccc
1155555555550000000000000000000000000000000777ccc77777cccccccccc777555555555555555555555555000000005555555577ccccccccccccccccccc
1555555555555000006000000000000000000000000777cc777577cccccccccc7770555555550555555555555550000000005555555777cccccccccccccccccc
5555555555555500000000000000000000000000000777cc77757cc7cccc77ccc750055555555550055555555550000000000555555777cccccccccccccccccc
555555555555555000000000000000000000000000077ccc77777ccccccc77ccc7700055555555500555555555500000000000555557777ccccccccccccccccc
555555555555555500000000000000000000000000077cccc77777cccccccccc77700005555555555555555555500000000000055557777ccccccccccccccccc
555555555555555550000000000000000000000070077cccc777777cc7777cc77770000055555055555555555550000000000000555777cccccccccccccccccc
5555555555555555550000000000000000000000000777cc77777777777777777770000005555555555555555550000000000000055777cccccccccccccccccc
5555655555555555555000000000000000000000000577777755777757777557775000000055555555555555555111111111111111577ccccccccccccccccccc
5555555555555555555555555550000000000000000000000000000000000000000000000005555555555555555511111111111111177ccccccccccccccccccc
55555555555555555555555555000000000000000000000000000000000000000000000000055555555555555555511111111111111777cccccc77cccccccccc
55555555555550000555555550000000000000000000000000000000000000000000000000055555555555555555551111111111111777cccccc77cc7ccccccc
555555555555500005555555000000000000000000000000000000000000000000000000000555555555555555555551111111111117777ccccccccccccccccc
555555555555500005555550000000000000000000000000000000000000000000000000000555555555555555555555111111111117777ccccccccccccccccc
55555555555550000555550000000000000000000000700000000000000000000000000000055555555555555555555551111111111777ccccccc7cccccccccc
55555555555555555555500000000000000000000000000000000000000000000000000000055555555555555555555555111111111777cccccccccc7ccccccc
5555555555555555555500000000000000000000000000000000000000000000000000000005555555555555555555555550011111177ccccccccccccccccccc
55555555555555555551111111111111166111111111111111100000000000000005555555555555555555555555555555500111111776cccccccccccccccccc
55555555555555555551111111111111166111111111111111100000000008888000555555555555555555555555555555500111111777cccccccccccccccccc
55555555555555555551111111111111111111111111111111100000000088888800055555555555555555555555555555500111111777cccccccccccccccccc
555555555555555555511111111111111111111111111111111000000000878888000055555555555555555555555555555001111117777ccccccccccccccccc
555555555555555555511111111111111111111111111111111000000000888888000005555555555555555555555566555001111117777ccccccccccccccccc
55555555555555555551111111111111111111111111111111100000000088888800000055555555555555555555556655500000000777cccccccccccccccccc
55555555555555555551111111111111111111111111111111100000000088888800000005555555555555555555555555500000000777cccccccccccccccccc
5555555555555555555111111111111111111111111111111110000000000888800000000055555555555555555555555550000000077ccccccccccccccccccc
5555555555555555555770000000000000000000000000000000000000000060000000000000000000555555555555555550000000077ccccccccccccccccccc
55555555555555555557700000000000000000000000000000000000000000600000000000000000055555555555555555000000000777cccccccccccccc67cc
55555555555555555550000000000000000000000000000000000000000000600000000000000000555555555555555550000000000777cccccccccccccc77cc
555555555555555555500000000000000000000000000000000000000000000600000000000000055555555555555555000000000007777ccccccccccccccccc
555555555555555555500000000000000000000000000000000000000000000600000000000000555555555555555550000000000007677ccccccccccccccccc
55555555555555555550000000000000000000000000000000000000000000060000000000000555555555555555550000000000000777ccccccccccccccc7cc
55555555555555555550000000000000000000000000000000000000000000060000000000005555555555555555500000000000000777cccccccccccccccccc
5555555555555555555000000000000000000000000000000000000000000000000000000005555555555555555500000000000000077ccccccccccccccccccc
5555555555555555555500000000000111111111111111111111111111111111111111111155555555555555555000000000000000077ccccccccccccccccccc
5555555555555555555550000000000111111111111111111111cccccc111111111111111555555555550555555000000000000000077ccccccccccccccccccc
555555555555555555555500000000011111111111111111111cccccccc11111111111115555555555555550055000000000000000077cc7cccccccccccccccc
555555555555555555555550000000011111111111111111111cffffcccc1111111111155555555555555550055000000000000000077ccccccccccccccccccc
555555555555555555555555555555555551111111111111111c1ff1fcccc5555555555555555555555555555550000000000000000777cccccccc77cccccccc
5555555555555555555555555555555555511111111111111111fffffccccc5555555555555555555555505555500000000000000007777ccccc777777cccccc
555555555555555555555555555555555551111111111111111113333cc77cc555555555555555555555555555500000000000000007777777777777777ccccc
5555555555555555555555555555555555511111111111111111711117c777c755555555555555555555555555500000000000000005777777777777777ccccc
55555555555555555555555555555555555555555551111111111111117777771115555555555555555555555555111111111111111111111115555555577ccc
55555555555555555555555555555555555555555500000000000000007777771777555555555555555555555555511111111111111111111115555555577ccc
55555555555555555555555555555000055555555000000000000000007777777777755555555555555555555555551111111111111111111115555555577cc7
55555555555555555555555555555111155555551111111111111111117177777777715555555555555555555555555111111111111111111115555555577ccc
555555555555555555555555555551111555555111111111111111111111111777777115555555555555555555555555555111111111111111155555555777cc
5555555555555555555555555555511115555511111111111111111111111111777777175555555555555555555555555551111111111111111555555557777c
55555555555555555555555555555555555551111111111111111111111111117777777707555555555555555555555555500000000000000005555555577777
55555555555555555555555555555555555511111111111111111111111111111177777700555555555555557555555555500000000000000005555555557777
55555555555000011111111111155555555111111111111111111111111111111177777700055555555555555555555555500000000000000055555555555555
55555555550000011111111111115555555111111111111111111111111111111170777070050555555055555555555555000000000000000555555555555555
55555555500000000000000000000555555000000000000000000000000111111111111117755551155115555555555551111111111111115555555555555555
55555555000000000000000000000055555000000000000000000000000111111111111717755757755111555555555511111111111111155555555555555555
55555550000000000000000000000005555000000000000000000000000111111111711111155557755111155555555111111111111111555555555555555555
55555500000000000000000000000000555000000000000000000000000111111111111111155175555111115555551111111111111115555555555555555555
55555000000000000000000000000000055000000000000000000000000111111111111111177555555111111555511111111111111155555555555555555555
55550000000000000000000000000000005000000000000000000000000111111111111111177755555111111155111111111111111555555555555555555555
77500000005000000000000000000000000000000000000000000000000000000000000000077557555000000000000000000000000555555555555555555555
77700000055000000000000000000000000000000000000000000000000000000000000000055555555000000000000000000000000555555555555555555555
77700000555000000000000000000000000000000000000000000000000000000000000000055555555000000000000000000000000555555555555555555555
77700005555000000000000000000000000000000000000000000000000000000000000000055555555000000000000000060000000555555555555555555555
c7700055555000000000000000000000000000000000000000000000000000000111111111155555555111111111111111111111111755555555555555555555
c7700555555000000000000000000000000000000000000600000000000000000111111111155555555111111111111111111111111555555555555555555555
c7705555555000000000000000000000000000000000000000000000000000000111111111155555555111111111111111111111111555555555555555555555
c7755555555000000000000000000000000000000000000000000000000000000111111111155555555111111111111111111111111555555555555555555555
c7755555555000000000777777000000000000000000000000000000000000000111111111555555555555555551111111111111117555555555555555555555
77755555550000000007777777700000000000000000000000000000000000000111111115555555555555555511111111111111111555555555155555555555
77755555500000000007777777700000000001111111111111111111111111111111111155555111155555555111111111111111111555555555555005555555
77755555000000000007777337700000000001111111111111111111111111111111111555555000055555550000000000000000000555555555555005555555
77755550000000000007777337700000000001111111111111111111111111111111115555555000055555500000000000770000000555555555555555555555
77755500000000000007377333700000000001111111111111111111111111111111155555555000055555000000000000770000000555555555505555555555
77755000000000000007333bb3700000000001111111111111111111111111111111555555555555555550000000000000000000000555555555556655555555
c7750000000000000000333bb3000000000001111111111111111111111111111115555555565555555500000000000000000000000555555555556655555555
c7700000000000000000333333000000000001111111111111111111111111111111111000055555555000000000000000000000000555555555555555555555
777000000000000000003b3333000000000001111111111111111111111111111111111000005555555000000000000000000000000555555555555555055555
77700000000000000000333333000000000001111111111111111111111111111111111111111555555111111111111111111111111555555555555550055555
77700000000000000000333b33000000000001111111111111111111111111111111111111111155555111111111111711111111111555555555555500055555
77706000000000000000033330000000000000000000000000000000000000000001111111111115555111111111111111111111111555555555555000055555
77700000000000000000004400000000000000000000000000000000000000000001111111111111555111111111111111111111111555555555550000055555
77700000000000000000004400000000000000000000000000000000000000000001111111111111155111111111111111111111111555555555510000055555
c7700000000000000000099990000000000000000000000000000000000000000001111111111111115111111111111111111111111555555555110000055555
ccc77777777777777777777777500000000000000000000000000000000000000001111111111111111111111111111111111111111555555551110000555555
ccc77777777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000055555550000005505555
cccc777777cc777777c7cc7777700000000000000000000000000000000000000000000000000000000000000000000000000000000005555550000055500555
cccccc77cccccc77cccccccc77700000000000000000070007000700070007000700000000000000000000000000000000000000000000555550000555500055
cccccccccccccccccccccccc77700000000000000000070007000700070007000700000000000000000000000000000000000000000000055550005555500005
ccccccccccccccccccc7ccc777700000000000000000677067706770677067706770000000000000000000000000000000000000000000005550055555500000
ccccccccccccccccccc7777777700000000000000005676567656765676567656760000000000000000000000000000000000000000000000550555555500000
ccccccccccccccccccc7777777500000000000000005666566656665666566656660000000000000000000000000000000000000000000000055555555500000
ccccccccccccccccc770000000000000000000000005777777777777777777777750000000000000000000000000000000000000000000000005555555500000
cccccccccccccccc7770000000000000000000000007777777777777777777777770000000000000000000000000000000000000000000000000555555500000
cccccccccccccccc7770000000000000000000000007777ccccc777777ccccc77770000000000000000000000000000000000000000000000000055555500000
ccccccccccccccc7777007000700070007000700070777cccccccc77cccccccc7770000000000000000000000000499994004999940000000000005555500000
ccccccccccccccc777700700070007000700070007077cccccccccccccccccccc770000000000000000000000000050060000500500000000000000555500000
cccccccccccccccc77706770677067706770677067777cc77ccccccccccccc7cc770000000000000000000000000005500000055000000000000000055500000
cccccccccccccccc77756765676567656765676567677cc77cccccccccccccccc771111111111111111111111111150050000500500000000000000005500000
ccccccccccccccccc7756665666566656665666566677cccccccccccccccccccc771111111111111111111111111115500000055000000000000000000500000
ccccccccccccccccccc77777777777777777777777577cccccccccccccccccccc771111111111111111111111115777777557777775000000000000000000000
ccccccccccccccccccc777777777777777777777777777cccccc77cccccccccc7771111111111111111111111117777777777777777000000000000000000000
cccccccccccccccccccc777777cc777777ccccc7777777cccccc77cc7ccccccc777111111111111111111111111777c7777777c7777111111111111111111111
cccccccccccccccccccccc77cccccc77cccccccc7777777cccccccccccccccc777711711171117111711171117177cccc7777cccc77117111711171117111711
ccccccccccccccccccccccccccccccccccccccccc777777cccccccccccccccc777711711171117111711171117177cccc7777cccc77117111711171117111711
cccccccccccccccccccccccccccccccccccccc7cc77777ccccccc7cccccccccc777167716771677167716771677777cc777777cc777167716771677167716771
ccccccccccccccccccccccccccccccccccccccccc77777cccccccccc7ccccccc7775676567656765676567656767777777777777777567656765676567656765
ccccccccccccccccccccccccccccccccccccccccc7777cccccccccccccccccccc775666566656665666566656665777777557777775566656665666566656665
ccccccccccccccccccccccccccccccccccccccccc7777cccccccccccccccccccc775777777777777777777777777777777777777777777777777777777777777
cccc77cccccccccccccccccccccccccccccccccc777777cccccccccccccccccc7777777777777777777777777777777777777777777777777777777777777777
cccc77cc7ccccccccccccccccccccccccccccccc777777cccccccccccccccccc7777777ccccc777777cc777777cc777777cc777777cc777777cc777777cc7777
ccccccccccccccccccccccccccccccccccccccc77777777cccccccccccccccc7777777cccccccc77cccccc77cccccc77cccccc77cccccc77cccccc77cccccc77
ccccccccccccccccccccccccccccccccccccccc77777777cccccccccccccccc777777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccc7cccccccccccccccccccccccccccccccccc777777cccccccccccccccccc77777cc77ccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccc7ccccccccccccccccccccccccccccccc777777cccccccccccccccccc77777cc77ccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccc7777cccccccccccccccccccc7777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

__gff__
0000000000000000000000000000000000000002020202000000080808000000030303030303030304040404000000000303030303030303030404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000002222222200002b28283b28000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000002222222200002828282828000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000222222220000283b282828000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0082000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000810000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000830000000000002d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222222222222222222222222222222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3825252525382525252538252525253800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

