pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- temple.p8 old base cart port

-- original game by
-- matt thorson and noel berry

-- globals --
-------------

-- <fruitrain> --
--full_restart=false
-- </fruitrain> --
room = { x=0, y=0 }
objects = {}
freeze=0
shake=0
delay_restart=0
--has_dashed=false
sfx_timer=0
--pause_player=false

time_ticking=true

bg_col=0
cloud_col=1

bg_music=0
current_music=0
level_table=
{[2]={
--insert mapdata here in strings
--the 2 should be replaced with the level index (0 indexed)
  }
}
height_table={
  [1]=2
}
length_table={
  [1]=2
}
reserve_levels={}

--not using tables to conserve tokens
cam_x=0
cam_y=0
cam_spdx=0
cam_spdy=0
cam_gain=0.25

function rectangle(x,y,w,h)
  return {x=x,y=y,w=w,h=h}
end

function level_length()
  return length_table[level_index()] or 1
end

function level_height()
  return height_table[level_index()] or 1
end

function level_data()
  return level_table[level_index()]
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

--[[k_left=0
k_right=1
k_up=2
k_down=3
k_jump=4
k_dash=5]]--

-- entry point --
-----------------

function _init()
  begin_game()
end

function begin_game()
  frames=0
  deaths=0
  max_djump=1
  centiseconds=0
  seconds=0
  minutes=0
  got_fruit={}
  load_room(0,0)
end

function level_index()
  return room.x+room.y*8
end

function is_end()
  return level_index()==30
end

function get_fruit()
  local froot=0
  for _ in pairs(got_fruit) do
    froot+=1
  end
  return froot
end

function rnd128()
  return rnd(128)
end


-- player entity --
-------------------

player={
  init=function(this)
    this.visible=true
    this.p_jump=false
    this.p_dash=false
    this.grace=0
    this.jbuffer=0
    this.djump=max_djump
    this.dash_time=0
    this.dash_effect_time=0
    this.dash_target=make_vec(0,0)
    this.dash_accel=make_vec(0,0)
    this.hitbox={x=1,y=3,w=6,h=5}
    this.spr_off=0
    this.was_on_ground=false
    this.solids=true
    create_hair(this)
    -- <fruitrain> --
    this.berry_timer=0
    this.berry_count=0
    -- <keydoor>
    this.key_count=0
    -- </keydoor>
  -- </fruitrain> --
  end,
  update=function(this)
    if pause_player then
      return
    end

    -- horizontal input
    local input=btn(1) and 1 or (btn(0) and -1 or 0)
    -- vertical input
    local inputv=btn(3) and 1 or (btn(2) and -1 or 0)

    -- spike collision and bottom death
    if spikes_at(this.x+this.hitbox.x,this.y+this.hitbox.y,this.hitbox.w,this.hitbox.h,this.spd.x,this.spd.y) or
    this.y>level_pheight() then
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
    for f in all(fruitrain) do
     if f.type==fruit and (not f.golden or level_index()==0) then
      fr=f
      if not f.golden then
       break
      end
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
      init_smoke(this.x,this.y+4)
    end

    --jump buffer+jump input
    if btn(4) and not this.p_jump then
      this.jbuffer=4
    elseif this.jbuffer>0 then
      this.jbuffer-=1
    end

    this.p_jump=btn(4)

    --dash input
    local dash = btn(5) and not this.p_dash
    this.p_dash = btn(5)

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
      init_smoke(this.x,this.y)
      this.dash_time-=1
      this.spd=make_vec(appr(this.spd.x,this.dash_target.x,this.dash_accel.x),
                        appr(this.spd.y,this.dash_target.y,this.dash_accel.y))
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
        this.flip.x=this.spd.x<0
      end

      --vertical movement
      local maxfall=2
      local gravity=abs(this.spd.y)>0.15 and 0.21 or 0.105

      -- wall slide
      if input!=0 and this.is_solid(input,0) then
        maxfall=0.4
        --wallslide particles
        if rnd(10)<2 then
          init_smoke(this.x+input*6,this.y)
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
          init_smoke(this.x,this.y+4)
        else
          -- wall jump
          local wall_dir=this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0
          if wall_dir!=0 then
            psfx(4)
            this.jbuffer=0
            this.spd=make_vec(-wall_dir*(maxrun+1),-2)

            --walljump particles
            init_smoke(this.x+wall_dir*6,this.y)
          end
        end
      end

      -- dash
      local d_full=5
      local d_half=3.5355339059

      if this.djump>0 and dash then
        init_smoke(this.x,this.y)
        this.djump-=1
        this.dash_time=4
        has_dashed=true
        this.dash_effect_time=10


        -- calculate dash speeds
        this.spd=make_vec(input!=0 and
        input*(inputv!=0 and d_half or d_full) or
        (inputv!=0 and 0 or this.flip.x and -1 or 1),
        inputv!=0 and inputv*(input!=0 and d_half or d_full) or 0)

        --effects
        psfx(5)
        freeze=2
        shake=6

        -- dash target speeds and accels
        this.dash_target=make_vec(2*sign(this.spd.x),
                                 (this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y))
        this.dash_accel=make_vec(this.spd.y==0 and 1.5 or 1.06066017177,
                                 this.spd.x==0 and 1.5 or 1.06066017177)
      elseif this.djump<=0 and dash then
        -- failed dash smoke
        psfx(6)
        init_smoke(this.x,this.y)
      end
    end

    -- animation
    this.spr_off+=0.25
    if not on_ground then
      -- wallslide or midair
      this.spr=this.is_solid(input,0) and 5 or 3
    elseif btn(3) then
      -- crouch
      this.spr=6
    elseif btn(2) then
      --look up
      this.spr=7
    else
      -- walk or stand
      this.spr=1+(this.spd.x~=0 and (btn(0) or btn(1)) and this.spr_off%4 or 0)
    end

    -- exit level from top
    if this.y<-4 and not is_end() then
      next_room()
    end

    -- was on the ground
    this.was_on_ground=on_ground
    move_camera(this)
  end,
  draw=function(this)
    -- clamp in screen
    if this.x<-1 or this.x>level_plength()-7 then
      this.x=clamp(this.x,-1,level_plength()-7)
      this.spd.x=0
    end
    if this.visible then
      -- draw player hair + sprite
      set_hair_color(this.djump)
      draw_hair(this)
      spr(this.spr,this.x,this.y,1,1,this.flip.x)
      unset_hair_color()
    end
  end
}

