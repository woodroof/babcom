-- drop function pallas_project.get_chat_persons(integer, boolean);

create or replace function pallas_project.get_chat_persons(in_chat_id integer, in_but_masters boolean default false)
returns jsonb
volatile
as
$$
declare
  v_persons jsonb ;
  v_title_attribute_id integer := data.get_attribute_id('title');
begin
-- Список участников чата
-- in_but_masters = true - кроме мастеров
  select jsonb_agg(jsonb_build_object('code', code, 'name', value) order by value) into v_persons
  from (
    select o.code, av.value
    from data.object_objects oo
    left join data.attribute_values av on av.object_id = oo.object_id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
    join data.objects o on oo.object_id = o.id
    where oo.parent_object_id = in_chat_id
      and oo.parent_object_id <> oo.object_id
      and (not coalesce(in_but_masters, false) 
           or oo.object_id not in (select oom.object_id from data.object_objects oom
                                   join data.objects om on om.id = oom.parent_object_id and om.code = 'master'
                                   where oom.parent_object_id <> oom.object_id))
    for share of oo) a;
  return v_persons;
end;
$$
language plpgsql;
