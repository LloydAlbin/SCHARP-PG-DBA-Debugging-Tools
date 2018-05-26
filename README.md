# SCHARP-PG-DBA-Debugging-Tools
SCHARP Generic Postgres Tools Extension for DBA Debugging

Install via Extension
```sql
CREATE EXTENSION IF NOT EXISTS pageinspect; -- Needs to be in the default location
CREATE EXTENSION IF NOT EXISTS scharp_pg_dba_debugging_tools; -- Automatically created in the tools schema
CREATE EXTENSION IF NOT EXISTS scharp_pg_dba_debugging_tools WITH SCHEMA tools;
```

Install other required extensions automatically
```sql
CREATE EXTENSION IF NOT EXISTS scharp_pg_dba_debugging_tools CASCADE;
CREATE EXTENSION IF NOT EXISTS scharp_pg_dba_debugging_tools WITH SCHEMA tools CASCADE;
```

Install via SQL file
```bash
pgsql -f scharp_pg_dba_debugging_tools.sql
```

References based on: src\include\access\htup_details.h

xmin = INSERTing or UPDATing transaction
xmax = DELETEing transaction
ctid = (block number, tuple within block} aka unique tuple identifier, blocks are 0 based, tuple is 1 based.

```sql
CREATE TABLE tools.study_item_heap_page_item_attrs_details AS
SELECT * FROM tools.heap_page_item_attrs_details ('study.item');

CREATE TABLE tools.study_item_data_heap_page_item_attrs_details AS
SELECT * FROM tools.heap_page_item_attrs_details ('study.item_data');

-- Current number of records
SELECT count(*) FROM study.item; -- 238,441

-- Max number of tuples possible
SELECT count(*) FROM tools.study_item_heap_page_item_attrs_details; -- 540,092

-- Current number of records
SELECT count(*) FROM study.item_data; -- 10,477,899

-- Max number of tuples possible
SELECT count(*) FROM tools.study_item_data_heap_page_item_attrs_details; -- 18,644,388

-- Oldest INSERT / UPDATE transaction not DELETE'd or UPDATE'd item
SELECT * FROM tools.study_item_heap_page_item_attrs_details WHERE t_xmax != '0' ORDER BY t_xmin::text::bigint ASC LIMIT 1;
-- 279,502,686 t_xmin

-- First tuple or any tuple via (page, tuple) with page 0 based and tuple 1 based
SELECT * FROM tools.study_item_heap_page_item_attrs_details WHERE t_ctid = '(0,1)'::tid;

-- All tupled from page 0, listed in tuple order
SELECT * FROM tools.study_item_heap_page_item_attrs_details WHERE t_ctid::text LIKE '(0,%)' ORDER BY lp;

-- Max Page
SELECT max(split_part(right(t_ctid::text, -1), ',', 1)::BIGINT) FROM tools.study_item_heap_page_item_attrs_details;

-- Number of DELETE'd or (UPDATE'd, update does a DELETE and INSERT) tuple entries
SELECT count(*) FROM tools.study_item_heap_page_item_attrs_details WHERE t_xmax != '0' AND t_xmin IS NOT NULL; -- 6,979,496

-- Number of Current (un-deleted) tuple entries
SELECT count(*) FROM tools.study_item_heap_page_item_attrs_details WHERE t_xmax = '0' AND t_xmin IS NOT NULL; -- 8,603,238

-- Number of blank tuple entries
SELECT count(*) FROM tools.study_item_heap_page_item_attrs_details WHERE t_xmin IS NULL; -- 3,112,246

-- Special handeling needed if t_xmax if this value is set.
SELECT * FROM tools.study_item_heap_page_item_attrs_details WHERE heap_xmax_is_multi = true;
SELECT * FROM tools.study_item_data_heap_page_item_attrs_details WHERE heap_xmax_is_multi = true;

-- Special handeling, not validated yet.
SELECT p_id::text, CASE WHEN heap_xmax_is_multi = true THEN (pg_get_multixact_members(t_xmax))::text ELSE t_xmax END AS t_xmax,
* FROM tools.study_item_data_heap_page_item_attrs_details WHERE heap_xmax_is_multi = true;

-- List of transaction ID's for Insert (t_xmin) and Delete/Update (t_xmax) with count of tuples affected
SELECT t_xmin, CASE WHEN heap_xmax_invalid THEN '0'::xid ELSE t_xmax END t_xmax, count(*) 
FROM tools.study_item_heap_page_item_attrs_details 
WHERE t_xmin IS NOT NULL 
    AND t_xmax IS NOT NULL 
GROUP BY t_xmin, CASE WHEN heap_xmax_invalid THEN '0'::xid ELSE t_xmax END;

-- Current tuples 222,939
SELECT sum(count) FROM 
(
SELECT t_xmin, CASE WHEN heap_xmax_invalid THEN '0'::xid ELSE t_xmax END t_xmax, count(*) 
FROM tools.study_item_heap_page_item_attrs_details 
WHERE t_xmin IS NOT NULL 
    AND t_xmax IS NOT NULL 
GROUP BY t_xmin, CASE WHEN heap_xmax_invalid THEN '0'::xid ELSE t_xmax END
) a WHERE t_xmax = '0'::xid;

-- Deleted/Updated tuples 35,038
SELECT sum(count) FROM 
(
SELECT t_xmin, CASE WHEN heap_xmax_invalid THEN '0'::xid ELSE t_xmax END t_xmax, count(*) 
FROM tools.study_item_heap_page_item_attrs_details 
WHERE t_xmin IS NOT NULL 
    AND t_xmax IS NOT NULL 
GROUP BY t_xmin, CASE WHEN heap_xmax_invalid THEN '0'::xid ELSE t_xmax END
) a WHERE t_xmax != '0'::xid;

-- Unused tuples 282,115
SELECT count(*) 
FROM tools.study_item_heap_page_item_attrs_details 
WHERE t_xmin IS NULL 
    AND t_xmax IS NULL 
```

######Thank you's to the following People - Pages
Laurenz Albe - https://www.cybertec-postgresql.com/en/whats-in-an-xmax/
Alvaro Herrera - https://www.commandprompt.com/blog/decoding_infomasks/
