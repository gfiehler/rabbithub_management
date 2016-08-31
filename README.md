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
| Get  | PUT  | DELETE  | POST | Path | Description |
| :-------------: |:-------------:| -----:| ------:| ------:| ------:|
| X |   |   | X | 1 | 2 |
| X |   | X |   | 1 | 3 |
|   | X |   |   | 1 | 4 |
| X |   |   |   | 1 | 4 |
| X |   |   |   | 1 | 4 |
You can drive the HTTP API yourself. It installs into the management plugin's API; you should understand that first. Once you do, the additional paths look like:
    
    |GET   | PUT  |DELETE|POST  |Path       |Description|
    |:----:|:----:|:----:|:----:|:----------|:----------|
    |X     |      |      |X     |/api/hub/subscriptions |A list of all subscribers |
    |X     |      |X     |      |/api/hub/subscriptions/|Get a subscriber or Delete a subscriber|	
    |      |X     |      |      |/api/hub/subscriptions/ |hub_mode = subscribe:  |
    |X     |      |      |      |/api/hub/consumers |Get a list of consumers |
    |X     |      |      |      |/api/hub/consumers |Get a list of http post to subscriber error tracking |
    
    
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





 
    
    
