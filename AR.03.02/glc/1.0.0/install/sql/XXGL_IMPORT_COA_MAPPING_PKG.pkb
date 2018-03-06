create or replace PACKAGE BODY xxgl_import_coa_mapping_pkg AS
/*$Header : $*/
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

TYPE last_number_rec_type IS RECORD
(
   record_id           VARCHAR2(60),
   last_number         NUMBER
);

TYPE prerun_error_tab_type IS TABLE OF VARCHAR2(640);

-- Interface Framework --
g_appl_short_name           VARCHAR2(10)   := 'GL';
g_debug                     VARCHAR2(30)   := 'DEBUG: ';
g_error                     VARCHAR2(30)   := 'ERROR: ';
g_staging_directory         VARCHAR2(30)   := 'WORKING';
g_src_code                  VARCHAR2(30)   := 'GL.00.01';
g_int_mode                  VARCHAR2(60)   := 'VALIDATE_TRANSFER';
g_stage                     VARCHAR2(30)   := 'STAGE';
g_transform                 VARCHAR2(30)   := 'TRANSFORM';
g_load                      VARCHAR2(30)   := 'LOAD';
--g_reset_tfm_sql             VARCHAR2(1000) := 'TRUNCATE TABLE FMSMGR.XXGL_COA_MAPPINGS';
g_int_code                  dot_int_interfaces.int_code%TYPE := 'GL.00.01';
g_int_name                  dot_int_interfaces.int_name%TYPE := 'DEDJTR GL COA Mapping Import';

-- Defaulting Rules --
g_enitity_file              VARCHAR2(150)  := 'ENTITY_COA_MAPPINGS.csv';
g_account_file              VARCHAR2(150)  := 'ACCOUNT_COA_MAPPINGS.csv';
g_cost_centre_file          VARCHAR2(150)  := 'COST_CENTRE_COA_MAPPINGS.csv';
g_authority_file            VARCHAR2(150)  := 'AUTHORITY_COA_MAPPINGS.csv';
g_project_file              VARCHAR2(150)  := 'PROJECT_COA_MAPPINGS.csv';
g_output_file               VARCHAR2(150)  := 'OUTPUT_COA_MAPPINGS.csv';
g_identifier_file           VARCHAR2(150)  := 'IDENTIFIER_COA_MAPPINGS.csv';
g_code_comb_file            VARCHAR2(150)  := 'CODE_COMB_COA_MAPPINGS.csv';
g_ctl_entity                VARCHAR2(150)  := '$GLC_TOP/bin/XXGLCOAENTI.ctl';
g_ctl_account               VARCHAR2(150)  := '$GLC_TOP/bin/XXGLCOAACC.ctl';
g_ctl_cost_cnetre           VARCHAR2(150)  := '$GLC_TOP/bin/XXGLCOACOST.ctl';
g_ctl_authority             VARCHAR2(150)  := '$GLC_TOP/bin/XXGLCOAAUTH.ctl';
g_ctl_project               VARCHAR2(150)  := '$GLC_TOP/bin/XXGLCOAPJT.ctl';
g_ctl_output                VARCHAR2(150)  := '$GLC_TOP/bin/XXGLCOAOUT.ctl';
g_ctl_identifier            VARCHAR2(150)  := '$GLC_TOP/bin/XXGLCOAIDENT.ctl';
g_ctl_code_comb            VARCHAR2(150)   := '$GLC_TOP/bin/XXGLCCOMB.ctl';

z_file_temp_dir             CONSTANT VARCHAR2(150)  := 'USER_TMP_DIR';
z_file_temp_path            CONSTANT VARCHAR2(150)  := '/usr/tmp';
z_file_write                CONSTANT VARCHAR2(1)    := 'w';

-- System Parameters --
g_user_id              fnd_user.user_id%TYPE;
g_login_id             NUMBER;
g_appl_id              fnd_application.application_id%TYPE;
g_user_name            fnd_user.user_name%TYPE;
g_interface_req_id     NUMBER;
g_debug_flag           VARCHAR2(2);

g_sob_id               gl_sets_of_books.set_of_books_id%TYPE := fnd_profile.value('GL_SET_OF_BKS_ID');
g_coa_id               gl_code_combinations.chart_of_accounts_id%TYPE;
g_org_id               NUMBER;

-- SRS --
srs_wait               BOOLEAN;
srs_phase              VARCHAR2(30);
srs_status             VARCHAR2(30);
srs_dev_phase          VARCHAR2(30);
srs_dev_status         VARCHAR2(30);
srs_message            VARCHAR2(240);

------------------------------------------------------
-- Procedure
--     PRINT_DEBUG
-- Purpose
--     Print debug log to FND_FILE.LOG
------------------------------------------------------

PROCEDURE print_debug
(
   p_debug_text   VARCHAR2
)
IS
BEGIN
   IF g_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || p_debug_text);
   END IF;
END print_debug;

------------------------------------------------------
-- Procedure
--     WAIT_FOR_REQUEST
-- Purpose
--     Oracle standard API for concurrent processing
------------------------------------------------------

PROCEDURE wait_for_request
(
   p_request_id   NUMBER,
   p_wait_time    NUMBER
)
IS
BEGIN
   srs_wait := fnd_concurrent.wait_for_request(p_request_id,
                                               p_wait_time,
                                               0,
                                               srs_phase,
                                               srs_status,
                                               srs_dev_phase,
                                               srs_dev_status,
                                               srs_message);
END wait_for_request;

----------------------------------------------------------
-- Procedure
--     RAISE_ERROR
-- Purpose
--     Subroutine for calling run phase errors log report
--     (Interface Framework API).
----------------------------------------------------------

PROCEDURE raise_error
(
   p_error_rec      dot_int_run_phase_errors%ROWTYPE
)
IS
BEGIN
   dot_common_int_pkg.raise_error(p_run_id => p_error_rec.run_id,
                                  p_run_phase_id => p_error_rec.run_phase_id,
                                  p_record_id => p_error_rec.record_id,
                                  p_msg_code => p_error_rec.msg_code,
                                  p_error_text => p_error_rec.error_text,
                                  p_error_token_val1 => p_error_rec.error_token_val1,
                                  p_error_token_val2 => p_error_rec.error_token_val2,
                                  p_error_token_val3 => p_error_rec.error_token_val3,
                                  p_error_token_val4 => p_error_rec.error_token_val4,
                                  p_error_token_val5 => p_error_rec.error_token_val5,
                                  p_int_table_key_val1 => p_error_rec.int_table_key_val1,
                                  p_int_table_key_val2 => p_error_rec.int_table_key_val2,
                                  p_int_table_key_val3 => p_error_rec.int_table_key_val3);
