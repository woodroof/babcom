-- drop function test_project.is_user_params_empty(jsonb);

create or replace function test_project.is_user_params_empty(in_user_params jsonb)
returns boolean
stable
as
$$
begin
  return in_user_params is null or in_user_params = jsonb 'null' or in_user_params = jsonb '{}';
end;
$$
language 'plpgsql';
