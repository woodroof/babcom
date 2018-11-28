-- drop type data.severity;

create type data.severity as enum(
  'error',
  'warning',
  'info');
