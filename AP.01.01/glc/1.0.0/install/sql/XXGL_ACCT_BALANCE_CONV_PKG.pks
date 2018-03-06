create or replace PACKAGE xxgl_acct_balance_conv_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.01.01/glc/1.0.0/install/sql/XXGL_ACCT_BALANCE_CONV_PKG.pks 2674 2017-10-05 01:02:16Z svnuser $*/
/****************************************************************************
**
** CEMLI ID: GL.00.02
**
** Description: DEDJTR GL Account Balances Conversion
**              Import Conversion Journal based on mapped COA
**
**
** Change History:
**
** Date        Who                  Comments
** 
****************************************************************************/


-- Messages --
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_error_message_04     VARCHAR2(150)  := '<ERROR-04>Encountered a problem during STAGE phase.';
g_error_message_05     VARCHAR2(150)  := '<ERROR-05>Encountered a problem during TRANSFORM phase.';
g_error_message_06     VARCHAR2(150)  := '<ERROR-06>Encountered a problem during LOAD phase.';
g_error_message_07     VARCHAR2(150)  := '<ERROR-07>Enter amount DR/CR error';
g_error_message_08     VARCHAR2(150)  := '<ERROR-08>GL Journal Import program error.';
g_error_message_09     VARCHAR2(150)  := '<ERROR-09>Unresolved account mapping: ';
g_error_message_10     VARCHAR2(150)  := '<ERROR-10>FND Flex segments breakup error on $OLD_COMBINATION.';
g_error_message_11     VARCHAR2(150)  := '<ERROR-11>Unable to map code combination $OLD_COMBINATION.';
g_error_message_12     VARCHAR2(150)  := '<ERROR-12>Journal amount is unbalanced on $NEW_SEGMENT1 entity segment.';
g_error_message_13     VARCHAR2(150)  := '<ERROR-13>Unable to resolve error while checking for unbalanced data.';

PROCEDURE run_import
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_source             IN   VARCHAR2,
   p_file_name          IN   VARCHAR2,
   p_control_file       IN   VARCHAR2,
   p_int_mode           IN   VARCHAR2,
   p_draft              IN   VARCHAR2
);

PROCEDURE initialize
(
   p_file               IN VARCHAR2,
   p_run_id             IN OUT NUMBER,
   p_run_stage_id       IN OUT NUMBER,
   p_run_transform_id   IN OUT NUMBER,
   p_run_load_id        IN OUT NUMBER
);

FUNCTION stage
(
   p_run_id         IN  NUMBER,
   p_run_phase_id   IN  NUMBER,
   p_source         IN  VARCHAR2,
   p_file           IN  VARCHAR2,
   p_ctl            IN  VARCHAR2,
   p_file_error     OUT VARCHAR2
)
RETURN BOOLEAN;

FUNCTION transform
(
   p_run_id         IN  NUMBER,
   p_run_phase_id   IN  NUMBER,
   p_source         IN  VARCHAR2,
   p_file           IN  VARCHAR2,
   p_stage_phase    IN  BOOLEAN
)
RETURN BOOLEAN;

FUNCTION load
(
   p_run_id            IN  NUMBER,
   p_run_phase_id      IN  NUMBER,
   p_file              IN  VARCHAR2,
   p_transform_phase   IN  BOOLEAN,
   p_request_id        OUT NUMBER
)
RETURN BOOLEAN;

PROCEDURE print_output
(
   p_run_id           NUMBER,
   p_run_phase_id     NUMBER,
   p_request_id       NUMBER,
   p_source           VARCHAR2,
   p_file             VARCHAR2,
   p_file_error       VARCHAR2,
   p_delim            VARCHAR2,
   p_write_to_out     BOOLEAN
);

PROCEDURE print_output_draft
(
   p_run_id           NUMBER,
   p_run_phase_id     NUMBER,
   p_request_id       NUMBER,
   p_source           VARCHAR2,
   p_file             VARCHAR2,
   p_file_error       VARCHAR2,
   p_delim            VARCHAR2,
   p_write_to_out     BOOLEAN
);

END xxgl_acct_balance_conv_pkg;
/
