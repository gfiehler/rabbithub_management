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

-export([init/1, process_post/2, content_types_provided/2, is_authorized/2, allowed_methods/2, to_json/2, set_subscription_url/5, content_types_accepted/2, accept_multipart/2]).

-include_lib("rabbitmq_management/include/rabbit_mgmt.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("webmachine/include/webmachine.hrl").
-include("include/rabbithub.hrl").
%%--------------------------------------------------------------------

%-record(rabbithub_subscription, {resource, topic, callback}).

%-record(rabbithub_lease, {subscription, lease_expiry_time_microsec}).

%%--------------------------------------------------------------------

init(_Config) -> {ok, #context{}}.

allowed_methods(ReqData, Context) ->
    {['GET', 'POST'], ReqData, Context}.


content_types_provided(ReqData, Context) ->
   {[{"application/json", to_json}], ReqData, Context}.

content_types_accepted(ReqData, Context) ->
   {[{"application/json", accept_json},
     {"multipart/form-data", accept_multipart}], ReqData, Context}.
        
to_json(ReqData, Context) ->   
    rabbit_mgmt_util:reply(get_hub_leases(ReqData), ReqData, Context).
   

process_post(ReqData, Context) ->
    CT = wrq:get_req_header("Content-type",ReqData),
    case CT of
        "application/json" ->
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
            end;
        Other ->
            case re:run(Other, "multipart/form-data.*") of
                {match, _} ->
                    accept_multipart(ReqData, Context);
                _ ->
                    {{halt, 200}, success(ReqData), Context}
            end
    end.           
            
accept_multipart(ReqData, Context) ->    
    Parts = webmachine_multipart:get_all_parts(
              wrq:req_body(ReqData),
              webmachine_multipart:find_boundary(ReqData)),
    Json = get_part("file", Parts),
    Resp = process_batch(Json, ReqData, Context),
    case Resp of
        {ok, {{"HTTP/1.1", ReturnCode, _State}, _Head, Body}} ->
            BatchResp = wrq:set_resp_header("Content-type", "application/json", wrq:set_resp_body(Body, ReqData)),                
            {{halt, ReturnCode}, BatchResp, Context};
        {error, Reason} ->
            {false, failure(Reason, ReqData), Context};
        Other ->
            {{halt, 400}, failure(Other, ReqData), Context}
    end.        
    
is_authorized(ReqData, Context) ->
    rabbit_mgmt_util:is_authorized_admin(ReqData, Context).

%%--------------------------------------------------------------------
%%strip_crlf(Str) -> lists:append(string:tokens(Str, "\r\n")).

get_hub_leases(ReqData) ->
     {atomic, Leases} =
        mnesia:transaction(fun () ->
                                   mnesia:foldl(fun (Lease, Acc) -> [Lease | Acc] end,
                                                [],
                                                rabbithub_lease)
                           end),
        Data = {struct,  [{subscriptions, [
              [{name, format_name(Lease)},
               {vhost, element(2,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource)},
               {resource_type, element(3,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource)},
               {resource_name, element(4,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource)},
               {topic, list_to_binary((Lease#rabbithub_lease.subscription)#rabbithub_subscription.topic)},
               {callback, list_to_binary((Lease#rabbithub_lease.subscription)#rabbithub_subscription.callback)},
               {lease_expiry_time_microsec, Lease#rabbithub_lease.lease_expiry_time_microsec},
               {lease_seconds, Lease#rabbithub_lease.lease_seconds},
               {ha_mode, Lease#rabbithub_lease.ha_mode},
               {max_tps, Lease#rabbithub_lease.max_tps},
               {status, Lease#rabbithub_lease.status},
               {pseudo_queue, convert_amq_to_binary(Lease#rabbithub_lease.pseudo_queue)},
       	       {outbound_auth, convert_outbound_auth_to_binary(Lease#rabbithub_lease.subscription)},
       	       {contact, convert_contact_to_binary(Lease#rabbithub_lease.subscription)}]
	    || Lease <- Leases]}]},

%%sort
    SortColumn = wrq:get_qs_value("sort", none, ReqData),
    SortDirection = list_to_atom(wrq:get_qs_value("sort_reverse", "none", ReqData)),    
    
    SortFun = case SortColumn of
        "name" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(name, 1, X))} < {element(2, lists:keyfind(name, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(name, 1, X))} > {element(2, lists:keyfind(name, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(name, 1, X))} < {element(2, lists:keyfind(name, 1, Y))} end
            end;
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
        "lease_seconds" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(lease_seconds, 1, X))} < {element(2, lists:keyfind(lease_seconds, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(lease_seconds, 1, X))} > {element(2, lists:keyfind(lease_seconds, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(lease_seconds, 1, X))} < {element(2, lists:keyfind(lease_seconds, 1, Y))} end
            end;
        "ha_mode" -> 
            case SortDirection of
                true  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(ha_mode, 1, X))} < {element(2, lists:keyfind(ha_mode, 1, Y))} end;
                false ->
                    fun(X, Y) -> {element(2, lists:keyfind(ha_mode, 1, X))} > {element(2, lists:keyfind(ha_mode, 1, Y))} end;
                none  -> 
                    fun(X, Y) -> {element(2, lists:keyfind(ha_mode, 1, X))} < {element(2, lists:keyfind(ha_mode, 1, Y))} end
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
            RespList = {struct, [{subscriptions, SortedList}]},
            RespList        
    end,  
    FinalResp.

%%<<AAA/binary, "_", BBB/binary>>,    
format_name(Lease) ->
    RName = element(4,(Lease#rabbithub_lease.subscription)#rabbithub_subscription.resource),
    Topic = list_to_binary((Lease#rabbithub_lease.subscription)#rabbithub_subscription.topic),
    << RName/binary, "_", Topic/binary>>.

convert_amq_to_binary(Amq) ->
    Flat = lists:flatten(io_lib:format("~p", [[Amq]])),
    AmqString = re:replace(re:replace(Flat, "\n", "", [global,{return,list}]), "\s{2,}", " ", [global,{return,list}]),
    AmqBinary = list_to_binary(AmqString),
    AmqBinary.


convert_outbound_auth_to_binary(Sub) ->   
    {atomic, Auth} = mnesia:transaction(fun () -> mnesia:read({rabbithub_outbound_auth, Sub}) end),
    AuthTuple = case Auth of
        undefined -> undefined;
        [] -> 
            undefined;
        AuthVal   -> 
            AuthTuple1 = lists:nth(1, AuthVal),
            [{auth_type, AuthTuple1#rabbithub_outbound_auth.auth_type}, 
                 {auth_config, list_to_binary((AuthTuple1#rabbithub_outbound_auth.auth_config)#rabbithub_outbound_auth_basicauth_config.authorization)}]
    end,     
    AuthTuple.

convert_contact_to_binary(Sub) ->
    {atomic, SubscriberContact} = mnesia:transaction(fun () -> mnesia:read({rabbithub_subscriber_contact_info, Sub}) end),
    ContactTuple = case SubscriberContact of
        undefined -> undefined;
        [] -> undefined;
        SC1   -> 
            SC2 = lists:nth(1, SC1),             
            ContactInfo = element(3, SC2), 
            [{app_name, conditional_list_to_binary(ContactInfo#rabbithub_contact.app_name)}, 
             {contact_name, conditional_list_to_binary(ContactInfo#rabbithub_contact.contact_name)},
             {phone, conditional_list_to_binary(ContactInfo#rabbithub_contact.phone)},
             {email, conditional_list_to_binary(ContactInfo#rabbithub_contact.email)},
             {description, conditional_list_to_binary(ContactInfo#rabbithub_contact.description)}]
    end,     
    ContactTuple.  
    
conditional_list_to_binary(ListVal) ->
    case ListVal of
        [] -> undefined;
        undefined -> undefined;
        [undefined] -> undefined;
        LV -> list_to_binary(LV)
    end.

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
    Queue_Or_Exchange =  proplists:get_value(<<"hub.resource_type">>, Body3),
    Queue_Or_Exchange_Name =  proplists:get_value(<<"hub.resource_name">>, Body3),
    Callback_URI =  proplists:get_value(<<"hub.callback">>, Body3),
    Topic =  proplists:get_value(<<"hub.topic">>, Body3),
    Lease_Seconds =  proplists:get_value(<<"hub.lease_seconds">>, Body3),
    MaxTps = binary_to_integer(proplists:get_value(<<"hub.max_tps">>, Body3)),
    HAMode = proplists:get_value(<<"hub.ha_mode">>, Body3),
    AuthType = proplists:get_value(<<"hub.auth_type">>, Body3),
    AuthConfig = proplists:get_value(<<"hub.auth_config">>, Body3),     
    
    AppName = proplists:get_value(<<"hub.contact.app_name">>, Body3),
    ContactName = proplists:get_value(<<"hub.contact.contact_name">>, Body3),
    Phone = proplists:get_value(<<"hub.contact.phone">>, Body3),
    Email = proplists:get_value(<<"hub.contact.email">>, Body3),
    Description = proplists:get_value(<<"hub.contact.description">>, Body3),
    
    HAMode1 = binary_to_list(HAMode),
    HAMode2 = case HAMode1 of
        [] -> no_ha_mode;
        AnythingElse -> AnythingElse
    end,

    HAModeStr =  case HAMode2 of
        no_ha_mode -> no_ha_mode;
        _OtherModes ->    
            case string:to_integer(HAMode2) of
                {error, _ReasonX} ->                         
                    case string:equal(HAMode2, "all") of
                        true -> atom_to_list(all);
                        false ->  atom_to_list(none)
                    end;
                {Int, _Rest} -> 
                    integer_to_list(Int);
                _ -> atom_to_list(none)
            end
    end,
    VhostStr = case Vhost of
        undefined -> "/";
        VH -> binary_to_list(VH)
    end,
    Queue_Or_ExchangeStr =  binary_to_list(Queue_Or_Exchange),
    Queue_Or_Exchange_NameStr =  binary_to_list(Queue_Or_Exchange_Name),
    CallbackURIStr =  binary_to_list(Callback_URI),
    CallbackURIStrEncoded = edoc_lib:escape_uri(CallbackURIStr),
    TopicStr =  binary_to_list(Topic),
    
    Lease_SecondsStr =  binary_to_list(Lease_Seconds),
    
    MaxTpsStr = case is_integer(MaxTps) of
        true -> lists:flatten(io_lib:format("~p", [MaxTps]));
        false -> "0"
    end,
    %% set other params    
    Method = post,
    URL = set_subscription_url(Server, PortStr, VhostStr, Queue_Or_ExchangeStr, Queue_Or_Exchange_NameStr),

    Authorization = wrq:get_req_header("Authorization",ReqData),
    Header = case Authorization of
        undefined -> [];
        AuthVal -> [{"Authorization", AuthVal}]
    end,
    Type = "application/x-www-form-urlencoded",
    PostBody = case HAModeStr of
        no_ha_mode ->
            "hub.mode=subscribe&hub.callback=" ++ CallbackURIStrEncoded ++ "&hub.topic=" ++ TopicStr ++ 
                "&hub.verify=sync&hub.lease_seconds=" ++ Lease_SecondsStr ++ "&hub.max_tps=" ++ MaxTpsStr;                       
        HAStr -> 
            "hub.mode=subscribe&hub.callback=" ++ CallbackURIStrEncoded ++ "&hub.topic=" ++ TopicStr ++ 
                "&hub.verify=sync&hub.lease_seconds=" ++ Lease_SecondsStr ++ "&hub.max_tps=" ++ MaxTpsStr ++ 
                "&hub.ha_mode=" ++ HAStr
    end,
    PostBody1 = case AuthType of
        undefined -> PostBody;
        [] -> PostBody;
        <<"basic_auth">> -> PostBody ++ "&hub.basic_auth=" ++ binary_to_list(AuthConfig);
        _Other -> PostBody
    end,
    PostBody2 = case AppName of
        undefined -> PostBody1;
        [] -> PostBody1;
        AN -> PostBody1 ++ "&hub.app_name=" ++ binary_to_list(AN)
    end,
    PostBody3 = case ContactName of
        undefined -> PostBody2;
        [] -> PostBody2;
        CN -> PostBody2 ++ "&hub.contact_name=" ++ binary_to_list(CN)
    end,
    PostBody4 = case Phone of
        undefined -> PostBody3;
        [] -> PostBody3;
        Ph -> PostBody3 ++ "&hub.phone=" ++ binary_to_list(Ph)
    end,
    PostBody5 = case Email of
        undefined -> PostBody4;
        [] -> PostBody4;
        Em -> PostBody4 ++ "&hub.email=" ++ binary_to_list(Em)
    end,
    PostBody6 = case Description of
        undefined -> PostBody5;
        [] -> PostBody5;
        De -> PostBody5 ++ "&hub.description=" ++ binary_to_list(De)
    end,
    %% make http request
    HTTPOptions = [],
    Options = [],
    R = httpc:request(Method, {URL, Header, Type, PostBody6}, HTTPOptions, Options),
    R.

set_subscription_url( Server, PortStr, "/", QorX, Name ) ->
    URL =  "http://" ++ Server ++ ":" ++ PortStr ++ "/subscribe/"  ++ QorX ++ "/" ++ Name,
    URL;
set_subscription_url( Server, PortStr, V, QorX, Name ) ->
    EncodedVhost = edoc_lib:escape_uri(V),
    URL = "http://" ++ Server ++ ":" ++ PortStr ++ "/" ++ EncodedVhost ++ "/subscribe/"  ++ QorX ++ "/" ++ Name,
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
    
process_batch(Json, ReqData, _Context) ->
    Host = wrq:get_req_header("Host",ReqData),    
    Server = lists:nth(1, string:tokens(Host, ":")),
    Listener =  application:get_env(rabbithub, listener),
    Port = element(2, lists:nth(1, element(2, Listener))),
    PortStr = lists:flatten(io_lib:format("~p", [Port])),    
    

    %% set other params    
    Method = post,
    URL =  "http://" ++ Server ++ ":" ++ PortStr ++ "/subscriptions",
    Authorization = wrq:get_req_header("Authorization",ReqData),
    Header = case Authorization of
        undefined -> [];
        AuthVal -> [{"Authorization", AuthVal}]
    end,
    Type = "application/json",

    %% make http request
    HTTPOptions = [],
    Options = [],
    
    R = httpc:request(Method, {URL, Header, Type, Json}, HTTPOptions, Options),
    R.

    
get_part(Name, Parts) ->
    %% TODO any reason not to use lists:keyfind instead?
    Filtered = [Value || {N, _Meta, Value} <- Parts, N == Name],
    case Filtered of
        []  -> unknown;
        [F] -> F
    end.    
        

