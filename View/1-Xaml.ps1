#
# Xaml
#

Function Global:Get-ViewClass{
    $Global:Win32Functions = Add-Type -PassThru -Name "Win32Functions" -MemberDefinition "[DllImport(""kernel32.dll"", SetLastError = true)]
        public static extern bool SetDllDirectory(string lpPathName);
        [DllImport(""user32.dll"", SetLastError = true)]
        public static extern bool SetSysColors(int cElements, int [] lpaElements, int [] lpaRgbValues);
        [DllImport(""user32.dll"", SetLastError = true)]
        public static extern int SystemParametersInfo(int uiAction, int uiParam, string pvParam, int fWinIni);"


    $WebView2RuntimesPath = "$env:ProgramFiles\PackageManagement\NuGet\Packages\Microsoft.Web.WebView*\runtimes"
    If (Test-Path $WebView2RuntimesPath -PathType Container){
        Switch ((Get-WmiObject -Class Win32_ComputerSystem).SystemType.ToLower()){
            ("x64-based pc"){
                $WebView2LoaderPath = (Get-Item "$WebView2RuntimesPath\win-x64\native\WebView2Loader.dll")[0]
            }
            ("x86-based pc"){
                $WebView2LoaderPath = (Get-Item "$WebView2RuntimesPath\win-x86\native\WebView2Loader.dll")[0]
            }
            ("arm64-based pc"){
                $WebView2LoaderPath = (Get-Item "$WebView2RuntimesPath\win-arm64\native\WebView2Loader.dll")[0]
            }
        }
        $MicrosoftWebWebView2WpfForDotnet45Path = (Get-Item "$env:ProgramFiles\PackageManagement\NuGet\Packages\Microsoft.Web.WebView*\lib\net45\Microsoft.Web.WebView2.Wpf.dll")[0]
        $MicrosoftWebWebView2CoreForDotnet45Path = (Get-Item "$env:ProgramFiles\PackageManagement\NuGet\Packages\Microsoft.Web.WebView*\lib\net45\Microsoft.Web.WebView2.Core.dll")[0]
        $Path = (Split-Path $WebView2LoaderPath -Parent)
        $Win32Functions::SetDllDirectory($Path) | Out-Null
    }
    Else{
        $MicrosoftWebWebView2WpfForDotnet45Path = (Get-Item "Microsoft.Web.WebView2.Wpf.dll")[0]
        $MicrosoftWebWebView2CoreForDotnet45Path = (Get-Item "Microsoft.Web.WebView2.Core.dll")[0]
    }
    [Reflection.Assembly]::LoadFile($MicrosoftWebWebView2WpfForDotnet45Path) | Out-Null
    [Reflection.Assembly]::LoadFile($MicrosoftWebWebView2CoreForDotnet45Path) | Out-Null

    Add-Type -Language VisualBasic -ReferencedAssemblies PresentationFramework,PresentationCore,WindowsBase,System.Xaml,$MicrosoftWebWebView2WpfForDotnet45Path,$MicrosoftWebWebView2CoreForDotnet45Path -TypeDefinition '
Public Class WebView2ExtendFunctions

    Public Shared Async Sub ExecuteScript(WebView2 As Microsoft.Web.WebView2.Wpf.WebView2, JavaScript As String, Optional Action As System.Action(Of String) = Nothing)
        Dim Value As String = Await WebView2.ExecuteScriptAsync(JavaScript)
        If (Action IsNot Nothing) Then
            Action(Value)
        End If
    End Sub

    Public Shared Async Sub CapturePreview(WebView2 As Microsoft.Web.WebView2.Wpf.WebView2, FilePath As String, Optional Action As System.Action = Nothing)
        Dim Stream As New System.IO.MemoryStream
        Await WebView2.CoreWebView2.CapturePreviewAsync(Microsoft.Web.WebView2.Core.CoreWebView2CapturePreviewImageFormat.Png, Stream)
        Dim FileStream As New System.IO.FileStream(FilePath, System.IO.FileMode.Create, System.IO.FileAccess.Write)
        Stream.WriteTo(FileStream)
        FileStream.Close()
        Stream.Close()

        If (Action IsNot Nothing) Then
            Action()
        End If
    End Sub

End Class
    '
}

