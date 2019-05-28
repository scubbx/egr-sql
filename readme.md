# Excess Granule Removal with SQL only

I'll let the [GeoServer help page](https://geoserver.geo-solutions.it/edu/en/raster_data/mosaic_pyramid.html) do the explaining, on what *excess granule removal* is about:

> **ExcessGranuleRemoval**: An option that should be enabled when using scattered and deeply overlapping images. By default the image mosaic will try to mosaic toghether all images in the requested area, even if some are behind and won’t show up in the final image. With excess granule removal the system will use the image footprint to determine which granules actually contribute pixels to the output, and will end up performing the image processing only on those actually contributing. Best used along with footprints and sorting (to control which images actually stay on top). Possible values are NONE or ROI (Region Of Interest).

Also, you can see Slide 23 of [this presentation](https://www.slideshare.net/geosolutions/state-of-geoserver-foss4g-2016) .

## What is this repository about?

The excess granule removal as performed by the GeoServer implementation is operating on a raster level. In this repository, SQL code is presented which is performing the same task. The benefit is, that by using SQL, the result is a valid PostGIS table which can be further processed.

## The Procedere

The query is separated into two parts, each is producing a view. Only the first one is a materialized view with two inices, the second one can be materialized, but is not in this example.
Both queries can be merged into one single query, but one looses a certain speed-benefit when creating multiple egr-layers for different timestamps (I will explain on that later).

### Table layout

For this example, it is assumed, that a table named `originalgranules` existes. This Table has to include at least the fields `granule_id`, `granule_time` and `the_geom` (a valid PostGIS geometry).

![Original Granules](https://github.com/scubbx/egr-sql/blob/master/originalgranules.png "Original Granules")

### First View

In the first view, all existing boundaries are extracted as line elements (boundaries). Then polygons are computed from these lines (splitgranules). The result is a set of smallest common polygons.
Sadly, all attributive information which is needed to select the splitgranule with the most current date is lost during this process.

So, this information is re-selected by the use of a topological test (st_coveredby).

![Split Granules](https://github.com/scubbx/egr-sql/blob/master/splitgranules.png "Split Granules")

[egr_all.sql](https://github.com/scubbx/egr-sql/blob/master/egr_all.sql)

```SQL
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
```

This view is materialized, since it is the basis for different further results.
Two incices are calculated to help the following steps improve in speed.

### Second View

With the second view, only the most recent splitgranule per common area is taken. After that, all splitgranules sharing the same granule_id are merged again.

The result is a table showing the current coverage of the most-recent areas contributing to the total coverage.

[egr_latest.sql](https://github.com/scubbx/egr-sql/blob/master/egr_latest.sql)

```SQL
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
```

### Optional: Not recent coverage

By using a slight variation of the second view, it is possible to select the coverage of a certain time or time-span.

The following SQL Statement is an alteration (in line 8) of the above one, but is selecting only splitgranules that were generated before the year 2018.

[egr_before2018.sql](https://github.com/scubbx/egr-sql/blob/master/egr_before2018.sql)

```SQL
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
```
