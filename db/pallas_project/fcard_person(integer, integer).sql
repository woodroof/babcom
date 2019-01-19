-- drop function pallas_project.fcard_person(integer, integer);

create or replace function pallas_project.fcard_person(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_value jsonb;
  v_is_master boolean;
  v_changes jsonb[];
begin
  perform * from data.objects where id = in_object_id for update;

  v_is_master := pallas_project.is_in_group(in_actor_id, 'master');
  if v_is_master or in_object_id = in_actor_id then
    v_value := data.get_attribute_value(in_object_id, 'system_money');
    if json.get_bigint_opt(v_value, null) is not null then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('money', in_actor_id, v_value));
    end if;
    v_value := data.get_attribute_value(in_object_id, 'system_person_deposit_money');
    if json.get_bigint_opt(v_value, null) is not null then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('person_deposit_money', in_actor_id, v_value));
    end if;
    v_value := data.get_attribute_value(in_object_id, 'system_person_coin');
    if json.get_integer_opt(v_value, null) is not null then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('person_coin', in_actor_id, v_value));
    end if;
    v_value := data.get_attribute_value(in_object_id, 'system_person_opa_rating');
    if json.get_integer_opt(v_value, null) is not null then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('person_opa_rating', in_actor_id, v_value));
    end if;
    v_value := data.get_attribute_value(in_object_id, 'system_person_un_rating');
    if json.get_integer_opt(v_value, null) is not null then
      v_changes := array_append(v_changes, data.attribute_change2jsonb('person_un_rating', in_actor_id, v_value));
    end if;
  end if;
  if array_length(v_changes,1) > 0 then
    perform data.change_object(in_object_id, to_jsonb(v_changes), in_actor_id);
  end if;
end;
$$
language 'plpgsql';
