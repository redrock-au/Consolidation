create or replace PACKAGE BODY xxar_customer_conversion_pkg AS
/*$Header: svn://d02584/consolrepos/branches/AR.02.02/arc/1.0.0/install/sql/XXAR_CUSTOMER_CONVERSION_PKG.pkb 2801 2017-10-13 04:12:47Z svnuser $*/
/****************************************************************************
**
** CEMLI ID: AR.00.01
**
** Description: This Program is to run Customer Data Conversion
**
**
** Change History:
**
** Date        Who                  Comments
** 01/05/2017  KWONDA (RED ROCK)   Initial build.
**
****************************************************************************/


---------------------------

FUNCTION file_length_check (p_source_name VARCHAR2,
                            p_file VARCHAR2)
RETURN BOOLEAN IS
    v_file_length NUMBER := 0;
BEGIN

   SELECT LENGTH(p_file)-length(p_source_name)
   INTO v_file_length
   FROM DUAL;

   IF v_file_length != 28 THEN
      RETURN FALSE;
   ELSE
       RETURN TRUE;
   END IF;
END file_length_check;


FUNCTION get_customer_name
(
   p_customer_name  VARCHAR2,
   p_org_id NUMBER
)
RETURN NUMBER
IS
   o_existing   number;

   CURSOR c_cust IS
      /*SELECT count(*)
      FROM ra_customers
      WHERE customer_name = p_customer_name;*/
      SELECT count(*)
      FROM ra_customers rc,
           hz_parties hp,
           hz_cust_accounts  hca,
           hz_cust_acct_sites_all hcs
      WHERE rc.customer_name = p_customer_name
      AND hcs.org_id = p_org_id
      AND rc.party_id = hp.party_id
      AND hp.party_id = hca.party_id
      AND hca.cust_account_id = hcs.cust_account_id;
BEGIN
   OPEN c_cust;
   FETCH c_cust INTO o_existing;
   CLOSE c_cust;

   RETURN o_existing;
END get_customer_name;


FUNCTION get_orig_system_reference
(
p_orig_system_reference VARCHAR2
)
RETURN BOOLEAN
IS
   v_exiting   number;
BEGIN
    SELECT COUNT(*)
    INTO v_exiting
    FROM ra_customers
    WHERE orig_system_reference = p_orig_system_reference;
    IF  v_exiting = 1 THEN
       RETURN TRUE;
    ELSE
       RETURN FALSE;
    END IF;
END;


FUNCTION get_customer_site
(
   p_party_site_number  VARCHAR2
)
RETURN NUMBER
IS
   v_exiting   number;

   CURSOR c_cust_site IS
      SELECT count(*)
      FROM hz_party_sites
      WHERE party_site_number = p_party_site_number;
BEGIN
   OPEN c_cust_site;
   FETCH c_cust_site INTO v_exiting;
   CLOSE c_cust_site;

   RETURN v_exiting;
END get_customer_site;

FUNCTION get_cust_level_profile_class
(
   p_customer_number  VARCHAR2
)
RETURN NUMBER
IS
   x_cust_profile_class_id NUMBER;
   CURSOR c_cust_profile_class_id IS
      SELECT CUSTOMER_PROFILE_CLASS_ID
      FROM AR_CUSTOMERS_V A
      WHERE CUSTOMER_NUMBER =p_customer_number;
BEGIN
   OPEN c_cust_profile_class_id;
   FETCH c_cust_profile_class_id INTO x_cust_profile_class_id;
   CLOSE c_cust_profile_class_id;

   RETURN x_cust_profile_class_id;
END get_cust_level_profile_class;


FUNCTION check_cust_site_relation
(
   p_customer_number VARCHAR2,
   p_site_number  VARCHAR2
)
RETURN NUMBER
IS
   x_cust_site_rel NUMBER;
   CURSOR c_cust_site_rel IS
      SELECT COUNT(*)
      FROM  RA_CUSTOMERS RC,
            HZ_PARTIES HP,
            HZ_PARTY_SITES HPS
      WHERE PARTY_SITE_NUMBER = p_site_number
      AND CUSTOMER_NUMBER = p_customer_number
      AND RC.PARTY_ID = HPS.PARTY_ID
      AND RC.PARTY_ID = HP.PARTY_ID;
BEGIN
   OPEN c_cust_site_rel;
   FETCH c_cust_site_rel INTO x_cust_site_rel;
   CLOSE c_cust_site_rel;

   RETURN x_cust_site_rel;
END check_cust_site_relation;

FUNCTION check_customer_class
(
 p_customer_class_code VARCHAR2
)
RETURN BOOLEAN
IS
   v_customer_class_count NUMBER := 0;
BEGIN
   SELECT count(*)
   INTO v_customer_class_count
   FROM FND_LOOKUP_VALUES
   WHERE LOOKUP_TYPE = 'CUSTOMER CLASS'
   AND LOOKUP_CODE = p_customer_class_code;

   IF v_customer_class_count !=1 THEN
      RETURN FALSE;
   ELSE
      RETURN TRUE;
   END IF;
END;


FUNCTION check_customer_profile_class
(
 p_industry_type VARCHAR2
)
RETURN BOOLEAN
IS
   v_profile_class_count NUMBER := 0;
BEGIN
   SELECT count(*)
   INTO v_profile_class_count
   FROM AR_CUSTOMER_PROFILE_CLASSES
   WHERE name = p_industry_type;

   IF v_profile_class_count !=1 THEN
      RETURN FALSE;
   ELSE
      RETURN TRUE;
   END IF;
END;

FUNCTION check_special_char
--(v_column VARCHAR2)
RETURN BOOLEAN
IS
   v_count NUMBER;
BEGIN
   SELECT COUNT(*)
   INTO v_count
   FROM xxar_customer_conversion_stg
   WHERE REGEXP_LIKE(RECORD_ACTION, '[^]^A-Z^a-z^0-9^[^.^{^}^ ]' ,'x');

   IF v_count >0 THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;

FUNCTION check_country_code
(p_country VARCHAR2)
RETURN BOOLEAN
IS
  v_count NUMBER;
BEGIN
   SELECT count(*)
   INTO v_count
   FROM FND_TERRITORIES_TL
   WHERE TERRITORY_CODE = p_country;
   IF v_count >0 THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END;

FUNCTION return_customer_number (p_orig_system_customer_ref VARCHAR2/*,
                                 p_customer_name VARCHAR2*/)
RETURN VARCHAR2
IS
   v_customer_number ra_customers.customer_number%TYPE;
BEGIN
   SELECT customer_number
   INTO v_customer_number
   FROM RA_CUSTOMERS
   WHERE orig_system_reference = p_orig_system_customer_ref;
   --AND customer_name = p_customer_name;
   RETURN v_customer_number;
EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'FUNCTION return_customer_number | Error While Retrieving Customer Number '|| SQLERRM);
      fnd_file.put_line(fnd_file.log,'p_orig_system_customer_ref :'|| p_orig_system_customer_ref);
      return null;
      --fnd_file.put_line(fnd_file.log,'p_customer_name :'|| p_customer_name);
END;

FUNCTION return_customer_site_number (p_orig_system_address_ref VARCHAR2)
RETURN VARCHAR2
IS
   v_customer_site_number hz_party_sites.party_site_number%TYPE;
BEGIN
   SELECT party_site_number
   INTO v_customer_site_number
   FROM hz_party_sites
   WHERE orig_system_reference = p_orig_system_address_ref;
   RETURN v_customer_site_number;
EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'Error While Retrieving Customer Site Number for orig system ref :'||p_orig_system_address_ref||'Error is  :'|| SQLERRM);
      return null;
END;

PROCEDURE update_customer_numbers_temp (p_run_id NUMBER)
IS
   CURSOR main_c IS
      SELECT record_action,
             orig_system_customer_ref,
             customer_name
      FROM xxar_customer_conversion_tfm
      WHERE dtpli_customer_num is null
      AND run_id = p_run_id;

   main_r    main_c%ROWTYPE;
   v_dtpli_customer_num      xxar_customer_conversion_tfm.dtpli_customer_num%TYPE;


BEGIN
   OPEN main_c;
      LOOP
         FETCH main_c INTO main_r;
            EXIT WHEN main_c%NOTFOUND;

               v_dtpli_customer_num := return_customer_number(main_r.orig_system_customer_ref);
                                                             --,main_r.customer_name);
               UPDATE xxar_customer_conversion_tfm
               SET dtpli_customer_num =  v_dtpli_customer_num
               WHERE dtpli_customer_num is null
               AND orig_system_customer_ref = main_r.orig_system_customer_ref
               --AND customer_name = main_r.customer_name
               AND run_id = p_run_id;

      END LOOP;
     -- COMMIT;
   CLOSE  main_c;
EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'Error While UPDATING Customer Number '|| SQLERRM);
END update_customer_numbers_temp;

PROCEDURE update_customer_site_num_temp(p_run_id NUMBER)
IS
   CURSOR main_c IS
      SELECT orig_system_address_ref
      FROM xxar_customer_conversion_tfm
      WHERE dtpli_customer_site_num is null
      AND run_id = p_run_id;
      main_r    main_c%ROWTYPE;
      v_dtpli_customer_site_num xxar_customer_conversion_tfm.dtpli_customer_site_num%TYPE;
