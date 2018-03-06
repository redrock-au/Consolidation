create or replace PACKAGE XXAP_INVOICE_IMPORT_PKG AS
/* $Header: svn://d02584/consolrepos/branches/AR.00.02/apc/1.0.0/install/sql/XXAP_INVOICE_IMPORT_PKG.pks 2379 2017-08-31 04:02:33Z svnuser $ */
/****************************************************************************
**
** CEMLI ID: AP.03.01
**
** Description: Package to handle the below
**              (1) Import Invoice Metadata into Oracle custom table
**              (2) Send Workflow Email to Requestor
**              (3) Attach URL of Scanned Invoice to Historical AP Invoices
**              (4) 3.5	Program to Deactivate Scanned Invoice Record in Oracle 
**              
**
** Change History:
**
** Date        Who                  Comments
** 15/05/2017  Joy Pinto            Initial build.
**
****************************************************************************/

   gn_user_id                 NUMBER := FND_PROFILE.VALUE('USER_ID');
   gn_login_id                NUMBER := FND_PROFILE.VALUE('LOGIN_ID');

PROCEDURE run_rcpt_reminder_email
(
   p_errbuf            OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_requestor_id      IN  VARCHAR2,
   p_days_old          IN  NUMBER,
   p_notification_type IN  VARCHAR2,
   p_org_id            IN NUMBER
);

PROCEDURE create_wf_initial_doc
(
   document_id   IN VARCHAR2,
   display_type  IN VARCHAR2,
   document      IN OUT nocopy VARCHAR2,
   document_type IN OUT nocopy VARCHAR2 );
   
PROCEDURE create_wf_reminder_doc(
    document_id   IN VARCHAR2,
    display_type  IN VARCHAR2,
    document      IN OUT nocopy VARCHAR2,
    document_type IN OUT nocopy VARCHAR2 );   
    
FUNCTION get_attachment_url
(
   p_invoice_id      IN NUMBER
)         
RETURN VARCHAR2;   

PROCEDURE import_invoices
(
   p_errbuf            OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_org_id            IN  NUMBER
);

PROCEDURE deactivate_invoice
(
   p_errbuf            OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_payload_id    IN  NUMBER
);

END XXAP_INVOICE_IMPORT_PKG;
/

