-- drop type data.metric_type;

create type data.metric_type as enum(
  'deadlock_count',
  'error_count',
  'max_api_time_ms');
