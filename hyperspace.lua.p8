pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- hyperspace
-- by j-fry

-- meshes
ship_pos = {}
ship_proj = {}
ship_tri = {}
nme_desc = {}

-- textures
ship_tex = {}
ship_tex_laser_lit = {}
nme_tex_hit = {}

-- cam
cam_mat = {}

-- ship
ship_mat = {}
inv_ship_mat = {}

-- ship roll/pitch
cur_noise_t = 0
tgt_noise_t = 0

roll_angle = 0.0
roll_spd = 0.0
cur_noise_roll = 0
old_noise_roll = 0

pitch_angle = 0.0
pitch_spd = 0.0
cur_noise_pitch = 0
old_noise_pitch = 0

-- objects
trails = {}
bgs = {}

-- light stuff
star_proj = {}
light_mat = {}
light_dir = {}
ship_light_dir = {}
t_light_dir = {}

hit_pos = {}
fade_ratio = -1

option_str = {"auto fire","manual fire","inverted y","non-inverted y"}

-- math stuff
function copy(res,v)
	for i=1,3 do
		res[i] = v[i]
	end
end

function vec_mul(v,f)
	for i=1,3 do
		v[i] *= f
	end
end

function vec_minus(v0,v1)
	local res = {}
	for i=1,3 do
		res[i] = v0[i] - v1[i]
	end
	return res
end

function dot(v0,v1)
	return v0[1] * v1[1] + v0[2] * v1[2] + v0[3] * v1[3]
end

function length(v)
	return sqrt(dot(v,v))
end

function normalize(v)
	vec_mul(v,0.1)
	local invl = 1 / length(v)
	vec_mul(v,invl)
end

function rotx(a)
	local cos_a = cos(a)
	local sin_a = sin(a)
	return {1,0,0,0,0,cos_a,sin_a,0,0,-sin_a,cos_a,0}	
end

function roty(a)
	local cos_a = cos(a)
	local sin_a = sin(a)
	return {cos_a,0,sin_a,0,0,1,0,0,-sin_a,0,cos_a,0}
end

function rotz(a)
	local cos_a = cos(a)
	local sin_a = sin(a)
	return {cos_a,sin_a,0,0,-sin_a,cos_a,0,0,0,0,1,0}
end

function translation(p)
	return {1,0,0,p[1],0,1,0,p[2],0,0,1,p[3]}
end

function mul_mat(res,m0,m1)
	local m00 = m0[1]
	local m01 = m0[2]
	local m02 = m0[3]
	local m03 = m0[4]
	local m04 = m0[5]
	local m05 = m0[6]
	local m06 = m0[7]
	local m07 = m0[8]
	local m08 = m0[9]
	local m09 = m0[10]
	local m010 = m0[11]
	local m011 = m0[12]
	
	local m10 = m1[1]
	local m11 = m1[2]
	local m12 = m1[3]
	local m13 = m1[4]
	local m14 = m1[5]
	local m15 = m1[6]
	local m16 = m1[7]
	local m17 = m1[8]
	local m18 = m1[9]
	local m19 = m1[10]
	local m110 = m1[11]
	local m111 = m1[12]
	
	res[1] = m00 * m10 + m01 * m14 + m02 * m18
	res[2] = m00 * m11 + m01 * m15 + m02 * m19
	res[3] = m00 * m12 + m01 * m16 + m02 * m110
	res[4] = m00 * m13 + m01 * m17 + m02 * m111 + m03
	
	res[5] = m04 * m10 + m05 * m14 + m06 * m18
	res[6] = m04 * m11 + m05 * m15 + m06 * m19
	res[7] = m04 * m12 + m05 * m16 + m06 * m110
	res[8] = m04 * m13 + m05 * m17 + m06 * m111 + m07
	
	res[9] = m08 * m10 + m09 * m14 + m010 * m18
	res[10] = m08 * m11 + m09 * m15 + m010 * m19
	res[11] = m08 * m12 + m09 * m16 + m010 * m110		
	res[12] = m08 * m13 + m09 * m17 + m010 * m111 + m011
end

function mul_vec(res,m,v) -- assuming w = 0
	local vx = v[1]
	local vy = v[2]
	local vz = v[3]

	res[1] = vx * m[1] + vy * m[2] + vz * m[3]
	res[2] = vx * m[5] + vy * m[6] + vz * m[7]
	res[3] = vx * m[9] + vy * m[10] + vz * m[11]
end

function mul_pos(res,m,v) -- assuming w = 1
	mul_vec(res,m,v)
	
	res[1] += m[4]
	res[2] += m[8]
	res[3] += m[12]
end

function transpose_rot(res,m) -- to invert rotations
	local m2 = m[2]
	local m3 = m[3]
	local m4 = m[5]
	local m6 = m[7]
	local m7 = m[9]
	local m8 = m[10]

	res[1] = m[1]
	res[2] = m4
	res[3] = m7
	res[4] = m[4]
	res[5] = m2
	res[6] = m[6]
	res[7] = m8	
	res[8] = m[8]
	res[9] = m3
	res[10] = m6
	res[11] = m[11]
	res[12] = m[12]
end

function normalize_angle(a) -- ]-0.5,0.5] for symmetry
	a = band(a,bnot(0xffff))
	if (a > 0.5) a -= 1
 	return a
end

function smoothstep(ratio) return ratio * ratio * (3 - 2 * ratio) end -- hermite interpolation

