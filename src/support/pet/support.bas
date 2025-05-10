10 rem commodore ieee disk diagnostics rom support program
20 rem by piers.rocks
30 ff=0: rem first flag
35 gosub 1000: rem initialize
40 gosub 2000: rem display main screen
50 gosub 3000: rem connect to device
60 gosub 4000: rem main loop
70 end

1000 rem *** initialization ***
1010 print chr$(147): rem clear screen
1020 print "------------- piers.rocks -------------"
1030 print "   ieee disk diagnostics rom support"
1035 print "---------------------------------------"
1040 print
1050 print "enter device id (8-15, default=8):";
1060 input d$
1070 if d$="" then d=8
1075 if d$="" then goto 1100
1080 d=val(d$)
1090 if d<8 or d>15 then print "invalid device id entered"
1095 if d<8 or d>15 then goto 1050
1100 sd=0: rem selected drive (0 or 1)
1110 mt=0: rem motor status (0=off, 1=on)
1130 ch$="": rem channel data
1140 lc$="none": rem last command
1145 if ff=0 then dim av(15): rem only dimension first time
1147 ff=1: rem set first run flag
1150 for i=0 to 15: av(i)=0: next i: rem reset array
1160 da$="": rem data string
1170 return

2000 rem *** display main screen ***
2010 print chr$(147): rem clear screen
2020 print "------------- piers.rocks -------------"
2030 print "   ieee disk diagnostics rom support"
2035 print "---------------------------------------"
2050 print "device:            ";d
2070 print "available channels:";ch$
2080 print "drive:             ";sd
2090 print "motor:              ";
2100 if mt=0 then print "off"; chr$(13);
2110 if mt=1 then print "on"; chr$(13);
2160 print "last command:       ";lc$
2180 print "data:";chr$(13);da$
2200 print "---------------------------------------"
2210 print "commands:"
2220 print "drive:  q-query channel  z-reboot drive"
2225 print "drive:  a-cmd mode       x-flash mode"
2230 print "drive:  0-drive 0        1-drive 1"
2235 print "drive#: m-motor on       n-motor off"
2240 print "drive#: f-head fwd       r-head rev"
2245 print "drive#: b-bump (tr 0)    e-end (tr 34)"
2250 print "global: c-change device  ?-help"
2260 print "---------------------------------------"
2270 print "command:";
2280 return

3000 rem *** connect to device ***
3010 print "connecting to device";d;"..."
3020 open 15,d,15: rem open command channel
3025 rem trap device not present error
3027 if st<>0 then close 15: goto 3200
3030 input#15,er,em$,et,es
3040 if er<>0 then print "error:";er;em$
3045 if er<>0 then close 15
3047 if er<>0 then goto 3200
3050 print "reading available channels..."
3060 open 1,d,0: rem open channel 0 for channel list
3070 ch$=""
3080 for i=0 to 15
3090 av(i)=0: rem initialize channel availability
3100 next i
3110 get#1,b$: if b$="" then b$=chr$(0)
3120 b=asc(b$)
3130 if b>0 and b<=15 then av(b)=1
3135 if b>0 and b<=15 then ch$=ch$+str$(b)+" "
3140 if st=0 then goto 3110: rem continue if no error
3150 close 1
3160 if ch$="" then ch$="none detected"
3165 rem read status channel and display it
3167 da$=""
3170 input#15,en$,em$,et$,es$
3175 da$=en$+","+em$+","+et$+","+es$
3180 print "connected successfully!"
3185 gosub 2000: rem refresh screen with status
3190 return

3200 rem error connecting
3210 print "failed to connect to device";d
3220 print "press any key to retry or 'q' to quit"
3230 get k$: if k$="" goto 3230
3240 if k$="q" then end
3250 goto 1000
3260 return

4000 rem *** main loop ***
4010 get k$: if k$="" goto 4010
4020 print k$
4030 if k$="q" then gosub 5000: goto 4000: rem query channel
4040 if k$="c" then close 15: goto 1000: rem change device
4050 if k$="?" then gosub 6000: goto 4000: rem help
4060 if k$="a" or k$="0" or k$="1" or k$="b" or k$="m" or k$="n" or k$="x" then gosub 7000: goto 4000: rem single commands
4070 if k$="e" then gosub 8000: goto 4000: rem track 34 command
4080 if k$="f" or k$="r" then gosub 9000: goto 4000: rem multiple commands
4090 if k$="z" then gosub 10000: goto 1000: rem reboot drive
4100 goto 4000