END raise_error;

-----------------------------------------------
-- Function
--    GET_FILES
-- Purpose
--    Interface Framework subprocess used for
--    checking occurrence of inbound files.
-----------------------------------------------

FUNCTION get_files
(
   p_source             IN  VARCHAR2,
   p_file_string        IN  VARCHAR2,
   p_inbound_directory  OUT VARCHAR2,
   p_files              OUT xxint_common_pkg.t_files_type,
   p_message            OUT VARCHAR2
)
RETURN BOOLEAN
IS
   l_file_req_id         NUMBER;
   l_code                VARCHAR2(15);
   l_message             VARCHAR2(1000);
   r_request             xxint_common_pkg.control_record_type;
BEGIN
   p_inbound_directory := NULL;
   p_message := NULL;

   p_inbound_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => p_source,
                                                          p_message => p_message);
   IF p_message IS NOT NULL THEN
      RETURN FALSE;
   END IF;

   l_file_req_id := fnd_request.submit_request(application => 'FNDC',
                                               program     => 'XXINTIFR',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => g_interface_req_id,
                                               argument2   => p_inbound_directory,
                                               argument3   => p_file_string,
                                               argument4   => g_appl_id);
   COMMIT;

   print_debug('fetching file ' || p_file_string || ' from ' || p_inbound_directory || ' (request_id=' || l_file_req_id || ')');

   wait_for_request(l_file_req_id, 5);

   IF NOT (srs_dev_phase = 'COMPLETE' AND
          (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
      xxint_common_pkg.get_error_message(g_error_message_02, l_code, l_message);
      l_message := REPLACE(l_message, '$INT_DIR', p_inbound_directory);
      r_request.error_message := l_message;
      r_request.status := 'ERROR';

   ELSE
      SELECT file_name BULK COLLECT
      INTO   p_files
      FROM   xxint_interface_ctl
      WHERE  interface_request_id = g_interface_req_id
      AND    sub_request_id = l_file_req_id
      AND    file_name IS NOT NULL;

      r_request.status := 'SUCCESS';
   END IF;

   -- Interface control record
   r_request.application_id := g_appl_id;
   r_request.interface_request_id := g_interface_req_id;
   r_request.sub_request_id := l_file_req_id;
   xxint_common_pkg.interface_request(r_request);

   p_message := l_message;

   IF r_request.status = 'ERROR' THEN
      RETURN FALSE;
   END IF;

   RETURN TRUE;

EXCEPTION
   WHEN others THEN
      p_message := SQLERRM;
      RETURN FALSE;
END get_files;



PROCEDURE execute_multiple_files
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_source             IN   VARCHAR2,
   p_debug_flag         IN   VARCHAR2,
   p_int_mode           IN   VARCHAR2
)
IS
   l_source  VARCHAR2(300) := 'CONV';
BEGIN

   -- Import Code Combination from DSDBI
   run_import
   (
   p_errbuff,
   p_retcode,
   p_source,
   g_code_comb_file,
   g_ctl_code_comb,
   p_debug_flag,
   p_int_mode
   );

   -- Import Entity Mapping
   run_import
   (
   p_errbuff,
   p_retcode,
   p_source,
   g_enitity_file,
   g_ctl_entity,
   p_debug_flag,
   p_int_mode
   );

   -- Import Account Mapping
   run_import
   (
   p_errbuff,
   p_retcode,
   p_source,
   g_account_file,
   g_ctl_account,
   p_debug_flag,
   p_int_mode
   );

   -- Import Cost Centre Mapping
   run_import
   (
   p_errbuff,
   p_retcode,
   p_source,
   g_cost_centre_file,
   g_ctl_cost_cnetre,
   p_debug_flag,
   p_int_mode
   );

   -- Import Cost Centre Mapping
   run_import
   (
   p_errbuff,
   p_retcode,
   p_source,
   g_authority_file,
   g_ctl_authority,
   p_debug_flag,
   p_int_mode
   );

   -- Import Project Mapping
   run_import
   (
   p_errbuff,
   p_retcode,
   p_source,
   g_project_file,
   g_ctl_project,
   p_debug_flag,
   p_int_mode
   );

   -- Import Output Mapping
   run_import
   (
   p_errbuff,
   p_retcode,
   p_source,
   g_output_file,
   g_ctl_output,
   p_debug_flag,
   p_int_mode
   );

   -- Import Identifier Mapping
   run_import
   (
   p_errbuff,
   p_retcode,
   p_source,
   g_identifier_file,
   g_ctl_identifier,
   p_debug_flag,
   p_int_mode
   );


   create_mappings
   (
   p_errbuff,
   p_retcode,
   p_debug_flag
   );

END execute_multiple_files;

PROCEDURE get_mapping
(
   p_src_seg1       IN  VARCHAR2
  ,p_src_seg2       IN  VARCHAR2
  ,p_src_seg3       IN  VARCHAR2
  ,p_src_seg4       IN  VARCHAR2
  ,p_src_seg5       IN  VARCHAR2
  ,p_src_account_type IN VARCHAR2
  ,p_target_seg1    OUT VARCHAR2
  ,p_target_seg2    OUT VARCHAR2
  ,p_target_seg3    OUT VARCHAR2
  ,p_target_seg4    OUT VARCHAR2
  ,p_target_seg5    OUT VARCHAR2
  ,p_target_seg6    OUT VARCHAR2
  ,p_target_seg7    OUT VARCHAR2
  ,x_ccid           OUT NUMBER
  ,x_error_message  OUT VARCHAR2
)
IS
   lv_err_msg VARCHAR2(2000) := 'No data found for Entity:';
   ln_coa_id                 gl_code_combinations.chart_of_accounts_id%TYPE;
BEGIN
   lv_err_msg := NULL;
   x_error_message := NULL;

   BEGIN
      SELECT chart_of_accounts_id
      INTO   g_coa_id
      FROM   gl_sets_of_books
      WHERE  set_of_books_id = g_sob_id;
   EXCEPTION
      WHEN OTHERS THEN
         x_error_message := 'Unable to derive COA ID'||SQLERRM;
   END;

   IF g_coa_id IS NOT NULL THEN
	   -- Seg1 - Organisation
   BEGIN
	    SELECT dedjtr_entity
	    INTO   p_target_seg1
	    FROM   xxgl_coa_entity_map_stg
	    WHERE  dbi_entity = p_src_seg1
	    AND    apply = 'Y';
   EXCEPTION
	    WHEN no_data_found THEN
         lv_err_msg := 'No data found for Entity:'|| p_src_seg1||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
      WHEN TOO_MANY_ROWS THEN
         lv_err_msg := 'Too many rows found for Entity:'|| p_src_seg1||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
      WHEN OTHERS THEN
         lv_err_msg := 'Error occured for Entity:'|| p_src_seg1||' Error Code is :  '||SQLERRM||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
   END;

	    -- Seg2 - Account
	 BEGIN
	    SELECT dedjtr_account
	    INTO   p_target_seg2
	    FROM   xxgl_coa_account_map_stg
	    WHERE  dbi_account = p_src_seg4
	    AND    apply = 'Y';
   EXCEPTION
	    WHEN no_data_found THEN
         lv_err_msg := 'No data found for Account:'|| p_src_seg4||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
      WHEN TOO_MANY_ROWS THEN
         lv_err_msg := 'Too many rows found for Account:'|| p_src_seg4||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
      WHEN OTHERS THEN
         lv_err_msg := 'Error occured for Account:'|| p_src_seg4||' Error Code is :  '||SQLERRM||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
	 END;

	   -- Seg3 - Cost Center
   BEGIN
	    SELECT dedjtr_cc
	    INTO   p_target_seg3
	    FROM   xxgl_coa_cc_map_stg
	    WHERE  dbi_cc = p_src_seg3
	    AND    apply = 'Y';
   EXCEPTION
	    WHEN no_data_found THEN
         lv_err_msg := 'No data found for Cost Center:'|| p_src_seg3||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
      WHEN TOO_MANY_ROWS THEN
         lv_err_msg := 'Too many rows found for Cost Center:'|| p_src_seg3||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
      WHEN OTHERS THEN
         lv_err_msg := 'Error occured for Cost Center:'|| p_src_seg3||' Error Code is :  '||SQLERRM||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
   END;

	   -- Seg4 - Authority
	 BEGIN
      SELECT dedjtr_authority
	    INTO   p_target_seg4
	    FROM   xxgl_coa_authority_map_stg
	    WHERE  /*dbi_acct_type = p_src_account_type
	    AND    */dbi_account = p_src_seg4
	    AND    dbi_source = p_src_seg2
	    AND    apply = 'Y';
   EXCEPTION
	    WHEN no_data_found THEN
         lv_err_msg := 'No data found for Authority:DBI Account-'|| p_src_seg4||' and DBI Source-' || p_src_seg2||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
      WHEN TOO_MANY_ROWS THEN
         lv_err_msg := 'Too many rows found for Authority:DBI Account-'|| p_src_seg4||' and DBI Source-' || p_src_seg2||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
      WHEN OTHERS THEN
         lv_err_msg := 'Error occured for Authority:DBI Account-:'|| p_src_seg4||' and DBI Source-' || p_src_seg2||' Error Code is :  '||SQLERRM||' ';
	       print_debug(lv_err_msg);
         x_error_message := x_error_message||lv_err_msg;
   END;

	   -- Seg5 - Project
	   BEGIN
	      SELECT dedjtr_project
	      INTO   p_target_seg5
	      FROM   xxgl_coa_project_map_stg
	      WHERE  dbi_project = p_src_seg2 -- Need to make change in xxgl_coa_project_map_stg from dbi_project to dbi_source
	      AND    apply = 'Y';
	   EXCEPTION
	      WHEN no_data_found THEN
           lv_err_msg := 'No data found for Project:'|| p_src_seg2||' ';
	         print_debug(lv_err_msg);
           x_error_message := x_error_message||lv_err_msg;
        WHEN TOO_MANY_ROWS THEN
           lv_err_msg := 'Too many rows found for Project:'|| p_src_seg2||' ';
	         print_debug(lv_err_msg);
           x_error_message := x_error_message||lv_err_msg;
        WHEN OTHERS THEN
           lv_err_msg := 'Error occured for Project:'|| p_src_seg2||' Error Code is :  '||SQLERRM||' ';
	         print_debug(lv_err_msg);
           x_error_message := x_error_message||lv_err_msg;
	   END;

	   -- Seg6 - Output
	   BEGIN
	      SELECT dedjtr_output
	      INTO   p_target_seg6
	      FROM   xxgl_coa_output_map_stg
	      WHERE  dbi_source = p_src_seg2
	      AND    dbi_cost_centre = p_src_seg3
	      AND    apply = 'Y';
	   EXCEPTION
	      WHEN no_data_found THEN
           lv_err_msg := 'No data found for Output:DBI Source-' || p_src_seg2||' and DBI CC:'||p_src_seg3||' ';
	         print_debug(lv_err_msg);
           x_error_message := x_error_message||lv_err_msg;
        WHEN TOO_MANY_ROWS THEN
           lv_err_msg := 'Too many rows found for Output:DBI Source-' || p_src_seg2||' and DBI CC:'||p_src_seg3||' ';
	         print_debug(lv_err_msg);
           x_error_message := x_error_message||lv_err_msg;
        WHEN OTHERS THEN
           lv_err_msg := 'Error occured for Output:DBI Source-' || p_src_seg2||' and DBI CC:'||p_src_seg3||' Error Code is :  '||SQLERRM||' ';
	         print_debug(lv_err_msg);
           x_error_message := x_error_message||lv_err_msg;
	   END;

	   -- Seg7 - Identifier
	   BEGIN
	      SELECT dedjtr_identifier
	      INTO   p_target_seg7
	      FROM   xxgl_coa_identifier_map_stg
	      WHERE  dbi_project = p_src_seg5
	      AND    apply = 'Y';
	   EXCEPTION
	      WHEN no_data_found THEN
           lv_err_msg := 'No data found for Identifier:'|| p_src_seg5||' ';
	         print_debug(lv_err_msg);
           x_error_message := x_error_message||lv_err_msg;
        WHEN TOO_MANY_ROWS THEN
           lv_err_msg := 'Too many rows found for Identifier:'|| p_src_seg5||' ';
	         print_debug(lv_err_msg);
           x_error_message := x_error_message||lv_err_msg;
        WHEN OTHERS THEN
           lv_err_msg := 'Error occured for Identifier:'|| p_src_seg5||' Error Code is :  '||SQLERRM||' ';
	         print_debug(lv_err_msg);
           x_error_message := x_error_message||lv_err_msg;
	   END;

   IF x_error_message IS NOT NULL THEN
      x_ccid := null;
   ELSE
      x_ccid := fnd_flex_ext.get_ccid(application_short_name => 'SQLGL',
                                                            key_flex_code => 'GL#',
                                                            structure_number => g_coa_id,
                                                            validation_date => NULL,
                                                            concatenated_segments => p_target_seg1||'-'||
                                                                                     p_target_seg2||'-'||
                                                                                     p_target_seg3||'-'||
                                                                                     p_target_seg4||'-'||
                                                                                     p_target_seg5||'-'||
                                                                                     p_target_seg6||'-'||
                                                                                     p_target_seg7);

      IF x_ccid = 0 THEN
         x_error_message := fnd_flex_ext.get_message;
         x_ccid := NULL;
      END IF;

   END IF;


	   print_debug('New seg1:'||p_target_seg1);
	   print_debug('New seg2:'||p_target_seg2);
	   print_debug('New seg3:'||p_target_seg3);
	   print_debug('New seg4:'||p_target_seg4);
	   print_debug('New seg5:'||p_target_seg5);
	   print_debug('New seg6:'||p_target_seg6);
	   print_debug('New seg7:'||p_target_seg7);

   END IF;

END get_mapping;

-------------------------------------------------------
-- Procedure
--     CREATE_MAPPINGS
-- Purpose
--     Main program for creating 5-string mappings to 7-string mappings.
-------------------------------------------------------

PROCEDURE create_mappings
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_debug_flag         IN   VARCHAR2
)
IS
   CURSOR c_source_ccstr IS
      SELECT DISTINCT segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             account_type
      FROM   XXGL_COA_DSDBI_CODE_COMB_STG
      WHERE  status = 'NEW';

   TYPE t_source_ccstr IS TABLE OF c_source_ccstr%ROWTYPE;
   r_source_ccstr t_source_ccstr;

   l_delim               VARCHAR2(1) := '|';
   l_request_id          NUMBER;
   l_period_name         gl_periods.period_name%TYPE;
   l_alloc_rule          ra_batch_sources.rev_acc_allocation_rule%TYPE;
   l_batch_source_type   ra_batch_sources.batch_source_type%TYPE;

   lv_target_seg1_org    xxgl_coa_mapping_conv_stg.target_organisation%TYPE := '';
   lv_target_seg2_acct   xxgl_coa_mapping_conv_stg.target_account%TYPE      := '';
   lv_target_seg3_cc     xxgl_coa_mapping_conv_stg.target_cost_centre%TYPE  := '';
   lv_target_seg4_auth   xxgl_coa_mapping_conv_stg.target_authority%TYPE    := '';
   lv_target_seg5_prj    xxgl_coa_mapping_conv_stg.target_project%TYPE      := '';
   lv_target_seg6_output xxgl_coa_mapping_conv_stg.target_output%TYPE       := '';
   lv_target_seg7_ident  xxgl_coa_mapping_conv_stg.target_identifier%TYPE   := '';

   lv_error_msg          VARCHAR2(2000);
   ln_ccid               NUMBER;
   ln_count              NUMBER := 0;
