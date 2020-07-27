pico-8 cartridge // http://www.pico-8.com
version 27
__lua__

--TODO
--camera transition
--list credits

cheatmode=true

--globals
levels_unlocked = 1

uidata = {
	border_1=5,
	panel_pos=128,
	hide_icons=true,
	button_pos=8,
	uistate='title',
	flashtimer=0,
	menux=0,
	menubounce=0,
	playx=0,
	seltrail=1,
	tickety=20,
	tickethide=0
}
menuitems = {
	menu={
		items={'play', 'options', 'credits'},
		sprites={0, 54, 55},
		actions={
			function() uidata.uistate='ticket' uianim = cocreate(playui_in) end,
			function() uidata.uistate='options' uianim = cocreate(menuui_in) end,
			function() transition_action=function() uidata.uistate='credits' end tstate=0 tcol=0 end
		},
		prev='title',
		level=0
	},
	options={
		items={'timer mode', 'screenshake', 'input display', 'delete save'},
		data={
			function() return timermodes[setting[1]+1] end,
			function() return setting[2]>0 and 'off' or 'on' end,
			function() return setting[3]>0 and 'on' or 'off' end,
			function() return '' end
		},
		sprites={0, 0, 0, 0, 0},
		actions={
			function() setting[1]=(setting[1]+1)%4 poke(0x5e43, (peek(0x5e43)&0b1100)+setting[1]) end,
			function() setting[2]=(setting[2]>0 and 0 or 1) poke(0x5e43, (peek(0x5e43)&0b1011)+(setting[2]<<2)) end,
			function() setting[3]=(setting[3]>0 and 0 or 1) poke(0x5e43, (peek(0x5e43)&0b0111)+(setting[3]<<3)) end,
			function() memset(0x5e00, 0, 0xff) sel_level=1 load_gamedata()end
		},
		prev='menu',
		level=1
	}
}

menu2={
	items={'play', 'pico-8', 'options', 'credits'},
	sprites={0, 53, 54, 55},
	actions={
		function() uidata.uistate='ticket' uianim = cocreate(playui_in) end,
		function() transition_action=function() load('celeste') end tstate=0 tcol=0 end,
		function() uidata.uistate='options' uianim = cocreate(menuui_in) end,
		function() transition_action=function() uidata.uistate='credits' end tstate=0 tcol=0 end
	},
	prev='title',
	level=0
}
menu1={
	items={'play', 'options', 'credits'},
	sprites={0, 54, 55},
	actions={
		function() uidata.uistate='ticket' uianim = cocreate(playui_in) end,
		function() uidata.uistate='options' uianim = cocreate(menuui_in) end,
		function() transition_action=function() uidata.uistate='credits' end tstate=0 tcol=0 end
	},
	prev='title',
	level=0
}

timermodes={'chapter', 'file', 'room', 'frames'}

--uistates : title, menu, ticket, map, options

particles = {}
for i=0,12 do
	add(particles,{
		x=rnd(128),
		y=rnd(128),
		s=0+flr(rnd(5)/4),
		spd=0.20+rnd(5),
		off=rnd(1),
		c=6+flr(0.5+rnd(1))
	})
end
for i=0,12 do
	add(particles2,{
		x=rnd(128),
		y=rnd(128),
		s=0+flr(rnd(5)/4),
		spd=0.20+rnd(5),
		off=rnd(1),
		c=6+flr(0.5+rnd(1))
	})
end

function _init()
	cartdata("collab_newleste_save")
	load_gamedata()

 	sel_level = 1
 	sel_menu = 1
 	level_selected = false

 	idlecamtimer=0
	cam_x = cam_positions[1][1][1]
	cam_y = cam_positions[1][1][2]
	cam_z = cam_positions[1][1][3]

	cam_ax = cam_positions[1][1][4]
	cam_ay = cam_positions[1][1][5]
	cam_az = cam_positions[1][1][6]

	init_3d()

	mountain=load_object(read_vector_string(model_v), read_face_string(model_f),0,0,0,0,0,0,false,k_colorize_static,13)
	prologue=load_object(read_vector_string(prologue_v), read_face_string(prologue_f),0,0,0,0,0,0,false,k_colorize_static,4)
	city=load_object(read_vector_string(city_v), read_face_string(city_f),0,0,0,0,0,0,false,k_colorize_static,1)
	castle=load_object(read_vector_string(castle_v), read_face_string(castle_f),0,0,0,0,0,0,false,k_colorize_static,5)
	heart=load_object(read_vector_string(heart_v), read_face_string(heart_f),0,0,0,0,0,0,false,k_colorize_static,8)
	waterfall=load_object(read_vector_string(waterfall_v), read_face_string(waterfall_f),0,0,0,0,0,0,false,k_colorize_static,12)
	temple=load_object(read_vector_string(temple_v), read_face_string(temple_f),0,0,0,0,0,0,false,k_colorize_static,1)
	lift=load_object(read_vector_string(lift_v), read_face_string(lift_f),0,0,0,0,0,0,false,k_colorize_static,13)
	hotel=load_object(read_vector_string(hotel_v), read_face_string(hotel_f),0,0,0,0,0,0,false,k_colorize_static,14)
	flag=load_object(read_vector_string(flag_v), read_face_string(flag_f),0,0,0,0,0,0,false,k_colorize_static,14)
end

function load_gamedata()

	-- debug flags
	if cheatmode then poke(0x5e03, 15) poke(0x5e47, 1) end

	-- user progress

	--debug force savedata
	-- 0xffff.ffff = all bits to 1 (poke4 only; use -1 for normal poke)
	-- 0x7fff.0000 = max int value
	-- 0x7fff.ffff = max floating point value
		--[[poke4(0x5e00,0xffff.ffff)
		poke(0x5e03,15)

		
		poke4(0x5e04,0xffff.ffff)
		poke4(0x5e08,0xffff.ffff)
		poke4(0x5e0c,0xffff.ffff)
		poke4(0x5e10,0xffff.ffff)
		poke4(0x5e14,0xffff.ffff)
		poke4(0x5e18,0xffff.ffff)
		poke4(0x5e1c,0xffff.ffff)
		poke4(0x5e20,0xffff.ffff)
		poke2(0x5e24,0xffff.ffff)
  poke(0x5e26,-1)

		--deaths
		poke4(0x5e27,0x7fff.0000)
		poke4(0x5e2b,0x7fff.0000)
		poke4(0x5e2f,0x7fff.0000)
		poke4(0x5e33,0x7fff.0000)
		poke4(0x5e37,0x7fff.0000)
		poke4(0x5e3b,0x7fff.0000)
		poke4(0x5e3f,0x7fff.0000)
		poke4(0x5e43,0x7fff.0000)--]]

 -- savedata
 hearts={}
 for i=0,7 do
  add(hearts,@0x5e00&(1<<i))
 end
 add(hearts,0)
 
 goldens={}
 for i=0,7 do
  add(goldens,@0x5e01&(1<<i))
 end
 add(goldens,0)
 
 summit_gems={}
 for i=0,7 do
  add(summit_gems,@0x5e02&(1<<i))
 end
 
 -- achievements:
  -- 1up 
  -- classic clear
  -- beat the game (any%) / reach the summit
  -- clear all chapters
  -- full clear all chapters
  -- all red berries
  -- all hearts
  -- all golden berries


 achievements={}
 for i=0,7 do
  add(achievements,@0x5e26&(1<<i))
 end
 
 -- chapters
 -- keep track of progress for multi-cart chapters
 completed_cp=@0x5e03&0b1111
 levels_unlocked=completed_cp2menu()


 -- berries
 -- give every chapter 4 bytes, 32 possible berries
 -- chapter 7 gets 6 bytes, 48 possible berries
 berries={}
 for chapter=1,8 do
  local tab={}
  for byo=0,chapter==7 and 5 or 3 do
   for bit=0,7 do
    add(tab,@(0x5e04+(chapter-1)*4+byo+(chapter>7 and 2 or 0))&(1<<bit))
   end
  end 
  add(berries,tab)
 end

 deaths={}
 for i=0,7 do
  add(deaths,$(0x5e27+i*4))
 end

 setting = {
  @0x5e43&0b0011, -- timer mode (chapter, file, room, room (frames))
  @0x5e43&0b0100, -- screenshake
  @0x5e43&0b1000  -- input display
 }

 pico_unlocked=(@0x5e47>0)
 if pico_unlocked then menuitems.menu = menu2 else menuitems.menu = menu1 end


	-- variables
	cartnames = {
		"prologue",
		"forsaken_city",
		"old_site",
		"celestial_resort",
		"goden_ridge",
		"mirror_temple",
		"reflection",
		"summit",
		"epilogue",
		"core"
	}

end

function completed_cp2menu()
	if completed_cp <= 5 then
		return completed_cp+1
	elseif completed_cp <= 6 then
		return 6
	elseif completed_cp <=8 then
		return 7
	elseif completed_cp <= 11 then
		return 8
	elseif completed_cp == 12 then
		return 9
	else
		return 10
	end
end

function selected2chap(selected)
	if selected>1 and selected<9 then 
		return selected-1 
	elseif selected==10 then 
		return 8
	else
		return 9 
 	end
end

function _update()
	handle_ui()
	upd_icons()
	update_camera(sel_level)
	update_3d()
end

function handle_ui()
	uidata.flashtimer+=1
	uidata.menubounce=0
	if not freeze_input then
		if uidata.uistate == 'title' then
			if btnp(4) or btnp(5) then
				transition_action = function() uidata.uistate = 'menu' end
				tstate=0
				tcol=1
			end
		elseif uidata.uistate == 'credits' then
			if btnp(5) or btnp(4) then
				transition_action=function() uidata.uistate='menu' end
				tstate=0
				tcol=0
			end
		elseif uidata.uistate == 'map' then
			if level_selected then
				if btnp(5) then
					level_selected = false
					uianim = cocreate(levelui_out)
				elseif btnp(4) then
					transition_action=function()
						if selected2chap(sel_level) ~= 9 then
							load(""..selected2chap(sel_level)..cartnames[sel_level])
						else
							load("0interludes")
						end
					end
					tstate=0
					tcol=0
				end
			else
				if btnp(0) and sel_level > 1 then
					sel_level-=1
				end
				if btnp(1) and sel_level < levels_unlocked then
					sel_level+=1
				end
				if btnp(4) then
					level_selected = true
					uianim = cocreate(levelui_in)
				elseif btnp(5) then
					uidata.uistate='menu'
					uidata.tickethide=0
					idlecamtimer=atan2(cam_x, cam_z)
					cam_ay=cam_ay-camround(cam_ay)
					uianim = cocreate(menuui_out)
					uidata.border_1 = 5
					uidata.hide_icons = true
				end
			end
		elseif uidata.uistate == 'ticket' then
			if btnp(4) then
				uidata.border_1 = 0
				uidata.hide_icons = false
				cam_ay=(((cam_ay+1)%2)-1)+camround(cam_positions[sel_level][1][5])
				uianim = cocreate(hide_ticket)
			elseif btnp(5) then
				uianim = cocreate(menuui_out)
			end
		else
			if btnp(3) and sel_menu < #menuitems[uidata.uistate].items then
				sel_menu+=1
				uidata.menubounce=1
			end
			if btnp(2) and sel_menu > 1 then
				sel_menu-=1
				uidata.menubounce=1
			end
			if btnp(4) then
				menuitems[uidata.uistate].actions[sel_menu]()
				uidata.menubounce=1
			elseif btnp(5) then
				if uidata.uistate == 'menu' then
					transition_action = function() uidata.uistate = 'title' end
					tstate=0
					tcol=1
				else
					uianim = cocreate(menuui_out)
				end
			end
		end
	end
	if uianim and costatus(uianim) ~= 'dead' then
		coresume(uianim)
	end
