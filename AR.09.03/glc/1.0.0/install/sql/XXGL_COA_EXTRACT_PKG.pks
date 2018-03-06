CREATE OR REPLACE PACKAGE xxgl_coa_extract_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.09.03/glc/1.0.0/install/sql/XXGL_COA_EXTRACT_PKG.pks 1424 2017-07-04 06:57:15Z svnuser $ */

/****************************************************************************
**
** CEMLI ID: GL.03.02
**
** Description: GL Chart of Accounts Extract
**
** Change History:
**
** Date        Who                  Comments
** 25/05/2017  ARELLAD (RED ROCK)   Initial build.
**
****************************************************************************/

PROCEDURE extract_fflexval_hierarchy
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_set_of_books_id    IN  NUMBER,
   p_segment            IN  VARCHAR2,
   p_parent_value       IN  VARCHAR2,
   p_levels             IN  NUMBER,
   p_debug_flag         IN  VARCHAR2
);

PROCEDURE extract_all
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_lookup_type        IN  VARCHAR2,
   p_debug_flag         IN  VARCHAR2
);

END xxgl_coa_extract_pkg;
/
