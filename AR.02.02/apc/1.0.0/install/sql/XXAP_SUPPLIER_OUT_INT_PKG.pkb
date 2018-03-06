create or replace PACKAGE BODY xxap_supplier_out_int_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.02/apc/1.0.0/install/sql/XXAP_SUPPLIER_OUT_INT_PKG.pkb 3066 2017-11-28 06:24:56Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: AP.02.02
**
** Description: Interface program for Vendor Outbound Interface 
**
** Change History:
**
** Date        Who                  Comments
** 02/05/2017  SRYAN (RED ROCK)     Initial build.
**
*******************************************************************/
g_debug_flag               VARCHAR2(1) := 'N';
g_request_id               NUMBER := -1;
e_invalid_source           EXCEPTION;
e_invalid_selection_code   EXCEPTION;
e_missing_selection_date   EXCEPTION;
-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      debug_msg
--  PURPOSE
--       Writes a line to the concurrent log file if the debug flag is on.
-- --------------------------------------------------------------------------------------------------
PROCEDURE debug_msg
(
   p_message               IN VARCHAR2
) IS
BEGIN
   IF nvl(g_debug_flag, 'N') = 'Y' THEN
      IF g_request_id > 0 THEN
         fnd_file.put_line(fnd_file.log, g_debug || SUBSTR(p_message, 1, 1990));
      ELSE
         dbms_output.put_line(g_debug || SUBSTR(p_message, 1, 1990));
      END IF;
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
   p_message               IN VARCHAR2
) IS
BEGIN
   IF g_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, SUBSTR(p_message, 1, 2000));
   ELSE
      dbms_output.put_line(SUBSTR(p_message, 1, 2000));
   END IF;
END log_msg;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_previous_business_date
--  PURPOSE
--      Gets the last business day relative to the current date.
--  DESCRIPTION
--      Just checks that the day is a week day.  Does not take into account public holidays
-- --------------------------------------------------------------------------------------------------
FUNCTION get_previous_business_date RETURN DATE
IS
   l_date                  DATE := NULL;
   l_offset                PLS_INTEGER := 1;
BEGIN
   WHILE l_date IS NULL
   LOOP
      IF TRIM(TO_CHAR(SYSDATE - l_offset, 'DAY')) IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY') THEN
         l_date := TRUNC(SYSDATE - l_offset);
         EXIT;
      ELSE
         l_offset := l_offset + 1;
      END IF;
   END LOOP;
   RETURN l_date;
END get_previous_business_date;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      get_conc_prog_last_run_date
--  PURPOSE
--      Gets the last run date of a concurrent program.
-- --------------------------------------------------------------------------------------------------
FUNCTION get_conc_prog_last_run_date 
(
   p_conc_program          IN VARCHAR2,
   p_appl_short_name       IN VARCHAR2
) RETURN DATE
IS
   l_last_run_date         DATE;
BEGIN
   SELECT MAX(fcr.actual_completion_date)
   INTO   l_last_run_date
   FROM   fnd_concurrent_requests fcr,
          fnd_concurrent_programs fcp,
          fnd_application a
   WHERE  fcr.concurrent_program_id = fcp.concurrent_program_id
   AND    fcp.concurrent_program_name = p_conc_program
   AND    fcp.application_id = a.application_id
   AND    a.application_short_name = p_appl_short_name
   AND    fcr.status_code = 'C'
   AND    fcr.actual_completion_date IS NOT NULL;
   RETURN l_last_run_date;
END get_conc_prog_last_run_date;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_source
--  PURPOSE
--      Validate invoice source.
--       1) Must be in SOURCE lookups
-- --------------------------------------------------------------------------------------------------
PROCEDURE validate_source
(
   p_source                IN  VARCHAR2
) IS
   l_source                fnd_lookup_values.lookup_code%TYPE;
BEGIN
   SELECT lookup_code
   INTO   l_source
   FROM   fnd_lookup_values
   WHERE  lookup_type = 'SOURCE'
   AND    lookup_code = p_source
   AND    SYSDATE BETWEEN nvl(start_date_active, SYSDATE - 1) AND nvl(end_date_active, SYSDATE + 1)
   AND    enabled_flag = 'Y';
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RAISE e_invalid_source;
END validate_source;

