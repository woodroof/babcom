-- drop function pallas_project.vd_debatle_status(integer, jsonb, integer);

create or replace function pallas_project.vd_debatle_status(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'draft' then
    return 'Черновик';
  when v_text_value = 'new' then
    return 'Неподтверждённый';
  when v_text_value = 'future' then
    return 'Будущий';
  when v_text_value = 'vote' then
    return 'Идёт голосование';
  when v_text_value = 'vote_over' then
    return 'Голосование завершено';
  when v_text_value = 'closed' then
    return 'Завершен';
  when v_text_value = 'deleted' then
    return 'Удалён';
  else
    return 'Неизвестно';
  end case;
end;
$$
language 'plpgsql';