5000 rem *** query channel ***
5010 print "enter channel number (0-15):";
5020 input cn$
5030 cn=val(cn$)
5040 if cn<0 or cn>15 then print "invalid channel!": return
5050 lc$="query ch"+str$(cn)
5060 da$=""
5070 print "querying channel";cn;"..."
5080 open 2,d,cn
5085 rem special handling for channel 15
5087 if cn=15 then goto 5300
5090 rem normal channel reading
5100 for i=1 to 20: rem read up to 20 bytes
5110 get#2,b$
5120 if st<>0 then i=20: goto 5150
5130 if b$="" then b$=chr$(0)
5140 da$=da$+str$(asc(b$))+" "
5150 next i
5160 close 2
5170 gosub 2000: rem refresh screen
5180 return

5300 rem special handling for channel 15
5310 da$=""
5320 t$=""
5330 for i=1 to 20
5340 get#2,b$
5350 if st<>0 then i=20: goto 5380
5360 if b$="" then b$=chr$(0)
5370 rem da$=da$+str$(asc(b$))+" "
5375 if asc(b$)>=32 and asc(b$)<127 then t$=t$+b$
5380 next i
5390 close 2
5395 da$=da$+t$
5400 gosub 2000
5410 return

6000 rem *** help screen ***
6010 print chr$(147): rem clear screen
6020 print "------------- piers.rocks -------------"
6030 print "   ieee disk diagnostics rom support"
6035 print "---------------------------------------"
6050 print "help:"
6060 print "a - enter drive command mode"
6070 print "0 - select drive 0"
6080 print "1 - select drive 1"
6110 print "m - motor on"
6120 print "n - motor off"
6150 print "f - move head forward a half track"
6160 print "r - move head reverse a half track"
6090 print "b - bump head against track 0(1)"
6095 print "    moves backwards 140 half tracks"
6100 print "e - move to track 34(35)"
6105 print "    moves forward 68 half tracks"
6170 print "x - enter drive flash mode"
6180 print "z - reboot drive"
6190 print "q - query channel"
6200 print "c - change device"
6210 print "? - this help screen"
6220 print "---------------------------------------"
6230 print "press any key to return"
6240 get k$: if k$="" goto 6240
6250 gosub 2000: rem redraw main screen
6260 return

7000 rem *** single command ***
7010 lc$=k$
7020 if k$="0" or k$="1" then sd=val(k$)
7030 if k$="m" then mt=1
7040 if k$="n" then mt=0
7070 print "sending command:";k$
7080 print#15,k$
7090 da$="command "+k$+" sent"
7100 gosub 2000: rem refresh screen
7110 return

8000 rem *** track 34 command ***
8010 print "warning: moving to track 34(35) may cause"
8020 print "a reverse head bump if not at track 0"
8030 print "are you sure? (y/n)";
8040 get c$: if c$="" goto 8040
8050 if c$<>"y" then return
8060 lc$="e"
8070 print "sending command: e"
8080 print#15,"e"
8090 da$="command e sent"
8100 gosub 2000: rem refresh screen
8110 return

9000 rem *** multiple commands ***
9010 cm$=k$
9020 print "how many times (1-99):";
9030 input ct$
9040 ct=val(ct$)
9050 if ct<1 or ct>99 then print "invalid count!": return
9060 lc$=cm$+"*"+str$(ct)
9070 print "sending command:";cm$;" (";ct;" times)"
9080 for i=1 to ct
9090 print#15,cm$
9100 rem 50ms delay using loop
9110 for dl=1 to 100: next dl
9120 next i
9130 da$="command "+cm$+" sent "+str$(ct)+" times"
9140 gosub 2000: rem refresh screen
9150 return

10000 rem *** reboot drive ***
10010 lc$="z"
10020 print "rebooting drive..."
10030 print#15,"z"
10040 close 15
10050 da$="drive rebooted"
10060 return