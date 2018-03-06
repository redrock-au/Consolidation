create or replace PACKAGE xxgl_import_coa_mapping_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.00.01/glc/1.0.0/install/sql/XXGL_IMPORT_COA_MAPPING_PKG.pks 2401 2017-09-04 00:46:57Z svnuser $ */
/****************************************************************************
**
** CEMLI ID: GL.00.01
**
** Description: Importing program for Mapped COA between DSDBI and DTPLI
**              
**
** Change History:
**
** Date        Who                  Comments
** 01-JUL-17   KWONDA               Initial Version
****************************************************************************/

-- Messages --
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_error_message_04     VARCHAR2(150)  := '<ERROR-04>Encountered a problem during STAGE phase.';
g_error_message_05     VARCHAR2(150)  := '<ERROR-05>Encountered a problem during TRANSFORM phase.';
g_error_message_06     VARCHAR2(150)  := '<ERROR-06>Encountered a problem during LOAD phase.';
/*
g_error_message_00     VARCHAR2(150)  := '<ERROR-00>Found discrepancy between TFM record count and data load count. ' ||
                                         'Please check the interface error table for details. ' ||
                                         'Error must be handled from transformation phase to achieve "all-or-nothing" interface run.';
*/

PROCEDURE execute_multiple_files
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_source             IN   VARCHAR2,
   p_debug_flag         IN   VARCHAR2,
   p_int_mode           IN   VARCHAR2
);

PROCEDURE run_import
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_source             IN   VARCHAR2,
   p_file_name          IN   VARCHAR2,
   p_control_file       IN   VARCHAR2,
   p_debug_flag         IN   VARCHAR2,
   p_int_mode           IN   VARCHAR2
);

PROCEDURE initialize
(
   p_file               IN VARCHAR2,
   p_run_id             IN OUT NUMBER,
   p_run_stage_id       IN OUT NUMBER,
   p_run_transform_id   IN OUT NUMBER,
   p_run_load_id        IN OUT NUMBER
);

PROCEDURE create_mappings
(
   p_run_id          IN  NUMBER,
   p_run_phase_id    IN  NUMBER,
   p_error_message   OUT VARCHAR2,
   p_record_count    OUT NUMBER,
   p_error_count     OUT NUMBER
);

PROCEDURE create_mappings
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_debug_flag         IN   VARCHAR2   
);

PROCEDURE get_mapping
(
   p_src_seg1          IN  VARCHAR2,
   p_src_seg2          IN  VARCHAR2,
   p_src_seg3          IN  VARCHAR2,
   p_src_seg4          IN  VARCHAR2,
   p_src_seg5          IN  VARCHAR2,
   p_src_account_type  IN VARCHAR2,
   p_target_seg1       OUT VARCHAR2,
   p_target_seg2       OUT VARCHAR2,
   p_target_seg3       OUT VARCHAR2,
   p_target_seg4       OUT VARCHAR2,
   p_target_seg5       OUT VARCHAR2,
   p_target_seg6       OUT VARCHAR2,
   p_target_seg7       OUT VARCHAR2,
   x_ccid              OUT NUMBER,
   x_error_message     OUT VARCHAR2
);

FUNCTION get_mapped_code_combination
(
   p_code_comb IN VARCHAR2,
   x_ccid  OUT NUMBER,
   x_error_msg OUT VARCHAR2
) 
RETURN VARCHAR2;

PROCEDURE build_account_mapping 
(
   p_errbuff     OUT VARCHAR2,
   p_retcode     OUT NUMBER,
   p_debug_flag  IN  VARCHAR2
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

END xxgl_import_coa_mapping_pkg;
/
