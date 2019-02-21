-- drop function pallas_project.create_synonym(text, jsonb);

create or replace function pallas_project.create_synonym(in_original_object_code text, in_attributes jsonb)
returns void
volatile
as
$$
-- Не для использования на игре, т.к. обновляет атрибуты напрямую, без уведомлений и блокировок!
begin
  perform pallas_project.create_synonym(null, in_original_object_code, in_attributes);
end;
$$
language plpgsql;
