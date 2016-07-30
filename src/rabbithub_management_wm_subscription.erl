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

-module(rabbithub_management_wm_subscription).

-export([init/1, to_json/2, content_types_provided/2, is_authorized/2, allowed_methods/2, content_types_accepted/2, accept_content/2, delete_resource/2 ]).

-include_lib("rabbitmq_management/include/rabbit_mgmt.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("webmachine/include/webmachine.hrl").


%%--------------------------------------------------------------------

%%-record(resource, {virtual_host, kind, name}).

-record(rabbithub_subscription, {resource, topic, callback}).

-record(rabbithub_lease, {subscription, lease_expiry_time_microsec}).

%%--------------------------------------------------------------------

init(_Config) -> {ok, #context{}}.

content_types_provided(ReqData, Context) ->
   {[{"application/json", to_json}], ReqData, Context}.

content_types_accepted(ReqData, Context) ->
   {[{"application/json", accept_content}], ReqData, Context}.
   
allowed_methods(ReqData, Context) ->
    {['GET', 'DELETE', 'PUT'], ReqData, Context}.
   

to_json(ReqData, Context) ->
    rabbit_mgmt_util:reply(get_hub_lease(ReqData), ReqData, Context).


accept_content(ReqData, Context) ->
    %% unsubscribe (delete), then subscribe
    case delete_lease(ReqData) of
        {ok, {{"HTTP/1.1", ReturnCode, _State}, _Head, Body}} ->
            case ReturnCode >= 200 of
                true ->
                    case ReturnCode < 300 of
                        %%% if successful delete, then subscribe
                        true  ->                        
                            case post_subscription_qs(ReqData) of
                                {ok, {{"HTTP/1.1", ReturnCode, _State}, _Head, Body}} ->
                                    case ReturnCode >= 200 of                                    
                                        true ->                                 
                                            case ReturnCode < 300 of
                                                true  -> {{halt, ReturnCode}, success(ReqData), Context};
                                                false -> {{halt, ReturnCode}, failure(Body, ReqData), Context}
                                            end;    
                                        false -> 
                                            {{halt, ReturnCode}, failure(Body, ReqData), Context}
                                    end;
                                {error, Reason} ->
                                    {false, failure(Reason, ReqData), Context}
                            end;                        
                        %%%failed delete do not subscribe
                        false -> 
                            {{halt, ReturnCode}, failure(Body, ReqData), Context}
                    end;    
                false -> 
                    {{halt, ReturnCode}, failure(Body, ReqData), Context}
                    
            end;
        {error, Reason} ->
            {false, failure(Reason, ReqData), Context}
    end. 
    
    
    
    
delete_resource(ReqData, Context) ->
    case delete_lease(ReqData) of
        {ok, {{"HTTP/1.1", ReturnCode, _State}, _Head, Body}} ->
            case ReturnCode >= 200 of
                true ->
                    case ReturnCode < 300 of
                        true  ->                        
                            {{halt, ReturnCode}, success(ReqData), Context};
                        false -> 
                            {{halt, ReturnCode}, failure(Body, ReqData), Context}
                    end;    
                false -> {{halt, ReturnCode}, failure(Body, ReqData), Context}
            end;
        {error, Reason} ->
            {false, failure(Reason, ReqData), Context}
    end. 


is_authorized(ReqData, Context) ->
    rabbit_mgmt_util:is_authorized_admin(ReqData, Context).

%%--------------------------------------------------------------------
      
get_hub_lease(ReqData) ->
    Vhost = rabbit_mgmt_util:id(vhost, ReqData),
    ResourceType = rabbit_mgmt_util:id(type, ReqData),
    ResourceTypeAtom = case ResourceType of
                            <<"queue">> -> queue;
                            <<"exchange">> -> exchange
                        end,
    ResourcName = rabbit_mgmt_util:id(resource, ReqData),    
    Topic = binary_to_list(rabbit_mgmt_util:id(topic, ReqData)),
    Callback = binary_to_list(rabbit_mgmt_util:id(callback, ReqData)),
    Resource =  rabbithub:r(Vhost, ResourceTypeAtom, binary_to_list(ResourcName)),

    Sub = #rabbithub_subscription{resource = Resource,
                                    topic = Topic,
                                    callback = Callback},
             
    {atomic, Data} =
    mnesia:transaction(
        fun () ->
            case  mnesia:read(rabbithub_lease, Sub) of
                [] ->                                  
                    Data = {},
                    Data;
                [Lease] ->
                    Data = {struct,  [{subscriptions, 
                        [[{vhost, element(2,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource)},              	              
                          {resource_type, element(3,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource)},
                          {resource_name, element(4,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource)},
                          {topic, list_to_binary((Lease#rabbithub_lease.subscription)#rabbithub_subscription.topic)},
                          {callback, list_to_binary((Lease#rabbithub_lease.subscription)#rabbithub_subscription.callback)},
                          {lease_expiry_time_microsec, Lease#rabbithub_lease.lease_expiry_time_microsec}]]}]},
                    Data
            end 
    end),
    Data.

delete_lease(ReqData) -> 
    Host = wrq:get_req_header("Host",ReqData),
    Server = lists:nth(1, string:tokens(Host, ":")),
    Listener =  application:get_env(rabbithub, listener),
    Port = element(2, lists:nth(1, element(2, Listener))),
    PortStr = lists:flatten(io_lib:format("~p", [Port])),    
    Vhost = binary_to_list(rabbit_mgmt_util:id(vhost, ReqData)),
    ResourceType = rabbit_mgmt_util:id(type, ReqData),         
    Resource = binary_to_list(rabbit_mgmt_util:id(resource, ReqData)),
    Topic = binary_to_list(rabbit_mgmt_util:id(topic, ReqData)),
    Callback = binary_to_list(rabbit_mgmt_util:id(callback, ReqData)),
    
    TypeCode = case ResourceType of
                "queue" -> "q";
                "exchange" -> "x";
                _ -> "q"
               end,
        
    %% set other params   
    %% fix to accept exchanges need to fix get subscribers to inlcude resourcetypeatom 
    Method = post,
    URL = set_delete_url(Server, PortStr, Vhost, TypeCode, Resource),
    Header = [],
    Type = "application/x-www-form-urlencoded",
    Body = "hub.mode=unsubscribe&hub.callback=" ++ Callback ++ "&hub.topic=" ++ Topic ++ "&hub.verify=sync&hub.lease_seconds=1",
    %% make http request
    HTTPOptions = [],
    Options = [],
    R = httpc:request(Method, {URL, Header, Type, Body}, HTTPOptions, Options),
    R.

set_delete_url( Server, PortStr, "/", TypeCode, Resource ) ->
    URL = "http://" ++ Server ++ ":" ++ PortStr ++ "/subscribe/"  ++ TypeCode ++ "/" ++ Resource,
    URL;
set_delete_url( Server, PortStr, V, TypeCode, Resource ) ->
    URL = "http://" ++ Server ++ ":" ++ PortStr ++ "/" ++ V ++ "/subscribe/"  ++ TypeCode ++ "/" ++ Resource,
    URL.
    
%% Subscribe
post_subscription_qs(ReqData) ->
    Host = wrq:get_req_header("Host",ReqData),
    Server = lists:nth(1, string:tokens(Host, ":")),
    Listener =  application:get_env(rabbithub, listener),
    Port = element(2, lists:nth(1, element(2, Listener))),
    PortStr = lists:flatten(io_lib:format("~p", [Port])),    
    Vhost = binary_to_list(rabbit_mgmt_util:id(vhost, ReqData)),
    ResourceType = rabbit_mgmt_util:id(type, ReqData),         
    Resource = binary_to_list(rabbit_mgmt_util:id(resource, ReqData)),
    Topic = binary_to_list(rabbit_mgmt_util:id(topic, ReqData)),
    Callback = binary_to_list(rabbit_mgmt_util:id(callback, ReqData)),
    Lease_Micro = binary_to_list(rabbit_mgmt_util:id(lease, ReqData)),
    
    Lease_Micro_Less_ST = list_to_integer(Lease_Micro) - system_time(),
    Lease_Div = Lease_Micro_Less_ST div 1000000,    
        
    Lease_Sec = case Lease_Div of        
        {error, Reason} -> {error, Reason};
        {Int, _Rest} -> Int;
        LS -> LS
    end,
    
    Resp = case Lease_Sec of
        {error, Reason2} -> 
            {error, Reason2};
        Lease ->    
            TypeCode = case ResourceType of
                        "queue" -> "q";
                        "exchange" -> "x";
                        _ -> "q"
                       end,
                
            %% set other params   
            Method = post,
            URL = rabbithub_management_wm_subscriptions:set_subscription_url(Server, PortStr, Vhost, TypeCode, Resource),
            Header = [],
            Type = "application/x-www-form-urlencoded",
            LeaseStr = lists:flatten(io_lib:format("~p", [Lease])),            
            Body = "hub.mode=subscribe&hub.callback=" ++ Callback ++ "&hub.topic=" ++ Topic ++ "&hub.verify=sync&hub.lease_seconds=" ++ LeaseStr,

            %% make http request
            HTTPOptions = [],
            Options = [],

            R = httpc:request(Method, {URL, Header, Type, Body}, HTTPOptions, Options),

            R        
    end,
    Resp.

%% utils
system_time() ->
    LocalTime = calendar:local_time(),
    TimeStamp = to_timestamp(LocalTime),
    TimeStamp.
    
to_timestamp({{Year,Month,Day},{Hours,Minutes,Seconds}}) ->
    (calendar:datetime_to_gregorian_seconds({{Year,Month,Day},{Hours,Minutes,Seconds}}) - 62167219200)*1000000.
    
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
    
