# Features
RabbitHub Management is a Rabbitmq Management Plugin for the RabbitHub Plugin
RabbitHub is a Webhooks Pub/Sub Plugin for Rabbitmq
Tested with Rabbitmq 3.6.1 3.6.2, 3.6.3 and 3.6.6
(only works with https://github.com/gfiehler/rabbithub/tree/3.6.3-Feature-Updates3, https://github.com/gfiehler/rabbithub/tree/3.6.6-Update and newer.)

Adds Admin page for managing RabbitHub Functionality.

Including

1. Viewing tables of 
  * Subscriptions
  * Consumers
  * HTTP Post Error Summary
  * Environment Variable Settings
  * Download Subscribers in JSON file
  * Upload Subscribers from a JSON file 
2. Actions
  * Create a new Subscription
  * Delete a Subscription
  * Re-Subscribe (Activate) a Subscription 
  
# Building

You can build and install it like any other plugin (see
[the plugin development guide](http://www.rabbitmq.com/plugin-development.html)).

This is dependent on the rabbitmq_management plugin being activated on the rabbitmq instance.

# Browser
The download subscriptions for either all subscriptions or for individual subscriptions seems to only work with Firefox as Chrome does not ask for credentials.  All other functions seem to work fine in Chrome.

# API
You can drive the HTTP API yourself. It installs into the management plugin's API; you should understand that first. Once you do, the additional paths look like:


| GET  | PUT  | DELETE  | POST | Path | Description |
| :---: |:---:| :---:| :---:| :------| :------|
| X |   |   | X | /api/hub/subscriptions | A list of all subscribers <br> To create a subscriber via a POST <br> to this URL you will need a body like this: <br> `{"vhost":"myvhost","queue-or-exchange":"q or x","q-or-x-name":"queue name","callback-uri":"http://server:Port/subscriber/callback/url","topic":"hub.topic value","lease-seconds":"1000000000"}` |
| X |   | X |   | /api/hub/subscriptions/<br>*vhost*/*resource_type*/*resource_name*/<br>*topic*/*callback* | Get a subscriber or Delete a subscriber |
|   | X |   |   | /api/hub/subscriptions/<br>*vhost*/*resource_type*/*resource_name*/<br>*topic*/*callback*/*lease_microseconds* | hub_mode = subscribe:<br>  Re-subscribe, this PUT api will re-subscribe this entry.<br> hub_mode = unsubscribe:  Deactivate, <br>this PUT api will deactivate the subscription.<br>This will shutdown all consumers and change status to inactive |
| X |   |   |   | /api/hub/consumers | Get a list of consumers  |
| X |   |   |   | /api/hub/errors | Get a list of http post to subscriber errors |

 
# RabbitHub UI
## Authorization
RabbitHub Management UI is a Rabbitmq_management UI plugin.  RabbitHub is setup as an admin function.  For a Rabbitmq user to use the RabbitHub Management Plugin, the user must have the `administrator` tag (role).
For a Rabbitmq_management user to perform export/import the user must have both `administrator,rabbithub_admin` tags (roles).

## Overview Page
This page will show a list of subscribers, consumers, http post errors summary, form to add a new subscriber, environment variable settings, and ability to import/export subscribers in batch.

The name column for each subscriber is a non-unqiue name that is a combination of the `resource_topic` and is a link to the details page for that subscriber.  A truly unique name would also have to inlcude the callback URL, however that was too long to use in the UI.  The name is a link to the details page for that Subscriber.

For details on what each field means for Adding a Subscriber, please see the RabbitHub readme file.

Environment Variables displayed in the configuration section can be found in the rabbitmq.config file.  This file is commonly found in /etc/rabbitmq directory in Unix installations.

Import and Export of subscribers can be done via the UI by downloading or uploading JSON files in the following format.  See RabbitHub batch processing for more details.

Note:  This can be used as backup or to migrate subscribers between environments.


```javascript
{
	"subscriptions": [{
		"vhost": "/",
		"resource_type": "queue",
		"resource_name": "ha.q2",
		"topic": "inactivetest",
		"callback": "http://callbackdomain/subscriber/s2",
		"lease_expiry_time_microsec": 1472911582355564,
		"lease_seconds": 1000000,
		"ha_mode": "all",
		"status": "inactive"
	}, {
		"vhost": "/",
		"resource_type": "queue",
		"resource_name": "ha.1",
		"topic": "activetest",
		"callback": "http://callbackdomain/subscriber/s1",
		"lease_expiry_time_microsec": 1472911582355564,
		"lease_seconds": 1000000,
		"ha_mode": "all",
		"status": "active"
	}]
```

## Details Page
On this page you see a single subscriber and its information along with three possible operations

 1. **Delete:** this button will unsubscribe the entry.  This will remove the subscription and stop all consumers
 2. **Activate/Resubscribe:**  this button will subscribe the entry to reset if there is an issue.
 3. **Deactivate:**  this button will unsubscribe or deactivate the entry.  This will shutdown all consumers for this entry and change its status to inactive.
 
 This page will also show the consumers and Post errors for this subscriber.
 
## Sample Screen Prints
### RabbitHub Management Main Screen with all features collapsed
<img src="doc/RabbitHub-Main%20Screen%20All%20Hidden.PNG" alt="RabbitHub Managment Main Screen"/>

### RabbitHub Management Main Screen with Subscribers
<img src="doc/RabbitHub-Main%20Screen%20Subscriptions.PNG" alt="RabbitHub Managment Main Screen:  Subscribers"/>

### RabbitHub Management Main Screen with Consumers
<img src="doc/RabbitHub-Main%20Screen%20Consumers.PNG" alt="RabbitHub Managment Main Screen:  Consumers"/>

### RabbitHub Management Main Screen with Subscriber Post Errors
<img src="doc/RabbitHub-Main%20Screen%20Post%20Errors.PNG" alt="RabbitHub Managment Main Screen:  Subscriber Post Errors"/>

### RabbitHub Management Main Screen with Add Subscriber Form
<img src="doc/RabbitHub-Main%20Screen%20Add%20Subscriber1.PNG" alt="RabbitHub Managment Main Screen:  Add Subscriber"/>

### RabbitHub Management Main Screen with Configuration
<img src="doc/RabbitHub-Main%20Screen%20Configuration.PNG" alt="RabbitHub Managment Main Screen:  Configuration"/>
 
### RabbitHub Management Main Screen with Batch Import/Export
<img src="doc/RabbitHub-Main%20Screen%20Batch%20Import%20Export.PNG" alt="RabbitHub Managment Main Screen:  Batch Import/Export"/>

### RabbitHub Management Main Screen with Batch Import Results
<img src="doc/RabbitHub-Main%20Screen%20Batch%20Import%20Results.png" alt="RabbitHub Managment Main Screen:  Batch Import Results"/>

### RabbitHub Management Subscriber Detail Page - Active
<img src="doc/RabbitHub%20Details%20Page%20Active.png" alt="RabbitHub Managment Main Screen:  Subscriber Detail Page - Active"/> 

### RabbitHub Management Subscriber Detail Page - Inactive
<img src="doc/RabbitHub%20Details%20Page%20Inactive.png" alt="RabbitHub Managment Main Screen:  Subscriber Detail Page - Inactive"/> 




 
    
    
