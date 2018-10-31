-- drop function json_test.get_integer_array_opt_should_throw_for_invalid_json_elem_type();

create or replace function json_test.get_integer_array_opt_should_throw_for_invalid_json_elem_type()
returns void
immutable
as
$$

declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[[]]''', '''["qwe"]''', '''[{}]''', '''[true]''', '''[null]'''] loop
      perform test.assert_throw(
        'select json.get_integer_array_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not an integer array');
    end loop;
  end loop;
end;

$$
language 'plpgsql';
