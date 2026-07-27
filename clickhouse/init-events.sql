-- A table to point Superset at on the first day, and a shape worth copying:
-- an event stream keyed by time, with a low-cardinality name and a JSON blob
-- for whatever else the event carries.
create database if not exists analytics;

create table if not exists analytics.events
(
  event_time  DateTime64(3) default now64(3),
  event_name  LowCardinality(String),
  user_id     String,
  properties  String default '{}'
)
engine = MergeTree
partition by toYYYYMM(event_time)
order by (event_name, event_time);
