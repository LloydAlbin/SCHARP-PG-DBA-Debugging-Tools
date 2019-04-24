CREATE EXTENSION IF NOT EXISTS pageinspect;

CREATE SCHEMA IF NOT EXISTS tools;

GRANT USAGE ON SCHEMA tools TO PUBLIC;

CREATE OR REPLACE FUNCTION tools.page_header (table_name regclass)
RETURNS TABLE (
  lsn pg_catalog.pg_lsn,
  checksum SMALLINT,
  flags SMALLINT,
  lower SMALLINT,
  upper SMALLINT,
  special SMALLINT,
  pagesize SMALLINT,
  version SMALLINT,
  prune_xid pg_catalog.xid
) AS
$body$
 WITH RECURSIVE t(n) AS (
SELECT (pg_relation_size.pg_relation_size / 8192 - 1)::integer AS int4
FROM pg_relation_size($1::regclass) pg_relation_size(pg_relation_size)
UNION ALL
SELECT t_1.n - 1
FROM t t_1
WHERE t_1.n > 0
        )
    SELECT (page_header(get_raw_page($1::text, t.n))).lsn AS lsn,
    (page_header(get_raw_page($1::text, t.n))).checksum AS checksum,
    (page_header(get_raw_page($1::text, t.n))).flags AS flags,
    (page_header(get_raw_page($1::text, t.n))).lower AS lower,
    (page_header(get_raw_page($1::text, t.n))).upper AS upper,
    (page_header(get_raw_page($1::text, t.n))).special AS special,
    (page_header(get_raw_page($1::text, t.n))).pagesize AS pagesize,
    (page_header(get_raw_page($1::text, t.n))).version AS version,
    (page_header(get_raw_page($1::text, t.n))).prune_xid AS prune_xid
    FROM t;
$body$
LANGUAGE 'sql'
VOLATILE
RETURNS NULL ON NULL INPUT
SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION tools.page_header (table_name regclass) TO PUBLIC;

CREATE OR REPLACE FUNCTION tools.heap_page_item_attrs (
  table_name pg_catalog.regclass
)
RETURNS TABLE (
  p integer,
  lp smallint,
  lp_off smallint,
  lp_flags smallint,
  lp_len smallint,
  t_xmin pg_catalog.xid,
  t_xmax pg_catalog.xid,
  t_field3 integer,
  t_ctid pg_catalog.tid,
  t_infomask2 integer,
  t_infomask integer,
  t_hoff smallint,
  t_bits text,
  t_oid oid,
  t_attrs bytea []
) AS
$body$
WITH RECURSIVE t(n) AS (
  SELECT (pg_relation_size / 8192 - 1)::integer AS int4
  FROM pg_relation_size($1::regclass)
  UNION ALL
  SELECT t_1.n - 1
  FROM t t_1
  WHERE t_1.n > 0)
      SELECT t.n AS p, (heap_page_item_attrs(get_raw_page($1::text, n), $1::regclass, true)).* 
      FROM t
$body$
LANGUAGE 'sql'
VOLATILE
RETURNS NULL ON NULL INPUT
SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION tools.heap_page_item_attrs (table_name regclass) TO PUBLIC;

CREATE OR REPLACE FUNCTION tools.heap_page_item_attrs_details (
  table_name pg_catalog.regclass,
  limit_page_results integer = 0
)
RETURNS TABLE (
  p integer,
  lp smallint,
  lp_off smallint,
  lp_flags smallint,
  lp_len smallint,
  t_xmin pg_catalog.xid,
  t_xmax pg_catalog.xid,
  t_field3 integer,
  t_ctid pg_catalog.tid,
  heap_hasnull boolean,
  heap_hasvarwidth boolean,
  heap_hasexternal boolean,
  heap_hasoid boolean,
  heap_xmax_keyshr_lock boolean,
  heap_combocid boolean,
  heap_xmax_excl_lock boolean,
  heap_xmax_lock_only boolean,
  heap_xmax_shr_lock boolean,
  heap_lock_mask boolean,
  heap_xmin_committed boolean,
  heap_xmin_invalid boolean,
  heap_xmax_committed boolean,
  heap_xmax_invalid boolean,
  heap_xmin_frozen boolean,
  heap_xmax_is_multi boolean,
  heap_updated boolean,
  heap_moved_off boolean,
  heap_moved_in boolean,
  heap_moved boolean,
  heap_xact_mask boolean,
  heap_natts_mask integer,
  heap_keys_updated boolean,
  heap_hot_updated boolean,
  heap_only_tuple boolean,
  heap2_xact_mask boolean,
  t_hoff smallint,
  t_bits text,
  t_oid oid,
  t_attrs bytea []
) AS
$body$
WITH RECURSIVE t(
    n) AS(
  SELECT 
  	CASE 
    	WHEN (limit_page_results > 0 AND (pg_relation_size / current_setting('block_size')::integer - 1)::integer > limit_page_results) 
        THEN limit_page_results 
        ELSE (pg_relation_size / current_setting('block_size')::integer - 1)::integer 
        END AS int4
  FROM pg_relation_size($1::regclass)
  UNION ALL
  SELECT t_1.n - 1
  FROM t t_1
  WHERE t_1.n > 0)
