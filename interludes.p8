pico-8 cartridge // http://www.pico-8.com

version 42
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


objects,got_fruit, --tables
freeze,delay_restart,sfx_timer,ui_timer, --timers
cam_x,cam_y,cam_spdx,cam_spdy,cam_gain,cam_offx,cam_offy, --camera values <camtrigger>
_pal, --for outlining
shake,screenshake
=
{},{},
0,0,0,-99,
0,0,0,0,0.1,0,0,
pal,
0,false


local _g=_ENV --for writing to global vars

-- [entry point]

function _init()
  max_djump,deaths,frames,seconds,minutes,time_ticking,berry_count=0,0,0,0,0,true,0
  music(0,0,7)
  load_level(1)
end


-- [effects]

clouds={}
for i=0,16 do
  add(clouds,{
    x=rnd"128",
    y=rnd"128",
    spd=1+rnd"4",
    w=32+rnd"32"
  })
end

particles={}
for i=0,24 do
  add(particles,{
    x=rnd"128",
    y=rnd"128",
    s=flr(rnd"1.25"),
    spd=0.25+rnd"5",
    off=rnd(),
    c=6+rnd"2",
  })
end

dead_particles={}

-- [player entity]

player={
  init=function(_ENV)
    djump, hitbox, collides,layer = max_djump, rectangle(1,3,6,5), true,2

    --<fruitrain>--
    -- ^ refers to setting berry_timer and berry_count to 0
    foreach(split"grace,jbuffer,dash_time,dash_effect_time,dash_target_x,dash_target_y,dash_accel_x,dash_accel_y,spr_off,berry_timer,berry_count", function(var)
      _ENV[var]=0
    end)
    create_hair(_ENV)
  end,
  update=function(_ENV)
    if pause_player then
      return
    end

    -- horizontal input
    local h_input=split"0,-1,1,1"[btn()%4+1]

    -- spike collision / bottom death
    if is_flag(0,0,-1) or
	    y>lvl_ph and not exit_bottom then
	    kill_player(_ENV)
    end

    -- on ground checks
    local on_ground=is_solid(0,1)

        -- <fruitrain> --
    if is_solid(0,1,true) then
      berry_timer+=1
    else
      berry_timer, berry_count=0, 0
    end

    for i,f in inext,fruitrain do
      if f.type==fruit and not f.golden and berry_timer>5 then
        -- to be implemented:
        -- save berry
        -- save golden
        berry_count+=1
        _g.berry_count+=1
        berry_timer, got_fruit[f.fruit_id]=-5, true
        init_object(lifeup, f.x, f.y,berry_count)
        del(fruitrain, f)
        destroy_object(f);
        (fruitrain[i] or {}).target=f.target
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
      jbuffer=5
    end
    jbuffer=max(jbuffer-1)

    -- grace frames and dash restoration
    if on_ground then
      grace=7
      if djump<max_djump then
        psfx"22"
        djump=max_djump
      end
    end
    grace=max(grace-1)

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
      local accel=on_ground and 0.6 or 0.4

      -- set x speed
      spd.x=abs(spd.x)<=1 and
        appr(spd.x,h_input,accel) or
        appr(spd.x,sign(spd.x),0.15)

      -- facing direction
      if spd.x~=0 then
        flip.x=spd.x<0
      end

      -- y movement
      local maxfall=2

      -- wall slide
      if is_solid(h_input,0) then
        maxfall=0.4
        -- wall slide smoke
        if rnd()<0.2 then
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
          psfx"18"
          jbuffer,grace,spd.y=0,0,-2
          init_smoke(0,4)
        else
          -- wall jump
          local wall_dir=is_solid(-3,0) and -1 or is_solid(3,0) and 1
          if wall_dir then
            psfx"19"
            jbuffer,spd=0,vector(wall_dir*-2,-2)
            -- wall jump smoke
            init_smoke(wall_dir*6)
          end
        end
      end

      -- dash
      if dash then
        if djump>0 then
          init_smoke()
          djump-=1
          dash_time,_g.has_dashed,dash_effect_time=4, true, 10
          -- vertical input
          local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
          -- calculate dash speeds
          local dspd=h_input&v_input==0 and 5 or 3.5355339059
          spd=vector(h_input~=0 and h_input*dspd or
          v_input~=0 and 0 or flip.x and -1 or 1,
          v_input*dspd)
          -- effects
          psfx"20"
          _g.freeze,_g.shake=2,5
          -- dash target speeds and accels
          dash_target_x,dash_target_y,dash_accel_x,dash_accel_y=
          2*sign(spd.x), split"-1.5,0,2"[v_input+2],
          v_input==0 and 1.5 or 1.06066017177 , spd.x==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()


          -- emulate soft dashes
          if ph_input==-h_input and oob(ph_input,0) then
            spd.x=0
          end

        else
          -- failed dash smoke
          psfx"21"
          init_smoke()
        end
      end
    end

    -- animation
    spr_off+=0.25
    sprite = on_ground and (
      btn(⬇️) and 6 or -- crouch
      btn(⬆️) and 7 or -- look up
      spd.x*h_input~=0 and 1+spr_off%4 or 1) -- walk or stand
      or is_solid(h_input,0) and 5 or 3 -- wall slide or mid air

    update_hair(_ENV)

    -- exit level (except summit)
    if (exit_right and left()>=lvl_pw or
        exit_top and y<-4 or
        exit_left and right()<0 or
        exit_bottom and top()>=lvl_ph) and levels[lvl_id+1] then
      next_level()
    end

    -- was on the ground, previous horizontal input (for soft dashes)
    was_on_ground,ph_input=on_ground, h_input
  end,

  draw=function(_ENV)
    -- draw player hair and sprite
    pal(8,((djump==1 or lvl_id==1) and 8) or (djump==2 and 14) or 12)
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
  init=function(_ENV)
    delta,dir=0,sprite==9 and 0 or is_solid(-1,0) and 1 or -1
  end,
  update=function(_ENV)
    delta*=0.75
    --can save tokens by setting hit as _ENV
    --but i'm not desperate enough yet
    local hit=player_here()
    if hit then
      if dir==0 then
        hit.move(0,y-hit.y-4,1)
        hit.spd.x*=0.2
        hit.spd.y=-3
      else
        hit.move(x+dir*4-hit.x,0,1)
        hit.spd=vector(dir*3,-1.5)
      end
      hit.dash_time,hit.dash_effect_time,delta,hit.djump=0,0,4,max_djump
    end
  end,
  draw=function(_ENV)
    local delta=flr(delta)
    if dir==0 then
      sspr(72,0,8,8-delta,x,y+delta)
    else
      spr(8,dir==-1 and x+delta or x,y,1-delta/8,1,dir==1)
    end
  end
}

