-- drop function pallas_project.act_free_equipment(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_free_equipment(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_id text := json.get_string(in_user_params, 'id');
  v_mine_equipment_id integer := data.get_object_id('mine_equipment');
  v_equipment jsonb := data.get_raw_attribute_value_for_update(v_mine_equipment_id, 'mine_equipment');
  v_equipment_object jsonb;
  v_notified boolean := false;
begin
  if v_equipment ? v_id then
    v_equipment_object := json.get_object(v_equipment, v_id);

    if jsonb_typeof(v_equipment_object->'actor_id') = 'string' then
      v_equipment := jsonb_set(v_equipment, array[v_id, 'actor_id'], jsonb 'false');

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