end

function levelui_in()
	freeze_input=true
	uidata.button_pos=8
	for i=0,5 do
		uidata.border_1 = i
		yield()
	end
	yield()
	local dist = leveldata[sel_level].width==0 and 64 or 80
	for i=0,dist,16 do
		uidata.panel_pos = 128-i
		yield()
	end
	yield()
	for i=8,0,-4 do
		uidata.button_pos=i
		yield()
	end
	freeze_input=false
end

function levelui_out()
	freeze_input=true
	local dist = leveldata[sel_level].width==0 and 64 or 80
	for i=dist,0,-16 do
		uidata.panel_pos = 128-i
		yield()
	end
	yield()
	for i=64,0,-16 do
		uidata.border_1 = i
		yield()
	end
	freeze_input=false
end

function menuui_in()
	freeze_input=true
	uidata.seltrail=sel_menu
	for i=0,128,16 do
		uidata.menux=i
		if i == 32 then sel_menu=1 end
		yield()
	end
	freeze_input=false
end

function playui_in()
	freeze_input=true
	uidata.seltrail=sel_menu
	uidata.tickety=20
	for i=0,64,16 do
		uidata.menux=i
		uidata.playx=i
		if i == 32 then sel_menu=1 end
		yield()
	end
	for i=64,-64,-16 do
		uidata.playx=i
		yield()
	end
	for i=0,7 do
  		if achievements[i+1]>0 then
  			for i=20,0,-5 do
				uidata.tickety=i
				yield()
			end
			freeze_input=false
			return
	  	end
 	end
 	freeze_input=false
end

function menuui_out()
	freeze_input=true
	uidata.playx=0
	for i=128,0,-16 do
		uidata.menux=i
		if i == 32 then sel_menu=uidata.seltrail end
		yield()
	end
	uidata.uistate='menu'
	freeze_input=false
end

function hide_ticket()
	freeze_input=true
	for i=0,128,32 do
		uidata.tickethide=i
		yield()
	end
	uidata.uistate='map'
	freeze_input=false
end

function _draw()
	cls()

	-- particles
	foreach(particles2, function(p)
		p.x += p.spd
		p.y += sin(p.off)
		p.off+= min(0.05,p.spd/32)
		rectfill(p.x,p.y,p.x+p.s,p.y+p.s,p.c)
		if p.x>128+4 then 
			p.x=-4
			p.y=rnd(128)
		end
	end)

	if uidata.uistate ~= 'title' then
		fillp(0b1000000000100000)
		rectfill(0, 0, 127, 32, 1)
		fillp(0b0101000010100000)
		rectfill(0, 32, 127, 64, 1)
		fillp(0b1010010110100101)
		rectfill(0, 64, 127, 96, 1)
		fillp(0b0111111111011111)
		rectfill(0, 97, 127, 127, 1)

		fillp()
		

		
		draw_3d()
		

	end



	if uidata.uistate == 'title' then
		draw_title()
	end

	-- particles
	foreach(particles, function(p)
		p.x -= p.spd
		p.y += sin(p.off)
		p.off+= min(0.05,p.spd/32)
		rectfill(p.x,p.y,p.x+p.s,p.y+p.s,p.c)
		if p.x<-1 then 
			p.x=128+4
			p.y=rnd(128)
		end
	end)

	if uidata.uistate == 'menu' or uidata.uistate == 'ticket' or uidata.uistate == 'options' then
		draw_menu()
	end

	if uidata.uistate == 'credits' then
		draw_credits()
	end

	draw_mapui()

	if uidata.uistate ~= 'title' then
		print("select🅾️ back❎", 67, 120, 1)
	end

	draw_transition()

	--[[print(stat(1), 120, 0, 8)

	print(cam_x, 0, 0, 8)
	print(cam_y, 0, 8, 8)
	print(cam_z, 0, 16, 8)
	print(cam_ax, 0, 34, 8)
	print(cam_ay, 0, 42, 8)
	print(cam_az, 0, 50, 8)--]]
end

function draw_transition()
	if tstate>=0 then
		freeze_input=true
		local t20=tpos+20
		if tstate==0 then
			po1tri(tpos,0,t20,0,tpos,127)
			if(tpos>0)rectfill(0,0,tpos,127,tcol)
			if(tpos>148)tstate=1 tpos=-20 transition_action()
		else
			po1tri(t20,0,t20,127,tpos,127)
			if(tpos<108)rectfill(t20,0,127,127,tcol)
			if(tpos>148)tstate=-1tpos=-20 freeze_input=false
		end
		tpos+=14
	end
end

function draw_title()
	rectfill(0, 0, 128, 128, 0)
	spr(71, 32, 22, 8, 8)

	print("z+x",58,80,5)
	--print("original by",43,88,5)
	print("matt thorson",42,96,5)
	print("noel berry",46,102,5)

	--print('🅾️', 118, 120, 7)
end

function draw_credits()
	rectfill(0, 0, 128, 128, 1)
	print(':yadelie:',50, 60, 7)
end

function draw_menu()
	for k,m in pairs(menuitems) do
		if not(k=='options' and uidata.uistate~='options') then
			for i=1,#m.items do
				local seloff = i==sel_menu and 4 or 0
				local selcol = i==sel_menu and (uidata.flashtimer%6<4 and 10 or 11) or 7
				local mbounce = i==sel_menu and uidata.menubounce or 0
				if m.items[i] == 'play' then
					spr(80, 11-uidata.menux+uidata.playx, 12+i*10+mbounce, 2, 2)
					print(m.items[i], 11-uidata.menux+uidata.playx, 30+i*10+mbounce, selcol)
				else
					spr(m.sprites[i], 9+seloff+128*m.level-uidata.menux-mbounce, 30+i*10+mbounce)

					local text = m.items[i]
					if m.data ~= null then
						text = text..' '..m.data[i]()
					end
					print(text, 15+seloff+128*m.level-uidata.menux-mbounce, 30+i*10+mbounce, selcol)
				end
			end
		end
	end

	if uidata.uistate == 'ticket' then
		local tx = uidata.playx-uidata.menux+128-uidata.tickethide

		rectfill(46+tx, 60-uidata.tickety, 82+tx, 82-uidata.tickety, 7)
		rect(46+tx, 60-uidata.tickety, 82+tx, 82-uidata.tickety, 0)
		for i=0,7 do
			if achievements[i+1]>0 then
				spr(56+i, 48+tx+((i%4)*8), 64+flr(i/4)*9-uidata.tickety)
			end
		end

		rectfill(38+tx, 34, 90+tx, 62, 7)
		rect(32+tx, 34, 96+tx, 62, 0)
		palt(0, false)
		palt(11, true)
		spr(112, 22+tx, 34, 2, 4)
		spr(112, 91+tx, 34, 2, 4, true)
		spr(82, 20+tx, 32, 4, 4)

		spr(50, 76+tx, 51)
		local all_deaths = 0
		for i=2,8 do
			all_deaths += deaths[selected2chap(i)]
		end
		print(all_deaths, 86+tx, 53, 13)
		palt()


		for i=1,levels_unlocked do
			pset(48+tx+i*5, 42, 13)
			if hearts[selected2chap(i)]>0 then
				spr(12, 46+tx+i*5, 41)
			end
		end

		spr(49, 49+tx, 51)
		local all_berries = 0
		foreach(berries,function(m)
			foreach(m,function(v)
				if v>0 then
					all_berries+=1
				end
			end)
		end)
		print(all_berries, 59+tx, 53, 13)
	end
end

