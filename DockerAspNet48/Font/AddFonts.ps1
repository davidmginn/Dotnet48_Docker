﻿$fontCSharpCode = @'
using System;
using System.Collections.Generic;
using System.Text;
using System.IO;
using System.Runtime.InteropServices;
namespace FontResource
{
    public class AddRemoveFonts
    {
        [DllImport("gdi32.dll")]
        static extern int AddFontResource(string lpFilename);
        public static int AddFont(string fontFilePath) {
            try 
            {
                return AddFontResource(fontFilePath);
            }
            catch
            {
                return 0;
            }
        }
    }
}
'@

Add-Type $fontCSharpCode

foreach($font in $(gci C:\Windows\Fonts))
{
    if(!$font.FullName.EndsWith("lucon.ttf"))
    {
        Write-Output "Loading $($font.FullName)"
        [FontResource.AddRemoveFonts]::AddFont($font.FullName) | Out-Null
    }
}

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
(New-Object System.Drawing.Text.InstalledFontCollection).Families

C:\ServiceMonitor.exe w3svc