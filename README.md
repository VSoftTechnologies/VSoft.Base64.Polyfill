# VSoft.Base64

This is a simple Delphi polyfill library that enables you to use Base64 Encode/Decode for versions of Delphi that do not include System.NetEncoding (earlier than XE7).

`<  XE 7 - uses own Base64 code.`

`>= XE 7 - calls through to TNetEncoding.Base64`

If you are only supporting XE7 or later just use System.NetEncoding
