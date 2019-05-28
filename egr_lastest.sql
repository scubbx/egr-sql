CREATE VIEW egr_latest AS
SELECT st_union(the_geom), granule_id FROM (

SELECT
  *,
  ROW_NUMBER() OVER w AS rnum
FROM
  egr_all
WINDOW w AS (
  PARTITION BY the_geom
  ORDER BY granule_time DESC, granule_id DESC
)

) t
WHERE t.rnum = 1
GROUP BY granule_id;