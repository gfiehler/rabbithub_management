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

%%--------------------------------------------------------------------
-record(rabbithub_subscription, {resource, topic, callback}).

-record(rabbithub_subscription_err, {subscription, error_count, first_error_time_microsec, last_error_time_microsec}).

%%--------------------------------------------------------------------

init(_Config) -> {ok, #context{}}.

content_types_provided(ReqData, Context) ->
   {[{"application/json", to_json}], ReqData, Context}.

to_json(ReqData, Context) ->   
    rabbit_mgmt_util:reply(get_hub_errors(), ReqData, Context).

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
               {last_error_time_microsec, Error#rabbithub_subscription_err.last_error_time_microsec}]
	    || Error <- Errors]}]},                            
    Data.
