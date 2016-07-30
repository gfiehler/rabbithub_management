dispatcher_add(function(sammy) {
  
   
    sammy.get('#/hub/subscriptions', function() {
            render({'hub': {path:    '/hub/subscriptions',
                            options: {sort: true}},
                    'consumers': {path:    '/hub/consumers',
                                  options: {sort: true}},
                    'errors':    '/hub/errors',
                    'environment':  '/hub/environment',
                    'vhosts':    '/vhosts'},
                    'hub', '#/hub/subscriptions');                                    
    });
    
    sammy.post('#/hub/subscriptions', function() {  
        if (post_subscription(this))
            update();    
        return false;        
    });

    sammy.get('#/hub/subscriptions/:vhost/:type/:resource/:topic/:callback', function() {        
        render({'hub': '/hub/subscriptions/' + esc(this.params['vhost']) + '/' + esc(this.params['type']) + '/' + esc(this.params['resource']) + '/' + esc(this.params['topic']) + '/' + esc(this.params['callback'])},
                    'subscription', '#/hub/subscriptions');
    });
    
    sammy.del('#/hub/subscriptions', function() {
        if (delete_subscription(this.params['vhost'], this.params['type'], this.params['resource'], this.params['topic'], this.params['callback']))
            go_to('#/hub/subscriptions');
        return false;
    });
    
    sammy.put('#/hub/subscriptions', function() {
        if (resubscribe(this.params['vhost'], this.params['type'], this.params['resource'], this.params['topic'], this.params['callback'], this.params['lease']))
            go_to('#/hub/subscriptions');
        return false;
    });
    
});


NAVIGATION['Admin'][0]['RabbitHub']            = ['#/hub/subscriptions', 'administrator'];


HELP['environment'] = 'RabbitHub environment variables can be set in the rabbitmq.config file under the rabbithub application.';

HELP['requeue_on_http_post_error'] = '<p>RabbitHub environment variable- requeue_on_http_post_error:  (true, false) <dl><dt>true: (default)</dt><dd>will not requeue, message may be lost</dd> <dt>false:</dt> <dd>will requeue, best utilized when queue has a dead-letter-exchange configured</dd></dl></p>';

HELP['unsubscribe_on_http_post_error'] = '<p>RabbitHub environment variable- unsubscribe_on_http_post_error:  (true, false) <dl><dt>true: (default)</dt><dd>on HTTP Post error to subscriber, the consumer will be unsubscribed</dd> <dt>false:</dt> <dd>on HTTP Post error to subscriber the consumer will not be unsubscribed</dd><dt>Note: </dt><dd>If this variable is set to false, it will override unsubscribe_on_http_post_error_limit and unsubscribe_on_http_post_error_timeout_microseconds and not unsubscribe even when reaching the configured limits.</dd></dl></p>';

HELP['unsubscribe_on_http_post_error_limit'] = '<p>RabbitHub environment variable- unsubscribe_on_http_post_error_limit:  (integer) <dl><dt>Integer value is how many errors are allowed prior to the consumer being unsubscribed</dt><dt>Note:</dt><dd>unsubscribe_on_http_post_error_limit and unsubscribe_on_http_post_error_timeout_microseconds must be set as a pair as it designates that unsubscribe_on_http_post_error_limit may occur within unsubscribe_on_http_post_error_timeout_microseconds time interval before the consumer is unsubscribed</dd></dl></p>';

HELP['unsubscribe_on_http_post_error_timeout_microseconds'] = '<p>RabbitHub environment variable- unsubscribe_on_http_post_error_timeout_microseconds:  (microseconds) <dl><dt>Time interval where unsubscribe_on_http_post_error_limit errors are allowed to happen prior to unsubscribing the consumer</dt><dt>Note:</dt><dd>unsubscribe_on_http_post_error_limit and unsubscribe_on_http_post_error_timeout_microseconds must be set as a pair as it designates that unsubscribe_on_http_post_error_limit may occur within unsubscribe_on_http_post_error_timeout_microseconds time interval before the consumer is unsubscribed</dd></dl></p>';

HELP['wait_for_consumer_restart_milliseconds'] = '<p>RabbitHub environment variable- wait_for_consumer_restart_milliseconds:  (milliseconds) <dl><dt>If a consumer fails, the configured interval will be waited prior to attemtping a restart.  This is useful when a master queue fails over to a new host.</dt></dl></p>';

HELP['ha_consumers'] = '<p>RabbitHub environment variable- ha_consumers:  (all, Int) <dl><dt>none:</dt><dd>default behaviour is when a subscription is created to start a consumer on the node to which the subscription request was sent</dd> <dt>all:</dt> <dd>when a subscription is created start a consumer on all nodes in the cluster</dd><dt>Int</dt><dd>When a subscription is created start a consumer on (Int) nodes in the cluster.  The nodes are picked at random.  If (Int) is greater than the number of nodes it will behave like (all)</dd></dl></p>';

