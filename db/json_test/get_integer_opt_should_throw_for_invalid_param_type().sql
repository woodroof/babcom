-- drop function json_test.get_integer_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_integer_opt_should_throw_for_invalid_param_type()
immutable
returns void as
$$

declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_integer_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not a number');
    end loop;
  end loop;
end;

$$
language 'plpgsql';
