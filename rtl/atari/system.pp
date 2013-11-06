{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Carl Eric Codere
    member of the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
unit system;

{--------------------------------------------------------------------}
{ LEFT TO DO:                                                        }
{--------------------------------------------------------------------}
{ o SBrk                                                             }
{ o Implement truncate                                               }
{ o Implement paramstr(0)                                            }
{--------------------------------------------------------------------}


  interface

    {$I systemh.inc}

{Platform specific information}
const
 LineEnding = #10;
 LFNSupport = true;
 CtrlZMarksEOF: boolean = false; (* #26 not considered as end of file *)
 DirectorySeparator = '/';
 DriveSeparator = ':';
 ExtensionSeparator = '.';
 PathSeparator = ';';
 AllowDirectorySeparators : set of char = ['\','/'];
 AllowDriveSeparators : set of char = [':'];
 FileNameCaseSensitive = false;
 FileNameCasePreserving = false;
 maxExitCode = 255;
 MaxPathLen = 255;
 AllFilesMask = '*';

 sLineBreak: string [1] = LineEnding;
    { used for single computations }
    const BIAS4 = $7f-1;

const
  UnusedHandle    = $ffff;
  StdInputHandle  = 0;
  StdOutputHandle = 1;
  StdErrorHandle  = $ffff;

    {$if defined(CPUARM) or defined(CPUM68K) or defined(CPUSPARC) or defined(CPUMIPS)}

    {$define fpc_softfpu_interface}
    {$i softfpu.pp}
    {$undef fpc_softfpu_interface}

    {$endif defined(CPUARM) or defined(CPUM68K) or defined(CPUSPARC) or defined(CPUMIPS)}


  implementation

    {$if defined(CPUARM) or defined(CPUM68K) or defined(CPUSPARC) or defined(CPUMIPS)}

    {$define fpc_softfpu_implementation}
    {$i softfpu.pp}
    {$undef fpc_softfpu_implementation}

    { we get these functions and types from the softfpu code }
    {$define FPC_SYSTEM_HAS_float64}
    {$define FPC_SYSTEM_HAS_float32}
    {$define FPC_SYSTEM_HAS_flag}
    {$define FPC_SYSTEM_HAS_extractFloat64Frac0}
    {$define FPC_SYSTEM_HAS_extractFloat64Frac1}
    {$define FPC_SYSTEM_HAS_extractFloat64Exp}
    {$define FPC_SYSTEM_HAS_extractFloat64Sign}
    {$define FPC_SYSTEM_HAS_ExtractFloat32Frac}
    {$define FPC_SYSTEM_HAS_extractFloat32Exp}
    {$define FPC_SYSTEM_HAS_extractFloat32Sign}

    {$endif defined(CPUARM) or defined(CPUM68K) or defined(CPUSPARC) or defined(CPUMIPS)}

    {$I system.inc}
    {$I lowmath.inc}


function GetProcessID:SizeUInt;
begin
{$WARNING To be checked by platform maintainer}
 GetProcessID := 1;
end;

    const
      argc : longint = 0;


    var
      errno : integer;

{$S-}
    procedure Stack_Check; assembler;
    { Check for local variable allocation }
    { On Entry -> d0 : size of local stack we are trying to allocate }
         asm
          XDEF STACKCHECK
           move.l  sp,d1            { get value of stack pointer            }
           sub.l   d0,d1            {  sp - stack_size                      }
           sub.l   #2048,d1
           cmp.l   __BREAK,d1
           bgt     @st1nosweat
           move.l  #202,d0
           jsr     HALT_ERROR
         @st1nosweat:
         end;


    Procedure Error2InOut;
    Begin
     if (errno <= -2) and (errno >= -11) then
       InOutRes:=150-errno  { 150+errno }
     else
      Begin
        case errno of
          -32 : InOutRes:=1;
          -33 : InOutRes:=2;
          -34 : InOutRes:=3;
          -35 : InOutRes:=4;
          -36 : InOutRes:=5;
          -37 : InOutRes:=8;
          -39 : InOutRes:=8;
          -40 : InOutRes:=9;
          -46 : InOutRes:=15;
          -67..-64 : InOutRes:=153;
          -15 : InOutRes:=151;
          -13 : InOutRes:=150;
        else
           InOutres := word(errno);
         end;
     end;
     errno:=0;
    end;



    procedure halt(errnum : byte);

      begin
         do_exit;
         flush(stderr);
         asm
            clr.l   d0
            move.b  errnum,d0
            move.w  d0,-(sp)
            move.w  #$4c,-(sp)
            trap    #1
         end;
      end;


      function args : pointer; assembler;
      asm
         move.l __ARGS,d0
      end;




   Function GetParamCount(const p: pchar): longint;
   var
    i: word;
    count: word;
   Begin
    i:=0;
    count:=0;
    while p[count] <> #0 do
     Begin
       if (p[count] <> ' ') and (p[count] <> #9) and (p[count] <> #0) then
       Begin
          i:=i+1;
          while (p[count] <> ' ') and (p[count] <> #9) and (p[count] <> #0) do
           count:=count+1;
       end;
       if p[count] = #0 then break;
       count:=count+1;
     end;
     GetParamCount:=longint(i);
   end;


   Function GetParam(index: word; const p : pchar): string;
   { On Entry: index = string index to correct parameter  }
   { On exit:  = correct character index into pchar array }
   { Returns correct index to command line argument }
   var
    count: word;
    localindex: word;
    l: byte;
    temp: string;
   Begin
     temp:='';
     count := 0;
     { first index is one }
     localindex := 1;
     l:=0;
     While p[count] <> #0 do
       Begin
         if (p[count] <> ' ') and (p[count] <> #9) then
           Begin
             if localindex = index then
              Begin
               while (p[count] <> #0) and (p[count] <> ' ') and (p[count] <> #9) and (l < 256) do
                Begin
                  temp:=temp+p[count];
                  l:=l+1;
                  count:=count+1;
                end;
                temp[0]:=char(l);
                GetParam:=temp;
                exit;
              end;
             { Point to next argument in list }
             while (p[count] <> #0) and (p[count] <> ' ') and (p[count] <> #9) do
               Begin
                 count:=count+1;
               end;
             localindex:=localindex+1;
           end;
         if p[count] = #0 then break;
         count:=count+1;
       end;
     GetParam:=temp;
   end;


    function paramstr(l : longint) : string;
      var
       p : pchar;
       s1 : string;
      begin
         if l = 0 then
         Begin
           s1 := '';
         end
         else
         if (l>0) and (l<=paramcount) then
           begin
             p:=args;
             paramstr:=GetParam(word(l),p);
           end
         else paramstr:='';
      end;

      function paramcount : longint;
      Begin
        paramcount := argc;
      end;




    procedure randomize;

      var
         hl : longint;

      begin
         asm
           movem.l d2/d3/a2/a3, -(sp)     { save OS registers }
           move.w #17,-(sp)
           trap   #14         { call xbios - random number }
           add.l  #2,sp
           movem.l (sp)+,d2/d3/a2/a3
           move.l d0,hl       { result in d0 }
         end;
         randseed:=hl;
      end;

function getheapstart:pointer;assembler;
asm
        lea.l   HEAP,a0
        move.l  a0,d0
end;


function getheapsize:longint;assembler;
asm
       move.l   HEAP_SIZE,d0
end ['D0'];

  { This routine is used to grow the heap.  }
  { But here we do a trick, we say that the }
  { heap cannot be regrown!                 }
  function sbrk( size: longint): pointer;
  { on exit nil = if fails.               }
  Begin
   sbrk:=nil;
  end;

{$I heap.inc}

{*****************************************************************************
                           UnTyped File Handling
*****************************************************************************}

{$i file.inc}

{*****************************************************************************
                           Typed File Handling
*****************************************************************************}

{$i typefile.inc}

{*****************************************************************************
                           Text File Handling
*****************************************************************************}

{$i text.inc}

{*****************************************************************************
                           Directory Handling
*****************************************************************************}

procedure DosDir(func:byte;const s:string);
var
  buffer : array[0..255] of char;
  c : word;
begin
  move(s[1],buffer,length(s));
  buffer[length(s)]:=#0;
  DoDirSeparators(pchar(@buffer));
  c:=word(func);
  asm
        move.l  d2,d6      { save d2 }
        movem.l d3/a2/a3,-(sp)
        pea     buffer
        move.w  c,-(sp)
        trap    #1
        add.l   #6,sp
        move.l  d6,d2       { restore d2 }
        movem.l (sp)+,d3/a2/a3
        tst.w   d0
        beq     @dosdirend
        move.w  d0,errno
     @dosdirend:
  end;
  if errno <> 0 then
     Error2InOut;
end;


procedure mkdir(const s : string);[IOCheck];
begin
  If InOutRes <> 0 then exit;
  DosDir($39,s);
end;


procedure rmdir(const s : string);[IOCheck];
begin
  If InOutRes <> 0 then exit;
  DosDir($3a,s);
end;


procedure chdir(const s : string);[IOCheck];
begin
  If InOutRes <> 0 then exit;
  DosDir($3b,s);
end;


function GetDirIO (DriveNr: byte; var Dir: ShortString): word;
                                               [public, alias: 'FPC_GETDIRIO'];
var
  temp : array[0..255] of char;
  i    : longint;
  j: byte;
  drv: word;
begin
  GetDirIO := 0;
  drv:=word(drivenr);
  asm
            move.l  d2,d6      { save d2 }
            movem.l d3/a2/a3,-(sp)

            { Get dir from drivenr : 0=default, 1=A etc... }
            move.w drv,-(sp)

            { put (previously saved) offset in si }
{            move.l temp,-(sp)}
             pea   temp

            { call attos function 47H : Get dir }
            move.w #$47,-(sp)

            { make the call }
            trap   #1
            add.l  #8,sp

            move.l d6,d2         { restore d2 }
            movem.l (sp)+,d3/a2/a3
  end;
  { conversion to pascal string }
  i:=0;
  while (temp[i]<>#0) do
   begin
     if temp[i] in AllowDirectorySeparators then
       temp[i]:=DirectorySeparator;
     dir[i+3]:=temp[i];
     inc(i);
   end;
  dir[2]:=':';
  dir[3]:='\';
  dir[0]:=char(i+2);
{ upcase the string (FPC Pascal function) }
  dir:=upcase(dir);
  if drivenr<>0 then   { Drive was supplied. We know it }
   dir[1]:=chr(65+drivenr-1)
  else
   begin
      asm
        move.l  d2,d6      { save d2 }
        movem.l d3/a2/a3,-(sp)
        move.w #$19,-(sp)
        trap   #1
        add.l  #2,sp
        move.w d0,drv
        move.l d6,d2        { restore d2 }
        movem.l (sp)+,d3/a2/a3
     end;
     dir[1]:=chr(byte(drv)+ord('A'));
   end;
end;

procedure GetDir (DriveNr: byte; var Dir: ShortString);

begin
  InOutRes := GetDirIO (DriveNr, Dir);
end;


{*****************************************************************************
                         System Dependent Exit code
*****************************************************************************}
Procedure system_exit;
begin
end;

{*****************************************************************************
                         SystemUnit Initialization
*****************************************************************************}

function CheckInitialStkLen (StkLen: SizeUInt): SizeUInt;
begin
  CheckInitialStkLen := StkLen;
end;

begin
  StackLength := CheckInitialStkLen (InitialStkLen);
{ Initialize ExitProc }
  ExitProc:=Nil;
{ Setup heap }
  InitHeap;
{$ifdef HASWIDESTRING}
  InitUnicodeStringManager;
{$endif HASWIDESTRING}
{ Setup stdin, stdout and stderr }
  OpenStdIO(Input,fmInput,StdInputHandle);
  OpenStdIO(Output,fmOutput,StdOutputHandle);
  OpenStdIO(StdOut,fmOutput,StdOutputHandle);
  OpenStdIO(StdErr,fmOutput,StdErrorHandle);
{ Reset IO Error }
  InOutRes:=0;
(* This should be changed to a real value during *)
(* thread driver initialization if appropriate.  *)
  ThreadID := 1;
  errno := 0;
{ Setup command line arguments }
  argc:=GetParamCount(args);
  InitVariantManager;
end.