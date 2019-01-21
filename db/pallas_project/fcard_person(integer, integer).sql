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
  v_money_attribute_id integer :=  data.get_attribute_id('money');
  v_system_money_attribute_id integer :=  data.get_attribute_id('system_money');
  v_person_deposit_money_attribute_id integer :=  data.get_attribute_id('person_deposit_money');
  v_system_person_deposit_money_attribute_id integer :=  data.get_attribute_id('system_person_deposit_money');
  v_person_coin_attribute_id integer :=  data.get_attribute_id('person_coin');
  v_system_person_coin_attribute_id integer :=  data.get_attribute_id('system_person_coin');
  v_person_opa_rating_attribute_id integer :=  data.get_attribute_id('person_opa_rating');
  v_system_person_opa_rating_attribute_id integer :=  data.get_attribute_id('system_person_opa_rating');
  v_person_un_rating_attribute_id integer :=  data.get_attribute_id('person_un_rating');
  v_system_person_un_rating_attribute_id integer :=  data.get_attribute_id('system_person_un_rating');
begin
  perform * from data.objects where id = in_object_id for update;

  v_is_master := pallas_project.is_in_group(in_actor_id, 'master');
  if v_is_master or in_object_id = in_actor_id then
    v_value := data.get_attribute_value(in_object_id, v_system_money_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_money_attribute_id, null, v_money_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_money_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, v_system_person_deposit_money_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_person_deposit_money_attribute_id, null, v_person_deposit_money_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_person_deposit_money_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, v_system_person_coin_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_person_coin_attribute_id, null, v_person_coin_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_person_coin_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, v_system_person_opa_rating_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_person_opa_rating_attribute_id, null, v_person_opa_rating_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_person_opa_rating_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
    v_value := data.get_attribute_value(in_object_id, v_system_person_un_rating_attribute_id);
    if data.should_attribute_value_be_changed(in_object_id, v_system_person_un_rating_attribute_id, null, v_person_un_rating_attribute_id, in_actor_id) then
      perform data.set_attribute_value(in_object_id, v_person_un_rating_attribute_id, v_value, in_actor_id, in_actor_id);
    end if;
  end if;
end;
$$
language plpgsql;