function get_random(t) return t[flr(rnd(#t)) + 1] end
function sym_random(f) return f - rnd(f * 2) end 

-- mesh encoding / decoding

mem_pos = 0x2000 -- tilemap memory

function decode_byte()
	local res = peek(mem_pos)
	mem_pos += 1
	if (res >= 128) res = bor(0xff00,res)
	return res * 0.5
end

function decode_mesh(vert,tri,scale)
	local nb_vert = decode_byte""
	for i=1,nb_vert do
		vert[i] = {}
		for j=1,3 do
			vert[i][j] = decode_byte"" * scale
		end
	end
	
	local nb_tri = decode_byte""
	for i=1,nb_tri do
		tri[i] = {}
		local tri = tri[i]
		tri.tri = {}
		local idx = tri.tri
		tri.uv = {{},{},{}}
		tri.normal = {}
		for j=1,3 do
			tri.tri[j] = decode_byte"" 
			tri.normal[j] = decode_byte"" / 63.5 
			for k=1,2 do
				tri.uv[j][k] = decode_byte""
			end
		end
	end
end

-- mesh description
function init_ship()	
	decode_mesh(ship_pos,ship_tri,1)
	
	for i=1,#ship_pos do
		ship_proj[i] = {}
	end
	
	ship_tex.x = 0
	ship_tex.y = 96
	ship_tex.light_x = 48
	
	ship_tex_laser_lit.x = 0
	ship_tex_laser_lit.y = 64
	ship_tex_laser_lit.light_x = 48
end

nme_scale = {1,2.5,3,5}
nme_life = {1,3,10,80}
nme_score = {1,10,10,100}
nme_radius = {3.25,6,8,16}

-- not for asteroids
nme_bounds = {-50,-50,-100}
nme_rot = {0.18,0.24,0.06}
nme_spd = {1,0.5,0.6}

function init_nme()

	for i=1,4 do
		nme_desc[i] = {}
		local desc = nme_desc[i]
		desc.pos = {}
		desc.tri = {}
		decode_mesh(desc.pos,desc.tri,nme_scale[i])
		
		desc.tex = {}
		local tex = desc.tex
		tex.x = (i-1) * 32
		tex.y = 32
		tex.light_x = 16
	end
		
	nme_tex_hit.x = 96
	nme_tex_hit.y = 64
	nme_tex_hit.light_x = 16
end

function init_single_trail(trail,z)
	copy(trail.pos0,{sym_random(100) + ship_x,sym_random(100) + ship_y,z})
	trail.spd = (2.5 + rnd(5)) * game_spd
	trail.col = flr(rnd(#trail_color - 1)) + 1
end

function init_trail()
	for i = 1,64 do
		trails[i] = {}
		local trail = trails[i]

		trail.pos0 = {}
		trail.pos1 = {}
		trail.proj0 = {}
		trail.proj1 = {}
		
		init_single_trail(trail,sym_random(150))
	end
end

function init_single_bg(bg,z)
	-- spawn on a cylinder
	local a = rnd(1)
	local r = 150 + rnd(150)
	copy(bg.pos,{r * cos(a),r * sin(a),z})
	bg.spd = 0.05 + rnd(0.05)
	if flr(rnd(6)) == 0 then
		bg.index = 8 + rnd(8)
	else
		bg.index = -get_random(bg_color) -- the negative sign is here to discriminate between sprite bg and pixel bg
	end
end

bg_color = {12,13,6}
function init_bg()
	for i = 1,64 do
		bgs[i] = {}
		local bg = bgs[i]
		
		bg.pos = {}
		bg.proj = {}
		
		init_single_bg(bg,sym_random(400))
	end
end

function _init()
	cartdata("hyperspace_jfry")

	init_main""
	
	init_ship""
	init_nme""
			
	init_trail""
	init_bg""
end

function init_main()
	cur_mode = 0
	cam_angle_z = -0.4
	cam_angle_x = (flr(rnd(2)) * 2 - 1) * (0.03 + rnd(0.1))
	
	ship_x = 0
	ship_y = 0
	
	cam_x = 0
	cam_y = 0

	ship_spd_x = 0
	ship_spd_y = 0

	life = 4
	
	barrel_cur_t = -1
	nmes = {}
	lasers = {}
	nme_lasers = {}
	hit_t = -1
	laser_on = false
	
	nb_nmes = 0
	nb_nme_ship = 0
	
	aim_z = -200

	cur_thrust = 0

	roll_f = 0
	pitch_f = 0

	global_t = 0

	asteroid_mul_t = 1
	cur_sequencer_x = 96
	cur_sequencer_y = 96
	next_sequencer_t = 0
	waiting_nme_clear = false
	spawn_asteroids = false

	game_spd = 1
	cam_depth = 22.5
	
	cur_nme_t = 0
	
	best_score = dget(0)
end


-- update stuff
function hit_ship(pos,sqr_size)
	if hit_t == -1 and barrel_cur_t == -1 then
		local dx = (pos[1] - ship_x) * 0.2
		local dy = (pos[2] - ship_y) * 0.2
		local sqrd = dx * dx + dy * dy
		if sqrd < sqr_size then
			local n = 1 / sqrt(sqrd)
			dx *= n
			dy *= n
			roll_f += dx * 0.05
			pitch_f -= dy * 0.02
			hit_t = 0
			copy(hit_pos,pos)
			life -= 1
			sfx(2,1)
			if life == 0 then
				fade_ratio = 0
				sfx(7,2)
			end
		end
	end
end

function spawn_nme(type,pos)
	nb_nmes += 1
	nmes[nb_nmes] = {}
	local nme = nmes[nb_nmes]
	nme.pos = pos
	nme.type = type
	nme.proj = {}
	for i=1,#nme_desc[type].pos do
		nme.proj[i] = {}
	end
	nme.life = nme_life[type]
	nme.light_dir = {}
	nme.hit_t = -1
	nme.hit_pos = {}
	nme.rot_x = 0
	nme.rot_y = 0
	return nme
end

function spawn_nme_ship(type)
	nb_nme_ship += 1
	next_sequencer_t = global_t + 0.25 -- for better effect when spawning
	local desc_bounds = nme_bounds[type - 1] * 2
	local nme = spawn_nme(type,{mid(-100,sym_random(50) + ship_x,100),mid(-100,sym_random(50) + ship_y,100),desc_bounds - 200})
	nme.spd = {0,0,8}
	nme.rot_x_spd = 0
	nme.rot_y_spd = 0
	nme.waypoint = {}
	copy(nme.waypoint,nme.pos)
	nme.waypoint[3] = desc_bounds
	nme.laser_t = 0
	nme.stop_laser_t = 0
	nme.next_laser_t = 0
	nme.laser_offset_x = {}
	nme.laser_offset_y = {}
end

-- update stuff
function update_enemis()
	for i=1,nb_nmes do
		local nme = nmes[i]
		local pos = nme.pos
		local spd = nme.spd
		for j=1,3 do
			pos[j] += spd[j] * game_spd
		end
		nme.rot_x += nme.rot_x_spd
		nme.rot_y += nme.rot_y_spd
		
		local type = nme.type
		local hit_t = nme.hit_t
		if type > 1 then
		
			local sub_type = type - 1
			local nb_lasers = type - 2
			local desc_bounds = nme_bounds[sub_type]
			local desc_spd = nme_spd[sub_type]
		
			local dir = vec_minus(nme.waypoint,pos)
			vec_mul(dir,0.1)
			local dist = dot(dir,dir)
			if (dist < game_spd * game_spd or hit_t == 0) nme.waypoint = {sym_random(100),sym_random(100),desc_bounds - rnd(-desc_bounds)}
			normalize(dir)
			for i=1,3 do
				spd[i] += dir[i] * desc_spd * 0.1
			end
			
			if pos[3] >= desc_bounds * 2 then
				dist = length(spd)
				if dist > desc_spd then
					vec_mul(spd,desc_spd / dist)
				end	
			
				nme.rot_x = -0.08 * spd[2]
				nme.rot_y = -nme_rot[sub_type] * spd[1]
			
				if (type == 4 or hit_t == 0) and nme.laser_t < 0 then
					nme.laser_t = 0
				end
			
				nme.laser_t += 1
				
				if nme.laser_t > nme.stop_laser_t then
					nme.laser_t = -(60 + rnd(60)) / game_spd
					nme.stop_laser_t = 60 + rnd(60)
					local c = -0.5 * pos[3] / game_spd
					for i=1,nb_lasers do
						nme.laser_offset_x[i] = sym_random(30) + ship_spd_x * c 
						nme.laser_offset_y[i] = sym_random(30) + ship_spd_y * c
					end
				end
				
				local laser_t = nme.laser_t
				local t = 6 / game_spd
				if laser_t > 0 then
				
					nme.next_laser_t += 1
					
					if nme.next_laser_t >= t then
						nme.next_laser_t -= t

						if type != 2 then
							local ratio = cos(laser_t / 120)
												
							for i=1,nb_lasers do 
								local vert_pos = nme_desc[type].pos[i]
								local laser = spawn_laser(nme_lasers,{pos[1] + vert_pos[1],pos[2],pos[3] + vert_pos[3]})
								dir = vec_minus({ship_x + nme.laser_offset_x[i] * ratio + sym_random(5),ship_y + nme.laser_offset_y[i] * ratio + sym_random(5),0},laser.pos0)
								vec_mul(dir,0.1)	
								local v = 2 * game_spd / length(dir)
								laser.spd = {dir[1] * v,dir[2] * v,dir[3] * v}
							end
						else
							local laser = spawn_laser(nme_lasers,{pos[1],pos[2],pos[3] + 12})
							laser.spd = {sym_random(0.05),sym_random(0.05),2 * game_spd}
						end
					end
				end
			end
		end
		
		local delete	
		if pos[3] > 0 then
			hit_ship(pos,2.5)
			delete = true
		end
	
		if nme.life <= 0 then
			nme.life -= 1
			if (nme.life < -15) delete = true
		end
		
		if hit_t > -1 then
			nme.hit_t += 1
			if (hit_t > 5) nme.hit_t = -1
		end
		
		if delete then
			if (type > 1) nb_nme_ship -= 1
			nmes[i] = nmes[nb_nmes]
			i -= 1
			nb_nmes -= 1
		end
	end
	
	cur_nme_t -= 1
	if spawn_asteroids and cur_nme_t <= 0 then
		cur_nme_t = (30 + rnd(60)) * asteroid_mul_t / game_spd
		local posx = mid(-100,10 * ship_spd_x + ship_x + sym_random(30),100)
		local posy = mid(-100,10 * ship_spd_y + ship_y + sym_random(30),100)
		local nme = spawn_nme(1,{posx,posy,-50})
		nme.spd = {mid((-100-posx)*0.005,sym_random(0.25),(100-posx)*0.005),mid((-100-posy)*0.005,sym_random(0.25),(100-posy)*0.005),0.25}
		nme.rot_x_spd = sym_random(0.015)
		nme.rot_y_spd = sym_random(0.015)
	end
	
	-- sort by distance
	for i = 2,nb_nmes do
		local nme = nmes[i]
		local j = i - 1
		local prev_nme = nmes[j]	
		while nme.pos[3] > prev_nme.pos[3] do
			nmes[j + 1] = prev_nme
			nmes[j] = nme
			j -= 1
			if (j == 0) break
			prev_nme = nmes[j]
		end
	end
end	

cur_laser_t = 0
cur_laser_side = -1

function update_nme_lasers()
	for laser in all(nme_lasers) do
		local pos0 = laser.pos0
		copy(laser.pos1,pos0)
		local spd = laser.spd
		for i=1,3 do
			pos0[i] += spd[i]
		end
		if pos0[3] >= 0 then
			hit_ship(pos0,1.5)
			hit_ship(laser.pos1,1.5)
			del(nme_lasers,laser)
		end
	end

end

function spawn_laser(in_lasers,pos)
	local laser = {}
	laser.pos0 = pos
	laser.pos1 = {}
	laser.proj0 = {}
	laser.proj1 = {}
	add(in_lasers,laser)
	return laser
end

function update_lasers()
	cur_laser_t += 1
	laser_spawned = false
	if laser_on and cur_laser_t > 2 then		
		cur_laser_t = 0
		laser_spawned = true
		local pos = {cur_laser_side,-1.5,-8}
		mul_pos(pos,ship_mat,pos)
		spawn_laser(lasers,pos)
		cur_laser_side = -cur_laser_side
	end
	
	for laser in all(lasers) do	
		local pos0 = laser.pos0
		
		copy(laser.pos1,pos0)
		pos0[3] -= 5
		
		if (pos0[3] <= -200) del(lasers,laser)
	end
end

trail_color = {7,7,6,13,1} --{6,12,12,13,13}- hyperspace
function update_trail()
	for i = 1,#trails do
		local trail = trails[i]
		local pos0 = trail.pos0
		
		if pos0[3] >= 150 then
			init_single_trail(trail,-150)
		end
		
		copy(trail.pos1,pos0)
		pos0[3] += trail.spd
	end
	
	for i = 1,#bgs do
		local bg = bgs[i]
		local pos = bg.pos
		pos[3] += bg.spd * game_spd
		
		if pos[3] >= 400 then
			init_single_bg(bg,-400)
		end		
	end
end

function update_collisions()
	local laser_idx = 1
	local nme_idx = nb_nmes
	local min_dist = 32767
	while laser_idx <= #lasers and nme_idx >= 1 do
		local laser_pos0 = lasers[laser_idx].pos0
		local laser_pos1 = lasers[laser_idx].pos1
		local nme = nmes[nme_idx]
		local nme_pos = nme.pos
		local nme_z = nme_pos[3]

		if nme_z > laser_pos1[3] then
			laser_idx += 1
		else
			if nme.life > 0 and nme_z >= laser_pos0[3] then
				local dx = (laser_pos0[1] - nme_pos[1]) * 0.2
				local dy = (laser_pos0[2] - nme_pos[2]) * 0.2
				
				min_dist = min(min_dist,dx * dx + dy * dy)
				
				local radius = nme_radius[nme.type]
				if dx * dx + dy * dy <= radius * radius * 0.04 then
					nme.life -= 1
					if nme.life == 0 then
						nme.hit_t = -1
						sfx(2,1)
						score += nme_score[nme.type]
					else
						copy(nme.hit_pos,laser_pos0)
						nme.hit_t = 0
						sfx(5,1)
					end
						
					del(lasers,lasers[laser_idx])
				end
			end
						
			nme_idx -= 1
		end
	end
end

-- main update
function _update()
	local dx = 0
	local dy = 0
	
	if (btn(0)) dx -= 1	
	if (btn(1)) dx += 1
	if (btn(2)) dy -= 1
	if (btn(3)) dy += 1
					
	if cur_mode == 2 then
	
		global_t += 0.033
		game_spd = 1 + global_t * 0.002
		
		if (dx == 0 and dy == 0) cur_thrust = 0 else cur_thrust = min(0.5,cur_thrust + 0.1) 
		local mul_spd = cur_thrust
		
		if (non_inverted_y != 0) dy = -dy
		
		if barrel_cur_t > -1 or life <= 0 then
			dx = 0
			dy = 0
		end
		
		if btn(5) and dx != 0 and barrel_cur_t == -1 then
			sfx(1,0)
			barrel_cur_t = 0
			barrel_dir = sgn(dx)
		end
		
		if barrel_cur_t != -1 then
			barrel_cur_t += 1
			
			if barrel_cur_t >= 0 then 
				dx = barrel_dir * 9
				dy = 0
				mul_spd = 0.1
				
				if barrel_cur_t > 5 then
					barrel_cur_t = -20
				end
			end
		end	
			
		if (abs(ship_x) > 100) dx = -sgn(ship_x) * 0.4
		if (abs(ship_y) > 100) dy = -sgn(ship_y) * 0.4
		
		ship_spd_x += dx * mul_spd
		ship_spd_y += dy * mul_spd
		
		roll_f -= 0.003 * dx
		pitch_f += 0.0008 * dy
		
		-- drag
		ship_spd_x *= 0.85
		ship_spd_y *= 0.85
	
		ship_x += ship_spd_x
		ship_y += ship_spd_y

		cam_x = 1.05 * ship_x
		cam_y = ship_y + 11.5
				
		if hit_t != -1 then
			cam_x += sym_random(2)
			cam_y += sym_random(2)
		elseif life <= 0 then
			hit_t = 0
			hit_pos = {ship_x,ship_y,0}
			sfx(2,1)
		end
		
		cam_angle_z = cam_x * 0.0005
		cam_angle_x = cam_y * 0.0003
		
		-- sequencer
		if waiting_nme_clear then
			if nb_nme_ship == 0 then
				next_sequencer_t = 0
				waiting_nme_clear = false
			else
				next_sequencer_t = 0x7fff
			end
		end

		if global_t >= next_sequencer_t then
			local value = sget(cur_sequencer_x,cur_sequencer_y)
			cur_sequencer_x += 1
			if cur_sequencer_x > 127 then
				cur_sequencer_x = 96
				cur_sequencer_y += 1		
			end
			
			if value == 1 then spawn_nme_ship(3)
			elseif value == 13 then 
				spawn_nme_ship(4)
				sfx(6,2)
			elseif value == 2 then spawn_nme_ship(2)
			elseif value == 6 then 
				spawn_asteroids = true
				asteroid_mul_t = 1
			elseif value == 7 then
				spawn_asteroids = true
				asteroid_mul_t = 0.5
			elseif value == 5 then spawn_asteroids = false
			elseif value == 10 then next_sequencer_t = global_t + 1
			elseif value == 9 then next_sequencer_t = global_t + 10
			elseif value == 11 then waiting_nme_clear = true
			else
				cur_sequencer_x = 96
				cur_sequencer_y = 96
			end
		end
		--
	elseif cur_mode == 0 then		
		if (dx == 0 and dy == 0) dx = -0.25
		
		cam_angle_z += dx * 0.007
		cam_angle_x -= dy * 0.007
		
		if btnp(5) then
			cur_mode = 3
			manual_fire = dget(1)
			non_inverted_y = dget(2)
		end
	elseif cur_mode == 3 then
	
		cam_angle_z -= 0.00175
	
		if btnp(0) or btnp(1) then
			manual_fire = 1 - manual_fire
			dset(1,manual_fire)
		end
		
		if btnp(2) or btnp(3) then	
			non_inverted_y = 1 - non_inverted_y
			dset(2,non_inverted_y)
		end
	
		if btnp(5) then
			src_cam_angle_z = normalize_angle(cam_angle_z)
			src_cam_angle_x = normalize_angle(cam_angle_x)
			src_cam_x = cam_x
			src_cam_y = cam_y

			dst_cam_x = 1.05 * ship_x
			dst_cam_y = ship_y + 11.5
			dst_cam_angle_z = dst_cam_x * 0.0005
			dst_cam_angle_x = dst_cam_y * 0.0003
					
			interpolation_spd = 0.25 / length(vec_minus({src_cam_x,src_cam_y,26},{dst_cam_x,dst_cam_y,22.5}))

			interpolation_ratio = 0
			cur_mode = 1
		end
	else
		interpolation_ratio += interpolation_spd
		
		if interpolation_ratio >= 1 then
			cur_mode = 2
			score = 0
		else
			local smoothed_ratio = smoothstep(interpolation_ratio)
			cam_x = src_cam_x + smoothed_ratio * (dst_cam_x - src_cam_x)
			cam_y = src_cam_y + smoothed_ratio * (dst_cam_y - src_cam_y)
			cam_depth = 22.5 + smoothed_ratio * 3.5
			cam_angle_z = src_cam_angle_z + smoothed_ratio * (dst_cam_angle_z - src_cam_angle_z)
			cam_angle_x = src_cam_angle_x + smoothed_ratio * (dst_cam_angle_x - src_cam_angle_x)
		end
	end
	
	local old_laser_on = laser_on 	
	laser_on = (cur_mode != 2 and btn(4)) or ((btn(4) or (manual_fire != 1 and tgt_pos)) and barrel_cur_t == -1 and hit_t == -1)
	
	if laser_on != old_laser_on then
		if (laser_on) sfx(0,0) else sfx(-2,0)
	end
		
	mul_mat(cam_mat,translation({0,0,-cam_depth}),rotx(cam_angle_x))
	mul_mat(cam_mat,cam_mat,roty(cam_angle_z))
	mul_mat(cam_mat,cam_mat,translation({-cam_x,-cam_y,0}))
		
	-- roll
	cur_noise_t += 1
	local noise_attenuation = cos(mid(-0.25,roll_angle * 1.2,0.25))
	if cur_noise_t > tgt_noise_t then		
		old_noise_roll = cur_noise_roll
		old_noise_pitch = cur_noise_pitch
		
		cur_noise_t = 0
		
		local new_roll_sign = -sgn(cur_noise_roll)
		if (new_roll_sign == 0) new_roll_sign = 1			
		
		cur_noise_roll = new_roll_sign * (0.01 + rnd(0.03))
		tgt_noise_t = (60 + rnd(40)) * noise_attenuation * abs(cur_noise_roll - old_noise_roll) * 10
	
		cur_noise_pitch = sym_random(0.01)
	end
	
	local noise_ratio = smoothstep(cur_noise_t / tgt_noise_t)
	
	roll_f -= roll_angle * 0.02
	roll_spd = roll_spd * 0.8 + roll_f
	roll_angle += roll_spd
	
	pitch_f -= pitch_angle * 0.02
	pitch_spd = pitch_spd * 0.8 + pitch_f	
	pitch_angle += pitch_spd
	
	roll_f = 0
	pitch_f = 0
		
	noise_roll = noise_attenuation * (old_noise_roll + noise_ratio * (cur_noise_roll - old_noise_roll))
	noise_pitch = noise_attenuation * (old_noise_pitch + noise_ratio * (cur_noise_pitch - old_noise_pitch))
	
	roll_angle = normalize_angle(roll_angle)
			
	ship_pos_mat = translation({ship_x,ship_y,0})
	mul_mat(ship_mat,ship_pos_mat,rotx(normalize_angle(pitch_angle + noise_pitch)))
	mul_mat(ship_mat,ship_mat,rotz(normalize_angle(roll_angle + noise_roll)))
	
	transpose_rot(inv_ship_mat,ship_mat)
	
	update_trail""
	if cur_mode == 2 then
		update_enemis""
	end
	
	update_lasers""
	update_nme_lasers""
	update_collisions""
	
	if hit_t != -1 then
		hit_t += 1
		if (hit_t > 15) hit_t = -1
	end
	
	mul_mat(ship_mat,cam_mat,ship_mat)
	mul_mat(ship_pos_mat,cam_mat,ship_pos_mat)
	
	light_mat = rotx(0.14)
	mul_mat(light_mat,light_mat,roty(0.34 + global_t * 0.003))
	mul_vec(light_dir,light_mat,{0,0,-1})
	
	mul_vec(ship_light_dir,inv_ship_mat,light_dir)
	
	if fade_ratio >= 0 then
		if (cur_mode == 2) fade_ratio += 2 else fade_ratio -= 2
		if fade_ratio >= 100 then
			if score > best_score then
				best_score = score
				dset(0,best_score)
			end
			init_main""
		end
	end
end

-- renderer

--near_plane_dist = 8
--near_plane_size = 0.1
--near_plane_coef = 10 --1 / near_plane_size
--coef_dim = 80 --near_plane_dist / near_plane_size

aim_proj = {}

function transform_vert()	
	for i = 1,#ship_pos do
		transform_pos(ship_proj[i],ship_mat,ship_pos[i])
	end
	
	-- aim
	transform_pos(aim_proj,cam_mat,{ship_x,ship_y - 1.5,aim_z})
	local auto_aim_dist = 30 -- ~54*54*0.01
	tgt_pos = nil
	aim_life_ratio = nil
	
	if cur_mode == 2 then
	
		local aim_x = aim_proj[1]
		local aim_y = aim_proj[2]
	
		for i=1,nb_nmes do
			local nme = nmes[i]
			local pos = nme.pos

			local projs = nme.proj
				
			local nme_mat = translation(nme.pos)
			mul_mat(nme_mat,nme_mat,rotx(nme.rot_x))
			mul_mat(nme_mat,nme_mat,rotz(nme.rot_y))

			local inv_nme_mat = {}
			transpose_rot(inv_nme_mat,nme_mat)
			
			mul_vec(nme.light_dir,inv_nme_mat,light_dir)
			--vec_mul(nme.light_dir,2)
			
			mul_mat(nme_mat,cam_mat,nme_mat)
			
			local type = nme.type
			local nme_pos = nme_desc[type].pos
			for j = 1,#nme_pos do
				transform_pos(projs[j],nme_mat,nme_pos[j])
			end
			
			-- auto aim in screen space
			if nme.life > 0 then
				local dx = (projs[1][1] - aim_x) * 0.1
				local dy = (projs[1][2] - aim_y) * 0.1
				local sqr_dist = dx * dx + dy * dy
				if sqr_dist < auto_aim_dist then
					auto_aim_dist = sqr_dist
					tgt_pos = pos
					local laser_t = -game_spd * pos[3] / 5
					local spd = nme.spd
					interp_tgt_pos = {pos[1] + spd[1] * laser_t,pos[2] + spd[2] * laser_t,min(0,pos[3] + spd[2] * laser_t)}
					if (type != 1) aim_life_ratio = nme.life / nme_life[type]
				end
			end
		end
	end
	
	local tgt_z = -200	
	if (tgt_pos) tgt_z = tgt_pos[3]
	aim_z += (tgt_z - aim_z) * 0.2
	
	transform_pos(star_proj,ship_pos_mat,{light_mat[3] * 100,light_mat[7] * 100,light_mat[11] * 100})
end

function transform_pos(proj,mat,pos)
	mul_pos(proj,mat,pos)
	
	local c = -80 / proj[3]
	
	proj[1] = 64 + proj[1] * c
	proj[2] = 64 - proj[2] * c -- inverse y as (0,0) is top left in screen coordinates
	
	if c > 0 and c <= 10 then -- near plane cull
		proj[3] = c
	else
		-- this is a simplification. beware as there is no near plane clipping, if a tri intersects the near plane, the rendering will be broken
		-- you can test against proj[3] being > 0 (or this function to return false) to near plane cull vertices / tris / objects
		proj[3] = 0
	end
end

function rasterize_flat_tri(v0,v1,v2,uv0,uv1,uv2,light) -- v0 top, v1 left, v2 right vertices
	
	local y0 = v0[2]
	local y1 = v1[2]
	
	local firstline
	local lastline 
	
	if y0 < y1 then
		firstline = flr(y0 + 0.5) + 0.5
		lastline = flr(y1 - 0.5) + 0.5
	elseif y0 == y1 then
		return
	else
		firstline = flr(y1 + 0.5) + 0.5
		lastline = flr(y0 - 0.5) + 0.5
	end
		
	firstline = max(0.5,firstline)
	lastline = min(lastline,127.5)
	
	local x0 = v0[1]
	local z0 = v0[3]
	local x1 = v1[1]
	local z1 = v1[3]
	local x2 = v2[1]
	local y2 = v2[2]
	local z2 = v2[3]
	
	local uv0x = uv0[1]
	local uv0y = uv0[2]
	local uv1x = uv1[1]
	local uv1y = uv1[2]
	local uv2x = uv2[1]
	local uv2y = uv2[2]
			
	local cb0 = x1 * y2 - x2 * y1
	local cb1 = x2 * y0 - x0 * y2
	
	local d = cb0 + cb1 + x0 * y1 - x1 * y0
	local invdy = 1 / (y1 - y0)
	
	local tex_x = cur_tex.x
	local tex_y = cur_tex.y
	local tex_lit_x = cur_tex.light_x

	for y=firstline,lastline do
	
		local coef = (y - y0) * invdy
		local xfirst = max(0.5,flr(x0 + coef * (x1 - x0) + 0.48) + 0.5)
		local xlast = min(flr(x0 + coef * (x2 - x0) - 0.48) + 0.5,127.5)
				
		local x0y = x0 * y
		local x1y = x1 * y
		local x2y = x2 * y
						
		for x=xfirst,xlast do
		
			local b0 = (cb0 + x * y1 + x2y - x * y2 - x1y) / d
			local b1 = (cb1 + x * y2 + x0y - x * y0 - x2y) / d
			local b2 = 1 - b0 - b1 -- as the pixel is inside
			
			-- perspective correction
			b0 *= z0
			b1 *= z1
			b2 *= z2
			
			local d2 = b0 + b1 + b2
			local uvx = (b0 * uv0x + b1 * uv1x + b2 * uv2x) / d2
			local uvy = (b0 * uv0y + b1 * uv1y + b2 * uv2y) / d2
								
			local offset_x = tex_x
			if (light <= 7 + sget(x % 8,56 + y % 8) * 0.125) offset_x += tex_lit_x
			pset(x,y,sget(uvx + offset_x,uvy + tex_y))	
		end
	end
end

function rasterize_tri(index,tris,projs)
	local tri = tris[index]
	local idx = tri.tri

	local v0 = projs[idx[1]]
	local v1 = projs[idx[2]]
	local v2 = projs[idx[3]]
	
	local x0 = v0[1]
	local y0 = v0[2]
	local x1 = v1[1]
	local y1 = v1[2]
	local x2 = v2[1]
	local y2 = v2[2]
	
	-- backface cull	
	local nz = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
	if (nz < 0) return
	
	local uv = tri.uv
	local uv0 = uv[1]
	local uv1 = uv[2]
	local uv2 = uv[3]
		
	local tmp
	if v1[2] < v0[2] then
		tmp = v1
		v1 = v0
		v0 = tmp
		tmp = uv1
		uv1 = uv0
		uv0 = tmp	
	end
	
	if v2[2] < v0[2] then
		tmp = v2
		v2 = v0
		v0 = tmp
		tmp = uv2
		uv2 = uv0
		uv0 = tmp
	end
		
	if v2[2] < v1[2] then
		tmp = v2
		v2 = v1
		v1 = tmp
		tmp = uv2
		uv2 = uv1
		uv1 = tmp
	end
	
	x0 = v0[1]
	y0 = v0[2]
	y1 = v1[2]
	y2 = v2[2]
	local z0 = v0[3]
	local z2 = v2[3]
	
	if (y0 == y2) return -- safe guard
	
	local light = 15 * dot(t_light_dir,tri.normal) -- lambert (with light intensity hard-coded!) must be in the range [0,15]
		
	local c = (y1 - y0) / (y2 - y0)
	local v3 = {x0 + c * (v2[1] - x0),y1,z0 + c * (z2 - z0)}
	
	-- interpolate uv of v3 in a perspective cor way
	local b0 = (1 - c) *  z0
	local b1 = c * z2
	local invd = 1 / (b0 + b1)
	
	local uv3 = {
		(b0 * uv0[1] + b1 * uv2[1]) * invd,
		(b0 * uv0[2] + b1 * uv2[2]) * invd
	}
	
	if v1[1] <= v3[1] then
		rasterize_flat_tri(v0,v1,v3,uv0,uv1,uv3,light)
		rasterize_flat_tri(v2,v1,v3,uv2,uv1,uv3,light)
	else	
		rasterize_flat_tri(v0,v3,v1,uv0,uv3,uv1,light)
		rasterize_flat_tri(v2,v3,v1,uv2,uv3,uv1,light)
	end	
end

function sort_tris(tris,projs)
	-- compute sort key
	for i = 1,#tris do
		local tri = tris[i]
		local idx = tri.tri				
		tri.z = projs[idx[1]][3] + projs[idx[2]][3] + projs[idx[3]][3] -- just a simple key to z sort tri
	end
	
	-- actual sort (simple insertion sort taking advantage of temporal coherency)
	for i = 2,#tris do
		local tri = tris[i]
		local j = i - 1
		local prev_tri = tris[j]	
		while tri.z < prev_tri.z do
			tris[j + 1] = prev_tri
			tris[j] = tri
			j -= 1
			if (j == 0) break
			prev_tri = tris[j]
		end
	end
end

-- ngn palette update
ngn_colors = {13,12,7,12}
laser_ngn_colors = {3,11,7,11}

ngn_col_idx = 0
ngn_laser_col_idx = 0

function set_ngn_pal()
	ngn_col_idx = (ngn_col_idx + 1) % 4
	ngn_laser_col_idx = (ngn_laser_col_idx + 0.2) % 4
		
	pal(12,ngn_colors[flr(ngn_col_idx) + 1])
	
	local index = flr(ngn_laser_col_idx)
	pal(8,laser_ngn_colors[index + 1])
	pal(14,laser_ngn_colors[(index + 1) % 4 + 1])
	pal(15,laser_ngn_colors[(index + 2) % 4 + 1])
end

-- lens flare
flare_offset = 0

function draw_single_flare(index,factor,vx,vy,offset)
	local px = flr(60 + vx * factor)
	local py = flr(60 + vy * factor)	
	local cur_offset = band(flare_offset + px + py + offset,0x1) * 4
	spr(index + cur_offset,px,py)
end

function draw_lens_flare()
	-- occlusion is tested by checking if the center pixel of the star is white
	if (pget(star_proj[1],star_proj[2]) != 7) return

	local vx = 64 - star_proj[1]
	local vy = 64 - star_proj[2]
	
	draw_single_flare(40,-0.3,vx,vy,0)
	draw_single_flare(59,0.4,vx,vy,1)
	draw_single_flare(56,0.5,vx,vy,0)
	draw_single_flare(42,0.9,vx,vy,1)
	draw_single_flare(43,1,vx,vy,0)
	
	flare_offset = 1 - flare_offset -- temporal dither to simulate translucency
end

--function debug_rect(center,width,height,color)
--	local proj = {}
--	transform_pos(proj,cam_mat,center)	
--	width *= proj[3] * 0.5
--	height *= proj[3] * 0.5
--	rect(proj[1] - width,proj[2] - height,proj[1] + width,proj[2] + height,color)
--end

explosion_color = {9,10,15,7}
trail_color_coef = 0.45 * #trail_color

function draw_explosion(proj,size)
	local invz = proj[3]
	circfill(proj[1] + sym_random(size * 0.5) * invz,proj[2] + sym_random(size * 0.5) * invz,invz * (size + rnd(size)),get_random(explosion_color))
end

function set_nme_hit(value,target)
	if (band(value,0x1) == 0) cur_tex = nme_tex_hit else cur_tex = nil
	return 0.5 + (target - value) / (target * 2)
end

function print_3d(str,x,y)	
	print(str,x + 2,y + 2,1)
	print(str,x + 1,y + 1,13)
	print(str,x,y,7)
end

function draw_lasers(in_lasers)
	local p0 = {}
	local p1 = {}
	
	for laser in all(in_lasers) do
		
		transform_pos(p0,cam_mat,laser.pos0)
		transform_pos(p1,cam_mat,laser.pos1)

		if p0[3] > 0 and p1[3] > 0 then
			line(p0[1],p0[2],p1[1],p1[2])
		end
	end
end

-- main draw
function _draw()
	
	local p0 = {}
	local p1 = {}
	
	cls""
	transform_vert""
	
	for i = 1,#bgs do
		local bg = bgs[i]
		
		transform_pos(p0,ship_pos_mat,bg.pos)
				
		if p0[3] > 0 then
			local index = bg.index
			if index > 0 then
				local size = min(8,16 * p0[3])
				spr(index + 16 * flr(rnd(2)),p0[1],p0[2])
			else
				local col = 7
				if (rnd(1) > 0.5) col = -index
				pset(p0[1],p0[2],col)
			end	
		end
	end
	
	-- sun
	local star_x = star_proj[1] 
	local star_y = star_proj[2] 
	
	local star_visible = star_proj[3] > 0 and star_x >= 0 and star_x < 128 and star_y >= 0 and star_y < 128
	if star_visible then
		local index = 32 + flr(rnd(4)) * 2
		spr(index,star_x - 7,star_y - 7,2,2)
	end	
	
	for i = 1,#trails do
		local trail = trails[i]
		
		transform_pos(p0,cam_mat,trail.pos0)
		transform_pos(p1,cam_mat,trail.pos1)

		if p0[3] > 0 and p1[3] > 0 then
			local index = mid(trail.col,flr(trail_color_coef / p0[3]) + 1,#trail_color)
			line(p0[1],p0[2],p1[1],p1[2],trail_color[index])
		end
	end
		
	if cur_mode == 2 then		
		for i = nb_nmes,1,-1 do -- back to front
			local nme = nmes[i]
			local projs = nme.proj

			local desc = nme_desc[nme.type]
			cur_tex = desc.tex			
				
			if nme.life < 0 or nme.hit_t > -1 then
				if nme.life < 0 then
					local size = set_nme_hit(-nme.life,15) * nme_radius[nme.type] * 0.8
					for i=1,3 do
						draw_explosion(get_random(projs),size)
					end
				else
					local size = set_nme_hit(nme.hit_t,6) * 3
					transform_pos(p0,cam_mat,nme.hit_pos)
					draw_explosion(p0,size)
				end
			end
				
			if cur_tex then
				t_light_dir = nme.light_dir
		
				local tri = desc.tri
				for j = 1,#tri do
					rasterize_tri(j,tri,projs)
				end
			end
			
			-- bounding sphere
			--transform_pos(p0,cam_mat,nme.pos)
			--circ(p0[1],p0[2],nme_radius[nme.type] * p0[3],7)
		end
	end
	
	color(8)
	draw_lasers(nme_lasers)
	
	color(11)
	draw_lasers(lasers)

	-- aim
	if cur_mode == 2 then	
		local idx = 97
		if tgt_pos then
			idx = 98
			transform_pos(p0,cam_mat,tgt_pos)
			transform_pos(p1,cam_mat,interp_tgt_pos)
			
			local x = p0[1] - 2
			local y = p0[2] - 4
			
			spr(113,x - 1,y + 1)
			spr(114,p1[1] - 3,p1[2] - 3)
			
			if aim_life_ratio then
				rectfill(x,y,x + 4,y,3)
				rectfill(x,y,x + aim_life_ratio * 4,y,11)
			end
		end
		
		spr(idx,aim_proj[1] - 3,aim_proj[2] - 3)
	end
	
	if (laser_spawned) cur_tex = ship_tex_laser_lit else cur_tex = ship_tex
		
	-- as the ship mesh is not convex, we need to z sort tris
	sort_tris(ship_tri,ship_proj)
	
	if hit_t != -1 then
		transform_pos(p0,cam_mat,hit_pos)
		draw_explosion(p0,3)
	
		if band(hit_t,0x1) == 0 then
			pal(0,2)
			pal(1,8)
			pal(6,14)
			pal(9,8)
			pal(10,14)
			pal(13,14)
		end
	end
	
	t_light_dir = ship_light_dir
	set_ngn_pal""
	
	for i=1,#ship_tri do
		rasterize_tri(i,ship_tri,ship_proj)
	end
	
	pal""
		
	-- lens flare
	if star_visible then
		draw_lens_flare""
	end
	
	if cur_mode == 2 then	
		print_3d("score "..score,1,1)
		spr(16,63,1,8,1)		
		clip(63,1,life * 16,7)
		spr(0,63,1,8,1)
		clip""
	elseif cur_mode != 1 then
		print_3d("hyperspace by j-fry",1,1)
		if cur_mode == 0 then
			if (score) print_3d("last score "..score,1,112)
			print_3d("best score "..best_score,1,120)
		else
			spr(99,1,112,1,2)
			print_3d(option_str[manual_fire + 1],9,112)
			print_3d(option_str[non_inverted_y + 3],9,120)
		end
	end
	
	if fade_ratio > 0 then
		draw_explosion({64,64,1},fade_ratio)
	end
	
	--color(7)
	--cursor(0,16)
	--print(stat(1))
	--print(cur_sequencer_x)
	--print(global_t)
	--print(next_sequencer_t)
	--print(game_spd)
	--print(nb_nme_ship)
	--print(waiting_nme_clear)
	--print(#nme_lasers)
end

__gfx__
70707070777077707777770777777770777777777777777777777777777777000000000000000000000000000000000000000000000000000001100000000000
b3b3b3b37bb37bb37bbbbb37bbbbbbb37bbbbbbbbbbbbbbbbbbbbbbbbbbbbb30000000000000000000000000000000000100111000000000101dd10000000000
b3b3b3b37bb37bb37bbbbb37bbbbbbb37bbbbbbbbbbbbbbbbbbbbbbbbbbbbb31000600000008000000090000000c0000100f66d1000000000ddffd1000000000
b3b3b3b37bb37bb37bbbbb37bbbbbbb37bbbbbbbbbbbbbbbbbbbbbbbbbbbbb3100676000008e8000009a900000c7c00010f7f6510007000001ffffd0000c0000
b3b3b3b37bb37bb37bbbbb37bbbbbbb37bbbbbbbbbbbbbbbbbbbbbbbbbbbbb31000600000008000000090000000c0000156f6d01000000001dfffdd100000000
0313131313331333133333313333333313333333333333333333333333333331000000000000000000000000000000001d66d0010000000011dfd1d000000000
0010101010111011101111110111111110111111111111111111111111111111000000000000000000000000000000000111001000000000001d101000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000
7070707077707770777777077777777077777777777777777777777777777700000d000000000000000000000001000000000000000000000001100000000000
6d6d6d6d766d766d766666d76666666d766666666666666666666666666666d0000600000008000000090000000c00000100111000000000101dd10000000000
6d6d6d6d766d766d766666d76666666d766666666666666666666666666666d100171000002e2000004a400000171000100f66d1000600000ddffd10000c0000
6d6d6d6d766d766d766666d76666666d766666666666666666666666666666d1d67776d008efe80009a7a9001c777c1010f7f6510067600001ffffd000c7c000
6d6d6d6d766d766d766666d76666666d766666666666666666666666666666d100171000002e2000004a400000171000156f6d01000600001dfffdd1000c0000
0d1d1d1d1ddd1ddd1dddddd1dddddddd1dddddddddddddddddddddddddddddd1000600000008000000090000000c00001d66d0010000000011dfd1d000000000
0010101010111011101111110111111110111111111111111111111111111111000d00000000000000000000000100000111001000000000001d101000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000
00000000000000000000000000000000000000010000000000000001000000000000000000010000000000000001010000000000000010000000000000101000
0000000000000000000000000000000000000001000000000000000c00000000000000000010d0000000200000c0c01000000000000d010000020000010c0c00
000000000000000000000001000000000000000c0000000000100007000010000001000001000d00000e02000c0c0c010000100000d000100020e00010c0c0c0
000000000000000000000001000000000000001c10000000000c0017100c00000010c000100000d000e0e02010c0c0c0000c01000d000001020e0e000c0c0c01
00000011100000000000001c10000000000001c7c10000000000c1c7c1c00000000c01000d000001020e0e000c0c0c010010c000100000d000e0e02010c0c0c0
000001ccc1000000000001c7c100000000001cc7cc10000000001c777c1000000000100000d000100020e00010c0c0c00001000001000d00000e02000c0c0c01
00001cc7cc10000000001cc7cc1000000001cc777cc100000001c77777c1000000000000000d010000020000010c0c00000000000010d0000000200000c0c010
00001c777c1000000011c77777c1100011cc7777777cc1101c77777777777c100000000000001000000000000010100000000000000100000000000000010100
00001cc7cc10000000001cc7cc1000000001cc777cc100000001c77777c1000000000000000e00000000000000000000000000000000e0000000000000000000
000001ccc1000000000001c7c100000000001cc7cc10000000001c777c1000000000000000e0200000001000000000000000000000020e000001000000000000
00000011100000000000001c10000000000001c7c10000000000c1c7c1c00000000400000e000200000c01000003000000004000002000e00010c00000003000
000000000000000000000001000000000000001c10000000000c0017100c00000040f000e000002000c0c0100030b000000f04000200000e010c0c00000b0300
000000000000000000000001000000000000000c000000000010000700001000000f04000200000e010c0c00000b03000040f000e000002000c0c0100030b000
0000000000000000000000000000000000000001000000000000000c0000000000004000002000e00010c00000003000000400000e000200000c010000030000
00000000000000000000000000000000000000010000000000000001000000000000000000020e0000010000000000000000000000e020000000100000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000e00000000000000000000
6666666666666666555555555555555588888899998888882222224444222222777dd777777557777771177777700777ddddddd66ddddddd1111111dd1111111
6666666666666666555555555555555588888899998888882222224444222222777dd777777557777771177777700777dd1111d66d1111dd1100001dd1000011
666555566666666655500005555555558888889aa98888882222224994222222777dd777777557777771177777700777dd11a1d66d1a11dd1100901dd1090011
66655666666656665550055555550555888888aeea888888222222988922222277dddd77775555777711117777000077ddd1a111111a1ddd1110900000090111
66666666666666665555555555555555888888aeea888888222222988922222277deed77775555777718817777000077ddd1a1d66d1a1ddd1110901dd1090111
6656666655665656550555550055050588888aeeeea88888222229888892222277deed77775555777718817777000077ddd111d66d111ddd1110001dd1000111
6655665556665556550055000555000588885aeeeea5888822220988889022227ddeedd7755555577118811770000007dddd11111111dddd1111000000001111
6566665555666566505555000055505588855aeeeea5588822200988889002227deeeed7755555577188881770000007dddd11d66d11dddd1111001dd1001111
6666655655666666555550050055555588955aeeeea5598822a0098888900a227deeeed7755555577188881770000007dddd11d66d11dddd1111001dd1001111
65566666565665665005555505055055889559aeea95598822a0049889400a227deeeed7755555577188881770000007ddddd111111ddddd1111100000011111
665566656666656655005550555550558885595aa59558882220040990400222dddddddd555555551111111100000000ddddd1d66d1ddddd1111101dd1011111
6556666666665666500555555555055588885955559588882222040000402222d666666d556666551dddddd100555500ddddd1d66d1ddddd1111101dd1011111
6655565666666666550005055555555588888995599888882222244004422222d611116d555555551d0000d100000000dddddddddddddddd1111111111111111
6665555666666566555000055555505588888995599888882222244004422222d611116d556666551d0000d100555500ddddddeeeedddddd1111118888111111
6655666566666666550055505555555588888999999888882222244444422222d666666d556666551dddddd100555500dddddddddddddddd1111111111111111
6656666666666666550555555555555588888999999888882222244444422222dddddddd555555551111111100000000dddddddddddddddd1111111111111111
0000000000000000000b00007777700055555555555555550000000000000000555555555555555d0000000000000001d11ddd1111ddd11d1001110000111001
00000000000b0000000b000075757d005555555555555555000000000000000055555555555555dd0000000000000011d11ddd1111ddd11d1001110000111001
00000000003030000030300055755d10555555555555555500000000000000005566666665555ddd0055555550000111da1ddd1661ddd1ad1901110550111091
000000000b000b00bb000bb075757d1055555555555555550000000000000000556666665555dd6d00555555000011d1d11ddd1661ddd11d1001110550111001
00000000003030000030300077777d105555555555555555000000000000000055666665555dd66d0055555000011dd1da1ddd1661ddd1ad1901110550111091
00000000000b0000000b00000ddddd10555555555555555500000000000000005566665555dd616d005555000011d0d1d11ddd1661ddd11d1001110550111001
0000000000000000000b00000011111055555565565555550000005005000000556665555dd6116d00555000011d00d1da1ddd1111ddd1ad1901110000111091
000000000000000000000000000000005555556556555555000000500500000055665555dd61116d0055000011d000d1d11ddd1661ddd11d1001110550111001
082a082a00000000bb000bb077577000555556655665555500000550055000005565555dd611116d005000011d0000d1d11ddd1111ddd11d1001110000111001
e4c6e4c603303300b00000b075557d0055555665566555550000055005500000555555dd6111116d00000011d00000d1d11ddd1111ddd11d1001110000111001
3b193b19030003000000000077777d105555666556665555000055500555000055555dd61111116d0000011d000000d1d11ddd1111ddd11d1001110000111001
d7f5d7f5000000000000000075557d10555566655666555500005550055500005555dd611111116d000011d0000000d1d11ddd1111ddd11d1001110000111001
082a082a030003000000000077577d1055566665566665550005555005555000555dd6111111116d00011d00000000d1d11ddd1111ddd11d1001110000111001
e4c6e4c603303300b00000b00ddddd105556666556666555000555500555500055dd66666666666d0011ddddddddddd1d11ddd1661ddd11d1001110550111001
3b193b1900000000bb000bb000111110556666655666665500555550055555005ddddddddddddddd0111111111111111d11ddd1111ddd11d1001110000111001
d7f5d7f500000000000000000000000055666665566666550055555005555500dddddddddddddddd1111111111111111d11ddd1111ddd11d1001110000111001
dddddddddddddddddddddddddddddddddddddbbbbbbddddd1111111111111111111111111111111111111bbbbbb1111188888888888888882222222222222222
dddddddddddddddddddddddddd1111dddddddbbbbbbddddd1111111111111111111111111100001111111bbbbbb1111188888888888888882222222222222222
dddddddddaaaaaabdddddd11111111dddddddbbbbbbddddd111111111999999b111111000000001111111bbbbbb1111188888888888888882222222222222222
dddddddddaaaaaabddd11111111111dddddddbbbbbbddddd111111111999999b111000000000001111111bbbbbb1111188888888888888882222222222222222
dddddddddaaaaaab11111111111111dddddddbb11bbddddd111111111999999b000000000000001111111bb00bb1111188888888888888882222222222222222
dddddddddaaaaaab11116616166111dddddddbb11bbddddd111111111999999b0000dd0d0dd0001111111bb00bb1111188888888888888882222222222222222
ddddddddddddddbbdddd6d6d66d6dddddddddb1111bddddd11111111111111bb1111d1d1dd1d111111111b0000b1111188888888888888882222222222222222
dbbbbbbbbb11111111111111111111dddddddb1111bddddd1bbbbbbbbb000000000000000000001111111b0000b1111188888888888888882222222222222222
dbbbbbbbbddddddddddddddddddddddddddddd1111dddddd1bbbbbbbb11111111111111111111111111111000011111188888888888888882222222222222222
dddddddddddddddddddddddddddddddddddddd1111dddddd11111111111111111111111111111111111111000011111188888888888888882222222222222222
dbbbbbddddbbbbbbbadddddddddddddddddddd1111dddddd1bbbbb1111bbbbbbb911111111111111111111000011111188888888888888882222222222222222
dbbbbb1dbdbbbbbbbabb111db11111dddddddd1111dddddd1bbbbb01b1bbbbbbb9bb0001b0000011111111000011111188888888888888882222222222222222
dbb66bdabdbbbbbbbabb111db11111dddddddd1111dddddd1bbddb19b1bbbbbbb9bb0001b0000011111111000011111188888888888888882222222222222222
dbbb6bdabdbbbbbbbabb111db11111dddddddd1111dddddd1bbbdb19b1bbbbbbb9bb0001b0000011111111000011111188888888888888882222222222222222
dbb6bbdabdbbbbbbbabb111db11111ddddddd111111ddddd1bbdbb19b1bbbbbbb9bb0001b0000011111110000001111188888888888888882222222222222222
dbbbbb1dbdbbbbbbbabb111db11111ddddddd111111ddddd1bbbbb01b1bbbbbbb9bb0001b0000011111110000001111188888888888888882222222222222222
dbbbbbddddbbbbbbbaddddddddddddddddddd111111ddddd1bbbbb1111bbbbbbb911111111111111111110000001111188888888888888882222222222222222
ddddddddddddddddddddddddddddddddddddd1d11d1ddddd11111111111111111111111111111111111110100101111188888888888888882222222222222222
dddddddddddddddddddddddddddddddddddd11d11d11dddd11111111111111111111111111111111111100100100111188888888888888882222222222222222
dddddddddddddddddddddddddd111ddddddd11d11d11dddd11111111111111111111111111000111111100100100111188888888888888882222222222222222
ddddddddddd1111111111ddddd111ddddddd11d11d11dddd11111111111000000000011111000111111100100100111188888888888888882222222222222222
dddddddddd11dddddddd11dddd111ddddddd1dd11dd1dddd11111111110011111111001111000111111101100110111188888888888888882222222222222222
ddddddddd11dccccccccd11dddddddddddd11d1111d11ddd111111111001cccccccc100111111111111001000010011188888888888888882222222222222222
dddddddd11dddddddddddd11ddddddddddd11d1881d11ddd11111111001111111111110011111111111001088010011188888888888888882222222222222222
ddddddd111111111111111111dddddddddd11d1111d11ddd11111110000000000000000001111111111001000010011188888888888888882222222222222222
dddddd11dddddd1111dddddd11ddddddddd1dd1ee1dd1ddd111111001111110000111111001111111110110ee011011188888888888888882222222222222222
ddddd11dccccccd11dccccccd11ddddddd11d111111d11dd11111001cccccc1001cccccc10011111110010000001001188888888888888882222222222222222
dddd1111dddddd1111dddddd1111dddddd11d11ff11d11dd111100001111110000111111000011111100100ff001001188888888888888882222222222222222
ddd11111111111111111111111111ddddd11d111111d11dd11100000000000000000000000000111110010000001001188888888888888882222222222222222
dd1111111111111111111111111111dddd11d111111d11dd11000000000000000000000000000011110010000001001188888888888888882222222222222222
dddddddddddddddddddddddddddddddddd111111111111dd11111111111111111111111111111111110000000000001188888888888888882222222222222222
dddddddddddddddddddddddddddddddddd111111111111dd11111111111111111111111111111111110000000000001188888888888888882222222222222222
dddddddddddddddddddddddddddddddddddddd1111dddddd111111111111111111111111111111111111110000111111aaa695a1ba1a1baa691ba1a1ba795aaa
dddddddddddddddddddddddddd1111dddddddd1111dddddd111111111111111111111111110000111111110000111111a111b222baaadbaaaa1aaa2aaa26aa2a
dddddddddaaaaaaddddddd11111111dddddddd1111dddddd111111111999999111111100000000111111110000111111aa2b795aa122baa11222baaa6db5aaad
dddddddddaaaaaadddd11111111111dddddddd1111dddddd111111111999999111100000000000111111110000111111a2aa2aa2baaa7aaaaa222b5aaaddb000
dddddddddaaaaaad11111111111111dddddddd1111dddddd11111111199999910000000000000011111111000011111100000000000000000000000000000000
dddddddddaaaaaad11116616166111dddddddd1111dddddd11111111199999910000dd0d0dd00011111111000011111100000000000000000000000000000000
dddddddddddddddddddd6d6d66d6dddddddddd1111dddddd11111111111111111111d1d1dd1d1111111111000011111100000000000000000000000000000000
ddddddd11111111111111111111111dddddddd1111dddddd11111110000000000000000000000011111111000011111100000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddd1111dddddd11111111111111111111111111111111111111000011111100000000000000000000000000000000
dddddddddddddddddddddddddddddddddddddd1111dddddd11111111111111111111111111111111111111000011111100000000000000000000000000000000
ddddddddddaaaaaaaadddddddddddddddddddd1111dddddd11111111119999999911111111111111111111000011111100000000000000000000000000000000
dd11111dadaaaaaaaad1111d111111dddddddd1111dddddd11000001919999999910000100000011111111000011111100000000000000000000000000000000
dd1661daadaaaaaaaad1111d111111dddddddd1111dddddd110dd019919999999910000100000011111111000011111100000000000000000000000000000000
dd1161daadaaaaaaaad1111d111111dddddddd1111dddddd1100d019919999999910000100000011111111000011111100000000000000000000000000000000
dd1611daadaaaaaaaad1111d111111ddddddd111111ddddd110d0019919999999910000100000011111110000001111100000000000000000000000000000000
dd11111dadaaaaaaaad1111d111111ddddddd111111ddddd11000001919999999910000100000011111110000001111100000000000000000000000000000000
ddddddddddaaaaaaaaddddddddddddddddddd111111ddddd11111111119999999911111111111111111110000001111100000000000000000000000000000000
ddddddddddddddddddddddddddddddddddddd1d11d1ddddd11111111111111111111111111111111111110100101111100000000000000000000000000000000
dddddddddddddddddddddddddddddddddddd11d11d11dddd11111111111111111111111111111111111100100100111100000000000000000000000000000000
dddddddddddddddddddddddddd111ddddddd11d11d11dddd11111111111111111111111111000111111100100100111100000000000000000000000000000000
ddddddddddd1111111111ddddd111ddddddd11d11d11dddd11111111111000000000011111000111111100100100111100000000000000000000000000000000
dddddddddd11dddddddd11dddd111ddddddd1dd11dd1dddd11111111110011111111001111000111111101100110111100000000000000000000000000000000
ddddddddd11dccccccccd11dddddddddddd11d1111d11ddd111111111001cccccccc100111111111111001000010011100000000000000000000000000000000
dddddddd11dddddddddddd11ddddddddddd11d1881d11ddd11111111001111111111110011111111111001088010011100000000000000000000000000000000
ddddddd111111111111111111dddddddddd11d1111d11ddd11111110000000000000000001111111111001000010011100000000000000000000000000000000
dddddd11dddddd1111dddddd11ddddddddd1dd1ee1dd1ddd111111001111110000111111001111111110110ee0110111611b222b000000000000000000000000
ddddd11dccccccd11dccccccd11ddddddd11d111111d11dd11111001cccccc1001cccccc100111111100100000010011d1b00000000000000000000000000000
dddd1111dddddd1111dddddd1111dddddd11d11ff11d11dd111100001111110000111111000011111100100ff001001122211b00000000000000000000000000
ddd11111111111111111111111111ddddd11d111111d11dd11100000000000000000000000000111110010000001001179995000000000000000000000000000
dd1111111111111111111111111111dddd11d111111d11dd110000000000000000000000000000111100100000010011ddbb0000000000000000000000000000
dddddddddddddddddddddddddddddddddd111111111111dd1111111111111111111111111111111111000000000000111b11b111b00000000000000000000000
dddddddddddddddddddddddddddddddddd111111111111dd11111111111111111111111111111111110000000000001171199900000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07070707077707770777007707770777007707770000077707070000077700000777077707070000000000000007000000000000000000000000000000000000
07d7d7d7d7d7d7ddd7d7d70dd7d7d7d7d70dd7ddd00007d7d7d7d000007dd00007ddd7d7d7d7d000000000000000000000000000000000000000000000000000
0777d777d777d7711771d7771777d777d7d0177111000771d777d100007d177707711771d777d100000000000000000000000000000000000000000000000000
07d7d1d7d7ddd7dd07d701d7d7ddd7d7d7d107dd000007d701d7d100007d10ddd7dd07d701d7d100000000000000000000000000000000000000000000000000
07d7d777d7d1177717d7d771d7d117d7d177077710000777d777d100077d100117d117d7d777d100000000000000000000000000000000000000000000000000
00d1d1ddd1d100ddd0d1d1dd01d100d1d10dd0ddd00000ddd1ddd10000dd100000d100d1d1ddd100000000000000000000000000000000000000000000000000
00010101110100011101010110010001010011011100000111011100000110000001000101011100000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000
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
0000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000
00000000000006000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000dd1d0000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000001101d11000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000d166611100000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000d1010d0d10000000000000000000000000000000000d00000000000000000000000000000000
0000000000000000000000000000000000000000000000000000dd1ddaaad1100000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000dd1d9a9d11010000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000dddaadddaa101000000000000800000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000d1d1a9a9a910100000000008e80000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000d1daaaaaaaa1010000000000800000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000d1d9a9a9a9a9101000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000d1daaaaaaaaa910100000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000d11da9a9a9a9a90010000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000dd1daaaaaaaaaa9001000000000000000000000000000000000000000000000000000000000
000000000006000000000000000000000000000000000000000000d1daaa9a9a9a11100100000000000000000000000000000000000000000000000000000000
000000000006000000000000000000000000000000000000000000d1ddaaaaaadddd010010000000000000000000000000000000000000000000000000000000
000000000006000000000000000000000000000000000000000000d11daa9d1d1101100001000000000000000000000000000000000000000000000000000000
000000000006000000000000000000000000000000000000000000d11daadd1111111d0100110000000000000000000000000000000000000000000000000000
000000000006000000000000000000000000000000000000000000d11daddd010101011010011000000000000000000000000000000000000000000000000000
000000000006000000000000000000000000000000000000000000dd1ddd1dd1111111d001000100000000000000000000000000000000000000000000000000
0000000000000000000000000900000000000000000000000000000d11d11dd101010d1d00100010000000000000000000000000000000000000000000000000
0000000000000000000000004a40000000000000000000000000000d11d111dd111dddd1d0d10001000000000000000000000000000000000000000000000000
000000000000000000000009a7a9000000000000000000000000000d11d111dd1d1d1101110dd000100000000000000000000000000000000000000000000000
0000000000000000000000004a40000000000000000000000000000d11dd11d1ddd111111d10d100010000000000000000000000000000000000000000000000
0000000000000000000000000900000000000000000000000000000d111d1111dd01010101100010001000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000dd11d1111dd1111111111000d000100000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d11d1111dd110101010d100d100010000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d11dd1111ddd11111111d100ddd001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d11dd6111d1d010101010d1000dd00100000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d1116661111dd11111111d1100ddd0011000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d1116661111dd10101011d11000dd1001100000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000dd11dd61111ddd1111dd1101100011100110000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000d11dd111111dd111d110000101001dd0011000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000d1166161111dddd11000101000110dd1000100000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000d1116d61111ddd100011cc1100011111100010000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000d111dd611111d10011ccc11000100010111111000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000d111dd111111d101ccc1100011c10000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000dd116611111110ccc1100011ccc00000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d116666111100c1100001ccc1110000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d1116661111011100001cc111000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d111666611001001010111100000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d1116d661100011c100011000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d111ddd610011ccc100000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000dd11dd61100cccc1000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000d116661101cc111000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000d11166100c11100000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000d111dd100110000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000d111d1000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000d111d0000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000dd1110000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000dd1100000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000d1100000000000000000000000000000000000d00000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000d10000000000000000000000000000000000000d0000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000d000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000000000000
077707770077077700000077007700770777077700000700077707101dd100000000000000000000000000000000000000000000000000000000000000000000
07d7d7ddd70dd07dd000070dd70dd707d7d7d7ddd00007d007ddd7dddffd10000000000000000000000000000000000000000000000000000000000000000000
0771d7711777117d1100077717d017d7d771d7711100077707771777ffffd0000000000000000000000000000000000000000000000000000000000000000000
07d707dd00d7d07d100000d7d7d107d7d7d707dd000007d7d0d7d7d7dffdd1000000000000000000000000000000000000000000000000000000000000000000
0777d7771771d17d10000771d1770771d7d7d77710000777d777d777d1d1d0000000000000000000000000000000000000000000000000000000000000000000
00ddd1ddd0dd010d100000dd010dd0dd01d1d1ddd00000ddd1ddd1ddd11010000000000000000000000000000000000000000000000000000000000000000000
00011101110110001000000110001101100101011100000111011101110000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__map__
1002fdf002050cfe050cfefdf00afd10f6fd1006ff0efaff0e180200031504863d1506223d210200031506863d210822032102c103110a923d110e0f380c029403110ebe380c04123301066b330110be380c08120311083e03111092380c0c0f3d110400152710d7373406862b27040015270ed80934108937340a00013b0ca6
3f3b0ea609340c003f3b10a637340ea6093402004e01087e52010c005f3f02004e010c7e5f3f0a00413f0a0204020003fc05fe03fc0203fffa000c0292050104d00a10062c001002290f010887141004060a1002f4190106e51e10088414100ab4051f062f001004580a100a6b0f1f04100a10083f14100a16191f0832141006
8e1e100800000a0004fafafe0006fe0006024a1001069c1f1304e7101f02b51001049c101f08e7011302001021087c013f06e71f3f0e000008fe04fc0204fcf8ff0008ff00fefefc02fefc0c020008010487101f06d7011f0239013f08971f2104d31f3f02c6013f06971f3f0ad31f21020018010e7d101f0ceb1f1f02061d21
0c7c012108ea013d02f91d210a7c013d0eea01210efe0014020014fef8fe02f8fef800f80800f80004fc0e0200143f04770c3f08d40c240200143f08770c2406d41424026b1f3f063f14240ae81f210494013f0c3f012108e80c2402000c1f0e82100404eb141f023d0c1f0a9101010ef2100404c2141f0e9110040cf21f0100
__sfx__
0001000d322303323033230312302e230292302423022230202301d2301c2301c2201c2101c2001c2001c000324003340033400314002e400294002440022400204001d4001c4001c4001c400014000140001400
000500002467024670276702a67031670386703f6703f670306702967024670206701e6601c6601b6501a650196401964018630196301a6201c62020610236100a6000b6000d6001060012600146001760018600
000300002d6702947024470196701e470206701d6700d6701667014470104700f470136700b470094700766007450054400863002420014100c60005600016000160001600036000160002600016000160000000
000100003c3703c070371703907036070330702f170300702907022070200701b070170701d1701407013070120701207013070150701217017070121701e070270702c07035070360701c170211702e17000000
0001000d2c4401204001020010000a60002000010000e0000e0000e00004600046000460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002c4702847023470204701c4701a4701746015440154201440016400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0018000000000073600144007360014401a370014401b37001440173701737017370173701736017350173000140001400173000b400170001700017000170000000000000000000000000000000000000000000
002000000d2700d270082700827004270042700127001270012700127001270012700120001200012000120001300014000320001400014000340004400054000740005400064000540005400054000140000000
001700001d4001d4001d4001d4001d40014400104000140013400113000f3000d3000c3000a300083000630005300023000130000000000000000000000000000000000000000000000000000000000000000000
