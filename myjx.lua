--go@ ../lua-files/bin/luajit.exe myjx.lua 54 resume1.odt resume1-result.odt
package.path='?.lua;../lua-files/?.lua'
require'strict'
local pp = require'pp'.pp
io.stdout:setvbuf'no'

local mysql = require'mysql'
local zip = require'minizip'
local glue = require'glue'

--odt document templating

local replace_repeated_section --forward decl.

local function replace_section(s, t)
	for k,v in pairs(t) do
		if type(k) == 'string' then
			if type(v) == 'string' then
				s = s:gsub(string.format('{%s}', k), v)
			elseif type(v) == 'table' then
				s = replace_repeated_section(s, k, v)
			end
		end
	end
	return s
end

local function find_enclosing_tag(s, i)
	local rs = s:reverse()
	while i > 0 do
		if s:sub(i) == '>' then
	end
end

function replace_repeated_section(s, name, rows)
	local i1, i2 = find_enclosing_tag(s, s:find(string.format('{start_%s}', name), 1, true))
	local i3, i4 = find_enclosing_tag(s, s:find(string.format('{end_%s}', name), 1, true))
	if not i1 or not i3 then return s end
	local template = s:sub(i2, i3)
	local dt = {}
	for i,row in ipairs(rows) do
		dt[i] = replace_section(template, row)
	end
	local content = table.concat(dt)
	return s:sub(1, i1) .. content .. s:sub(i4)
end

local function gen_doc(template_file, dest_file, data)
	local src = zip.open(template_file, 'r')
	local dst = zip.open(dest_file, 'w')
	for t in src:files() do
		if data[t.filename] then
			local template = src:extract(t.filename)
			local result = replace_section(template, data[t.filename])
			dst:archive(t.filename, result)
		else
			dst:copy_from_zip(src)
		end
	end
	src:close()
	dst:close()
end

--mysql resume data gathering

