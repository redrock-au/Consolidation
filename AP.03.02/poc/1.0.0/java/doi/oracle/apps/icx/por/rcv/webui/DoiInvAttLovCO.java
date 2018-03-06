package doi.oracle.apps.icx.por.rcv.webui;
// **********************************************************************
// doi.oracle.apps.icx.por.rcv.webui.DoiInvAttLovCO.java
//
//
// Joy Pinto 27-APR-2017
//
// Controller for DoiInvAttachmentLOVRN
//
//
// **********************************************************************
/* $Header: svn://d02584/consolrepos/branches/AP.03.02/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/DoiInvAttLovCO.java 1472 2017-07-05 00:35:27Z svnuser $ */
import java.io.Serializable;
import java.util.Dictionary;
import oracle.apps.fnd.common.VersionInfo;
import oracle.apps.fnd.framework.OAViewObject;
import oracle.apps.fnd.framework.webui.OAControllerImpl;
import oracle.apps.fnd.framework.webui.OAPageContext;
import oracle.apps.fnd.framework.webui.beans.OAImageBean;
import oracle.apps.fnd.framework.webui.beans.OAWebBean;
import oracle.cabo.ui.UIConstants;

public class DoiInvAttLovCO extends OAControllerImpl {
    public static final String RCS_ID = "$Header: svn://d02584/consolrepos/branches/AP.03.02/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/DoiInvAttLovCO.java 1472 2017-07-05 00:35:27Z svnuser $";
    public static final boolean RCS_ID_RECORDED = VersionInfo.recordClassVersion((String)"$Header: svn://d02584/consolrepos/branches/AP.03.02/poc/1.0.0/java/doi/oracle/apps/icx/por/rcv/webui/DoiInvAttLovCO.java 1472 2017-07-05 00:35:27Z svnuser $", (String)"%packagename%");

    public void processRequest(OAPageContext pageContext, OAWebBean webBean) {
        super.processRequest(pageContext, webBean);
        OAImageBean invAttchImg = (OAImageBean)webBean.findIndexedChildRecursive("xxInvImage");
        invAttchImg.setAttributeValue(UIConstants.TARGET_FRAME_ATTR, (Object)"_blank");
        invAttchImg.setDestination("{$Attribute15}");
        invAttchImg.setViewAttributeName("Attribute15");
        invAttchImg.setViewUsageName("doiInvAttachmentListVO");
        OAViewObject VO = (OAViewObject)pageContext.getApplicationModule(webBean).findViewObject("doiInvAttachmentListVO");
        Dictionary lov_dict = pageContext.getLovCriteriaItems();
        String lov_criteria = (String)lov_dict.get("PoHeaderId");
        try {
        Class[] parameterTypes = new Class[]{Class.forName("java.lang.String")};
                Serializable[] criteriaparams = new Serializable[]{lov_criteria};
                String reqHeaderId = pageContext.getParameter("reqHeaderId");             
                VO.setWhereClause(" po_header_id  = "+lov_criteria);
                VO.executeQuery();
			}
	    catch (Exception  e) {
			 pageContext.writeDiagnostics(this, "Exception "+e, 1);
		}

    }

    public void processFormRequest(OAPageContext pageContext, OAWebBean webBean) {
        super.processFormRequest(pageContext, webBean);
        if (pageContext.isLoggingEnabled(1)) {
            pageContext.writeDiagnostics((Object)this, "Inside LOC process form request", 1);
        }
    }
}