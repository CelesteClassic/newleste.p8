pico-8 cartridge // http://www.pico-8.com
version 27
__lua__
-- newleste.p8 base cart

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
  [0]=1
}
length_table={
  [0]=2
}
reserve_levels={}

--not using tables to conserve tokens
cam_x=0
cam_y=0
cam_spdx=0
cam_spdy=0
cam_gain=0.25

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
-- effects --
-------------

clouds = {}
for i=0,16 do
  add(clouds,{
      x=rnd128(),
      y=rnd128(),
      spd=1+rnd(4),
      w=32+rnd(32)
    })
end

particles = {}
for i=0,24 do
  add(particles,{
      x=rnd128(),
      y=rnd128(),
      s=rnd(5)\4,
      spd=0.25+rnd(5),
      off=rnd(1),
      c=6+rnd(2)\2
    })
end

dead_particles = {}

-- player entity --
-------------------

player={
  init=function(this)
    this.underwater = false
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
  -- </fruitrain> --
  end,
  update=function(this)
    if pause_player or this.nothing then
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
    if this.feather then 
			--calculate direction and velocity
			if input ~= 0 or inputv ~= 0 then
      	this.movedir = appr_circ(this.movedir, atan2(input, inputv), 0.04)
    	end

			this.spd = make_vec(cos(this.movedir), sin(this.movedir))

			--speed up if holding button
			if input ~= 0 or inputv ~= 0 then
				local k=1.5 + clamp((this.lifetime-80)/10, 0, 10)
      	this.spd.x *= k
      	this.spd.y *= k
    	end

			--bounce off objects
    	if this.bouncetimer==0 then
      	if this.is_solid(0, 2) or this.is_solid(0, -2) then
        	this.movedir *=-1
        	this.bouncetimer = 2
        	init_smoke(this.x, this.y)
				elseif this.is_solid(2, 0) or this.is_solid(-2, 0) then
					this.movedir = (this.movedir<0.5 and 0.5 or 1.5)-this.movedir
					this.bouncetimer = 2
					init_smoke(this.x, this.y) 
				end
			end
			--make sure we dont bounce too often
    	if this.bouncetimer > 0 then
      	this.bouncetimer-=1
    	end

			--lifetime of feather
			if this.lifetime > 0 then
				this.lifetime-=1
				if this.lifetime==0 then
					transform_player(this)
				end
    	end

			--dash out
    	if btn(5) then
      	transform_player(this)
    	end

			local particle = {x=this.x+(rnd(8)-4), y=this.y+(rnd(8)-4), life=10+flr(rnd(5))}
			particle.xspd = -this.spd.x/2-(this.x-particle.x)/4
			particle.yspd = -this.spd.y/2-(this.y-particle.y)/4
			add(this.particles, particle)
		end
		if not this.feather then
    --ground and terrain checks
    local on_ground=this.is_solid(0,1)

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
    if fr1 then
      if fr1.golden and fr2 then
        fr=fr2
      elseif not fr1.golden or level_index()==30 then
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

      if this.underwater then
        accel=0.3
        maxrun=0.6
      end

      -- set x speed
      this.spd.x=abs(this.spd.x)<=maxrun and
      appr(this.spd.x,input*maxrun,accel) or
      appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)

      if this.underwater then
        if abs(this.spd.y) > maxrun then
        this.spd.y=appr(this.spd.y,sign(this.spd.y)*maxrun,deccel)
        else
          this.spd.y=appr(this.spd.y,inputv*maxrun,accel)
        end
      end

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
      if not on_ground and not this.underwater then
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
            this.spd.y=-2
            this.spd.x=-wall_dir*(maxrun+1)
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

        --vertical input

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
        this.dash_target=make_vec(2*sign(this.spd.x),(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y))
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
    

    -- was on the ground
    this.was_on_ground=on_ground
    end 

    if this.y<-4 and not is_end() then
      next_room()
    end
    move_camera(this)
  end,
  draw=function(this)
    -- clamp in screen
    if this.x<-1 or this.x>level_plength()-7 then
      this.x=clamp(this.x,-1,level_plength()-7)
      this.spd.x=0
    end
    -- draw feather 
    if this.feather then 
			foreach(this.particles, function(p)
				pset(p.x+4, p.y+4,10)
				p.x+=p.xspd
				p.y+=p.yspd
				p.xspd=appr(p.xspd, 0, 0.03)
				p.yspd=appr(p.yspd, 0, 0.03)
				p.life-=1
				if p.life==0 then
					del(this.particles, p)
				end
			end)

			if this.lifetime%5==1 then pal(10, 7) end

			if this.lifetime < 10 then
				pal(10, this.lifetime%4<2 and 8 or 10)
			end

			circfill(this.x+4, this.y+4, 4, 10)

			local last=make_vec(this.x+4.5,this.y+4.5)
			foreach(this.tail,function(h)
				h.x+=(last.x-h.x)/1.4
				h.y+=(last.y-h.y)/1.4
				circfill(h.x,h.y,h.size+1,10)
				last=h
			end)
			pal(10, 10)
    -- draw player hair + sprite
    elseif not this.nothing then
      set_hair_color(this.djump)
      draw_hair(this)
      spr(this.spr,this.x,this.y,1,1,this.flip.x)
      unset_hair_color()
    end
  end
}

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


