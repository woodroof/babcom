-- drop function pallas_project.create_person(text, jsonb, text[]);

create or replace function pallas_project.create_person(in_login_code text, in_attributes jsonb, in_groups text[])
returns void
volatile
as
$$
declare
  v_person_id integer := data.create_object(null, in_attributes, 'person', in_groups);
  v_login_id integer;
begin
  insert into data.logins(code) values(in_login_code) returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);
end;
$$
language plpgsql;
