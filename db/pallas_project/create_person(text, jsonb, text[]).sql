-- drop function pallas_project.create_person(text, jsonb, text[]);

create or replace function pallas_project.create_person(in_login_code text, in_attributes jsonb, in_groups text[])
returns void
volatile
as
$$
declare
  v_person_class_id integer := data.get_class_id('person');
  v_person_id integer;
  v_login_id integer;
  v_attribute record;
  v_group_code text;
begin
  insert into data.objects(class_id) values(v_person_class_id) returning id into v_person_id;
  insert into data.logins(code) values(in_login_code) returning id into v_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_login_id, v_person_id);

  for v_attribute in
  (
    select key, value
    from jsonb_each(in_attributes)
  )
  loop
    insert into data.attribute_values(object_id, attribute_id, value)
    values(v_person_id, data.get_attribute_id(v_attribute.key), v_attribute.value);
  end loop;

  for v_group_code in
  (
    select value
    from unnest(in_groups) a(value)
  )
  loop
    perform data.add_object_to_object(v_person_id, data.get_object_id(v_group_code));
  end loop;
end;
$$
language plpgsql;
