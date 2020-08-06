--CHANGES: The codes now don't allow the same player to have the reward multiple times
--without those changes the player can get infinite itens as reward
--The textures were also changed to 63 pixels for greater resolution and the blocks colors now are equal to the 
--white clay color, allowing the blocks to merge in buildings made of white clay. 

--ADVICES: I'm not a mod builder therefore I don't know how to do it. Now the game remembers the players who solved the 
--problem during a section of the game, but once the server is shutdown the game restart the list of players who solved it.
--It would be useful to save the players names between sections and maybe even build a sign node with the names of the players
--who solved.

-- check if node at pos is a digit
local function node_is_digit(pos)
	local node = minetest.get_node(pos)
	local nd = minetest.registered_nodes[node.name]
	if nd == nil then
		return false
	end
	if nd.groups == nil then
		return false
	end
	if nd.groups.teaching_util == nil then
		return false
	end
	return true
end

-- check if node at pos is the digit dg
local function node_is_spec_digit(pos, dg)
	if not node_is_digit(pos) then
		return false
	end
	local node = minetest.get_node(pos)
	local nd = minetest.registered_nodes[node.name]
	if type(nd.teaching_digit) == 'table' then
		for _, digit in ipairs(nd.teaching_digit) do
			if digit == dg then
				return true
			end
		end
	elseif type(nd.teaching_digit) == 'string' then
		if nd.teaching_digit == dg then
			return true
		end
	end
	return false
end

--CHANGE: check if a table contain a certain value
local function tab_has_value (tab, val)
    if tab == nil then return false end
    if type(tab) == 'table' then
		for idx, value in ipairs(tab) do
			if value == val then
				return true
			end
        end
        return false
	elseif type(tab) == 'string' then
		if tab == val then
			return true
		end
		return false
    end
end

--CHANGE: place a specific value on the last index of a table
local function place_value_tab(tab,val)
	if type(tab) == 'table' then
		tab[#tab+1] = val
	elseif type(tab) == 'string' then
		tab = {tab, val}
	end
	if tab == nil then 
		tab = val
	end
	return tab
end

-- check a solution placed by player (checker node at pos) and give prizes if correct
local players_who_solved = {'adm_name','moderator_name'}
local function check_solution(pos, player, players_who_solved)
	local meta = minetest.get_meta(pos)
	local sol = meta:get_string('solution')
	if node_is_spec_digit({x=pos.x, y=pos.y+1, z=pos.z}, sol) then 
		if meta:get_string('b_lock') == 'true' then
			-- Place a lab block (indestructible for students) where the solution was
			-- CHANGE: isn't better to put a destructible block, so others players can solve it?
			minetest.set_node({x=pos.x, y=pos.y+1, z=pos.z}, {name="teaching:util_empty"}) 
		end
		if meta:get_string('b_saytext') == 'true' then
			minetest.chat_send_player(player:get_player_name(), meta:get_string('s_saytext'))
		end
		if meta:get_string('b_dispense') == 'true' then
			--CHANGE: don't allow the same player to have a reward after answering again
			if not tab_has_value(players_who_solved,player:get_player_name()) then
				minetest.add_item({x=pos.x, y=pos.y+2, z=pos.z}, meta:get_inventory():get_list('dispense')[1])
			end
		end
		-- CHANGE: Saves player name if it weren't already saved
		if not tab_has_value(players_who_solved,player:get_player_name()) then 
			player_s = player:get_player_name()
			players_who_solved = place_value_tab(players_who_solved, player_s)
			return players_who_solved
		end
	end
end

-- can_dig callback that only allows teachers or freebuild to destroy the node
local function only_dig_teacher_or_freebuild(pos, player)
	if minetest.check_player_privs(player:get_player_name(), {teacher=true}) then
		return true
	elseif minetest.check_player_privs(player:get_player_name(), {freebuild=true}) then
		return true
	else
		return false
	end
end

local function register_util_node(name, digit, humanname)
	minetest.register_node('teaching:util_' .. name, {
		drawtype = 'normal',
		tiles = {'teaching_lab.png', 'teaching_lab.png', 'teaching_lab.png', 
			'teaching_lab.png', 'teaching_lab.png', 'teaching_lab_util_' .. name .. '.png'},
		--CHANGE: this paramtype is need for the blocks to face the player direction
		paramtype2 = 'facedir',
		description = humanname,
		groups = {teaching_util=1, snappy=3},
		teaching_digit = digit,
		can_dig = function(pos, player)					
			if minetest.check_player_privs(player:get_player_name(), {teacher=true}) then
				return true
			else			
				local node = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z})	
				if node.name == 'teaching:lab_checker' or node.name == 'teaching:lab_allowdig' then
					return true
				else
					return false
				end
			end
		end,
	})
