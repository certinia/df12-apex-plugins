/**
 * Copyright (c) 2012, FinancialForce.com, inc
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice, 
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice, 
 *      this list of conditions and the following disclaimer in the documentation 
 *      and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors 
 *      may be used to endorse or promote products derived from this software without 
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/ 

public with sharing class AdjustOpportunityController
{
	ApexPages.StandardController m_standardController;
	Decimal m_adjustmentPercentage;
	Decimal m_adjustmentProportion = 0;
	Opportunity m_opportunity;
	Opportunity m_adjustedOpportunity;
	Map<Id,OpportunityLineItem> m_adjustedOpportunityLineItemMap;
	Boolean m_showAdjusted = false;

	public AdjustOpportunityController(ApexPages.StandardController standardController)
	{
		m_standardController = standardController;
		m_opportunity = (Opportunity) m_standardController.getRecord();
	}
	
	public Decimal getLineCount()
	{
		return m_opportunity.OpportunityLineItems.size();
	}
	
	public Decimal getAdjustmentPercentage()
	{
		return m_adjustmentPercentage;
	}
	
	Decimal getAdjustmentProportion()
	{
		return m_adjustmentProportion;
	}
	
	public void setAdjustmentPercentage(Decimal value)
	{
		m_adjustmentPercentage = value;
		m_adjustmentProportion = m_adjustmentPercentage==null ? 0 : m_adjustmentPercentage/100;
	}

	public Opportunity getAdjustedOpportunity()
	{
		return m_adjustedOpportunity;
	}

	public Map<Id,OpportunityLineItem> getAdjustedOpportunityLineItems()
	{
		return m_adjustedOpportunityLineItemMap;
	}
	
	public Boolean getShowAdjusted()
	{
		return m_showAdjusted;
	}
	
	// Actions
	
	public void preview()
	{
		m_showAdjusted = true;
		try
		{
			adjust();
		}
		catch (Exception e)
		{
			ApexPages.addMessages(e);
		}
	}
	
	public PageReference save()
	{
		if(getAdjustmentProportion()==0)
			return m_standardController.view();
		
		try
		{
			adjust();
		}
		catch (Exception e)
		{
			ApexPages.addMessages(e);
			return null;
		}
		
		Savepoint sp = Database.setSavePoint();		
		try
		{
			if(m_adjustedOpportunityLineItemMap.isEmpty())
				update m_adjustedOpportunity;
			else
				// We only need to update the lines - platform will update the header
				update m_adjustedOpportunityLineItemMap.values();
		}
		catch (Exception e)
		{
			Database.rollback(sp);
			ApexPages.addMessages(e);
			return null;
		}

		return m_standardController.view();
	}
	
	void adjust()
	{
		Plugin.IAdjustOpportunities adjuster = Plugin.getInstanceIAdjustOpportunities();
		Plugin.IValidateOpportunityAdjustments validator = Plugin.getInstanceIValidateOpportunityAdjustments();

		// If we need to know whether the plugins have been configured, or the default plugin has been substituted
		// we would use: [plugin] instanceof Plugin.IDefault 
		
		// Clone the records
		m_adjustedOpportunity = m_opportunity.clone(true,true,true,true);
		m_adjustedOpportunityLineItemMap = new Map<Id,OpportunityLineItem>();
		for(OpportunityLineItem item : m_opportunity.OpportunityLineItems)
			m_adjustedOpportunityLineItemMap.put(item.Id, item.clone(true,true,true,true));

		// Make the adjustments
		adjuster.adjust(m_adjustedOpportunity, m_adjustedOpportunityLineItemMap.values(), getAdjustmentProportion());
		// validate the adjustments
		validator.validate(m_adjustedOpportunity, m_adjustedOpportunityLineItemMap.values(), getAdjustmentProportion());
	}
	
	// Tests
	
	@isTest(SeeAllData=true)
	static void testGetLineCount()
	{
		AdjustOpportunityController controller = setupTestEnvironment();
		system.assertEquals(1,controller.getLineCount());
	}
	
	@isTest
	static void testAdjustmentPercentage()
	{
		AdjustOpportunityController controller = setupTestEnvironmentNoData();
		controller.setAdjustmentPercentage(12.34);
		system.assertEquals(12.34,controller.getAdjustmentPercentage());
	}
	
	@isTest
	static void testAdjustmentProportion()
	{
		AdjustOpportunityController controller = setupTestEnvironmentNoData();
		controller.setAdjustmentPercentage(12.34);
		system.assertEquals(0.1234,controller.getAdjustmentProportion());
	}
	
	@isTest
	static void testDefaultProperties()
	{
		AdjustOpportunityController controller = setupTestEnvironmentNoData();
		system.assertEquals(null,controller.getAdjustmentPercentage());
		system.assertEquals(0,controller.getAdjustmentProportion());
		system.assertEquals(null,controller.getAdjustedOpportunity());
		system.assertEquals(null,controller.getAdjustedOpportunityLineItems());
		system.assertEquals(false,controller.getShowAdjusted());
	}
	
	@isTest(SeeAllData=true)
	static void testPreview()
	{
		AdjustOpportunityController controller = setupTestEnvironment();
		controller.setAdjustmentPercentage(10);
		controller.preview();
		system.assertEquals(true,controller.getShowAdjusted());
		system.assertEquals(100,controller.m_opportunity.Amount);
		system.assertEquals(10,controller.m_opportunity.OpportunityLineItems[0].UnitPrice);
		system.assertEquals(110,controller.getAdjustedOpportunity().Amount);
		system.assert(controller.getAdjustedOpportunityLineItems()!=null);
		system.assert(!controller.getAdjustedOpportunityLineItems().isEmpty());
		system.assertEquals(11,controller.getAdjustedOpportunityLineItems().values()[0].UnitPrice);
	}

	@isTest(SeeAllData=true)
	static void testPreviewException()
	{
		AdjustOpportunityController controller = setupTestEnvironment();
		controller.setAdjustmentPercentage(-110);
		controller.preview();
		boolean foundError = false;
		for(ApexPages.Message message : ApexPages.getMessages())
		{
			if(message.getSeverity()==ApexPages.Severity.ERROR)
			{
				foundError=true;
				break;
			}
		}
		system.assert(foundError);
		system.assertEquals(true,controller.getShowAdjusted());
		system.assertEquals(100,controller.m_opportunity.Amount);
		system.assertEquals(10,controller.m_opportunity.OpportunityLineItems[0].UnitPrice);
		system.assertEquals(-10,controller.getAdjustedOpportunity().Amount);
		system.assertEquals(-1,controller.getAdjustedOpportunityLineItems().values()[0].UnitPrice);
	}

	@isTest(SeeAllData=true)
	static void testSave()
	{
		AdjustOpportunityController controller = setupTestEnvironment();
		controller.setAdjustmentPercentage(10);
		controller.save();
		system.assertEquals(false,controller.getShowAdjusted());
		system.assertEquals(100,controller.m_opportunity.Amount);
		system.assertEquals(10,controller.m_opportunity.OpportunityLineItems[0].UnitPrice);
		system.assertEquals(110,[select Amount from Opportunity where id=:controller.m_opportunity.id].Amount);
		system.assertEquals(11,[select UnitPrice from OpportunityLineItem where OpportunityId=:controller.m_opportunity.id].UnitPrice);
	}

	@isTest(SeeAllData=true)
	static void testSaveNoLines()
	{
		AdjustOpportunityController controller = setupTestEnvironmentNoLines();
		controller.setAdjustmentPercentage(10);
		controller.save();
		system.assertEquals(false,controller.getShowAdjusted());
		system.assertEquals(100,controller.m_opportunity.Amount);
		system.assertEquals(110,[select Amount from Opportunity where id=:controller.m_opportunity.id].Amount);
	}
	
	@isTest(SeeAllData=true)
	static void testSaveException()
	{
		AdjustOpportunityController controller = setupTestEnvironment();
		controller.setAdjustmentPercentage(-110);
		controller.save();
		boolean foundError = false;
		for(ApexPages.Message message : ApexPages.getMessages())
		{
			if(message.getSeverity()==ApexPages.Severity.ERROR)
			{
				foundError=true;
				break;
			}
		}
		system.assert(foundError);
		system.assertEquals(false,controller.getShowAdjusted());
		system.assertEquals(100,controller.m_opportunity.Amount);
		system.assertEquals(10,controller.m_opportunity.OpportunityLineItems[0].UnitPrice);
		system.assertEquals(100,[select Amount from Opportunity where id=:controller.m_opportunity.id].Amount);
		system.assertEquals(10,[select UnitPrice from OpportunityLineItem where OpportunityId=:controller.m_opportunity.id].UnitPrice);
	}

	static AdjustOpportunityController setupTestEnvironment()
	{
		system.assert(Test.isRunningTest());
        Opportunity opp = new Opportunity(Name='MyTestOpportunity',StageName='Closed Won',CloseDate=System.today(),Amount=100);
        insert opp;
        Product2 prod = new Product2(Name='MyTestProduct');
        insert prod;
        Pricebook2 pb = [select id from Pricebook2 where isStandard=true];
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id=pb.id,Product2Id=prod.id,UnitPrice=10,isActive=true);
        insert pbe;
        List<OpportunityLineItem> opportunityLineItems = new List<OpportunityLineItem>{
        	new OpportunityLineItem(UnitPrice=10,Quantity=10,OpportunityId=opp.id,PricebookEntryId=pbe.id)
        };
        insert opportunityLineItems;
		PageReference pageRef = Page.adjustopportunity;
        Test.setCurrentPage(pageRef);
		ApexPages.StandardController standardController = new ApexPages.StandardController([select Amount, (select UnitPrice from OpportunityLineItems) from Opportunity where id=:opp.id]);
		return new AdjustOpportunityController(standardController);
	}

	static AdjustOpportunityController setupTestEnvironmentNoLines()
	{
		system.assert(Test.isRunningTest());
        Opportunity opp = new Opportunity(Name='MyTestOpportunity',StageName='Closed Won',CloseDate=System.today(),Amount=100);
        insert opp;
		PageReference pageRef = Page.adjustopportunity;
        Test.setCurrentPage(pageRef);
		ApexPages.StandardController standardController = new ApexPages.StandardController([select Amount from Opportunity where id=:opp.id]);
		return new AdjustOpportunityController(standardController);
	}

	static AdjustOpportunityController setupTestEnvironmentNoData()
	{
		system.assert(Test.isRunningTest());
		PageReference pageRef = Page.adjustopportunity;
        Test.setCurrentPage(pageRef);
		ApexPages.StandardController standardController = new ApexPages.StandardController(new Opportunity());
		return new AdjustOpportunityController(standardController);
	}
}