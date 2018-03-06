package doi.oracle.apps.icx.por.rcv.webui;
// **********************************************************************
// doi.oracle.apps.icx.por.rcv.webui.DoiRcvSrchCO
//
//
// Joy Pinto 27-APR-2017
//
// Custom version of oracle.apps.icx.por.rcv.webui.DoiRcvSrchCO
//
//
// **********************************************************************
/* $Header: svn://d02584/consolrepos/branches/AP.02.02/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/DoiRcvSrchCO.java 3150 2017-12-07 22:14:52Z svnuser $ */
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.text.DecimalFormat;
import oracle.apps.fnd.common.VersionInfo;
import oracle.apps.fnd.framework.OAException;
import oracle.apps.fnd.framework.OAApplicationModule;
import oracle.apps.fnd.framework.webui.OAPageContext;
import oracle.apps.fnd.framework.webui.beans.OAWebBean;
import oracle.apps.fnd.framework.webui.beans.form.OAFormValueBean;
import oracle.apps.fnd.framework.webui.beans.message.OAMessageChoiceBean;
import oracle.apps.fnd.framework.webui.beans.message.OAMessageLovInputBean;
import oracle.apps.fnd.framework.webui.beans.table.OATableBean;
import oracle.apps.icx.por.rcv.server.ReceiveItemsVOImpl;
import oracle.apps.icx.por.rcv.webui.RcvSrchCO;
import oracle.jbo.Row;
import oracle.jbo.domain.Number;
import oracle.apps.fnd.framework.webui.beans.layout.OAPageLayoutBean;
import oracle.apps.fnd.framework.webui.beans.message.OAMessageTextInputBean;
import oracle.apps.icx.por.rcv.webui.RcvSrchCO;
import oracle.apps.fnd.framework.OAViewObject;
import oracle.apps.fnd.common.MessageToken;

public class DoiRcvSrchCO extends RcvSrchCO {

    public void processRequest(OAPageContext oapagecontext, OAWebBean oawebbean) {
        super.processRequest(oapagecontext, oawebbean);

          OAPageLayoutBean oaPageLayoutBean = (OAPageLayoutBean) oawebbean;
          OATableBean t = (OATableBean) oaPageLayoutBean.findChildRecursive("ResultsTableRN");
          OAMessageTextInputBean receiptQuantityCol = (OAMessageTextInputBean) t.findChildRecursive("ReceiptQuantity");
          OAMessageTextInputBean derivedQuantityAmtCol = (OAMessageTextInputBean) t.findChildRecursive("xx_derived_qty_amt");
          OAMessageLovInputBean invoiceSingleLineCol = (OAMessageLovInputBean) t.findChildRecursive("XXINVOICE");
          OAMessageLovInputBean invoiceMultiLineCol = (OAMessageLovInputBean) t.findChildRecursive("XXINVOICEMULTI");
          int i=0;

      if (isOrgKofaxEnabled(oawebbean,oapagecontext).equals("Y"))
       { // Kofax enabled new code starts
          String lineType = "";
          if (oapagecontext.isLoggingEnabled(1))
            oapagecontext.writeDiagnostics(this, "processRequest Extended(): params - origin = ", 1);
          OATableBean oatablebean = (OATableBean) oawebbean.findIndexedChildRecursive("ResultsTableRN");
          String s = oatablebean.getViewUsageName();
          OAMessageChoiceBean oamessagechoicebean = (OAMessageChoiceBean) oawebbean.findIndexedChildRecursive("xxchoice");
          OAApplicationModule oaapplicationmodule = oapagecontext.getRootApplicationModule();

          String s1 = oapagecontext.getParameter("RequisitionNumber");
          OAFormValueBean oaformvaluebean = (OAFormValueBean) oawebbean.findIndexedChildRecursive("xxlovFV");
          oaformvaluebean.setViewAttributeName("PoHeaderId");
          oaformvaluebean.setViewUsageName(s);
          OAMessageLovInputBean oamessagelovinputbean = (OAMessageLovInputBean) oawebbean.findChildRecursive("XXINVOICE");
          oamessagelovinputbean.setViewUsageName(s);

          ReceiveItemsVOImpl receiveitemsvoimpl = (ReceiveItemsVOImpl) oaapplicationmodule.findViewObject(s);
          OAViewObject vo = (OAViewObject) oaapplicationmodule.findViewObject(s);
          String reqHeaderId     = "0";
          String reqLineId       = "0";
          String receiptQuantity = "0";
          String orderedQty      = "0";
          String derivedQty      = "0";
          OAApplicationModule am = oapagecontext.getApplicationModule(oawebbean);
          PreparedStatement ps   = null;
          String invNumNull      = "N";

         for (Row row1 = vo.first(); row1 != null; row1 = vo.next())
          {


            try
               {
                reqHeaderId       = row1.getAttribute("ReqHeaderId").toString();
                reqLineId         = row1.getAttribute("ReqLineId").toString();
                receiptQuantity   = row1.getAttribute("ReceiptQuantity").toString();
                orderedQty        = row1.getAttribute("OrderedQty").toString();
                derivedQty        = String.format("%.2f",getDerivedValue(reqLineId,Double.parseDouble(receiptQuantity),Double.parseDouble(orderedQty),am,oawebbean,oapagecontext));
                row1.setAttribute("Attribute2", derivedQty);
               }
           catch (Exception ave)
               {
                // Handle Attribute-level validation exceptions here.
                throw new OAException("Custom Exception while deriving the default values " + ave, OAException.ERROR);
               }
               i++;
          }
           lineType = getLineType(reqHeaderId,am,oawebbean) ;
           oapagecontext.putSessionValue("lineType",lineType);
            if (lineType.equalsIgnoreCase("Amount"))
            {
                derivedQuantityAmtCol.setPrompt("Quantity");
                oapagecontext.putSessionValue("primaryField","Amount");
                oapagecontext.putSessionValue("secondaryField","Quantity");
                receiptQuantityCol.setPrompt("Amount (GST Excl) "); // Joy Pinto 26-Sep-2017
            } else
            {
                derivedQuantityAmtCol.setPrompt("Amount (GST Excl) ");  //15/09/17 Rao
                oapagecontext.putSessionValue("primaryField","Quantity");
                oapagecontext.putSessionValue("secondaryField","Amount");
                receiptQuantityCol.setPrompt("Quantity"); // Joy Pinto 26-Sep-2017
            }

        OAException oaexception = new OAException("POC", "XXICX_POR_RCV_DELEGATE_MSG", null, (byte) 2, null);
        oapagecontext.putDialogMessage(oaexception);

        if (i>1)
        {
          invoiceSingleLineCol.setRendered(false);
          invoiceMultiLineCol.setRendered(true);
        }
        else
        {
          invoiceSingleLineCol.setRendered(true);
          invoiceMultiLineCol.setRendered(false);
        }

      }
      else
      {

        derivedQuantityAmtCol.setRendered(false);
        invoiceSingleLineCol.setRendered(false);
        invoiceMultiLineCol.setRendered(false);
      }

    }

