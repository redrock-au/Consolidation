/* $Header: svn://d02584/consolrepos/branches/AR.01.02/glc/1.0.0/install/sql/cashbal_all_sources.sql 1832 2017-07-18 00:28:00Z svnuser $ */
DECLARE
   l_req_id      NUMBER;
   l_source      VARCHAR2(30) := '&1';
   l_gl_date     VARCHAR2(30) := '&2';
   l_gl_period   VARCHAR2(30) := '&3';
BEGIN
   -- Run process as FINPROD 1003
   fnd_global.apps_initialize(USER_ID => 1003, RESP_ID => 20434, RESP_APPL_ID => 101);

   IF l_source = 'RECOUP' THEN
      l_source := 'Cash Balancing';
   END IF;

   IF l_gl_date = '0' THEN
      l_gl_date := TO_CHAR(SYSDATE, 'YYYY/MM/DD');
   END IF;

   IF l_gl_period = '0' THEN
      l_gl_period := NULL;
   END IF;

   l_req_id := fnd_request.submit_request(application => 'SQLGLC',
                                          program     => 'XXGLCSHBALH',
                                          description => NULL,
                                          start_time  => NULL,
                                          sub_request => FALSE,
                                          argument1   => l_source,
                                          argument2   => l_gl_date,
                                          argument3   => l_gl_period);
   COMMIT;
END;
/
EXIT;