BEGIN
   -- Global Variables
   g_debug_flag := NVL(p_debug_flag, 'Y');
   g_interface_req_id := fnd_global.conc_request_id;
   g_user_name := fnd_global.user_name;
   g_org_id := fnd_global.org_id;
   g_user_id := fnd_global.user_id;
   g_login_id := fnd_global.login_id;
   g_appl_id := fnd_global.resp_appl_id;
   g_sob_id := fnd_profile.value('GL_SET_OF_BKS_ID');

   fnd_file.put_line(fnd_file.log, 'DEBUG_FLAG=' || g_debug_flag);
   dbms_output.put_line('DEBUG_FLAG=' || g_debug_flag);

   print_debug('org_id=' || g_org_id);
   print_debug('user_id=' || g_user_id);
   print_debug('login_id=' || g_login_id);
   print_debug('resp_appl_id=' || g_appl_id);
   print_debug('set_of_bks_id=' || g_sob_id);

   print_debug('Deleting the records from xxgl_coa_mapping_conv_stg :' || g_sob_id);
   DELETE FROM xxgl_coa_mapping_conv_stg;
   COMMIT;



   FOR r_source_ccstr IN c_source_ccstr
   LOOP
   ln_count := ln_count+1;
     get_mapping(r_source_ccstr.segment1
               ,r_source_ccstr.segment2
               ,r_source_ccstr.segment3
               ,r_source_ccstr.segment4
               ,r_source_ccstr.segment5
               ,r_source_ccstr.account_type
               ,lv_target_seg1_org
               ,lv_target_seg2_acct
               ,lv_target_seg3_cc
               ,lv_target_seg4_auth
               ,lv_target_seg5_prj
               ,lv_target_seg6_output
               ,lv_target_seg7_ident
               ,ln_ccid
               ,lv_error_msg
               );


        INSERT INTO xxgl_coa_mapping_conv_stg
         VALUES
              (xxgl_coa_mapping_recid_s.NEXTVAL
              ,NULL -- source_id
              ,r_source_ccstr.segment1
              ,r_source_ccstr.segment2
              ,r_source_ccstr.segment3
              ,r_source_ccstr.segment4
              ,r_source_ccstr.segment5
              ,ln_ccid -- target_id
              ,lv_target_seg1_org
              ,lv_target_seg2_acct
              ,lv_target_seg3_cc
              ,lv_target_seg4_auth
              ,lv_target_seg5_prj
              ,lv_target_seg6_output
              ,lv_target_seg7_ident
              ,case when lv_error_msg IS NOT NULL THEN 'ERROR' ELSE 'MAPPED' END
              ,fnd_global.user_id
              ,sysdate
              ,fnd_global.user_id
              ,sysdate
              ,lv_error_msg
              );

        IF mod(ln_count,100) = 0 THEN
           COMMIT;
        END IF;

   END LOOP;


