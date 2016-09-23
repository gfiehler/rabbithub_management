

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
        render({'hub': '/hub/subscriptions/' + esc(this.params['vhost']) + '/' 
                    + esc(this.params['type']) + '/' + esc(this.params['resource']) 
                    + '/' + esc(this.params['topic']) + '/' + esc(this.params['callback']),
                'consumers': '/hub/consumers/' + esc(this.params['vhost']) + '/' 
                    + esc(this.params['type']) + '/' + esc(this.params['resource']) 
                    + '/' + esc(this.params['topic']) + '/' + esc(this.params['callback']),
                'errors': '/hub/errors/' + esc(this.params['vhost']) 
                    + '/' + esc(this.params['type']) + '/' + esc(this.params['resource']) 
                    + '/' + esc(this.params['topic']) + '/' + esc(this.params['callback'])},
                'subscription', '#/hub/subscriptions');
    });
    
    sammy.del('#/hub/subscriptions', function() {
        if (delete_subscription(this.params['vhost'], this.params['type'], this.params['resource'], 
                this.params['topic'], this.params['callback']))
            go_to('#/hub/subscriptions');
        return false;
    });
        
    sammy.put('#/hub/subscriptions', function() {   
        if (resubscribe(this))
            update();
        return false;
    });
        
    sammy.post('#/hub/subscriptions/batch', function() {
        importResults = post_batch(this); 
        json = JSON.parse(importResults);
        html = format('import-results', json);
        document.getElementById("subscription-import-results").innerHTML = html;
        return false;        
    });
    
});


NAVIGATION['Admin'][0]['RabbitHub']            = ['#/hub/subscriptions', 'administrator'];


HELP['environment'] = 'RabbitHub environment variables can be set in the rabbitmq.config file under the rabbithub application.';