end

minetest.register_privilege('teacher', {
      description = "Teacher privilege",
      give_to_singleplayer = false,
})

minetest.register_privilege('freebuild', {
      description = "Free-building privilege",
      give_to_singleplayer = false,
})

minetest.register_node('teaching:lab', {
		drawtype = 'normal',
		tiles = {'teaching_lab.png'},
		description = 'Lab block',
		groups = {oddly_breakable_by_hand=2},
		can_dig = only_dig_teacher_or_freebuild,
})

minetest.register_node('teaching:lab_allowdig', {
		drawtype = 'normal',
		--CHANGE: this paramtype is need for the blocks to face the player direction
		paramtype2 = 'facedir',
		tiles = {'teaching_lab.png','teaching_lab.png','teaching_lab.png', 
			'teaching_lab.png','teaching_lab.png','teaching_lab_allowdig.png'},
		description = 'Allow-dig block (allows students to break block above)',
		groups = {oddly_breakable_by_hand=2},
		can_dig = only_dig_teacher_or_freebuild,
})

local checker_formspec = 
	'size[8,9]'..
	'field[0.5,0.5;2,1;solution;Correct solution:;${solution}]'..
	'checkbox[2.5,0.2;b_lock;Lock once solved?;${b_lock}]'..
	'label[0.25,1;Action if right:]'..
	'checkbox[0.5,1.5;b_saytext;Say text:;${b_saytext}]'..
	'field[2.4,1.9;3,0.75;s_saytext;;${s_saytext}]'..
	'checkbox[0.5,2.25;b_dispense;Dispense item:;${b_dispense}]'..
	'list[nodemeta:${x},${y},${z};dispense;1,2.9;1,1;]'..
	'list[current_player;main;0,5;8,4;]'..
	'button_exit[0.3,4;2,1;save;Save]'

minetest.register_on_player_receive_fields(function(sender, formname, fields)
	if formname:find('teaching:lab_checker_') == 1 then
		local x, y, z = formname:match('teaching:lab_checker_(.-)_(.-)_(.*)')
		local pos = {x=tonumber(x), y=tonumber(y), z=tonumber(z)}
		--print("Checker at " .. minetest.pos_to_string(pos) .. " got " .. dump(fields))
		local meta = minetest.get_meta(pos)
		if fields.b_saytext ~= nil then -- If we get a checkbox value we need to save that immediately because they are not sent on clicking 'Save' (due to a bug in minetest)
			meta:set_string('b_saytext', fields.b_saytext)
		end
		if fields.b_dispense ~= nil then -- ditto
			meta:set_string('b_dispense', fields.b_dispense)
		end
		if fields.b_lock ~= nil then -- ditto
			meta:set_string('b_lock', fields.b_lock)
		end
		if fields.save ~= nil then
			meta:set_string('solution', fields.solution)
			if meta:get_string('b_saytext') == 'true' then
				meta:set_string('s_saytext', fields.s_saytext)
			end
		end
	end
end)