function get_obj(object)
  for obj in all(objects) do
    if obj.type==object then
      return obj
    end
  end
end

function psfx(num)
  if sfx_timer<=0 then
    sfx(num)
  end
end

function set_hair_color(djump)
  pal(8,djump==1 and 8 or 12)
end

function create_hair(obj)
  obj.hair={}
  for i=0,4 do
    add(obj.hair,{x=obj.x,y=obj.y,size=clamp(3-i,1,2)})
  end
end

function draw_hair(obj)
  local last=make_vec(obj.x+4-(obj.flip.x and -2 or 2),obj.y+(btn(3) and 4 or 3))
  foreach(obj.hair,function(h)
      h.x+=(last.x-h.x)/1.5
      h.y+=(last.y+0.5-h.y)/1.5
      circfill(h.x,h.y,h.size,8)
      last=h
    end)
end

function unset_hair_color()
  pal(8,8)
end

player_spawn = {
  init=function(this)
    sfx(0)
    this.spr=3
    this.target= this.y
    this.y=min(this.y+48,level_pheight())
    cam_x=this.x
    cam_y=this.y
    this.spd.y=-4
    this.state=0
    this.delay=0
    create_hair(this)
    --- <fruitrain> ---
    for i=1,#fruitrain do
      local f=init_object(fruit,this.x,this.y,fruitrain[i].spr)
      f.follow=true
      f.target=i==1 and get_player() or fruitrain[i-1]
      f.r=fruitrain[i].r
      f.level=fruitrain[i].level
      fruitrain[i]=f
    end
  --- </fruitrain> ---
  end,
  update=function(this)
    -- jumping up
    if this.state==0 then
      if this.y < this.target+16 then
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
          this.spd.y=0
          this.state=2
          this.delay=5
          shake=5
          init_smoke(this.x,this.y+4)
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
        if (fruitrain[1]) fruitrain[1].target=p
      --- </fruitrain> ---
      end
    end

    move_camera(this)
  end,
  draw=function(this)
    draw_hair(this)
    spr(this.spr,this.x,this.y)
  end
}

-- <keydoor>
key={
 init=function(this)
  this.y_=this.y
  this.off=0
  this.follow=false
  this.tx=this.x
  this.ty=this.y
  this.deco=false
  this.timer=0
 end,
	update=function(this)
		 if not this.deco then
		   local was=flr(this.spr)
		     this.spr=69.5+sin(frames/30)
		   local is=flr(this.spr)
		   if is==70 and is!=was then
			    this.flip.x=not this.flip.x
		   end
		   if not this.follow then
       local hit=this.collide(player,0,0)
       if hit then
      	  sfx(23)
			      sfx_timer=10
			      hit.key_count+=1
         this.follow=true
         this.target=#fruitrain==0 and hit or fruitrain[#fruitrain]
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
   else
     local d=get_obj(door)
     this.x=e_appr(this.x,d.x+4,2)
     this.y=e_appr(this.y,d.y+4,2)
     if this.timer==0 and (d.x+4 - this.x)^2 + (d.y+4 - this.y)^2 < 32 then
       this.spr=71
       this.timer=1
     elseif this.timer==0 then
       this.spr=68
     end
     if this.timer>0 and this.timer<28 then
      this.timer+=1
     end
     if (d.x+4 - this.x)^2 + (d.y+4 - this.y)^2 < 2  then
       this.x=d.x+4
       this.y=d.y+4
       if this.timer>27 then
         d.timer=1
         init_smoke(this.x,this.y)
         destroy_object(this)
         d.hitbox={x=0,y=0,w=0,h=0}
       end
     end
   end
	end
}

door={
 init=function(this)
  this.timer=0
  this.hitbox={x=0,y=0,w=16,h=16}
 end,
 update=function(this)
  local hit=get_player()
  if hit then
   if hit.key_count!=0 and (hit.x - (this.x+8))^2 + (hit.y - (this.y+8))^2 < 324 then
    hit.key_count-=1
    for f in all(fruitrain) do
     if f.type==key then
      local k=get_obj(key)
      del(fruitrain,f)
      destroy_object(f)
      init_object(key,k.x,k.y)
      local k=get_obj(key)
      k.deco=true
     end
    end
   end
  end
  if this.timer<32 and this.timer~=0 then
   this.timer+=1
  end
  if this.timer>31 then
   init_smoke(this.x-8,this.y)
   init_smoke(this.x-8,this.y+8)
   init_smoke(this.x+16,this.y)
   init_smoke(this.x+16,this.y+8)
   destroy_object(this)
  end
 end,
 draw=function(this)
  if this.timer==0 then
   spr(98,this.x,this.y,2.0,2.0)
  elseif this.timer<32 then
   spr(98,this.x-this.timer/4,this.y,1.0,2.0)
   spr(99,this.x+8+this.timer/4,this.y,1.0,2.0)
  end
 end
}
-- </keydoor>

