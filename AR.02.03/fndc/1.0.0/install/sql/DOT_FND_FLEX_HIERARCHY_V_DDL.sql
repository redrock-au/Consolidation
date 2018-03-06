/* $Header: svn://d02584/consolrepos/branches/AR.02.03/fndc/1.0.0/install/sql/DOT_FND_FLEX_HIERARCHY_V_DDL.sql 2798 2017-10-12 05:12:11Z svnuser $ */

CREATE OR REPLACE VIEW dot_fnd_flex_hierarchy_v 
AS
SELECT ffse.flex_value_set_name,
       ffvl.flex_value_set_id,
       ffvl.flex_value_id,
       ffvl.flex_value,
       fftl.flex_value_meaning,
       fftl.description,
       ffvl.enabled_flag,
       ffvr.range_attribute,
       ffvr.parent_flex_value,
       ffvr.parent_flex_value_id,
       ffvl.creation_date,
       ffvl.last_update_date
FROM   fnd_flex_values ffvl,
       fnd_flex_value_sets ffse,
       fnd_flex_values_tl fftl,
       (SELECT ffnh.flex_value_set_id,
               ffvc.flex_value_id,
               ffvc.flex_value,
               ffnh.range_attribute,
               ffvp.flex_value_id parent_flex_value_id,
               ffnh.parent_flex_value
        FROM   fnd_flex_value_norm_hierarchy ffnh,
               fnd_flex_values ffvp,
               fnd_flex_values ffvc
        WHERE  ffnh.flex_value_set_id = ffvp.flex_value_set_id
        AND    ffnh.flex_value_set_id = ffvc.flex_value_set_id
        AND    ffvc.flex_value BETWEEN ffnh.child_flex_value_low
                               AND     ffnh.child_flex_value_high
        AND    ffnh.parent_flex_value = ffvp.flex_value
        -- arellanod 2017/05/08
        AND    ((ffnh.range_attribute = 'C' AND NVL(ffvc.summary_flag, 'N') = 'N') OR
               (ffnh.range_attribute = 'P' AND NVL(ffvc.summary_flag, 'N') = 'Y'))
       ) ffvr
WHERE  ffvl.flex_value_set_id = ffvr.flex_value_set_id(+)
AND    ffvl.flex_value_id = ffvr.flex_value_id(+)
AND    ffvl.flex_value_set_id = ffse.flex_value_set_id
AND    ffvl.flex_value_id = fftl.flex_value_id;