minetest.register_node('teaching:lab_checker', {
		drawtype = 'normal',
		tiles = {'teaching_lab.png', 'teaching_lab.png','teaching_lab.png', 
			'teaching_lab.png','teaching_lab.png','teaching_lab_checker.png'},
		description = 'Checking block',
		paramtype2 = 'facedir',
		groups = {oddly_breakable_by_hand=1},
		can_dig = only_dig_teacher_or_freebuild,
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("dispense", 1)
		end,
		on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			if minetest.check_player_privs(clicker:get_player_name(), {teacher=true}) then
				local meta = minetest.get_meta(pos)
				local formspec = checker_formspec
				formspec = formspec:gsub('${x}', pos.x)
				formspec = formspec:gsub('${y}', pos.y)
				formspec = formspec:gsub('${z}', pos.z)
				formspec = formspec:gsub('${(.-)}', function(name) return meta:get_string(name) end)
				minetest.show_formspec(clicker:get_player_name(), 'teaching:lab_checker_'..pos.x..'_'..pos.y..'_'..pos.z, formspec)
				-- We need to ue this complicated way because MT does not allow us to deny showing the formspec to some people
			else
				if not itemstack:is_empty() then
					if minetest.registered_nodes[itemstack:get_name()] ~= nil then
						if minetest.registered_nodes[itemstack:get_name()].teaching_digit ~= nil then
							-- Someone wants to place a utility node, we can do that
							local newpos = {x=pos.x, y=pos.y+1, z=pos.z} -- FIXME: This assumes said person wants to place node on top
							minetest.set_node(newpos, {name=itemstack:get_name(), param2=minetest.dir_to_facedir(clicker:get_look_dir())})
							itemstack:take_item()
							minetest.log('action', clicker:get_player_name() .. ' places ' .. node.name .. ' at ' .. minetest.pos_to_string(newpos))
							check_solution(pos, clicker, players_who_solved)
						end -- We don't have way to pass on_rightclick along
					end
				end
				return false
			end
		end,
})

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if not minetest.check_player_privs(placer:get_player_name(), {teacher=true}) then
		if minetest.registered_nodes[newnode.name].teaching_digit ~= nil then
			local below = minetest.get_node({x=pos.x, y=pos.y-1, z=pos.z})
			if below.name == 'teaching:lab_checker' then
				if not placer:get_player_name() then
					return minetest.log('warning', 'placenode event triggered without valid player')
				end
				check_solution(pos, placer,players_who_solved)
			else
				if minetest.check_player_privs(placer:get_player_name(), {freebuild=true}) then
					return false
				else
					minetest.set_node(pos, oldnode)
					return true -- Don't take item
				end
			end
		end
	end
end)

-- CHANGES: Adds other math related characters
-- Alphanumeric Register
local s = 'aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ0123456789'
for i in s:gmatch('.') do
	register_util_node(i, i, i)
end

--Greek letters
local greek_letters = {'alpha','beta','delta','Delta','gamma','lambda','mu','nu','omega','Omega','phi','phi2','Phi','pi','psi','Psi','rho','shima','sigma','tau','theta','xi'}
for idx, value in ipairs (greek_letters) do
	register_util_node(value,value,value)
end

--Arrows
local arrows = {'up','down','left','right'}
for idx, value in ipairs (arrows) do
	register_util_node(value,value,'Arrow ' .. value)
end

--Some Symbols 
local symbols = {'summation','product','integral','infinite'}
for idx, value in ipairs (symbols) do
	register_util_node(value,value,value)
end