END create_mappings;

FUNCTION get_mapped_code_combination(
                                       p_code_comb IN VARCHAR2,
                                       x_ccid  OUT NUMBER,
                                       x_error_msg OUT VARCHAR2
                                    ) RETURN VARCHAR2
IS
   CURSOR get_mapped_values (
                            p_segment1 IN VARCHAR2,
                            p_segment2 IN VARCHAR2,
                            p_segment3 IN VARCHAR2,
                            p_segment4 IN VARCHAR2,
                            p_segment5 IN VARCHAR2
                            ) IS
            SELECT target_organisation,
                   target_account,
                   target_cost_centre,
                   target_authority,
                   target_project,
                   target_output,
                   target_identifier,
                   target_ccid,
                   error_message,
                   'Y'
            FROM   xxgl_coa_mapping_conv_stg
            WHERE  source_entity=p_segment1
            AND    source_Source = p_segment2
            AND    source_cost_centre = p_segment3
            AND    source_account = p_segment4
            AND    source_project = p_segment5;

   t_segments            fnd_flex_ext.SegmentArray;
   l_segs                NUMBER;
   lv_target_seg1_org    xxgl_coa_mapping_conv_stg.target_organisation%TYPE := '';
   lv_target_seg2_acct   xxgl_coa_mapping_conv_stg.target_account%TYPE      := '';
   lv_target_seg3_cc     xxgl_coa_mapping_conv_stg.target_cost_centre%TYPE  := '';
   lv_target_seg4_auth   xxgl_coa_mapping_conv_stg.target_authority%TYPE    := '';
   lv_target_seg5_prj    xxgl_coa_mapping_conv_stg.target_project%TYPE      := '';
   lv_target_seg6_output xxgl_coa_mapping_conv_stg.target_output%TYPE       := '';
   lv_target_seg7_ident  xxgl_coa_mapping_conv_stg.target_identifier%TYPE   := '';
   lv_error_msg          VARCHAR2(2000);
   lv_record_exists      VARCHAR2(1);
   ln_ccid               NUMBER;
   ln_count              NUMBER := 0;

   PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
   l_segs := fnd_flex_ext.breakup_segments(concatenated_segs => p_code_comb,
                                                    delimiter         => '-',
                                                    segments          => t_segments);

   IF l_segs <> 5 THEN
      x_error_msg := 'Expected segment value is 5 actual value is : '||l_segs;
      COMMIT;
      RETURN NULL;
   ELSE -- 5 segment value is passed to the function
      OPEN get_mapped_values(t_segments(1),t_segments(2),t_segments(3),t_segments(4),t_segments(5));
      FETCH get_mapped_values INTO
                 lv_target_seg1_org,
                 lv_target_seg2_acct,
                 lv_target_seg3_cc,
                 lv_target_seg4_auth,
                 lv_target_seg5_prj,
                 lv_target_seg6_output,
                 lv_target_seg7_ident,
                 ln_ccid,
                 lv_error_msg,
                 lv_record_exists;
      CLOSE get_mapped_values;

      IF nvl(lv_record_exists,'N') = 'Y' THEN
         IF nvl(ln_ccid,0) = 0 THEN
            x_ccid := NULL;
            x_error_msg := lv_error_msg;
            COMMIT;
            RETURN NULL;
         ELSE -- valid mapped record exists in mapping table
            x_ccid := ln_ccid;
            x_error_msg := lv_error_msg;
            COMMIT;
            RETURN lv_target_seg1_org||'-'||
                   lv_target_seg2_acct||'-'||
                   lv_target_seg3_cc||'-'||
                   lv_target_seg4_auth||'-'||
                   lv_target_seg5_prj||'-'||
                   lv_target_seg6_output||'-'||
                   lv_target_seg7_ident;
         END IF;
      ELSE -- record does not exist in mapping table
              get_mapping(t_segments(1)
               ,t_segments(2)
               ,t_segments(3)
               ,t_segments(4)
               ,t_segments(5)
               ,NULL
               ,lv_target_seg1_org
               ,lv_target_seg2_acct
               ,lv_target_seg3_cc
               ,lv_target_seg4_auth
               ,lv_target_seg5_prj
               ,lv_target_seg6_output
               ,lv_target_seg7_ident
               ,ln_ccid
               ,lv_error_msg
               );

            x_ccid := ln_ccid;
            x_error_msg := lv_error_msg;

        INSERT INTO xxgl_coa_mapping_conv_stg
         VALUES
              (xxgl_coa_mapping_recid_s.NEXTVAL
              ,NULL -- source_id
              ,t_segments(1)
              ,t_segments(2)
              ,t_segments(3)
              ,t_segments(4)
              ,t_segments(5)
              ,ln_ccid -- target_id
              ,lv_target_seg1_org
              ,lv_target_seg2_acct
              ,lv_target_seg3_cc
              ,lv_target_seg4_auth
              ,lv_target_seg5_prj
              ,lv_target_seg6_output
              ,lv_target_seg7_ident
              ,case when lv_error_msg IS NOT NULL THEN 'ERROR' ELSE 'MAPPED' END
              ,fnd_global.user_id
              ,sysdate
              ,fnd_global.user_id
              ,sysdate
              ,lv_error_msg
              );
            COMMIT;

            IF lv_error_msg IS NULL THEN
               RETURN lv_target_seg1_org||'-'||
                   lv_target_seg2_acct||'-'||
                   lv_target_seg3_cc||'-'||
                   lv_target_seg4_auth||'-'||
                   lv_target_seg5_prj||'-'||
                   lv_target_seg6_output||'-'||
                   lv_target_seg7_ident;
            ELSE
               RETURN NULL;
            END IF;

      END IF;
   END IF;
   COMMIT;
