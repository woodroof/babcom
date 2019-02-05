-- drop index data.jobs_idx_time;

create index jobs_idx_time on data.jobs(desired_time);
