-- drop function random_test.random_x_should_return_le_than_max_value();

create or replace function random_test.random_x_should_return_le_than_max_value()
returns void
immutable
as
$$
declare
  v_type text;
  v_min_value text := '2';
  v_max_value text := '5';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_ge(' || v_max_value || ', random.random_' || v_type || '(' || v_min_value || ', ' || v_max_value || '))';
  end loop;
end;
$$
language plpgsql;
