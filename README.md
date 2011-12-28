## Description

CFML wrapper library for [PostalMethods Web-to-Postal Web Service](http://www.postalmethods.com/).

First version of this library was initially created for [ContactChimp](http://contactchimp.com/) application.

## Requirements

Library uses modern CFScript syntax, so it requires at least Adobe ColdFusion 9 or Railo 3.2 engine to work.

Library uses both types of access point (SOAP/POST) for different methods. POST API used for *Get* methods 
to avoid incompatibility with SOAP web-service, discovered in Apache Axis version used by Railo 3.x.
Additionally, XML response is easier to handle for these.

Please note that there are some [important limits](http://www.postalmethods.com/system-limitations) applied to API.

## Using Component

You need to have a PostalMethods account to use the API. No special API keys needed, just your username and password.
Make sure your account is in development work mode, though this is default state for new accounts.
You may be interested in creating multiple users, reasons of this are explained in 'Using Web-Service' section.

Please note the *assets* directory shipped with this library. There's a JSON file *status-codes.json*, 
it is required for proper translating API response codes to meaningful text (yes, API developers did not bother 
to return both code and text). Path to this file is passed as init argument, as will be described below.  

**init** initializes the component. It accepts three required arguments: *username* (string) and *password* (string) 
are actual credentials used for logging in to account; *statuscodes* (string) is full path to status codes JSON file.
Also there are two optional arguments: *useragent* (string) allows to override http agent (say, put your application 
name there), *verbose* (boolean) enables adding debugging info to response (cfhttp result, exception struct).
Credentials need to be set either with *init* or with *setApiKey(apikey)* in order to authenticate correctly.
   
See all API parameters and response fields [in API reference](http://www.postalmethods.com/method/2009-02-26).

There are few other helper (getter/setter) methods, please see component code for details.

## Using Web-Service

One of the problems with PostalMethods API is that you cannot select some letter properties when sending.
For example, print color and print sides are set only in CP /User Settings. Possible solution to this problem
is to create multiple users (they are not limited) with different combinations of settings and limited permissions. 

For example, we have admin user *johndoe* (John Doe) and want to send letters only. We are going to create four users 
with all color/side combinations. Name for each user would be 'johndoe' plus suffix identifying the settings:

- johndoe\_cs (Color Simplex)
- johndoe\_cd (Color Duplex)
- johndoe\_bs (Black Simplex)
- johndoe\_bd (Black Duplex)

Please note that letter preferences need to be set by logging in as each user and editing the settings.

Another useful feature here is **webhooks** support (in PostalMethods it is called 'Feedback').
[Webhook](http://wiki.webhooks.org/) is simple concept used as better alternative to polling requests 
(periodical checking the status of mailing). It is even more important here because of PostalMethods API 
limitations mentioned above.

In your application you need to set up webhook handler action (page) which accepts the request once
mailing completed/failed and does desired post-processing. It is recommended to add some simple layer of 
security for this page to prevent possible abuse, for example include secret authentication key in URL.

Webhooks are configured in User Settings / Feeback section. Possibly, HTTP POST is simplest approach,
plus it allows to use [Postbin](http://www.postbin.org) for testing easily. Please note the built-in authentication
options available, they are described in [docs](http://www.postalmethods.com/resources/reference/106), 
as well as all other webhook settings.

Another approach for integration testing can be implemented using previously described concepts.
Idea is simple: create four users with live webhook URL, and four with Postbin/dev site webhook URL.

## Usage Examples

Please check out [Developer's Guide](http://www.postalmethods.com/resources/developers-guide) for templates, 
content, addresses handling instructions, plus other relevant information.

Example of initialization and fetching details for range of mail IDs:

    ws = CreateObject("PostalMethods").init(
        username = "johndoe",
        password = "johndoe12345",
        statuscodes = ExpandPath("assets/status-codes.json"),
        verbose = true
    );

    result = ws.GetDetailsExtended("1234567-1234569");

    if (result.fault) {
        WriteOutput("Something went wrong: " & result.data);
        WriteDump(var=result.exception, label="Exception");
    }
    else {
        WriteDump(var=result.data, label="Success");
        WriteDump(var=result.result, label="HTTP Result");
    }

Here's (semi)real-life example of sending a batch of emails sharing the same template:

    // note: local.mailing object and local.addresses query are prepared somewhere above in code

    // initialize API wrapper object with admin permissions

    local.postalmethods = CreateObject("components.wrappers.PostalMethods").init(
        username = "johndoe",
        password = "johndoe12345",
        useragent = "JohnDoeStartup v1.0",
        statuscodes = ExpandPath("components/wrappers/assets/status-codes.json")
    );

    // upload the mailing template with random name

    local.filename = CreateUUID() & ".pdf";

    local.res = local.postalmethods.UploadFile(
        FilePath = ExpandPath("templates/#local.mailing.template#"),
        MyFileName = local.filename
    );

    if (local.res.fault) {
        throw(message="PostalMethods UploadFile failed. #local.res.data#");
    }

    // build specific API username by current mailing options

    local.username = "johndoe_";
    local.username &= (local.mailing.isMono ? "b" : "c") & (local.mailing.isDuplex ? "d" : "s");

    // initialize API wrapper object for specific user (password is pre-defined)

    local.postalmethods = CreateObject("components.wrappers.PostalMethods").init(
        username = local.username,
        password = "johndoe12345",
        useragent = "JohnDoeStartup v1.0",
        statuscodes = ExpandPath("components/wrappers/assets/status-codes.json")
    );

    // add mailings to queue one by one, batch processing is not supported by API

    for (local.idx=1; local.idx LTE local.addresses.recordCount; local.idx++) {

        local.res = local.postalmethods.SendLetterAndAddress(
            MyDescription = "Address ###local.addresses.id# of mailing ###local.mailing.id#",
            FileExtension = "MyFile:#local.filename#",
            AttentionLine1 = local.addresses.fullname[local.idx],
            AttentionLine2 = "",
            Company = local.addresses.company[local.idx],
            Address1 = local.addresses.address1[local.idx],
            Address2 = local.addresses.address2[local.idx],
            City = local.addresses.city[local.idx],
            State = local.addresses.state[local.idx],
            PostalCode = local.addresses.postalcode[local.idx],
            Country = local.addresses.country[local.idx]
        );

        if (local.res.fault) {
            // handle the failure, say log the details using local.res.data and mark address record as failed
        }
        else {
            // handle the successful queueing, say mark address record as queued
        }

    }

Finally, example of webhook status handling:

    if (StructKeyExists(url, "status") AND StructKeyExists(ws.getStatusCodes(), url.status)) {
        WriteOutput(ws.getStatusMessage(url.status));
    }
    else {
        WriteOutput("Unknown PostalMethods status code: " & url.status);
    }

## License

Library is released under the [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
