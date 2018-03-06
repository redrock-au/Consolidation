CREATE OR REPLACE PACKAGE BODY xxpo_cms_int_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AP.02.03/poc/1.0.0/install/sql/XXPO_CMS_INT_PKG.pkb 1806 2017-07-18 00:10:05Z svnuser $
/*******************************************************************
**
** CEMLI ID: PO.12.01
**
** Description: Interface program for importing contracts from CMS
**
** Change History:
**
** Date        Who                  Comments
** 12/05/2017  NCHENNURI (RED ROCK) Initial build.
**
*******************************************************************/
g_debug_flag                  VARCHAR2(1) := 'N';
g_int_batch_name              dot_int_runs.src_batch_name%TYPE;
g_org_id                      NUMBER;
g_chart_id                    NUMBER;
g_source                      fnd_lookup_values.lookup_code%TYPE;

TYPE r_srs_request_type IS RECORD 
(
   srs_wait           BOOLEAN,
   srs_phase          VARCHAR2(30),
   srs_status         VARCHAR2(30),
   srs_dev_phase      VARCHAR2(30),
   srs_dev_status     VARCHAR2(30),
   srs_message        VARCHAR2(240)
);

TYPE t_varchar_tab_type IS TABLE OF VARCHAR2(200) INDEX BY BINARY_INTEGER;
TYPE t_validation_errors_type IS TABLE OF VARCHAR2(240);

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      debug_msg
--  PURPOSE
--       Writes a line to the concurrent log file if the debug flag is on.
-- --------------------------------------------------------------------------------------------------
PROCEDURE debug_msg
(
   p_message            IN VARCHAR2
) IS
BEGIN
   IF nvl(g_debug_flag, 'N') = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || SUBSTR(p_message, 1, 1990));
   END IF;
END debug_msg;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      log_msg
--  PURPOSE
--       Writes a line to the concurrent log file.
-- --------------------------------------------------------------------------------------------------
PROCEDURE log_msg
(
   p_message            IN VARCHAR2
) IS
BEGIN
   fnd_file.put_line(fnd_file.log, SUBSTR(p_message, 1, 2000));
END log_msg;



-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      delete_stg_tfm
--  PURPOSE
--       Deletes data from stg and tfm
-- --------------------------------------------------------------------------------------------------
PROCEDURE delete_stg_tfm
IS
BEGIN
   DELETE xxpo_contracts_stg;
   DELETE xxpo_contracts_tfm;
   COMMIT;
END delete_stg_tfm;


-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      raise_error
--  PURPOSE
--       Local wrapper of the interface framework error procedure.
--       This inserts a row into dot_int_run_phase_errors.
-- --------------------------------------------------------------------------------------------------
PROCEDURE raise_error
(
   p_error_rec      IN OUT NOCOPY dot_int_run_phase_errors%ROWTYPE
)
IS
BEGIN
   dot_common_int_pkg.raise_error
      ( p_run_id => p_error_rec.run_id,
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
        p_int_table_key_val3 => p_error_rec.int_table_key_val3 );
END raise_error;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      append_error
--  PURPOSE
--      Appends an error message to an validation error pl/sql table
-- --------------------------------------------------------------------------------------------------
PROCEDURE append_error
(
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type,
   p_error                 IN VARCHAR2
) IS
BEGIN
   IF p_errors_tab IS NULL THEN
      p_errors_tab := t_validation_errors_type(SUBSTR(p_error, 1, 240));
   ELSE
      p_errors_tab.EXTEND;
      p_errors_tab(p_errors_tab.LAST) := SUBSTR(p_error, 1, 240);
   END IF;
