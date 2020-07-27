pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- ~celeste~
-- matt thorson + noel berry

-- globals --
-------------

-- <fruitrain> --
full_restart=false
-- </fruitrain> --
room = { x=0, y=0 }
objects = {}
types = {}
freeze=0
will_restart=false
delay_restart=0
got_fruit={}
has_dashed=false
sfx_timer=0
has_key=false
pause_player=false
music_timer=0

k_left=0
k_right=1
k_up=2
k_down=3
k_jump=4
k_dash=5

--- <snowball> ---
snowball_timer=0
is_snowball=false
player_y=0
--- </snowball> ---

--- <wind> ---
wind_particlespd=6
is_wind=false
--- </wind> ---

-- entry point --
-----------------

function _init()
  got_fruit = {}
  for i=0,29 do
    add(got_fruit,false) end
  deaths=0
  max_djump=1

  frames=0
  seconds=0
  minutes=0
  music_timer=0
  music(0,0,7)
  load_room(0,0)
end

function level_index()
  return room.x%8+room.y*8
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
for i=0,48 do
  add(particles,{
      x=rnd(128),
      y=rnd(128),
      s=0+flr(rnd(5)/3),
      spd=0.1+rnd(0.9),
      wspd=0,
      off=rnd(0.5),
      c=6+flr(0.5+rnd(1))
    })
end

dead_particles = {}

-- player entity --
-------------------
function do_dash(this, input)
  local d_full=5
  local d_half=d_full*0.70710678118
  local input = btn(k_right) and 1 or (btn(k_left) and -1 or 0)

  init_object(smoke,this.x,this.y)
  this.djump-=1
  this.dash_time=4
  has_dashed=true
  this.dash_effect_time=10
  local v_input=(btn(k_up) and -1 or (btn(k_down) and 1 or 0))
  if input!=0 then
    if v_input!=0 then
      this.spd.x=input*d_half
      this.spd.y=v_input*d_half
    else
      this.spd.x=input*d_full
      this.spd.y=0
    end
  elseif v_input!=0 then
    this.spd.x=0
    this.spd.y=v_input*d_full
  else
    this.spd.x=(this.flip.x and -1 or 1)
    this.spd.y=0
  end

  psfx(3)
  freeze=2
  this.dash_target.x=2*sign(this.spd.x)
  this.dash_target.y=2*sign(this.spd.y)
  this.dash_accel.x=1.5
  this.dash_accel.y=1.5

  if this.spd.y<0 then
    this.dash_target.y*=.75
  end

  if this.spd.y!=0 then
    this.dash_accel.x*=0.70710678118
  end
  if this.spd.x!=0 then
    this.dash_accel.y*=0.70710678118
  end