red_bubble={
  init=function(this)
    this.state=0
    this._x=this.x
    this._y=this.y
    this.t=0
  end,
  update=function(this)
    if this.state==0 then
      local hit=get_player()
      if hit then
        -- get direction
        this.spd.x=(btn(k_right) and 2 or 0)+(btn(k_left) and -2 or 0)
        this.spd.y=(btn(k_down) and 2 or 0)+(btn(k_up) and -2 or 0)
        -- get player inside yo belleh
       -- hit.visible=false
        -- change state
        this.state=1
        this.t=0
        hit.x=this.x
        hit.y=this.y
      end
    else
      this.t+=1
      if this.t>10 then
        if this.is_solid(this.spd.x,this.spd.y) or btn(k_dash) then
          local p=get_player()
          p.visible=true
          if btn(k_dash) then
           -- do_dash(p)
          end
          this.x=this._x
          this.y=this._y
          this.spd.x=0
          this.spd.y=0
          this.state=0
        end
      end
    end
  end
}

-- <blade>
blade_vert={
  init=function(this)
    this.hitbox=rectangle(2,2,12,12)
    while true do
      if not this.is_solid(0,-1) and this.y-1>0 then
        this.y-=1
      else
        break 
      end
    end
    local fy=0
    while true do
      if not this.is_solid(0,fy) and this.y+fy<level_pheight() then
        fy+=1
      else
        this.mid=this.y+(fy/2)
        break
      end
    end
    this.timer=15
    this.up=false
  end,
  update=function(this)
    if this.timer>0 then
      this.timer-=1
    else
      if this.up then
        if not this.is_solid(0,-2) and this.y>0 then
          this.y-=2
        else
          this.up=false
          this.timer=15
        end
      else
        if not this.is_solid(0,2) and this.y+14<level_pheight() then
          this.y+=2
        else
          this.up=true
          this.timer=15
        end
      end
    end
    local hit=this.collide(player,0,0)
    if hit then
      kill_player(hit)
    end
  end,
  draw=function(this)
    if this.y>this.mid-4 and this.y<this.mid+4 then
      this.spr=67
    else
      this.spr=66
    end
    draw_4sprite(this.spr,this)
  end
}

blade_horiz={
  init=function(this)
    this.hitbox=rectangle(2,2,12,12)
    while true do
      if not this.is_solid(-1,0) and this.x-1>0 then
        this.x-=1
      else
        break 
      end
    end
    local fx=0
    while true do
      if not this.is_solid(fx,0) and this.x+fx<level_plength() then
        fx+=1
      else
        this.mid=this.x+(fx/2)
        break
      end
    end
    this.timer=15
    this.left=false
  end,
  update=function(this)
    if this.timer>0 then
      this.timer-=1
    else
      if this.left then
        if not this.is_solid(-2,0) and this.x>0 then
          this.x-=2
        else
          this.left=false
          this.timer=15
        end
      else
        if not this.is_solid(2,0) and this.x+14<level_plength() then
          this.x+=2
        else
          this.left=true
          this.timer=15
        end
      end
    end
    local hit=this.collide(player,0,0)
    if hit then
      kill_player(hit)
    end
  end,
  draw=function(this)
    if this.x>this.mid-4 and this.x<this.mid+4 then
      this.spr=67
    else
      this.spr=66
    end
    draw_4sprite(this.spr,this)
  end
}

function draw_4sprite(s,o)
  for i=0,3 do
    spr(s,o.x+((i%2)*8),o.y+(i>1 and 8 or 0),1,1,(i%2!=0),(i>1))
  end
end
-- </blade>

spring = {
  init=function(this)
    this.hide_in=0
    this.hide_for=0
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for<=0 then
        this.spr=10
        this.delay=0
      end
    elseif this.spr==10 then
      local hit = this.collide(player,0,0)
      if hit  and hit.spd.y>=0 then
        this.spr=11
        hit.y=this.y-4
        hit.spd.x*=0.2
        hit.spd.y=-3
        hit.djump=max_djump
        this.delay=10
        init_smoke(this.x,this.y)

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
      if hit  and this.dir*hit.spd.x<=0 then
        this.spr=9
        hit.x=this.x+this.dir*4
        hit.spd=make_vec(this.dir*3,-1.5)
        hit.djump=max_djump
        hit.dash_time=0
        hit.dash_effect_time=0
        this.delay=10
        init_smoke(this.x,this.y)
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
  if obj then
    obj.hide_in=15
  end
end

-- </springelie> --

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
        init_smoke(this.x,this.y)
        hit.djump=max_djump
        this.active=false
        this.timer=60
      end
    elseif this.timer>0 then
      this.timer-=1
    else
      psfx(12)
      init_smoke(this.x,this.y)
      this.active=true
    end
  end,
  draw=function(this)
    if this.active then
      local off=sin(this.offset)+0.5
      spr(this.spr,this.x,this.y+off)
    else
      color(7)
      line(this.x,this.y+4,this.x+3,this.y+7)
      line(this.x+4,this.y+7,this.x+7,this.y+4)
      line(this.x+7,this.y+3,this.x+4,this.y)
      line(this.x+3,this.y,this.x,this.y+3)
    end
  end
}

