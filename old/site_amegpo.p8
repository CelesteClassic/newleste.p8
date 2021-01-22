pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- ~celeste~
-- matt thorson + noel berry

-- globals --
-------------

room = { x=0, y=0 }
objects = {}
types = {}
freeze=0
shake=0
will_restart=false
delay_restart=0
got_fruit={}
has_dashed=false
sfx_timer=0
has_key=false
pause_player=false
flash_bg=false
music_timer=0
music_toplay=22

screenshake=true

k_left=0
k_right=1
k_up=2
k_down=3
k_jump=4
k_dash=5

k_screenshake=2

positions={}
smokes={}
smoke_={}

collected_tokens=0
total_tokens=0
dream_collision=0
has_badeline={false,--100m
														false,--200m
														false,--300m
														false,--400m
														false,--500m
														false,--600m
														false,--700m
														false,--800m
														false,--900m
														false,--1000m
														false,--1100m
														false,--1200m
														false,--1300m
														false,--1400m
														false,--1500m
														true,--1600m
														true,--1700m
														true,--1800m
														true,--1900m
														true,--2000m
														true,--2100m
														false,--2200m
														true,--2300m
														true,--2400m
														true,--2500m
														true,--2600m
														true,--2700m
														true,--2800m
														true,--2900m
														false,}--3000m

spawn_t=0
level_particles={}

-- entry point --
-----------------

function _init()
	level_particles.w=128
	level_particles.h=128
	init_particles(level_particles,128)
	title_screen()
end

function title_screen()
	got_fruit = {}
	for i=0,29 do
		add(got_fruit,false) end
	frames=0
	deaths=0
	max_djump=1
	start_game=false
	start_game_flash=0
	music(30,0,7)
	
	load_room(7,3)
end

function begin_game()
	frames=0
	seconds=0
	minutes=0
	music_timer=0
	start_game=false
	music(0,0,7)
	room.x=0
	room.y=0
	create_dream_blocks()
	load_room(room.x,room.y)
end

function level_index()
	return room.x%8+room.y*8
end

function is_title()
	return level_index()==31
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
		this.dreaming=false
		this.last_dash_x=0
		this.last_dash_y=0
		create_hair(this)
	end,
	update=function(this)
		if (pause_player) return
		
		local input = btn(k_right) and 1 or (btn(k_left) and -1 or 0)
		
		-- spikes collide
		if spikes_at(this.x+this.hitbox.x,this.y+this.hitbox.y,this.hitbox.w,this.hitbox.h,this.spd.x,this.spd.y) then
		 kill_player(this) end
		
		--dream
		local was_dreaming=false
		local dream=this.collide(dream_block,0,0)
		if dream==nil and this.dreaming then --exiting a dream block
			this.dreaming=false
			this.djump=max_djump
			was_dreaming=true
			this.dash_time=0
			this.dash_effect_time=0
			if btn(k_jump) and not dream_block_at(this.x+4,this.y-4) then
			 this.spd.y=-2
			end
		end
		
		-- bottom death and dream death
		if this.y>128 or dream_collision>=3 then
			kill_player(this)
		end

		local on_ground=this.is_solid(0,1)
		local on_ice=this.is_ice(0,1)
		
		-- smoke particles
		if on_ground and not this.was_on_ground then
		 init_object(smoke,this.x,this.y+4)
			register_smoke(this.x,this.y+4)
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
			 psfx(60)
			 this.djump=max_djump
			end
		elseif this.grace > 0 then
		 this.grace-=1
		end

		this.dash_effect_time-=1
  if this.dash_time > 0 then
   init_object(smoke,this.x,this.y)
  	register_smoke(this.x,this.y)
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
				 register_smoke(this.x+input*6,this.y)
				end
			end

			if not on_ground then
				this.spd.y=appr(this.spd.y,maxfall,gravity)
			end

			-- jump
			if this.jbuffer>0 then
		 	if this.grace>0 then
		  	-- normal jump
		  	psfx(7)
		  	this.jbuffer=0
		  	this.grace=0
					this.spd.y=-2
					init_object(smoke,this.x,this.y+4)
					register_smoke(this.x,this.y+4)
				else
					-- wall jump
					local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
					if wall_dir!=0 then
			 		psfx(8)
			 		this.jbuffer=0
			 		this.spd.y=-2
			 		this.spd.x=-wall_dir*(maxrun+1)
			 		if not this.is_ice(wall_dir*3,0) then
		 				init_object(smoke,this.x+wall_dir*6,this.y)
							register_smoke(this.x+wall_dir*6,this.y)
						end
					end
				end
			end
		
			-- dash
			if (dash and this.djump>0) then
		 	start_dash(this)
			elseif dash and this.djump<=0 then
			 psfx(15)
			 init_object(smoke,this.x,this.y)
				register_smoke(this.x,this.y)
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
		if this.y<-4 and level_index()<30 then
			if collected_tokens==total_tokens then
				next_room()
			else
				this.y=-4
				this.spd.y=0
			end
		end
		
		-- was on the ground
		this.was_on_ground=on_ground
		
		register_pos(this)
		
		add(smokes,smoke_)
		smoke_={}
		if #smokes>30 then
			del(smokes,smokes[1])
		end
		
	end, --<end update loop
	
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

function start_dash(this)
	local input = btn(k_right) and 1 or (btn(k_left) and -1 or 0)

	local d_full=5
	local d_half=d_full*0.70710678118
				
	init_object(smoke,this.x,this.y)
	register_smoke(this.x,this.y)
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
	
	psfx(9)
	freeze=2
	shake=6
	this.dash_target.x=2*sign(this.spd.x)
	this.dash_target.y=2*sign(this.spd.y)
	this.dash_accel.x=1.5
	this.dash_accel.y=1.5
	if input==0 and v_input==0 then
 	this.last_dash_x=this.flip.x and -1 or 1
	else
		this.last_dash_x=input
	end
	this.last_dash_y=v_input
		 	
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
	 sfx(10)
		this.spr=3
		this.target= {x=this.x,y=this.y}
		this.y=128
		this.spd.y=-4
		this.state=0
		this.delay=0
		this.solids=false
		create_hair(this)
		add(smokes,smoke_)
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
				shake=5
				init_object(smoke,this.x,this.y+4)
				register_smoke(this.x,this.y+4)
				sfx(11)
			end
		-- landing
		elseif this.state==2 then
			this.delay-=1
			this.spr=6
			if this.delay<0 then
				destroy_object(this)
				init_object(player,this.x,this.y)
			end
		end
		register_pos(this)
		add(smokes,smoke_)
		smoke_={}
		
		if #smokes>30 then
			del(smokes,smokes[1])
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

function register_pos(obj)
	local p={}
	p.x=obj.x
	p.y=obj.y
	p.flipx=obj.flip.x
	p.spr=obj.spr
	add(positions,p)
	if #positions>30 then
		del(positions,positions[1])
	end
end

function register_smoke(x,y)
	local s={}
	s.x=x
	s.y=y
	add(smoke_,s)
end

badeline = {
	init=function(this)
		this.flipx=1
		this.y=256
		this.spr=1
		this.timer=0
	end,
	update=function(this)
		this.timer+=1
		if this.timer>30 then
 		local p=positions[1]
 		this.x=p.x
 		this.y=p.y
 		this.flipx=p.flipx
 		this.spr=p.spr
 		if this.timer==33 then
 			create_hair(this)
 		end
		end	
		for s in all(smokes[1]) do
 		init_object(smoke,s.x,s.y)
 	end
		
		if this.timer>70 then
 		local hit = this.collide(player,0,0)
		if hit then
 			kill_player(hit)
 		end
		end
	end,
	draw=function(this)
		pal(8,2)
		pal(15,6)
		pal(3,1)
		pal(1,8)
		pal(7,5)
		if this.timer>=3 then
			draw_hair(this,this.flipx and -1 or 1)
		end
		spr(this.spr,this.x,this.y,1,1,this.flipx)
	 pal()
	end,
}
add(types,badeline)

