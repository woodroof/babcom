-- drop function pallas_project.get_document_participants(jsonb, integer, boolean);

create or replace function pallas_project.get_document_participants(in_document_peartitpants jsonb, in_actor_id integer, in_with_sign_info boolean default false)
returns text
volatile
as
$$
declare
  v_persons text := '';
  v_record record;
begin
  for v_record in (select x.key, 
                          (case 
                            when in_with_sign_info then (case when x.value = 'true' then ' - Есть подпись' else ' - Нет подписи' end) 
                            else '' end) sign
                   from jsonb_each_text(in_document_peartitpants) x) loop
    v_persons:= v_persons || E'\n' || pp_utils.link(v_record.key, in_actor_id) || v_record.sign;
  end loop;

  return v_persons;
end;
$$
language plpgsql;
