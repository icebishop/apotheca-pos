{ Apothêca - Parameter encryption

  Symmetric encryption for sensitive parameter values, using Blowfish (ECB) from
  fcl-base and Base64 text encoding so ciphertext can be stored in a TEXT column.

  This protects credential values at rest in the database. The key is derived
  from a fixed application secret; callers may override it via SetKey.

  NOTE: This is obfuscation-grade protection suitable for keeping credentials out
  of plain sight in the local database. It is not a substitute for OS-level
  secret storage for high-value secrets.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UCrypto;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TCrypto = class(TObject)
  public
    { Sets the encryption key (any length; truncated/padded to Blowfish limits). }
    class procedure SetKey(const AKey: String);
    { Encrypts plaintext -> Base64 ciphertext (empty in -> empty out). }
    class function Encrypt(const PlainText: String): String;
    { Decrypts Base64 ciphertext -> plaintext. Returns '' on failure/empty. }
    class function Decrypt(const CipherText: String): String;
  end;

implementation

uses
  BlowFish, base64;

var
  FKey: String = 'apotheca-pos-default-parameter-key-v1';

const
  { Blowfish key must be 1..56 bytes. }
  MAX_BF_KEY = 56;

class procedure TCrypto.SetKey(const AKey: String);
begin
  if AKey <> '' then
    FKey := AKey;
end;

class function TCrypto.Encrypt(const PlainText: String): String;
var
  KeyStr: String;
  Enc: TBlowFishEncryptStream;
  MemOut: TStringStream;
  Cipher: TStringStream;
begin
  Result := '';
  if PlainText = '' then
    Exit;

  KeyStr := Copy(FKey, 1, MAX_BF_KEY);
  MemOut := TStringStream.Create('');
  try
    Enc := TBlowFishEncryptStream.Create(KeyStr, MemOut);
    try
      Enc.Write(PlainText[1], Length(PlainText));
    finally
      Enc.Free;  { flushes remaining bytes to MemOut }
    end;
    { Base64-encode the raw ciphertext. }
    Cipher := TStringStream.Create('');
    try
      Cipher.WriteString(EncodeStringBase64(MemOut.DataString));
      Result := Cipher.DataString;
    finally
      Cipher.Free;
    end;
  finally
    MemOut.Free;
  end;
end;

class function TCrypto.Decrypt(const CipherText: String): String;
var
  KeyStr: String;
  Dec: TBlowFishDeCryptStream;
  RawCipher: String;
  MemIn: TStringStream;
  Buf: array[0..1023] of Char;
  ReadCount: Integer;
begin
  Result := '';
  if CipherText = '' then
    Exit;

  KeyStr := Copy(FKey, 1, MAX_BF_KEY);
  try
    RawCipher := DecodeStringBase64(CipherText);
    if RawCipher = '' then
      Exit;
    MemIn := TStringStream.Create(RawCipher);
    try
      MemIn.Position := 0;
      Dec := TBlowFishDeCryptStream.Create(KeyStr, MemIn);
      try
        repeat
          ReadCount := Dec.Read(Buf, SizeOf(Buf));
          if ReadCount > 0 then
            Result := Result + Copy(Buf, 1, ReadCount);
        until ReadCount = 0;
      finally
        Dec.Free;
      end;
    finally
      MemIn.Free;
    end;
    { Blowfish is a block cipher: the decrypted stream is padded with NUL bytes
      to the block boundary. Strip trailing NULs added by padding. }
    while (Length(Result) > 0) and (Result[Length(Result)] = #0) do
      SetLength(Result, Length(Result) - 1);
  except
    Result := '';
  end;
end;

end.
