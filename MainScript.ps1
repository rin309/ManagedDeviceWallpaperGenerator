# requiers admin

#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
Import-Module PackageManagement
Get-PackageSource -Name nuget.org | Set-PackageSource -Trusted | Out-Null
Install-Package Microsoft.Web.WebView2
