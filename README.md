```
================================================================================
    __    _______    _______ ___________    ___________  ___    _   __
   / /   / ____/ |  / /  _//   |_  __/ |  / /  _/  _  |/ / |  / | / /
  / /   / __/  | | / // / / /| | / /  | | / // / / __  / /| | / |/ / 
 / /___/ /___  | |/ // / / ___ |/ /   | |/ // / / /_/ / / | |/ /|  /  
/_____/_____/  |___/___//_/  |_/_/    |___/___//_/___/_/  |__/_/ |_/   
                                                                        
        Distributed Message Exchange System v0.7.2-beta
        Deep Systems Research Laboratory - Est. 1994
================================================================================
```

## SYSTEM REQUIREMENTS

```
Processor:    Intel 486DX or compatible
Memory:       8 MB RAM minimum (16 MB recommended)
Storage:      10 MB available disk space
OS:           Windows NT 3.51, Windows 95, OS/2 Warp, or Unix-like system
Network:      TCP/IP stack required
Software:     Erlang/OTP R5B or later (tested up to R6B)
Terminal:     VT100, VT220, or compatible terminal emulator
```

**Modern Systems:** Works on contemporary Windows 10/11 with Erlang/OTP 24+

## INSTALLATION

### Method 1: Traditional Installation

```
C:\> cd leviathan
C:\leviathan> erl -compile leviathan
C:\leviathan> erl -s leviathan start
```

### Method 2: Using Modern Erlang Shell

```bash
$ cd leviathan
$ erl
Erlang/OTP 24 [erts-12.0] [source] [64-bit] [smp:8:8]

1> c(leviathan).
{ok,leviathan}
2> leviathan:start().
[INIT] Leviathan Message Exchange System
[INIT] Binding to port 5023...
[OK] System ready
```

## USAGE

### Starting the Server

```erlang
%% Compile and start
c(leviathan).
leviathan:start().
```

You will see the initialization sequence:

```
[KERNEL] Initializing message queues...
[KERNEL] Allocating session table...
[KERNEL] Starting watchdog timer...
```

### Connecting as a User

```erlang
%% In a new Erlang shell or process
leviathan:connect("username", "VT220").
```

You will receive the Message of the Day (MOTD):

```
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              L E V I A T H A N   v0.7.2                   ║
║        Distributed Message Exchange System                ║
║                                                           ║
║   Deep Systems Research Laboratory - Est. 1994           ║
║   "In the depths, knowledge flows..."                    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

### Sending Messages

```erlang
leviathan:broadcast("username", "Hello, world!").
```

### Administrative Commands

```erlang
%% List all connected sessions
leviathan:list_sessions().

%% Disconnect a user
leviathan:disconnect("username").

%% Stop the server
leviathan:stop().
```

## EXAMPLE SESSION

```erlang
%% Terminal 1: Start server
1> c(leviathan).
{ok,leviathan}
2> leviathan:start().
[INIT] Leviathan Message Exchange System
...

%% Terminal 2: User "alice" connects
1> leviathan:connect("alice", "VT100").
ok
*** alice has entered the system

%% Terminal 3: User "bob" connects
1> leviathan:connect("bob", "VT220").
ok
*** bob has entered the system

%% Alice sends message
2> leviathan:broadcast("alice", "Anyone there?").
[1994-03-12 14:23:11] <alice> Anyone there?

%% Bob responds
2> leviathan:broadcast("bob", "Yes, reading you loud and clear").
[1994-03-12 14:23:45] <bob> Yes, reading you loud and clear
```

## FILE STRUCTURE

```
leviathan/
├── leviathan.erl       Primary server module (THIS FILE IS CRITICAL)
├── leviathan.conf      Configuration file (deprecated, optional)
├── leviathan.log       System log (auto-generated at runtime)
├── README.md           This document
└── MANIFEST            File listing (archival purposes)
```

## LOGGING

All system events are logged to `leviathan.log`:

```
[1994-03-12 14:20:33] SYSTEM: Leviathan started
[1994-03-12 14:23:08] CONNECT: alice from VT100
[1994-03-12 14:23:41] CONNECT: bob from VT220
[1994-03-12 14:23:11] MESSAGE: alice: Anyone there?
[1994-03-12 14:24:15] DISCONNECT: alice
```

## KNOWN ISSUES

⚠️ **WARNING:** This is beta software. Use at your own risk.

- Session timeouts may be unreliable on high-latency networks
- Unicode and extended ASCII not supported (7-bit ASCII only)
- Maximum 253 concurrent sessions (hardcoded limitation)
- No encryption - all traffic transmitted in plaintext
- Documentation incomplete due to data loss
- Some features referenced in comments are not implemented
- Hot code reloading not fully tested

## SECURITY CONSIDERATIONS

> **IMPORTANT:** This system was designed for trusted academic networks in  
> the 1990s. It has NO built-in security features:

- No authentication or password protection
- No encryption of any kind
- No rate limiting or abuse prevention
- All messages logged in plaintext
- Suitable for LOCAL NETWORKS ONLY

**DO NOT expose this system to the public internet without implementing  
proper security measures.**

## TECHNICAL NOTES

### Architecture

LEVIATHAN uses the Erlang/OTP gen_server behaviour to implement a fault-
tolerant message exchange. Each user session is monitored by the server 
process. If a client crashes or disconnects unexpectedly, the server 
automatically cleans up the session.
### Process Model

```
┌─────────────────┐
│  leviathan.erl  │  (gen_server)
│   Main Server   │
└────────┬────────┘
         │
    ┌────┴────┬─────────┬─────────┐
    │         │         │         │
┌───▼───┐ ┌──▼────┐ ┌──▼────┐ ┌──▼────┐
│Client │ │Client │ │Client │ │Client │
│  PID  │ │  PID  │ │  PID  │ │  PID  │
└───────┘ └───────┘ └───────┘ └───────┘
```

Each client process is monitored. Server broadcasts to all registered PIDs.

