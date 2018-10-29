-- drop function random_test.random_x_should_return_ge_than_min_value();

create or replace function random_test.random_x_should_return_ge_than_min_value()
immutable
returns void as
$$

declare
  v_type text;
  v_min_value text := '-5';
  v_max_value text := '-2';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_le(' || v_min_value || ', random.random_' || v_type || '(' || v_min_value || ', ' || v_max_value || '))';
  end loop;
end;

$$
language 'plpgsql';