RETURN NULL;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         RETURN NULL;
END ;


PROCEDURE run_import
(
   p_errbuff            OUT  VARCHAR2,
   p_retcode            OUT  NUMBER,
   p_source             IN   VARCHAR2,
   p_file_name          IN   VARCHAR2,
   p_control_file       IN   VARCHAR2,
   p_debug_flag         IN   VARCHAR2,
   p_int_mode           IN   VARCHAR2
)
IS
   CURSOR c_int IS
      SELECT int_id,
             int_code,
             enabled_flag
      FROM   dot_int_interfaces
      WHERE  int_code = g_int_code;

   l_file                VARCHAR2(150);
   l_file_error          VARCHAR2(1);
   l_inbound_directory   VARCHAR2(150);
   l_ctl                 VARCHAR2(60);
   l_source              VARCHAR2(30) := upper(p_source);
   l_code                VARCHAR2(15);
   l_message             VARCHAR2(1000);
   l_delim               VARCHAR2(1) := '|';
   l_request_id          NUMBER;

   r_int                 c_int%ROWTYPE;
   t_prerun_errors       prerun_error_tab_type := prerun_error_tab_type();
   t_files               xxint_common_pkg.t_files_type;

   -- Interface Framework
   l_run_id              NUMBER;
   l_run_stage_id        NUMBER;
   l_run_transform_id    NUMBER;
   l_run_load_id         NUMBER;
   l_run_report_id       NUMBER;

   stage_phase           BOOLEAN;
   transform_phase       BOOLEAN;
   load_phase            BOOLEAN;
   write_to_out          BOOLEAN;

   interface_error       EXCEPTION;
   to_date_error         EXCEPTION;
   PRAGMA                EXCEPTION_INIT(to_date_error, -1850);

