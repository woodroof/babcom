-- drop function pallas_project.get_document_possible_signers(integer);

create or replace function pallas_project.get_document_possible_signers(in_document_id integer)
returns text[]
volatile
as
$$
declare
  v_content text[];
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_player_id integer := data.get_object_id('player');
  v_system_document_participants jsonb := data.get_attribute_value(in_document_id, 'system_document_participants');
begin
  -- Собираем список всех персонажей, кроме тех, кто уже в списке участников
  select array_agg(o.code order by av.value) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
  where oo.parent_object_id = v_player_id
    and oo.object_id not in (oo.parent_object_id)
    and o.code not in (select x.code from jsonb_to_recordset(v_system_document_participants) as x(code text));

  if v_content is null then
    v_content := array[]::text[];
  end if;

  return v_content;
end;
$$
language plpgsql;