fall_floor = {
  init=function(this)
    this.state=0
    this.hitbox.h=7
  end,
  update=function(this)
    -- idling
    if this.state == 0 then
      if this.collide(player,0,-1) or this.collide(player,-1,0) or this.collide(player,1,0) then
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
      if this.delay<=0 and not this.collide(player,0,0) then
        psfx(12)
        this.state=0
        this.collideable=true
        init_smoke(this.x,this.y)
      end
    end
  end,
  draw=function(this)
    if this.state!=2 then
      spr(23+(this.state~=1 and 0 or (15-this.delay)/5),this.x,this.y)
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
    init_smoke(obj.x,obj.y)
    break_spring(obj.collide(spring,0,-1))
    break_spring(obj.collide(side_spring,1,0))
    break_spring(obj.collide(side_spring,-1,0))
  end
end

smoke={
  init=function(this)
    this.spd=make_vec(0.3+rnd(0.2),-0.1)
    this.x+=-1+rnd(2)
    this.y+=-1+rnd(2)
    this.flip=make_vec(maybe(),maybe())
  end,
  update=function(this)
    this.spr+=0.2
    if this.spr>=32 then
      destroy_object(this)
    end
  end
}
function init_smoke(x,y)
  init_object(smoke,x,y,29)
end

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
    this.golden=this.spr==14
    if(this.golden and deaths>0) then
      destroy_object(this)
    end
  end,
  update=function(this)
    if not this.follow then
      local hit=this.collide(player,0,0)
      if hit then
        hit.berry_timer=0
        this.follow=true
        this.target=#fruitrain==0 and hit or fruitrain[#fruitrain]
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
      init_smoke(this.x-6, this.y)
      init_smoke(this.x+6, this.y)
      local f=init_object(fruit, this.x, this.y,12)
      fruit.update(f)
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
  str = this.num<=5 and this.num.."000" or "1UP"
    ?str,this.x-2,this.y,7+this.flash%2
  end
}

-- <seeker>
seeker={
  init=function(this)
    this.state=0 -- states: 0=wander, 1=charge, 2=dead, 3=bounce
    this.freeze=10
    this.xcheck=this.x+2
    this.ycheck=this.y+8
    this.chargeangle=0
    this.bounce=7
    this.chargedelay=0
    this.hitbox=rectangle(3,3,10,10)
    this.spdx=1
    this.spdy=1
    this.flipx=false
    this.dir=0 --0=up,1=left,2=down,3=right
    this.pd=0 --prev dir
    -- idle timer
    this.itimer=0
    this.solids=true
  end,
  update=function(this)
    if this.chargedelay>0 then
      this.chargedelay-=1
    end
    this.freeze-=1
    this.xcheck=this.x+4
    this.ycheck=this.y+8
    if this.state==0 then -- if wandering
      local xd=(this.dir%2!=0 and this.dir-2 or 0)
      this.spdx=clamp(this.spdx+xd/10,-2,2)
      local yd=(this.dir%2==0 and this.dir-1 or 0)
      this.spdy=clamp(this.spdy+yd/10,-2,2)      
      if this.chargedelay==0 then
        seek(this)
      end
    elseif this.state==1 then
      if this.spdx<3 then
        this.spdx+=0.2
      end
      if this.spdy<3 then
        this.spdy+=0.2
      end
    elseif this.state==3 then
      this.bounce*=0.8
      this.y-=(this.bounce/3)*cos(this.chargeangle)
      this.x-=(this.bounce/3)*sin(this.chargeangle)
      if this.bounce==0 then
        this.state=0
        this.bounce=8
      --  this.spdx=0
      --  this.spdy=0
      end
      if this.chargedelay==0 then
        seek(this)
      end
    end
    local hit=get_player()
    if hit then
      this.flipx=(hit.x<this.x and false or hit.x>this.x and true)
    end
    if not this.is_solid(this.spdx*sin(this.chargeangle),0) then
      this.x+=this.spdx*sin(this.chargeangle)
    else
      for i=ceil(abs(this.spdx*sin(this.chargeangle))),0 do
        if not this.is_solid(i,0) then
          this.x+=i
          break
        end
      end
      if this.state!=3 then
        this.chargedelay=30
        this.state=3
        this.spdx=2
      end
    end
    if not this.is_solid(0,this.spdy*cos(this.chargeangle)) then
      this.y+=this.spdy*cos(this.chargeangle)
    else
      for i=ceil(abs(this.spdy*cos(this.chargeangle))),0 do
        if not this.is_solid(0,i) then
          this.y+=i
          break
        end
      end
      if this.state!=3 then
        this.chargedelay=30
        this.state=3
        this.spdy=2
      end
    end
  end,
  draw=function(this)
    if this.state==1 then -- charge
      tentacle(this,8,(this.flipx and -0.5 or 0))
      sspr(48,48,16,16,this.x,this.y,16,16,this.flipx)
    elseif this.state==0 or this.state==3 then -- wander
      tentacle(this,13,(this.flipx and -0.5 or 0))
      sspr(32,48,16,16,this.x,this.y,16,16,this.flipx)
    elseif this.state==2 then -- dead
      sspr(64,48,16,16,this.x+4,this.y)
    end
  end
}

function circle(x,y,h,obj,a,c)
  circfill((obj.x+x+1.6*h*cos(a))-(obj.flipx and 12 or 0),obj.y+y+1.6*h*sin(a)+(obj.freeze>0 and 0 or sin((frames+3*h+4*a)/15)),max(1,min(2,1-h)),c)
end

function seek(this)
  this.hitbox=rectangle(0,0,1,1)
  local hit=get_player()
  if hit then
    for i=0,32 do
      this.xcheck=appr(this.xcheck,hit.x+3,4)
      this.ycheck=appr(this.ycheck,hit.y+3,4)
      if not this.is_solid(this.xcheck-this.x,this.ycheck-this.y) then
        if this.collide(player,this.xcheck-this.x,this.ycheck-this.y) then 
          this.chargeangle=atan2((this.ycheck-this.y)-8,(this.xcheck-this.x)-10)
          this.state=1
          this.xcheck=this.x+2
          this.ycheck=this.y+8
        end
      else
        break
      end
    end
  end
  this.hitbox=rectangle(3,3,10,10)
