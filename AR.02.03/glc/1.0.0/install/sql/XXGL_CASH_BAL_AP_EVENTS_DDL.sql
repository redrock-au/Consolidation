/* $Header: svn://d02584/consolrepos/branches/AR.02.03/glc/1.0.0/install/sql/XXGL_CASH_BAL_AP_EVENTS_DDL.sql 2945 2017-11-10 04:55:39Z svnuser $ */
PROMPT creating xxgl_cash_bal_ap_events table

CREATE TABLE fmsmgr.xxgl_cash_bal_ap_events
(
   accounting_event_id      NUMBER,
   csh_request_id           NUMBER,
   status                   VARCHAR2(15),
   created_by               NUMBER,
   creation_date            DATE,
   last_updated_by          NUMBER,
   last_update_date         DATE
)
TABLESPACE LOCDAT;

CREATE OR REPLACE SYNONYM xxgl_cash_bal_ap_events FOR fmsmgr.xxgl_cash_bal_ap_events;

CREATE INDEX fmsmgr.xxgl_cash_bal_ap_events_n1 ON xxgl_cash_bal_ap_events (accounting_event_id);
