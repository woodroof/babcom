#!/usr/bin/env python3
import os
import psycopg2
import re
import shutil
import sys

from pathlib import Path

from db_settings import DB_HOST, DB_PORT, DB_NAME

DB_USER = 'woodroof'
DB_PASSWORD = ''

DB_EXTENSIONS = ('intarray', 'pgcrypto')

EMPTY_STR_REGEX = re.compile(r"^ +$", re.MULTILINE)

def append_file(file, source_file_path):
	with open(source_file_path, encoding="utf-8") as source_file:
			file.write('\n')
			file.write(source_file.read())

def append_files(file, name, source_file_paths):
	file.write('\n-- Creating ' + name + '\n')
	for source_file_path in sorted(source_file_paths):
		append_file(file, source_file_path)

class DatabaseInfo:
	def __init__(self):
		self.schemas = []
		self.enums = []
		self.functions = []
		self.indexes = []
		self.tables = []
		self.foreign_keys = []
		self.triggers = []
	
	def create_recreate_script(self, db_path):
		file = open(db_path / 'recreate.sql', 'w+', encoding="utf-8")
		file.write(r"""-- Cleaning database

create schema if not exists database_cleanup;

create or replace function database_cleanup.clean()
returns void as
$$
declare
  v_schema_name text;
begin
  for v_schema_name in
  (
    select nspname as name
    from pg_namespace
    where nspname not like 'pg\_%' and nspname not in ('information_schema', 'database_cleanup')
  )
  loop
    execute format('drop schema %s cascade', v_schema_name);
  end loop;
end;
$$
language plpgsql;

select database_cleanup.clean();

drop schema database_cleanup cascade;

-- Creating extensions
""")

		for extension in DB_EXTENSIONS:
			file.write("""
create schema {0};
create extension {0} schema {0};
""".format(extension))

		append_files(file, 'schemas', self.schemas)
		append_files(file, 'enums', self.enums)
		append_files(file, 'functions', self.functions)
		append_files(file, 'tables', self.tables)
		append_files(file, 'foreign keys', self.foreign_keys)
		append_files(file, 'indexes', self.indexes)
		append_files(file, 'triggers', self.triggers)

		file.write('\n-- Initial data\n')
		append_file(file, db_path / 'initial_data.sql')

def save_schema(connection, db_path, schema, db_info):
	schema_name = schema[0]
	schema_comment = schema[1]

	schema_dir_path = db_path / schema_name
	schema_dir_path.mkdir()

	file_path = schema_dir_path / (schema_name + '.sql')
	db_info.schemas.append(file_path)
	file = open(file_path, "w+", encoding="utf-8")
	file.write('-- drop schema ' + schema_name + ';\n\n')
	file.write('create schema ' + schema_name + ';\n')
	if schema_comment:
		file.write("comment on schema {} is '{}';\n".format(schema_name, schema_comment))

	save_enums(connection, schema_name, schema_dir_path, db_info)
	save_functions(connection, schema_name, schema_dir_path, db_info)
	save_tables(connection, schema_name, schema_dir_path, db_info)
	save_foreign_keys(connection, schema_name, schema_dir_path, db_info)
	save_indexes(connection, schema_name, schema_dir_path, db_info)
	save_triggers(connection, schema_name, schema_dir_path, db_info)

def save_enum(schema_name, schema_dir_path, enum, db_info):
	enum_name = enum[0]
	enum_values = enum[1]

	file_path = schema_dir_path / (enum_name + '.sql')
	db_info.enums.append(file_path)
	file = open(file_path, "w+", encoding="utf-8")
	file.write('-- drop type ' + schema_name + '.' + enum_name + ';\n\n')
	file.write('create type ' + schema_name + '.' + enum_name + ' as enum(\n')
	file.write(enum_values + ');\n')

