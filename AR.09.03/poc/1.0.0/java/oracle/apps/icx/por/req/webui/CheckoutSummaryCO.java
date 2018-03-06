// **********************************************************************
// oracle.apps.icx.por.req.webui.CheckoutSummaryCO
//
// Bruce Freshwater 27-FEB-2009
//
// Custom version of oracle.apps.icx.por.req.webui.CheckoutSummaryCO
//
// This controller has already been invasively customised during earlier
// development phases (for reasons unknown), so there is nothing toit's be
// gained by extending it and creating a custom version.
//
// New logic in this phase simply caters for NULL quantity values (which
// can occur with service requisitions) when making the GST calculation.
//
// In these instances, the line amount is used, instead of multiplying
// Quantity and Unit Price.
//
//
// Jon Bartlett (Red Rock) 14-MAY-2009
//
// Changed Requisition Amount Limits to read from Profile Options
// See specification: DOT MD070 iProc CMS Number Validation.doc
//
// **********************************************************************
package oracle.apps.icx.por.req.webui;

import com.sun.java.util.collections.ArrayList;
import com.sun.java.util.collections.HashMap;

import doi.oracle.apps.util.DoiUtil;

import oracle.apps.fnd.common.VersionInfo;
import oracle.apps.fnd.framework.OAApplicationModule;
import oracle.apps.fnd.framework.OAException;
import oracle.apps.fnd.framework.OAViewObject;
import oracle.apps.fnd.framework.server.OAApplicationModuleImpl;
import oracle.apps.fnd.framework.server.OADBTransaction;
import oracle.apps.fnd.framework.webui.OADialogPage;
import oracle.apps.fnd.framework.webui.OAPageContext;
import oracle.apps.fnd.framework.webui.beans.OADescriptiveFlexBean;
import oracle.apps.fnd.framework.webui.beans.OAWebBean;
import oracle.apps.fnd.framework.webui.beans.form.OASubmitButtonBean;
import oracle.apps.fnd.framework.webui.beans.layout.OACellFormatBean;
import oracle.apps.fnd.framework.webui.beans.layout.OAPageLayoutBean;
import oracle.apps.fnd.framework.webui.beans.nav.OANavigationBarBean;
import oracle.apps.fnd.framework.webui.beans.nav.OAPageButtonBarBean;

import oracle.apps.icx.por.common.PorAppsContext;
import oracle.apps.icx.por.common.webui.ClientUtil;
import oracle.apps.icx.por.req.server.PoRequisitionLinesVOImpl;
import oracle.apps.icx.por.req.server.PoRequisitionLinesVORowImpl;

import oracle.jbo.domain.Number;

import oracle.jdbc.driver.OraclePreparedStatement;
import oracle.jdbc.driver.OracleResultSet;

import java.util.Enumeration;

import oracle.apps.fnd.framework.webui.beans.message.OAMessageLovInputBean; //PO.12.01
import oracle.apps.fnd.framework.webui.beans.message.OAMessageTextInputBean; //PO.12.01
import oracle.apps.icx.por.req.server.PoRequisitionHeadersVOImpl;  //PO.12.01
import oracle.apps.icx.por.req.server.PoRequisitionHeadersVORowImpl; //PO.12.01
import oracle.apps.fnd.framework.webui.beans.message.OAMessageTextInputBean;


// Referenced classes of package oracle.apps.icx.por.req.webui:
//            CheckoutInfoBaseCO, BoundValueUtil
public class CheckoutSummaryCO extends CheckoutInfoBaseCO {
    public static final String RCS_ID = "$Header: svn://d02584/consolrepos/branches/AR.09.03/poc/1.0.0/java/oracle/apps/icx/por/req/webui/CheckoutSummaryCO.java 1242 2017-06-26 05:12:05Z svnuser $";
    public static final boolean RCS_ID_RECORDED = VersionInfo.recordClassVersion("$Header: svn://d02584/consolrepos/branches/AR.09.03/poc/1.0.0/java/oracle/apps/icx/por/req/webui/CheckoutSummaryCO.java 1242 2017-06-26 05:12:05Z svnuser $",
            "oracle.apps.icx.por.req.webui");
    public boolean CMSNumberRequired = false;
    public boolean CMSNumberWarningRequired = false;
    public boolean ApprovedByFinDelRequired = false;
    public boolean ApprovalDateRequired = false;
    public Number CMSWarningThreshold = new Number(0);

    public CheckoutSummaryCO() {
    }

    protected String getBusinessView(OAPageContext oapagecontext, OAWebBean oawebbean) {
        return "DefaultBizView";
    }

    protected void doiDebug(String msg, OAApplicationModule am) {
        DoiUtil.debug(toString(), msg, (OAApplicationModuleImpl) am);
    }

    public void logRequestParameters(OAPageContext pageContext, OAApplicationModule am) {
        String elementName;

        for (Enumeration e = pageContext.getParameterNames(); e.hasMoreElements();
                doiDebug("Parameter: " + elementName + " = " + pageContext.getParameter(elementName), am))
            elementName = e.nextElement().toString();
    }

    public void processRequest(OAPageContext oapagecontext, OAWebBean oawebbean) {
        super.processRequest(oapagecontext, oawebbean);

        String s = oapagecontext.getParameter("porMode");

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processRequest().begin", 1);
            logParam(this, oapagecontext, "CheckoutSummaryPG - mode", s, 1);
        }

        OAApplicationModule oaapplicationmodule = oapagecontext.getApplicationModule(oawebbean);
        executePrepareForDisplay(oapagecontext, oaapplicationmodule, s);
        prepareBoundValuesForSpelAttributes(oapagecontext, oawebbean);
        prepareUI(oapagecontext, oawebbean, oaapplicationmodule);

        if (oapagecontext.isLoggingEnabled(1)) {
            oapagecontext.writeDiagnostics(this, "XXDOT: processRequest: event:" + oapagecontext.getParameter("event"), 1);
        }

        OADescriptiveFlexBean headerDffBean = (OADescriptiveFlexBean) oawebbean.findChildRecursive("ReqHeaderDFF");

        // Financial Delegate Field
        OAWebBean finDelegate = headerDffBean.findChildRecursive("ReqHeaderDFF5"); //PO.12.01 //rectify the warnings while compilation

        // Approval Date Field
        OAWebBean approvalDate = headerDffBean.findChildRecursive("ReqHeaderDFF6"); //PO.12.01

        // CMS Number Field
        OAWebBean cmsContractNumber = headerDffBean.findChildRecursive("ReqHeaderDFF1");

        cmsContractNumber.setRendered(false); // Hiding the DFF attribute3 as custom fields are being used to handle this PO.12.01


        //PO.12.01  -- Start
		OAMessageLovInputBean customCMSLov = (OAMessageLovInputBean)oawebbean.findChildRecursive("xxpoCMSLOV");     //for attribute3 PO.12.01
		OAMessageTextInputBean customCMSText = (OAMessageTextInputBean)oawebbean.findChildRecursive("xxpoCMSText"); //for attribute3 PO.12.01

		PoRequisitionHeadersVOImpl poRequisitionHeadersVOImpl = (PoRequisitionHeadersVOImpl) oaapplicationmodule.findViewObject("PoRequisitionHeadersVO");
		PoRequisitionHeadersVORowImpl poRequisitionHeadersVORowImpl = (PoRequisitionHeadersVORowImpl) poRequisitionHeadersVOImpl.first();

