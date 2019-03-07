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
begin
  if v_equipment ? v_id then
    v_equipment_content := json.get_string_array(json.get_object(v_equipment, v_id), 'content');
    if array_position(v_equipment_content, v_content_id) is not null then
      v_equipment_content := array_remove(v_equipment_content, v_content_id);
      v_equipment := jsonb_set(v_equipment, array[v_id, 'content'], to_jsonb(v_equipment_content));

      if v_equipment ? v_content_id then
        declare
          v_unloaded_object jsonb := json.get_object(v_equipment, v_content_id);
          v_current_coords jsonb := jsonb_build_object('x', v_unloaded_object->'x', 'y', v_unloaded_object->'y');
          v_type text := json.get_string(v_unloaded_object, 'type');
        begin
          if v_type = 'box' then
            if data.get_param('customs_coords') = v_current_coords then
              perform pallas_project.send_to_master_chat('Коробка прибыла на таможню, пора генерировать товары!');
              v_equipment := v_equipment - v_content_id;
            elsif data.get_param('contraband_coords') = v_current_coords then
              perform pallas_project.send_to_master_chat('Коробку притащили на пункт выдачи контрабанды, нужно отреагировать!');
              v_equipment := v_equipment - v_content_id;
            end if;
          elsif v_type in ('brill', 'stone', 'iron') then
            if data.get_param('de_beers_coords') = v_current_coords then
              declare
                v_resource_type text := (case when v_type = 'brill' then 'diamonds' when v_type = 'stone' then 'ore' else 'iridium' end);
                v_system_res_attr_id integer := data.get_attribute_id('system_resource_' || v_resource_type);
                v_res_attr_id integer := data.get_attribute_id('resource_' || v_resource_type);
                v_org_id integer := data.get_object_id('org_de_beers');
                v_res_count integer := json.get_integer(data.get_attribute_value_for_update(v_org_id, v_system_res_attr_id)) + 1;
              begin
                perform data.change_object_and_notify(
                  v_org_id,
                  format(
                    '[
                      {"id": %s, "value": %s},
                      {"id": %s, "value": %s, "value_object_code": "org_de_beers_head"},
                      {"id": %s, "value": %s, "value_object_code": "master"}
                    ]',
                    v_system_res_attr_id,
                    v_res_count,
                    v_res_attr_id,
                    v_res_count,
                    v_res_attr_id,
                    v_res_count)::jsonb);
              end;
              v_equipment := v_equipment - v_content_id;
            end if;
          elsif v_type = 'barge' then
            if data.get_param('dock_coords') = v_current_coords then
              v_equipment := v_equipment - v_content_id;
              v_equipment :=
                v_equipment ||
                format('{"%s": {"x": %s, "y": %s, "type":"box", "actor_id": false, "fueled": true, "broken":false, "firm":"CM", "content":[]}}', (pgcrypto.gen_random_uuid())::text, json.get_integer(v_unloaded_object, 'x'), json.get_integer(v_unloaded_object, 'y'))::jsonb;
            end if;
          end if;
        end;
      end if;

      perform data.change_object_and_notify(
        v_mine_equipment_id,
        jsonb_build_object('mine_equipment', v_equipment));
    end if;
  end if;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
