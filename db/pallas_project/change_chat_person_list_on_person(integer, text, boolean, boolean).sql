-- drop function pallas_project.change_chat_person_list_on_person(integer, text, boolean, boolean);

create or replace function pallas_project.change_chat_person_list_on_person(in_chat_id integer, in_chat_title text, in_is_master_chat boolean, in_is_current_object boolean default false)
returns jsonb[]
volatile
as
$$
declare
  v_chat_person_list_id integer := data.get_object_id(data.get_object_code(in_chat_id) || '_person_list'); 
  v_changes jsonb[];
  v_content text[];
  v_persons text := '';
  v_chat_can_invite boolean := json.get_boolean_opt(data.get_attribute_value(in_chat_id, 'system_chat_can_invite'), false);
  v_master_group_id integer := data.get_object_id('master');
begin
  -- Меняем привязанный к чату список для участников
  perform * from data.objects where id = v_chat_person_list_id for update;

  v_changes := array[]::jsonb[];
  if in_chat_title is not null then 
    v_changes := array_append(v_changes, data.attribute_change2jsonb('title', to_jsonb('Участники чата ' || in_chat_title)));
  end if;

  v_content := pallas_project.get_chat_possible_persons(in_chat_id, in_is_master_chat);
  if v_chat_can_invite then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_master_group_id));
    v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), in_chat_id));
  elsif not in_is_master_chat then
    v_changes := array_append(v_changes, data.attribute_change2jsonb('content', to_jsonb(v_content), v_master_group_id));
  end if;

  v_persons := pallas_project.get_chat_persons_text(in_chat_id, not in_is_master_chat);
  v_changes := array_append(v_changes, data.attribute_change2jsonb('chat_person_list_persons', to_jsonb(v_persons)));

  if not in_is_current_object then
    perform data.change_object_and_notify(v_chat_person_list_id, 
                                          to_jsonb(v_changes),
                                          null);
  end if;
                                      return v_changes;
end;
$$
language plpgsql;