    public void processFormRequest(OAPageContext oapagecontext, OAWebBean oawebbean) {
       if (isOrgKofaxEnabled(oawebbean,oapagecontext).equals("Y"))
       { // Kofax enabled new code starts
        if (oapagecontext.isLoggingEnabled(2)) {}

        double invAmount               = 0;
        String invNumber               = "0";
        String invDate                 = "";
        String reqHeaderId             = "0";
        String reqLineId               = "0";
        Number receiptQuantity         = new Number(0);
        double receiptQuantityTotal    = 0;
        Number orderedQty              = new Number(0);
        double derivedQtyAmt           = 0;
        double derivedQtyAmtTotal      = 0;
        OAApplicationModule am         = oapagecontext.getApplicationModule(oawebbean);
        PreparedStatement ps           = null;
        String refInvoiceNum           = "0";
        String duplicateInvoice        = "N";
        String lineType                = "Amount";
        String invBlank                = "N";
        double dDervied                =  0.0;
        String itemDescription         = "";
        // FSC-5995 arellanod 2017/11/22
        DecimalFormat df               = new DecimalFormat("#0.00");
        String dfInvAmount             = null;
        String dfTotAmount             = null;
        String roundedTo               = "N";

        if(oapagecontext.getParameter(SOURCE_PARAM).equals("NavigationBar"))
        {
        OATableBean oatablebean = (OATableBean) oawebbean.findIndexedChildRecursive("ResultsTableRN");
        OAApplicationModule oaapplicationmodule = oapagecontext.getRootApplicationModule();
        String s = oatablebean.getViewUsageName();
        OAViewObject vo = (OAViewObject) oaapplicationmodule.findViewObject(s);

        int i =0;
        invBlank = "N";
        for (Row row1 = vo.first(); row1 != null; row1 = vo.next())
          {
           if("Y".equals(row1.getAttribute("SelectFlag"))) {
            try
              {
                reqHeaderId       = row1.getAttribute("ReqHeaderId").toString();
                reqLineId         = row1.getAttribute("ReqLineId").toString();
                invNumber         = String.valueOf(row1.getAttribute("Attribute1"));
                invDate           = String.valueOf(row1.getAttribute("Attribute4"));
                receiptQuantity   = (Number)row1.getAttribute("ReceiptQuantity");
                orderedQty        = (Number)row1.getAttribute("OrderedQty");
                itemDescription   = String.valueOf(row1.getAttribute("ItemDescription"));
                try {
                //invAmount         = Integer.parseInt(row1.getAttribute("Attribute3").toString()); FSC-3772

                invAmount         = Double.parseDouble(row1.getAttribute("Attribute3").toString());
                }
                catch (Exception e) {
                invAmount =0;
                }
                lineType = getLineType(reqHeaderId,am,oawebbean) ;
                if (!lineType.equals("Amount")) // If the line is Qty based
                {
                derivedQtyAmt     = getDerivedValue(reqLineId,receiptQuantity.doubleValue(),orderedQty.doubleValue(),am,oawebbean,oapagecontext);
                row1.setAttribute("Attribute2", String.format("%.2f",derivedQtyAmt));
                }
                else
                {
                derivedQtyAmt     = (getDerivedValue(reqLineId,receiptQuantity.doubleValue(),orderedQty.doubleValue(),am,oawebbean,oapagecontext));
                row1.setAttribute("Attribute2", String.format("%.2f",derivedQtyAmt));
                }
                receiptQuantityTotal = receiptQuantityTotal+receiptQuantity.doubleValue();
                derivedQtyAmtTotal   = derivedQtyAmtTotal+derivedQtyAmt;
                if(row1.getAttribute("Attribute1") == null)
                // if(!(row1.getAttribute("Attribute1") != null && !row1.getAttribute("Attribute1").equals("")))
                {
                invBlank = "Y";
                }

                if ((i>0) && (!refInvoiceNum.equalsIgnoreCase(invNumber))//&&(!(invNumber != null && !invNumber.equals("")))
                  ) // i >0 implies dont validate the first record
                {
                  duplicateInvoice = "Y";
                }
             }
            catch (Exception ave)
               {
                throw new OAException("Custom Exception while validating PO Receipt Amount and Invoice Amount " + ave, OAException.ERROR);
               }
            refInvoiceNum = invNumber;
            i++;
           }
        }

        if (i==1) // there is only 1 PO Line
           {
             oapagecontext.putSessionValue("itemDescription",itemDescription);
           }
        else
           {
             oapagecontext.putSessionValue("itemDescription","");
           }


        if (invBlank.equals("Y"))
                {
                 // throw new OAException("Please enter Invoice Number for all the selected invoice Lines", OAException.ERROR);
                 throw new OAException("POC", "XXICX_POR_RCV_INVOICE_MISSING");
                }
          if (duplicateInvoice.equals("Y"))
          {
            //throw new OAException("Please note that only 1 Invoice can be selected for a Receipt", OAException.ERROR);
            throw new OAException("POC", "XXICX_POR_RCV_DUPL_INVOICE");
          }

        lineType = getLineType(reqHeaderId,am,oawebbean) ;

        if (lineType.equals("Amount"))
        {
          // FSC-5995 arellanod 2017/11/22
          dfInvAmount = df.format(invAmount);
          dfTotAmount = df.format(receiptQuantityTotal);

          if (dfInvAmount.equals(dfTotAmount))
          {
            roundedTo = "Y";
          }
          else
          {
            //throw new OAException("Invoice Amount "+invAmount+" does not equal PO receipt Amount total "+receiptQuantityTotal, OAException.ERROR);
            //MessageToken[] msgtoken = {new MessageToken("INVAMT ",String.valueOf(invAmount)),new MessageToken("RCPTTOTAL ",String.valueOf(receiptQuantityTotal)) };
            MessageToken[] msgtoken = {new MessageToken("INVAMT ", dfInvAmount), new MessageToken("RCPTTOTAL ", dfTotAmount) };
            throw new OAException("POC", "XXICX_POR_RCV_INV_AMT_MISMATCH", msgtoken, OAException.ERROR, null);
          }
        }
        else
        {
          // FSC-5995 arellanod 2017/11/22
          dfInvAmount = df.format(invAmount);
          dfTotAmount = df.format(derivedQtyAmtTotal);

          if (dfInvAmount.equals(dfTotAmount))
          {
            roundedTo = "Y";
          }
          else
          {
            //throw new OAException("Invoice Amount "+invAmount+" does not equal PO receipt Amount total "+derivedQtyAmtTotal, OAException.ERROR);
            //MessageToken[] msgtoken1 = {new MessageToken("INVAMT ",String.valueOf(invAmount)),new MessageToken("RCPTTOTAL ",String.valueOf(derivedQtyAmtTotal)) };
            MessageToken[] msgtoken1 = {new MessageToken("INVAMT ", dfInvAmount), new MessageToken("RCPTTOTAL ", dfTotAmount) };
            throw new OAException("POC", "XXICX_POR_RCV_INV_AMT_MISMATCH", msgtoken1, OAException.ERROR, null);
          }
        }

        } // Navigation Click

        oapagecontext.putSessionValue("invNumber",invNumber);
        oapagecontext.putSessionValue("invDate",invDate);
        oapagecontext.putSessionValue("overrideComments","Y");
       }
        super.processFormRequest(oapagecontext, oawebbean);
    }

public double getDerivedValue(String reqLineId, double receiptQuantity,double orderedQty,OAApplicationModule am,OAWebBean oawebbean,OAPageContext oapagecontext)
    {
        double derivedValue = 0;
        PreparedStatement ps = null;
        try {
            ps = am.getOADBTransaction().getJdbcConnection().prepareStatement("select XXPO_RCV_OAF_UTIL_PKG.get_derived_value(:1,:2,:3) derived_value from dual");
            ps.setString(1, reqLineId);
            ps.setDouble(2, receiptQuantity);
            ps.setDouble(3, orderedQty);
            ResultSet rs = ps.executeQuery();
            if (rs.next())
            {
              derivedValue = rs.getDouble("derived_value");
            }
        } catch (SQLException sq) {
            throw new OAException("Custom Exception " + sq, OAException.ERROR);
        } finally
                {
                 try
                   {
                    ps.close();
                   } catch (Exception e)
                          {
                          throw new OAException("Custom Exception " + e, OAException.ERROR);
                          }
                }
      return derivedValue;
    }

