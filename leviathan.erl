-module(leviathan).
-behaviour(gen_server).

-export([start/0, start_link/1, stop/0]).
-export([connect/2, disconnect/1, broadcast/2, list_sessions/0]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(MOTD, "
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              L E V I A T H A N   v0.7.2                   ║
║        Distributed Message Exchange System                ║
║                                                           ║
║   Deep Systems Research Laboratory - Est. 1994           ║
║   \"In the depths, knowledge flows...\"                    ║
║                                                           ║
║   NOTICE: This is a restricted research system.          ║
║   All communications are logged for analysis.            ║
║   Type .help for available commands                      ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
").

-record(state, {
    sessions = #{}, 
    log_file,
    boot_time,
    msg_count = 0 
}).

-record(session, {
    username,
    pid,
    connected_at,
    terminal_type = "VT100"
}).

start() ->
    io:format("~n[INIT] Leviathan Message Exchange System~n"),
    io:format("[INIT] Binding to port 5023...~n"),
    io:format("[INIT] Loading configuration from leviathan.conf...~n"),
    timer:sleep(200),
    io:format("[OK] System ready~n~n"),
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

start_link(Args) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, Args, []).

stop() ->
    gen_server:call(?SERVER, stop).

%% Connect a user to the system
connect(Username, Terminal) ->
    gen_server:call(?SERVER, {connect, Username, self(), Terminal}).

%% Disconnect current user
disconnect(Username) ->
    gen_server:cast(?SERVER, {disconnect, Username}).

%% Send message to all connected users
broadcast(From, Message) ->
    gen_server:cast(?SERVER, {broadcast, From, Message}).

%% List active sessions (admin command)
list_sessions() ->
    gen_server:call(?SERVER, list_sessions).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    process_flag(trap_exit, true),
    
    %% Simulate old system initialization
    io:format("[KERNEL] Initializing message queues...~n"),
    timer:sleep(100),
    io:format("[KERNEL] Allocating session table...~n"),
    timer:sleep(100),
    io:format("[KERNEL] Starting watchdog timer...~n"),
    timer:sleep(100),
    
    {ok, LogFile} = file:open("leviathan.log", [append]),
    log_event(LogFile, "SYSTEM", "Leviathan started"),
    
    {ok, #state{
        sessions = #{},
        log_file = LogFile,
        boot_time = erlang:timestamp(),
        msg_count = 0
    }}.

