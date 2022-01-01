{==============================================================================
     _    _ _
    / \  | | | ___  __ _ _ __ ___
   / _ \ | | |/ _ \/ _` | '__/ _ \
  / ___ \| | |  __/ (_| | | | (_) |
 /_/   \_\_|_|\___|\__, |_|  \___/
                   |___/
    A game programming library


 Pascal bindings that allow you to use Allegro with Delphi.

 Inclued:
   - Allegro (https://github.com/liballeg/allegro5)
   - minizip (https://github.com/madler/zlib)

 Minimum Requirements:
   - Windows 10+ (64 bits)
   - Delphi Community Edition (Win64 platform only)

 Usage:
   You simply add Allegro to your uses section and everything will be linked in
   and ready for use. You will have direct access to all the above
   libraries.

 Copyright © 2021 tinyBigGAMES™ LLC
 All Rights Reserved.

 Website: https://tinybiggames.com
 Email  : support@tinybiggames.com

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. The origin of this software must not be misrepresented; you must not
    claim that you wrote the original software. If you use this software in
    a product, an acknowledgment in the product documentation would be
    appreciated but is not required.
 2. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

 3. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 4. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 5. All video, audio, graphics and other content accessed through the
    software in this distro is the property of the applicable content owner
    and may be protected by applicable copyright law. This License gives
    Customer no rights to such content, and Company disclaims any liability
    for misuse of content.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
============================================================================= }

unit uZipArc;

interface

uses
  System.Types,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.ZLib,
  WinAPI.Windows,
  Allegro;

type

  { TZipArc }
  TZipArc = class
  protected
    LCodePage: Cardinal;
    procedure Header;
    procedure Usage;
    function GetCRC32(aStream: TStream): Cardinal;
    procedure OnProgress(const aFilename: string; aProgress: Integer; aNewFile: Boolean);
    function Build(const aPassword: string; const aFilename: string; const aDirectory: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
  end;

procedure RunZipArc;

implementation

procedure RunZipArc;
var
  LArc: TZipArc;
begin
  LArc := TZipArc.Create;
  try
    LArc.Run;
  finally
    FreeAndNil(LArc);
  end;
end;

{ TZipArc }
procedure TZipArc.Header;
begin
  WriteLn;
  WriteLn('ZipArc™ Archive Utilty');
  WriteLn('Copyright © 2021 tinyBigGAMES™');
  WriteLn('All Rights Reserved.');
end;

procedure TZipArc.Usage;
begin
  WriteLn;
  WriteLn('Usage: ZipArc [password] archivename[.zip] directoryname');
  WriteLn('  password      - make archive password protected');
  WriteLn('  archivename   - compressed archive name');
  WriteLn('  directoryname - directory to archive');
end;

function TZipArc.GetCRC32(aStream: TStream): Cardinal;
var
  LBytesRead: Integer;
  LBuffer: array of Byte;
begin
  SetLength(LBuffer, 65521);

  Result := Crc32(0, nil, 0);
  repeat
    LBytesRead := AStream.Read(LBuffer[0], Length(LBuffer));
    Result := Crc32(Result, @LBuffer[0], LBytesRead);
  until LBytesRead = 0;

  LBuffer := nil;
end;

procedure TZipArc.OnProgress(const aFilename: string; aProgress: Integer; aNewFile: Boolean);
begin
  if aNewFile then WriteLn;
  Write(Format(#13'Adding "%s" (%d%s)...', [aFilename, aProgress, '%']));
end;

function TZipArc.Build(const aPassword: string; const aFilename: string; const aDirectory: string): Boolean;
var
  LMarshaller: array[0..1] of TMarshaller;
  LFileList: TStringDynArray;
  LFilename: string;
  LZipFile: zipFile;
  LZipFileInfo: zip_fileinfo;
  LFile: TStream;
  LCrc: Cardinal;
  LBytesRead: Integer;
  LBuffer: array of Byte;
  LFileSize: Int64;
  LProgress: Single;
  LNewFile: Boolean;
begin
  Result := False;

  // check if directory exists
  if not TDirectory.Exists(aDirectory) then Exit;

  // init variabls
  SetLength(LBuffer, 1024*4);
  FillChar(LZipFileInfo, SizeOf(LZipFileInfo), 0);

  // scan folder and build file list
  LFileList := TDirectory.GetFiles(aDirectory, '*', TSearchOption.soAllDirectories);

  // create a zip file
  LZipFile := zipOpen(LMarshaller[0].AsUtf8(aFilename).ToPointer, APPEND_STATUS_CREATE);

  // process zip file
  if LZipFile <> nil then
  begin
    // loop through all files in list
    for LFilename in LFileList do
    begin
      // open file
      LFile := TFile.OpenRead(LFilename);

      // get file size
      LFileSize := LFile.Size;

      // get file crc
      LCrc := GetCRC32(LFile);

      // open new file in zip
      if ZipOpenNewFileInZip3(LZipFile, LMarshaller[0].AsUtf8(LFilename).ToPointer,
        @LZipFileInfo, nil, 0, nil, 0, '',  Z_DEFLATED, 9, 0, 15, 9,
        Z_DEFAULT_STRATEGY, LMarshaller[1].AsUtf8(aPassword).ToPointer, LCrc) = Z_OK then
      begin
        // make sure we start at star of stream
        LFile.Position := 0;

        // this is a new file
        LNewFile := True;

        // read through file
        repeat
          // read in a buffer length of file
          LBytesRead := LFile.Read(LBuffer[0], Length(LBuffer));

          // write buffer out to zip file
          zipWriteInFileInZip(LZipFile, @LBuffer[0], LBytesRead);

          // calc file progress percentage
          LProgress := 100.0 * (LFile.Position / LFileSize);

          // show progress
          OnProgress(LFilename, Round(LProgress), LNewFile);

          // reset new file flag
          LNewFile := False;
        until LBytesRead = 0;

        // close file in zip
        zipCloseFileInZip(LZipFile);

        // free file stream
        FreeAndNil(LFile);
      end;
    end;

    // close zip file
    zipClose(LZipFile, '');
  end;

  // return true if new zip file exits
  Result := TFile.Exists(aFilename);
end;

constructor TZipArc.Create;
begin
  inherited;

  // save current console codepage
  LCodePage := GetConsoleOutputCP;

  // change current console codepage to UTF8
  SetConsoleOutputCP(WinApi.Windows.CP_UTF8);
end;

destructor TZipArc.Destroy;
begin
  // restore prev console codepage
  SetConsoleOutputCP(LCodePage);

  inherited;
end;

procedure TZipArc.Run;
var
  LPassword: string;
  LArchiveFilename: string;
  LDirectoryName: string;
begin
  // init local vars
  LPassword := '';
  LArchiveFilename := '';
  LDirectoryName := '';

  // display header
  Header;

  // check for password, archive, directory
  if ParamCount = 3 then
    begin
      LPassword := ParamStr(1);
      LArchiveFilename := ParamStr(2);
      LDirectoryName := ParamStr(3);
      LPassword := LPassword.DeQuotedString;
      LArchiveFilename := LArchiveFilename.DeQuotedString;
      LDirectoryName := LDirectoryName.DeQuotedString;
    end
  // check for archive directory
  else if ParamCount = 2 then
    begin
      LArchiveFilename := ParamStr(1);
      LDirectoryName := ParamStr(2);
      LArchiveFilename := LArchiveFilename.DeQuotedString;
      LDirectoryName := LDirectoryName.DeQuotedString;
    end
  else
    begin
      // show usage
      Usage;
      Exit;
    end;

  // init archive filename
  LArchiveFilename :=  TPath.ChangeExtension(LArchiveFilename, 'zip');

  // check if directory exist
  if not TDirectory.Exists(LDirectoryName) then
    begin
      WriteLn;
      WriteLn('Directory was not found: ', LDirectoryName);
      Usage;
      Exit;
    end;

  // display params
  WriteLn;
  if LPassword = '' then
    WriteLn('Password : NONE')
  else
    WriteLn('Password : ', LPassword);
  WriteLn('Archive  : ', LArchiveFilename);
  WriteLn('Directory: ', LDirectoryName);

  // try to build archive
  if Build(LPassword, LArchiveFilename, LDirectoryName) then
    begin
      WriteLn;
      WriteLn;
      WriteLn('Success!')
    end
  else
    begin
      WriteLn;
      WriteLn;
      WriteLn('Failed!');
    end;
end;

end.
