-- drop function pallas_project.fcard_person(integer, integer);

create or replace function pallas_project.fcard_person(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_value jsonb;
  v_is_master boolean;
begin
  v_is_master := json.get_boolean(data.get_attribute_value(in_actor_id, 'person_is_master'));
  if v_is_master or in_object_id = in_actor_id then
    v_value := data.get_attribute_value(in_object_id, 'system_money');
    if json.get_bigint_opt(v_value, null) is not null then
    null;
     -- perform data.set_attribute_value(in_object_id, 'money', v_value, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, 'system_person_deposit_money');
    if json.get_bigint_opt(v_value, null) is not null then
    null;
      --perform data.set_attribute_value(in_object_id, 'person_deposit_money', v_value, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, 'system_person_coin');
    if json.get_integer_opt(v_value, null) is not null then
    null;
      --perform data.set_attribute_value(in_object_id, 'person_coin', v_value, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, 'system_person_opa_rating');
    if json.get_integer_opt(v_value, null) is not null then
    null;
      --perform data.set_attribute_value(in_object_id, 'person_opa_rating', v_value, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, 'system_person_un_rating');
    if json.get_integer_opt(v_value, null) is not null then
      null;
      --perform data.set_attribute_value(in_object_id, 'person_un_rating', v_value, in_actor_id);
    end if;
  end if;
end;
$$
language 'plpgsql';
