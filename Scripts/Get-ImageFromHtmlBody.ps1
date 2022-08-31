Function Global:Get-ImageFromHtmlBody{
    Function Initialize-Configuration($ConfigPath, $Name, $DefaultConfigPath, [Switch]$IsRoot, [Switch]$IsArray, [Switch]$Force){
        Try{
            If (($ConfigPath | Get-Member -Name $Name).Count -ne 0 -or $Force){
                $ConfigPath = $ConfigPath | Select-Object ($ConfigPath | ForEach-Object { (Get-Member -InputObject $_ -MemberType NoteProperty).Name -ne "Styles"})
            }
            If (($ConfigPath | Get-Member -Name $Name).Count -eq 0){
                If ($IsRoot){
                    $ConfigPath = $ConfigPath | Select-Object *, $Name
                    $ConfigPath.$Name = [PSCustomObject]@{}
                    Write-Verbose "[Initialize-Configuration] Config に $Name をルートとして追加しました"
                }
                If ($IsArray){
                    $ConfigPath = $ConfigPath | Select-Object *, $Name
                    $ConfigPath.$Name = @()
                    Write-Verbose "[Initialize-Configuration] Config に $Name をルート配列として追加しました"
                }
                If ($DefaultConfigPath -ne $Null){
                    If (-not $IsArray -and -not $IsRoot){
                        $ConfigPath | Add-Member -MemberType NoteProperty -Name $Name -Value $DefaultConfigPath.$Name
                        Write-Verbose "[Initialize-Configuration] Config の $Name に既定値を追加しました"
                    }
                    Else{
                        Write-Warning "[Initialize-Configuration] Config の $Name に既定値を追加できませんでした: DefaultConfigPath はルートのため値は追加を追加できません"
                    }
                }
                ElseIf(-not $IsArray -and -not $IsRoot){
                    $ConfigPath | Add-Member -MemberType NoteProperty -Name $Name -Value $Null
                    Write-Verbose "[Initialize-Configuration] Config の $Name に null を追加しました"
                }
            }
        }
        Catch{
            If ($IsRoot){
                Write-Warning "[Initialize-Configuration] Config に $Name をルートとして追加できませんでした: $($_.Exception.Message))"
            }
            If ($IsArray){
                Write-Warning "[Initialize-Configuration] Config に $Name をルート配列として追加できませんでした: $($_.Exception.Message)"
            }
            ElseIf ($DefaultConfigPath -ne $Null){
                Write-Warning "[Initialize-Configuration] Config の $Name に既定値を追加できませんでした: $($_.Exception.Message)"
            }
        }
        Return $ConfigPath
    }
    Add-Type -AssemblyName System,System.Core,System.Windows.Forms,PresentationFramework,PresentationCore,WindowsBase,WindowsFormsIntegration,System.Xml.Linq,System.Dynamic | Out-Null
    #[Console].AssemblyQualifiedName
    [Windows.Forms.Application]::EnableVisualStyles()
    [System.Environment]::CurrentDirectory = (Get-Location)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Get-ChildItem -Path (Join-Path $PSScriptRoot "..\View\*.ps1") | ForEach-Object { . $_}

    $DefaultSettings = (Get-Content (Join-Path $PSScriptRoot "..\Assets\Settings.json") -Encoding UTF8 | ConvertFrom-Json)
    $Global:Settings = $DefaultSettings
    $Global:Settings = Initialize-Configuration -ConfigPath $Global:Settings -Name "Styles" -IsArray
    $DefaultSettings.Styles | ForEach-Object{
        $_ = Initialize-Configuration -ConfigPath $_ -Name "font-family" -DefaultConfigPath ""
        $_ = Initialize-Configuration -ConfigPath $_ -Name "padding" -DefaultConfigPath ""
        $_ = Initialize-Configuration -ConfigPath $_ -Name "line1.font-size" -DefaultConfigPath ""
        $_ = Initialize-Configuration -ConfigPath $_ -Name "line1.font-family" -DefaultConfigPath ""
        $_ = Initialize-Configuration -ConfigPath $_ -Name "line2.font-size" -DefaultConfigPath ""
        $_ = Initialize-Configuration -ConfigPath $_ -Name "line2.font-family" -DefaultConfigPath ""
        $Global:Settings.Styles += $_
    }

    Get-ViewClass
    Get-MainWindow

$MainWindow.Show()
[System.Windows.Forms.Application]::Run((New-Object System.Windows.Forms.ApplicationContext))

}
Export-ModuleMember -Function Get-ImageFromHtmlBody
