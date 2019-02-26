-- drop function pallas_project.act_claim_change_defendant(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_claim_change_defendant(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_claim_code text := json.get_string(in_params, 'claim_code');
  v_claim_id integer := data.get_object_id(v_claim_code);
  v_actor_id integer := data.get_active_actor_id(in_client_id);

  v_title_attribute_id integer := data.get_attribute_id('title');

  v_claim_author text := json.get_string(data.get_attribute_value(v_claim_id, 'claim_author'));
  v_claim_plaintiff text := json.get_string(data.get_attribute_value(v_claim_id, 'claim_plaintiff'));
  v_claim_defendant text := json.get_string_opt(data.get_attribute_value_for_share(v_claim_id, 'claim_defendant'), null);

  v_claim_title text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_claim_id, v_title_attribute_id), '');

  v_content text[];

  v_temp_object_id integer;
begin
  assert in_request_id is not null;

  select array_agg(s.code order by s.ord, s.value) into v_content from
    (select o.code, 1 ord, av.value
    from data.object_objects oo
      left join data.objects o on o.id = oo.object_id
      left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
    where oo.parent_object_id = data.get_object_id('player')
      and oo.object_id <> oo.parent_object_id
      and o.code not in (v_claim_author, v_claim_plaintiff , coalesce(v_claim_defendant, '~'))
    union all 
    select o.code, 2 ord, av.value
    from data.objects o
      left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
    where o.class_id = data.get_class_id('organization')
      and o.code not in (v_claim_author, v_claim_plaintiff , coalesce(v_claim_defendant, '~'))) s;

  if v_content is null then
    v_content := array[]::text[];
  end if;

  -- создаём темповый список возможных ответчиков
  v_temp_object_id := data.create_object(
  null,
  jsonb_build_array(
    jsonb_build_object('code', 'title', 'value', 'Изменение ответчика для иска "' || v_claim_title || '"'),
    jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_actor_id),
    jsonb_build_object('code', 'content', 'value', v_content),
    jsonb_build_object('code', 'system_claim_id', 'value', v_claim_id)
  ),
  'claim_temp_defendant_list');

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_temp_object_id));
end;
$$
language plpgsql;
