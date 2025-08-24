unit Base64EncodeTests;

interface

uses
  DUnitX.TestFramework,
  VSoft.Base64;

type
  [TestFixture]
  TBase64EncodeTests = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestEncode;
    [Test]
    procedure TestStream;
  end;

implementation

uses
  System.SysUtils,
  System.Classes;

procedure TBase64EncodeTests.Setup;
begin
end;

procedure TBase64EncodeTests.TearDown;
begin

end;

procedure TBase64EncodeTests.TestEncode;
var
  x : TBytes;
  i : integer;
  s : string;
begin
  SetLength(x, 10);
  for i := 0 to 9 do
    x[i] := i;

  s := TBase64.Encode(x, true, 5 );
  Assert.AreEqual('AAEC'#$D#$A'AwQF'#$D#$A'BgcI'#$D#$A'CQ==', s);

  x := TBase64.Decode('AAECAwQFBgcICQ==');
  s := TBase64.Encode(x, true );
  Assert.AreEqual('AAECAwQFBgcICQ==', s);


end;


procedure TBase64EncodeTests.TestStream;
var
  x : TBytes;
  source : TMemoryStream;
  i : integer;
  s : string;
  expected : string;
begin
  SetLength(x, 10);
  for i := 0 to 9 do
    x[i] := i;
  source := TMemoryStream.Create;
  source.WriteBuffer(x[0],10);
  source.Seek(0,TSeekOrigin.soBeginning);

  s := TBase64.Encode(source, false );
  expected := 'AAECAwQFBgcICQ==';
  Assert.AreEqual(expected, s);

  source.Seek(0,TSeekOrigin.soBeginning);

  TBase64.Decode('8iyrYhh+UcyimGVxCsccjE9lqCvfqQg13GAvYwMonEM=', source);
  source.Seek(0,TSeekOrigin.soBeginning);
  s := TBase64.Encode(source, true );
  expected := '8iyrYhh+UcyimGVxCsccjE9lqCvfqQg13GAvYwMonEM=';
  Assert.AreEqual(expected, s);
end;

initialization
  TDUnitX.RegisterTestFixture(TBase64EncodeTests);

end.
