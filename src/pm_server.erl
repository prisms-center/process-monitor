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
-module(pm_server).

%% API
-export([start_link/1, stop/1]).

-behaviour(gen_server).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {port}).

start_link(ExternalProcess) ->
    io:format("pm_server:start_link ~p~n", [ExternalProcess]),
    gen_server:start_link(?MODULE, [ExternalProcess], []).

stop(Pid) ->
    gen_server:cast(Pid, stop).

%% ===================================================================
%% gen_server callbacks
%% ===================================================================

%% @private
init([ExternalProcess]) ->
    process_flag(trap_exit, true),
    gen_server:cast(self(), {start_process, ExternalProcess}),
    {ok, #state{}}.

%% @private
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

%% @private
handle_cast({start_process, ExternalProcess}, _State) ->
    Port = open_port({spawn, ExternalProcess}, []),
    {noreply, #state{port = Port}};
handle_cast(stop, State) ->
    {stop, normal, State}.

%% @private
handle_info({'EXIT', _Port, Reason}, State) ->
    {stop, {port_terminated, Reason}, State};
handle_info(_Info, State) ->
    {noreply, State}.

%% @private
%% Do something when the process terminates
terminate({port_terminated, _Reason}, _State) ->
    ok;
terminate(_Reason, #state{port = Port}) ->
    io:format("Calling port_close ~p~n", [Port]),
    port_close(Port),
    ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.