BEGIN
    OPEN main_c;
      LOOP
         FETCH main_c INTO main_r;
            EXIT WHEN main_c%NOTFOUND;
            
               v_dtpli_customer_site_num := return_customer_site_number(main_r.orig_system_address_ref);

               UPDATE xxar_customer_conversion_tfm
               SET dtpli_customer_site_num = v_dtpli_customer_site_num,
               status = 'SUCCESS' -- Added by Joy Pinto on 15-Aug-2017
               WHERE dtpli_customer_site_num is null
               AND orig_system_address_ref = main_r.orig_system_address_ref
               AND run_id = p_run_id;

      END LOOP;
      --COMMIT;
   CLOSE  main_c;
   
   -- Added by Joy Pinto on 22-Aug-2017, Any record that is not success should be marked as Rejected
   UPDATE xxar_customer_conversion_tfm
   SET status = 'REJECTED' -- Added by Joy Pinto on 15-Aug-2017
   WHERE status != 'SUCCESS' 
   AND run_id = p_run_id;
   
   COMMIT; -- Added by Joy Pinto on 25-Aug-2017 Adding new Post Update Script to Update Suppliers   
   
EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'Error While UPDATING Customer Site Number '|| SQLERRM);
END update_customer_site_num_temp;

PROCEDURE create_site_profile(p_run_id NUMBER) -- Added by Joy Pinto on 28-Aug-2017 Add on script written to handle CONVERSION issue
IS
   CURSOR main_c IS
      SELECT  --hcp.site_use_id,
              hcu.site_use_id,
              hps.party_site_number, 
              hcas.cust_Account_id,
              UPPER(tfm.industry_type) staging_profile_class,
              (select c.profile_class_id from hz_cust_profile_classes c where upper(c.name) = UPPER(tfm.industry_type) ) expected_profile_class_id,
              UPPER((select c.name from hz_cust_profile_classes c where c.profile_class_id = hcp.profile_class_id )) system_profile_class
      FROM   fmsmgr.xxar_customer_conversion_tfm tfm,
             hz_party_sites hps,
             hz_cust_acct_sites_all hcas,
             (select * from hz_cust_site_uses_all hcu where hcu.site_use_code = 'BILL_TO') hcu,
             hz_customer_profiles hcp
      WHERE  run_id = p_run_id
      AND    tfm.dtpli_customer_site_num = hps.party_site_number
      AND    hcas.party_site_id=hps.party_site_id
      AND    hcu.cust_acct_site_id = hcas.cust_acct_site_id
      AND    hcp.site_use_id(+) = hcu.site_use_id
      AND    tfm.record_action = 'SITE' 
      AND    nvl(UPPER((select c.name from hz_cust_profile_classes c where c.profile_class_id = hcp.profile_class_id )),'X') <> UPPER(tfm.industry_type);
      
   main_r    main_c%ROWTYPE;
   p_customer_profile_rec_type HZ_CUSTOMER_PROFILE_V2PUB.CUSTOMER_PROFILE_REC_TYPE;
   lx_cust_account_profile_id NUMBER;
   lx_return_status VARCHAR2(2000);
   lx_msg_count NUMBER;
   lx_msg_data VARCHAR2(2000);      
      
BEGIN
    OPEN main_c;
      LOOP
         FETCH main_c INTO main_r;
         EXIT WHEN main_c%NOTFOUND;   
         
         BEGIN
            p_customer_profile_rec_type.cust_account_id   := main_r.cust_Account_id;
            p_customer_profile_rec_type.site_use_id       := main_r.site_use_id;
            p_customer_profile_rec_type.profile_class_id  := main_r.expected_profile_class_id;
            p_customer_profile_rec_type.created_by_module := 'CONVERSION';
            HZ_CUSTOMER_PROFILE_V2PUB.create_customer_profile(
                                                                p_init_msg_list           => FND_API.G_FALSE,
                                                                p_customer_profile_rec    => p_customer_profile_rec_type,
                                                                p_create_profile_amt      => FND_API.G_TRUE,
                                                                x_cust_account_profile_id => lx_cust_account_profile_id,
                                                                x_return_status           => lx_return_status,
                                                                x_msg_count               => lx_msg_count,
                                                                x_msg_data                => lx_msg_data
                                                             );
            COMMIT;
         EXCEPTION
         WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,'Error While Updating profile for customer site Customer Site Number '||main_r.party_site_number||'Error is  :'|| SQLERRM);
         END;

      END LOOP;
      --COMMIT;
   CLOSE  main_c;
   
   -- Added by Joy Pinto on 22-Aug-2017, Any record that is not success should be marked as Rejected
   UPDATE xxar_customer_conversion_tfm
   SET status = 'REJECTED' -- Added by Joy Pinto on 15-Aug-2017
   WHERE status != 'SUCCESS' 
   AND run_id = p_run_id;
   
   COMMIT; -- Added by Joy Pinto on 25-Aug-2017 Adding new Post Update Script to Update Suppliers   
   
EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'Error While UPDATING Customer Site Number '|| SQLERRM);
END create_site_profile;


---------------------
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
--------------------

