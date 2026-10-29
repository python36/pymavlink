signed_flight_information
=====

The examples use the MAVLink library over a serial port (ttyACM0) at a baud rate of 115,200, which requires the MAVLink v2 protocol and message signing.

Run
-----
    $ cd mavlink
    $ python3 -m pymavlink.tools.mavgen --lang=Erlang --wire-protocol=2.0 --output=$MAVERLPATH message_definitions/v1.0/ardupilotmega.xml
    $ cd pymavlink/generator/Erlang/examples/signed_flight_information
    $ cp $MAVERLPATH/mavlink.erl src
    $ cp $MAVERLPATH/mavlink.hrl src
    $ rebar3 shell
