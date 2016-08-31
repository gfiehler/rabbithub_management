# Features
(only works with https://github.com/gfiehler/rabbithub/tree/3.6.2-Feature-Updates)

Adds Admin page for managing RabbitHub Functionality.

Including
* Viewing tables of 
  ..*Subscriptions
  ..*Consumers
  ..*HTTP Post Error Summary
  ..*Environment Variable Settings
  ..*Download Subscribers in JSON file
  ..*Upload Subscribers from a JSON file
* Actions
  ..*Create a new Subscription
  ..*Delete a Subscription
  ..*Re-Subscribe a Subscription

# Building

You can build and install it like any other plugin (see
[the plugin development guide](http://www.rabbitmq.com/plugin-development.html)).

# API
You can drive the HTTP API yourself. It installs into the management plugin's API; you should understand that first. Once you do, the additional paths look like:


| Get  | PUT  | DELETE  | POST | Path | Description |
| :---: |:---:| :---:| :---:| :------| :------|
| X |   |   | X | /api/hub/subscriptions | A list of all subscribers <br> To create a subscriber via a POST <br> to this URL you will need a body like this: <br> `{"vhost":"myvhost","queue-or-exchange":"q or x","q-or-x-name":"queue name","callback-uri":"http://server:Port/subscriber/callback/url","topic":"hub.topic value","lease-seconds":"1000000000"}` |
| X |   | X |   | /api/hub/subscriptions/<br>*vhost*/*resource_type*/*resource_name*/<br>*topic*/*callback* | Get a subscriber or Delete a subscriber |
|   | X |   |   | /api/hub/subscriptions/<br>*vhost*/*resource_type*/*resource_name*/<br>*topic*/*callback*/*lease_microseconds* | hub_mode = subscribe:<br>  Re-subscribe, this PUT api will re-subscribe this entry.<br> hub_mode = unsubscribe:  Deactivate, <br>this PUT api will deactivate the subscription.<br>This will shutdown all consumers and change status to inactive |
| X |   |   |   | /api/hub/consumers | Get a list of consumers  |
| X |   |   |   | /api/hub/errors | Get a list of http post to subscriber errors |

 
# RabbitHub UI
## Overview Page
This page will show a list of subscribers, consumers, http post errors summary and environment variable settings.

The name column for each subscriber is a non-unqiue name that is a combination of the `resource_topic` to the details page.  A truly unique name would also have to inlcude the callback URL, however that was too long to use in the UI.  The name is a link to the details page for that Subscriber.

Import and Export of subscribers can be done via the UI by downloading or uploading JSON files in the following format.  
Note:  This can be used as backup or to migrate subscribers between environments

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





 
    
    