SELECT 
             n AS p,
             lp,
             lp_off,
             lp_flags,
             lp_len,
             t_xmin, /* inserting xact ID */
             t_xmax, /* deleting or locking xact ID */
             t_field3, /* Union of inserting or deleting command ID, or both AND old-style VACUUM FULL xact ID */
             t_ctid, /*(Page Number,Tuple Number within Page) current TID of this or newer tuple (or a speculative insertion token) */ 
             ((t_infomask) & x'0001'::integer)::boolean AS HEAP_HASNULL,      /* has null attribute(s) */
             ((t_infomask) & x'0002'::integer)::boolean AS HEAP_HASVARWIDTH,      /* has variable-width attribute(s) */
             ((t_infomask) & x'0004'::integer)::boolean AS HEAP_HASEXTERNAL,      /* has external stored attribute(s) */
             ((t_infomask) & x'0008'::integer)::boolean AS HEAP_HASOID,      /* has an object-id field */
             ((t_infomask) & x'0010'::integer)::boolean AS HEAP_XMAX_KEYSHR_LOCK,      /* xmax is a key-shared locker */
             ((t_infomask) & x'0020'::integer)::boolean AS HEAP_COMBOCID,      /* t_cid is a combo cid */
             (( t_infomask) & x'0040'::integer)::boolean AS HEAP_XMAX_EXCL_LOCK,      /* xmax is exclusive locker */
             (( t_infomask) & x'0080'::integer)::boolean AS HEAP_XMAX_LOCK_ONLY,      /* xmax, if valid, is only a locker */
       
             ((t_infomask) & (x'0040' | x'0010')::integer)::boolean AS HEAP_XMAX_SHR_LOCK, /* xmax is a shared locker #define HEAP_XMAX_SHR_LOCK  (HEAP_XMAX_EXCL_LOCK | HEAP_XMAX_KEYSHR_LOCK) */
             ((t_infomask) & ((x'0040' | x'0010') | x'0040' | x'0010')::integer)::boolean AS HEAP_LOCK_MASK, /* xmax is a shared locker #define HEAP_XMAX_SHR_LOCK    (HEAP_XMAX_EXCL_LOCK | HEAP_XMAX_KEYSHR_LOCK) */
       
             ((t_infomask) & x'0100'::integer)::boolean AS HEAP_XMIN_COMMITTED,    /* t_xmin committed */
             ((t_infomask) & x'0200'::integer)::boolean AS HEAP_XMIN_INVALID,    /* t_xmin invalid/aborted */
             ((t_infomask) & x'0400'::integer)::boolean AS HEAP_XMAX_COMMITTED,    /* t_xmax committed */
             ((t_infomask) & x'0800'::integer)::boolean AS HEAP_XMAX_INVALID,  /* t_xmax invalid/aborted aka xmax_rolled_back */
             ((t_infomask) & (x'0800' | x'0400')::integer)::boolean AS HEAP_XMIN_FROZEN,  /* (HEAP_XMIN_COMMITTED|HEAP_XMIN_INVALID) */
       
             ((t_infomask) & x'1000'::integer)::boolean AS HEAP_XMAX_IS_MULTI,    /* t_xmax is a MultiXactId */
             ((t_infomask) & x'2000'::integer)::boolean AS HEAP_UPDATED,    /* this is UPDATEd version of row */
             ((t_infomask) & x'4000'::integer)::boolean AS HEAP_MOVED_OFF,    /* moved to another place by pre-9.0
                                         * VACUUM FULL; kept for binary
                                         * upgrade support */
             ((t_infomask) & x'8000'::integer)::boolean AS HEAP_MOVED_IN,    /* moved from another place by pre-9.0
                                         * VACUUM FULL; kept for binary
                                         * upgrade support */
             ((t_infomask) & (x'4000' | x'8000')::integer)::boolean AS HEAP_MOVED,    /* HEAP_MOVED (HEAP_MOVED_OFF | HEAP_MOVED_IN) */
             ((t_infomask) & x'FFF0'::integer)::boolean AS HEAP_XACT_MASK,    /* visibility-related bits */

             ((t_infomask2) & x'07FF'::integer) AS HEAP_NATTS_MASK,    /* 11 bits for number of attributes */
             ((t_infomask2) & x'2000'::integer)::boolean AS HEAP_KEYS_UPDATED,    /* tuple was updated and key cols
                                         * modified, or tuple deleted */
             ((t_infomask2) & x'4000'::integer)::boolean AS HEAP_HOT_UPDATED,    /* tuple was HOT-updated */
             ((t_infomask2) & x'8000'::integer)::boolean AS HEAP_ONLY_TUPLE,    /* this is heap-only tuple */
             ((t_infomask2) & x'E000'::integer)::boolean AS HEAP2_XACT_MASK,    /* visibility-related bits */
             t_hoff, /* sizeof header incl. bitmap, padding */
             t_bits, /* bitmap of NULLs */
             t_oid,
             t_attrs
FROM 
(
    SELECT t.n, (heap_page_item_attrs(get_raw_page($1::text, n), $1::regclass, true)).* 
    FROM t
) a;
$body$
LANGUAGE 'sql'
VOLATILE
RETURNS NULL ON NULL INPUT
SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION tools.heap_page_item_attrs_details (table_name regclass) TO PUBLIC;

CREATE OR REPLACE FUNCTION tools.page_count (table_name regclass)
RETURNS int4
AS
$body$
SELECT (pg_relation_size.pg_relation_size / 8192 )::integer AS int4
  FROM pg_relation_size($1::regclass) pg_relation_size(
    pg_relation_size)
$body$
LANGUAGE 'sql'
VOLATILE
RETURNS NULL ON NULL INPUT
SECURITY DEFINER;  

GRANT EXECUTE ON FUNCTION tools.page_count (table_name regclass) TO PUBLIC;
