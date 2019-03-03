-- drop function pallas_project.job_unuse_stimulant(jsonb);

create or replace function pallas_project.job_unuse_stimulant(in_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := json.get_integer(in_params, 'actor_id');
  v_person_id integer; 

  v_message_text text := 'Мир снова ускорился и как будто посерел. Ваш энергетический подъём закончился.';

  v_system_person_is_stimulant_used boolean := json.get_boolean_opt(data.get_attribute_value_for_update(v_actor_id, 'system_person_is_stimulant_used'), false);
  v_changes jsonb[];
begin
  if v_system_person_is_stimulant_used then
    perform pp_utils.add_notification(v_actor_id, v_message_text);
    v_changes := array[]::jsonb[];
    v_changes := array_append(v_changes, data.attribute_change2jsonb('system_person_is_stimulant_used', null));
    perform data.change_object_and_notify(v_actor_id, 
                                          to_jsonb(v_changes),
                                          null);
    for v_person_id in (select * from unnest(json.get_integer_array_opt(data.get_attribute_value(v_actor_id, 'system_person_doubles_id_list'), array[]::integer[]))) loop
      perform pp_utils.add_notification(v_person_id, v_message_text);
      perform data.change_object_and_notify(v_person_id,
                                            to_jsonb(v_changes),
                                            null);
    end loop;

    perform data.change_object_and_notify(
      data.get_object_id('mine_person'),
      jsonb '[]' || data.attribute_change2jsonb('is_stimulant_used', jsonb 'null', v_actor_id));
  end if;
end;
$$
language plpgsql;
