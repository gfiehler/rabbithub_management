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
-include("include/rabbithub.hrl").

%%--------------------------------------------------------------------

%%-record(resource, {virtual_host, kind, name}).

%-record(rabbithub_subscription, {resource, topic, callback}).

%-record(rabbithub_lease, {subscription, lease_expiry_time_microsec}).

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
    %% if hub.mode = subscribe (activate or resubscribe)
    %%      delete then subscribe
    %% else if hub.mode = unsubscribe (deactivate)
    %%      unsubscribe
    HubMode =  get_hubmode(ReqData),    
    case HubMode of
        <<"subscribe">> ->            
            TempPS =  post_subscription_qs(ReqData),                                   
            case TempPS of                                                                       
                {ok, {{"HTTP/1.1", ReturnCodePS, _StatePS}, _HeadPS, BodyPS}} ->
                    case ReturnCodePS >= 200 of   
                        true ->                                 
                            case ReturnCodePS < 300 of
                                true  -> {{halt, ReturnCodePS}, success(ReqData), Context};
                                false -> {{halt, ReturnCodePS}, failure(BodyPS, ReqData), Context}
                            end;    
                        false -> 
                            {{halt, ReturnCodePS}, failure(BodyPS, ReqData), Context}
                    end;
                {error, ReasonPS} ->
                    {false, failure(ReasonPS, ReqData), Context};
                OtherPS -> 
                    {false, failure(OtherPS, ReqData), Context} 
            end;                        
        <<"unsubscribe">> ->               
            case unsubscribe_lease(ReqData) of
                {ok, {{"HTTP/1.1", ReturnCodeUL, _StateUL}, _HeadUL, BodyUL}} ->
                    case ReturnCodeUL >= 200 of
                        true ->
                            case ReturnCodeUL < 300 of
                                true  ->                        
                                    {{halt, ReturnCodeUL}, success(ReqData), Context};
                                false -> 
                                    {{halt, ReturnCodeUL}, failure(BodyUL, ReqData), Context}
                            end;    
                        false -> {{halt, ReturnCodeUL}, failure(BodyUL, ReqData), Context}
                    end;
                {error, ReasonUL} ->
                    {false, failure(ReasonUL, ReqData), Context}
            end
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

get_hubmode(ReqData) ->
    Body1 = wrq:req_body(ReqData),     
    [{Body2, _}] = mochiweb_util:parse_qs(Body1),
    {struct, Body3} = mochijson2:decode(Body2),
    proplists:get_value(<<"hub_mode">>, Body3).
    

      
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
                          {lease_expiry_time_microsec, Lease#rabbithub_lease.lease_expiry_time_microsec},
                          {lease_seconds, Lease#rabbithub_lease.lease_seconds},
                          {ha_mode, Lease#rabbithub_lease.ha_mode},
                          {status, Lease#rabbithub_lease.status}]]}]},
                    Data
            end 
    end),
    Data.
%%%%% delete

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
    Authorization = wrq:get_req_header("Authorization",ReqData),
    %% Header format[{"connection", "close"}] [{"Authorization","Basic Z3JlZ2c6Z3JlZ2c="}].
    Header = case Authorization of
        undefined -> [];
        AuthVal -> [{"Authorization", AuthVal}]
    end,
    
    TypeCode = case ResourceType of
                "queue" -> "q";
                "exchange" -> "x";
                _ -> "q"
               end,
        
    %% set other params   
    %% fix to accept exchanges need to fix get subscribers to inlcude resourcetypeatom 
    Method = delete,
    QueryParams = "hub.mode=unsubscribe&hub.callback=" ++ Callback ++ "&hub.topic=" ++ Topic,
    URL = set_delete_url(Server, PortStr, Vhost, TypeCode, Resource, QueryParams),
    
    Type = "application/x-www-form-urlencoded",             
    %% make http request
    HTTPOptions = [],
    Options = [],
    R = httpc:request(Method, {URL, Header, Type, ""}, HTTPOptions, Options),           
    R.

set_delete_url( Server, PortStr, "/", TypeCode, Resource, QueryParams ) ->
    URL = "http://" ++ Server ++ ":" ++ PortStr ++ "/subscribe/"  ++ TypeCode ++ "/" ++ Resource  ++ "?" ++ QueryParams,
    URL;
set_delete_url( Server, PortStr, V, TypeCode, Resource, QueryParams ) ->
    URL = "http://" ++ Server ++ ":" ++ PortStr ++ "/" ++ V ++ "/subscribe/"  ++ TypeCode ++ "/" ++ Resource ++ "?" ++ QueryParams,
    URL.


%%%%% end delete

unsubscribe_lease(ReqData) -> 
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
    Authorization = wrq:get_req_header("Authorization",ReqData),
    %% Header format[{"connection", "close"}] [{"Authorization","Basic Z3JlZ2c6Z3JlZ2c="}].
    Header = case Authorization of
        undefined -> [];
        AuthVal -> [{"Authorization", AuthVal}]
    end,
    
    TypeCode = case ResourceType of
                "queue" -> "q";
                "exchange" -> "x";
                _ -> "q"
               end,
        
    %% set other params   
    %% fix to accept exchanges need to fix get subscribers to inlcude resourcetypeatom 
    Method = post,
    URL = set_unsubscribe_url(Server, PortStr, Vhost, TypeCode, Resource),
    Type = "application/x-www-form-urlencoded",
    Body = "hub.mode=unsubscribe&hub.callback=" ++ Callback ++ "&hub.topic=" ++ Topic ++ "&hub.verify=sync&hub.lease_seconds=1",
    %% make http request
    HTTPOptions = [],
    Options = [],
    R = httpc:request(Method, {URL, Header, Type, Body}, HTTPOptions, Options),
    R.

set_unsubscribe_url( Server, PortStr, "/", TypeCode, Resource ) ->
    URL = "http://" ++ Server ++ ":" ++ PortStr ++ "/subscribe/"  ++ TypeCode ++ "/" ++ Resource,
    URL;
set_unsubscribe_url( Server, PortStr, V, TypeCode, Resource ) ->
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
    
    %%get body params  
    Body1 = wrq:req_body(ReqData),     
    [{Body2, _}] = mochiweb_util:parse_qs(Body1),
    {struct, Body3} = mochijson2:decode(Body2),
    Lease_Exp_Micro = binary_to_integer(proplists:get_value(<<"lease">>, Body3)),    
    LeaseSec = binary_to_integer(proplists:get_value(<<"lease_sec">>, Body3)),
    LS2 = case LeaseSec of
        none ->             
            Lease_Micro_Less_ST = list_to_integer(Lease_Exp_Micro) - system_time(),
            Lease_Div = Lease_Micro_Less_ST div 1000000,                    
            case Lease_Div of        
                {error, Reason} -> {error, Reason};
                {Int, _Rest} -> Int;
                LSD -> LSD
            end;
        LS -> LS
    end,
    
    Resp = case LS2 of
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
            Authorization = wrq:get_req_header("Authorization",ReqData),
            %% Header format[{"connection", "close"}] [{"Authorization","Basic Z3JlZ2c6ZJlZ2c="}].
            Header = case Authorization of
                undefined -> [];
                AuthVal -> [{"Authorization", AuthVal}]
            end,
    
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
    
