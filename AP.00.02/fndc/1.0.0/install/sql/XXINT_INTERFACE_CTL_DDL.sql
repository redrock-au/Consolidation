CREATE TABLE FMSMGR.XXINT_INTERFACE_CTL
(
  application_id         NUMBER,
  interface_request_id   NUMBER,
  interface_program_id   NUMBER,
  file_name              VARCHAR2(150),
  sub_request_id         NUMBER,
  sub_request_program_id NUMBER,
  status                 VARCHAR2(30),
  error_message          VARCHAR2(1000),
  org_id                 NUMBER,
  creation_date          DATE,
  created_by             NUMBER,
  last_update_date       DATE,
  last_updated_by        NUMBER
);

-- Create/Recreate indexes 
CREATE INDEX FMSMGR.XXINT_INTERFACE_CTL_N1 on FMSMGR.XXINT_INTERFACE_CTL (INTERFACE_REQUEST_ID);

CREATE SYNONYM xxint_interface_ctl FOR fmsmgr.xxint_interface_ctl;
