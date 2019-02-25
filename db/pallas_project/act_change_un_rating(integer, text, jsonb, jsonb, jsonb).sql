-- drop function pallas_project.act_change_un_rating(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_change_un_rating(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_un_rating_diff integer := json.get_integer(in_user_params, 'un_rating_diff');
  v_un_rating integer := json.get_integer(data.get_raw_attribute_value_for_update(v_object_id, 'person_un_rating'));
  v_comment text := json.get_string(in_user_params, 'comment');
  v_notified boolean;
begin
  if v_un_rating_diff = 0 then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
    return;
  end if;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_object_id,
      format(
        '{
          "person_un_rating": %s
        }',
        v_un_rating + v_un_rating_diff)::jsonb,
      'Изменение рейтинга мастером');
  assert v_notified;

  perform pp_utils.add_notification(
    v_object_id,
    (case when v_un_rating_diff > 0 then 'Ваш рейтинг гражданина вырос' else 'Ваш рейтинг гражданина снизился' end) || E'\n' || pp_utils.trim(v_comment),
    v_object_id,
    true);
end;
$$
language plpgsql;
