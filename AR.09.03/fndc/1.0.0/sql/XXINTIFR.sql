/* $Header: svn://d02584/consolrepos/branches/AR.09.03/fndc/1.0.0/sql/XXINTIFR.sql 1059 2017-06-21 03:26:39Z svnuser $ */

SET ECHO OFF;
SET FEEDBACK OFF;
SET VERIFY OFF;

DECLARE
   l_file_name           xxint_interface_ctl.file_name%TYPE := '&3';
   l_org_id              NUMBER;
   l_interface_prog_id   NUMBER;
   l_sub_prog_id         NUMBER;

BEGIN
   l_org_id := fnd_global.org_id;

   SELECT concurrent_program_id
   INTO   l_interface_prog_id
   FROM   fnd_concurrent_requests
   WHERE  request_id = &2;

   SELECT concurrent_program_id
   INTO   l_sub_prog_id
   FROM   fnd_concurrent_requests
   WHERE  request_id = &4;

   IF INSTR(l_file_name, '*', 1, 1) = 0 THEN
      INSERT INTO XXINT_INTERFACE_CTL
      VALUES (&1,
              &2,
              l_interface_prog_id,
              l_file_name,
              &4,
              l_sub_prog_id,
              NULL,
              NULL,
              NULL,
              SYSDATE,
              &5,
              SYSDATE,
              &5);

      COMMIT;
   END IF;
END;
/

EXIT;
