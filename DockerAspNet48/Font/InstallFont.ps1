#COPY Font/wingding.ttf c:/windows/fonts/wingding.ttf
#New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name 'Wingdings (TrueType)' -PropertyType String -Value wingding.ttf

#COPY Font/FrederickatheGreat-Regular.ttf c:/windows/fonts/FrederickatheGreat-Regular.ttf
#New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -Name 'Fredericka the Great (TrueType)' -PropertyType String -Value FrederickatheGreat-Regular.ttf


#Enable-WindowsOptionalFeature -Online -FeatureName "ServerCoreFonts-NonCritical-Fonts-MinConsoleFonts" -All -Source C:\inetpub\wwwroot\Font\install.wim
#Enable-WindowsOptionalFeature -Online -FeatureName "ServerCoreFonts-NonCritical-Fonts-Support" -All -Source C:\inetpub\wwwroot\Font\install.wim
#Enable-WindowsOptionalFeature -Online -FeatureName "ServerCoreFonts-NonCritical-Fonts-BitmapFonts" -All -Source C:\inetpub\wwwroot\Font\install.wim
#Enable-WindowsOptionalFeature -Online -FeatureName "ServerCoreFonts-NonCritical-Fonts-TrueType" -All -Source C:\inetpub\wwwroot\Font\install.wim
#Enable-WindowsOptionalFeature -Online -FeatureName "ServerCoreFonts-NonCritical-Fonts-UAPFonts" -All -Source C:\inetpub\wwwroot\Font\install.wim