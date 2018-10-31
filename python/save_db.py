import shutil
import psycopg2
import sys

from pathlib import Path

DB_NAME = 'woodroof'
DB_USER = 'woodroof'
DB_PASSWORD = ''
DB_HOST = 'localhost'
DB_PORT = 5432

def get_schema_list(connection):
	cursor = connection.cursor()
	cursor.execute("""
select schema_name
from information_schema.schemata
where schema_name not like 'pg_%' and schema_name not in ('information_schema', 'pgcrypto');
""")
	result = cursor.fetchall()
	return [elem[0] for elem in result]

def save_function(schema, schema_dir_path, func):
	func_name = func[0]
	func_args = func[1]
	func_result = func[2]
	func_arg_types = func[3]
	func_type = func[4]
	func_body = func[5]

	file_path = schema_dir_path / (func_name + '(' + func_arg_types + ')' + '.sql')
	file = open(file_path, "w+")
	file.write('-- drop function ' + schema + '.' + func_name + '(' + func_arg_types + ');\n\n')
	file.write('create or replace function ' + schema + '.' + func_name + '(' + func_args + ')\n')
	file.write('returns ' + func_result + '\n')
	file.write(func_type + '\n')
	file.write('as\n')
	file.write('$$')
	file.write(func_body)
	file.write('$$\n')
	file.write("language 'plpgsql';\n")

def save_table(schema, schema_dir_path, table):
	table_name = table[0]
	table_columns = table[1]
	table_constraints = table[2]

	file_path = schema_dir_path / (table_name + '.sql')
	file = open(file_path, "w+")
	file.write('-- drop table ' + schema + '.' + table_name + ';\n\n')
	file.write('create table ' + schema + '.' + table_name + '(\n  ')
	file.write(',\n  '.join(table_columns))
	for constraint in table_constraints:
		file.write(',\n  constraint ' + constraint.lower().replace(' key (', ' key('))
	file.write("\n);\n")

def save_index(schema, schema_dir_path, index):
	index_name = index[0]
	index_definition = index[1]

	file_path = schema_dir_path / (index_name + '.sql')
	file = open(file_path, "w+")
	file.write('-- drop index ' + schema + '.' + index_name + ';\n\n')
	file.write(index_definition.lower().replace(' using btree ', '') + ';\n')

def save_functions(connection, schema, schema_dir_path):
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
  p.prosrc proc_body
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
  not p.proisagg and not p.proiswindow and
  --p.prokind = 'f' and
  -- only "in" arguments
  p.proallargtypes is null and
  -- only non-strict functions
  p.proisstrict = false
""",
		(schema,))
	functions = cursor.fetchall()
	for func in functions:
		save_function(schema, schema_dir_path, func)

def save_tables(connection, schema, schema_dir_path):
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
		save_table(schema, schema_dir_path, table)

def save_indexes(connection, schema, schema_dir_path):
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
		save_index(schema, schema_dir_path, index)

def save_schema(connection, schema, schema_dir_path):
	save_functions(connection, schema, schema_dir_path)
	save_tables(connection, schema, schema_dir_path)
	save_indexes(connection, schema, schema_dir_path)

def save_db(path):
	db_path = path / 'db'
	if db_path.exists():
		for subdir_path in db_path.iterdir():
			if subdir_path.is_dir():
				shutil.rmtree(subdir_path)
	else:
		db_path.mkdir()

	connection = psycopg2.connect(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, dbname=DB_NAME)

	schema_list = get_schema_list(connection)
	for schema in schema_list:
		schema_dir_path = db_path / schema
		schema_dir_path.mkdir()
		save_schema(connection, schema, schema_dir_path)

path = Path('.')
if len(sys.argv) > 1:
	path = Path(sys.argv[1])
save_db(path)