#!/usr/bin/bash
# $Header: svn://d02584/consolrepos/branches/AR.02.02/glc/1.0.0/install/FSC-5796_install.sh 3066 2017-11-28 06:24:56Z svnuser $
# --------------------------------------------------------------
# Install script for GL.03.01 GL Cash Balancing
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
# File permissions and symbolic links
# --------------------------------------------------------------

chmod +x $GLC_TOP/tmp/cheq.prog
chmod +x $GLC_TOP/tmp/EFT_AMT_ALERT
chmod +x $GLC_TOP/tmp/eft_payment_amount_check_alert.sql
chmod +x $GLC_TOP/tmp/eft_amount_check_alert_recipients.sql
chmod +x $GLC_TOP/tmp/eft_amount_check_alert_subject.sql

# --------------------------------------------------------------
# Copy to source directory
# --------------------------------------------------------------

cp -p $GLC_TOP/tmp/cheq.prog $PRODB
cp -p $GLC_TOP/tmp/EFT_AMT_ALERT $PRODB
cp -p $GLC_TOP/tmp/eft_payment_amount_check_alert.sql $PRODS
cp -p $GLC_TOP/tmp/eft_amount_check_alert_recipients.sql $PRODS
cp -p $GLC_TOP/tmp/eft_amount_check_alert_subject.sql $PRODS

echo "Installation complete"
echo "***********************************************"
echo "Time: `date '+%d-%b-%Y.%H:%M:%S'`"
echo "***********************************************"

exit 0

