import shutil
import psycopg2
import sys

from pathlib import Path

from db_settings import DB_HOST, DB_PORT, DB_NAME

DB_USER = 'woodroof'
DB_PASSWORD = ''

DB_EXTENSIONS = ('pgcrypto',)

def append_to_file(file, source_file_paths):
	for source_file_path in sorted(source_file_paths):
		with open(source_file_path) as source_file:
			file.write(source_file.read())
			file.write('\n')

class DatabaseInfo:
	def __init__(self):
		self.schemas = []
		self.enums = []
		self.functions = []
		self.indexes = []
		self.tables = []
	
	def create_recreate_script(self, db_path):
		file = open(db_path / 'recreate.sql', 'w+')
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
language 'plpgsql';

select database_cleanup.clean();

drop schema database_cleanup cascade;

-- Creating extensions
""")

		for extension in DB_EXTENSIONS:
			file.write("""
create schema {0};
create extension {0} schema {0};
""".format(extension))

		file.write('\n-- Creating schemas\n\n')
		for schema in sorted(self.schemas):
			file.write('create schema {};\n'.format(schema))

		file.write('\n-- Creating enums\n\n')
		append_to_file(file, self.enums)

		file.write('\n-- Creating functions\n\n')
		append_to_file(file, self.functions)

		file.write('-- Creating tables\n\n')
		append_to_file(file, self.tables)

		file.write('-- Creating indexes\n\n')
		append_to_file(file, self.indexes)

def get_schema_list(connection):
	cursor = connection.cursor()
	cursor.execute(r"""
select nspname as name
from pg_namespace
where nspname not like 'pg\_%%' and nspname != 'information_schema' and nspname not in %s;
""",
		(DB_EXTENSIONS,))
	result = cursor.fetchall()
	return [elem[0] for elem in result]

def save_enum(schema, schema_dir_path, enum, db_info):
	enum_name = enum[0]
	enum_values = enum[1]

	file_path = schema_dir_path / (enum_name + '.sql')
	db_info.enums.append(file_path)
	file = open(file_path, "w+")
	file.write('-- drop type ' + schema + '.' + enum_name + ';\n\n')
	file.write('create type ' + schema + '.' + enum_name + ' as enum(\n')
	file.write(enum_values + ');\n')

def save_function(schema, schema_dir_path, func, db_info):
	func_name = func[0]
	func_args = func[1]
	func_result = func[2]
	func_arg_types = func[3]
	func_type = func[4]
	func_body = func[5]

	file_path = schema_dir_path / (func_name + '(' + func_arg_types + ')' + '.sql')
	db_info.functions.append(file_path)
	file = open(file_path, "w+")
	file.write('-- drop function ' + schema + '.' + func_name + '(' + func_arg_types + ');\n\n')
	file.write('create or replace function ' + schema + '.' + func_name + '(' + func_args + ')\n')
	file.write('returns ' + func_result + '\n')
	file.write(func_type + '\n')
	file.write('as\n')
	file.write('$$\n')
	file.write(func_body.replace('\t', '  '))
	file.write('\n$$\n')
	file.write("language 'plpgsql';\n")

def save_table(schema, schema_dir_path, table, db_info):
	table_name = table[0]
	table_columns = table[1]
	table_constraints = table[2]

	file_path = schema_dir_path / (table_name + '.sql')
	db_info.tables.append(file_path)
	file = open(file_path, "w+")
	file.write('-- drop table ' + schema + '.' + table_name + ';\n\n')
	file.write('create table ' + schema + '.' + table_name + '(\n  ')
	file.write(',\n  '.join(table_columns))
	for constraint in table_constraints:
		file.write(',\n  constraint ' + constraint.lower().replace(' key (', ' key(').replace(' unique (', ' unique('))
	file.write("\n);\n")

def save_index(schema, schema_dir_path, index, db_info):
	index_name = index[0]
	index_definition = index[1]

	file_path = schema_dir_path / (index_name + '.sql')
	db_info.indexes.append(file_path)
	file = open(file_path, "w+")
	file.write('-- drop index ' + schema + '.' + index_name + ';\n\n')
	file.write(index_definition.lower().replace(' using btree ', '') + ';\n')

def save_enums(connection, schema, schema_dir_path, db_info):
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
		(schema,))
	enums = cursor.fetchall()
	for enum in enums:
		save_enum(schema, schema_dir_path, enum, db_info)

def save_functions(connection, schema, schema_dir_path, db_info):
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
		(schema,))
	functions = cursor.fetchall()
	for func in functions:
		save_function(schema, schema_dir_path, func, db_info)

def save_tables(connection, schema, schema_dir_path, db_info):
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
          (case when atthasdef then (select ' default ' || adsrc from pg_attrdef where adrelid = t.oid and adnum = a.attnum) else '' end))
    from pg_attribute a
    where
      attrelid = t.oid and
      attnum > 0
  ) as columns,
  (
    select array_agg(c.conname || ' ' || pg_get_constraintdef(c.oid))
    from pg_constraint c
    where conrelid = t.oid
  ) as constraints
from pg_class t
join pg_namespace n
  on n.nspname = %s
  and t.relnamespace = n.oid
where
  -- only ordinary tables
  t.relkind = 'r'
""",
		(schema,))
	tables = cursor.fetchall()
	for table in tables:
		save_table(schema, schema_dir_path, table, db_info)

def save_indexes(connection, schema, schema_dir_path, db_info):
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
		(schema,))
	indexes = cursor.fetchall()
	for index in indexes:
		save_index(schema, schema_dir_path, index, db_info)

def save_schema(connection, schema, schema_dir_path, db_info):
	save_enums(connection, schema, schema_dir_path, db_info)
	save_functions(connection, schema, schema_dir_path, db_info)
	save_tables(connection, schema, schema_dir_path, db_info)
	save_indexes(connection, schema, schema_dir_path, db_info)

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
	db_info.schemas = get_schema_list(connection)
	for schema in db_info.schemas:
		schema_dir_path = db_path / schema
		schema_dir_path.mkdir()
		save_schema(connection, schema, schema_dir_path, db_info)
	db_info.create_recreate_script(db_path)

path = Path('.')
if len(sys.argv) > 1:
	path = Path(sys.argv[1])
save_db(path)