--given a mysql connection object, return a function query(sql, param1_value, ...) -> rows_t
local function query_function(conn)
	return function(sql, ...)
		local n = select('#', ...)
		local ptypes = {}
		for i=1,n do
			local v = tostring(select(i, ...))
			ptypes[i] = 'varchar('..#v..')'
		end
		local stmt = conn:prepare(sql)
		local params = stmt:bind_params(ptypes)
		for i=1,n do
			params:set(i, tostring(select(i, ...)))
		end
		local fields = stmt:bind_result()
		stmt:exec()
		stmt:store_result()
		local field_names = {}
		for i,field in stmt:fields() do
			field_names[i] = field.name
		end
		local rows = {
			fields = field_names,
			field_indices = glue.index(field_names)
		}
		while stmt:fetch() do
			local row = {}
			for i=1,fields.count do
				local v = fields:get(i)
				row[i] = tostring(v) -- type(v) == 'table' and tostring(v) or v
			end
			rows[#rows+1] = row
		end
		--require'mysql_print'.table(field_names, rows, nil, 20)
		return rows
	end
end

local query --forward decl.

local function kv_row(i, rows) --given a rows_t, return row i as an associative array
	local t = {}
	for j=1,#rows.fields do
		t[rows.fields[j]] = rows[i][j]
	end
	return t
end

local function kv_rows(rows) --given a rows_t, return a list of kv_row()'s
	local t = {}
	for i=1,#rows do
		t[i] = kv_row(i, rows)
	end
	return t
end

local function group_by(by, rows)
	local t = {}
	by = rows.field_indices[by]
	for i=1,#rows do
		t[rows[i][by]] = kv_row(i, rows)
	end
	return t
end

local function get_resume(id)
	return kv_row(1, query([[
	select
		p.first_name as first_name,
		p.last_name as last_name,
		p.nickname as nickname,
		r.formatted_name as resume_name
	from
		profiles p,
		resumes r
	where
		r.profile_id = p.id
		and r.id = ?
	;
	]], id))
end

local function get_resume_sections(resume_id)
	return kv_rows(query([[
	select
		rs.id,
		rs.display_name as name
	from
		resume_sections rs
	where
		rs.resume_id = ?
	order by
		rs.position,
		rs.display_name
	]], resume_id))
end

local function get_section_entries(section_id)
	return kv_rows(query([[
	select
		re.resume_entry_foundation_type as class_name,
		re.resume_entry_foundation_id as obj_id
	from
		resumes r,
		resume_sections rs,
		resume_entry_types ret,
		resume_entries re,
		resume_section_memberships rsm
	where
		rs.resume_id = r.id
		and rs.resume_entry_type_id = ret.id
		and re.profile_id = r.profile_id
		and re.resume_entry_foundation_type = ret.class_name
		and rsm.section_id = rs.id and rsm.entry_id = re.id
		and rs.id = ?
	order by
		rsm.position,
		rsm.updated_at desc
	]], section_id))
end

local function get_address(id)
	local a = kv_row(1, query([[
	select
		a.name,
		a.line_1, a.line_2, a.line_3,
		a.city,
		a.zip
		s.name as state,
		c.printable_name as country,
	from
		addresses a
		left join states s on s.id = a.state_id
		left join countries c on c.id = a.country_id
	where
		a.id = ?
	]], id))
	local t = {}
	t[#t+1] = a.line_1; a.line_1 = nil
	t[#t+1] = a.line_2; a.line_2 = nil
	t[#t+1] = a.line_3; a.line_3 = nil
	a.street = table.concat(t, '\n')
	return a
end

local function ftable_generic(table_name, id)
	return kv_row(1, query(string.format([[select * from %s where id = ?]], table_name), id))
end

local ftable = setmetatable({}, {__index = ftable_generic}) --foundation table selectors

function ftable.education_histories(id)
	local eh = kv_row(1, query([[
	select
		eh.school_name,
		eh.school_url
	from
		education_histories eh
	where
		eh.id = ?
	]], id))
	if eh.address_id then
		eh.address = get_address(eh.address_id)
		eh.address_id = nil
	end
	return eh
end

function ftable.employment_histories(id)
	return kv_row(1, query([[
	select
		eh.name,
		eh.url,
		eh.title,
		id.description as industry_description
	from
		employment_histories eh
		left join industry_descriptions id on id.id = eh.industry_description_id
	where
		eh.id = ?
	]], id))
end

function ftable.qualifications(id)
	return kv_row(1, query([[
	select
		q.name
	from
		qualifications q
	where
		q.id = ?
	]], id))
end

function ftable.certifications(id)
	return kv_row(1, query([[
	select
		c.name,
		c.first_issue_date,
		c.issuing_authority,
		ct.name as country,
		c.description,
		c.valid_from,
		c.valid_to
	from
		certifications c
		left join countries ct on ct.id = c.country_id
	where
		c.id = ?
	]], id))
end

function ftable.security_credentials(id)
	return kv_row(1, query([[
	select
		s.name,
		s.issuing_authority,
		c.name as country,
		s.description,
		s.valid_from,
		s.valid_to,
		s.first_issue_date
	from
		security_credentials s
		left join countries c on c.id = s.country_id
	where
		s.id = ?
	]], id))
end

function ftable.objectives(id)
	return kv_row(1, query([[
	select
		o.summary
	from
		objectives o
	where
		o.id = ?
	]], id))
end

function ftable.military_experiences(id)
	return kv_row(1, query([[
	select
		c.name as country,
		me.service_number,
		mss.name as service_status,
		me.branch,
		me.unit_or_division,
		me.rank_achieved,
		me.started_on,
		me.ended_on,
		me.campaign,
		me.area_of_expertise,
		me.recognition_achieved,
		me.disciplinary_action,
		me.disciplinary_status,
		me.summary
	from
		military_experiences me
		left join military_service_statuses mss on mss.id = me.service_status
		left join countries c on c.id = me.country_id
	where
		me.id = ?
	]], id))
end

function ftable.achievements(id)
	return kv_row(1, query([[
	select
		a.date,
		a.issuing_authority,
		a.description
	from
		achievements a
	where
		a.id = ?
	]], id))
end

function ftable.associations(id)
	return kv_row(1, query([[
	select
		a.name,
		a.title,
		at.name as type,
		a.website,
		a.started_on,
		a.ended_on,
		ft.text as description,
		a.summary
	from
		associations a
		left join association_types at on at.id = a.association_type_id
		left join full_texts ft on ft.id = a.description_id
	where
		a.id = ?
	]], id))
end

function ftable.publication_histories(id)
	return kv_row(1, query([[
	select
		ph.title,
		ph.role,
		ph.publication_date,
		ph.copyright_text,
		ph.copyright_original_date,
		ph.copyright_most_recent_date,
		ph.publishable_id,
		ph.publishable_type,
		ph.summary
	from
		publication_histories ph
	where
		ph.id = ?
	]], id))
end

local function classname_to_tablename(s) -- 'EmploymentHistory' -> 'employment_histories'
	s = s:gsub('(%u)(%l*)()', function(u,l,pos)
		return u:lower() .. l .. (pos == #s+1 and 's' or  '_')
	end)
	s = s:gsub('ys$', 'ies')
	return s
end

local function get_resume_data(resume_id)
	local resume = get_resume(resume_id)
	resume.sections = get_resume_sections(resume_id)
	for i, section in ipairs(resume.sections) do
		glue.extend(section, get_section_entries(section.id))
		section.id = nil
		for i,entry in ipairs(section) do
			local table_name = classname_to_tablename(entry.class_name)
			local t = ftable[table_name](entry.obj_id)
			glue.update(entry, t)
			entry.obj_id = nil
			entry.class_name = nil
		end
	end
	return resume
end

--script

local resume_id, template_file, dest_file = ...
local conn = mysql.connect('localhost', 'root', nil, 'myj')
query = query_function(conn)
local resume = get_resume_data(resume_id)
gen_doc(template_file, dest_file, {['content.xml'] = resume})
conn:close()


pp(resume)
