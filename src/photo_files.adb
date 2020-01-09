--  Copyright (c) 2020 Maxim Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
--  License-Filename: LICENSE
-------------------------------------------------------------

with Ada.Text_IO;
with Ada.Wide_Wide_Text_IO;

with AWS.Client;
with AWS.Headers;
with AWS.Messages;
with AWS.Response;

with League.String_Vectors;
with League.JSON.Documents;
with League.JSON.Arrays;
with League.JSON.Objects;
with League.JSON.Values;

package body Photo_Files is

   function "+"
    (Item : Wide_Wide_String) return League.Strings.Universal_String
       renames League.Strings.To_Universal_String;

   procedure Read_Albums (Self : in out Context);
   procedure Read_Album
     (Self : in out Context;
      Name : League.Strings.Universal_String);

   procedure Read_File
     (Self     : in out Context;
      Base_URL : League.Strings.Universal_String);

   -------------
   -- GetAttr --
   -------------

   function GetAttr
     (Path : in String; St_Buf : access Photos.System.Stat_Type)
      return Photos.System.Error_Type
   is
      use type Photos.System.St_Mode_Type;

      Context : constant Context_Access := Photos.General.Get_User_Data;
      List    : constant League.String_Vectors.Universal_String_Vector :=
        League.Strings.From_UTF_8_String (Path).Split
          ('/', League.Strings.Skip_Empty);
   begin
      if Context.Albums.Is_Empty then
         Read_Albums (Context.all);
      end if;

      if Path = "/" then
         St_Buf.St_Mode := Photos.System.S_IFDIR or 8#755#;
         St_Buf.St_Nlink := 2;

      elsif List.Length = 1 and then
        Context.Albums.Contains (List (1))
      then

         St_Buf.St_Mode := Photos.System.S_IFDIR or 8#755#;
         St_Buf.St_Nlink := 3;

      elsif List.Length = 2 and then
        Context.Albums.Contains (List (1))
      then
         if Context.Albums (List (1)).Files.Is_Empty then
            Read_Album (Context.all, List (1));
         end if;

         if Context.Albums (List (1)).Files.Contains (List (2)) then
            St_Buf.St_Mode := Photos.System.S_IFREG or 8#444#;
            St_Buf.St_Nlink := 1;
            St_Buf.St_Size := 10_000_000;
         else
            return Photos.System.ENOENT;
         end if;

      else
         return Photos.System.ENOENT;

      end if;

      return Photos.System.EXIT_SUCCESS;
   end GetAttr;

   ----------
   -- Open --
   ----------

   function Open
     (Path   : in String;
      Fi     : access Photos.System.File_Info_Type)
      return Photos.System.Error_Type
   is
      use type Photos.System.RW_Type;

      Context : constant Context_Access := Photos.General.Get_User_Data;
      List    : constant League.String_Vectors.Universal_String_Vector :=
        League.Strings.From_UTF_8_String (Path).Split
          ('/', League.Strings.Skip_Empty);
   begin

      if List.Length = 2 and then
        Context.Albums.Contains (List (1))
      then
         if Context.Albums (List (1)).Files.Is_Empty then
            Read_Album (Context.all, List (1));
         end if;

         if Context.Albums (List (1)).Files.Contains (List (2)) then

            if Fi.all.Flags.RW /= Photos.System.O_RDONLY then
               return Photos.System.EACCES;

            else

               return Photos.System.EXIT_SUCCESS;
            end if;
         end if;
      end if;

      return Photos.System.ENOENT;
   end Open;

   function Read
     (Path   : in String;
      Buffer : access Photos.Buffer_Type;
      Size   : in out Natural;
      Offset : in Natural;
      Fi     : access Photos.System.File_Info_Type)
      return Photos.System.Error_Type
   is
      pragma Unreferenced (Fi);
      use type League.Strings.Universal_String;

      Context : constant Context_Access := Photos.General.Get_User_Data;
      Value   : constant League.Strings.Universal_String :=
        League.Strings.From_UTF_8_String (Path);
      List    : constant League.String_Vectors.Universal_String_Vector :=
        Value.Split ('/', League.Strings.Skip_Empty);
      Length  : Natural;
   begin

      if List.Length = 2 and then
        Context.Albums.Contains (List (1))
      then
         if Context.Albums (List (1)).Files.Is_Empty then
            Read_Album (Context.all, List (1));
         end if;

         if Context.Albums (List (1)).Files.Contains (List (2)) then
            if Context.Cached_File /= Value then
               Read_File
                 (Context.all,
                  Context.Albums (List (1)).Files (List (2)).Base_URL);
               Context.Cached_File := Value;
            end if;

            Length := Natural (Context.Cached_Data.Length);

            Ada.Wide_Wide_Text_IO.Put_Line
              ("Offset=" & Natural'Wide_Wide_Image (Offset)
               & " Size=" & Natural'Wide_Wide_Image (Size));

            if Offset <= Length then

               if Offset + Size > Length then
                  Size := Length - Offset;
               end if;

               for J in 1 .. Size loop
                  Buffer (J) := Context.Cached_Data.Element
                    (Ada.Streams.Stream_Element_Offset (Offset + J));
               end loop;
            else
               Size := 0;

            end if;

            Ada.Wide_Wide_Text_IO.Put_Line
              ("Length=" & Natural'Wide_Wide_Image (Length)
               & " Size=" & Natural'Wide_Wide_Image (Size));

            return Photos.System.EXIT_SUCCESS;
         end if;
      end if;

      return Photos.System.ENOENT;
   end Read;

   ----------------
   -- Read_Album --
   ----------------

   procedure Read_Album
     (Self : in out Context;
      Name : League.Strings.Universal_String)
   is
      Id      : constant League.Strings.Universal_String :=
        Self.Albums (Name).Id;
      Request : League.JSON.Objects.JSON_Object;
      Result  : AWS.Response.Data;
      Headers : AWS.Headers.List;
   begin
      Request.Insert (+"albumId", League.JSON.Values.To_JSON_Value (Id));

      AWS.Headers.Add
        (Headers,
         "Authorization",
         "Bearer " & Self.Access_Token.To_UTF_8_String);

      Result := AWS.Client.Post
        ("https://photoslibrary.googleapis.com/v1/mediaItems:search",
         Headers => Headers,
         Data    => Request.To_JSON_Document.To_JSON.To_Stream_Element_Array,
         Content_Type => "application/json");

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
         Files    : File_Maps.Map renames Self.Albums (Name).Files;
         Document : constant League.JSON.Documents.JSON_Document :=
           League.JSON.Documents.From_JSON
             (AWS.Response.Message_Body (Result));
         Items : League.JSON.Arrays.JSON_Array;
      begin
         Items := Document.To_JSON_Object.Value (+"mediaItems").To_Array;

         for J in 1 .. Items.Length loop
            declare
               Item : constant League.JSON.Objects.JSON_Object :=
                 Items.Element (J).To_Object;
               Id       : League.Strings.Universal_String;
               Filename : League.Strings.Universal_String;
               baseUrl  : League.Strings.Universal_String;
            begin
               Id := Item.Value (+"id").To_String;
               Filename := Item.Value (+"filename").To_String;
               baseUrl := Item.Value (+"baseUrl").To_String;
               Files.Include (Filename, (Id, baseUrl));
               Ada.Wide_Wide_Text_IO.Put_Line (baseUrl.To_Wide_Wide_String);
               Ada.Wide_Wide_Text_IO.Put_Line (Filename.To_Wide_Wide_String);
            end;
         end loop;
      end;

   end Read_Album;

   -----------------
   -- Read_Albums --
   -----------------

   procedure Read_Albums (Self : in out Context) is
      Result : AWS.Response.Data;
      Headers : AWS.Headers.List;
   begin
      AWS.Headers.Add
        (Headers,
         "Authorization",
         "Bearer " & Self.Access_Token.To_UTF_8_String);

      Result := AWS.Client.Get
        (URL     => "https://photoslibrary.googleapis.com/v1/sharedAlbums",
         Headers => Headers);

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
         Albums : League.JSON.Arrays.JSON_Array;
      begin
         Albums :=
           Document.To_JSON_Object.Value (+"sharedAlbums").To_Array;

         for J in 1 .. Albums.Length loop
            declare
               Album : constant League.JSON.Objects.JSON_Object :=
                 Albums.Element (J).To_Object;
               Id    : League.Strings.Universal_String;
               Title : League.Strings.Universal_String;
            begin
               Id := Album.Value (+"id").To_String;
               Title := Album.Value (+"title").To_String;
               Ada.Wide_Wide_Text_IO.Put_Line (Id.To_Wide_Wide_String);
               Ada.Wide_Wide_Text_IO.Put_Line (Title.To_Wide_Wide_String);

               if Title.Is_Empty then
                  Title := Id;
               end if;

               Self.Albums.Include (Title, (Id, File_Maps.Empty_Map));
            end;
         end loop;
      end;
   end Read_Albums;

   ---------------
   -- Read_File --
   ---------------

   procedure Read_File
     (Self     : in out Context;
      Base_URL : League.Strings.Universal_String)
   is
      Result  : AWS.Response.Data;
   begin
      Result := AWS.Client.Get
        (URL     => Base_URL.To_UTF_8_String & "=w1920-h1080");

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

      Self.Cached_Data.Clear;
      Self.Cached_Data.Append (AWS.Response.Message_Body (Result));

      Ada.Wide_Wide_Text_IO.Put_Line
        (Self.Cached_File.To_Wide_Wide_String
         & " => "
         & Ada.Streams.Stream_Element_Offset'Wide_Wide_Image
           (Self.Cached_Data.Length));
   end Read_File;

   -------------
   -- ReadDir --
   -------------

   function ReadDir
     (Path   : in String;
      Filler :    access procedure
        (Name : String; St_Buf : Photos.System.Stat_Access; Offset : Natural);
      Offset : in Natural; Fi : access Photos.System.File_Info_Type)
      return Photos.System.Error_Type
   is
      pragma Unreferenced (Fi, Offset);
      Context : constant Context_Access := Photos.General.Get_User_Data;
      List    : constant League.String_Vectors.Universal_String_Vector :=
        League.Strings.From_UTF_8_String (Path).Split
          ('/', League.Strings.Skip_Empty);
   begin
      if Context.Albums.Is_Empty then
         Read_Albums (Context.all);
      end if;

      if Path = "/" then

         Filler (".", null, 0);
         Filler ("..", null, 0);

         for Cursor in Context.Albums.Iterate loop
            Filler (Album_Maps.Key (Cursor).To_UTF_8_String, null, 0);
         end loop;

         return Photos.System.EXIT_SUCCESS;

      elsif List.Length = 1 and then
        Context.Albums.Contains (List (1))
      then

         if Context.Albums (List (1)).Files.Is_Empty then
            Read_Album (Context.all, List (1));
         end if;

         Filler (".", null, 0);
         Filler ("..", null, 0);

         for Cursor in Context.Albums (List (1)).Files.Iterate loop
            Filler (File_Maps.Key (Cursor).To_UTF_8_String, null, 0);
         end loop;

         return Photos.System.EXIT_SUCCESS;
      end if;

      return Photos.System.ENOENT;

   end ReadDir;

end Photo_Files;
