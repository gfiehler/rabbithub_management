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

-module(rabbithub_management_wm_consumers).

-export([init/1, to_json/2, content_types_provided/2, is_authorized/2]).

-include_lib("rabbitmq_management/include/rabbit_mgmt.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("webmachine/include/webmachine.hrl").
-include("include/rabbithub.hrl").
%%--------------------------------------------------------------------
%-record(rabbithub_subscription, {resource, topic, callback}).

%-record(consumer, {subscription, node}).

%-record(rabbithub_subscription_pid, {consumer, pid, expiry_timer}).



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
            rabbit_mgmt_util:reply(get_hub_consumers_for_sub(ReqData, binary_to_list(Callback), binary_to_list(Topic), Vhost, ResourceName, ResourceType), ReqData, Context);
        true ->
            rabbit_mgmt_util:reply(get_hub_consumers(ReqData), ReqData, Context)
    end.

is_authorized(ReqData, Context) ->
    rabbit_mgmt_util:is_authorized_admin(ReqData, Context).

%%--------------------------------------------------------------------

get_hub_consumers(ReqData) ->
     {atomic, Consumers} =
        mnesia:transaction(fun () ->
                                   mnesia:foldl(fun (Consumer, Acc) -> [Consumer | Acc] end,
                                                [],
                                                rabbithub_subscription_pid)
                           end), 
	    
    Data = {struct,
            [{consumers, [
            [{vhost, element(2, ((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.resource)},
                {resource_type, element(3, ((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.resource)},
                {resource_name, element(4, ((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.resource)},
                {topic, list_to_binary(((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.topic)},
                {callback, list_to_binary(((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.callback)},
                {pid, list_to_binary(pid_to_list(Consumer#rabbithub_subscription_pid.pid))},
                {node, (Consumer#rabbithub_subscription_pid.consumer)#consumer.node},
                {status, get_pid_status(Consumer#rabbithub_subscription_pid.pid)}]
               || Consumer <- Consumers]}]},
	                             
%%    Data.

%%sort
    SortColumn = wrq:get_qs_value("sort", none, ReqData),
    SortDirection = list_to_atom(wrq:get_qs_value("sort_reverse", "none", ReqData)),    
    
    
    SortFun = case SortColumn of
        "vhost" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(vhost, 1, X))} < {element(2, lists:keyfind(vhost, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(vhost, 1, X))} > {element(2, lists:keyfind(vhost, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(vhost, 1, X))} < {element(2, lists:keyfind(vhost, 1, Y))} end
            end;
        "resource_type" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(resource_type, 1, X))} < {element(2, lists:keyfind(resource_type, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(resource_type, 1, X))} > {element(2, lists:keyfind(resource_type, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(resource_type, 1, X))} < {element(2, lists:keyfind(resource_type, 1, Y))} end
            end;
        "resource_name" ->             
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(resource_name, 1, X))} < {element(2, lists:keyfind(resource_name, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(resource_name, 1, X))} > {element(2, lists:keyfind(resource_name, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(resource_name, 1, X))} < {element(2, lists:keyfind(resource_name, 1, Y))} end
            end;
        "topic" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(topic, 1, X))} < {element(2, lists:keyfind(topic, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(topic, 1, X))} > {element(2, lists:keyfind(topic, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(topic, 1, X))} < {element(2, lists:keyfind(topic, 1, Y))} end
            end;
        "callback" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(callback, 1, X))} < {element(2, lists:keyfind(callback, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(callback, 1, X))} > {element(2, lists:keyfind(callback, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(callback, 1, X))} < {element(2, lists:keyfind(callback, 1, Y))} end
            end;
        "node" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(node, 1, X))} < {element(2, lists:keyfind(node, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(node, 1, X))} > {element(2, lists:keyfind(node, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(node, 1, X))} < {element(2, lists:keyfind(node, 1, Y))} end
            end;
        "status" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(status, 1, X))} < {element(2, lists:keyfind(status, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(status, 1, X))} > {element(2, lists:keyfind(status, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(status, 1, X))} < {element(2, lists:keyfind(status, 1, Y))} end
            end;
        none ->
            do_nothing;
        _Other ->
            do_nothing
        end,
        
        
            
    FinalResp = case SortFun of 
        do_nothing ->            
            Data;
        _A ->
            DataList = element(2, lists:nth(1, element(2, Data))),
            
            SortedList = lists:sort(SortFun, DataList),
            RespList = {struct, [{consumers, SortedList}]},
            
            RespList        
    end,  
    FinalResp.
    
get_hub_consumers_for_sub(_ReqData, Callback, Topic, Vhost, ResourceName, ResourceType) ->
%% -record(consumer, {subscription, node}).
%% -record(rabbithub_subscription, {resource, topic, callback}).
%% -record(rabbithub_subscription_pid, {consumer, pid, expiry_timer}).

    ResourceTypeAtom = case ResourceType of
                            <<"queue">> -> queue;
                            <<"exchange">> -> exchange
                        end,
    
    Resource =  rabbithub:r(Vhost, ResourceTypeAtom, binary_to_list(ResourceName)),

    Sub = #rabbithub_subscription{resource = Resource,
                                    topic = Topic,
                                    callback = Callback},
    Con = #consumer{subscription = Sub, node = '_'},
    
    WildPattern = mnesia:table_info(rabbithub_subscription_pid, wild_pattern),
    Pattern = WildPattern#rabbithub_subscription_pid{consumer = Con},
    F = fun() -> mnesia:match_object(Pattern) end,   
    {atomic, Results} = mnesia:transaction(F),
    
    Data = {struct,
            [{consumers, [
            [{vhost, element(2, ((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.resource)},
                {resource_type, element(3, ((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.resource)},
                {resource_name, element(4, ((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.resource)},
                {topic, list_to_binary(((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.topic)},
                {callback, list_to_binary(((Consumer#rabbithub_subscription_pid.consumer)#consumer.subscription)#rabbithub_subscription.callback)},
                {pid, list_to_binary(pid_to_list(Consumer#rabbithub_subscription_pid.pid))},
                {node, (Consumer#rabbithub_subscription_pid.consumer)#consumer.node},
                {status, get_pid_status(Consumer#rabbithub_subscription_pid.pid)}]
               || Consumer <- Results]}]},
    Data.        
%%-------------------------------------
get_pid_status(Pid) ->
    PidStatus = rpc:call(node(Pid), erlang,
                         is_process_alive, [Pid]),
    Status = case PidStatus of
               true -> running;
               false -> not_running;
               {badrpc, nodedown} -> not_running
             end,
    Status.

