-- drop function json_test.get_object_should_throw_for_invalid_json_type();

create or replace function json_test.get_object_should_throw_for_invalid_json_type()
returns void
immutable
as
$$

declare
  v_json_type text;
  v_json text;
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    foreach v_json in array array ['''[]''', '''"qwe"''', '''5''', '''true''', '''null'''] loop
      perform test.assert_throw(
        'select json.get_object(' || v_json || '::' || v_json_type || ')',
        'Json is not an object');
    end loop;
  end loop;
end;

$$
language 'plpgsql';