handle_call({connect, Username, Pid, Terminal}, _From, State) ->
    Sessions = State#state.sessions,
    
    case maps:is_key(Username, Sessions) of
        true ->
            {reply, {error, "Username already in use"}, State};
        false ->
            Session = #session{
                username = Username,
                pid = Pid,
                connected_at = erlang:timestamp(),
                terminal_type = Terminal
            },
            
            NewSessions = maps:put(Username, Session, Sessions),
            
            Pid ! {system, ?MOTD},
            Pid ! {system, format_timestamp() ++ " - SESSION ESTABLISHED\n"},
            Pid ! {system, "Terminal: " ++ Terminal ++ "\n"},
            Pid ! {system, "Users online: " ++ integer_to_list(maps:size(NewSessions)) ++ "\n\n"},
            
            broadcast_system(NewSessions, Username, 
                "*** " ++ Username ++ " has entered the system"),
            
            log_event(State#state.log_file, "CONNECT", 
                Username ++ " from " ++ Terminal),
            
            monitor(process, Pid),
            
            {reply, ok, State#state{sessions = NewSessions}}
    end;

handle_call(list_sessions, _From, State) ->
    Sessions = State#state.sessions,
    SessionList = maps:fold(fun(User, Session, Acc) ->
        Uptime = calendar:now_to_datetime(Session#session.connected_at),
        [{User, Session#session.terminal_type, Uptime} | Acc]
    end, [], Sessions),
    {reply, SessionList, State};

handle_call(stop, _From, State) ->
    {stop, normal, ok, State}.

handle_cast({disconnect, Username}, State) ->
    Sessions = State#state.sessions,
    
    case maps:get(Username, Sessions, undefined) of
        undefined ->
            {noreply, State};
        _Session ->
            NewSessions = maps:remove(Username, Sessions),
            broadcast_system(NewSessions, Username,
                "*** " ++ Username ++ " has left the system"),
            
            log_event(State#state.log_file, "DISCONNECT", Username),
            
            {noreply, State#state{sessions = NewSessions}}
    end;

handle_cast({broadcast, From, Message}, State) ->
    Sessions = State#state.sessions,
    Timestamp = format_timestamp(),
    FormattedMsg = io_lib:format("[~s] <~s> ~s~n", 
        [Timestamp, From, Message]),
    
    %% Send to all sessions except sender
    maps:foreach(fun(Username, Session) ->
        if Username =/= From ->
            Session#session.pid ! {message, lists:flatten(FormattedMsg)};
        true ->
            ok
        end
    end, Sessions),
    
    log_event(State#state.log_file, "MESSAGE", 
        From ++ ": " ++ Message),
    
    NewCount = State#state.msg_count + 1,
    {noreply, State#state{msg_count = NewCount}}.

handle_info({'DOWN', _Ref, process, Pid, _Reason}, State) ->
    Sessions = State#state.sessions,
    

    Username = find_username_by_pid(Pid, Sessions),
    case Username of
        undefined ->
            {noreply, State};
        User ->
            NewSessions = maps:remove(User, Sessions),
            broadcast_system(NewSessions, User,
                "*** " ++ User ++ " connection lost (timeout)"),
            
            log_event(State#state.log_file, "TIMEOUT", User),
            
            {noreply, State#state{sessions = NewSessions}}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    log_event(State#state.log_file, "SYSTEM", "Leviathan shutting down"),
    file:close(State#state.log_file),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

broadcast_system(Sessions, Exclude, Message) ->
    Timestamp = format_timestamp(),
    FormattedMsg = io_lib:format("[~s] ~s~n", [Timestamp, Message]),
    
    maps:foreach(fun(Username, Session) ->
        if Username =/= Exclude ->
            Session#session.pid ! {system, lists:flatten(FormattedMsg)};
        true ->
            ok
        end
    end, Sessions).

find_username_by_pid(Pid, Sessions) ->
    Result = maps:fold(fun(Username, Session, Acc) ->
        case Session#session.pid of
            Pid -> Username;
            _ -> Acc
        end
    end, undefined, Sessions),
    Result.

format_timestamp() ->
    {{Y, M, D}, {H, Min, S}} = calendar:local_time(),
    io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w:~2..0w", 
        [Y, M, D, H, Min, S]).

log_event(LogFile, Type, Message) ->
    Timestamp = format_timestamp(),
    LogLine = io_lib:format("[~s] ~s: ~s~n", [Timestamp, Type, Message]),
    file:write(LogFile, LogLine)

-ifdef(TEST).

%% Simple test client
test_client(Username) ->
    case leviathan:connect(Username, "VT220") of
        ok ->
            io:format("Connected as ~s~n", [Username]),
            client_loop(Username);
        {error, Reason} ->
            io:format("Connection failed: ~s~n", [Reason])
    end.

client_loop(Username) ->
    receive
        {system, Msg} ->
            io:format("~s", [Msg]),
            client_loop(Username);
        {message, Msg} ->
            io:format("~s", [Msg]),
            client_loop(Username);
        {send, Text} ->
            leviathan:broadcast(Username, Text),
            client_loop(Username);
        quit ->
            leviathan:disconnect(Username),
            io:format("Disconnected~n")
    after 30000 ->
        io:format("~n[IDLE WARNING] No activity detected~n"),
        client_loop(Username)
    end.

-endif.