function init_particles(this,f)
		this.particles={}
		for i=1,this.w*this.h/f do
			local p={}
			p.x=rnd(this.w-1)+1
			p.y=rnd(this.h-1)+1
			p.spdx=rnd(2)-1
			p.spdy=rnd(2)-1
			p.tile=rnd(2)
			p.c=0
			local r=rnd(1)
			if r<0.33 then
				p.c=8
			elseif r>=0.33 and r<0.66 then
				p.c=10
			else
				p.c=11
			end
			add(this.particles,p)
		end
	end

dream_block = {
	tile=73,
	init=function(this)
		this.particles={}
	end,
	update=function(this)
		this.hitbox={x=-1,y=-1,w=this.w+2,h=this.h+2}
		local hit = this.collide(player,0,0)
		if hit then
			if hit.dash_effect_time>2 then
				local x_off=2
				local y_off=1
				if dream_block_at(hit.x+hit.spd.x+x_off,hit.y+hit.spd.y+y_off) or dream_block_at(hit.x+hit.spd.x+8-x_off,hit.y+hit.spd.y+8-y_off) or dream_block_at(hit.x+hit.spd.x+8-x_off,hit.y+hit.spd.y+y_off) or dream_block_at(hit.x+hit.spd.x+x_off,hit.y+hit.spd.y+8-y_off) then
 				hit.dash_effect_time=10
 				hit.dash_time=2
 				local spd=3
 				if hit.last_dash_x~=0 and hit.last_dash_y~=0 then
 					spd*=0.70710678118
 				end
 				hit.spd.x=hit.last_dash_x*spd
 				hit.spd.y=hit.last_dash_y*spd
 				hit.dreaming=true
 				hit.djump=max_djump
 			end
			end
		end
 	this.hitbox={x=0,y=0,w=this.w,h=this.h}
	end,
	draw=function(this)
		rectfill(this.x,this.y,this.x+this.w,this.y+this.h,0)
		
		--outline
		for x=0,this.w/8-1 do
			if not dream_block_at(this.x+x*8+1,this.y-1) then
				line(this.x+x*8,this.y,this.x+x*8+8,this.y,7)
			end
		end
		for x=0,this.w/8-1 do
			if not dream_block_at(this.x+x*8+1,this.y+this.h+1) then
				line(this.x+x*8,this.y+this.h,this.x+x*8+8,this.y+this.h,7)
			end
		end
		
		for y=0,this.h/8-1 do
			if not dream_block_at(this.x-1,this.y+y*8+1) then
				line(this.x,this.y+y*8,this.x,this.y+y*8+8,7)
			end
		end
		for y=0,this.h/8-1 do
			if not dream_block_at(this.x+this.w+1,this.y+y*8+1) then
				line(this.x+this.w,this.y+y*8,this.x+this.w,this.y+y*8+8,7)
			end
		end
		
		--particles
		for p in all(this.particles) do
			p.tile+=0.05
			if p.tile>=2 then
				p.tile-=2
			end
			p.x+=p.spdx
			p.y+=p.spdy
			if p.x<=1 or p.x>=this.w-1 then
				p.spdx*=-1
			end
			if p.y<=1 or p.y>=this.h-1 then
				p.spdy*=-1
			end
			if flr(p.tile)==1 then
				rectfill(this.x+p.x,this.y+p.y,this.x+p.x,this.y+p.y,p.c)
			end
		end
	end
}
add(types,dream_block)

function dream_block_at(x,y)
	for obj in all(objects) do
		if obj.type==dream_block then
			if x>=obj.x and x<=obj.x+obj.w then
				if y>=obj.y and y<=obj.y+obj.h then
					return true
				end
			end
		end
	end
	return false
end

token = {
	tile=74,
	init=function(this)
		this.timer=0
		this.spr=74
		this.flipx=false
		this.collected=false
	end,
	update=function(this)
		local hit=this.collide(player,0,0)
		if hit then
			if not this.collected then
				this.collected=true
				init_object(smoke,this.x,this.y)
				sfx(29)
				sfx_timer=10
				collected_tokens+=1
				if collected_tokens==total_tokens then
					for o in all(objects) do
						if o.type==token then
							init_object(smoke,o.x,o.y)
							o.spr=74
					  o.flipx=false
						end
					end
				end
			end
		end
	end,
	draw=function(this)
		if collected_tokens~=total_tokens then
 		this.timer+=1
 		if this.timer>=5 then
 			this.timer-=5
 			if this.spr==74 then
 				this.spr=75
 			elseif this.spr==75 and not this.flipx then
 				this.spr=77
 			elseif this.spr==77 then
 				this.spr=75
 				this.flipx=true
 			elseif this.spr==75 and this.flipx then
 				this.spr=74
 				this.flipx=false
 			end
 		end
		end
		
		palt(0,false)
		palt(8,true)
		if this.collected then
			pal(12,7)
			pal(1,6)
			if collected_tokens==total_tokens then
				pal(12,2)
			end
		end
		spr(this.spr,this.x,this.y,1,1,this.flipx)
		palt()
		pal()
	end
}
add(types,token)

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
			if hit  and hit.spd.y>=0 then
				this.spr=19
				hit.y=this.y-4
				hit.spd.x*=0.2
				hit.spd.y=-3
				hit.djump=max_djump
				this.delay=10
				init_object(smoke,this.x,this.y)
				register_smoke(this.x,this.y)
				
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

function break_spring(obj)
	obj.hide_in=15
end

balloon = {
	tile=22,
	init=function(this) 
		this.offset=rnd(1)
		this.start=this.y
		this.timer=0
		this.hitbox={x=-1,y=-1,w=10,h=10}
	end,
	update=function(this) 
		if this.spr==22 then
			this.offset+=0.01
			this.y=this.start+sin(this.offset)*2
			local hit = this.collide(player,0,0)
			if hit and hit.djump<max_djump then
				psfx(12)
				init_object(smoke,this.x,this.y)
				hit.djump=max_djump
				this.spr=0
				this.timer=60
			end
		elseif this.timer>0 then
			this.timer-=1
		else 
		 psfx(13)
		 init_object(smoke,this.x,this.y)
			this.spr=22 
		end
	end,
	draw=function(this)
		if this.spr==22 then
			spr(13+(this.offset*8)%3,this.x,this.y+6)
			spr(this.spr,this.x,this.y)
		end
	end
}
add(types,balloon)

fall_floor = {
	tile=23,
	init=function(this)
		this.state=0
		this.solid=true
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
				this.delay=60--how long it hides for
				this.collideable=false
			end
		-- invisible, waiting to reset
		elseif this.state==2 then
			this.delay-=1
			if this.delay<=0 and not this.check(player,0,0) then
				psfx(13)
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
		end
	end
}
add(types,fall_floor)

function break_fall_floor(obj)
 if obj.state==0 then
 	psfx(21)
		obj.state=1
		obj.delay=15--how long until it falls
		init_object(smoke,obj.x,obj.y)
		local hit=obj.collide(spring,0,-1)
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

fruit={
	tile=26,
	if_not_fruit=true,
	init=function(this) 
		this.start=this.y
		this.off=0
	end,
	update=function(this)
	 local hit=this.collide(player,0,0)
		if hit then
		 hit.djump=max_djump
			sfx_timer=20
			sfx(19)
			got_fruit[1+level_index()] = true
			init_object(lifeup,this.x,this.y)
			destroy_object(this)
		end
		this.off+=1
		this.y=this.start+sin(this.off/40)*2.5
	end
}
add(types,fruit)

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
		   sfx(20)
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
		 hit.djump=max_djump
			sfx_timer=20
			sfx(19)
			got_fruit[1+level_index()] = true
			init_object(lifeup,this.x,this.y)
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

