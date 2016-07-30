# Features
(only works with https://github.com/gfiehler/rabbithub/tree/3.6.2-Feature-Updates)

Adds Admin page for managing RabbitHub Functionality.

Including
* Viewing tables of 
  ..*Subscriptions
  ..*Consumers
  ..*HTTP Post Error Summary
  ..*Environment Variable Settings
* Actions
  ..*Create a new Subscription
  ..*Delete a Subscription
  ..*Re-Subscribe a Subscription

# Building

You can build and install it like any other plugin (see
[the plugin development guide](http://www.rabbitmq.com/plugin-development.html)).

# API

You can drive the HTTP API yourself. It installs into the management plugin's API; you should understand that first. Once you do, the additional paths look like:


    
    |GET   | PUT  |DELETE|POST  |Path       |Description|
    |:----:|:----:|:----:|:----:|:----------|:----------|
    |X     |      |      |X     |/api/hub/subscriptions |A list of all subscribers <br> To create a subscriber via a POST to this URL you will need a body like this: <br> `{"vhost":"myvhost","queue-or-exchange":"q or x","q-or-x-name":"queue name","callback-uri":"http://server:Port/subscriber/callback/url","topic":"hub.topic value","lease-seconds":"1000000000"}`|
    |X     |      |X     |      |/api/hub/subscriptions/*vhost*/*resource_type*/*resource_name*/*topic*/*callback* |Get a subscriber or Delete(Unsubscribe) a subscriber|
    |      |X     |      |      |/api/hub/subscriptions/*vhost*/*resource_type*/*resource_name*/*topic*/*callback*/*lease_microseconds* |Re-subscribe, this PUT api will unsubscribe then re-subscribe this entry |
    |X     |      |      |      |/api/hub/consumers |Get a list of consumers |
    |X     |      |      |      |/api/hub/consumers |Get a list of http post to subscriber error tracking |
    
    
# RabbitHub UI
## Overview Page
This page will show a list of subscribers, consumers, http post errors summary and environment variable settings.

The vhost column for each subscriber is a link to the details page.

## Details Page
On this page you see a single subscriber and its information along with two operations

**Delete:** this button will unsubscribe the entry.  This will remove the subscription and stop all consumers
**Re-Subscribe:**  this button will unsubscribe then subscribe the entry to reset if there is an issue.

 
    
    
