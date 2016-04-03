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

-- check a solution placed by player (checker node at pos) and give prizes if correct
local function check_solution(pos, player)
	local meta = minetest.get_meta(pos)
	local sol = meta:get_string('solution')
	if node_is_spec_digit({x=pos.x, y=pos.y+1, z=pos.z}, sol) then
		if meta:get_string('b_saytext') == 'true' then
			minetest.chat_send_player(player:get_player_name(), meta:get_string('s_saytext'))
		end
		if meta:get_string('b_dispense') == 'true' then
			minetest.add_item({x=pos.x, y=pos.y+2, z=pos.z}, meta:get_inventory():get_list('dispense')[1])
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
		tiles = {'teaching_lab_allowdig.png'},
		description = 'Allow-dig block (allows students to break block above)',
		groups = {oddly_breakable_by_hand=2},
		can_dig = only_dig_teacher_or_freebuild,
})

local checker_formspec = 
	'size[8,9]'..
	'field[0.5,0.5;3,1;solution;Correct solution:;${solution}]'..
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
		if fields.b_saytext ~= nil then -- If we get b_saytext or b_dispense we need to save that immediately because they are not sent on clicking 'Save' (due a bug in minetest)
			meta:set_string('b_saytext', fields.b_saytext)
		end
		if fields.b_dispense ~= nil then -- ditto
			meta:set_string('b_dispense', fields.b_dispense)
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
		tiles = {'teaching_lab_checker.png'},
		description = 'Checking block',
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
							local newpos = {x=pos.x, y=pos.y+1, z=pos.z} -- XXX: This assumes said person wants to place node on top
							minetest.set_node(newpos, {name=itemstack:get_name(), param2=minetest.dir_to_facedir(clicker:get_look_dir())})
							itemstack:take_item()
							minetest.log('action', clicker:get_player_name() .. ' places ' .. node.name .. ' at ' .. minetest.pos_to_string(newpos))
							check_solution(pos, clicker)
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
				check_solution(pos, placer)
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

local s = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
for i in s:gmatch('.') do
	register_util_node(i, i, i)
end

register_util_node('decimalpoint', '.', '. (Decimal point)')
register_util_node('divide', {':', '/'}, ': (Divide)')
register_util_node('equals', '=', '= (Equals)')
register_util_node('less', '<', '< (Less than)')
register_util_node('minus', '-', '- (Minus)')
register_util_node('more', '>', '> (More than)')
register_util_node('multiply', {'*', 'x'}, '* (Multiply)')
register_util_node('plus', '+', '+ (Plus)')

