## Description

CFML wrapper library for [PostalMethods Web-to-Postal Web Service v2009-02-26](http://www.postalmethods.com/postal-api).

First version of this library was initially created for [ContactChimp](http://contactchimp.com/) application.

## Requirements

Library uses modern CFScript syntax, so it requires at least Adobe ColdFusion 9 or Railo 3.2 engine to work.

Library uses both types of access point (SOAP/POST) for different methods. POST API used for Get* methods 
to avoid incompatibility with SOAP web-service, discovered in Apache Axis version used by Railo 3.x.
Additionally, XML response is easier to handle for these.

Please note that there are some [important limits](http://www.postalmethods.com/system-limitations) applied to API.

## Using Component

First you need to register an account and [](https://www.smartystreets.com/Account/Api/Install/rest/).

Please note the assets directory shipped with this library before. There's a JSON file status-codes.json, 
it is required for proper translating API response codes to meaningful text (yes, API developers did not bother 
to return both code and text). Path to this file is passed as init argument, as will be described below.  

ToDo
   
See all API parameters and response fields [in API reference](http://www.postalmethods.com/resources/reference/postal-web-service).

There are few other helper (getter/setter) methods, please see component code for details.

## Usage Examples

Please check out [Developer's Guide](http://www.postalmethods.com/resources/developers-guide) for templates, 
content, addresses handling instructions, plus other relevant information.

ToDo

## Tips & Tricks

ToDo 

 - tell about settings through users
 - tell about webhooks

## License

Library is released under the [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