Function Global:Request-Job($Script, $DependentPs1File, $Arguments) {
    $Hash = [hashtable]::Synchronized(@{})
    $Hash.Host = $Host
    $Hash.MainWindow = $MainWindow
    $Hash.ScheduledTaskName = $ScheduledTaskName
    $Hash.DetectiveInstalledComponents = $DetectiveInstalledComponents
    $Hash.CurrentConfig = $CurrentConfig
    $Hash.DependentPs1File = (Convert-Path $DependentPs1File)
    $Hash.Arguments = $Arguments

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('Hash',$Hash)
    $runspace.SessionStateProxy.SetVariable('Script',$Script)
    $powershell = [powershell]::Create()

    $powershell.Runspace = $runspace
    $powershell.AddScript({
        $Global:MainWindow = $Hash.MainWindow
        $Global:HostUi = $Hash.Host.Ui
        $Global:CurrentConfig = $Hash.CurrentConfig
        $MainWindow.FindName("WebView2").
        $Global:DependentPs1File = $Hash.DependentPs1File
        $Global:Arguments = $Hash.Arguments

        Invoke-Expression -Command 'Function Global:Write-Host($Text){$HostUi.WriteLine($Text)}' | Out-Null
        Invoke-Expression -Command 'Function Global:Write-Verbose($Text){$HostUi.WriteVerboseLine($Text)}' | Out-Null
        Invoke-Expression -Command 'Function Global:Write-Warning($Text){$HostUi.WriteWarningLine($Text)}' | Out-Null
        Invoke-Expression -Command 'Function Global:Write-Error($Text){$HostUi.WriteErrorLine($Text)}' | Out-Null

        Try{
            & $DependentPs1File | Out-Null
        }
        Catch{
            $HostUi.WriteErrorLine($PSItem.ToString())
            $HostUi.WriteErrorLine($PSItem.ScriptStackTrace)
        }

        Try{
            Invoke-Expression -Command "$Script" | Out-Null
        }
        Catch{
            $HostUi.WriteErrorLine($PSItem.ToString())
            $HostUi.WriteErrorLine($PSItem.ScriptStackTrace)
        }

    })
    $asyncpl = $powershell.BeginInvoke()
}

Function Global:Get-Xaml($Path){
    $XamlDocument = [System.Xml.Linq.XDocument]::Load($Path)
    # ResourceDictionaryのパスを指定
    $XamlDocument.Root.Descendants("{http://schemas.microsoft.com/winfx/2006/xaml/presentation}ResourceDictionary") | Where-Object HasAttributes | ForEach-Object{ If (Test-Path $_.Attribute("Source").Value){$_.Attribute("Source").SetValue((Convert-Path $_.Attribute("Source").Value))} } 
    # 余分なAttributesの削除
    $XamlDocument.Root.Attributes() | Where-Object Name -like "{http://www.w3.org/2000/xmlns/}local" | ForEach-Object{ $_.Remove() }
    $XamlDocument.Root.Attributes() | Where-Object Name -like "{http://schemas.microsoft.com/winfx/2006/xaml}Class" | ForEach-Object{ $_.Remove() }
    $XamlDocument.Root.Attributes() | Where-Object Name -like "{http://schemas.openxmlformats.org/markup-compatibility/2006}Ignorable" | ForEach-Object{ $_.Remove() }
    $XamlDocument.Root.Attributes() | Where-Object Name -like "{http://schemas.microsoft.com/expression/blend/2008}*" | ForEach-Object{ $_.Remove() }
    ($XamlDocument.Root.DescendantNodes() | Where-Object HasAttributes).Attributes() | Where-Object Name -like "{http://schemas.microsoft.com/expression/blend/2008}*" | ForEach-Object{ $_.Remove() }

    Return [Windows.Markup.XamlReader]::Load($XamlDocument.CreateReader())
}

Function Script:Set-FontFamilyComboBoxFontSizeComboBoxValue(){
    $FontFamily = $MainWindow.FindName("StylesComboBox").SelectedItem."$(($EditingTextControlName).ToLower()).font-family"
    $FontSize = $MainWindow.FindName("StylesComboBox").SelectedItem."$(($EditingTextControlName).ToLower()).font-size".Replace("pt","")
    If ([String]::IsNullOrWhiteSpace($FontFamily)){
        $FontFamily = $MainWindow.FindName("StylesComboBox").SelectedItem."font-family"
    }
    If ([String]::IsNullOrWhiteSpace($FontSize)){
        $FontSize = $MainWindow.FindName("StylesComboBox").SelectedItem."font-size".Replace("pt","")
    }
    $MainWindow.FindName("FontFamilyComboBox").Text = $FontFamily
    $MainWindow.FindName("FontSizeComboBox").Text = $FontSize
}