fake_wall = {
	tile=64,
	if_not_fruit=true,
	update=function(this)
		this.hitbox={x=-1,y=-1,w=18,h=18}
		local hit = this.collide(player,0,0)
		if hit and hit.dash_effect_time>0 then
			hit.spd.x=-sign(hit.spd.x)*1.5
			hit.spd.y=-1.5
			hit.dash_time=-1
			sfx_timer=20
			sfx(22)
			destroy_object(this)
			init_object(smoke,this.x,this.y)
			init_object(smoke,this.x+8,this.y)
			init_object(smoke,this.x,this.y+8)
			init_object(smoke,this.x+8,this.y+8)
			init_object(fruit,this.x+4,this.y+4)
		end
		this.hitbox={x=0,y=0,w=16,h=16}
	end,
	draw=function(this)
		spr(64,this.x,this.y)
		spr(65,this.x+8,this.y)
		spr(80,this.x,this.y+8)
		spr(81,this.x+8,this.y+8)
	end
}
add(types,fake_wall)

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
			sfx(29)
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
			 sfx(22)
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
			if hit then
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

message={
	tile=86,
	last=0,
	draw=function(this)
		palt(8,true)
		palt(0,false)
		spr(86,this.x,this.y)
		spr(70,this.x,this.y-8)
		spr(87,this.x+8,this.y)
		spr(71,this.x+8,this.y-8)
		
		palt()
		this.hitbox={x=0,y=-8,w=16,h=16}
		local hit=this.collide(player,0,0)
		if hit then
			local nx=(this.x*2)-hit.x+8
			clip(this.x,this.y-7,16,15)
			pal(8,2)
			pal(15,6)
			pal(3,1)
			pal(1,8)
			pal(7,5)
			spr(hit.spr,nx,hit.y,1,1,not hit.flip.x)
			clip()
			pal()
		end
		palt(8,true)
		palt(0,false)
		
		spr(123,this.x,this.y)
		spr(78,this.x,this.y-8)
		spr(124,this.x+8,this.y)
		spr(79,this.x+8,this.y-8)
		palt()
	end
}
add(types,message)

big_chest={
	tile=96,
	init=function(this)
		this.state=0
		this.hitbox.w=16
	end,
	draw=function(this)
		if this.state==0 then
			local hit=this.collide(player,0,8)
			if hit and hit.is_solid(0,1) then
				music(-1,500,7)
				sfx(43)
				pause_player=true
				hit.spd.x=0
				hit.spd.y=0
				this.state=1
				init_object(smoke,this.x,this.y)
				init_object(smoke,this.x+8,this.y)
				this.timer=60
				this.particles={}
			end
			spr(96,this.x,this.y)
			spr(97,this.x+8,this.y)
		elseif this.state==1 then
			this.timer-=1
		 shake=5
		 flash_bg=true
			if this.timer<=45 and count(this.particles)<50 then
				add(this.particles,{
					x=1+rnd(14),
					y=0,
					h=32+rnd(32),
					spd=8+rnd(8)
				})
			end
			if this.timer<0 then
				this.state=2
				this.particles={}
				flash_bg=false
				init_object(orb,this.x+4,this.y+4)
				pause_player=false
			end
			foreach(this.particles,function(p)
				p.y+=p.spd
				line(this.x+p.x,this.y+8-p.y,this.x+p.x,min(this.y+8-p.y+p.h,this.y+8),7)
			end)
		end
		spr(112,this.x,this.y+8)
		spr(113,this.x+8,this.y+8)
	end
}
add(types,big_chest)

orb={
	init=function(this)
		this.spd.y=-4
		this.solids=false
		this.particles={}
	end,
	draw=function(this)
		this.spd.y=appr(this.spd.y,0,0.5)
		local hit=this.collide(player,0,0)
		if this.spd.y==0 and hit then
		 music_timer=45
			sfx(57)
			freeze=10
			shake=10
			destroy_object(this)
			max_djump=2
			hit.djump=2
		end
		
		spr(102,this.x,this.y)
		local off=frames/30
		for i=0,7 do
			circfill(this.x+4+cos(off+i/8)*8,this.y+4+sin(off+i/8)*8,1,7)
		end
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
		palt(0,false)
		palt(8,true)
		spr(118,this.x,this.y)
		spr(119,this.x,this.y-8)
		spr(120,this.x,this.y-16)
		palt()
		if this.show then
			rectfill(32,2,96,31,0)
			spr(26,55-6,6)
			print("x"..this.score.."/11",64-6,9,7)
			draw_time(49,16)
			print("deaths:"..deaths,48,24,7)
		elseif this.check(player,0,0) then
			sfx(61)
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
			if room.x==3 and room.y==1 then
				print("old site",48,62,7)
			elseif level_index()==30 then
				print("summit",52,62,7)
			else
				local level=(1+level_index())*100
				print(level.." m",52+(level<1000 and 2 or 0),62,7)
			end
			
			draw_time(4,4)
		end
	end
}

-- object functions --
-----------------------

function init_object(type,x,y)
	if type.if_not_fruit and got_fruit[1+level_index()] then
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

	obj.is_solid=function(ox,oy)
		if oy>0 and not obj.check(platform,ox,0) and obj.check(platform,ox,oy) then
			return true
		end
		return solid_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
		 or obj.check(fall_floor,ox,oy)
		 or obj.check(fake_wall,ox,oy)
		 or (not obj.dreaming and obj.check(dream_block,ox,oy))
	end
	
	obj.is_ice=function(ox,oy)
		return ice_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
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
		local collided_x=obj.move_x(amount,0)
		
		-- [y] get move amount
		obj.rem.y += oy
		amount = flr(obj.rem.y + 0.5)
		obj.rem.y -= amount
		local collided_y=obj.move_y(amount)
	 
	 return collided_x or collided_y
	end
	
	obj.move_x=function(amount,start)
		local ret=false
		if obj.solids then
			local step = sign(amount)
			for i=start,abs(amount) do
				if not obj.is_solid(step,0) then
					obj.x += step
				else --found a collision
					if obj.type==player then
						if obj.dreaming then
							dream_collision+=1
						end
					end
					obj.spd.x = 0
					obj.rem.x = 0
					ret=true
					break
				end
			end
		else
			obj.x += amount
		end
		return ret
	end
	
	obj.move_y=function(amount)
		local ret=false
		if obj.solids then
			local step = sign(amount)
			for i=0,abs(amount) do
	 		if not obj.is_solid(0,step) then
					obj.y += step
				else
					if obj.type==player then
						if obj.dreaming then
							dream_collision+=1
						end
					end
					obj.spd.y = 0
					obj.rem.y = 0
					ret=true
					break
				end
			end
		else
			obj.y += amount
		end
		return ret
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
	sfx(6)
	deaths+=1
	shake=10
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
		restart_room()
	end
end

-- room functions --
--------------------

function restart_room()
	will_restart=true
	delay_restart=15
end

function create_dream_blocks()
	local dream_x=0
	local dream_y=0
	local dream_w=0
	local dream_h=0
	
	local rectangles={}
	local finished=false
	
	local ty=0
	local tx=0
	
	while not finished do
 	while ty<=15 do
 		while tx<=15 do
 			local tile=mget(room.x*16+tx,room.y*16+ty)
  		local visited=false
  		for r in all(rectangles) do
  			if tx>=r.x and tx<r.x+r.w then
  				if ty>=r.y and ty<r.y+r.h then
  					visited=true
  					break
  				end
  			end
  		end
  		if tile==73 and not visited and (dream_h==0 or tx<dream_x+dream_w) then
  			if dream_w==0 then
  				dream_x=tx
  				dream_y=ty
  			end
  			if dream_h==0 then
  				dream_w+=1
  			end
 			else
 				if dream_w>0 then
 					if tx==dream_x+dream_w then
  					dream_h+=1
  					tx=dream_x-1
  					ty+=1
  				else
  					local r={}
  					r.x=dream_x
  					r.y=dream_y
  					r.w=dream_w
  					r.h=max(1,dream_h)
  					add(rectangles,r)
  					dream_x=0
  					dream_y=0
  					dream_w=0
  					dream_h=0
  					tx=0
  					ty=0
 					end
 				end
 			end
 			tx+=1
 		end
 		ty+=1
 		tx=0
 	end
 	if ty==16 and tx==0 then
 		finished=true
 	end
	end
	
	for r in all(rectangles) do
		local o=init_object(dream_block,r.x*8,r.y*8)
		o.w=r.w*8
		o.h=r.h*8
		init_particles(o,32)
	end
