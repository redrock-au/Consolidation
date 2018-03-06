/*$Header: svn://d02584/consolrepos/branches/AP.02.03/arc/1.0.0/install/sql/XXAR_CUSTOMER_INTERFACE_STG_DDL.sql 1027 2017-06-21 01:18:32Z svnuser $*/

CREATE TABLE FMSMGR.XXAR_CUSTOMER_INTERFACE_STG 
   (	RECORD_ID NUMBER, 
	RUN_ID NUMBER, 
	RUN_PHASE_ID NUMBER, 
	INSERT_UPDATE_FLAG VARCHAR2(500), 
	CUSTOMER_NAME VARCHAR2(500), 
	ORIG_SYSTEM_CUSTOMER_REF VARCHAR2(500), 
	CUSTOMER_NUMBER VARCHAR2(500), 
	ABN VARCHAR2(500), 
	ORIG_SYSTEM_ADDRESS_REF VARCHAR2(500), 
	CUSTOMER_SITE_NUMBER VARCHAR2(500), 
	LOCATION VARCHAR2(500), 
	ADDRESS1 VARCHAR2(500), 
	ADDRESS2 VARCHAR2(500), 
	ADDRESS3 VARCHAR2(500), 
	ADDRESS4 VARCHAR2(500), 
	COUNTRY VARCHAR2(500), 
	CITY VARCHAR2(500), 
	STATE VARCHAR2(500), 
	POSTAL_CODE VARCHAR2(500), 
	CONTACT_LAST_NAME VARCHAR2(500), 
	CONTACT_FIRST_NAME VARCHAR2(500), 
	EMAIL_ADDRESS VARCHAR2(500), 
	SITE_STATUS VARCHAR2(500), 
	INDUSTRY_TYPE VARCHAR2(500), 
	CUSTOMER_CLASS_CODE VARCHAR2(500), 
	STATUS VARCHAR2(25), 
	CREATED_BY NUMBER, 
	CREATION_DATE DATE
   );
   
CREATE OR REPLACE SYNONYM APPS.XXAR_CUSTOMER_INTERFACE_STG FOR FMSMGR.XXAR_CUSTOMER_INTERFACE_STG;   