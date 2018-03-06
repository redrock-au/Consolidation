/* $Header: svn://d02584/consolrepos/branches/AP.00.02/glc/1.0.0/install/sql/cashbal_all_sources.sql 1470 2017-07-05 00:33:23Z svnuser $ */
DECLARE
   l_req_id  NUMBER;
BEGIN
   -- Run process as FINPROD 1003

   fnd_global.apps_initialize(USER_ID => 1003, RESP_ID => 20434, RESP_APPL_ID => 101);

   l_req_id := fnd_request.submit_request(application => 'SQLGLC',
                                          program     => 'XXGLCSHBALH',
                                          description => NULL,
                                          start_time  => NULL,
                                          sub_request => FALSE,
                                          argument1   => '&1',
                                          argument2   => '&2');
   COMMIT;
END;
/
EXIT;
