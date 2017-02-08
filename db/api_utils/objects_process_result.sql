-- Type: api_utils.objects_process_result

-- DROP TYPE api_utils.objects_process_result;

CREATE TYPE api_utils.objects_process_result AS
   (object_ids integer[],
    filled_attributes_ids integer[]);