end
player =
{
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
    this.hitbox = {x=1,y=3,w=6,h=5}
    this.spr_off=0
    this.was_on_ground=false
    create_hair(this)
    -- <fruitrain> --
    this.berry_timer=0
    this.berry_count=0
  -- </fruitrain> --
  end,
  update=function(this)
    if (pause_player) return

    local input = btn(k_right) and 1 or (btn(k_left) and -1 or 0)

    -- spikes collide
    if spikes_at(this.x+this.hitbox.x,this.y+this.hitbox.y,this.hitbox.w,this.hitbox.h,this.spd.x,this.spd.y) then
      kill_player(this) end

    -- bottom death
    if this.y>128 then
      kill_player(this) end
    local on_ground=this.is_solid(0,1)
    local on_ice=this.is_ice(0,1)

    -- <fruitrain> --
    if on_ground then
      this.berry_timer+=1
    else
      this.berry_timer=0
      this.berry_count=0
    end

    local fr=nil
    local fr1=fruitrain[1]
    local fr2=fruitrain[2]
    if fr1~=nil then
      if fr1.type.golden and fr2~=nil then
        fr=fr2
      elseif fr1.type.golden==nil or level_index()==30 then
        fr=fr1
      end
    end

    if this.berry_timer>5 and fr~=nil then
      -- to be implemented:
      -- save berry
      -- save golden
      got_fruit[fr.level+1]=true
      init_object(lifeup, fr.x, fr.y)
      del(fruitrain, fr)
      destroy_object(fr)
      this.berry_timer=-5
      this.berry_count+=1
      if (fruitrain[1]~=nil) fruitrain[1].target=get_player()
    end
    -- </fruitrain> --

    -- smoke particles
    if on_ground and not this.was_on_ground then
      init_object(smoke,this.x,this.y+4)
    end

    local jump = btn(k_jump) and not this.p_jump
    this.p_jump = btn(k_jump)
    if (jump) then
      this.jbuffer=4
    elseif this.jbuffer>0 then
      this.jbuffer-=1
    end

    local dash = btn(k_dash) and not this.p_dash
    this.p_dash = btn(k_dash)

    if on_ground then
      this.grace=6
      if this.djump<max_djump then
        psfx(54)
        this.djump=max_djump
      end
    elseif this.grace > 0 then
      this.grace-=1
    end

    this.dash_effect_time -=1
    if this.dash_time > 0 then
      init_object(smoke,this.x,this.y)
      this.dash_time-=1
      this.spd.x=appr(this.spd.x,this.dash_target.x,this.dash_accel.x)
      this.spd.y=appr(this.spd.y,this.dash_target.y,this.dash_accel.y)
    else

      -- move
      local maxrun=1
      local accel=0.6
      local deccel=0.15

      if not on_ground then
        accel=0.4
      elseif on_ice then
        accel=0.05
        if input==(this.flip.x and -1 or 1) then
          accel=0.05
        end
      end

      if abs(this.spd.x) > maxrun then
        this.spd.x=appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
      else
        this.spd.x=appr(this.spd.x,input*maxrun,accel)
      end

      --facing
      if this.spd.x!=0 then
        this.flip.x=(this.spd.x<0)
      end

      -- gravity
      local maxfall=2
      local gravity=0.21

      if abs(this.spd.y) <= 0.15 then
        gravity*=0.5
      end

      -- wall slide
      if input!=0 and this.is_solid(input,0) and not this.is_ice(input,0) then
        maxfall=0.4
        if rnd(10)<2 then
          init_object(smoke,this.x+input*6,this.y)
        end
      end

      if not on_ground then
        this.spd.y=appr(this.spd.y,maxfall,gravity)
      end

      -- jump
      if this.jbuffer>0 then
        if this.grace>0 then
          -- normal jump
          psfx(1)
          this.jbuffer=0
          this.grace=0
          this.spd.y=-2
          init_object(smoke,this.x,this.y+4)
        else
          -- wall jump
          local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
          if wall_dir!=0 then
            psfx(2)
            this.jbuffer=0
            this.spd.y=-2
            this.spd.x=-wall_dir*(maxrun+1)
            if not this.is_ice(wall_dir*3,0) then
              init_object(smoke,this.x+wall_dir*6,this.y)
            end
          end
        end
      end

      -- dash
      if this.djump>0 and dash then
        do_dash(this)
      elseif dash and this.djump<=0 then
        psfx(9)
        init_object(smoke,this.x,this.y)
      end

    end

    -- animation
    this.spr_off+=0.25
    if not on_ground then
      if this.is_solid(input,0) then
        this.spr=5
      else
        this.spr=3
      end
    elseif btn(k_down) then
      this.spr=6
    elseif btn(k_up) then
      this.spr=7
    elseif (this.spd.x==0) or (not btn(k_left) and not btn(k_right)) then
      this.spr=1
    else
      this.spr=1+this.spr_off%4
    end

    -- next level
    if this.y<-4 and level_index()<30 then next_room() end

    -- was on the ground
    this.was_on_ground=on_ground
    --- <snowball> ---
    player_y=this.y
  --- </snowball> ---

  end,  --<end update loop

  draw=function(this)

    -- clamp in screen
    if this.x<-1 or this.x>121 then
      this.x=clamp(this.x,-1,121)
      this.spd.x=0
    end

    set_hair_color(this.djump)
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
  tile=1,
  init=function(this)
    sfx(4)
    this.spr=3
    this.target= {x=this.x,y=this.y}
    this.y=128
    this.spd.y=-4
    this.state=0
    this.delay=0
    this.solids=false
    create_hair(this)
    --- <fruitrain> ---
    for i=1,#fruitrain do
      local f=nil
      if fruitrain[i].type.golden then
        f=init_object(golden_fruit,this.x,this.y)
      else
        f=init_object(fruit,this.x,this.y)
      end
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
      if this.spd.y>0 and this.delay>0 then
        this.spd.y=0
        this.delay-=1
      end
      if this.spd.y>0 and this.y > this.target.y then
        this.y=this.target.y
        this.spd = {x=0,y=0}
        this.state=2
        this.delay=5
        init_object(smoke,this.x,this.y+4)
        sfx(5)
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
        if (f~=nil) f.target=p
      --- </fruitrain> ---
      end
    end
  end,
  draw=function(this)
    set_hair_color(max_djump)
    draw_hair(this,1)
    spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
    unset_hair_color()
  end
}
add(types,player_spawn)
--- <bubble> ---
green_bubble = {  --by amegpo
  tile=124,
  init=function(this)
    this.timer=0
    this.dead_timer=0
    this.shake=0
    this.draw_x=this.x
    this.draw_y=this.y
    this.player=nil
  end,
  update=function(this)
    local hit=this.collide(player, 0, 0)
    if hit~=nil then
      if this.spr>0 then
        this.player=hit
        hit.visible=false
        if this.timer==0 then
          this.timer=1
          this.shake=5
        end
      end
      this.draw_x=this.x
      this.draw_y=this.y
      if this.timer>0 then
        if this.shake>0 then
          this.draw_x+=rnd(2)-1
          this.draw_y+=rnd(2)-1
          this.shake-=1
        end
        hit.x=this.x
        hit.y=this.y
        this.timer+=1
        if this.timer==20 or btnp(k_dash) then
          hit.visible=true
          do_dash(hit)
          hit.djump=max_djump
          this.spr=0
          this.timer=0
        end
      end
    elseif this.player~=nil then
      this.player.visible=true
      this.spr=0
      this.timer=0
      this.player=nil
    end
    if this.spr==0 then
      this.dead_timer+=1
      if this.dead_timer==60 then
        this.dead_timer=0
        this.spr=124
        init_object(smoke, this.x, this.y)
      end
    end
  end,
  draw=function(this)
    spr(this.spr,this.draw_x,this.draw_y)
  end

}
add(types, green_bubble)
--- </bubble> ---
-- <falling_platform>
fall_plat={
  tile=76,
  init=function(this)
    this.yspd = 0
    this.state = -1
    this.timer = -1
    this.last = {x=this.x,y=this.y}
    this.finished = false
  end,
  clip_out=function(player)
    local clipped=player.collide(fall_plat,0,0)
    if clipped == nil then return end
    for i=1,8 do
      if player.check(fall_plat,0,0) then
        player.y += 1
      else
        break
      end
    end
    if player.is_solid(0,1) then
      kill_player(player)
    end
  end,
  update=function(this)
    local hit = this.collide(player,0,-1)
    if hit~=nil then
      if this.state==-1 then
        this.state = 0  -- shake
        this.timer = 10
      end
    end

    if this.is_solid(0,1) and not this.finished then
      this.finished = true
      this.state = 0  -- shake
      this.timer = 6
    end

    if this.timer >= 0 then
      this.timer -= 1
      if this.timer==0 then
        this.state = 1  -- falling
      end
    end

    if this.state==1 then
      this.yspd = appr(this.yspd,3,0.4)
      this.move_y(this.yspd)
      if hit~=nil then
        for i=0,this.y-this.last.y do
         if hit.is_solid(0,1) then
          break
         else
          hit.y += 1
         end
        end
      end
            local tophit = this.collide(player,0,1)
            if tophit!=nil then
                tophit.move_y(this.y-this.last.y,1)
        fall_plat.clip_out(tophit)
            end
    end

    this.last.x = this.x
    this.last.y = this.y
  end,
  draw=function(this)
    if this.state==0 then
      spr(76,this.x+rnd(2),this.y+rnd(2))
    else
      spr(76,this.x,this.y)
    end
  end
}
add(types,fall_plat)
-- </falling_platform>
--- <snowball> ---
snowball = {  --by amegpo
  tile=125,
  init=function(this)
  end,
  update=function(this)
    this.x-=2
    local hit=this.collide(player, 0, 0)
    if hit~=nil then
      if hit.y<this.y then
        hit.djump=max_djump
        hit.spd.y=-2
        psfx(1)
        hit.dash_time=-1
        init_object(smoke, this.x, this.y)
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
--- </snowball> ---
--- <moving_platform> ---
moving_platform={
  init=function(this)
    this.initial={x=this.x,y=this.y}
    this.start=false
    this.dir=1
    this.hitbox.w=16
    this.hide_for=0
    this.delay=15
    this.death_delay=0
    this.spdx = 0
  end,
  respawn=function(this)
    local dir=this.dir
    this.x=this.initial.x
    this.y=this.initial.y
    this.collideable=true
    moving_platform.init(this)
    this.dir=dir
    init_object(smoke,this.x,this.y)
    init_object(smoke,this.x+8,this.y)
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for==0 then
        moving_platform.respawn(this)
      end
    else
      if this.start then
        this.spdx=(frames%3==0 and 1 or 0)*this.dir

      end
      if this.delay>0 then
        local tophit=this.collide(player,0,-1)
        local horhit=this.collide(player,1*this.dir,0)
        if horhit~=nil then
          horhit.move_x(this.spdx,0)
        end
        local lastx=this.x
        this.move_x(this.spdx,0)
        if horhit~=nil and horhit.is_solid(0,0) then
          kill_player(horhit)
        end
        if tophit~=nil then
          this.start=true
          local input = btn(k_down) and 1 or (btn(k_up) and -1 or 0)
          local tomove=(frames%3==0 and 1 or 0)*input
          if not tophit.is_solid(0,tomove-1) then
            if input==1 then
              this.move_y(tomove)
              tophit.move_y(tomove)
            else
              tophit.move_y(tomove)
              this.move_y(tomove)
            end
          end
          tophit.move_x(this.x-lastx,1)
        end
      end
      if this.start and this.is_solid(this.dir,0) then
        if this.delay>0 then
          this.delay-=1
          if this.delay==0 then
            this.death_delay=10
          end
        elseif this.death_delay>0 then
          this.death_delay-=1
        else
          init_object(smoke,this.x,this.y)
          init_object(smoke,this.x+8,this.y)
          this.hide_for=60
          this.collideable=false
        end
      else
        this.delay=15
      end
    end
  end,
  draw=function(this)
    if this.hide_for<=0 then
      if this.start and this.delay>0 then
        pal(13,11)
      elseif this.death_delay>0 then
        pal(13,8)
      end
      spr(73,this.x,this.y,2,1,this.dir==-1)
      if this.collide(player,0,-1)==nil and not this.is_solid(0,-1)then
        line(this.x+2,this.y-1,this.x+13,this.y-1,13)
      end
      pal(13,13)
    end

  end
}
--- </moving_platform> ---
spring = {
  tile=18,
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
    elseif this.spr==18 then
      local hit = this.collide(player,0,0)
      if hit ~=nil and hit.spd.y>=0 then
        this.spr=19
        hit.y=this.y-4
        hit.spd.x*=0.2
        hit.spd.y=-3
        hit.djump=max_djump
        this.delay=10
        init_object(smoke,this.x,this.y)

        -- breakable below us
        local below=this.collide(fall_floor,0,1)
        if below~=nil then
          break_fall_floor(below)
        end

        psfx(8)
      end
    elseif this.delay>0 then
      this.delay-=1
      if this.delay<=0 then
        this.spr=18
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
add(types,spring)
--- <side spring> ---
side_spring = {
  init=function(this)
    this.hide_in=0
    this.hide_for=0
    this.delay=0
    this.dir=0
    this.spr=78
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for<=0 then
        this.spr=78
        this.delay=0
      end
    elseif this.spr==78 then
      local hit = this.collide(player,0,0)
      if hit ~=nil and this.dir*hit.spd.x<=0 then
        this.spr=79
        hit.x=this.x+this.dir*4
        hit.spd.x=this.dir*3
        hit.spd.y=-1
        hit.djump=max_djump
        hit.dash_time=0
        hit.dash_effect_time=0
        this.delay=10
        init_object(smoke,this.x,this.y)
        local left=this.collide(fall_floor,-1,0)
        if left~=nil then
          break_fall_floor(left)
        end
        psfx(8)
      end
    elseif this.delay>0 then
      this.delay-=1
      if this.delay<=0 then
        this.spr=78
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
--- <side spring> ---
function break_spring(obj)
  obj.hide_in=15
end

refill = {
  tile=22,
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
      if hit~=nil and hit.djump<max_djump then
        psfx(6)
        init_object(smoke,this.x,this.y)
        hit.djump=max_djump
        this.active=false
        this.timer=60
      end
    elseif this.timer>0 then
      this.timer-=1
    else
      psfx(7)
      init_object(smoke,this.x,this.y)
      this.active=true
    end
  end,
  draw=function(this)
    if this.active then
      spr(22,this.x,this.y+sin(this.offset)*1+0.5)
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
add(types,refill)

fall_floor = {
  tile=23,
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
        psfx(7)
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
add(types,fall_floor)

function break_fall_floor(obj)
  if obj.state==0 then
    psfx(15)
    obj.state=1
    obj.delay=15  --how long until it falls
    init_object(smoke,obj.x,obj.y)
    local hit=obj.collide(spring,0,-1)
    if hit~=nil then
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
  tile=26,
  if_not_fruit=true,
  init=function(this)
    this.y_=this.y
    this.off=0
    this.follow=false
    this.tx=this.x
    this.ty=this.y
    this.level=level_index()
  end,
  update=function(this)
    if not this.follow then
      if this.collide(player,0,0)~=nil then
        get_player().berry_timer=0
        this.follow=true
        this.target=#fruitrain==0 and get_player() or fruitrain[#fruitrain]
        this.r=#fruitrain==0 and 12 or 8
        add(fruitrain,this)
      end
    else
      local p=get_player()
      if p~=nil then
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
  end,
  draw=function(this)
    spr(this.type.tile, this.x, this.y)
  end
}
add(types,fruit)

golden_fruit={}
for key, value in pairs(fruit) do
  golden_fruit[key] = value
end
golden_fruit.if_not_fruit=nil
golden_fruit.tile=123
golden_fruit.golden=true
add(types,golden_fruit)
--- </fruitrain> ---

fly_fruit={
  tile=28,
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
          sfx(14)
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
    if hit~=nil then
      --- <fruitrain> ---
      init_object(smoke, this.x-6, this.y)
      init_object(smoke, this.x+6, this.y)
      local f=init_object(fruit, this.x, this.y)
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
    spr(45+off,this.x-6,this.y-2,1,1,true,false)
    spr(this.spr,this.x,this.y)
    spr(45+off,this.x+6,this.y-2)
  end
}
add(types,fly_fruit)

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
    sfx(13)
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

    print("1000",this.x-2,this.y,7+this.flash%2)
  end
}

--- <beeg fake wall> ---
beeg_fake_wall={
  tile=81,
  init=function(this)
    local match=nil
    for o in all(corners) do
      if o.x==this.x then
        match=o
        break
      end
    end
    if (match==nil) then
      destroy_object(this)
      return
    end
    this.h=(this.y-match.y)/8+1
    this.y=match.y
    this.x-=8
    this.has_fruit=false
    for o in all(objects) do
      if o.type==fruit and o.x==this.x and o.y==this.y then
        this.has_fruit=true
        destroy_object(o)
        break
      end
    end
  end,
  update=function(this)
    this.hitbox={x=-1,y=-1,w=18,h=this.h*8+2}
    local hit = this.collide(player,0,0)
    if hit~=nil and hit.dash_effect_time>0 then
      hit.spd.x=-sign(hit.spd.x)*1.5
      hit.spd.y=-1.5
      hit.dash_time=-1
      sfx_timer=20
      sfx(16)
      destroy_object(this)
      for i=0,this.h-1 do
        init_object(smoke,this.x,this.y+8*i)
        init_object(smoke,this.x+8,this.y+8*i)
      end
      if this.has_fruit then
        init_object(fruit,this.x+4,this.y+4)
      end
    end
    this.hitbox={x=0,y=0,w=16,h=this.h*8}
  end,
  draw=function(this)
    spr(64,this.x,this.y,2.0,1.0)
    for i=1,this.h-2 do
      spr(80,this.x,this.y+8*i)
      spr(75,this.x+8,this.y+8*i)
    end
    spr(65,this.x,this.y+8*(this.h-1),1.0,1.0,true,true)
    spr(81,this.x+8,this.y+8*(this.h-1))
  end
}
add(types,beeg_fake_wall)
--- </beeg fake wall> ---
key={
  tile=8,
  if_not_fruit=true,
  update=function(this)
    local was=flr(this.spr)
    this.spr=9+(sin(frames/30)+0.5)*1
    local is=flr(this.spr)
    if is==10 and is!=was then
      this.flip.x=not this.flip.x
    end
    if this.check(player,0,0) then
      sfx(23)
      sfx_timer=10
      destroy_object(this)
      has_key=true
    end
  end
}
add(types,key)

chest={
  tile=20,
  if_not_fruit=true,
  init=function(this)
    this.x-=4
    this.start=this.x
    this.timer=20
  end,
  update=function(this)
    if has_key then
      this.timer-=1
      this.x=this.start-1+rnd(3)
      if this.timer<=0 then
        sfx_timer=20
        sfx(16)
        init_object(fruit,this.x,this.y-4)
        destroy_object(this)
      end
    end
  end
}
add(types,chest)

platform={
  init=function(this)
    this.x-=4
    this.solids=false
    this.hitbox.w=16
    this.last=this.x
  end,
  update=function(this)
    this.spd.x=this.dir*0.65
    if this.x<-16 then this.x=128
    elseif this.x>128 then this.x=-16 end
    if not this.check(player,0,0) then
      local hit=this.collide(player,0,-1)
      if hit~=nil then
        hit.move_x(this.x-this.last,1)
      end
    end
    this.last=this.x
  end,
  draw=function(this)
    spr(11,this.x,this.y-1)
    spr(12,this.x+8,this.y-1)
  end
}

flag = {
  tile=118,
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
    this.spr=118+(frames/5)%3
    spr(this.spr,this.x,this.y)
    if this.show then
      rectfill(32,2,96,31,0)
      spr(26,55,6)
      print("x"..this.score,64,9,7)
      draw_time(49,16)
      print("deaths:"..deaths,48,24,7)
    elseif this.check(player,0,0) then
      sfx(55)
      sfx_timer=30
      this.show=true
    end
  end
}
add(types,flag)

room_title = {
  init=function(this)
    this.delay=5
  end,
  draw=function(this)
    this.delay-=1
    if this.delay<-30 then
      destroy_object(this)
    elseif this.delay<0 then

      rectfill(24,58,104,70,0)
      --rect(26,64-10,102,64+10,7)
      --print("---",31,64-2,13)
      if room.x==3 and room.y==1 then
        print("old site",48,62,7)
      elseif level_index()==30 then
        print("summit",52,62,7)
      else
        local level=(1+level_index())*100
        print(level.." m",52+(level<1000 and 2 or 0),62,7)
      end
      --print("---",86,64-2,13)

      draw_time(4,4)
    end
  end
}

-- object functions --
-----------------------

function init_object(type,x,y)
  if type.if_not_fruit~=nil and got_fruit[1+level_index()] then
    return
  end
  local obj = {}
  obj.type = type
  obj.collideable=true
  obj.solids=true

  obj.spr = type.tile
  obj.flip = {x=false,y=false}

  obj.x = x
  obj.y = y
  obj.hitbox = { x=0,y=0,w=8,h=8 }

  obj.spd = {x=0,y=0}
  obj.rem = {x=0,y=0}

  obj.visible = true

  obj.is_solid=function(ox,oy)
    if oy>0 and not obj.check(platform,ox,0) and obj.check(platform,ox,oy) then
      return true
    end
    return solid_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
    or obj.check(fall_floor,ox,oy)
    --- <moving_platform> ---
    or obj.check(moving_platform,ox,oy)
    --- </moving_platform> ---
    --- <beeg fake wall> ---
    or obj.check(beeg_fake_wall,ox,oy)
    --- </beeg fake wall> ---
    --- <falling_platform> ---
    or obj.check(fall_plat,ox,oy)
  --- </falling_platform> ---
  end

  obj.is_ice=function(ox,oy)
    return ice_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
  end

  obj.collide=function(type,ox,oy)
    local other
    for i=1,count(objects) do
      other=objects[i]
      if other ~=nil and other.type == type and other != obj and other.collideable and
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
    return obj.collide(type,ox,oy) ~=nil
  end

  obj.move=function(ox,oy)
    local amount
    -- [x] get move amount
    obj.rem.x += ox
    --- <wind> ---
    if is_wind and obj.type==player and obj.dash_time<=0 then
      obj.rem.x-=0.5
    end
    --- </wind> ---
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
  if obj.type.init~=nil then
    obj.type.init(obj)
  end
  return obj
end

function destroy_object(obj)
  del(objects,obj)
end

function kill_player(obj)
  sfx_timer=12
  sfx(0)
  deaths+=1
  destroy_object(obj)
  dead_particles={}
  for dir=0,7 do
    local angle=(dir/8)
    add(dead_particles,{
        x=obj.x+4,
        y=obj.y+4,
        t=10,
        spd={
          x=sin(angle)*3,
          y=cos(angle)*3
        }
      })

  end

  -- <fruitrain> ---
  for f in all(fruitrain) do
    local g=f.type.golden
    del(fruitrain,f)
    if (g) full_restart=true
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
  if room.x==2 and room.y==1 then
    music(30,500,7)
  elseif room.x==3 and room.y==1 then
    music(20,500,7)
  elseif room.x==4 and room.y==2 then
    music(30,500,7)
  elseif room.x==5 and room.y==3 then
    music(30,500,7)
  end

  if room.x==7 then
    load_room(0,room.y+1)
  else
    load_room(room.x+1,room.y)
  end
end
--- <beeg fake wall> ---
corners={}
--- </beeg fake wall> ---
function load_room(x,y)
  has_dashed=false
  has_key=false
  --- <beeg fake wall> ---
  corners={}
  --- </beeg fake wall> ---
  --- <snowball> ---
  snowball_timer=0
  is_snowball=false
  --- </snowball> ---
  --- <wind> ---
  was_wind=is_wind
  is_wind=false
  --- </wind> ---
  --remove existing objects
  foreach(objects,destroy_object)

  --current room
  room.x = x
  room.y = y

  -- entities
  for tx=0,15 do
    for ty=0,15 do
      local tile = mget(room.x*16+tx,room.y*16+ty);
      if tile==11 then
        init_object(platform,tx*8,ty*8).dir=-1
      elseif tile==12 then
        init_object(platform,tx*8,ty*8).dir=1
      --- <beeg fake wall> ---
      elseif tile==65 then
        add(corners,{x=tx*8,y=ty*8})
      --- </beeg fake wall> ---
      --- <moving_platform> ---
      elseif tile==73 then
        init_object(moving_platform,tx*8-8,ty*8).dir=-1
      elseif tile==74 then
        init_object(moving_platform,tx*8-8,ty*8).dir=1
      --- </moving_platform> ---
      --- <side spring> ---
      elseif tile==78 then
        init_object(side_spring,tx*8,ty*8).dir=1
      elseif tile==79 then
        init_object(side_spring,tx*8,ty*8).dir=-1
      --- </side spring> ---
      --- <snowball> ---
      elseif tile==125 then
        is_snowball=true
      --- </snowball> ---
      --- <wind> ---
      elseif tile==129 then
        is_wind=true
      ---</wind> ---
      else
        foreach(types,
          function(type)
            if type.tile == tile then
              init_object(type,tx*8,ty*8)
            end
          end)
      end
    end
  end
  init_object(room_title,0,0)
end

-- update function --
-----------------------

function _update()
  frames=((frames+1)%30)
  if frames==0 and level_index()<30 then
    seconds=((seconds+1)%60)
    if seconds==0 then
      minutes+=1
    end
  end

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
      if obj.type.update~=nil then
        obj.type.update(obj)
      end
    end)
  --- <snowball> ---
  -- snowballs (amegpo)
  if is_snowball then
    snowball_timer+=1
    if snowball_timer==60 then
      snowball_timer=0
      init_object(snowball, 128, player_y)
    end
  end
--- </snowball> ---
end

-- drawing functions --
-----------------------
function _draw()
  if freeze>0 then return end

  -- reset all palette values
  pal()

  -- clear screen
  local bg_col = 9
  if flash_bg then
    bg_col = frames/5
  elseif new_bg~=nil then
    bg_col=2
  end
  cls(bg_col)

  -- clouds
  foreach(clouds, function(c)
      c.x += c.spd
      rectfill(c.x,c.y,c.x+c.w,c.y+4+(1-c.w/64)*12,new_bg~=nil and 10 or 10)
      if c.x > 128 then
        c.x = -c.w
        c.y=rnd(128-8)
      end
    end)

  -- draw bg terrain
  map(room.x * 16,room.y * 16,0,0,16,16,4)

  -- platforms/big chest
  foreach(objects, function(o)
      if o.type==platform then
        draw_object(o)
      end
    end)

  -- draw terrain
  --pal(5,140,1)
  map(room.x*16,room.y * 16,0,0,16,16,2)

  -- draw objects
  foreach(objects, function(o)
      if o.type~=platform and o.visible then
        draw_object(o)
      end
    end)

  -- draw fg terrain
  map(room.x * 16,room.y * 16,0,0,16,16,8)

  --- <wind> ---
  foreach(particles, function(p)
      p.y += p.spd
      p.off+= min(0.05,p.spd/32)

      if is_wind then
        p.x -= p.wspd
        p.wspd=appr(p.wspd,wind_particlespd,0.5)
        line(p.x,p.y,p.x+p.wspd*1.5,p.y,7)
      else
        p.x += sin(p.off)-p.wspd
        p.wspd=appr(p.wspd,0,0.5)
        rectfill(p.x,p.y,p.x+p.s+p.wspd*1.5,p.y+p.s,7)
      end

      if p.y>128+4 then
        p.y=-4
        p.x=rnd(128)
      end

      if p.x<-4 then
        p.x=128+4
        p.y=rnd(128)
      end
    end)
  --- </wind> ---

  -- dead particles
  foreach(dead_particles, function(p)
      p.x += p.spd.x
      p.y += p.spd.y
      p.t -=1
      if p.t <= 0 then del(dead_particles,p) end
      rectfill(p.x-p.t/5,p.y-p.t/5,p.x+p.t/5,p.y+p.t/5,14+p.t%2)
    end)

  if level_index()==30 then
    local p
    for i=1,count(objects) do
      if objects[i].type==player then
        p = objects[i]
        break
      end
    end
    if p~=nil then
      local diff=min(24,40-abs(p.x+4-64))
      rectfill(0,0,diff,128,0)
      rectfill(128-diff,0,128,128,0)
    end
  end

end

function draw_object(obj)

  if obj.type.draw ~=nil then
    obj.type.draw(obj)
  elseif obj.spr > 0 then
    spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
  end

end

function draw_time(x,y)

  local s=seconds
  local m=minutes%60
  local h=flr(minutes/60)

  rectfill(x,y,x+32,y+6,0)
  print((h<10 and "0"..h or h)..":"..(m<10 and "0"..m or m)..":"..(s<10 and "0"..s or s),x+1,y+1,7)

end

-- helper functions --
----------------------
function get_player()
  for i=1,count(objects) do
    if objects[i].type==player or objects[i].type==player_spawn then
      return objects[i]
    end
  end
  return nil
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

function ice_at(x,y,w,h)
  return tile_flag_at(x,y,w,h,4)
end

function tile_flag_at(x,y,w,h,flag)
  for i=max(0,flr(x/8)),min(15,(x+w-1)/8) do
    for j=max(0,flr(y/8)),min(15,(y+h-1)/8) do
      if fget(tile_at(i,j),flag) then
        return true
      end
    end
  end
  return false
end

function tile_at(x,y)
  return mget(room.x * 16 + x, room.y * 16 + y)
end

function spikes_at(x,y,w,h,xspd,yspd)
  for i=max(0,flr(x/8)),min(15,(x+w-1)/8) do
    for j=max(0,flr(y/8)),min(15,(y+h-1)/8) do
      local tile=tile_at(i,j)
      if tile==17 and ((y+h-1)%8>=6 or y+h==j*8+8) and yspd>=0 then
        return true
      elseif tile==27 and y%8<=2 and yspd<=0 then
        return true
      elseif tile==43 and x%8<=2 and xspd<=0 then
        return true
      elseif tile==59 and ((x+w-1)%8>=6 or x+w==i*8+8) and xspd>=0 then
        return true
      end
    end
  end
  return false
end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700000000000000000000000000
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a0000777777677777770000000000000000000000000
000000008888888888888888888ffff888888888888888800888888088f1ff1800a909a0000a0a000000a0007766666667767777000000000000000000000000
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff8009aaa900009a9000000a0007677766676666677000000000000000000000000
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff80000a0000000a0000000a0000000000000000000000000000000000000000000
0000000008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0000000000000000000000000000000000000000000
00000000003333000033330007000070073333000033337008f1ff10003333000009a0000000a0000000a0000000000000000000000000000000000000000000
000000000070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a0000000000000000000000000000000000000000000
55555555000000100000000000000000000000000000000000077000d666666dd666666dd666066d0300b0b0077c7c100300b0b0000000000000000070000000
55555555001001c100000000000000000000000000000000007bb7006dddddd56ddd5dd56dd50dd5003b3300071c1cc1003b3300007700000770070007000007
5500005501c101c100000000000000000aaaaaa00000000007bbb370666ddd55666d6d55565005550288882001cc1cc102888820007770700777000000000000
5500005501c11c100499994000000000a998888a111111117bbb3bb766ddd5d5656505d5000000550898888001c11c1078988887077777700770000000000000
5500005501c11c100050050000000000a988888a1000000173b33bb76ddd5dd56dd50655650000000888898001c11c1078888987077777700000700000000000
550000551cc1cc100005500000000000aaaaaaaa11111111073333706ddd6d656ddd7d656d500565088988801c101c1008898880077777700000077000000000
555555551cc1c1700050050000000000a980088a144444410073370005ddd65005d5d65005505650028888201c10010002888820070777000007077007000070
5555555501c7c7700005500004999940a988888a1444444100077000000000000000000000000000002882000100000000288200000000007000000000000000
5777777557777777777777777777777577eeeeeeeeeeeeeeeeeeee77577777755555555555555555555555550110000007777770000000000000000000000000
77777777777777777777777777777777777eeeeeeeeeeeeeeeeee777777777775555555555555550055555551cc1110077777777000777770000000000000000
777e77777777eeeee777777eeeee7777777eeeeeeeeeeeeeeeeee77777777777555555555555550000555555cccccc1077777777007766700000000000000000
77eeee77777eeeeeeee77eeeeeeee7777777eeeeeeeeeeeeeeee7777777ee7775555555555555000000555557111110077773377076777000000000000000000
77eeee7777eeeeeeeeeeeeeeeeeeee777777eeeeeeeeeeeeeeee777777eeee77555555555555000000005555ccc1100077773377077660000777770000000000
777ee77777ee77eeeeeeeeeeeee7ee77777eeeeeeeeeeeeeeeeee77777eeee7755555555555000000000055571ccc11073773337077770000777767007700000
7777777777ee77eeeeeeeeeeeeeeee77777eeeeeeeeeeeeeeeeee77777e7ee7755555555550000000000005577111cc17333bb37000000000000007700777770
5777777577eeeeeeeeeeeeeeeeeeee7777eeeeeeeeeeeeeeeeeeee7777eeee77555555555000000000000005000001100333bb30000000000000000000077777
77eeee7777eeeeeeeeeeeeeeeeeeee77577777777777777777777775777eee775555555550000000000000050110000003333330000000000000000000000000
777eee7777eeeeeeeeeeeeeeeeeeee77777777777777777777777777777ee7775055555555000000000000551cc1117703b333300000000000ee0ee000000000
777eee7777ee7eeeeeeeeeeee77eee777777eee7777777777eee7777777ee777555500555550000000000555011ccc17033333300000000000eeeee000000030
77eee77777eeeeeeeeeeeeeee77eee77777eeeee7e7777eeeeeee77777eee77755550055555500000000555500011ccc0333b33000000000000e8e00000000b0
77eee777777eeeeeeee77eeeeeeee777777eeeeeee7777e7eeeee77777eeee7755555555555550000005555500111117003333000000b00000eeeee000000b30
777ee7777777eeeee777777eeeee77777777eee7777777777eee777777eeee7755055555555555000055555501cccccc00044000000b000000ee3ee003000b00
777ee777777777777777777777777777777777777777777777777777777ee77755555555555555500555555500111cc700044000030b00300000b00000b0b300
77eeee77577777777777777777777775577777777777777777777775577777755555555555555555555555550000011000999900030330300000b00000303300
5777755777577775000000000000000000000000000000000000000000000000eeeeeeee1dddddddddddddd1eeeee77757777775000000000000000000000000
7777777777777777000000000000000000000000000000000000000000000000e77eeeee1111111111111111eeeeee7777777777000000000000400040000000
7777ee7777ee7777000000000000000000000000000000000000000000000000e77ee7ee1d111111d11111d1eeeeee77777e7777000000000505900090000000
777eeeeeeeeee777000000000000000000000000000000000000000000000000eeeeeeee1d111111dd1111d1eeeee77577eeee77000000005050900090000000
57eeeeeeeeeeee77000000000000000000000000000000000000000000000000eeeeeeee1d111dddddd111d1e77ee77577eeee77000000005050900090000000
57ee77eeeee7ee75000000000000000000000000000000000000000000000000ee7eeeee1d111111dd1111d1e77eee77777ee777000000000505900090000000
777e77eeeeeee775000000000000000000000000000000000000000000000000eeeee7ee1ddd1111d111ddd1eeeeee7777777777000000000000400040000000
777eeeeeeeeee777000000000000000000000000000000000000000000000000eeeeeeee1111111111111111eeeee77757777775000000000000000000000000
777eeeeeeeeee7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77eeeeeeeeeee7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77eeee7ee77eee750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
577eeeeee77eee750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
577eeeeeeeeee7770000000000000000000000000000000000000000000000005555555500000000000000000000000000000000000000000000000000000000
77eeeeee77ee77770000000000000000000000000000000000000000000000005555555500000000000000000000000000000000000000000000000000000000
77ee7eee777777770000000000000000000000000000000000000000000000005555555500000000000000000000000000000000000000000000000000000000
777eeeee775577750000000000000000000000000000000000000000000000005555555500000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000500000000000000500000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000550000000000005500000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000555000000000055500000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000555500000000555500000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000555555555555555500000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000555555555555555500000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000555555555555555500000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000555555555555555500000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000004bbb00004b000000400bbb00000000000000000a0aa0a000bbbb00007777000000000000000000
000000000000000000000000000000000000000000000000004bbbbb004bb000004bbbbb00000000000000000aa88aa00bb77bb0077777700000000000000000
00000000000000000000000000000000000000000000000004200bbb042bbbbb042bbb00000000000000000002999920bb7777bb777777770000000000000000
000000000000000000000000000000000000000000000000040000000400bbb004000000000000000000000009a99990b6b77333777777770000000000000000
000000000000000000000000000000000000000000000000040000000400000004000000000000000000000009999a90b6b33333777777770000000000000000
0000000000000000000000000000000000000000000000004200000042000000420000000000000000000000099a9990bb333333777777760000000000000000
0000000000000000000000000000000000000000000000004000000040000000400000000000000000000000029999200b333330077777600000000000000000
00000000000000000000000000000000000000000000000040000000400000004000000000000000000000000029920000333300006666000000000000000000
00000000000000008242525252528452339200001323232352232323232352230000000000000000b302000013232352526200a2828342525223232323232323
00000000000000a20182920013232352363636462535353545550000005525355284525262b20000000000004252525262828282425284525252845252525252
00000000000085868242845252525252b1006100b1b1b1b103b1b1b1b1b103b100000000000000111102000000a282425233000000a213233300009200008392
000000000000110000a2000000a28213000000002636363646550000005525355252528462b2a300000000004252845262828382132323232323232352528452
000000000000a201821323525284525200000000000000007300000000007300000000000000b343536300410000011362b2000000000000000000000000a200
0000000000b302b2002100000000a282000000000000000000560000005526365252522333b28292001111024252525262019200829200000000a28213525252
0000000000000000a2828242525252840000000000000000b10000000000b1000000000000000000b3435363930000b162273737373737373737374711000061
000000110000b100b302b20000006182000000000000000000000000005600005252338282828201a31222225252525262820000a20011111100008283425252
0000000000000093a382824252525252000061000011000000000011000000001100000000000000000000020182001152222222222222222222222232b20000
0000b302b200000000b10000000000a200000000000000009300000000000000846282828283828282132323528452526292000000112434440000a282425284
00000000000000a2828382428452525200000000b302b2936100b302b20061007293a30000000000000000b1a282931252845252525252232323232362b20000
000000b10000001100000000000000000000000093000086820000a3000000005262828201a200a282829200132323236211111111243535450000b312525252
00000000000000008282821323232323820000a300b1a382930000b100000000738283931100000000000011a382821323232323528462829200a20173b20061
000000000000b302b2000061000000000000a385828286828282828293000000526283829200000000a20000000000005222222232263636460000b342525252
00000011111111a3828201b1b1b1b1b182938282930082820000000000000000b100a282721100000000b372828283b122222232132333610000869200000000
00100000000000b1000000000000000086938282828201920000a20182a37686526282829300000000000000000000005252845252328283920000b342845252
00008612222232828382829300000000828282828283829200000000000061001100a382737200000000b373a2829211525284628382a2000000a20000000000
00021111111111111111111111110061828282a28382820000000000828282825262829200000000000000000000000052525252526201a2000000b342525252
00000113235252225353536300000000828300a282828201939300001100000072828292b1039300000000b100a282125223526292000000000000a300000000
0043535353535353535353535363b2008282920082829200061600a3828382a28462000000000000000000000000000052845252526292000011111142525252
0000a28282132362b1b1b1b1000000009200000000a28282828293b372b2000073820100110382a3000000110082821362101333610000000000008293000000
0002828382828202828282828272b20083820000a282d3000717f38282920000526200000000000093000000000000005252525284620000b312223213528452
000000828392b30300000000002100000000000000000082828282b303b20000b1a282837203820193000072a38292b162710000000000009300008382000000
00b1a282820182b1a28283a28273b200828293000082122232122232820000a3233300000000000082920000000000002323232323330000b342525232135252
000000a28200b37300000000a37200000010000000111111118283b373b200a30000828273039200828300738283001162930000000000008200008282920000
0000009261a28200008261008282000001920000000213233342846282243434000000000000000082000085860000008382829200000000b342528452321323
0000100082000082000000a2820300002222321111125353630182829200008300009200b1030000a28200008282001262829200000000a38292008282000000
00858600008282a3828293008292610082001000001222222252525232253535000000f3100000a3820000a2010000008292000000009300b342525252522222
0400122232b200839321008683039300528452222262c000a28282820000a38210000000a3738000008293008292001362820000000000828300a38201000000
00a282828292a2828283828282000000343434344442528452525252622535350000001263000083829300008200c1008210d3e300a38200b342525252845252
1232425262b28682827282820103820052525252846200000082829200008282320000008382930000a28201820000b162839300000000828200828282930000
0000008382000000a28201820000000035353535454252525252528462253535000000032444008282820000829300002222223201828393b342525252525252
525252525262b2b1b1b1132323526200845223232323232352522323233382825252525252525252525284522333b2822323232323526282820000b342525252
52845252525252848452525262838242528452522333828292425223232352520000000000000000000000000000000000000000000000000000000000000000
525252845262b2000000b1b1b142620023338276000000824233b2a282018283525252845252232323235262b1b10083921000a382426283920000b342232323
2323232323232323232323526201821352522333b1b1018241133383828242840000000000000000000000000000000000000000000000000000000000000000
525252525262b20000000000a242627682828392000011a273b200a382729200525252525233b1b1b1b11333000000825353536382426282410000b30382a2a2
a1829200a2828382820182426200a2835262b1b10000831232b2000080014252000000000000a300000000000000000000000000000000000000000000000000
528452232333b20000001100824262928201a20000b3720092000000830300002323525262b200000000b3720000a382828283828242522232b200b373928000
000100110092a2829211a2133300a3825262b2000000a21333b20000868242520000000000000100009300000000000000000000000000000000000000000000
525262122232b200a37672b2a24262838292000000b30300000000a3820300002232132333b200000000b303829300a2838292019242845262b2000000000000
00a2b302b2a36182b302b200110000825262b200000000b1b10000a283a2425200000000a30082000083000000000000000000000094a4b4c4d4e4f400000000
525262428462b200a28303b2214262928300000000b3030000000000a203e3415252222232b200000000b30392000000829200000042525262b2000000000000
000000b100a2828200b100b302b211a25262b200000000000000000092b3428400000000827682000001009300000000000000000095a5b5c5d5e5f500000000
232333132362b221008203b2711333008293858693b3031111111111114222225252845262b200001100b303b2000000821111111142528462b2000000000000
000000000000110176851100b1b3026184621111111100000061000000b3135200000000828382670082768200000000000000000096a6b6c6d6e6f600000000
82000000a203117200a203b200010193828283824353235353535353535252845252525262b200b37200b303b2000000824353535323235262b2000011000000
0000000000b30282828372b26100b100525232122232b200000000000000b14200000000a28282123282839200000000000000000097a7b7c7d7e7f700000000
9200110000135362b2001353535353539200a2000001828282829200b34252522323232362b261b30300b3030000000092b1b1b1b1b1b34262b200b372b20000
001100000000b1a2828273b200000000232333132333b200001111000000b342000000868382125252328293a300000000000000000000000000000000000000
00b372b200a28303b2000000a28293b3000000000000a2828382827612525252b1b1b1b173b200b30393b30361000000000000000000b34262b271b303b20000
b302b211000000110092b100000000a3b1b1b1b1b1b10011111232110000b342000000a282125284525232828386000000000000000000000000000000000000
80b303b20000820311111111008283b311111111110000829200928242528452000000a3820000b30382b37300000000000000000000b3426211111103b20000
00b1b302b200b372b200000000000082b21000000000b31222522363b200b3138585868292425252525262018282860000000000000000000000000000000000
00b373b20000a21353535363008292b32222222232111102b20000a21323525200000001839200b3038282820000000011111111930011425222222233b20000
100000b10000b303b200000000858682b27100000000b3425233b1b1000000b182018283001323525284629200a2820000000000000000000000000000000000
9300b100000000b1b1b1b1b100a200b323232323235363b100000000b1b1135200000000820000b30382839200000000222222328283432323232333b2000000
329300000000b373b200000000a20182111111110000b31333b100a30061000000a28293f3123242522333020000820000000000000000000000000000000000
829200001000410000000000000000b39310d30000a28200000000000000824200000086827600b30300a282760000005252526200828200a30182a2006100a3
62820000000000b100000093a382838222222232b20000b1b1000083000000860000122222526213331222328293827600000000000000000000000000000000
017685a31222321111111111002100b322223293000182930000000080a301131000a383829200b373000083920000005284526200a282828283920000000082
62839321000000000000a3828282820152845262b261000093000082a300a3821000135252845222225252523201838200000000000000000000000000000000
828382824252522222222232007100b352526282a38283820000000000838282320001828200000083000082010000005252526271718283820000000000a382
628201729300000000a282828382828252528462b20000a38300a382018283821222324252525252525284525222223200000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000f000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000f00000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000
00000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000070000000000000000006000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000f00000000000060600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000d000600000000000000660000000000000000000000000000000f0000000000000
0000000000000000000000000000000000000000000000000000000000000d00000c00f000000000066000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000d000000c000000000000000000000000000000000000000000000000060000000000
00000000000000000000000000000000000000000000000000000000000c0000000c000600000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d000000000c060d0000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c00000000000d000d000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000006666600666666006600c00066666600066666006666660066666600000000000000000000000000000000000000
0000000000000000000000000000000000006666666066666660660c000066666660666666606666666066666660000000000000000000000000000000000000
00000000000000000000000000000000000066000660660000006600000066000000660000000066000066000000000000000000000000000000000000000000
000000000000000000000000000000000000dd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000000000000000000000000000000000000000
000000000000000000000000000000000000dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000000000000000000000000000000000000000
000000000000000000000000000000000000ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00000000000000000000000000000000000000
0000000000000000000000000000000000000ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd000000f000000000000000f00000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000c000000000000000000000000000000c00000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c00000000000000000000000000000000c0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000cc0000000000000000000000000000000000c000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c000000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000f0f0f0f0f0f0f0f0c0f00000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000100000000000000000000000000000000000000c00c000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0000000000000000000000000000000000000001010c0f000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000001000c00000000000000000000000000000000f0f0f0f0
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000010000000600000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000000000010000000000000f000f000f000f000f000f00000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000f0000000f00000000000f00000000000f0f0f000f00000000000f0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000f0f00000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000f000f0000000f000f000f000f000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000f000f000f000f0000000f000f0000000000000000000000000
00f000f000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050006000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000500555050000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050000000000000600000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000f00000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000
000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000f0000000000000000000000000f0000000000000000000000000000000000000000000f00000000000000000000
0000000000f000000000f000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000
0000000000000000f000f000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000f000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000700000000006600f0000000000000000000000000000f0000000000000000000f000f00
000000000000f000000000000000000f000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000f00000000000000000000000f00000f0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000f000f00000000000000000000000000000000
f0000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000055505550555055500000555050500550555005500550550000000000000000000000000000000000000000
0000000000000000000000000f000000000000000055505050f500050000000500505050505050500050505050000000000000f0000000000000000000000000
00000000000000000000000000000000000000000050505550050005000000050055505050550055505050505000000000000000000000000000000000000000
000000000f00000000000000000000000000f0000050505050050005000000050050505050505000505050505000000000000000000000000000000000000000
000000000000000000000000000000000000000000505050500500050000000500505055005050550055005050000000f0000000000000000000000000000000
f000000000000000000000000000000000000000f00000000000000000000f0000000000000000000000000000000000000000000000000000000f0000000000
0000000000000000000000000000000000000000000060550f0550555050f0000055505550555055505050000000000000000000000000000000000000000000
000f000f000000000000000000000000000000000000005050505f50005000000050505000505050505050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505055005000000055005500550055005550000000000000000000000000000000000000000000
000f0000000000000000000000000000000000000000005050505050005000000050505000505050500050000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000050505500555055500000555055505050505055500000000f0000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000f00000000000000000000000f0000000000000000000000000000000000000f0000000000000
000000000000000000000000000000f000000000f0000000000000f0f0f0f000f0f0f0f0f000000000000000000000000000000000000000000000000000000f
000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000f00000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000
00000000000600000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000600000000000000000000000000000000000000000
0000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000f0000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000f00000000f000000000000000000000
0000000000000000000f00000f0000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000f00000
0000000000f0000f0000000000000000000000000000000000000f00000000000f000000f0000000000000000000000000000000000000000000000000000000
0000000000000000000000000000f0000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000f000000000000000f0000000000000f0000000000000000000000000000000000000000000
000000000000000000000000000000f00000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000f00000000000000f00000000000000000000000000000000000000000000000f0f00000000000
0000000000000000000000000000000000000000f000f00f0f00f000000000000000000000000000000000000000000000000000000000000000000000000000
00000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200001313131300000300000000020000000013131313000004020202020202020000131313130004040202020202020200001313131300000002020000000202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2331252548252532323232323300002425262425252631323232252628282824252525252525323328382828312525253232323233000000313232323232323232330000002432323233313232322525252525482525252525252526282824252548252525262828282824254825252526282828283132323225482525252525
252331323232332900002829000000242526313232332828002824262a102824254825252526002a2828292810244825282828290000000028282900000000002810000000372829000000002a2831482525252525482525323232332828242525254825323338282a283132252548252628382828282a2a2831323232322525
252523201028380000002a0000003d24252523201028292900282426003a382425252548253300002900002a0031252528382900003a676838280000000000003828393e003a2800000000000028002425253232323232332122222328282425252532332828282900002a283132252526282828282900002a28282838282448
3232332828282900000000413f2020244825262828290000002a243300002a2425322525260000000000000000003125290000000021222328280000000000002a2828343536290000000000002839242526212223202123313232332828242548262b000000000000001c00003b242526282828000000000028282828282425
231a413828294c2839410000343522252548262900000000000030000000002433003125333d3f00000000000000003100001c3a3a31252620283900000000000010282828290000000011113a2828313233242526103133202828282838242525262b000000000000000000003b2425262a2828670016002a28283828282425
263a512828102829000000000000312525323300000000110000370000003e2400000037212223000000000000000000395868282828242628290000000000002a2828290000000000002123283828292828313233282829002a002a2828242525332b0c00000011110000000c3b314826112810000000006828282828282425
2522353536287b0000510000003a282426003d003a3900270000000000002125001a000024252611111111000000002c28382828283831332800000017170000002a000000001111000024261028290028281b1b1b282800000000002a2125482628390000003b34362b000000002824252328283a67003a28282829002a3132
25333828282900000000005100493824252320201029003039000000005824480000003a31323235353536675800003c282828281028212329000000000000000000000000003436003a2426282800003828390000002a29000000000031323226101000000000282839000000002a2425332828283800282828390000001700
2600002a28000000163a283a28284f2425252223283900372858390068283132000000282828282820202828283921222829002a28282426000000000000000000000000000020382828312523000000282828290000000000163a67682828003338280b00000010382800000b00003133282828282868282828280000001700
3300004a2867580000281028283422252525482628286720282828382828212200003a283828102900002a28382824252a0000002838242600000017170000000000000000002728282a283133390000282900000000000000002a28282829002a2839000000002a282900000000000028282838282828282828290000000000
0000003a2828383e3a2828283828242548252526002a282729002a28283432250000002a282828000000002810282425000000002a282426000000000000000000000000000037280000002a28283900280000003928390000000000282800000028290000002a2828000000000000002a282828281028282828675800000000
000000287c282821234e00002a28242532322526003a2830000000002a28282400000000002a281111111128282824480000003a28283133000000000000171700013f0000002029000000003828000028013a28281028580000003a28290000002a280c0000003a380c00000000000c00002a2828282828292828290000003a
17013a2123282a313329001111112425002831263a3829300000000000002a310000000000002834222236292a0024253e013a3828292a00000000000000000035353536000020000000003d2a28671422222328282828283900582838283d00003a290000000028280000000000000000002a28282a29000058100012002a28
22222225262900212311112122222525002a3837282900301111110000003a2800013f0000002a282426290000002425222222232900000000000000171700002a282039003a2000003a003435353535252525222222232828282810282821220b10000000000b28100000000b0000002c00002838000000002a283917000028
2548252526111124252222252525482500012a2828673f242222230000003828222223000012002a24260000001224252525252600000000171700000000000000382028392827080028676820282828254825252525262a28282122222225253a28013d0000006828390000000000003c0168282800171717003a2800003a28
25252525252222252525252525252525222222222222222525482667586828282548260000270000242600000021252525254826171700000000000000000000002a2028102830003a282828202828282525252548252600002a2425252548252821222300000028282800000000000022222223286700000000282839002838
2532330000002432323232323232252525252628282828242532323232254825253232323232323225262828282448252525253300000000000000000000005225253232323233313232323233282900262829286700000000002828313232322525253233282800312525482525254825254826283828313232323232322548
26282800000030402a282828282824252548262838282831333828290031322526280000163a28283133282838242525482526000000000000000000000000522526000016000000002a10282838390026281a3820393d000000002a3828282825252628282829003b2425323232323232323233282828282828102828203125
3328390000003700002a3828002a2425252526282828282028292a0000002a313328111111282828000028002a312525252526000000000000000000000000522526000000001111000000292a28290026283a2820102011111121222328281025252628382800003b24262b002a2a38282828282829002a2800282838282831
28281029000000000000282839002448252526282900282067000000000000003810212223283829003a1029002a242532323367000000000000000000004200252639000000212300000000002122222522222321222321222324482628282832323328282800003b31332b00000028102829000000000029002a2828282900
2828280016000000162a2828280024252525262700002a2029000000000000002834252533292a0000002a00111124252223282800002c46472c00000042535325262800003a242600001600002425252525482631323331323324252620283822222328292867000028290000000000283800111100001200000028292a1600
283828000000000000003a28290024254825263700000029000000000000003a293b2426283900000000003b212225252526382867003c56573c4243435363633233283900282426111111111124252525482526201b1b1b1b1b24252628282825252600002a28143a2900000000000028293b21230000170000112867000000
2828286758000000586828380000313232323320000000000000000000272828003b2426290000000000003b312548252533282828392122222352535364000029002a28382831323535353522254825252525252300000000003132332810284825261111113435361111111100000000003b3133111111111127282900003b
2828282810290000002a28286700002835353536111100000000000011302838003b3133000000000000002a28313225262a282810282425252662636400000000160028282829000000000031322525252525252667580000002000002a28282525323535352222222222353639000000003b34353535353536303800000017
282900002a0000000000382a29003a282828283436200000000000002030282800002a29000011110000000028282831260029002a282448252523000000000039003a282900000000000000002831322525482526382900000017000058682832331028293b2448252526282828000000003b201b1b1b1b1b1b302800000017
283a0000000000000000280000002828283810292a000000000000002a3710281111111111112136000000002a28380b2600000000212525252526001c0000002828281000000000001100002a382829252525252628000000001700002a212228282908003b242525482628282912000000001b00000000000030290000003b
3829000000000000003a102900002838282828000000000000000000002a2828223535353535330000000000002828393300000000313225252533000000000028382829000000003b202b00682828003232323233290000000000000000312528280000003b3132322526382800170000000000000000110000370000000000
290000000000000000002a000000282928292a0000000000000000000000282a332838282829000000000000001028280000000042434424252628390000000028002a0000110000001b002a2010292c1b1b1b1b0000000000000000000010312829160000001b1b1b313328106700000000001100003a2700001b0000000000
00000100000011111100000000002a3a2a0000000000000000000000002a2800282829002a000000000000000028282800000000525354244826282800000000290000003b202b39000000002900003c000000000000000000000000000028282800000000000000001b1b2a2829000001000027390038300000000000000000
1111201111112122230000001212002a00010000000000000000000000002900290000000000000000002a6768282900003f01005253542425262810673a3900013f0000002a3829001100000000002101000000000000003a67000000002a382867586800000100000000682800000021230037282928300000000000000000
22222222222324482611111120201111002739000017170000001717000000000001000000001717000000282838393a0021222352535424253328282838290022232b00000828393b27000000001424230000001200000028290000000000282828102867001717171717282839000031333927101228370000000000000000
254825252526242526212222222222223a303800000000000000000000000000001717000000000000003a28282828280024252652535424262828282828283925262b00003a28103b30000000212225260000002700003a28000000000000282838282828390000005868283828000022233830281728270000000000000000
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
00100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
011000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
002000002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0108002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
0018002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 150a5644
00 0a160c44
00 0a160c44
00 0a0b0c44
00 14131244
00 0a160c44
00 0a160c44
02 0a111244
00 41424344
00 41424344
01 18191a44
00 18191a44
00 1c1b1a44
00 1d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a272944
00 2a272944
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 34312744
02 35322744
00 41424344
01 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44