end

function destroy_dream_blocks()
	for obj in all(objects) do
		if obj.type==dream_block then
			destroy_object(obj)
		end
	end
end

function next_room()
 if room.x==2 and room.y==1 then
  --old site
  music(-1,500,7)
 elseif room.x==3 and room.y==1 then
  --after old site
  music(16,500,7)
 elseif room.x==4 and room.y==2 then
  --gem
  music(-1,1000,7)
 elseif room.x==4 and room.y==3 then
 	--3000m
 	music(-1,1000,7)
 	music_toplay=26
 	music_timer=45
 end

	if room.x==7 then
		room.x=0
		room.y+=1
	else
		room.x+=1
	end

	--dream block
	destroy_dream_blocks()
	create_dream_blocks()
	
	load_room(room.x,room.y)
end

function load_room(x,y)
	collected_tokens=0
	total_tokens=0

	has_dashed=false
	has_key=false

	--remove existing objects
	for obj in all(objects) do
		if obj.type~=dream_block then
			destroy_object(obj)
		end
	end

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
			else
 			foreach(types, 
 			function(type)
 				if type.tile~=73 then
  				if type.tile == tile then
  					if type==player_spawn and has_badeline[level_index()+1] then
  						init_object(badeline,tx*8,ty*8)
 							positions={}
 							smokes={}
 						elseif type==token then
 							total_tokens+=1
  					end
  					init_object(type,tx*8,ty*8) 
  				end
  			end
 			end)
			end
		end
	end
	
	if not is_title() then
		init_object(room_title,0,0)
	end
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
	  music(music_toplay,0,7)
	 end
	end
	
	if sfx_timer>0 then
	 sfx_timer-=1
	end
	
	-- cancel if freeze
	if freeze>0 then freeze-=1 return end

	-- screenshake
	if btnp(k_screenshake,1) then
		screenshake=not screenshake
	end
	if shake>0 then
		shake-=1
		if screenshake then
 		camera()
 		if shake>0 then
 			camera(-2+rnd(5),-2+rnd(5))
 		end
		end
	end
	
	-- restart (soon)
	if will_restart and delay_restart>0 then
		delay_restart-=1
		if delay_restart<=0 then
			will_restart=false
			load_room(room.x,room.y)
		end
	end

	-- update each object
	local has_player
	foreach(objects,function(obj)
		local collided=obj.move(obj.spd.x,obj.spd.y)
		if obj.type==player and not collided then
		 dream_collision=0
		end
		if obj.type.update then
			obj.type.update(obj) 
		end
	end)
	
	-- start game
	if is_title() then
		if not start_game and (btn(k_jump) or btn(k_dash)) then
			music(-1)
			start_game_flash=50
			start_game=true
			sfx(44)
		end
		if start_game then
			start_game_flash-=1
			if start_game_flash<=-30 then
				begin_game()
			end
		end
	end
end