def save_function(schema_name, schema_dir_path, func, db_info):
	func_name = func[0]
	func_args = func[1]
	func_result = func[2]
	func_arg_types = func[3]
	func_type = func[4]
	func_security_definer = func[5]
	func_body = func[6]

	file_path = schema_dir_path / (func_name + '(' + func_arg_types + ')' + '.sql')
	db_info.functions.append(file_path)
	file = open(file_path, "w+", encoding="utf-8")
	file.write('-- drop function ' + schema_name + '.' + func_name + '(' + func_arg_types + ');\n\n')
	file.write('create or replace function ' + schema_name + '.' + func_name + '(' + func_args.replace(' DEFAULT', ' default').replace(' NULL', ' null') + ')\n')
	file.write('returns ' + func_result + '\n')
	file.write(func_type + '\n')
	if func_security_definer:
		file.write('security definer\n')
	file.write('as\n')
	file.write('$$\n')
	file.write(EMPTY_STR_REGEX.sub('', func_body.replace('\t', '  ')))
	file.write('\n$$\n')
	file.write("language plpgsql;\n")

def save_table(schema_name, schema_dir_path, table, db_info):
	table_name = table[0]
	table_columns = table[1]
	table_constraints = table[2]
	table_comment = table[3]
	column_comments = table[4]

	file_path = schema_dir_path / (table_name + '.sql')
	db_info.tables.append(file_path)
	file = open(file_path, "w+", encoding="utf-8")
	file.write('-- drop table ' + schema_name + '.' + table_name + ';\n\n')
	file.write('create table ' + schema_name + '.' + table_name + '(\n  ')
	file.write(',\n  '.join(table_columns))
	for constraint in table_constraints:
		file.write(',\n  constraint ' + constraint.lower().replace(' key (', ' key(').replace(' unique (', ' unique('))
	file.write("\n);\n")
	if table_comment is not None:
		file.write('\ncomment on table ' + schema_name + '.' + table_name + " is '" + table_comment + "';\n")
	if column_comments:
		file.write('\n')
		for column_comment in column_comments:
			file.write('comment on column ' + schema_name + '.' + table_name + '.' + column_comment + ';\n')

def save_foreign_key(schema_name, schema_dir_path, foreign_key, db_info):
	table_name = foreign_key[0]
	key_name = foreign_key[1]
	key_def = foreign_key[2]

	file_path = schema_dir_path / (key_name + '.sql')
	db_info.foreign_keys.append(file_path)
	file = open(file_path, "w+", encoding="utf-8")
	file.write('alter table ' + schema_name + '.' + table_name + ' add constraint ' + key_name + '\n')
	file.write(key_def.lower().replace(' key (', ' key(') + ';\n')

def save_index(schema_name, schema_dir_path, index, db_info):
	index_name = index[0]
	index_definition = index[1]

	file_path = schema_dir_path / (index_name + '.sql')
	db_info.indexes.append(file_path)
	file = open(file_path, "w+", encoding="utf-8")
	file.write('-- drop index ' + schema_name + '.' + index_name + ';\n\n')
	file.write(index_definition.lower().replace(' using btree ', '') + ';\n')

def get_trigger_events(trigger_type):
	if trigger_type & (1 << 2):
		events = 'insert'
	if trigger_type & (1 << 3):
		if events:
			events += ' or '
		events += 'delete'
	if trigger_type & (1 << 4):
		if events:
			events += ' or '
		events += 'update'
	if trigger_type & (1 << 5):
		if events:
			events += ' or '
		events += 'truncate'

	return events

def get_trigger_time(trigger_type):
	if trigger_type & (1 << 1):
		time = 'before'
	elif trigger_type & (1 << 6):
		time = 'instead of'
	else:
		time = 'after'

	return time

def get_trigger_scope(trigger_type):
	if trigger_type & 1:
		return 'for each row'
	return 'for each statement'

