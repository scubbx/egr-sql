CREATE materialized view egr_all AS

SELECT originalgranules.*,
       splitgranules.the_geom
FROM
       (select st_setsrid((st_dump(st_polygonize(boundaries.the_geom))).geom, 31255) as the_geom 
           FROM ( SELECT st_union(st_exteriorring(the_geom)) as the_geom from originalgranules ) boundaries ) splitgranules,
       originalgranules
WHERE
       st_coveredby(splitgranules.the_geom, originalgranules.the_geom)
ORDER BY
       originalgranules.granule_time DESC;

CREATE INDEX idx_egr_all_geom ON egr_all USING gist (the_geom);
CREATE INDEX idx_egr_all_time ON egr_all USING btree (time);