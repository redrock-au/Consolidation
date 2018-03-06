--$Header: svn://d02584/consolrepos/branches/AR.03.01/arc/1.0.0/bin/XXARCUSTIMP.ctl 1706 2017-07-12 04:37:42Z svnuser $

LOAD DATA
REPLACE
INTO TABLE FMSMGR.XXAR_CUSTOMER_INTERFACE_STG FIELDS TERMINATED BY '|'
TRAILING NULLCOLS
(
   INSERT_UPDATE_FLAG,
   CUSTOMER_NAME,
   ORIG_SYSTEM_CUSTOMER_REF,
   CUSTOMER_NUMBER,
   ABN,
   ORIG_SYSTEM_ADDRESS_REF,
   CUSTOMER_SITE_NUMBER,
   LOCATION,
   ADDRESS1,
   ADDRESS2,
   ADDRESS3,
   ADDRESS4,
   COUNTRY,
   CITY,
   STATE,
   POSTAL_CODE,
   CONTACT_LAST_NAME,
   CONTACT_FIRST_NAME,
   EMAIL_ADDRESS,
   SITE_STATUS,
   INDUSTRY_TYPE,
   CUSTOMER_CLASS_CODE,
   RECORD_ID "XXAR_CUSTOMER_INT_RECORD_ID_S.NEXTVAL",
   STATUS    CONSTANT 'NEW',
   CREATION_DATE SYSDATE
)