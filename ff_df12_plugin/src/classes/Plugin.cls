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

global class Plugin
{
	/* 
	 * Each plugin has 3 components:
	 * 1. public static factory method which returns the plugin instance, cast to the interface type
	 * 2. global interface which must be implemented by the plugin class
	 * 3. global class implementing the interface and providing a default implementation in the absence of a plugin
	 *    The default class may implement default behaviour directly, or extend / delegate to another class in the package
	 *
	 * Note - we could use [interface].class.getName() to derive plugin keys here, however, as the key is used in a custom setting name
	 * we are hardcoding keys instead, e.g. KEY_VALIDATE_OPPORTUNITY_ADJUSTMENTS, to avoid exceeding the length of the name field.
	 */

	// -------------------- Start of Plugins --------------------

	// IValidateOpportunityAdjustments

	public static final String KEY_VALIDATE_OPPORTUNITY_ADJUSTMENTS = 'IValidateOpportunityAdjustments';
	
	public static Plugin.IValidateOpportunityAdjustments getInstanceIValidateOpportunityAdjustments()
	{
		Object result = getInstance(KEY_VALIDATE_OPPORTUNITY_ADJUSTMENTS);
		return (Plugin.IValidateOpportunityAdjustments) (result == null ? new DefaultValidateOpportunityAdjustments() : result);
	}
	
	global interface IValidateOpportunityAdjustments
	{
		void validate(Opportunity opportunity, List<OpportunityLineItem> opportunityLineItems, Decimal adjustmentProportion);
	}

	global class DefaultValidateOpportunityAdjustments implements IDefault,IValidateOpportunityAdjustments
	{
		global void validate(Opportunity opportunity, List<OpportunityLineItem> opportunityLineItems, Decimal adjustmentProportion)
		{
			if(opportunity.Amount==null || opportunity.Amount<0)
				throw new PluginException(Label.PluginAdjustedValuesMustBePositive);
			if(opportunityLineItems==null)
				return;
			for(OpportunityLineItem item : opportunityLineItems)
				if(item.UnitPrice==null || item.UnitPrice<0)
					throw new PluginException(Label.PluginAdjustedValuesMustBePositive);
		}
	}
	
	// IAdjustOpportunities

	public static final String KEY_ADJUST_OPPORTUNITIES = 'IAdjustOpportunities';

	public static Plugin.IAdjustOpportunities getInstanceIAdjustOpportunities()
	{
		Object result = getInstance(KEY_ADJUST_OPPORTUNITIES);
		return (Plugin.IAdjustOpportunities) (result == null ? new DefaultAdjustOpportunities() : result);
	}
	
	global interface IAdjustOpportunities
	{
		void adjust(Opportunity opportunity, List<OpportunityLineItem> opportunityLineItems, Decimal adjustmentProportion);
	}

	global class DefaultAdjustOpportunities implements IDefault,IAdjustOpportunities
	{
		global virtual void adjust(Opportunity opportunity, List<OpportunityLineItem> opportunityLineItems, Decimal adjustmentProportion)
		{
			for(OpportunityLineItem item : opportunityLineItems)
				item.UnitPrice = item.UnitPrice + (item.UnitPrice * adjustmentProportion);
			
			opportunity.Amount = opportunity.Amount + (opportunity.Amount * adjustmentProportion);
		}
	}

	// -------------------- End of Plugins --------------------


	// Private factory method generates a generic object by interface identifier (shortened name)
	static Object getInstance(String interfaceKey)
	{
		PluginSettings__c pluginSettings = PluginSettings__c.getInstance(interfaceKey);
		if(pluginSettings==null)
			return null;
		// From Winter'13 Type.forName(String) in a managed package does not resolve unmanaged (local) apex class
		// Namespace must explicitly be set to an empty value to reference an unmanaged class  
		Type t = Type.forName(pluginSettings.NamespacePrefix__c,pluginSettings.ApexClassName__c); 
		if(t==null)
			throw new PluginException(Messages.getPluginClassNotFound(pluginSettings.ApexClassName__c));
		return t.newInstance();
	}

	// Marker Interface 
	// See http://en.wikipedia.org/wiki/Marker_interface_pattern
	
	public interface IDefault {}
	
	// Exception class
	
	class PluginException extends Exception{}
	


	/*
	 * Tests
	 */

	// Test values
	
	static final String TEST_KEY = 'ICanBeTested';
	static final String TEST_NAME = 'Plugin.DefaultCanBeTested';
	static final String NAMESPACE = 'ff_df12_plugin';

	// Test classes
	
	interface ICanBeTested
	{
		String invoke(String arg);
	}
	
	class DefaultCanBeTested implements ICanBeTested
	{
		public String invoke(String arg)
		{
			return arg + 'response';
		}
	}
	

	// specific plugin tests

	@isTest
	static void testGetInstanceIAdjustOpportunities()
	{
		// test no plugin configured
		system.assert(getInstanceIAdjustOpportunities() != null);
		// test plugin configured
		insert new PluginSettings__c(Name=KEY_ADJUST_OPPORTUNITIES,NamespacePrefix__c=NAMESPACE,ApexClassName__c='Plugin.DefaultAdjustOpportunities');	
		system.assert(getInstanceIAdjustOpportunities() != null);
		getInstanceIAdjustOpportunities().adjust(new Opportunity(Amount=100), new List<OpportunityLineItem>(), Decimal.valueOf(0));
	}

	@isTest
	static void testAdjusterAdjust()
	{
		DefaultAdjustOpportunities adjuster = new DefaultAdjustOpportunities();
		Opportunity opportunity = new Opportunity(Amount=100);
		List<OpportunityLineItem> opportunityLineItems = new List<OpportunityLineItem>{
			new OpportunityLineItem(UnitPrice=10)
		};
		adjuster.adjust(opportunity, opportunityLineItems, 0.1);
		system.assertEquals(110,opportunity.Amount);
		system.assertEquals(11,opportunityLineItems[0].UnitPrice);
	}

	@isTest
	static void testGetInstanceIValidateOpportunityAdjustments()
	{
		// test no plugin configured
		system.assert(getInstanceIValidateOpportunityAdjustments() != null);
		// test plugin configured
		insert new PluginSettings__c(Name=KEY_VALIDATE_OPPORTUNITY_ADJUSTMENTS,NamespacePrefix__c=NAMESPACE,ApexClassName__c='Plugin.DefaultValidateOpportunityAdjustments');	
		system.assert(getInstanceIValidateOpportunityAdjustments() != null);
		getInstanceIValidateOpportunityAdjustments().validate(new Opportunity(Amount=0), new List<OpportunityLineItem>(), Decimal.valueOf(0));
	}

	@isTest
	static void testDefaultValidateOpportunityAdjustmentsValidate()
	{
		DefaultValidateOpportunityAdjustments validator = new DefaultValidateOpportunityAdjustments();
		Opportunity opportunity = new Opportunity(Amount=1);
		List<OpportunityLineItem> opportunityLineItems = new List<OpportunityLineItem>{
			new OpportunityLineItem(UnitPrice=1)
		};
		// no exception expected
		validator.validate(opportunity, opportunityLineItems, null);
	}

	@isTest
	static void testDefaultValidateOpportunityAdjustmentsValidateNullLines()
	{
		DefaultValidateOpportunityAdjustments validator = new DefaultValidateOpportunityAdjustments();
		Opportunity opportunity = new Opportunity(Amount=1);
		// no exception expected
		validator.validate(opportunity, null, null);
	}

	@isTest
	static void testDefaultValidateOpportunityAdjustmentsValidateException()
	{
		DefaultValidateOpportunityAdjustments validator = new DefaultValidateOpportunityAdjustments();
		Opportunity opportunity = new Opportunity(Amount=-1);
		List<OpportunityLineItem> opportunityLineItems = new List<OpportunityLineItem>{
			new OpportunityLineItem(UnitPrice=1)
		};
		// exception expected
		try
		{
			validator.validate(opportunity, opportunityLineItems, null);
			system.assert(false,'Expected exception not thrown');
		}
		catch(Exception e)
		{
			system.assert(e instanceof PluginException);
		}
	}

	@isTest
	static void testDefaultValidateOpportunityAdjustmentsValidateExceptionOnLine()
	{
		DefaultValidateOpportunityAdjustments validator = new DefaultValidateOpportunityAdjustments();
		Opportunity opportunity = new Opportunity(Amount=1);
		List<OpportunityLineItem> opportunityLineItems = new List<OpportunityLineItem>{
			new OpportunityLineItem(UnitPrice=-1)
		};
		// exception expected
		try
		{
			validator.validate(opportunity, opportunityLineItems, null);
			system.assert(false,'Expected exception not thrown');
		}
		catch(Exception e)
		{
			system.assert(e instanceof PluginException);
		}
	}

	// General tests

	@isTest
	static void testGetInstance()
	{
		insert new PluginSettings__c(Name=TEST_KEY,NamespacePrefix__c=NAMESPACE,ApexClassName__c=TEST_NAME);	
		Object o = getInstance(TEST_KEY);
		system.assert(o != null);
		system.assert(o instanceof DefaultCanBeTested);
		ICanBeTested result = (ICanBeTested) o;
		system.assertEquals('requestresponse', result.invoke('request'));
	}

	@isTest
	static void testGetInstanceNull()
	{
		Object result = getInstance(TEST_KEY);
		system.assertEquals(null, result);
	}

	@isTest
	static void testGetInstanceBadClassName()
	{
		// Note - cannot use a non-existent inner class for a 'bad' class name: "System.UnexpectedException: Salesforce System Error"
		String className = 'DoesNotExist';  

		insert new PluginSettings__c(Name=TEST_KEY,NamespacePrefix__c=NAMESPACE,ApexClassName__c=className);	
		try
		{
			getInstance(TEST_KEY);
			system.assert(false,'Exception not thrown');
		}
		catch(Exception e)
		{
			system.assert(e instanceof PluginException);
			system.assertEquals(Messages.getPluginClassNotFound(className),e.getMessage());
		}
	}
}