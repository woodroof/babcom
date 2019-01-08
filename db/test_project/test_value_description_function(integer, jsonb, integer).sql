-- drop function test_project.test_value_description_function(integer, jsonb, integer);

create or replace function test_project.test_value_description_function(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
begin
  assert in_attribute_id is not null;
  assert in_actor_id is not null;

  if in_value = jsonb '-42' then
    return 'минус сорок два';
  elsif in_value = jsonb '1' then
    return '**один**';
  elsif in_value = jsonb '2' then
    return '*два*';
  elsif in_value = jsonb '0.0314159265' then
    return 'π / 100';
  end if;

  assert false;
end;
$$
language 'plpgsql';
