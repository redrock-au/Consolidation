--$Header: svn://d02584/consolrepos/branches/AR.02.04/arc/1.0.0/bin/XXARITEMSIMP.ctl 238 2017-05-01 06:15:09Z dart $

LOAD DATA
REPLACE
INTO TABLE xxar_open_items_stg fields terminated by  X'09'
trailing nullcols
(
   CRN_NUMBER,
   ORIG_AMT1,
   ORIG_AMT2,
   ORIG_AMT3,
   ORIG_AMT4,
   RECORD_ID "xxar_open_items_record_id_s.NEXTVAL",
   STATUS CONSTANT 'NEW'

)