def save_trigger(schema_name, schema_dir_path, trigger, db_info):
	trigger_name = trigger[0]
	trigger_type = trigger[1]
	table_name = trigger[2]
	function_name = trigger[3]

	file_path = schema_dir_path / (trigger_name + '.sql')
	db_info.triggers.append(file_path)
	file = open(file_path, "w+", encoding="utf-8")
	file.write('-- drop trigger ' + trigger_name + ' on ' + schema_name + '.' + table_name + ';\n\n')
	file.write('create trigger ' + trigger_name + '\n')
	file.write(get_trigger_time(trigger_type) + ' ' + get_trigger_events(trigger_type) + '\n')
	file.write('on ' + schema_name + '.' + table_name + '\n')
	file.write(get_trigger_scope(trigger_type) + '\n')
	file.write('execute function ' + function_name + '();\n')

def save_schemas(connection, db_path, db_info):
	cursor = connection.cursor()
	cursor.execute(r"""
select
  n.nspname as name,
  d.description
from pg_namespace n
left join pg_description d
  on d.objoid = n.oid
where
  n.nspname not like 'pg\_%%' and
  n.nspname != 'information_schema' and
  n.nspname not in %s
""",
		(DB_EXTENSIONS,))
	schemas = cursor.fetchall()
	for schema in schemas:
		save_schema(connection, db_path, schema, db_info)

def save_enums(connection, schema_name, schema_dir_path, db_info):
	cursor = connection.cursor()
	cursor.execute("""
select
  t.typname enum_name,
  (
    select string_agg(ev.name, E',\n')
    from
    (
      select '  ''' || enumlabel || '''' as name
      from pg_enum
      where enumtypid = t.oid
      order by enumsortorder
    ) ev
  ) enum_values
from pg_type t
join pg_namespace n
  on n.nspname = %s
  and n.oid = t.typnamespace
where
  -- only enums
  t.typtype = 'e'
""",
		(schema_name,))
	enums = cursor.fetchall()
	for enum in enums:
		save_enum(schema_name, schema_dir_path, enum, db_info)

def save_functions(connection, schema_name, schema_dir_path, db_info):
	cursor = connection.cursor()
	cursor.execute("""
select
  p.proname proc_name,
  coalesce(pg_get_function_arguments(p.oid), '') proc_args,
  pg_get_function_result(p.oid) proc_result,
  coalesce(
    (
      select string_agg(ett.elem_type_name, ', ')
      from
      (
        select format_type(att.oid, null) as elem_type_name
        from
        (
          select row_number() over() as num, v.value
          from (select unnest(p.proargtypes) as value) v
        ) at
        join pg_type att
          on att.oid = at.value
        order by at.num
      ) ett
    ),
    ''
  ) proc_arg_types,
  (case when p.provolatile = 'i' then 'immutable' when p.provolatile = 's' then 'stable' else 'volatile' end) proc_type,
  prosecdef security_definer,
  trim(E'\n' from p.prosrc) proc_body
from pg_proc p
join pg_namespace n
  on n.nspname = %s
  and n.oid = p.pronamespace
join pg_language l
  on l.oid = p.prolang
  -- only pl/pgSQL
  and l.lanname = 'plpgsql'
join pg_type t
  on t.oid = p.prorettype
where
  -- only simple functions
  p.prokind = 'f' and
  -- only "in" arguments
  p.proallargtypes is null and
  -- only non-strict functions
  p.proisstrict = false
""",
		(schema_name,))
	functions = cursor.fetchall()
	for func in functions:
		save_function(schema_name, schema_dir_path, func, db_info)

