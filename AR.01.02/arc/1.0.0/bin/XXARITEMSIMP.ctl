--$Header: svn://d02584/consolrepos/branches/AR.01.02/arc/1.0.0/bin/XXARITEMSIMP.ctl 1274 2017-06-27 01:12:13Z svnuser $

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
