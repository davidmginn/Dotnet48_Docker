﻿COPY Font/wingding.ttf c:/windows/fonts/wingding.ttf
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name 'Wingdings (TrueType)' -PropertyType String -Value wingding.ttf