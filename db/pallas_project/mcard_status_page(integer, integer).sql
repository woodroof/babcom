-- drop function pallas_project.mcard_status_page(integer, integer);

create or replace function pallas_project.mcard_status_page(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_code text := data.get_object_code(in_object_id);
  v_prefix text := substring(v_code for position('_status_page' in v_code) - 1);
  v_status integer := json.get_integer(data.get_attribute_value(in_actor_id, 'system_person_' || v_prefix || '_status'));
  v_status_text text := (case when v_status = 1 then 'Бронзовый' when v_status = 2 then 'Серебряный' when v_status = 3 then 'Золотой' else 'Нет' end);
begin
  assert in_actor_id is not null;

  perform data.change_object_and_notify(
    in_object_id,
    jsonb '[]' ||
    data.attribute_change2jsonb('mini_description', null, to_jsonb(v_status_text)),
    in_actor_id);
end;
$$
language plpgsql;
