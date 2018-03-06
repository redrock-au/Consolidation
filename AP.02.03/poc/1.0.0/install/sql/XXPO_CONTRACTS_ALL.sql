rem $Header: svn://d02584/consolrepos/branches/AP.02.03/poc/1.0.0/install/sql/XXPO_CONTRACTS_ALL.sql 1442 2017-07-04 22:35:02Z svnuser $
CREATE TABLE FMSMGR.XXPO_CONTRACTS_ALL
(	
   CONTRACT_NUMBER    NUMBER(6),
   DESCRIPTION        VARCHAR2(255),
   ORG_ID	      NUMBER,
   ATTRIBUTE1         VARCHAR2(150),
   ATTRIBUTE2         VARCHAR2(150),
   ATTRIBUTE3         VARCHAR2(150),
   ATTRIBUTE4         VARCHAR2(150),
   ATTRIBUTE5         VARCHAR2(150),
   ATTRIBUTE6         VARCHAR2(150),
   ATTRIBUTE7         VARCHAR2(150),
   ATTRIBUTE8         VARCHAR2(150),
   ATTRIBUTE9         VARCHAR2(150),
   ATTRIBUTE10        VARCHAR2(150),
   ATTRIBUTE11        VARCHAR2(150),
   ATTRIBUTE12        VARCHAR2(150),
   ATTRIBUTE13        VARCHAR2(150),
   ATTRIBUTE14        VARCHAR2(150),
   ATTRIBUTE15        VARCHAR2(150),      
   START_DATE         DATE,
   END_DATE           DATE,
   CREATED_BY         NUMBER,
   CREATION_DATE      DATE,
   LAST_UPDATED_BY    NUMBER,
   LAST_UPDATE_DATE   DATE
) 
/

CREATE INDEX FMSMGR.XXPO_CONTRACTS_ALL_U1 ON FMSMGR.XXPO_CONTRACTS_ALL (CONTRACT_NUMBER)
/

CREATE OR REPLACE SYNONYM APPS.XXPO_CONTRACTS_ALL FOR FMSMGR.XXPO_CONTRACTS_ALL
/
