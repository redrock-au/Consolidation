create or replace PACKAGE BODY xxar_customer_interface_pkg AS
/*$Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/sql/XXAR_CUSTOMER_INTERFACE_PKG.pkb 2810 2017-10-17 03:13:57Z svnuser $*/
/******************************************************************************
**
**  Filename:  xxar_customer_interface_pkg.sql
**
**  Location:
**
**  Purpose:
**
**  Author:
**
**  Date:  01-MAY-2017
**
**  Revision:
**
**  History: Refer to Source Control
**
******************************************************************************/

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

FUNCTION file_format_check (p_source_name VARCHAR2,
                            p_file VARCHAR2)
RETURN BOOLEAN IS
  v_file_format_check DATE;
BEGIN

   SELECT TO_DATE(SUBSTR(P_FILE,length(p_source_name)+11,14),'YYYYMMDDHH24MISS')
   INTO v_file_format_check
   FROM DUAL;

   RETURN TRUE;

EXCEPTION
   WHEN OTHERS THEN
      RETURN FALSE;
END file_format_check;


FUNCTION get_customer_name
(
   p_customer_name  VARCHAR2
)
RETURN NUMBER
IS
   v_exiting   number;

   CURSOR c_cust IS
      SELECT count(*)
      FROM ra_customers
      WHERE UPPER(customer_name) = UPPER(p_customer_name);
BEGIN
   OPEN c_cust;
   FETCH c_cust INTO v_exiting;
   CLOSE c_cust;

   RETURN v_exiting;
END get_customer_name;

FUNCTION get_customer
(
   p_customer_number  VARCHAR2
)
RETURN NUMBER
IS
   v_exiting   number;

   CURSOR c_cust IS
      SELECT count(*)
      FROM ra_customers
      WHERE customer_number = p_customer_number;
BEGIN
   OPEN c_cust;
   FETCH c_cust INTO v_exiting;
   CLOSE c_cust;

   RETURN v_exiting;
END get_customer;


FUNCTION check_orig_add_ref (p_orig_system_reference VARCHAR2)
RETURN BOOLEAN IS
   v_count NUMBER;
BEGIN
   SELECT COUNT(*)
   INTO v_count
   FROM RA_ADDRESSES_ALL
   WHERE ORIG_SYSTEM_REFERENCE = p_orig_system_reference;

   IF v_count >0 THEN
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
   AND UPPER(LOOKUP_CODE) = UPPER(p_customer_class_code);

   IF v_customer_class_count !=1 THEN
      RETURN FALSE;
   ELSE
      RETURN TRUE;
   END IF;
END check_customer_class;

FUNCTION get_customer_class
(
 p_customer_class_code VARCHAR2
)
RETURN VARCHAR2
IS
   o_customer_class_code FND_LOOKUP_VALUES.LOOKUP_CODE%TYPE;
BEGIN
   SELECT LOOKUP_CODE
   INTO o_customer_class_code
   FROM FND_LOOKUP_VALUES
   WHERE LOOKUP_TYPE = 'CUSTOMER CLASS'
   AND UPPER(LOOKUP_CODE) = UPPER(p_customer_class_code);
   RETURN o_customer_class_code;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      RETURN NULL;
END get_customer_class;


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

   IF v_profile_class_count != 1 THEN
      RETURN FALSE;
   ELSE
      RETURN TRUE;
   END IF;
END check_customer_profile_class;

FUNCTION check_special_char
--(v_column VARCHAR2)
RETURN BOOLEAN
IS
   v_count NUMBER;
   v_special_char VARCHAR2(100):='[^]^A-Z^a-z^0-9^[^.^{^}^ ]';
BEGIN
   SELECT COUNT(*)
   INTO v_count
   FROM xxar_customer_interface_stg
   WHERE REGEXP_LIKE(insert_update_flag, v_special_char,'x') OR
   REGEXP_LIKE(customer_class_code, v_special_char ,'x')
;

   IF v_count >0 THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END check_special_char;

FUNCTION check_location(p_location VARCHAR2)
RETURN BOOLEAN
IS
   v_count NUMBER;
BEGIN
   SELECT COUNT(*)
   INTO v_count
   FROM HZ_CUST_SITE_USES_ALL
   WHERE LOCATION = p_location
   AND SITE_USE_CODE = 'BILL_TO';

   IF v_count > 0 THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END check_location;

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
END check_country_code;

FUNCTION check_cust_sys_ref (p_orig_system_reference VARCHAR2)
RETURN BOOLEAN IS
   v_count NUMBER;
BEGIN
   select count(*)
   into v_count
   from ra_customers
   where orig_system_reference = p_orig_system_reference;
      IF v_count>0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
END check_cust_sys_ref;

FUNCTION get_profile_class_name(p_customer_id NUMBER)
RETURN VARCHAR2 IS
   v_customer_profile_class ar_customers_v.profile_class_name%TYPE;
BEGIN
   select profile_class_name
   into v_customer_profile_class
   from ar_customers_v
   where customer_id = p_customer_id;
   RETURN v_customer_profile_class;
END get_profile_class_name;


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


