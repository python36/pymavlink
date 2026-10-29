%%%-------------------------------------------------------------------
%% @doc signed_flight_information public API
%% @end
%%%-------------------------------------------------------------------

-module(signed_flight_information_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    signed_flight_information_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
