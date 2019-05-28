CREATE VIEW egr_before2018 AS
SELECT st_union(the_geom), granule_id FROM (

SELECT
  *,
  ROW_NUMBER() OVER w AS rnum
FROM
  (SELECT * FROM egr_all WHERE granule_time < '2018-01-01') timesliced
WINDOW w AS (
  PARTITION BY the_geom
  ORDER BY granule_time DESC, granule_id DESC
)

) t
WHERE t.rnum = 1
GROUP BY granule_id;