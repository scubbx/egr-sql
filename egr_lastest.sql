CREATE VIEW egr_latest AS
SELECT DISTINCT st_union(a.the_geom) as geom, b.granule_id, b.granule_time FROM (

SELECT
  *,
  ROW_NUMBER() OVER w AS rnum
  FROM
    egr_all
  WINDOW w AS (
    PARTITION BY the_geom
    ORDER BY granule_time DESC, granule_id DESC
  )
  ) a,
  originalgranules b

WHERE
    a.rnum = 1
    AND a.location = b.location
GROUP BY
    b.granule_id,
    b.granule_time;