end

function tentacle(obj,c,a)
  for h=0,4 do
    circle(14,4,h,obj,a,c)
    circle(15,8,h,obj,a-(obj.flipx and -0.045 or 0.075),c)
    circle(13,12,h,obj,a-(obj.flipx and -0.125 or 0.125),c)
  end
end
-- </seeker>

fake_wall={
  init=function(this)
    local match
    for o in all(corners) do
      if o.x==this.x then
        match=o
        break
      end
    end
    if (not match) then
      destroy_object(this)
      return
    end
    this.h=(this.y-match.y)/8+1
    this.y=match.y
    this.x-=8
    for o in all(objects) do
      if o.type==fruit and o.x==this.x and o.y==this.y then
        this.has_fruit=true
        destroy_object(o)
        break
      end
    end
  end,
  update=function(this)
    this.hitbox.w=18
    this.hitbox.h=this.h*8+2
    local hit = this.collide(player,-1,-1)
    if hit and hit.dash_effect_time>0 then
      hit.spd=make_vec(sign(hit.spd.x)*-1.5,-1.5)
      hit.dash_time=-1
      sfx_timer=20
      sfx(16)
      destroy_object(this)
      for i=0,this.h-1 do
        init_smoke(this.x,this.y+8*i)
        init_smoke(this.x+8,this.y+8*i)
      end
      if this.has_fruit then
        init_object(fruit,this.x+4,this.y+4,12)
      end
    end
    this.hitbox.w=16
    this.hitbox.h-=2
  end,
  draw=function(this)
    local x,y,bot=this.x,this.y,this.y+8*(this.h-1)
    spr(60,x,y,1,1,true,true)
    spr(44,x+8,y)
    for i=1,this.h-2 do
      spr(45,x,y+8*i,2,1)
    end
    spr(44,x,bot,1,1,true,true)
    spr(60,x+8,bot)
  end
}
corner={
  init=function(this)
    add(corners,this)
    destroy_object(this)
  end
}

flag = {
  init=function(this)
    this.x+=5
    this.show=false
  end,
  draw=function(this)
    this.spr=61+(frames/5)%3
    spr(this.spr,this.x,this.y)
    if this.show then
      rectfill(32,2,96,31,0)
      spr(12,55,6)
      ?"x"..get_fruit(),64,9,7
      draw_time(41,16)
      ?"deaths:"..deaths,48,24,7
    elseif this.collide(player,0,0) then
      time_ticking=false
      sfx(15)
      sfx_timer=30
      this.show=true
    end
  end
}

-- object functions --
-----------------------

-- complete object list
-- used instead of add()
-- to save tokens
tiles={
  [1]  =player_spawn,
  [8]  =side_spring,
  [9]  =side_spring,
  [10] =spring,
  [12] =fruit,
  [13] =fly_fruit,
  [14] =fruit,
  [15] =refill,
  [23] =fall_floor,
  [44] =corner,
  [60] =fake_wall,
  [61] =flag,
  -- <keydoor>
  [68] =key,
  [98] =door,
  -- </keydoor>
  -- <blade>
  [66] =blade_vert,
  [67] =blade_horiz,
  -- </blade>
  [83] =red_bubble,
  -- <seeker>
  [100]=seeker
  -- </seeker>
}

function init_object(type,x,y,tile)
  if type.if_not_fruit and got_fruit[1+level_index()] then
    return
  end

  local obj={
    type=type,
    collideable=true,
    -- <tilesystem> --
    spr=tile,
    -- </tilesystem> --
    flip=make_vec(false,false),

    x=x,
    y=y,
    hitbox={x=0,y=0,w=8,h=8},

    spd=make_vec(0,0),
    rem=make_vec(0,0)
  }
  function obj.is_solid(ox,oy)
    return (oy>0 and not obj.is_platform(ox,0) and obj.is_platform(ox,oy))  -- one way platform
    or solid_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
    or obj.collide(fall_floor,ox,oy)
    or obj.collide(fake_wall,ox,oy)
    or obj.collide(door,ox,oy)
    or obj.collide(plat,ox,oy)
  end

  function obj.is_platform(ox,oy)
    return tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,3)
  end

  function obj.collide(type,ox,oy)
    for other in all(objects) do
      if other and other.type == type and other != obj and other.collideable and
      other.x+other.hitbox.x+other.hitbox.w > obj.x+obj.hitbox.x+ox and
      other.y+other.hitbox.y+other.hitbox.h > obj.y+obj.hitbox.y+oy and
      other.x+other.hitbox.x < obj.x+obj.hitbox.x+obj.hitbox.w+ox and
      other.y+other.hitbox.y < obj.y+obj.hitbox.y+obj.hitbox.h+oy then
        return other
      end
    end
  end

  function obj.move(ox,oy)
    -- [x] get move amount
    obj.rem.x += ox
    local amount = round(obj.rem.x)
    obj.rem.x -= amount
    obj.move_x(amount,0)

    -- [y] get move amount
    obj.rem.y += oy
    amount = round(obj.rem.y)
    obj.rem.y -= amount
    obj.move_y(amount)
  end

  function obj.move_x(amount,start)
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

  function obj.move_y(amount)
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

-- room functions --
--------------------

function next_room()
  local next_lvl=level_index()+1
  load_room(next_lvl%8,next_lvl\8)
end

function load_data(tbl,reserve)
  for i=0,level_length()-1 do
    for j=0,level_height()-1 do
      if i~=0 or j~=0 then
        replace_level(room.x+i,room.y+j,tbl[i*level_height()+j],reserve)
      end
    end
  end
end


