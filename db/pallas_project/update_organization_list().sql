-- drop function pallas_project.update_organization_list();

create or replace function pallas_project.update_organization_list()
returns void
volatile
as
$$
declare
  v_district record;
begin
  -- Создадим объект со списком организаций
  declare
    v_organization_list jsonb;
    v_class_id integer := data.get_class_id('organization');
  begin
    select jsonb_agg(o.code order by data.get_raw_attribute_value(o.code, 'title'))
    into v_organization_list
    from data.objects o
    where o.class_id = v_class_id;

    perform data.change_object_and_notify(
      data.get_object_id('organizations'),
      jsonb '[]' ||
      data.attribute_change2jsonb('content', v_organization_list));
  end;
end;
$$
language plpgsql;
