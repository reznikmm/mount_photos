--  Copyright (c) 2020 Maxim Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: MIT
--  License-Filename: LICENSE
-------------------------------------------------------------

with Ada.Streams;
with Ada.Containers.Hashed_Maps;

with Fuse.Main;

with League.Stream_Element_Vectors;
with League.Strings.Hash;

package Photo_Files is

   type Element_Array is
     array (Positive range <>) of Ada.Streams.Stream_Element;

   type File is record
      Id       : League.Strings.Universal_String;
      Base_URL : League.Strings.Universal_String;
   end record;

   package File_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => League.Strings.Universal_String,  --  Name
      Element_Type    => File,
      Hash            => League.Strings.Hash,
      Equivalent_Keys => League.Strings."=");

   type Album is record
      Id    : League.Strings.Universal_String;
      Files : File_Maps.Map;
   end record;

   package Album_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => League.Strings.Universal_String,  --  Name
      Element_Type    => Album,
      Hash            => League.Strings.Hash,
      Equivalent_Keys => League.Strings."=");

   type Context is record
      Access_Token : League.Strings.Universal_String;
      Albums       : Album_Maps.Map;
      Cached_File  : League.Strings.Universal_String;
      Cached_Data  : League.Stream_Element_Vectors.Stream_Element_Vector;
   end record;

   type Context_Access is access all Context;

   pragma Warnings (Off);
   package Photos is new Fuse.Main
     (Element_Type   => Ada.Streams.Stream_Element,
      Element_Array  => Element_Array,
      User_Data_Type => Context_Access);
   pragma Warnings (On);

   function GetAttr
     (Path   : in String;
      St_Buf : access Photos.System.Stat_Type)
      return Photos.System.Error_Type;

   function Open
     (Path   : in String;
      Fi     : access Photos.System.File_Info_Type)
      return Photos.System.Error_Type;

   function Read
     (Path   : in String;
      Buffer : access Photos.Buffer_Type;
      Size   : in out Natural;
      Offset : in Natural;
      Fi     : access Photos.System.File_Info_Type)
      return Photos.System.Error_Type;

   function ReadDir
     (Path   : in String;
      Filler : access procedure
                 (Name     : String;
                  St_Buf   : Photos.System.Stat_Access;
                  Offset   : Natural);
      Offset : in Natural;
      Fi     : access Photos.System.File_Info_Type)
      return Photos.System.Error_Type;

   package Hello_GetAttr is new Photos.GetAttr;
   package Hello_Open is new Photos.Open;
   package Hello_Read is new Photos.Read;
   package Hello_ReadDir is new Photos.ReadDir;

end Photo_Files;
