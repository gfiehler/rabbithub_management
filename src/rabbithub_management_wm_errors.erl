%%  The contents of this file are subject to the Mozilla Public License
%%  Version 1.1 (the "License"); you may not use this file except in
%%  compliance with the License. You may obtain a copy of the License
%%  at http://www.mozilla.org/MPL/
%%
%%  Software distributed under the License is distributed on an "AS IS"
%%  basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%%  the License for the specific language governing rights and
%%  limitations under the License.
%%
%%  The Original Code is RabbitMQ.
%%
%%  The Initial Developer of the Original Code is VMware, Inc.
%%  Copyright (c) 2007-2012 VMware, Inc.  All rights reserved.
%%

-module(rabbithub_management_wm_errors).

-export([init/1, to_json/2, content_types_provided/2, is_authorized/2]).

-include_lib("rabbitmq_management/include/rabbit_mgmt.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("webmachine/include/webmachine.hrl").
-include("include/rabbithub.hrl").
%%--------------------------------------------------------------------
%-record(rabbithub_subscription, {resource, topic, callback}).

%-record(rabbithub_subscription_err, {subscription, error_count, first_error_time_microsec, last_error_time_microsec}).

%%--------------------------------------------------------------------

init(_Config) -> {ok, #context{}}.

content_types_provided(ReqData, Context) ->
   {[{"application/json", to_json}], ReqData, Context}.

to_json(ReqData, Context) ->
    Vhost = rabbit_mgmt_util:id(vhost, ReqData),
    ResourceType = rabbit_mgmt_util:id(type, ReqData),
    ResourceName = rabbit_mgmt_util:id(resource, ReqData),    
    Topic = rabbit_mgmt_util:id(topic, ReqData),
    Callback = rabbit_mgmt_util:id(callback, ReqData),
    case lists:member(none, [Callback, Topic, Vhost, ResourceName, ResourceType]) of
        false ->
            rabbit_mgmt_util:reply(get_hub_errors_for_sub(ReqData, binary_to_list(Callback), binary_to_list(Topic), Vhost, ResourceName, ResourceType), ReqData, Context);
        true ->
            rabbit_mgmt_util:reply(get_hub_errors(), ReqData, Context)
    end.   


is_authorized(ReqData, Context) ->
    rabbit_mgmt_util:is_authorized_admin(ReqData, Context).

%%--------------------------------------------------------------------

get_hub_errors() ->
     {atomic, Errors} =
        mnesia:transaction(fun () ->
                                   mnesia:foldl(fun (Error, Acc) -> [Error | Acc] end,
                                                [],
                                                rabbithub_subscription_err)
                           end),
    Data = {struct,  [{errors, [
              [{vhost, element(2,(Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.resource)},              	              
               {resource_type, element(3,(Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.resource)},
               {resource_name, element(4,(Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.resource)}, 
               {topic, list_to_binary((Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.topic)},
               {callback, list_to_binary((Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.callback)},
               {error_count, Error#rabbithub_subscription_err.error_count},
               {first_error_time_microsec, Error#rabbithub_subscription_err.first_error_time_microsec},
               {last_error_time_microsec, Error#rabbithub_subscription_err.last_error_time_microsec},
               {last_error_msg, Error#rabbithub_subscription_err.last_error_msg}]
	    || Error <- Errors]}]},                            
    Data.
    
get_hub_errors_for_sub(_ReqData, Callback, Topic, Vhost, ResourceName, ResourceType) ->
%% -record(consumer, {subscription, node}).
%% -record(rabbithub_subscription, {resource, topic, callback}).
%% -record(rabbithub_subscription_err, {subscription, error_count, first_error_time_microsec, last_error_time_microsec, last_error_msg}).

    ResourceTypeAtom = case ResourceType of
                            <<"queue">> -> queue;
                            <<"exchange">> -> exchange
                        end,
    
    Resource =  rabbithub:r(Vhost, ResourceTypeAtom, binary_to_list(ResourceName)),

    Sub = #rabbithub_subscription{resource = Resource,
                                    topic = Topic,
                                    callback = Callback},
    
    WildPattern = mnesia:table_info(rabbithub_subscription_err, wild_pattern),
    Pattern = WildPattern#rabbithub_subscription_err{subscription = Sub},
    F = fun() -> mnesia:match_object(Pattern) end,   
    {atomic, Results} = mnesia:transaction(F),
    
    Data = {struct,  [{errors, [
              [{vhost, element(2,(Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.resource)},              	              
               {resource_type, element(3,(Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.resource)},
               {resource_name, element(4,(Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.resource)}, 
               {topic, list_to_binary((Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.topic)},
               {callback, list_to_binary((Error#rabbithub_subscription_err.subscription)#rabbithub_subscription.callback)},
               {error_count, Error#rabbithub_subscription_err.error_count},
               {first_error_time_microsec, Error#rabbithub_subscription_err.first_error_time_microsec},
               {last_error_time_microsec, Error#rabbithub_subscription_err.last_error_time_microsec},
               {last_error_msg, Error#rabbithub_subscription_err.last_error_msg}]
	    || Error <- Results]}]},                            
    Data.        
    