BEGIN
   xxint_common_pkg.g_object_type := 'SEGMENTS'; -- Added as interface directories are repointed to NFS
   -- Global Variables
   g_debug_flag := NVL(p_debug_flag, 'N');
   g_interface_req_id := fnd_global.conc_request_id;
   g_user_name := fnd_global.user_name;
   g_user_id := fnd_global.user_id;
   g_login_id := fnd_global.login_id;
   g_appl_id := fnd_global.resp_appl_id;
   g_int_mode := NVL(p_int_mode, g_int_mode);
   write_to_out := TRUE;

   l_ctl := p_control_file;
   l_file := p_file_name;

   fnd_file.put_line(fnd_file.log, 'DEBUG_FLAG=' || g_debug_flag);

   print_debug('parameter: p_source=' || p_source);
   print_debug('parameter: p_file_name=' || l_file);
   print_debug('parameter: p_control_file=' || l_ctl);
   print_debug('parameter: p_int_mode=' || g_int_mode);
   print_debug('user_id=' || g_user_id);
   print_debug('login_id=' || g_login_id);
   print_debug('resp_appl_id=' || g_appl_id);
   print_debug('pre interface run validations...');

   -- Interface Registry
   OPEN c_int;
   FETCH c_int INTO r_int;
   IF c_int%NOTFOUND THEN
      INSERT INTO dot_int_interfaces
      VALUES (dot_int_interfaces_s.NEXTVAL,
              g_int_code,
              g_int_name,
              'IN',
              'GL',
              'Y',
              SYSDATE,
              g_user_id,
              g_user_id,
              SYSDATE,
              g_login_id,
              g_interface_req_id);
      COMMIT;
   ELSE
      IF NVL(r_int.enabled_flag, 'N') = 'N' THEN
         xxint_common_pkg.get_error_message(g_error_message_01, l_code, l_message);
         l_message := REPLACE(l_message, '$INT_CODE', g_int_code);
         t_prerun_errors.EXTEND;
         t_prerun_errors(t_prerun_errors.COUNT) := l_message;
      END IF;
   END IF;
   CLOSE c_int;

   IF t_prerun_errors.COUNT > 0 THEN
      RAISE interface_error;
   END IF;

   print_debug('pre interface run validations... passed');

   -- Get files
   IF NOT get_files(p_source => l_source,
                    p_file_string => l_file,
                    p_inbound_directory => l_inbound_directory,
                    p_files => t_files,
                    p_message => l_message)
   THEN
      RAISE interface_error;
   END IF;

   print_debug('file_count=' || t_files.COUNT);

   IF t_files.COUNT > 1 THEN
      write_to_out := FALSE;
   END IF;

   -- Interface Run Phases
   FOR i IN 1 .. t_files.COUNT LOOP
      l_file := REPLACE(t_files(i), l_inbound_directory || '/');
      l_file_error := NULL;

      initialize(l_file,
                 l_run_id,
                 l_run_stage_id,
                 l_run_transform_id,
                 l_run_load_id);

      print_debug('====================================');
      print_debug('interface framework initialize phase');
      print_debug('====================================');
      print_debug('run_id=' || l_run_id);
      print_debug('run_stage_id=' || l_run_stage_id);
      print_debug('run_transform_id=' || l_run_transform_id);
      print_debug('run_load_id=' || l_run_load_id);
      print_debug('====================================');

      l_request_id := NULL;

      stage_phase := stage(p_run_id => l_run_id,
                           p_run_phase_id => l_run_stage_id,
                           p_source => l_source,
                           p_file => l_file,
                           p_ctl => l_ctl,
                           p_file_error => l_file_error);


      l_run_report_id := dot_common_int_pkg.launch_run_report
                            (p_run_id => l_run_id,
                             p_notify_user => g_user_name);

      print_debug('run interface report (request_id=' || l_run_report_id || ')');

   END LOOP;
   
   print_output(l_run_id,
                   l_run_transform_id,
                   l_request_id,
                   l_source,
                   l_file,
                   l_file_error,
                   l_delim,
                   write_to_out);

EXCEPTION
   WHEN interface_error THEN
      print_debug('pre interface run validations... failed');
      FOR i IN 1 .. t_prerun_errors.COUNT LOOP
         fnd_file.put_line(fnd_file.log, g_error || t_prerun_errors(i));
      END LOOP;
      p_retcode := 2;

END run_import;

--------------------------------------------------------
-- Function
--     STAGE
-- Purpose
--     Interface Framework STAGE phase. This is the
--     subprocess that loads the data file from a
--     specified source into the staging area.
--------------------------------------------------------

FUNCTION stage
(
   p_run_id         IN  NUMBER,
   p_run_phase_id   IN  NUMBER,
   p_source         IN  VARCHAR2,
   p_file           IN  VARCHAR2,
   p_ctl            IN  VARCHAR2,
   p_file_error     OUT VARCHAR2
)
RETURN BOOLEAN
IS
   l_inbound_directory    VARCHAR2(150);
   l_outbound_directory   VARCHAR2(150);
   l_staging_directory    VARCHAR2(150);
   l_archive_directory    VARCHAR2(150);
   l_file                 VARCHAR2(150);
   l_bad                  VARCHAR2(150);
   l_log                  VARCHAR2(150);
   l_request_id           NUMBER;
   l_record_count         NUMBER := 0;
   l_error_count          NUMBER := 0;
   l_code                 VARCHAR2(15);
   l_message              VARCHAR2(1000);
   r_request              xxint_common_pkg.control_record_type;

   stage_error            EXCEPTION;
