rem $Header: svn://d02584/consolrepos/branches/AP.01.02/arc/1.0.0/install/sql/XXAR_RECALL_INTERFACE_HDR_STG.sql 1368 2017-07-02 23:54:39Z svnuser $
CREATE TABLE FMSMGR.XXAR_RECALL_INTERFACE_HDR_STG
(
    RECORD_ID               NUMBER NOT NULL PRIMARY KEY,
    SOURCE                  VARCHAR2(30),
    RECALL_NUMBER           VARCHAR2(30),
    BILLER_NAME             VARCHAR2(30),
    STATE                   VARCHAR2(30),
    BILLER_BSB              VARCHAR2(30),
    BILLER_ACCOUNT          VARCHAR2(30),
    UNIT_CHARGE             VARCHAR2(30),
    PROCESSING_DATE         VARCHAR2(30),
    RUN_ID                  NUMBER,
    RUN_PHASE_ID            NUMBER,
    STATUS                  VARCHAR2(25),
    CREATED_BY              NUMBER,
    CREATION_DATE           DATE
);

CREATE OR REPLACE SYNONYM APPS.XXAR_RECALL_INTERFACE_HDR_STG FOR FMSMGR.XXAR_RECALL_INTERFACE_HDR_STG;

CREATE INDEX FMSMGR.XXAR_RECALL_INT_HDR_STG_N1 ON FMSMGR.XXAR_RECALL_INTERFACE_HDR_STG(RUN_ID); 
