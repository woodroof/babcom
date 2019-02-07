-- drop function pallas_project.create_class(text, jsonb);

create or replace function pallas_project.create_class(in_code text, in_attributes jsonb)
returns integer
volatile
as
$$
declare
  v_class_id integer;
  v_attribute record;
begin
  assert in_code is not null;

  insert into data.objects(code, type)
  values(in_code, 'class')
  returning id into v_class_id;

  for v_attribute in
  (
    select key, value
    from jsonb_each(in_attributes)
  )
  loop
    insert into data.attribute_values(object_id, attribute_id, value)
    values(v_class_id, data.get_attribute_id(v_attribute.key), v_attribute.value);
  end loop;

  return v_class_id;
end;
$$
language plpgsql;
