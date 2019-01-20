-- drop function json_test.get_x_should_throw_for_null_json();

create or replace function json_test.get_x_should_throw_for_null_json()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_type text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['array', 'bigint', 'bigint_array', 'boolean', 'boolean_array', 'integer', 'integer_array', 'object', 'object_array', 'string', 'string_array'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(null::' || v_json_type || ')',
        'Json is not a%');
    end loop;
    foreach v_type in array array ['array', 'bigint', 'bigint_array', 'boolean', 'boolean_array', 'integer', 'integer_array', 'object', 'object_array', 'string', 'string_array'] loop
      perform test.assert_throw(
        'select json.get_' || v_type || '(null::' || v_json_type || ', ''key'')',
        'Json is not an object');
    end loop;
  end loop;
end;
$$
language plpgsql;