-- --------------------------------------------------------------------------------------------------
--  FUNCTION
--      derive_selection_date
--  PURPOSE
--      Determines the selection date of the exract based on selection code and since date parameters.
-- --------------------------------------------------------------------------------------------------
FUNCTION derive_selection_date
(
   p_selection_code        IN  VARCHAR2,
   p_since_date            IN  VARCHAR2
) RETURN DATE
IS
   l_selection_date        DATE;
BEGIN
   debug_msg('p_selection_code='||p_selection_code||'; p_since_date='||p_since_date);
   IF p_selection_code = 'L' THEN
      l_selection_date := get_conc_prog_last_run_date('XXAP_VENDOR_OUT_INT', 'SQLAPC');
   ELSIF p_selection_code = 'B' THEN
      l_selection_date := get_previous_business_date();
   ELSIF p_selection_code = 'D' THEN
      IF p_since_date IS NOT NULL THEN
         l_selection_date := TRUNC(TO_DATE(p_since_date, 'YYYY/MM/DD HH24:MI:SS'));
      ELSE
         RAISE e_missing_selection_date;
      END IF;
   ELSIF p_selection_code = 'H' THEN
      l_selection_date := TO_DATE('01-JAN-1900', 'DD-MON-YYYY');
   ELSE
      RAISE e_invalid_selection_code;
   END IF;
   RETURN NVL(l_selection_date, TO_DATE('01-JAN-1900', 'DD-MON-YYYY'));
END derive_selection_date;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      extract
--  PURPOSE
--      Performs the selection and output of vendors according to the selected range
-- --------------------------------------------------------------------------------------------------
PROCEDURE extract
(
   p_selection_date        IN  DATE,
   p_out_dir               IN  VARCHAR2,
   p_file_name             IN  VARCHAR2,
   p_source                IN  VARCHAR2 -- FSC-5915 Payment Method shows data from Vendor instead of Site (GEMS)                
) IS
   CURSOR c_vend(p_date IN DATE) IS
      
      SELECT pov.segment1 as vendor_number,
             pov.vendor_name,
             pos.vendor_site_code,
             pos.vendor_site_id,
             pos.vat_registration_num,
             pos.attribute13 as rcti_flag,
             DECODE(p_source,'GEMS',
                             pos.payment_method_lookup_code, 
                             pov.payment_method_lookup_code) as payment_method, -- FSC-5915 Payment Method shows data from Vendor instead of Site (GEMS) 
             terms.name payment_terms,
             pos.address_line1 || ',' || pos.address_line2|| ',' || pos.address_line3 
                  || ',' || pos.city || ',' || pos.state || ',' || pos.zip as address,
             pov.vendor_type_lookup_code,
             pos.attribute3 as remittance_email,
             greatest(pos.last_update_date, pov.last_update_date) as last_updated_date,
             nvl2(pos.inactive_date, (case when pos.inactive_date < sysdate then 'Inactive' else 'Active' end), 'Active') as status,
             -- FSC-5974 Supplier outbound file for GEMS : Added Site's Bank Account and BSB by Daniel Kwon 17-11-2017
             (bank.bank_number||bank.bank_num) as bsb,
             bank.bank_account_num as bank_account
      FROM   po_vendors pov,
             po_vendor_sites pos,
             ap_terms terms, -- FSC-3379 Joy Pinto 17-08-2017
             (SELECT bu.vendor_site_id,
                     br.bank_number,
                     br.bank_num,
                     ba.bank_account_num
             FROM  ap_bank_account_uses_all bu,
                   ap_bank_accounts_all ba,
                   ap_bank_branches br
             WHERE  bu.external_bank_account_id = ba.bank_account_id
             and ba.bank_branch_id = br.bank_branch_id) bank -- FSC-5974 17-11-2017
      WHERE  pos.vendor_id = pov.vendor_id
      AND    ( pov.last_update_date >= p_selection_date OR 
               pos.last_update_date >= p_selection_date )
      AND    terms.term_id = pos.terms_id(+)
      AND    pos.vendor_site_id = bank.vendor_site_id (+); -- FSC-5974 17-11-2017

      /*SELECT pov.segment1 as vendor_number,
             pov.vendor_name,
             pos.vendor_site_code,
             pos.vendor_site_id,
             pos.vat_registration_num,
             pos.attribute13 as rcti_flag,
             pov.payment_method_lookup_code as payment_method,
             terms.name payment_terms,
             pos.address_line1 || ',' || pos.address_line2|| ',' || pos.address_line3 
                  || ',' || pos.city || ',' || pos.state || ',' || pos.zip as address,
             pov.vendor_type_lookup_code,
             pos.attribute3 as remittance_email,
             greatest(pos.last_update_date, pov.last_update_date) as last_updated_date,
             nvl2(pos.inactive_date, (case when pos.inactive_date < sysdate then 'Inactive' else 'Active' end), 'Active') as status,
             -- FSC-5974 Supplier outbound file for GEMS : Added Site's Bank Account and BSB by Daniel Kwon 17-11-2017
             (pos.bank_number||pos.bank_num) as bsb,
             pos.bank_account_num as bank_account
      FROM   po_vendors pov,
             po_vendor_sites pos,
             ap_terms terms -- FSC-3379 Joy Pinto 17-08-2017
      WHERE  pos.vendor_id = pov.vendor_id
      AND    ( pov.last_update_date >= p_selection_date OR 
               pos.last_update_date >= p_selection_date )
      AND    terms.term_id = pos.terms_id(+);*/

   l_buffer                VARCHAR2(1000);
   l_headers               VARCHAR2(500);
   z_delim                 CONSTANT VARCHAR2(1) := ',';
   z_encl                  CONSTANT VARCHAR2(1) := '"';
   z_date_fmt              CONSTANT VARCHAR2(11) := 'DD-MON-YYYY';
   z_file_temp_dir         CONSTANT VARCHAR2(150)  := 'USER_TMP_DIR';
   z_file_temp_name        CONSTANT VARCHAR2(150) := p_file_name || '.tmp';
   l_fhandle               utl_file.file_type;
   l_file_copy             INTEGER;
   -- helper function to enclose with enclosing character
   FUNCTION enclose(p_str IN VARCHAR2) RETURN VARCHAR2
   IS
   BEGIN
      RETURN z_encl || p_str || z_encl;
   END;
