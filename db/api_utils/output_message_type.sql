-- drop type api_utils.output_message_type;

create type api_utils.output_message_type as enum(
  'action_result',
  'actors',
  'diff',
  'object',
  'object_list');
