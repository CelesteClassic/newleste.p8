pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

--reflection.p8
--by many contributers
_g = _ENV
poke(24366, 1)

function unsplit(s) 
	return unpack(split(s)) 
end

function vector(n, e)
  return {x = n, y = e}
end

function v0()
  return vector(0, 0)
end

function rectangle(n)
  local _g, _ENV = _ENV, {}
  x, y, w, h = _g.unpack(_g.split(n))
  return _ENV
end

objects = {}
freeze, delay_restart, sfx_timer, music_timer, ui_timer =unsplit'0,0,0,0,-99'
cam_x, cam_y, cam_spdx, cam_spdy, cam_gain, cam_offx, cam_offy =unsplit'0,0,0,0,.25,0,0'
_pal = pal

function _init()
  max_djump, deaths, frames, seconds, minutes, music_timer, time_ticking, berry_count =unsplit'1, 0, 0, 0, 0, 0,true, 0'
  music(unsplit'0,0,7')
  load_level(1)
end

dead_particles = {}
player = {layer = 2, init = function(_ENV)
  particles, feather, collides, djump, hitbox = {}, false, true, max_djump, rectangle "1,3,6,5"
  create_hair(_ENV)
  foreach(split "bouncetimer,grace,jbuffer,dash_time,dash_effect_time,dash_target_x,dash_target_y,dash_accel_x,dash_accel_y,spr_off,berry_timer,_berry_count", function(n)
    _ENV[n] = 0
  end)
end, update = function(_ENV)
  local n, e = btn(➡️) and 1 or btn(⬅️) and -1 or 0, btn(⬆️) and -1 or btn(⬇️) and 1 or 0
  foreach(particles, function(n)
    n.x += n.xspd
    n.y += n.yspd
    n.xspd = appr(n.xspd, 0, .03)
    n.yspd = appr(n.yspd, 0, .03)
    n.life -= 1
    if n.life == 0 then
      del(particles, n)
    end
  end)
  if y > lvl_ph and not exit_bottom then
    kill_player(_ENV)
  end
  if feather then
    local d = 1
    if n ~= 0 or e ~= 0 then
      movedir, d = appr_circ(movedir, atan2(n, e), .04), 1.5
    end
    spd = vector(d * cos(movedir), d * sin(movedir))
    local e = vector(x + 4.5, y + 4.5)
    foreach(tail, function(n)
      n.x += (e.x - n.x) / 1.4
      n.y += (e.y - n.y) / 1.4
      e = n
    end)
    if bouncetimer == 0 then
      if is_solid(0, 2) or is_solid(0, -2) then
        movedir *= -1
        bouncetimer = 2
        init_smoke()
      elseif is_solid(2, 0) or is_solid(-2, 0) then
        movedir = round(movedir) + .5 - movedir
        bouncetimer = 2
        init_smoke()
      end
    end
    if bouncetimer > 0 then
      bouncetimer -= 1
    end
    local n = {x = x + rnd(8) - 4, y = y + rnd(8) - 4, life = 10 + flr(rnd(5))}
    n.xspd = -spd.x / 2 - (x - n.x) / 4
    n.yspd = -spd.y / 2 - (y - n.y) / 4
    add(particles, n)
    lifetime -= 1
    if lifetime <= 0 or btn(❎) then
      p_dash = false
      feather = false
      init_smoke()
      player.init(_ENV)
      spd.x /= 2
      spd.y = spd.y < 0 and -1.5 or 0
    end
  elseif feather_idle then
    spd.x *= .8
    spd.y *= .8
    spawn_timer -= 1
    if spawn_timer <= 0 then
      feather_idle = false
      feather = true
      if n == 0 and e == 0 then
        movedir = flip.x and .5 or 0
      else
        movedir = atan2(n, e)
      end
      lifetime = 60
      _g.bouncetimer = 0
      tail, particles = {}, {}
      for n = 0, 15 do
        add(tail, {x = x + 4, y = y + 4, size = mid(1, 2, 9 - n)})
      end
    end
  end
  if not feather and not feather_idle then
    local d = is_solid(0, 1)
    if d then
      berry_timer += 1
    else
      berry_timer, _berry_count = 0, 0
    end
    if d and not was_on_ground then
      init_smoke(0, 4)
    end
    local f, o = btn(🅾️) and not p_jump, btn(❎) and not p_dash
    p_jump, p_dash = btn(🅾️), btn(❎)
    if f then
      jbuffer = 4
    elseif jbuffer > 0 then
      jbuffer -= 1
    end
    if d then
      grace = 6
      if djump < max_djump then
        psfx(22)
        djump = max_djump
      end
    elseif grace > 0 then
      grace -= 1
    end
    dash_effect_time -= 1
    if dash_time > 0 then
      init_smoke()
      dash_time -= 1
      spd = vector(appr(spd.x, dash_target_x, dash_accel_x), appr(spd.y, dash_target_y, dash_accel_y))
    else
      local f = d and .6 or .4
      spd.x = abs(spd.x) <= 1 and appr(spd.x, n * 1, f) or appr(spd.x, sign(spd.x) * 1, .15)
      if spd.x ~= 0 then
        flip.x = spd.x < 0
      end
      local f = 2
      if n ~= 0 and is_solid(n, 0) then
        f = .4
        if rnd(10) < 2 then
          init_smoke(n * 6)
        end
      end
      if not d then
        spd.y = appr(spd.y, f, abs(spd.y) > .15 and .21 or .105)
      end
      if jbuffer > 0 then
        if grace > 0 then
          psfx(18)
          jbuffer, grace, spd.y = 0, 0, -2
          init_smoke(0, 4)
        else
          local n = is_solid(-3, 0) and -1 or is_solid(3, 0) and 1 or 0
          if n ~= 0 then
            psfx(19)
            jbuffer = 0
            spd = vector(n * -2, -2)
            init_smoke(n * 6)
          end
        end
      end
      if djump > 0 and o then
        init_smoke()
        djump -= 1
        dash_time = 4
        has_dashed = true
        dash_effect_time = 10
        spd = vector(n ~= 0 and n * (e ~= 0 and 3.53553 or 5) or (e ~= 0 and 0 or flip.x and -1 or 1), e ~= 0 and e * (n ~= 0 and 3.53553 or 5) or 0)
        psfx(20)
        dash_target_x = 2 * sign(spd.x)
        dash_target_y = (spd.y >= 0 and 2 or 1.5) * sign(spd.y)
        dash_accel_x = spd.y == 0 and 1.5 or 1.06066
        dash_accel_y = spd.x == 0 and 1.5 or 1.06066
      elseif djump <= 0 and o then
        psfx(21)
        init_smoke()
      end
    end
    spr_off += .25
    sprite = not d and (is_solid(n, 0) and 5 or 3) or btn(⬇️) and 6 or btn(⬆️) and 7 or spd.x ~= 0 and n ~= 0 and 1 + spr_off % 4 or 1
    update_hair(_ENV)
    if (exit_right and left() >= lvl_pw or exit_top and y < -4 or exit_left and right() < 0 or exit_bottom and top() >= lvl_ph) and levels[lvl_id + 1] then
      next_level()
    end
    was_on_ground = d
  end
end, draw = function(_ENV)
  foreach(particles, function(n)
    if n.big then
      spr(15, n.x - 1, n.y - 1, 1, 1, n.flip.x, n.flip.y)
    else
      pset(n.x + 4, n.y + 4, 10)
    end
  end)
  if feather and lifetime then
    if lifetime % 5 == 1 then
      pal(10, 7)
    end
    if lifetime < 10 then
      pal(10, lifetime % 4 < 2 and 8 or 10)
    end
    circfill(x + 4, y + 4, 4, 10)
    foreach(tail, function(n)
      circfill(n.x, n.y, n.size, 10)
    end)
  elseif feather_idle then
    circfill(x + 4, y + 4, 3, spawn_timer % 4 < 2 and 7 or 10)
  else
    pal(8, djump == 1 and 8 or 12)
    draw_hair(_ENV)
    draw_obj_sprite(_ENV)
    pal()
  end
end}

function create_hair(_ENV)
  hair = {}
  for n = 1, 5 do
    add(hair, vector(x, y))
  end
end

function update_hair(_ENV)
  local e = vector(x + (flip.x and 6 or 1), y + (btn(⬇️) and 4 or 2.9))
  foreach(hair, function(n)
    n.x += (e.x - n.x) / 1.5
    n.y += (e.y + .5 - n.y) / 1.5
    e = n
  end)
end

function draw_hair(_ENV)
  for e, n in inext, hair do
    circfill(round(n.x), round(n.y), split "2,2,1,1,1" [e], 8)
  end
end

