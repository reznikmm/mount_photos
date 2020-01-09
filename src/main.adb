--  Copyright (c) 2020 Maxim Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
--  License-Filename: LICENSE
-------------------------------------------------------------

with Ada.Text_IO;
with Ada.Wide_Wide_Text_IO;

with AWS.Client;
with AWS.Messages;
with AWS.Response;
with AWS.URL;
with AWS.Headers;

with League.Application;
with League.Holders;
with League.JSON.Documents;
with League.JSON.Objects;
with League.JSON.Values;
with League.Settings;
with League.Strings;

with Photo_Files;

procedure Main is

   function "+"
    (Item : Wide_Wide_String) return League.Strings.Universal_String
       renames League.Strings.To_Universal_String;

   function Get_OAuth_Parameter
     (Name : Wide_Wide_String) return League.Strings.Universal_String;
   function Get_Auth_URL return League.Strings.Universal_String;
   function Encode (Text : String) return League.Strings.Universal_String;

   procedure Get_Tokens
     (Code         : Wide_Wide_String;
      Access_Token : out League.Strings.Universal_String);

   ------------
   -- Encode --
   ------------

   function Encode (Text : String) return League.Strings.Universal_String is
   begin
      return League.Strings.From_UTF_8_String (AWS.URL.Encode (Text));
   end Encode;

   ------------------
   -- Get_Auth_URL --
   ------------------

   function Get_Auth_URL return League.Strings.Universal_String is
      Result : League.Strings.Universal_String;
   begin
      Result.Append ("https://accounts.google.com/o/oauth2/v2/auth");

      Result.Append ("?client_id=");
      Result.Append (Get_OAuth_Parameter ("client_id"));

      Result.Append ("&redirect_uri=urn:ietf:wg:oauth:2.0:oob");

      Result.Append ("&response_type=code");

      Result.Append ("&scope=");
      Result.Append
        (Encode ("https://www.googleapis.com/auth/photoslibrary.readonly"));

      return Result;
   end Get_Auth_URL;

   -------------------
   -- Get_OAuth_Parameter --
   -------------------

   function Get_OAuth_Parameter
     (Name : Wide_Wide_String) return League.Strings.Universal_String
   is
      Key : constant Wide_Wide_String := "oauth/" & Name;
      Settings : League.Settings.Settings;
   begin
      return League.Holders.Element (Settings.Value (+Key));
   end Get_OAuth_Parameter;

   procedure Get_Tokens
     (Code         : Wide_Wide_String;
      Access_Token : out League.Strings.Universal_String)
   is
      Result : AWS.Response.Data;
      Parameters : League.Strings.Universal_String;
   begin
      Parameters.Append ("code=");
      Parameters.Append (Code);
      Parameters.Append ("&client_id=");
      Parameters.Append (Get_OAuth_Parameter ("client_id"));
      Parameters.Append ("&client_secret=");
      Parameters.Append (Get_OAuth_Parameter ("client_secret"));
      Parameters.Append ("&grant_type=authorization_code");
      Parameters.Append ("&redirect_uri=urn:ietf:wg:oauth:2.0:oob");

      Result := AWS.Client.Post
        (URL          => "https://oauth2.googleapis.com/token",
         Data         => Parameters.To_UTF_8_String,
         Content_Type => "application/x-www-form-urlencoded");

      if AWS.Response.Status_Code (Result) not in AWS.Messages.Success then
         Ada.Wide_Wide_Text_IO.Put_Line
           (AWS.Messages.Status_Code'Wide_Wide_Image
              (AWS.Response.Status_Code (Result)));
         Ada.Wide_Wide_Text_IO.Put_Line
           (AWS.Response.Content_Length_Type'Wide_Wide_Image
              (AWS.Response.Content_Length (Result)));
         Ada.Text_IO.Put_Line (AWS.Response.Content_Type (Result));
         Ada.Text_IO.Put_Line (AWS.Response.Message_Body (Result));
         raise Program_Error with "Unexpected response";
      end if;

      declare
         Document : constant League.JSON.Documents.JSON_Document :=
           League.JSON.Documents.From_JSON
             (AWS.Response.Message_Body (Result));
      begin
         Access_Token :=
           Document.To_JSON_Object.Value (+"access_token").To_String;
      end;
   end Get_Tokens;

   Context : aliased Photo_Files.Context;

   Access_Token : League.Strings.Universal_String;
begin
   League.Application.Set_Organization_Name (+"Matreshka Project");
   League.Application.Set_Organization_Domain (+"forge.ada-ru.org");
   League.Application.Set_Application_Name (+"Mount Photos");

   Ada.Wide_Wide_Text_IO.Put_Line ("Введите Access_Token (если есть):");

   declare
      Line : constant Wide_Wide_String := Ada.Wide_Wide_Text_IO.Get_Line;
   begin
      if Line'Length > 0 then
         Access_Token.Append (Line);
      end if;
   end;

   if Access_Token.Is_Empty then
      Ada.Wide_Wide_Text_IO.Put_Line ("Перейдите по ссылке:");
      Ada.Wide_Wide_Text_IO.Put_Line (Get_Auth_URL.To_Wide_Wide_String);
      Ada.Wide_Wide_Text_IO.Put_Line ("Введите код доступа:");

      declare
         Code : constant Wide_Wide_String := Ada.Wide_Wide_Text_IO.Get_Line;
      begin
         Get_Tokens (Code, Access_Token);
      end;
   end if;

   Ada.Wide_Wide_Text_IO.Put_Line (Access_Token.To_Wide_Wide_String);

   Context.Access_Token := Access_Token;
   Photo_Files.Photos.Main (User_Data => Context'Unchecked_Access);
end Main;
