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
  elsif in_value = jsonb '"значение"' then
    return 'описание значения';
  elsif in_value = jsonb '"lorem ipsum"' then
    return 'Lorem **ipsum** dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
  elsif in_value = jsonb '0.0314159265' then
    return 'π / 100';
  elsif in_value = jsonb '"integral"' then
    return '∫x dx = ½x² + C';
  end if;

  assert false;
end;
$$
language 'plpgsql';
