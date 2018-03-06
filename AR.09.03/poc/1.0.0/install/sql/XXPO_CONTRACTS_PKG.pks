CREATE OR REPLACE PACKAGE xxpo_contracts_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.09.03/poc/1.0.0/install/sql/XXPO_CONTRACTS_PKG.pks 2689 2017-10-05 04:37:59Z svnuser $ */
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