def save_tables(connection, schema_name, schema_dir_path, db_info):
	cursor = connection.cursor()
	cursor.execute("""
select
  t.relname as name,
  (
    select
      array_agg(
        attname || ' ' ||
        format_type(atttypid, null) ||
        (case when attnotnull then ' not null' else '' end) ||
        (case when atthasdef then (select ' default ' || adsrc from pg_attrdef where adrelid = t.oid and adnum = a.attnum) else '' end) ||
        (case when attidentity = 'a' then ' generated always as identity' when attidentity = 'd' then ' generated by default as identity' else '' end))
    from pg_attribute a
    where
      attrelid = t.oid and
      attnum > 0 and
      attisdropped = false
  ) as columns,
  (
    select array_agg(c.conname || ' ' || (case when c.conbin is null then pg_get_constraintdef(c.oid) else 'check' || (case when c.consrc like '(%%' then c.consrc else '(' || c.consrc || ')' end) end) order by c.conname)
    from pg_constraint c
    where
      conrelid = t.oid and
      contype != 'f'
  ) as constraints,
  (
    select description
    from pg_description
    where
      objoid = t.oid and
      objsubid = 0
  ) as comment,
  (
    select
      array_agg(
        a.attname || ' is ''' || d.description || '''')
    from pg_attribute a
    join pg_description d
      on d.objoid = a.attrelid
      and d.objsubid = a.attnum
    where
      a.attrelid = t.oid and
      a.attnum > 0 and
      a.attisdropped = false
  ) as column_comments
from pg_class t
join pg_namespace n
  on n.nspname = %s
  and t.relnamespace = n.oid
where
  -- only ordinary tables
  t.relkind = 'r'
""",
		(schema_name,))
	tables = cursor.fetchall()
	for table in tables:
		save_table(schema_name, schema_dir_path, table, db_info)

def save_foreign_keys(connection, schema_name, schema_dir_path, db_info):
	cursor = connection.cursor()
	cursor.execute("""
select
  t.relname table_name,
  c.conname key_name,
  pg_get_constraintdef(c.oid) key_def
from pg_class t
join pg_namespace n
  on n.nspname = %s
  and t.relnamespace = n.oid
  -- only ordinary tables
  and t.relkind = 'r'
join pg_constraint c
  on c.conrelid = t.oid
  and c.contype = 'f'
""",
		(schema_name,))
	foreign_keys = cursor.fetchall()
	for foreign_key in foreign_keys:
		save_foreign_key(schema_name, schema_dir_path, foreign_key, db_info)

def save_indexes(connection, schema_name, schema_dir_path, db_info):
	cursor = connection.cursor()
	cursor.execute("""
select
  i.relname as name,
  pg_get_indexdef(i.oid) as index_def
from pg_class i
join pg_namespace n
  on n.nspname = %s
  and i.relnamespace = n.oid
join pg_index ii
  on ii.indexrelid = i.oid
  and (not ii.indisunique or ii.indpred is not null)
where i.relkind = 'i'
""",
		(schema_name,))
	indexes = cursor.fetchall()
	for index in indexes:
		save_index(schema_name, schema_dir_path, index, db_info)

def save_triggers(connection, schema_name, schema_dir_path, db_info):
	cursor = connection.cursor()
	cursor.execute("""
select
  t.tgname trigger_name,
  t.tgtype trigger_type,
  c.relname table_name,
  pn.nspname || '.' || p.proname as function_name
from pg_trigger t
join pg_class c
  on c.oid = t.tgrelid
join pg_namespace n
  on n.oid = c.relnamespace
  and n.nspname = %s
join pg_proc p
  on p.oid = t.tgfoid
join pg_namespace pn
  on pn.oid = p.pronamespace
where
  t.tgisinternal = false and
  -- only for tables
  array_length(t.tgattr, 1) = 0 and
  -- only without "when"
  t.tgqual is null
""",
		(schema_name,))
	triggers = cursor.fetchall()
	for trigger in triggers:
		save_trigger(schema_name, schema_dir_path, trigger, db_info)

def save_db(path):
	db_path = path / 'db'
	if db_path.exists():
		for subdir_path in db_path.iterdir():
			if subdir_path.is_dir():
				shutil.rmtree(subdir_path)
	else:
		db_path.mkdir()

	connection = psycopg2.connect(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, dbname=DB_NAME)

	db_info = DatabaseInfo()
	save_schemas(connection, db_path, db_info)
	db_info.create_recreate_script(db_path)

path = Path(os.path.dirname(os.path.abspath(__file__))) / '..'
if len(sys.argv) > 1:
	path = Path(sys.argv[1])
save_db(path)