PROCEDURE customer_import
(
   p_errbuff          OUT  VARCHAR2,
   p_retcode          OUT  NUMBER,
   p_source           IN   VARCHAR2,
   p_file_name        IN   VARCHAR2,
   p_control_file     IN   VARCHAR2,
   --p_archive_flag     IN   VARCHAR2,
   p_debug_flag       IN   VARCHAR2,
   p_int_mode         IN   VARCHAR2
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
             REPLACE(insert_update_flag, CHR(13), '' ) insert_update_flag, -- Remove Special Characters such as ^M
             customer_name,
             orig_system_customer_ref,
             customer_number,
             abn,
             orig_system_address_ref,
             customer_site_number,
             location,
             address1,
             address2,
             address3,
             address4,
             country,
             city,
             state,
             postal_code,
             contact_last_name,
             contact_first_name,
             email_address,
             site_status,
             industry_type,
             REPLACE(customer_class_code, CHR(13), '' ) customer_class_code, -- Remove Special Characters such as ^M
             status,
             created_by,
             creation_date
      FROM   fmsmgr.xxar_customer_interface_stg
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
   l_insert_update_flag        VARCHAR2(1);
   l_delim                     VARCHAR2(1) := '|';
   z_file_temp_dir             CONSTANT VARCHAR2(150)  := 'USER_TMP_DIR';
   z_file_temp_path            CONSTANT VARCHAR2(150)  := '/usr/tmp';
   z_file_write                CONSTANT VARCHAR2(1)    := 'w';
   g_staging_directory         VARCHAR2(30)   := 'WORKING';

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
   l_PROCEDURE_name             VARCHAR2(150) := 'xxar_customer_interface_pkg.customer_import';
   l_cust_site_create_req_id    NUMBER;
   v_transmission_method        VARCHAR2(150);
   x_message                    VARCHAR2(1000);
   x_status                     VARCHAR2(1);

   r_int                        c_int%ROWTYPE;
   r_stg                        c_stage%ROWTYPE;
   r_error                      dot_int_run_phase_errors%ROWTYPE;
   r_tfm                        fmsmgr.xxar_customer_interface_tfm%ROWTYPE;
   r_request                    xxint_common_pkg.control_record_type;
   t_files                      xxint_common_pkg.t_files_type;
   r_new_cust_sites_count   NUMBER:= 0;
   v_new_sites_rec_count        NUMBER:= 0;
   v_updated_sites_rec_count    NUMBER:= 0;
   l_new_org_contact_party_id   NUMBER;
   l_new_contact_party_id       NUMBER;

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

   interface_error              EXCEPTION;
   number_error                 EXCEPTION;
   pragma                       EXCEPTION_INIT(number_error, -6502);

   PROCEDURE create_location(p_country IN VARCHAR2,
                             p_address1 IN VARCHAR2,
                             p_address2 IN VARCHAR2,
                             p_address3 IN VARCHAR2,
                             p_address4 IN VARCHAR2,
                             p_city IN VARCHAR2,
                             p_postal_code IN VARCHAR2,
                             p_state IN VARCHAR2,
                             x_location_id OUT NUMBER,
                             p_record_id IN NUMBER
                             )
   IS
      l_location_rec  HZ_LOCATION_V2PUB.LOCATION_REC_TYPE;
     -- x_location_id   NUMBER;
      x_return_status VARCHAR2(300);
      x_msg_count     NUMBER;
      x_msg_data      VARCHAR2(300);

   BEGIN

      l_location_rec.country := p_country;
      l_location_rec.address1 := p_address1;
      l_location_rec.address2 := p_address2;
      l_location_rec.address3 := p_address3;
      l_location_rec.address4 := p_address4;
      l_location_rec.city := p_city;
      l_location_rec.postal_code := p_postal_code;
      l_location_rec.state := p_state;
      l_location_rec.created_by_module  := g_created_by_module;

        hz_location_v2pub.create_location(
                                            p_init_msg_list  =>   fnd_api.g_true,
                                            p_location_rec   =>   l_location_rec,
                                            x_location_id    =>   x_location_id,
                                            x_return_status  =>   x_return_status,
                                            x_msg_count      =>   x_msg_count,
                                            x_msg_data       =>   x_msg_data
                                         );

      IF l_debug_flag = 'Y' THEN
          fnd_file.put_line(fnd_file.log, g_debug || 'Return Status '||x_return_status);
          fnd_file.put_line(fnd_file.log, g_debug || 'Message Count '||x_msg_count);
          fnd_file.put_line(fnd_file.log, g_debug || 'Created Location ID '||x_location_id);
          fnd_file.put_line(fnd_file.log, g_debug || 'Message '||SUBSTR(x_msg_data,1,255));
      END IF;

      IF x_msg_count >0 THEN
         FOR i IN 1..x_msg_count
         LOOP
            fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
            r_error.error_token_val1 := 'API_CREATE_LOCATION';
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_12||'-'||x_msg_data, r_error.msg_code, l_message);
            r_error.record_id := p_record_id;
            r_error.msg_code := REPLACE(SQLCODE, '-');
            r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
            raise_error(r_error);

         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log, g_debug ||'ERROR While creating Location : '|| SQLERRM);

   END create_location;


   PROCEDURE create_party_site(p_party_id IN NUMBER,
                               p_location_id IN NUMBER,
                               p_identifying_address_flag IN VARCHAR2,
                               x_party_site_id OUT NUMBER,
                               p_record_id IN NUMBER)
   IS
      l_party_site_rec              hz_party_site_v2pub.party_site_rec_type;
      x_party_site_number           VARCHAR2(2000);
      x_return_status               VARCHAR2(2000);
      x_msg_count                   NUMBER;
      x_msg_data                    VARCHAR2(2000);
   BEGIN

      l_party_site_rec.party_id :=  p_party_id;
      l_party_site_rec.location_id :=  p_location_id;
      l_party_site_rec.identifying_address_flag :=  p_identifying_address_flag;
      l_party_site_rec.created_by_module := g_created_by_module;

      hz_party_site_v2pub.create_party_site ( p_init_msg_list     => fnd_api.g_true,
                                              p_party_site_rec    => l_party_site_rec,
                                              x_party_site_id     => x_party_site_id,
                                              x_party_site_number => x_party_site_number,
                                              x_return_status     => x_return_status,
                                              x_msg_count         => x_msg_count,
                                              x_msg_data          => x_msg_data);

      IF l_debug_flag = 'Y' THEN
           fnd_file.put_line(fnd_file.log, g_debug || 'Return Status '||x_return_status);
           fnd_file.put_line(fnd_file.log, g_debug || 'Message Count '||x_msg_count);
           fnd_file.put_line(fnd_file.log, g_debug || 'Created Party Site ID '||x_party_site_id);
           fnd_file.put_line(fnd_file.log, g_debug || 'Message '||SUBSTR(x_msg_data,1,255));
      END IF;

      IF x_msg_count >0 THEN
      FOR i IN 1..x_msg_count
          LOOP
            fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
            r_error.error_token_val1 := 'API_CREATE_PARTY_SITE';
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_13||'-'||x_msg_data, r_error.msg_code, l_message);
            r_error.record_id := p_record_id;
            r_error.msg_code := REPLACE(SQLCODE, '-');
            r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
            raise_error(r_error);
          END LOOP;
      END IF;

   EXCEPTION
      WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log,'ERROR While creating Party Site : '|| SQLERRM);
   END create_party_site;

   PROCEDURE create_cust_account_site(p_cust_account_id   IN NUMBER,
                                      p_party_site_id     IN NUMBER,
                                      p_attribute1        IN VARCHAR2,
                                      p_attribute2        IN VARCHAR2,
                                      p_orig_system_reference IN VARCHAR2,
                                      x_cust_acct_site_id OUT NUMBER,
                                      p_record_id         IN NUMBER)
   IS
      l_cust_acct_site_rec          hz_cust_account_site_v2pub.cust_acct_site_rec_type;
      x_return_status               VARCHAR2(300);
      x_msg_count                   NUMBER;
      x_msg_data                    VARCHAR2(300);
   BEGIN

      l_cust_acct_site_rec.cust_account_id :=  p_cust_account_id;
      l_cust_acct_site_rec.party_site_id :=  p_party_site_id;
      l_cust_acct_site_rec.created_by_module := g_created_by_module;
      l_cust_acct_site_rec.attribute1 :=p_attribute1;
      l_cust_acct_site_rec.attribute2 :=p_attribute2;
      l_cust_acct_site_rec.orig_system_reference:=p_orig_system_reference;

      hz_cust_account_site_v2pub.create_cust_acct_site ( p_init_msg_list      => fnd_api.g_true,
                                                         p_cust_acct_site_rec => l_cust_acct_site_rec,
                                                         x_cust_acct_site_id  => x_cust_acct_site_id,
                                                         x_return_status      => x_return_status,
                                                         x_msg_count          => x_msg_count,
                                                         x_msg_data           => x_msg_data);
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'Return Status '||x_return_status);
         fnd_file.put_line(fnd_file.log, g_debug || 'Message Count '||x_msg_count);
         fnd_file.put_line(fnd_file.log, g_debug || 'Created Customer Account Site ID '||x_cust_acct_site_id);
         fnd_file.put_line(fnd_file.log, g_debug || 'Message '||SUBSTR(x_msg_data,1,255));
      END IF;

      IF x_msg_count >0 THEN
         FOR i IN 1..x_msg_count
         LOOP
            fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
            r_error.error_token_val1 := 'API_CREATE_CUST_ACCOUNT_SITE';
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_14||'-'||x_msg_data, r_error.msg_code, l_message);
            r_error.record_id := p_record_id;
            r_error.msg_code := REPLACE(SQLCODE, '-');
            r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
            raise_error(r_error);
         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log,'ERROR While creating Customer Account Site : '|| SQLERRM);
   END create_cust_account_site;


   PROCEDURE create_cust_site_use(p_cust_acct_site_id IN NUMBER,
                                  p_customer_number IN VARCHAR2,
                                  p_orig_system_address_ref IN VARCHAR2,
                                  x_site_use_id OUT NUMBER,
                                  x_return_status OUT VARCHAR2,
                                  p_profile_class_name IN VARCHAR2,
                                  p_location IN VARCHAR2,
                                  p_record_id IN NUMBER)
   IS
      l_customer_site_use_rec hz_cust_account_site_v2pub.cust_site_use_rec_type;
      l_customer_profile_rec  hz_customer_profile_v2pub.customer_profile_rec_type;
      l_profile_class_id      NUMBER;
      l_party_site_no         varchar2(50);
      --x_return_status         varchar2(10);
      x_msg_count             number;
      x_msg_data              varchar2(800);
   BEGIN

      BEGIN
         SELECT profile_class_id
         INTO l_profile_class_id
         FROM hz_cust_profile_classes
         WHERE NAME = NVL(p_profile_class_name,'X');

      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            l_profile_class_id := get_cust_level_profile_class(p_customer_number);
            fnd_file.put_line(fnd_file.log,g_debug ||'l_profile_class_id from customer level : '||l_profile_class_id);
         WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,'Error while getting Profile Class ID from Customer Level');
            fnd_file.put_line(fnd_file.log,SQLERRM);
      END;

        l_customer_site_use_rec.cust_acct_site_id := p_cust_acct_site_id;
        l_customer_site_use_rec.status            := 'A';
        --l_customer_site_use_rec.location          := p_location; -- 29-06-2017 Comment out to avoid Location already exists for this business purpose and customer.
        l_customer_site_use_rec.orig_system_reference  := p_orig_system_address_ref; -- 29-06-2017 Add to maintain the sync between Address and Usage Table
        l_customer_site_use_rec.site_use_code     := 'BILL_TO';
        l_customer_site_use_rec.created_by_module := g_created_by_module;
        l_customer_profile_rec.profile_class_id   := l_profile_class_id;
        l_customer_profile_rec.created_by_module  := g_created_by_module;

        hz_cust_account_site_v2pub.create_cust_site_use
       (
           p_init_msg_list         => fnd_api.g_true,
           p_cust_site_use_rec     => l_customer_site_use_rec,
           p_customer_profile_rec  => l_customer_profile_rec,
           p_create_profile        => fnd_api.g_true,
           p_create_profile_amt    => fnd_api.g_false,
           x_site_use_id           => x_site_use_id,
           x_return_status         => x_return_status,
           x_msg_count             => x_msg_count,
           x_msg_data              => x_msg_data
       );

       IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'Return Status '||x_return_status);
         fnd_file.put_line(fnd_file.log, g_debug || 'Message Count '||x_msg_count);
         fnd_file.put_line(fnd_file.log, g_debug || 'Created Customer Account Site Use ID '||x_site_use_id);
         fnd_file.put_line(fnd_file.log, g_debug || 'New Profile Class ID '||l_profile_class_id);
         fnd_file.put_line(fnd_file.log, g_debug || 'Created Customer Account Site Use CODE '||l_customer_site_use_rec.site_use_code );
         fnd_file.put_line(fnd_file.log, g_debug || 'Message '||SUBSTR(x_msg_data,1,255));
       END IF;

       IF x_msg_count >0 THEN
          FOR i IN 1..x_msg_count
          LOOP
             fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
             fnd_file.put_line(fnd_file.log,'ERROR While creating Customer Account Site Use : '|| SQLERRM);
             r_error.error_token_val1 := 'API_CREATE_CUST_SITE_USE';
             xxint_common_pkg.get_error_message(g_error_message_15||'-'||x_msg_data, r_error.msg_code, l_message);
             r_error.record_id := p_record_id;
             r_error.msg_code := REPLACE(SQLCODE, '-');
             r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
             raise_error(r_error);
          END LOOP;
       END IF;

   EXCEPTION
       WHEN OTHERS THEN
           fnd_file.put_line(fnd_file.log,'OTHERS Exception While creating Customer Account Site Use : '|| SQLERRM);
           raise;

   END create_cust_site_use;

   PROCEDURE create_contact_person(p_first_name IN VARCHAR2,
                                   p_last_name IN VARCHAR2,
                                   x_party_id OUT NUMBER,
                                   p_record_id IN NUMBER)
   IS
      P_CREATE_PERSON_REC   HZ_PARTY_V2PUB.PERSON_REC_TYPE;
      X_PARTY_NUMBER        VARCHAR2 (100);
      X_PROFILE_ID          NUMBER;
      X_RETURN_STATUS       VARCHAR2 (1000);
      X_MSG_COUNT           NUMBER;
      X_MSG_DATA            VARCHAR2 (1000);
   BEGIN

      p_create_person_rec.person_first_name := p_first_name;
      p_create_person_rec.person_last_name := p_last_name;
      p_create_person_rec.created_by_module := g_created_by_module;
      --p_create_person_rec.party_rec.orig_system_reference := '1459891';
      HZ_PARTY_V2PUB.CREATE_PERSON (fnd_api.g_true,
                                    p_create_person_rec,
                                    x_party_id,
                                    x_party_number,
                                    x_profile_id,
                                    x_return_status,
                                    x_msg_count,
                                    x_msg_data);

      IF l_debug_flag = 'Y' THEN
          fnd_file.put_line(fnd_file.log, g_debug || 'Return Status '||x_return_status);
          fnd_file.put_line(fnd_file.log, g_debug || 'Message Count '||x_msg_count);
          fnd_file.put_line(fnd_file.log, g_debug || 'New Party ID '||x_party_id);
          fnd_file.put_line(fnd_file.log, g_debug || 'Message '||SUBSTR(x_msg_data,1,255));
      END IF;

      IF x_msg_count >0 THEN
          FOR i IN 1..x_msg_count
          LOOP
             fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
             fnd_file.put_line(fnd_file.log,'ERROR While Uodating Customer Account Site');
             r_error.error_token_val1 := 'CREATE_CONTACT_PERSON';
             l_tfm_error := l_tfm_error + 1;
             xxint_common_pkg.get_error_message(g_error_message_21||'-'||x_msg_data, r_error.msg_code, l_message);
             r_error.record_id:= p_record_id;
             r_error.msg_code := REPLACE(SQLCODE, '-');
             r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
             raise_error(r_error);
         END LOOP;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
           fnd_file.put_line(fnd_file.log,'ERROR While creating new person for contact : '|| SQLERRM);
   END create_contact_person;

   PROCEDURE create_org_contact (p_subject_party_id IN NUMBER,
                                 p_object_party_id IN NUMBER,
                                 x_party_id OUT NUMBER,
                                 p_record_id IN NUMBER)
   IS

      p_org_contact_rec HZ_PARTY_CONTACT_V2PUB.ORG_CONTACT_REC_TYPE;
      x_org_contact_id NUMBER;
      x_party_rel_id NUMBER;
      x_party_number VARCHAR2(2000);
      x_return_status VARCHAR2(2000);
      x_msg_count NUMBER;
      x_msg_data VARCHAR2(2000);

   BEGIN

      p_org_contact_rec.created_by_module := g_created_by_module;
      p_org_contact_rec.party_rel_rec.subject_id := p_subject_party_id; --> Newly Create Party ID
      p_org_contact_rec.party_rel_rec.subject_type := 'PERSON';
      p_org_contact_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';
      p_org_contact_rec.party_rel_rec.object_id := p_object_party_id;  --> Existing Party That would have an Account
      p_org_contact_rec.party_rel_rec.object_type := 'ORGANIZATION';
      p_org_contact_rec.party_rel_rec.object_table_name := 'HZ_PARTIES';
      p_org_contact_rec.party_rel_rec.relationship_code := 'CONTACT_OF';
      p_org_contact_rec.party_rel_rec.relationship_type := 'CONTACT';
      p_org_contact_rec.party_rel_rec.start_date := SYSDATE;
      hz_party_contact_v2pub.create_org_contact(
                                                fnd_api.g_true,
                                                p_org_contact_rec,
                                                x_org_contact_id,
                                                x_party_rel_id,
                                                x_party_id,
                                                x_party_number,
                                                x_return_status,
                                                x_msg_count,
                                                x_msg_data);
      IF l_debug_flag = 'Y' THEN
          fnd_file.put_line(fnd_file.log, g_debug || 'Return Status '||x_return_status);
          fnd_file.put_line(fnd_file.log, g_debug || 'Message Count '||x_msg_count);
          fnd_file.put_line(fnd_file.log, g_debug || 'New Party Relationship ID '||x_party_rel_id);
          fnd_file.put_line(fnd_file.log, g_debug || 'Message '||SUBSTR(x_msg_data,1,255));
      END IF;

      IF x_msg_count >0 THEN
           FOR i IN 1..x_msg_count
           LOOP
             fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));

             r_error.error_token_val1 := 'CREATE_ORG_CONTACT';
             l_tfm_error := l_tfm_error + 1;
             xxint_common_pkg.get_error_message(g_error_message_22||'-'||x_msg_data, r_error.msg_code, l_message);
             r_error.msg_code := REPLACE(SQLCODE, '-');
             r_error.record_id := p_record_id;
             r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
             raise_error(r_error);
          END LOOP;
       END IF;
   EXCEPTION
      WHEN OTHERS THEN
           fnd_file.put_line(fnd_file.log,'ERROR While Creating ORG Contact: '|| SQLERRM);
   END create_org_contact;

   PROCEDURE create_cust_account_role (p_party_id IN NUMBER,
                                       p_cust_account_id IN NUMBER,
                                       p_cust_acct_site_id IN NUMBER,
                                       p_record_id IN NUMBER)
   IS
      p_cr_cust_acc_role_rec HZ_CUST_ACCOUNT_ROLE_V2PUB.cust_account_role_rec_type;
      x_cust_account_role_id NUMBER;
      x_return_status VARCHAR2(2000);
      x_msg_count NUMBER;
      x_msg_data VARCHAR2(2000);

   BEGIN

      p_cr_cust_acc_role_rec.party_id := p_party_id;
      p_cr_cust_acc_role_rec.cust_account_id := p_cust_account_id;
      p_cr_cust_acc_role_rec.cust_acct_site_id := p_cust_acct_site_id;
      p_cr_cust_acc_role_rec.primary_flag := 'N';
      p_cr_cust_acc_role_rec.role_type := 'CONTACT';
      p_cr_cust_acc_role_rec.created_by_module := g_created_by_module;

      HZ_CUST_ACCOUNT_ROLE_V2PUB.create_cust_account_role(
                                                          fnd_api.g_true,
                                                          p_cr_cust_acc_role_rec,
                                                          x_cust_account_role_id,
                                                          x_return_status,
                                                          x_msg_count,
                                                          x_msg_data);
     IF l_debug_flag = 'Y' THEN
        fnd_file.put_line(fnd_file.log, g_debug || 'Return Status '||x_return_status);
        fnd_file.put_line(fnd_file.log, g_debug || 'Message Count '||x_msg_count);
        fnd_file.put_line(fnd_file.log, g_debug || 'New Customer account role ID '||x_cust_account_role_id);
        fnd_file.put_line(fnd_file.log, g_debug || 'Message '||SUBSTR(x_msg_data,1,255));
     END IF;

     IF x_msg_count >0 THEN
        FOR i IN 1..x_msg_count
           LOOP
              fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
              fnd_file.put_line(fnd_file.log,'ERROR While Creating Customer Account Role');
              r_error.error_token_val1 := 'CREATE_CUST_ACCOUNT_ROLE';
              l_tfm_error := l_tfm_error + 1;
              xxint_common_pkg.get_error_message(g_error_message_23||'-'||x_msg_data, r_error.msg_code, l_message);
              r_error.record_id := p_record_id;
              r_error.msg_code := REPLACE(SQLCODE, '-');
              r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
              raise_error(r_error);
          END LOOP;
       END IF;
   EXCEPTION
      WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log,'ERROR While Creating Customer Account Role: '|| SQLERRM);

   END create_cust_account_role;

   PROCEDURE update_cust_acct_site(p_party_site_number IN VARCHAR2,
                                   p_status IN VARCHAR2,
                                   p_attribute1 IN VARCHAR2,
                                   p_attribute2 IN VARCHAR2,
                                   p_record_id IN NUMBER)
   IS l_init_msg_list            VARCHAR2 (1000) := FND_API.G_TRUE;
       l_cust_acct_site_rec      HZ_CUST_ACCOUNT_SITE_V2PUB.cust_acct_site_rec_type;
       x_return_status           VARCHAR2 (1000);
       l_object_version_number   NUMBER;
       x_msg_count               NUMBER;
       x_msg_data                VARCHAR2 (1000);
       p_cust_acct_site_id       NUMBER;
       p_object_version_number   NUMBER;
    BEGIN

       BEGIN
          SELECT hcas.cust_acct_site_id,
                 hcas.object_version_number
          INTO p_cust_acct_site_id,
               p_object_version_number
          FROM hz_cust_acct_sites_all hcas,
               hz_party_sites hps
          WHERE hcas.party_site_id=hps.party_site_id
          AND party_site_number = p_party_site_number;
       EXCEPTION
          WHEN NO_DATA_FOUND THEN
             fnd_file.put_line(fnd_file.log,SQLERRM);
             fnd_file.put_line(fnd_file.log,'The Party Site number '||p_party_site_number||' is not existing');
             r_error.error_token_val1 := 'LOOKUP_PARY_SITE';
             l_tfm_error := l_tfm_error + 1;
             xxint_common_pkg.get_error_message(g_error_message_18||'Party Site number :'||p_party_site_number, r_error.msg_code, l_message);
             r_error.msg_code := REPLACE(SQLCODE, '-');
             r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
             raise_error(r_error);
       END;
         l_object_version_number:=p_object_version_number;
         l_cust_acct_site_rec.cust_acct_site_id := p_cust_acct_site_id;
         l_cust_acct_site_rec.status := p_status;
         l_cust_acct_site_rec.attribute1 := p_attribute1;
         l_cust_acct_site_rec.attribute2 := NVL(p_attribute2,FND_API.G_MISS_CHAR);

       hz_cust_account_site_v2pub.update_cust_acct_site (fnd_api.g_true,
                                                         l_cust_acct_site_rec,
                                                         l_object_version_number,
                                                         x_return_status,
                                                         x_msg_count,
                                                         x_msg_data);

      IF l_debug_flag = 'Y' THEN
          fnd_file.put_line(fnd_file.log, g_debug || 'Return Status '||x_return_status);
          fnd_file.put_line(fnd_file.log, g_debug || 'Message Count '||x_msg_count);
          fnd_file.put_line(fnd_file.log, g_debug || 'Updated Customer Account Site ID '||p_cust_acct_site_id);
          fnd_file.put_line(fnd_file.log, g_debug || 'Message '||SUBSTR(x_msg_data,1,255));
      END IF;

      IF x_msg_count >0 THEN
        FOR i IN 1..x_msg_count
        LOOP
           fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
           fnd_file.put_line(fnd_file.log,'ERROR While Uodating Customer Account Site');

           r_error.error_token_val1 := 'UPDATE_CUST_ACCT_SITE';
           l_tfm_error := l_tfm_error + 1;
           xxint_common_pkg.get_error_message(g_error_message_16||'-'||x_msg_data, r_error.msg_code, l_message);
           r_error.record_id := p_record_id;
           r_error.msg_code := REPLACE(SQLCODE, '-');
           r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
           raise_error(r_error);
        END LOOP;
     END IF;
   EXCEPTION
     WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log,'ERROR While Uodating Customer Account Site : '|| SQLERRM);
   END update_cust_acct_site;

   PROCEDURE update_location(p_party_site_number IN VARCHAR2,
                             p_address1 IN VARCHAR2,
                             p_address2 IN VARCHAR2,
                             p_address3 IN VARCHAR2,
                             p_address4 IN VARCHAR2,
                             p_country IN VARCHAR2,
                             p_city IN VARCHAR2,
                             p_state IN VARCHAR2,
                             p_postal_code IN VARCHAR2,
                             p_record_id IN NUMBER)
   IS l_location_rec          HZ_LOCATION_V2PUB.LOCATION_REC_TYPE;
      p_object_version_number NUMBER;
      x_return_status         VARCHAR2(2000);
      x_msg_count             NUMBER;
      x_msg_data              VARCHAR2(2000);
      p_location_id           NUMBER;
   BEGIN

       BEGIN
           SELECT hl.location_id,
                  hl.object_version_number
           INTO p_location_id,
                p_object_version_number
           FROM hz_party_sites hps,
                hz_locations hl
           where hps.location_id = hl.location_id
           and hps.party_site_number = p_party_site_number;
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
            fnd_file.put_line(fnd_file.log,SQLERRM);
            fnd_file.put_line(fnd_file.log,'The Location for Party Site number '||p_party_site_number||' is not existing');
            r_error.error_token_val1 := 'LOOKUP_LOCATION';
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_19||p_party_site_number, r_error.msg_code, l_message);
            r_error.msg_code := REPLACE(SQLCODE, '-');
            r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
            raise_error(r_error);
       END;

       l_location_rec.location_id := p_location_id;

       IF p_address1 IS NULL THEN
           r_error.error_token_val1 := 'UPDATE_LOCATION';
           r_error.error_token_val2 := 'ADDRESS1_CHECK';
           l_tfm_error := l_tfm_error + 1;
           xxint_common_pkg.get_error_message(g_error_message_20||'-'||x_msg_data, r_error.msg_code, l_message);
           r_error.msg_code := REPLACE(SQLCODE, '-');
           r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
           raise_error(r_error);
       END IF;

         l_location_rec.address1    := nvl(p_address1,FND_API.G_MISS_CHAR);
         l_location_rec.address2    := nvl(p_address2,FND_API.G_MISS_CHAR);
         l_location_rec.address3    := nvl(p_address3,FND_API.G_MISS_CHAR);
         l_location_rec.address4    := nvl(p_address4,FND_API.G_MISS_CHAR);
         l_location_rec.country     := nvl(p_country,FND_API.G_MISS_CHAR);
         l_location_rec.city        := nvl(p_city,FND_API.G_MISS_CHAR);
         l_location_rec.state       := nvl(p_state,FND_API.G_MISS_CHAR);
         l_location_rec.postal_code := nvl(p_postal_code,FND_API.G_MISS_CHAR);
         hz_location_v2pub.update_location
                    (
                     p_init_msg_list                  => fnd_api.g_true,
                     p_location_rec                   => l_location_rec,
                     p_object_version_number          => p_object_version_number,
                     x_return_status                  => x_return_status,
                     x_msg_count                      => x_msg_count,
                     x_msg_data                       => x_msg_data
                          );

       IF l_debug_flag = 'Y' THEN
          fnd_file.put_line(fnd_file.log, g_debug || 'Updated location Return Status '||x_return_status);
          fnd_file.put_line(fnd_file.log, g_debug || 'Update location Message Count '||x_msg_count);
          fnd_file.put_line(fnd_file.log, g_debug || 'Updated Location ID is :'||p_location_id);
          fnd_file.put_line(fnd_file.log, g_debug || 'Message '||SUBSTR(x_msg_data,1,255));
       END IF;

     IF x_msg_count >0 THEN
         FOR i IN 1..x_msg_count
         LOOP
            fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
            fnd_file.put_line(fnd_file.log,'ERROR While Uodating Location');

            r_error.error_token_val1 := 'UPDATE_LOCATION';
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_17||'-'||x_msg_data, r_error.msg_code, l_message);
            r_error.record_id := p_record_id;
            r_error.msg_code := REPLACE(SQLCODE, '-');
            r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
            raise_error(r_error);
         END LOOP;
      END IF;
   EXCEPTION
     WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log,'ERROR While Uodating Location : '|| SQLERRM);
   END update_location;

   PROCEDURE update_cust_site_use_status(p_site_number IN VARCHAR2,
                                         p_cust_site_use_status IN VARCHAR2,
                                         p_record_id IN NUMBER)
   IS

          x_return_status         varchar2(10);
          x_msg_count             number(10);
          x_msg_data              varchar2(1200);
          v_object_version_number number(10);
          v_site_use_id           hz_cust_site_uses_all.site_use_id%TYPE;
          v_cust_acct_site_id     hz_cust_site_uses_all.cust_acct_site_id%TYPE;
          P_CUST_SITE_USE_REC     hz_cust_account_site_v2pub.CUST_SITE_USE_REC_TYPE;

   BEGIN
      SELECT hcu.site_use_id,
          hcu.cust_acct_site_id,
          hcu.object_version_number
      INTO v_site_use_id,
           v_cust_acct_site_id,
           v_object_version_number
      FROM hz_cust_acct_sites_all hcas,
           hz_cust_site_uses_all hcu,
           hz_party_sites hps
      WHERE hcas.party_site_id=hps.party_site_id
      AND hcu.cust_acct_site_id = hcas.cust_acct_site_id
      AND hcu.site_use_code = 'BILL_TO'
      AND party_site_number = p_site_number;


      P_CUST_SITE_USE_REC.site_use_id:=v_site_use_id;
      P_CUST_SITE_USE_REC.status:= p_cust_site_use_status;
      P_CUST_SITE_USE_REC.cust_acct_site_id :=v_cust_acct_site_id;
      P_CUST_SITE_USE_REC.CREATED_BY_MODULE := 'TCA_V2_API';

      hz_cust_account_site_v2pub.update_cust_site_use
      (
         p_init_msg_list             => 'T',
         P_CUST_SITE_USE_REC         => P_CUST_SITE_USE_REC,
         p_object_version_number     => v_object_version_number,
         x_return_status             => x_return_status,
         x_msg_count                 => x_msg_count ,
         x_msg_data                  => x_msg_data
      );
      IF x_msg_count >0 THEN
         FOR i IN 1..x_msg_count
         LOOP
            fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
            fnd_file.put_line(fnd_file.log,'ERROR While Uodating Customer Account Site Use Status');
            r_error.error_token_val1 := 'UPDATE_CUST_SITE_USE_STATUS';
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_41||'-'||x_msg_data, r_error.msg_code, l_message);
            r_error.record_id := p_record_id;
            r_error.msg_code := REPLACE(SQLCODE, '-');
            r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
            raise_error(r_error);
         END LOOP;
      END IF;
   EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,' Error Here'||sqlcode||sqlerrm);
   END update_cust_site_use_status;


   PROCEDURE update_cust_site_prof_class(p_site_number IN VARCHAR2,
                                      p_new_profile_class_name IN VARCHAR2,
                                      p_record_id IN NUMBER)
   IS
      x_return_status         varchar2(10);
      x_msg_count             number(10);
      x_msg_data              varchar2(1200);
      v_object_version_number number(10);
      v_customer_profile_rec_type   hz_customer_profile_v2pub.customer_profile_rec_type;
      v_latest_ver_num              NUMBER;
      v_new_profile_class_id        NUMBER;
      v_cust_account_profile_id     NUMBER;
      v_cust_account_id             NUMBER;
      v_site_use_id                 hz_cust_site_uses_all.site_use_id%TYPE;
   BEGIN
      BEGIN
         SELECT cust_account_profile_id,
              hcas.cust_account_id,
              hcu.site_use_id
         INTO   v_cust_account_profile_id,
              v_cust_account_id,
              v_site_use_id
         FROM hz_cust_acct_sites_all hcas,
              hz_cust_site_uses_all hcu,
              hz_party_sites hps,
              hz_customer_profiles hcp
         WHERE hcas.party_site_id=hps.party_site_id
         AND hcu.cust_acct_site_id = hcas.cust_acct_site_id
         AND hcp.site_use_id = hcu.site_use_id
         AND hcas.cust_account_id = hcp.cust_account_id
         AND hcu.site_use_code = 'BILL_TO'
         AND party_site_number = p_site_number;
      EXCEPTION
         WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,'STEP 1 : ERROR While Uodating Profile Class '||SQLERRM);
      END;

      BEGIN
         SELECT profile_class_id
         INTO v_new_profile_class_id
         FROM  hz_cust_profile_classes
         WHERE upper(name) = upper(p_new_profile_class_name);
      EXCEPTION
         WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log,'STEP 2 : ERROR While Uodating Profile Class'||SQLERRM);
      END;


   v_customer_profile_rec_type.cust_account_profile_id := v_cust_account_profile_id;
   v_customer_profile_rec_type.cust_account_id := v_CUST_ACCOUNT_ID;
   v_customer_profile_rec_type.site_use_id := v_site_use_id;
   v_customer_profile_rec_type.profile_class_id := v_new_profile_class_id;

      SELECT   object_version_number
      INTO     v_latest_ver_num
      FROM     hz_customer_profiles
      WHERE    cust_account_profile_id = v_customer_profile_rec_type.cust_account_profile_id;

      hz_customer_profile_v2pub.update_customer_profile
           ( p_init_msg_list                  => fnd_api.g_true,
             p_customer_profile_rec          => v_customer_profile_rec_type,
            p_object_version_number       => v_latest_ver_num,
            x_return_status               => x_return_status,
            x_msg_count                   => x_msg_count,
            x_msg_data                    => x_msg_data
         );

      IF l_debug_flag = 'Y' THEN
          fnd_file.put_line(fnd_file.log, 'Return Status '||x_return_status);
          fnd_file.put_line(fnd_file.log, 'Message Count '||x_msg_count);
          fnd_file.put_line(fnd_file.log, 'Message '||SUBSTR(x_msg_data,1,255));
      END IF;

      IF x_msg_count >0 THEN
        FOR i IN 1..x_msg_count
        LOOP
           fnd_file.put_line(fnd_file.log,i||'.'||SUBSTR(fnd_msg_pub.get(p_encoded=>FND_API.G_FALSE),1,255));
           fnd_file.put_line(fnd_file.log,'ERROR While Updating Profile for Customer Account Site');
           r_error.error_token_val1 := 'UPDATE_CUST_SITE_PROFILE_CLASS';
           l_tfm_error := l_tfm_error + 1;
           xxint_common_pkg.get_error_message(g_error_message_45||'-'||x_msg_data, r_error.msg_code, l_message);
           r_error.record_id := p_record_id;
           r_error.msg_code := REPLACE(SQLCODE, '-');
           r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
           raise_error(r_error);
        END LOOP;
     END IF;
   EXCEPTION
     WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.log,'ERROR While Updating Profile for Customer Account Site : '|| SQLERRM);
   END update_cust_site_prof_class;


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
      p_write_to_out     BOOLEAN,
      x_success_count   OUT NUMBER, --FSC-3819
      x_error_count    OUT NUMBER   --FSC-3819
   )
   IS
      CURSOR c_processed_records IS
         -- Retrieve newly Created Customer and Site
         SELECT 'CREATE' record_action,
                null record_id,
                rc.orig_system_reference orig_system_customer_ref,
                rc.customer_number customer_number,
                rc.customer_name customer_name,
                radd.orig_system_reference orig_system_address_ref,
                hps.party_site_number customer_site_number,
                hcsu.location location,
                hps.creation_date creation_date,
                hps.last_update_date last_update_date,
                'Success' oracle_processing_status,
                '' error_comments
         FROM ra_customers rc,
              hz_parties hp,
              hz_party_sites hps,
              hz_cust_site_uses_all hcsu,
              hz_cust_acct_sites_all hcas,
              xxar_customer_interface_tfm tfm,
              ra_addresses_all radd
         WHERE hp.party_id = hps.party_id
         AND hp.party_id = rc.party_id
         AND hcsu.site_use_code ='BILL_TO'
         AND hps.party_site_id = hcas.party_site_id
         AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
         AND TFM.CUSTOMER_NAME = rc.CUSTOMER_NAME
         AND rc.request_id = hps.request_id
         AND tfm.insert_update_flag = 'I'
         and radd.party_id = hp.party_id
         and radd.party_site_id = hps.party_site_id
         and radd.ORIG_SYSTEM_REFERENCE = TFM.ORIG_SYSTEM_ADDRESS_REF
         and RC.ORIG_SYSTEM_REFERENCE = TFM.ORIG_SYSTEM_CUSTOMER_REF
         AND rc.request_id = nvl(p_request_id,0)
         UNION ALL
         -- Retrieve newly Created Site
         SELECT 'CREATE' record_action,
            null record_id,
            rc.orig_system_reference orig_system_customer_ref,
            rc.customer_number customer_number,
            rc.customer_name customer_name,
            ra.orig_system_reference orig_system_address_ref,
            hps.party_site_number customer_site_number,
            hcsu.location location,
            hps.creation_date creation_date,
            hps.last_update_date last_update_date,
            'Success' oracle_processing_status,
            ' ' error_comments
         FROM ra_customers rc,
              ra_addresses_all RA,
              hz_parties hp,
              hz_party_sites hps,
              hz_cust_site_uses_all hcsu,
              hz_cust_acct_sites_all hcas,
              fnd_concurrent_requests fcr,
              xxar_customer_interface_tfm tfm
         WHERE hp.party_id = hps.party_id
         AND hp.party_id = rc.party_id
         AND hcsu.site_use_code ='BILL_TO'
         AND hps.party_site_id = hcas.party_site_id
         AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
         AND hps.request_id = fcr.parent_request_id
         AND TFM.CUSTOMER_NUMBER = rc.CUSTOMER_NUMBER
         AND tfm.orig_system_address_ref = ra.orig_system_reference
         AND RA.PARTY_ID = hp.party_id
         AND RA.party_site_id  = hps.party_site_id
         AND tfm.insert_update_flag = 'I'
         AND fcr.request_id = p_file_req_id
         UNION ALL
         -- Retrieve Updated Site
         SELECT 'UPDATE' record_action,
            null record_id,
            rc.orig_system_reference orig_system_customer_ref,
            rc.customer_number customer_number,
            rc.customer_name customer_name,
            ra.orig_system_reference orig_system_address_ref,
            hps.party_site_number customer_site_number,
            hcsu.location location,
            rc.creation_date creation_date,
            rc.last_update_date last_update_date,
            'Success' oracle_processing_status,
            '' error_comments
         FROM ra_customers rc,
              hz_parties hp,
              hz_party_sites hps,
              hz_cust_acct_sites_all hcas,
              hz_cust_site_uses_all hcsu,
              fnd_concurrent_requests fcr,
              xxar_customer_interface_tfm tfm,
              ra_addresses_all RA
         WHERE hp.party_id = hps.party_id
         AND hp.party_id = rc.party_id
         AND hps.party_site_id = hcas.party_site_id
         AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
         AND hcsu.site_use_code ='BILL_TO'
         AND HCAS.request_id = fcr.parent_request_id
         --AND hps.request_id != hcas.request_id
         --AND TFM.CUSTOMER_NUMBER = rc.CUSTOMER_NUMBER
         AND TFM.CUSTOMER_SITE_NUMBER = hps.PARTY_SITE_NUMBER
         and tfm.insert_update_flag = 'U'
         AND RA.PARTY_ID = hp.party_id
         AND RA.party_site_id  = hps.party_site_id
         AND fcr.request_id = p_file_req_id;

         CURSOR c_stuck_records IS
         SELECT distinct stg.insert_update_flag record_action,
                tfm.record_id record_id,
                stg.orig_system_customer_ref orig_system_customer_ref,
                stg.customer_number customer_number,
                stg.customer_name customer_name,
                stg.orig_system_address_ref orig_system_address_ref,
                stg.customer_site_number customer_site_number,
                stg.location location,
                stg.creation_date creation_date,
                stg.creation_date last_update_date,
                decode(err.error_text,NULL,tfm.status,'ERROR') oracle_processing_status,
                '' error_comments
         FROM fmsmgr.xxar_customer_interface_tfm tfm,
              fmsmgr.xxar_customer_interface_stg stg,
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

   l_file              VARCHAR2(150);
   l_outbound_path     VARCHAR2(150);
   l_text              VARCHAR2(32767);
   l_code              VARCHAR2(15);
   l_message           VARCHAR2(4000);
   r_processed_records     c_processed_records%ROWTYPE;
   r_stuck_records         c_stuck_records%ROWTYPE;
   f_handle            utl_file.file_type;
   f_copy              INTEGER;
   print_error         EXCEPTION;

   CURSOR error_check_c IS
      SELECT tfm.record_id record_id,
             decode(err.error_text,NULL,tfm.status,'ERROR') oracle_processing_status,
             REPLACE(RTRIM(err.error_text),'"','') error_comments
      FROM fmsmgr.xxar_customer_interface_tfm tfm,
           fmsmgr.xxar_customer_interface_stg stg,
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
      v_error_count   NUMBER := 0;
      v_success_count NUMBER := 0;

   BEGIN


      --l_file := p_source|| '_CUSTOMER_' ||to_char(sysdate,'YYYYMMDDHH24MMSS_') || NVL(p_request_id, l_file_req_id) || '.out';
      l_file := REPLACE(p_file,'.txt','')||'_' || NVL(p_request_id, l_file_req_id) || '.out';
      f_handle := utl_file.fopen(z_file_temp_dir, l_file, z_file_write);
      l_outbound_path := xxint_common_pkg.interface_path(p_application => l_appl_short_name,
                                                      p_source => p_source,
                                                      p_in_out => 'OUTBOUND',
                                                      p_message => l_message);


      IF l_message IS NOT NULL THEN
         RAISE print_error;
      END IF;

      BEGIN
         SELECT COUNT(*)
         INTO  v_error_count
         FROM xxar_customer_interface_tfm
         WHERE STATUS != 'VALIDATED'
         AND run_id = p_run_id;
         
         x_error_count := v_error_count;
      END;

      IF v_error_count >0 THEN
         OPEN c_stuck_records;
         LOOP
            FETCH c_stuck_records INTO r_stuck_records;
            EXIT WHEN c_stuck_records%NOTFOUND;

            l_message := NULL;
            IF r_processed_records.oracle_processing_status = 'ERROR' AND r_processed_records.record_id IS NOT NULL THEN
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
             o_error_text := NULL;

             v_record_id  := r_stuck_records.record_id;
             FOR error_check_r IN error_check_c LOOP
                IF v_record_id = error_check_r.record_id then
                   IF o_error_text IS NOT NULL THEN
                  --o_error_text:= error_check_r.error_comments||' - '||o_error_text;
                      o_error_text:= error_check_r.error_comments||' - '||o_error_text;
                   ELSE
                      o_error_text:= error_check_r.error_comments||o_error_text;
                   END IF;
                END IF;
             END LOOP;

             v_record_id  := -1;

             l_text := NULL;
             l_text := l_text || r_stuck_records.record_action || p_delim;
             l_text := l_text || r_stuck_records.orig_system_customer_ref || p_delim;
             l_text := l_text || r_stuck_records.customer_number || p_delim;
             l_text := l_text || r_stuck_records.customer_name || p_delim;
             l_text := l_text || r_stuck_records.orig_system_address_ref || p_delim; -- Added by Joy Pinto 16-Aug-2017
             l_text := l_text || r_stuck_records.customer_site_number || p_delim;
             l_text := l_text || r_stuck_records.location || p_delim;
             l_text := l_text || r_stuck_records.creation_date || p_delim;
             l_text := l_text || r_stuck_records.last_update_date || p_delim;
             l_text := l_text || r_stuck_records.oracle_processing_status || p_delim;
             l_text := l_text || o_error_text;--r_processed_records.error_comments;

             utl_file.put_line(f_handle, l_text);


         IF p_write_to_out THEN
            fnd_file.put_line(fnd_file.output, l_text);
         END IF;

         END LOOP;
         CLOSE c_stuck_records;
      ELSE
         OPEN c_processed_records;
         LOOP
            FETCH c_processed_records INTO r_processed_records;
            EXIT WHEN c_processed_records%NOTFOUND;
            v_success_count := v_success_count+1;
            l_message := NULL;
            IF r_processed_records.oracle_processing_status = 'ERROR' AND r_processed_records.record_id IS NOT NULL THEN
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
         l_text := l_text || r_processed_records.orig_system_address_ref || p_delim; -- Added by Joy Pinto 16-Aug-2017
         l_text := l_text || r_processed_records.customer_site_number || p_delim;
         l_text := l_text || r_processed_records.location || p_delim;
         l_text := l_text || r_processed_records.creation_date || p_delim;
         l_text := l_text || r_processed_records.last_update_date || p_delim;
         l_text := l_text || r_processed_records.oracle_processing_status || p_delim;
         l_text := l_text || o_error_text;--r_processed_records.error_comments;

      utl_file.put_line(f_handle, l_text);

      IF p_write_to_out THEN
         fnd_file.put_line(fnd_file.output, l_text);
      END IF;

      END LOOP;
      CLOSE c_processed_records;
      x_success_count := v_success_count;
   END IF;

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
            orig_system_customer_ref,
            customer_name,
            abn,
            orig_system_address_ref,
            address1,
            address2,
            address3,
            address4,
            city,
            state,
            country,
            postal_code,
            insert_update_flag,
            email_address,
            NVL(industry_type,'NON GOVERNMENT'),
            l_user_id last_updated_by,
            SYSDATE last_update_date,
            l_user_id created_by,
            SYSDATE creation_date,
            customer_number,
            location,
            customer_class_code,
            l_org_id,
            contact_last_name,
            contact_first_name
        FROM fmsmgr.xxar_customer_interface_tfm
        WHERE insert_update_flag = 'I'
        AND customer_name IS NOT NULL
        AND orig_system_customer_ref IS NOT NULL
        AND customer_number IS NULL
        AND customer_site_number IS NULL
        AND status = 'VALIDATED'
        AND run_id = p_run_id;

        r_new_cust_sites         c_new_cust_sites%ROWTYPE;

        CURSOR c_create_customer_site_prof IS
        SELECT DISTINCT insert_update_flag,
           orig_system_customer_ref,
           NULL orig_system_address_ref,
           NVL(INDUSTRY_TYPE,'NON GOVERNMENT') INDUSTRY_TYPE
        FROM fmsmgr.xxar_customer_interface_tfm
        WHERE insert_update_flag = 'I'
        AND customer_name IS NOT NULL
        AND orig_system_customer_ref IS NOT NULL
        AND customer_number IS NULL
        AND customer_site_number IS NULL
        AND status = 'VALIDATED'
        AND run_id = p_run_id
        UNION ALL
        SELECT insert_update_flag,
             orig_system_customer_ref,
             orig_system_address_ref,
             NVL(INDUSTRY_TYPE,'NON GOVERNMENT') INDUSTRY_TYPE
        FROM fmsmgr.xxar_customer_interface_tfm
        WHERE insert_update_flag = 'I'
        AND customer_name IS NOT NULL
        AND orig_system_customer_ref IS NOT NULL
        AND customer_number IS NULL
        AND customer_site_number IS NULL
        AND status = 'VALIDATED'
	    	AND run_id = p_run_id;

        r_create_customer_site_prof    c_create_customer_site_prof%ROWTYPE;

    BEGIN
        r_new_cust_sites_count := 0;
        /* Debug Log */

        OPEN c_new_cust_sites;
        LOOP
           FETCH c_new_cust_sites INTO r_new_cust_sites;
           EXIT WHEN c_new_cust_sites%NOTFOUND;
        --FOR new_cust_sites_rec IN c_new_cust_sites LOOP
            r_new_cust_sites_count := r_new_cust_sites_count+1;

            IF r_new_cust_sites.email_address IS NOT NULL THEN
               v_transmission_method := 'EMAIL';
            ELSE
               v_transmission_method := 'PRINT';
            END IF;

            INSERT INTO ar.ra_customers_interface_all
               (orig_system_customer_ref,
               site_use_code,
               primary_site_use_flag,
               customer_name,
               cust_tax_reference,
               orig_system_address_ref,
               address1,
               address2,
               address3,
               address4,
               city,
               state,
               country,
               postal_code,
               insert_update_flag,
               address_attribute1,
               address_attribute2,
               last_updated_by,
               last_update_date,
               created_by,
               creation_date,
               customer_number,
               customer_status,
               location,
               customer_class_code,
               org_id)
            VALUES
              (r_new_cust_sites.orig_system_customer_ref,
               'BILL_TO',
               'N',
               r_new_cust_sites.customer_name,
               r_new_cust_sites.abn,--Customer tax registration number
               r_new_cust_sites.orig_system_address_ref,
               r_new_cust_sites.address1,
               r_new_cust_sites.address2,
               r_new_cust_sites.address3,
               r_new_cust_sites.address4,
               r_new_cust_sites.city,
               r_new_cust_sites.state,
               r_new_cust_sites.country,
               r_new_cust_sites.postal_code,
               r_new_cust_sites.insert_update_flag,
               v_transmission_method,
               r_new_cust_sites.email_address,
               l_user_id,
               SYSDATE,
               l_user_id,
               SYSDATE,
               r_new_cust_sites.customer_number,
               'A',
               NULL, -- As system option Automatic Site Numbering is set to Yes
               r_new_cust_sites.customer_class_code,
               l_org_id);


        IF r_new_cust_sites.contact_last_name IS NOT NULL OR r_new_cust_sites.contact_first_name IS NOT NULL THEN

            INSERT INTO ar.ra_contact_phones_int_all
               (orig_system_customer_ref
               ,orig_system_address_ref
               ,orig_system_contact_ref
               ,insert_update_flag
               ,contact_first_name
               ,contact_last_name
               ,last_update_date
               ,last_updated_by
               ,creation_date
               ,created_by
               ,org_id
               )
            VALUES
              ( r_new_cust_sites.orig_system_customer_ref,
                r_new_cust_sites.orig_system_address_ref,
                r_new_cust_sites.orig_system_customer_ref, -- Put orig_system_address_ref, as orig_system_contact_ref is not provided via the File Transfer
                r_new_cust_sites.insert_update_flag,
                r_new_cust_sites.contact_first_name,
                r_new_cust_sites.contact_last_name,
                SYSDATE,
                l_user_id,
                SYSDATE,
                l_user_id,
                l_org_id);


        END IF;

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
               (r_create_customer_site_prof.insert_update_flag,
                r_create_customer_site_prof.orig_system_customer_ref,
                r_create_customer_site_prof.orig_system_address_ref,
                r_create_customer_site_prof.industry_type,
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

        IF r_new_cust_sites_count > 0 THEN
           l_cust_site_create_req_id := fnd_request.submit_request(application => 'AR',
                                              program     => 'RACUST',
                                              description => NULL,
                                              start_time  => NULL,
                                              sub_request => FALSE,
                                              argument1   => 'N');

        END IF;

        COMMIT;

        wait_for_request(l_cust_site_create_req_id, 5);

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

   PROCEDURE run_create_site_only(p_run_id NUMBER) IS

     CURSOR c_site_on_tfm IS
      SELECT tfm.record_id,
             tfm.run_id,
             tfm.run_phase_id,
             tfm.insert_update_flag,
             tfm.customer_name,
             tfm.orig_system_customer_ref,
             tfm.customer_number,
             tfm.abn,
             tfm.orig_system_address_ref,
             tfm.customer_site_number,
             tfm.location,
             tfm.address1,
             tfm.address2,
             tfm.address3,
             tfm.address4,
             tfm.country,
             tfm.city,
             tfm.state,
             tfm.postal_code,
             tfm.contact_last_name,
             tfm.contact_first_name,
             tfm.email_address,
             tfm.site_status,
             tfm.industry_type,
             tfm.customer_class_code,
             tfm.status,
             tfm.created_by,
             tfm.creation_date,
             hp.party_id,
             hca.cust_account_id,
             rc.customer_id
      FROM fmsmgr.xxar_customer_interface_tfm tfm,
           ra_customers rc,
           hz_parties hp,
           hz_cust_accounts hca
      WHERE tfm.insert_update_flag = 'I'
      AND rc.customer_number = tfm.customer_number
      AND rc.party_id = hp.party_id
      AND hp.party_id = hca.party_id
      AND tfm.status = 'VALIDATED'
      AND tfm.orig_system_address_ref IS NOT NULL
      AND tfm.customer_name IS NULL
      AND tfm.customer_number IS NOT NULL
      AND tfm.customer_site_number IS NULL
      AND run_id = p_run_id;

      r_site_on_tfm            c_site_on_tfm%ROWTYPE;
      l_site_count             NUMBER :=0;

  BEGIN

       OPEN c_site_on_tfm;
       LOOP
          FETCH c_site_on_tfm INTO r_site_on_tfm;
          EXIT WHEN c_site_on_tfm%NOTFOUND;

           l_site_count := l_site_count+1;

           IF r_site_on_tfm.email_address IS NULL THEN
                      v_transmission_method := 'PRINT';
           ELSE
                      v_transmission_method := 'EMAIL';
              IF l_debug_flag = 'Y' THEN
                   fnd_file.put_line(fnd_file.log, g_debug || 'v_transmission_method '||v_transmission_method);
                   fnd_file.put_line(fnd_file.log, g_debug || 'r_site_on_tfm.email_address '||r_site_on_tfm.email_address);
              END IF;
           END IF;

            create_location(r_site_on_tfm.country,
                            r_site_on_tfm.address1,
                            r_site_on_tfm.address2,
                            r_site_on_tfm.address3,
                            r_site_on_tfm.address4,
                            r_site_on_tfm.city,
                            r_site_on_tfm.postal_code,
                            r_site_on_tfm.state,
                            l_location_id,
                            r_site_on_tfm.record_id);

            IF l_debug_flag = 'Y' THEN
               fnd_file.put_line(fnd_file.log, g_debug || 'API create_location completed at '||TO_CHAR(sysdate,'DD-MM-YYYY HH24:MI:SS'));
            END IF;

            create_party_site(r_site_on_tfm.party_id,
                              l_location_id,
                              'N',-->p_identifying_address_flag
                              l_party_site_id,
                              r_site_on_tfm.record_id
                              );

            IF l_debug_flag = 'Y' THEN
               fnd_file.put_line(fnd_file.log, g_debug || 'API create_party_site completed at '||TO_CHAR(sysdate,'DD-MM-YYYY HH24:MI:SS'));
            END IF;

            create_cust_account_site(r_site_on_tfm.cust_account_id,
                                     l_party_site_id,
                                     v_transmission_method,
                                     r_site_on_tfm.email_address,
                                     r_site_on_tfm.orig_system_address_ref,
                                     --r_site_on_tfm.STATUS,
                                     l_cust_acct_site_id,
                                     r_site_on_tfm.record_id);

            IF l_debug_flag = 'Y' THEN
               fnd_file.put_line(fnd_file.log, g_debug || 'API create_cust_account_site completed at '||TO_CHAR(sysdate,'DD-MM-YYYY HH24:MI:SS'));
               fnd_file.put_line(fnd_file.log, g_debug||r_site_on_tfm.STATUS);
            END IF;



            create_cust_site_use (l_cust_acct_site_id,
                                  r_site_on_tfm.customer_number,
                                  r_site_on_tfm.orig_system_address_ref,
                                  l_site_use_id,
                                  r_site_on_tfm.status,
                                  NVL(r_site_on_tfm.industry_type,get_profile_class_name(r_site_on_tfm.customer_id)),--r_site_on_tfm.industry_type,
                                  l_site_use_id,
                                  r_site_on_tfm.record_id);

            IF l_debug_flag = 'Y' THEN
               fnd_file.put_line(fnd_file.log, g_debug || 'create_cust_site_use'||r_site_on_tfm.status);
               fnd_file.put_line(fnd_file.log, g_debug || 'API create_cust_account_site_use completed at '||TO_CHAR(sysdate,'DD-MM-YYYY HH24:MI:SS'));
            END IF;

                  IF r_site_on_tfm.contact_last_name IS NOT NULL OR r_site_on_tfm.contact_first_name IS NOT NULL THEN


                     create_contact_person(r_site_on_tfm.contact_first_name,
                                           r_site_on_tfm.contact_last_name,
                                           l_new_contact_party_id,
                                           r_site_on_tfm.record_id);
                     create_org_contact (l_new_contact_party_id,
                                         r_site_on_tfm.party_id,
                                         l_new_org_contact_party_id,
                                         r_site_on_tfm.record_id);
                     create_cust_account_role(l_new_org_contact_party_id,
                                              r_site_on_tfm.cust_account_id,
                                              l_cust_acct_site_id,
                                              r_site_on_tfm.record_id);


                   END IF;

         END LOOP;


         CLOSE c_site_on_tfm;

   EXCEPTION
      WHEN OTHERS THEN
         l_error_count := l_record_count;
         l_int_status := 'ERROR';
         r_error.error_token_val1 := 'CREATE_SITES';
         xxint_common_pkg.get_error_message(g_error_message_11|| SQLERRM, r_error.msg_code, l_message);
         r_error.msg_code := REPLACE(SQLCODE, '-');
         r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
         raise_error(r_error);
         fnd_file.put_line(fnd_file.log,'Error While creating New Customer Sites'|| SQLERRM);
   END run_create_site_only;

   PROCEDURE run_update_site(p_run_id NUMBER) IS

   CURSOR c_updated_site_on_tfm IS
       SELECT  tfm.record_id,
               tfm.customer_site_number,
               tfm.location,
               tfm.address1,
               tfm.address2,
               tfm.address3,
               tfm.address4,
               tfm.country,
               tfm.city,
               tfm.state,
               tfm.postal_code,
               tfm.contact_last_name,
               tfm.contact_first_name,
               tfm.email_address,
               tfm.site_status,
               tfm.industry_type,
               tfm.customer_class_code,
               hps.party_id,
               hca.cust_account_id,
               hcas.cust_acct_site_id
        FROM fmsmgr.xxar_customer_interface_tfm tfm,
             hz_party_sites hps,
             hz_parties hp,
             hz_cust_accounts hca,
             hz_cust_acct_sites_all hcas
        WHERE hps.party_site_number = tfm.customer_site_number
        AND hps.PARTY_ID = hp.party_id
        AND hp.party_id = hca.party_id
        AND hca.cust_account_id = hcas.cust_account_id
        AND hcas.party_site_id = hps.party_site_id
        AND tfm.insert_update_flag = 'U'
        AND tfm.status = 'VALIDATED'
        AND tfm.customer_name is null
        --AND tfm.orig_system_customer_ref is null -- FSC-4078 : Commented out 06-Sep-2017. Though the data file contains orig_system_customer_ref, it needs to be updateed.
        --AND tfm.customer_number is not null
        AND tfm.customer_site_number is not null
        AND tfm.run_id = p_run_id;

   r_updated_site_on_tfm    c_updated_site_on_tfm%ROWTYPE;

   BEGIN

      OPEN c_updated_site_on_tfm;
      LOOP
         FETCH c_updated_site_on_tfm INTO r_updated_site_on_tfm;
         EXIT WHEN c_updated_site_on_tfm%NOTFOUND;

         IF r_updated_site_on_tfm.email_address IS NULL THEN
                v_transmission_method := 'PRINT';
         ELSE
                v_transmission_method := 'EMAIL';
                  IF l_debug_flag = 'Y' THEN
                    fnd_file.put_line(fnd_file.log, g_debug || 'v_transmission_method '||v_transmission_method);
                    fnd_file.put_line(fnd_file.log, g_debug || 'r_site_on_tfm.email_address '||r_updated_site_on_tfm.email_address);
                  END IF;
         END IF;

         update_cust_acct_site(r_updated_site_on_tfm.customer_site_number,
                               r_updated_site_on_tfm.site_status,
                               v_transmission_method,
                               r_updated_site_on_tfm.email_address,
                               r_updated_site_on_tfm.record_id);

         IF l_debug_flag = 'Y' THEN
            fnd_file.put_line(fnd_file.log, g_debug || 'API update_cust_acct_site completed at '||TO_CHAR(sysdate,'DD-MM-YYYY HH24:MI:SS'));
         END IF;

         update_location(r_updated_site_on_tfm.customer_site_number,
                       r_updated_site_on_tfm.address1,
                       r_updated_site_on_tfm.address2,
                       r_updated_site_on_tfm.address3,
                       r_updated_site_on_tfm.address4,
                       r_updated_site_on_tfm.country,
                       r_updated_site_on_tfm.city,
                       r_updated_site_on_tfm.state,
                       r_updated_site_on_tfm.postal_code,
                       r_updated_site_on_tfm.record_id);

         IF l_debug_flag = 'Y' THEN
            fnd_file.put_line(fnd_file.log, g_debug || 'API update_location completed at '||TO_CHAR(sysdate,'DD-MM-YYYY HH24:MI:SS'));
         END IF;

         update_cust_site_use_status(r_updated_site_on_tfm.customer_site_number,
                                     r_updated_site_on_tfm.site_status,
                                     r_updated_site_on_tfm.record_id);

         IF l_debug_flag = 'Y' THEN
            fnd_file.put_line(fnd_file.log, g_debug || 'API update_cust_site_use_status completed at '||TO_CHAR(sysdate,'DD-MM-YYYY HH24:MI:SS'));
         END IF;

         update_cust_site_prof_class(r_updated_site_on_tfm.customer_site_number,
                                    r_updated_site_on_tfm.industry_type, --> Assign New Profile Class for the Site
                                    r_updated_site_on_tfm.record_id);

         IF l_debug_flag = 'Y' THEN
            fnd_file.put_line(fnd_file.log, g_debug || 'API update_cust_site_prof_class completed at '||TO_CHAR(sysdate,'DD-MM-YYYY HH24:MI:SS'));
         END IF;



         IF r_updated_site_on_tfm.contact_last_name IS NOT NULL OR r_updated_site_on_tfm.contact_first_name IS NOT NULL THEN

                     create_contact_person(r_updated_site_on_tfm.contact_first_name,
                                           r_updated_site_on_tfm.contact_last_name,
                                           l_new_contact_party_id,
                                           r_updated_site_on_tfm.record_id);


                     create_org_contact (l_new_contact_party_id,
                                         r_updated_site_on_tfm.party_id,
                                         l_new_org_contact_party_id,
                                         r_updated_site_on_tfm.record_id);


                     create_cust_account_role(l_new_org_contact_party_id,
                                              r_updated_site_on_tfm.cust_account_id,
                                              r_updated_site_on_tfm.cust_acct_site_id,
                                              r_updated_site_on_tfm.record_id);

                     IF l_debug_flag = 'Y' THEN
                        fnd_file.put_line(fnd_file.log, g_debug ||'CREATE CONTACT FOR UPDATE : l_new_org_contact_party_id :'||l_new_org_contact_party_id);
                        fnd_file.put_line(fnd_file.log, g_debug ||'CREATE CONTACT FOR UPDATE : r_updated_site_on_tfm.cust_account_id :'||r_updated_site_on_tfm.cust_account_id);
                        fnd_file.put_line(fnd_file.log, g_debug ||'CREATE CONTACT FOR UPDATE : l_cust_acct_site_id :'||l_cust_acct_site_id);
                     END IF;

          END IF;


      END LOOP;
   EXCEPTION
      -- Add Error Message in Case No data found in the Cursor
      WHEN NO_DATA_FOUND THEN
         fnd_file.put_line(fnd_file.log,'NO DATA FOUND in the main cursor to update Sites '|| SQLERRM);
      WHEN OTHERS THEN
         l_error_count := l_record_count;
         l_int_status := 'ERROR';
         r_error.error_token_val1 := 'UPDATE_SITES';
         xxint_common_pkg.get_error_message(g_error_message_11|| SQLERRM, r_error.msg_code, l_message);
         r_error.msg_code := REPLACE(SQLCODE, '-');
         r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
         raise_error(r_error);
         fnd_file.put_line(fnd_file.log,'Error While Updating Customer Sites'|| SQLERRM);
   END run_update_site;


BEGIN
   xxint_common_pkg.g_object_type := 'CUSTOMERS';-- Added as interface directories are repointed to NFS
   l_tfm_mode := NVL(p_int_mode, g_int_mode);
   l_ctl := NVL(p_control_file, g_customer_ctl);
   l_user_name := fnd_profile.value('USERNAME');
   l_user_id := fnd_profile.value('USER_ID');
   l_login_id := fnd_profile.value('LOGIN_ID');
   l_org_id := fnd_global.org_id;
   l_appl_id := fnd_global.resp_appl_id;
   l_interface_req_id := fnd_global.conc_request_id;
   l_source_dir := p_source;
   l_file := NVL(p_file_name, p_source||g_customer_file);
   write_to_out := TRUE;

   /* Program Short Name */
   g_src_code := 'XXCUSTIMPT';

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
      l_log  := REPLACE(l_file, 'txt', 'log');
      l_bad  := REPLACE(l_file, 'txt', 'bad');


      IF NOT file_length_check(p_source,l_file) THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'The File ' || l_file ||' is not correct Format');
         CONTINUE;
      END IF;

      IF NOT file_format_check(p_source,l_file) THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'The File ' || l_file ||' is not correct Format. Should be <Source>_CUSTOMER_<YYYYMMDDHHMMSS>.txt');
         CONTINUE;
      END IF;

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
                            p_int_table_key_col1      => 'CUSTOMER_NUMBER',
                            p_int_table_key_col_desc1 => 'Customer Number',
                            p_int_table_key_col2      => 'CUSTOMER_SITE_NUMBER',
                            p_int_table_key_col_desc2 => 'Customer Site Number',
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

         UPDATE fmsmgr.xxar_customer_interface_stg
         SET    run_id = l_run_id,
                run_phase_id = l_run_phase_id,
                status = 'PROCESSED',
                created_by = l_user_id,
                creation_date = SYSDATE;

         SELECT COUNT(1)
         INTO   l_record_count
         FROM   fmsmgr.xxar_customer_interface_stg
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
                            p_int_table_name          => 'XXAR_CUSTOMER_INTERFACE_STG',
                            p_int_table_key_col1      => 'CUSTOMER_NUMBER',
                            p_int_table_key_col_desc1 => 'Customer Number',
                            p_int_table_key_col2      => 'CUSTOMER_SITE_NUMBER',
                            p_int_table_key_col_desc2 => 'Customer Site Number',
                            p_int_table_key_col3      => NULL,
                            p_int_table_key_col_desc3 => NULL);

      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework (run_transform_id=' || l_run_phase_id || ')');
         fnd_file.put_line(fnd_file.log, g_debug || 'reset transformation table');
      END IF;

      EXECUTE IMMEDIATE g_customer_reset_tfm_sql;
      l_success_count := 0;
      l_error_count := 0;
      l_int_status := 'SUCCESS';



      ---------------------------------
      -- TRANSFORM: Update Run Phase --
      ---------------------------------
      dot_common_int_pkg.update_run_phase
         (p_run_phase_id => l_run_phase_id,
          p_src_code     => g_src_code,
          p_rec_count    => l_record_count,
          p_hash_total   => NULL,
          p_batch_name   => l_file);



      OPEN c_stage(l_run_id);
      LOOP
         FETCH c_stage INTO r_stg;
         EXIT WHEN c_stage%NOTFOUND;

         l_tfm_error := 0;
         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := r_stg.record_id;
         r_error.int_table_key_val1 := r_stg.customer_number;

         -- Transform
         r_tfm := NULL;
         r_tfm.record_id := r_stg.record_id;
         r_tfm.run_id := l_run_id;
         r_tfm.run_phase_id := l_run_phase_id;



         BEGIN

            IF r_stg.insert_update_flag not in ('UPDATE', 'CREATE') THEN
               r_error.error_token_val1 := 'STG_UPDATE_OR_CREATE';
               l_tfm_error := l_tfm_error + 1;
               xxint_common_pkg.get_error_message(g_error_message_08, r_error.msg_code, l_message);
               r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
               raise_error(r_error);
            END IF;



            IF r_stg.country is not null THEN
               IF NOT check_country_code(r_stg.country) THEN
                  r_error.error_token_val1 := 'STG_UPDATE_OR_CREATE';
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_37, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$COUNTRY_CODE',r_stg.country);
                  raise_error(r_error);
               END IF;
            END IF;



            IF r_stg.contact_last_name IS NULL AND r_stg.contact_first_name IS NOT NULL THEN
               IF NOT check_country_code(r_stg.country) THEN
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_42, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$FIRST_NAME',r_stg.contact_first_name);
                  raise_error(r_error);
               END IF;
            END IF;


           -- 29-06-2017 Obsolete, instead of checking special character, replace the CHAR(13) with NULL in the Cursor
           /*IF check_special_char THEN
              r_error.error_token_val1 := 'STG_SPECIAL_CHAR_CHECK1';
              l_tfm_error := l_tfm_error + 1;
              xxint_common_pkg.get_error_message(g_error_message_36, r_error.msg_code, l_message);
              r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
              raise_error(r_error);
           END IF;*/



           IF r_stg.customer_class_code IS NOT NULL THEN
               IF NOT check_customer_class(r_stg.customer_class_code) THEN
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_34, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$CUSTOMER_CLASS_CODE', r_stg.customer_class_code);
                  raise_error(r_error);
               END IF;
           END IF;



           IF r_stg.industry_type IS NOT NULL THEN
              IF NOT check_customer_profile_class(r_stg.industry_type) THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_35, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$INDUSTRY_TYPE', r_stg.industry_type);
                 raise_error(r_error);
              END IF;
           END IF;

           IF r_stg.abn IS NOT NULL THEN
              IF length(regexp_replace(r_stg.abn, '[^0-9A-Za-z]', ''))!= 11 THEN--LENGTH(r_stg.abn)
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_43, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$ABN', r_stg.abn);
                 raise_error(r_error);
              END IF;
           END IF;

           IF r_stg.insert_update_flag = 'CREATE'
              AND r_stg.customer_number IS NULL
              AND r_stg.customer_site_number IS NULL THEN

              -------------------------------------------------------------
              -- 1. Data Validation for creating a New Customer and Site --
              -------------------------------------------------------------

              r_error.error_token_val1 := 'STG_CREATE_NEW_CUSTOMER';

              IF r_stg.CUSTOMER_NAME IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_27, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              END IF;

              IF  r_stg.ORIG_SYSTEM_CUSTOMER_REF IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_32, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              ELSE
                 IF check_cust_sys_ref(r_stg.ORIG_SYSTEM_CUSTOMER_REF) THEN
                    l_tfm_error := l_tfm_error + 1;
                    xxint_common_pkg.get_error_message(g_error_message_39, r_error.msg_code, l_message);
                    r_error.error_text := REPLACE(l_message, '$ORIG_SYSTEM_CUSTOMER_REF', r_stg.ORIG_SYSTEM_CUSTOMER_REF);
                    raise_error(r_error);
                 END IF;
              END IF;

              IF get_customer_name(NVL(r_stg.CUSTOMER_NAME,'!@#!@#^&#')) > 0 THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_29, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$CUSTOMER_NAME', r_stg.CUSTOMER_NAME);
                 raise_error(r_error);
                    END IF;

              IF r_stg.customer_number IS NOT NULL OR r_stg.customer_site_number IS NOT NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_04, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              END IF;

              IF r_stg.location IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_28, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              ELSE
                 IF check_location (r_stg.location) THEN
                    l_tfm_error := l_tfm_error + 1;
                    xxint_common_pkg.get_error_message(g_error_message_44, r_error.msg_code, l_message);
                    r_error.error_text := REPLACE(l_message, '$LOCATION', r_stg.location);
                    raise_error(r_error);
                 END IF;
              END IF;

              IF r_stg.address1 IS NULL THEN
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_33, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                  raise_error(r_error);

              END IF;

              IF r_stg.ORIG_SYSTEM_ADDRESS_REF IS NULL THEN
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_09||':'||r_stg.ADDRESS1||','||r_stg.ADDRESS2||','||r_stg.ADDRESS3||','||r_stg.ADDRESS4, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                  raise_error(r_error);
              ELSE
                 IF check_orig_add_ref(r_stg.ORIG_SYSTEM_ADDRESS_REF) THEN
                    l_tfm_error := l_tfm_error + 1;
                    xxint_common_pkg.get_error_message(g_error_message_38, r_error.msg_code, l_message);
                    r_error.error_text := REPLACE(l_message, '$ORIG_SYSTEM_ADDRESS_REF', r_stg.ORIG_SYSTEM_ADDRESS_REF);
                    raise_error(r_error);
                 END IF;
              END IF;


           ELSIF  r_stg.insert_update_flag = 'CREATE'
             AND r_stg.customer_number IS NOT NULL
             AND r_stg.customer_site_number IS NULL THEN

             ----------------------------------------------------------------------
             -- 2. Data Validation for Creating A New Site for existing Customer --
             ----------------------------------------------------------------------
               r_error.error_token_val1 := 'STG_CREATE_SITE_ONLY';

              IF r_stg.customer_name is not null THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_30, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              END IF;

              IF get_customer(NVL(r_stg.customer_number,'X')) = 0 THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_06, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$CUSTOMER_NUMBER', r_stg.customer_number);
                 raise_error(r_error);
              END IF;


              IF r_stg.location IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_28, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              ELSE
                 IF check_location(r_stg.location) THEN
                    l_tfm_error := l_tfm_error + 1;
                    xxint_common_pkg.get_error_message(g_error_message_44, r_error.msg_code, l_message);
                    r_error.error_text := REPLACE(l_message, '$LOCATION', r_stg.location);
                    raise_error(r_error);
                 END IF;
              END IF;

              IF r_stg.ORIG_SYSTEM_ADDRESS_REF IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_31, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              ELSE
                 IF check_orig_add_ref(r_stg.ORIG_SYSTEM_ADDRESS_REF) THEN
                    l_tfm_error := l_tfm_error + 1;
                    xxint_common_pkg.get_error_message(g_error_message_38, r_error.msg_code, l_message);
                    r_error.error_text := REPLACE(l_message, '$ORIG_SYSTEM_ADDRESS_REF', r_stg.ORIG_SYSTEM_ADDRESS_REF);
                    raise_error(r_error);
                 END IF;
              END IF;

              IF r_stg.address1 IS NULL THEN
                  l_tfm_error := l_tfm_error + 1;
                  xxint_common_pkg.get_error_message(g_error_message_33, r_error.msg_code, l_message);
                  r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                  raise_error(r_error);
              END IF;

              IF r_stg.industry_type IS NOT NULL THEN
                 IF NOT check_customer_profile_class(r_stg.industry_type) THEN
                    l_tfm_error := l_tfm_error + 1;
                    xxint_common_pkg.get_error_message(g_error_message_35, r_error.msg_code, l_message);
                    r_error.error_text := REPLACE(l_message, '$INDUSTRY_TYPE', r_stg.industry_type);
                    raise_error(r_error);
                 END IF;
              END IF;

           ELSIF r_stg.insert_update_flag = 'UPDATE'
                --AND r_stg.customer_number IS NOT NULL
                AND r_stg.customer_site_number IS NOT NULL THEN



              --------------------------------------------------------
              -- 3. Data Validation for Updating a Site Information --
              --------------------------------------------------------

              r_error.error_token_val1 := 'UPDATE_SITE';

              IF r_stg.customer_name is not null THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_30, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              END IF;


              IF r_stg.customer_site_number IS NULL THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_26, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              END IF;

              IF get_customer_site(NVL(r_stg.customer_site_number,'X')) = 0 THEN
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_07, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$CUSTOMER_SITE_NUMBER', r_stg.customer_site_number);
                 raise_error(r_error);
              END IF;

          ELSE

            --  IF r_stg.insert_update_flag = 'CREATE' THEN
                 r_error.error_token_val1 := 'CREATE_INVALID_RECORDS_IN_STG';
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_25, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);
              /*ELSIF r_stg.insert_update_flag = 'UPDATE' THEN
                 r_error.error_token_val1 := 'UPDATE_INVALID_RECORDS_IN_STG';
                 l_tfm_error := l_tfm_error + 1;
                 xxint_common_pkg.get_error_message(g_error_message_33, r_error.msg_code, l_message);
                 r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
                 raise_error(r_error);*/
            --  END IF;

           END IF;



      EXCEPTION
         WHEN others THEN
            r_error.error_token_val1 := 'EXCEPTION_IN_TRANSFORMATION';
            l_tfm_error := l_tfm_error + 1;
            xxint_common_pkg.get_error_message(g_error_message_10||SQLERRM, r_error.msg_code, l_message);
            r_error.msg_code := REPLACE(SQLCODE, '-');
            r_error.error_text := REPLACE(l_message, '$COL_VAL', r_error.error_token_val1);
            raise_error(r_error);
            RETURN;
            p_retcode := 2;
      END;


         IF l_tfm_error > 0 THEN
            l_error_count := l_error_count + 1;
            r_tfm.status := 'ERROR';
         ELSE
            l_success_count := l_success_count + 1;
            --r_tfm.object_version_id := get_object_version(r_stg.crn_number);
            -- 1. Insert TFM Table to Create A New Customer and Site

            IF r_stg.insert_update_flag = 'CREATE' THEN
               l_insert_update_flag := 'I';
            ELSIF r_stg.insert_update_flag = 'UPDATE' THEN
               l_insert_update_flag := 'U';
            END IF;



            r_tfm.insert_update_flag        := l_insert_update_flag;
            r_tfm.customer_name             := SUBSTR(r_stg.customer_name,1,360);
            r_tfm.orig_system_customer_ref  := SUBSTR(r_stg.orig_system_customer_ref,1,240);
            r_tfm.customer_number           := SUBSTR(r_stg.customer_number,1,30); --> to create a new customer, customer number should be null
            r_tfm.abn                       := SUBSTR(r_stg.abn,1,50);
            r_tfm.orig_system_address_ref   := SUBSTR(r_stg.orig_system_address_ref,1,240);
            r_tfm.customer_site_number      := SUBSTR(r_stg.customer_site_number,1,30);--> to create a new customer site, customer site number should be null
            r_tfm.location                  := SUBSTR(r_stg.location,1,40);
            r_tfm.address1                  := SUBSTR(r_stg.address1,1,240);
            r_tfm.address2                  := SUBSTR(r_stg.address2,1,240);
            r_tfm.address3                  := SUBSTR(r_stg.address3,1,240);
            r_tfm.address4                  := SUBSTR(r_stg.address4,1,240);
            r_tfm.country                   := SUBSTR(r_stg.country,1,60);
            r_tfm.city                      := SUBSTR(r_stg.city,1,60);
            r_tfm.state                     := SUBSTR(r_stg.state,1,60);
            r_tfm.postal_code               := SUBSTR(r_stg.postal_code,1,60);
            r_tfm.contact_last_name         := SUBSTR(r_stg.contact_last_name,1,50);
            r_tfm.contact_first_name        := SUBSTR(r_stg.contact_first_name,1,40);
            r_tfm.email_address             := SUBSTR(r_stg.email_address,1,240);
            r_tfm.site_status               := SUBSTR(r_stg.site_status,1,1);
            r_tfm.industry_type             := SUBSTR(r_stg.industry_type,1,30);
            r_tfm.customer_class_code       := SUBSTR(get_customer_class(r_stg.customer_class_code),1,30);
            r_tfm.status                    := 'VALIDATED';

         END IF;

         r_tfm.created_by := l_user_id;
         r_tfm.creation_date := SYSDATE;

         INSERT INTO fmsmgr.xxar_customer_interface_tfm
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

      IF l_tfm_mode = g_int_mode THEN

         SELECT COUNT(1)
         INTO   l_record_count
         FROM   fmsmgr.xxar_customer_interface_tfm
         WHERE  run_id = l_run_id
         AND    run_phase_id = l_run_phase_id;

         ----------------------------
         -- LOAD: Start Run Phase  --
         ----------------------------
         l_run_phase_id := dot_common_int_pkg.start_run_phase
                              (p_run_id                  => l_run_id,
                               p_phase_code              => 'LOAD',
                               p_phase_mode              => g_int_mode,
                               p_int_table_name          => 'XXAR_CUSTOMER_INTERFACE_TFM',
                               p_int_table_key_col1      => 'CUSTOMER_NUMBER',
                               p_int_table_key_col_desc1 => 'Customer Number',
                               p_int_table_key_col2      => 'CUSTOMER_SITE_NUMBER',
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

         r_error := NULL;
         r_error.run_id := l_run_id;
         r_error.run_phase_id := l_run_phase_id;
         r_error.record_id := -1;
         l_success_count := 0;
         l_error_count := 0;
         -------------------------
         -- LOAD: End Run Phase --
         -------------------------

         IF l_error_count > 0 THEN

            RAISE interface_error;

         ELSE

            -------------------------------------
            -- Start Create Customer and Sites --
            -------------------------------------
            run_create_customer_and_site(l_run_id);
            -------------------------------------------------------
            -- Start Create Customer Sites for Existing Customer --
            -------------------------------------------------------

            run_create_site_only(l_run_id);

            -----------------------------------------------------------
            -- Start Update Customer Site for Existing Customer Site --
            -----------------------------------------------------------

            run_update_site(l_run_id);

            --------------------------------------------
            -- Start to create Acknowledgement Report --
            --------------------------------------------

            creation_results_output(l_run_id,
                  l_run_phase_id,
                  l_cust_site_create_req_id,
                  l_file_req_id,
                  l_source_dir, --p_source
                  l_file,
                  l_delim,
                  write_to_out,
                  l_success_count,
                  l_error_count
                  );

         END IF;

      END IF;

      dot_common_int_pkg.end_run_phase
            (p_run_phase_id => l_run_phase_id,
             p_status => l_int_status,
             p_error_count => l_error_count,
             p_success_count => l_success_count);

      IF l_error_count > 0 THEN
            RAISE interface_error;
      END IF;

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

      fnd_file.put_line(fnd_file.log, g_debug ||'The File '||l_file||' gets interface error, Please refer to the Error Messages in the Out File');


      creation_results_output(l_run_id,
                  l_run_phase_id,
                  l_cust_site_create_req_id,
                  l_file_req_id,
                  l_source_dir, --p_source
                  l_file,
                  l_delim,
                  write_to_out,
                  l_success_count,
                  l_error_count                  
                  );

      /* Debug Log */
      IF l_debug_flag = 'Y' THEN
         fnd_file.put_line(fnd_file.log, g_debug || 'interface framework error report (request_id=' || l_run_report_id || ')');
      END IF;

      IF l_success_count > 0 THEN
         p_retcode := 1;
      ELSE
         p_retcode := 2;
      END IF;

END customer_import;

END xxar_customer_interface_pkg;
/