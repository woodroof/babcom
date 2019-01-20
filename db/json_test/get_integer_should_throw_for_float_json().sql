-- drop function json_test.get_integer_should_throw_for_float_json();

create or replace function json_test.get_integer_should_throw_for_float_json()
returns void
immutable
as
$$
declare
  v_json_type text;
  v_json text := '''5.55''';
begin
  foreach v_json_type in array array ['json', 'jsonb'] loop
    perform test.assert_throw(
      'select json.get_integer(' || v_json || '::' || v_json_type || ')',
      'Json is not an integer');
  end loop;
end;
$$
language plpgsql;
