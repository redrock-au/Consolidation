rem $Header: svn://d02584/consolrepos/branches/AR.01.01/poc/1.0.0/install/sql/XXPO_CONTRACTS_STG.sql 1262 2017-06-26 23:43:06Z svnuser $
CREATE TABLE FMSMGR.XXPO_CONTRACTS_STG
(
   record_id 		NUMBER,
   run_id 		NUMBER,
   run_phase_id 	NUMBER,
   status 	      VARCHAR2(240),
   contract_number    VARCHAR2(255),
   description        VARCHAR2(255),
   org_id	      number,
   attribute1         varchar2(150),
   attribute2         varchar2(150),
   attribute3         varchar2(150),
   attribute4         varchar2(150),
   attribute5         varchar2(150),
   attribute6         varchar2(150),
   attribute7         varchar2(150),
   attribute8         varchar2(150),
   attribute9         varchar2(150),
   attribute10        varchar2(150),
   attribute11        varchar2(150),
   attribute12        varchar2(150),
   attribute13        varchar2(150),
   attribute14        varchar2(150),
   attribute15        varchar2(150),         
   start_date         VARCHAR2(255),
   end_date           VARCHAR2(255),
   created_by         NUMBER,
   creation_date      DATE,
   last_updated_by    NUMBER,
   last_update_date   DATE
)
/

CREATE OR REPLACE SYNONYM APPS.XXPO_CONTRACTS_STG FOR FMSMGR.XXPO_CONTRACTS_STG
/