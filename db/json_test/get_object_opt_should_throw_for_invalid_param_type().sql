-- drop function json_test.get_object_opt_should_throw_for_invalid_param_type();

create or replace function json_test.get_object_opt_should_throw_for_invalid_param_type()
immutable
returns void as
$$

declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": []}''', '''{"key": "qwe"}''', '''{"key": 5}''', '''{"key": true}'''] loop
      perform test.assert_throw(
        'select json.get_object_opt(' || v_json || '::' || v_json_type || ', ''key'', null)',
        '%key% is not an object');
    end loop;
  end loop;
end;

$$
language 'plpgsql';
