-- drop function pallas_project.act_add_equipment(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_add_equipment(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_x integer := json.get_integer(in_user_params, 'x');
  v_y integer := json.get_integer(in_user_params, 'y');
  v_type text := json.get_string(in_user_params, 'type');

  v_mine_equipment_id integer := data.get_object_id('mine_equipment');
  v_equipment jsonb := data.get_raw_attribute_value_for_update(v_mine_equipment_id, 'mine_equipment');
begin
  assert v_type in ('train', 'driller', 'box', 'brill', 'buksir', 'digger', 'dron', 'iron', 'loader', 'stealer', 'stone', 'ship', 'barge', 'brillmine', 'stonemine', 'ironmine');

  v_equipment :=
    v_equipment ||
    format(
      '{
        "%s": {
          "x": %s,
          "y": %s,
          "type": "%s",
          "actor_id": false,
          "fueled": true,
          "broken": false,
          "firm": "CM",
          "content": []
        }
      }',
      (pgcrypto.gen_random_uuid())::text,
      v_x,
      v_y,
      v_type)::jsonb;

  perform data.change_object_and_notify(
    v_mine_equipment_id,
    jsonb_build_object('mine_equipment', v_equipment));
  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
