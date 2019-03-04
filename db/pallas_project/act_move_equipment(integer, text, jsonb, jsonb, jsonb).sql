-- drop function pallas_project.act_move_equipment(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_move_equipment(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_id text := json.get_string(in_user_params, 'id');
  v_x integer := json.get_integer(in_user_params, 'x');
  v_y integer := json.get_integer(in_user_params, 'y');

  v_mine_equipment_id integer := data.get_object_id('mine_equipment');
  v_equipment jsonb := data.get_raw_attribute_value_for_update(v_mine_equipment_id, 'mine_equipment');
  v_equipment_content text[];
  v_content_id text;

  v_notified boolean := false;
begin
  if v_equipment ? v_id then
    v_equipment_content := json.get_string_array(json.get_object(v_equipment, v_id), 'content');

    for v_content_id in
    (
      select value
      from unnest(v_equipment_content) a(value)
    )
    loop
      v_equipment := jsonb_set(v_equipment, array[v_content_id, 'x'], to_jsonb(v_x));
      v_equipment := jsonb_set(v_equipment, array[v_content_id, 'y'], to_jsonb(v_y));
    end loop;

    v_equipment := jsonb_set(v_equipment, array[v_id, 'x'], to_jsonb(v_x));
    v_equipment := jsonb_set(v_equipment, array[v_id, 'y'], to_jsonb(v_y));

    perform data.change_object_and_notify(
      v_mine_equipment_id,
      jsonb_build_object('mine_equipment', v_equipment));
  end if;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
