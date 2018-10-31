-- drop function json_test.get_boolean_should_throw_for_invalid_param_type();

create or replace function json_test.get_boolean_should_throw_for_invalid_param_type()
returns void
immutable
as
$$

declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": 5}''', '''{"key": []}''', '''{"key": "qwe"}''', '''{"key": {}}''', '''{"key": null}'''] loop
      perform test.assert_throw(
        'select json.get_boolean(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a boolean');
    end loop;
  end loop;
end;

$$
language 'plpgsql';
