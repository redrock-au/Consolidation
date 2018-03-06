create or replace PACKAGE xxar_customer_conversion_pkg AS
/*$Header: svn://d02584/consolrepos/branches/AR.01.01/arc/1.0.0/install/sql/XXAR_CUSTOMER_CONVERSION_PKG.pks 2318 2017-08-28 04:51:18Z svnuser $*/
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
-- Defaults and Messages --
---------------------------
g_error_message_01     VARCHAR2(150)  := '<ERROR-01>Interface $INT_CODE is disabled from the interfaces registry table.';
g_error_message_02     VARCHAR2(150)  := '<ERROR-02>Unable to read file from $INT_DIR.';
g_error_message_03     VARCHAR2(150)  := '<ERROR-03>Unable to load file $INT_FILE.';
g_error_message_04     VARCHAR2(150)  := '<ERROR-04>Customer / Site Number should not be specified to create new customer.';
g_error_message_05     VARCHAR2(150)  := '<ERROR-05>Customer Site Number should not be specified to create new customer site.';
g_error_message_06     VARCHAR2(150)  := '<ERROR-06>Customer to have new site is not found.';
g_error_message_07     VARCHAR2(150)  := '<ERROR-07>The Customer site to be updated is not existing in Oracle.';
g_error_message_08     VARCHAR2(150)  := '<ERROR-08>NEW, SITE or MAPPED value should be specified in RECORD_ACTION Column.';
g_error_message_09     VARCHAR2(150)  := '<ERROR-09>ORIG_SYSTEM_ADDRESS_REF is required when specifying an address.';
g_error_message_10     VARCHAR2(150)  := '<ERROR-10>Error while checking transformed data.';
g_error_message_11     VARCHAR2(150)  := '<ERROR-11>Loading Transformed Data into AR Customers Interface Table.';
g_error_message_12     VARCHAR2(150)  := '<ERROR-12>Error running API for Creating LOCATION.';
g_error_message_13     VARCHAR2(150)  := '<ERROR-13>Error running API for Creating PARTY SITE.';
g_error_message_14     VARCHAR2(150)  := '<ERROR-14>Error running API for Creating CUSTOMER ACCOUNT SITE.';
g_error_message_15     VARCHAR2(150)  := '<ERROR-15>Error running API for Creating CUSTOMER SITE USE.';
g_error_message_16     VARCHAR2(150)  := '<ERROR-16>Error running API for Updateing CUSTOMER ACCOUNT SITE.';
g_error_message_17     VARCHAR2(150)  := '<ERROR-17>Error running API for Updateing LOCATION.';
g_error_message_18     VARCHAR2(150)  := '<ERROR-18>Error - Party Site Number to be updated is not existing. ';
g_error_message_19     VARCHAR2(150)  := '<ERROR-19>Error - The Party Site Location to be updated is not existing - Party Site number  : ';
g_error_message_20     VARCHAR2(150)  := '<ERROR-20>The combination of customer number and site number seem not correct';
g_error_message_21     VARCHAR2(150)  := '<ERROR-21>Error - Error while running API create_contact_person.';
g_error_message_22     VARCHAR2(150)  := '<ERROR-22>Error - Error while running API create_org_contact.';
g_error_message_23     VARCHAR2(150)  := '<ERROR-23>Error - Error while running API create_cust_account_role.';
g_error_message_24     VARCHAR2(150)  := '<ERROR-24>Copy file to the outbound directory failed.';
g_error_message_25     VARCHAR2(200)  := '<ERROR-25>Please Check the Customer and Site Numbers 1.To create customer and site together, both numbers should not be set. 2.To create site,put customer number only.' ;
g_error_message_26     VARCHAR2(150)  := '<ERROR-26>Both Customer Number and Site Number should not be NULL to update Site.';
g_error_message_27     VARCHAR2(150)  := '<ERROR-27>Customer Name Cannot be null to create new customer.';
g_error_message_28     VARCHAR2(150)  := '<ERROR-28>Location should be entered to create new site.';
g_error_message_29     VARCHAR2(150)  := '<ERROR-29>Customer Name in this record is already existing in Oracle.';
g_error_message_30     VARCHAR2(150)  := '<ERROR-30>Customer Name should not be specified when create site only or update site.';
g_error_message_31     VARCHAR2(150)  := '<ERROR-31>ORIG_SYSTEM_ADDRESS_REF should not be NULL.';
g_error_message_32     VARCHAR2(150)  := '<ERROR-32>ORIG_SYSTEM_CUSTOMER_REF should not be NULL.';
g_error_message_33     VARCHAR2(150)  := '<ERROR-33>To Update Site, you need to provide both Customer Number and Site Number.';
g_error_message_34     VARCHAR2(150)  := '<ERROR-34>Customer Class Code $CUSTOMER_CLASS_CODE is not existing in Oracle';
g_error_message_35     VARCHAR2(150)  := '<ERROR-35>Industry Type $INDUSTRY_TYPE is not existing in Oracle. ';
g_error_message_36     VARCHAR2(150)  := '<ERROR-36>Special Characters are not allowed. ';
g_error_message_37     VARCHAR2(150)  := '<ERROR-37>Country Code is Invalid. ';
g_error_message_38     VARCHAR2(150)  := '<ERROR-38>The customer number $DTPLI_CUSTOMER_NUM in DTPLI_CUSTOMER_NUM is not existing';
g_error_message_39     VARCHAR2(150)  := '<ERROR-39>The ORIG SYS REF for the customer number $DTPLI_CUSTOMER_NUM  is not existing';
g_error_message_40     VARCHAR2(150)  := '<ERROR-40>The ORIG SYS ADDRESS REF $ORIG_SYS_ADDRESS_REF is existing in hz_party_sites already';
g_error_message_41     VARCHAR2(150)  := '<ERROR-41>The Address : $ADDRESS is existing already for the Customer';