refill={
  init=function(_ENV)
    offset,timer,hitbox=rnd(),0,rectangle(-1,-1,10,10)
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

fall_plat={
  init=function(_ENV)
    while right()<lvl_pw-1 and tile_at(right()/8+1,y/8)==67 do
      hitbox.w+=8
    end
    while bottom()<lvl_ph-1 and tile_at(x/8,bottom()/8+1)==67 do
      hitbox.h+=8
    end
    collides=true
    solid_obj=true
    timer=0
  end,
  update=function(_ENV)
    if not state then
      hitbox.w+=40
      hitbox.h+=32
      if player_here() then
        state = 0  -- shake
        timer = 12
      end
      hitbox.w-=40
      hitbox.h-=32
    elseif timer>0 then
      timer-=1
      if timer==0 then
        state=finished and 2 or 1
        spd.y=0.4
      end
    elseif state==1 then
      if spd.y==0 then
        state=0
        for i=0,hitbox.w-1,8 do
          init_smoke(i,hitbox.h-2)
        end
        timer=6
        finished=true
      end
      spd.y=appr(spd.y,4,0.4)
    end
  end,
  draw=function(_ENV)
    local _x,_y=x,y
    if state==0 then
      _x+=rnd(2)-1
      _y+=rnd(2)-1
    end
    local r,d=_x+hitbox.w-8,_y+hitbox.h-8
    for i=_x,r,r-_x do
      for j=_y,d,d-_y do
        spr(80,i,j,1.0,1.0,i~=_x,j~=_y)
      end
    end
    for i=_x+8,r-8,8 do
      spr(81,i,_y)
      spr(81,i,d,1,1,false,true)
    end
    for i=_y+8,d-8,8 do
      spr(83,_x,i)
      spr(83,r,i,1,1,true)
    end
    for i=_x+8,r-8,8 do
      for j=_y+8,d-8,8 do
        spr((i+j-_x-_y)%16==0 and 84 or 85,i,j)
      end
    end
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

fly_fruit={
  check_fruit=true,
  init=function(_ENV)
    start,step,sfx_delay=y,0.5,8
  end,
  update=function(_ENV)
    --fly away
    if has_dashed then
      sfx_delay-=1
      if sfx_delay==0 then
       _g.sfx_timer=20
       sfx"10"
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


psfx=function(num)
  if sfx_timer<=0 then
   sfx(num)
  end
end

-- [tile dict]
tiles={}
foreach(split([[
1,player_spawn
8,spring
9,spring
10,fruit
11,fruit
12,fly_fruit
15,refill
23,fall_floor
66,fall_plat
]],"\n"),function(t)
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

function destroy_object(obj)
  del(objects,obj)
end

function kill_player(obj)
  sfx_timer,shake=12,9
  sfx"17"
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
  foreach(fruitrain,function(f)
    full_restart = full_restart or f.golden
  end)
  fruitrain={}
  --- </fruitrain> ---
  delay_restart=15
  -- <transition>
  tstate=0
  -- </transition>
end

-- [room functions]


function next_level()
  load_level((lvl_id==3 and 2) or lvl_id+1)
end

function load_level(id)
  --remove existing objects
  foreach(objects,destroy_object)

  --reset camera speed, drawing timer setup
  ui_timer,cam_spdx,cam_spdy,has_dashed=5,0,0--,false

  local diff_level=lvl_id~=id

  --set level index
  lvl_id=id

  --set level globals
  local tbl=split(levels[lvl_id])
  for i=1,4 do
    _ENV[split"lvl_x,lvl_y,lvl_w,lvl_h"[i]]=tbl[i]*16
  end

  lvl_pw,lvl_ph=lvl_w*8,lvl_h*8

  local exits=tonum(tbl[5]) or 0b0001

  -- exit_top,exit_right,exit_bottom,exit_left=exits&1!=0,exits&2!=0,exits&4!=0, exits&8!=0
  for i,v in inext,split"exit_top,exit_right,exit_bottom,exit_left" do
    _ENV[v]=exits&(0.5<<i)~=0
  end


  --reload map
  if diff_level then
    reload()
  end
    --chcek for mapdata strings
  if mapdata[lvl_id] then
    --hex loaded levels go at (0,0), despite what the levels table says (to make everhorn nicer)
    lvl_x,lvl_y=0,0
    if diff_level then
      --replace mapdata with base256
      --encoding is offset by 1, to avoid shenanigans with null chars
      for i=0,#mapdata[lvl_id]-1 do
        mset(i%lvl_w,i\lvl_w,ord(mapdata[lvl_id][i+1])-1)
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

  foreach(objects,function(_ENV)
    (type.end_init or time)(_ENV)
  end)

  --<camtrigger>--
  --generate camera triggers
  cam_offx,cam_offy=0,0
  for s in all(camera_offsets[lvl_id]) do
    local tx,ty,tw,th,offx_,offy_=unpack(split(s))
    local _ENV=init_object(camera_trigger,tx*8,ty*8)
    hitbox.w,hitbox.h,offx,offy=tw*8,th*8,offx_,offy_
  end
  --</camtrigger>--

  -- dash inventory changes
  max_djump = (id == 1 and 0) or (id <=4 and 2) or 1
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

  sfx_timer=max(sfx_timer-1)

  -- cancel if freeze
  if freeze>0 then
    freeze-=1
    return
  end

  -- screenshake toggle
  if btnp(⬆️,1) then
    screenshake=not screenshake
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
  draw_x,draw_y=round(cam_x)-64,round(cam_y)-64

  if shake>0 then
    shake-=1
    if screenshake then
      draw_x+=-2+rnd"5"
      draw_y+=-2+rnd"5"
    end
  end
  camera(draw_x,draw_y)

  -- draw bg color
  cls()

  -- bg clouds effect
  foreach(clouds,function(_ENV)
    x+=spd-_g.cam_spdx
    _g.rectfill(x+_g.draw_x,y+_g.draw_y,x+w+_g.draw_x,y+16-w*0.1875+_g.draw_y,1)
    if x>128 then
      x,y=-w,_g.rnd"120"
    end
  end)

	-- draw bg terrain
  palt(0, false)
  palt(8, true)
  map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)
  palt()

  -- draw outlines
  if lvl_id<=4 then
    pal(split"1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1")
    pal=time
    foreach(objects,function(_ENV)
      if outline then
        for i=1,4 do
          camera(draw_x+split"-1,0,0,1"[i],draw_y+split"0,-1,1,0"[i]) draw_object(_ENV)
        end
      end
    end)
    pal=_pal
    camera(draw_x,draw_y)
    pal()
  end

  --set draw layering
  --0: background layer
  --1: default layer
  --2: player layer
  --3: foreground layer
  local layers={{},{},{}}
  foreach(objects,function(_ENV)
    if layer==0 then
      draw_object(_ENV) --draw below terrain
    else
      add(layers[layer or 1],_ENV) --add object to layer, default draw below player
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
      x,y=-4,_g.rnd"128"
    elseif x<-4 then
      x,y=128,_g.rnd"128"
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
  color"0"
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
  return sub("0"..x,-2)
end

-- [helper functions]

function round(x)
  return flr(x+0.5)
end

function appr(val,target,amount)
  return mid(val-amount,val+amount,target)
end

function sign(v)
  return v~=0 and sgn(v) or 0
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

--@conf
--[[
param_names={}
composite_shapes={}
autotiles={{45, 31, 46, 33, 33, 35, 34, 49, 49, 51, 50, 32, 32, 48, 41, [0] = 46}, {36, 38, 37, 36, 36, 38, 37, 52, 52, 54, 53, 39, 39, 55, 41, [0] = 30}, {140, 142, 141, 143, 156, 159, 157, 175, 189, 191, 190, 159, 173, 175, 174, [0] = 191, [42] = 211}, {197, 199, 198, 216, 213, 215, 214, 248, 245, 247, 246, 232, 229, 231, 230, [0] = 200}}
]]
--@begin
--level table
--"x,y,w,h,exit_dirs"
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
levels={
  "0,-3,8,1,0b0000",
  "0,-2,3,1,0b0010",
  "3,-2,1,1,0b1000",
  "0,-1,1,1,0b0000",
  "0,0,1,1,0b0001",
  "1,0,1,1,0b0001",
  "2,0,1,1,0b0001",
  "3,0,1,1,0b0001",
  "4,0,1,1,0b0001",
  "5,0,1,1,0b0001",
  "6,0,1,1,0b0001",
  "7,0,1,1,0b0001",
  "0,1,1,1,0b0001",
  "1,1,1,1,0b0001",
  "2,1,1,1,0b0001",
  "3,1,1,1,0b0001",
  "4,1,1,1,0b0001",
  "5,1,1,1,0b0001",
  "6,1,1,1,0b0001",
  "7,1,1,1,0b0001",
  "0,4,1,1,0b0001",
  "1,4,1,1,0b0001",
  "2,4,1,1,0b0001",
  "3,4,1,1,0b0001",
  "4,4,1,1,0b0001",
  "5,4,1,1,0b0001",
  "6,4,1,1,0b0001",
  "7,4,1,1,0b0001",
  "0,5,1,1,0b0001",
  "1,5,1,1,0b0001",
  "2,5,1,1,0b0001",
  "3,5,1,1,0b0001",
  "4,5,1,1,0b0001",
  "5,5,1,1,0b0001",
  "6,5,1,1,0b0001",
  "7,5,1,1,0b0001"
}

--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {},
  {}
}
--</camtrigger>--

--mapdata string table
--assigned levels will load from here instead of the map
mapdata={
  "¹¹¹¹¹¹¹¹¹¹¹¹¹(+******+8¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹░¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹I¹¹¹¹¹¹¹¹¹¹¹¹¹¹(<6+*****7¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹\"#$¹¹¹¹¹¹¹¹¹¹¹¹¹¹★⧗⬆️ˇ¹¹¹¹¹¹¹¹H¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹Y¹¹¹¹¹¹¹¹¹¹¹¹¹¹57n!)**;8¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹!)8¹¹¹¹¹¹¹¹H¹¹¹¹¹けこさし¹¹¹¹¹¹¹¹X¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹W¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹}n2:9*)8¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹!<7¹¹¹¹¹¹¹¹X¹¹E¹ねのはひ➡️-¹¹¹¹¹¹¹W¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹g%¹¹¹¹¹¹¹¹¹¹`,¹¹¹}~23334¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹▶\"$¹¹H¹¹¹¹¹!8¹¹¹¹¹¹¹¹¹W¹¹\"######&'_¹¹¹¹¹g¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹w(¹¹¹¹¹¹¹¹¹%&'_¹¹¹¹CDDDD¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹!1░¹X¹¹¹¹¹!8¹¹¹¹¹¹¹¹¹g¹]!9)9)+;<8n^_¹E-y¹E¹¹¹¹E¹¹¹¹¹¹¹E¹¹¹¹¹¹¹¹¹¹¹¹¹E]%+¹¹¹¹¹¹¹¹]567o¹¹¹¹D¹¹¹¹¹¹¹¹¹¹¹I¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹E¹¹¹¹¹¹¹¹¹¹!)$¹h¹¹¹¹¹!8¹¹¹¹¹¹-¹,w]\"9*******+&&###### bcdaaadbcd¹¹adbc¹¹¹¹¹¹¹¹%%##;*¹¹¹¹H¹]^n~○¹m^_¹¹D¹¹¹¹¹¹¹¹¹¹¹Y¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹\"#$¹¹¹¹¹¹◀▶!91¹x¹¹¹¹¹24¹¹¹¹¹¹%&&##)*********;+)))):1¹rst¹¹¹trst¹¹¹trs¹¹¹¹¹¹¹¹5<::**¹¹¹¹X¹mn○¹¹¹}no¹¹¹¹¹¹¹¹¹¹¹¹¹¹W¹¹¹¹¹I¹¹¹¹¹¹¹¹¹!:1¹¹¹¹¹¹¹¹2:1░y¹¹¹¹¹¹¹¹¹¹¹¹¹(<+)9****************94¹ef¹¹¹¹¹ef¹¹¹¹¹ef¹¹¹¹¹¹¹¹¹56***¹¹¹¹h]n○¹¹¹¹¹mn_¹¹¹¹¹¹¹¹¹¹¹¹¹g¹¹¹¹¹Y¹¹¹¹¹¹¹◀▶!)4¹¹¹¹E¹¹¹¹!)##$¹¹¹¹¹¹¹¹¹¹◀▶(;******************)1o¹ji¹¹¹¹¹zi¹¹¹¹¹ji¹¹¹¹¹¹¹¹¹¹m5+*JKL¹xmoE¹¹¹¹,mn○¹¹¹¹¹¹¹¹¹¹¹¹,w¹¹¹¹¹W¹¹¹¹¹¹¹¹¹!1¹¹¹\"##$¹]^!99:1¹¹¹¹¹¹\"# ^_,(+******************<7o¹ji¹¹¹¹¹ji¹¹¹¹¹ji¹¹¹¹¹¹¹¹¹¹}n(;Z[\\²y%#$¹¹¹¹%'○¹¹¹,-¹,¹¹¹¹¹¹%'¹¹¹¹¹g¹¹¹¹¹¹¹,¹!1_¹¹29:1¹mn!9*)1_¹¹¹¹E!1nnn%+*******************8no¹zi¹¹¹¹¹zi¹¹¹¹¹zi¹¹¹¹¹¹¹¹¹¹¹m5;&&&&##)4¹¹¹¹(8,¹¹゜&&&'¹¹¹¹-¹(8_¹,-,w¹E¹¹¹¹゜&#91n^_¹!)4¹mn!:*91n^_¹\"#:8nnn5++******************8n○¹ji¹¹¹¹¹ji¹¹_¹¹ji¹¹¹¹¹¹¹¹¹¹¹}n(+;<+):1¹¹¹-¹(;'¹¹¹(<+7_¹¹▶%#;8o¹゜&&### ¹¹]n(9)4nnn^(1¹¹}n5+**1nn.#:998}nn5+;******************8o¹¹zi¹¹¹¹¹zi¹]o¹¹zi¹¹¹¹¹¹¹¹¹¹¹¹}(*****91¹¹¹%&+<8¹¹](+8nn_¹¹5+;7n^n(+;)1¹¹]nn(;8nn~n~(8¹¹¹}~(;91~nn!)*+7¹}nn(+******************8○¹¹ji¹¹]¹¹ji¹mn_¹ji¹¹¹¹¹¹¹¹¹¹¹¹¹(*****)1¹¹¹(;*+8¹]n(;8nno¹¹¹(8nnnn(;*91¹¹mnn(+8no¹}○(8¹¹¹¹¹(+)1¹mn(+<8¹¹¹mn(<******************8¹¹¹zi¹]o¹¹zi]nno¹zi¹¹¹¹¹¹¹¹¹¹¹¹¹(",
  "¹¹¹¹¹░¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹I¹¹¹¹★⧗⬆️ˇ¹¹¹¹¹¹¹¹H¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹Y¹¹¹¹けこさし¹¹¹¹¹¹¹¹X¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹W¹E¹ねのはひふ-¹¹¹¹¹¹¹W¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹g%\"######&'_¹¹¹¹¹g¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹w(!9)9)+;<8n^_¹E-y¹E¹¹¹¹E¹¹¹¹¹¹¹E¹¹¹¹¹¹¹¹¹¹¹¹²E]%+9*******+&&###### b☉웃⌂⬅️😐dbcdFG✽●♥cFuuuvuuG%%##;**********;+)))):1¹r▤▥¹¹¹trst¹¹¹∧❎s¹¹¹¹h¹¹¹5<::*****************94¹ef¹¹¹¹¹ef¹¹¹¹¹ef¹¹¹¹x¹¹¹¹56*****************)1o¹ji¹¹¹¹¹zi¹¹¹¹¹ji¹¹¹¹h¹¹¹¹¹m5+***************<7o¹ji¹¹¹¹¹ji¹¹¹¹¹ji¹¹¹¹x¹¹¹¹¹}n(;**************8no¹zi¹¹¹¹¹zi¹¹¹¹¹zi¹¹¹¹h¹¹¹¹¹¹m5;**************8n○¹ji¹¹¹¹¹ji¹¹_¹¹ji¹¹¹¹x¹¹¹¹¹¹}n(**************8o¹¹zi¹¹¹¹¹zi¹]o¹¹zi¹¹¹¹h¹¹¹¹¹¹¹}(**************8○¹¹ji¹¹]¹¹ji¹mn_¹ji¹¹¹¹x¹¹¹¹¹¹¹¹(**************8¹¹¹zi¹]o¹¹zi]nno¹zi¹¹¹¹h¹¹¹¹¹¹¹¹(",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹²¹¹¹¹¹¹¹¹¹¹¹¹%&&'¹¹¹¹¹¹¹¹¹¹¹¹5;+<#$¹¹¹¹¹¹¹¹¹%<***:)$¹¹¹¹¹¹\"#:+****91¹¹¹¹¹¹2:9****9)4¹¹¹¹¹¹¹2)9**)34¹¹¹¹¹¹¹¹¹23)91¹¹¹¹¹¹¹¹¹¹¹¹¹!91¹¹¹¹¹¹¹¹¹¹¹¹¹!*)$¹¹¹¹¹🐱⬇️¹¹¹¹¹!**9#$¹\"###$¹¹\"#:***)9#:9)9:##:99",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  nil,
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹",
  "¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹¹"
}
--@end


function move_camera(obj)
  --<camtrigger>--
  cam_spdx,cam_spdy=cam_gain*(4+obj.x-cam_x+cam_offx),cam_gain*(4+obj.y-cam_y+cam_offy)
  --</camtrigger>--

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  --clamp camera to level boundaries
  local clampx,clampy=mid(cam_x,64,lvl_pw-64),mid(cam_y,64,lvl_ph-64)
  if cam_x~=clampx then
    cam_spdx,cam_x=0,clampx
  end
  if cam_y~=clampy then
    cam_spdy,cam_y=0,clampy
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
  for i=0,w*h-1 do
    reserve..=num2base256(mget(i%w,i\w)+1)
  end
  printh(reserve,"@clip")
end

--convert mapdata to memory data
function num2base256(number)
  return number%256==0 and "\\000" or number==10 and "\\n" or number==13 and "\\r" or number==34 and [[\"]] or number==92 and [[\\]] or chr(number)
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
ccccccc777cccccc00cccccccccccc7744400000000000000000044400004ff00ccc10000cccccc0044440004400044000000000000000000000000000000000
cccccc7777cccccccccccccccccccc77ff44040000000440004044ff0004ffff1cc11000cccccccc444440000444444000000000000000000000000000000000
cccc777767c7cccccccccccccccc7c67fff400000440444000004fff00444fff111100001ccccccc444400004444444000000000000000000000000000000000
00ccccc76ccccccccccccc6cccccccc60440044044444f400440044000044ff40011cc101cc1ccc1004444404444444400000000000000000000000000000000
0ccccc776ccccccccc6cccccccccccc6444444404ff4440004444444004f4440001cccc01cc11c10004444404444444000000000000000000000000000000000
ccccc67766ccccc6cccccccc6ccccc664ff44f444fff4f4444f44ff4004444ff0111cc1011111100044444404444444000000000000000000000000000000000
ccccc6676ccc66c6666ccc666c66ccc64fff4ff4ffff4ff44ff4fff400044fff1c11110001101000044444004444440000000000000000000000000000000000
cccccc670666666606666666666666660ff40ff444ff0ff44ff04ff0000044ffcc10000000000000044000000440400000000000000000000000000000000000
00000000000000000777777777777777888888881444144444414441888558888885b38888888888888888888888888811111111111111111155111151111115
00000000000000007777777777677767888888881111111111111111885dd588885dd38888888888888888888888888815118811111111111555885151111155
0000000000000000767766777776667788888888888144188814418885d66d5885d66b3888888888888888888888888811188881115111115888888585111158
00000000000000007766677777776d678888888888144188888144185d6666d53d66663588888888888888888888888811188881111111111888888555111155
000000000000000077d67777dd77dcd7888888888144188888881441165555613655553188888888888888888888888811158881111155111888888551151115
00000000000000007dcd667dccddcccd888877881441888888888144165aa561b653856188885555555555558888888815515551111155111888885185111158
00000000000000007cccd66ccccccccc877766784418888888888811816aa618316b861888855151cc5c551c5888888815511111151111111588855185515588
00000000000000007ccccccc0ccc00cc766776771188888888888888816aa618816388888855c1511c51c551c588888811111111111111111155511188855588
0777777777777777777777707ccccccccc0000000cccccc088144188816aa618816888888551115111511c551158888888855585555555555588555888855888
77777777776777677777777777ccccc01c00cc00cccccccc88114188816556188165588855555555555555555555555588555551551155115155155588511558
76776677777666777777777776ccccc00000ccc01ccccccc8814118881d66d1881d66d889ddddddddd5dddddd577dd7585155155155115511111111585511118
7766677777776d6767776777667cccc000001ccc1cc1ccc18813413881555518815555189d000dd55d555dd00077557555111155155115511151111555111115
77d67777dd77dcd7666677706ccccccc0cc01ccc1cc11c1088b4438888144188881441886000006666566600000dddd555111111111511151111555555155111
7dcd667dccddcccd6d6777667ccccccc1ccc11c11111110088343b888814418888114188d00600dddd5ddd00600dddd511111115115511111511555581155158
7cccd66cccccccccccc66d667ccccccc1ccc01110110100088134188881411888814118850000055555555000005555851888111111115111111155885111158
7ccccccc0ccc00cccccd6dd677cccccc11c00000000000003814b138881441888814418888000888000888800080008851888111111111111111115885111155
d666666dd666666dd666666dd666666d881441144114418883133138881441884188888888888814d666666dd666666d85111111111111115111115888555588
6dddddd56dddddd56dddddd56ddddd55888144144144188888b4b3888814418841888888888888146dddddd56ddddd5555511111111111111115515555115555
666ddd55666ddd5d6ddddd556dddd5d58888144414418888881443388811418841888888888888116ddddd55611dd5d555111111111111111115511511115515
66ddd5d566ddd5ddddddd5d56ddd5dd5888881444418888888134b38881411881188888888888814ddddd5d51671ddd555111111111111111111111511111158
6ddd5dd56ddd5ddddddd5dd56ddddd65888888144188888888344388881441884188888888888811dddd5dd11661dd6585111151111111111111155511151158
6ddd6d65dd5ddddd5ddddd65666dd65588888814118888888813b3888814418841888888888888145ddddd14111dd65585111111111111111151155811111155
85ddd658d5ddddd5ddddd65566dddd658888881141888888881b3188881441884188888888888814ddddd11441dddd6581111111111111111111155815551155
88888888dddddd5dddddddd56ddddd55888888144188888888334188881441884188888888888811dddd11441ddddd5511111111111111111111155855885588
00000000d66ddddddddddd656dddd5d514441444144414448b314188881441888814418888888814ddd167110000000055111111111111111111115888558555
000000006dddddddddddddd56ddd5dd5111111111111111183141188881441888811418888888814ddd166150000000051551111111111111111115855115111
00000000666ddd5ddddddd556dddddd5888888888114411883143188881141888814418888888814dddd11550000000011551511511111151111115555115511
0000000066ddd5ddddddd5d56ddd6d6d8888888888144188881b4138881441888814418888888814ddddd5d50000000051111111111111151111111551111111
000000006ddd5ddddddd5dd585ddd658888888888811418888344138881441888814418888888811dddd5dd50000000011111111111115511111115551111111
000000006ddd6d6d6ddd6d65888888888888888888141188881313b88814418888111188888888146ddd6d650000000085511551111115511111155851111551
000000006d6dd66dd66dd6d588888888888888888814418881663618881411888166661888888814d66dd6d50000000085551551111511111115888885511511
0000000085dddddddddddd5888888888888888888814418816636661881141881666666188888814dddddd580000000088855555558885551588888888855855
88888888888888888888888888888888d666666dd666666dd666666dd666666dd666666dd666666dd666666dd666666d57777777777777777777777557777775
878887788948ff8888888498888888886dddddd56ddddd556dddddd56dddddd56ddddd556dddddd56dddddd56dddddd577777777777777777777777777777777
777777772292fff22ff2292288888888666dd11111111111111ddd5d6111111111ddd5d566611111111111111111dd557777ccc7777777777ccc777777777777
7ffff77742249ff22ff942248888888866dd1671444144441671d5dd1671441167115dd56611671444444444416715d5777ccccc7c7777ccccccc777777cc777
81ff1f782444222424224442877888886ddd1661444414441661dddd1661414166141165114166144444444441661dd5777ccccccc7777c7ccccc77777cccc77
8fffff888222444444442228776788886ddd611444144441411ddddd5111111111144411414411111111111111116d657777ccc7777777777ccc777777cccc77
f833338888822222222288886776778885ddd6111111111111ddddd5ddddd6556dd141671411d65885ddd65885ddd65877777777777777777777777777c7cc77
48688688888888888888888877777678888888886ddd11111111dd5ddddd11111111116611888888888888888888888857777777777777777777777577cccc77
21911429888888888977999992992777866688886dd1671441671dddddd167144167141188888888588888888888888557777777777777777777777577cccc77
27911779888888877767292222992267755588886dd1661141661dddddd16614416611d5888888885588888888888855777777777777777777777777777ccc77
777777778888877777769221129921777ddd88886ddd11111111dd5ddddd11444411ddd58888888855588888888885557777ccccc777777ccccc7777777ccc77
7ffff777888876776229221112222177975588886ddd6d6d66ddd5ddddddd111111d6d6d888888885555888888885555777cccccccc77cccccccc77777ccc777
21ff1f798888776222922114444444474292888885ddd6586ddd5ddddddd5dd585ddd65855555555555555555555555577cccccccccccccccccccc7777ccc777
1fffff2988872222292214444444444744192888888888886ddd6d6d6ddd6d658888888855555555555555555555555577cc77ccccccccccccc7cc77777cc777
f433332988727222922144477774444744412288888888886d6dd66dd66dd6d58888888855555555555555555555555577cc77cccccccccccccccc77777cc777
47674629822262292214447777677444444411288888888885dddddddddddd588888888855555555555555555555555577cccccccccccccccccccc7777cccc77
21911129999999991111111171111111111111190088880003333330077777705555555555555555555555555555555577cccccccccccccccccccc77777ccc77
21111119899142921444444444444444444444190888888003b333307777777755555555555555555555555885555555777cccccccccccccccccc777777cc777
211717198291129211111111111111111111111908788880033333307777777755888855555555555555558888555555777cccccccccccccccccc777777cc777
1111991182914292114444441444444411144429088888800333b33077773377558888555555555555555888888555557777cccccccccccccccc777777ccc777
1117771182914292144444444444444444444429088888800033330077773377558888555555555555558888888855557777cccccccccccccccc777777cccc77
111777198291429214499994444444444999942908888880000440007377333755888855555555555558888888888555777cccccccccccccccccc77777cccc77
411777198291429211219111111111112191112900888800000440007333bb3755555555555555555588888888888855777cccccccccccccccccc777777cc777
1199d9998291429214219114499994442191142900000000009999000333bb305555555555555555588888888888888577cccccccccccccccccccc7757777775
88888899999999921421911441111944219114290000600000060000000600000000000055555555588888888888888577cccccccccccccccccccc7757777775
888899222229922214219114414449442191142900006000000600000006000000ee0ee058555555558888888888885577cccccccccccccccccccc7777777777
889922222992211211219111114442442191142900060000000600000006000000eeeee055558855555888888888855577cc7cccccccccccc77ccc77777c7777
9999999992291442142191144144494421911429000600000006000000060000000e2e0055558855555588888888555577ccccccccccccccc77ccc7777cccc77
829111111929144214299994414449442999942900060000000060000000600000eeeee0555555555555588888855555777cccccccc77cccccccc77777cccc77
829144441929144214111114414449441111142900060000000060000000600000ee3ee05585555555555588885555557777ccccc777777ccccc7777777cc777
82914114192914421444777741444944444444290000600000006000000060000000b00055555555555555588555555577777777777777777777777777777777
82914444192914421447677677744944477744290000600000006000000060000000b00055555555555555555555555557777777777777777777777557777775
00aaaaa0000aaa000000a00000077077700777000777777777777777777777700777777000000d0550d000008888888888888888888888888888888888888888
00a000a0000a0a000000a00007777776777777707000777000007770000077777000777700000501105000008888888888888888888888888888888888888888
00a909a0000a0a000000a000776666666776777770c777ccccc777ccccc7770770c7770700666d666d6d66008888888888888888888888888888888888888888
009aaa900009a9000000a000767776667666667770777ccccc777ccccc777c0770777c0706dddddddddddd608888888888888888888888888888888888888888
0000a0000000a0000000a000000000000000000077770000077700000777000777770007dddddd5555dddddd8888888888888888888888888888888888888888
0099a0000009a0000000a000000000000000000077700000777000007770000777700c07dddd5d5dd5d5dddd8888888888888888888888888888888888888888
0009a0000000a0000000a000000000000000000070000000000000000000000770000007dddddd5555dddddd8888888888888888888888888888888888888888
00aaa0000009a0000000a000000000000000000007777777777777777777777007777770dddddddddddddddd8888888888888888888888888888888888888888
499999944999999449990994cccccccc0077770007777777777777777777777007777770dd555555555555dd8888888888888888888888888888888888888888
911111199111411991140919c77ccccc0700007070000777000077700000777770007777dddddddddddddddd8888888888888888888888888888888888888888
911111199111911949400419c77cc7cc7077000770cc777cccc777ccccc7770770c777075dd5555d555d5ddd8888888888888888888888888888888888888888
911111199494041900000044cccccccc7077bb0770c777cccc777ccccc777c0770777c07dddddddddddddddd8888888888888888888888888888888888888888
911111199114094994000000cccccccc700bbb07707770000777000007770007777700075ddd55d5d55dddd58888888888888888888888888888888888888888
911111199111911991400499cc7ccccc700bbb0777770000777000007770000777700007dddddddddddddddd8888888888888888888888888888888888888888
911111199114111991404119ccccc7cc070000707000000000000000000c000770000c07ddd55555d5555ddd8888888888888888888888888888888888888888
499999944999999444004994cccccccc0077770070000000000000000000000770000007dddddddddddddddd8888888888888888888888888888888888888888
004bbb00004b000000400bbb577775570000000070000000000000000000000770000007dd555555555555dd8888888888888888888888888888888888888888
004bbbbb004bb000004bbbbb7777777700aaaaaa7000000c000000000000000770cc00075ddddddddddddddd8888888888888888888888888888888888888888
04200bbb042bbbbb042bbb007777cc770a99999970000000000cc0000000000770cc000755dddd5555ddddd58888888888888888888888888888888888888888
040000000400bbb004000000777ccccca99aaaaa70c00000000cc00000000c0770000c07d55ddd5dd5dddd5d8888888888888888888888888888888888888888
04000000040000000400000077cccccca9aaaaaa700000000000000000000007700000075ddddd5555dddddd8888888888888888888888888888888888888888
42000000420000004200000057cc77cca999999970000000000000000000000770c000075ddddddddddddddd8888888888888888888888888888888888888888
400000004000000040000000577c77cca999999970000000c0000000000000077000000755dd5dd55dddddd58888888888888888888888888888888888888888
400000004000000040000000777ccccca99999997000000000000000000000077000c007555dd5dddddd5d558888888888888888888888888888888888888888
888888888888888888888888777cccccaaaaaaaa7000000000000000000000077000000788888888888888888888888888888888888888888888888888888888
888888888888888888888888577ccccca49494a1700000000000000000000007700c000788888888888888888888888888888888888888888888888888888888
88888888888888888888888857cc7ccca494a4a1700000000000c000000000077000000788888888888888888888888888888888888888888888888888888888
88888888888888888888888877cccccca49444aa7000000cc0000000000000077000cc0788888888888888888888888888888888888888888888888888888888
888888888888888888888888777ccccca49999aa7000000cc0000000000c00077000cc0788888888888888888888888888888888888888888888888888888888
8888888888888888888888887777cc77a494449970c00000000000000000000770c0000788888888888888888888888888888888888888888888888888888888
88888888888888888888888877777777a494a4447000000000000000000000077000000788888888888888888888888888888888888888888888888888888888
88888888888888888888888857777577a49499990777777777777777777777700777777088888888888888888888888888888888888888888888888888888888
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
0000000000000000000000000000000002020202080808000000000000030303030303030303030303030304040303000303030303030303030303030000000000000000040303040404040404040404000000000303040404040404040404040303030304040404040403030404040400030303030304040404030000000000
0404040003030303030303030303030304040404040303030304040403030303040404040400040404040404030303030404040404000000040404040303030300000000001313131304040000000000000000030013131313040400000000000000000000131313130404000000000000000000001313131000000000000000
__map__
9ebcadadd3adadbdbdbdbdbdbe0000ac00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ad9ebcbdbdbdbeaa0000a9aa000000ac00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
adad9ebfa8a9b9000000ab0000002bac00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bdbdbea9a9a9aa00000000002cbfbfac00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9ee3a9b9a9aabba9ba0000008c8d9dad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
aebba9a9a9a8a9aa000000000000bcad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ad9d8d8d8ea9a9000000000000bba9ac00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
adbeb9a9a9aa00000000000000a9b9ac00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ae0000aba900000000bba9bba9a9a9ac00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
be000000a9ba000000a9a8a9a98c9dad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bba9a9b9b8bba9a9a9b9a9acad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000a9b9a9a99c9ea90000aba9acad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001bb9c9ea9abacaeaa00101010acad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9d9d9dadaeaa00acae10109c9d9dadad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
adadadadae1010acad9d9dadadadadad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
adadadadad9d9dadadadadadadadadad00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

