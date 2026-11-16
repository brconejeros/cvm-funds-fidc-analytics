-- Placeholder model: proves the project builds end-to-end without external data.
-- Remove once the first CVM staging models land.
select 1 as hello_id, 'hello' as greeting, 'duckdb' as default_target
union all
select 2 as hello_id, 'olá' as greeting, 'duckdb' as default_target
