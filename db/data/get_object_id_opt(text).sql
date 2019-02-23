-- drop function data.get_object_id_opt(text);

create or replace function data.get_object_id_opt(in_object_code text)
returns integer
stable
as
$$
declare
  v_object_id integer;
begin
  if in_object_code is not null then 
    v_object_id :=  data.get_object_id(in_object_code);
  end if;
  return v_object_id;
end;
$$
language plpgsql;
