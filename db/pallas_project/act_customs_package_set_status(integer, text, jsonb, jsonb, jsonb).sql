-- drop function pallas_project.act_customs_package_set_status(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_customs_package_set_status(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_package_code text := json.get_string(in_params, 'package_code');
  v_list_code text := json.get_string_opt(in_params, 'from_list', null);
  v_new_status text := json.get_string(in_params, 'status');
  v_is_job boolean := json.get_boolean_opt(in_params, 'job', false);
  v_package_id integer := data.get_object_id(v_package_code);
  v_package_status text := json.get_string(data.get_attribute_value_for_update(v_package_id, 'package_status'));
  v_package_receiver_status integer := json.get_integer(data.get_attribute_value(v_package_id, 'package_receiver_status'));
  v_package_arrival_time text := json.get_string(data.get_attribute_value(v_package_id, 'package_arrival_time'));
  v_interval text;

  v_message_sent boolean := false;
  v_customs_list_old text;
  v_customs_list_new text;
  v_customs_id integer;
  v_customs_new_id integer;
  v_content text[];
  v_change jsonb[] := array[]::jsonb[];
begin
  if v_new_status = 'new' and v_package_status in ('frozen', 'arrested')
    or v_new_status = 'frozen' and v_package_status in ('new', 'checking')
    or v_new_status = 'arrested' and v_package_status in ('new', 'frozen', 'checking')
    or v_new_status = 'checked' and v_package_status in ('new', 'checking') then

    if v_new_status  = 'new' then
      if v_package_receiver_status = 1 then
        v_interval := '2 hours';
      elsif v_package_receiver_status = 2 then
        v_interval := '1 hour';
      elsif v_package_receiver_status = 3 then
        v_interval := '30 minutes';
      end if;
      if to_timestamp(pp_utils.format_date(clock_timestamp()), 'DD.MM.YYYY HH24:MI:SS') - to_timestamp(v_package_arrival_time, 'DD.MM.YYYY HH24:MI:SS') > v_interval::interval then
        v_new_status := 'checked';
      end if;
    end if;
    case
    when v_package_status in ('new', 'checking') then v_customs_list_old := 'new'; 
    when v_package_status in ('frozen', 'arrested') then v_customs_list_old := 'arrested';
    when v_package_status in ('checked') then v_customs_list_old := 'checked';
    when v_package_status in ('received') then v_customs_list_old := 'received';
    when v_package_status in ('future') then v_customs_list_old := 'future';
    else null;
    end case;

    case
    when v_new_status in ('new', 'checking') then v_customs_list_new := 'new'; 
    when v_new_status in ('frozen', 'arrested') then v_customs_list_new := 'arrested';
    when v_new_status in ('checked') then v_customs_list_new := 'checked';
    when v_new_status in ('received') then v_customs_list_new := 'received';
    when v_new_status in ('future') then v_customs_list_new := 'future';
    else null;
    end case;

    v_customs_id := data.get_object_id('customs_' || v_customs_list_old);
    v_customs_new_id := data.get_object_id('customs_' || v_customs_list_new);

    if v_customs_id <> v_customs_new_id then  
      if v_list_code is null or v_list_code <> 'customs_' || v_customs_list_old then
          perform pp_utils.list_remove_and_notify(v_customs_id, v_package_code, null);
      else
        v_content := json.get_string_array(data.get_raw_attribute_value_for_update(v_customs_id, 'content', null));
        v_content := array_remove(v_content, v_package_code);
        v_message_sent := data.change_current_object(in_client_id, 
                                                     in_request_id,
                                                     v_customs_id, 
                                                     jsonb_build_array(data.attribute_change2jsonb('content', to_jsonb(v_content))));

      end if;
    end if;
    v_change := array_append(v_change, data.attribute_change2jsonb('package_status', to_jsonb(v_new_status)));
    if not v_is_job and (v_list_code is null or v_list_code <> 'customs_' || v_customs_list_old) then
        v_message_sent := data.change_current_object(in_client_id, 
                                                     in_request_id,
                                                     v_package_id, 
                                                     to_jsonb(v_change));
    else
      perform data.change_object_and_notify(v_package_id, 
                                            to_jsonb(v_change),
                                            null);
    end if;
    if v_customs_id <> v_customs_new_id then
      perform pp_utils.list_prepend_and_notify(v_customs_new_id, v_package_code, null);
    end if;
    if v_new_status = 'checked' then
      null;  -- TODO - уведомление для получателя
    end if;
  end if;

  if not v_message_sent and not v_is_job then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