player_spawn = {init = function(_ENV)
  layer = 2
  sfx "15"
  sprite = 3
  target = y
  y = min(y + 48, lvl_ph)
  _g.cam_x, _g.cam_y = mid(x, 64, lvl_pw - 64), mid(y, 64, lvl_ph - 64)
  spd.y = -4
  state = 0
  delay = 0
  create_hair(_ENV)
  djump = max_djump
  foreach(fruitrain, function(n)
    fruitrain[1].target = _ENV
    add(objects, n)
    n.x, n.y = x, y
    fruit.init(n)
  end)
end, update = function(_ENV)
  if state == 0 and y < target + 16 then
    state, delay = 1, 3
  elseif state == 1 then
    spd.y += .5
    if spd.y > 0 then
      if delay > 0 then
        spd.y = 0
        delay -= 1
      elseif y > target then
        y, spd, state, delay, _g.shake = target, vector(0, 0), 2, 5, 4
        init_smoke(0, 4)
        sfx "16"
      end
    end
  elseif state == 2 then
    delay -= 1
    sprite = 6
    if delay < 0 then
      destroy_object(_ENV)
      local n = init_object(player, x, y);
      (fruitrain[1] or {}).target = n
    end
  end
  update_hair(_ENV)
end, draw = player.draw}
camera_trigger = {update = function(_ENV)
  if timer and timer > 0 then
    timer -= 1
    if timer == 0 then
      _g.cam_offx, _g.cam_offy = offx, offy
    else
      _g.cam_offx += cam_gain * (offx - cam_offx)
      _g.cam_offy += cam_gain * (offy - cam_offy)
    end
  elseif player_here() then
    timer = 5
  end
end}
spring = {update = function(_ENV)
  delta = delta or 0
  delta *= .75
  local n, e = _ENV, dir
  local _ENV = player_here() and player_here() or n
  if _ENV ~= n then
    move(0, n.y - y - 4, 1)
    spd.x *= .2
    spd.y = -3
    dash_time, dash_effect_time, n.delta, djump = 0, 0, 4, max_djump
  end
end, draw = function(_ENV)
  local n = flr(delta)
  sspr(64, 0, 8, 8 - n, x, y + n)
end}
refill = {init = function(_ENV)
  offset, timer, hitbox = rnd(), 0, rectangle "-1,-1,10,10"
end, update = function(_ENV)
  if timer > 0 then
    timer -= 1
    if timer == 0 then
      psfx "12"
      init_smoke()
    end
  else
    offset += .02
    local n = player_here()
    if n and n.djump < max_djump then
      psfx "11"
      init_smoke()
      n.djump, timer = max_djump, 60
    end
  end
end, draw = function(_ENV)
  if timer == 0 then
    spr(12, x, y + sin(offset) + .5)
  else
    spr(11, x, y)
  end
end}
smoke = {init = function(_ENV)
  layer, spd, flip = 3, vector(.3 + rnd "0.2", -.1), vector(rnd() < .5, rnd() < .5)
  x += -1 + rnd "2"
  y += -1 + rnd "2"
end, update = function(_ENV)
  sprite += .2
  if sprite >= 27 then
    destroy_object(_ENV)
  end
end}
fruitrain = {}
fruit = {init = function(_ENV)
  golden, y_, off, tx, ty = true, y, 0, x, y
  if deaths > 0 then
    destroy_object(_ENV)
  end
end, update = function(_ENV)
  if target then
    tx += .2 * (target.x - tx)
    ty += .2 * (target.y - ty)
    local n, e = x - tx, y_ - ty
    local d, o = atan2(n, e), n ^ 2 + e ^ 2 > r ^ 2 and .2 or .1
    x += o * (r * cos(d) - n)
    y_ += o * (r * sin(d) - e)
  else
    local n = player_here()
    if n then
      n.berry_timer, target, r = 0, fruitrain[#fruitrain] or n, fruitrain[1] and 8 or 12
      add(fruitrain, _ENV)
    end
  end
  off += .025
  y = y_ + sin(off) * 2.5
end}
lifeup = {init = function(_ENV)
  spd.y, duration, flash, _g.sfx_timer, outline = -.25, 30, 0, 20
  sfx "9"
end, update = function(_ENV)
  duration -= 1
  if duration <= 0 then
    destroy_object(_ENV)
  end
  flash += .5
end, draw = function(_ENV)
  ?split "1000,2000,3000,4000,5000,1up" [min(sprite, 6)], x - 4, y - 4, 7 + flash % 2
end}
kevin = {init = function(_ENV)
  while right() < lvl_pw - 1 and tile_at(right() / 8, y / 8) != 65 do
    hitbox.w += 8
  end
  while bottom() < lvl_ph - 1 and tile_at(x / 8, bottom() / 8) != 80 do
    hitbox.h += 8
  end
  solid_obj, collides, retrace_list, hit_timer, retrace_timer, shake = true, true, {}, 0, 0, 0
end, update = function(_ENV)
  shake = max(0, shake - 1)
  for n = -1, 1 do
    for e = -1, 1 do
      if (n + e) % 2 == 1 then
        local d = check(player, n, e)
        if d and d.dash_effect_time > 0 and (n ~= 0 and sign(d.dash_target_x) == -n or e ~= 0 and sign(d.dash_target_y) == -e) and (not active or n ~= dirx and e ~= diry) then
          d.spd = vector(n * 1.5, e == 1 and .5 or -1.5)
          d.dash_time = -1
          add(retrace_list, vector(x, y))
          dirx, diry = n, e
          spd = v0()
          hit_timer = 10
          active = true
          shake = 4
        end
      end
    end
  end
  if hit_timer > 0 then
    hit_timer -= 1
    if hit_timer == 0 then
      spd = vector(.2 * dirx, .2 * diry)
    end
  elseif active then
    if spd.x == 0 and spd.y == 0 then
      retrace_timer = 10
      active = false
      shake = 5
      if dirx ~= 0 then
        for n = 0, hitbox.h - 1, 8 do
          init_smoke(dirx == -1 and -8 or hitbox.w, n)
        end
      else
        for n = 0, hitbox.w - 1, 8 do
          init_smoke(n, diry == -1 and -8 or hitbox.h)
        end
      end
    else
      spd = vector(appr(spd.x, 3 * dirx, .2), appr(spd.y, 3 * diry, .2))
    end
  elseif retrace_timer > 0 then
    retrace_timer -= 1
    if retrace_timer == 0 then
      retrace = true
    end
  elseif retrace then
    local n = retrace_list[#retrace_list]
    if not n then
      retrace = false
    elseif n.x == x and n.y == y then
      del(retrace_list, n)
      retrace_timer = 5
      shake = 4
      spd = v0()
      rem = v0()
    else
      spd = vector(appr(spd.x, sign(n.x - x), .2), appr(spd.y, sign(n.y - y), .2))
    end
  end
end, draw = function(_ENV)
  local n, e = x, y
  if shake > 0 then
    n += rnd "2" - 1
    e += rnd "2" - 1
  end
  local o, f, t, d, i, r = n + hitbox.w - 8, e + hitbox.h - 8, active and diry == -1, active and diry == 1, active and dirx == -1, active and dirx == 1
  for n = n + 8, o - 8, 8 do
    pal(12, t and 7 or 12)
    spr(65, n, e)
    pal(12, d and 7 or 12)
    spr(65, n, f, 1, 1, false, true)
  end
  for e = e + 8, f - 8, 8 do
    pal(12, i and 7 or 12)
    spr(80, n, e)
    pal(12, r and 7 or 12)
    spr(80, o, e, 1, 1, true)
  end
  rectfill(n + 8, e + 8, o, f, 4)
  local t = {d, i, t, r, d}
  for d = 0, 3 do
    pal(12, (t[d + 1] or t[d + 2]) and 7 or 12)
    spr(64, d <= 1 and n or o, (d - 1) \ 2 == 0 and e or f, 1, 1, d >= 2, (d - 1) \ 2 ~= 0)
  end
  pal()
  spr(active and 63 or 47, n + hitbox.w / 2 - 4, e + hitbox.h / 2 - 4)
end}
bumper = {init = function(_ENV)
  hitbox = rectangle "1,1,14,14"
  hittimer = 0
  startx, starty = x, y
  meep = 0
  outline = false
  inc = rnd "1" < .5 and -.02 or .02
end, update = function(_ENV)
  x = startx + cos(meep * 1.5) * 2
  y = starty + sin(meep) * 1.5
  if hittimer > 0 then
    hittimer -= 1
    if hittimer == 0 then
      init_smoke(4, 4)
    end
  else
    meep += inc
    local n = player_here()
    if n then
      n.init_smoke()
      local e, d = x + 8 - (n.x + 4), y + 8 - (n.y + 4)
      local o = atan2(e, d)
      n.spd = abs(e) > abs(d) and vector(sign(e) * -2.8, -2) or vector(-3 * cos(o), -3 * sin(o))
      n.dash_time, n.djump = -1, max_djump
      hittimer = 20
    end
  end
end, draw = function(_ENV)
  local n, e = x + 8, y + 8
  if hittimer > 0 then
    pal(12, 1)
    pal(4, 2)
    if hittimer > 17 then
      circ(n, e, 26 - hittimer, 7)
      circfill(n, e, 25 - hittimer, 1)
      if hittimer > 19 then
        rectfill(n - 4, e - 9, n + 4, e + 9, 7)
        rectfill(n - 9, e - 4, n + 9, e + 4, 7)
      end
    end
  end
  sspr(112, 16, 8, 16, x, y)
  sspr(112, 16, 8, 16, x + 8, y, 8, 16, true)
  pal()
  if hittimer == 1 then
    circfill(n, e, 4, 6)
  end
end}

function appr_circ(n, e, d)
  return (n + sign(sin(n) * cos(e) - cos(n) * sin(e)) * d) % 1
end

feather = {init = function(_ENV)
  sprtimer = 0
  offset = 0
  starty, startx = y, x
  timer = 0
  bubble = sprite == 27
  bubbled = bubble
end, update = function(_ENV)
  if timer > 0 then
    timer -= 1
    if timer == 0 then
      init_smoke()
      bubbled = bubble
    end
  else
    sprtimer += .2
    offset += .01
    y = appr(y, starty + .5 + 2 * sin(offset), 1)
    x = appr(x, startx, 1)
    if bubbled then
      hitbox = rectangle "-4,-4,16,16"
    end
    local n = player_here()
    ::j::
    if not bubbled and n then
      init_smoke()
      timer = 60
      if n.feather_idle or n.feather then
        n.lifetime = 60
        n.feather = false
      end
      n.spawn_timer, n.feather_idle, n.dash_time, n.dash_effect_time = 10, true, -10, 0
      n.spd = vector(mid(n.spd.x, -1.5, 1.5), mid(n.spd.y, -1.5, 1.5))
      particles = {}
      for e = 0, 10 do
        local e = {x = x + rnd "8" - 4, y = y + rnd "8" - 4, life = 10 + flr(rnd(5)), big = true}
        e.xspd = -n.spd.x / 2 - (x - e.x) / 4
        e.yspd = -n.spd.y / 2 - (y - e.y) / 4
        e.flip = vector(rnd "1" > .5, rnd "1" > .5)
        add(n.particles, e)
      end
    elseif bubbled and n then
      if n.dash_time > 0 then
        bubbled = false
        goto j
      else
        local e = atan2(n.y + 4 - (y + 4), n.x + 4 - (x + 4)) + .01
        local e, d = sin(e) * 2, cos(e) * 2
        n.spd = vector(e, d)
        x = startx - e * 3
        y = starty - d * 3
        n.djump = max_djump
        if n.movedir then
          n.movedir += .5
        end
      end
    end
    hitbox = rectangle "0,0,8,8"
  end
end, draw = function(_ENV)
  if timer == 0 then
    local n = flr(sprtimer % 6)
    spr(66 + min(n, 6 - n), x, y, 1, 1, n > 3)
  end
end}
garbage = {init = function(_ENV)
  local n = check(osc_plat, 0, -1)
  if n then
    n.badestate = sprite + 1
    n.hitbox.h += 8
    destroy_object(_ENV)
    return
  end
  n = check(osc_plat, -1, 0)
  if n then
    n.target_id = sprite
    foreach(objects, function(e)
      if e.type == garbage and e.sprite == sprite and e ~= _ENV then
        n.targetx, n.targety = e.x, e.y
        destroy_object(e)
      end
    end)
    destroy_object(_ENV)
  else
    foreach(objects, function(n)
      if n.type == osc_plat and n.target_id == sprite then
        n.targetx, n.targety = x, y
        destroy_object(_ENV)
      end
    end)
  end
end, end_init = function(_ENV)
  for n in all(objects) do
    if n.type == badeline then
      n.nodes[sprite + 1] = {x, y}
    end
  end
  destroy_object(_ENV)
end}
badeline = {init = function(_ENV)
  nodes, next_node, ffreeze, outline, off, target_x, target_y, rx, ry, attack, attack_timer = {}, 1, 0, false, 0, x, y, x, y, boss_phases[1], 0
end, update = function(_ENV)
  off += .005
  attack_timer += 1
  x, y = round(rx + 4 * sin(2 * off)), round(ry + 4 * sin(off))
  if ffreeze > 0 then
    ffreeze -= 1
  else
    if round(rx) ~= target_x or round(ry) ~= target_y then
      rx += .2 * (target_x - rx)
      ry += .2 * (target_y - ry)
    else
      local n = player_here()
      if n then
        attack_timer = 1
        destroy_object(laser or {})
        laser = nil
        if next_node > #nodes then
          target_x = lvl_pw + 50
          node, ffreeze = -1, 10
        else
          target_x, target_y = unpack(nodes[next_node])
          ffreeze = 10
        end
        next_node += 1
        attack = boss_phases[next_node]
        n.dash_time = 4
        n.djump = max_djump
        n.spd = vector(-2, -1)
        n.dash_accel_x, n.dash_accel_y = 0, 0
        off = 0
        local e = 20
        foreach(objects, function(n)
          if n.type == fall_plat or n.type == osc_plat and next_node - 1 == n.badestate then
            n.timer = e
            n.state = 0
            e += 15
          end
        end)
      elseif node ~= -1 and find_player() then
        hitbox = rectangle '-12,-12,32,32'
        --try to suck player in
        local hit = player_here()
        hitbox = rectangle '0,0,8,8'
        if hit then
          hit.spd = vector(mid(-2, 2, hit.spd.x), mid(-2, 2, hit.spd.y))
          hit.dash_time = 0
          hit.spd.x += hit.left() > right() and -.5 or hit.right() < left() and .5 or 0
          hit.spd.y += hit.top() > bottom() and -.35 or hit.bottom() < top() and .25 or 0
        end
        if attack == 1 and attack_timer % 60 == 0 then
          init_object(orb, flip.x and right() or left(), y + 4)
        elseif attack == 2 and attack_timer % 100 == 0 then
          laser = init_object(laser, x, y)
          laser.badeline = _ENV
        end
      end
    end
  end
  foreach(objects, function(n)
    if n.type == player and ffreeze == 0 then
      if n.x > x + 16 then
        flip.x = true
      elseif n.x < x - 16 then
        flip.x = false
      end
    end
  end)
end, draw = function(_ENV)
  for n = 1, 2 do
    pal(n, ffreeze == 0 and n or _g.frames % 2 == 0 and 14 or 7)
  end
  for n in all(split("1,-0.1 1,-0.4 2,0 2,0.5 1,0.125 1,0.375", " ")) do
    local d, e = unpack(split(n))
    for n = 0, 7 do
      circfill(x + (flip.x and 2 or 6) + 1.45 * n * cos(e), y + 3 + 1.45 * n * sin(e) + (ffreeze > 0 and 0 or sin((_g.frames + 3 * n + 4 * e) / 14)), split "2,2,1,1,1,1,1" [n], d)
    end
  end
  draw_obj_sprite(_ENV)
  pal()
  _g.anxiety = true
end}
orb = {init = function(_ENV)
  for n in all(objects) do
    if n.type == player then
      local n, e = n.x + 4 - x, n.y + 4 - y
      local d = sqrt(n ^ 2 + e ^ 2) * .65
      spdx, spdy = n / d, e / d
    end
  end
  init_smoke(-4 + 2 * sign(spdx), -4)
  hitbox, t, y_, particles = rectangle "-2,-2,5,5", 0, y, {}
end, update = function(_ENV)
  t += .05
  x += spdx
  y_ += spdy
  y = round(y_ + 1.5 * sin(t))
  local n = player_here()
  if n then
    kill_player(n)
  end
  if maybe() then
    add(particles, {x = x, y = y, dx = -rnd() * spdx, dy = -rnd() * spdy, c = 8, d = 15})
  end
  foreach(particles, function(n)
    n.x += n.dx
    n.y += n.dy
    if rnd() < .3 then
      n.c = split "7,8,14" [1 + flr(rnd "3")]
    end
    n.d -= 1
    if n.d < 0 then
      del(particles, n)
    end
  end)
end, draw = function(_ENV)
  foreach(particles, function(n)
    pset(n.x, n.y, n.c)
  end)
  local d, o, n = x, y, t
  for n = n, n + .08, .01 do
    pset(round(d + 6 * cos(n)), round(o - 6 * sin(n)), 8)
  end
  local f, t, e = cos(2 * n) <= -.5 and 1 or 0, cos(2 * n) > .5 and 1 or 0, 1 + flr(1.5 * n % 3)
  for n in all {2.001, round(1 - cos(1.5 * n))} do
    if n > 0 or e == 3 then
      if n ~= 2.001 and e == 3 then
        n = 2 - n
      end
      ovalfill(d - n - f, o - n - t, d + n, o + n, n ~= 2.001 and split "15,7,8" [e] or e == 2 and 8 or 2)
    end
    pal()
  end
end}

function find_player()
  for n in all(objects) do
    if n.type == player or n.type == player_spawn then
      return n
    end
  end
end

function line_dist(f, t, n, e, d, o)
  local d, o = d - n, o - e
  return abs(d * (e - t) - (n - f) * o) / sqrt(d ^ 2 + o ^ 2)
end

function rectfillr(d, o, f, t, n, i, r, a)
  local function e(e, d)
    e, d = e - i, d - r
    return vector(i + cos(n) * e - sin(n) * d, r + sin(n) * e + cos(n) * d)
  end

  local d, n, e = {e(d, o), e(d, t), e(f, t), e(f, o)}, 32767.99999, 32768
  for d in all(d) do
    n, e = min(n, d.y), max(e, d.y)
  end
  for n = ceil(n), e do
    local o, f = 32767.99999, 32768
    for t, e in pairs(d) do
      local d = d[1 + t % 4]
      if mid(n, e.y, d.y) == n then
        local n = e.x + (n - e.y) / (d.y - e.y) * (d.x - e.x)
        o, f = min(o, n), max(f, n)
      end
    end
    rectfill(o, n, f, n, a)
  end
end

function get_laser_coords(_ENV)
  return badeline.x + 4, badeline.y - 1, playerx + 4, playery + 6
end

laser = {layer = 3, init = function(_ENV)
  outline = false
  timer = 0
  particles = {}
end, update = function(_ENV)
  timer += 1
  local n = find_player()
  if n then
    if timer < 30 then
      playerx, playery = appr(playerx or badeline.x, n.x, 10), appr(playery or badeline.y, n.y, 10)
    elseif timer == 45 then
      if line_dist(n.x + 4, n.y + 6, get_laser_coords(_ENV)) < 6 then
        kill_player(n)
      end
    elseif timer >= 48 and #particles == 0 then
      destroy_object(_ENV)
      badeline.laser = nil
    end
    foreach(particles, function(n)
      n.x += n.dx
      n.y += n.dy
      n.d -= 1
      if n.d < 0 then
        del(particles, n)
      end
    end)
  else
    destroy_object(_ENV)
  end
end, draw = function(_ENV)
  local d = timer
  if d > 42 and d < 45 then
    return
  end
  if d < 48 then
    local n, e, o, f = get_laser_coords(_ENV)
    local o, f = n - o, e - f
    local r, a = n - 128 * o, e - 128 * f
    for d = 0, rnd "4" do
      local d = rnd()
      line(n, e, n + cos(d) * rnd "7", e + sin(d) * rnd "7", 7)
    end
    local t, i, l, c, h = n, e, sqrt(o ^ 2 + f ^ 2) * .1, d > 45 and 2 or .5, d >= 30 and d % 4 < 2 and 7 or 8
    line(n, e, n, e, 8)
    for n = 0, 10 do
      t -= o / l
      i -= f / l
      line(t + (rnd "10" - 5) * c, i + (rnd "10" - 5) * c, maybe() and 0 or d > 45 and h or 2)
      if d == 47 then
        for n = 1, 3 do
          add(particles, {x = t, y = i, dx = rnd() - .5, dy = rnd() - .5, d = 10})
        end
      end
    end
    if d < 45 or d == 47 then
      line(n, e, r, a, h)
      local o = d > 30 and d % 4 < 2 and 4 or 2
      for d = 1, 2 do
        circfill(n, e, o / d, 7 + d)
      end
    else
      for d = 1, 3 do
        rectfillr(n + 2, e + split "-4,-4,3" [d], n + 132, e + split "4,-3,4" [d], atan2(r - n, a - e), n, e, split "7,8,8" [d])
      end
      circfill(n, e, 4, 7)
    end
  end
  foreach(particles, function(n)
    pset(n.x, n.y, n.d > 4 and 8 or 2)
  end)
end}

function plat_draw(_ENV)
  local n, e = x, y
  if shake > 0 then
    n += rnd "2" - 1
    e += rnd "2" - 1
  end
  local d, o, f = n + hitbox.w - 8, e + hitbox.h - 8, 1.5 * timer - 4.5
  palt(0, false)
  palt(5, true)
  palt(14, true)
  if palswap then
    pal(12, 2)
    pal(7, 5)
    pal(6, 1)
  end
  if f > 0 and f < 12 and state == 0 then
    rect(n - f, e - f, d + f + 8, o + f + 8, 15)
  end
  for n = n, d, d - n do
    for n = e, o, o - e do
    end
  end
  spr(33, n, e)
  spr(35, d, e)
  spr(49, n, o)
  spr(51, d, o)
  for n = n + 8, d - 8, 8 do
    spr(34, n, e)
    spr(50, n, o)
  end
  for e = e + 8, o - 8, 8 do
    spr(32, n, e)
    spr(48, d, e)
  end
  for d = n + 8, d - 8, 8 do
    for o = e + 8, o - 8, 8 do
      spr((d + o - n - e) % 16 == 0 and 41 or 56, d, o)
    end
  end
  palt()
  pal()
end

fall_plat = {init = function(_ENV)
  while right() < lvl_pw - 1 and tile_at(right() / 8 + 1, y / 8) == 85 do
    hitbox.w += 8
  end
  while bottom() < lvl_ph - 1 and tile_at(x / 8, bottom() / 8 + 1) == 85 do
    hitbox.h += 8
  end
  collides, solid_obj, timer, shake, state, new = true, true, 0, 0, 0, false
end, update = function(_ENV)
  if timer > 0 then
    timer -= 1
    if timer == 2 then
      palswap = true
    end
    if timer == 0 then
      state += 1
      spd.y, shake = .4, 0
    elseif state == 0 then
      shake = 1
    end
  elseif state >= 1 then
    if spd.y == 0 then
      if not is_solid(0, 1) then
        new = false
      end
      if not new then
        for n = 0, hitbox.w - 1, 8 do
          init_smoke(n, hitbox.h - 2)
        end
        new, shake = true, 3
      end
      timer = 6
    end
    spd.y = appr(spd.y, 4, .4)
  end
end, draw = plat_draw}
osc_plat = {init = fall_plat.init, end_init = function(_ENV)
  hitbox.w += 8
  if not badestate then
    timer = 1
  end
  local n, e = targetx - x, targety - y
  local d = sqrt(n ^ 2 + e ^ 2)
  t, shake, palswap, startx, starty, dirx, diry = 0, 0, not badestate, x, y, n / d, e / d
end, update = function(_ENV)
  if timer > 0 then
    timer -= 1
    palswap, start = timer <= 2, timer == 0
  elseif start then
    if state == 0 then
      state = t == 0 and 1 or t == 40 and 2 or 0
    else
      local n, e, d = 1, targetx, targety
      if state == 2 then
        n, e, d = -1, startx, starty
      end
      spd = vector(mid(appr(spd.x, n * 5 * dirx, abs(.5 * dirx)), e - x, x - e), mid(appr(spd.y, n * 5 * diry, abs(.5 * diry)), d - y, y - d))
      if spd.x | spd.y == 0 then
        shake, state = 3, 0
        if is_solid(sign(n * dirx), 0) then
          for e = 0, hitbox.h - 1, 8 do
            init_smoke(sign(dirx) == n and hitbox.w - 1 or -4, e)
          end
        end
        if is_solid(0, sign(n * diry)) then
          for e = 0, hitbox.w - 1, 8 do
            init_smoke(e, sign(diry) == n and hitbox.h - 1 or -4)
          end
        end
      end
    end
    t += 1
    t %= 80
  end
  shake = max(shake - 1)
end, draw = plat_draw}
psfx = function(n)
  if sfx_timer <= 0 then
    sfx(n)
  end
end
spinner_controller = {spinners = {}, connectors = {}, layer = 0, init = function()
  spinner_controller.spinners, spinner_controller.connectors = {}, {}
end, end_init = function()
  for e, n in ipairs(spinner_controller.spinners) do
    for e = 1, e - 1 do
      local e = spinner_controller.spinners[e]
      local d, o = abs(n.x - e.x), abs(n.y - e.y)
      if d <= 16 and o <= 16 and d + o < 32 then
        add(spinner_controller.connectors, vector((n.x + e.x) / 2 + 4, (n.y + e.y) / 2 + 4))
      end
    end
  end
end, update = function()
  local n = find_player()
  if n and n.type == player then
    for e in all(spinner_controller.spinners) do
      if e.objcollide(n, 0, 0) then
        kill_player(find_player())
        break
      end
    end
  end
end, draw = function()
  foreach(spinner_controller.connectors, function(n)
    spr(28, n.x, n.y)
  end)
  foreach(spinner_controller.spinners, function(n)
    spr(13, n.x, n.y, 2, 2)
  end)
end}
spinner = {init = function(_ENV)
  if sprite % 2 == 0 then
    x -= 8
  end
  if sprite >= 29 then
    y -= 8
  end
  hitbox = rectangle "2,2,12,12"
  add(spinner_controller.spinners, _ENV)
  destroy_object(_ENV)
end}
tiles = {}
foreach(split([[
1,player_spawn
8,spring
10,fruit
12,refill
64,kevin
46,bumper
66,feather
27,feather
31,badeline
84,fall_plat
70,osc_plat
13,spinner
14,spinner
29,spinner
30,spinner
]], "\n"), function(n)
  local n, e = unpack(split(n))
  tiles[n] = _ENV[e]
end)

function init_object(n, e, d, f)
  local _ENV = setmetatable({}, {__index = _g})
  type, collideable, sprite, flip, x, y, hitbox, spd, rem, outline, draw_seed = n, true, f, vector(), e, d, rectangle "0,0,8,8", vector(0, 0), vector(0, 0), true, rnd()

  function left()
    return x + hitbox.x
  end

  function right()
    return left() + hitbox.w - 1
  end

  function top()
    return y + hitbox.y
  end

  function bottom()
    return top() + hitbox.h - 1
  end

  function is_solid(e, d, o)
    for n in all(objects) do
      if n ~= _ENV and (n.solid_obj or n.semisolid_obj and not objcollide(n, e, 0) and d > 0) and objcollide(n, e, d) and not (o and n.unsafe_ground) then
        return true
      end
    end
    return d > 0 and not is_flag(e, 0, 3) and is_flag(e, d, 3) or is_flag(e, d, 0)
  end

  function oob(n, e)
    return not exit_left and left() + n < 0 or not exit_right and right() + n >= lvl_pw or top() + e <= -8
  end

  function is_flag(e, d, n)
    for o = mid(0, lvl_w - 1, (left() + e) \ 8), mid(0, lvl_w - 1, (right() + e) / 8) do
      for e = mid(0, lvl_h - 1, (top() + d) \ 8), mid(0, lvl_h - 1, (bottom() + d) / 8) do
        local d = tile_at(o, e)
        if n >= 0 then
          if fget(d, n) and (n ~= 3 or e * 8 > bottom()) then
            return true
          end
        end
      end
    end
  end

  function objcollide(n, e, d)
    return n.collideable and n.right() >= left() + e and n.bottom() >= top() + d and n.left() <= right() + e and n.top() <= bottom() + d
  end

  function check(e, d, o)
    for n in all(objects) do
      if n.type == e and n ~= _ENV and objcollide(n, d, o) then
        return n
      end
    end
  end

  function player_here()
    return check(player, 0, 0)
  end

  function move(e, d, t)
    for n in all {"x", "y"} do
      rem[n] += vector(e, d)[n]
      local e = round(rem[n])
      rem[n] -= e
      local f = n == "y" and e < 0
      local d, o = not player_here() and check(player, 0, f and e or -1)
      if collides then
        local d, i = sign(e), _ENV[n]
        local f = n == "x" and d or 0
        for e = t, abs(e) do
          if is_solid(f, d - f) or oob(f, d - f) then
            spd[n], rem[n] = 0, 0
            break
          else
            _ENV[n] += d
          end
        end
        o = _ENV[n] - i
      else
        o = e
        if (solid_obj or semisolid_obj) and f and d then
          o += top() - bottom() - 1
          local n = round(d.spd.y + d.rem.y)
          n += sign(n)
          if o < n then
            d.spd.y = max(d.spd.y)
          else
            o = 0
          end
        end
        _ENV[n] += e
      end
      if (solid_obj or semisolid_obj) and collideable then
        collideable = false
        local f = player_here()
        if f and solid_obj then
          f.move(n ~= "x" and 0 or e > 0 and right() + 1 - f.left() or e < 0 and left() - f.right() - 1, n ~= "y" and 0 or e > 0 and bottom() + 1 - f.top() or e < 0 and top() - f.bottom() - 1, 1)
          if player_here() then
            kill_player(f)
          end
        elseif d then
          d.move(vector(o, 0)[n], vector(0, o)[n], 1)
        end
        collideable = true
      end
    end
  end

  function init_smoke(n, e)
    init_object(smoke, x + (n or 0), y + (e or 0), 24)
  end

  add(objects, _ENV);
  (type.init or time)(_ENV)
  return _ENV
end

function destroy_object(_ENV)
  del(objects, _ENV)
end

function kill_player(_ENV)
  _g.sfx_timer = 12
  sfx(17)
  _g.deaths += 1
  destroy_object(_ENV)
  for n = 0, .875, .125 do
    add(dead_particles, {x = x + 4, y = y + 4, t = 2, dx = sin(n) * 3, dy = cos(n) * 3})
  end
  foreach(fruitrain, function(n)
    if n.golden then
      _g.full_restart = true
    end
  end)
  _g.fruitrain = {}
  _g.delay_restart = 15
  _g.tstate = 0
end

function next_level()
  local n = lvl_id + 1
  load_level(n)
end

function load_level(n)
  has_dashed = false
  foreach(objects, destroy_object)
  cam_spdx, cam_spdy = 0, 0
  local e = lvl_id ~= n
  lvl_id = n
  local n = split(levels[lvl_id])
  lvl_x, lvl_y, lvl_w, lvl_h = n[1] * 16, n[2] * 16, n[3] * 16, n[4] * 16
  lvl_pw = lvl_w * 8
  lvl_ph = lvl_h * 8
  boss_phases = split(n[6], "/")
  local n = tonum(n[5]) or 1
  for e, d in inext, split "exit_top,exit_right,exit_bottom,exit_left" do
    _ENV[d] = n & .5 << e ~= 0
  end
  ui_timer = 5
  if e then
    if mapdata[lvl_id] then
      for i = 0, #mapdata[lvl_id] - 1 do
        mset(i % lvl_w, i \ lvl_w, ord(mapdata[lvl_id][i + 1]) - 1)
      end
    end
    reload()
  end
  init_object(spinner_controller, 0, 0)
  for e = 0, lvl_w - 1 do
    for d = 0, lvl_h - 1 do
      local n = tile_at(e, d)
      if tiles[n] then
        init_object(tiles[n], e * 8, d * 8, n)
      end
      if n >= 224 then
        init_object(garbage, e * 8, d * 8, n - 224)
      end
    end
  end
  foreach(objects, function(n)
    (n.type.end_init or time)(n)
  end)
  cam_offx, cam_offy = 0, 0
  for n in all(camera_offsets[lvl_id]) do
    local n, e, d, o, f, t = unpack(split(n))
    local n = init_object(camera_trigger, n * 8, e * 8)
    n.hitbox, n.offx, n.offy = rectangle("0,0," .. d * 8 .. "," .. o * 8), f, t
  end
end

function _update()
  frames += 1
  if time_ticking then
    seconds += frames \ 30
    minutes += seconds \ 60
    seconds %= 60
  end
  frames %= 30
  if music_timer > 0 then
    music_timer -= 1
    if music_timer <= 0 then
      music(10, 0, 7)
    end
  end
  if sfx_timer > 0 then
    sfx_timer -= 1
  end
  if delay_restart > 0 then
    cam_spdx, cam_spdy = 0, 0
    delay_restart -= 1
    if delay_restart == 0 then
      if full_restart then
        full_restart = false
        _init()
      else
        load_level(lvl_id)
      end
    end
  end
  foreach(objects, function(_ENV)
    move(spd.x, spd.y, type == player and 0 or 1);
    (type.update or time)(_ENV)
    draw_seed = rnd()
  end)
  foreach(objects, function(_ENV)
    if type == player or type == player_spawn then
      move_camera(_ENV)
      return
    end
  end)
end

function _draw()
  pal()
  cls '9'
  palt(0, false)
  sspr(0, 64, 32, 32, 0, 0, 128, 128)
  draw_x = round(cam_x) - 64
  draw_y = round(cam_y) - 64
  camera(draw_x, draw_y)
  if anxiety then
    cls '0'
--  fillp'0b0101101001011010'
--  for i=0,127,2 do 
--  offset=sin(frames/15+i/150)*3
--  for j=-16,256,12 do
--  local shrink=(150+(sin(j/4.5+frames/30)*30)-i)/16
--  if (shrink<=7.5) line(j+offset+shrink,i,j+offset+16-shrink,i,1)
--  line(j+offset+shrink,i,j+offset+15-shrink,i,(i>96 or i>80 and i<90 or i>70 and i<75 or i>64 and i<67 or i>60 and i%2==1) and 1 or 2)
--  end end	
--  fillp()
--  palt(2,true)
  end
  pal ''
  palt(2, true)
  palt(0, false)
  map(lvl_x, lvl_y, 0, 0, lvl_w, lvl_h, 4)
  palt()
  if anxiety then
--  pa'12,-1,2'
--  pa'8,1,2'
  end
  for n = 0, 15 do
    pal(n, 0)
  end
  pal = time
  foreach(objects, function(n)
    if n.outline then
      for e = -1, 1 do
        for d = -1, 1 do
          if e == 0 or d == 0 then
            camera(draw_x + e, draw_y + d)
            draw_object(n)
          end
        end
      end
    end
  end)
  pal = _pal
  camera(draw_x, draw_y)
  pal()
  palt()
  anxiety = false
  local e = {{}, {}, {}}
  foreach(objects, function(n)
    if n.type.layer == 0 then
      draw_object(n)
    else
      add(e[n.type.layer or 1], n)
    end
  end)
  pal ''
  palt(0, false)
  palt(2, true)
  map(lvl_x, lvl_y, 0, 0, lvl_w, lvl_h, 2)
  palt()
  foreach(e, function(n)
    foreach(n, function(_ENV)
      draw_object(_ENV)
      if bubble and bubbled then
        --oval(left()-4,top()-4,right()+4,bottom()+4,7)
        circ(x + 4, y + 3, 8, 7)
      -- 9 tokens smaller, looks off though.
      end
    end)
  end)
  for n = 0, lvl_w do
    for e = 0, lvl_h do
      if grass[tile_at(n, e)] and not grass[tile_at(n, e - 1)] and not not_grass[tile_at(n, e - 1)] then
        spr(60, n * 8, (e - 1) * 8)
      end
    end
  end
  map(lvl_x, lvl_y, 0, 0, lvl_w, lvl_h, 8)
  foreach(dead_particles, function(n)
    n.x += n.dx
    n.y += n.dy
    n.t -= .2
    if n.t <= 0 then
      del(dead_particles, n)
    end
    rectfill(n.x - n.t, n.y - n.t, n.x + n.t, n.y + n.t, 14 + 5 * n.t % 2)
  end)
  if ui_timer >= -30 then
    if ui_timer < 0 then
    end
    ui_timer -= 1
  end
  camera()
  color(0)
  if tstate == 0 then
    tlo += 14
    thi = tlo - 320
    po1tri(0, tlo, 128, tlo, 64, 80 + tlo)
    rectfill(0, thi, 128, tlo)
    po1tri(0, thi - 64, 0, thi, 64, thi)
    po1tri(128, thi - 64, 128, thi, 64, thi)
    if tlo > 474 then
      tstate = -1
      tlo = -64
    end
  end
  p "9,137"
  p "10,9"
  p "14,131"
  p "13,139"
  p "15,14"
  p "0,129"
  p "6,140"
--p"5,15"
end

function p(n)
  n = split(n)
  pal(n[1], n[2], 1)
end

function draw_object(_ENV)
  srand(draw_seed);
  (type.draw or draw_obj_sprite)(_ENV)
end

function draw_obj_sprite(_ENV)
  spr(sprite, x, y, 1, 1, flip.x, flip.y)
end

function two_digit_str(n)
  return n < 10 and "0" .. n or n
end

function round(n)
  return flr(n + .5)
end

function appr(n, e, d)
  return n > e and max(n - d, e) or min(n + d, e)
end

function sign(n)
  return n ~= 0 and sgn(n) or 0
end

function maybe()
  return rnd() < .5
end

function tile_at(n, e)
  return mget(lvl_x + n, lvl_y + e)
end

tstate, tlo = -1, -64

function po1tri(n, e, f, d, o, t)
  local i = n + (o - n) / (t - e) * (d - e)
  p01traph(n, n, f, i, e, d)
  p01traph(f, i, o, o, d, t)
end

function p01traph(n, e, d, o, f, t)
  d, o = (d - n) / (t - f), (o - e) / (t - f)
  for f = f, t do
    rectfill(n, f, e, f)
    n += d
    e += o
  end
end

--function pa(a)
--local t,q,l=unsplit(a)
--for i=1,15 do pal(i,t) end
--if l<0 then
--camera(draw_x+q,draw_y)
--else
--map(lvl_x,lvl_y,q,0,lvl_w,lvl_h,l)
--end
--end
-->8
--[map metadata]
--@conf
--[[
autotiles={{33, 35, 34, 32, 33, 35, 34, 32, 49, 51, 50, 48, 32, 48, 40, 41, [0] = 34, [28] = 57, [40] = 56}, {37, 39, 38, 36, 37, 39, 38, 36, 53, 55, 54, 52, 36, 52, 59, 42, [0] = 38, [28] = 58, [40] = 43}, {118, 102, 112, 96, 81, 83, 82, 96, 113, 115, 114, 112, 97, 99, 98, 37, 38, 39, 36, 87, 144, 145, 90, 91, 92, 93, 78, 53, 54, 55, 52, 103, 104, 105, 106, 107, 108, 109, 128, 32, 33, 34, 35, 119, 120, 121, 122, 123, 94, 95, 129, 48, 49, 50, 51, 116, 117, 100, 101, 146, 110, 111, 130, [0] = 98}}
composite_shapes={}
param_names={"phase/phase/phase/..."}
]]
--@begin

--level table
--"x,y,w,h,exit_dirs,phase/phase/phase/..."
--exit directions "0b"+"exit_left"+"exit_bottom"+"exit_right"+"exit_top" (default top- 0b0001)
--phase 1 (ball) or 2 (laser)

levels={
  "0,0,2,1,0b0010,0",
  "2,0,2,1,0b0010,0/1/2"
 
}
--<camtrigger>--
--camera trigger hitboxes
--"x,y,w,h,off_x,off_y"
camera_offsets={
  {},
  {}
}
--</camtrigger>--

--mapdata string table
--assigned levels will load from here instead of the map
mapdata={

}

--@end

function move_camera(obj)
  --<camtrigger>--
  cam_spdx,cam_spdy=cam_gain*(4+obj.x-cam_x+cam_offx),cam_gain*(4+obj.y-cam_y+cam_offy)
  --</camtrigger>--

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  --clamp camera to level boundaries
  local clamped=mid(cam_x,64,lvl_pw-64)
  if cam_x~=clamped then
    cam_spdx,cam_x=0,clamped
  end
  clamped=mid(cam_y,64,lvl_ph-64)
  if cam_y~=clamped then
    cam_spdy,cam_y=0,clamped
  end
end

--tiles to draw grass on
grass={}
foreach(split'36,37,38,39,52,53,54,55',function(t)
grass[t]=true
end)

not_grass={}
foreach(split'21,22,23,42,43,58,59',function(t)
not_grass[t]=true
end)


--copy mapdata string to clipboard
--function get_mapdata(x,y,w,h)

--  local reserve=""
--  for i=0,w*h-1 do
--    reserve..=num2base256(mget(i%w,i\w)+1)
--  end
--  printh(reserve,"@clip")
--end

--convert mapdata to memory data

--function num2base256(number)
--  return number%256==0 and "\\000" or number==10 and "\\n" or number==13 and "\\r" or number==34 and [[\"]] or number==92 and [[\\]] or chr(number)
--end


__gfx__
000000000000000000000000088888800000000000000000000000000000000000000000ee15513e0a0aa0a0000770000007700000000007007000000aa00000
000000000888888008888880888888880888888008888800000000000888888000000000e15005ee0aa88aa000700700007bb70000000000ff000070aa000000
00000000888888888888888888877778888888888888888008888880887177180000000013500511029999200700007007bbb3707000f0027f20070000000000
0000000088877778888777788871771888877778877778808888888888777778024444203155555309a99990700000077bbb3bb7070007ff2ff2ff0000000000
0000000088717718887177180877777088717718817717808887777888777778005005005005551509999a907000000773b33bb70fff2ff2f22ff00000000000
000000000877777008777770003333000877777007777780887777780833338000055000e0055005099a99900700007007333370002222ff22f2f70000000000
000000000033330000333300050000500533330000333350087177100033330000500500e555500e0299992000700700007337000002222ff2ff200000000000
000000000050050000500050000000000000050000005000055333500050050000055000e115111100299200000770000007700000ff2ff22222f22000000000
22222222eeeeee1349994999499949994999499911311311111bbb111331331100000000000000007000000000777700022f22f077f2f22f22f227f000000000
22222222ee1ee13e44444444444444444444444413313331331bb3313133b3310077000007700700070000070700aa70fff22f2f020f22f2ff2ffff702222220
22222222e13ee3ee0004200000000000000240001b33b331b331b33333133bb1007770700777000000000000700aaa072fff2ff20000f272f272200022222222
2222222213eeeeee00420000000000000000240033b33bb11b311b333331311307777770077000000000000070959007f2f22222000ff72f2f27700025555222
222261223eee61ee04200000000000000000024031bb313333b111b313311b13077777700000700000000000705900072222222f002ff02ff22ff20028558522
22cc6612eecc661e420000000000000000000024b11b1333333133111b133bb107777770000007700000000070500007f22222ff0072000f0000f70005555520
2cc66662ecc6666e2000000000000000000000021bb3b33bb33133311bb333bb070777000007077007000070070e0070f2222f2f070000007000007000111110
cc666661cc6666610000000000000000000000001b133bb11b11b33311bb3331000000007000000000000000007777000ff2fff0000000002000000000050005
7cc1c1005771777777cc1777777717757133311117777b7777b77b77777b777111000000000006603313311111333111ee11eeeee33d111e0000000011100111
77cc1c10777c177cc771cc77c771c7777bb331bb7bbb33111bb1bbb11bbb331711100000006600663313311113331331e1e311ee1ed3dd110000011100000000
777cc1c177ccc1cccccc1ccccc11cc77bbb31bb3711bb31113bb3bb111bbb31701100110006cc00611111331333133311e3d3e11e1ee3de1000015ec01100110
177ccc1c77cccc1ccccc1ccccccc1cc77b311b317b1133b1bb3bb331b1133b1700000110000ccc00133113333311331113d33ebeee11ebe10001ceec00e99e00
7c1cccc11cccccc11cccc11c1cccc1c7731113bb7bb1133bb133b11bbb1133b7001100000000ccc013331133111111131edd3ed1e3e11e1e001ccc11099ee990
77c1ccc071ccccc111ccc11111cccc1771bb1bbb71111bb131131b1b1111bb1700111000cc000c661133111333313313113eebd1ee3e11ed015ec1440e1111e0
777c11007711ccc101111000011cccc17bbb1bb3733311bb133b3bb133311bb700011100cc6000663111333113333311e111ddb1eee1eedb01ee14c400e99e00
177c1000ccc11111001100000011ccccbbb311317b33b11b131bb311b33b11b70000110006600000331113311113311113311bd1ee1edbbe01cc14c200099000
0ccc17711111cccc0ccccccc1cccccc111133317bb3bb1b11bb1bb111113331700066000000c0000331113333311111100000000e11eeeee01cc144411000011
01ccc1717ccc1cccccccccccc1cccc71bb133bb77bb3b1bbb1bb3bb1bb133bb700066c0000cc60003311133113111ee100000000e1edddbe01ee124c01100110
111c77107cccc1ccccc1cccccc1ccc713bb13bbb7bb1313bbb1bb3313bb13bbb66006cc000066c001133111111133eee000000001eebdbe1015ec1240c0000c0
1cc1777117cccc1ccccc1cccccc1ccc713b113b7b33b1b13bbb1b11b13b113b76cc006c66600cc6033333111111133ee000000b0111eebe1001ccc110cc99cc0
cccc1771717ccc1c1cccc1ccccc71c77bb31113b71333bb11bb1131bbb31113b0ccc00666cc006603313331111111311b00b00b0ee111e1e0001ceec09eeee90
ccccc1117717cc11c1c7c711ccc77171bbb1bb17731133bb131b3331bbb1bb1700cc60000ccc00001111331111111ee1b0b003b0e3ee111e000015ec0e4114e0
1cccc71017c1cc1c771777cc1ccc77113bb1bbb773b13333133bb3333bb1bbb766066000c0cc60001331113311311eeeb3b03b30eed3e11e000001110e1111e0
01cc7771e111111171117cc10111111e13113bbb777177717177771117777777066000000c06600013331113113311eeb3bb3b3be13d1ee10000000000eeee00
0992cc5445cccc5400aaa0000099aa0000999aa0000aaa0057777777eeeeeeeeee1ee111111eee1eeeeeeeee1eeeeeeeeeeeeee1eeeeeeeeeeee0000eeee13ee
9245cc2442cccc2409aaa900099aaaa0099aaaaa00aaaaa078807277eee1111ee1e111dd331111eeeee1eee13eee11eeeeeeee13eeee1eeeeee000000ee13eee
942ecc22221ee12201aaa1009911aaaa995aaa11009a5a907870222cee111d1e1111d3bdd33111eeee13ee13111111eeeeeee13eee111eeeee000ee11e13eeee
25e5ee11111111110111110091110aa095aa0001009a5a907000c2c2e11ddd1e11dddd3bd333111ee13ee11113dd11e1eeee13eeee111eeeee0001eeee3eee1e
cccec12222222222011111009110000095a000000099599077ccc2cc1ddbd31e1dddddd3b311111113ee113dddd31113ee1e3eeee0001ee1ee18011110eee13e
ccce112444444444011111001100000095a000000099599077c2c2c21bd3331e1ddddddd311111113ee11dddddb3113eee11eee1e0001e13eee80011001ee3ee
52212244444444440011100010000000095000000009590077cc222c1333111e11ddddb311111111eee13ddddb3111eee111ee131100013eee08800000111eee
44212444444444440000100010000000005000000005000077ccc2cc11111eeee1ddb13d11110001eee1dddd333111eee1100e31100113e0ee8888ee000111ee
44212444222ddd23ddd33dd3dd22ddd257777777777777772223d222eee1eeeee11d131d3110001eee11ddb3333111eeee10031000011000ee8888e08ee0111e
5221244422ddddd1dd11ddddddd11ddd78807877700877772233ddd2ee13eeeeee113ddd111111eee111db33333111eeee00880880010001e10080e888e8001e
cc11244421dd31131dd11dd1dddd31d37870c8ccc0c8cccc2ddeddd2e13eee1eeee1bddd110001ee131d3333331111eeee0084a48000011113e001e080e8800e
cce124443313113331313311d11133137000c8ccc888ccccdddee333e3eee13eeee11ddd11001eee3e1b333311311ee1e0084a900000011e3ee001ee0ee8011e
cce124441dd331eee3133e33e3131dd377ccc8ccccccccccdd33ee33eeee133eee1e1bdd1101eeeeee1111111dd11e13e10880480000111eee0010110e00011e
cc112444ddd31eeeee3eee3eeee1ddd377c8c8c8cccccccc233eeeddeee133eee13e11bd1111ee1eee1133311111113ee1000088000111eee0010111110001e1
52212444dddd1eeeeeeeeeeeeee11dd277cc888cccccccccddeee3ddeee13eee13eee11b1111e13ee1311d33111113eeee10000000111eee0110010110011e13
442124443ddd3eeeeeeeeeeeeeee1d3277ccc8ccccccccccddde3dddeeeeeeee3eeeee11111e13eee3ee11d331111eeeee1100001111eeee100000000011ee3e
ddd3eddd2133e3eeeeeeeeeeee31ddd2eeeeee1eeeeeee1e22dd3322ee1ee13eeeeeeeeeeeeeeeeeeeeee1d313111ee1eeeee13eeeeeeeeeeeeeeee13eee13ee
dd3eeedd1dd113eeeeeeeeeeee3e1dd3ee1ee13eeee1e13eddde3dd3e13e13eeeee1111111eeee1eeeee11113d111e1deeee13eeeeeee1eeeeeeee13eee13eee
ddeee332ddd333eeeeeeeeeeeee31ddde13e13eeee1313eeddd33ddd13e13ee1ee111ddd11eee13eeee13e13d1111133ee1100eeeeee13eeeeeee13eeee3eee1
33ee33dddd13e3eeeeeeeeeeeee131dd13ee3eeee13e3ee33eeeedd23ee3ee13e131dddd11ee13eeee13ee11d11113eee111100eeee13eee888803eeeeeeee13
333eeddd211d3eeeeeeeeeeeeee331dd3ee1eeee33eeee1eede3e332ee1ee13e1311dddd11ee3e1ee13eee11111113eeeee0000eee13e888888000eeeeeee13e
2dddedd22ddd1eeeeeeeeeeeeee1e312ee13e3d1d33ee13edddedd33e13e13ee311ddddd111ee13e13eee13e11113eeeeeeee00ee13e000888808888eeee13ee
2ddd3322dddd1eeeeeeeeeeeeee31dd2e13ee3dd1dde13eedd3dddd3e3ee3eeee1ddddb1b11e1d3e3eee13eee113eeeeee111011e3ee880088a908888ee13eee
222d32223dd13eeeeeeeeeeeee31ddd2e3ee3d111d1e3eee3322d322eeeeeeeee1dddb1331111eeeeeee3eeeee3eeeee11110011eeee8880a99a90888e13eeee
2222222223d1eeeeeeeeeeeeeee3ddd3ee1edd1333dd1eee223d2233eeeeeeeee1ddd1333d3d1eee2222288213eee88e111000011ee8888099440000883eeeee
287888222dd11eeeeeeeeeeeeee1dddde13e1d13111d3eee3dddd3ddee133eeee11d1b33d3d11eee2881888838818888000000011ee888800000088000eeeee1
888887823ddd1eeeee1eee13eee13ddde3eedd1dddd3ee1e33ddeddde1333ee1ee11b333d11d1eee888991128889911e0000000000eee800088808880eeeee13
878878883dd1313ee3313133ee133dd1ee1e33dddd13e13e233e3ede1333ee13ee11333d13d11ee1889aa882889aa883000ee0000011001088880088eeeee13e
187888873133111d3113313e33113133e13eee31e13e13ee2ddeeee3133ee13eee1133d1d111ee1321aa9888e1aa98880eeee13e0000000008888e13eeee13ee
218878813d13dddd3ddd13d13113dd1213eee13313e13e1eddd33dddeeee13eee1e11d1111eee13e28881880188818800eee13eeeee00e0eeeeee13eeee13eee
22049012ddd11ddd1dddd1dd1ddddd223eee13ee3ee3e13e3dd3edddeeee3eee13ee111eeeee13ee288810023888100eeee13eeeeee13e00000e13eeee13eeee
209944022ddd22dddddd2ddd32ddd222eeeeeeeeeeee13ee2233dd22eeeeeeee3eeeeeeeeeee3eee22810022ee8100eeeee3eeeeeee3eee000ee3eeeee3eeeee
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa21122222e1013e13222e2222222222222222222222222222220000112222222222222222110000222222222222222222
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa210222221013e13e22ede222221222222222222222222221100000011222222222222221100000011222222222222222
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa21882222318813ee22ede12221e122222222222222222110000000001112222222222111000000000112222222222222
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa21888008e18880082ed3ee121ede12222222222222211100000222200112222222222110022220000011122222222222
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa2108aa88e018aa882e3e3ee11ebbe2222222222222111000022222222011222222221102222222200001112222222222
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa2100aa001100aa002e33ede1eddd3e222222222221110000222222222201122222211022222222220000111222222222
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa20880888308808882e3e3ddeeedbbbe2dd222222211000022221110222011222222110222011122220000112222222dd
99999aaaaaaaaaaaaaaaaaaaaaaaaaaa28880882e888088e2ede3eee11ee3de2ddd1122211000022221110022200122222210022200111222200001122211ddd
9999999999aaaaaaaaaaaaaaaaaaaaaa22802222ee8103ee2ed3ee111e11ee12d1dd33300000022222110022000112222221100022001122222000000333dd1d
9999999999999999aaaaaaaaaaaaaaaa22102822e11038ee2eee111ee3e11e22d1113d0000002222221000000001222222221000000001222222000000d3111d
9999999999999999999aaaaaaaaaaaaa2221888213e1888e2e111eedd33e11221e3e1e1100022222222000000012222222222100000002222222200011e1e3e1
9999999999999999999999aaaaaaaaaa288088823880888e211eeed3bdbbe12231e1e111000222222222000000222222222222000000222222222000111e1e13
99999999999999999999999999999aaa8889a0028889a00e1eedd33dddbdde12e11111100022222222222022022222222222222022022222222222000111111e
99999999999999999999999999999999288a9882e88a988111ed3333ddd3bbe21111110000222222222220220222222222222220220222222222220000111111
9999999999999999999999999999999920998882e09988832111e3333d3deee21111100102222222222200120222222222222220210022222222222010011111
99999999999999999999999999999999888088228880883e11eeee3ee11111221110000112222222222211d102222222222222201d1122222222222110000111
9999999999999999999999999999999921002222e100eee111eeee3ee111112211000002100e01102200dddd1222222222222221dddd0022e33d111e20000011
9999999999999999999999999999999922110022ee1000132111e3333d3deee20000002210e0110020111dd331222222222222133dd111021ed3dd1122000000
9999999999999999999999999999999922221022e13e103e11ed3333ddd3bbe20000d32211e11e1e20001133312222222222221333111002e1ee3de1223d0000
999999999999999999999999999999992222210213e1e00e1eedd33dddbdde1200ddd22211e1e2e020000113311222222222211331100002ee11ebe1222ddd00
aaaaa999999999999999999999999999222220023e13e101211eeed3bdbbe122311ed2221e1112e221dd000000122222222221000000dd12e3e11e1e222de113
aaaaaaaaa9999999999999999999999922211012e13110032e111eedd33e11223e1dd322e22112e2221d33e000002222222200000033d1222e3e11ed223dd1e3
aaaaaaaaaaaaaaaaaaaaa9999999999922110022e311003e2eee111ee3e11e22e31ddd22e22212e2222133300002222222222000033312222ee1eedb22ddd13e
aaaaaaaaaaaaaaaaaaaaaaa99999999920112222e00003ee2ed3ee111e11ee12e131dd2202221202222213131002222222222001313122222e1edbbe22dd131e
aaaaaaaaaaaaaaaaaaaaaaaaaa999999e0010eeeee13eee12ede3eee11ee3de2e331dd222222022222222131102222222222220113122222211eeeee22dd133e
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9ee0010eee13eee132e3e3ddeeedbbbe2e1e313222222122222222212222222222222222221222222e1edddbe22313e1e
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeeee100ee311113e2e33ede1eddd3e22e31dd22222221222222222222222222222222222222222220eebdbe1222dd13e
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1eee000ee171711e2e3e3ee11ebbe22231ddd2222222122222222222222222222222222222222222111eebe1222ddd13
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa3e1000eee1aa111e2ed3ee121ede12223d2222222222122222222222222222222222222222222222ee111e12222222d3
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1d013dd31177711122ede12221e12222ddd222222222222222222222222222222222222222222222e3ee111222222ddd
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaad013d1d11a77a11122ede22222122222d222222222222222222222222222222222222222222222222ed3e11e2222222d
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaad0033d1dea55a11e222e222222222222222222222222222222222222222222222222222222222222e13d1ee122222222
22111111111111e22e11111111111222ee111111111111eeee11111111111eee111eeb112222222222222222d1d13eeee31eeeeeeee13eeeeeeeee1eeeeeeee1
22eee1111dbbe112e33e33eeeeeee222eeeee1111dbbe11ee33e33eeeeeeeeeeee111db1222222222222222d1ddd11eeee31eeeeee13eeee0000013eee118813
2e33e3ddeddbbde22e333333dddde222ee33e3ddeddbbdeeee333333ddddeeeeed3eedde2222222222222222d1dd1eeeee0011eee13eeee0000000888118888e
e3e333de1ddddde22ee3e3ddddbde222e3e333de1dddddeeeee3e3ddddbdeeeee3ed3ede2222222222208888dd1d1eeee001111e13eee1e00ee000e88844881e
ee33d33e3ddbdde222111eeeebbdde22ee33d33e3ddbddeeee111eeeebbddeee1e3deebe2222222222000888888e31eee0000eee3eee13e0ee1e00004a994111
e33dd3e1ebbddde222ee11111eeebe22e33dd3e1ebbdddeeeeee11111eeebeee0edeeee122222222888808888000e31ee00eeeeeeee13eeee13e110088a888ee
e3bdee111ebdddde22edeeee1111ee22e3bdee111ebddddeeeedeeee1111eeee01ee11e02222222888809a880088ee3e110111eeeee0008813ee11088884888e
edee11ee11edbdde22edde33eeee1122edee11ee11edbddeeeedde33eeee11ee00e100e0222222288809a99a0888eeee11001111e0ee088880ee1100880eeee1
ee11ee3ee11ebbbe2e333333dbddeee2ee11ee3ee11ebbbeee333333dbddeeee00e100e0222222880000449908888ee110000111008849940001110000e01113
11ee333dbde1ebbe2e33d33dbeeee11211ee333dbde1ebbeee33d33dbeeee11e01ee11e0222222000880000008888ee110000000088889a88001100000011111
e333d111edbe1eee2eeddd3ee1111122e333d111edbe1eeeeeeddd3ee11111ee0edeeee12222222088808880008eee00000000000884aa8888000000001111ee
1111ee1111bbe11e2eeddee11e11ee221111ee1111bbe11eeeeddee11e11eeee1e3deebe222222228800888801001100000ee00000088848800000000011eee1
22ee33eee11edde22e3de11eede11ee2eeee33eee11eddeeee3de11eede11eee13dd3ede222222222228888000000000e31eeee010088800010000000111ee13
e13e333dbee11beee33e11e3ddbe11e2e13e333dbee11beee33e11e3ddbe11ee113eebde222222222222222dd0d00eeeee31eee01100800111110000111ee13e
133dd3dbbddeee112ee113e3beeee112133dd3dbbddeee11eee113e3beeee11ee111ddbe222222222222200000d3333eeee31eee1110000011100011111e13ee
1eeee1111eee1112222eeeeee11111121eeee1111eee111eeeeeeeeee111111eeee11bde22222222222222000d1dd3eeeeee3eeee11110000000011111ee3eee
00888800000008000088880000888800008008000088880000800000008888000088880000888800008888000088880000888800008880000088880000888800
00800800000008000000080000000800008008000080000000800000000008000080080000800800008008000080080000800000008008000080000000800000
00800800000008000000080000000800008008000080000000800000000008000080080000800800008008000080080000800000008008000080000000800000
00800800000008000088880000888800008888000088880000888800000008000088880000888800008888000088800000800000008008000088880000888800
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00800800000008000080000000000800000008000000080000800800000008000080080000000800008008000080080000800000008008000080000000800000
00888800000008000088880000888800000008000088880000888800000008000088880000000800008008000088880000888800008880000088880000800000
00cccc0000000c0000cccc0000cccc0000c00c0000cccc0000c0000000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000ccc00000cccc0000cccc00
00c00c0000000c0000000c0000000c0000c00c0000c0000000c0000000000c0000c00c0000c00c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000000c0000000c0000c00c0000c0000000c0000000000c0000c00c0000c00c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000cccc0000cccc0000cccc0000cccc0000cccc0000000c0000cccc0000cccc0000cccc0000ccc00000c0000000c00c0000cccc0000cccc00
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00c00c0000000c0000c0000000000c0000000c0000000c0000c00c0000000c0000c00c0000000c0000c00c0000c00c0000c0000000c00c0000c0000000c00000
00cccc0000000c0000cccc0000cccc0000000c0000cccc0000cccc0000000c0000cccc0000000c0000c00c0000cccc0000cccc0000ccc00000cccc0000c00000
__label__
3311111133111111113331113311133311b11b111bb1bb111113331fjjjjjjjjjjjjjj1jjjj1jjjjjjjjjjjj7cc1c1hhhhhhhssh11hhhhhh11hhhhhh11hhhhhh
13111jj113111jj113331331331113311bb1bbb1b1bb3bb1bb133bbfjjjjjjjjjjj1j13jjj13jjjjjj133jjj77cc1c1hhhsshhss111hhhhh111hhhhh111hhhhh
11133jjj11133jjj333133311133111113bb3bb1bb1bb3313bb13bbbjj1jjj13jj1313jjj13jjj1jj1333jj1777cc1c1hhscchhsh11hh11hh11hh11hh11h11hh
111133jj111133jj3311331133333111bb3bb331bbb1b1bb13b113bfj3313133j13j3jj3j3jjj13j1333jj13177ccc1chhhccchhhhhhh11hhhhhh11hhhhh111h
11111311111113111111111333133311b133b1bbbbbb13bbbb31113b3113313j33jjjj1jjjjj133j133jj13j7c1cccc1hhhhccchhh11hhhhhh11hhhhh11hh11h
11111jj111111jj1333133131111331131131bbbb3bbb3b1bbb1bb1f3rrr13r1r33jj13jjjj133jjjjjj13jj77c1ccchcchhhcsshh111hhhhh111hhhh111hhhh
11311jjj11311jjj1333331113311133133b3bb3b3bb3b333bb1bbbf1rrrr1rr1rrj13jjjjj13jjjjjjj3jjj777c11hhccshhhsshhh111hhhhh111hhhh11hhhh
113311jj113311jj1113311113331113131bb331b3bb3b3b1fffffffrrrr9rrr1r1j3jjjjjjjjjjjjjjjjjjj177c1hhhhsshhhhhhhhh11hhhhhh11hhhhhhhhhh
113331113311133311333111111333111bb1bb111113331f999999999999999993r1jjjjjjjjjj1jjjj1jjjj1111cccchccccccchhhhhsshhhhchhhh11hhhhhh
133313313311133113331331bb133bb1b1bb3bb1bb133bbf99999999999999999rr11jjjjjj1j13jjj13jjjj7ccc1ccccccccccchhsshhsshhccshhh111hhhhh
3331333111331111333133313bb13bbbbb1bb3313bb13bbb99999999999999993rrr1jjjjj1313jjj13jjj1j7cccc1ccccc1cccchhscchhshhhsschhh11hh11h
33113311333331113311331113b113bbbbb1b1bb13b113bf99999999999999993rr1313jj13j3jj3j3jjj13j17cccc1ccccc1ccchhhccchhsshhccshhhhhh11h
111111133313331111111113bb3b11bbbbbb13bbbb31113b99999999999999993133111r33jjjj1jjjjj133j717ccc1c1cccc1cchhhhccchscchhsshhh11hhhh
333133131111331133313313bbb1b3b1b3bbb3b1bbb1bb1f99999999999999993r13rrrrr33jj13jjjj133jj7717cc11c1c7c711cchhhcsshccchhhhhh111hhh
133333111331113313333311b3b13b31b3bb3b333bb1bbbf9999999999999999rrr11rrr1rrj13jjjjj13jjj17c1cc1c771777ccccshhhsschccshhhhhh111hh
111331111333111311133111b3bb3b3bb3bb3b3b1fffffff99999999999999999rrr99rr1r1j3jjjjjjjjjjjj111111171117cc1hsshhhhhhchsshhhhhhh11hh
11b11b111bb1bb111bb1bb111bb1bb111113331f9999999999999999999999999999999993r1jjjjjjjjjj1jjjjjjjjjjjjjjjjj1111cccchccccccchhhchhhh
1bb1bbb1b1bb3bb1b1bb3bb1b1bb3bb1bb133bbf999999999999999999999999999999999rr11jjjjjj1j13jjj133jjjjjjjjjjj7ccc1ccccccccccchhccshhh
13bb3bb1bb1bb331bb1bb331bb1bb3313bb13bbb999999999999999999999999999999993rrr1jjjjj1313jjj1333jj1jjjjjjjj7cccc1ccccc1cccchhhsschh
bb3bb331bbb1b11bbbb1b11bbbb1b11b13b113bf999999999999999999999999999999993rr1313jj13j3jj31333jj13jjjjjjjj17cccc1ccccc1cccsshhccsh
b133b1bb1bb1131b1bb1131b1bb1131bbb31113b999999999999999999999999999999993133111r33jjjj1j133jj13jjjjjjjjj717ccc1c1cccc1ccscchhssh
31131bbb131b3331131b3331131b3331bbb1bb1f999999999999999999999999999999993r13rrrrr33jj13jjjjj13jjjjjjjjjj7717cc11c1c7c711hccchhhh
133b3bb3133bb333133bb333133bb3333bb1bbbf99999999999999999999999999999999rrr11rrr1rrj13jjjjjj3jjjjjjjjjjj17c1cc1c771777ccchccshhh
131bb331f1ffff11f1ffff11f1ffff111fffffff999999999999999999999999999999999rrr99rr1r1j3jjjjjjjjjjjjjjjjjjjj111111171117cc1hchsshhh
1113331f11hhhhhh11hhhhhhhccc1771999999999999999999hhhh1199999999999999999999999993r1jjjjjjjjjjjjjjjjjj1jjjj1jjjjjj1jj13j1111cccc
bb133bbf111hhhhh111hhhhhh1ccc17199999999999999911hhhhhh11999999999999999999999999rr11jjjjjjjjjjjjjj1j13jjj13jjjjj13j13jj7ccc1ccc
3bb13bbbh11hh11hh11hh11h111c771h999999999999911hhhhhhhhh1119999999999999999999993rrr1jjjjj1jjj13jj1313jjj13jjj1j13j13jj17cccc1cc
13b113bfhhhhh11hhhhhh11h1cc1777199999999999111hhhhh9999hh119999999999999999999993rr1313jj3313133j13j3jj3j3jjj13j3jj3jj1317cccc1c
bb31113bhh11hhhhhh11hhhhcccc17719999999999111hhhh99999999h11999999999999999999993133111r3113313j33jjjj1jjjjj133jjj1jj13j717ccc1c
bbb1bb1fhh111hhhhh111hhhccccc111999999999111hhhh9999999999h1199999999999999999993r13rrrr3rrr13r1r33jj13jjjj133jjj13j13jj7717cc11
3bb1bbbfhhh111hhhhh111hh1cccc71hrr999999911hhhh9999111h999h119999999999999999999rrr11rrr1rrrr1rr1rrj13jjjjj13jjjj3jj3jjj17c1cc1c
1fffffffhhhh11hhhhhh11hhh1cc7771rrr1199911hhhh9999111hh999hh199999999999999999999rrr99rrrrrr9rrr1r1j3jjjjjjjjjjjjjjjjjjjj1111111
11hhhhhh11hhhhhhhhhchhhhhccc1771r1rr333hhhhhh9999911hh99hhh119999999999999999999999999999999999993r1jjjjjjjjjj1jjjjjjj1jjjj1jjjj
111hhhhh111hhhhhhhccshhhh1ccc171r1113rhhhhhh9999991hhhhhhhh19999999999999999999999999999999999999rr11jjjjjj1j13jjj1jj13jjj13jjjj
h11hh11hh11hh11hhhhsschh111c771h1j3j1j11hhh99999999hhhhhhh199999999999999999999999999999999999993rrr1jjjjj1313jjj13j13jjj13jjj1j
hhhhh11hhhhhh11hsshhccsh1cc1777131j1j111hhh999999999hhhhhh999999999999999999999999999999999999993rr1313jj13j3jj313jj3jjjj3jjj13j
hh11hhhhhh11hhhhscchhsshcccc1771j111111hhh99999999999h99h9999999999999999999999999999999999999993133111r33jjjj1j3jj1jjjjjjjj133j
hh111hhhhh111hhhhccchhhhccccc111111111hhhh99999999999h99h9999999999999999999999999999999999999993r13rrrrr33jj13jjj13j3r1jjj133jj
hhh111hhhhh111hhchccshhh1cccc71h11111hh1h99999999999hh19h999999999999999999999999999999999999999rrr11rrr1rrj13jjj13jj3rrjjj13jjj
hhhh11hhhhhh11hhhchsshhhh1cc7771111hhhh119999999999911r1h9999999999999999999999999999999999999999rrr99rr1r1j3jjjj3jj3r11jjjjjjjj
11hhhhhh11hhhhhhhhhhhssh1cccccc111hhhhh99999999999hhrrrr19999999999999999999999999999999999999999999999993r1jjjjjjjjjj1jjjjjjjjj
111hhhhh111hhhhhhhsshhssc1cccc71hhhhhh99999999999h111rr33199999999999999999999999999999999999999999999999rr11jjjjjj1j13jjjjjjjjj
h11hh11hh11hh11hhhscchhscc1ccc71hhhhr399999999999hh111333199999999999999999999999999999999999999999999993rrr1jjjjj1313jjjjjjjjjj
hhhhh11hhhhhh11hhhhccchhccc1ccc7hhrrr999999999999hhhh1133119999999999999999999999999999999999999999999993rr1313jj13j3jj3jjjjjjjj
hh11hhhhhh11hhhhhhhhccchccc71c77311jr9999999999991rrhhhhhh19999999999999999999999999999999999999999999993133111r33jjjj1jjjjjjjjj
hh111hhhhh111hhhcchhhcssccc771713j1rr39999999999991r33hhhhhh999999999999999999999999999999999999999999993r13rrrrr33jj13jjjjjjjjj
hhh111hhhhh111hhccshhhss1ccc7711j31rrr99999999999991333hhhh999999999999999999999999999999999999999999999rrr11rrr1rrj13jjjjjjjjjj
hhhh11hhhhhh11hhhsshhhhhh111111jj131rr9999999999999913131hh9999999999999999999999999999999999999999999999rrr99rr1r1j3jjjjjjjjjjj
11hhhhhhhhhchhhh1cccccc1jjjjjjjjj331rr9999999999999991311h99999999999999999999999999999999999999999999999999999993r1jjjjjjjjjj1j
111hhhhhhhccshhhc1cccc71jjjjjjjjj1j313999999999999999919999999999999999999999999999999999999999999999999999999999rr11jjjjjj1j13j
h11hh11hhhhsschhcc1ccc71jj1jjj13j31rr9999999999999999999999999999999999999999999999999999999999999999999999999993rrr1jjjjj1313jj
hhhhh11hsshhccshccc1ccc7j331313331rrr9999999999999999999999999999999999999999999999999999999999999999999999999993rr1313jj13j3jj3
hh11hhhhscchhsshccc71c773113313j3r9999999999999999999999999999999999999999999999999999999999999999999999999999993133111r33jjjj1j
hh111hhhhccchhhhccc771713rrr13r1rrr999999999999999999999999999999999999999999999999999999999999999999999999999993r13rrrrr33jj13j
hhh111hhchccshhh1ccc77111rrrr1rrr9999999999999999999999999999999999999999999999999999999999999999999999999999999rrr11rrr1rrj13jj
hhhh11hhhchsshhhh111111jrrrr9rrr999999999999999999999999999999999999999999999999999999999999999999999999999999999rrr99rr1r1j3jjj
hhhchhhh1cccccc19999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999993r1jjjj
hhccshhhc1cccc71999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999rr11jjj
hhhsschhcc1ccc71999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999993rrr1jjj
sshhccshccc1ccc7999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999993rr1313j
scchhsshccc71c77999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999993133111r
hccchhhhccc77171999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999993r13rrrr
chccshhh1ccc771199999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999rrr11rrr
hchsshhhh111111j9999999999999999999999999999999999999999999999999999999h99h9999999999999999999999999999999999999999999999rrr99rr
1cccccc1jj31rrr9999999999999999999999999999999999999999999999999999999h7hh7h99h9999999999999999999999999999999999999999999999999
c1cccc71jj3j1rr3999999999999999999999999999999999999999999999999h999h99heeh99h7h999999999999999999999999999999999999999999999999
cc1ccc71jjj31rrr99999999999999999999999999999999999999999999999h7h9hehh27e2hh7h9999999999999999999999999999999999999999999999999
ccc1ccc7jjj131rr999999999999999999999999999999999999999999999999h7hhh7ee2ee2eeh9999999999999999999999999999999999999999999999999
ccc71c77jjj331rr999999999999999999999999999999999999999999999999heee2ee2e22eeh99999999999999999999999999999999999999999999999999
ccc77171jjj1j3199999999999999999999999999999999999999999999999999h2222ee22e2e7h9999999999999999999999999999999999999999999999999
1ccc7711jjj31rr999999999999999999999999999999999999999999999999999h2222ee2ee2hh99999999999999999999hh999999999999999999999999999
h111111jjj31rrr999999999999999999999999999999999999999999999999hhhee2ee22222e22h999999999999999999h77h99999999999999999999999999
jjj1jjjjjj31rrr99999999999999999999999999999999999999999999999h777e2e22e22e227eh99999999999999999h7bb7h9999999999999999999999999
jj13jjjjjj3j1rr39999999999999999999999999999999999999999h999h99he2ee22e2ee2eeee7h999999999999999h7bbb37h999999999999999999999999
j13jjj1jjjj31rrr999999999999999999999999999999999999999h7h9hehh27e2ee272e2722hhh999999999999999h7bbb3bb7h99999999999999999999999
j3jjj13jjjj131rr9999999997777779999999999999999999999999h7hhh7ee2eeee72e2e277h99999999999999999h73b33bb7h99999999999999999999999
jjjj133jjjj331rr9999999779999997799999999999999999999999heee2ee2e22ee22ee22ee2h99999999999999999h733337h999999999999999999999999
jjj133jjjjj1j31999999979999999999799999999999999999999999h2222ee2272e72ehhhhe7h999999999999999999h7337h9999999999999999999999999
jjj13jjjjjj31rr99999979999hhhhh999799999999999999999999999h2222ee7ee2ee27h99hh7h999999999999999999h77h99999999999999999999999999
jjjjjjjjjj31rrr9999997999h999aah997999999999999999999999hhee2ee22222e2222h9999h99999999h99h99999999hh999999999999999999999999999
jj1jj13jjj1jrr13rr997rr9h99aaaaah9979999999999999999999h77e2e227227227eeh9999999999999h7hh7h99h999999999999999999999999999999999
j13j13jjj13j1r13rrr17rrh99faaa11h99799999999999999999999h2he22e2ee2eee77h9999999h999h99heeh99h7h99999999999999999999999999999999
13j13jj1j3jjrr1rrrrr71rh9faahhh1h9979999999999999hhhhhhh7h9he2727e22272eh999999h7h9hehh27e2hh7h999999999999999999999999999999999
3jj3jj13jj1j33rrr111731h9fah999h9997999999999999h24444bhh7hee7be2ee2eeeh99999999h7hhh7ee2ee2eeh999999999999999999999999999999999
jj1jj13jj13jjj31j3137rrh9fah99999997999999999999bhfbhfb9beeb2eb2e22ee2h999999999heee2ee2e22eeh9999999999999999999999999999999999
j13j13jj13jjj133jjj17rr3h9fh99999997999999999999b9bff3b9bhb223be22e2e7h9999999999h2222ee22e2e7h999999999999999999999999999999999
j3jj3jjj3jjj13jjjjj117r99hfh99999979999999999999b3bh3b39b3b23b3ee2ee2h7h9999999999h2222ee2ee2hh999999999999999999999999999999999
jjjjjjjjjjjjjjjjjjjj173999h999999979999999999999b3bb3b3bb3bb3b3b2222e22hhhh9999hhhee2ee22222e22hhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh9
jjjjjjjjjjj1jjjjjj31rr799999999997999999999999991ffffbfffffbfff122e227ee22eh99h77992ccf44fccccf44fccccf44fccccf44fccccf44fcc299h
jjjjjjjjjj13jjjjjj3j1rr7799999977999999999999999fbbb33111bbb331fee2eeee72e2eh99h924fcc2442cccc2442cccc2442cccc2442cccc2442ccf429
jjjjjjjjj13jjj1jjjj31rrr977777799999999999999999f11bb31111bbb31fe2722eee7ee2ehh2942jcc22221jj122221jj122221jj122221jj12222ccj249
jjjjjjjjj3jjj13jjjj131rr9999999999999999999999b9fb1133b1b1133b1f2e2772b22722h7ee2fjfjj111111111111111111111111111111111111jjfjf2
jjjjjjjjjjjj133jjjj331rr9999999999999999b99b99b9fbb1133bbb1133bfb22be2b22eee2ee2cccjc12222222222222222222222222222222222221cjccc
jjjjjjjjjjj133jjjjj1j3199999999999999999b9b993b9f1111bb11111bb1fbhbhe3b2222222eecccj1124444444444444444444444444444444444211jccc
jjjjjjjjjjj13jjjjjj31rr99999999999999999b3b93b39f33311bb33311bbfb3bh3b322e22222ef2212244444444444444444444444444444444444422122f
jjjjjjjjjjjjjjjjjj31rrr99999999999999999b3bb3b3bfb33b11bb33b11bfb3bb3b3beeee2ee2442124444444444444444444444444444444444444421244
jjjjjjj1jjjjjjjjjj31rrr999999999999999991ffffbff1bb1bb1111133311fffbfff177e2e227442124444444444444441114411144444444444444421244
jjjjjj13jjjj1jjjjj3j1rr39999999999999999fbbb3311b1bb3bb1bb133bb11bbb331fh2he22e2f2212444444444444444444444444444444444444442122f
jjjjj13jjj111jjjjjj31rrr9999999999999999f11bb311bb1bb3313bb13bbb11bbb31f7h9he272cc11244444444444444441144114444444444444444211cc
jjjj13jjjj111jjjjjj131rr9999999999999999fb1133b1bbb1b11b13b113bbb1133b1fh7hee7beccj1244444444444444444j99j4444444444444444421jcc
jj1j3jjjjhhh1jj1jjj331rr9999999999999999fbb1133b1bb1131bbb31113bbb1133bfbeeb2eb2ccj12444444444444444499jj99444444444444444421jcc
jj11jjj1jhhh1j13jjj1j3199999999999999999f1111bb1131bb331bbb1bb111111bb1fbhb223becc1124444444444444444j1111j4444444444444444211cc
j111jj1311hhh13jjjj31rr99999999999999999f33311bb133bbb333bb1bbb133311bbfb3b23b3ef221244444444444444444j99j444444444444444442122f
j11hhj311hh113jhjj31rrr99999999999999999fb33b11b1133bbb113113bbbb33b11bfb3bb3b3b442124444444444444444449944444444444444444421244
jj1hh31hhhh11hhhjj1jrr13rr99rrr9hhhhhhh9f133311111b11b113313311111b11b11fffbfff1442124444444444444444444444444444444444444421244
jjhh88h88hh1hhh1j13j1r13rrr11rrh8888888hfbb331bb1bb1bbb1331331111bb1bbb11bbb331ff2212244444444444444444444444444444444444422122f
jjhh89a98hhhh111j3jjrr1rrrrr31h888888888bbb31bb313bb3bb11111133113bb3bb111bbb31fcccj1124444444444444444444444444444444444211jccc
jhh89a9hhhhhh11jjj1j33rrr11133h8888777b8fb311b31bb3bb33113311333bb3bb331b1133b1fcccjc1b222222222222222222222222222222222221cjccc
j1h88h98hhhh111jj13jjj31j3131rh8b87b77b8f31113bbb133b1bb13331133b133b1bbbb1133bfbfjbjjb11111111111111111111111111111111111jjfjf2
j1hhhh88hhh111jj13jjj133jjj1rrh8b8b773bhf1bb1bbb31131bbb1133111331131bbb1111bb1fb4bjc3b2221jj122221jj122221jj122221jj12222ccj249
jj1hhhhhhh111jjj3jjj13jjjjj11rrhb3b33b39fbbb1bb3133b3bb331113331133b3bb333311bbfb3bf3b3442cccc2442cccc2442cccc2442cccc2442ccf429
jj11hhhh1111jjjjjjjjjjjjjjjj1r39b3bb3b3bbbb31131131bb33133111331131bb331b33b11bfb3bb3b3b4fccccf44fccccf44fccccf44fccccf44fcc299h
f771777777cc177777cc177777cc17771ffffbff11b11b111133311133111111331113331bb1bb11fffbfff177cc177777cc177777cc177777cc177777cc1777
777c177cc771cc77c771cc77c771cc77fbbb33111bb1bbb11333133113111jj133111331b1bb3bb11bbb331fc771cc77c771cc77c771cc77c771cc77c771cc77
77ccc1cccccc1ccccccc1ccccccc1cccf11bb31113bb3bb13331333111133jjj11331111bb1bb33111bbb31fcccc1ccccccc1ccccccc1ccccccc1ccccccc1ccc
77cccc1ccccc1ccccccc1cbccccc1cbcfb1133b1bb3bb33133113311111133jj33333111bbb1b11bb1133b1fcccc1ccccccc1ccccccc1ccccccc1ccccccc1cbc
1cccccc11cccc11cbccbc1bcbccbc1bcfbb1133bb133b1bb1111111311111311331333111bb1131bbb1133bf1cccc11c1cccc11c1cccc11c1cccc11cbccbc1bc
71ccccc111ccc111b1bcc3b1b1bcc3b1f1111bb131131bbb3331331311111jj111113311131bb3311111bb1f11ccc11111ccc11111ccc11111ccc111b1bcc3b1
7711ccc1h1111hhhb3b13b3hb3b13b3hf33311bb133b3bb31333331111311jjj13311133133bbb3333311bbfh1111hhhh1111hhhh1111hhhh1111hhhb3b13b3h
ccc11111hh11hhhhb3bb3b3bb3bb3b3bfb33b11b131bb33111133111113311jj133311131133bbb1b33b11bfhh11hhhhhh11hhhhhh11hhhhhh11hhhhb3bb3b3b
7cc1c1hhhhhhhssh1ffffbffffbffbff1bb1bb113313311133111111331111111133311111b11b111113331fhhhsshhhhhhchhhhhhhhhsshhhhchhhh1ffffbff
77cc1c1hhhsshhssfbbb33111bb1bbb1b1bb3bb13313311113111jj113111jj1133313311bb1bbb1bb133bbfhhhsschhhhccshhhhhsshhsshhccshhhfbbb3311
777cc1c1hhscchhsf11bb31113bb3bb1bb1bb3311111133111133jjj11133jjj3331333113bb3bb13bb13bbbsshhscchhhhsschhhhscchhshhhsschhf11bb311
177ccc1chhhccchhfb1133b1bb3bb331bbb1b11b13311333111133jj111133jj33113311bb3bb33113b113bfscchhscssshhccshhhhccchhsshhccshfb1133b1
7c1cccc1hhhhccchfbb1133bb133b11b1bb1131b13331133111113111111131111111113b133b1bbbb31113bhccchhssscchhsshhhhhccchscchhsshfbb1133b
77c1ccchcchhhcssf1111bb131131b1b131bb3311133111311111jj111111jj13331331331131bbbbbb1bb1fhhccshhhhccchhhhcchhhcsshccchhhhf1111bb1
777c11hhccshhhssf33311bb133b3bb1133bbb333111333111311jjj11311jjj13333311133b3bb33bb1bbbfsshsshhhchccshhhccshhhsschccshhhf33311bb
177c1hhhhsshhhhhfb33b11b131bb3111133bbb133111331113311jj113311jj11133111131bb33113113bbbhsshhhhhhchsshhhhsshhhhhhchsshhhfb33b11b

__gff__
0000000000000000000400000000000004040808080303030000000000000000030303030303030303030303040400000303030303030303030303030404000000000000000000040404040404040404000404040000040404040404040404040404040404040404040404040404040404040404040404040404040404040404
0000000004040404040404040404040400000000040404040404040404040404000000000404040404040404040404040000000004040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000
__map__
3b3b2b3a1716377265c6c72029282828282828252a3b3b3b2a173457686967572828282939323224173a2a1634292828282829242a3a3b3b3b2b16173428282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2b3a2b151637a90061d6d73132292828282825153b2b2a15161537777879776728293839332526153a153636373239293932251515162a2b3a1517363728282800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1736363637a9b90061c4c567852039293825163a2a1516363637b46557626757293932252616163a1734465555f0313233ae353636151516153637282828393900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3728283088898a8b71d4d56595313231322416171536376473a484717265574739302517152a3a1736375500000094a984be4655f1353636373239383939323200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2828393098999a9b00c2c3616277d6d7677735363762576300a4940000716562323324153a1536375455e000008687b994ae550000f2ae7165a531323233686900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28282933a800aaab00d2d3716567c4c562484977a5647273009400000000615726263a1636374763550000000096970094bee1000000be0071b465958567787900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
283933b4b800babb00c0c1007172d4d5655859578563000000000000c9cacbcc171515376277647300d8000000c2c3e000ae00868700c8000094716595cdcecf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3933a484000042000dd0d1000000a6a76162676264730d00000e0000d9dadbdc3636374a4b57630000ae000000d2d30000be00969700000000e1006167dddedf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3363840000000000000dc3000000b6b761576247630d000000002e0000006167c4c5775a5b6263001fbe000000c0c10e00c800c2c3000000000051752c25262600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
576394000000000d00d2d30d000a00006177676263000e000d00700000517562d4d5656a6b67630000ae00000dd0d1000e00f1d2d3465555f251757b2516151600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6774531b007a08000ec00d000000000061cdcecf742527222222235252757767a6a771655777745300bef00d00212370000e0dc0c1e100000025262615173a2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6257630000a425271dd040000000004161dddedf251534393829292223574a4bb6b70071654e4f74522527007a203822230d000dd125262626171615172b2b3a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4c4d630000251615270d000e000e001d61252626172a34282828392930625a5b00000100615e5f11b524152627203829392222252615151615163a2b2b2b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5c5d74530124172a172750000e000d00251715173a3a2a272828283930096a6b702122222222222225151716162627283938292417172a2a3a2a2b2b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2122222225172b3b3a1627222222222224172a2b3b3b3b342828283821236277222938392938292924172b2a3a163428282828353615152b2b3a3b3b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20292526162a3b3b2b17343839293925172a3b3b3b3b3b3428282839293067622928282828282825172a3b3b2b16342828282828282416162b3a3a3b3b3b3b3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
01020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
01030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
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

