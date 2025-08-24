{******************************************************************************}
{                                                                              }
{  VSoft.Base64                                                                }
{  Copyright (c) 2024 Vincent Parrett & Contributors                           }
{  https://github.com/VSoftTechnologies/VSoft.Base64                           }
{                                                                              }
{******************************************************************************}
{                                                                              }
{  Licensed under the Apache License, Version 2.0 (the "License");             }
{  you may not use this file except in compliance with the License.            }
{  You may obtain a copy of the License at                                     }
{                                                                              }
{      http://www.apache.org/licenses/LICENSE-2.0                              }
{                                                                              }
{  Unless required by applicable law or agreed to in writing, software         }
{  distributed under the License is distributed on an "AS IS" BASIS,           }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    }
{  See the License for the specific language governing permissions and         }
{  limitations under the License.                                              }
{                                                                              }
{******************************************************************************}

{

This is a simple Delphi polyfill library that enables you to use Base64 Encode/Decode for versions
of Delphi that do not include System.NetEncoding (earlier than XE7).

<  XE 7 - uses own Base64 code.
>= XE 7 - calls through to TNetEncoding.Base64

If you are only supporting XE7 or later just use System.NetEncoding

}
// Parts of this code were modified from
//https://github.com/paolo-rossi/delphi-jose-jwt
//which appears to be a variation of the base64 implementation in Soap.EncdDecd.

unit VSoft.Base64;

interface

uses
  System.Classes,
  System.SysUtils;

type
 TBase64 = class
  public
    class function Encode(const bytes : TBytes; includeLineBreaks : boolean = true; charsPerLine : integer = 76; const lineBreak : string = #13#10): string; overload;
    class function Encode(const stream : TStream; includeLineBreaks : boolean = true; charsPerLine : integer = 76; const lineBreak : string = #13#10): string; overload;

    class function Decode(const base64String : string): TBytes; overload;
    class procedure Decode(const base64String : string; const stream : TStream); overload;
  end;

implementation


{$IFDEF CONDITIONALEXPRESSIONS}  //Started being defined with D2009
  {$IF CompilerVersion > 24.0 } //XE4 or later
    {$LEGACYIFEND ON} //Delphi switched back to ENDIF but we need IFEND for backwards compatibility.
  {$IFEND}
  {$IF CompilerVersion < 22.0} // Before XE2
    {$ERROR 'Unsupported Compiler'}
   {$IFEND}
{$ELSE}
  {$DEFINE UNSUPPORTED_COMPILER_VERSION}
{$ENDIF}

{$IF CompilerVersion >= 28}  // Delphi XE7
  {$DEFINE HAS_NET_ENCODING} // System.NetEncoding unit introduced
{$IFEND}
uses
 System.Math
{$IFDEF HAS_NET_ENCODING}
 ,System.NetEncoding
{$ENDIF}
;


{$IFNDEF HAS_NET_ENCODING}


type
  TPacket = packed record
    case Integer of
      0: (b0, b1, b2, b3: Byte);
      1: (i: Integer);
      2: (a: array[0..3] of Byte);
  end;


{$REGION 'ENCODE'}

function Base64Encode(const bytes : TBytes; includeLineBreaks : boolean; charsPerLine : integer; const lineBreak : string): string; overload;
const
  // Base64 character lookup table
  Base64Chars: array[0..63] of Char = (
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
    'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
    'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
    'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
  );
var
  InputLen, OutputLen: Integer;
  SrcPtr, EndPtr: PByte;
  CharCount: Integer;
  b1, b2, b3: Byte;
  i: Integer;
  BytesInGroup: Integer;
begin
  InputLen := Length(bytes);
  if InputLen = 0 then
  begin
    Result := '';
    Exit;
  end;

  // Calculate output size (4 chars for every 3 bytes, plus line breaks)
  OutputLen := ((InputLen + 2) div 3) * 4;
  if includeLineBreaks and (charsPerLine > 0) then
    OutputLen := OutputLen + ((OutputLen div charsPerLine) * Length(lineBreak));

  SetLength(Result, OutputLen);
  CharCount := 0;
  i := 1; // String index (1-based)

  SrcPtr := PByte(bytes);
  EndPtr := SrcPtr + InputLen;

  while SrcPtr < EndPtr do
  begin
    // Clear bytes
    b1 := 0;
    b2 := 0;
    b3 := 0;
    BytesInGroup := 0;

    // Get up to 3 bytes and count how many we actually have
    if SrcPtr < EndPtr then
    begin
      b1 := SrcPtr^;
      Inc(SrcPtr);
      Inc(BytesInGroup);
    end;

    if SrcPtr < EndPtr then
    begin
      b2 := SrcPtr^;
      Inc(SrcPtr);
      Inc(BytesInGroup);
    end;

    if SrcPtr < EndPtr then
    begin
      b3 := SrcPtr^;
      Inc(SrcPtr);
      Inc(BytesInGroup);
    end;

    // Encode to 4 Base64 characters using array lookup
    Result[i] := Base64Chars[b1 shr 2];
    Inc(i);
    Result[i] := Base64Chars[((b1 and $03) shl 4) or (b2 shr 4)];
    Inc(i);

    // Third character: depends on having at least 2 bytes
    if BytesInGroup >= 2 then
      Result[i] := Base64Chars[((b2 and $0F) shl 2) or (b3 shr 6)]
    else
      Result[i] := '=';
    Inc(i);

    // Fourth character: depends on having 3 bytes
    if BytesInGroup >= 3 then
      Result[i] := Base64Chars[b3 and $3F]
    else
      Result[i] := '=';
    Inc(i);

    Inc(CharCount, 4);

    // Add line break if needed
    if includeLineBreaks and (charsPerLine > 0) and (CharCount >= charsPerLine) then
    begin
      if SrcPtr < EndPtr then // Not at the end
      begin
        // Insert line break
        Move(lineBreak[1], Result[i], Length(lineBreak));
        Inc(i, Length(lineBreak));
        CharCount := 0;
      end;
    end;
  end;

  // Trim to actual length used
  SetLength(Result, i - 1);
end;

function Base64Encode(const stream: TStream; includeLineBreaks : boolean; charsPerLine : integer; const lineBreak : string): string; overload;
const
  BufferSize = 3072; // Multiple of 3 for efficient processing
var
  Buffer: TBytes;
  BytesRead: Integer;
  OriginalPosition: Int64;
  PartialResult: string;
  CharCount: Integer;
  i: Integer;
  TempResult: string;
begin
  Result := '';
  CharCount := 0;

  if not Assigned(stream) then
    Exit;

  // Save original position
  OriginalPosition := stream.Position;

  try
    SetLength(Buffer, BufferSize);

    repeat
      BytesRead := stream.Read(Buffer[0], BufferSize);

      if BytesRead > 0 then
      begin
        // Adjust buffer size to actual bytes read
        SetLength(Buffer, BytesRead);

        // Encode this chunk
        PartialResult := Base64Encode(Buffer, False, 0, '');

        // Handle line breaks manually for stream processing
        if includeLineBreaks and (charsPerLine > 0) then
        begin
          TempResult := '';

          for i := 1 to Length(PartialResult) do
          begin
            TempResult := TempResult + PartialResult[i];
            Inc(CharCount);

            if (CharCount >= charsPerLine) and (i < Length(PartialResult)) then
            begin
              TempResult := TempResult + lineBreak;
              CharCount := 0;
            end;
          end;

          Result := Result + TempResult;
        end
        else
          Result := Result + PartialResult;
        // Reset buffer size for next iteration
        SetLength(Buffer, BufferSize);
      end;

    until BytesRead < BufferSize;

  finally
    // Restore original position
    stream.Position := OriginalPosition;
  end;
end;

{$ENDIF}

{$ENDREGION}


{$REGION 'DECODE'}

{$IFNDEF HAS_NET_ENCODING}

function Base64Decode(const base64String : string): TBytes; overload;
const
  // Base64 decode lookup table - maps ASCII values to 6-bit values
  // Invalid chars map to 255, padding '=' maps to 0
  Base64DecodeTable: array[0..255] of Byte = (
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255, // 0-15
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255, // 16-31
    255,255,255,255,255,255,255,255,255,255,255, 62,255,255,255, 63, // 32-47 (+,/)
     52, 53, 54, 55, 56, 57, 58, 59, 60, 61,255,255,255,  0,255,255, // 48-63 (0-9,=)
    255,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, // 64-79 (A-O)
     15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,255,255,255,255,255, // 80-95 (P-Z)
    255, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, // 96-111 (a-o)
     41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51,255,255,255,255,255, // 112-127 (p-z)
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255, // 128-143
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255, // 144-159
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255, // 160-175
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255, // 176-191
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255, // 192-207
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255, // 208-223
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255, // 224-239
    255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255  // 240-255
  );
var
  InputLen, OutputLen, PaddingCount: Integer;
  SrcPtr, EndPtr: PChar;
  DestPtr: PByte;
  c1, c2, c3, c4: Byte;
  CleanInput: string;
  i, j: Integer;
begin
  // Fast path for empty input
  if base64String = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // Pre-allocate clean input string for worst case (no removals needed)
  SetLength(CleanInput, Length(base64String));
  j := 1;

  // Single pass cleanup - remove whitespace characters
  for i := 1 to Length(base64String) do
  begin
    if not (base64String[i] in [' ', #9, #10, #13]) then
    begin
      CleanInput[j] := base64String[i];
      Inc(j);
    end;
  end;

  // Adjust length to actual clean size
  InputLen := j - 1;
  SetLength(CleanInput, InputLen);

  // Validate input length
  if (InputLen mod 4) <> 0 then
    raise Exception.Create('Invalid Base64 string length');

  if InputLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // Count padding - check last 2 characters only
  PaddingCount := 0;
  if CleanInput[InputLen] = '=' then
  begin
    Inc(PaddingCount);
    if (InputLen > 1) and (CleanInput[InputLen - 1] = '=') then
      Inc(PaddingCount);
  end;

  // Calculate output size
  OutputLen := (InputLen * 3) div 4 - PaddingCount;
  SetLength(Result, OutputLen);

  if OutputLen = 0 then
    Exit;

  // Use pointers for faster access
  SrcPtr := PChar(CleanInput);
  EndPtr := SrcPtr + InputLen;
  DestPtr := PByte(Result);

  // Process 4 characters at a time
  while SrcPtr < EndPtr do
  begin
    // Get 4 decoded values using table lookup
    c1 := Base64DecodeTable[Ord(SrcPtr^)];
    Inc(SrcPtr);
    c2 := Base64DecodeTable[Ord(SrcPtr^)];
    Inc(SrcPtr);
    c3 := Base64DecodeTable[Ord(SrcPtr^)];
    Inc(SrcPtr);
    c4 := Base64DecodeTable[Ord(SrcPtr^)];
    Inc(SrcPtr);

    // Validate (255 = invalid character)
    if (c1 = 255) or (c2 = 255) or
       ((c3 = 255) and ((SrcPtr - 1)^ <> '=')) or
       ((c4 = 255) and ((SrcPtr - 1)^ <> '=')) then
      raise Exception.Create('Invalid Base64 character found');

    // Decode first byte (always present)
    DestPtr^ := (c1 shl 2) or (c2 shr 4);
    Inc(DestPtr);

    // Decode second byte (if not padded)
    if (SrcPtr - 2)^ <> '=' then
    begin
      if DestPtr < PByte(Result) + OutputLen then
      begin
        DestPtr^ := ((c2 and $0F) shl 4) or (c3 shr 2);
        Inc(DestPtr);
      end;
    end;

    // Decode third byte (if not padded)
    if (SrcPtr - 1)^ <> '=' then
    begin
      if DestPtr < PByte(Result) + OutputLen then
      begin
        DestPtr^ := ((c3 and $03) shl 6) or c4;
        Inc(DestPtr);
      end;
    end;
  end;
end;

procedure Base64Decode(const base64String : string; const stream : TStream); overload;
var
  DecodedBytes: TBytes;
  OriginalPosition: Int64;
begin
  if not Assigned(stream) then
    raise Exception.Create('Stream parameter cannot be nil');

  // Save original position
  OriginalPosition := stream.Position;

  try
    // Decode to bytes first
    DecodedBytes := Base64Decode(base64String);

    // Write the decoded bytes to the stream
    if Length(DecodedBytes) > 0 then
      stream.WriteBuffer(DecodedBytes[0], Length(DecodedBytes));

  except
    // Restore original position on error
    stream.Position := OriginalPosition;
    raise;
  end;
end;{$ENDIF}

{$ENDREGION}




{ TBase64 }


class function TBase64.Decode(const base64String : string): TBytes;
begin
{$IFDEF HAS_NET_ENCODING}
  Result := TNetEncoding.Base64.DecodeStringToBytes(base64String);
{$ELSE}
  result := Base64Decode(base64String);
{$ENDIF}
end;



class procedure TBase64.Decode(const base64String : string; const stream : TStream);
{$IFDEF HAS_NET_ENCODING}
var
  base64Stream: TStringStream;
{$ENDIF}
begin
{$IFDEF HAS_NET_ENCODING}
  base64Stream := TStringStream.Create(base64String);
  base64Stream.Position := 0;
  try
    TNetEncoding.Base64.Decode(base64Stream, stream);
  finally
    base64Stream.Free;
  end;
{$ELSE}
  Base64Decode(base64String, stream);
{$ENDIF}

end;



class function TBase64.Encode(const bytes : TBytes; includeLineBreaks : boolean; charsPerLine : integer; const lineBreak : string): string;
{$IFDEF HAS_NET_ENCODING}
var
  encoding : TBase64Encoding;
{$ENDIF}
begin
{$IFDEF HAS_NET_ENCODING}
  if includeLineBreaks then
    encoding := TBase64Encoding.Create(charsPerLine, lineBreak)
  else
    encoding := TBase64Encoding.Create;
  try
     Result := encoding.EncodeBytesToString(bytes);
  finally
    encoding.Free;
  end;

{$ELSE}
  result := Base64Encode(bytes,  includeLineBreaks, charsPerLine, lineBreak);
{$ENDIF}
end;



class function TBase64.Encode(const stream: TStream; includeLineBreaks : boolean; charsPerLine : integer; const lineBreak : string): string;
{$IFDEF HAS_NET_ENCODING}
var
  base64Stream: TStringStream;
  encoding: TBase64Encoding;
{$ENDIF}
begin
 {$IFDEF HAS_NET_ENCODING}
  base64Stream := TStringStream.Create;
  try
    if includeLineBreaks then
      encoding := TBase64Encoding.Create(charsPerLine, lineBreak)
    else
      encoding := TBase64Encoding.Create;
    try
      encoding.Encode(stream, base64Stream);
      Result := base64Stream.DataString;
    finally
      encoding.Free;
    end;
  finally
    base64Stream.Free;
  end;
  {$ELSE}
    result := Base64Encode(stream, includeLineBreaks, charsPerLine, lineBreak);
  {$ENDIF}
end;

end.