Function Global:Get-MainWindow(){
    $Global:HtmlTemplate = Get-Content -Path (Join-Path $PsScriptRoot "..\Assets\Template.htm") -Encoding UTF8
    $Global:FiledUpdateing = $True
    $Global:FirstLoaded = $False
    $Global:MainWindow = Get-Xaml ".\View\MainWindow.xaml"

    $MainWindow.FindName("ColorsComboBox").DataContext = $Settings
    $MainWindow.FindName("StylesComboBox").DataContext = $Settings
    $MainWindow.FindName("FontFamilyComboBox").DataContext = $Settings
    $MainWindow.FindName("FontSizeComboBox").DataContext = $Settings

    $MainWindow.Add_Closing({
        [System.Windows.Forms.Application]::Exit()
        Stop-Process $Pid
    })

    [System.Windows.Forms.Integration.ElementHost]::EnableModelessKeyboardInterop($MainWindow)
    $MainWindow.FindName("WebView2").Add_Loaded({
        $MainWindow.FindName("WebView2").Add_NavigationCompleted({param($sender, $e)
            If ($FirstLoaded){
                Return
            }
            $Global:FirstLoaded = $True

            $MainWindow.FindName("ColorsComboBox").SelectedIndex = 0
            $MainWindow.FindName("StylesComboBox").SelectedIndex = 0

            $MainWindow.FindName("AutoOverFlowCheckBox").IsChecked = $True
            $Global:FiledUpdateing = $False
            Update-WebView2Variable -sender $sender -e $e
            $MainWindow.Activate()
        })

        $MainWindow.FindName("WebView2").Add_CoreWebView2InitializationCompleted({param($sender, $e)
            
        })
        $MainWindow.FindName("ColorsComboBox").Add_SelectionChanged({param($sender, $e)
            $Global:EditingTextControlName = $Null
            Update-WebView2Variable -sender $sender -e $e
        })
        $MainWindow.FindName("StylesComboBox").Add_SelectionChanged({param($sender, $e)
            $Global:EditingTextControlName = $Null
            $MainWindow.FindName("FontFamilyComboBox").IsEnabled = $False
            $MainWindow.FindName("FontFamilyComboBox").Text = ""
            $MainWindow.FindName("FontSizeComboBox").IsEnabled = $False
            $MainWindow.FindName("FontSizeComboBox").Text = ""
            Update-WebView2Variable -sender $sender -e $e
        })
        $MainWindow.Add_KeyUp({param($sender, $e)
            If ($e.Key -eq [System.Windows.Input.Key]::F12){
                $MainWindow.FindName("WebView2").CoreWebView2.OpenDevToolsWindow()
            }
        })

    })

    $MainWindow.FindName("WebView2").CreationProperties = New-Object Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties
    $MainWindow.FindName("WebView2").CreationProperties.UserDataFolder = "$env:LocalAppData\ManagedDeviceWallpaperGenerator"

    $MainWindow.FindName("Line1TextBox").Add_TextChanged({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("Line2TextBox").Add_TextChanged({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("Line1TextBox").Add_GotFocus({
        $Global:EditingTextControlName = "Line1"
        $MainWindow.FindName("FontFamilyComboBox").IsEnabled = $True
        $MainWindow.FindName("FontSizeComboBox").IsEnabled = $True
        Set-FontFamilyComboBoxFontSizeComboBoxValue
    })
    $MainWindow.FindName("Line2TextBox").Add_GotFocus({
        $Global:EditingTextControlName = "Line2"
        $MainWindow.FindName("FontFamilyComboBox").IsEnabled = $True
        $MainWindow.FindName("FontSizeComboBox").IsEnabled = $True
        Set-FontFamilyComboBoxFontSizeComboBoxValue
    })


    $MainWindow.FindName("FontFamilyComboBox").Add_KeyUp({param($sender, $e)
        If ($e.Key -eq [System.Windows.Input.Key]::Enter){
            If ($sender -ne $Null){
                $sender.Template.FindName("PART_EditableTextBox", $sender).SelectAll()
            }
            $MainWindow.FindName("StylesComboBox").SelectedItem."$(($EditingTextControlName).ToLower()).font-family" = $MainWindow.FindName("FontFamilyComboBox").Text
            Update-WebView2Variable -sender $sender -e $e
        }
    })
    $MainWindow.FindName("FontFamilyComboBox").AddHandler([System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent, [System.Windows.RoutedEventHandler]{param($sender, $e)
        If ($sender -ne $Null){
            #$sender.Template.FindName("PART_EditableTextBox", $sender).SelectAll()
        }
        If ($EditingTextControlName -ne $Null){
            If (($MainWindow.FindName("StylesComboBox").SelectedItem)."$(($EditingTextControlName).ToLower()).font-family" -ne $MainWindow.FindName("FontFamilyComboBox").Text){
                $MainWindow.FindName("StylesComboBox").SelectedItem."$(($EditingTextControlName).ToLower()).font-family" = $MainWindow.FindName("FontFamilyComboBox").Text
                Update-WebView2Variable -sender $sender -e $e
            }
        }
    })
    $MainWindow.FindName("FontSizeComboBox").Add_KeyUp({param($sender, $e)
        If ($e.Key -eq [System.Windows.Input.Key]::Enter){
            If ($sender -ne $Null){
                $sender.Template.FindName("PART_EditableTextBox", $sender).SelectAll()
            }
            $MainWindow.FindName("StylesComboBox").SelectedItem."$(($EditingTextControlName).ToLower()).font-size" = "$($MainWindow.FindName("FontSizeComboBox").Text)pt"
            Update-WebView2Variable -sender $sender -e $e
        }
    })
    $MainWindow.FindName("FontSizeComboBox").AddHandler([System.Windows.Controls.Primitives.TextBoxBase]::TextChangedEvent, [System.Windows.RoutedEventHandler]{param($sender, $e)
        If ($sender -ne $Null){
            #$sender.Template.FindName("PART_EditableTextBox", $sender).SelectAll()
        }
        If ($EditingTextControlName -ne $Null){
            If (($MainWindow.FindName("StylesComboBox").SelectedItem)."$(($EditingTextControlName).ToLower()).font-size" -ne "$($MainWindow.FindName("FontSizeComboBox").Text)pt"){
                $MainWindow.FindName("StylesComboBox").SelectedItem."$(($EditingTextControlName).ToLower()).font-size" = "$($MainWindow.FindName("FontSizeComboBox").Text)pt"
                Update-WebView2Variable -sender $sender -e $e
            }
        }
    })


    $MainWindow.FindName("SaveImageButton").Add_Click({
        $FileChooser = New-Object System.Windows.Forms.SaveFileDialog
        $FileChooser.InitialDirectory = [Environment]::GetFolderPath("Desktop")
        $FileChooser.RestoreDirectory = $True
        $FileChooser.FileName = "Wallpaper.png"
        $FileChooser.Filter = "*.png|*.png"

        If ($FileChooser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            [WebView2ExtendFunctions]::CapturePreview($MainWindow.FindName("WebView2"), $FileChooser.FileName, $Null)
        }
    })

    $MainWindow.FindName("ApplyDesktopButton").Add_Click({
        $FileChooser = New-Object System.Windows.Forms.SaveFileDialog
        If ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
            $FileChooser.InitialDirectory = (Join-Path $env:SystemRoot "Web\Wallpaper")
        }
        Else{
            $FileChooser.InitialDirectory = [Environment]::GetFolderPath("Desktop")
        }
        $FileChooser.RestoreDirectory = $True
        $FileChooser.FileName = "Wallpaper.png"
        $FileChooser.Filter = "*.png|*.png"

        If ($FileChooser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            $FileName = $FileChooser.FileName
            Remove-Item $FileName -ErrorAction Ignore
            
            [WebView2ExtendFunctions]::CapturePreview($MainWindow.FindName("WebView2"), $FileName, $Null)

            [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "window.getComputedStyle(document.body, null).getPropertyValue('background-color');", [Action[String]]{param ($Value)
                $Value = ($Value | ConvertFrom-Json).Replace("rgb(","").Replace(")","").Replace(",",".")
                $Value = [Version]$Value
                $BackgroundColor = [System.Drawing.ColorTranslator]::ToHtml([System.Drawing.Color]::FromArgb($Value.Major, $Value.Minor, $Value.Build))
                $COLOR_DESKTOP = 1
                [int[]]$Elements = @($COLOR_DESKTOP)
                [int[]]$Colors = @([System.Drawing.ColorTranslator]::ToWin32($BackgroundColor))
                $Win32Functions::SetSysColors($Elements.Length, $Elements, $Colors) | Out-Null

            })
            
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value 0
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value 0
            Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value ([String]::Format("{0} {1} {2}", $Value.Major, $Value.Minor, $Value.Build))

            Start-Job -ArgumentList $FileName -ScriptBlock {param($FileName)
                $Global:Win32Functions = Add-Type -PassThru -Name "Win32Functions" -MemberDefinition "[DllImport(""user32.dll"", SetLastError = true)]
                    public static extern int SystemParametersInfo(int uiAction, int uiParam, string pvParam, int fWinIni);"

                $SPI_SETDESKWALLPAPER = 0x0014
                [Flags()] enum fWinIni{
                    SPIF_UPDATEINIFILE
                    SPIF_SENDCHANGE
                    SPIF_SENDWININICHANGE
                }
                $Limit = (Get-Date).AddSeconds(10)
                While ((Get-Date) -lt $Limit){
                    If (Test-Path $FileName){
                        $Win32Functions::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $FileName, [Int]([fWinIni]::SPIF_SENDCHANGE + [fWinIni]::SPIF_SENDWININICHANGE)) | Out-Null
                        Return
                    }
                }
            }

        }

    })

    # Layout tab
    $MainWindow.FindName("TopLeftAlignmentRadioButton").Add_Checked({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("TopCenterAlignmentRadioButton").Add_Checked({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("TopRightAlignmentRadioButton").Add_Checked({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("LeftAlignmentRadioButton").Add_Checked({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("CenterAlignmentRadioButton").Add_Checked({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("RightAlignmentRadioButton").Add_Checked({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("BottomLeftAlignmentRadioButton").Add_Checked({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("BottomCenterAlignmentRadioButton").Add_Checked({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})
    $MainWindow.FindName("BottomRightAlignmentRadioButton").Add_Checked({param($sender, $e) Update-WebView2Variable -sender $sender -e $e})

    $MainWindow.FindName("WidthTextBox").Add_PreviewTextInput({param($sender, $e) 
        Try{
            $Value = $MainWindow.FindName("WidthTextBox").Text
            If ([String]::IsNullOrWhiteSpace($Value)){
                $MainWindow.FindName("WidthTextBox").Dispatcher.Invoke({
                    $MainWindow.FindName("WidthTextBox").Undo()
                })
                Return
            }
            [Int]$Value | Out-Null
        }
        Catch{
            $MainWindow.FindName("WidthTextBox").Dispatcher.Invoke({
                $MainWindow.FindName("WidthTextBox").Undo()
            })
        }
    })
    $MainWindow.FindName("WidthTextBox").Add_TextChanged({param($sender, $e) 
        Try{
            If ($MainWindow.FindName("IgnoreDpiSettingsCheckBox").IsChecked){
                $MainWindow.FindName("WebView2").Width = [Int]$MainWindow.FindName("WidthTextBox").Text * $MainWindow.FindName("WebView2").ZoomFactor
                $MainWindow.FindName("WebView2").Height = [Int]$MainWindow.FindName("HeightTextBox").Text * $MainWindow.FindName("WebView2").ZoomFactor
            }
            Else{
                $MainWindow.FindName("WebView2").Width = [Int]$MainWindow.FindName("WidthTextBox").Text
                $MainWindow.FindName("WebView2").Height = [Int]$MainWindow.FindName("HeightTextBox").Text
            }
            Update-WebView2Variable -sender $sender -e $e
        }
        Catch{}
    })
    $MainWindow.FindName("HeightTextBox").Add_PreviewTextInput({param($sender, $e) 
        Try{
            $Value = $MainWindow.FindName("HeightTextBox").Text
            If ([String]::IsNullOrWhiteSpace($Value)){
                $MainWindow.FindName("HeightTextBox").Dispatcher.Invoke({
                    $MainWindow.FindName("HeightTextBox").Undo()
                })
                Return
            }
            [Int]$Value | Out-Null
        }
        Catch{
            $MainWindow.FindName("HeightTextBox").Dispatcher.Invoke({
                $MainWindow.FindName("HeightTextBox").Undo()
            })
        }
    })
    $MainWindow.FindName("HeightTextBox").Add_TextChanged({param($sender, $e) 
        Try{
            If ($MainWindow.FindName("IgnoreDpiSettingsCheckBox").IsChecked){
                $MainWindow.FindName("WebView2").Width = [Int]$MainWindow.FindName("WidthTextBox").Text * $MainWindow.FindName("WebView2").ZoomFactor
                $MainWindow.FindName("WebView2").Height = [Int]$MainWindow.FindName("HeightTextBox").Text * $MainWindow.FindName("WebView2").ZoomFactor
            }
            Else{
                $MainWindow.FindName("WebView2").Width = [Int]$MainWindow.FindName("WidthTextBox").Text
                $MainWindow.FindName("WebView2").Height = [Int]$MainWindow.FindName("HeightTextBox").Text
            }
            Update-WebView2Variable -sender $sender -e $e
        }
        Catch{}
    })

    $MainWindow.FindName("SetPrimaryScreenSizeButton").Add_Click({
        $MainWindow.FindName("AutoOverFlowCheckBox").IsChecked = $False
        $MainWindow.FindName("IgnoreDpiSettingsCheckBox").IsChecked = $True
        $MainWindow.FindName("WidthTextBox").Text = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
        $MainWindow.FindName("HeightTextBox").Text = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
    })
    $MainWindow.FindName("AutoOverFlowCheckBox").Add_Checked({param($sender, $e) 
        $MainWindow.FindName("WidthTextBox").IsEnabled = $False
        $MainWindow.FindName("HeightTextBox").IsEnabled = $False
        Update-WebView2Variable -sender $sender -e $e
    })
    $MainWindow.FindName("AutoOverFlowCheckBox").Add_UnChecked({param($sender, $e) 
        $MainWindow.FindName("WidthTextBox").IsEnabled = $True
        $MainWindow.FindName("HeightTextBox").IsEnabled = $True
        Update-WebView2Variable -sender $sender -e $e
    })
    $MainWindow.FindName("IgnoreDpiSettingsCheckBox").Add_Checked({param($sender, $e) 
        $MainWindow.FindName("WebView2").ZoomFactor = (1 / ([System.Windows.PresentationSource]::FromVisual($MainWindow).CompositionTarget.TransformToDevice.M11))
        $Global:FiledUpdateing = $True
        $MainWindow.FindName("WebView2").Width = [Int]($MainWindow.FindName("WidthTextBox").Text) * $MainWindow.FindName("WebView2").ZoomFactor
        $MainWindow.FindName("WebView2").Height = [Int]($MainWindow.FindName("HeightTextBox").Text) * $MainWindow.FindName("WebView2").ZoomFactor
        $Global:FiledUpdateing = $False
    })
    $MainWindow.FindName("IgnoreDpiSettingsCheckBox").Add_UnChecked({param($sender, $e)
        $MainWindow.FindName("WebView2").ZoomFactor = 1
        $Global:FiledUpdateing = $True
        $MainWindow.FindName("WebView2").Width = [Int]($MainWindow.FindName("WidthTextBox").Text)
        $MainWindow.FindName("WebView2").Height = [Int]($MainWindow.FindName("HeightTextBox").Text)
        $Global:FiledUpdateing = $False
        Update-WebView2Variable -sender $sender -e $e
    })

    # Template tab
    $MainWindow.FindName("ImportHtmlButton").Add_Click({param($sender, $e)
        $FileChooser = New-Object System.Windows.Forms.OpenFileDialog
        $FileChooser.InitialDirectory = [Environment]::GetFolderPath("Desktop")
        $FileChooser.RestoreDirectory = $True
        $FileChooser.Filter = "*.htm;*.html|*.htm;*.html"

        If ($FileChooser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            $Global:HtmlTemplate = Get-Content -Path $FileChooser.FileName -Encoding UTF8
            Update-WebView2Variable -sender $sender -e $e
        }
    })
    $MainWindow.FindName("ExportHtmlButton").Add_Click({param($sender, $e)
        $FileChooser = New-Object System.Windows.Forms.SaveFileDialog
        $FileChooser.InitialDirectory = [Environment]::GetFolderPath("Desktop")
        $FileChooser.RestoreDirectory = $True
        $FileChooser.Filter = "*.htm;*.html|*.htm;*.html"

        If ($FileChooser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            $Global:HtmlFilePath = $FileChooser.FileName
            [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "document.documentElement.outerHTML;", [Action[String]]{param ($Value) $Value | ConvertFrom-Json | Out-File $HtmlFilePath -Encoding UTF8; $Global:HtmlFilePath = $Null})
        }
       
    })
}
