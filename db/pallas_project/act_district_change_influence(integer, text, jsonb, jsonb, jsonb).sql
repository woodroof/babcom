-- drop function pallas_project.act_district_change_influence(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_district_change_influence(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params, 'object_code');
  v_control_code text := json.get_string(in_params, 'control_code');
  v_influence_diff integer := json.get_integer(in_user_params, 'influence_diff');
  v_description text := pp_utils.trim(json.get_string(in_user_params, 'description'));
  v_district_influence jsonb := data.get_attribute_value_for_update(v_object_code, 'district_influence');
  v_control_influence integer := json.get_integer(v_district_influence, v_control_code);
  v_object_id integer := data.get_object_id(v_object_code);
  v_org_id integer := data.get_object_id(pallas_project.control_to_org_code(v_control_code));
  v_notified boolean;
begin
  if v_control_influence + v_influence_diff < 0 then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Значение влияния не может быть меньше нуля');
    return;
  end if;

  v_district_influence := jsonb_set(v_district_influence, array[v_control_code], to_jsonb(v_control_influence + v_influence_diff));
  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_object_id,
      jsonb_build_object('district_influence', v_district_influence),
      'Изменение влияния мастером');
  if not v_notified then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  else
    perform pallas_project.notify_organization(
      v_org_id,
      format(
        E'Влияние организации в секторе %s %s\n%s',
        pp_utils.link(v_object_code),
        (case when v_influence_diff > 0 then 'выросло' else 'уменьшилось' end),
        v_description),
      v_object_id);

    perform pallas_project.update_org_districts_influence(v_org_id);
  end if;
end;
$$
language plpgsql;