END append_error;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      append_error
--  PURPOSE
--      Appends one validation error pl/sql table to another
-- --------------------------------------------------------------------------------------------------
PROCEDURE append_error_tab
(
   p_target_errors_tab     IN OUT NOCOPY t_validation_errors_type,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
BEGIN
   IF p_target_errors_tab IS NULL THEN
      p_target_errors_tab := t_validation_errors_type();
   END IF;
   IF p_errors_tab IS NOT NULL THEN
      p_target_errors_tab := p_target_errors_tab MULTISET UNION p_errors_tab;
   END IF;
END append_error_tab;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      is_number
--  PURPOSE
--      Determines whether a given value is a number.
--  RETURNS
--      True if the value is a number, else False
-- --------------------------------------------------------------------------------------------------
FUNCTION is_number
(
   p_value                 VARCHAR2
) RETURN BOOLEAN
IS
   l_number               NUMBER;
BEGIN
   l_number := to_number(p_value);
   RETURN TRUE;
EXCEPTION
   WHEN VALUE_ERROR THEN
      RETURN FALSE;
END is_number;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      insert_interface
--  PURPOSE
--      Inserts a row into the XXPO_CMS_INTERFACE table
-- --------------------------------------------------------------------------------------------------
PROCEDURE insert_interface
(
   p_tfm_rec               IN OUT NOCOPY xxpo_contracts_tfm%ROWTYPE
) IS
BEGIN

                  MERGE INTO xxpo_contracts_all c
                  USING DUAL ON (c.contract_number = p_tfm_rec.contract_number)
                  WHEN MATCHED THEN
                     UPDATE SET c.description = p_tfm_rec.description,
                                c.start_date = p_tfm_rec.start_date,
                                c.end_date = p_tfm_rec.end_date,
                                c.last_updated_by = p_tfm_rec.last_updated_by,
                                c.last_update_date = p_tfm_rec.last_update_date
                  WHEN NOT MATCHED THEN
                     INSERT (
				contract_number,
				description,
				org_id,
				attribute1,
				attribute2,
				attribute3,
				attribute4,
				attribute5,
				attribute6,
				attribute7,
				attribute8,
				attribute9,
				attribute10,
				attribute11,
				attribute12,
				attribute13,
				attribute14,
				attribute15,      
				start_date,
				end_date,
				creation_date,
				created_by,
				last_update_date,
				last_updated_by                     
                     )
                     VALUES (
				p_tfm_rec.contract_number,
				p_tfm_rec.description,
				p_tfm_rec.org_id,
				p_tfm_rec.attribute1,
				p_tfm_rec.attribute2,
				p_tfm_rec.attribute3,
				p_tfm_rec.attribute4,
				p_tfm_rec.attribute5,
				p_tfm_rec.attribute6,
				p_tfm_rec.attribute7,
				p_tfm_rec.attribute8,
				p_tfm_rec.attribute9,
				p_tfm_rec.attribute10,
				p_tfm_rec.attribute11,
				p_tfm_rec.attribute12,
				p_tfm_rec.attribute13,
				p_tfm_rec.attribute14,
				p_tfm_rec.attribute15,
				p_tfm_rec.start_date,
				p_tfm_rec.end_date,
				p_tfm_rec.creation_date,
				p_tfm_rec.created_by,
				p_tfm_rec.last_update_date,
				p_tfm_rec.last_updated_by                                          
                            );

   /*INSERT INTO xxpo_contracts_all
   (
      contract_number,
      description,
      org_id,
      attribute1,
      attribute2,
      attribute3,
      attribute4,
      attribute5,
      attribute6,
      attribute7,
      attribute8,
      attribute9,
      attribute10,
      attribute11,
      attribute12,
      attribute13,
      attribute14,
      attribute15,      
      start_date,
      end_date,
      creation_date,
      created_by,
      last_update_date,
      last_updated_by
   ) 
      VALUES
   (
      p_tfm_rec.contract_number,
      p_tfm_rec.description,
      p_tfm_rec.org_id,
      p_tfm_rec.attribute1,
      p_tfm_rec.attribute2,
      p_tfm_rec.attribute3,
      p_tfm_rec.attribute4,
      p_tfm_rec.attribute5,
      p_tfm_rec.attribute6,
      p_tfm_rec.attribute7,
      p_tfm_rec.attribute8,
      p_tfm_rec.attribute9,
      p_tfm_rec.attribute10,
      p_tfm_rec.attribute11,
      p_tfm_rec.attribute12,
      p_tfm_rec.attribute13,
      p_tfm_rec.attribute14,
      p_tfm_rec.attribute15,
      p_tfm_rec.start_date,
      p_tfm_rec.end_date,
      p_tfm_rec.creation_date,
      p_tfm_rec.created_by,
      p_tfm_rec.last_update_date,
      p_tfm_rec.last_updated_by
   );
   */
END insert_interface;


-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      get_interface_files
--  PURPOSE
--       Selects all file names found in the interface framework control table that was populated
--       by the interface framework loader program XXINTSQLLDR.
--       Result is returned as a list of file names in a varchar2 pl/sql table.
-- --------------------------------------------------------------------------------------------------
PROCEDURE get_interface_files
(
   p_request_id        IN NUMBER,
   p_sub_req_id        IN NUMBER,
   p_files_tab         IN OUT NOCOPY t_varchar_tab_type
) IS
BEGIN
   SELECT file_name BULK COLLECT
   INTO   p_files_tab
   FROM   xxint_interface_ctl
   WHERE  interface_request_id = p_request_id
   AND    sub_request_id = p_sub_req_id
   AND    file_name IS NOT NULL;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_files_tab.DELETE;
END get_interface_files;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      query_contract_number
--  PURPOSE
--      Queries an contract number for a specific contract
-- --------------------------------------------------------------------------------------------------
PROCEDURE query_contract_number
(
   p_contract_number        IN VARCHAR2,
   p_contracts_rec          IN OUT NOCOPY xxpo_contracts_all%ROWTYPE
) IS
   l_po_contracts_rec       xxpo_contracts_all%ROWTYPE;
BEGIN
   SELECT * 
   INTO   l_po_contracts_rec
   FROM   xxpo_contracts_all
   WHERE  contract_number = p_contract_number;
   p_contracts_rec := l_po_contracts_rec;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      l_po_contracts_rec.contract_number := NULL;
END query_contract_number;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      validate_load
--  PURPOSE
--      Validates and determines the the final status of transform records against base tables
--  RETURNS
--      Number of successfully imported records into CMS Interface
-- --------------------------------------------------------------------------------------------------
FUNCTION validate_load
(
   p_run_id             IN  NUMBER,
   p_run_phase_id       IN  NUMBER
)  RETURN NUMBER
IS
   CURSOR c_tfm(p_run_id IN NUMBER) IS
      SELECT tfm.record_id,
             tfm.contract_number,
             tfm.status
      FROM   xxpo_contracts_tfm tfm,
             xxpo_contracts_all xci
      WHERE  run_id IN p_run_id
      AND    xci.contract_number(+) = tfm.contract_number
      FOR UPDATE OF status;

   l_status               xxpo_contracts_tfm.status%TYPE;
   l_error_msg            fnd_lookup_values.meaning%TYPE;
   r_error                dot_int_run_phase_errors%ROWTYPE;
   l_success_count        NUMBER := 0;
   l_rejected_count       NUMBER := 0;
BEGIN
   FOR r_tfm IN c_tfm(p_run_id)
   LOOP
      IF r_tfm.contract_number IS NOT NULL THEN
         l_status := 'PROCESSED';
         l_success_count := l_success_count + 1;
      ELSE 
         l_status := 'REJECTED';
         l_rejected_count := l_rejected_count + 1;
         l_error_msg := 'Rejected by CMS Import';
         r_error.run_id := p_run_id;
         r_error.run_phase_id := p_run_phase_id;
         r_error.int_table_key_val1 := r_tfm.contract_number;
         r_error.record_id := r_tfm.record_id;
         r_error.error_text := l_error_msg;
         raise_error(r_error);
      END IF;
      UPDATE xxpo_contracts_tfm
         SET status = l_status
           , run_phase_id = p_run_phase_id
       WHERE CURRENT OF c_tfm;
   END LOOP;
   debug_msg('updated ' || l_success_count || ' transform rows to status processed');
   debug_msg('updated ' || l_rejected_count || ' transform rows to status rejected');
   RETURN l_success_count;
END validate_load;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_start_date
--  PURPOSE
--      Validates start date.
--  DESCRIPTION
--      1) Must have a value
--      2) Must be of the format DD-MON-YYYY
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_start_date
(
   p_stg_rec               IN OUT NOCOPY xxpo_contracts_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_contracts_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   z_date_format              CONSTANT VARCHAR2(11) := 'DD/MM/YYYY';
BEGIN
   IF p_stg_rec.start_date IS NOT NULL THEN
      -- validate format
      BEGIN
         p_tfm_rec.start_date := to_date(p_stg_rec.start_date, z_date_format);  --'FX'||z_date_format         
      EXCEPTION
         WHEN OTHERS THEN
            p_tfm_rec.start_date:=null;
            append_error(p_errors_tab, 'Contract start Date ''' || p_stg_rec.start_date 
               || ''' is not in the required format ''' || z_date_format || '''');
            --RETURN;
      END;
   ELSE
      append_error(p_errors_tab, 'Contract start date not supplied');
   END IF;
END validate_start_date;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_end_date
--  PURPOSE
--      Validates end date.
--  DESCRIPTION
--      1) Must be of the format DD-MON-YYYY
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_end_date
(
   p_stg_rec               IN OUT NOCOPY xxpo_contracts_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_contracts_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   z_date_format              CONSTANT VARCHAR2(11) := 'DD/MM/YYYY';
BEGIN
   IF p_stg_rec.end_date IS NOT NULL THEN
      -- validate format
      BEGIN
         p_tfm_rec.end_date := to_date(p_stg_rec.end_date, z_date_format);
      EXCEPTION
         WHEN OTHERS THEN
            p_tfm_rec.end_date:=null;         
            append_error(p_errors_tab, 'Contract end Date ''' || p_stg_rec.end_date 
               || ''' is not in the required format ''' || z_date_format || '''');
            --RETURN;
      END;
   --ELSE Commented to fix the Incident ID 45 reported by Emilio
      --append_error(p_errors_tab, 'Contract end date not supplied');
   END IF;
END validate_end_date;


--29/Jun/2017
-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_start_end_date
--  PURPOSE
--      validates start and end date
--  DESCRIPTION
--      1) Start date should not be greater than end date
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_start_end_date
(
   p_stg_rec               IN OUT NOCOPY xxpo_contracts_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_contracts_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   z_date_format              CONSTANT VARCHAR2(11) := 'DD/MM/YYYY';
BEGIN
   debug_msg('in validate_start_end_date');
   IF p_stg_rec.start_date IS NOT NULL and p_stg_rec.end_date IS NOT NULL THEN
      BEGIN
	 
	 debug_msg('in dates are not null');
	 debug_msg(to_date(p_stg_rec.start_date, z_date_format) );
	 debug_msg(to_date(p_stg_rec.end_date, z_date_format) );
	 
         IF to_date(p_stg_rec.start_date, z_date_format) > to_date(p_stg_rec.end_date, z_date_format) THEN
                debug_msg('Contract start date should be less than or equal to end Date ');
         	append_error(p_errors_tab, 'Contract start date should be less than or equal to end Date ');
         END IF;
         debug_msg('No error');
         
      EXCEPTION
         WHEN OTHERS THEN            
            RETURN;
      END;
   END IF;
END validate_start_end_date;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_description
--  PURPOSE
--      Validates end date.
--  DESCRIPTION
--      1) Must have a value
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_description
(
   p_stg_rec               IN OUT NOCOPY xxpo_contracts_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_contracts_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   l_desc_len NUMBER;
BEGIN
   IF p_stg_rec.description IS NULL or LENGTH(p_stg_rec.description)<1 THEN
      append_error(p_errors_tab, 'Contract description not supplied');
   ELSE
       p_tfm_rec.description := p_stg_rec.description;
   END IF;
END validate_description;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_contract_number
--  PURPOSE
--      Validates contract numbers.
--  DESCRIPTION
--      1) Must be provided
--      2) Must not already exist in POC for the provided contract
--      Validation errors are returned in the errors table, p_errors_tab
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_contract_number
(
   p_stg_rec               IN OUT NOCOPY xxpo_contracts_stg%ROWTYPE,
   p_tfm_rec               IN OUT NOCOPY xxpo_contracts_tfm%ROWTYPE,
   p_errors_tab            IN OUT NOCOPY t_validation_errors_type
) IS
   l_po_contracts_rec       xxpo_contracts_all%ROWTYPE;
BEGIN
   -- first check whether the contract number was supplied
   IF p_stg_rec.contract_number IS NULL THEN
      append_error(p_errors_tab, 'Contract number not supplied');
      --RETURN;
   END IF;
   -- check that the contract has already been mapped.
   IF p_tfm_rec.contract_number IS NULL THEN
      append_error(p_errors_tab, 'Contract number not mapped in validation of contract number');
      --RETURN;
   END IF;
   -- query from ap base tables 
   
   BEGIN
      p_tfm_rec.contract_number := TO_CHAR(to_number(p_stg_rec.contract_number));
   EXCEPTION WHEN OTHERS THEN
               p_tfm_rec.contract_number:=null;   
               append_error(p_errors_tab, 'Contract number '|| p_stg_rec.contract_number||' is non-numeric ' );
   END;
   /*
   -- 27/jun/2017 -- if contract number exists, program will update with latest data
   query_contract_number(p_stg_rec.contract_number,l_po_contracts_rec);
   IF l_po_contracts_rec.contract_number IS NOT NULL THEN
      append_error(p_errors_tab, 'Contract number ''' || p_stg_rec.contract_number || ''' already exists in contracts table, created on ' 
            || to_char(l_po_contracts_rec.creation_date, 'DD-MON-YYYY'));
   ELSE
      p_tfm_rec.contract_number := p_stg_rec.contract_number;
   END IF;
   */
END validate_contract_number; 

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      copy_conc_request_file
--  PURPOSE
--      Copies a LOG or OUTPUT concurrent request file to the designated target file and directory
--  DESCRIPTION
--      p_file_type must be 'LOG' or 'OUTPUT'
--      If p_target_filename is not provided the source file name is used
-- --------------------------------------------------------------------------------------------------
PROCEDURE copy_conc_request_file
(
   p_request_id        IN NUMBER,
   p_file_type         IN VARCHAR2,
   p_target_dir        IN VARCHAR2,
   p_target_filename   IN VARCHAR2 DEFAULT NULL
) IS
   l_request_file       fnd_concurrent_requests.outfile_name%TYPE; -- outfile and logfile have the same type
   l_target_file        VARCHAR2(100);
   l_file_copy          NUMBER := 0;
BEGIN
   IF upper(p_file_type) IN ('OUTPUT','LOG') THEN
      -- get the concurrent request file name
      SELECT decode(upper(p_file_type), 'OUTPUT', outfile_name, 'LOG', logfile_name) 
      INTO   l_request_file
      FROM   fnd_concurrent_requests
      WHERE  request_id = p_request_id;
      -- determine the target file name.  defaults to same name if not specified by p_target_filename
      l_target_file := nvl(p_target_filename, SUBSTR(l_request_file, INSTR(l_request_file, '/', -1) + 1));
      -- copy the file
      l_file_copy := xxint_common_pkg.file_copy(
            p_from_path => l_request_file,
            p_to_path => p_target_dir || '/' || l_target_file);
      debug_msg('file copy of ' || l_request_file || ' to ' || p_target_dir 
         || '/' || l_target_file || ' returned ' || l_file_copy);
   ELSE
      debug_msg(g_error || 'Invalid concurrent request file type ''' || p_file_type || '''');
      RETURN;
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      debug_msg(g_error || 'could not find concurrent request '''|| p_file_type || ''' file for request ' || p_request_id);
END copy_conc_request_file;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      wait_for_request
--  PURPOSE
--       Waits for a concurrent request to complete
--       p_interval is time to wait between polls measured in seconds
-- --------------------------------------------------------------------------------------------------
PROCEDURE wait_for_request
(
   p_request_id         IN NUMBER,
   p_interval           IN NUMBER,
   p_srs_request        IN OUT NOCOPY r_srs_request_type
)
IS
   b_wait              BOOLEAN;
BEGIN
   b_wait := fnd_concurrent.wait_for_request
      ( p_request_id,
        p_interval,
        0,
        p_srs_request.srs_phase,
        p_srs_request.srs_status,
        p_srs_request.srs_dev_phase,
        p_srs_request.srs_dev_status,
        p_srs_request.srs_message);
END wait_for_request;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      submit_xxintsqlldr
--  PURPOSE
--       Submits the interface framework program XXINTSQLLDR (DEDJTR Interface Framework SQLLDR)
--       This loads a file into staging tables.
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_xxintsqlldr
(
   p_inbound_directory   IN VARCHAR2,
   p_outbound_directory  IN VARCHAR2,
   p_staging_directory   IN VARCHAR2,
   p_archive_directory   IN VARCHAR2,
   p_file                IN VARCHAR2,
   p_log                 IN VARCHAR2,
   p_bad                 IN VARCHAR2,
   p_ctl                 IN VARCHAR2
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_sqlldr_req_id     NUMBER;
BEGIN
   l_sqlldr_req_id := fnd_request.submit_request
      ( application => 'FNDC',
        program     => 'XXINTSQLLDR',
        description => NULL,
        start_time  => NULL,
        sub_request => FALSE,
        argument1   => p_inbound_directory,
        argument2   => p_outbound_directory,
        argument3   => p_staging_directory,
        argument4   => p_archive_directory,
        argument5   => p_file,
        argument6   => p_log,
        argument7   => p_bad,
        argument8   => p_ctl );
   COMMIT;
   RETURN l_sqlldr_req_id;
END;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      submit_xxintifr_get_file
--  PURPOSE
--       Submits the interface framework program XXINTIFR (DEDJTR Interface Framework Get File)
--       This inserts rows into xxint_interface_ctl.
--  RETURNS
--       Concurrent Request Id of the submitted request
-- --------------------------------------------------------------------------------------------------
FUNCTION submit_xxintifr_get_file
(
   p_int_req_id         IN NUMBER,
   p_in_dir             IN VARCHAR2,
   p_file               IN VARCHAR2,
   p_appl_id            IN NUMBER
) RETURN NUMBER
IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_request_id        NUMBER;
BEGIN
   l_request_id := fnd_request.submit_request
      ( application => 'FNDC',
        program     => 'XXINTIFR',
        description => NULL,
        start_time  => NULL,
        sub_request => FALSE,
        argument1   => p_int_req_id,
        argument2   => p_in_dir,
        argument3   => p_file,
        argument4   => p_appl_id );
   COMMIT;
   RETURN l_request_id;
END;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      get_interface_defn
--  PURPOSE
--       Selects the interface definition of the current interface.  Creates it if it does not exist.
-- --------------------------------------------------------------------------------------------------
PROCEDURE get_interface_defn
(
   p_int_code           IN dot_int_interfaces.int_code%TYPE,
   p_int_name           IN dot_int_interfaces.int_name%TYPE,
   p_request_id         IN NUMBER,
   p_interface_dfn      IN OUT NOCOPY dot_int_interfaces%ROWTYPE
) IS
   PRAGMA AUTONOMOUS_TRANSACTION;
   l_user_id              NUMBER := fnd_profile.value('USER_ID');
BEGIN
   SELECT * 
   INTO   p_interface_dfn
   FROM   dot_int_interfaces
   WHERE  int_code = p_int_code;
   ROLLBACK;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      INSERT INTO dot_int_interfaces VALUES
      (
         dot_int_interfaces_s.NEXTVAL,
         p_int_code,
           p_int_name,
         'IN',
         'PO',
         'Y',
         SYSDATE,
         l_user_id,
         l_user_id,
         SYSDATE,
         l_user_id,
         p_request_id
      );
   COMMIT;
END get_interface_defn;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      update_stage_run_ids
--  PURPOSE
--      Updates the stage tables with values for run_id, run_phase_id, status, created_by and 
--      creation_date where these values are NULL.  They would be NULL if they have only just been 
--      loaded.
-- --------------------------------------------------------------------------------------------------
PROCEDURE update_stage_run_ids
(
   p_run_id              IN   NUMBER,
   p_run_phase_id        IN   NUMBER,
   p_status              IN   VARCHAR2,
   p_row_count           OUT  NUMBER
)
IS
   l_user_id            NUMBER := fnd_profile.value('USER_ID');
BEGIN
   UPDATE xxpo_contracts_stg
   SET    run_id = p_run_id,
          run_phase_id = p_run_phase_id,
          status = p_status,
          created_by = l_user_id,
          org_id = g_org_id
   WHERE  run_id || run_phase_id IS NULL;
   p_row_count := SQL%ROWCOUNT;
END update_stage_run_ids;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      generate_ack_output
--  PURPOSE
--      Formats the interface acknowledgement file in the concurrent output.
-- --------------------------------------------------------------------------------------------------
PROCEDURE generate_ack_output
(
   p_run_id              IN   NUMBER,
   p_source              IN   VARCHAR2,
   p_file_name           IN   VARCHAR2,
   p_file_dir            IN   VARCHAR2
) IS
   z_sep                 CONSTANT VARCHAR2(1) := ','; -- separator
   z_err_sep             CONSTANT VARCHAR2(3) := ' - '; -- error message separator
   z_enc                 CONSTANT VARCHAR2(1) := '"'; -- enclosing character
   l_buffer              VARCHAR2(2000);
   l_error_buffer        VARCHAR2(1000);
   z_file_temp_dir       CONSTANT VARCHAR2(150)  := 'USER_TMP_DIR';
   z_file_temp_name      CONSTANT VARCHAR2(150) := p_file_name || '.tmp';
   lf_file_handle        utl_file.file_type;
   l_file_copy           INTEGER;

   CURSOR c_ack(p_run_id IN NUMBER) IS
      SELECT nvl(tfm.record_id, stg.record_id) as record_id,
             stg.run_id,
             stg.contract_number,
             stg.description,
             stg.start_date,
             stg.end_date,
           --  p_source as source,
             stg.created_by,
             stg.org_id,
             decode(tfm.status
              , 'ERROR', 'Error'
              , 'VALIDATED', 'Validated'
              , 'PROCESSED', 'Success'
              , 'REJECTED', 'Rejected'
              ) as status
      FROM   xxpo_contracts_stg stg, 
             xxpo_contracts_tfm tfm
      WHERE  stg.run_id = p_run_id
      AND    tfm.source_record_id(+) = stg.record_id
      AND    tfm.contract_number(+) = stg.contract_number;

   CURSOR c_error(p_run_id IN NUMBER, p_record_id IN NUMBER) IS
      SELECT error_text
      FROM   dot_int_run_phase_errors
      WHERE  run_id = p_run_id
      AND    record_id = p_record_id;

BEGIN
   lf_file_handle := utl_file.fopen(z_file_temp_dir, z_file_temp_name, 'w');
   FOR r_ack IN c_ack(p_run_id)
   LOOP
      l_buffer :=  
         z_enc || r_ack.contract_number     || z_enc || z_sep ||
         z_enc || r_ack.description         || z_enc || z_sep ||
         z_enc || r_ack.org_id              || z_enc || z_sep ||
         z_enc || r_ack.start_date          || z_enc || z_sep ||
         z_enc || r_ack.end_date            || z_enc || z_sep ||
         z_enc || r_ack.created_by          || z_enc || z_sep ||
         z_enc || r_ack.status              || z_enc ;
      FOR r_error IN c_error(r_ack.run_id, r_ack.record_id)
      LOOP
         IF c_error%ROWCOUNT > 1 THEN
            l_error_buffer := l_error_buffer || z_err_sep || r_error.error_text;
         ELSE
            l_error_buffer := r_error.error_text;
         END IF;
      END LOOP;
      IF l_error_buffer IS NOT NULL THEN
         l_buffer := l_buffer || z_sep || z_enc || l_error_buffer || z_enc;
         l_error_buffer := NULL;
      END IF;
      utl_file.put_line(lf_file_handle, l_buffer);
      fnd_file.put_line(fnd_file.output, l_buffer);
   END LOOP;
   utl_file.fclose(lf_file_handle);
   debug_msg('copying /usr/tmp/' || z_file_temp_name || ' to ' || p_file_dir || '/' || p_file_name);
   l_file_copy := xxint_common_pkg.file_copy(
         p_from_path => '/usr/tmp/' || z_file_temp_name,
         p_to_path => p_file_dir || '/' || p_file_name);
   debug_msg('file copy return code ' || l_file_copy);
   IF nvl(l_file_copy,0) > 0 THEN
      utl_file.fremove(z_file_temp_dir, z_file_temp_name);
   END IF;
END generate_ack_output;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      stage
--  PURPOSE
--       Loads file data into the staging tables.
--  DESCRIPTION
--       Common Interface Framework program XXINTSQLLDR is used to load data into the stage tables
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION stage
(
   p_run_id              IN   NUMBER,
   p_run_phase_id        OUT  NUMBER,
   p_request             IN OUT NOCOPY xxint_common_pkg.CONTROL_RECORD_TYPE,
   p_inbound_directory   IN VARCHAR2,
   p_outbound_directory  IN VARCHAR2,
   p_staging_directory   IN VARCHAR2,
   p_archive_directory   IN VARCHAR2,
   p_file                IN VARCHAR2,
   p_log                 IN VARCHAR2,
   p_bad                 IN VARCHAR2,
   p_ctl                 IN VARCHAR2
)  RETURN BOOLEAN
IS
   l_run_id              NUMBER := p_run_id;
   l_run_phase_id        NUMBER;
   l_sqlldr_req_id       NUMBER;
   l_message             VARCHAR2(240);
   l_stg_rows_loaded     NUMBER := 0;
   r_srs_xxintsqlldr     r_srs_request_type;
   l_error_count         NUMBER:=0; --27/Jun/2017
   r_error                 dot_int_run_phase_errors%ROWTYPE; ----27/Jun/2017
BEGIN
   /**************************/
   /* Initialize run phase   */
   /**************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'STAGE',
        p_phase_mode              => NULL,
        p_int_table_name          => 'xxpo_contracts_stg',  --27/Jun/2017
        p_int_table_key_col1      => NULL,
        p_int_table_key_col_desc1 => NULL,
        p_int_table_key_col2      => NULL,
        p_int_table_key_col_desc2 => NULL,
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL);

   debug_msg('interface framework (run_stage_id=' || l_run_phase_id || ')');
   p_run_phase_id := l_run_phase_id;

   /****************************/
   /* Framework SQL*Loader     */
   /****************************/
   l_sqlldr_req_id := submit_xxintsqlldr
      ( p_inbound_directory,
        p_outbound_directory,
        p_staging_directory,
        p_archive_directory,
        p_file,
        p_log,
        p_bad,
        p_ctl );
   
   debug_msg('load file ' || p_file || ' to staging (request_id=' || l_sqlldr_req_id || ')');

   /******************************/
   /* Interface Control Record   */
   /******************************/
   p_request.file_name := p_file;
   p_request.sub_request_id := l_sqlldr_req_id;
   p_request.sub_request_program_id := NULL;
   xxint_common_pkg.interface_request(p_request);

   /******************************/
   /* End run phase              */
   /******************************/
   dot_common_int_pkg.end_run_phase
             (p_run_phase_id  => l_run_phase_id,
              p_status        => 'SUCCESS',
              p_error_count   => 0,
              p_success_count => l_stg_rows_loaded);

   /******************************/
   /* Wait for request           */
   /******************************/
   wait_for_request(l_sqlldr_req_id, 5, r_srs_xxintsqlldr);

   IF NOT ( r_srs_xxintsqlldr.srs_dev_phase = 'COMPLETE' AND
            r_srs_xxintsqlldr.srs_dev_status IN ('NORMAL','WARNING') ) THEN
      l_message := replace(SUBSTR(g_error_message_03, 11, 100), '$INT_FILE', p_file);
      log_msg(g_error || 'Failed SQL*Loader. Please refer concurrent request id:'||l_sqlldr_req_id);
      log_msg(g_error || l_message);
      log_msg(g_error || '');
      p_request.error_message := l_message;
      p_request.status := 'ERROR';
      l_error_count := 1; --27/Jun/2017
      l_stg_rows_loaded:=0;  --27/Jun/2017
      
         r_error.run_id := p_run_id;
         r_error.run_phase_id := p_run_phase_id;
         r_error.int_table_key_val1 := 'SQL*LOADER';
         r_error.record_id := 1;
         r_error.error_text := l_message;
         raise_error(r_error);
         
         --delete xxpo_contracts_stg; -- 27/Jun/2017
         
         RETURN FALSE;  -- returning from middle. 
                        -- Since the framework is not generating SQL Loader issues. We are displaying the error in the log
   ELSE
      p_request.status := 'SUCCESS';
      -- Update the stage rows with run ids
      update_stage_run_ids(l_run_id, l_run_phase_id, 'PROCESSED', l_stg_rows_loaded);
      debug_msg('updated ' || l_stg_rows_loaded || ' stage runs ids with run_id '||l_run_id);
   END IF;

   /******************************/
   /* Interface Control Record   */
   /******************************/
   xxint_common_pkg.interface_request(p_request);
   debug_msg('file staging (status=' || p_request.status || ')');

   /******************************/
   /* Update run phase           */
   /******************************/
   dot_common_int_pkg.update_run_phase
          (p_run_phase_id => l_run_phase_id,
           p_src_code     => g_src_code,
           p_rec_count    => l_stg_rows_loaded,
           p_hash_total   => NULL,
           p_batch_name   => g_int_batch_name);

   /******************************/
   /* End run phase              */
   /******************************/
   dot_common_int_pkg.end_run_phase
             (p_run_phase_id  => l_run_phase_id,
              p_status        => p_request.status, --27/Jun/2017
              p_error_count   => l_error_count,  --27/Jun/2017  -- in sql loader level error count set to 1
              p_success_count => l_stg_rows_loaded);

   /******************************/
   /* Return status              */
   /******************************/
   IF (p_request.status = 'SUCCESS') THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END stage; 

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      transform
--  PURPOSE
--       Transforms data from Staging tables to the Transform table.
--  DESCRIPTION
--       Updates the Stage row status to PROCESSED or ERROR as it goes
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION transform
(
   p_run_id        IN   NUMBER,
   p_run_phase_id  OUT  NUMBER,
   p_file_name     IN   VARCHAR2,
   p_int_mode      IN   VARCHAR2
) RETURN BOOLEAN
IS
   CURSOR c_stg(p_run_id IN NUMBER) IS
      SELECT *
      FROM   xxpo_contracts_stg
      WHERE  run_id = p_run_id
      FOR UPDATE OF status
      ORDER BY contract_number;

   r_stg                   c_stg%ROWTYPE;
   r_tfm                   xxpo_contracts_tfm%ROWTYPE;
   l_run_id                NUMBER := p_run_id;
   l_run_phase_id          NUMBER;
   l_total                 NUMBER;
   r_error                 dot_int_run_phase_errors%ROWTYPE;
   l_tfm_count             NUMBER := 0;
   l_stg_count             NUMBER := 0;
   b_stg_row_valid        BOOLEAN := TRUE;
   l_val_err_count         NUMBER := 0;
   l_err_count             NUMBER := 0;
   l_header_err_count      NUMBER := 0;
   l_new_record_id         NUMBER;
   l_user_id               NUMBER := fnd_profile.value('USER_ID');
   l_status                VARCHAR2(30);
   l_wip_contract_number       xxpo_contracts_stg.contract_number%TYPE;
   -- validation variables
   l_val_errors_tab        t_validation_errors_type;
BEGIN
    -- to make sure the l_val_errors_tab.count should not throw an error when there are no errors
    l_val_errors_tab := t_validation_errors_type(); 
   /************************************/
   /* Initialize Transform Run Phase   */
   /************************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'TRANSFORM',
        p_phase_mode              => p_int_mode,
        p_int_table_name          => 'xxpo_contracts_tfm',
        p_int_table_key_col1      => 'CONTRACT_NUMBER',
        p_int_table_key_col_desc1 => 'Contract Number',
        p_int_table_key_col2      => NULL,
        p_int_table_key_col_desc2 => NULL,
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL );

   p_run_phase_id := l_run_phase_id;
   r_error.run_id := l_run_id;
   r_error.run_phase_id := l_run_phase_id;

   debug_msg('interface framework (run_transform_id=' || l_run_phase_id || ')');

   SELECT COUNT(1)
   INTO   l_total
   FROM   xxpo_contracts_stg
   WHERE  run_id = l_run_id;

   /******************************/
   /* Update run phase           */
   /******************************/
   dot_common_int_pkg.update_run_phase
      ( p_run_phase_id => l_run_phase_id,
        p_src_code     => g_src_code,
        p_rec_count    => l_total,
        p_hash_total   => NULL,
        p_batch_name   => g_int_batch_name );

   /**********************/
   /* Process STG rows   */
   /**********************/
   OPEN c_stg(l_run_id);
   LOOP
      FETCH c_stg INTO r_stg;
      EXIT WHEN c_stg%NOTFOUND;
      -- initilise and increment 
      l_stg_count := l_stg_count + 1;
      b_stg_row_valid := TRUE;
      r_tfm := NULL;
      r_error.int_table_key_val1 := r_stg.contract_number;
      -- determine if new contract
      IF ( r_stg.contract_number <> nvl(l_wip_contract_number, '-1')) THEN
         -- reset the wip variables
         l_wip_contract_number := r_stg.contract_number;
      END IF;

      /***********************************/
      /* Validation and Mapping          */
      /***********************************/
      r_tfm.contract_number := r_stg.contract_number;
      validate_contract_number(r_stg, r_tfm, l_val_errors_tab);
      validate_start_date(r_stg, r_tfm, l_val_errors_tab);
      validate_end_date(r_stg, r_tfm, l_val_errors_tab);
      validate_start_end_date(r_stg, r_tfm, l_val_errors_tab); --29/Jun/2017
      validate_description(r_stg, r_tfm, l_val_errors_tab);
      -- get the next record_id
      SELECT xxpo_contract_record_id_s.NEXTVAL
      INTO   r_tfm.RECORD_ID
      FROM   dual;
      /*****************************************/
      /* Raise validation errors if they exist */
      /*****************************************/
      r_error.record_id := r_tfm.RECORD_ID;
      IF l_val_errors_tab.COUNT > 0 THEN
         FOR i IN l_val_errors_tab.FIRST..l_val_errors_tab.LAST
         LOOP
            r_error.error_text := l_val_errors_tab(i);
            raise_error(r_error);
            log_msg(g_error || r_error.error_text);
         END LOOP;
         l_val_err_count := l_val_err_count + 1;
         r_tfm.STATUS := 'ERROR';
         l_val_errors_tab.DELETE;
      ELSE
         l_tfm_count := l_tfm_count + 1;
         r_tfm.STATUS := 'VALIDATED';
      END IF;
      
      	BEGIN
	      /***********************************/
	      /* Transform / Mapping             */
	      /***********************************/
	      -- interface framework columns
	      r_tfm.SOURCE_RECORD_ID := r_stg.record_id;
	      r_tfm.RUN_ID := l_run_id;
	      r_tfm.RUN_PHASE_ID := l_run_phase_id;
	      -- who columns
	      r_tfm.CREATED_BY := l_user_id;
	      r_tfm.CREATION_DATE := SYSDATE;
	      r_tfm.LAST_UPDATED_BY := l_user_id;
	      r_tfm.LAST_UPDATE_DATE := SYSDATE;
	      -- header columns
	      r_tfm.contract_number := to_number(l_wip_contract_number);
	      --r_tfm.DESCRIPTION := SUBSTR(r_stg.description, 1, 255);
	      r_tfm.org_id := r_stg.org_id;
	      r_tfm.attribute1 := r_stg.attribute1;
	      r_tfm.attribute2 := r_stg.attribute2;
	      r_tfm.attribute3 := r_stg.attribute3;
	      r_tfm.attribute4 := r_stg.attribute4;
	      r_tfm.attribute5 := r_stg.attribute5;
	      r_tfm.attribute6 := r_stg.attribute6;
	      r_tfm.attribute7 := r_stg.attribute7;
	      r_tfm.attribute8 := r_stg.attribute8;
	      r_tfm.attribute9 := r_stg.attribute9;
	      r_tfm.attribute10 := r_stg.attribute10;
	      r_tfm.attribute11 := r_stg.attribute11;
	      r_tfm.attribute12 := r_stg.attribute12;
	      r_tfm.attribute13 := r_stg.attribute13;
	      r_tfm.attribute14 := r_stg.attribute14;
	      r_tfm.attribute15 := r_stg.attribute15;            
	      --r_tfm.start_date := to_date(r_stg.start_date,'dd/mm/yyyy');      
	      --r_tfm.end_date := to_date(r_stg.end_date,'dd/mm/yyyy');

      	      /*************************************/
      	      /* Insert single row into TFM table  */
      	      /*************************************/
      		 INSERT INTO xxpo_contracts_tfm VALUES r_tfm;
      	      EXCEPTION
      		 WHEN OTHERS THEN
      		    r_error.record_id := r_stg.record_id;
      		    r_error.msg_code := SQLCODE;
      		    r_error.error_text := SQLERRM;
      		    raise_error(r_error);
      		    -- Update the stage table row with error status
      		    UPDATE xxpo_contracts_stg SET status = 'ERROR' WHERE CURRENT OF c_stg;
      		    l_err_count := l_err_count + 1;
	      END;
	      
   END LOOP;

   debug_msg('inserted ' || l_tfm_count || ' transform rows with status validated');
   debug_msg('inserted ' || l_val_err_count || ' transform rows with status error');
   debug_msg('raised ' || l_header_err_count || ' header level validation errors');
   debug_msg('updated ' || l_err_count || ' stage rows with status error');

   IF (l_val_err_count > 0) OR (l_err_count > 0) OR (l_header_err_count > 0)THEN
      l_status := 'ERROR';
   ELSE
      l_status := 'SUCCESS';
   END IF;

   /*******************/
   /* End run phase   */
   /*******************/
   dot_common_int_pkg.end_run_phase
      ( p_run_phase_id  => l_run_phase_id,
        p_status        => l_status,
        p_error_count   => l_val_err_count + l_err_count,
        p_success_count => l_tfm_count);

   IF l_status = 'ERROR' THEN
      RETURN FALSE;
   END IF;
   RETURN TRUE;
END transform;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      load
--  PURPOSE
--       Loads data from the Transform table to the Contract interface table
--  DESCRIPTION
--       Updates the Transform row status to PROCESSED or ERROR as it goes
--  RETURNS
--       True if successful, otherwise False
-- --------------------------------------------------------------------------------------------------
FUNCTION load
(
   p_run_id                IN  NUMBER,
   p_run_phase_id          OUT NUMBER,
   p_submit_validation     IN  VARCHAR2,
   p_apxiimpt_req_id       OUT NUMBER
)  RETURN BOOLEAN
IS
   CURSOR c_tfm IS
      SELECT *
      FROM   xxpo_contracts_tfm
      WHERE  run_id = p_run_id
      AND    status <> 'ERROR' -- Added by Joy Pinto on 13-Jul-2017 Incident #79
      ORDER  BY contract_number
      FOR UPDATE OF status;

   r_tfm                   xxpo_contracts_tfm%ROWTYPE;
   l_run_id                NUMBER := p_run_id;
   l_run_phase_id          NUMBER;
   l_total                 NUMBER := 0;
   l_error_count           NUMBER := 0;
   l_tfm_count             NUMBER := 0;
   l_load_count            NUMBER := 0;
   r_error                 dot_int_run_phase_errors%ROWTYPE;
   l_status                VARCHAR2(240);
   l_apxiimpt_req_id       NUMBER;
   l_apprvl_req_id         NUMBER;
   r_srs_apxiimpt          r_srs_request_type;
   l_load_success_cnt      NUMBER := 0;
   l_batch_id              NUMBER;
   l_wip_contract_number   NUMBER;
BEGIN
   /*******************************/
   /* Initialise Load Phase       */
   /*******************************/
   l_run_phase_id := dot_common_int_pkg.start_run_phase
      ( p_run_id                  => l_run_id,
        p_phase_code              => 'LOAD',
        p_phase_mode              => NULL,
        p_int_table_name          => 'xxpo_contracts_all',
        p_int_table_key_col1      => 'CONTRACT_NUMBER',
        p_int_table_key_col_desc1 => 'Contract Num',
        p_int_table_key_col2      => NULL,
        p_int_table_key_col_desc2 => NULL,
        p_int_table_key_col3      => NULL,
        p_int_table_key_col_desc3 => NULL );

   p_run_phase_id := l_run_phase_id;
   r_error.run_id := l_run_id;
   r_error.run_phase_id := l_run_phase_id;
   debug_msg('interface framework (run_load_id=' || l_run_phase_id || ')');

   SELECT COUNT(1)
   INTO   l_total
   FROM   xxpo_contracts_tfm
   WHERE  run_id = l_run_id;

   /*******************************/
   /* Update Load phase           */
   /*******************************/
   dot_common_int_pkg.update_run_phase
      ( p_run_phase_id => l_run_phase_id,
        p_src_code     => g_src_code,
        p_rec_count    => l_total,
        p_hash_total   => NULL,
        p_batch_name   => g_int_batch_name );

   OPEN c_tfm;
   LOOP
      FETCH c_tfm INTO r_tfm;
      EXIT WHEN c_tfm%NOTFOUND;
      l_tfm_count := l_tfm_count + 1;
      r_error.record_id := r_tfm.record_id;
      r_error.int_table_key_val1 := r_tfm.contract_number;
      BEGIN
         IF r_tfm.contract_number <> nvl(l_wip_contract_number,-1) THEN
            /*********************************/
            /* Insert into xxpo_contracts_all*/
            /*********************************/
            insert_interface(r_tfm);
            l_wip_contract_number := r_tfm.contract_number;
            l_load_count := l_load_count + 1;
         END IF;         
      EXCEPTION
         WHEN OTHERS THEN
            r_error.msg_code := SQLCODE;
            r_error.error_text := SQLERRM;
            raise_error(r_error);
            l_error_count := l_error_count + 1;
            UPDATE xxpo_contracts_tfm 
               SET status = 'ERROR'
             WHERE CURRENT OF c_tfm;
      END;
   END LOOP;

   debug_msg('inserted ' || l_load_count || ' rows into interface');
   debug_msg('updated ' || l_error_count || ' transform rows to error status');

   /**********************************/
   /* Determine status               */
   /**********************************/
      
   IF l_error_count > 0 THEN
      l_status := 'ERROR';
   ELSE
         -- check that the import program actually imported the contracts
         l_load_success_cnt := validate_load(p_run_id, l_run_phase_id);
         IF l_load_success_cnt = l_total THEN
            l_status := 'SUCCESS';
            l_error_count := 0;
         ELSE
            l_status := 'ERROR';
            l_error_count := l_total - l_load_success_cnt;
         END IF;
   END IF;

   /*******************/
   /* End run phase   */
   /*******************/
   dot_common_int_pkg.end_run_phase
      ( p_run_phase_id  => l_run_phase_id,
        p_status        => l_status,
        p_error_count   => l_error_count,
        p_success_count => l_load_success_cnt);

   IF l_status = 'ERROR' THEN
      RETURN FALSE;
   END IF;
   
   RETURN TRUE;
END load;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      process_contracts
--  PURPOSE
--       Concurrent Program XXPOCMSINT (DEDJTR Contract Extract Inbound from CMS)
--  DESCRIPTION
--       Main program controller
-- --------------------------------------------------------------------------------------------------
PROCEDURE process_contracts
(
   p_errbuff            OUT VARCHAR2,
   p_retcode            OUT NUMBER,
   p_source             IN  VARCHAR2,
   p_file_name          IN  VARCHAR2,
   p_batch_name         IN  VARCHAR2,
   p_control_file       IN  VARCHAR2,
   p_submit_validation  IN  VARCHAR2,
   p_debug_flag         IN  VARCHAR2,
   p_int_mode           IN  VARCHAR2
) IS
   z_procedure_name           CONSTANT VARCHAR2(150) := 'xxpo_cms_int_pkg.process_contracts';
   z_app                      CONSTANT VARCHAR2(2) :=  'PO';
   l_user_name                VARCHAR2(60);
   l_req_id                   NUMBER;
   l_appl_id                  NUMBER;
   l_file                     VARCHAR2(150);
   l_log                      VARCHAR2(150);
   l_bad                      VARCHAR2(150);
   l_ctl                      VARCHAR2(150);
   l_inbound_directory        fnd_flex_values_tl.description%TYPE;
   l_outbound_directory       fnd_flex_values_tl.description%TYPE;
   l_staging_directory        fnd_flex_values_tl.description%TYPE;
   l_archive_directory        fnd_flex_values_tl.description%TYPE;
   x_message                  VARCHAR2(1000);
   l_tfm_mode                 VARCHAR2(60);
   lr_interface_dfn           dot_int_interfaces%ROWTYPE;
   l_getfile_req_id           NUMBER;
   l_apxiimpt_req_id          NUMBER;
   r_srs_xxintifr             r_srs_request_type;
   l_run_error                NUMBER := 0;
   r_request                  xxint_common_pkg.CONTROL_RECORD_TYPE;
   l_message                  VARCHAR2(240);
   t_files_tab                t_varchar_tab_type;
   l_run_id                   NUMBER;
   l_run_phase_id             NUMBER;
   l_rep_req_id               NUMBER;
   l_err_req_id               NUMBER;
   l_ack_file_name            VARCHAR2(100);
   e_interface_error          EXCEPTION;
   e_stag_error               EXCEPTION;
BEGIN
   /******************************************/
   /* Pre-process validation                 */
   /******************************************/
   l_req_id := fnd_global.conc_request_id;
   l_appl_id := fnd_global.resp_appl_id;
   l_user_name := fnd_profile.value('USERNAME');
   g_org_id := fnd_profile.value('ORG_ID');
   g_debug_flag := nvl(p_debug_flag, 'N');
   g_source := SUBSTR(p_source, 1, 80);
   l_ctl := nvl(p_control_file, g_ctl);
   l_file := nvl(p_file_name, g_file);
   l_tfm_mode := nvl(p_int_mode, g_int_mode);
   xxint_common_pkg.g_object_type :='CONTRACTS'; -- 19/JUN/2017 -- RAO as per new changes to repoint directories to NFS 

   debug_msg('procedure name ' || z_procedure_name || '.');

   /****************************/
   /* Get Interface ID         */
   /****************************/
   debug_msg('check interface registry for ' || g_int_code || '.');
   get_interface_defn(g_int_code, g_int_name, l_req_id, lr_interface_dfn);
   IF nvl(lr_interface_dfn.enabled_flag, 'Y') = 'N' THEN
      log_msg(g_error || replace(SUBSTR(g_error_message_01, 11, 100), '$INT_CODE', g_int_code));
      p_retcode := 2;
      RETURN;
   END IF;

   /****************************/
   /* Get Directory Info       */
   /****************************/
   debug_msg('retrieving interface directory information');

   l_inbound_directory := xxint_common_pkg.interface_path
      ( p_application => z_app,
        p_source  => p_source,
        p_in_out  => 'INBOUND',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_outbound_directory := xxint_common_pkg.interface_path
      ( p_application => z_app,
        p_source  => p_source,
        p_in_out  => 'OUTBOUND',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_staging_directory := xxint_common_pkg.interface_path
      ( p_application => z_app,
        p_source  => p_source,
        p_in_out  => 'WORKING',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_archive_directory := xxint_common_pkg.interface_path
      ( p_application => z_app,
        p_source  => p_source,
        p_archive => 'Y',
        p_message => x_message );
   IF x_message IS NOT NULL THEN
      log_msg(g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   debug_msg('p_source=' || p_source);
   debug_msg('l_file=' || l_file);
   debug_msg('l_ctl=' || l_ctl);
   debug_msg('l_inbound_directory=' || l_inbound_directory);
   debug_msg('l_outbound_directory=' || l_outbound_directory);
   debug_msg('l_staging_directory=' || l_staging_directory);
   debug_msg('l_archive_directory=' || l_archive_directory);

   /****************************/
   /* Submit Get File          */
   /****************************/
   l_getfile_req_id := submit_xxintifr_get_file(l_req_id, l_inbound_directory, l_file, l_appl_id);
   debug_msg('fetching file ' || l_file || ' from ' || l_inbound_directory || ' (request_id=' || l_getfile_req_id || ')');

   /****************************/
   /* Wait for request         */
   /****************************/
   wait_for_request(l_getfile_req_id, 5, r_srs_xxintifr);
   IF NOT ( r_srs_xxintifr.srs_dev_phase = 'COMPLETE' AND
            r_srs_xxintifr.srs_dev_status IN ('NORMAL','WARNING') ) THEN
      l_run_error := l_run_error + 1;
      l_message := replace(SUBSTR(g_error_message_02, 11, 100), '$INT_DIR', l_inbound_directory);
      log_msg(g_error || l_message);
      r_request.error_message := l_message;
      r_request.status := 'ERROR';
   ELSE
      r_request.status := 'SUCCESS';
   END IF;

   /*****************************/
   /* Interface Control Record  */
   /*****************************/
   r_request.application_id := l_appl_id;
   r_request.interface_request_id := l_req_id;
   r_request.sub_request_id := l_getfile_req_id;
   xxint_common_pkg.interface_request(r_request);

   /*****************************/
   /* Get list of file names    */
   /*****************************/
   get_interface_files(l_req_id, l_getfile_req_id, t_files_tab);

   IF l_run_error > 0 OR t_files_tab.COUNT = 0 THEN
      RAISE e_interface_error;
   END IF;

   /*****************************/
   /* Process each file         */
   /*****************************/
   FOR i IN 1..t_files_tab.LAST
   LOOP
      l_file := replace(t_files_tab(i), l_inbound_directory || '/');
      l_log  := replace(l_file, 'txt', 'log');
      l_bad  := replace(l_file, 'txt', 'bad');
      g_int_batch_name := nvl(p_batch_name, l_file);
      
      /******************************************/
      /* Interface Run ID                       */
      /******************************************/
      l_run_id := dot_common_int_pkg.initialise_run
         ( p_int_code       => g_int_code,
           p_src_rec_count  => NULL,
           p_src_hash_total => NULL,
           p_src_batch_name => g_int_batch_name);

      debug_msg('interface framework (run_id=' || l_run_id || ')');

      /******************************************/
      /* Staging                                */
      /******************************************/
      IF NOT stage (
            l_run_id,
            l_run_phase_id,
            r_request,
            l_inbound_directory,
            l_outbound_directory,
            l_staging_directory,
            l_archive_directory,
            l_file,
            l_log,
            l_bad,
            l_ctl )
      THEN
         --RAISE e_interface_error;
         RAISE e_stag_error;
      END IF;

      /******************************************/
      /* Transformation                         */
      /******************************************/
      IF NOT transform(l_run_id, l_run_phase_id, l_file, l_tfm_mode) THEN
         --RAISE e_interface_error; Commented by Joy Pinto on 12-Jul-2017 Incident ID 79
         p_retcode := 1;
         l_err_req_id := dot_common_int_pkg.launch_error_report
            ( p_run_id       => l_run_id,
              p_run_phase_id => l_run_phase_id ); 
      END IF;

      /******************************************/
      /* Load                                   */
      /******************************************/
      debug_msg('interface framework (int_mode=' || l_tfm_mode || ')');
      IF l_tfm_mode = g_int_mode THEN
         IF NOT load(l_run_id, l_run_phase_id, p_submit_validation, l_apxiimpt_req_id) THEN
            --RAISE e_interface_error; Commented by Joy Pinto on 12-Jul-2017 Incident ID 79
            p_retcode := 1;
            l_err_req_id := dot_common_int_pkg.launch_error_report
               ( p_run_id       => l_run_id,
                 p_run_phase_id => l_run_phase_id ); 
         END IF;
      END IF;

      /*********************************/
      /* Interface report              */
      /*********************************/
      l_rep_req_id := dot_common_int_pkg.launch_run_report
         ( p_run_id      => l_run_id,
           p_notify_user => l_user_name);

      debug_msg('interface framework completion report (request_id=' || l_rep_req_id || ')');
      
      /*********************************/
      /* Acknowledgement file          */
      /*********************************/
      l_ack_file_name := g_source || '_' || to_char(SYSDATE, 'YYYYMMDDHH24MISS') || '_' || l_req_id || '.txt';
      generate_ack_output(l_run_id, g_source, l_ack_file_name, l_outbound_directory);

   END LOOP;
   
   -- Delete the data from stg and tfm tables
   delete_stg_tfm; --27/Jun

EXCEPTION
   WHEN e_stag_error THEN
   -- Since the report does not have staging details
   -- This error information is displayed in the log
   delete_stg_tfm; --27/Jun
   log_msg(g_error || 'Program failed at Staging level');
   p_retcode := 2;
   WHEN e_interface_error THEN
      /*********************************/
      /* Interface report              */
      /*********************************/
      l_err_req_id := dot_common_int_pkg.launch_error_report
         ( p_run_id       => l_run_id,
           p_run_phase_id => l_run_phase_id );

      l_rep_req_id := dot_common_int_pkg.launch_run_report
         ( p_run_id      => l_run_id,
           p_notify_user => l_user_name);
      /*********************************/
      /* Acknowledgement file          */
      /*********************************/
      l_ack_file_name := g_source || '_' || to_char(SYSDATE, 'YYYYMMDDHH24MISS') || '_' || l_req_id || '.csv';
      generate_ack_output(l_run_id, g_source, l_ack_file_name, l_outbound_directory);
      delete_stg_tfm; --27/Jun
      p_retcode := 2;
   WHEN OTHERS THEN
      debug_msg('OTHER ERROR: '||SQLERRM);
      delete_stg_tfm; --27/Jun
END process_contracts;

END xxpo_cms_int_pkg;
/