BEGIN
   l_fhandle := utl_file.fopen(z_file_temp_dir, z_file_temp_name, 'w');

   l_headers := enclose('Vendor Number') || z_delim 
      || enclose('Vendor Name') || z_delim 
      || enclose('Site') || z_delim 
      || enclose('Site Id') || z_delim 
      || enclose('ABN') || z_delim 
      || enclose('RCTI Flag') || z_delim 
      || enclose('Payment Method') || z_delim 
      || enclose('Payment Terms') || z_delim 
      || enclose('Address') || z_delim 
      || enclose('Entity Type') || z_delim
      || enclose('Email') || z_delim
      || enclose('Last Update Date') || z_delim
      || enclose('Status')|| z_delim
      /* FSC-5974 Supplier outbound file for GEMS : Added Site's Bank Account and BSB by Daniel Kwon 17-11-2017*/
      || enclose('BSB')|| z_delim
      || enclose('Bank Account');
   fnd_file.put_line(fnd_file.output, l_headers);
   utl_file.put_line(l_fhandle, l_headers);

   FOR r_vend IN c_vend(p_selection_date)
   LOOP
      l_buffer := 
         enclose(r_vend.vendor_number)          || z_delim || 
         enclose(r_vend.vendor_name)            || z_delim || 
         enclose(r_vend.vendor_site_code)       || z_delim || 
         r_vend.vendor_site_id                  || z_delim || 
         enclose(r_vend.vat_registration_num)   || z_delim || 
         enclose(r_vend.rcti_flag)              || z_delim || 
         enclose(r_vend.payment_method)         || z_delim || 
         enclose(r_vend.payment_terms)         || z_delim ||
         enclose(r_vend.address)                || z_delim || 
         enclose(r_vend.vendor_type_lookup_code)|| z_delim || 
         enclose(r_vend.remittance_email)       || z_delim || 
         enclose(TO_CHAR(r_vend.last_updated_date, z_date_fmt)) || z_delim || 
         enclose(r_vend.status) || z_delim || 
          /* FSC-5974 Supplier outbound file for GEMS : Added Site's Bank Account and BSB by Daniel Kwon 17-11-2017*/
         enclose(r_vend.bsb) || z_delim || 
         enclose(r_vend.bank_account)  
         ; 
      fnd_file.put_line(fnd_file.output, l_buffer);
      utl_file.put_line(l_fhandle, l_buffer);
   END LOOP;
   utl_file.fclose(l_fhandle);

   debug_msg('Copying temporary file ' || '/usr/tmp/' || z_file_temp_name || ' to ' || p_out_dir || '/' || p_file_name);
   l_file_copy := xxint_common_pkg.file_copy(
         p_from_path => '/usr/tmp/' || z_file_temp_name,
         p_to_path => p_out_dir || '/' || p_file_name);
   debug_msg('File copy returned ' || l_file_copy);

   IF nvl(l_file_copy,0) > 0 THEN
      utl_file.fremove(z_file_temp_dir, z_file_temp_name);
   END IF;
