-- drop function pallas_project.act_remove_content(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_remove_content(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_id text := json.get_string(in_user_params, 'id');
  v_content_id text := json.get_string(in_user_params, 'content_id');
  v_mine_equipment_id integer := data.get_object_id('mine_equipment');
  v_equipment jsonb := data.get_raw_attribute_value_for_update(v_mine_equipment_id, 'mine_equipment');
  v_equipment_content text[];
  v_notified boolean := false;
begin
  if v_equipment ? v_id then
    v_equipment_content := json.get_string_array(json.get_object(v_equipment, v_id), 'content');
    if array_position(v_equipment_content, v_content_id) is not null then
      v_equipment_content := array_remove(v_equipment_content, v_content_id);
      v_equipment := jsonb_set(v_equipment, array[v_id, 'content'], to_jsonb(v_equipment_content));

      v_notified :=
        data.change_current_object(
          in_client_id,
          in_request_id,
          v_mine_equipment_id,
          jsonb_build_object('mine_equipment', v_equipment));
    end if;
  end if;

  if not v_notified then
    perform pallas_project.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
