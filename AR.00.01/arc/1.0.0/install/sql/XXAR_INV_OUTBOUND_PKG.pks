CREATE OR REPLACE PACKAGE xxar_inv_outbound_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.00.01/arc/1.0.0/install/sql/XXAR_INV_OUTBOUND_PKG.pks 1492 2017-07-05 07:01:42Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: AR.02.01
**
**      This package implements outbound file creation for Feeder Systems
**      Files are created in file system directories specified by configuration
**      in the custom table
**      Invoices are selected based on updates to invoice header or payment
**      schedules ("activity") since a point in time, either a user specified
**      time or since the last time the program run.
**
** Change History:
**
** Date        Who                  Comments
** 12/05/2017  NCHENNURI (RED ROCK) Initial build.
**
*******************************************************************/
-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      create_outbound_file_cp
--  PURPOSE
--       Concurrent Program XXARINVOUTINT (DEDJTR AR Outbound Invoice File Create)
--  DESCRIPTION
--       Main program
-- --------------------------------------------------------------------------------------------------
PROCEDURE create_outbound_file_cp
(
   p_errbuf OUT VARCHAR2,
   p_retcode OUT VARCHAR2,
   p_trx_type  IN VARCHAR2 DEFAULT NULL,
   p_date_from IN VARCHAR2 DEFAULT NULL 
);
END xxar_inv_outbound_pkg;
/