PROCEDURE customer_import
(
   p_errbuff          OUT  VARCHAR2,
   p_retcode          OUT  NUMBER,
   p_file_name        IN   VARCHAR2,
   p_control_file     IN   VARCHAR2,
   --p_archive_flag     IN   VARCHAR2,
   p_debug_flag       IN   VARCHAR2,
   p_int_mode         IN   VARCHAR2,
   p_source           IN   VARCHAR2
)
IS
   CURSOR c_int IS
      SELECT int_id,
             int_code,
             enabled_flag
      FROM   dot_int_interfaces
      WHERE  int_code = g_customer_int_code;

   CURSOR c_stage (p_run_id NUMBER) IS
      SELECT record_id,
             run_id,
             run_phase_id,
             record_action,
             customer_name,
             orig_system_customer_ref,
             dsdbi_customer_num,
             dtpli_customer_num,
             abn,
             customer_class_code,
             customer_attribute2,
             industry_type,
             dsdbi_customer_site_num,
             dtpli_customer_site_num,
             address_attribute3,
             orig_system_address_ref,
             site_use_code,
             primary_site_use_flag,
             location,
             address1,
             address2,
             address3,
             address4,
             city,
             country,
             state,
             postal_code,
             status,
             created_by,
             creation_date
      FROM   fmsmgr.xxar_customer_conversion_stg
      WHERE  run_id = p_run_id;

   l_party_id                  NUMBER;
   l_cust_acct_id              NUMBER;
   l_account_number            VARCHAR2(30);
   l_party_site_id             NUMBER;
   l_cust_acct_site_id         NUMBER;
   l_party_site_number         NUMBER;
   l_location_id               NUMBER;
   l_site_use_id               NUMBER;
   l_profile_class_id          NUMBER;
   l_site_party_id             NUMBER;
   l_insert_update_flag        VARCHAR2(1) := 'I';
   l_user_name                  VARCHAR2(60);
   l_user_id                    NUMBER;
   l_login_id                   NUMBER;
   l_appl_id                    NUMBER;
   l_org_id                     NUMBER;
   l_interface_req_id           NUMBER;
   l_file                       VARCHAR2(150);
   l_file_req_id                NUMBER;
   l_sqlldr_req_id              NUMBER;
   l_record_count               NUMBER;
   l_success_count              NUMBER := 0;
   l_error_count                NUMBER := 0;
   l_inbound_directory          VARCHAR2(150);
   l_outbound_directory         VARCHAR2(150);
   l_staging_directory          VARCHAR2(150);
   l_archive_directory          VARCHAR2(150);
   l_appl_short_name            VARCHAR2(5) := 'AR';
   l_source_dir                 VARCHAR2(30);
   l_log                        VARCHAR2(150);
   l_bad                        VARCHAR2(150);
   l_ctl                        VARCHAR2(150);
   l_tfm_mode                   VARCHAR2(60);
   l_tfm_error                  NUMBER;
   l_int_status                 VARCHAR2(25);
   l_dup                        NUMBER;
   l_debug_flag                 VARCHAR2(15) := NVL(p_debug_flag, 'N');
   l_message                    VARCHAR2(1000);
   l_convert_temp               VARCHAR2(500);
   l_PROCEDURE_name             VARCHAR2(150) := 'xxar_customer_conversion_pkg.customer_import';
   l_cust_site_create_req_id    NUMBER;
   v_transmission_method        VARCHAR2(150);
   x_message                    VARCHAR2(1000);
   x_status                     VARCHAR2(1);

   r_int                        c_int%ROWTYPE;
   r_stg                        c_stage%ROWTYPE;
   r_error                      dot_int_run_phase_errors%ROWTYPE;
   r_tfm                        fmsmgr.xxar_customer_conversion_tfm%ROWTYPE;
   r_request                    xxint_common_pkg.control_record_type;
   t_files                      xxint_common_pkg.t_files_type;
   r_new_cust_sites_count   NUMBER:= 0;
   v_new_sites_rec_count        NUMBER:= 0;
   v_updated_sites_rec_count    NUMBER:= 0;
   l_new_org_contact_party_id   NUMBER;
   l_new_contact_party_id       NUMBER;
   l_conv_prefix                VARCHAR2(4):= 'CONV';
   
   -- SRS
   srs_wait                     BOOLEAN;
   srs_phase                    VARCHAR2(30);
   srs_status                   VARCHAR2(30);
   srs_dev_phase                VARCHAR2(30);
   srs_dev_status               VARCHAR2(30);
   srs_message                  VARCHAR2(240);

   -- Interface Framework
   l_run_id                     NUMBER;
   l_run_phase_id               NUMBER;
   l_run_report_id              NUMBER;
   l_run_error                  NUMBER := 0;
   write_to_out                 BOOLEAN;
   l_delim                      VARCHAR2(1) := '|';

   interface_error              EXCEPTION;
   number_error                 EXCEPTION;
   pragma                       EXCEPTION_INIT(number_error, -6502);

   PROCEDURE wait_for_request
   (
      p_request_id_x   NUMBER,
      p_wait_time      NUMBER
   )
   IS
   BEGIN
      srs_wait := fnd_concurrent.wait_for_request(p_request_id_x,
                                                  p_wait_time,
                                                  0,
                                                  srs_phase,
                                                  srs_status,
                                                  srs_dev_phase,
                                                  srs_dev_status,
                                                  srs_message);
   END wait_for_request;

   PROCEDURE creation_results_output
   (
      p_run_id           NUMBER,
      p_run_phase_id     NUMBER,
      p_request_id       NUMBER,
      p_file_req_id      NUMBER,
      p_source           VARCHAR2,
      p_file             VARCHAR2,
      p_delim            VARCHAR2,
      p_write_to_out     BOOLEAN
   )
   IS
      CURSOR c_processed_records IS
         -- Retrieve newly Created Customer and Site
        SELECT 'CREATED' record_action,
               NULL record_id,
               rc.customer_name,
               rc.customer_number,
               rc.orig_system_reference orig_system_customer_ref,
               hps.party_site_number customer_site_number,
               hps.orig_system_reference orig_system_address_ref,
               'CREATED IN ORACLE' status,
               rc.creation_date,
               rc.created_by
        FROM hz_cust_acct_sites_all hcas,
             hz_party_sites hps,
             RA_CUSTOMERS rc
        WHERE hcas.REQUEST_ID = p_request_id
        AND hcas.PARTY_SITE_ID = HPS.PARTY_SITE_ID
        AND  hcas.cust_account_id = rc.customer_id
        union all
        select record_action,
               record_id,
               customer_name,
               dtpli_customer_num customer_number,
               orig_system_customer_ref,
               dtpli_customer_site_num customer_site_number,
               orig_system_address_ref,
               status,
               creation_date,
               created_by
        from xxar_customer_conversion_tfm
        where record_action not in ('NEW','SITE')
        and run_id = p_run_id;

      CURSOR c_summary IS
      	SELECT 'Number of Created Customers : ' || count(*) summary_stmt
        FROM ra_customers
        WHERE request_id = p_request_id
        UNION ALL
        SELECT 'Number of Created Customer Sites : ' ||count(*) summary_stmt
        FROM hz_cust_acct_sites_all hcas,
             hz_party_sites hps,
             ra_customers rc
        WHERE hcas.request_id = p_request_id
        AND hcas.party_site_id = hps.party_site_id
        AND  hcas.cust_account_id = rc.customer_id
        UNION ALL
        select 'Number of Mapped Customer and Sites : ' ||count(*) summary_stmt
        from xxar_customer_conversion_tfm
        where record_action ='MAPPED'
        and run_id = p_run_id;



   l_file              VARCHAR2(150);
   l_outbound_path     VARCHAR2(150);
   l_text              VARCHAR2(32767);
   l_code              VARCHAR2(15);
   l_message           VARCHAR2(4000);
   r_processed_records     c_processed_records%ROWTYPE;
   r_summary               c_summary%ROWTYPE;
   --r_stuck_records         c_stuck_records%ROWTYPE;
   f_handle            utl_file.file_type;
   f_copy              INTEGER;
   print_error         EXCEPTION;
   z_file_temp_dir        CONSTANT VARCHAR2(150)  := 'USER_TMP_DIR';
   z_file_temp_path       CONSTANT VARCHAR2(150)  := '/usr/tmp';
   z_file_write           CONSTANT VARCHAR2(1)    := 'w';


   CURSOR error_check_c IS
      SELECT tfm.record_id record_id,
             decode(err.error_text,NULL,tfm.status,'ERROR') oracle_processing_status,
             REPLACE(RTRIM(err.error_text),'"','') error_comments
      FROM fmsmgr.xxar_customer_conversion_tfm tfm,
           fmsmgr.xxar_customer_conversion_stg stg,
           dot_int_run_phase_errors err
      WHERE STG.record_id = TFM.record_id(+)
      AND STG.run_id = TFM.run_id(+)
      AND STG.record_id = err.record_id(+)
      AND STG.run_id = err.run_id(+)
      AND TFM.run_id = p_run_id
      /*AND exists (SELECT 'x'
                     FROM   fmsmgr.dot_int_run_phase_errors x
                     WHERE  x.run_id = tfm.run_id
                     AND    x.record_id = tfm.record_id)*/
      ORDER BY record_id;
      v_record_id NUMBER;
      v_error_text VARCHAR(10000);
      o_error_text VARCHAR(10000);
      v_error_count NUMBER;

   BEGIN

      --l_file := p_source|| '_CUSTOMER_' ||to_char(sysdate,'YYYYMMDDHH24MMSS_') || NVL(p_request_id, l_file_req_id) || '.out';
      l_file := REPLACE(p_file,'.txt','')||'_' || p_request_id || '.out';
      f_handle := utl_file.fopen(z_file_temp_dir, l_file, z_file_write);
      l_outbound_path := xxint_common_pkg.interface_path(p_application => l_appl_short_name,
                                                      p_source => p_source,
                                                      p_in_out => 'OUTBOUND',
                                                      p_message => l_message);


      IF l_message IS NOT NULL THEN
         RAISE print_error;
      END IF;

      /*BEGIN
         SELECT COUNT(*)
         INTO  v_error_count
         FROM xxar_customer_interface_tfm
         WHERE STATUS != 'VALIDATED'
         AND run_id = p_run_id;
      END;*/
         OPEN c_summary;
         LOOP
            FETCH c_summary INTO r_summary;
            EXIT WHEN c_summary%NOTFOUND;

            l_text := NULL;
            l_text := l_text || r_summary.summary_stmt;

         utl_file.put_line(f_handle, l_text);
         fnd_file.put_line(fnd_file.output, l_text);

         END LOOP;
         CLOSE c_summary;

         l_text := NULL;
         l_text := NULL;

         OPEN c_processed_records;
         LOOP
            FETCH c_processed_records INTO r_processed_records;
            EXIT WHEN c_processed_records%NOTFOUND;

            l_message := NULL;
            IF r_processed_records.status = 'ERROR' AND r_processed_records.record_id IS NOT NULL THEN
               xxint_common_pkg.get_error_message(p_run_id, p_run_phase_id, r_processed_records.record_id, '-', l_message);
               IF l_message IS NULL THEN
                  FOR i IN (SELECT error_text
                            FROM   dot_int_run_phase_errors
                            WHERE  run_id = p_run_id
                            AND    run_phase_id = p_run_phase_id
                            AND    record_id = -1)
                  LOOP
                     IF l_message IS NOT NULL THEN
                        l_message := l_message || ' - ';
                     END IF;
                     l_message := l_message || i.error_text;
                  END LOOP;
               END IF;
             END IF;

         l_text := NULL;
         l_text := l_text || r_processed_records.record_action || p_delim;
         l_text := l_text || r_processed_records.orig_system_customer_ref || p_delim;
         l_text := l_text || r_processed_records.customer_number || p_delim;
         l_text := l_text || r_processed_records.customer_name || p_delim;
         l_text := l_text || r_processed_records.customer_site_number || p_delim;
         l_text := l_text || r_processed_records.creation_date || p_delim;
         l_text := l_text || r_processed_records.status || p_delim;
         l_text := l_text || l_message;--r_processed_records.error_comments;

         utl_file.put_line(f_handle, l_text);
         fnd_file.put_line(fnd_file.output, l_text);

      END LOOP;
      CLOSE c_processed_records;

   utl_file.fclose(f_handle);

   f_copy := xxint_common_pkg.file_copy(p_from_path => z_file_temp_path || '/' || l_file,
                                        p_to_path => l_outbound_path || '/' || l_file);


   IF f_copy = 0 THEN
      xxint_common_pkg.get_error_message(g_error_message_24, l_code, l_message);
      RAISE print_error;
   END IF;

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

   END creation_results_output;

   PROCEDURE run_create_customer_and_site(p_run_id NUMBER) IS
      CURSOR c_new_cust_sites IS
        SELECT record_id,
             run_id,
             run_phase_id,
             record_action,
             customer_name,
             orig_system_customer_ref orig_system_customer_ref,
             dsdbi_customer_num,
             dtpli_customer_num,
             abn,
             customer_class_code,
             customer_attribute2,
             --DECODE(customer_attribute2,NULL,NULL,'RRAMS') customer_attribute_category,
             industry_type,
             dsdbi_customer_site_num,
             dtpli_customer_site_num,
             address_attribute3,
             DECODE(address_attribute3,NULL,NULL,'RRAMS') address_attribute_category,
             orig_system_address_ref orig_system_address_ref,
             site_use_code,
             primary_site_use_flag,
             location,
             address1,
             address2,
             address3,
             address4,
             city,
             country,
             state,
             postal_code,
             status,
             created_by,
             creation_date
        FROM fmsmgr.xxar_customer_conversion_tfm
        WHERE record_action = 'NEW'
        AND status = 'VALIDATED'
        AND run_id = p_run_id;

        r_new_cust_sites               c_new_cust_sites%ROWTYPE;

    CURSOR c_create_customer_site_prof IS
        SELECT
           DISTINCT orig_system_customer_ref orig_system_customer_ref,
           NULL orig_system_address_ref,
           INDUSTRY_TYPE -- RPI005/006 - Customer Profile and Address Profile to use the same logic, no longer setting Customer level to DEFAULT
           --NVL(INDUSTRY_TYPE,'DEFAULT') INDUSTRY_TYPE
        FROM fmsmgr.xxar_customer_conversion_tfm
        WHERE record_action = 'NEW'
        AND status = 'VALIDATED'
        AND run_id = p_run_id
        UNION ALL
        SELECT orig_system_customer_ref orig_system_customer_ref,
             orig_system_address_ref orig_system_address_ref,
             INDUSTRY_TYPE
        FROM fmsmgr.xxar_customer_conversion_tfm
        WHERE record_action = 'NEW'
        AND status = 'VALIDATED'
        AND run_id = p_run_id;

        r_create_customer_site_prof    c_create_customer_site_prof%ROWTYPE;

    BEGIN
        r_new_cust_sites_count := 0;
        /* Debug Log */
        IF l_debug_flag = 'Y' THEN
           fnd_file.put_line(fnd_file.log, g_debug || 'Loading Transformed Data into AR Customers Interface Table');
        END IF;

        OPEN c_new_cust_sites;
        LOOP
           FETCH c_new_cust_sites INTO r_new_cust_sites;
           EXIT WHEN c_new_cust_sites%NOTFOUND;
        --FOR new_cust_sites_rec IN c_new_cust_sites LOOP
            r_new_cust_sites_count := r_new_cust_sites_count+1;

            INSERT INTO ar.ra_customers_interface_all
               (orig_system_customer_ref,
                site_use_code,
                orig_system_address_ref,
                insert_update_flag,
                customer_name,
                customer_status,
                customer_type,
                primary_site_use_flag,
                address1,
                address2,
                address3,
                address4,
                city,
                state,
                postal_code,
                country,
                customer_attribute_category,
                customer_attribute2,
                address_attribute_category,
                address_attribute1,
                address_attribute3,
                customer_class_code,
                cust_tax_reference,
                last_updated_by,
                last_update_date,
                created_by,
                creation_date,
                org_id)
            VALUES
              ( r_new_cust_sites.orig_system_customer_ref,
                r_new_cust_sites.site_use_code,
                r_new_cust_sites.orig_system_address_ref,
                l_insert_update_flag,
                r_new_cust_sites.customer_name,
                'A',
                'R',
                r_new_cust_sites.primary_site_use_flag,
                r_new_cust_sites.address1,
                r_new_cust_sites.address2,
                r_new_cust_sites.address3,
                r_new_cust_sites.address4,
                r_new_cust_sites.city,
                r_new_cust_sites.state,
                r_new_cust_sites.postal_code,
                r_new_cust_sites.country,
                '',--r_new_cust_sites.customer_attribute_category,
                r_new_cust_sites.customer_attribute2,
                r_new_cust_sites.address_attribute_category,
                'PRINT',
                r_new_cust_sites.address_attribute3,
                r_new_cust_sites.customer_class_code,
                r_new_cust_sites.abn,
                l_user_id,
                sysdate,
				        l_user_id,
                sysdate,
                l_org_id);

        END LOOP;
        CLOSE c_new_cust_sites;

        OPEN c_create_customer_site_prof;
        LOOP
        FETCH c_create_customer_site_prof INTO r_create_customer_site_prof;
           EXIT WHEN c_create_customer_site_prof%NOTFOUND;

           INSERT INTO ar.ra_customer_profiles_int_all
               (insert_update_flag,
                orig_system_customer_ref,
				        orig_system_address_ref,
                customer_profile_class_name,
                credit_hold,
                last_updated_by,
                last_update_date,
                created_by,
                creation_date,
                org_id)
           VALUES
               (l_insert_update_flag,
                r_create_customer_site_prof.orig_system_customer_ref,
                r_create_customer_site_prof.orig_system_address_ref,
                NVL(r_create_customer_site_prof.industry_type,'NON GOVERNMENT'),
                'N',
                l_user_id,
                SYSDATE,
                l_user_id,
                SYSDATE,
                l_org_id);

        END LOOP;
        CLOSE c_create_customer_site_prof;

        l_success_count := sql%ROWCOUNT;
        l_int_status := 'SUCCESS';

   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         l_error_count := l_record_count;
         l_int_status := 'ERROR';
         r_error.error_token_val1 := 'INSERT_INTO_INTERFACE';
         xxint_common_pkg.get_error_message(g_error_message_11|| SQLERRM, r_error.msg_code, l_message);
         r_error.msg_code := REPLACE(SQLCODE, '-');
         r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
         raise_error(r_error);
         fnd_file.put_line(fnd_file.log,'Error While creating New Customer '|| SQLERRM);
        RETURN;
         p_retcode := 2;
   END run_create_customer_and_site;

   FUNCTION get_cust_name_for_site (p_customer_number VARCHAR2)
   RETURN VARCHAR2 IS
      v_customer_name ra_customers.customer_name%TYPE;
   BEGIN
      SELECT customer_name
	  INTO v_customer_name
      FROM ra_customers
      WHERE customer_number = p_customer_number;

	  RETURN v_customer_name;
   EXCEPTION
      WHEN OTHERS THEN
	     fnd_file.put_line(fnd_file.log,'Error While Retrieving Customer Name '|| SQLERRM);
   END;

   PROCEDURE run_create_site_only(p_run_id NUMBER) IS

     CURSOR c_site_on_tfm IS
      SELECT record_id,
             run_id,
             run_phase_id,
             record_action,
             customer_name,
             orig_system_customer_ref orig_system_customer_ref,
             dsdbi_customer_num,
             dtpli_customer_num,
             abn,
             customer_class_code,
             customer_attribute2,
             --DECODE(customer_attribute2,NULL,NULL,'RRAMS') customer_attribute_category,
             INDUSTRY_TYPE,
             dsdbi_customer_site_num,
             dtpli_customer_site_num,
             address_attribute3,
             DECODE(address_attribute3,NULL,NULL,'RRAMS') address_attribute_category,
             orig_system_address_ref orig_system_address_ref,
             site_use_code,
             primary_site_use_flag,
             location,
             address1,
             address2,
             address3,
             address4,
             city,
             country,
             state,
             postal_code,
             status,
             created_by,
             creation_date
        FROM fmsmgr.xxar_customer_conversion_tfm
        WHERE record_action = 'SITE'
        AND status = 'VALIDATED'
        AND run_id = p_run_id;

        r_site_on_tfm            c_site_on_tfm%ROWTYPE;
        l_site_count             NUMBER :=0;
		    l_customer_name          xxar_customer_conversion_tfm.customer_name%TYPE;
        l_new_orig_system_ref    ra_customers.orig_system_reference%TYPE;
        l_new_party_orig_sys_ref    hz_parties.orig_system_reference%TYPE;

     FUNCTION get_new_cust_orig_sys_ref (p_customer_number varchar2,
                                       p_customer_name varchar2)
     RETURN VARCHAR IS
        v_new_cust_orig_sys_ref ra_customers.orig_system_reference%TYPE;
     BEGIN
        SELECT orig_system_reference
        INTO v_new_cust_orig_sys_ref
        FROM ra_customers
        WHERE customer_number = p_customer_number;
       -- AND customer_name = p_customer_name; -- Commnented by Joy Pinto on 07-Sep-2017

        RETURN v_new_cust_orig_sys_ref;
        
     EXCEPTION 
        WHEN OTHERS THEN 
           RETURN NULL;
     END get_new_cust_orig_sys_ref;


     FUNCTION get_new_party_orig_sys_ref (p_new_cust_orig_sys_ref varchar2)
     RETURN VARCHAR IS
        v_new_party_orig_sys_ref hz_parties.orig_system_reference%TYPE;
     BEGIN
        select a.orig_system_reference party_ref
        into v_new_party_orig_sys_ref
        from hz_parties a, hz_cust_accounts b
        where a.party_id = b.party_id
        and b.orig_system_reference = p_new_cust_orig_sys_ref;

        RETURN v_new_party_orig_sys_ref;
     END get_new_party_orig_sys_ref;

  BEGIN
       OPEN c_site_on_tfm;
       LOOP
          FETCH c_site_on_tfm INTO r_site_on_tfm;
          EXIT WHEN c_site_on_tfm%NOTFOUND;
          
          BEGIN
			    l_customer_name := get_cust_name_for_site (r_site_on_tfm.dtpli_customer_num);
			   -- l_new_orig_system_ref := get_new_cust_orig_sys_ref(r_site_on_tfm.dtpli_customer_num,l_customer_name);
          l_new_party_orig_sys_ref := get_new_party_orig_sys_ref (r_site_on_tfm.orig_system_customer_ref);
          
          fnd_file.put_line(fnd_file.log,'l_customer_name :'||l_customer_name);
          fnd_file.put_line(fnd_file.log,'l_new_orig_system_ref :'||l_new_orig_system_ref);
          fnd_file.put_line(fnd_file.log,'l_new_party_orig_sys_ref :'||l_new_party_orig_sys_ref);

            INSERT INTO ar.ra_customers_interface_all
               (orig_system_customer_ref,
                site_use_code,
                orig_system_address_ref,
                insert_update_flag,
                customer_name,
				--customer_number,
                customer_status,
                customer_type,
                primary_site_use_flag,
                address1,
                address2,
                address3,
                address4,
                city,
                state,
                postal_code,
                country,
                customer_attribute_category,
                customer_attribute2,
                address_attribute_category,
                address_attribute1,
                address_attribute3,
                customer_class_code,
                cust_tax_reference,
                ORIG_SYSTEM_PARTY_REF,
                last_updated_by,
                last_update_date,
                created_by,
                creation_date,
                org_id)
            VALUES
              ( r_site_on_tfm.orig_system_customer_ref,
                --l_new_orig_system_ref , -- Commented by Joy Pinto on 07-Sep-2017
                r_site_on_tfm.site_use_code,
                r_site_on_tfm.orig_system_address_ref,
                l_insert_update_flag,
                l_customer_name,--r_site_on_tfm.customer_name,
				--r_site_on_tfm.dtpli_customer_num,
                'A',
                'R',
                r_site_on_tfm.primary_site_use_flag,
                r_site_on_tfm.address1,
                r_site_on_tfm.address2,
                r_site_on_tfm.address3,
                r_site_on_tfm.address4,
                r_site_on_tfm.city,
                r_site_on_tfm.state,
                r_site_on_tfm.postal_code,
                r_site_on_tfm.country,
                '',--r_site_on_tfm.customer_attribute_category,
                r_site_on_tfm.customer_attribute2,
                r_site_on_tfm.address_attribute_category,
                'PRINT',
                r_site_on_tfm.address_attribute3,
                r_site_on_tfm.customer_class_code,
                r_site_on_tfm.abn,
                l_new_party_orig_sys_ref,
                l_user_id,
                sysdate,
				        l_user_id,
                sysdate,
                l_org_id);



			INSERT INTO ar.ra_customer_profiles_int_all
               (insert_update_flag,
				        orig_system_customer_ref,
              	orig_system_address_ref,
                customer_profile_class_name,
                credit_hold,
                last_updated_by,
                last_update_date,
                created_by,
                creation_date,
                org_id)
            VALUES
               (l_insert_update_flag,
				        r_site_on_tfm.orig_system_customer_ref,
				        r_site_on_tfm.orig_system_address_ref,
                NVL(r_site_on_tfm.industry_type,'NON GOVERNMENT'),
                'N',
                l_user_id,
                SYSDATE,
                l_user_id,
                SYSDATE,
                l_org_id);
                
         EXCEPTION
         WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log,'Error while inserting orig_system_address_ref = '||r_site_on_tfm.orig_system_address_ref||'Error is  : '||SQLERRM);
         END;

         END LOOP;
         

         COMMIT;
         


         CLOSE c_site_on_tfm;

   EXCEPTION
      WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log,SQLERRM);
   END run_create_site_only;

   FUNCTION check_orig_sys_add_ref(p_orig_sys_add_ref VARCHAR2)
   RETURN BOOLEAN IS
      o_existing NUMBER;
      o_existing1 NUMBER;
      o_existing2 NUMBER;
   BEGIN
      select count(*)
      into o_existing
      from hz_party_sites--hz_locations
      where orig_system_reference = p_orig_sys_add_ref;
      
      select count(*)
      into o_existing1
      from 
      HZ_LOCATIONS
      where ORIG_SYSTEM_REFERENCE = p_orig_sys_add_ref;
      
      select count(*)
      into o_existing2
      from
      HZ_CUST_ACCT_SITES_ALL
      where ORIG_SYSTEM_REFERENCE = p_orig_sys_add_ref;

      IF o_existing>0 OR o_existing1 >0 or o_existing2 >0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, g_debug ||'Error while running check_orig_sys_add_ref '||p_orig_sys_add_ref);
          RETURN FALSE;
   END check_orig_sys_add_ref;
   
   FUNCTION check_orig_sys_cust_ref(p_orig_sys_cust_ref VARCHAR2)
   RETURN BOOLEAN IS
      o_existing NUMBER;
   BEGIN
      select count(*)
      into o_existing
      from ra_customers--hz_locations
      where orig_system_reference = p_orig_sys_cust_ref;

      IF o_existing>0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, g_debug ||'Error while running check_orig_sys_cust_ref '||p_orig_sys_cust_ref);
          RETURN FALSE;
   END check_orig_sys_cust_ref;   


   -- Check whether the customer's Detail Address Information is already Existing -
   FUNCTION check_address_uniquness(p_dtpli_customer_num VARCHAR2,
                                    p_site_use_code VARCHAR2,
                                    p_address1 VARCHAR2,
                                    p_address2 VARCHAR2,
                                    p_address3 VARCHAR2,
                                    p_address4 VARCHAR2)
   RETURN BOOLEAN IS
      o_existing NUMBER;
   BEGIN
      SELECT  count(*)
      INTO o_existing
      FROM ra_customers rc,
           hz_parties hp,
           hz_party_sites hps,
           hz_locations hl,
           hz_cust_acct_sites_all has,
           hz_cust_site_uses_all hu
      WHERE rc.party_id = hp.party_id
      AND hps.party_id = hp.party_id
      AND hps.location_id = hl.location_id
      AND has.party_site_id = hps.party_site_id
      AND has.cust_acct_site_id = hu.cust_acct_site_id
      AND nvl(hl.address1,'x') = nvl(p_address1,'x')
      AND nvl(hl.address2,'x') = nvl(p_address2,'x')
      AND nvl(hl.address3,'x') = nvl(p_address3,'x')
      AND nvl(hl.address4,'x') = nvl(p_address4,'x')
      AND rc.customer_number = p_dtpli_customer_num
      AND hu.site_use_code = p_site_use_code;

      IF  o_existing > 0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   END check_address_uniquness;

     FUNCTION get_new_cust_orig_sys_ref (p_customer_number varchar2,
                                       p_customer_name varchar2)
     RETURN VARCHAR IS
        v_new_cust_orig_sys_ref ra_customers.orig_system_reference%TYPE;
     BEGIN
        SELECT orig_system_reference
        INTO v_new_cust_orig_sys_ref
        FROM ra_customers
        WHERE customer_number = p_customer_number;
       -- AND customer_name = p_customer_name; -- Commnented by Joy Pinto on 07-Sep-2017

        RETURN v_new_cust_orig_sys_ref;
        
     EXCEPTION 
        WHEN OTHERS THEN 
           RETURN NULL;
     END get_new_cust_orig_sys_ref;