    public String getLineType(String reqHeaderId,OAApplicationModule am,OAWebBean oawebbean)
    {
     String lineType = "";
     PreparedStatement ps = null;
        try {
            ps = am.getOADBTransaction().getJdbcConnection().prepareStatement("select XXPO_RCV_OAF_UTIL_PKG.get_line_type(:1) line_type from dual");
            ps.setString(1, reqHeaderId);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                if (rs.getString("line_type") != null) {
                    lineType = rs.getString("line_type");
                }
            }
          } catch (SQLException sq) {
            throw new OAException("Custom Exception " + sq, OAException.ERROR);
                                    }
        finally
        {
            try {
                ps.close();
            } catch (Exception e) {
                throw new OAException("Custom Exception " + e, OAException.ERROR);
            }
        }

        return lineType;
    }

    public String isOrgKofaxEnabled(OAWebBean oawebbean,OAPageContext oapagecontext)
    {
     String iskofaxEnabled = "";
     PreparedStatement ps = null;
     OAApplicationModule am = oapagecontext.getApplicationModule(oawebbean);
        try {
            ps = am.getOADBTransaction().getJdbcConnection().prepareStatement("select nvl(fnd_profile.VALUE_SPECIFIC(NAME => 'POC_KOFAX_ENABLED',ORG_ID => :1),'N') kofax_enabled from dual");
            ps.setInt(1, oapagecontext.getOrgId());
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                if (rs.getString("kofax_enabled") != null) {
                    iskofaxEnabled = rs.getString("kofax_enabled");
                }
            }
          } catch (SQLException sq) {
            throw new OAException("Custom Exception " + sq, OAException.ERROR);
                                    }
        finally
        {
            try {
                ps.close();
            } catch (Exception e) {
                throw new OAException("Custom Exception " + e, OAException.ERROR);
            }
        }

        return iskofaxEnabled;
    }

    public DoiRcvSrchCO() {}

    public static final String RCS_ID = "$Header: svn://d02584/consolrepos/branches/AP.02.02/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/DoiRcvSrchCO.java 3150 2017-12-07 22:14:52Z svnuser $";
    public static final boolean RCS_ID_RECORDED = VersionInfo.recordClassVersion("$Header: svn://d02584/consolrepos/branches/AP.02.02/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/DoiRcvSrchCO.java 3150 2017-12-07 22:14:52Z svnuser $", "oracle.apps.icx.por.rcv.webui");

}
