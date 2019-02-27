-- drop function pallas_project.act_district_change_control(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_district_change_control(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params, 'object_code');
  v_control_code text := json.get_string(in_params, 'control_code');
  v_object_id integer := data.get_object_id(v_object_code);
  v_current_control jsonb := data.get_attribute_value_for_update(v_object_id, 'district_control');
  v_old_org_code text :=
    (case when v_current_control = jsonb 'null' then '' else pallas_project.control_to_org_code(json.get_string(v_current_control)) end);
  v_old_org_id integer;
  v_org_code text := pallas_project.control_to_org_code(v_control_code);
  v_org_id integer := data.get_object_id(v_org_code);
  v_tax integer := json.get_integer(data.get_attribute_value_for_share(v_org_code, 'system_org_tax'));
  v_district_influence jsonb := data.get_attribute_value_for_update(v_object_id, 'district_influence');
  v_notified boolean;
begin
  if v_current_control = to_jsonb(v_control_code) then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Контроль над районом уже изменился');
    return;
  end if;

  select jsonb_object_agg(key, case when key = v_control_code then 1 else 0 end)
  into v_district_influence
  from jsonb_each(v_district_influence);

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_object_id,
      format(
        '{
          "district_control": "%s",
          "district_tax": %s,
          "district_influence": %s
        }',
        v_control_code,
        v_tax,
        v_district_influence::text)::jsonb,
      'Изменение контроля мастером');
  assert v_notified;

  perform pallas_project.notify_district_tax_change(
    v_object_id,
    'в связи с изменением организации, контролирующей ваш район проживания');

  if v_old_org_code != '' then
    v_old_org_id := data.get_object_id(v_old_org_code);
    perform pallas_project.notify_organization(
      v_old_org_id,
      format(
        E'Организация потеряла контроль над сектором %s',
        pp_utils.link(v_object_code)),
      v_object_id);
    perform pallas_project.update_org_districts_control(v_old_org_id);
    perform pallas_project.update_org_districts_influence(v_old_org_id);
  end if;

  perform pallas_project.notify_organization(
    v_org_id,
    format(
      E'Организация получила контроль над сектором %s',
      pp_utils.link(v_object_code)),
    v_object_id);

  perform pallas_project.update_org_districts_control(v_org_id);
  perform pallas_project.update_org_districts_influence(v_org_id);
end;
$$
language plpgsql;
