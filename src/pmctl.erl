%%% ===================================================================
%%% @author V. Glenn Tarcea <gtarcea@umich.edu>
%%%
%%% @doc CLI for controlling the process monitor.
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
-module(pmctl).

%% API main for script
-export([main/1]).

-record(cargs,
        {
            sgroup :: string(),
            jgroup :: string(),
            commands :: [atom()]
        }).

%%%===================================================================
%%% Main
%%%===================================================================
main([]) -> usage();
main(Args) ->
    setup(),
    CArgs = parse_results(getopt:parse(opt_spec(), Args)),
    execute_commands(CArgs),
    ok.

%%%===================================================================
%%% Local
%%%===================================================================

setup() ->
    net_kernel:start(['pmcli@127.0.0.1', longnames]),
    auth:set_cookie('process_monitor').

usage({error, {Error, Description}}) ->
    io:format(standard_error, "~nError: ~p ~p~n~n", [Error, Description]),
    usage();
usage(Message) ->
    io:format(standard_error, "~nError: ~s~n~n", [Message]),
    usage().

usage() ->
    getopt:usage(opt_spec(), "pmctl", "<command>" ),
    Commands =
            " Commands: stopsgroup, stopjgroup~n" ++
            "           startsgroup, startjgroup~n" ++
            "           restartsgroup, restartjgroup~n" ++
            "           listsgroups, listjgroups, listchildren~n",
    io:format(standard_error, Commands, []),
    halt().

opt_spec() ->
    [
        {sgroup, $s, "sgroup", string, "The sgroup to use."},
        {jgroup, $j, "jgroup", string, "The jgroup to use."}
    ].

parse_results({error, {_Error, _Description}} = ErrorValue) ->
    usage(ErrorValue);
parse_results({ok, {Values, Commands}}) ->
    SGroup = retrieve_key(sgroup, Values),
    JGroup = retrieve_key(jgroup, Values),
    #cargs{sgroup = to_atom(SGroup), jgroup = to_atom(JGroup), commands = Commands}.

retrieve_key(Key, Values) ->
    key_value(lists:keyfind(Key, 1, Values)).

key_value({_Key, Value}) -> Value;
key_value(false) -> false.

to_atom(Value) when is_atom(Value) -> Value;
to_atom(Value) when is_list(Value) -> list_to_atom(Value).

execute_commands(#cargs{sgroup = SGroup, jgroup = JGroup, commands = Commands}) ->
    lists:foreach(
            fun ("listsgroups") ->
                    listsgroups();
                ("listjgroups") ->
                    run_sgroup_command(fun listjgroups/1, SGroup);
                ("listchildren") ->
                    run_sgroup_command(fun listchildren/1, SGroup);
                ("stopsgroup") ->
                    run_sgroup_command(fun stopsgroup/1, SGroup);
                ("stopjgroup") ->
                    run_sjgroups_command(fun stopjgroup/2, SGroup, JGroup);
                ("startsgroup") ->
                    run_sgroup_command(fun startsgroup/1, SGroup);
                ("startjgroup") ->
                    run_sjgroups_command(fun startjgroup/2, SGroup, JGroup);
                ("restartsgroup") ->
                    run_sgroup_command(fun restartsgroup/1, SGroup);
                ("restartjgroup") ->
                    run_sjgroups_command(fun restartjgroup/2, SGroup, JGroup);
                (Command) ->
                    usage("Unknown Command: " ++ Command)
            end, Commands).

%% ======================================================================================
%% Note: The run_sgroup_command and run_sjgroups_command have a 1 second timer:sleep()
%% call in them. The reason for this is the cast returns immediately, and then the cli
%% exits. This interaction appears to be causing the message not to be sent. The sleep
%% fixed this issue.
%% ======================================================================================

run_sgroup_command(_Command, false) ->
    usage("No SGroup specified");
run_sgroup_command(Fun, SGroup) ->
    Fun(SGroup),
    timer:sleep(1000).

run_sjgroups_command(_Command, SGroup, JGroup) when SGroup =:= false; JGroup =:= false ->
    usage("An SGroup and a JGroup must be specified");
run_sjgroups_command(Fun, SGroup, JGroup) ->
    Fun(SGroup, JGroup),
    timer:sleep(1000).

%% ======================================================================================
%% ^^^^^^^^^^^^^^^^^^^^^^^^^^^ **** See Comment Above **** ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
%% ======================================================================================

listsgroups() ->
    lists:foreach(
        fun(SGroup) ->
            io:format("~p~n", [SGroup])
        end, process_monitor:list_sgroups()).

listjgroups(SGroup) ->
    case process_monitor:list_sgroup_job_groups(SGroup) of
        {error, badgroup} -> usage("Unknown SGroup: " ++ SGroup);
        Groups -> lists:foreach(fun(Group) -> io:format("~p~n", [Group]) end, Groups)
    end.

listchildren(SGroup) ->
    case process_monitor:list_sgroup_children(SGroup) of
        {error, badgroup} ->
            usage("Unknown SGroup: " ++ SGroup);
        Children ->
            lists:foreach(
                    fun([{server, Server}, {command, Command}, {os_pid, Pid}]) ->
                        io:format("~p, ~p, ~p~n", [Server, Command, Pid])
                    end, Children)
    end.

stopsgroup(SGroup) ->
    io:format("Stopping SGroup ~p~n", [SGroup]),
    process_monitor:stop_sgroup(SGroup).

stopjgroup(SGroup, JGroup) ->
    io:format("Stopping JGroup ~p for SGroup ~p ~n", [JGroup, SGroup]),
    process_monitor:stop_sgroup_job_group(SGroup, JGroup).

startsgroup(SGroup) ->
    io:format("Starting SGroup ~p~n", [SGroup]),
    process_monitor:start_sgroup(SGroup).

startjgroup(SGroup, JGroup) ->
    io:format("Starting JGroup ~p for SGroup ~p~n", [JGroup, SGroup]),
    process_monitor:start_sgroup_job_group(SGroup, JGroup).

restartjgroup(SGroup, JGroup) ->
    io:format("Restarting JGroup ~p for SGroup ~p ~n", [JGroup, SGroup]),
    process_monitor:restart_sgroup_job_group(SGroup, JGroup).

restartsgroup(SGroup) ->
    io:format("Restarting SGroup: ~s~n", [SGroup]),
    process_monitor:restart_sgroup(SGroup).

