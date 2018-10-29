-- drop function json_test.get_x_array_should_throw_for_invalid_json_type();

create or replace function json_test.get_x_array_should_throw_for_invalid_json_type()
immutable
returns void as
$$

declare
  v_json_type text;
  v_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_type in array array ['bigint', 'boolean', 'integer', 'object', 'string'] loop
      foreach v_json in array array ['''5''', '''"qwe"''', '''{}''', '''true''', '''null'''] loop
        perform test.assert_throw(
          'select json.get_' || v_type || '_array(' || v_json || '::' || v_json_type || ')',
          'Json is not an array');
      end loop;
	  end loop;
  end loop;
end;

$$
language 'plpgsql';