--Powers of a
register_util_node('a2', {'a^2','a²'}, ' a² (Square of a)')
register_util_node('a3', {'a^3','a³'}, ' a³ (Cube of a)')
register_util_node('a4', {'a^4','a⁴'}, ' a⁴ (Quartic of a)')
register_util_node('a5', {'a^5','a⁵'}, ' a⁵ (Quintic of a)')
register_util_node('an', 'a^n', ' a^n (a raised to the n-th power)')
--Powers of b
register_util_node('b2', {'b^2','b²'}, ' b² (Square of b)')
register_util_node('b3', {'b^3','b³'}, ' b³ (Cube of b)')
register_util_node('b4', {'b^4','b⁴'}, ' b⁴ (Quartic of b)')
register_util_node('b5', {'b^5','b⁵'}, ' b⁵ (Quintic of b)')
register_util_node('bn', 'b^n', ' b^n (b raised to the n-th power)')
--Powers of c
register_util_node('c2', {'c^2','c²'}, ' c² (Square of c)')
register_util_node('c3', {'c^3','c³'}, ' c³ (Cube of c)')
register_util_node('c4', {'c^4','c⁴'}, ' c⁴ (Quartic of c)')
register_util_node('c5', {'c^5','c⁵'}, ' c⁵ (Quintic of c)')
register_util_node('cn', 'c^n', ' c^n (c raised to the n-th power)')
--Powers of x
register_util_node('x2', {'x^2','x²'}, ' x² (Square of x)')
register_util_node('x3', {'x^3','x³'}, ' x³ (Cube of x)')
register_util_node('x4', {'x^4','x⁴'}, ' x⁴ (Quartic of x)')
register_util_node('x5', {'x^5','x⁵'}, ' x⁵ (Quintic of x)')
register_util_node('xn', 'x^n', ' x^n (x raised to the n-th power)')
--Powers of y
register_util_node('y2', {'y^2','y²'}, ' y² (Square of y)')
register_util_node('y3', {'y^3','y³'}, ' y³ (Cube of y)')
register_util_node('y4', {'y^4','y⁴'}, ' y⁴ (Quartic of y)')
register_util_node('y5', {'y^5','y⁵'}, ' y⁵ (Quintic of y)')
register_util_node('yn', 'y^n', ' y^n (y raised to the n-th power)')
--Powers of z
register_util_node('z2', {'z^2','z²'}, ' z² (Square of z)')
register_util_node('z3', {'z^3','z³'}, ' z³ (Cube of z)')
register_util_node('z4', {'z^4','z⁴'}, ' z⁴ (Quartic of z)')
register_util_node('z5', {'z^5','z⁵'}, ' z⁵ (Quintic of z)')
register_util_node('zn', 'z^n', ' z^n (z raised to the n-th power)')
--Derivatives
register_util_node('d2', {'d^2','d²'}, ' d² (Second Derivative)')
register_util_node('d3', {'d^3','d³'}, ' d³ (Third Derivative)')
register_util_node('d4', {'d^4','d⁴'}, ' d⁴ (Fourth Derivative)')
register_util_node('d5', {'d^5','d⁵'}, ' d⁵ (Fifth Derivative)')
register_util_node('dn', 'd^n', ' d^n (n-th Derivative)')
--Symbols
register_util_node('and', {'&','and'}, ' And Operator')
register_util_node('and2', {'&','and'}, ' And Operator')
register_util_node('approx', '~', ' Almost Equal')
register_util_node('atsign', '@', '@ (At Sign)')
register_util_node('colon', ':', ': (Colon)')
register_util_node('comma', ',', ', (Comma)')
register_util_node('division', {':','/'}, ' Division')
register_util_node('equal', '=', ' = (Equal)')
register_util_node('ellipsis_low', '...', ' Ellipsis Dots (etc)')
register_util_node('ellipsis_mid', '...', ' Ellipsis Dots (etc)')
register_util_node('dollar_sign', '$', '$ (Dollar Sign)')
register_util_node('factorial', '!', '! (Factorial)')
register_util_node('hashtag', '#', '# (Hashtag)')
register_util_node('less', '<', '< (Less than)')
register_util_node('less_equal', '<=', '< (Less or Equal than)')
register_util_node('more', '>', '> (Greater than)')
register_util_node('more_equal', '>=', '> (Greater or Equal than)')
register_util_node('multiply_lowdot', {'.','x'}, 'Multiply Low Dot')
register_util_node('multiply_middot', {'.','x'}, 'Multiply Low Dot')
register_util_node('multiply', {'.','x'}, 'x (Multiply, Times Sign)')
register_util_node('minus', '-', '- (Subtraction, Minus Sign)')
register_util_node('percent', '%', '% (Percent)')
register_util_node('plus', '+', '+ (Sum, Plus Sign)')
register_util_node('plus_minus', '+-', 'Plus or Minus')
register_util_node('question', '?', '? (Question Mark)')
register_util_node('slash','/','/ (Slash)')
register_util_node('underscore','_','_ (Underscore)')
--Brackets
register_util_node('bracket_left','[','[ (Left Bracket)')
register_util_node('bracket_left_down','[','Left Bracket Down')
register_util_node('bracket_left_up','[','Left Bracket Up')
register_util_node('bracket_mid','|','Bracket Mid')
register_util_node('bracket_right',']','] (Right Bracket)')
register_util_node('bracket_right_down',']','Right Bracket Down')
register_util_node('bracket_right_up',']','Right Bracket Up')
--Parenthesis
register_util_node('parenthesis_left','(','Left Parenthesis')
register_util_node('parenthesis_right',')','Right Parenthesis')
register_util_node('parenthesis_right_2',')^2','Square Right Parenthesis')
register_util_node('parenthesis_right_3',')^3','Cube Right Parenthesis')
register_util_node('parenthesis_right_4',')^4','Quartic Right Parenthesis')
register_util_node('parenthesis_right_5',')^5','Quintic Right Parenthesis')
register_util_node('parenthesis_right_n',')^n','n-th Right Parenthesis')
register_util_node('parenthesis_in','(','Left Parenthesis')
register_util_node('parenthesis_out',')','Right Parenthesis')
--Square Roots
register_util_node('sqrt','^1/2','Square Root')
register_util_node('sqrt3','^1/3','Cubic Root')
register_util_node('sqrt4','^1/4','Quartic Root')
register_util_node('sqrt5','^1/5','Quintic Root')
register_util_node('sqrtn','^1/n','n-th Root')
register_util_node('sqrtp',')^1/2','Square Root Parenthesis')
register_util_node('sqrtp3',')^1/3','Cubic Root Parenthesis')
register_util_node('sqrtp4',')^1/4','Quartic Root Parenthesis')
register_util_node('sqrtp5',')^1/5','Quintic Root Parenthesis')
register_util_node('sqrtpn',')^1/n','n-th Root Parenthesis')
--Rectangles and Squares
register_util_node('geometric_lines_diagonal','gl-d','Square Diagonal')
register_util_node('geometric_lines_down','gl-xlow','Rectangles Low Side')
register_util_node('geometric_lines_left','gl-yleft','Rectangles Left Side')
register_util_node('geometric_lines_left_down','gl-xlow-yleft','Rectangles Left Lower Corner')
register_util_node('geometric_lines_left_down_diagonal','gl-xlow-yleft-d','Square Left Lower Corner Diagonal')
register_util_node('geometric_lines_left_up','gl-xhigh-yleft','Rectangles Left Higher Corner')
register_util_node('geometric_lines_right','gl-yright','Rectangles Right Side')
register_util_node('geometric_lines_right_down','gl-xlow-yright','Rectangles Right Lower Corner')
register_util_node('geometric_lines_right_up','gl-xhigh-yright','Rectangles Right Higher Corner')
register_util_node('geometric_lines_right_up_diagonal','gl-xhigh-yright-d','Square Right Higher Corner Diagonal')
register_util_node('geometric_lines_square','gl-sq','Square')
register_util_node('geometric_lines_up','gl-xhigh','Rectangles Higher Side')