function load_room(x,y)
  has_dashed=false

  --remove existing objects
  foreach(objects,destroy_object)
  corners={}



  --load/unload scrolling levels

  local same_room=x+8*y==level_index()

  --return old levels to reserve
  if not same_room and level_data() then
    load_data(reserve_levels,false)
    reserve_levels={}
  end

  --current room
  room=make_vec(x,y)

  --replace new rooms with data
  if not same_room and level_data() then
    load_data(level_data(),true)
  end

  -- entities
  for tx=0,level_tlength()-1 do
    for ty=0,level_theight()-1 do
      local tile = mget(x*16+tx,y*16+ty);
      if tiles[tile] then
        init_object(tiles[tile],tx*8,ty*8,tile)
      end
    end
  end

  setuparea(level_index())
end

function move_camera(obj)
  --set camera speed
  cam_spdx=cam_gain*(4+obj.x+0*obj.spd.x-cam_x)
  cam_spdy=cam_gain*(4+obj.y+0*obj.spd.y-cam_y)

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  if cam_x<64 or cam_x>level_plength()-64 then
    cam_spdx=0
    cam_x=clamp(cam_x,64,level_plength()-64)
  end
  if cam_y<64 or cam_y>level_pheight()-64 then
    cam_spdy=0
    cam_y=clamp(cam_y,64,level_pheight()-64)
  end
end

-- update function --
-----------------------

function _update()
  frames=(frames+1)%30
  if time_ticking then
    centiseconds=100*frames\30
    if frames==0 then
      seconds=(seconds+1)%60
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
  if delay_restart>0 then
    delay_restart-=1
    if delay_restart<=0 then
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
function qcirc(x,y,a2,r)
  local res=ceil(1.618*r)
  for i=0,res do
    local ang=i/res/4
    clip(x+r*cos(a2+ang),y+r*sin(a2+ang),(x-(x+r*cos(a2+ang)))*2,(y-(y+r*sin(a2+ang)))*2)
    draw2()
  end
end

function draw2()
  --set cam draw position
  local camx=round(cam_x)-64
  local camy=round(cam_y)-64
  camera(camx,camy)

  --local token saving
  local xtiles=room.x*16
  local ytiles=room.y*16


  -- draw bg terrain
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),4)

  -- draw terrain
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),2)

  -- draw objects
  foreach(objects,function(o)
      draw_object(o)
    end)

  -- draw platforms
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),8)

end

function draw()
  --set cam draw position
  local camx=round(cam_x)-64
  local camy=round(cam_y)-64
  camera(camx,camy)

  --local token saving
  local xtiles=room.x*16
  local ytiles=room.y*16

  -- clear screen
  rectfill(camx,camy,camx+128,camy+128,bg_col)

  -- draw bg terrain
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),4)

  -- draw terrain
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),2)

  -- draw objects
  foreach(objects,function(o)
      draw_object(o)
    end)

  -- draw platforms
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),8)

  -- <transition>
  if tstate>=0 then
    local t20=tpos+20
    local yedge=camy+127
    if tstate==0 then
      po1tri(tpos,camy,t20,camy,tpos,yedge)
      if(tpos>camx) rectfill(camx,camy,tpos,yedge,0)
      if(tpos>148+camx) then
        tstate=1
        tpos=camx-20
      end
    else
      po1tri(t20,camy,t20,yedge,tpos,yedge)
      if(tpos<108+camx) rectfill(t20,camy,camx+127,yedge,0)
      if(tpos>148+camx) then
        tstate=-1
        tpos=camx-20
      end
    end
    tpos+=14
  end
 -- </transition>
end


function _draw()
  if freeze>0 then return end

  -- dark palatte
  pal_dark()
  clip()
  draw()
  pal()
  local hit=get_player()
  if hit then
    qcirc(hit.x+4,hit.y+4,-0.75,20)
  end
  pal(2,130,1)
  pal(13,141,1)
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
  print(two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds).."."..two_digit_str(centiseconds),x+1,y+1,7)
end

-- helper functions --
----------------------
function get_player()
  for obj in all(objects) do
    if obj.type==player or obj.type==player_spawn then
      return obj
    end
  end
end

function two_digit_str(x)
  return x<10 and "0"..x or x
end

function make_vec(x,y)
  return {x=x,y=y}
end

function round(x)
  return flr(x+0.5)
end

function clamp(val,a,b)
  return max(a, min(b, val))
end

function appr(val,target,amount)
  return val > target
  and max(val - amount, target)
  or min(val + amount, target)
end

function e_appr(val,target,g)
  return val + g * ((target - val)/12)
end

function sign(v)
  return v~=0 and sgn(v) or 0
end

function maybe()
  return rnd(1)<0.5
end

function solid_at(x,y,w,h)
  return tile_flag_at(x,y,w,h,0)
end

function tile_flag_at(x,y,w,h,flag)
  for i=max(0,x\8),min(level_tlength()-1,(x+w-1)/8) do
    for j=max(0,y\8),min(level_theight()-1,(y+h-1)/8) do
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
  for i=max(0,x\8),min(level_tlength()-1,(x+w-1)/8) do
    for j=max(0,y\8),min(level_theight()-1,(y+h-1)/8) do
      local tile=tile_at(i,j)
      if tile==22 and ((y+h-1)%8>=6 or y+h==j*8+8) and yspd>=0 or
      tile==20 and y%8<=2 and yspd<=0 or
      tile==19 and x%8<=2 and xspd<=0 or
      tile==21 and ((x+w-1)%8>=6 or x+w==i*8+8) and xspd>=0 then
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
 local resultstr=""
 while number>0 do
  local remainder=1+number%16
  number\=16
  resultstr=sub("0123456789abcdef",remainder,remainder)..resultstr
 end
 return #resultstr==0 and "00" or #resultstr==1 and "0"..resultstr or resultstr
