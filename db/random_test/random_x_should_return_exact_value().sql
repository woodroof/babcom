-- drop function random_test.random_x_should_return_exact_value();

create or replace function random_test.random_x_should_return_exact_value()
immutable
returns void as
$$

declare
  v_type text;
  v_value text := '5';
begin
  foreach v_type in array array ['bigint', 'integer'] loop
    execute 'select test.assert_eq(5, random.random_' || v_type || '(' || v_value || ', ' || v_value || '))';
  end loop;
end;

$$
language 'plpgsql';
