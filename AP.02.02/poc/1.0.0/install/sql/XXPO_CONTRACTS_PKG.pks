CREATE OR REPLACE PACKAGE xxpo_contracts_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.02/poc/1.0.0/install/sql/XXPO_CONTRACTS_PKG.pks 2999 2017-11-17 04:36:48Z svnuser $ */
/****************************************************************************
**
** CEMLI ID: PO.12.01
**
** Description: Contract Management System (CMS) interface file import
**
** Change History:
**
** Date        Who                  Comments
** 28/08/2017  ARELLAD (RED ROCK)   Initial build.
**
****************************************************************************/

FUNCTION convert_to_date
(
   p_date_in    IN VARCHAR2,
   p_date_out   OUT DATE
)
RETURN BOOLEAN;

PROCEDURE load_contracts
(
   p_errbuff     OUT VARCHAR2,
   p_retcode     OUT NUMBER,
   p_source      IN  VARCHAR2,
   p_filename    IN  VARCHAR2,
   p_debug       IN  VARCHAR2
);

END xxpo_contracts_pkg;
/