		if (isCMSLOVEnabled(oawebbean,oapagecontext).equals("Y") ) //i.e. DOI, so enable LOV field and hide free text field
		{

			customLog(oapagecontext, "XXDOT:isCMSLOVEnabled:"+isCMSLOVEnabled(oawebbean,oapagecontext));

			customCMSLov.setRendered(true);
			customCMSText.setRendered(false);


			if (( customCMSLov.getValue(oapagecontext) ==null || "".equals(customCMSLov.getValue(oapagecontext)) ) && oapagecontext.getSessionValue("cmsSession") != "X")
				{

					customLog(oapagecontext, "XXDOT:customCMSLov is null in processrequest so setting vo value");
					customCMSLov.setValue(oapagecontext,poRequisitionHeadersVORowImpl.getAttribute3());
			}
			else//new
				if (oapagecontext.getSessionValue("cmsSession") == "X") //new
					customCMSLov.setValue(oapagecontext,""); //new

			   customLog(oapagecontext, "XXDOT:after getAttribute3:"+isCMSLOVEnabled(oawebbean,oapagecontext)+" attr3 value;"+poRequisitionHeadersVORowImpl.getAttribute3());
			  //default the value from DFF
		}
		else
		{
			customLog(oapagecontext, "XXDOT:isCMSLOVEnabled:"+isCMSLOVEnabled(oawebbean,oapagecontext));
			customCMSLov.setRendered(false);
			customCMSText.setRendered(true);

			//if (customCMSText.getValue(oapagecontext) ==null || "".equals(customCMSText.getValue(oapagecontext)) )
			if (( customCMSText.getValue(oapagecontext) ==null || "".equals(customCMSText.getValue(oapagecontext)) ) && oapagecontext.getSessionValue("cmsSession") != "X")
				{	customCMSText.setValue(oapagecontext,poRequisitionHeadersVORowImpl.getAttribute3());
			}
			else//new
				if (oapagecontext.getSessionValue("cmsSession") == "X") //new
				customCMSText.setValue(oapagecontext,""); //new


			customLog(oapagecontext, "XXDOT:after getAttribute3:"+isCMSLOVEnabled(oawebbean,oapagecontext)+" attr3 value"+poRequisitionHeadersVORowImpl.getAttribute3());

		}
		//PO.12.01


        PoRequisitionLinesVOImpl poRequisitionLinesVOImpl = (PoRequisitionLinesVOImpl) oaapplicationmodule.findViewObject(
                "PoRequisitionLinesVO");
        PoRequisitionLinesVORowImpl poRequisitionLinesVORowImpl = (PoRequisitionLinesVORowImpl) poRequisitionLinesVOImpl.first();

        // Warning Category Flag
        Boolean warningCategory = Boolean.FALSE;

        //
        int numOfLines = poRequisitionLinesVOImpl.getFetchedRowCount();
        doiDebug("number of lines = " + numOfLines, oaapplicationmodule);

        // Reg Total
        double reqTotalExclGst = 0.0D;

        // Array of Item Categories JB 22/10/09
        ReqLineItemCategory[] reqLineItemCategories = new ReqLineItemCategory[numOfLines];

        // Loop through Req Lines
        for (int i = 0; i < numOfLines; i++) {
            String category = poRequisitionLinesVORowImpl.getCategory();
            Number categoryId = poRequisitionLinesVORowImpl.getCategoryId();
            Number unitPrice = poRequisitionLinesVORowImpl.getUnitPrice();
            Number quantity = poRequisitionLinesVORowImpl.getQuantity();

            // *****************************************
            // Bruce Freshwater 27-FEB-2009
            //
            // Start of changes
            //
            // Check for NULL unit price and/or quantity,
            // and use amount instead, as the basis for
            // the GST calculation
            // *****************************************
            Number lineTotalExclGst;
            doiDebug("unitPrice = " + unitPrice, oaapplicationmodule);
            doiDebug("quantity  = " + quantity, oaapplicationmodule);

            if ((unitPrice == null) || (quantity == null)) {
                lineTotalExclGst = poRequisitionLinesVORowImpl.getAmount();
            } else {
                lineTotalExclGst = unitPrice.multiply(quantity);
            }

            // *****************************************
            // Bruce Freshwater 27-FEB-2009
            //
            // End of changes
            // *****************************************
            reqTotalExclGst += lineTotalExclGst.doubleValue();
            doiDebug("categoryId = " + categoryId, oaapplicationmodule);
            doiDebug("category = " + category, oaapplicationmodule);
            doiDebug("lineTotalExclGst = " + lineTotalExclGst, oaapplicationmodule);

            // Fetch Item Category DFF Values -- JB 22/10/09
            if (oapagecontext.isLoggingEnabled(1)) {
                oapagecontext.writeDiagnostics(this, "XXDOT: processRequest about to call ReqLineItemCategory", 1);
            }

            ReqLineItemCategory reqLineCat = new ReqLineItemCategory(oapagecontext, oawebbean, categoryId);

            reqLineItemCategories[i] = reqLineCat;

            /*            if (categoryId.equals(new Number(49))) {
                            cmsContractNumber.setRequired("yes");
                            finDelegate.setRequired("yes");
                            approvalDate.setRequired("yes");
                        }

                        if (categoryId.equals(new Number(50))) {
                            finDelegate.setRequired("yes");
                            approvalDate.setRequired("yes");
                            warningCategory = Boolean.TRUE;
                        }

                        if (categoryId.equals(new Number(41))) {
                            cmsContractNumber.setRequired("yes");
                        }

                        if (categoryId.equals(new Number(43))) {
                            warningCategory = Boolean.TRUE;
                        }

            */
            poRequisitionLinesVORowImpl = (PoRequisitionLinesVORowImpl) poRequisitionLinesVOImpl.next();
        }

        // Now we know the Req Total, loop through the Item Category DFF Array  // JB 22/10/09
        for (int j = 0; j < numOfLines; j++) {
            if (oapagecontext.isLoggingEnabled(1)) {
                oapagecontext.writeDiagnostics(this, "XXDOT: in Category loop i:" + j, 1);
            }

            // First set the validation on Approval Date and Approval by Fin Delegate
            if (reqLineItemCategories[j].ApprovalDateRequired) {
                approvalDate.setRequired("yes");

                if (oapagecontext.isLoggingEnabled(1)) {
                    oapagecontext.writeDiagnostics(this, "XXDOT: setting Approval Date to Required", 1);
                }
            }

            if (reqLineItemCategories[j].ApprovedByFinDelRequired) {
                finDelegate.setRequired("yes");

                if (oapagecontext.isLoggingEnabled(1)) {
                    oapagecontext.writeDiagnostics(this, "XXDOT: setting Approved by Fin Del to Required", 1);
                }
            }

            if (oapagecontext.isLoggingEnabled(1)) {
                oapagecontext.writeDiagnostics(this, "XXDOT: reqTotalExclGst: " + reqTotalExclGst, 1);
                oapagecontext.writeDiagnostics(this,
                    "XXDOT: CMSValidationThreshold: " + reqLineItemCategories[j].CMSValidationThreshold.doubleValue(), 1);
            }

            if (reqTotalExclGst >= reqLineItemCategories[j].CMSValidationThreshold.doubleValue()) {
                if (reqLineItemCategories[j].CMSNumberHighAction.equals(reqLineItemCategories[j].VALIDATION_REQUIRED)) {
                    //cmsContractNumber.setRequired("yes");
                    //PO.12.01
                    if (isCMSLOVEnabled(oawebbean,oapagecontext).equals("Y") ) //i.e. DOI, so enable LOV field and hide free text field
                    {
						customCMSLov.setRequired("yes");
					}
					else
					{
						customCMSText.setRequired("yes");
					}
					//end of PO.12.01

                    if (oapagecontext.isLoggingEnabled(1)) {
                        oapagecontext.writeDiagnostics(this, "XXDOT: setting CMS Number to Required", 1);
                    }
                } else if (reqLineItemCategories[j].CMSNumberHighAction.equals(reqLineItemCategories[j].VALIDATION_WARNING)) {
                    warningCategory = Boolean.TRUE;

                    if (oapagecontext.isLoggingEnabled(1)) {
                        oapagecontext.writeDiagnostics(this, "XXDOT: setting Warning Category flag to true", 1);
                    }
                }
            } else // Req Total lower than threshold
             {
                if (reqLineItemCategories[j].CMSNumberLowAction.equals(reqLineItemCategories[j].VALIDATION_REQUIRED)) {

                    //cmsContractNumber.setRequired("yes"); //PO.12.01
                    //PO.12.01
                    if (isCMSLOVEnabled(oawebbean,oapagecontext).equals("Y") ) //i.e. DOI, so enable LOV field and hide free text field
                    {
						customCMSLov.setRequired("yes");
					}
					else
					{
						customCMSText.setRequired("yes");
					}
					//End PO.12.01

                    if (oapagecontext.isLoggingEnabled(1)) {
                        oapagecontext.writeDiagnostics(this, "XXDOT: setting CMS Number to Required", 1);
                    }
                } else if (reqLineItemCategories[j].CMSNumberLowAction.equals(reqLineItemCategories[j].VALIDATION_WARNING)) {
                    warningCategory = Boolean.TRUE;

                    if (oapagecontext.isLoggingEnabled(1)) {
                        oapagecontext.writeDiagnostics(this, "XXDOT: setting Warning Category flag to true", 1);
                    }
                }
            }

            if (oapagecontext.isLoggingEnabled(1)) {
                oapagecontext.writeDiagnostics(this, "XXDOT: end Category loop i:" + j, 1);
            }
        }