--FRACTIONS
--Powers of x
register_util_node('fraction_x', '1/x', ' 1/x (1 over x)')
register_util_node('fraction_x2', {'1/x^2','1/x²'}, ' 1/x² (1 over Square of x)')
register_util_node('fraction_x3', {'1/x^3','1/x³'}, ' 1/x³ (1 over Cube of x)')
register_util_node('fraction_x4', {'1/x^4','1/x⁴'}, ' 1/x⁴ (1 over Quartic of x)')
register_util_node('fraction_x5', {'1/x^5','1/x⁵'}, ' 1/x⁵ (1 over Quintic of x)')
register_util_node('fraction_xn', '1/x^n', ' 1/x^n (1/x raised to the n-th power)')
--Powers of y
register_util_node('fraction_y', '1/y', ' 1/y (1 over y)')
register_util_node('fraction_y2', {'1/y^2','1/y²'}, ' 1/y² (1 over Square of y)')
register_util_node('fraction_y3', {'1/y^3','1/y³'}, ' 1/y³ (1 over Cube of y)')
register_util_node('fraction_y4', {'1/y^4','1/y⁴'}, ' 1/y⁴ (1 over Quartic of y)')
register_util_node('fraction_y5', {'1/y^5','1/y⁵'}, ' 1/y⁵ (1 over Quintic of y)')
register_util_node('fraction_yn', '1/y^n', ' 1/y^n ( 1/y raised to the n-th power)')
--Powers of z
register_util_node('fraction_z', '1/z', ' 1/z (1 over z)')
register_util_node('fraction_z2', {'1/z^2','1/z²'}, ' 1/z² (1 over Square of z)')
register_util_node('fraction_z3', {'1/z^3','1/z³'}, ' 1/z³ (1 over Cube of z)')
register_util_node('fraction_z4', {'1/z^4','1/z⁴'}, ' 1/z⁴ (1 over Quartic of z)')
register_util_node('fraction_z5', {'1/z^5','1/z⁵'}, ' 1/z⁵ (1 over Quintic of z)')
register_util_node('fraction_zn', '1/z^n', ' 1/z^n (1/z raised to the n-th power)')
--Derivatives
register_util_node('fraction_d', '1/d', ' 1/d (Derivative)')
--Numbers
register_util_node('fraction_1', '1/1', ' 1/1 (1 over 1)')
register_util_node('fraction_2', '1/2', ' 1/2 (1 over 2)')
register_util_node('fraction_3', '1/3', ' 1/3 (1 over 3)')
register_util_node('fraction_4', '1/4', ' 1/4 (1 over 4)')
register_util_node('fraction_5', '1/5', ' 1/5 (1 over 5)')
register_util_node('fraction_6', '1/6', ' 1/6 (1 over 6)')
register_util_node('fraction_7', '1/7', ' 1/7 (1 over 7)')
register_util_node('fraction_8', '1/8', ' 1/8 (1 over 8)')
register_util_node('fraction_9', '1/9', ' 1/9 (1 over 9)')
--Symbols
register_util_node('fraction_minus', '/-', ' Over Minus')
register_util_node('fraction_multiply', '/x', ' Over Times')
register_util_node('fraction_plus', '/+', ' Over plus')
--Parenthesis
register_util_node('fraction_parenthesis_left','/(','Left Parenthesis Fraction')
register_util_node('fraction_parenthesis_right','/)','Right Parenthesis Fraction')
register_util_node('fraction_parenthesis_right_2','/)^2','Square Right Parenthesis Fraction')
register_util_node('fraction_parenthesis_right_3','/)^3','Cube Right Parenthesis Fraction')
register_util_node('fraction_parenthesis_right_4','/)^4','Quartic Right Parenthesis Fraction')
register_util_node('fraction_parenthesis_right_5','/)^5','Quintic Right Parenthesis Fraction')
register_util_node('fraction_parenthesis_right_n','/)^n','n-th Right Parenthesis Fraction')

--Empty Blocks
register_util_node('empty',' ','Empty Block')
register_util_node('fraction_empty',' ','Fraction Empty Block')
