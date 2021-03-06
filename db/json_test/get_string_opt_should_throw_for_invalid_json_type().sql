-- drop function json_test.get_string_opt_should_throw_for_invalid_json_type();

create or replace function json_test.get_string_opt_should_throw_for_invalid_json_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''5''', '''{}''', '''true'''] loop
      perform test.assert_throw(
        'select json.get_string_opt(' || v_json || '::' || v_json_type || ', null)',
        'Json is not a string');
    end loop;
  end loop;
end;
$$
language plpgsql;
