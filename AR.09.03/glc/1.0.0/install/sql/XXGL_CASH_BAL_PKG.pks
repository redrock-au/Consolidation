CREATE OR REPLACE PACKAGE xxgl_cash_bal_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.09.03/glc/1.0.0/install/sql/XXGL_CASH_BAL_PKG.pks 2689 2017-10-05 04:37:59Z svnuser $ */

/****************************************************************************
**
** CEMLI ID: GL.03.01
**
** Description: Cash Balancing and Authority Allocation Journals
**
** Change History:
**
** Date        Who                  Comments
** 03/05/2017  ARELLAD (RED ROCK)   Initial build. 
**
****************************************************************************/

PROCEDURE submit_cash_balancing
(
   p_errbuf       OUT VARCHAR2,
   p_retcode      OUT NUMBER,
   p_source       IN  VARCHAR2,
   p_gl_date      IN  VARCHAR2,
   p_gl_period    IN  VARCHAR2
);

PROCEDURE create_journals
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_set_of_books_id    IN  NUMBER,
   p_effective_date     IN  VARCHAR2,
   p_period_name        IN  VARCHAR2,
   p_source             IN  VARCHAR2,
   p_je_batch_id        IN  NUMBER,
   p_je_header_id       IN  NUMBER,
   p_force_flag         IN  VARCHAR2,
   p_test_flag          IN  VARCHAR2,
   p_debug_flag         IN  VARCHAR2
);

PROCEDURE validate_interface_lines
(
   p_request_id       IN  NUMBER,
   p_group_id         IN  NUMBER,
   p_accounting_date  IN  DATE,
   p_error_count      OUT NUMBER
);

PROCEDURE download_rules
(
   p_errbuff     OUT VARCHAR2,
   p_retcode     OUT NUMBER,
   p_path        IN  VARCHAR2,
   p_filename    IN  VARCHAR2,
   p_debug_flag  IN  VARCHAR2
);

PROCEDURE upload_rules
(
   p_errbuff     OUT VARCHAR2,
   p_retcode     OUT NUMBER,
   p_path        IN  VARCHAR2,
   p_filename    IN  VARCHAR2,
   p_debug_flag  IN  VARCHAR2
);

PROCEDURE run_test_report
(
   p_request_id       NUMBER,
   p_accounting_date  DATE
);

END xxgl_cash_bal_pkg;
/