g_debug                   VARCHAR2(10)   := 'DEBUG: ';
g_error                   VARCHAR2(10)   := 'ERROR: ';
g_staging_directory       VARCHAR2(25)   := 'WORKING';
g_src_code                VARCHAR2(25);
g_int_mode                VARCHAR2(60)   := 'VALIDATE_TRANSFER';
-----------------
-- CUSTOMER         --
-----------------
g_customer_file            VARCHAR2(150) := 'CUST_CONVERSION*.csv';
g_customer_ctl             VARCHAR2(150) := '$ARC_TOP/bin/XXARCUSTCONV.ctl';
g_customer_int_code        dot_int_interfaces.int_code%TYPE := 'AR.00.01';
g_customer_int_name        dot_int_interfaces.int_name%TYPE := 'DEDJTR AR Customer Conversion';
g_customer_reset_tfm_sql   VARCHAR2(1000) := 'TRUNCATE TABLE FMSMGR.XXAR_CUSTOMER_CONVERSION_TFM';
g_created_by_module        VARCHAR2(150) := 'TCA_V2_API';

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
);

FUNCTION file_length_check
(p_source_name VARCHAR2,
 p_file VARCHAR2) RETURN BOOLEAN;

/*FUNCTION get_customer_name
(p_customer_number  VARCHAR2)
RETURN VARCHAR2;

FUNCTION get_customer
( p_customer_number  VARCHAR2)RETURN NUMBER;*/

FUNCTION get_customer_site
(p_party_site_number  VARCHAR2) RETURN NUMBER;

FUNCTION get_cust_level_profile_class
(p_customer_number  VARCHAR2)RETURN NUMBER;

FUNCTION check_cust_site_relation
(p_customer_number VARCHAR2,p_site_number  VARCHAR2)RETURN NUMBER;

FUNCTION get_customer_name
(p_customer_name  VARCHAR2,  p_org_id NUMBER) RETURN NUMBER;

PROCEDURE raise_error
(p_error_rec      dot_int_run_phase_errors%ROWTYPE);


END xxar_customer_conversion_pkg;
/