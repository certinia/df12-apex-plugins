Making your managed package extensible with Apex Plugins
========================================================

Dreamforce 2012 Session
-----------------------

Tuesday, September 18th: 1:45 PM - 2:15 PM  
Community Common, Moscone Center West, San Francisco

###Description
Apex-driven processing in packaged solutions is becoming more and more complex on the [Force.com](http://developer.force.com) platform these days. As an ISV, it is not always enough for your customers to create triggers or add their own logic around your custom objects to meet their unique requirements. Sometimes they simply want to effect or steer the existing calculations or data manipulation going on within the managed package. Join us to learn a pattern and approach that can be used to expose a plugin interface to your managed packages by using Apex Interfaces and the new Type.newInstance feature.

###Speakers
Stephen Willcock, FinancialForce.com  
[@stephenwillcock](https://twitter.com/stephenwillcock)

###Slides
[www.slideshare.net/stephenwillcock/apex-plugins](http://www.slideshare.net/stephenwillcock/apex-plugins)


Repository
----------

This repository contains all the code that was used to build a sample Force.com managed package to demonstrate the Plugin technique - [ff_df12_plugin](financialforcedev/df12-apex-plugins/tree/master/ff_df12_plugin), 
and a very simple [Plugin class](financialforcedev/df12-apex-plugins/tree/master/unpackaged) to accompany it.

If you want to play with the plugin, you can [install the managed package](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tE0000000DmLn). The package has deliberately been left in beta - it is provided purely for demonstrating the Plugin technique.

More usage details to follow after Dreamforce.

References
----------
[Martin Fowler, Patterns of Enterprise Application Architecture - Plugin](http://martinfowler.com/eaaCatalog/plugin.html)  
[Martin Fowler, Patterns of Enterprise Application Architecture - Separated Interface](http://martinfowler.com/eaaCatalog/separatedInterface.html)  
[Apex Developer's Guide - Type Methods](http://www.salesforce.com/us/developer/docs/apexcode/Content/apex_methods_system_type.htm)