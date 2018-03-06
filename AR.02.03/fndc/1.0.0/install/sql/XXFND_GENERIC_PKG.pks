CREATE OR REPLACE PACKAGE xxfnd_generic_pkg AS
/* $Header: svn://d02584/consolrepos/branches/AR.02.03/fndc/1.0.0/install/sql/XXFND_GENERIC_PKG.pks 2246 2017-08-22 07:34:56Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: XX.XX.XX
**
** Description: Program to update email address after sanitization
**
** Change History:
**
** Date        Who                  Comments
** 17/08/2017  Joy Pinto                Initial build.
**
*******************************************************************/
PROCEDURE EMAIL_UPDATE
(
   p_errbuff           OUT VARCHAR2,
   p_retcode           OUT NUMBER,
   p_object            IN  VARCHAR2,
   p_email_address     IN  VARCHAR2,
   p_debug             IN  VARCHAR2
);
END xxfnd_generic_pkg;
/