smoke={
  init=function(this)
    this.spd=make_vec(-0.1,0.3+rnd(0.2))
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

function collision_bump(obj)
	local hit = obj.collide(player,-1,-1)
	local ret=hit and hit.dash_effect_time>0
	if ret then
		hit.spd=make_vec(-sign(hit.spd.x)*1.5,-1.5)
		hit.dash_time=-1
		hit.dash_effect_time=0
	end
	obj.hitbox.w-=2
	obj.hitbox.h-=2
	return ret
end

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
    local Khit = this.collide(kevin,-1,-1)
    if collision_bump(this) or Khit then
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

spinner = {
  init=function (this)
    this.tiles={}
    for i=-1, level_tlength() do
      this.tiles[i]={}
    end
    for i=0, level_tlength()-1 do
      for j=0, level_theight()-1 do
        local t=tile_at(i,j)
        if t==64 or t==65 or t==80 or t==81 then
          local rndoffset = make_vec(0,flr(rnd(3))-1)
          if rndoffset.y == 0 then rndoffset.x = flr(rnd(3))-1 end
          local halfoffsetx = (t==64 or t==80) and 4 or -4
          local halfoffsety = (t==64 or t==65) and 4 or -4
          this.tiles[i][j] = make_vec((i*8)+rndoffset.x+halfoffsetx, (j*8)+rndoffset.y+halfoffsety)
        end
      end
    end
  end,
  draw=function (this)
    for i=0, level_tlength()-1 do
      for j=0, level_theight()-1 do
        if this.tiles[i][j] then
          for dx=-1, 1 do
            for dy=-1, 1 do
              if this.tiles[i+dx][j+dy] then
                local centerx,centery = (this.tiles[i][j].x + this.tiles[i+dx][j+dy].x)/2+3 ,(this.tiles[i][j].y + this.tiles[i+dx][j+dy].y)/2+3
                circ(centerx, centery, 4, 1)
                circfill(centerx, centery, 3, 2)
              end
            end
          end
        end
      end
    end
    for i=0, level_tlength()-1 do
      for j=0, level_theight()-1 do
        if this.tiles[i][j] then
          spr(64, this.tiles[i][j].x-4, this.tiles[i][j].y-4, 2, 2)
        end
      end
    end
  end
}

kevin = {
	init=function(this)
		this.sizex=3
		this.sizey=4
		this.lastx=this.x
		this.lasty=this.y
		this.movex=0
		this.movey=0
		this.hittimer=0
		this.solids=true
		--retrace stuff
		this.retrace = {}
		this.retracetimer=0
	end,
	update=function(this)
		--bigger hitbox for activation check
		this.hitbox.w=(this.sizex*8)+2
		this.hitbox.h=(this.sizey*8)+2

		--detect if player activates
		local hit = this.collide(player,-1,-1)
		if collision_bump(this) then
			sfx_timer=20
			sfx(16)

			this.hittimer=10
			this.spd=make_vec(0,0)

			--add to retrace list
			add(this.retrace, make_vec(this.x,this.y))

			if hit.x < this.x-4 or hit.x > this.x+(this.sizex*8)-3 then
				this.movex=sign(this.x-hit.x)*-2
				this.movey=0
			else
				this.movey=sign(this.y-hit.y)*-2
				this.movex=0
			end
		end


		--backtrack
		local len=#this.retrace
		if len ~= 0 and this.movex == 0 and this.movey == 0 and this.retracetimer == 0 and
			abs(this.x - this.retrace[len].x) <= 1 and abs(this.y - this.retrace[#this.retrace].y) <= 1 then
			this.x = this.retrace[len].x
			this.y = this.retrace[len].y
			this.spd=make_vec(0,0)
			this.retracetimer = 5
		end

		if this.retracetimer > 0 then
			this.retracetimer-=1
			if this.retracetimer==0 then
				del(this.retrace, this.retrace[len])
				if #this.retrace ~= 0 then
					this.spd = make_vec(sign(this.retrace[len-1].x - this.x),sign(this.retrace[len-1].y - this.y))
				end
			end
		end

		--countdown after activated to move
		if this.hittimer > 0 then
			this.hittimer-=1
			if this.hittimer==0 then
				this.spd =make_vec(this.movex,this.movey)
			end
		end

		--move player
		local hit = this.collide(player, 0, -1)
		if hit then
			hit.solids = false
			hit.move(this.x-this.lastx, this.y-this.lasty)
			hit.solids = true
			if hit.is_solid(0, 0) then
				kill_player(hit)
			end
		end
		-- use the fact that move checks for collision
		-- and zeroes speed on collision
		-- could probably save a few tokens on the if by using the fact that rem is also zeroed
		local xclmp,yclmp=clamp(this.x, 0, level_plength()+1-this.hitbox.w),clamp(this.y, 0, level_pheight()+1-this.hitbox.h)
		if this.hittimer==0 and this.retracetimer==0 and #this.retrace~=0 and this.spd.x==0 and this.spd.y==0 or xclmp~=this.x or yclmp~=this.y then
			this.movex=0
			this.movey=0
			this.spd=make_vec(0,0)
			this.x=xclmp
			this.y=yclmp

			add(this.retrace, make_vec(xclmp,yclmp))
		end
		
		--keep track of position last update
		this.lastx = xclmp
		this.lasty = yclmp

	end,
	draw=function(this)
		--corners
		local up,down,left,right=this.movey < 0 or this.spd.y < 0,this.movey > 0 or this.spd.y > 0,this.movex < 0 or this.spd.x < 0,this.movex > 0 or this.spd.x > 0
		pal(12, (up or left) and 7 or 12) 
		spr(66,this.x,this.y)
		pal(12, (up or right) and 7 or 12)
		spr(66,this.x+8*(this.sizex-1),this.y, 1, 1, true)
		pal(12, (down or left) and 7 or 12) 
		spr(66,this.x,this.y+8*(this.sizey-1), 1, 1, false, true)
		pal(12, (down or right) and 7 or 12)
		spr(66,this.x+8*(this.sizex-1),this.y+8*(this.sizey-1), 1, 1, true, true)
		--sides
		for x=1,this.sizex-2 do
			pal(12,up and 7 or 12)
			spr(67,this.x+(8*x),this.y, 1, 1, false, false)
			
			pal(12, down and 7 or 12)
			spr(67,this.x+(8*x),this.y+(8*(this.sizey-1)), 1, 1, false, true)
		end
		for y=1,this.sizey-2 do
			pal(12,left and 7 or 12)
			spr(82,this.x,this.y+(8*y), 1, 1, false, false)
			pal(12,right and 7 or 12)
			spr(82,this.x+(8*(this.sizex-1)),this.y+(8*y), 1, 1, true, false)
		end
		pal(12, 12)
		--middle
		rectfill(this.x+8, this.y+8, this.x+(8*(this.sizex-1)), this.y+(8*(this.sizey-1)), 4)
		--face
		spr((up or down or left or right) and 69 or 68, this.x+((this.sizex-1)*8)/2, this.y+((this.sizey-1)*8)/2)
	end
}

feather = {
	init=function(this) 
		this.offset=0
		this.startx=this.x
		this.starty=this.y
		--this.timer=0
		this.sprtimer=0
		this.spawntimer=0
		--this.spawndir=0
	end,
	update=function(this) 
		if not this.hide then
			this.offset+=0.01
			this.y=this.starty+sin(this.offset)*2
			local hit = this.collide(player,0,0)
			if hit then
				psfx(6)
				init_smoke(this.x,this.y)
				this.hide=true
				this.timer=60
				if hit.feather then
					hit.lifetime=45
				else
					this.spawntimer=10
					this.spawndir=atan2(hit.spd.x, hit.spd.y)
					this.x=hit.x
					this.y=hit.y
					this.spd=make_vec(hit.spd.x,hit.spd.y)
					shake=8
					hit.nothing=true
				end
			end
		elseif this.timer>0 then
			this.timer-=1
		else 
			psfx(7)
			init_smoke(this.x,this.y)
			this.hide=false
			this.x=this.startx
			this.y=this.starty
			this.spd=make_vec(0,0)
		end

		if this.spawntimer > 0 then
			this.spawntimer-=1
			this.spd=make_vec(appr(this.spd.x, 0, 0.2),appr(this.spd.y, 0, 0.2))
			if this.spawntimer==0 then
				init_smoke(this.x,this.y) 
				transform_feather(get_player(),this.spawndir,this.x,this.y)
			end
		end

		this.sprtimer+=0.2
	end,
	draw=function(this)
		--draw spinning feather
		if not this.hide then
			local d=flr(this.sprtimer%6)
			spr(97+min(d,6-d),this.x,this.y, 1, 1,d>3) -- 98=first feather animation sprite
		end
		--draw start of orb
		if this.spawntimer > 0 then
			circfill(this.x+4, this.y+4, 4, this.spawntimer%4<2 and 7 or 10)
		end
	end
}

function transform_feather(p,movedir,x,y)
	p.lifetime=45
	p.bouncetimer=0
	p.tail={}
  for i=0,15 do
    add(p.tail,{x=x,y=y,size=max(0,min(1,8-i))})
  end
  p.particles={}
	p.feather=true
	p.nothing=false
	p.movedir=movedir
	p.x=x 
	p.y=y
	p.spd=make_vec(0,0)
end
function transform_player(p) 
	init_smoke(p.x, p.y)
	p.feather=false
	player.init(p)
	p.spd.x/=2
	p.spd.y=p.spd.y<0 and -1.5 or 0
	shake=2
	convert_particles(p.particles)
end

function convert_particles(part)
  foreach(part,function(p)
    p.spd = p.xspd+rnd(2)+0.25
    p.off = 0
    p.s=0
    p.c=6
    p.destroy=true
    add(particles,p)
  end)
end

function appr_circ(value,target,amount)
	return (value +sign(sin(value)*cos(target)-cos(value)*sin(target))*amount)%1
end

water = {
	init=function(this)
		this.tiles={}
		init_water(this.x, this.y, this.y, this.tiles)
		this.timer=0
		this.hasplayer=false
	end,
	update=function(this)
		this.timer+=0.2
		this.timer%=15
		for i in all(this.tiles) do
			local other = this.collide(player, i.x-this.x, i.y-this.y)
			if other then
				if not this.hasplayer then
					init_smoke(other.x, other.y)
					poke(0x5f41, 0xf)
					poke(0x5f43, 0xf)
				end
				this.player=other
				other.djump=max_djump
				if other.y<this.y then
					other.grace=2
				end
				other.underwater=true
				this.hasplayer = true
				return
			end
		end
		if this.hasplayer then
			poke(0x5f41, 0x0)
			poke(0x5f43, 0x0)
			this.player.underwater=false
		end
		this.hasplayer = false
	end,
	draw=function(this)
		local off = flr((this.timer)%7)+1
		for i in all(this.tiles) do
			local top = i.y==this.y and 1 or 0
			for py=i.y,i.y+7 do
				for px=i.x,i.x+7,2 do
					local addr = abs(0x6000 + py*64 + px/2)
					local v=@addr 
					if(py>=i.y+off and py<=i.y+off+3) then 
						v=@(addr+1) << 4 | v >> 4
					end 
					if py>=i.y+top then 
						v=shift_pal((v & 0xf0) >> 4) << 4 | shift_pal(v&0xf)
					end
					poke(addr,v)
				end
			end
			if i.y == this.y then
				for bx=0, 7 do
					pset(i.x+bx, i.y+1+sin((bx+this.timer+i.x)/16)*0.5, 7)
				end
			end
		end
	end
}

function init_water(sx, sy, maxy, tiles)
	if sy<maxy or clamp(sx,0,126)~=sx or clamp(sy,0,126)~=sy or solid_at(sx,sy,8,8) or contains(tiles,make_vec(sx,sy)) then 
		return 
	end
	add(tiles, make_vec(sx,sy))
	init_water(sx+8, sy, maxy, tiles)
	init_water(sx-8, sy, maxy, tiles)
	init_water(sx, sy+8, maxy, tiles)
	init_water(sx, sy-8, maxy, tiles)
	sort(tiles)
end

function contains(t, k)
	for i in all(t) do
		if i.x == k.x and i.y==k.y then return true end
	end
end

function sort(a)
    for i=1,#a do
        local j = i
        while j > 1 and a[j-1].x > a[j].x do
            a[j],a[j-1] = a[j-1],a[j]
            j -= 1
        end
    end
end

function shift_pal(col)
	local sft=col%2 * 4
	return (peek(0xe0c + (col%8)\2 + col\8*64) & 0xf<<sft) >> sft
end

bumper = {
	init=function(this)
		this.hitbox={x=1,y=1,h=14,w=14}
		this.hittimer=0
	end,
	update=function(this)
		if this.hittimer <=0 then
			local hit=this.collide(player,0,0)
			if hit then
				init_smoke(hit.x,hit.y)
				psfx(16)
				local dx = (this.x+8)-hit.x
				local dy = (this.y+8)-hit.y
				if abs(dx) > abs(dy) then
					hit.spd=make_vec(-3.5*cos(0.90)*sign(dx), -3.5*sin(0.90))
				else
					local angle = atan2(dx,dy)
					hit.spd = make_vec(-3*cos(angle), -3*sin(angle))
				end
				hit.dash_time=0
				hit.djump=max_djump
				this.hittimer=20
				shake=6
			end
		end
		if this.hittimer > 0 then
			this.hittimer-=1
			if this.hittimer == 0 then
				init_smoke(this.x+4, this.y+4)
			end
		end
	end,
	draw=function(this)
		local x,y=this.x+8,this.y+8 -- a bit ugly and hacky, but saves a few tokens
		if this.hittimer>0 then
			pal(12, 1)
			pal(4, 2)
			if this.hittimer > 16 then
				circ(x, y, 26-this.hittimer, 7)
				circfill(x, y, 25-this.hittimer, 1)
				if this.hittimer > 18 then
					rectfill(x-4, y-9, x+4, y+9, 7)
					rectfill(x-9, y-4, x+9, y+4, 7)
				end
			end
		end
		spr(101, this.x, this.y, 2, 2)
		pal()
		if this.hittimer == 1 then
			circfill(x, y, 4, 6)
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
  [12] =fruit,
  [14] =fruit,
  [15] =refill,
  [44] =corner,
  [60] =fake_wall,
  [61] =flag,
  [66] =kevin,
  [99] =feather,
  [114]=water,
  [101]=bumper
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
    or obj.collide(kevin,ox,oy)
    or obj.collide(fake_wall,ox,oy)
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

  local same_room=x+8*y==level_index() and not level_index()==0 -- hack so the first level doesn't have same_room=true

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


  if not same_room then
    spinner.init(spinner)
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
function _draw()
  if freeze>0 then return end

  -- reset all palette values
  pal()

  --set cam draw position
  local camx=round(cam_x)-64
  local camy=round(cam_y)-64
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
        c.y=rnd(120)
      end
    end)

  -- draw bg terrain
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),4)

  spinner.draw(spinner)

  -- draw terrain
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),2)

  -- draw objects
  foreach(objects,function(o)
      if o.type ~= water then draw_object(o) end
    end)

  -- draw platforms
  map(xtiles,ytiles,0,0,level_tlength(),level_theight(),8)

  foreach(objects, function(o)
    if o.type==water then
      draw_object(o)
    end
  end)

  -- particles
  foreach(particles, function(p)
      p.x += p.spd-cam_spdx
      p.y += sin(p.off)-cam_spdy
      p.off+= min(0.05,p.spd/32)
      rectfill(p.x+camx,p.y%128+camy,p.x+p.s+camx,p.y%128+p.s+camy,p.c)
      if p.x>132 then
        if(p.destroy ~= nil) then del(particles, p) end --REFLECTIONS
        p.x=-4
        p.y=rnd128()
      elseif p.x<-4 then
        p.x=128
        p.y=rnd128()
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
      --if tile==64 then return true end
    end
  end
  local ox=x
  local oy=y
  x-=4
  y-=4
  for x=x,x+8,8 do
    for y=y,y+8,8 do
      for i=max(0,x\8),min(level_tlength()-1,(x+w-1)/8) do
        for j=max(0,y\8),min(level_theight()-1,(y+h-1)/8) do
         local tile=tile_at(i,j)
         if (tile==64 and x<ox and y<oy) or
            (tile==65 and x>ox and y<oy) or
            (tile==80 and x<ox and y>oy) or
            (tile==81 and x>ox and y>oy) then return true end
        end
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
57777775577777777777777777777775771cc1111111111111cc1cc7577777755555555555555555555555555555555577577775777cccccccccc77700000000
777c77777777c777c777c777c777c7777cc11c11111111111c11c1777777c777555555555555555005555555555555557777777777cccccccccccc7700000000
77c1cc7777ccccccccc1ccc1cc1ccc7777cc1cc1111111111cc1cc7777cccc775555555555555500005555555500005577cc777777cccc7ccccccc7700000000
77111cc777cc1ccc1ccc1ccc11cccc7777cc11cc11111111c1c1cc777cc11c7755555555555550000005555555000055ccccc777577cccccccccc77500000000
7cc1117777c1c111111c111cc11c1cc7771cc11111111111cc1c1cc777cc1c7755555555555500000000555555000055cccccc77577cccccc77cc77500000000
77ccc1777cc1ccc1cc11c111cc11c1777cc1111111111111cc11c177771cccc755555555555000000000055555000055ccc7cc7577ccccccc77ccc7700000000
777c777777cc11cc1c11ccc11cc1cc7777cc1cc1111111111cc1cc7777c1cc7755555555550000000000005555555555ccccc77577cc7ccccccccc7700000000
5777777577cc1c11111111c111c1117777cc11c11111111111c1cc777cc11c7755555555500000000000000555555555ccccc777777cccccccccc77700000000
77cc1c7777c11cc11c111111c111c1c757777777777777777777777577cc1c77c1111111500000000000000555555555ccccc777004bbb00004b000000400bbb
77ccccc77ccc11cc1ccc1cc1cc11cc77777c777c777c777c777c777777ccccc7ccc1cc11550000000000005550555555ccccc777004bbbbb004bb000004bbbbb
77c1cc7777c1c111111c11cc1cc11c7777ccc1cccccc1cccccc1cc7777c1cc771ccc1c11555000000000055555550055c77ccc7504200bbb042bbbbb042bbb00
7cc11c7777c11cc1c111c111111c11777711cc1cc11cc1cc11c11cc77cc11c77111c1cc1555500000000555555550055c77ccc75040000000400bbb004000000
77cc1c7777cc11ccccc1ccc1cc1cccc77cc11c11cc11c111c11cc17777cc1c7711111111555550000005555555555555ccccc777040000000400000004000000
771cc1c77ccccccc1ccc1ccc1cc1cc7777cc1ccccccc1ccccccccc7777ccccc71cc11c1155555500005555555505555577cc7777420000004200000042000000
77c1cc77777c777c777c777c777c777777777c777c777c777c777c77777c777711cc1ccc55555550055555555555555577777777400000004000000040000000
7cc11c7757777777777777777777777557777777777777777777777557777775111111cc55555555555555555555555577557775400000004000000040000000
00000000000000000220cc5555cccc55ddd00dddddd00ddd00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000002125ccc55cccccc5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000222c5cc55cc11cc5011001100cc00cc000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ee000e002e00005cc1cc111111111000000000cc00cc000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002e002e02e0000cc51152222222222001111000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000
00002ee2e2e00000cccc5524444444440111111001d11d1000000000000000000000000000000000000000000000000000000000000000000000000000000000
000002eeeee000005ccc224444444444001dd10001d11d1000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000eeeeee2200005551244444444444000dd0000011110000000000000000000000000000000000000000000000000000000000000000000000000000000000
000e2eeeeeeee0005551244400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000002eeeee000005cc1244400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000eeeeee200000ccc1244400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000e20e2ee20000cc11244400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000e200e00ee0000cc11244400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000ccc1244400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000005cc1244400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000005551244400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaa0000099aa0000999aa0000aaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000009aaa900099aaaa0099aaaaa00aaaaa00000011111100000000000000000000000000000000000000000000000000000000000000000000000000000
0000000001aaa1009911aaaa995aaa11009a5a90000015dccd510000000000000000000000000000000000000000000000000000000000000000000000000000
000000000111110091110aa095aa0001009a5a900001cddccddc1000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111009110000095a0000000995990001ccc1111ccc100000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111001100000095a0000000995990015dc144441cd510000000000000000000000000000000000000000000000000000000000000000000000000
000000000011100010000000095000000009590001dd14c44c41dd10000000000000000000000000000000000000000000000000000000000000000000000000
000000000000100010000000005000000005000001cc14c44c41cc10000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000007007700711155d560000000001cc14444441cc10000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000c77cc77c2493152d0000000001dd144cc441dd10000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000cccccccc0000000000000000015dc144441cd510000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000cccccccc0000000000000000001ccc1111ccc100000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000cccccccc00000000000000000001cddccddc1000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000cccccccc0000000000000000000015dccd510000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000cccccccc01234567000000000000011111100000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000cccccccc89abcdef000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000008242525252528452339200001323232352232323232352230000000000000000000000000000000000000000000000000000000000000000
00000000000000000182920013232352363636462535353545550000005525355284525262b20000000000000000000000000000000000000000000000000000
00000000000000008242845252525252b1006100b1b1b1b103b1b1b1b1b103b10000000000000011000000000000000000000000000000000000000000000000
000000000000000000a2000000a28213000000002636363646550000005525355252528462b2a300000000000000000000000000000000000000000000000000
0000000000000000821323525284525200000000000000007300000000007300000000000000b343000000000000000000000000000000000000000000000000
0000000000000000002100000000a282000000000000000000560000005526365252522333b28292000000000000000000000000000000000000000000000000
0000000000000000a2828242525252840000000000000000b10000000000b1000000000000000000000000000000000000000000000000000000000000000000
0000000000000000b302b20000006182000000000000000000000000005600005252338282828201000000000000000000000000000000000000000000000000
0000000000000000a382824252525252000061000011000000000011000000001100000000000000000000000000000000000000000000000000000000000000
000000000000000000b10000000000a2000000000000000093000000000000008462828282838282000000000000000000000000000000000000000000000000
0000000000000000828382428452525200000000b302b2936100b302b20061007293a30000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000093000086820000a3000000005262828201a200a2000000000000000000000000000000000000000000000000
00000000000000008282821323232323820000a300b1a382930000b1000000007382839311000000000000000000000000000000000000000000000000000000
0000000000000000b2000061000000000000a3858282868282828282930000005262838292000000000000000000000000000000000000000000000000000000
0000000000000000828201b1b1b1b1b182938282930082820000000000000000b100a28272110000000000000000000000000000000000000000000000000000
0000000000000000000000000000000086938282828201920000a20182a376865262828293000000000000000000000000000000000000000000000000000000
00000000000000008382829300000000828282828283829200000000000061001100a38273720000000000000000000000000000000000000000000000000000
00000000000000001111111111110061828282a28382820000000000828282825262829200000000000000000000000000000000000000000000000000000000
00000000000000005353536300000000828300a282828201939300001100000072828292b1039300000000000000000000000000000000000000000000000000
0000000000000000535353535363b2008282920082829200061600a3828382a28462000000000000000000000000000000000000000000000000000000000000
0000000000000000b1b1b1b1000000009200000000a28282828293b372b2000073820100110382a3000000000000000000000000000000000000000000000000
0000000000000000828282828272b20083820000a282d3000717f382829200005262000000000000000000000000000000000000000000000000000000000000
000000000000000000000000002100000000000000000082828282b303b20000b1a2828372038201000000000000000000000000000000000000000000000000
0000000000000000a28283a28273b200828293000082122232122232820000a32333000000000000000000000000000000000000000000000000000000000000
000000000000000000000000a37200000010000000111111118283b373b200a30000828273039200000000000000000000000000000000000000000000000000
00000000000000000082610082820000019200000002132333428462822434340000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000a2820300002222321111125353630182829200008300009200b1030000000000000000000000000000000000000000000000000000
0000000000000000828293008292610082001000001222222252525232253535000000f3100000a3000000000000000000000000000000000000000000000000
00000000000000009321008683039300528452222262c000a28282820000a38210000000a3738000000000000000000000000000000000000000000000000000
00000000000000008283828282000000343434344442528452525252622535350000001263000083000000000000000000000000000000000000000000000000
00000000000000008272828201038200525252528462000000828292000082823200000083829300000000000000000000000000000000000000000000000000
0000000000000000a282018200000000353535354542525252525284622535350000000324440082000000000000000000000000000000000000000000000000
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
2b3b290e0d00500000510000002a3b2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3b29000c000000000000006300002a3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
29000000000000013d0000000000002a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4141000000152122222313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4141414141153132323313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4141414100001414141400000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2041000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2041000000000000402741414100002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000650000000000203734360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000503436515100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0042000000006400005050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000001a1b1c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000c2c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000003c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222222222222320202122222222222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3825252525382600002438252525253800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

