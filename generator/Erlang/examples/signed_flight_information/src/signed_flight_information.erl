-module(signed_flight_information).
-behaviour(gen_server).

-include("signed_flight_information.hrl").
-include("mavlink.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-define(SECRET_KEY, <<"the very secreted key 32 symbols">>).

start_link() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
  {ok, Serial} = gen_serial:open("/dev/ttyACM0", [{packet, none}, {baud, 115200}, {flow_control, none}]),
  schedule_next_request(),
  {ok, #state{mav_conn=#mavlink_connection{system_id = 255, wire_protocol_version = 2, secret_key = ?SECRET_KEY},
              serial_port = Serial}}.

handle_call(_Request, _From, State) ->
  {reply, {error, unexpected}, State}.

handle_cast({send_mav, Msg}, State) ->
  Conn = State#state.mav_conn,
  {New_Conn, Buf} = mavlink:encode(Conn, Msg),

  gen_serial:send(State#state.serial_port, Buf),

  {noreply, State#state{mav_conn = New_Conn}};

handle_cast({send_mav_signed, Msg}, State) ->
  Conn = State#state.mav_conn,
  {New_Conn, Buf} = mavlink:encode(Conn, Msg, [{sign_info, #sign_info{link_id = 1, timestamp = now}}]),

  gen_serial:send(State#state.serial_port, Buf),

  {noreply, State#state{mav_conn = New_Conn}};

handle_cast(_Request, State) ->
  {noreply, State}.

handle_info(tick, State) ->
  send_command_long_request_flight_information(),
  {noreply, State};

handle_info({serial, _Info, Data}, State) ->
  Serial_Buf = State#state.serial_buf,
  {Msgs, Buf} = mavlink:decode(State#state.mav_conn, <<Serial_Buf/binary, Data/binary>>),

  handle_mav(Msgs),
  {noreply, State#state{serial_buf = Buf}};

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

% % -----------------------------------------------------------------

handle_mav([]) ->
  ok;

handle_mav([{Msg_Info, _Msg} | Other]) when Msg_Info#msg_info.protocol_version /= 2 ->
  io:format("Received v1 message, but v2 is required.\n"),

  handle_mav(Other);

handle_mav([{Msg_Info, Msg} | Other]) ->
  handle_mav_msg(Msg_Info, Msg),

  handle_mav(Other);

handle_mav([bad_sign | Other]) ->
  io:format("Bad sign~n"),
  send_setup_signing(),

  handle_mav(Other);

handle_mav([Error | Other]) ->
  io:format("Bad msg: ~p~n", [Error]),

  handle_mav(Other).

% % handle_mav_msg

handle_mav_msg(Msg_Info, #flight_information{}) when Msg_Info#msg_info.sign_info == undefined ->
  io:format("Received flight_information not signed.\n"),
  send_setup_signing(),
  schedule_next_request();

handle_mav_msg(#msg_info{sign_info = #sign_info{link_id = Link_Id, timestamp = Timestamp}},
               Flight_Information = #flight_information{}) ->
  io:format("Received signed msg: Link_Id: ~p, Timestamp: ~p~n", [Link_Id, Timestamp]),
  io:format("Received signed flight_information: ~p\n", [mavlink:to_proplist(Flight_Information)]),
  send_disable_signing();

handle_mav_msg(1, #command_ack{result=failed}) ->
  io:format("Unsupported flight_information. Update autopilot (Ardupilot 4.7.1+)\n");

handle_mav_msg(_, _) ->
  unhandled.

schedule_next_request() ->
  erlang:send_after(1000, self(), tick).

send_setup_signing() ->
  io:format("Send setup_signing. Enabale signing. ~n"),
  Setup_Signing = #setup_signing{
    target_system = 1,
    target_component = 0,
    secret_key = binary_to_list(?SECRET_KEY),
    initial_timestamp = 1},
  gen_server:cast(self(), {send_mav, Setup_Signing}).

send_disable_signing() ->
  io:format("Send setup_signing(0, 0). Disable signing. ~n"),
  Setup_Signing = #setup_signing{
    target_system = 1,
    target_component = 0,
    secret_key = [],
    initial_timestamp = 0},
  gen_server:cast(self(), {send_mav, Setup_Signing}).

send_command_long_request_flight_information() ->
  io:format("Send command_long_request_flight_information~n"),
  Command_Long = #command_long{
    target_system = 1,
    target_component = 1,
    confirmation = 0,
    command = request_message,
    param1 = 264,
    param2 = 0,
    param3 = 0,
    param4 = 0,
    param5 = 0,
    param6 = 0,
    param7 = 0},
  gen_server:cast(self(), {send_mav_signed, Command_Long}).
