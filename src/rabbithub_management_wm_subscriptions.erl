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

-module(rabbithub_management_wm_subscriptions).

-export([init/1, process_post/2, content_types_provided/2, is_authorized/2, allowed_methods/2, to_json/2, set_subscription_url/5]).

-include_lib("rabbitmq_management/include/rabbit_mgmt.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("webmachine/include/webmachine.hrl").

%%--------------------------------------------------------------------

-record(rabbithub_subscription, {resource, topic, callback}).

-record(rabbithub_lease, {subscription, lease_expiry_time_microsec}).

%%--------------------------------------------------------------------

init(_Config) -> {ok, #context{}}.

allowed_methods(ReqData, Context) ->
    {['GET', 'POST'], ReqData, Context}.


content_types_provided(ReqData, Context) ->
   {[{"application/json", to_json}], ReqData, Context}.
   
to_json(ReqData, Context) ->   
    rabbit_mgmt_util:reply(get_hub_leases(ReqData), ReqData, Context).
   

process_post(ReqData, Context) ->       
    case post_subscription(ReqData) of
        {ok, {{"HTTP/1.1", ReturnCode, _State}, _Head, Body}} ->
            case string:to_integer(ReturnCode) >= 200 of
                true ->
                    case string:to_integer(ReturnCode) < 300 of
                        true  -> {{halt, ReturnCode}, success(ReqData), Context};
                        false -> {{halt, ReturnCode}, failure(Body, ReqData), Context}
                    end;    
                false -> {{halt, ReturnCode}, failure(Body, ReqData), Context}
            end;
        {error, Reason} ->
            {false, failure(Reason, ReqData), Context}
    end.                   

is_authorized(ReqData, Context) ->
    rabbit_mgmt_util:is_authorized_admin(ReqData, Context).

%%--------------------------------------------------------------------


get_hub_leases(ReqData) ->
     {atomic, Leases} =
        mnesia:transaction(fun () ->
                                   mnesia:foldl(fun (Lease, Acc) -> [Lease | Acc] end,
                                                [],
                                                rabbithub_lease)
                           end),
        Data = {struct,  [{subscriptions, [
              [{vhost, element(2,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource)},              	              
               {resource_type, element(3,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource)},
               {resource_name, element(4,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource)}, 	     
               {topic, list_to_binary((Lease#rabbithub_lease.subscription)#rabbithub_subscription.topic)},
               {callback, list_to_binary((Lease#rabbithub_lease.subscription)#rabbithub_subscription.callback)},
               {lease_expiry_time_microsec, Lease#rabbithub_lease.lease_expiry_time_microsec}]
        || Lease <- Leases]}]},
        
        

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
        "lease_expiry_time_microsec" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(lease_expiry_time_microsec, 1, X))} < {element(2, lists:keyfind(lease_expiry_time_microsec, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(lease_expiry_time_microsec, 1, X))} > {element(2, lists:keyfind(lease_expiry_time_microsec, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(lease_expiry_time_microsec, 1, X))} < {element(2, lists:keyfind(lease_expiry_time_microsec, 1, Y))} end
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
            RespList = {struct, [{subscriptions, SortedList}]},
            RespList        
    end,  
    FinalResp.
    



post_subscription(ReqData) ->
    Host = wrq:get_req_header("Host",ReqData),
    Server = lists:nth(1, string:tokens(Host, ":")),
    Listener =  application:get_env(rabbithub, listener),
    Port = element(2, lists:nth(1, element(2, Listener))),
    PortStr = lists:flatten(io_lib:format("~p", [Port])),    
    
    Body1 = wrq:req_body(ReqData),     
    [{Body2, _}] = mochiweb_util:parse_qs(Body1),
    {struct, Body3} = mochijson2:decode(Body2),
    Vhost = proplists:get_value(<<"vhost">>, Body3),   
    Queue_Or_Exchange =  proplists:get_value(<<"queue-or-exchange">>, Body3),
    Queue_Or_Exchange_Name =  proplists:get_value(<<"q-or-x-name">>, Body3),
    Callback_URI =  proplists:get_value(<<"callback-uri">>, Body3),
    Topic =  proplists:get_value(<<"topic">>, Body3),
    Lease_Seconds =  proplists:get_value(<<"lease-seconds">>, Body3),
    VhostStr = binary_to_list(Vhost),
    Queue_Or_ExchangeStr =  binary_to_list(Queue_Or_Exchange),
    Queue_Or_Exchange_NameStr =  binary_to_list(Queue_Or_Exchange_Name),
    Callback_URIStr =  binary_to_list(Callback_URI),
    TopicStr =  binary_to_list(Topic),
    Lease_SecondsStr =  binary_to_list(Lease_Seconds),


    %% set other params    
    Method = post,
    URL = set_subscription_url(Server, PortStr, VhostStr, Queue_Or_ExchangeStr, Queue_Or_Exchange_NameStr),

    Header = [],
    Type = "application/x-www-form-urlencoded",
    Body = "hub.mode=subscribe&hub.callback=" ++ Callback_URIStr ++ "&hub.topic=" ++ TopicStr ++ "&hub.verify=sync&hub.lease_seconds=" ++ Lease_SecondsStr,

    %% make http request
    HTTPOptions = [],
    Options = [],
    R = httpc:request(Method, {URL, Header, Type, Body}, HTTPOptions, Options),
    R.

set_subscription_url( Server, PortStr, "/", QorX, Name ) ->
    URL =  "http://" ++ Server ++ ":" ++ PortStr ++ "/subscribe/"  ++ QorX ++ "/" ++ Name,
    URL;
set_subscription_url( Server, PortStr, V, QorX, Name ) ->
    URL = "http://" ++ Server ++ ":" ++ PortStr ++ "/" ++ V ++ "/subscribe/"  ++ QorX ++ "/" ++ Name,
    URL.
      
%%responses
success(ReqData) ->
    success("true", ReqData).

success(BooleanStr, ReqData) ->
    build_response([{success, BooleanStr}], ReqData).


failure(Msg, ReqData) ->
    build_response([{error, Msg}], ReqData).

build_response(Status, ReqData)->
    wrq:set_resp_header(
      "Content-type", "text/plain",
      response_body(Status, ReqData)
    ).

response_body(Status, ReqData) ->
    wrq:set_resp_body(
      mochijson:encode(
        {struct, Status}
      ), ReqData
    ).    

