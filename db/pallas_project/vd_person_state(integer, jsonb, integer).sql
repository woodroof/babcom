-- drop function pallas_project.vd_person_state(integer, jsonb, integer);

create or replace function pallas_project.vd_person_state(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'un' then
    return 'Гражданин ООН';
  when v_text_value = 'aster' then
    return 'Астер';
  when v_text_value = 'mars' then
    return 'Марсианин';
  else
    return 'Неизвестно';
  end case;
end;
$$
language plpgsql;
