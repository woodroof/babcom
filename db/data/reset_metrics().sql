-- drop function data.reset_metrics();

create or replace function data.reset_metrics()
returns void
volatile
as
$$
declare
  v_metric_type data.metric_type;
begin
  for v_metric_type in
  (
    select type
    from data.metrics
    for update
  )
  loop
    perform api_utils.create_metric_notification(v_metric_type, 0);
  end loop;

  truncate table data.metrics;
end;
$$
language plpgsql;