-- drawing functions --
-----------------------
function _draw()
	if freeze>0 then return end
	
	-- reset all palette values
	pal()
	
	-- start game flash
	if start_game then
		local c=10
		if start_game_flash>10 then
			if frames%10<5 then
				c=7
			end
		elseif start_game_flash>5 then
			c=2
		elseif start_game_flash>0 then
			c=1
		else 
			c=0
		end
		if c<10 then
			pal(6,c)
			pal(12,c)
			pal(13,c)
			pal(5,c)
			pal(1,c)
			pal(7,c)
		end
	end

	-- clear screen
	local bg_col = 0
	if flash_bg then
		bg_col = frames/5
	elseif new_bg then
		bg_col=2
	end
	rectfill(0,0,128,128,bg_col)

	-- clouds
	if not is_title() then
		foreach(clouds, function(c)
			c.x += c.spd
			rectfill(c.x,c.y,c.x+c.w,c.y+4+(1-c.w/64)*12,new_bg and 14 or 1)
			if c.x > 128 then
				c.x = -c.w
				c.y=rnd(128-8)
			end
		end)
	end

	-- draw bg terrain
	map(room.x * 16,room.y * 16,0,0,16,16,4)

	-- platforms/big chest
	foreach(objects, function(o)
		if o.type==platform or o.type==big_chest then
			draw_object(o)
		end
	end)

	-- draw terrain
	local off=is_title() and -4 or 0
	map(room.x*16,room.y * 16,off,0,16,16,2)
	
	-- draw objects
	foreach(objects, function(o)
		if o.type~=platform and o.type~=big_chest and o.type~=badeline and o.type~=smoke then
			draw_object(o)
		end
	end)
	
	foreach(objects, function(o)
		if o.type==badeline then
			draw_object(o)
		end
	end)
	
	foreach(objects, function(o)
		if o.type==smoke then
			draw_object(o)
		end
	end)
	
	-- draw fg terrain
	map(room.x * 16,room.y * 16,0,0,16,16,8)
	
	-- particles
	foreach(particles, function(p)
		p.x += p.spd
		p.y += sin(p.off)
		p.off+= min(0.05,p.spd/32)
		rectfill(p.x,p.y,p.x+p.s,p.y+p.s,p.c)
		if p.x>128+4 then 
			p.x=-4
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
	
	-- draw outside of the screen for screenshake
	rectfill(-5,-5,-1,133,0)
	rectfill(-5,-5,133,-1,0)
	rectfill(-5,128,133,133,0)
	rectfill(128,-5,133,133,0)
	
	-- credits
	if is_title() then
		print("x+c",58,80,5)
		print("original by matt thorson",64-24*2,96,5)
		print("and noel berry",64-14*2,102,5)
		print("by amegpo",64-9*2,114,5)
	end
	
	if level_index()==30 then
		local p
		for i=1,count(objects) do
			if objects[i].type==player then
				p = objects[i]
				break
			end
		end
		for p in all(level_particles.particles) do
			p.tile+=0.05
			if p.tile>=2 then
				p.tile-=2
			end
			p.x+=p.spdx
			p.y+=p.spdy
			if p.x<=1 or p.x>=127 then
				p.spdx*=-1
			end
			if p.y<=1 or p.y>=127 then
				p.spdy*=-1
			end
			if flr(p.tile)==1 then
				rectfill(p.x,p.y,p.x,p.y,p.c)
			end
		end
	end
end

function draw_object(obj)

	if obj.type.draw  then
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
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700000060000000600000060000
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a0000777777677777770000060000000600000060000
000000008888888888888888888ffff888888888888888800888888088f1ff1800a909a0000a0a000000a0007766666667767777000600000000600000060000
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff8009aaa900009a9000000a0007677766676666677000600000000600000060000
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff80000a0000000a0000000a0000000000000000000000600000006000000006000
0000000008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0000000000000000000000600000006000000006000
00000000003333000033330007000070073333000033337008f1ff10003333000009a0000000a0000000a0000000000000000000000060000006000000006000
000000000070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a0000000000000000000000060000006000000006000
555555550000000000000000000000000000000000000000008888004999999449999994499909940300b0b0666566650300b0b0000000000000000070000000
55555555000000000000000000000000000000000000000008888880911111199111411991140919003b330067656765003b3300007700000770070007000007
550000550000000000000000000000000aaaaaa00000000008788880911111199111911949400419028888206770677002888820007770700777000000000000
55000055007000700499994000000000a998888a1111111108888880911111199494041900000044089888800700070078988887077777700770000000000000
55000055007000700050050000000000a988888a1000000108888880911111199114094994000000088889800700070078888987077777700000700000000000
55000055067706770005500000000000aaaaaaaa1111111108888880911111199111911991400499088988800000000008898880077777700000077000000000
55555555567656760050050000000000a980088a1444444100888800911111199114111991404119028888200000000002888820070777000007077007000070
55555555566656660005500004999940a988888a1444444100000000499999944999999444004994002882000000000000288200000000007000000000000000
5777777557777777777777777777777577cccccccccccccccccccc77577777755555555555555555555555555500000007777770000000000000000000000000
77777777777777777777777777777777777cccccccccccccccccc777777777775555555555555550055555556670000077777777000777770000000000000000
777c77777777ccccc777777ccccc7777777cccccccccccccccccc777777777775555555555555500005555556777700077777777007766700000000000000000
77cccc77777cccccccc77cccccccc7777777cccccccccccccccc7777777cc7775555555555555000000555556660000077773377076777000000000000000000
77cccc7777cccccccccccccccccccc777777cccccccccccccccc777777cccc775555555555550000000055555500000077773377077660000777770000000000
777cc77777cc77ccccccccccccc7cc77777cccccccccccccccccc77777cccc775555555555500000000005556670000073773337077770000777767007700000
7777777777cc77cccccccccccccccc77777cccccccccccccccccc77777c7cc77555555555500000000000055677770007333bb37000000000000007700777770
5777777577cccccccccccccccccccc7777cccccccccccccccccccc7777cccc77555555555000000000000005666000000333bb30000000000000000000077777
77cccc7777cccccccccccccccccccc77577777777777777777777775777ccc775555555550000000000000050000066603333330000000000000000000000000
777ccc7777cccccccccccccccccccc77777777777777777777777777777cc7775055555555000000000000550007777603b333300000000000ee0ee000000000
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc77755550055555000000000055500000766033333300000000000eeeee000000030
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777555500555555000000005555000000550333b33000000000000e8e00000000b0
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc7755555555555550000005555500000666003333000000b00000eeeee000000b30
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc775505555555555500005555550007777600044000000b000000ee3ee003000b00
777cc777777777777777777777777777777777777777777777777777777cc7775555555555555550055555550000076600044000030b00300000b00000b0b300
77cccc77577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00000303300
5777755777577775077777777777777777777770077777708000000000000008cccccccc0000000088cccc8888cccc880000000088cccc888000000000000008
7777777777777777700007770000777000007777700077770011111111111100c77ccccc000080008c0000c88c0000c8000000008c0000c80011111111111100
7777cc7777cc777770cc777cccc777ccccc7770770c777070111111111111110c77cc7cc00b00000c00cc00cc00c100c00000000c00cc00c0111111111111110
777cccccccccc77770c777cccc777ccccc777c0770777c070111ccc11ccc1110cccccccc00000000c0c00c0cc010c10c00006000c00cc00c0111877187881110
77cccccccccccc7770777000077700000777000777770007011cccccccccc110cccccccc0000b000c0cccc0cc01cc10c00060600c00cc00c0110078877887110
57cc77ccccc7cc757777000077700000777000077770000701cccccccccccc10cc7ccccc0b000000c00cc00cc00c100c00d00060c00cc00c0187568778877810
577c77ccccccc7757000000000000000000c000770000c0701cccccccccccc10ccccc7cc000000808c0000c88c0000c80d00000c8c0000c80177607788778010
777cccccccccc7777000000000000000000000077000000701cccccccccccc10cccccccc0000000088cccc8888cccc88d000000c88cccc880178856887750610
777cccccccccc7777000000000000000000000077000000701cccccccccccc100000000000000000000000000000000c0000000c000600000000000000000000
577cccccccccc7777000000c000000000000000770cc000701cccccccccccc10000000000000000000000000000000d000000000c060d0000000000000000000
57cc7cccc77ccc7570000000000cc0000000000770cc000701cccccccccccc1000000000000000000000000000000c00000000000d000d000000000000000000
77ccccccc77ccc7770c00000000cc00000000c0770000c0701cccccccccccc1000000000000000000000000000000c0000000000000000000000000000000000
777cccccccccc7777000000000000000000000077000000701cccccccccccc105555555506666600660000006666600000006666600666606666660066666600
7777cc7777cc777770000000000000000000000770c0000701cccccccccccc105555555566666660660000006606660000066666660666606666666066666660
777777777777777770000000c00000000000000770000007011cccccccccc1105555555566000660660000006600660000066000000066000066000066000000
57777577775577757000000000000000000000077000c007011cccccccccc11055555555dd000dd0dd000000dd00dd00000ddddddd00dd0000dd0000dddd0000
000000000000000070000000000000000000000770000007007777005000000000000005dd000dd0dd0000d0dd00dd00000000000d00dd0000dd0000dd000000
00aaaaaaaaaaaa00700000000000000000000007700c0007070000705500000000000055ddddddd0ddddddd0dd0ddd00000ddddddd0dddd000dd0000dddddd00
0a999999999999a0700000000000c00000000007700000077077000755500000000005550ddddd00ddddddd0ddddd0000000ddddd00dddd000dd0000ddddddd0
a99aaaaaaaaaa99a7000000cc0000000000000077000cc077077bb07555500000000555500000000000000000000000000000000000000000000000000000000
a9aaaaaaaaaaaa9a7000000cc0000000000c00077000cc07700bbb0755555555555555550000000000000c000000000000000000000000000000c00000000000
a99999999999999a70c00000000000000000000770c00007700bbb075555555555555555000000000000c00000000000000000000000000000000c0000000000
a99999999999999a700000000000000000000007700000070700007055555555555555550000000000cc0000000000000000000000000000000000c000000000
a99999999999999a07777777777777777777777007777770007777005555555555555555000000000c000000000000000000000000000000000000c000000000
aaaaaaaaaaaaaaaa0777777777777777777777700777777085000644666666448666664400000000c0000000018876066506771000000000000000c000000000
a49494a11a49494a700077700000777000007777700077778550064466666644662268440000000100000000018776050687781000000000000000c00c000000
a494a4a11a4a494a70c777ccccc777ccccc7770770c77707855556448554454462266844000000c0000000000176056068778810000000000000001010c00000
a49444aaaa44494a70777ccccc777ccccc777c0770777c07854555448555464462266844000001000000000001056778577887100000000000000001000c0000
a49999aaaa99994a7777000007770000077700077777000785445644855006446226684400000100000000000188778607887710000000000000000000010000
a49444999944494a77700000777000007770000777700c0785445644850006446622684400000100000000000187788568877810000000000000000000001000
a494a444444a494a7000000000000000000000077000000788888644850056448666664400000000000000000117887088778110000000000000000000000000
a49499999999494a0777777777777777777777700777777088888844850056448888884400010000000000000118870687788110000000000000000000000010
5252338292000000a292920000a213525223339200a2a28382929200a213235252845252620192a292004252232323525284526292a4a2039300a400a2425284
94949442525252522323232323235252133342845252526200a20142845252523392a2831333b1b1b1b1b1b1b1b1b1b192a28313232323232323232323232352
5262019200000000000000000000a24233929200000000a29200000000a2a2135252528462920000000042628392004252522333e300007383930000d3132352
94949442845252628392a2018282425204a34252528452629300a24252525284920000a29494930000000000000000000000a29494839200a28201920000a242
52339200000000000000000000610042920000000000000000000000000000a2232323236200000000a34262920000425262019294949494949494949400a242
9494944252528462920000a28283428400a21323232323339200a34252525252000000a39494920000a3000000000000000000949492000000a2920000000042
62920000000000000000000000000042e3a4a3930000000000000000a393a4f3838292a20300006100a2426200a4004284629200949494949494949494000042
949494132323233300001100a28242520000a2920000a2920000a21323232323930000a294940000a20193001111110000000094949200000000000000000042
620000000000000000a3930000000042225363920000111111110000a2435322829494940393000000004262f3a3934252620000949494949494949494930042
019200b39494949400a372b200a242520000000000000000000000a292a282019200000000000000009200009494949393d3a394949300000000a39300000042
6293000000e30000a3828393000000423392920000a394949494930000a2a213929494947392000000004262949494425262a4a3949494949494949494920042
920000b39494949400a203b2000042529300000000000000000000000000a2821111111111111111111111009494949294949412320193a4d3a3123293000042
6294949412535353535353533200004292000000a382949494948293000000a2939494949300000000a3426294949442526200a2949494949494949494000042
000000b39494949411110311111142528293000000000000000000a3a30000a22222222222222222222232b200a2920094949413235353535353236292000042
6294949403273737373737470393a44200000000a2019494949401920000000092949494829300e3a3014262949494425262111194949494949494949400a442
9300b31222222222222262949494425283920000000000000000a282839300005284525252525252845262b20000000092a283949492000000a2010300000042
62949494425353535353535352222252a400000000a2949494949200000000a4329494942222222222225262949494428452223294949494949494949400a342
9200b342528452525284629494944284920000a3930000000000a282829300005252525284525252525262b2000000a30000a294940000000000a20393000042
629494947393000000f300a2132352523200000000a2949494949200000000126294949423232323232323339494944223232333949494949494949494a38242
0000b3132323232323233394949442520000a3828293000000060092920000002323232323232323232333b2000000a300000094949300000000a3039200a342
629200a28394949494949494a2014252629300000000a282839200000000a3426200a201949494949494949482920042a292a201949494949494949494a28342
0000a394949494949494b2a2a28342520000a28283920000e30000d3000000009200a28394949494949494b2000000a293000012329200000000a30300a30142
62000000a29494949494949400a2425262829300000000a2920000c200a38242629300a2949494949494949492000042000000a294949494949494949400a242
0000a294949494949494b20000a242520000a282828200001222223293000000000000a294949494949494b20000000092000042620000000000a20300a28242
62000000009494949494949400a4425262838293f310000000d300c3a38283426292000094949494949494940000a34200000000949494949494949494111142
00000094949494949494b20000a2425293000001829200a342525252329300000000c20094949494949494b2000000a30000004262930000000000030000a242
6210d3000094949494949494000042525222222222222222222222222222225262000000949494949494949400a3824293f310a39372d3a4a37293a4f3122252
9310e30000a282839200001111114284829310a28200a31252528452620193a39310c30000a28201920000000000a30100000042628293a40000a30300000042
52223293000000a29200000011114252525252525252528452525252525252526210d3000000a28292000000a382834222222222225222222252222222528452
222232000000a2920000a312222252522222222232f3a3428452525252222222222232930000a2920000000000a382829310a34262018293f3a3830393a1e342
5252523293000000000000a3123242525252528452525252525252525284525252223293000000000000a3a31222225252528452525252525284525252525252
528462930000000000a301425284525284525252522222525252525252528452525262829300000000000000a382838222222252522222222222225222222252
9200a20142528452525284525252845282019200000000a29292000000a28382828292a2132323232323232352525252b1b1b103b1b1b1b1b113232362839203
42845252522323232323233383920000949494949442525252845252528452620000000000000000000000000000000000000000000000000000000000000000
d30000a24223232323232323232323528292000000000000000000000000a28201920000b1b1b1b1b1b1b1a3428452529310e3039300000000a2a28303920003
42525252629200009494949492000000949494949442845252232323232323330000000000000000000000000000000000000000000000000000000000000000
9494949403839294949494949200a242920000000000000000000000000000a29211110011110000000000a2425252849494940392000000000000a203000003
42525252620000a39494949400a393939494949494132323338282920000a2010000000000000000000000000000000000000000000000000000000000000000
94949494039200949494949400a4a34200000000000000000000000000000000639494b34363b2610000000013232323949494039341d300000000000300a303
42528452629494941222222222222232920000a20194949494839200000000a20000000000000000000000000000000000000000000000000000000000000000
94949494030000949494949400a3014200a4000000000000000000000000a40000a292b394949300001100009400a2839494941353533293000000a30300a203
4252525262949494428452525252846200000000a294949494920000000000a3000000000000000000000000000000000000000000000000c400000000000000
9494949403000043535353639494944200000000000011111111000000000000000000b394949200b372b200940000a28392a294a2010392000000a203111103
4252525262a38283425252528452526211111111119494949411111111a3a38300000000000000000000000000000000000000000095a5b5c5d5e5f500000000
949494940300009494949494b1b1b142930000000000949494949300000000001111111111111111b303b211940000009200009400a20311111100f303949403
1323232333a2828242232323522323331222222222222222222222223294949400000000000000000000000000000000000000000096a6b6c6d6e6f600000000
a282828203000094949494940000a3420193000000a3949494949200000000a32222222222225353532353639400000011111194930003949472949403949403
019200949400a201039200a3030000a2425284525252525252528452629494940000000000000000000000000000000000000000009700000000e7f700000000
00a28382031111949494949400a382428292000000a3949494940000000000a352845252526283829294a292b3b2000053535363839303949403949473949403
92000094940000a20300a4a20300a400425252525252845252525252629494940000000000000000000000000000000000000000000000000000000000000000
0000a282135353535353536300a283429200000000a2949494949300000000a2525252528462829200940000b3b2111192a20194829203839203828292a28303
0000009494930000030000a303930000132323232323232323232323339494940000000000000000000000000000000000000000000000000000000000000000
000000a294949494949494940000a24200a4000000009494949492000000a400232323232333920000940000b37294940000a29492000392000301820000a203
0000a312329494940394949403949494a282839294949494949494a2018292a20000000000000000000000000000000000000000000000000000000000000000
9300000094949494949494949300a2420000000000000000a292000000000000a283949494940000b372b200b30394940000009411110300a303920000000003
0000a24262949494739494947394949400a292009494949494949400a292000000000000000000000000e3d30000000000000000000000000000000000000000
93000000949494949494949492000042930000000000000000000000000000a300a2949494949300b303b200b30394940000004353533300a203000000000003
0000004262000000a292000000a201820000c2009494949494949400000000000000000000000000000012320000000000000000000000000000000000000000
9210e3000000a29200000000111111420193000000000010000000000000a3010000949494949200b373b200b37394940000a394949494000003000000000003
1000004262000000000000000000a2829310c300000012223293000000000000e31000e300f3000000f3425232d3670000000000000000000000000000000000
2222329300000000000000a31222225282829300000000717100000000a3828210000000a2920000a3930061000000a300a3829494949400000380000000a303
3200a3426293000000000000000000a22222320000a3425262829300000000a3222222222232d3e3122252845222222200000000000000000000000000000000
84526201930000000000a38342528452828382930000a39393000000a382838232930000000000a3018293000000a383a3828312222232930003930000a30103
62a38342628393000000a3019300000052526293a3014284628283930000a3835284525284522222525252525252845200000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000660000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000660000000000
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
00000000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000060600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000d00060000000000000000000000000000000000000000000000000000060000000
0000000000000000000000000000000000000000000000000000000000000d00000c000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000d000000c000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000c0000000c000600000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d000000000c060d0000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c00000000000d000d000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000007700000000000000000
00000000000000000000000000000000000006666600660000006666600000006666600666606666660066666600000000000000000007700000000000000000
00000000000000000000000000000000000066666660660000006606660000066666660666606666666066666660000000000000000000000000000000000000
00000000000000000000000000000000000066000660660000006600660000066000000066000066000066000000000000000000000000000000000000000000
000000000000000000000000000000000000dd000dd0dd000000dd00dd00000ddddddd00dd0000dd0000dddd0000000000000000000000000000000000000000
000000000000000000000000000000000000dd000dd0dd0000d0dd00dd00000000000d00dd0000dd0000dd000000000000000000000000000000000000000000
000000000000000000000000000000000000ddddddd0ddddddd0dd0ddd00000ddddddd0dddd000dd0000dddddd00000000000000000000000000000000000000
0000000000000000000000000000000000000ddddd00ddddddd0ddddd0000000ddddd00dddd000dd0000ddddddd0000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000007000000000000000000000000000000c000000000000000000000000000000c00000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c00000000000000000000000000000000c0000000000000000000000000000000000000000000000
0000000000000000000000000000000600000000000000cc0007000000000000000000000000000000c000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c000000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000100000000000000000000000000000000000000c00c000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0770000000000000000000000000000000000001010c00000000000000000000000000000000000000000
000000000000000000000000000000000000000001007700000000000000000000000000000000000001000c0000000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000010000000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000001000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010600000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000500555050000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000550555055500550555055005550500000005550505000005550555055505550000055505050055055500550055055000000000000000000
00000000000000005050505005005000050050505050500000005050505000005550505005000500000005005050505050505000505050500000000000000000
00000000000000005050550005005000050050505550500000005500555000005050555005000500000005005550505055005550505050500000000000000000
00000000000000005050505005005050050050505050500000005050005000005050505005000500000005005050505050500050505050500000000000000000
00000000000000005500505055505550555050505050555000005550555000005050505005000500000005005050550050505500550050500000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000055505500550000005500055055505000000055505550555055505050000000000000000000000000000000000000
00000000006000000000000000000000000050505050505000005050505050005000000050505000505050505050000000000000000000000000000000000000
00000000000000000000000000000000000055505050505000005050505055005000000055005500550055005550000000000000000000000000000000000000
00000000000000000000000000000000000050505050505000005050505050005000000050505000505050500050000000000000000000000000000000000000
00000000000000000000000000000000000050505050555000005050550055505550000055505550505050505550000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005550505000005550555055500550555005500000000000000000000000000000000000000000000007
00000000000700000000000000000000000000000000005050505000005050555050005000505050500000000000000000000000000000000000000000000007
00000000000000000000000000000000000000000000005500555000005550505055005000555050500000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050005000005050505050005050500050500000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005550555000005050505055505550500055000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200001313131300000300000002000000000013131313000004020202020202020000131313130004040202020202020200001313131300000002020000020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4825323328290000000000002a31254825323300000000003a31322548252525263829003148261b1b1b1b1b1b312525262a28383900002a282831322525261b25482532333900000031331b1b1b1b24253329000000000038290000002a38242533283900000000000000000000312525332938293a2900002a10301b1b1b24
2533382929000000000000000028312533000000000000002a282831322525482629000000242628393900000000242533002a28283900002a10282824482600253233393a1039003a38290000000024332900000000003a2839000000002a2426002a383900003a28000000003a3824262928291029000000002a3039000024
262900000000000000000000002a2824000000000000003a2828382900312525260000000031332828283828390024250000002a282839003a28282824252600332838282828282828290000003a3a2429004a000000003a2828390000002a242600002a282a2828290000003a282924261029162a003a0000003a30291a0024
26000000000000000000000000002a2400003d0000003a3828282900000031322600000000000000002a282828392448000000002a2829002a28282824252600292c002a002a2a39280000003a28382400000000000000002a2a3900004a0024260c002a2a3a1029000c003a2829292426290000002a3839003a383000003e24
26000000003d00000000000000003a242222222222222328282800000000000026000000003a3900002123292a2824250000171700290000002a28382448261a003c000000003e2a290000003a1028243e00000000000000003a283900003f24260000003a390000003a3a10290000243329003a393a29003a2828302b3b3425
252222222222222223000000003a382448253232323233282829000000000000260000003a28283939242600002a24253a2839000000000000002a283132330022222222222235363900003a2828282436171717000000393a292a103921222526004a3a3828003a3a3828290000002429003a102829003a2929293000002a24
482532323232323233393a393a282824323328282839002a282828390000000026003e3a28292a10282426000000242528282839000000000000002a2828290025482525323339002a393a10213535253839000000003a103a39392a2a2425482600003a292a28282a392a2a39000024393a282829293a290000003000000024
323328102829002a283828102829002438282828102800002a2a28382839003d2522222222222222222526000000242538282829000000001717003a2829000025253233002a28002a28292a30002a2428283939003a292900002a000031322526000b1029002810392a0b002a3939242a3828293a38290000000030004a0024
2838282828000000002a282829000024282828282828000000002a2828212222254825252525482525252639000024252829291717000000003a3a28290000003233282900002a283829000030000024292828102939391600002a390038293133003a29003a282900000000002a2a31002a2929282839120000003039000024
2828292a2800000000002a29003e002429002a2a282800000000003a282425252525253232323232323233283939242529000000000000003a382829000000002a290000000000282900000030391c240029002900290039000000283a290000003a29003a3a2a00000000394a000000003a2900292a10271111113029000024
29000000283939000000000000212225000000002828390000003a28102448253232332828282900002a38282810242500000000000000002a282839001717000000000000003a102900000030283924000000003a3929283900002a290000003a293a3a002a1039003a3a29000000003a29000000002a313535353329003a24
00000000282838390000000000242525000000002a282839003a282929242525002a28382829000000002a28282924480000000000000000002a2828390000000001003d00002a29000000003038282400013d00002900283900393a0000000029003a0c3a002a29393a290c00000000290000000000002a2a28382900002a31
00013f3a28282821230000111124252500013d00002a3828282829003e2425250000002a281111110000002a290024250001003e0000171700002a2810390000353535360012000000003a3a242222252222230000003a10282928283900000000002a2a3828290038283a39000000000000000000000000002a2a000000002a
2222222223292a2426111121222548252222230000000000002a21222225252500013d002a212223000000003f00242522222223390000000000002a28283900290000003a27390000002a38242525252525263900003a282900292a390000002c0000002a29003a29002a38390000000001003f00000000000000000000003a
2548252526111124482222252525252525482611111111111111242548252525222223000024482600002122222225252525482628390000000000002a2828390000003a2830290000002a282425482525482638282829290000002a283939003c00013e00003a290000002a2839000022222223390000171700000017173a29
252525252522222525252525252525252525252222222222222225252525252525482600002425260000242548252525252525262929000000000000002a2a2800003a38283000000000002a242525252525262929000000000000002a38390022222223003a29000000003a28103939252525262839000000000000003a1039
263900002a2839000024261b1b1b2425253232322532323225253310292a3125253232323233292a2828283028292a2424262425252600000000242525262426494949492425252525261b1b1b1b1b1b262a102448252525252525482525252538290000002a10242610290000002a3832323232322548252525254826102924
26393900002a283900242639000024482610292a372a28382433282900002a2426282828292900002a28103029000024242624254826000000002448252624264949494924482525252639000000003a26002a31253232323232253232323225294a3d0000002a3133290000003f4a2a382900002a3132322525252526290024
262a390000002a38392426394a002425262900001b002a283038290000002a242638282900000000002a2830001a00242426242525264949494924252526242649494949242525254826390000003a382639002a37002a292a2a37393a393e312235364949494949494949494934352229000000002a2a102448252526000024
26002a390000002a28242629003a2425262900000000002a30290000000000242628290000003a3900162a3000003a242426242525264949494924252526242649494949313232323233290000002a282629004949494949494949494949492a263829494949494949494949492a3824000000000000002a2425323233000024
26002a10111100002a2426293a2924252600000011000000300000000000002426290000113a292900002a3000002a242426244825264949494924254826242629002a1049494949494900000000002a2600004949494949494949494949490026290049494949494949494949002a2400000000000000003133494949003a24
2639002a21233900002426002a39242526004a3a2739083a300000000000142426394a3a2729000000003a3000002a24313331323233494949493132323331332c00002a49494949494900000000002a2639004949494949494949494949490026290049494949494949494949002a2439143a39000000000000494949003a24
3329160024262839002426002a1024252639003a3029002a30000000003435323329002a3711000000162a3000000024403a292a2828494949492828292a21233c3a390049494949494900003d0000002638394949494949494949494949493a264a0049494949494949494949004a242222222339000000003a494949002a24
290000002426102900242600002a24482628392a301111113039000000002a10290000003b272b0000003a30390000243a2900002a3849494949382900003133222223111111111111111121234949493235352235353535352222233900002126390049494949494949494949003a2448323233290000003a10494949000024
000000002426282900242600160024252638290031353535332900001600002a000000003b302b00003a283029003a2422353600002a4949494929000034352232323235222235353535353226494949382900372900003a393132333839002426290049494949494949494949002a2433292a290000003a2828494949000024
00000000242629003a2426390000242533290000002a2838290000000000002a000000003b302b00002a383000003a243310290000002a2a29290000002a103129002a10313339001a003e3a374949492900004949494949494949494949492426111149494949494949494949111124290000000000002a3828494949000024
00000000242600002a313329000024252900000000002a290000000000000000000000003b30111100002a3011002a2438290000000000000000000000002a380000002a49494949494949494938292a00000049494949494949494949494924323536494949494949494949493435320000000000003a39002a494949000824
0000003a242600162a1029000000242539000000000000000000000000000000390000003b31353600002a31362b3b312900000000000000000000000000002a000000004949494949494949492900000000004949494949494949494949492439002a292900002a1028292a2929002a00000000003a21233900494949390024
3d013a282426390000290000000024252900000000000000000000000000000029000000001b1b1b0000001b00000000000000003a39005600003a3900000000000000004949494949494949490000390000004949494949494949494949492429000000000000002a2900000000003a00000000003a2426293a494949290024
222223282426290000000000000024253e01000000000000000000000000003a3901003f00000000000000000000003a3901003a21222222222222233900003a39013f000000002a29000000003a391039013d3a212222233f00002a29003a24390100003a3a3900003e3a3900003a383900013d3a382426002a212223111124
2548263824260000000000003a3a244821222339000017170000001717173a282222222300111111001200113a393a10212222222548252525254825222222232222233900000000000000003a212222222222222525482522222222222222252122222222222222222222222222222322222222222225260000244825222225
2525262a242600000000003a2838242524252610390000003a393900003a283825482526392122233a27392122222222244825252525252525252525252548262548263839000000000000002a242548252548252525252525252525482525252425252548252525252525254825252625482525254825261111242525252548
__sfx__
010600000c17618570185701857018570185701856018560185601856018560185501854018530185301853018520185201852018510185101851018510185150050000500005000050000500005000050000500
010900010c770296002760026600266002660027600286002860029600296002a6002a6002b6002d6002e6002f60030600316003260033600346003560037600386003b6003e6003f6003e6003b6003860036600
011000003c65500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
010f00003c6213c6003c0003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010b00003c62600005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400002447118570185701857018570185701857018570185601855018540185301852018515001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
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
01180000090500c0501005014050180501c0502005024050280501c0302003024030280301c0202002024020090500c0501005014050180501c0502005024050280501c0302003024030280301c0202002024020
0118000009000090000c0000c000090300c0301003014030090200c0201002014020180201c0202002024020280201c0102001024010090300c0301003014030090200c0201002014020180201c0202002024020
01180000070500c0501005013050180501c0501f05024050280501c0301f03024030280301c0201f02024020070500c0501005013050180501c0501f05024050280501c0301f03024030280301c0201f02024020
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
01180000280101c0102001024010070300c0301003013030070200c0201002013020180201c0201f02024020280201c0101f01024010070300c0301003013030070200c0201002013020180201c0201f02024020
0118000005050090500c0501005015050180501c0502105024050180301c0302103024030180201c0202102005050090500c0501005015050180501c0502105024050180301c0302103024030180201c02021020
01180000280101c0101f0102401005030090300c0301003005020090200c0201002015020180201c0202102024020180101c0102101005030090300c0301003005020090200c0201002015020180201c02021020
0118000004050080500b0501005014050170501c0502005023050170301c0302003023030170201c0202002004050080500b0501005014050170501c0502005023050170301c0302003023030170201c02020020
0118000024010180101c0102101004030080300b0301003004020080200b0201002014020170201c0202002023020170101c0102001004030080300b0301003004020080200b0201002014020170201c02020020
011800002180021800218002180021800218002180021800008000080000800008000080000800008000080000800008000080000800008000080000800008000080000800218002180021830238302483026830
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
011800002883028830288302883028830288302883028830288000080528800268002480026800248002683024830248302483024830248302483024830248301c80000805218002180023800008000080023830
011800002183021830218302183021830218002180021800008000080000800008000080000800008000080000800008000080000800008000080000800008000080000800218002180021830238302483026830
011000002083020830208302083020830208300080000800008000080000800008000080000800008000080000800008000080000800008000080000800008000080000800008000080000800008000080000800
011800000000000000148501485500000000001485014855000000000015850158550000000000158501585500000000001785017855000000000017850178550000000000188501885518000180001885018855
011800000000000000138501385500000000001385013855000000000015850158550000000000158501585500000000001785017855000000000017850178550000000000188501885518000180001885018855
011800002885028850288502885028850288500000000000000000000000000000002680028800268002485623850238502385023850238502385000000000000000000000218502185023850238502385524850
011800001c8501c8501c8501c8501c8501c8500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002185021855
011000082885028855218602486026870248702386021860288002880021800248002680024800238002180000000000000000000000000000000000000000000000000000000000000000000000000000000000
012000000997009970099700997009970099700997009970089700897008970089700897008970089700897007970079700797007970079700797007970079700697006970069700697006970069750797508975
01100010100733cb0030b303cc4025a4025a4030a00100003cc1030a001007330b0025a40100731000030b00100003cb0030b0030b00100003cb0030b0030b0030a0030a0030b0030b003cc003cc0030b0030b00
01080020100733cc0039c153cc0039c253cc0039c453cc0025a4025a4039c153cc0039c251000039c453cc0039c252dc003bc452dc001007325a0039c450000025a4025a40100731000039c453bc2539c4500000
011000002dd702dd602dd5521d002dd7028d702fd7030d702dd3028d302fd3030d302dd1028d102fd1030d102dd1028d102cd702dd702fd702dd002dd702cd702fd102dd002dd102cd102fd102dd002dd102cd10
011000002bd702bd602bd5500d002bd7026d702dd702fd702bd3026d302dd302fd302bd1026d102dd102fd102bd1026d102ad702bd702dd702dd002bd702ad702dd102dd002bd102ad1028d7028d7028d7028d75
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
011000002dd702dd602dd5521d002dd7028d702fd7030d702dd3028d302fd3030d302dd1028d102fd1030d102dd1028d102fd7030d7032d702dd0030d702fd7032d102dd0030d102fd1032d102dd0030d102fd10
011000002dd702dd602dd5521d002dd7028d702fd7030d702dd3028d302fd3030d302dd1028d102fd1030d102dd1028d1030d7032d7034d702dd0032d7030d7034d102dd0032d1030d1034d102dd0032d1030d10
0120000021170211702117021175211701c1722317024170241702417024160241602415224155241702617028171281722617024170241702417024160241602415024150241402414024132241352317224176
0120000021170211702117021175211701c1722317024170241702417024160241602415224155241702617027171271722617024170241702417024162261662317023170231702317023160231602315223155
012000002847021800284302380028410264002640024476234700840023430084002341021470244702647007400214202442026420074002141024410264100640006400064000640006400064000740008400
012800000987015860178601887009870158601786018870098701586017860188700987015860178601887008870158601786018870088701586017860188700887015860178601887008870158601786018870
0128000021130211302113021135211301c1322313024130241302413024120241202411224115241302613028131281322613024130241302413024130241202412024120241102411024112241152313224136
012800000787015860178601887007870158601786018870078701586017860188700787015860178601887006870158601786018870068701586017860188700687015860178601887006870158601786018870
012800000587015860178601887005870158601786018870058701586017860188700587015860178601887003870158601786018870038701586017860188700387015860178601887003870158601786018870
0128000021130211302113021135211301c1322313024130241302413024120241202411224115241302613027131271322613024130241302413024120241202412024110241102411026130261322412224126
012800000487015860178601887004870158601786018870048701586017860188700487015860178601887004870158601786018870048701586017860188700487015860178601887004870158601786018870
012800002313023130231302313023130231202312023120231102311023110231102311223115241322613228130281302813028130281202812028110281121c1301c1301c1301c1301c1201c1201c1101c110
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
010b0000293502d700293453037030360303552b00028000243000030013300243002430000300003002430024300003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
01100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
__music__
00 10115644
00 12175244
00 18194c44
00 1a1b1c44
00 10111e44
00 12171f44
00 18191e44
00 1a1b2044
00 10112144
00 12172244
00 18192144
00 1a1b2144
01 10112344
00 12172444
00 18192344
02 1a1b2444
00 25262744
00 25262844
01 29252844
00 2a252844
00 2d252844
02 2e252844
01 2f252844
00 30252844
00 2f312844
02 30312844
01 32337044
00 34336744
00 35366844
02 37384344
01 3e7e4344
02 3f7e4344
00 7d4a4344
00 7d7e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44

