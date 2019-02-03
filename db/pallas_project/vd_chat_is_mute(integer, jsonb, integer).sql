-- drop function pallas_project.vd_chat_is_mute(integer, jsonb, integer);

create or replace function pallas_project.vd_chat_is_mute(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_bool_value boolean := json.get_boolean(in_value);
begin
  case when v_bool_value then
    return 'Уведомления отключены';
  else
    return null;
  end case;
end;
$$
language plpgsql;
