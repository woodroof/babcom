-- drop function json_test.get_number_array_should_throw_for_invalid_param_elem_type();

create or replace function json_test.get_number_array_should_throw_for_invalid_param_elem_type()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''{"key": [[]]}''', '''{"key": ["qwe"]}''', '''{"key": [{}]}''', '''{"key": [true]}''', '''{"key": [null]}'''] loop
      perform test.assert_throw(
        'select json.get_number_array(' || v_json || '::' || v_json_type || ', ''key'')',
        '%key% is not a number array');
    end loop;
  end loop;
end;
$$
language plpgsql;