end

-- transition globals
tstate=-1
tpos=-20

--<transition>--
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
--</transition>--
-->8
-- lighting stuff --

function pal_vdark()
 pal(1,0)
 pal(2,0)
 pal(3,0)
 pal(4,1)
 pal(5,0)
 pal(6,1)
 pal(7,1)
 pal(8,1)
 pal(9,1)
 pal(10,2)
 pal(11,0)
 pal(12,0)
 pal(13,1)
 pal(14,1)
 pal(15,2)
end

function pal_dark()
 pal(1,0)
 pal(2,1)
 pal(3,1)
 pal(4,2)
 pal(5,1)
 pal(6,5)
 pal(7,5)
 pal(8,2)
 pal(9,2)
 pal(10,4)
 pal(11,1)
 pal(12,1)
 pal(13,1)
 pal(14,2)
 pal(15,4)
end

function pal_green()

 pal(1,1)
 pal(2,1)
 pal(3,3)
 pal(4,3)
 pal(5,3)
 pal(6,11)
 pal(7,10)
 pal(8,11)
 pal(9,3)
 pal(10,10)
 pal(11,11)
 pal(12,11)
 pal(13,3)
 pal(14,3)
 pal(15,11)
end

__gfx__
0000000000000000000000000888888000000000000000000000000000000000000000000000000000000000000000000300b0b00300b0b00a0aa0a000077000
000000000888888008888880888888880888888008888800000000000888888000004000400000000000000000000000003b3300003b33000aa88aa0007bb700
000000008888888888888888888ffff888888888888888800888888088f1ff180505900090000000000000000000000002888820028888200299992007bbb370
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff850509000900000000499994000000000089888807898888709a999907bbb3bb7
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff850509000900000000050050000000000088889807888898709999a9073b33bb7
0000000008fffff008fffff00033330008fffff00fffff8088fffff808333380050590009000000000055000000000000889888008898880099a999007333370
00000000003333000033330007000070073333000033337008f1ff10003333000000400040000000005005000000000002888820028888200299992000733700
00000000007007000070007000000000000007000000700007733370007007000000000000000000000550000499994000288200002882000029920000077000
00000000000000000000000055000000666566650000066600000000d666666dd666666dd666066d4fff4fff4fff4fff4fff4fff000000000000000070000000
000777770000000000000000667000006765676500077776000000006dddddd56ddd5dd56dd50dd5444444444444444444444444007700000770070007000007
00776670000000000000000067777000677067700000076600000000666ddd55666d6d5556500555000450000000000000054000007770700777000000000000
0767770000000000000000006660000007000700000000550070007066ddd5d5656505d500000055004500000000000000005400077777700770000000000000
077660000777770000000000550000000700070000000666007000706ddd5dd56dd5065565000000045000000000000000000540077777700000700000000000
077770000777767007700000667000000000000000077776067706776ddd6d656ddd7d656d500565450000000000000000000054077777700000077000000000
0000000000000077007777706777700000000000000007665676567605ddd65005d5d65005505650500000000000000000000005070777000007077007000070
00000000000000000007777766600000000000000000005556665666000000000000000000000000000000000000000000000000000000007000000000000000
566666655666666666666666666666656dddd6d1111111111d6dddd6566666650000000000000000000000000000000077577775777cccccccccc77700000000
66d66d66666ddddddd6dd6ddddddd6666d6666d1111111111d6666d666111166000000000000000000000000000000007777777777cccccccccccc7700000000
6dddddd666ddddd1d666666d1ddddd666d6dddd1111111111dddd6d6611dd1160000000000000000000000000000000077cc777777cccc7ccccccc7700000000
66d11d666ddd1111d6dddd6d1111ddd66d6d66d1111111111d66d6d6611dd11600000000000000000000000000000000ccccc777577cccccccccc77500000000
66d11d666dd11dd1d6d11d6d1dd11dd66d6dd6d1111111111d6dd6d66d1dd1d600000000000000000000000000000000cccccc77577cccccc77cc77500000000
6dddddd66dd1ddd1d611116d1ddd1dd66d6dd6d1111111111d6dd6d66dd11dd600000000000000000000000000000000ccc7cc7577ccccccc77ccc7700000000
66d66d666dd1ddd1661661661ddd1dd66d66666111111111166666d66dddddd600000000000000000000000000000000ccccc77577cc7ccccccccc7700000000
566666656d11111111111111111111d66ddddd611111111116ddddd66dddddd600000000000000000000000000000000ccccc777777cccccccccc77700000000
6dddddd66d11111111111111111111d65666666666666666666666506dddddd600000000000000000000000000000000ccccc777004bbb00004b000000400bbb
6d1111d66dd1ddd1dddddddd1ddd1dd666111111dddddddddd11dd656dddddd600000000000000000000000000000000ccccc777004bbbbb004bb000004bbbbb
6d1dd1d66dd1ddd1111dd1111ddd1dd66d1dddd1d111ddddd111ddd66dd11dd600000000000000000000000000000000c77ccc7504200bbb042bbbbb042bbb00
6d1111d66dd11dd1d61dd16d1dd11dd66d1d11d1d1ddddddd111d1156d1dd1d600000000000000000000000000000000c77ccc75040000000400bbb004000000
6dd11dd66ddd1111d611116d1111ddd66d1dd1d1d1dddddddd11d115611dd11600000000000000000000000000000000ccccc777040000000400000004000000
61d11d1666ddddd1d666666d1ddddd666d1111ddd111111dddddd115611dd1160000000000000000000000000000000077cc7777420000004200000042000000
61d11d16666dddddddddddddddddd66666dddddddddddddddddd1d65661111660000000000000000000000000000000077777777400000004000000040000000
61111116566666666666666666666665566666666666666666666650566666650000000000000000000000000000000077557775400000004000000040000000
0000000000000000000000000000000000aaaaa0000aaa000000a000000000000000000000000000000000000000000000100001010000000100100011010010
0000000000000000000007000000760000a000a0000a0a000000a00000000000000000000000000000000000000000000d00d0d0d000d00d0d0000d00dd1ddd0
0000000000000000000007600000676000a909a0000a0a000000a000000aa000000000000000000000000000000000002021d2222221d2020201d0002001d020
00000000000000000000676000000676009aaa900009a9000000a000000aa000000000000000000000000000000000000221d2222221d222222102202021d200
000000000000000000065766076000670000a0000000a0000000a000000aa0000000000000000000000000000000000000111111111111111111110000111110
000000000000000007777556067600560099a0000009a0000000a000000aa00000000000000000000000000000000000d0ddd1ddddddd1ddddddd1d00dddd100
000000000000000000666565006765650009a0000000a0000000a0000000000000000000000000000000000000000000002221d2222221d2222221d020222102
0000000000000000000066580006765800aaa0000009a0000000a0000000000000000000000000000000000000000000022221d2222221d2222221d0002221d0
00000000000000000000000000666600000000000000000000000000000000000000000000000000000000000000000011111111111111111111111101111110
00000000000000000000000006877760000000000000000000000000000000000000000000000000000000000000000000d1ddddddd1ddddddd1ddd000d1dd00
0000000000000000000000006877788600000000000000000000000000000000000000000000000000000000000000002021d2222221d2222221d2202021d220
00000000000000000000000068e2e22600000000000000000000000000000000000000000000000000000000000000000201d2222221d2222221d2000021d020
00000000000000000000000068822826000000000000000000000000000000000000000000000000000000000000000000111111111111111111111001011100
0000000000000000000000006e282226000000000000000000000000000000000000000000000000000000000000000000ddd1ddddddd1ddddddd10d00ddd1d0
00000000000000000000000006e228600000000000000000000000000000000000000000000000000000000000000000022221d2222221d2222221d0022221d0
000000000000000000000000006666000000000000000000000000000000000000000000000000000000000000000000022221d2222221d222222100222221d2
000000000000000006d6667006666d60000000000000000000000000000000000000000000000000000000000000000010221d22111111111111110101111010
00000000000000006d666d6006d766d600000000000000000000000000000000000000000000000000000000000000000d221dddddd1ddddddd1ddddd0d1dd00
0000000000000000d66dd8d00d8dd66d000000ddddd00000000000888880000000000000000000000000000000000000002211112221d2222221d2200221d202
0000000000000000676d6d6006d6d6660000dd7ddd1dd0000000887888288000000000000000000000000000000000000ddd1d222221d2222221d2020021d200
0000000000000000666d66655666d676000ddd07dd5ddd000008880788e888000000000000000000000000000000000000111d22111111111111111010111110
00000000000000006ddd6d5005d6ddd6000ddd7d15d51500008888782e8e2e80000000dddd000000000000000000000010221d22ddddd1dddddd00000dddd10d
00000000000000006d6ddd5555ddd6d600d7ddddddddddd0007788888888888000000dc55cd0000000000000000000000d02020202000002220001d2202220d0
0000000000000000676d65500556d76600d77dd551ddddd00070788ee28888800d55555cc55555d0000000000000000000200d0000000100202020d002002102
0000000000000000676d65500556d67600707dddd5ddddd00000078885888880d5ddddc11cdddd5d000000000000000001101100100100010100010100101110
000000000000000066dd65000056dd6600d77dddddddddd000707888888888805d00ddc11cdd00d50000000000000000000100dddd000ddd00011000ddd10d00
00000000000000006d8dd555555dd8d600d7ddddddd15dd0007788888882e800d000dd5cc5dd000d00000000000000000201d2222220d2222221d2200021d222
000000000000000076dd6d6006d6dd66000dd07ddddddd000088807888888800000005dddd50000000000000000000002021d2222221d2222221d2002221d220
0000000000000000666d76d00d66d666000dd7ddd15ddd000008878882e88000000000dddd000000000000000000000000011111111111111111111000111101
000000000000000066d8ddd00ddd8d670000ddd55dddd0000000888ee888800000000000000000000000000000000000d0ddd1ddddddd0ddddddd10dddd0d1dd
0000000000000000566d66d00d66d665000000d1ddd00000000000828880000000000000000000000000000000000000000001d022020102020220d000222002
000000000000000005676d6006d676500000000000000000000000000000000000000000000000000000000000000000002000d0200000d2220201d000000000
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
0000000000000000000000000000000000000002020202000000080808000000030303030303030300000000000000000303030303030303000000000000000000000000000000000000000004040404000000000000000000000000040404040000000300000000000000000404040400000000000000000000000004040404
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2532323232323232323232323232322500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
265d5d5d6e006f00000000000000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
265d5d5e00000000002700437c4e002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
265d6d5d4d201a1b1c374e00005f002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
266e005c5d6e000000006c4d4d5e002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2600005c5e0044006400005c5d5d4d2400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
267d2122230000000000005c5d6d5d2400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
26003132330800000000006c5e005c2400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2600004200004c4d7e0000006c7d6d2400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2600000000005c5e000000000000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
260000004c4d5d6d4d4e00000000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2600004c5d5d5e005c5d4e0a0000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2600343535353535353535360000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
267d5d5d6e006c5d6e6200000000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
26005c5e0001005f000000000000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2522222222222222222222222222222500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

