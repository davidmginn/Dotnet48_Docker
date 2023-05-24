$FONTS = 0x14
$FONTS
$objShell = New-Object -ComObject Shell.Application
$objShell
$objFolder = $objShell.Namespace($FONTS)

$objFolder.CopyHere("FrederickatheGreat-Regular.ttf")

[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
(New-Object System.Drawing.Text.InstalledFontCollection).Families