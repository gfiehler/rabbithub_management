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

-module(rabbithub_management_extension).

-behaviour(rabbit_mgmt_extension).

-export([dispatcher/0, web_ui/0]).

dispatcher() -> [{["hub", "consumers"],  rabbithub_management_wm_consumers, []},
                 {["hub", "consumers", vhost, type, resource, topic, callback],  rabbithub_management_wm_consumers, []},                 
                 {["hub", "errors"],  rabbithub_management_wm_errors, []},
                 {["hub", "errors", vhost, type, resource, topic, callback],  rabbithub_management_wm_errors, []},
                 {["hub", "environment"],  rabbithub_management_wm_environment, []},
                 {["hub", "subscriptions"],  rabbithub_management_wm_subscriptions, []},
                 {["hub", "subscriptions", vhost, type, resource, topic, callback],  rabbithub_management_wm_subscription, []},
                 {["hub", "subscriptions", "batch"],  rabbithub_management_wm_subscriptions, []}].

web_ui()     -> [{javascript, <<"rabbithub.js">>}].

