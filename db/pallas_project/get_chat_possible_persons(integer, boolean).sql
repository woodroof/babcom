-- drop function pallas_project.get_chat_possible_persons(integer, boolean);

create or replace function pallas_project.get_chat_possible_persons(in_chat_id integer, in_is_master_chat boolean default false)
returns text[]
volatile
as
$$
declare
  v_content text[];
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_player_id integer := data.get_object_id('player');
  v_master_id  integer := data.get_object_id('master');
  v_all_person_id  integer := data.get_object_id('all_person');
begin
  assert in_is_master_chat is not null;
  -- Собираем список всех персонажей, кроме тех, кто уже в чате
  -- in_but_masters = true - без мастеров
  select array_agg(code) into v_content
  from (
    select o.code
    from data.object_objects oo
    join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
    where (oo.parent_object_id = v_player_id or in_is_master_chat and oo.parent_object_id in (v_master_id, v_all_person_id))
      and oo.object_id not in (oo.parent_object_id)
      and oo.object_id not in (select chat.object_id from data.object_objects chat where chat.parent_object_id = in_chat_id)
    order by av.value
    for share of o) a;

  if v_content is null then
    v_content := array[]::text[];
  end if;

  return v_content;
end;
$$
language plpgsql;