EXCEPTION
   WHEN OTHERS THEN  
      IF utl_file.is_open(l_fhandle) THEN
         utl_file.fclose(l_fhandle);
      END IF;
      log_msg('Error in extract() procedure: ' || SQLERRM);
      RAISE;
END extract;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      extract_suppliers
--  PURPOSE
--       Concurrent Program XXAP_VENDOR_OUT_INT (DEDJTR Vendor Outbound Interface)
--  DESCRIPTION
--       Main program controller
-- --------------------------------------------------------------------------------------------------
PROCEDURE extract_suppliers
(
   p_errbuff               OUT VARCHAR2,
   p_retcode               OUT NUMBER,
   p_source                IN  VARCHAR2,
   p_file_name             IN  VARCHAR2 DEFAULT NULL,
   p_selection_code        IN  VARCHAR2,
   p_since_date            IN  VARCHAR2 DEFAULT NULL,
   p_debug_flag            IN  VARCHAR2
) IS
   l_selection_date        DATE;
   l_outbound_dir          VARCHAR2(100);
   l_file_name             VARCHAR2(100);
   l_message               VARCHAR2(500);
BEGIN
   -- Initialise
   xxint_common_pkg.g_object_type := 'SUPPLIERS';
   g_request_id := fnd_global.conc_request_id;
   g_debug_flag := p_debug_flag;
   
   debug_msg('p_source = '||p_source);
   debug_msg('p_file_name = '||p_file_name);
   debug_msg('p_selection_code = '||p_selection_code);
   debug_msg('p_since_date = '||p_since_date);
   debug_msg('p_debug_flag = '||p_debug_flag);

   -- validate parameters
   validate_source(p_source);
   l_selection_date := derive_selection_date(p_selection_code, p_since_date);
   debug_msg('Selection date: '|| TO_CHAR(l_selection_date,'DD-MON-YYYY HH24:MI:SS'));
   l_file_name := nvl(p_file_name, p_source || '_SUPPLIER_' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MI') || '.csv');
   debug_msg('File name: '|| l_file_name);

   -- get outbound directory
   l_outbound_dir := xxint_common_pkg.interface_path
      ( p_application => 'AP',
        p_source  => p_source,
        p_in_out  => 'OUTBOUND',
        p_message => l_message );
   IF l_message IS NOT NULL THEN
      log_msg(g_error || l_message);
      p_retcode := 2;
      RETURN;
   END IF;
   debug_msg('Outbound directory: ' || l_outbound_dir);

   -- call extract routine
   --extract(l_selection_date, l_outbound_dir, l_file_name);
   extract(l_selection_date, l_outbound_dir, l_file_name, p_source); -- FSC-5915 Payment Method shows data from Vendor instead of Site (GEMS) 
   p_retcode := 0;
EXCEPTION
   WHEN e_invalid_source THEN
      log_msg(g_error || 'Invalid source ''' || p_source || '''');
      p_retcode := 2;
   WHEN e_invalid_selection_code THEN
      log_msg(g_error || 'Invalid selection code ''' || p_selection_code || '''');
      p_retcode := 2;
   WHEN e_missing_selection_date THEN
      log_msg(g_error || 'Invalid selection date. p_since_date must be provided if selection code is ''D''');
      p_retcode := 2;
END extract_suppliers; 

END xxap_supplier_out_int_pkg;
/
