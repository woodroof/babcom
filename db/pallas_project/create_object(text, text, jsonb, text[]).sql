-- drop function pallas_project.create_object(text, text, jsonb, text[]);

create or replace function pallas_project.create_object(in_code text, in_class_code text, in_attributes jsonb, in_groups text[])
returns integer
volatile
as
$$
declare
  v_object_id integer;
  v_attribute record;
  v_group_code text;
begin
  if in_code is null then
    insert into data.objects(class_id)
    values(case when in_class_code is not null then data.get_class_id(in_class_code) else null end)
    returning id into v_object_id;
  else
    insert into data.objects(code, class_id)
    values(in_code, case when in_class_code is not null then data.get_class_id(in_class_code) else null end)
    returning id into v_object_id;
  end if;

  for v_attribute in
  (
    select key, value
    from jsonb_each(in_attributes)
  )
  loop
    insert into data.attribute_values(object_id, attribute_id, value)
    values(v_object_id, data.get_attribute_id(v_attribute.key), v_attribute.value);
  end loop;

  for v_group_code in
  (
    select value
    from unnest(in_groups) a(value)
  )
  loop
    perform data.add_object_to_object(v_object_id, data.get_object_id(v_group_code));
  end loop;

  return v_object_id;
end;
$$
language plpgsql;
