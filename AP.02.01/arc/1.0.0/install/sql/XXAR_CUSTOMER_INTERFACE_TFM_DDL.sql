/*$Header: svn://d02584/consolrepos/branches/AP.02.01/arc/1.0.0/install/sql/XXAR_CUSTOMER_INTERFACE_TFM_DDL.sql 1021 2017-06-21 00:47:18Z svnuser $*/

CREATE TABLE FMSMGR.XXAR_CUSTOMER_INTERFACE_TFM 
   (	RECORD_ID NUMBER, 
	SOURCE_RECORD_ID NUMBER, 
	RUN_ID NUMBER, 
	RUN_PHASE_ID NUMBER, 
	INSERT_UPDATE_FLAG VARCHAR2(1), 
	CUSTOMER_NAME VARCHAR2(360), 
	ORIG_SYSTEM_CUSTOMER_REF VARCHAR2(240), 
	CUSTOMER_NUMBER VARCHAR2(30), 
	ABN VARCHAR2(50), 
	ORIG_SYSTEM_ADDRESS_REF VARCHAR2(240), 
	CUSTOMER_SITE_NUMBER VARCHAR2(30), 
	LOCATION VARCHAR2(40), 
	ADDRESS1 VARCHAR2(240), 
	ADDRESS2 VARCHAR2(240), 
	ADDRESS3 VARCHAR2(240), 
	ADDRESS4 VARCHAR2(240), 
	COUNTRY VARCHAR2(60), 
	CITY VARCHAR2(60), 
	STATE VARCHAR2(60), 
	POSTAL_CODE VARCHAR2(60), 
	CONTACT_LAST_NAME VARCHAR2(50), 
	CONTACT_FIRST_NAME VARCHAR2(40), 
	EMAIL_ADDRESS VARCHAR2(240), 
	SITE_STATUS VARCHAR2(1), 
	INDUSTRY_TYPE VARCHAR2(30), 
	CUSTOMER_CLASS_CODE VARCHAR2(30), 
	STATUS VARCHAR2(25), 
	CREATED_BY NUMBER, 
	CREATION_DATE DATE
   );
   
CREATE OR REPLACE SYNONYM APPS.XXAR_CUSTOMER_INTERFACE_TFM FOR FMSMGR.XXAR_CUSTOMER_INTERFACE_TFM;   