        // end loop
        // both CMS Warning and Required cannot occur together, Required wins
        /* PO.12.01
        if (cmsContractNumber.getRequired().equalsIgnoreCase("yes") && (warningCategory == Boolean.TRUE)) {
            warningCategory = Boolean.FALSE;

            if (oapagecontext.isLoggingEnabled(1)) {
                oapagecontext.writeDiagnostics(this, "XXDOT: both CMS warning and Required set. Turning warning off", 1);
            }
        }
        */

        doiDebug("reqTotalExclGst = " + String.valueOf(reqTotalExclGst), oaapplicationmodule);
    }

    protected void executePrepareForDisplay(OAPageContext oapagecontext, OAApplicationModule oaapplicationmodule, String s) {
        if ("fromOneTime".equals(s)) {
            String s1 = oapagecontext.getParameter("porOneTimeLocationAdded");

            if ("true".equals(s1)) {
                ArrayList arraylist1 = new ArrayList(2);
                arraylist1.add("processAddOneTimeLocation");
                arraylist1.add("summary");
                executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist1);

                return;
            }
        } else {
            ArrayList arraylist = new ArrayList(3);
            arraylist.add("prepareForDisplay");
            arraylist.add("summary");
            arraylist.add(oapagecontext.getParameter("porSummaryPageFromCart"));
            executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist);
        }
    }

    protected void prepareBoundValuesForSpelAttributes(OAPageContext oapagecontext, OAWebBean oawebbean) {
        BoundValueUtil.bindRenderedAttr("DeliveryCell", oawebbean, "IsGoodsServicesRequisition", "ReqSummaryVO");
        BoundValueUtil.bindRenderedAttr("UrgentCheckBox", oawebbean, "IsUrgentFlagRendered");
        BoundValueUtil.bindRenderedAttr("UrgentMultiple", oawebbean, "IsUrgentFlagMultiple");
        BoundValueUtil.bindRenderedAttr("NeedByDate", oawebbean, "IsNeedByDateRendered");
        BoundValueUtil.bindRenderedAttr("NeedByDateMultiple", oawebbean, "IsNeedByDateMultiple");
        BoundValueUtil.bindRenderedAttr("Requester", oawebbean, "IsRequesterRendered");
        BoundValueUtil.bindRenderedAttr("RequesterMultiple", oawebbean, "IsRequesterMultiple");
        BoundValueUtil.bindRenderedAttr("Phone", oawebbean, "IsRequesterRendered");
        BoundValueUtil.bindRenderedAttr("Fax", oawebbean, "IsRequesterRendered");
        BoundValueUtil.bindRenderedAttr("Email", oawebbean, "IsRequesterRendered");
        BoundValueUtil.bindRenderedAttr("DeliverToLocation", oawebbean, "IsDeliverToLocationRendered");
        BoundValueUtil.bindReadOnlyAttr("DeliverToLocation", oawebbean, "IsDeliverToLocationReadOnly");
        BoundValueUtil.bindRenderedAttr("DeliverToLocationMultiple", oawebbean, "IsDeliverToLocationMultiple");
        BoundValueUtil.bindRenderedAttr("EnterOneTimeAddr", oawebbean, "IsAddOneTimeLocationRendered", "ReqSummaryVO");
        BoundValueUtil.bindRenderedAttr("EnterOneTimeAddrDummy", oawebbean, "IsAddOneTimeLocationRendered", "ReqSummaryVO");
        BoundValueUtil.bindRenderedAttr("EditOneTimeAddr", oawebbean, "IsEditDelOneTimeLocationRendered", "ReqSummaryVO");
        BoundValueUtil.bindRenderedAttr("EditOneTimeAddrDummy", oawebbean, "IsEditDelOneTimeLocationRendered", "ReqSummaryVO");
        BoundValueUtil.bindRenderedAttr("DeleteOneTimeAddr", oawebbean, "IsEditDelOneTimeLocationRendered", "ReqSummaryVO");
        BoundValueUtil.bindRenderedAttr("DeleteOneTimeAddrDummy", oawebbean, "IsEditDelOneTimeLocationRendered", "ReqSummaryVO");
        BoundValueUtil.bindRenderedAttr("DestinationTypeMultiple", oawebbean, "IsDestinationTypeMultipleRendered");
        BoundValueUtil.bindRenderedAttr("InventoryCheckBox", oawebbean, "IsInventoryCheckboxRendered");
        BoundValueUtil.bindRenderedAttr("ShopFloorCheckBox", oawebbean, "IsShopFloorCheckboxRendered");
        BoundValueUtil.bindRenderedAttr("DestinationTypeChoice", oawebbean, "IsDestinationTypeChoiceRendered");
        BoundValueUtil.bindRenderedAttr("SubInventory", oawebbean, "IsSubInventoryRendered");
        BoundValueUtil.bindRenderedAttr("SubInventoryMultiple", oawebbean, "IsSubInventoryMultipleRendered");
        BoundValueUtil.bindRenderedAttr("WorkOrder", oawebbean, "IsWorkOrderRendered");
        BoundValueUtil.bindRenderedAttr("WorkOrderMultiple", oawebbean, "IsWorkOrderMultipleRendered");
        BoundValueUtil.bindRenderedAttr("OperationReference", oawebbean, "IsOperationReferenceRendered");
        BoundValueUtil.bindRenderedAttr("OperationReferenceMultiple", oawebbean, "IsOperationReferenceMultipleRendered");
        BoundValueUtil.bindRenderedAttr("SuggestedBuyer", oawebbean, "IsSuggestedBuyerRendered");
        BoundValueUtil.bindRenderedAttr("SuggestedBuyerMultiple", oawebbean, "IsSuggestedBuyerMultipleRendered");
        BoundValueUtil.bindRenderedAttr("UnNumber", oawebbean, "IsUnNumberRendered");
        BoundValueUtil.bindRenderedAttr("UnNumberMultiple", oawebbean, "IsUnNumberMultiple");
        BoundValueUtil.bindRenderedAttr("HazardClass", oawebbean, "IsHazardClassRendered");
        BoundValueUtil.bindRenderedAttr("HazardClassMultiple", oawebbean, "IsHazardClassMultiple");
        BoundValueUtil.bindRenderedAttr("PCard", oawebbean, "IsPCardRendered");
        BoundValueUtil.bindRenderedAttr("ProjectOnSummary", oawebbean, "IsProjectRendered");
        BoundValueUtil.bindReadOnlyAttr("ProjectOnSummary", oawebbean, "IsProjectTaskReadOnly");
        BoundValueUtil.bindRenderedAttr("ProjectMultiple", oawebbean, "IsProjectMultipleRendered");
        BoundValueUtil.bindRenderedAttr("Task", oawebbean, "IsTaskRendered");
        BoundValueUtil.bindReadOnlyAttr("Task", oawebbean, "IsProjectTaskReadOnly");
        BoundValueUtil.bindDisabledAttr("Task", oawebbean, "IsTaskDisabled");
        BoundValueUtil.bindRenderedAttr("TaskMultiple", oawebbean, "IsTaskMultipleRendered");
        BoundValueUtil.bindRenderedAttr("Award", oawebbean, "IsAwardRendered");
        BoundValueUtil.bindDisabledAttr("Award", oawebbean, "IsAwardDisabled");
        BoundValueUtil.bindRenderedAttr("AwardMultiple", oawebbean, "IsAwardMultipleRendered");
        BoundValueUtil.bindRenderedAttr("ExpenditureType", oawebbean, "IsExpenditureTypeRendered");
        BoundValueUtil.bindRenderedAttr("ExpenditureTypeMultiple", oawebbean, "IsExpenditureTypeMultipleRendered");
        BoundValueUtil.bindRenderedAttr("ExpenditureOrg", oawebbean, "IsExpenditureOrgRendered");
        BoundValueUtil.bindRenderedAttr("ExpenditureOrgMultiple", oawebbean, "IsExpenditureOrgMultipleRendered");
        BoundValueUtil.bindRenderedAttr("ExpenditureItemDate", oawebbean, "IsExpenditureItemDateRendered");
        BoundValueUtil.bindRenderedAttr("ExpenditureItemDateMultiple", oawebbean, "IsExpenditureItemDateMultipleRendered");
        BoundValueUtil.bindRenderedAttr("Taxable", oawebbean, "IsTaxStatusRendered");
        BoundValueUtil.bindReadOnlyAttr("Taxable", oawebbean, "IsTaxStatusReadOnly");
        BoundValueUtil.bindRenderedAttr("TaxableMultiple", oawebbean, "IsTaxStatusMultiple");
        BoundValueUtil.bindRenderedAttr("TaxCode", oawebbean, "IsTaxCodeRendered");
        BoundValueUtil.bindReadOnlyAttr("TaxCode", oawebbean, "IsTaxCodeReadOnly");
        BoundValueUtil.bindRenderedAttr("TaxCodeMultiple", oawebbean, "IsTaxCodeMultipleRendered");
        BoundValueUtil.bindRenderedAttr("ChargeAccount", oawebbean, "IsChargeAccountRendered");
        BoundValueUtil.bindRenderedAttr("ChargeAccountMultiple", oawebbean, "IsChargeAccountMultipleRendered");
        BoundValueUtil.bindRenderedAttr("EnterChargeAccount", oawebbean, "IsEnterChargeAccountRendered");
        BoundValueUtil.bindRenderedAttr("TransactionCode", oawebbean, "IsTransactionCodeRendered");
        BoundValueUtil.bindRenderedAttr("TransactionCodeMultiple", oawebbean, "IsTransactionCodeMultipleRendered");
        BoundValueUtil.bindRenderedAttr("GLDate", oawebbean, "IsGLDateRendered");
        BoundValueUtil.bindRenderedAttr("GLDateMultiple", oawebbean, "IsGLDateMultipleRendered");
        BoundValueUtil.bindRenderedAttr("ReqLineDFF", oawebbean, "IsReqLineDFFRendered");
        BoundValueUtil.bindRenderedAttr("ReqLineDFFMultiple", oawebbean, "IsReqLineDFFMultiple");
    }

    protected void prepareUI(OAPageContext oapagecontext, OAWebBean oawebbean, OAApplicationModule oaapplicationmodule) {
        prepareButtons(oapagecontext, oawebbean);
        prepareTrainAndNavigation(oapagecontext, oawebbean);
        prepareDescriptiveFlexFields(oapagecontext, oawebbean);
        preparePCardDropdown(oapagecontext, oawebbean);

        OACellFormatBean oacellformatbean = (OACellFormatBean) oawebbean.findChildRecursive("ReqLineDFFCell");

        if (oacellformatbean != null) {
            oacellformatbean.setColumnSpan(2);
        }
    }

    protected void prepareDescriptiveFlexFields(OAPageContext oapagecontext, OAWebBean oawebbean) {
        OADescriptiveFlexBean oadescriptiveflexbean = (OADescriptiveFlexBean) oawebbean.findIndexedChildRecursive("ReqHeaderDFF");

        if (oadescriptiveflexbean != null) {
            oadescriptiveflexbean.setContextListRendered(false);
            oadescriptiveflexbean.mergeSegmentsWithParent(oapagecontext);
        }

        OADescriptiveFlexBean oadescriptiveflexbean1 = (OADescriptiveFlexBean) oawebbean.findIndexedChildRecursive("ReqLineDFF");

        if (oadescriptiveflexbean1 != null) {
            oadescriptiveflexbean1.setContextListRendered(false);
            oadescriptiveflexbean1.mergeSegmentsWithParent(oapagecontext);
        }
    }

    protected void prepareButtons(OAPageContext oapagecontext, OAWebBean oawebbean) {
        OASubmitButtonBean oasubmitbuttonbean = (OASubmitButtonBean) oawebbean.findChildRecursive("IcxPrintablePageButton");
        oasubmitbuttonbean.setRendered(false);

        PorAppsContext porappscontext = ClientUtil.getPorAppsContext(oapagecontext);
        String s = porappscontext.getCurrentFlow();

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "prepareButtons().begin", 1);
            logParam(this, oapagecontext, "currentFlow", s, 1);
        }

        if ("ApproverCheckoutFlow".equals(s)) {
            OAWebBean oawebbean1 = oawebbean.findChildRecursive("Cancel");
            oawebbean1.setRendered(false);

            OAWebBean oawebbean2 = oawebbean.findChildRecursive("Save");
            oawebbean2.setRendered(false);
        }
    }

    protected void prepareTrainAndNavigation(OAPageContext oapagecontext, OAWebBean oawebbean) {
        OAPageLayoutBean oapagelayoutbean = (OAPageLayoutBean) oawebbean;
        OANavigationBarBean oanavigationbarbean = (OANavigationBarBean) createWebBean(oapagecontext, "NAVIGATION_BAR", null,
                "CheckoutNavigationBar");
        oanavigationbarbean.setValue(1);
        oanavigationbarbean.setMinValue(1);
        oanavigationbarbean.setMaxValue(3);
        oanavigationbarbean.setFormSubmitted(true);

        OAPageButtonBarBean oapagebuttonbarbean = (OAPageButtonBarBean) oapagelayoutbean.getPageButtons();
        oapagebuttonbarbean.addIndexedChild(oanavigationbarbean);
    }

    public void processFormRequest(OAPageContext oapagecontext, OAWebBean oawebbean) {
        super.processFormRequest(oapagecontext, oawebbean);

        OAApplicationModule oaapplicationmodule = oapagecontext.getApplicationModule(oawebbean);

        if (oapagecontext.isLoggingEnabled(1)) {
            oapagecontext.writeDiagnostics(this, "XXDOT: processFormRequest: event:" + oapagecontext.getParameter("event"), 1);
        }

        String event = oapagecontext.getParameter("event");


		//Start PO.12.01
        String cms= "";
        String cmsForSession = "";
		PoRequisitionHeadersVOImpl poRequisitionHeadersVOImpl = (PoRequisitionHeadersVOImpl) oaapplicationmodule.findViewObject("PoRequisitionHeadersVO");
		PoRequisitionHeadersVORowImpl poRequisitionHeadersVORowImpl = (PoRequisitionHeadersVORowImpl) poRequisitionHeadersVOImpl.first();

		OAMessageLovInputBean customCMSLov = (OAMessageLovInputBean)oawebbean.findChildRecursive("xxpoCMSLOV"); //for attribute3
		OAMessageTextInputBean customCMSText = (OAMessageTextInputBean)oawebbean.findChildRecursive("xxpoCMSText"); //for attribute3



			if (isCMSLOVEnabled(oawebbean,oapagecontext).equals("Y") )
			{
				if (customCMSLov.getValue(oapagecontext) !=null)
				{	cmsForSession = customCMSLov.getValue(oapagecontext).toString();  //handle null
				}
		    }
			else
			{
				if (customCMSText.getValue(oapagecontext) !=null)
				{	cmsForSession = customCMSText.getValue(oapagecontext).toString(); //handle null
			    }
		    }
			 if ("".equals(cmsForSession) || (cmsForSession == null))
			 {
				oapagecontext.putSessionValue("cmsSession","X");
			 }
			 else
			 	oapagecontext.putSessionValue("cmsSession",cmsForSession);
		//end PO.12.01



        if ("goto".equals(event) || "submit".equals(event) || "save".equals(event)) {  // Save included  //PO.12.01
            //String cmsContractNumber = oapagecontext.getParameter("ReqHeaderDFF1"); //PO.12.01
            //doiDebug("cmsContractNumber = " + cmsContractNumber, oaapplicationmodule); //PO.12.01

				/****************************************************************************************************************/
				//Start PO.12.01 in PFR



				/* ---------------------------------------------------------------------------
				*    CMS Contract Number Validation
				*    Validates CMS number based on Org level profile
				* ------------------------------------------------------------------------ */
				doiDebug("isCMSLOVEnabled(oawebbean,oapagecontext): " + isCMSLOVEnabled(oawebbean,oapagecontext), oaapplicationmodule);
				customLog(oapagecontext, "isCMSLOVEnabled(oawebbean,oapagecontext): " + isCMSLOVEnabled(oawebbean,oapagecontext));
				customLog(oapagecontext, "isCMSLOVEnabled(oawebbean,oapagecontext).equals  " + isCMSLOVEnabled(oawebbean,oapagecontext));

				if (customCMSText.getValue(oapagecontext) !=null || customCMSLov.getValue(oapagecontext) !=null)
				{
					if (isCMSLOVEnabled(oawebbean,oapagecontext).equals("N") )
					{
					//Check CMS Mod 11 (Checksum)
					customLog(oapagecontext,  "isCMSLOVEnabled = No, checking Checksum validation" );


						String cmsText = customCMSText.getValue(oapagecontext).toString();
						if (IsMod11Valid(cmsText) == false) //if true
						{

							customLog(oapagecontext, "IsMod11Valid(customCMSText) - false ");
							throw new OAException("POC", "XXPO_CMS_CHECKSUM_ERR",null,OAException.ERROR,null);
						}
						else		//valid Checksum
						{
							customLog(oapagecontext, "IsMod11Valid(cmsContractNumber)  - yes valid" );
						}
					}
					else		//Lov is not enabled
					{
						//verifies CMS number in XXPO_CONTRACTS_ALL table
						String cmsLovValue ="";
						cmsLovValue = customCMSLov.getValue(oapagecontext).toString();
						String isValidCMS = isCMSNumber(oapagecontext, oawebbean, cmsLovValue);

						if (isValidCMS.equals("N"))
						{
							doiDebug("isValidCMS : No " + cmsLovValue, oaapplicationmodule);
							customLog(oapagecontext, "isValidCMS : No " + cmsLovValue);
							throw new OAException("ICX", "POC_CMS_INVALID",null,OAException.ERROR,null);
						}
						else
						{
						customLog(oapagecontext,  "isValidCMS : yes " + cmsLovValue);
						doiDebug("isValidCMS : Yes" + cmsLovValue, oaapplicationmodule);
						}
					}

						if (isCMSLOVEnabled(oawebbean,oapagecontext).equals("Y"))
						{
							cms = customCMSLov.getValue(oapagecontext).toString();  //handle null
						}
						else
						{
						cms = customCMSText.getValue(oapagecontext).toString(); //handle null
						}

						poRequisitionHeadersVORowImpl.setAttribute3(cms);

				}//if customCMSLov or customCMSText are not null
				else
				{
						customLog(oapagecontext,  "XXDOI: customCMSLov or customCMSText is NULL");
				}
							String cmsContractNumber = cms;
				//End of PO.12.01 in PFR
				/****************************************************************************************************************/

            if ("".equals(cmsContractNumber) || (cmsContractNumber == null)) {
                PoRequisitionLinesVOImpl poRequisitionLinesVOImpl = (PoRequisitionLinesVOImpl) oaapplicationmodule.findViewObject(
                        "PoRequisitionLinesVO");
                PoRequisitionLinesVORowImpl poRequisitionLinesVORowImpl = (PoRequisitionLinesVORowImpl) poRequisitionLinesVOImpl.first();
                int numOfLines = poRequisitionLinesVOImpl.getFetchedRowCount();
                doiDebug("number of lines = " + numOfLines, oaapplicationmodule);

                Boolean warningCategory = Boolean.FALSE;
                double reqTotalExclGst = 0.0D;

                // Array of Item Categories JB 22/10/09
                ReqLineItemCategory[] reqLineItemCategories = new ReqLineItemCategory[numOfLines];

                // Loop through Req Lines.
                for (int i = 0; i < numOfLines; i++) {
                    String category = poRequisitionLinesVORowImpl.getCategory();
                    Number categoryId = poRequisitionLinesVORowImpl.getCategoryId();
                    Number unitPrice = poRequisitionLinesVORowImpl.getUnitPrice();
                    Number quantity = poRequisitionLinesVORowImpl.getQuantity();
                    Number lineTotalExclGst = unitPrice.multiply(quantity);
                    reqTotalExclGst += lineTotalExclGst.doubleValue();
                    doiDebug("categoryId = " + categoryId, oaapplicationmodule);
                    doiDebug("category = " + category, oaapplicationmodule);
                    doiDebug("lineTotalExclGst = " + lineTotalExclGst, oaapplicationmodule);

                    /*                    if (categoryId.equals(new Number(50))) {
                                            warningCategory = Boolean.TRUE;
                                        }

                                        if (categoryId.equals(new Number(43))) {
                                            warningCategory = Boolean.TRUE;
                                        }
                    */
                    if (oapagecontext.isLoggingEnabled(1)) {
                        oapagecontext.writeDiagnostics(this, "XXDOT: processFormRequest about to call ReqLineItemCategory: " + i, 1);
                    }

                    ReqLineItemCategory reqLineCat = new ReqLineItemCategory(oapagecontext, oawebbean, categoryId);
                    reqLineItemCategories[i] = reqLineCat; // JB 22/10/09

                    poRequisitionLinesVORowImpl = (PoRequisitionLinesVORowImpl) poRequisitionLinesVOImpl.next();
                }

                // JB 22/10/09
                // Loop through Req Line Category Array now that we know the Req Total
                for (int j = 0; j < numOfLines; j++) {
                    if (oapagecontext.isLoggingEnabled(1)) {
                        oapagecontext.writeDiagnostics(this, "XXDOT: processFormRequest in Category loop i:" + j, 1);
                    }

                    if (oapagecontext.isLoggingEnabled(1)) {
                        oapagecontext.writeDiagnostics(this, "XXDOT: reqTotalExclGst: " + reqTotalExclGst, 1);
                        oapagecontext.writeDiagnostics(this,
                            "XXDOT: CMSValidationThreshold: " + reqLineItemCategories[j].CMSValidationThreshold.doubleValue(), 1);
                    }

                    if (reqTotalExclGst >= reqLineItemCategories[j].CMSValidationThreshold.doubleValue()) {
                        if (oapagecontext.isLoggingEnabled(1)) {
                            oapagecontext.writeDiagnostics(this, "XXDOT: Req value greater than CMS Threshold", 1);
                            oapagecontext.writeDiagnostics(this,
                                "XXDOT: CMSNumberHighAction: " + reqLineItemCategories[j].CMSNumberHighAction, 1);
                        }

                        if (reqLineItemCategories[j].CMSNumberHighAction.equals(reqLineItemCategories[j].VALIDATION_WARNING)) {
                            warningCategory = Boolean.TRUE;

                            if (oapagecontext.isLoggingEnabled(1)) {
                                oapagecontext.writeDiagnostics(this, "XXDOT: setting Warning Category flag to true", 1);
                            }
                        }
                    } else // Req Total lower than threshold
                     {
                        if (oapagecontext.isLoggingEnabled(1)) {
                            oapagecontext.writeDiagnostics(this, "XXDOT: Req value less than CMS Threshold", 1);
                            oapagecontext.writeDiagnostics(this,
                                "XXDOT: CMSNumberLowAction: " + reqLineItemCategories[j].CMSNumberLowAction, 1);
                        }

                        if (reqLineItemCategories[j].CMSNumberLowAction.equals(reqLineItemCategories[j].VALIDATION_WARNING)) {
                            warningCategory = Boolean.TRUE;

                            if (oapagecontext.isLoggingEnabled(1)) {
                                oapagecontext.writeDiagnostics(this, "XXDOT: setting Warning Category flag to true", 1);
                            }
                        }
                    }

                    if (oapagecontext.isLoggingEnabled(1)) {
                        oapagecontext.writeDiagnostics(this, "XXDOT: end Category loop i:" + j, 1);
                    }
                }

                doiDebug("reqTotalExclGst = " + String.valueOf(reqTotalExclGst), oaapplicationmodule);

                if (warningCategory.booleanValue()) {
                    doiDebug("Redirecting using POC_CMS_WARN_HIGH", oaapplicationmodule);

                    OAException descMsg = new OAException("ICX", "POC_CMS_WARN_HIGH");
                    OAException instrMsg = new OAException("ICX", "POC_CMS_WARN_HIGH_INSTRUCTION");
                    OADialogPage dialogPage = new OADialogPage((byte) 1, descMsg, instrMsg, "", "");
                    dialogPage.setOkButtonToPost(true);
                    dialogPage.setOkButtonItemName("DoiContinue");
                    dialogPage.setOkButtonLabel("Continue");
                    dialogPage.setNoButtonToPost(true);
                    dialogPage.setNoButtonItemName("DoiBack");
                    dialogPage.setNoButtonLabel("Back");
                    dialogPage.setPostToCallingPage(true);
                    oapagecontext.redirectToDialogPage(dialogPage);
                }
            }
        } else if ((oapagecontext.getParameter("DoiYes") != null) || (oapagecontext.getParameter("DoiBack") != null)) {
            doiDebug("Redirect back to calling page", oaapplicationmodule);
            customLog(oapagecontext,   "XXDOT: oapagecontext.getParameter(DoiYes) or oapagecontext.getParameter(DoiBack) cms: ");
        } else if ((oapagecontext.getParameter("DoiNo") != null) || (oapagecontext.getParameter("DoiContinue") != null)) {
			customLog(oapagecontext,  "XXDOT: oapagecontext.getParameter(DoiNo) or oapagecontext.getParameter(DoiContinue) cms:");
            doiDebug("Continue", oaapplicationmodule);


			//PO.12.01 -- Start
			//--------------------------------------------------------------------------------------------------------------
			if (isCMSLOVEnabled(oawebbean,oapagecontext).equals("Y") )
			{
				if (customCMSLov.getValue(oapagecontext) !=null)
					{
						cms = customCMSLov.getValue(oapagecontext).toString();
				}
				else
				customLog(oapagecontext, "XXDOT:  event cms lov value is null");
			}
			else
			{
				customLog(oapagecontext, "XXDOT:  in else isCMSLOVEnabled condition ");
				if (customCMSText.getValue(oapagecontext) !=null)
					{
						cms = customCMSText.getValue(oapagecontext).toString();
					}
				else
					{
						customLog(oapagecontext,"XXDOT:  event cms lov value is null");
					}
			}

			if ("X".equals(oapagecontext.getSessionValue("cmsSession")))  //X is set when it is null
			{
				customLog(oapagecontext,"XXDOT: setting cmssession to null");
				poRequisitionHeadersVORowImpl.setAttribute3("");

				if (isCMSLOVEnabled(oawebbean,oapagecontext).equals("Y") )
					customCMSLov.setValue(oapagecontext,"");
				else
					customCMSText.setValue(oapagecontext,"");
			}
			//--------------------------------------------------------------------------------------------------------------
			//PO.12.01 -- End




            processNextButton(oapagecontext, oaapplicationmodule);

            return;
        }

        String s = oapagecontext.getParameter("event");

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processFormRequest().begin", 1);
            logParam(this, oapagecontext, "event", s, 1);
        }

        if (oapagecontext.isLovEvent()) {
            processLovEvents(oapagecontext, oaapplicationmodule, "summary", true);

            return;
        }

        if ("PPRUserEvent".equals(s)) {
            processPPREvents(oapagecontext, oaapplicationmodule, "summary", true);

            return;
        }

        if ("goto".equals(s)) {
            processNextButton(oapagecontext, oaapplicationmodule);

            return;
        }

        if ("editLines".equals(s)) {
            processEditLines(oapagecontext, oaapplicationmodule);

            return;
        }

        if ("save".equals(s)) {
            processSaveReq(oapagecontext, oaapplicationmodule);

            return;
        }

        if ("submit".equals(s)) {
            processSubmitReq(oapagecontext, oaapplicationmodule);

            return;
        }

        if ("cancel".equals(s)) {
            processCancelReq(oapagecontext);

            return;
        }

        if ("multipleLink".equals(s)) {
            processMultipleLink(oapagecontext, oaapplicationmodule);

            return;
        }

        if ("addOneTimeAddr".equals(s)) {
            processAddOneTimeLocation(oapagecontext, oaapplicationmodule);

            return;
        }

        if ("editOneTimeAddr".equals(s)) {
            processEditOneTimeLocation(oapagecontext, oaapplicationmodule);

            return;
        }

        if ("deleteOneTimeAddr".equals(s)) {
            processDeleteOneTimeLocation(oapagecontext, oaapplicationmodule);
        }
    }


