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
  for v_record in (select x.code, 
                          (case 
                            when in_with_sign_info then (case when signed then ' - Подписано' else ' - Неподписано' end) 
                            else '' end) sign
                   from jsonb_to_recordset(in_document_peartitpants) as x(code text, signed boolean)) loop
    v_persons:= v_persons || E'\n' || pp_utils.link(v_record.code, in_actor_id) || v_record.sign;
  end loop;

  return v_persons;
end;
$$
language plpgsql;
