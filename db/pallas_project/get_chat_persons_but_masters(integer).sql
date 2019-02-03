-- drop function pallas_project.get_chat_persons_but_masters(integer);

create or replace function pallas_project.get_chat_persons_but_masters(in_chat_id integer)
returns jsonb[]
volatile
as
$$
declare
  v_persons jsonb[] := array[]::jsonb[];
  v_title_attribute_id integer := data.get_attribute_id('title');
begin

  select array_agg(av.value order by av.value) into v_persons
      from data.object_objects oo
      left join data.attribute_values av on av.object_id = oo.object_id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
      where oo.parent_object_id = in_chat_id
        and oo.parent_object_id <> oo.object_id
        and oo.object_id not in (select oom.object_id from data.object_objects oom
                                 join data.objects om on om.id = oom.parent_object_id and om.code = 'master'
                                 where oom.parent_object_id <> oom.object_id);
  return v_persons;
end;
$$
language plpgsql;
