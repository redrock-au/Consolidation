CREATE OR REPLACE PACKAGE dot_appssql_dw_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.01.01/fndc/1.0.0/install/sql/DOT_APPSSQL_DW_PKG.pks 2949 2017-11-13 01:09:55Z svnuser $ */
/******************************************************************************
**
**  CEMLI ID: INT.10.01
**
**  Description: Create materialized views for the following business objects -
**               Chart of Accounts, AP & AR Invoices, AR Receipts, GL Journals,
**               and GL Balances. MV data are extracted into IBM Cognos Analytics.
**
**  Change History:
**
**  Date          Who           Description
**  11-Nov-2015   Dart          Initial build.
**  05-Apr-2016   Katie H.      Modified refresh_dw and close_process procedures
**  26-May-2017   Dart          Allow creation of multiple parent-child rows, as  
**                              long as it belongs to different hierarchy group.
**                              This helps user to determine overlap in the
**                              account hierarchy setup.
**
******************************************************************************/

TYPE mview_rec_type IS RECORD
   (mview_name        VARCHAR2(30),
    staleness         VARCHAR2(19),
    stale_since       DATE,
    compile_state     VARCHAR2(600));

TYPE mview_tab_type IS TABLE OF mview_rec_type INDEX BY binary_integer;

FUNCTION get_segment_value
(
   p_segment_num             IN  NUMBER,
   p_code_combination_id     IN  NUMBER,
   p_concatenated_account    IN  VARCHAR2,
   p_reversed_je_header_id   IN  NUMBER,
   p_reversed_je_line_num    IN  NUMBER
)  RETURN VARCHAR2;

FUNCTION convert_to_date
(
   p_string   VARCHAR2
) RETURN DATE;

FUNCTION requisition_approver
(
   p_requisition_id   NUMBER,
   p_sequence_num     NUMBER,
   p_action_code      VARCHAR2
)
RETURN VARCHAR2;

FUNCTION po_exclude_filter
(
   p_po_header_id   NUMBER
)  RETURN VARCHAR2;

FUNCTION get_payable_aging
(
   p_invoice_id         NUMBER,
   p_amount_remaining   NUMBER,
   p_paid               VARCHAR2,
   p_due_date           DATE,
   p_cancel_date        DATE
)  RETURN NUMBER;

FUNCTION get_invoice_num
(
   p_po_distribution_id   NUMBER
)  RETURN VARCHAR2;

--FUNCTION get_site_use_id
--(
--   p_cash_receipt_id    NUMBER,
--   p_customer_id        NUMBER,
--   p_org_id             NUMBER
--)  RETURN NUMBER;

FUNCTION get_site_use_id
(
   p_customer_id        NUMBER,
   p_site_use_id        NUMBER,
   p_org_id             NUMBER,
   p_version            NUMBER
)  RETURN NUMBER;

FUNCTION current_refresh
(
   p_mview_name   VARCHAR2
)
RETURN BOOLEAN;

PROCEDURE refresh_dw
(
   p_errbuff         OUT VARCHAR2,
   p_retcode         OUT NUMBER,
   p_include_coa     IN  VARCHAR2,
   p_full_refresh    IN  VARCHAR2,
   p_immediate_flag  IN  VARCHAR2
);

PROCEDURE refresh_gl_mviews
(
   p_errbuff         OUT VARCHAR2,
   p_retcode         OUT NUMBER,
   p_rebuild         IN  VARCHAR2
);

PROCEDURE update_mview
(
   p_errbuff         OUT  VARCHAR2,
   p_retcode         OUT  NUMBER,
   p_request_id      IN   NUMBER,
   p_mview_name      IN   VARCHAR2,
   p_full_refresh    IN   VARCHAR2,
   p_immediate_flag  IN   VARCHAR2
);

PROCEDURE close_process
(
   p_errbuff      OUT  VARCHAR2,
   p_retcode      OUT  NUMBER,
   p_request_id   IN   NUMBER
);

PROCEDURE notify_users
(
   p_scope           IN  VARCHAR2,
   p_manual_mv_1     IN  VARCHAR2,
   p_manual_mv_2     IN  VARCHAR2,
   p_request_id      IN  NUMBER,
   p_program_id      IN  NUMBER,
   p_status          OUT VARCHAR2,
   p_error_message   OUT VARCHAR2
);

END dot_appssql_dw_pkg;
/
