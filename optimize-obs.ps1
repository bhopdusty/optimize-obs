# couleur's tweaklist compacted into only optimize-obs

using namespace System.Management.Automation # Required by Invoke-NGENpsosh
Remove-Module TweakList -ErrorAction Ignore
New-Module TweakList ([ScriptBlock]::Create({

function Assert-Choice {
    if (-Not(Get-Command choice.exe -ErrorAction Ignore)){
        Write-Host "[!] Unable to find choice.exe (it comes with Windows, did a little bit of unecessary debloating?)" -ForegroundColor Red
        PauseNul
        exit 1
    }
}
function Assert-Path {
    param(
        $Path
    )
    if (-Not(Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}
function Get-ShortcutTarget {
    [alias('gst')]

    param([String]$ShortcutPath)

    Try {
        $null = Get-Item $ShortcutPath -ErrorAction Stop
    } Catch {
        throw
    }
    
    return (New-Object -ComObject WScript.Shell).CreateShortcut($ShortcutPath).TargetPath
}
<#
	.LINK
	Frankensteined from Inestic's WindowsFeatures Sophia Script function
	https://github.com/Inestic
	https://github.com/farag2/Sophia-Script-for-Windows/blob/06a315c643d5939eae75bf6e24c3f5c6baaf929e/src/Sophia_Script_for_Windows_10/Module/Sophia.psm1#L4946

	.SYNOPSIS
	User gets a nice checkbox-styled menu in where they can select 
	
	.EXAMPLE

	Screenshot: https://i.imgur.com/zrCtR3Y.png

	$ToInstall = Invoke-CheckBox -Items "7-Zip", "PowerShell", "Discord"

	Or you can have each item have a description by passing an array of hashtables:

	$ToInstall = Invoke-CheckBox -Items @(

		@{
			DisplayName = "7-Zip"
			# Description = "Cool Unarchiver"
		},
		@{
			DisplayName = "Windows Sandbox"
			Description = "Windows' Virtual machine"
		},
		@{
			DisplayName = "Firefox"
			Description = "A great browser"
		},
		@{
			DisplayName = "PowerShell 777"
			Description = "PowerShell on every system!"
		}
	)
#>
function Invoke-Checkbox{
param(
	$Title = "Select an option",
	$ButtonName = "Confirm",
	$Items = @("Fill this", "With passing an array", "to the -Item param!")
)

if (!$Items.Description){
	$NewItems = @()
	ForEach($Item in $Items){
		$NewItems += @{DisplayName = $Item}
	}
	$Items = $NewItems
} 

Add-Type -AssemblyName PresentationCore, PresentationFramework, System.Drawing, System.Windows.Forms, WindowsFormsIntegration


# Initialize an array list to store the selected Windows features
$SelectedFeatures = New-Object -TypeName System.Collections.ArrayList($null)
$ToReturn = New-Object -TypeName System.Collections.ArrayList($null)


#region XAML Markup
# The section defines the design of the upcoming dialog box
[xml]$XAML = '
<Window
	xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
	xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	Name="Window"
	MinHeight="450" MinWidth="400"
	SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen"
	TextOptions.TextFormattingMode="Display" SnapsToDevicePixels="True"
	FontFamily="Arial" FontSize="16" ShowInTaskbar="True"
	Background="#F1F1F1" Foreground="#262626">

	<Window.TaskbarItemInfo>
		<TaskbarItemInfo/>
	</Window.TaskbarItemInfo>
	
	<Window.Resources>
		<Style TargetType="StackPanel">
			<Setter Property="Orientation" Value="Horizontal"/>
			<Setter Property="VerticalAlignment" Value="Top"/>
		</Style>
		<Style TargetType="CheckBox">
			<Setter Property="Margin" Value="10, 10, 5, 10"/>
			<Setter Property="IsChecked" Value="True"/>
		</Style>
		<Style TargetType="TextBlock">
			<Setter Property="Margin" Value="5, 10, 10, 10"/>
		</Style>
		<Style TargetType="Button">
			<Setter Property="Margin" Value="25"/>
			<Setter Property="Padding" Value="15"/>
		</Style>
		<Style TargetType="Border">
			<Setter Property="Grid.Row" Value="1"/>
			<Setter Property="CornerRadius" Value="0"/>
			<Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
			<Setter Property="BorderBrush" Value="#000000"/>
		</Style>
		<Style TargetType="ScrollViewer">
			<Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
			<Setter Property="BorderBrush" Value="#000000"/>
			<Setter Property="BorderThickness" Value="0, 1, 0, 1"/>
		</Style>
	</Window.Resources>
	<Grid>
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>
		<ScrollViewer Name="Scroll" Grid.Row="0"
			HorizontalScrollBarVisibility="Disabled"
			VerticalScrollBarVisibility="Auto">
			<StackPanel Name="PanelContainer" Orientation="Vertical"/>
		</ScrollViewer>
		<Button Name="Button" Grid.Row="2"/>
	</Grid>
</Window>
'
#endregion XAML Markup

$Form = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$XAML.SelectNodes("//*[@Name]") | ForEach-Object {
	Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name)
}

#region Functions
function Get-CheckboxClicked
{
	[CmdletBinding()]
	param
	(
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true
		)]
		[ValidateNotNull()]
		$CheckBox
	)

	$Feature = $Items | Where-Object -FilterScript {$_.DisplayName -eq $CheckBox.Content}

	if ($CheckBox.IsChecked) {
		[void]$SelectedFeatures.Add($Feature)
	}
	else {
		[void]$SelectedFeatures.Remove($Feature)
	}
	if ($SelectedFeatures.Count -gt 0) {
		$Button.Content = $ButtonName
		$Button.IsEnabled = $true
	}
	else {
		$Button.Content = "Cancel"
		$Button.IsEnabled = $true
	}
}

function Add-FeatureControl
{
	[CmdletBinding()]
	param
	(
		[Parameter(
			Mandatory = $true,
			ValueFromPipeline = $true
		)]
		[ValidateNotNull()]
		$Feature
	)

	process {

		$StackPanel = New-Object -TypeName System.Windows.Controls.StackPanel

		$CheckBox = New-Object -TypeName System.Windows.Controls.CheckBox
		$CheckBox.Add_Click({Get-CheckboxClicked -CheckBox $_.Source})
		$Checkbox.Content = $Feature.DisplayName
		if ($Feature.Description){
			$CheckBox.ToolTip = $Feature.Description
		}
		$Checkbox.IsChecked = $False
		[void]$StackPanel.Children.Add($CheckBox)

		[void]$PanelContainer.Children.Add($StackPanel)
	}

}

$Window.Add_Loaded({$Items | Add-FeatureControl})

$Button.Content = $ButtonName
$Button.Add_Click({
	[void]$Window.Close()

	$ToReturn.Add($SelectedFeatures.DisplayName)
})

$Window.Title = $Title

# ty chrissy <3 https://blog.netnerds.net/2016/01/adding-toolbar-icons-to-your-powershell-wpf-guis/
$base64 = "iVBORw0KGgoAAAANSUhEUgAAACoAAAAqCAMAAADyHTlpAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAPUExURQAAAP///+vr6+fn5wAAAD8IT84AAAAFdFJOU/////8A+7YOUwAAAAlwSFlzAAALEwAACxMBAJqcGAAAANBJREFUSEut08ESgjAMRVFQ/v+bDbxLm9Q0lRnvQtrkDBt1O4a2FoNWHIBajJW/sQ+xOnNnlkMsrXZkkwRolHHaTXiUYfS5SOgXKfuQci0T5bLoIeWYt/O0FnTfu62pyW5X7/S26D/yFca19AvBXMaVbrnc3n6p80QGq9NUOqtnIRshhi7/ffHeK0a94TfQLQPX+HO5LVef0cxy8SX/gokU/bIcQvxjB5t1qYd0aYWuz4XF6FHam/AsLKDTGWZpuWNqWZ358zdmrOLNAlkM6Dg+78AGkhvs7wgAAAAASUVORK5CYII="
 
 
# Create a streaming image by streaming the base64 string to a bitmap streamsource
$bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
$bitmap.BeginInit()
$bitmap.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($base64)
$bitmap.EndInit()
$bitmap.Freeze()

 
# This is the toolbar icon and description
$Form.TaskbarItemInfo.Overlay = $bitmap
$Form.TaskbarItemInfo.Description = $window.Title

$Window.Add_Closing({[System.Windows.Forms.Application]::Exit()})

$Form.Show()

# This makes it pop up
$Form.Activate() | Out-Null
 
# Create an application context for it to all run within. 
# This helps with responsiveness and threading.
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext) 
return $ToReturn
}
# https://github.com/chrisseroka/ps-menu
function Menu {
    param ([array]$menuItems, [switch]$ReturnIndex=$false, [switch]$Multiselect)

function DrawMenu {
    param ($menuItems, $menuPosition, $Multiselect, $selection)
    $l = $menuItems.length
    for ($i = 0; $i -le $l;$i++) {
		if ($menuItems[$i] -ne $null){
			$item = $menuItems[$i]
			if ($Multiselect)
			{
				if ($selection -contains $i){
					$item = '[x] ' + $item
				}
				else {
					$item = '[ ] ' + $item
				}
			}
			if ($i -eq $menuPosition) {
				Write-Host "> $($item)" -ForegroundColor Green
			} else {
				Write-Host "  $($item)"
			}
		}
    }
}

function Toggle-Selection {
	param ($pos, [array]$selection)
	if ($selection -contains $pos){ 
		$result = $selection | where {$_ -ne $pos}
	}
	else {
		$selection += $pos
		$result = $selection
	}
	$result
}

    $vkeycode = 0
    $pos = 0
    $selection = @()
    if ($menuItems.Length -gt 0)
	{
		try {
			[console]::CursorVisible=$false #prevents cursor flickering
			DrawMenu $menuItems $pos $Multiselect $selection
			While ($vkeycode -ne 13 -and $vkeycode -ne 27) {
				$press = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown")
				$vkeycode = $press.virtualkeycode
				If ($vkeycode -eq 38 -or $press.Character -eq 'k') {$pos--}
				If ($vkeycode -eq 40 -or $press.Character -eq 'j') {$pos++}
				If ($vkeycode -eq 36) { $pos = 0 }
				If ($vkeycode -eq 35) { $pos = $menuItems.length - 1 }
				If ($press.Character -eq ' ') { $selection = Toggle-Selection $pos $selection }
				if ($pos -lt 0) {$pos = 0}
				If ($vkeycode -eq 27) {$pos = $null }
				if ($pos -ge $menuItems.length) {$pos = $menuItems.length -1}
				if ($vkeycode -ne 27)
				{
					$startPos = [System.Console]::CursorTop - $menuItems.Length
					[System.Console]::SetCursorPosition(0, $startPos)
					DrawMenu $menuItems $pos $Multiselect $selection
				}
			}
		}
		finally {
			[System.Console]::SetCursorPosition(0, $startPos + $menuItems.Length)
			[console]::CursorVisible = $true
		}
	}
	else {
		$pos = $null
	}

    if ($ReturnIndex -eq $false -and $pos -ne $null)
	{
		if ($Multiselect){
			return $menuItems[$selection]
		}
		else {
			return $menuItems[$pos]
		}
	}
	else 
	{
		if ($Multiselect){
			return $selection
		}
		else {
			return $pos
		}
	}
}


<#
$Original = @{
    lets = 'go'
    Sub = @{
      Foo =  'bar'
      big = 'ya'
    }
    finish = 'fish'
}
$Patch = @{
    lets = 'arrive'
    Sub = @{
      Foo =  'baz'
    }
    finish ='cum'
    New="Ye"
}
#>
function Merge-Hashtables {
    param(
        $Original,
        $Patch
    )
    $Merged = @{} # Final Merged settings

    if (!$Original){$Original = @{}}

    if ($Original.GetType().Name -in 'PSCustomObject','PSObject'){
        $Temp = [ordered]@{}
        $Original.PSObject.Properties | ForEach-Object { $Temp[$_.Name] = $_.Value }
        $Original = $Temp
        Remove-Variable Temp #fck temp vars
    }

    foreach ($Key in [object[]]$Original.Keys) {

        if ($Original.$Key -is [HashTable]){
            $Merged.$Key += [HashTable](Merge-Hashtables $Original.$Key $Patch.$Key)
            continue
        }

        if ($Patch.$Key -and !$Merged.$Key){ # If the setting exists in the patch
            $Merged.Remove($Key)
            if ($Original.$Key -ne $Patch.$Key){
                Write-Verbose "Changing $Key from $($Original.$Key) to $($Patch.$Key)"
            }
            $Merged += @{$Key = $Patch.$Key} # Then add it to the final settings
        }else{ # Else put in the unchanged normal setting
            $Merged += @{$Key = $Original.$Key}
        }
    }

    ForEach ($Key in [object[]]$Patch.Keys) {
        if ($Patch.$Key -is [HashTable] -and ($Key -NotIn $Original.Keys)){
            $Merged.$Key += [HashTable](Merge-Hashtables $Original.$Key $Patch.$Key)
            continue
        }
        if ($Key -NotIn $Original.Keys){
            $Merged.$Key += $Patch.$Key
        }
    }

    return $Merged
}
function Get-IniContent {
    <#
    .Synopsis
        Gets the content of an INI file

    .Description
        Gets the content of an INI file and returns it as a hashtable

    .Notes
        Author		: Oliver Lipkau <oliver@lipkau.net>
		Source		: https://github.com/lipkau/PsIni
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91
        Version		: 1.0.0 - 2010/03/12 - OL - Initial release
                      1.0.1 - 2014/12/11 - OL - Typo (Thx SLDR)
                                              Typo (Thx Dave Stiff)
                      1.0.2 - 2015/06/06 - OL - Improvment to switch (Thx Tallandtree)
                      1.0.3 - 2015/06/18 - OL - Migrate to semantic versioning (GitHub issue#4)
                      1.0.4 - 2015/06/18 - OL - Remove check for .ini extension (GitHub Issue#6)
                      1.1.0 - 2015/07/14 - CB - Improve round-tripping and be a bit more liberal (GitHub Pull #7)
                                           OL - Small Improvments and cleanup
                      1.1.1 - 2015/07/14 - CB - changed .outputs section to be OrderedDictionary
                      1.1.2 - 2016/08/18 - SS - Add some more verbose outputs as the ini is parsed,
                      				            allow non-existent paths for new ini handling,
                      				            test for variable existence using local scope,
                      				            added additional debug output.

        #Requires -Version 2.0

    .Inputs
        System.String

    .Outputs
        System.Collections.Specialized.OrderedDictionary

    .Example
        $FileContent = Get-IniContent "C:\myinifile.ini"
        -----------
        Description
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent

    .Example
        $inifilepath | $FileContent = Get-IniContent
        -----------
        Description
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent

    .Example
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini"
        C:\PS>$FileContent["Section"]["Key"]
        -----------
        Description
        Returns the key "Key" of the section "Section" from the C:\settings.ini file

    .Link
        Out-IniFile
    #>

    [CmdletBinding()]
    [OutputType(
        [System.Collections.Specialized.OrderedDictionary]
    )]
    Param(
        # Specifies the path to the input file.
        [ValidateNotNullOrEmpty()]
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [String]
        $FilePath,

        # Specify what characters should be describe a comment.
        # Lines starting with the characters provided will be rendered as comments.
        # Default: ";"
        [Char[]]
        $CommentChar = @(";"),

        # Remove lines determined to be comments from the resulting dictionary.
        [Switch]
        $IgnoreComments
    )

    Begin {
        Write-Debug "PsBoundParameters:"
        $PSBoundParameters.GetEnumerator() | ForEach-Object { Write-Debug $_ }
        if ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }
        Write-Debug "DebugPreference: $DebugPreference"

        Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"

        $commentRegex = "^\s*([$($CommentChar -join '')].*)$"
        $sectionRegex = "^\s*\[(.+)\]\s*$"
        $keyRegex     = "^\s*(.+?)\s*=\s*(['`"]?)(.*)\2\s*$"

        Write-Debug ("commentRegex is {0}." -f $commentRegex)
    }

    Process {
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"

        $ini = New-Object System.Collections.Specialized.OrderedDictionary([System.StringComparer]::OrdinalIgnoreCase)
        #$ini = @{}

        if (!(Test-Path $Filepath)) {
            Write-Verbose ("Warning: `"{0}`" was not found." -f $Filepath)
            Write-Output $ini
        }

        $commentCount = 0
        switch -regex -file $FilePath {
            $sectionRegex {
                # Section
                $section = $matches[1]
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Adding section : $section"
                $ini[$section] = New-Object System.Collections.Specialized.OrderedDictionary([System.StringComparer]::OrdinalIgnoreCase)
                $CommentCount = 0
                continue
            }
            $commentRegex {
                # Comment
                if (!$IgnoreComments) {
                    if (!(test-path "variable:local:section")) {
                        $section = $script:NoSection
                        $ini[$section] = New-Object System.Collections.Specialized.OrderedDictionary([System.StringComparer]::OrdinalIgnoreCase)
                    }
                    $value = $matches[1]
                    $CommentCount++
                    Write-Debug ("Incremented CommentCount is now {0}." -f $CommentCount)
                    $name = "Comment" + $CommentCount
                    Write-Verbose "$($MyInvocation.MyCommand.Name):: Adding $name with value: $value"
                    $ini[$section][$name] = $value
                }
                else {
                    Write-Debug ("Ignoring comment {0}." -f $matches[1])
                }

                continue
            }
            $keyRegex {
                # Key
                if (!(test-path "variable:local:section")) {
                    $section = $script:NoSection
                    $ini[$section] = New-Object System.Collections.Specialized.OrderedDictionary([System.StringComparer]::OrdinalIgnoreCase)
                }
                $name, $value = $matches[1, 3]
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Adding key $name with value: $value"
                if (-not $ini[$section][$name]) {
                    $ini[$section][$name] = $value
                }
                else {
                    if ($ini[$section][$name] -is [string]) {
                        $ini[$section][$name] = [System.Collections.ArrayList]::new()
                        $ini[$section][$name].Add($ini[$section][$name]) | Out-Null
                        $ini[$section][$name].Add($value) | Out-Null
                    }
                    else {
                        $ini[$section][$name].Add($value) | Out-Null
                    }
                }
                continue
            }
        }
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"
        Write-Output $ini
    }

    End {
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
    }
}

Set-Alias gic Get-IniContent

Function Out-IniFile {
    <#
    .Synopsis
        Write hash content to INI file

    .Description
        Write hash content to INI file

    .Notes
        Author      : Oliver Lipkau <oliver@lipkau.net>
        Blog        : http://oliver.lipkau.net/blog/
        Source      : https://github.com/lipkau/PsIni
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91

        #Requires -Version 2.0

    .Inputs
        System.String
        System.Collections.IDictionary

    .Outputs
        System.IO.FileSystemInfo

    .Example
        Out-IniFile $IniVar "C:\myinifile.ini"
        -----------
        Description
        Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini

    .Example
        $IniVar | Out-IniFile "C:\myinifile.ini" -Force
        -----------
        Description
        Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini and overwrites the file if it is already present

    .Example
        $file = Out-IniFile $IniVar "C:\myinifile.ini" -PassThru
        -----------
        Description
        Saves the content of the $IniVar Hashtable to the INI File c:\myinifile.ini and saves the file into $file

    .Example
        $Category1 = @{“Key1”=”Value1”;”Key2”=”Value2”}
        $Category2 = @{“Key1”=”Value1”;”Key2”=”Value2”}
        $NewINIContent = @{“Category1”=$Category1;”Category2”=$Category2}
        Out-IniFile -InputObject $NewINIContent -FilePath "C:\MyNewFile.ini"
        -----------
        Description
        Creating a custom Hashtable and saving it to C:\MyNewFile.ini
    .Link
        Get-IniContent
    #>

    [CmdletBinding()]
    [OutputType(
        [System.IO.FileSystemInfo]
    )]
    Param(
        # Adds the output to the end of an existing file, instead of replacing the file contents.
        [switch]
        $Append,

        # Specifies the file encoding. The default is UTF8.
        #
        # Valid values are:
        # -- ASCII:  Uses the encoding for the ASCII (7-bit) character set.
        # -- BigEndianUnicode:  Encodes in UTF-16 format using the big-endian byte order.
        # -- Byte:   Encodes a set of characters into a sequence of bytes.
        # -- String:  Uses the encoding type for a string.
        # -- Unicode:  Encodes in UTF-16 format using the little-endian byte order.
        # -- UTF7:   Encodes in UTF-7 format.
        # -- UTF8:  Encodes in UTF-8 format.
        [ValidateSet("Unicode", "UTF7", "UTF8", "ASCII", "BigEndianUnicode", "Byte", "String")]
        [Parameter()]
        [String]
        $Encoding = "UTF8",

        # Specifies the path to the output file.
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path $_ -IsValid} )]
        [Parameter( Position = 0, Mandatory = $true )]
        [String]
        $FilePath,

        # Allows the cmdlet to overwrite an existing read-only file. Even using the Force parameter, the cmdlet cannot override security restrictions.
        [Switch]
        $Force,

        # Specifies the Hashtable to be written to the file. Enter a variable that contains the objects or type a command or expression that gets the objects.
        [Parameter( Mandatory = $true, ValueFromPipeline = $true )]
        [System.Collections.IDictionary]
        $InputObject,

        # Passes an object representing the location to the pipeline. By default, this cmdlet does not generate any output.
        [Switch]
        $Passthru,

        # Adds spaces around the equal sign when writing the key = value
        [Switch]
        $Loose,

        # Writes the file as "pretty" as possible
        #
        # Adds an extra linebreak between Sections
        [Switch]
        $Pretty
    )

    Begin {
        Write-Debug "PsBoundParameters:"
        $PSBoundParameters.GetEnumerator() | ForEach-Object { Write-Debug $_ }
        if ($PSBoundParameters['Debug']) {
            $DebugPreference = 'Continue'
        }
        Write-Debug "DebugPreference: $DebugPreference"

        Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"

        function Out-Keys {
            param(
                [ValidateNotNullOrEmpty()]
                [Parameter( Mandatory, ValueFromPipeline )]
                [System.Collections.IDictionary]
                $InputObject,

                [ValidateSet("Unicode", "UTF7", "UTF8", "ASCII", "BigEndianUnicode", "Byte", "String")]
                [Parameter( Mandatory )]
                [string]
                $Encoding = "UTF8",

                [ValidateNotNullOrEmpty()]
                [ValidateScript( {Test-Path $_ -IsValid})]
                [Parameter( Mandatory, ValueFromPipelineByPropertyName )]
                [Alias("Path")]
                [string]
                $FilePath,

                [Parameter( Mandatory )]
                $Delimiter,

                [Parameter( Mandatory )]
                $MyInvocation
            )

            Process {
                if (!($InputObject.get_keys())) {
                    Write-Warning ("No data found in '{0}'." -f $FilePath)
                }
                Foreach ($key in $InputObject.get_keys()) {
                    if ($key -match "^Comment\d+") {
                        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing comment: $key"
                        "$($InputObject[$key])" | Out-File -Encoding $Encoding -FilePath $FilePath -Append
                    }
                    else {
                        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing key: $key"
                        $InputObject[$key] |
                            ForEach-Object { "$key$delimiter$_" } |
                            Out-File -Encoding $Encoding -FilePath $FilePath -Append
                    }
                }
            }
        }

        $delimiter = '='
        if ($Loose) {
            $delimiter = ' = '
        }

        # Splatting Parameters
        $parameters = @{
            Encoding = $Encoding;
            FilePath = $FilePath
        }

    }

    Process {
        $extraLF = ""

        if ($Append) {
            Write-Debug ("Appending to '{0}'." -f $FilePath)
            $outfile = Get-Item $FilePath
        }
        else {
            Write-Debug ("Creating new file '{0}'." -f $FilePath)
            $outFile = New-Item -ItemType file -Path $Filepath -Force:$Force
        }

        if (!(Test-Path $outFile.FullName)) {Throw "Could not create File"}

        Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing to file: $Filepath"
        foreach ($i in $InputObject.get_keys()) {
            if (!($InputObject[$i].GetType().GetInterface('IDictionary'))) {
                #Key value pair
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing key: $i"
                "$i$delimiter$($InputObject[$i])" | Out-File -Append @parameters

            }
            elseif ($i -eq $script:NoSection) {
                #Key value pair of NoSection
                Out-Keys $InputObject[$i] `
                    @parameters `
                    -Delimiter $delimiter `
                    -MyInvocation $MyInvocation
            }
            else {
                #Sections
                Write-Verbose "$($MyInvocation.MyCommand.Name):: Writing Section: [$i]"

                # Only write section, if it is not a dummy ($script:NoSection)
                if ($i -ne $script:NoSection) { "$extraLF[$i]"  | Out-File -Append @parameters }
                if ($Pretty) {
                    $extraLF = "`r`n"
                }

                if ( $InputObject[$i].Count) {
                    Out-Keys $InputObject[$i] `
                        @parameters `
                        -Delimiter $delimiter `
                        -MyInvocation $MyInvocation
                }

            }
        }
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Writing to file: $FilePath"
    }

    End {
        if ($PassThru) {
            Write-Debug ("Returning file due to PassThru argument.")
            Write-Output (Get-Item $outFile)
        }
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
    }
}

Set-Alias oif Out-IniFile

function Add-ContextMenu {
    #! TODO https://www.tenforums.com/tutorials/69524-add-remove-drives-send-context-menu-windows-10-a.html
    param(
        [ValidateSet(
            'SendTo',
            'TakeOwnership',
            'OpenWithOnBatchFiles',
            'DrivesInSendTo',
            'TakeOwnership'
            )]
        [Array]$Entries
    )
    if (!(Test-Admin)){
        return 'Changing the context menu / default file extensions requires running as Admin, exitting..'

    }

    if ('SendTo' -in $Entries){
        New-ItemProperty -Path Registry::HKEY_CLASSES_ROOT\AllFilesystemObjects\shellex\ContextMenuHandlers\SendTo -Name "(default)" -PropertyType String -Value "{7BA4C740-9E81-11CF-99D3-00AA004AE837}" -Force
    }

    if ('DrivesInSendTo' -in $Entries){
        Set-ItemProperty "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name NoDrivesInSendToMenu -Value 0
    }


    if ('OpenWithOnBatchFiles' -in $Entries){
        New-Item -Path "Registry::HKEY_CLASSES_ROOT\batfile\shell\Open with\command" -Force
        New-Item -Path "Registry::HKEY_CLASSES_ROOT\cmdfile\shell\Open with\command" -Force
        Set-ItemProperty "Registry::HKEY_CLASSES_ROOT\batfile\shell\Open with\command" -Name "(Default)" -Value "{09799AFB-AD67-11d1-ABCD-00C04FC30936}" -Force
        Set-ItemProperty "Registry::HKEY_CLASSES_ROOT\batfile\shell\Open with\command" -Name "(Default)" -Value "{09799AFB-AD67-11d1-ABCD-00C04FC30936}" -Force

    }

    if ('TakeOwnership' -in $Entries){
        '*','Directory' | ForEach-Object {
            New-Item -Path "Registry::HKEY_CLASSES_ROOT\$_\shell\runas"
            New-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\$_\shell\runas" -Name '(Default)' -Value 'Take Ownership'
            New-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\$_\shell\runas" -Name 'NoWorkingDirectory' -Value ''
            New-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\$_\shell\runas" -Name 'HasLUAShield' -Value ''
            New-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\$_\shell\runas" -Name 'Position' -Value 'Middle'
            New-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\$_\shell\runas" -Name 'AppliesTo' -Value "NOT (System.ItemPathDisplay:=`"$env:HOMEDRIVE\`")"

            New-Item -Path "Registry::HKEY_CLASSES_ROOT\$_\shell\runas\command"
            $Command = 'cmd.exe /c title Taking ownership.. & mode con:lines=30 cols=150 & takeown /f "%1" && icacls "%1" /grant administrators:F & timeout 2 >nul'
            New-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\$_\shell\runas\command" -Name '(Default)' -Value $Command
            New-ItemProperty -LiteralPath "Registry::HKEY_CLASSES_ROOT\$_\shell\runas\command" -Name 'IsolatedCommand' -Value $Command

        }
    }

}
function Set-CompatibilitySettings {
    [alias('scs')]
    param(
        [Parameter(Mandatory = $true)]
        [String]$Path,

        [Switch]$DisableFullScreenOptimizations,
        [Switch]$RunAsAdmin
    )

    if (!$RunAsAdmin -and !$DisableFullScreenOptimizations){
        return "No compatibility settings were set, returning."
    }

    if ($FilePath.Extension -eq '.lnk'){
        $FilePath = Get-Item (Get-ShortcutTarget $FilePath) -ErrorAction Stop
    }else{
        $FilePath = Get-Item $Path -ErrorAction Stop
    }

    $Data = '~'
    if ($DisableFullScreenOptimizations){$Data += " DISABLEDXMAXIMIZEDWINDOWEDMODE"}
    if ($RunAsAdmin){$Data += " RUNASADMIN"}

    New-Item -ItemType Directory -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" -ErrorAction Ignore
    New-ItemProperty -Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" `
    -Name $FilePath.FullName -PropertyType String -Value $Data -Force | Out-Null

}
function Optimize-OBS {
    <#
    .SYNOPSIS
    Display Name: Optimize OBS
    .DESCRIPTION
    Tune your OBS for a specific usecase in the snap of a finger!
    .PARAMETER Encoder
    Which hardware type you wish to record with
    test: test
    .PARAMETER OBS64Path
    If you've got a portable install or something, pass in the main OBS binary's path here
    #>
    [alias('optobs')]
    param(
        [ValidateSet('test')]
        [String]$Encoder,
        
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
        [String]$OBS64Path,

        [ValidateSet('HighPerformance')]
        [String]$Preset = 'HighPerformance',

        [ValidateSet(
            'EnableStatsDock', 'OldDarkTheme')]
        [Array]$MiscTweaks = (Invoke-CheckBox -Title "Select misc tweaks to apply" -Items (
            'EnableStatsDock', 'OldDarkTheme')),

        [ValidateScript({ Test-Path -Path $_ -PathType Container })]
        [String]$OBSProfile = $null
    )

    if (!$Encoder){
        $Encoders = [Ordered]@{
            "test" = "test"
        }
        Write-Host "Select what OBS will use to record (use arrow keys and press ENTER to confirm)"
        $Key = Menu ([Collections.ArrayList]$Encoders.Keys)
        $Encoder = $Encoders.$Key
    }

    $OBSPatches = @{
        HighPerformance = @{
            test = @{
                basic = @{
                    Video = @{
                        BaseCX=1920
                        BaseCY=1080
                        OutputCX=1920
                        OutputCY=1080
                        AutoRemux='false'
                        FPSType=0
                        FPSCommon=60
                        FPSNum=120
                        ScaleType='bicubic'
                        FPSInt=30
                        FPSDen=1
                        ColorFormat='NV12'
                        ColorSpace=709
                        ColorRange='Partial'
                        SdrWhiteLevel=300
                        HdrNominalPeakLevel=1000
                    }
                    Output = @{
                        FilenameFormatting='%MM-%DD-%hh-%mm-%ss'
                        Reconnect='false'
                        DelayEnable='false'
                        DelaySec=20
                        DelayPreserve='true'
                        RetryDelay=2
                        MaxRetries=25
                        BindIP='default'
                        NewSocketLoopEnable='false'
                        LowLatencyEnable='false'
                        Mode='Advanced'
                    }
                    AdvOut = @{
                        AudioEncoder='ffmpeg_aac'
                        UseRescale='false'
                        ApplyServiceSettings='true'
                        Track6Bitrate=320
                        RecType='Standard'
                        RecUseRescale='false'
                        FFAudioMixes=1
                        FFAEncoderId=0
                        Track4Bitrate=320
                        RecAudioEncoder='ffmpeg_aac'
                        Track2Bitrate=320
                        VodTrackIndex=2
                        FFVGOPSize=250
                        FFUseRescale='false'
                        FFABitrate=160
                        FFIgnoreCompat='false'
                        RecFormat2='mkv'
                        FFVEncoderId=0
                        Track5Bitrate=320
                        RecRBSize=8192
                        RecRB='true'
                        FLVTrack=1
                        RecTracks=1
                        Track3Bitrate=320
                        Encoder='jim_nvenc'
                        RecEncoder='jim_hevc_nvenc'
                        FFOutputToFile='true'
                        FFVBitrate=2500
                        TrackIndex=1
                        Track1Bitrate=320
                        RecRBTime=45
                    }
                    Stream1 = @{
                        IgnoreRecommended='true'
                    }
                    Audio = @{
                        SampleRate=48000
                    }
                }
                recordEncoder = @{
                    bf=0
                    cqp=16
                    lookahead='false'
                    multipass='disabled'
                    preset2='p7'
                    psycho_aq='false'
                    rate_control='CQP'
                    profile='main'
                }
                streamEncoder = @{
                    bitrate=8250
                    bf=2
                    psycho_aq='false'
                    keyint_sec=2
                    preset='p7'
                    preset2='p7'
                    multipass='disabled'
                    lookahead='disabled'
                    tune=11
                }
            }
            SinglePCRecording = @{
                basic = @{
                    Video = @{
                        BaseCX=1920
                        BaseCY=1080
                        OutputCX=1920
                        OutputCY=1080
                        AutoRemux='false'
                        FPSType=0
                        FPSCommon=60
                        FPSNum=120
                        ScaleType='bicubic'
                        FPSInt=30
                        FPSDen=1
                        ColorFormat='NV12'
                        ColorSpace=709
                        ColorRange='Partial'
                        SdrWhiteLevel=300
                        HdrNominalPeakLevel=1000
                    }
                    Output = @{
                        FilenameFormatting='%MM-%DD-%hh-%mm-%ss'
                        Reconnect='false'
                        DelayEnable='false'
                        DelaySec=20
                        DelayPreserve='true'
                        RetryDelay=2
                        MaxRetries=25
                        BindIP='default'
                        NewSocketLoopEnable='false'
                        LowLatencyEnable='false'
                    }
                    AdvOut = @{
                        ApplyServiceSettings='true'
                        UseRescale='false'
                        TrackIndex=1
                        VodTrackIndex=2
                        Encoder='obs_x264'
                        RecType='Standard'
                        RecFilePath='C:\\Users\\dusty\\Videos'
                        RecFormat2='fragmented_mp4'
                        RecUseRescale='false'
                        RecTracks=1
                        RecEncoder='jim_hevc_nvenc'
                        FLVTrack=1
                        FFOutputToFile='true'
                        FFFilePath='C:\\Users\\dusty\\Videos'
                        FFVBitrate=2500
                        FFVGOPSize=250
                        FFUseRescale='false'
                        FFIgnoreCompat='false'
                        FFABitrate=160
                        FFAudioMixes=1
                        Track1Bitrate=320
                        Track2Bitrate=320
                        Track3Bitrate=320
                        Track4Bitrate=320
                        Track5Bitrate=320
                        Track6Bitrate=320
                        RecSplitFileTime=15
                        RecSplitFileSize=2048
                        RecRBTime=30
                        RecRBSize=8192
                        AudioEncoder='ffmpeg_aac'
                        RecAudioEncoder='ffmpeg_opus'
                        RecSplitFileType='Time'
                        FFVEncoderId=0
                        FFAEncoderId=0
                    }
                    Hotkeys = @{
                        ReplayBuffer='{"ReplayBuffer.Save":[{"key":"OBS_KEY_F24"}]}'
                    }
                }
                recordEncoder = @{
                    rate_control='CQP'
                    cqp=16
                    preset2='p7'
                    multipass='disabled'
                    psycho_aq='false'
                    bf=0
                }
            }
            QuickSync = @{

                basic = @{
                    AdvOut = @{
                        RecEncoder = 'obs_qsv11'
                    }
                }
                recordEncoder = @{
                    enhancements = 'false'
                    target_usage = 'speed'
                    bframes = 0
                    rate_control = 'ICQ'
                    bitrate = 16500
                    icq_quality = 18
                    keyint_sec = 2
                }
                
            }
            x264 = @{
                basic = @{
                    ADVOut = @{
                        RecEncoder='obs_x264'
                    }
                }
                recordEncoder = @{
                    crf=1
                    keyint_sec=1
                    preset='ultrafast'
                    profile='high'
                    rate_control='CRF'
                    x264opts='qpmin=15 qpmax=15 ref=0 merange=4 direct=none weightp=0 no-chroma-me'
                }
            }
        }
    }

    # Applies to all patches/presets
    $Global = @{
            basic = @{
                Output = @{
                    Mode='Advanced'
            }
                AdvOut = @{
                    RecRB='true'
            }
        }
    }
    $OBSPatches.$Preset.$Encoder = Merge-Hashtables $OBSPatches.$Preset.$Encoder $Global
        # Merge with global, which will be added for all

    if (!$OBSProfile){
        Remove-Variable -Name OBSProfile
        if (-Not($OBS64Path)){

            $Parameters = @{
                Path = @("$env:APPDATA\Microsoft\Windows\Start Menu","$env:ProgramData\Microsoft\Windows\Start Menu")
                Recurse = $True
                Include = 'OBS Studio*.lnk'
            }
            $StartMenu = Get-ChildItem @Parameters
            
            if (!$StartMenu){
                if ((Get-Process obs64 -ErrorAction Ignore).Path){$OBS64Path = (Get-Process obs64).Path} # Won't work if OBS is ran as Admin
                else{
    return @'
Your OBS installation could not be found, 
please manually specify the path to your OBS64 executable, example:
Optimize-OBS -OBS64Path "D:\obs\bin\64bit\obs64.exe"
You can find it this way:             
Search OBS -> Right click it
Open file location in Explorer ->
Open file location again if it's a shortcut ->
Shift right click obs64.exe -> Copy as path
'@
                }
            }
            if ($StartMenu.Count -gt 1){

                $Shortcuts = $null
                $StartMenu = Get-Item $StartMenu
                ForEach($Lnk in $StartMenu){$Shortcuts += @{$Lnk.BaseName = $Lnk.FullName}}
                "There are multiple OBS shortcuts in your Start Menu folder. Please select one."
                $ShortcutName = menu ($Shortcuts.Keys -Split [System.Environment]::NewLine)
                $StartMenu = $Shortcuts.$ShortcutName
                $OBS64Path = Get-ShortcutTarget $StartMenu
            }else{
                $OBS64Path = Get-ShortcutTarget $StartMenu
            }

        }

        if (!$IsLinux -or !$IsMacOS){
            [Version]$CurVer = (Get-Item $OBS64Path).VersionInfo.ProductVersion
            if ($CurVer -lt [Version]"28.1.0"){
                Write-Warning @"
It is strongly advised you update OBS before continuing (for compatibility with new NVENC/AMD settings)
Detected version: $CurVer
obs64.exe path: $OBS64Path
pause
"@
            }
        }

        Set-CompatibilitySettings $OBS64Path -RunAsAdmin

        if (Resolve-Path "$OBS64Path\..\..\..\portable_mode.txt" -ErrorAction Ignore){ # "Portable Mode" makes OBS make the config in it's own folder, else it's in appdata

            $ProfilesDir = (Resolve-Path "$OBS64Path\..\..\..\config\obs-studio\basic\profiles" -ErrorAction Stop)
        }else{
            $ProfilesDir = (Resolve-Path "$env:APPDATA\obs-studio\basic\profiles" -ErrorAction Stop)
        }
        $Profiles = Get-ChildItem $ProfilesDir

        ForEach($OBSProfile in $Profiles){$ProfilesHash += @{$OBSProfile.Name = $OBSProfile.FullName}}

        $ProfileNames = ($ProfilesHash.Keys -Split [System.Environment]::NewLine) + 'Create a new profile'
        "Please select a profile (use arrow keys to navigate, ENTER to select)"
        $OBSProfile = menu  $ProfileNames

        if ($OBSProfile -eq 'Create a new profile'){
            $NewProfileName = Read-Host "Enter a name for the new profile"
            $OBSProfile = Join-Path $ProfilesDir $NewProfileName
            New-Item -ItemType Directory -Path $OBSProfile -ErrorAction Stop
            $DefaultWidth, $DefaultHeight = ((Get-CimInstance Win32_VideoController).VideoModeDescription.Split(' x ') | Where-Object {$_ -ne ''} | Select-Object -First 2)
            if (!$DefaultWidth -or !$DefaultHeight){
                $DefaultWidth = 1920
                $DefaultHeight = 1080
            }
            Set-Content "$OBSProfile\basic.ini" -Value @"
[General]
Name=$NewProfileName
[Video]
BaseCX=$DefaultWidth
BaseCY=$DefaultHeight
OutputCX=$DefaultWidth
OutputCY=$DefaultHeight
"@
            Write-Host "Created new profile '$NewProfileName' with default resolution of $DefaultWidth`x$DefaultHeight" -ForegroundColor DarkGray
        }else{
            $OBSProfile = $ProfilesHash.$OBSProfile
        }
    }
    if ('basic.ini' -notin ((Get-ChildItem $OBSProfile).Name)){
       return "FATAL: Profile $OBSProfile is incomplete (missing basic.ini)"
    }
    Write-Verbose "Tweaking profile $OBSProfile"
    try {
        $Basic = Get-IniContent "$OBSProfile\basic.ini" -ErrorAction Stop
    } catch {
        Write-Warning "Failed to get basic.ini from profile folder $OBSProfile"
        $_
        return
    }

    $FPS = $Basic.Video.FPSNum/$Basic.Video.FPSDen
    $Pixels = [int]$Basic.Video.BaseCX*[int]$Basic.Video.BaseCY

    if (!$Basic.Hotkeys.ReplayBuffer){
        Write-Warning "Set a Key to Save Replay in Hotkeys and Push-To-Talk if needed, Set Process Priority to Normal and Disable Browser Source Hardware Acceleration in Advanced"
    }

    $Basic = Merge-Hashtables -Original $Basic -Patch $OBSPatches.$Preset.$Encoder.basic -ErrorAction Stop
    Out-IniFile -FilePath "$OBSProfile\basic.ini" -InputObject $Basic -Pretty -Force

    if ($Basic.Video.BaseCX -and $Basic.Video.BaseCY -and $Basic.Video.OutputCX -and $Basic.Video.OutputCY){

        $Base = "{0}x{1}" -f $Basic.Video.BaseCX,$Basic.Video.BaseCY
        $Output = "{0}x{1}" -f $Basic.Video.OutputCX,$Basic.Video.OutputCY
        if ($Base -Ne $Output){
            Write-Warning "Your Base/Canvas resolution ($Base) is not the same as the Output/Scaled resolution ($Output),`nthis means OBS is scaling your video. This is not recommended."
        }    
    }
    
    $NoEncSettings = -Not(Test-Path "$OBSProfile\recordEncoder.json")
    $EmptyEncSettings = (Get-Content "$OBSProfile\recordEncoder.json" -ErrorAction Ignore) -in '',$null

    if ($NoEncSettings -or $EmptyEncSettings){
        Set-Content -Path "$OBSProfile\recordEncoder.json" -Value '{}' -Force 
    }
    $RecordEncoder = Get-Content "$OBSProfile\recordEncoder.json" | ConvertFrom-Json -ErrorAction Stop

    if (($Basic.Video.FPSNum/$Basic.Video.FPSDen -gt 480) -And ($Pixels -ge 2073600)){ # Set profile to baseline if recording at a high FPS and if res +> 2MP
        $RecordEncoder.Profile = 'baseline'
    }
    $RecordEncoder = Merge-Hashtables -Original $RecordEncoder -Patch $OBSPatches.$Preset.$Encoder.recordEncoder -ErrorAction Stop
    if ($Verbose){
        ConvertTo-Yaml $Basic
        ConvertTo-Yaml $RecordEncoder    
    }
    Set-Content -Path "$OBSProfile\recordEncoder.json" -Value (ConvertTo-Json -InputObject $RecordEncoder -Depth 100) -Force

    $NoEncSettings = -Not(Test-Path "$OBSProfile\streamEncoder.json")
    $EmptyEncSettings = (Get-Content "$OBSProfile\streamEncoder.json" -ErrorAction Ignore) -in '',$null

    if ($NoEncSettings -or $EmptyEncSettings){
        Set-Content -Path "$OBSProfile\streamEncoder.json" -Value '{}' -Force 
    }
    $StreamEncoder = Get-Content "$OBSProfile\streamEncoder.json" | ConvertFrom-Json -ErrorAction Stop

    if (($Basic.Video.FPSNum/$Basic.Video.FPSDen -gt 480) -And ($Pixels -ge 2073600)){ # Set profile to baseline if recording at a high FPS and if res +> 2MP
        $StreamEncoder.Profile = 'baseline'
    }
    $StreamEncoder = Merge-Hashtables -Original $streamEncoder -Patch $OBSPatches.$Preset.$Encoder.streamEncoder -ErrorAction Stop
    if ($Verbose){
        ConvertTo-Yaml $Basic
        ConvertTo-Yaml $streamEncoder    
    }
    Set-Content -Path "$OBSProfile\streamEncoder.json" -Value (ConvertTo-Json -InputObject $streamEncoder -Depth 100) -Force



    if ($True -in [bool]$MiscTweaks){ # If there is anything in $MiscTweaks
        $global = Get-Item (Join-Path ($OBSProfile | Split-Path | Split-Path | Split-Path) -ChildPath 'global.ini') -ErrorAction Stop
        $glob = Get-IniContent -FilePath $global

        if ('OldDarkTheme' -in $MiscTweaks){
            $glob.General.CurrentTheme3 = 'Dark'
        }

        if ('OldDarkTheme' -in $MiscTweaks){

            $glob.BasicWindow.geometry = 'AdnQywADAAAAAAe/////uwAADJ0AAAKCAAAHv////9oAAAydAAACggAAAAEAAAAACgAAAAe/////2gAADJ0AAAKC'
            $glob.BasicWindow.DockState = 'AAAA/wAAAAD9AAAAAgAAAAAAAAJOAAABvPwCAAAAAfsAAAASAHMAdABhAHQAcwBEAG8AYwBrAQAAABYAAAG8AAAA5gD///8AAAADAAAE3wAAALr8AQAAAAX7AAAAFABzAGMAZQBuAGUAcwBEAG8AYwBrAQAAAAAAAAD4AAAAoAD////7AAAAFgBzAG8AdQByAGMAZQBzAEQAbwBjAGsBAAAA/AAAAPoAAACgAP////sAAAASAG0AaQB4AGUAcgBEAG8AYwBrAQAAAfoAAAFBAAAA3gD////7AAAAHgB0AHIAYQBuAHMAaQB0AGkAbwBuAHMARABvAGMAawEAAAM/AAAAtAAAAI4A////+wAAABgAYwBvAG4AdAByAG8AbABzAEQAbwBjAGsBAAAD9wAAAOgAAACeAP///wAAAo0AAAG8AAAABAAAAAQAAAAIAAAACPwAAAAA'
        }

        $glob | Out-IniFile -FilePath $global -Force
    }
    Write-Host "Finished patching OBS, yay! Please switch profiles or reload OBS to see changes" -ForegroundColor Green
}
Export-ModuleMember * -Alias *
})) | Import-Module -DisableNameChecking -Global