function draw_mapui()
	if uidata.panel_pos ~= 128 then

		--[[if uidata.border_1 ~=0 then
			line(0, 64, 0, 64+uidata.border_1, 7)
			line(0, 63, 0, 63-uidata.border_1, 7)
			line(127, 64, 127, 64+uidata.border_1, 7)
			line(127, 63, 127, 63-uidata.border_1, 7)
		end
		if uidata.border_2 ~=0 then
			line(0, 0, 0+uidata.border_2, 0, 7)
			line(127, 0, 127-uidata.border_2, 0, 7)
			line(0, 127, 0+uidata.border_2, 127, 7)
			line(127, 127, 127-uidata.border_2, 127, 7)
		end--]]

		local statoff = leveldata[sel_level].hasstats and 0 or 20

		rectfill(uidata.panel_pos, 10, uidata.panel_pos+70+leveldata[sel_level].width, 60-statoff, 7)
		rectfill(uidata.panel_pos, 51-statoff, uidata.panel_pos+70+leveldata[sel_level].width, 60-statoff, 6)
		rect(uidata.panel_pos, 10, uidata.panel_pos+70+leveldata[sel_level].width, 60-statoff, 0)

		--banner
		rectfill(uidata.panel_pos, 15, uidata.panel_pos+80, 25, 0)
		shade_trifill(uidata.panel_pos-5, 15, uidata.panel_pos, 15, uidata.panel_pos, 20, 0, 0)
		shade_trifill(uidata.panel_pos, 20, uidata.panel_pos, 25, uidata.panel_pos-5, 25, 0, 0)
		rectfill(uidata.panel_pos+1, 16, uidata.panel_pos+80, 24, leveldata[sel_level].color)
		shade_trifill(uidata.panel_pos-3, 16, uidata.panel_pos+2, 16, uidata.panel_pos+2, 21, leveldata[sel_level].color, leveldata[sel_level].color)
		shade_trifill(uidata.panel_pos+2, 19, uidata.panel_pos+2, 24, uidata.panel_pos-3, 24, leveldata[sel_level].color, leveldata[sel_level].color)
		local offset = leveldata[sel_level].width==0 and 0 or 16
		print(leveldata[sel_level].title, uidata.panel_pos+52+offset-(#leveldata[sel_level].title*4), 18, leveldata[sel_level].textcol)

		--playbutton
		rectfill(uidata.panel_pos+27+leveldata[sel_level].width, 58+uidata.button_pos-statoff, uidata.panel_pos+37+leveldata[sel_level].width, 68+uidata.button_pos-statoff, 0)
		shade_trifill(uidata.panel_pos+27+leveldata[sel_level].width, 68+uidata.button_pos-statoff,
		 uidata.panel_pos+27+leveldata[sel_level].width, 73+uidata.button_pos-statoff,
		 uidata.panel_pos+32+leveldata[sel_level].width, 68+uidata.button_pos-statoff, 0, 0)
		shade_trifill(uidata.panel_pos+32+leveldata[sel_level].width, 68+uidata.button_pos-statoff,
		 uidata.panel_pos+37+leveldata[sel_level].width, 73+uidata.button_pos-statoff,
		 uidata.panel_pos+37+leveldata[sel_level].width, 68+uidata.button_pos-statoff, 0, 0)
		shade_trifill(uidata.panel_pos+27+leveldata[sel_level].width, 58+uidata.button_pos-statoff,
		 uidata.panel_pos+32+leveldata[sel_level].width, 53+uidata.button_pos-statoff,
		 uidata.panel_pos+37+leveldata[sel_level].width, 58+uidata.button_pos-statoff, 0, 0)
		rectfill(uidata.panel_pos+28+leveldata[sel_level].width, 59+uidata.button_pos-statoff, uidata.panel_pos+36+leveldata[sel_level].width, 67+uidata.button_pos-statoff, 13)
		shade_trifill(uidata.panel_pos+28+leveldata[sel_level].width, 68+uidata.button_pos-statoff,
		 uidata.panel_pos+28+leveldata[sel_level].width, 71+uidata.button_pos-statoff,
		 uidata.panel_pos+31+leveldata[sel_level].width, 68+uidata.button_pos-statoff, 13, 13)
		shade_trifill(uidata.panel_pos+33+leveldata[sel_level].width, 68+uidata.button_pos-statoff,
		 uidata.panel_pos+36+leveldata[sel_level].width, 71+uidata.button_pos-statoff,
		 uidata.panel_pos+36+leveldata[sel_level].width, 68+uidata.button_pos-statoff, 13, 13)
		shade_trifill(uidata.panel_pos+28+leveldata[sel_level].width, 58+uidata.button_pos-statoff,
		 uidata.panel_pos+32+leveldata[sel_level].width, 54+uidata.button_pos-statoff,
		 uidata.panel_pos+36+leveldata[sel_level].width, 58+uidata.button_pos-statoff, 13, 13)
		spr(48, uidata.panel_pos+28+leveldata[sel_level].width, 58+uidata.button_pos-statoff)

		--stats
		if leveldata[sel_level].hasstats then
			local berryc = 0
			foreach(berries[selected2chap(sel_level)],function(v)
				if v>0 then
					berryc+=1
				end
			end)
			if goldens[selected2chap(sel_level)]>0 then berryc+=1 end
			print(berryc..'/'..leveldata[sel_level].max_berries, uidata.panel_pos+39+leveldata[sel_level].width, 30)
			print(deaths[selected2chap(sel_level)], uidata.panel_pos+39+leveldata[sel_level].width, 41)
			if goldens[selected2chap(sel_level)]>0 then
				spr(63, uidata.panel_pos+30+leveldata[sel_level].width, 29)
			else
				spr(49, uidata.panel_pos+30+leveldata[sel_level].width, 29)
			end
			palt(0, false)
			spr(50, uidata.panel_pos+30+leveldata[sel_level].width, 39)
			palt(0, true)
			if hearts[selected2chap(sel_level)]>0 then
				spr(51, uidata.panel_pos+11+leveldata[sel_level].width, 30, 2, 2)
			end
		end
	end
	draw_icons()

end

iconpositions={
	{x=64,y=-8},
	{x=74,y=-8},
	{x=84,y=-8},
	{x=94,y=-8},
	{x=104,y=-8},
	{x=114,y=-8},
	{x=124,y=-8},
	{x=134,y=-8},
	{x=144,y=-8},
	{x=154,y=-8}
}

function upd_icons()
	for i=1,levels_unlocked do
		local selected = i==sel_level and 5 or 0

		if level_selected or uidata.hide_icons then
			if i==sel_level and not uidata.hide_icons then
				iconpositions[i].x = lerp2(iconpositions[i].x, 118, 0.4)
				iconpositions[i].y = movetow(iconpositions[i].y, 16, 1)
			else
				local moveoff = uidata.border_1*2 > i-1 and 1 or 0
				iconpositions[i].y = movetow(iconpositions[i].y, -1*i-8, 2*moveoff)
			end
		else
			if i==sel_level then
				iconpositions[i].x = movetow(iconpositions[i].x, 60+10*i-10*sel_level, 8)
				iconpositions[i].y = lerp2(iconpositions[i].y, 3+selected, 0.3)
			else
				iconpositions[i].x = movetow(iconpositions[i].x, 60+10*i-10*sel_level, 3)
				iconpositions[i].y = movetow(iconpositions[i].y, 3+selected, 2)
			end
		end
	end
end

function draw_icons()
	local ref = sel_level==1 and 2 or 1
	rectfill(59, -1, 68, iconpositions[ref].y*2+12, 12)
	for i=1,levels_unlocked do
		spr(i, iconpositions[i].x, iconpositions[i].y, 1, 1.3)
	end
end

-->8
//3d library

-------------------------------------------------------------begin cut here-------------------------------------------------
------------------------------------------------------electric gryphon's 3d library-----------------------------------------
----------------------------------------------------------------------------------------------------------------------------

hex_string_data = "0123456789abcdef"
char_to_hex = {}
for i=1,#hex_string_data do
	char_to_hex[sub(hex_string_data,i,i)]=i-1
end

function read_byte(string)
	return char_to_hex[sub(string,1,1)]*16+char_to_hex[sub(string,2,2)]
end

function read_2byte_fixed(string)
	local a=read_byte(sub(string,1,2))
	local b=read_byte(sub(string,3,4))
	local val =a*256+b
	return val/256
end

cur_string=""
cur_string_index=1
function load_string(string)
	cur_string=string
	cur_string_index=1
end

function read_vector()
	v={}
	for i=1,3 do
		text=sub(cur_string,cur_string_index,cur_string_index+4)
		value=read_2byte_fixed(text)
		v[i]=value
		cur_string_index+=4
	end
	return v
end

function read_face()
	f={}
	for i=1,3 do
		text=sub(cur_string,cur_string_index,cur_string_index+2)
		value=read_byte(text)
		f[i]=value
		cur_string_index+=2
	end
	return f
end		

function read_vector_string(string)
	vector_list={}
	load_string(string)
	while(cur_string_index<#string)do
		vector=read_vector()
		add(vector_list,vector)
	end
		return vector_list
end

function read_face_string(string)
	face_list={}
	load_string(string)
	while(cur_string_index<#string)do
		face=read_face()
		add(face_list,face)
	end
		return face_list
end

k_color1=4
k_color2=5

k_screen_scale=100
k_x_center=64
k_y_center=64



z_clip=-0.1
z_max=-50

k_min_x=0
k_max_x=128
k_min_y=0
k_max_y=128



--these are used for the 2 scanline color shading scheme
double_color_list=	{{0,0,0,0,0,0,0,0,0,0},
					 {0,0,0,0,0,0,0,0,0,0},

					{0,0,1,1,1,1,13,13,12,12},
					{0,0,0,1,1,1,1,13,13,12},
					
					{2,2,2,2,8,8,14,14,14,15},
					{0,1,1,2,2,8,8,8,14,14},
					
					{1,1,1,1,3,3,11,11,10,10},
					{0,1,1,1,1,3,3,11,11,10},
					
					{1,1,2,2,4,4,9,9,10,10},
					{0,1,1,2,2,4,4,9,9,10},
					
					{0,0,1,1,5,5,13,13,6,6},
					{0,0,0,1,1,5,5,13,13,6},
					
					{1,1,5,5,6,6,6,6,7,7},
					{0,1,1,5,5,6,6,6,6,7},
					
					{5,5,6,6,7,7,7,7,7,7},
					{0,5,5,6,6,7,7,7,7,7},
					
					{2,2,2,2,8,8,14,14,15,15},
					{0,2,2,2,2,8,8,14,14,15},
					
					{2,2,4,4,9,9,15,15,7,7},
					{0,2,2,4,4,9,9,15,15,7},
					
					{4,4,9,9,10,10,7,7,7,7},
					{0,4,4,9,9,10,10,7,7,7},
					
					{1,1,3,3,11,11,10,10,7,7},
					{0,1,1,3,3,11,11,10,10,7},
					
					{13,13,13,12,12,12,6,6,7,7},
					{0,5,13,13,12,12,12,6,6,7},
					
					{1,1,5,5,13,13,6,6,7,7},
					{0,1,1,5,5,13,13,6,6,7},
					
					{2,2,2,2,14,14,15,15,7,7},
					{0,2,2,2,2,14,14,15,15,7},
					
					{4,4,9,9,15,15,7,7,7,7},
					{0,4,4,9,9,15,15,7,7,7}
					}


k_ambient=.7
function color_faces(object,base)
	--local p1x,p1y,p1z,p2x,p2y,p2z,p3x,p3y,p3z
	
		
		for i=1,#object.faces do
			local face=object.faces[i]
		--for face in all(object.faces)do
			local p1x=object.t_vertices[face[1]][1]
			local p1y=object.t_vertices[face[1]][2]
			local p1z=object.t_vertices[face[1]][3]
			local p2x=object.t_vertices[face[2]][1]
			local p2y=object.t_vertices[face[2]][2]
			local p2z=object.t_vertices[face[2]][3]
			local p3x=object.t_vertices[face[3]][1]
			local p3y=object.t_vertices[face[3]][2]
			local p3z=object.t_vertices[face[3]][3]		
		
		
	
			local nx,ny,nz = vector_cross_3d(p1x,p1y,p1z,
								p2x,p2y,p2z,
								p3x,p3y,p3z)

	
		nx,ny,nz = normalize(nx,ny,nz)
		local b = vector_dot_3d(nx,ny,nz,light1_x,light1_y,light1_z)
		--see how closely the light vector and the face normal line up and shade appropriately
		
		-- print(nx.." "..ny.." "..nz,10,i*8+8,8) 
		-- flip()
		if object.color_mode==k_multi_color_dynamic then
			face[4],face[5]=color_shade(object.base_faces[i][4], mid( b,0,1)*(1-k_ambient)+k_ambient )
		else
			face[4],face[5]=color_shade(base, mid( b,0,1)*(1-k_ambient)+k_ambient )
		end
	end
	
end

					
function color_shade(color,brightness)
	--return double_color_list[ (color+1)*2-1 ][flr(brightness*10)] , double_color_list[ (color+1)*2 ][flr(brightness*10)] 
	local b= band(brightness*10,0xffff)
	local c= (color+1)*2
	return double_color_list[ c-1 ][b] , double_color_list[ c ][b] 
end			
	


light1_x=0
light1_y=1
light1_z=0

--t_light gets written to
t_light_x=0
t_light_y=0
t_light_z=0

function init_light()
	light1_x,light1_y,light1_z=normalize(light1_x,light1_y,light1_z)
end

function update_light()
	t_light_x,t_light_y,t_light_z = rotate_cam_point(light1_x,light1_y,light1_z)
end

function normalize(x,y,z)
	local x1=shl(x,2)
	local y1=shl(y,2)
	local z1=shl(z,2)
	
	local inv_dist=1/sqrt(x1*x1+y1*y1+z1*z1)
	
	return x1*inv_dist,y1*inv_dist,z1*inv_dist
	
end

function	vector_dot_3d(ax,ay,az,bx,by,bz)
	return ax*bx+ay*by+az*bz
end
	
function	vector_cross_3d(px,py,pz,ax,ay,az,bx,by,bz)

	 ax-=px
	 ay-=py
	 az-=pz
	 bx-=px
	 by-=py
	 bz-=pz
	
	
	local dx=ay*bz-az*by
	local dy=az*bx-ax*bz
	local dz=ax*by-ay*bx
	return dx,dy,dz
end



k_colorize_static = 1
k_colorize_dynamic = 2
k_multi_color_static = 3
k_multi_color_dynamic = 4
k_preset_color = 5

--function load object:
--object_vertices: vertex list for object (see above)
--object_faces: face list for object (see above)
--x,y,z: translated center for the the object
--ax,ay,az: rotation of object about these axis
--obstacle: boolean will the player collide with this?
--color mode:
--k_colorize_static = 1 : shade the model at init with one shaded color
--k_colorize_dynamic = 2 : color the model dynamically with one shade color -- slow
--k_multi_color_static = 3 : shade the model based on colors defined in face list
--k_multi_color_dynamic = 4 : shade the model dynamically based on colors define din face list -- slow
--k_preset_color = 5 : use the colors defined in face list only -- no lighting effects

function load_object(object_vertices,object_faces,x,y,z,ax,ay,az,obstacle,color_mode,color)
	object=new_object()
	
	object.vertices=object_vertices
	
	
	--make local deep copy of faces 
	--if we don't car about on-demand shading we can share faces
	--but it means that objects will look wrong when rotated
	
	if color_mode==k_preset_color then
		object.faces=object_faces
	else
		object.base_faces=object_faces
		object.faces={}
		for i=1,#object_faces do
			object.faces[i]={}
			for j=1,#object_faces[i] do
				object.faces[i][j]=object_faces[i][j]
			end
		end
	end

	
	object.radius=0
	
	--make local deep copy of translated vertices
	--we share the initial vertices
	for i=1,#object_vertices do
		object.t_vertices[i]={}
			for j=1,3 do
				object.t_vertices[i][j]=object.vertices[i][j]
			end
	end

	object.ax=ax or 0
	object.ay=ay or 0
	object.az=az or 0
	
	transform_object(object)
	
	set_radius(object)
	set_bounding_box(object)
	
	object.x=x or 0
	object.y=y or 0
	object.z=z or 0

	object.sortx = (object.min_x+object.max_x)/2
	object.sorty = (object.min_y+object.max_y)/2
	object.sortz = (object.min_z+object.max_z)/2

	object.color = color or 8
	object.color_mode= color_mode or k_colorize_static
			
	if color_mode==k_colorize_static or color_mode==k_colorize_dynamic or color_mode==k_multi_color_static then
		color_faces(object,color)
	end

	
	
	return object
end

function set_radius(object)
	for vertex in all(object.vertices) do
		object.radius=max(object.radius,vertex[1]*vertex[1]+vertex[2]*vertex[2]+vertex[3]*vertex[3])
	end
	object.radius=sqrt(object.radius)
end

function set_bounding_box(object)
	for vertex in all(object.t_vertices) do
	
		object.min_x=min(vertex[1],object.min_x)
		object.min_y=min(vertex[2],object.min_y)
		object.min_z=min(vertex[3],object.min_z)
		object.max_x=max(vertex[1],object.max_x)
		object.max_y=max(vertex[2],object.max_y)
		object.max_z=max(vertex[3],object.max_z)
	end

end

function new_object()
	object={}
	object.vertices={}
	object.faces={}
	
	object.t_vertices={}

	object.x=0
	object.y=0
	object.z=0
	
	object.tx=0
	object.ty=0
	object.tz=0
	
	object.ax=0
	object.ay=0
	object.az=0
	
	object.sx=0
	object.sy=0
	object.radius=10
	object.sradius=10
	object.visible=true
	
	--object.render=true
	object.background=false
	
	object.min_x=100
	object.min_y=100
	object.min_z=100
	
	object.max_x=-100
	object.max_y=-100
	object.max_z=-100
	
	object.vx=0
	object.vy=0
	object.vz=0

	add(object_list,object)
	return object

end

function delete_object(object)
	del(object_list,object)
end


function new_triangle(p1x,p1y,p2x,p2y,p3x,p3y,z,c1,c2)

	add(triangle_list,{p1x=p1x,
	                   p1y=p1y,
	                   p2x=p2x,
	                   p2y=p2y,
	                   p3x=p3x,
	                   p3y=p3y,
	                   tz=z,
	                   c1=c1,
	                   c2=c2})
	
	
	
	
end

function draw_triangle_list()
	--for t in all(triangle_list) do
	for i=1,#triangle_list do
		local t=triangle_list[i]
		shade_trifill( t.p1x,t.p1y,t.p2x,t.p2y,t.p3x,t.p3y, t.c1,t.c2 )
	end
end

function update_visible(object)
		object.visible=false

		local px,py,pz = object.sortx-cam_x,object.sorty-cam_y,object.sortz-cam_z
		object.tx, object.ty, object.tz =rotate_cam_point(px,py,pz)

		object.sx,object.sy = project_point(object.tx,object.ty,object.tz)
		object.sradius=project_radius(object.radius,object.tz)
		object.visible= is_visible(object)
end

function cam_transform_object(object)
	if object.visible then

		for i=1, #object.vertices do
			local vertex=object.t_vertices[i]

			vertex[1]+=object.x - cam_x
			vertex[2]+=object.y - cam_y
			vertex[3]+=object.z - cam_z
			
			vertex[1],vertex[2],vertex[3]=rotate_cam_point(vertex[1],vertex[2],vertex[3])
		
		end
	

	end
end

function transform_object(object)
	

		
	
	if object.visible then
		generate_matrix_transform(object.ax,object.ay,object.az)
		for i=1, #object.vertices do
			local t_vertex=object.t_vertices[i]
			local vertex=object.vertices[i]
			
			t_vertex[1],t_vertex[2],t_vertex[3]=rotate_point(vertex[1],vertex[2],vertex[3])
		
		end
	

	end
end

function generate_matrix_transform(xa,ya,za)

	
	local sx=sin(xa)
	local sy=sin(ya)
	local sz=sin(za)
	local cx=cos(xa)
	local cy=cos(ya)
	local cz=cos(za)
	
	mat00=cz*cy
	mat10=-sz
	mat20=cz*sy
	mat01=cx*sz*cy+sx*sy
	mat11=cx*cz
	mat21=cx*sz*sy-sx*cy
	mat02=sx*sz*cy-cx*sy
	mat12=sx*cz
	mat22=sx*sz*sy+cx*cy

end

function generate_cam_matrix_transform(xa,ya,za)

	
	local sx=sin(xa)
	local sy=sin(ya)
	local sz=sin(za)
	local cx=cos(xa)
	local cy=cos(ya)
	local cz=cos(za)
	
	cam_mat00=cz*cy
	cam_mat10=-sz
	cam_mat20=cz*sy
	cam_mat01=cx*sz*cy+sx*sy
	cam_mat11=cx*cz
	cam_mat21=cx*sz*sy-sx*cy
	cam_mat02=sx*sz*cy-cx*sy
	cam_mat12=sx*cz
	cam_mat22=sx*sz*sy+cx*cy

end

function rotate_point(x,y,z)	
	return (x)*mat00+(y)*mat10+(z)*mat20,(x)*mat01+(y)*mat11+(z)*mat21,(x)*mat02+(y)*mat12+(z)*mat22
end

function rotate_cam_point(x,y,z)
	return (x)*cam_mat00+(y)*cam_mat10+(z)*cam_mat20,(x)*cam_mat01+(y)*cam_mat11+(z)*cam_mat21,(x)*cam_mat02+(y)*cam_mat12+(z)*cam_mat22
end

function is_visible(object)

	if object.tz+object.radius>z_max and object.tz-object.radius<z_clip and
	   object.sx+object.sradius>0 and object.sx-object.sradius<128 and
	   object.sy+object.sradius>0 and object.sy-object.sradius<128 
	   then return true else return false end
end

function render_object(object)

	--project all points in object to screen space
	--it's faster to go through the array linearly than to use a for all()
	for i=1, #object.t_vertices do
		local vertex=object.t_vertices[i]
		vertex[4],vertex[5] = vertex[1]*k_screen_scale/vertex[3]+k_x_center,vertex[2]*k_screen_scale/vertex[3]+k_x_center
	end

	for i=1,#object.faces do
	--for face in all(object.faces) do
		local face=object.faces[i]
	
		local p1=object.t_vertices[face[1]]
		local p2=object.t_vertices[face[2]]
		local p3=object.t_vertices[face[3]]
		
		local p1x,p1y,p1z=p1[1],p1[2],p1[3]
		local p2x,p2y,p2z=p2[1],p2[2],p2[3]
		local p3x,p3y,p3z=p3[1],p3[2],p3[3]

		
		local c1=-p1x*p1x-p1y*p1y-p1z*p1z
		local c2=-p2x*p2x-p2y*p2y-p2z*p2z
		local c3=-p3x*p3x-p3y*p3y-p3z*p3z
		local z_paint=.01*(c1+c2+c3)/3
		
		
		
		
		if object.background==true then z_paint-=1000 end
		face[6]=z_paint
		

		if p1z>z_max or p2z>z_max or p3z>z_max then
			if p1z< z_clip and p2z< z_clip and p3z< z_clip then
			--simple option -- no clipping required

					local s1x,s1y = p1[4],p1[5]
					local s2x,s2y = p2[4],p2[5]
					local s3x,s3y = p3[4],p3[5]
		

					if  max(s3x,max(s1x,s2x))>0 and min(s3x,min(s1x,s2x))<128  and
					  max(s3y,max(s1y,s2y))>0 and min(s3y,min(s1y,s2y))<128  then
						--only use backface culling on simple option without clipping
						--check if triangles are backwards by cross of two vectors
						if ( (s1x-s2x)*(s3y-s2y)-(s1y-s2y)*(s3x-s2x)) < 0 or 
							min (s3x, min(s2x, s2x))<0 or max(s3x, max(s1x, s2x))>128 or
							min (s3y, min(s2y, s2y))<0 or max(s3y, max(s1y, s2y))>128 then		

							if object.color_mode==k_colorize_dynamic then
								--nx,ny,nz = vector_cross_3d(p1x,p1y,p1z,p2x,p2y,p2z,p3x,p3y,p3z)
								--save a bit on dynamic rendering by moving this funciton inline
								p2x-=p1x p2y-=p1y p2z-=p1z	
								p3x-=p1x p3y-=p1y p3z-=p1z	
								local nx = p2y*p3z-p2z*p3y
								local ny = p2z*p3x-p2x*p3z
								local nz = p2x*p3y-p2y*p3x
								
								--nx,ny,nz = normalize(nx,ny,nz)
								--save a bit by moving this function inline
								nx=shl(nx,2) ny=shl(ny,2) nz=shl(nz,2)
								local inv_dist=1/sqrt(nx*nx+ny*ny+nz*nz)
								nx*=inv_dist ny*=inv_dist nz*=inv_dist						
															
								
								--b = vector_dot_3d(nx,ny,nz,t_light_x,t_light_y,t_light_z)
								--save a bit by moving this function inline
								face[4],face[5]=color_shade(object.color, mid( nx*t_light_x+ny*t_light_y+nz*t_light_z,0,1)*(1-k_ambient)+k_ambient )
							end
								
						
							--new_triangle(s1x,s1y,s2x,s2y,s3x,s3y,z_paint,face[k_color1],face[k_color2])
							--faster to move new triangle function inline
							add(triangle_list,{p1x=s1x,
												p1y=s1y,
												p2x=s2x,
												p2y=s2y,
												p3x=s3x,
												p3y=s3y,
												tz=z_paint,
												c1=face[k_color1],
												c2=face[k_color2]})
							

						end
					end
					
			--not optimizing clipping functions for now
			--these still have errors for large triangles
			elseif p1z< z_clip or p2z< z_clip or p3z< z_clip then
			
			--either going to have 3 or 4 points
				p1x,p1y,p1z,p2x,p2y,p2z,p3x,p3y,p3z = three_point_sort(p1x,p1y,p1z,p2x,p2y,p2z,p3x,p3y,p3z)
				if p1z<z_clip and p2z<z_clip then
				

				
					local n2x,n2y,n2z = z_clip_line(p2x,p2y,p2z,p3x,p3y,p3z,z_clip)
					local n3x,n3y,n3z = z_clip_line(p3x,p3y,p3z,p1x,p1y,p1z,z_clip)
					

					
					local s1x,s1y = project_point(p1x,p1y,p1z)
					local s2x,s2y = project_point(p2x,p2y,p2z)
					local s3x,s3y = project_point(n2x,n2y,n2z)
					local s4x,s4y = project_point(n3x,n3y,n3z)

					
					if  max(s4x,max(s1x,s2x))>0 and min(s4x,min(s1x,s2x))<128   then
						new_triangle(s1x,s1y,s2x,s2y,s4x,s4y,z_paint,face[k_color1],face[k_color2])
					end
					if  max(s4x,max(s3x,s2x))>0 and min(s4x,min(s3x,s2x))<128   then
						new_triangle(s2x,s2y,s4x,s4y,s3x,s3y,z_paint,face[k_color1],face[k_color2])
					end
				else

				
					local n1x,n1y,n1z = z_clip_line(p1x,p1y,p1z,p2x,p2y,p2z,z_clip)
					local n2x,n2y,n2z = z_clip_line(p1x,p1y,p1z,p3x,p3y,p3z,z_clip)
					

					
					local s1x,s1y = project_point(p1x,p1y,p1z)
					local s2x,s2y = project_point(n1x,n1y,n1z)
					local s3x,s3y = project_point(n2x,n2y,n2z)
					
					--solid_trifill(s1x,s1y,s2x,s2y,s3x,s3y,face[k_color1])
					if( max(s3x,max(s1x,s2x))>0 and min(s3x,min(s1x,s2x))<128)  then
						new_triangle(s1x,s1y,s2x,s2y,s3x,s3y,z_paint,face[k_color1],face[k_color2])
					end
				end
				
				--print("p1",p1x+64,p1z+64,14)
				--print("p2",p2x+64,p2z+64,14)
				--print("p3",p3x+64,p3z+64,14)
				
			
			
			end
		end
		
	end


end

function three_point_sort(p1x,p1y,p1z,p2x,p2y,p2z,p3x,p3y,p3z)
	if(p1z>p2z) p1z,p2z = p2z,p1z p1x,p2x = p2x,p1x p1y,p2y = p2y,p1y
	if(p1z>p3z) p1z,p3z = p3z,p1z p1x,p3x = p3x,p1x p1y,p3y = p3y,p1y
	if(p2z>p3z) p2z,p3z = p3z,p2z p2x,p3x = p3x,p2x p2y,p3y = p3y,p2y
	
	return p1x,p1y,p1z,p2x,p2y,p2z,p3x,p3y,p3z
end

function quicksort(t, start, endi)
   start, endi = start or 1, endi or #t
  --partition w.r.t. first element
  if(endi - start < 1) then return t end
  local pivot = start
  for i = start + 1, endi do
    if t[i].tz <= t[pivot].tz then
      if i == pivot + 1 then
        t[pivot],t[pivot+1] = t[pivot+1],t[pivot]
      else
        t[pivot],t[pivot+1],t[i] = t[i],t[pivot],t[pivot+1]
      end
      pivot = pivot + 1
    end
  end
   t = quicksort(t, start, pivot - 1)
  return quicksort(t, pivot + 1, endi)
end



function z_clip_line(p1x,p1y,p1z,p2x,p2y,p2z,clip)
	if(p1z>p2z)then
		p1x,p2x=p2x,p1x
		p1z,p2z=p2z,p1z
		p1y,p2y=p2y,p1y
	end
	
	if(clip>p1z and clip<=p2z)then

	--	line(p1x+64,p1z+64,p2x+64,p2z+64,14)
		alpha= abs((p1z-clip)/(p2z-p1z))
		nx=lerp(p1x,p2x,alpha)
		ny=lerp(p1y,p2y,alpha)
		nz=lerp(p1z,p2z,alpha)
				
	--	circ(nx+64,nz+64,1,12)
		return nx,ny,nz
	else
		return false
	end
end

function project_point(x,y,z)
	return x*k_screen_scale/z+k_x_center,y*k_screen_scale/z+k_x_center
end

function project_radius(r,z)
	return r*k_screen_scale/abs(z)
end



function lerp(a,b,alpha)
	if abs(a-b) < 0.0001 then return b end
  return a*(1.0-alpha)+b*alpha
end

function lerp2(a,b,alpha)
	if abs(a-b) < 0.5 then return b end
  return a*(1.0-alpha)+b*alpha
end

function movetow(a,b,spd)
	if abs(b-a) <= spd then return b end
	return a + sign(b-a)*spd
end

function sign(v)
	return v>0 and 1 or v<0 and -1 or 0
end

function camround(a)
	if a <= -0.6 then return -1 end
	return flr(abs(a))
end

function update_camera(index)
	if uidata.uistate ~= 'map' then idle_camera()
	else
		delta = 0.1;
		local cam_m = level_selected and 2 or 1
		cam_x = lerp(cam_x, cam_positions[index][cam_m][1], delta)
		cam_y = lerp(cam_y, cam_positions[index][cam_m][2], delta)
		cam_z = lerp(cam_z, cam_positions[index][cam_m][3], delta)

		cam_ax = lerp(cam_ax, cam_positions[index][cam_m][4], delta)
		cam_ay = lerp(cam_ay, cam_positions[index][cam_m][5], delta)
		cam_az = lerp(cam_az, cam_positions[index][cam_m][6], delta)
	end
	--[[inx = btn(0, 0) and 1 or btn(1, 0) and -1 or 0
	iny = btn(2, 0) and -1 or btn(3, 0) and 1 or 0
	inz = btn(4, 0) and -1 or btn(5, 0) and 1 or 0
	inay = btn(0, 1) and -1 or btn(1, 1) and 1 or 0
	inax = btn(2, 1) and 1 or btn(3, 1) and -1 or 0
	cam_x+=inx/10
	cam_y+=inz/10
	cam_z+=iny/10
	cam_ax+=inax/180
	cam_ay+=inay/180--]]

	generate_cam_matrix_transform(cam_ax,cam_ay,cam_az)
end

function idle_camera()
	idlecamtimer-=0.0005

	cam_x=lerp(cam_x, cos(idlecamtimer)*5-1, 0.1)
	cam_y=lerp(cam_y, 1, 0.1)
	cam_z=lerp(cam_z, sin(idlecamtimer)*5, 0.1)

	if abs(cam_ay - atan2(cam_x, cam_z)) > 0.9 then cam_ay+=1 end

	cam_ax=lerp(cam_ax, 0.05, 0.1)
	cam_ay=lerp(cam_ay, atan2(cam_x, cam_z)-0.75, 0.1)
	cam_az=lerp(cam_az, 0, 0.1)
end

function init_3d()
	init_light()
	object_list={}
end

function update_3d()
	for object in all(object_list) do
			update_visible(object)
			transform_object(object)
			cam_transform_object(object)
			--update_light()
	end
	if cam_z < 0 then city.visible,castle.visible=false end 
	if cam_z > 0.5 and cam_x > 0 then lift.visible,temple.visible=false end
end

function draw_3d()
	triangle_list={}
	quicksort(object_list)
	
	for object in all(object_list) do
		
		if object.visible and not object.background then
			render_object(object) --sort_faces(object)
			--if(object.color_mode==k_colorize_dynamic or object.color_mode==k_multi_color_dynamic) color_faces(object,object.color)
		end
	end
	
	quicksort(triangle_list)
	
	draw_triangle_list()
end


function shade_trifill( x1,y1,x2,y2,x3,y3, color1, color2)

		  local x1=band(x1,0xffff)
		  local x2=band(x2,0xffff)
		  local y1=band(y1,0xffff)
		  local y2=band(y2,0xffff)
		  local x3=band(x3,0xffff)
		  local y3=band(y3,0xffff)
		  
		  local nsx,nex
		  --sort y1,y2,y3
		  if y1>y2 then
			y1,y2=y2,y1
			x1,x2=x2,x1
		  end
		  
		  if y1>y3 then
			y1,y3=y3,y1
			x1,x3=x3,x1
		  end
		  
		  if y2>y3 then
			y2,y3=y3,y2
			x2,x3=x3,x2		  
		  end
		  
		 if y1!=y2 then 		 
			local delta_sx=(x3-x1)/(y3-y1)
			local delta_ex=(x2-x1)/(y2-y1)
			
			if(y1>0)then
				nsx=x1
				nex=x1
				min_y=y1
			else --top edge clip
				nsx=x1-delta_sx*y1
				nex=x1-delta_ex*y1
				min_y=0
			end
			
			max_y=min(y2,128)
			
			for y=min_y,max_y-1 do

			--rectfill(nsx,y,nex,y,color1)
			if(band(y,1)==0)then rectfill(nsx,y,nex,y,color1) else rectfill(nsx,y,nex,y,color2) end
			nsx+=delta_sx
			nex+=delta_ex
			end

		else --where top edge is horizontal
			nsx=x1
			nex=x2
		end

		  
		if y3!=y2 then
			local delta_sx=(x3-x1)/(y3-y1)
			local delta_ex=(x3-x2)/(y3-y2)
			
			min_y=y2
			max_y=min(y3,128)
			if y2<0 then
				nex=x2-delta_ex*y2
				nsx=x1-delta_sx*y1
				min_y=0
			end
			
			 for y=min_y,max_y do

				--rectfill(nsx,y,nex,y,color1)
				if band(y,1)==0 then rectfill(nsx,y,nex,y,color1) else rectfill(nsx,y,nex,y,color2) end
				nex+=delta_ex
				nsx+=delta_sx
			 end
			
		else --where bottom edge is horizontal
			--rectfill(nsx,y3,nex,y3,color1)
			if(band(y,1)==0)then rectfill(nsx,y3,nex,y3,color1) else rectfill(nsx,y3,nex,y3,color2) end
		end

end

-->8
-- transition globals
tstate=-1
tcol=1
tpos=-20
transition_action=nil

-- triangle functions
function po1tri(x0,y0,x1,y1,x2,y2)
 local c=x0+(x2-x0)/(y2-y0)*(y1-y0)
 p01traph(x0,x0,x1,c,y0,y1)
 p01traph(x1,c,x2,x2,y1,y2)
end

function p01traph(l,r,lt,rt,y0,y1)
 lt,rt=(lt-l)/(y1-y0),(rt-r)/(y1-y0)
 //if(y0<0)l,r,y0=l-y0*lt,r-y0*rt,0
 for y0=y0,y1 do
  rectfill(l,y0,r,y0,tcol)
  l+=lt
  r+=rt
 end
end

----------------------------------end copy-------------------------------------------------------
----------------------------------electric gryphon's 3d library----------------------------------
-------------------------------------------------------------------------------------------------
-->8
--models

--mountain

--model_v="ffbe0c15ff6dfed102a0fb4e0041023e0262fff200ab0501ffbfffc41035fe3d03570253fe1d0330031ffe0700a504d1fdc7007f1033fd66035f0190fd01032c024afac3009e027beb69fe84038cfacf00e2fce6eb3fff68fc04fcc40380fd91fea40006f979fa4dff45ee8e04fc08f9ffc902b80424001003320309fdf603adffe7fa4400fc02e8fbdf01530007f9590295037a02030246012f0347046dffd10fa1045903fc02700699032101bb076e02ffff09053602e1fdef04c7018303b90b5c00400fbb078400b5025810e2ffc20b50087d005efede11ceffb8ff8b06b80015fb920ebf004ff39a0790ffd3efd3014fff80ef2904f80634014a050a05f101f405f506050147039e05eb000b03ec05f40169013706adfe110115081cfefa0037081cfdec0108081cfe3dfe7707e4003efedf0952ff3cff49098a0039fe810960ffb7fe7e07730061feb408b2ff56ff51088f00c0fe1e08a10061fdcf06c2ffcffe44059effe7fd4404b1fffefe0e05cf00f7fd8805b2fed1"
--model_f="0103060603070407030904050b0607063e010b080c0d08090c080d103d0a0f0c0d0a0c0e100a0e0201100e0210120e0f161718180211152d14141901030119031a04041b052a2e2d2a2c2b1f1315131f1e2c1e1d19201a1b20211d201c2122231e221d2225231f241e242725161f152911122818292628272a2d132a132c1d2b2c1c2e2b2e142d1401151501170102173132302f3231322f30353634333635363334393a38373a393a37383c3b3e3c3e3d3b013e3e0a3d3d3f3c3c3f3b103f3d10013f3b3f010408070908040b0a06060a3e0b07080f0e0c0a0b0c0e110212110e16151718170215132d03191a041a1b2a2b2e2c131e191c201b1a201d22202120221e24222224251f262424262716261f2918112816182616281d1c2b1c192e2e1914"

--model_v="052d0be401dd05c207750284020d06630298029a0bdd018afe2f0c00018afb840c830182fda206cb01edf9a40769026906650b0d0119062c07f30119f9bb0cb6017df82c0ad90182f8590e2a01def7500b5201d6f5f30dd90175f6050c8f01a9f5d00b5c0117f52b0a880133f5e80a5f0133f5f30e71009cf5680d1c00eefa040d830094f8460f1700a4fda206cb009c020d0663009c052d0c4b009c029a0c860087f82c0a16009cf9a40706009cf47e0a88009cf59d09e3009c070507f3009c06c40b0d009c05650686009cf5830b5c009cfe2f0caa0087fb840c83009cf7500a7f009cfc29053b0216fa5405aa0216fc29053b00d7fa5405aa00d7057703fc01540367042f019a02ee042f0069057703fc0069071c098101190527096a02820253097502cafde9099902cafa9409f7033bf9180bc80182f7d40cd101d6071c0981009cfb170e53014cfa880ec80193fb2c0ec3011ffa790f42016ef9d20d4b014af90f0e160151fa900e2d012ffa420e6d0156f6120c54015ef5e40bba00f6f5c40c9a0100f5e40bba00f600170673012c009b0bec012c00170673009c00a40c96008700550985021608990abd009c09900c83009c096c0e70009c07b91002009c05c60fd2005cfbcd030901b7fae302ab01b7fbcd030900d7fae302ab00d7fb7300b00147fa9400a60147fb7300b000d7fa9400a600d70627022c0154050c025f0154050c025f00690627022c006905d800550154050f00670154050f0067006905d800550069fbcd000d0171fa4800100171fbcd000d00adfa48001000ad0605fff30173047dffff0173047dffff004a0605fff3004a052d0c4b0002052206860002020d06630002029a0c860002fe2f0caa0002fb840c830002fda206cb0002f9a40769000207040b0d0002073407f30002fa040d790002f82c0a160002f8570f210002f7500a7f0002f5f30e710002f51b0d1c0002f4fc0b5c0002f4490a880002f5ff09e30002052d0be4fe2805c20775fd81020d0663fd6d029a0bddfe7bfe2f0c00fe7bfb840c83fe82fda206cbfe18f9a40769fd9c06650b0dfeec062c07f3feecf9bb0cb6fe88f82c0ad9fe82f8590e2afe27f7500b52fe2ff5f30dd9fe90f6050c8ffe5cf5d00b5cfeeef52b0a88fed2f5e80a5ffed2f5f30e71ff69f5680d1cff17fa040d83ff71f8460f17ff60fda206cbff69020d0663ff69052d0c4bff69029a0c86ff7ef82c0a16ff69f9a40706ff69f47e0a88ff69f59d09e3ff69070507f3ff6906c40b0dff6905650686ff69f5830b5cff69fe2f0caaff7efb840c83ff69f7500a7fff69fc29053bfdeffa5405aafdeffc29053bff2efa5405aaff2e057703fcfeb10367042ffe6a02ee042fff9c057703fcff9c071c0981feec0527096afd8302530975fd3bfde90999fd3bfa9409f7fccaf9180bc8fe82f7d40cd1fe2f071c0981ff69fb170e53feb9fa880ec8fe71fb2c0ec3fee5fa790f42fe97f9d20d4bfebbf90f0e16feb4fa900e2dfed6fa420e6dfeaff6120c54fea7f5e40bbaff0ff5c40c9aff05f5e40bbaff0f00170673000200a40c96000200170673fed9009b0becfed900170673ff6900a40c96ff7e00550985fdef08380b85000208fb09f6000208990abdff6908b70cb200020a6a0c54000209900c83ff6908930e3f00020a450ea10002096c0e70ff6907820f2b000207f0107a000207b91002ff69060f0f4b0002057d1022000205c60fd2ffa9fbcd0309fe4efae302abfe4efbcd0309ff2efae302abff2efb7300b0febefa9400a6febefb7300b0ff2efa9400a6ff2e0627022cfeb1050c025ffeb1050c025fff9c0627022cff9c05d80055feb1050f0067feb1050f0067ff9c05d80055ff9cfbcd000dfe94fa480010fe94fbcd000dff57fa480010ff570605fff3fe91047dfffffe91047dffffffbb0605fff3ffbb"
--model_f="020a2f03023043033133320533060b340b0d0e350d0f100e10110e12130e141510173a394519031b04011d080c1e1f13362109200a0218292a15234225060517140f4624051c0c0e160b061f260e19222e1e1211211a017374156f7117ba6719681b1a706c1d771f1e666e206c6b18752315696a25717314692446701c266a6f1672261f676622761e236d651a294f50180727081d2a0828272d2e58022b2e03192d032c2b01302f3130014447310807320833340c3435362f0a3a38370b16390d383a0d3c3e3c3b3d0b373d37383e0d0b3b42403f11404215413f103f40320743454307464404ba4518bb461b324744206e3621366d3648c16ec2484849c4c2c549494ac7c5c84a4a4bcac8cb4b4ccecdca4b4c4bcbce4f5354274d4f282a5027284e535f604d51534e50544d4e5257585c2b55582d57562c56555c646355595c575b5a565a595f5d5e53515d52546051525e6461625961645b6362595a6230022f31033047433106330534330b35340d0f0e0d11120e0f14101617394345031a1b011c1d0c121e132f36092220021d182a4115422425050d170f444605261c0e251606131f0e2d192e231e11092101147315166f1745ba1965681a1c701d76771e2266201d6c18747515246925177114bb6946727026256a1677721f196722757623216d1a2a295029182728082a070827572d5822022e2c032d02032b09012f0431010444313308320c08340e0c3520360a393a37370b39170d3a380d3e3e3c3d3b0b3d3d373e3c0d3b41423f23114210153f1110404732431845071b46046bba1868bb1b0532446d36c1366e48c148c448c249c449c749c54ac74aca4ac84bcdca4c4c4bce504f5429274f4e28504d274e5453604f4d53524e54514d525b575c2e2b582c2d562b2c555b5c6358555c56575a555659605f5e5f535d5e52605d515e6364625c59645a5b6261596279a6817aa779bca87aaa7ca9aa827dab84828584ac86858787858889858a8b878c8eb0b1be7a9092787b94837f958a96ad80989779818fa1a08cb99a9c7c7d8e868bbf7c9b9385838d7d8296859d90a599958889987891738c746f8e71ba906768919270946c77959666976e6c8f6b758c9a699c6a718b7369bf9b709d936a8d6f72969d679966769a956d9165a0d3d28f9e7e7fa1947f9e9fa4dba579a5a27aa4907aa2a378a6a7a878a7bda8c07fa97e7fabaa83acabad81a6b1aeaf82b08d84b1af84b5b3b3b4b282b4aeaeb5af84b282b9b6b788b9b78cb6b887b7b6a9bc7ebe7ebcbf7bbdba8fbebb92bfa9bdc097ad6e986dad6ec16dc2c4c1adc1c36ec3c2c5c7c4c3c4c6c2c6c5c8cac7c6c7c9c5c9c8cacecdc9caccc8cccbcfcdcecacfcccccecbd2d7d69ed2d09fd3a19ed19fd6e3e2d0d6d4d1d7d3d0d5d1dadfdba2dbd8a4d9daa3d8d9dfe6e7d8dfdcdaddded9dcdde2e1e0d6e0d4d5e3d7d4e1d5e7e5e4dce7e4dee5e6dce5dda7a679a8a77ac0a8bc7d7caaab82aaac84ab86848588858986878b8db08ebc7abe917892938394898a95a680ad99799794a18fb8b98c9b7c9c84868ebd7cbf9d85939c7d8d8a8596a4a5909a88958078988b8c738d8e6fbe90ba659168939470769577999766948f6c748c759b9c698e8b71bbbf69729d709c8d6a779672909967759a7698916da1d3a0a09e8f9fa17f7e9e7fdadba499a579a3a47a79a27a80a6787b78a87ba8bdaaa97f83ab7f85ac839781adb0aeb1aeb0828eb184afb584b5b4b3b2b482b4b5aeb3b284b8b6b99ab98887b68c88b787c0bca98f7ebe927bbf6b8fba6892bb7cbda9c2c16ec5c4c26dc1adadc36ec8c7c5c1c4c3c3c6c2cbcac8c4c7c6c6c9c5cbcecac7cac9c9ccc8cdcfcacfceccd3d7d2a0d29ed1d39fd0d19ed7e3d6d2d6d0d5d7d1d4d5d0dedfdaa5dba2a3d9a4a2d8a3dee6dfdbdfd8d9dddad8dcd9e3e1e2e2e0d6e1e3d5e0e1d4e6e5e7dfe7dcdde5dee4e5dc"

--small mountain
model_v="001104c2ff8600690143fe00ffe0011f009efffd00890196ffae0030032e009f0186009800c3017800f900b30087018400140030032e00ef01890050012c017700aa01e8008400a703ce0030009d01e4009efe9603d70030ff16012b0196fed60079004cfd5200c90030fc5bfe21039cffa8fef701d2ffc2feca0169fefbfe9d0041fd9dff9b015dfe35ff7b004dfd46ff040193007bff2100ba00f3febb00300310fe5d01c300a3fd8801730060fd390166ff61fe0b015bfef9fe3400d9011dfd5300300316fd31008d009afc3400300230fcd5006dff51fc040030ffcdfd7c0052fe19fca30030fd61fe180030fc9dff5d0030fc7afe3802830022fe1b027d0075fd7a0282fffffea2027bffc0fe85027e0042ff8502c2ff05ff83034eff4affdc0349fef5ff83034afeef0056037bffc0006303bdff74003c03d1ffd1008603c2ffa10087030bffe000730382ff7e00390375000300ab037bffe000c802caffaa009d025effb300fb0206ffbb00b00270001800e20265ff4c006c03bcff6d007f0384ff68000503d9ffccfff902f00012ffec02070058ffae0030032e00140030032e03ce0030009d03d70030ff1600c90030fc5bfebb00300310fd5300300316fc3400300230fc040030ffcdfca30030fd61fe180030fc9dff5d0030fc7afea50260fed3fef40274fefffe8b0260ff2efda80282ffda"
model_f="3534010603070407030904050b06070b080c0d08090c080d103d0a0f0c0d0a0c0e100a0e0201100e0210120e0f161718180211152d14141901194342031a04041b052a2e2d2a2c2b1f1315131f1e2c1e1d19201a1b20211d201c2122231e221d2225231f241e242725161f152911122818292628272a2d132a13541d2b2c1c2e2b2e142d1401300131303101023132302f3231322f3035363433363536333433393a373a393a37383c3b3e3c3e3d3e0a3d3d3f3c3c3f3b103f3d1040410408070908040b0a06060a3e0b07080f0e0c0a0b0c0e110212110e16151718170215132d03191a041a1b2a2b2e54131e191c201b1a201d22202120221e24222224251f262424262716261f2918112816182616281d1c2b1c192e2e191433383433353934400101423539063e0639433935423841403b3f41373e3b31172f15302f152f17441903194201431944143015310217333a3810413f401001393e370643033942433840343b4138373b381b4505284e27234b21054609274d250d480f1250290f4912254c23294f28214a1b09470d5251532c2a542c541e1b4a45284f4e234c4b054546274e4d0d47481249500f4849254d4c29504f214b4a094647"

prologue_v="0062006102290064008802290062006101f80064008801f8003d00610229003a00880229003d006101f8003a008801f8004f009b01f8004f009b0229"
prologue_f="030201080904050807020a0606090802090a030402040307070804050608060501010206060a09020409"

heart_v="00c8025bffd400bc027cffc300db0259ff9a00c8027bff9f00c70271ffb300dd0240ffbc00d6026aff8d00bd026dffdb"
heart_f="050201080102010605060305030704050304"

city_v="ff97008f0196ff9700e90196ff9700970174ff9700e90174ff7500900196ff7500e90196ff7500990174ff7500e90174ff46008901b9ff4600d001b9ff4600910197ff4600d00197ff24008901b9ff2400d001b9ff2400920197ff2400d00197ffa200aa0148ffa200ff0148ffa200be0126ffa200ff0126ff7f00a40148ff7f00ff0148ff7f00b60126ff7f00ff0126ff2800b40114ff2801130114ff2800d300e8ff28011300e8fefc00ba0114fefc01130114fefc00e300e8fefc011300e8ff7500a00157ff7500ff0157ff7500a3014cff7500ff014cff6900a10157ff6900ff0157ff6900a3014cff6900ff014cff8600f50162ff2200f50162ff8600f50158ff2200f50158ff8600ec0162ff2200ec0162ff8600ec0158ff2200ec0158ff8d00d800f4ff8d011300f4ff8d010500bdff8d011300bcff5500ca00f4ff55011300f4ff55011300bcff05011300cbff05014e00cbfeff00f800dcfeff014e00dcff16010100d1ff16014e00d1ff1000e500e2ff10014e00e2ff02013f00baff7a013f00e7fefd013f00c7ff75013f00f4ff02013100baff7a013100e7fefd013100c7ff75013100f4"
city_f="0302010704030706080502060b0a090604080f0c0b0f0e100d0a0e0e0c101312111318141716181116151614181b1a191f1c1b1f1e201d1a1e1e1c202322212724232726282522262624282b2a292f2c2b2d302f292e2d2e2c303332313337343536373136353634372d2b29383b393a3f3b3c3f3e383d3c3d3b3f4043414643424447464045444543474442401117130304020708040705060501020b0c0a0602040f100c0f0d0e0d090a0e0a0c1314121317181715161112161612141b1c1a1f201c1f1d1e1d191a1e1a1c2324222728242725262521222622242b2c2a2f302c2d2e30292a2e2e2a2c3334323132363632342d2f2b383a3b3a3e3f3c3d3f38393d3d393b404243464743444547404145454143444642111517"

castle_v="00df0189007b00df01d1007b00c2018300ae00c201d100ae00fd017d00ae00fd01d100ae00f101bb009e00fc01e0009f00e901bb00ac00f001e000b400f901bb00ac010801e000b400df01bb007e00df01e0006d00d601bb008d00d301e0008200e701bb008d00eb01e0008200cb01bb00a000c401e0009f00c401bb00ac00b801e000b400d201bb00ac00d001e000b4"
castle_f="010402030604040602010605070a080b0a090a0c080b080c0d100e11100f10120e0d121115141315181616181417141801030403050601020607090a0b0c0a0b07080d0f101112100d0e12151614151718171314"

waterfall_v="fd86016aff3efdbe0165ff21fdef02daff7afe0502dbff70"
waterfall_f="020304020103"

temple_v="ffcd034cff05ffdb037fff11ffa8034dfef9ffaa0385fef8ff8c034eff13ff8e0386ff12ff94034eff38ffa30382ff44ffab03adff02ffaa0387ff03ffd803adff1bffd00381ff18ff970388ff14ff9803aeff13ffaa0383ff3affb003aeff40"
temple_f="010402050403070605080d060d090a0f0e0d0c090b060a04040c0210090e010304050604070806080f0d0d0e090f100e0c0a09060d0a040a0c100b09"

lift_v="fea90260feddfee6026ffefffe950260ff24feba00fafe77ff000162fec2fe2c0160fefafef10274ff07feed028cff05fef10273fef8feed028bfef7fee00271ff07fedb0288ff05fee00270fef8fedb0288fef7"
lift_f="020103050604010603030502050102070a080d0a090d0c0e0b080c090b0d0e080a01040603060505040107090a0d0e0a0d0b0c0b070809070b0e0c08"

hotel_v="fdb802880025fdb802c50025fe1302880065fe1302c50065fe6f02870037fe6f02c50037fe8c0280ffd5fe8402c1ffc4fe2402c50019fdb10284ffe2fdde02c5ffe2"
hotel_f="030201030604070605080906060904040902020a0102090b030402030506070806020b0a"

flag_v="001604fbff84001604c0ff84001604fbff88001604c0ff88000d04c0ff88000d04fbff88000d04c0ff84000d04fbff84000d04faff83000d04e0ff83000d04faff89000d04e0ff89ffea04deff89ffea04f8ff89ffea04deff83ffea04f8ff83"
flag_f="0107020604050a100f0e0c0d0108070603040a09100e0b0c"

--mountain2
--model_v="ffe404c2ff86ff8c0143fe000015011f009efff700890196006100320284ff5601860098ff4a017800e4ff42008701840010004f0283ff0601890050fee101770095fe0d008400a7fd24ffff0080fe11009efe96fd1d0023ff4dfeca0196fed6ff7c004cfd52ff83001dfd2801d4039cffa800fe01d2ffc2012b0169fefb01580041fd9d005a015dfe35007a004dfd4700f10193007b00d400ba00f3011f0034026c019801c300a3026d0173006002bc0166ff6101ea015bfef901c100d9011d023a0045027002c4008d009a031b003101bc0320006dff5103400030ffdd02790052fe1902c40048fdf6019f0034fd5c00a00027fd4101d30295003601d9027d00750231028400350153027bffc00170027e0042006f02c2ff050072034eff4a00190349fef5005e034aff16ff9f037bffc0ff9203bdff74ffb903d1ffd1ff6f03c2ffa1ff6e030bffe0ff820382ff7effbc03750003ff4a037bffe0ff2d02caffaaff58025effb3fefa0206ffbbff4402700018ff130265ff4cff8903bcff6dff760384ff68fff003d9ffccfffc02f00012000802070058ffd0ffec0416fc5fffec00bffd05ffecfc870374ffec02cd03f0ffecfff40262ffecfbb5ffd6ff8803f4fc81ff8800b9fd22ff88fca3035cff8802b603d4ff88fff40253ff88fbd8"
--model_f="3501340607030403070905040b07060b0c080d09080c0d08100a3d0f0d0c0a0e0c100e0a0210010e1002120f0e16181718110215142d14011919424303041a04051b2a2d2e2a2b2c1f1513131e1f2c1d1e191a201b21201d1c202123221e1d222223251f1e2424252716151f2912112829182627282a132d2a2c131d2c2b1c2b2e2e2d141430010130313102013130322f313232302f353436333536363433333a3937393a3a38373c3e3b3c3d3e3e3d0a3d3c3f3c3b3f103d3f1041400407080904080b060a063e0a0b08070f0c0e0a0c0b0e0211120e11161715180217152d13031a19041b1a2a2e2b2c1e1319201c1b201a1d20222122201e22242225241f2426242726161f262911182818162628161d2b1c1c2e192e1419333438333935340140013542393e060643393942353840413b413f373b3e312f17152f3015172f44031919014243441914153031170233383a103f4140011039373e0603433943423834403b384137383b27494a0f460d1229470f1247234925294a472145480d45091b054528274a232148050945454c4b4a4d47484b4e49504a464d4c494e4f2725490f474623484929284a211b450d464545464c4a504d48454b494f5046474d49484e"


cam_positions = {
{{	0.6002, 1.2002, 3, -0.0889, 0.0611, 0},
{0.5002, 0.7002, 2.7999, -0.0556, 0.0611, 0}},

{{-0.0997, 1.6001, 2.3, -0.0778, 0.0778, 0},
{-0.0997, 1.0002, 2.4, -0.0333, 0.1111, 0}},

{{1.3002, 2.1001, 0.7001, -0.1222, 0.2111, 0},
{1.5001, 1.8001, 1, -0.0111, 0.2111, 0}},

{{-2.5995, 3.2, 1.7, -0.0444, -0.1222, 0},
{-1.3996, 3.3, 1.8, -0.0611, 0.0889, 0}},

{{-3.3994, 3.5999, -1.9996, -0.0611, -0.3388, 0},
{-3.1994, 2.6, -2.6996, -0.0222, -0.3499, 0}},

{{-0.1997, 4.0999, -2, -0.0944, -0.561, 0},
{-0.8996, 3.7999, -1.1997, -0.0556, -0.2721, 0}},

{{0.7002, 4.2999, 0.9001, -0.0611, -1.0275, 0},
{0.9002, 4.2999, 1, -0.0611, -0.8942, 0}},

{{1.6001, 1.4001, 4.3998, 0.05, -0.9164, 0},
{1.7001, 1.7001, 4.6998, 0.0777, -0.8998, 0}},

{{0.5002, 0.6002, 2.5, -0.0278, -0.9331, 0},
{0.5002, 0.6002, 2.5, -0.0278, -0.8831, 0}},

{{1.6001, 2.7, 0.4001, -0.0278, -0.8498, 0},
{1.6001, 2.7, 0.6001, -0.0278, -0.8276, 0}}

}

leveldata={
	{title="prologue",color=2,textcol=7,width=0,hasstats=false,max_berries=20},
	{title="forsaken city",color=13,textcol=7,width=10,hasstats=true,max_berries=20},
	{title="old site",color=3,textcol=7,width=0,hasstats=true,max_berries=20},
	{title="celestial resort",color=4,textcol=7,width=10,hasstats=true,max_berries=20},
	{title="golden ridge",color=14,textcol=7,width=10,hasstats=true,max_berries=20},
	{title="mirror temple",color=2,textcol=7,width=10,hasstats=true,max_berries=20},
	{title="reflection",color=12,textcol=7,width=0,hasstats=true,max_berries=20},
	{title="the summit",color=10,textcol=1,width=0,hasstats=true,max_berries=20},
	{title="epilogue",color=1,textcol=7,width=0,hasstats=false,max_berries=20},
	{title="core",color=8,textcol=7,width=0,hasstats=true,max_berries=20}
}

__gfx__
00000000444444440006600054444445055555500007770055544000000dd000400000004444444400eeee0000000000c0cc0000000000000000000000000000
0000000044422444333373330424424054444445077777775c1110000ddccdd0b003bb00444224440e8888e000000000cc6c0000000000000000000000000000
000000004422224433377377042222400777777077ddd5dd55144444dccc1ccdbbb33bbb44222244e822828e00000000cccc0000000000000000000000000000
00000000422222247737737704422440077111707dd5555d44145554dcc111cdbb3bb3bb42222224e222222e000000000cc00000000000000000000000000000
0000000044222244777773770442244007717170dd55dd5d44142224dc1111cdb3bbb33044222244e222222e0000000000000000000000000000000000000000
0000000044222244777777770422224007711170d5d5dd5d00042224dc1111cdb3bb3b3b44222244e822228e0000000000000000000000000000000000000000
00000000444444443333333304444440071777705dd5555d00042224dcc11ccdbb000bb0444444440e8228e00000000000000000000000000000000000000000
0000000044444444000660000444404007777770ddd5dd5d000444440ddccdd0400000004444444400eeee000000000000000000000000000000000000000000
00000000555555550006600004040000555555550ddd00dd00060600000dd0004000000055555555000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000444000300b0b07777777700011100001110000080000005d50000080800000300b0b000000000000000000004bb00000499000300b0b0011001100a0aa0a0
00445540003b3300711111770016661001666100097f00005ddd500088888000003b330000004bb0000000000004bbbb00049999003b33001cc11cc10aa88aa0
044555040288882016777617016ccc6116ccc610a777e000dd0dd0008888800003bbbb3000004bbb00000000000400bb00040099028888201cccc6c102999920
044555040898888017770017016cccc66cccc6100b7d00005ddd5000088800000b377bb00888400b000100000001000000010000089888801ccccc6109a99990
04455504088889801007001716cccccccc77cc6100c0000005d50000008000000b7773b081f18000001710000017100000171000088889801cccccc109999a90
04455888088988801677761716cccccccc77cc610000000000000000000000000bb77bb08fff80000177710001777100017771000889888001cccc10099a9990
0c888888028888207616167716cccccccccccc6100000000000000000000000003b77b30033300000177cc100177cc100177cc1002888820001cc10002999920
00888000002882007171717716cccccccccccc61000000000000000000000000003bb300070700001cccc6611cccc6611cccc661002882000001100000299200
000000000000000000000000016cccccccccc6100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000016cccccccccc6100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000016cccccccc61000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000
00000000000000000000000000016cccccc610000000000000000000000000000000000000000000000000017100000000000000000000000000000000000000
000000000000000000000000000016cccc6100000000000000000000000000000000000000000000000000177710000000000000000000000000000000000000
0000000000000000000000000000016cc61000000000000000000000000000000000000000000000000000177cc1000000000000000000000000000000000000
00000000000000000000000000000016610000000000000000000000000000000000000000000000000001cccc61000000000000000000000000000000000000
00000000000000000000000000000001100000000000000000000000000000000000000000000000000001ccc666100000000000000000000000000000000000
0000000100000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000001ccc6666100000000000000000000000000000000000
0000001710000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000001ccc6666100000000000000000000000000000000000
0000001710000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000001ccc66666610000000000000000000000000000000000
0000017771000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000000000001cc666666610000000000000000000000000000000000
0000017771000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000001cc6666666610000000000000000000000000000000000
0000017761000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000000000000000000001cc6666666661100000000000000000000000000000000
0000177666100000bbbbbbbbbb66bbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000001cccc666666661c10000000000000000000000000000000
0000176666101000bbbbbbbb6666bbbbbbbbbbbbbbbbbbbb000000000000000000000000000000001cc6cccc666666ccc1000000000000000000000000000000
0000166666617100bbbbbb666622888828181818bbbbbbbb00000000000000000000000000000001cc6666cccc6666ccd1000000000000000000000000000000
0001766666677100bbbbbb662288888121182181bbbbbbbb00000000000000000000000000000001cc66666666666cccdd100000000000000000000000000000
0017666666676610bbbbbbbb888881121f182282bbbbbbbb000000000000000000000000000000166cc6666666666cccdd100000000000000000000000000000
0016666666666610bbbbbbbb88811ffff181ff12bbbbbbbb0000000000000000000000000000016666c666666666ccccddd10000000000000000000000000000
016666d666666610bbbbbbbb1111ff0001810012bbbbbbbb0000000000000000000000000000016666666666666cccc6dddd1000000000000000000000000000
01d666ddd66dd6d1bbbbbbbb2881f07000107012bbbbbbbb000000000000000000000000000016666666666666cccc666ddd1000000000000000000000000000
1dddddddddddddd1bbbbbbbb2881f07000f07012bbbbbbbb00000000000000000000000000016666666666666cccc6666dddd100000000000000000000000000
1111111111111111bbbbbbbb8881f07770707712bbbbbbbb0000000000000000000000000001666666666666cc66666666dddd10000000000000000000000000
0000000000000000bbbbbbbb8281f77777977772bbbbbbbb00000000000000000000000000166666666666666666666666dddd10000000000000000000000000
0777777777777777bbbbbbbb2281877777777781bbbbbbbb00000000000000000000000001666666c666666666666666666dddc1000000000000000000000000
0777777777777777bbbbbbbb281ff77777777771bbbbbbbb000000000000000000000001016666666ccc666666666666666ddccc101000000000000000000000
0777777777777777bbbbbbbb281ff77770007771bbbbbbbb00000000000000000000101c166666666ccccc666666666666ccccc661c100000000000000000000
0777777777777777bbbbbbbb881ffff777777712bbbbbbbb00000000000000000001c1ccd6666666cccc66666666cccccccccc666cc610000000000000000000
0777777777777777bbbbbbbb81cc111ff1111122bbbbbbbb0000000000000000001ccc6c6666666cc666666666666666666666666c66d1000000000000000000
0777777777777777bbbbbbbb81ccccc11cccc12266bbbbbb00000000000000000016c666666666666666666666666666666666666d66d1000000000000000000
0777777777777777bbbbbbbb1cccccccc1ccc16666bbbbbb000000000000000001666666666666666666666666666666666666666d66dd100000000000000000
0777777777777777bbbbbbbbbbbbbbbbbbbb6666bbbbbbbb00000000000000001d66666666666666666d666666666666dddddd66ddddddd10000000000000000
0777777777777777bbbbbbbbbbbbbbbbbbbb66bbbbbbbbbb00000000000000001d66ddd666666666666dd6666666666dddd6666dddddddd10000000000000000
0007777777777777bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000dddddddddddd666666ddd66666dddddddddddddddddddddd0000000000000000
bb70777777777777bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000dddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000
bbb7077777777777bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000001111111111111111111111111111111111111111111111110000000000000000
bb77077777777777bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000000177711777777177111117777771177771177777717777770000000000000000
bbb7077777777777bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000177cc717c7cc717c1111177ccc7177cc77177cccc177cc770000000000000000
bb77077777777777bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb00000000000000007ccddd17cdddd1cc111117cdddd17cddcc1ddccdd17cdddd0000000000000000
bbb7077777777777000000000000000000000000000000000000000000000000ccd1111cccccd1cc11111cccccd1cccddd111cc111cccccd0000000000000000
bb70777777777777000000000000000000000000000000000000000000000000ccd1111ccccc11cc11111ccccc11dcccc1111cc111ccccc10000000000000000
0007777777777777000000000000000000000000000000000000000000000000ccd1111ccddd11cc11111ccddd111ddcc1111cc111ccddd10000000000000000
0777777777777777000000000000000000000000000000000000000000000000ccd1111ccddd11cc11111ccddd11ccddcc111cc111ccddd10000000000000000
0777777777777777000000000000000000000000000000000000000000000000cccccc1cccccc1cccccc1cccccc1cccccc111cc111cccccc0000000000000000
0777777777777777000000000000000000000000000000000000000000000000dccc7d1c7cccc1cccccc17ccccc1dccc7d111cc111cc77cc0000000000000000
07777777777777770000000000000000000000000000000000000000000000001dddd11dddddd1dddddd1dddddd11dddd1111dd111dddddd0000000000000000
07777777777777770000000000000000000000000000000000000000000000000111100111111111111111111111111111111111111111110000000000000000
07777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777777777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000300b0b000000000000000000004bb00000499000300b0b0011001100a0aa0a0
0000000000000000000000000000000000000000000000000000000000000000003b330000004bb0000000000004bbbb00049999003b33001cc11cc10aa88aa0
000000000000000000000000000000000000000000000000000000000000000003bbbb3000004bbb00000000000400bb00040099028888201cccc6c102999920
00000000000000000000000000000000000000000000000000000000000000000b377bb00888400b000100000001000000010000089888801ccccc6109a99990
00000000000000000000000000000000000000000000000000000000000000000b7773b081f18000001710000017100000171000088889801cccccc109999a90
00000000000000000000000000000000000000000000000000000000000000000bb77bb08fff80000177710001777100017771000889888001cccc10099a9990
000000000000000000000000000000000000000000000000000000000000000003b77b30033300000177cc100177cc100177cc1002888820001cc10002999920
0000000000000000000000000000000000000000000000000000000000000000003bb300070700001cccc6611cccc6611cccc661002882000001100000299200
__gff__
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffff0000000000ffffffffffffffff00ffff0000000000ffffffffffffffff00ffff0000000000ffffffffffffffff00ffff
0000000000ffffffffffffffff00ffff0000000000000000000000000000ffff0000000000000000ffffffffff00ffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