BEGIN
   p_file_error := 'N';

   print_debug('retrieve interface directory information');

   l_inbound_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => p_source,
                                                          p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE stage_error;
   END IF;

   l_outbound_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                           p_source => p_source,
                                                           p_in_out => 'OUTBOUND',
                                                           p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE stage_error;
   END IF;

   l_staging_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => p_source,
                                                          p_in_out => g_staging_directory,
                                                          p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE stage_error;
   END IF;

   l_archive_directory := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                          p_source => p_source,
                                                          p_archive => 'Y',
                                                          p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE stage_error;
   END IF;

   l_file := p_file;
   l_log  := REPLACE(l_file, 'csv', 'log');
   l_bad  := REPLACE(l_file, 'csv', 'bad');

   print_debug('l_inbound_directory=' || l_inbound_directory);
   print_debug('l_outbound_directory=' || l_outbound_directory);
   print_debug('l_staging_directory=' || l_staging_directory);
   print_debug('l_archive_directory=' || l_archive_directory);
   print_debug('l_file=' || l_file);
   print_debug('l_log=' || l_log);
   print_debug('l_bad=' || l_bad);

   l_request_id := fnd_request.submit_request(application => 'FNDC',
                                              program     => 'XXINTSQLLDR',
                                              description => NULL,
                                              start_time  => NULL,
                                              sub_request => FALSE,
                                              argument1   => l_inbound_directory,
                                              argument2   => l_outbound_directory,
                                              argument3   => l_staging_directory,
                                              argument4   => l_archive_directory,
                                              argument5   => l_file,
                                              argument6   => l_log,
                                              argument7   => l_bad,
                                              argument8   => p_ctl);
   COMMIT;

   print_debug('load file ' || l_file || ' to staging (request_id=' || l_request_id || ')');

   wait_for_request(l_request_id, 5);
   r_request := NULL;

   IF NOT (srs_dev_phase = 'COMPLETE' AND
          (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
      xxint_common_pkg.get_error_message(g_error_message_03, l_code, l_message);
      l_message := REPLACE(l_message, '$INT_FILE', l_file);
      r_request.error_message := l_message;
      r_request.status := 'ERROR';
      p_file_error := 'Y';

   ELSE

      IF l_file LIKE 'ENTITY_COA_MAPPINGS.csv' THEN

         UPDATE XXGL_COA_ENTITY_MAP_STG
         SET    run_id = p_run_id,
                run_phase_id = p_run_phase_id,
                status = 'PROCESSED',
                created_by = g_user_id,
                creation_date = SYSDATE
         WHERE  status = 'NEW';

      ELSIF l_file LIKE 'ACCOUNT_COA_MAPPINGS.csv' THEN

         UPDATE XXGL_COA_ACCOUNT_MAP_STG
         SET    run_id = p_run_id,
                run_phase_id = p_run_phase_id,
                status = 'PROCESSED',
                created_by = g_user_id,
                creation_date = SYSDATE
         WHERE  status = 'NEW';

      ELSIF l_file LIKE 'COST_CENTRE_COA_MAPPINGS.csv' THEN

         UPDATE XXGL_COA_CC_MAP_STG
         SET    run_id = p_run_id,
                run_phase_id = p_run_phase_id,
                status = 'PROCESSED',
                created_by = g_user_id,
                creation_date = SYSDATE
         WHERE  status = 'NEW';

      ELSIF l_file LIKE 'AUTHORITY_COA_MAPPINGS.csv' THEN

         UPDATE XXGL_COA_AUTHORITY_MAP_STG
         SET    run_id = p_run_id,
                run_phase_id = p_run_phase_id,
                status = 'PROCESSED',
                created_by = g_user_id,
                creation_date = SYSDATE
         WHERE  status = 'NEW';

      ELSIF l_file LIKE 'PROJECT_COA_MAPPINGS.csv' THEN

         UPDATE XXGL_COA_PROJECT_MAP_STG
         SET    run_id = p_run_id,
                run_phase_id = p_run_phase_id,
                status = 'PROCESSED',
                created_by = g_user_id,
                creation_date = SYSDATE
         WHERE  status = 'NEW';

      ELSIF l_file LIKE 'OUTPUT_COA_MAPPINGS.csv' THEN

         UPDATE XXGL_COA_OUTPUT_MAP_STG
         SET    run_id = p_run_id,
                run_phase_id = p_run_phase_id,
                status = 'PROCESSED',
                created_by = g_user_id,
                creation_date = SYSDATE
         WHERE  status = 'NEW';

      ELSIF l_file LIKE 'IDENTIFIER_COA_MAPPINGS.csv' THEN

         UPDATE XXGL_COA_IDENTIFIER_MAP_STG
         SET    run_id = p_run_id,
                run_phase_id = p_run_phase_id,
                status = 'PROCESSED',
                created_by = g_user_id,
                creation_date = SYSDATE
         WHERE  status = 'NEW';


      END IF;

      l_record_count := sql%ROWCOUNT;

      IF l_record_count > 0 THEN
         COMMIT;
      END IF;

      r_request.status := 'SUCCESS';

      -- Update Run Phase
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => g_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      -- End Run Phase
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => r_request.status,
          p_error_count => 0,
          p_success_count => l_record_count);
   END IF;

   print_debug('stage: record_count=' || l_record_count);
   print_debug('stage: success_count=' || l_record_count);
   print_debug('stage: error_count=' || l_error_count);

   -- Interface control record
   r_request.application_id := g_appl_id;
   r_request.interface_request_id := g_interface_req_id;
   r_request.file_name := l_file;
   r_request.sub_request_id := l_request_id;
   xxint_common_pkg.interface_request(r_request);

   IF r_request.status = 'ERROR' THEN
      RAISE stage_error;
   END IF;

   RETURN TRUE;

EXCEPTION
   WHEN stage_error THEN
      fnd_file.put_line(fnd_file.log, g_error || l_message);

      -- Update Run Phase
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => g_src_code,
          p_rec_count    => 0,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      -- End Run Phase
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => 'ERROR',
          p_error_count => 0,
          p_success_count => 0);

      RETURN FALSE;

   WHEN others THEN
      xxint_common_pkg.get_error_message(g_error_message_04, l_code, l_message);
      l_message := l_message || ' ' || SQLERRM;
      fnd_file.put_line(fnd_file.log, g_error || l_message);

      -- Update Run Phase
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_src_code     => g_src_code,
          p_rec_count    => 0,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      -- End Run Phase
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => p_run_phase_id,
          p_status => 'ERROR',
          p_error_count => 0,
          p_success_count => 0);

      RETURN FALSE;