HELP['requeue_on_http_post_error'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>requeue_on_http_post_error</strong></mark>:  (true, false) <dl><dt>true: (default)</dt><dd>will not requeue, message may be lost</dd> <dt>false:</dt> <dd>will requeue, best utilized when queue has a dead-letter-exchange configured</dd></dl></p>';

HELP['unsubscribe_on_http_post_error'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>unsubscribe_on_http_post_error</strong></mark>:  (true, false) <dl><dt>true: (default)</dt><dd>on HTTP Post error to subscriber, the consumer will be unsubscribed</dd> <dt>false:</dt> <dd>on HTTP Post error to subscriber the consumer will not be unsubscribed</dd><dt>Note: </dt><dd>If this variable is set to false, it will NOT override unsubscribe_on_http_post_error_limit and unsubscribe_on_http_post_error_timeout_milliseconds and will unsubscribe when reaching the configured limits.</dd></dl></p>';

HELP['unsubscribe_on_http_post_error_limit'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>unsubscribe_on_http_post_error_limit</strong></mark>:  (integer) <dl><dt>Integer value is how many errors are allowed prior to the consumer being unsubscribed</dt><dt>Note:</dt><dd>unsubscribe_on_http_post_error_limit and unsubscribe_on_http_post_error_timeout_milliseconds must be set as a pair as it designates that unsubscribe_on_http_post_error_limit may occur within unsubscribe_on_http_post_error_timeout_milliseconds time interval before the consumer is unsubscribed</dd></dl></p>';

HELP['unsubscribe_on_http_post_error_timeout_milliseconds'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>unsubscribe_on_http_post_error_timeout_milliseconds</strong></mark>:  (milliseconds) <dl><dt>Time interval where unsubscribe_on_http_post_error_limit errors are allowed to happen prior to unsubscribing the consumer</dt><dt>Note:</dt><dd>unsubscribe_on_http_post_error_limit and unsubscribe_on_http_post_error_timeout_milliseconds must be set as a pair as it designates that unsubscribe_on_http_post_error_limit may occur within unsubscribe_on_http_post_error_timeout_milliseconds time interval before the consumer is unsubscribed</dd></dl></p>';

HELP['wait_for_consumer_restart_milliseconds'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>wait_for_consumer_restart_milliseconds</strong></mark>:  (milliseconds) <dl><dt>If a consumer fails, the configured interval will be waited prior to attemtping a restart.  This is useful when a master queue fails over to a new host.</dt></dl></p>';

HELP['ha_consumers'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>ha_consumers</strong></mark>:  (all, Int) <dl><dt>none:</dt><dd>default behaviour is when a subscription is created to start a consumer on the node to which the subscription request was sent</dd> <dt>all:</dt> <dd>when a subscription is created start a consumer on all nodes in the cluster</dd><dt>Int</dt><dd>When a subscription is created start a consumer on (Int) nodes in the cluster.  The nodes are picked at random.  If (Int) is greater than the number of nodes it will behave like (all)</dd></dl></p>';

HELP['log_http_post_request'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>log_http_post_request</strong></mark>:  (true, false) <dl><dt>true:</dt><dd>Log messags being Posted to RabbitHUb subscribers</dd> <dt>false: (default)</dt> <dd>Do not log messags being Posted to RabbitHUb subscribers</dd></dl></p>';

HELP['validate_callback_on_unsubscribe'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>validate_callback_on_unsubscribe</strong></mark>:  (true, false) <dl><dt>true: (default)</dt><dd>To unsubscribe or deactivate a subscription, the callback URL must be active and validate to allow deactivation</dd> <dt>false: </dt> <dd>RabbitHub will not validate a unsubscribe/deactivation with the callback URL</dd></dl></p>';

HELP['append_hub_topic_to_callback'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>append_hub_topic_to_callback</strong></mark>:  (true, false) <dl><dt>true: (default)</dt><dd>Append hub.topic parameter when Posting a message to a subscriber</dd> <dt>false: </dt> <dd>Do not append hub.topic parameter when Posting a message to a subscriber</dd></dl></p>';

HELP['include_servername_in_consumer_tag'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>include_servername_in_consumer_tag</strong></mark>:  (true, false) <dl><dt>true: </dt><dd>Add local server name to standard consumer tag [amq.http.consumer.localservername-AhKV3L3eH2gZbrF79v2kig]</dd> <dt>false: (default)</dt> <dd>Use standard consumer tag [amq.http.consumer-AhKV3L3eH2gZbrF79v2kig]</dd><dt>Note: </dt><dd>Consumer tags can be viewed in the queue details screen</dd></dl></p>';

HELP['log_http_headers'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>log_http_headers</strong></mark>:  ([&#39;header1&#39;, &#39;header2&#39;,...]) <dl><dt>List of http headers </dt><dd>A comma separated list of http headers to be logged with each published event</dd> <dt>Note: </dt><dd>E.g. [&#39;content&#45;type&#39;, &#39;Authorization&#39;]</dd></dl></p>';

HELP['set_correlation_id'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>set_correlation_id</strong></mark>:  (&#39;header&#39;) <dl><dt>Http header Name </dt><dd>The name of a http header to use as a message correlation id, when recieved on a publish event, the id will be passed to the subscriber in the same http header</dd> <dt>Note: </dt><dd>E.g. &#39;x-correlation-id&#39;</dd></dl></p>';

HELP['set_message_id'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>set_message_id</strong></mark>:  (&#39;header&#39;) <dl><dt>Http header Name </dt><dd>The name of a http header to use to pass a RabbitHub generated message id to subscribers</dd> <dt>Note: </dt><dd>E.g. &#39;x-message-id&#39;</dd></dl></p>';

HELP['default_username'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>default_username</strong></mark>:  (rabbitmq username) <dl><dt>This is the username that Rabbithb will use if one is not explicitly sent to the RabbitHub apis.</dt></dl></p>';

HELP['listener'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>listener port</strong></mark>:  (port) <dl><dt>This is the port on which the RabbitHub apis will listen.</dt></dl></p>';

HELP['http_client_options'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>http_client_options</strong></mark>:  <dl><dt>These are options that can be set to control the http client behaviour.</dt></dl></p>';

HELP['http_request_options'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>http_request_options</strong></mark>:  <dl><dt>These are options that can be set to control http request to the subscriber.</dt></dl></p>';

HELP['log_maxtps_delay'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>log_maxtps_delay</strong></mark>:  (true, false) <dl><dt>true: </dt><dd>If subscriber has Max TPS set (non zero) do not log the delay time for each POST</dd> <dt>false:  (default) </dt> <dd>If subscriber has Max TPS set (non zero) log the delay time for each POST</dd><dt>Note: </dt><dd>Max TPS can be set when creating a subscriber with the hub.maxttps parameter, this value is used to calculate how long to delay between POSTs to a subscriber.  See documentation for details.</dd></dl></p>';

HELP['use_internal_queue_for_pseudo_queue'] = '<p><strong>RabbitHub environment variable-</strong> <mark><strong>use_internal_queue_for_pseudo_queue</strong></mark>:  (true, false) <dl><dt>true:  (default) </dt><dd>Backwards compatibility setting, by default RabbitHub uses an internally declared queue when a subscription is made directly to an exchange.  In this mode some new features in error management are not avaiable and consumers are not assigned to the queue.</dd> <dt>false:</dt> <dd>Generate a queue and assign to a standard consumer, all RabbitHUb features are available. </dd><dt>Note: </dt><dd>See documentation for details.</dd></dl></p>';



function post_subscription(sammy) {
    var path = '/hub/subscriptions';
	var req = xmlHttpRequest();
	var type = 'POST';
    req.open(type, 'api' + path, false);
    req.setRequestHeader('content-type', 'application/json');
    req.setRequestHeader('authorization', auth_header());
    
    req.send(esc(JSON.stringify(sammy.params)));
    if (req.status >= 200 && req.status < 300) {
        return true;
    } 
    show_popup('warn', req.responseText);    
    return false;
    
}

function post_batch(sammy) {
    var myform = document.getElementById("importForm");  
    var path = '/hub/subscriptions/batch';
	var req = xmlHttpRequest();
	var type = 'POST';
    var file = document.getElementById("subfile").files[0];
    var fd = new FormData();     

    req.open(type, 'api' + path, false);
    req.setRequestHeader('authorization', auth_header());    
    fd.append("file", file);
    
    req.send(fd);
    if (req.status >= 200 && req.status < 300) {               
        return req.responseText;
    } 
    show_popup('warn', req.responseText);    
    //submit_subscriptions_import(myform);
    return false;
    
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

function resubscribe(sammy) {
    var vhost = sammy.params['vhost'];
    var type =  sammy.params['type'];
    var resource =  sammy.params['resource'];
    var topic = sammy.params['topic'];
    var callback = sammy.params['callback'];
    var lease =  sammy.params['lease'];
    var lease_sec = sammy.params['lease_sec'];
    var ha_mode = sammy.params['ha_mode'];
    var hub_mode = sammy.params['hub_mode'];
    var maxtps = sammy.params['maxtps'];
    var path = '/hub/subscriptions/' + esc(vhost) + '/' + esc(type) + '/' + esc(resource)+ '/' + esc(topic)+ '/' + esc(callback);
	var req = xmlHttpRequest();
	var type = 'PUT';
	
    req.open(type, 'api' + path, false);
    req.setRequestHeader('content-type', 'application/json');
    req.setRequestHeader('authorization', auth_header());
    req.send(esc(JSON.stringify(sammy.params)));
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

function fmt_rabbithub_download_filename() {
    var now = new Date();
    return rabbithub + "_" + now.getFullYear() + "-" +
        (now.getMonth() + 1) + "-" + now.getDate() + ".json";
}

function link_subscriptions(name, vhost, resource_type, resource_name, topic, callback) {
    var link = _link_to(name, '#/hub/subscriptions/' + esc(vhost) + '/' + esc(resource_type) + '/' + esc(resource_name) + '/' + esc(topic) + '/' + esc(callback));
    return link;
}

function fmt_micro_to_date(micro) {
    var milli = micro / 1000;
    var date = new Date(milli).toUTCString();

    return date;
}