HELP['log_http_post_request'] = '<p>RabbitHub environment variable- log_http_post_request:  (true, false) <dl><dt>true:</dt><dd>Log messags being Posted to RabbitHUb subscribers</dd> <dt>false: (default)</dt> <dd>Do not log messags being Posted to RabbitHUb subscribers</dd></dl></p>';

HELP['append_hub_topic_to_callback'] = '<p>RabbitHub environment variable- append_hub_topic_to_callback:  (true, false) <dl><dt>true: (default)</dt><dd>Append hub.topic parameter when Posting a message to a subscriber</dd> <dt>false: </dt> <dd>Do not append hub.topic parameter when Posting a message to a subscriber</dd></dl></p>';

HELP['include_servername_in_consumer_tag'] = '<p>RabbitHub environment variable- include_servername_in_consumer_tag:  (true, false) <dl><dt>true: </dt><dd>Add local server name to standard consumer tag [amq.http.consumer.localservername-AhKV3L3eH2gZbrF79v2kig]</dd> <dt>false: (default)</dt> <dd>Use standard consumer tag [amq.http.consumer-AhKV3L3eH2gZbrF79v2kig]</dd><dt>Note: </dt><dd>Consumer tags can be viewed in the queue details screen</dd></dl></p>';

HELP['default_username'] = '<p>RabbitHub environment variable- default_username:  (rabbitmq username) <dl><dt>This is the username that Rabbithb will use if one is not explicitly sent to the RabbitHub apis.</dt></dl></p>';

HELP['listener'] = '<p>RabbitHub environment variable- listener port:  (port) <dl><dt>This is the port on which the RabbitHub apis will listen.</dt></dl></p>';

HELP['http_client_options'] = '<p>RabbitHub environment variable- http_client_options:  (various) <dl><dt>These are options that can be set to control the http client behaviour.</dt></dl></p>';



function fmt_micro_to_date(micro) {
    var milli = micro / 1000;
    var date = new Date(milli).toUTCString();

    return date;
}



function post_subscription(sammy) {
    var path = '/hub/subscriptions';
	var req = xmlHttpRequest();
	var type = 'POST';
    req.open(type, 'api' + path, false);
    req.setRequestHeader('content-type', 'application/json');
    req.setRequestHeader('authorization', auth_header());
    
    req.send(JSON.stringify(sammy.params));
    if (req.status >= 200 && req.status < 300) {
        return true;
    } 
    show_popup('warn', req.responseText);    
    return false;
    
}
	
function link_subscriptions(name, vhost, resource_type, resource_name, topic, callback) {
    var link = _link_to(name, '#/hub/subscriptions/' + esc(vhost) + '/' + esc(resource_type) + '/' + esc(resource_name) + '/' + esc(topic) + '/' + esc(callback));
    return link;
}

function delete_subscription(vhost, resource_type, resource_name, topic, callback) {
    var path = '/hub/subscriptions/' + esc(vhost) + '/' + esc(resource_type) + '/' + esc(resource_name)+ '/' + esc(topic)+ '/' + esc(callback);
	var req = xmlHttpRequest();
	var type = 'DELETE';
    req.open(type, 'api' + path, false);
    req.setRequestHeader('content-type', 'application/json');
    req.setRequestHeader('authorization', auth_header());

    req.send();
    if (req.status >= 200 && req.status < 300) {
        return true;
    } 
    show_popup('warn', req.responseText);    
    return false;
    

}

function resubscribe(vhost, resource_type, resource_name, topic, callback, lease) {
    var path = '/hub/subscriptions/' + esc(vhost) + '/' + esc(resource_type) + '/' + esc(resource_name)+ '/' + esc(topic)+ '/' + esc(callback)+ '/' + esc(lease);
	var req = xmlHttpRequest();
	var type = 'PUT';
    req.open(type, 'api' + path, false);
    req.setRequestHeader('content-type', 'application/json');
    req.setRequestHeader('authorization', auth_header());

    req.send();
    if (req.status >= 200 && req.status < 300) {
        return true;
    } 
    show_popup('warn', req.responseText);    
    return false;
    

}

function fmt_rabbithub_endpoint(resourceType, resourceName) {
    var txt = '';
    if (resourceType == 'queue') {
        txt += resourceName + '<sub>queue</sub>';
    } else if (resourceType == 'exchange') {
        txt += resourceName + '<sub>exchange</sub>';     
    } else {
        txt += resourceName;
    }
    return txt;
}

