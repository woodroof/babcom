-- drop function pallas_project.act_district_remove_control(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_district_remove_control(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params, 'object_code');
  v_object_id integer := data.get_object_id(v_object_code);
  v_control_code text := json.get_string(in_params, 'control_code');
  v_description text := pp_utils.trim(json.get_string(in_user_params, 'description'));
  v_current_control jsonb := data.get_attribute_value_for_update(v_object_id, 'district_control');
  v_org_id integer := data.get_object_id(pallas_project.control_to_org_code(v_control_code));
  v_notified boolean;
begin
  if v_current_control != to_jsonb(v_control_code) then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Контроль над районом уже изменился');
    return;
  end if;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_object_id,
      jsonb '{
        "district_control": null,
        "district_tax": 0
      }',
      'Изменение контроля мастером');
  assert v_notified;

  perform pallas_project.notify_district_tax_change(
    v_object_id,
    'в связи с изменением организации, контролирующей ваш район проживания');

  perform pallas_project.notify_organization(
    v_org_id,
    format(
      E'Организация потеряла контроль над сектором %s\n%s',
      pp_utils.link(v_object_code),
      v_description),
    v_object_id);

  perform pallas_project.update_org_districts_control(v_org_id);
end;
$$
language plpgsql;
