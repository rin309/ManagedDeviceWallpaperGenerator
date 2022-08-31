Function Global:Update-WebView2Variable($sender, $e){
    If ($MainWindow.FindName("WebView2") -eq $Null){
        Write-Verbose "WebView2 is null. <$($sender.Name).$($e.RoutedEvent.Name)>"
        Return
    }
    If (-not $MainWindow.FindName("WebView2").IsInitialized){
        Write-Verbose "WebView2 is not initialized. <$($sender.Name).$($e.RoutedEvent.Name)>"
        Return
    }
    If ($FiledUpdateing){
        Write-Verbose "The requested action has been canceled because it is currently being processed. <$($sender.Name).$($e.RoutedEvent.Name)>"
        Return
    }

    $Global:FiledUpdateing = $True

    $MainWindow.FindName("WebView2").NavigateToString($HtmlTemplate)
    $MainWindow.FindName("WebView2").ExecuteScriptAsync("document.getElementById(""Line1"").innerText = ""$($MainWindow.FindName("Line1TextBox").Text)""")
    $MainWindow.FindName("WebView2").ExecuteScriptAsync("document.getElementById(""Line2"").innerText = ""$($MainWindow.FindName("Line2TextBox").Text)""")

    $Body = @()
    $Line1 = @()
    $Line2 = @()
    $HtmlAndBody = @()

    $Color = $MainWindow.FindName("ColorsComboBox").SelectedItem
    $Style = $MainWindow.FindName("StylesComboBox").SelectedItem

    If ($Style.'font-family' -ne $Null){ $Body += "font-family: $($Style.'font-family')" }
    If ($Color.'background-color' -ne $Null){ $Body += "background-color: $($Color.'background-color')" }
    If ($Color.'color' -ne $Null){ $Body += "color: $($Color.'color')" }
    If ($Style.'line1.font-family' -ne $Null){ $Line1 += "font-family: $($Style.'line1.font-family')" }
    If ($Style.'line1.font-size' -ne $Null){ $Line1 += "font-size: $($Style.'line1.font-size')" }
    If ($Style.'line2.font-family' -ne $Null){ $Line2 += "font-family: $($Style.'line2.font-family')" }
    If ($Style.'line2.font-size' -ne $Null){ $Line2 += "font-size: $($Style.'line2.font-size')" }
    If ($Style.'padding' -ne $Null){ $MainWindow.FindName("WebView2").ExecuteScriptAsync("document.styleSheets[0].addRule(""#Container"", ""padding: $($Style.'padding')"")") }

    # layout tab
    If ($MainWindow.FindName("TopLeftAlignmentRadioButton").IsChecked){
        $HtmlAndBody += "justify-content: left; align-items: flex-start"
    }
    ElseIf ($MainWindow.FindName("TopCenterAlignmentRadioButton").IsChecked){
        $HtmlAndBody += "justify-content: center; align-items: flex-start"
    }
    ElseIf ($MainWindow.FindName("TopRightAlignmentRadioButton").IsChecked){
        $HtmlAndBody += "justify-content: right; align-items: flex-start"
    }
    ElseIf ($MainWindow.FindName("LeftAlignmentRadioButton").IsChecked){
        $HtmlAndBody += "justify-content: left; align-items: center"
    }
    ElseIf ($MainWindow.FindName("CenterAlignmentRadioButton").IsChecked){
        $HtmlAndBody += "justify-content: center; align-items: center"
    }
    ElseIf ($MainWindow.FindName("RightAlignmentRadioButton").IsChecked){
        $HtmlAndBody += "justify-content: right; align-items: center"
    }
    ElseIf ($MainWindow.FindName("BottomLeftAlignmentRadioButton").IsChecked){
        $HtmlAndBody += "justify-content: left; align-items: flex-end"
    }
    ElseIf ($MainWindow.FindName("BottomCenterAlignmentRadioButton").IsChecked){
        $HtmlAndBody += "justify-content: center; align-items: flex-end"
    }
    ElseIf ($MainWindow.FindName("BottomRightAlignmentRadioButton").IsChecked){
        $HtmlAndBody += "justify-content: right; align-items: flex-end"
    }

    If ($MainWindow.FindName("AutoOverFlowCheckBox").IsChecked){
        If ($MainWindow.FindName("IgnoreDpiSettingsCheckBox").IsChecked){
            [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "document.body.firstElementChild.clientWidth", [Action[String]]{param ($Value)
                $Global:FiledUpdateing = $True
                $MainWindow.FindName("WidthTextBox").Text = $Value
                $Global:FiledUpdateing = $False
            })
            [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "document.body.firstElementChild.clientHeight", [Action[String]]{param ($Value)
                $Global:FiledUpdateing = $True
                $MainWindow.FindName("HeightTextBox").Text = $Value
                $Global:FiledUpdateing = $False
            })
        }
        Else{
            [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "document.body.firstElementChild.clientWidth", [Action[String]]{param ($Value)
                $Global:FiledUpdateing = $True
                $MainWindow.FindName("WidthTextBox").Text = $Value
                $Global:FiledUpdateing = $False
            })
            [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "document.body.firstElementChild.clientHeight", [Action[String]]{param ($Value)
                $Global:FiledUpdateing = $True
                $MainWindow.FindName("HeightTextBox").Text = $Value
                $Global:FiledUpdateing = $False
            })
        }
    }


    Write-Verbose "[$($Style.Name)] <$($sender.Name).$($e.RoutedEvent.Name)> `n- body: $($Body -Join "; ")`n- #Line1: $($Line1 -Join "; ")`n- #Line2: $($Line2 -Join "; ")`n- html, body: $($HtmlAndBody -Join "; ")"

    [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "document.styleSheets[0].addRule(""body"", ""$($Body -Join "; ")"");", [Action[String]]{})
    [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "document.styleSheets[0].addRule(""#Line1"", ""$($Line1 -Join "; ")"");", [Action[String]]{})
    [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "document.styleSheets[0].addRule(""#Line2"", ""$($Line2 -Join "; ")"");", [Action[String]]{})
    [WebView2ExtendFunctions]::ExecuteScript($MainWindow.FindName("WebView2"), "document.styleSheets[0].addRule(""html, body"", ""$($HtmlAndBody -Join "; ")"");", [Action[String]]{})

    $Global:FiledUpdateing = $False
}
