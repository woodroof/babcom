-- drop function pallas_project.act_debatle_change_bonuses(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_change_bonuses(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_debatle_code text := json.get_string(in_params, 'debatle_code');
  v_judged_person text := json.get_string_opt(in_params, 'judged_person', '~~~');
  v_debatle_id integer := data.get_object_id(v_debatle_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatle_status text;
  v_debatle_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_debatle_id, 'title'), '');

  v_debatle_person_bonuses jsonb;

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_debatle_temp_bonus_list_person_attribute_id integer := data.get_attribute_id('debatle_temp_bonus_list_person');
  v_system_debatle_temp_bonus_list_debatle_id_attribute_id integer := data.get_attribute_id('system_debatle_id');
  v_debatle_temp_bonus_list_bonuses_attribute_id integer := data.get_attribute_id('debatle_temp_bonus_list_bonuses');
  v_debatle_bonus_votes_attribute_id integer:= data.get_attribute_id('debatle_bonus_votes');

  v_debatle_temp_bonus_list_class_id integer := data.get_class_id('debatle_temp_bonus_list');
  v_debatle_bonus_class_id integer := data.get_class_id('debatle_bonus');
  v_content text[];

  v_temp_object_code text;
  v_temp_object_id integer;
begin
  assert in_request_id is not null;

  if v_judged_person not in ('instigator', 'opponent') then
    perform api_utils.create_show_message_action_notification(
      in_client_id,
      in_request_id,
      'Ошибка',
      'Непонятно, какой из персон начислять бонусы и штрафы. Наверное что-то пошло не так. Обратитесь к мастеру.');
    return;
  end if;

  if v_judged_person = 'instigator' then
    v_debatle_person_bonuses := coalesce(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person1_bonuses'), jsonb '[]');
  else
    v_debatle_person_bonuses := coalesce(data.get_attribute_value_for_share(v_debatle_id, 'debatle_person2_bonuses'), jsonb '[]');
  end if;

  -- создаём темповый список бонусов и штрафов
  insert into data.objects(class_id) values (v_debatle_temp_bonus_list_class_id) returning id, code into v_temp_object_id, v_temp_object_code;

  select array_agg(o.code order by av_votes.value desc, av_title.value) into v_content
  from data.objects o
  left join data.attribute_values av_votes on av_votes.object_id = o.id and av_votes.attribute_id = v_debatle_bonus_votes_attribute_id and av_votes.value_object_id is null
  left join data.attribute_values av_title on av_title.object_id = o.id and av_title.attribute_id = v_title_attribute_id and av_title.value_object_id is null
  where o.class_id = v_debatle_bonus_class_id
    and o.code not in (select x.code from jsonb_to_recordset(v_debatle_person_bonuses) as x(code text, name text, votes int));

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_temp_object_id, v_title_attribute_id, to_jsonb(format('Изменение дебатла "%s"', v_debatle_title)), v_actor_id),
  (v_temp_object_id, v_is_visible_attribute_id, jsonb 'true', v_actor_id),
  (v_temp_object_id, v_debatle_temp_bonus_list_person_attribute_id, to_jsonb(v_judged_person), null),
  (v_temp_object_id, v_system_debatle_temp_bonus_list_debatle_id_attribute_id, to_jsonb(v_debatle_id), null),
  (v_temp_object_id, v_debatle_temp_bonus_list_bonuses_attribute_id, v_debatle_person_bonuses, null);

  if v_content is not null then
    insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
    (v_temp_object_id, v_content_attribute_id, to_jsonb(v_content), null);
  end  if;

  perform api_utils.create_open_object_action_notification(
    in_client_id,
    in_request_id,
    v_temp_object_code);
end;
$$
language plpgsql;