BEGIN
   xxint_common_pkg.g_object_type := 'CUSTOMERS'; -- Added as interface directories are repointed to NFS
   l_tfm_mode := NVL(p_int_mode, g_int_mode);
   l_ctl := NVL(p_control_file, g_customer_ctl);
   l_user_name := fnd_profile.value('USERNAME');
   l_user_id := fnd_profile.value('USER_ID');
   l_login_id := fnd_profile.value('LOGIN_ID');
   l_org_id := fnd_global.org_id;
   l_appl_id := fnd_global.resp_appl_id;
   l_interface_req_id := fnd_global.conc_request_id;
   l_source_dir := p_source;
   l_file := NVL(p_file_name, g_customer_file);
   write_to_out := TRUE;

   /* Program Short Name */
   g_src_code := 'XXARCUSTCV';

   fnd_file.put_line(fnd_file.log, 'DEBUG_FLAG=' || NVL(p_debug_flag, 'N'));

   /* Debug Log */
   IF l_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || 'PROCEDURE name ' || l_PROCEDURE_name || '.');
   END IF;

   /* Debug Log */
   IF l_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || 'check interface registry for ' || g_customer_int_code || '.');
   END IF;

   /* Interface Registry */
   OPEN c_int;
   FETCH c_int INTO r_int;
   IF c_int%NOTFOUND THEN
      INSERT INTO dot_int_interfaces
      VALUES (dot_int_interfaces_s.NEXTVAL,
              g_customer_int_code,
              g_customer_int_name,
              'IN',
              'AR',
              'Y',
              SYSDATE,
              l_user_id,
              l_user_id,
              SYSDATE,
              l_login_id,
              l_interface_req_id);

      COMMIT;
   ELSE
      IF NVL(r_int.enabled_flag, 'N') = 'N' THEN
         fnd_file.put_line(fnd_file.log, g_error || REPLACE(SUBSTR(g_error_message_01, 11, 100), '$INT_CODE', g_customer_int_code));
         p_retcode := 2;
         RETURN;
      END IF;
   END IF;
   CLOSE c_int;

   /* Debug Log */
   IF l_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || 'retrieving interface directory information');
   END IF;


   l_inbound_directory := xxint_common_pkg.interface_path(p_application => l_appl_short_name,
                                                          p_source => l_source_dir,
                                                          p_message => x_message);
   IF x_message IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_outbound_directory := xxint_common_pkg.interface_path(p_application => l_appl_short_name,
                                                           p_source => l_source_dir,
                                                           p_in_out => 'OUTBOUND',
                                                           p_message => x_message);
   IF x_message IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_staging_directory := xxint_common_pkg.interface_path(p_application => l_appl_short_name,
                                                          p_source => l_source_dir,
                                                          p_in_out => g_staging_directory,
                                                          p_message => x_message);
   IF x_message IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   l_archive_directory := xxint_common_pkg.interface_path(p_application => l_appl_short_name,
                                                          p_source => l_source_dir,
                                                          p_archive => 'Y',
                                                          p_message => x_message);
   IF x_message IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log, g_error || x_message);
      p_retcode := 2;
      RETURN;
   END IF;

   IF l_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || 'p_source=' || p_source);
      fnd_file.put_line(fnd_file.log, g_debug || 'p_file_name=' || l_file);
      fnd_file.put_line(fnd_file.log, g_debug || 'p_control_file=' || l_ctl);
      fnd_file.put_line(fnd_file.log, g_debug || 'l_inbound_directory=' || l_inbound_directory);
      fnd_file.put_line(fnd_file.log, g_debug || 'l_outbound_directory=' || l_outbound_directory);
      fnd_file.put_line(fnd_file.log, g_debug || 'l_staging_directory=' || l_staging_directory);
      fnd_file.put_line(fnd_file.log, g_debug || 'l_archive_directory=' || l_archive_directory);
   END IF;

   IF (p_source IS NOT NULL) AND
      (INSTR(l_file, p_source) = 0) AND
      (INSTR(l_file, '*') > 0) THEN
      fnd_file.put_line(fnd_file.log, g_error || 'unable to resolve source and file to process');
      p_retcode := 2;
      RETURN;
   END IF;

   l_file_req_id := fnd_request.submit_request(application => 'FNDC',
                                               program     => 'XXINTIFR',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => l_interface_req_id,
                                               argument2   => l_inbound_directory,
                                               argument3   => l_file,
                                               argument4   => l_appl_id);
   COMMIT;

   /* Debug Log */
   IF l_debug_flag = 'Y' THEN
      fnd_file.put_line(fnd_file.log, g_debug || 'fetching file ' || l_file || ' from ' || l_inbound_directory || ' (request_id=' || l_file_req_id || ')');
   END IF;

   r_request := NULL;
   r_request.application_id := l_appl_id;
   r_request.interface_request_id := l_interface_req_id;
   r_request.sub_request_id := l_file_req_id;

   wait_for_request(l_file_req_id, 5);

   IF NOT (srs_dev_phase = 'COMPLETE' AND
          (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
      l_run_error := l_run_error + 1;
      l_message := REPLACE(SUBSTR(g_error_message_02, 11, 100), '$INT_DIR', l_inbound_directory);
      fnd_file.put_line(fnd_file.log, g_error || l_message);
      r_request.error_message := l_message;
      r_request.status := 'ERROR';

   ELSE
      r_request.status := 'SUCCESS';

      SELECT file_name BULK COLLECT
      INTO   t_files
      FROM   xxint_interface_ctl
      WHERE  interface_request_id = l_interface_req_id
      AND    sub_request_id = l_file_req_id
      AND    file_name IS NOT NULL;
   END IF;

   /* Interface control record */
   xxint_common_pkg.interface_request(r_request);

   IF l_run_error > 0 THEN
      RAISE interface_error;
   END IF;

   IF t_files.COUNT > 1 THEN
      write_to_out := FALSE;
   END IF;

   IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'File Count : ' || t_files.COUNT);
   END IF;

   FOR i IN 1 .. t_files.COUNT LOOP
      l_file := REPLACE(t_files(i), l_inbound_directory || '/');
      l_log  := REPLACE(l_file, 'csv', 'log');
      l_bad  := REPLACE(l_file, 'csv', 'bad');


      /*IF NOT file_length_check(p_source,l_file) THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'The File ' || l_file ||' is not correct Format');
         CONTINUE;
      END IF;*/

      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'File : ' || l_file);
      END IF;

      -----------------------
      -- Interface Run ID  --
      -----------------------
      l_run_id := dot_common_int_pkg.initialise_run
                     (p_int_code       => g_customer_int_code,
                      p_src_rec_count  => NULL,
                      p_src_hash_total => NULL,
                      p_src_batch_name => l_file);

      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework (run_id=' || l_run_id || ')');
      END IF;

      ----------------------------
      -- STAGE: Start Run Phase --
      ----------------------------
      l_run_phase_id := dot_common_int_pkg.start_run_phase
                           (p_run_id                  => l_run_id,
                            p_phase_code              => 'STAGE',
                            p_phase_mode              => NULL,
                            p_int_table_name          => l_file,
                            p_int_table_key_col1      => 'DSDBI_CUSTOMER_NUM',
                            p_int_table_key_col_desc1 => 'DSDBI Customer Number',
                            p_int_table_key_col2      => 'DSDBI_CUSTOMER_SITE_NUM',
                            p_int_table_key_col_desc2 => 'DSDBI Customer Site Number',
                            p_int_table_key_col3      => NULL,
                            p_int_table_key_col_desc3 => NULL);

      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework (run_stage_id=' || l_run_phase_id || ')');
      END IF;

      l_sqlldr_req_id := fnd_request.submit_request(application => 'FNDC',
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
                                                    argument8   => l_ctl);
      COMMIT;

      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'load file ' || l_file || ' to staging (request_id=' || l_sqlldr_req_id || ')');
      END IF;

      l_success_count := 0;
      l_error_count := 0;

      /* Interface control record */
      r_request.file_name := t_files(i);
      r_request.sub_request_id := l_sqlldr_req_id;
      xxint_common_pkg.interface_request(r_request);

      wait_for_request(l_sqlldr_req_id, 5);

      IF NOT (srs_dev_phase = 'COMPLETE' AND
             (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
         l_run_error := l_run_error + 1;
         l_message := REPLACE(SUBSTR(g_error_message_03, 11, 100), '$INT_FILE', l_file);
         fnd_file.put_line(fnd_file.log, g_error || l_message);

         r_request.error_message := l_message;
         r_request.status := 'ERROR';

      ELSE
         r_request.status := 'SUCCESS';

         UPDATE fmsmgr.xxar_customer_conversion_stg
         SET    run_id = l_run_id,
                run_phase_id = l_run_phase_id,
                status = 'PROCESSED',
                created_by = l_user_id,
                creation_date = SYSDATE;

         SELECT COUNT(1)
         INTO   l_record_count
         FROM   fmsmgr.xxar_customer_conversion_stg
         WHERE  run_id = l_run_id
         AND    run_phase_id = l_run_phase_id;

         IF sql%FOUND THEN
            l_success_count := l_record_count;
            COMMIT;
         END IF;
      END IF;

      /* Interface control record */
      xxint_common_pkg.interface_request(r_request);

      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'file staging (status=' || r_request.status || ')');
      END IF;

      -----------------------------
      -- STAGE: Update Run Phase --
      -----------------------------
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_src_code     => g_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      ----------------------------
      -- STAGE: End Run Phase   --
      ----------------------------
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_status => r_request.status,
          p_error_count => l_error_count,
          p_success_count => l_success_count);

      IF l_run_error > 0 THEN
         RAISE interface_error;
      END IF;

      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'executing transformation and validation');
      END IF;

      --------------------------------
      -- TRANSFORM: Start Run Phase --
      --------------------------------
      l_run_phase_id := dot_common_int_pkg.start_run_phase
                           (p_run_id                  => l_run_id,
                            p_phase_code              => 'TRANSFORM',
                            p_phase_mode              => g_int_mode,
                            p_int_table_name          => 'xxar_customer_conversion_stg',
                            p_int_table_key_col1      => 'DSDBI_CUSTOMER_NUM',
                            p_int_table_key_col_desc1 => 'DSDBI Customer Number',
                            p_int_table_key_col2      => 'DSDBI_CUSTOMER_SITE_NUM',
                            p_int_table_key_col_desc2 => 'DSDBI Customer Site Number',
                            p_int_table_key_col3      => NULL,
                            p_int_table_key_col_desc3 => NULL);

      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework (run_transform_id=' || l_run_phase_id || ')');
         fnd_file.put_line(fnd_file.log, g_debug || 'reset transformation table');
      END IF;

      --EXECUTE IMMEDIATE g_customer_reset_tfm_sql;
      l_success_count := 0;
      l_error_count := 0;
      l_int_status := 'SUCCESS';

      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework (l_int_status=' || l_int_status || ')');
         fnd_file.put_line(fnd_file.log, g_debug || 'Reset transformation table completed');
      END IF;
      ---------------------------------
      -- TRANSFORM: Update Run Phase --
      ---------------------------------
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_src_code     => g_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => l_file);

      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework (p_run_phase_id=' || l_run_phase_id || ')');
         fnd_file.put_line(fnd_file.log, g_debug || 'dot_common_int_pkg.update_run_phase');
      END IF;


      OPEN c_stage(l_run_id);
      LOOP
         FETCH c_stage INTO r_stg;
         EXIT WHEN c_stage%NOTFOUND;

         l_tfm_error := 0;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := r_stg.record_id;
         r_error.int_table_key_val1 := r_stg.dsdbi_customer_num;
         r_error.int_table_key_val2 := r_stg.dsdbi_customer_site_num;
         -- Transform
         r_tfm := NULL;
         r_tfm.record_id := r_stg.record_id;
         r_tfm.run_id := l_run_id;
         r_tfm.run_phase_id := l_run_phase_id;


         BEGIN

            IF r_stg.record_action not in ('NEW','SITE','MAPPED') THEN
               r_error.error_token_val1 := 'STG_UPDATE_OR_CREATE';
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_08, r_error.msg_code, l_message);
               r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
               raise_error(r_error);
               fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
            END IF;

            IF r_stg.country IS NOT NULL THEN
               IF NOT check_country_code(r_stg.country) THEN
                  r_error.error_token_val1 := 'STG_COUNTRY_CODE';
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_37, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                  raise_error(r_error);
                  fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
               END IF;
            END IF;

            IF check_special_char THEN
               r_error.error_token_val1 := 'STG_SPECIAL_CHAR_CHECK1';
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_36, r_error.msg_code, l_message);
               r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
               raise_error(r_error);
               fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
            END IF;

           IF r_stg.customer_class_code IS NOT NULL THEN
               IF NOT check_customer_class(r_stg.customer_class_code) THEN
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_34, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$CUSTOMER_CLASS_CODE', r_stg.customer_class_code);
                  raise_error(r_error);
                  fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
               END IF;
           END IF;

           IF r_stg.industry_type IS NOT NULL THEN
              IF NOT check_customer_profile_class(r_stg.industry_type) THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_35, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$INDUSTRY_TYPE', r_stg.industry_type);
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
              END IF;
           END IF;

           IF r_stg.record_action = 'NEW' THEN

              -------------------------------------------------------------
              -- 1. Data Validation for creating a New Customer and Site --
              -------------------------------------------------------------

              r_error.error_token_val1 := 'STG_CREATE_NEW_CUSTOMER';
              
              IF check_orig_sys_cust_ref(r_stg.orig_system_customer_ref) THEN -- Added by Joy Pinto on 31-Aug-2017 FSC-751
                 r_tfm.orig_system_customer_ref	     :=SUBSTR('CONV'||r_stg.orig_system_customer_ref,1,240);              
              ELSE
                 r_tfm.orig_system_customer_ref := r_stg.orig_system_customer_ref;
              END IF;               

              IF r_stg.CUSTOMER_NAME IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_27, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
              END IF;


              IF  r_stg.ORIG_SYSTEM_CUSTOMER_REF IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_32, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
              END IF;

              /* Commented by Joy Pinto on 04-Aug-2017 as per ERPTEST comments
              IF get_customer_name(NVL(r_stg.CUSTOMER_NAME,'!@#!@#^&#'),l_org_id) > 0 THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_29, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              END IF;
              */

              IF r_stg.DTPLI_CUSTOMER_NUM IS NOT NULL OR r_stg.DTPLI_CUSTOMER_SITE_NUM IS NOT NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_04, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
              END IF;

              IF r_stg.location IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_28, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
              END IF;

              IF r_stg.ADDRESS1 IS NOT NULL or r_stg.ADDRESS2 IS NOT NULL or r_stg.ADDRESS3 IS NOT NULL or r_stg.ADDRESS4 IS NOT NULL or r_stg.COUNTRY IS NOT NULL or r_stg.CITY IS NOT NULL or r_stg.STATE IS NOT NULL or r_stg.POSTAL_CODE IS NOT NULL THEN
                 IF r_stg.ORIG_SYSTEM_ADDRESS_REF IS NULL THEN
                    l_tfm_error := l_tfm_error + 1;
                    xxint_common_pkg.get_error_message(g_error_message_09||':'||r_stg.ADDRESS1||','||r_stg.ADDRESS2||','||r_stg.ADDRESS3||','||r_stg.ADDRESS4, r_error.msg_code, l_message);
                    r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                    raise_error(r_error);
                    fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
                 END IF;
              END IF;
              
              IF check_orig_sys_add_ref(r_stg.orig_system_address_ref) THEN -- Added by Joy Pinto on 31-Aug-2017 FSC-751
                 r_tfm.orig_system_address_ref       :=SUBSTR('CONV'||r_stg.orig_system_address_ref,1,240);                 
              ELSE
                 r_tfm.orig_system_address_ref := r_stg.orig_system_address_ref;
              END IF;
              
              IF check_orig_sys_add_ref(r_tfm.orig_system_address_ref) THEN -- Checking the r_tfm value after prefixing with CONV Joy Pinto 24-Jul-2017
                  r_error.error_token_val1 := 'ORIG_SYS_ADDRESS_REF for site';
                  r_tfm.status := 'ERROR';
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_40, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$ORIG_SYS_ADDRESS_REF', r_tfm.orig_system_address_ref); -- Checking the r_tfm value after prefixing with CONV Joy Pinto 24-Jul-2017
                  raise_error(r_error);
                  fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
               END IF;  
               
              IF check_orig_sys_cust_ref(r_tfm.orig_system_customer_ref) THEN -- Checking the r_tfm value after prefixing with CONV Joy Pinto 24-Jul-2017
                  r_error.error_token_val1 := 'ORIG_SYS_CUSTOMER_REF for Customer';
                  r_tfm.status := 'ERROR';
                  l_tfm_error := l_tfm_error + 1;
                  --xxint_common_pkg.get_error_message(g_error_message_40, r_error.msg_code, l_message);
                  r_error.error_text := 'ORIG SYS CUSTOMER REF '||r_tfm.orig_system_customer_ref||' is already existing for the customer';
                  raise_error(r_error);
                  fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
               END IF;                  

           ELSIF  r_stg.record_action = 'SITE' THEN
           
              r_tfm.orig_system_customer_ref := get_new_cust_orig_sys_ref(r_stg.dtpli_customer_num,r_stg.customer_name);
                         
              IF get_new_cust_orig_sys_ref(r_stg.dtpli_customer_num,r_stg.customer_name) IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||'DTPLI Customer Number '||r_stg.dtpli_customer_num ||' is invalid');
              END IF;              
           
              IF check_orig_sys_add_ref(r_stg.orig_system_address_ref) THEN -- Added by Joy Pinto on 31-Aug-2017 FSC-751
                 r_tfm.orig_system_address_ref       :=SUBSTR('CONV'||r_stg.orig_system_address_ref,1,240);                 
              ELSE
                 r_tfm.orig_system_address_ref := r_stg.orig_system_address_ref;
              END IF;              
                          
              -- Added by Joy Pinto on 24 July 2017 ensure address i sunique by prefixing CONV
             ----------------------------------------------------------------------
             -- 2. Data Validation for Creating A New Site for existing Customer --
             ----------------------------------------------------------------------
               r_error.error_token_val1 := 'STG_CREATE_SITE_ONLY';

               IF r_stg.location IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_28, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
              END IF;

              IF r_stg.ORIG_SYSTEM_ADDRESS_REF IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_31, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
              END IF;

              IF r_stg.industry_type IS NOT NULL THEN
                 IF NOT check_customer_profile_class(r_stg.industry_type) THEN
                    l_tfm_error := l_tfm_error + 1;
                    xxint_common_pkg.get_error_message(g_error_message_35||'. Customer Industry Type : '||r_stg.customer_class_code, r_error.msg_code, l_message);
                    r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                    raise_error(r_error);
                    fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
                 END IF;
              END IF;
              
              IF check_orig_sys_add_ref(r_tfm.orig_system_address_ref) THEN -- Checking the r_tfm value after prefixing with CONV Joy Pinto 24-Jul-2017
                  r_error.error_token_val1 := 'ORIG_SYS_ADDRESS_REF for site';
                  r_tfm.status := 'ERROR';
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_40, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$ORIG_SYS_ADDRESS_REF', r_tfm.orig_system_address_ref); -- Checking the r_tfm value after prefixing with CONV Joy Pinto 24-Jul-2017
                  raise_error(r_error);
                  fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
               END IF;
               
               /*
              IF check_orig_sys_cust_ref(r_tfm.orig_system_customer_ref) THEN -- Checking the r_tfm value after prefixing with CONV Joy Pinto 24-Jul-2017
                  r_error.error_token_val1 := 'ORIG_SYS_CUSTOMER_REF for Customer';
                  r_tfm.status := 'ERROR';
                  l_tfm_error := l_tfm_error + 1;
                  --xxint_common_pkg.get_error_message(g_error_message_40, r_error.msg_code, l_message);
                  r_error.error_text := 'ORIG SYS CUSTOMER REF '||r_tfm.orig_system_customer_ref||' is existing for the customer';
                  raise_error(r_error);
                  fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
               END IF;  
               */

               /* Commented by Joy Pinto on 04-Aug-2017 as per ERPTEST comments
               IF check_address_uniquness(r_stg.dtpli_customer_num,
                                    r_stg.site_use_code,
                                    r_stg.address1,
                                    r_stg.address2,
                                    r_stg.address3,
                                    r_stg.address4) THEN
                  r_error.error_token_val1 := 'ADDRESS DETAIL for site';
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_41, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$ADDRESS', r_stg.address1||','||r_stg.address2||','||r_stg.address3||','||r_stg.address4);
                  raise_error(r_error);
                  fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
               END IF;
               */

          /*ELSIF r_stg.record_action = 'MAPPED' THEN
             CONTINUE;*/
          ELSE

              IF r_stg.record_action = 'NEW' THEN
                 r_error.error_token_val1 := 'CREATE_ALL_INVALID_RECORDS_IN_STG';
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_25, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
              ELSIF r_stg.record_action = 'SITE' THEN
                 r_error.error_token_val1 := 'CREATE_SITE_INVALID_RECORDS_IN_STG';
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_33, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
                 fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
              END IF;

           END IF;

      EXCEPTION
         WHEN others THEN
            r_error.error_token_val1 := 'EXCEPTION_IN_TRANSFORMATION';
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_10||SQLERRM, r_error.msg_code, l_message);
            r_error.msg_code := REPLACE(SQLCODE, '-');
            r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
            raise_error(r_error);
            fnd_file.put_line(fnd_file.log, g_debug ||r_error.error_text);
            RETURN;
            p_retcode := 2;
      END;
            
         IF l_tfm_error > 0 THEN
            l_error_count := l_error_count + 1;
            r_tfm.status := 'ERROR';
         ELSE
            r_tfm.status                         := 'VALIDATED';
         END IF;
         
         -- l_success_count := l_success_count + 1;
         -- Incoming ORIG_SYSTEM customer refs need to be programatically prefixed with "CONV" for both NEW and SITE record types (Rule RCI008)
           /*
           IF r_stg.record_action = 'SITE' THEN -- 07-Sep-2017 Only when the record Type = SITE then derive existing customer number
           
              r_tfm.orig_system_customer_ref := get_new_cust_orig_sys_ref(r_stg.dtpli_customer_num,r_stg.customer_name);
           
           ELSE           
              IF check_orig_sys_cust_ref(r_stg.orig_system_customer_ref) THEN -- Added by Joy Pinto on 31-Aug-2017 FSC-751
                 r_tfm.orig_system_customer_ref	     :=SUBSTR('CONV'||r_stg.orig_system_customer_ref,1,240);              
              ELSE
                 r_tfm.orig_system_customer_ref := r_stg.orig_system_customer_ref;
              END IF; 
           END IF;
           */
           
           r_tfm.site_use_code                  :=SUBSTR(r_stg.site_use_code,1,30);
           r_tfm.location                       :=SUBSTR(r_stg.location,1,40);
           r_tfm.address1                       :=SUBSTR(r_stg.address1,1,240);
           r_tfm.address2                       :=SUBSTR(r_stg.address2,1,240);
           r_tfm.address3                       :=SUBSTR(r_stg.address3,1,240);
           r_tfm.address4                       :=SUBSTR(r_stg.address4,1,240);
           r_tfm.city                           :=SUBSTR(r_stg.city,1,60);
           r_tfm.country                        :=SUBSTR(r_stg.country,1,60);
           r_tfm.state                          :=SUBSTR(r_stg.state,1,60);
           r_tfm.postal_code                    :=SUBSTR(r_stg.postal_code,1,60);
           r_tfm.address_attribute3             :=SUBSTR(r_stg.address_attribute3,1,150);

           r_tfm.record_action	                 :=SUBSTR(r_stg.record_action,1,6);
           r_tfm.customer_name	                 :=SUBSTR(r_stg.customer_name,1,360);
           r_tfm.dsdbi_customer_num             :=SUBSTR(r_stg.dsdbi_customer_num,1,30);
           r_tfm.dtpli_customer_num             :=SUBSTR(r_stg.dtpli_customer_num,1,30);
           r_tfm.abn                            :=SUBSTR(r_stg.abn,1,50);
           r_tfm.customer_class_code            :=SUBSTR(r_stg.customer_class_code,1,30);
           r_tfm.customer_attribute2            :=SUBSTR(r_stg.customer_attribute2,1,150);
           r_tfm.industry_type                  :=SUBSTR(r_stg.industry_type,1,30);
           r_tfm.dsdbi_customer_site_num        :=SUBSTR(r_stg.dsdbi_customer_site_num,1,30);
           r_tfm.dtpli_customer_site_num        :=SUBSTR(r_stg.dtpli_customer_site_num,1,30);
           r_tfm.primary_site_use_flag          :=SUBSTR(r_stg.primary_site_use_flag,1,1);

          IF l_tfm_error = 0 THEN -- Added by Joy Pinto on 08-Sep-2017
             l_success_count := l_success_count + 1;
          END IF;

         r_tfm.created_by := l_user_id;
         r_tfm.creation_date := SYSDATE;

         INSERT INTO fmsmgr.xxar_customer_conversion_tfm
         VALUES r_tfm;

      END LOOP;
      CLOSE c_stage;

      COMMIT;


      IF l_error_count > 0 THEN
         l_int_status := 'ERROR';
      END IF;

      ------------------------------
      -- TRANSFORM: End Run Phase --
      ------------------------------
      dot_common_int_pkg.end_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_status => l_int_status,
          p_error_count => l_error_count,
          p_success_count => l_success_count);

      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework (int_mode=' || l_tfm_mode || ')');
      END IF;

      IF l_error_count > 0 THEN
         RAISE interface_error;
      END IF;

      IF p_int_mode = g_int_mode THEN
      
         SELECT COUNT(1)
         INTO   l_record_count
         FROM   XXAR_CUSTOMER_CONVERSION_TFM
         WHERE  run_id = l_run_id
         AND    run_phase_id = l_run_phase_id;

         ----------------------------
         -- LOAD: Start Run Phase  --
         ----------------------------
         l_run_phase_id := dot_common_int_pkg.start_run_phase
                              (p_run_id                  => l_run_id,
                               p_phase_code              => 'LOAD',
                               p_phase_mode              => g_int_mode,
                               p_int_table_name          => 'XXAR_CUSTOMER_CONVERSION_TFM',
                               p_int_table_key_col1      => 'CUSTOMER_NAME',
                               p_int_table_key_col_desc1 => 'Customer Name',
                               p_int_table_key_col2      => 'DTPLI_CUSTOMER_SITE_NUM',
                               p_int_table_key_col_desc2 => 'Customer Site Number',
                               p_int_table_key_col3      => NULL,
                               p_int_table_key_col_desc3 => NULL);

         /* Debug Log */
         IF l_debug_flag = 'Y' THEN
            fnd_file.put_line(fnd_file.log, g_debug || 'interface framework (run_load_id=' || l_run_phase_id || ')');
         END IF;

         ----------------------------
         -- LOAD: Update Run Phase --
         ----------------------------
         dot_common_int_pkg.update_run_phase
            (p_run_phase_id => l_run_phase_id,
             p_src_code     => g_src_code,
             p_rec_count    => l_record_count,
             p_hash_total   => NULL,
             p_batch_name   => l_file);
             
             
           -------------------------------------
           -- Start Create Customer and Sites --
           -------------------------------------
           run_create_customer_and_site(l_run_id);

          -------------------------------------------------------
          -- Start Create Customer Sites for Existing Customer --
          -------------------------------------------------------

          run_create_site_only(l_run_id);


          l_cust_site_create_req_id := fnd_request.submit_request(application => 'AR',
                                                             program     => 'RACUST',
                                                             description => NULL,
                                                             start_time  => NULL,
                                                             sub_request => FALSE,
                                                             argument1   => 'N');

          COMMIT;

         wait_for_request(l_cust_site_create_req_id, 5);

   /*  update_customer_numbers_temp (l_run_id);

     update_customer_site_num_temp(l_run_id);*/

        creation_results_output( l_run_id,
                        l_run_phase_id ,
                        l_cust_site_create_req_id ,
                        l_file_req_id ,
                        p_source ,
                        l_file,
                        l_delim,
                        write_to_out);
                        
        update_customer_numbers_temp (l_run_id);
   
        COMMIT;
   
        update_customer_site_num_temp(l_run_id);

        COMMIT;   
        
        create_site_profile(l_run_id); -- Added by Joy Pinto on 28-Aug-2017
        
        COMMIT;
        
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := -1;
         l_success_count := 0;
         l_error_count := 0;
         
         SELECT COUNT(1)
         INTO l_success_count
         FROM
         fmsmgr.xxar_customer_conversion_tfm 
         WHERE run_id = l_run_id
         AND STATUS = 'SUCCESS';
         
         SELECT COUNT(1)
         INTO l_error_count
         FROM
         fmsmgr.xxar_customer_conversion_tfm 
         WHERE run_id = l_run_id
         AND STATUS != 'SUCCESS';
         
         IF l_error_count > 0 THEN
            l_int_status := 'ERROR';
         END IF;         

         -------------------------
         -- LOAD: End Run Phase --
         -------------------------
         dot_common_int_pkg.end_run_phase
            (p_run_phase_id => l_run_phase_id,
             p_status => l_int_status,
             p_error_count => l_error_count,
             p_success_count => l_success_count);

         IF l_error_count > 0 THEN
            RAISE interface_error;
         END IF;        
   
        END IF ;-- Only for Validate transfer
        
      l_run_report_id := dot_common_int_pkg.launch_run_report
                              (p_run_id      => l_run_id,
                               p_notify_user => l_user_name);



      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework completion report (request_id=' || l_run_report_id || ')');
      END IF;        
              

   END LOOP;

EXCEPTION
   WHEN interface_error THEN

      l_run_report_id := dot_common_int_pkg.launch_error_report
                        (p_run_id => l_run_id,
                         p_run_phase_id => l_run_phase_id);
                         
      l_run_report_id := dot_common_int_pkg.launch_run_report
                            (p_run_id => l_run_id,
                             p_notify_user => fnd_global.user_name);                         
      COMMIT;
      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework error report (request_id=' || l_run_report_id || ')');
      END IF;

      p_retcode := 2;

END customer_import;

END xxar_customer_conversion_pkg;
/