END stage;


-----------------------------------------------
-- Procedure
--    PRINT_OUTPUT
-- Purpose
--    Procedure for creating output file.
-----------------------------------------------

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
)
IS
   CURSOR c_results IS
      SELECT 'Organisation' segment_type,
        APPLY apply_flag,
        status,
        count(*) inserted_numbers
      FROM xxgl_coa_entity_map_stg
      GROUP BY APPLY, status
      UNION ALL
      SELECT 'Account',
        APPLY,
        status,
        count(*)
      FROM xxgl_coa_account_map_stg
      GROUP BY APPLY, status
      UNION ALL
      SELECT 'Cost Centre',
        APPLY,
        status,
        count(*)
      FROM xxgl_coa_cc_map_stg
      GROUP BY APPLY, status
      UNION ALL
      SELECT 'Authority',
       APPLY,
       status,
       count(*)
      FROM xxgl_coa_authority_map_stg
      GROUP BY APPLY, status
      UNION ALL
      SELECT 'Project',
       APPLY,
       status,
       count(*)
      FROM xxgl_coa_project_map_stg
      GROUP BY APPLY, status
      UNION ALL
      SELECT 'Output',
        APPLY,
        status,
        count(*)
      FROM xxgl_coa_output_map_stg
      GROUP BY APPLY, status
      UNION ALL
      SELECT 'Identifier',
        APPLY,
        status,
        count(*)
      FROM xxgl_coa_identifier_map_stg
      GROUP BY APPLY, status;

   l_file              VARCHAR2(150);
   l_outbound_path     VARCHAR2(150);
   l_text              VARCHAR2(32767);
   l_code              VARCHAR2(15);
   l_message           VARCHAR2(4000);
   r_results               c_results%ROWTYPE;
   f_handle            utl_file.file_type;
   f_copy              INTEGER;

   print_error         EXCEPTION;

BEGIN
   -- Comments:
   -- In case a file cannot be processed due to
   -- errors, use the parent request id for output
   -- file id.

   l_file := REPLACE(p_file, '.txt') || '_' || NVL(p_request_id, g_interface_req_id) || '.out';

   f_handle := utl_file.fopen(z_file_temp_dir, l_file, z_file_write);

   l_outbound_path := xxint_common_pkg.interface_path(p_application => g_appl_short_name,
                                                      p_source => p_source,
                                                      p_in_out => 'OUTBOUND',
                                                      p_message => l_message);
   IF l_message IS NOT NULL THEN
      RAISE print_error;
   END IF;

   print_debug('print output to file');

   OPEN c_results;
   LOOP
      FETCH c_results INTO r_results;
      EXIT WHEN c_results%NOTFOUND;

      l_text := NULL;
      l_text := l_text || r_results.segment_type ||' - ';
      l_text := l_text || r_results.apply_flag ||' : ';
      l_text := l_text || r_results.inserted_numbers;
      l_text := l_text || l_message;

      utl_file.put_line(f_handle, l_text);

      -- write output
      IF p_write_to_out THEN
         fnd_file.put_line(fnd_file.output, l_text);
      END IF;

      IF NVL(p_file_error, 'N') = 'Y' THEN
         EXIT;
      END IF;
   END LOOP;
   CLOSE c_results;

   utl_file.fclose(f_handle);

   print_debug('print output to file... completed');
   print_debug('move output file');
   print_debug('from_path=' || z_file_temp_path || '/' || l_file);
   print_debug('to_path=' || l_outbound_path || '/' || l_file);

   f_copy := xxint_common_pkg.file_copy(p_from_path => z_file_temp_path || '/' || l_file,
                                        p_to_path => l_outbound_path || '/' || l_file);

   print_debug('f_copy=' || f_copy);
   print_debug('1=SUCCESS');
   print_debug('0=FAILURE');
   print_debug('delete output file from temp directory');

   utl_file.fremove(z_file_temp_dir, l_file);

EXCEPTION
   WHEN print_error THEN
      IF utl_file.is_open(f_handle) THEN
         utl_file.fclose(f_handle);
      END IF;
      fnd_file.put_line(fnd_file.log, g_error || l_message);
   WHEN others THEN
      IF utl_file.is_open(f_handle) THEN
         utl_file.fclose(f_handle);
      END IF;
      fnd_file.put_line(fnd_file.log, g_error || SQLERRM);

END print_output;

------------------------------------------------------
-- Procedure
--     INITIALIZE
-- Purpose
--     Initializes the interface run phases
--     STAGE-TRANSFORM-LOAD
------------------------------------------------------

PROCEDURE initialize
(
   p_file               IN VARCHAR2,
   p_run_id             IN OUT NUMBER,
   p_run_stage_id       IN OUT NUMBER,
   p_run_transform_id   IN OUT NUMBER,
   p_run_load_id        IN OUT NUMBER
)
IS
BEGIN
   -- Interface Run
   p_run_id := dot_common_int_pkg.initialise_run
                  (p_int_code       => g_int_code,
                   p_src_rec_count  => NULL,
                   p_src_hash_total => NULL,
                   p_src_batch_name => p_file);

   -- Staging
   p_run_stage_id := dot_common_int_pkg.start_run_phase
                        (p_run_id                  => p_run_id,
                         p_phase_code              => g_stage,
                         p_phase_mode              => NULL,
                         p_int_table_name          => p_file,
                         p_int_table_key_col1      => '',
                         p_int_table_key_col_desc1 => '',
                         p_int_table_key_col2      => '',
                         p_int_table_key_col_desc2 => '',
                         p_int_table_key_col3      => '',
                         p_int_table_key_col_desc3 => '');

END initialize;

END xxgl_import_coa_mapping_pkg;