//Begin of PO.12.01 methods
//---------------------------------------------------------------------------------------------------------

/*----------------------------------------------------------------------------
* isCMSLOVEnabled:
* Checks CMS is enabled or not
* History:
* 17/05/2017  Rao Chennuri    1.0  Initial version.
*------------------------------------------------------------------------- */
public String isCMSLOVEnabled(OAWebBean oawebbean,OAPageContext oapagecontext)
{
 StringBuffer stringBuffer = new StringBuffer();
 String isEnabled = "";
 OraclePreparedStatement pStmt = null;
 OracleResultSet resultSet = null;
	try {
		stringBuffer.append("SELECT NVL(fnd_profile.value_specific(name => 'XXPO_CMS_LOV_ENABLED',org_id => :1),'N') cmslov_profile_value from dual");
	if (oapagecontext.isLoggingEnabled(1)) {
		oapagecontext.writeDiagnostics(this, "XXDOT: select:  "+stringBuffer.toString(), 1);
	}
		OADBTransaction dbTrx = oapagecontext.getApplicationModule(oawebbean).getOADBTransaction();
		pStmt = (OraclePreparedStatement) dbTrx.createPreparedStatement(stringBuffer.toString(), 1);
		pStmt.setInt(1, oapagecontext.getOrgId());
		resultSet = (OracleResultSet) pStmt.executeQuery();
		if (resultSet.next()) {
			if (resultSet.getString("cmslov_profile_value") != null) {
				isEnabled = resultSet.getString("cmslov_profile_value");
			}
		}
	  }//end try
		catch (Exception sq) {
		throw new OAException("Custom Exception " + sq, OAException.ERROR);
								} //end catch
	finally
	{
		try {
			pStmt.close();
			resultSet.close();
		} catch (Exception e) {
			throw new OAException("Custom Exception " + e, OAException.ERROR);
		}
	} // end finally
	return isEnabled;
}

  /*----------------------------------------------------------------------------
   * IsMod11Valid:
   *   Implements Modulus 11 Self-check validation
   *   Initially this logic was used in an EO writted by S.Ryan
   *   Now, this is moved here to validate CMS from database based on a profile value
   * History:
   *   17/05/2017  Rao Chennuri    1.0  Initial version.
   *------------------------------------------------------------------------- */
  public boolean IsMod11Valid(String cmsNumber)
  {
	boolean result = false;
	String cmsStem = cmsNumber.substring(0,cmsNumber.length()-1);
	int cmsChkDigit = Integer.parseInt(cmsNumber.substring(cmsNumber.length()-1));

	System.out.println("cmsStem = " + cmsStem);
	System.out.println("cmsChkdigit = " + cmsChkDigit);

	int length = cmsStem.length();
	int[] weights = new int[length];
	int weightLow = 2;
	int weightHigh = 7;
	int multiplier = weightLow;

	// build the list of multipliers
	for (int i=length-1; i>=0; i--)
	{
	  weights[i] = multiplier;
	  if (multiplier == 7)
		multiplier = weightLow;
	  else
		multiplier++;
	}
	// calculate the weighted sum of the cmsNumber
	int weightedSum = 0;
	for (int i=0; i<length; i++)
	{
	  weightedSum += (Integer.parseInt(cmsStem.substring(i,i+1)) * weights[i]);
	}

	int remainder = (weightedSum%11);

	// compare check digit with remainder
	switch (remainder)
	{
	  case 0:
		result = (cmsChkDigit == 0);
		break;
	  case 1:
		result = false;
		break;
	  default:
		int calcChkDigit = 11 - remainder;
		result = (cmsChkDigit == calcChkDigit);
		break;
	}
	return result;
  } // end of IsMod11Valid

