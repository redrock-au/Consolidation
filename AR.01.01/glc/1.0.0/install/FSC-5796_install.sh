#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.01.01/glc/1.0.0/install/FSC-5796_install.sh 3173 2017-12-12 05:28:14Z svnuser $

# --------------------------------------------------------------
# Install script for GL.03.01 GL Cash Balancing redeploy FSC-5796
#   Usage: FSC-5796_install.sh <apps_pwd> | tee FSC-5796_install.log
# --------------------------------------------------------------
CEMLI=GL.03.01

TIER_DB=`echo 'cat //TIER_DB/text()'| xmllint --shell $CONTEXT_FILE | sed -n 2p`

usage() {
  echo "Usage: FSC-5796_install.sh <apps_pwd>"
  exit 1
}

# --------------------------------------------------------------
# Validate parameters
# --------------------------------------------------------------
if [ $# == 1 ]
then
  APPSLOGIN=apps/$1
else
  usage
fi

echo "Installing $CEMLI"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

# --------------------------------------------------------------
# Database objects
# --------------------------------------------------------------


# --------------------------------------------------------------
# Loader files
# --------------------------------------------------------------
if [ "$TIER_DB" = "YES" ]
then
  IMPORTDIR=$GLC_TOP/import
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $IMPORTDIR/XXGL_PAYMENT_AMT_CHK_ALERT_MSG.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $IMPORTDIR/XXGL_PAYMENT_AMT_CHK_MAIL_LIST.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
  $FND_TOP/bin/FNDLOAD $APPSLOGIN 0 Y UPLOAD $FND_TOP/patch/115/import/afmdmsg.lct $IMPORTDIR/XXGL_PAYMENT_AMT_CHK_SUBJECT.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
fi

# --------------------------------------------------------------
# Copy from install directory to target directory
# --------------------------------------------------------------

cp -p $GLC_TOP/bin/cheq.prog $PRODB
cp -p $GLC_TOP/bin/EFT_AMT_ALERT $PRODB
cp -p $GLC_TOP/install/sql/eft_payment_amount_check_alert.sql $PRODS
cp -p $GLC_TOP/install/sql/eft_amount_check_alert_recipients.sql $PRODS
cp -p $GLC_TOP/install/sql/eft_amount_check_alert_subject.sql $PRODS

chmod +x $PRODB/cheq.prog
chmod +x $PRODB/EFT_AMT_ALERT
chmod +x $PRODS/eft_payment_amount_check_alert.sql
chmod +x $PRODS/eft_amount_check_alert_recipients.sql
chmod +x $PRODS/eft_amount_check_alert_subject.sql

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0
