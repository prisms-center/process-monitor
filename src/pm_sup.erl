
%%% ===================================================================
%%% @author V. Glenn Tarcea <gtarcea@umich.edu>
%%%
%%% @doc Server for monitoring jobs.
%%%
%%% @copyright Copyright (c) 2013, Regents of the University of Michigan.
%%% All rights reserved.
%%%
%%% Permission to use, copy, modify, and/or distribute this software for any
%%% purpose with or without fee is hereby granted, provided that the above
%%% copyright notice and this permission notice appear in all copies.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
%%% ===================================================================
-module(pm_sup).

-behaviour(supervisor).

%% API
-export([start_link/2]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(Name, Arg), {Name, {pm_server, start_link, [Name,Arg]}, permanent, 5000, worker, [pm_server]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link(SupervisorName, {_JobGroupName, RestartSpec, Jobs}) ->
    supervisor:start_link({local, SupervisorName}, ?MODULE, [RestartSpec, Jobs]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([RestartSpec, Jobs]) ->
    Children = construct_supervised_children(Jobs),
    {ok, { RestartSpec, Children} }.

%% ===================================================================
%% Local functions
%% ===================================================================

%% Creates the list of supervisors that need to be managed. Each
%% supervisor will need to have a unique name. The name is based
%% off of the supervisor group name given in the config file.
construct_supervised_children(Jobs) ->
    lists:flatten(lists:map(
                fun({JobName, Count, Command}) ->
                    [?CHILD(create_name(JobName, Counter), Command) || Counter <- lists:seq(1,Count)]
                end, Jobs)).

%% Create a unique supervisor name based on the supervisor group. As documented we assume
%% that the supervisor groups are unique. If this isn't true then the app will fail to
%% start because of duplicate names.
create_name(JobName, Counter) ->
    list_to_atom("pm_server_" ++ atom_to_list(JobName) ++ "_" ++ integer_to_list(Counter)).