public void customLog(OAPageContext oapagecontext, String debugMsg)
{
		if (oapagecontext.isLoggingEnabled(1)) {
			oapagecontext.writeDiagnostics(this, debugMsg, 1);
		}
}

/* ---------------------------------------------------------------------------
*    isCMSNumber
*    Validates CMS number in XXPO_CONTRACTS_ALL table (loaded by an interface)
* History:
*    17/05/2017    Rao Chennuri      1.0  Initial version.
* ------------------------------------------------------------------------ */
   public String isCMSNumber(OAPageContext oapagecontext, OAWebBean oawebbean, String cmsNumber) {

		customLog(oapagecontext,"XXDOT: CMS Number:" + cmsNumber);

	String cmsValidationStatus = "Y";
	StringBuffer stringBuffer = new StringBuffer();
	OraclePreparedStatement pStmt = null;
	OracleResultSet resultSet = null;
	stringBuffer.append("SELECT COUNT(1) CNT FROM XXPO_CONTRACTS_ALL ");
	stringBuffer.append("WHERE ORG_ID = "+oapagecontext.getOrgId()+" AND CONTRACT_NUMBER = ? ");

	customLog(oapagecontext,"XXDOT: select:  "+stringBuffer.toString());

	try {
		OADBTransaction dbTrx = oapagecontext.getApplicationModule(oawebbean).getOADBTransaction();
		pStmt = (OraclePreparedStatement) dbTrx.createPreparedStatement(stringBuffer.toString(), 1);
		pStmt.setString(1, cmsNumber);
		resultSet = (OracleResultSet) pStmt.executeQuery();
		// Get values out of the ResultSet
		resultSet.next();
		int getCMSNumber = resultSet.getInt("CNT");
		if (getCMSNumber > 0 ) {
			customLog(oapagecontext,"XXDOT: Contract number is "+getCMSNumber);
		}
		else
		{
				customLog(oapagecontext,"XXDOT: Contract number is "+getCMSNumber);
				cmsValidationStatus = "N";
		}
	}// end try
	catch (Exception sqlexception) {

		if (oapagecontext.isLoggingEnabled(1)) {
			oapagecontext.writeDiagnostics(this, "XXDOT: Contract number validation: sqlexception:" + sqlexception, 1);

			StackTraceElement[] stackTrace = sqlexception.getStackTrace();

			for (int i = 0; i < stackTrace.length; i++) {
				oapagecontext.writeDiagnostics(this, "XXDOT: stackTrace:" + i + ": " + stackTrace[i].toString(), 1);
				}
		}// end if
	} // end catch
	finally
	{
		try {
			// Close ResultSet and PreparedStatement
			pStmt.close();
			resultSet.close();
		} catch (Exception e) {
			throw new OAException("Custom Exception " + e, OAException.ERROR);
		}
	}// end finally
	return cmsValidationStatus;
} //end of isCMSNumber
// End of PO.12.01 methods
//---------------------------------------------------------------------------------------------------------



    protected void processNextButton(OAPageContext oapagecontext, OAApplicationModule oaapplicationmodule) {
        ArrayList arraylist = new ArrayList(2);
        arraylist.add("populateValidateAndImplicitSave");
        arraylist.add("summary");
        executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist);

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processNextButton().after populateValidateAndImplicitSave", 1);
        }

        if (hasErrors(oapagecontext)) {
            processErrorRedirectsForCheckoutSummary(oapagecontext, oaapplicationmodule);

            return;
        } else {
            oapagecontext.setForwardURL("ICX_POR_REQAPPRV_LIST", (byte) 0, null, null, true, "N", (byte) 99);

            return;
        }
    }

    protected void processEditLines(OAPageContext oapagecontext, OAApplicationModule oaapplicationmodule) {
        ArrayList arraylist = new ArrayList(3);
        arraylist.add("populate");
        arraylist.add("summary");
        arraylist.add("Y");
        executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist);

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processEditLines().after populate", 1);
        }

        String s = oapagecontext.getParameter("PorLineSubTab");
        String s1 = getLineSubTabIndex(oapagecontext, s);
        HashMap hashmap = new HashMap(2);
        hashmap.put("porMode", "display");
        hashmap.put("OA_SubTabIdx", s1);
        oapagecontext.forwardImmediately("ICX_POR_CHECKOUT_LINES", (byte) 0, null, hashmap, true, "N");
    }

    protected void processSaveReq(OAPageContext oapagecontext, OAApplicationModule oaapplicationmodule) {
        ArrayList arraylist = new ArrayList(2);
        arraylist.add("populateValidateAndSave");
        arraylist.add("summary");
        executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist);

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processSaveReq().after populateValidateAndSave", 1);
        }

        if (hasErrors(oapagecontext)) {
            processErrorRedirectsForCheckoutSummary(oapagecontext, oaapplicationmodule);

            return;
        } else {
            HashMap hashmap = new HashMap(1);
            hashmap.put("porMode", "display");
            setReturnUrl(oapagecontext, "ICX_POR_CHECKOUT_SUMMARY", hashmap);
            oapagecontext.setForwardURL("ICX_POR_SAVE_CONFIRMATION", (byte) 0, null, null, true, "N", (byte) 99);

            return;
        }
    }

    protected void processSubmitReq(OAPageContext oapagecontext, OAApplicationModule oaapplicationmodule) {
        Number number = ClientUtil.getPorAppsContext(oapagecontext).getOrigReqHeaderId();
        ArrayList arraylist = new ArrayList(2);
        arraylist.add("populateValidateAndSubmit");
        arraylist.add("summary");
        executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist);

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processSubmitReq().after populateValidateAndSubmit", 1);
        }

        if (hasErrors(oapagecontext)) {
            processErrorRedirectsAfterSubmitReq(oapagecontext, oaapplicationmodule);

            return;
        } else {
            displaySubmitConfirmation(oapagecontext, number);

            return;
        }
    }

    protected void processCancelReq(OAPageContext oapagecontext) {
        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processCancelReq().begin cancelling req", 1);
        }

        oapagecontext.setForwardURL("ICX_POR_SHOPPING_CART", (byte) 0, null, null, false, "N", (byte) 99);
    }

    protected void processMultipleLink(OAPageContext oapagecontext, OAApplicationModule oaapplicationmodule) {
        ArrayList arraylist = new ArrayList(3);
        arraylist.add("populate");
        arraylist.add("summary");
        arraylist.add("Y");
        executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist);

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processMultipleLink().after populate", 1);
        }

        String s = oapagecontext.getParameter("PorLineSubTab");
        String s1 = getLineSubTabIndex(oapagecontext, s);
        HashMap hashmap = new HashMap(2);
        hashmap.put("porMode", "display");
        hashmap.put("OA_SubTabIdx", s1);
        oapagecontext.forwardImmediately("ICX_POR_CHECKOUT_LINES", (byte) 0, null, hashmap, true, "N");
    }

    protected void processAddOneTimeLocation(OAPageContext oapagecontext, OAApplicationModule oaapplicationmodule) {
        ArrayList arraylist = new ArrayList(3);
        arraylist.add("populate");
        arraylist.add("summary");
        arraylist.add("N");
        executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist);

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processAddOneTimeLocation().after populate", 1);
        }

        HashMap hashmap = new HashMap(1);
        hashmap.put("porMode", "fromOneTime");
        setReturnUrl(oapagecontext, "ICX_POR_CHECKOUT_SUMMARY", hashmap);

        HashMap hashmap1 = new HashMap(2);
        hashmap1.put("porMode", "add");
        hashmap1.put("porUsage", "all");
        oapagecontext.setForwardURL("ICX_POR_ONE_TIME_LOCATION", (byte) 0, null, hashmap1, true, "N", (byte) 99);
    }

    protected void processEditOneTimeLocation(OAPageContext oapagecontext, OAApplicationModule oaapplicationmodule) {
        ArrayList arraylist = new ArrayList(3);
        arraylist.add("populate");
        arraylist.add("summary");
        arraylist.add("N");
        executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist);

        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processEditOneTimeLocation().after populate", 1);
        }

        OAViewObject oaviewobject = (OAViewObject) oaapplicationmodule.findViewObject("PoRequisitionLinesVO");
        oaviewobject.first();

        HashMap hashmap = new HashMap(1);
        hashmap.put("porMode", "display");
        setReturnUrl(oapagecontext, "ICX_POR_CHECKOUT_SUMMARY", hashmap);

        HashMap hashmap1 = new HashMap(1);
        hashmap1.put("porMode", "edit");
        oapagecontext.setForwardURL("ICX_POR_ONE_TIME_LOCATION", (byte) 0, null, hashmap1, true, "N", (byte) 99);
    }

    protected void processDeleteOneTimeLocation(OAPageContext oapagecontext, OAApplicationModule oaapplicationmodule) {
        if (isLoggingEnabled(oapagecontext, 1)) {
            logMsg(this, oapagecontext, "processDeleteOneTimeLocation().begin", 1);
        }

        ArrayList arraylist = new ArrayList(2);
        arraylist.add("processDeleteOneTimeLocation");
        arraylist.add("summary");
        executeServerCommand(oapagecontext, oaapplicationmodule, "CheckoutSummarySvrCmd", arraylist);
    }

    // Class to fetch Req Line Item Category DFF Attributes
    // Jon Bartlett 22/10/09
    public class ReqLineItemCategory {
        public static final String RCS_ID = "$Header: svn://d02584/consolrepos/branches/AR.09.03/poc/1.0.0/java/oracle/apps/icx/por/req/webui/CheckoutSummaryCO.java 1242 2017-06-26 05:12:05Z svnuser $";
        public static final String VALIDATION_REQUIRED = "1";
        public static final String VALIDATION_WARNING = "2";
        public static final String VALIDATION_NO_WARNING = "3";
        public String CMSNumberHighAction = VALIDATION_NO_WARNING;
        public String CMSNumberLowAction = VALIDATION_NO_WARNING;
        public boolean ApprovedByFinDelRequired = false;
        public boolean ApprovalDateRequired = false;
        public Number CMSValidationThreshold = new Number(0);

        public ReqLineItemCategory(OAPageContext pageContext, OAWebBean oawebbean, Number catId) {
            if (pageContext.isLoggingEnabled(1)) {
                pageContext.writeDiagnostics(this, "XXDOT: ReqLineItemCategory: in ReqLineItemCategory", 1);
                pageContext.writeDiagnostics(this, "XXDOT: ReqLineItemCategory: catId:" + catId, 1);
            }

            StringBuffer stringBuffer = new StringBuffer();

            stringBuffer.append("SELECT to_number(dff.IPROC_CMS_VALIDATION_THRESHOLD)   IPROC_CMS_VALIDATION_THRESHOLD ");
            stringBuffer.append(",      dff.IPROC_CMS_HIGH_ACTION            IPROC_CMS_HIGH_ACTION ");
            stringBuffer.append(",      dff.IPROC_CMS_LOW_ACTION             IPROC_CMS_LOW_ACTION ");
            stringBuffer.append(",      dff.APPROVED_BY_FIN_DEL_VALIDATION   APPROVED_BY_FIN_DEL_VALIDATION ");
            stringBuffer.append(",      dff.APPROVAL_DATE_VALIDATION         APPROVAL_DATE_VALIDATION ");
            stringBuffer.append("FROM   MTL_CATEGORIES_B_DFV  dff ");
            stringBuffer.append(",      MTL_CATEGORIES_B      cat ");
            stringBuffer.append("WHERE  dff.ROW_ID      = cat.ROWID ");
            stringBuffer.append("  AND  cat.CATEGORY_ID = ?");

            try {
                OADBTransaction dbTrx = pageContext.getApplicationModule(oawebbean).getOADBTransaction();

                OraclePreparedStatement ps = (OraclePreparedStatement) dbTrx.createPreparedStatement(stringBuffer.toString(), 1);

                ps.setNUMBER(1, catId);

                OracleResultSet rs = (OracleResultSet) ps.executeQuery();

                // Get values out of the ResultSet
                rs.next();

                String CMSNumberHighActionString = rs.getString("IPROC_CMS_HIGH_ACTION");
                String CMSNumberLowActionString = rs.getString("IPROC_CMS_LOW_ACTION");

                if (rs.getNUMBER("IPROC_CMS_VALIDATION_THRESHOLD") != null) {
                    if (pageContext.isLoggingEnabled(1)) {
                        pageContext.writeDiagnostics(this, "XXDOT: IPROC_CMS_VALIDATION_THRESHOLD is not null", 1);
                    }

                    CMSValidationThreshold = new Number(rs.getDouble("IPROC_CMS_VALIDATION_THRESHOLD"));

                    if (pageContext.isLoggingEnabled(1)) {
                        pageContext.writeDiagnostics(this, "XXDOT: CMSValidationThreshold variable created", 1);
                    }
                }

                String ApprovedByFinDelRequiredString = rs.getString("APPROVED_BY_FIN_DEL_VALIDATION");
                String ApprovalDateRequiredString = rs.getString("APPROVAL_DATE_VALIDATION");

                if (pageContext.isLoggingEnabled(1)) {
                    pageContext.writeDiagnostics(this,
                        "XXDOT: ReqLineItemCategory: CMSNumberHighActionString:" + CMSNumberHighActionString, 1);
                    pageContext.writeDiagnostics(this, "XXDOT: ReqLineItemCategory: CMSNumberLowActionString:" + CMSNumberLowActionString, 1);
                    pageContext.writeDiagnostics(this, "XXDOT: ReqLineItemCategory: CMSValidationThreshold:" + CMSValidationThreshold, 1);
                    pageContext.writeDiagnostics(this,
                        "XXDOT: ReqLineItemCategory: ApprovedByFinDelRequiredString:" + ApprovedByFinDelRequiredString, 1);
                    pageContext.writeDiagnostics(this,
                        "XXDOT: ReqLineItemCategory: ApprovalDateRequiredString:" + ApprovalDateRequiredString, 1);
                }

                // Close ResultSet and PreparedStatement
                rs.close();
                ps.close();

                if (CMSNumberHighActionString != null) {
                    if (CMSNumberHighActionString.equals("REQ")) {
                        CMSNumberHighAction = VALIDATION_REQUIRED;
                    } else if (CMSNumberHighActionString.equals("OPT_WARN")) {
                        CMSNumberHighAction = VALIDATION_WARNING;
                    }
                }

                if (CMSNumberLowActionString != null) {
                    if (CMSNumberLowActionString.equals("REQ")) {
                        CMSNumberLowAction = VALIDATION_REQUIRED;
                    } else if (CMSNumberLowActionString.equals("OPT_WARN")) {
                        CMSNumberLowAction = VALIDATION_WARNING;
                    }
                }

                if (ApprovedByFinDelRequiredString != null) {
                    if (ApprovedByFinDelRequiredString.equals("REQ")) {
                        ApprovedByFinDelRequired = true;
                    }
                }

                if (ApprovalDateRequiredString != null) {
                    if (ApprovalDateRequiredString.equals("REQ")) {
                        ApprovalDateRequired = true;
                    }
                }

                if (CMSValidationThreshold == null) {
                    CMSValidationThreshold = new Number(0);
                }
            } catch (Exception sqlexception) {
                //pageContext.putDialogMessage(new OAException("OraclePreparedStatement OR OracleResultSet Exception"));
                //                sqlexception.printStackTrace();
                if (pageContext.isLoggingEnabled(1)) {
                    pageContext.writeDiagnostics(this, "XXDOT: ReqLineItemCategory: sqlexception:" + sqlexception, 1);

                    StackTraceElement[] stackTrace = sqlexception.getStackTrace();

                    for (int i = 0; i < stackTrace.length; i++) {
                        pageContext.writeDiagnostics(this, "XXDOT: stackTrace:" + i + ": " + stackTrace[i].toString(), 1);
                    }
                }
            }
        }
    }
}
